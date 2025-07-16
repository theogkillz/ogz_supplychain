-- ============================================
-- ADMIN TOOLS FOR CONTAINER MANAGEMENT
-- Advanced administrative interface for container system
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- ADMIN PERMISSION CHECKING
-- ============================================

-- Enhanced admin permission check (reusing from sv_admin.lua)
local function hasContainerAdminPermission(source, level)
    if source == 0 then return true end -- Console access
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return false end
    
    -- Try multiple permission methods
    local group = nil
    
    if QBCore.Functions.GetPermission then
        group = QBCore.Functions.GetPermission(source)
    end
    
    if not group and xPlayer.PlayerData and xPlayer.PlayerData.job then
        group = xPlayer.PlayerData.job.name
    end
    
    if not group and xPlayer.PlayerData and xPlayer.PlayerData.metadata then
        group = xPlayer.PlayerData.metadata.group or xPlayer.PlayerData.metadata.permission
    end
    
    if not group then return false end
    
    -- Permission hierarchy
    local permissions = {
        superadmin = {"god", "admin", "superadmin", "owner"},
        admin = {"god", "admin", "superadmin", "owner", "moderator", "mod"},
        moderator = {"god", "admin", "superadmin", "owner", "moderator", "mod"}
    }
    
    if permissions[level] then
        for _, perm in ipairs(permissions[level]) do
            if group == perm then return true end
        end
    end
    
    return false
end

-- ============================================
-- CONTAINER SYSTEM OVERVIEW
-- ============================================

-- Get comprehensive container system overview
local function getContainerSystemOverview(callback)
    MySQL.Async.fetchAll([[
        SELECT 
            -- Container inventory status
            ci.container_type,
            ci.available_quantity,
            ci.total_capacity,
            ci.reorder_threshold,
            
            -- Active containers
            COUNT(c.container_id) as active_containers,
            AVG(c.quality_level) as avg_quality,
            
            -- Status distribution
            SUM(CASE WHEN c.status = 'filled' THEN 1 ELSE 0 END) as filled_containers,
            SUM(CASE WHEN c.status = 'in_transit' THEN 1 ELSE 0 END) as in_transit_containers,
            SUM(CASE WHEN c.status = 'delivered' THEN 1 ELSE 0 END) as delivered_containers,
            SUM(CASE WHEN c.status = 'opened' THEN 1 ELSE 0 END) as opened_containers
            
        FROM supply_container_inventory ci
        LEFT JOIN supply_containers c ON ci.container_type = c.container_type
        GROUP BY ci.container_type, ci.available_quantity, ci.total_capacity, ci.reorder_threshold
    ]], {}, function(containerStats)
        
        -- Get system alerts
        MySQL.Async.fetchAll([[
            SELECT 
                alert_type,
                alert_level,
                COUNT(*) as alert_count
            FROM supply_container_alerts 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            AND acknowledged = 0
            GROUP BY alert_type, alert_level
        ]], {}, function(alerts)
            
            -- Get performance metrics
            MySQL.Async.fetchAll([[
                SELECT 
                    COUNT(*) as total_deliveries_24h,
                    AVG(avg_quality) as avg_quality_24h,
                    COUNT(CASE WHEN avg_quality >= 90 THEN 1 END) as excellent_deliveries,
                    COUNT(CASE WHEN temperature_breaches = 0 THEN 1 END) as zero_breach_deliveries
                FROM supply_container_quality_tracking
                WHERE tracking_date >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ]], {}, function(performance)
                
                callback({
                    containerStats = containerStats or {},
                    alerts = alerts or {},
                    performance = performance and performance[1] or {},
                    timestamp = os.time()
                })
            end)
        end)
    end)
end

-- ============================================
-- CONTAINER MONITORING COMMANDS
-- ============================================

