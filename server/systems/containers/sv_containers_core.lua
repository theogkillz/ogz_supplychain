-- ============================================
-- CONTAINER CORE SYSTEM - ENTERPRISE EDITION
-- Professional container management and logistics
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- VALIDATION & ACCESS CONTROL
-- ============================================

-- Validate container access using shared validation
local function hasContainerAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE)
end

-- Enhanced access validation with detailed feedback
local function validateContainerAccess(source, operation)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return false, "Player not found"
    end
    
    local playerJob = Player.PlayerData.job.name
    local hasAccess = SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE)
    
    if not hasAccess then
        local errorMessage = SupplyValidation.getAccessDeniedMessage("container", playerJob)
        return false, errorMessage
    end
    
    return true, "Access granted"
end

-- ============================================
-- CONTAINER MATERIAL MANAGEMENT
-- ============================================

-- Give Empty Containers (PRESERVED FUNCTIONALITY)
RegisterNetEvent('containers:giveEmpty')
AddEventHandler('containers:giveEmpty', function(containerType, amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then return end
    
    -- Enhanced access validation
    local hasAccess, message = validateContainerAccess(src, "give_containers")
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Container Access Denied',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Validate container type using config validation
    if not SupplyValidation.validateContainerType(containerType) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Container Error',
            description = 'Invalid container type.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Validate amount using config validation
    if not SupplyValidation.validateQuantity(amount, 1, 50) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Container Error',
            description = 'Invalid amount (1-50).',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Get container configuration
    local containerConfig = Config.ContainerMaterials and Config.ContainerMaterials[containerType]
    if not containerConfig then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Configuration Error',
            description = 'Container configuration not found.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Give containers
    local success = xPlayer.Functions.AddItem(containerType, amount)
    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Containers Obtained',
            description = string.format('Received %d %s', amount, containerConfig.label),
            type = 'success',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        
        -- Log container distribution for analytics
        MySQL.Async.execute([[
            INSERT INTO supply_container_logs (
                citizenid, action, container_type, quantity, timestamp
            ) VALUES (?, ?, ?, ?, ?)
        ]], {
            xPlayer.PlayerData.citizenid,
            'containers_given',
            containerType,
            amount,
            os.time()
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Inventory Error',
            description = 'Inventory full or item not found.',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- ============================================
-- CONTAINER PURCHASING SYSTEM
-- ============================================

-- Buy Container Materials (ENHANCED)
RegisterNetEvent('containers:buyMaterial')
AddEventHandler('containers:buyMaterial', function(containerType, amount, totalCost)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then return end
    
    -- Enhanced access validation
    local hasAccess, message = validateContainerAccess(src, "buy_containers")
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Purchase Access Denied',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Validate container type
    if not SupplyValidation.validateContainerType(containerType) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Purchase Error',
            description = 'Invalid container type.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    local containerConfig = Config.ContainerMaterials and Config.ContainerMaterials[containerType]
    if not containerConfig then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Configuration Error',
            description = 'Container pricing not found.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Enhanced cost validation with precision
    local expectedCost = SupplyCalculations.calculateContainerCost(containerType, amount)
    if math.abs(totalCost - expectedCost) > 0.01 then -- Allow for floating point precision
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Price Error',
            description = 'Price mismatch detected. Please try again.',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Check if player has enough money
    if xPlayer.PlayerData.money.cash < totalCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            description = string.format('You need %s cash.', SupplyUtils.formatMoney(totalCost)),
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Process transaction
    if xPlayer.Functions.RemoveMoney('cash', totalCost, "Container materials purchase") then
        local success = xPlayer.Functions.AddItem(containerType, amount)
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Purchase Successful',
                description = string.format('Bought %d %s for %s', 
                    amount, containerConfig.label, SupplyUtils.formatMoney(totalCost)),
                type = 'success',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
            
            -- Log purchase for analytics
            MySQL.Async.execute([[
                INSERT INTO supply_container_logs (
                    citizenid, action, container_type, quantity, cost, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                xPlayer.PlayerData.citizenid,
                'containers_purchased',
                containerType,
                amount,
                totalCost,
                os.time()
            })
            
            -- Update container inventory if using dynamic system
            if Config.DynamicContainers and Config.DynamicContainers.enabled then
                TriggerEvent('containers:updateInventory', containerType, amount)
            end
        else
            -- Refund money if item couldn't be added
            xPlayer.Functions.AddMoney('cash', totalCost, "Container purchase refund")
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Purchase Error',
                description = 'Inventory full. Money refunded.',
                type = 'error',
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Transaction Error',
            description = 'Failed to process payment.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- ============================================
-- CONTAINER DELIVERY COMPLETION
-- ============================================

-- Complete container delivery (ENHANCED WITH TRACKING)
local function completeContainerDelivery(orderGroupId, restaurantId)
    if not orderGroupId or not restaurantId then
        print("[CONTAINERS ERROR] Missing parameters for delivery completion")
        return false
    end
    
    -- Update container status to delivered
    MySQL.Async.execute([[
        UPDATE supply_containers 
        SET status = 'delivered', 
            updated_at = CURRENT_TIMESTAMP,
            delivered_timestamp = ?
        WHERE order_group_id = ?
    ]], {os.time(), orderGroupId}, function(success, affectedRows)
        if success and affectedRows > 0 then
            print(string.format("[CONTAINERS] Delivery completed for order %s to restaurant %s (%d containers)", 
                orderGroupId, restaurantId, affectedRows))
            
            -- Trigger analytics tracking
            TriggerEvent('analytics:trackContainerDelivery', {
                orderGroupId = orderGroupId,
                restaurantId = restaurantId,
                containersDelivered = affectedRows,
                timestamp = os.time()
            })
            
            -- Notify restaurant staff about delivered containers
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local player = QBCore.Functions.GetPlayer(playerId)
                if player then
                    local restaurantJob = Config.Restaurants and Config.Restaurants[restaurantId] and 
                                        Config.Restaurants[restaurantId].job
                    if restaurantJob and player.PlayerData.job.name == restaurantJob then
                        TriggerClientEvent('ox_lib:notify', playerId, {
                            title = '📦 Container Delivery',
                            description = string.format('%d containers delivered to your restaurant!', affectedRows),
                            type = 'info',
                            duration = 10000,
                            position = Config.UI and Config.UI.notificationPosition or 'center-right',
                            markdown = Config.UI and Config.UI.enableMarkdown or true
                        })
                    end
                end
            end
            
            return true
        else
            print(string.format("[CONTAINERS ERROR] Failed to update containers for order %s", orderGroupId))
            return false
        end
    end)
    
    return true
end

-- ============================================
-- CONTAINER STATUS & TRACKING
-- ============================================

-- Get container status for order
RegisterNetEvent('containers:getOrderStatus')
AddEventHandler('containers:getOrderStatus', function(orderGroupId)
    local src = source
    
    if not hasContainerAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Container access restricted to warehouse employees.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    if not orderGroupId then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Order group ID required.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT 
            c.*,
            CASE 
                WHEN c.status = 'filled' THEN '📦 Ready for Pickup'
                WHEN c.status = 'loaded' THEN '🚚 In Transit'
                WHEN c.status = 'delivered' THEN '✅ Delivered'
                WHEN c.status = 'opened' THEN '📂 Opened'
                ELSE '❓ Unknown'
            END as status_display
        FROM supply_containers c
        WHERE c.order_group_id = ?
        ORDER BY c.created_at ASC
    ]], {orderGroupId}, function(results)
        if results and #results > 0 then
            TriggerClientEvent('containers:showOrderStatus', src, {
                orderGroupId = orderGroupId,
                containers = results,
                totalContainers = #results
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'No Containers Found',
                description = 'No containers found for this order.',
                type = 'info',
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
        end
    end)
end)

-- Update container tracking
RegisterNetEvent('containers:updateTracking')
AddEventHandler('containers:updateTracking', function(containerIds, newStatus, additionalData)
    local src = source
    
    if not hasContainerAccess(src) then return end
    
    if not containerIds or not newStatus then
        print("[CONTAINERS ERROR] Missing parameters for tracking update")
        return
    end
    
    -- Convert single ID to array for consistency
    if type(containerIds) ~= "table" then
        containerIds = {containerIds}
    end
    
    local updatedCount = 0
    for _, containerId in ipairs(containerIds) do
        MySQL.Async.execute([[
            UPDATE supply_containers 
            SET status = ?, updated_at = CURRENT_TIMESTAMP
            WHERE container_id = ?
        ]], {newStatus, containerId}, function(success)
            if success then
                updatedCount = updatedCount + 1
                
                -- Log tracking update
                MySQL.Async.execute([[
                    INSERT INTO supply_container_tracking (
                        container_id, status, updated_by, additional_data, timestamp
                    ) VALUES (?, ?, ?, ?, ?)
                ]], {
                    containerId,
                    newStatus,
                    src,
                    additionalData and json.encode(additionalData) or nil,
                    os.time()
                })
            end
        end)
    end
    
    -- Notify about successful updates
    if updatedCount > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Container Status Updated',
            description = string.format('Updated %d container(s) to %s', updatedCount, newStatus),
            type = 'success',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- ============================================
-- INTEGRATION WITH OTHER SYSTEMS
-- ============================================

-- Handle container system events from other modules
RegisterNetEvent('containers:systemIntegration')
AddEventHandler('containers:systemIntegration', function(eventType, eventData)
    if eventType == "order_created" then
        -- Handle new order with container requirements
        TriggerEvent('containers:processOrderContainers', eventData)
    elseif eventType == "delivery_started" then
        -- Update container status for delivery
        TriggerEvent('containers:updateDeliveryStatus', eventData)
    elseif eventType == "delivery_completed" then
        -- Complete container delivery
        completeContainerDelivery(eventData.orderGroupId, eventData.restaurantId)
    end
end)

-- Process containers for new orders
RegisterNetEvent('containers:processOrderContainers')
AddEventHandler('containers:processOrderContainers', function(orderData)
    -- This would integrate with the dynamic container system
    if Config.DynamicContainers and Config.DynamicContainers.enabled then
        -- Use dynamic container creation
        TriggerEvent('containers:createDynamicContainers', orderData)
    else
        -- Use standard container processing
        print("[CONTAINERS] Processing containers for order: " .. (orderData.orderGroupId or "unknown"))
    end
end)

-- ============================================
-- EXPORTS (FOR SYSTEM INTEGRATION)
-- ============================================

-- Export container functions for other systems
exports('completeContainerDelivery', completeContainerDelivery)
exports('hasContainerAccess', hasContainerAccess)
exports('validateContainerAccess', validateContainerAccess)

-- Export container status functions
exports('getContainerStatus', function(containerId)
    if not containerId then return nil end
    
    local result = MySQL.Sync.fetchAll('SELECT * FROM supply_containers WHERE container_id = ?', {containerId})
    return result and result[1] or nil
end)

-- Export container analytics functions
exports('getContainerAnalytics', function(timeframe)
    local days = timeframe == "7d" and 7 or timeframe == "30d" and 30 or 1
    
    local result = MySQL.Sync.fetchAll([[
        SELECT 
            COUNT(*) as total_containers,
            AVG(quality_level) as avg_quality,
            COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered_count
        FROM supply_containers 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], {days})
    
    return result and result[1] or {}
end)

-- ============================================
-- ADMIN COMMANDS
-- ============================================

-- Container system status command
RegisterCommand('containerstatus', function(source, args, rawCommand)
    if source ~= 0 and not exports['ogz_supplychain']:hasAdminPermission(source, 'moderator') then
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
    
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_containers,
            COUNT(CASE WHEN status = 'filled' THEN 1 END) as filled,
            COUNT(CASE WHEN status = 'loaded' THEN 1 END) as in_transit,
            COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered,
            AVG(quality_level) as avg_quality
        FROM supply_containers 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]], {}, function(results)
        if results and results[1] then
            local stats = results[1]
            local message = string.format(
                "Container Status (24h):\nTotal: %d\nFilled: %d\nIn Transit: %d\nDelivered: %d\nAvg Quality: %.1f%%",
                stats.total_containers,
                stats.filled,
                stats.in_transit,
                stats.delivered,
                stats.avg_quality or 0
            )
            
            if source == 0 then
                print("=== " .. message:gsub("\n", " | ") .. " ===")
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '📦 Container Status',
                    description = message,
                    type = 'info',
                    duration = 15000,
                    markdown = true
                })
            end
        end
    end)
end, false)

-- Add command suggestion
TriggerEvent('chat:addSuggestion', '/containerstatus', 'Show container system status (Admin)')

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("^2[CONTAINERS] 🏗️ Enterprise container core system loaded^0")
        
        -- Create container tracking tables if they don't exist
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_container_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                action VARCHAR(50) NOT NULL,
                container_type VARCHAR(50) NOT NULL,
                quantity INT NOT NULL,
                cost DECIMAL(10,2) DEFAULT 0,
                timestamp INT NOT NULL,
                INDEX idx_citizenid (citizenid),
                INDEX idx_action (action),
                INDEX idx_timestamp (timestamp)
            )
        ]])
        
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_container_tracking (
                id INT AUTO_INCREMENT PRIMARY KEY,
                container_id VARCHAR(100) NOT NULL,
                status VARCHAR(50) NOT NULL,
                updated_by INT DEFAULT 0,
                additional_data TEXT NULL,
                timestamp INT NOT NULL,
                INDEX idx_container (container_id),
                INDEX idx_status (status),
                INDEX idx_timestamp (timestamp)
            )
        ]])
        
        print("^2[CONTAINERS] 📊 Container tracking tables initialized^0")
    end
end)

print("^2[CONTAINERS] 🏆 Enterprise container core system initialized^0")