-- Container system status command
RegisterCommand('containerstatus', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'moderator') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Moderator permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    getContainerSystemOverview(function(overview)
        if source == 0 then
            -- Console output
            print('=== CONTAINER SYSTEM STATUS ===')
            print('Active Containers: ' .. (overview.performance.total_deliveries_24h or 0))
            print('Average Quality (24h): ' .. string.format("%.1f%%", overview.performance.avg_quality_24h or 0))
            print('Excellent Deliveries: ' .. (overview.performance.excellent_deliveries or 0))
            print('Zero Breach Deliveries: ' .. (overview.performance.zero_breach_deliveries or 0))
            print('===============================')
            
            -- Container inventory status
            for _, container in ipairs(overview.containerStats) do
                local availability = container.available_quantity / container.total_capacity * 100
                local status = availability > 50 and "GOOD" or availability > 20 and "LOW" or "CRITICAL"
                print(string.format('%s: %d/%d (%.1f%% - %s)', 
                    container.container_type, 
                    container.available_quantity, 
                    container.total_capacity,
                    availability,
                    status
                ))
            end
        else
            -- Player notification
            TriggerClientEvent('containers:showAdminOverview', source, overview)
        end
    end)
end, false)

-- Container search command
RegisterCommand('searchcontainer', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'moderator') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Moderator permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local searchTerm = args[1]
    if not searchTerm then
        local usage = "Usage: /searchcontainer [container_id|order_group_id|restaurant_id]"
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Usage',
                description = usage,
                type = 'info',
                duration = 8000
            })
        end
        return
    end
    
    -- Search containers
    MySQL.Async.fetchAll([[
        SELECT c.*, ci.preservation_multiplier, ci.temperature_controlled
        FROM supply_containers c
        JOIN supply_container_inventory ci ON c.container_type = ci.container_type
        WHERE c.container_id LIKE ? 
           OR c.order_group_id LIKE ?
           OR c.restaurant_id = ?
        ORDER BY c.created_at DESC
        LIMIT 20
    ]], {
        '%' .. searchTerm .. '%',
        '%' .. searchTerm .. '%',
        tonumber(searchTerm) or -1
    }, function(results)
        
        if not results or #results == 0 then
            local message = "No containers found matching: " .. searchTerm
            if source == 0 then
                print(message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Search Results',
                    description = message,
                    type = 'info',
                    duration = 8000
                })
            end
            return
        end
        
        if source == 0 then
            print('=== CONTAINER SEARCH RESULTS ===')
            for _, container in ipairs(results) do
                print(string.format('ID: %s | Type: %s | Item: %s | Quality: %.1f%% | Status: %s',
                    container.container_id:sub(-8),
                    container.container_type,
                    container.contents_item,
                    container.quality_level,
                    container.status
                ))
            end
            print('===============================')
        else
            TriggerClientEvent('containers:showSearchResults', source, results, searchTerm)
        end
    end)
end, false)

-- ============================================
-- CONTAINER MANAGEMENT COMMANDS
-- ============================================

-- Force container quality update
RegisterCommand('updatecontainerquality', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'admin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local containerId = args[1]
    local newQuality = tonumber(args[2])
    
    if not containerId or not newQuality then
        local usage = "Usage: /updatecontainerquality [container_id] [quality_percentage]"
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Usage',
                description = usage,
                type = 'info',
                duration = 8000
            })
        end
        return
    end
    
    if newQuality < 0 or newQuality > 100 then
        local message = "Quality must be between 0 and 100"
        if source == 0 then
            print(message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Invalid Quality',
                description = message,
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    MySQL.Async.execute([[
        UPDATE supply_containers 
        SET quality_level = ?, updated_at = CURRENT_TIMESTAMP 
        WHERE container_id LIKE ?
    ]], {newQuality, '%' .. containerId .. '%'}, function(success, rowsAffected)
        
        if success and rowsAffected > 0 then
            local message = string.format("Updated %d container(s) quality to %.1f%%", rowsAffected, newQuality)
            
            -- Log the admin action
            MySQL.Async.execute([[
                INSERT INTO supply_container_quality_log 
                (container_id, quality_check_timestamp, quality_before, quality_after, degradation_factor, notes)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                containerId, GetGameTimer(), 0, newQuality, 'admin_override', 
                'Quality manually updated by admin (source: ' .. source .. ')'
            })
            
            if source == 0 then
                print(message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Quality Updated',
                    description = message,
                    type = 'success',
                    duration = 8000
                })
            end
        else
            local message = "Container not found or update failed"
            if source == 0 then
                print(message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Update Failed',
                    description = message,
                    type = 'error',
                    duration = 5000
                })
            end
        end
    end)
end, false)

-- Emergency container restock
RegisterCommand('emergencyrestock', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'admin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local containerType = args[1]
    local quantity = tonumber(args[2]) or 50
    
    if not containerType then
        local usage = "Usage: /emergencyrestock [container_type] [quantity]"
        if source == 0 then
            print(usage)
            print("Available types: ogz_cooler, ogz_crate, ogz_thermal, ogz_freezer, ogz_produce, ogz_bulk")
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Usage',
                description = usage .. "\nTypes: ogz_cooler, ogz_crate, ogz_thermal, ogz_freezer, ogz_produce, ogz_bulk",
                type = 'info',
                duration = 12000
            })
        end
        return
    end
    
    -- Validate container type
    if not Config.DynamicContainers.containerTypes[containerType] then
        local message = "Invalid container type: " .. containerType
        if source == 0 then
            print(message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Invalid Type',
                description = message,
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    -- Update inventory
    MySQL.Async.execute([[
        UPDATE supply_container_inventory 
        SET available_quantity = available_quantity + ?, 
            last_restocked = CURRENT_TIMESTAMP 
        WHERE container_type = ?
    ]], {quantity, containerType}, function(success)
        
        if success then
            local message = string.format("Emergency restock: +%d %s containers", quantity, containerType)
            
            if source == 0 then
                print("[EMERGENCY RESTOCK] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '🚨 Emergency Restock Complete',
                    description = message,
                    type = 'success',
                    duration = 8000
                })
            end
            
            -- Notify warehouse workers
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local xPlayer = QBCore.Functions.GetPlayer(playerId)
                if xPlayer and xPlayer.PlayerData.job.name == "warehouse" then
                    TriggerClientEvent('ox_lib:notify', playerId, {
                        title = '📦 Emergency Restock',
                        description = string.format('%d %s containers have been restocked', quantity, containerType),
                        type = 'info',
                        duration = 10000
                    })
                end
            end
        else
            local message = "Emergency restock failed"
            if source == 0 then
                print("[ERROR] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Restock Failed',
                    description = message,
                    type = 'error',
                    duration = 5000
                })
            end
        end
    end)
end, false)

-- ============================================
-- CONTAINER ANALYTICS AND REPORTS
-- ============================================

-- Generate container analytics report
RegisterCommand('containeranalytics', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'admin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local timeframe = args[1] or "7d" -- Default 7 days
    local days = timeframe == "1d" and 1 or timeframe == "7d" and 7 or timeframe == "30d" and 30 or 7
    
    -- Generate comprehensive analytics
    MySQL.Async.fetchAll([[
        SELECT 
            -- Usage statistics
            COUNT(DISTINCT c.container_id) as total_containers_used,
            COUNT(DISTINCT c.order_group_id) as total_orders_processed,
            COUNT(DISTINCT DATE(c.created_at)) as active_days,
            
            -- Quality metrics
            AVG(c.quality_level) as avg_final_quality,
            MIN(c.quality_level) as min_quality_recorded,
            MAX(c.quality_level) as max_quality_recorded,
            COUNT(CASE WHEN c.quality_level >= 90 THEN 1 END) as excellent_quality_count,
            COUNT(CASE WHEN c.quality_level < 50 THEN 1 END) as poor_quality_count,
            
            -- Container type distribution
            c.container_type,
            COUNT(*) as type_usage_count,
            AVG(c.quality_level) as type_avg_quality,
            
            -- Performance metrics
            AVG(TIMESTAMPDIFF(HOUR, c.filled_timestamp, c.delivered_timestamp)) as avg_delivery_time_hours,
            COUNT(CASE WHEN c.status = 'opened' THEN 1 END) as successfully_opened
            
        FROM supply_containers c
        WHERE c.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY c.container_type
        
        UNION ALL
        
        SELECT 
            -- Overall totals
            COUNT(DISTINCT container_id) as total_containers_used,
            COUNT(DISTINCT order_group_id) as total_orders_processed,
            COUNT(DISTINCT DATE(created_at)) as active_days,
            AVG(quality_level) as avg_final_quality,
            MIN(quality_level) as min_quality_recorded,
            MAX(quality_level) as max_quality_recorded,
            COUNT(CASE WHEN quality_level >= 90 THEN 1 END) as excellent_quality_count,
            COUNT(CASE WHEN quality_level < 50 THEN 1 END) as poor_quality_count,
            'TOTAL' as container_type,
            COUNT(*) as type_usage_count,
            AVG(quality_level) as type_avg_quality,
            AVG(TIMESTAMPDIFF(HOUR, filled_timestamp, delivered_timestamp)) as avg_delivery_time_hours,
            COUNT(CASE WHEN status = 'opened' THEN 1 END) as successfully_opened
        FROM supply_containers
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], {days, days}, function(analytics)
        
        if source == 0 then
            -- Console output
            print('=== CONTAINER ANALYTICS (' .. timeframe .. ') ===')
            
            for _, data in ipairs(analytics or {}) do
                if data.container_type == 'TOTAL' then
                    print('OVERALL STATISTICS:')
                    print('  Total Containers: ' .. (data.total_containers_used or 0))
                    print('  Total Orders: ' .. (data.total_orders_processed or 0))
                    print('  Average Quality: ' .. string.format("%.1f%%", data.avg_final_quality or 0))
                    print('  Excellent Quality Rate: ' .. string.format("%.1f%%", 
                        (data.excellent_quality_count / math.max(data.type_usage_count, 1)) * 100))
                    print('  Average Delivery Time: ' .. string.format("%.1f hours", data.avg_delivery_time_hours or 0))
                    print('')
                else
                    print('TYPE: ' .. data.container_type)
                    print('  Usage: ' .. (data.type_usage_count or 0))
                    print('  Avg Quality: ' .. string.format("%.1f%%", data.type_avg_quality or 0))
                    print('')
                end
            end
            print('===============================')
        else
            TriggerClientEvent('containers:showAnalyticsReport', source, analytics, timeframe)
        end
    end)
end, false)

-- ============================================
-- CONTAINER DEBUGGING TOOLS
-- ============================================

-- Test container creation
RegisterCommand('testcontainer', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'admin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local containerType = args[1] or "ogz_crate"
    local ingredient = args[2] or "tomato"
    local quantity = tonumber(args[3]) or 10
    local restaurantId = tonumber(args[4]) or 1
    
    -- Create test container
    local containerId = exports[GetCurrentResourceName()]:createContainer(ingredient, quantity, "TEST_" .. GetGameTimer(), restaurantId)
    
    if containerId then
        local message = string.format("Test container created: %s (%s - %d %s)", 
            containerId, containerType, quantity, ingredient)
        
        if source == 0 then
            print("[TEST] " .. message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Test Container Created',
                description = message,
                type = 'success',
                duration = 10000
            })
        end
    else
        local message = "Failed to create test container"
        if source == 0 then
            print("[ERROR] " .. message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Test Failed',
                description = message,
                type = 'error',
                duration = 5000
            })
        end
    end
end, false)

-- Clean up orphaned containers
RegisterCommand('cleanupcontainers', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'superadmin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Superadmin permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local daysOld = tonumber(args[1]) or 7
    
    -- Clean up old opened containers
    MySQL.Async.execute([[
        DELETE FROM supply_containers 
        WHERE status = 'opened' 
        AND opened_timestamp < (UNIX_TIMESTAMP() - (? * 24 * 3600)) * 1000
    ]], {daysOld}, function(success, rowsAffected)
        
        if success then
            local message = string.format("Cleaned up %d old containers (older than %d days)", rowsAffected or 0, daysOld)
            
            if source == 0 then
                print("[CLEANUP] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Cleanup Complete',
                    description = message,
                    type = 'success',
                    duration = 8000
                })
            end
        else
            local message = "Cleanup failed"
            if source == 0 then
                print("[ERROR] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Cleanup Failed',
                    description = message,
                    type = 'error',
                    duration = 5000
                })
            end
        end
    end)
end, false)

-- ============================================
-- CONTAINER ALERT MANAGEMENT
-- ============================================

-- Acknowledge container alerts
RegisterCommand('ackcontaineralerts', function(source, args, rawCommand)
    if not hasContainerAdminPermission(source, 'moderator') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Moderator permissions required.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local alertType = args[1] or "all"
    local playerId = source
    
    local whereClause = alertType == "all" and "" or "AND alert_type = ?"
    local params = alertType == "all" and {} or {alertType}
    
    MySQL.Async.execute([[
        UPDATE supply_container_alerts 
        SET acknowledged = 1, acknowledged_by = ?, acknowledged_at = CURRENT_TIMESTAMP
        WHERE acknowledged = 0 ]] .. whereClause, 
        
        table.concat({playerId}, ",") .. (alertType ~= "all" and "," .. alertType or ""), 
        
        function(success, rowsAffected)
        
        if success then
            local message = string.format("Acknowledged %d %s alerts", 
                rowsAffected or 0, alertType == "all" and "container" or alertType)
            
            if source == 0 then
                print("[ALERTS] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Alerts Acknowledged',
                    description = message,
                    type = 'success',
                    duration = 8000
                })
            end
        end
    end)
end, false)

-- ============================================
-- COMMAND SUGGESTIONS
-- ============================================

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/containerstatus', 'Show container system status')
TriggerEvent('chat:addSuggestion', '/searchcontainer', 'Search for containers', {
    { name = 'search_term', help = 'Container ID, Order Group ID, or Restaurant ID' }
})
TriggerEvent('chat:addSuggestion', '/updatecontainerquality', 'Update container quality (Admin)', {
    { name = 'container_id', help = 'Container ID (partial match)' },
    { name = 'quality', help = 'New quality percentage (0-100)' }
})
TriggerEvent('chat:addSuggestion', '/emergencyrestock', 'Emergency container restock (Admin)', {
    { name = 'container_type', help = 'Container type (ogz_cooler, ogz_crate, etc.)' },
    { name = 'quantity', help = 'Quantity to add (default: 50)' }
})
TriggerEvent('chat:addSuggestion', '/containeranalytics', 'Generate container analytics report (Admin)', {
    { name = 'timeframe', help = 'Time period: 1d, 7d, or 30d (default: 7d)' }
})
TriggerEvent('chat:addSuggestion', '/testcontainer', 'Create test container (Admin)', {
    { name = 'type', help = 'Container type' },
    { name = 'ingredient', help = 'Ingredient name' },
    { name = 'quantity', help = 'Quantity (default: 10)' },
    { name = 'restaurant_id', help = 'Restaurant ID (default: 1)' }
})
TriggerEvent('chat:addSuggestion', '/cleanupcontainers', 'Clean up old containers (Superadmin)', {
    { name = 'days', help = 'Delete containers older than X days (default: 7)' }
})
TriggerEvent('chat:addSuggestion', '/ackcontaineralerts', 'Acknowledge container alerts', {
    { name = 'alert_type', help = 'Alert type or "all" (default: all)' }
})

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CONTAINER ADMIN] Container administration system loaded!")
        print("[CONTAINER ADMIN] Available commands:")
        print("  /containerstatus - System overview")
        print("  /searchcontainer - Find containers")
        print("  /containeranalytics - Analytics report")
        print("  /emergencyrestock - Emergency container restock")
        print("  Type /help for full command list")
    end
end)

-- Export admin functions
exports('getContainerSystemOverview', getContainerSystemOverview)
exports('hasContainerAdminPermission', hasContainerAdminPermission)

print("[CONTAINER ADMIN] Container admin tools loaded successfully!")