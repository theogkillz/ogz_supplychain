-- ============================================
-- CONTAINER DYNAMIC SYSTEM - CLIENT LOGIC
-- Container visualization and interaction system
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']

-- Client state management
local nearbyContainers = {}
local playerContainers = {}
local currentRestaurantId = nil
local containerAlerts = {}
local qualityUpdateThread = {}
local currentContainerMenu = nil
-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Get player's restaurant ID based on job
local function getPlayerRestaurantId()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return nil
    end
    
    local playerJob = PlayerData.job.name
    
    -- Map job names to restaurant IDs
    local jobToRestaurant = {
        ["burgershot"] = 1,
        ["pizzathis"] = 2,
        ["tacobomb"] = 3,
        ["restaurant"] = 1, -- Generic restaurant job defaults to 1
        ["hurst"] = nil     -- Warehouse workers don't have a specific restaurant
    }
    
    return jobToRestaurant[playerJob]
end

-- Get player's job access level
local function getPlayerJobAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return "none"
    end
    
    local playerJob = PlayerData.job.name
    
    if playerJob == "hurst" then
        return "warehouse"
    elseif playerJob == "burgershot" or playerJob == "pizzathis" or playerJob == "tacobomb" or playerJob == "restaurant" then
        return "restaurant"
    else
        return "none"
    end
end

-- Check if player has container access
local function hasContainerAccess()
    local access = getPlayerJobAccess()
    return access == "warehouse" or access == "restaurant"
end

-- Format time display
local function formatTime(timestamp)
    local currentTime = GetGameTimer()
    local timeDiff = math.abs(currentTime - timestamp)
    local seconds = math.floor(timeDiff / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes % 60)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds % 60)
    else
        return string.format("%ds", seconds)
    end
end

-- Format quality percentage
local function formatQuality(quality)
    if quality >= 80 then
        return string.format("🟢 %.1f%%", quality)
    elseif quality >= 50 then
        return string.format("🟡 %.1f%%", quality)
    else
        return string.format("🔴 %.1f%%", quality)
    end
end

-- Get container type display info
local function getContainerTypeInfo(containerType)
    local containerInfo = {
        ["standard"] = {icon = "📦", name = "Standard Container", color = "blue"},
        ["refrigerated"] = {icon = "🧊", name = "Refrigerated Container", color = "cyan"},
        ["freezer"] = {icon = "❄️", name = "Freezer Container", color = "lightblue"},
        ["insulated"] = {icon = "🌡️", name = "Insulated Container", color = "orange"},
        ["premium"] = {icon = "💎", name = "Premium Container", color = "gold"}
    }
    
    return containerInfo[containerType] or {icon = "📦", name = "Unknown Container", color = "gray"}
end

-- Get item label from ox_inventory
local function getItemLabel(item)
    local itemNames = exports.ox_inventory:Items() or {}
    return itemNames[item] and itemNames[item].label or item
end

-- ============================================
-- CONTAINER VISUALIZATION SYSTEM
-- ============================================

-- Create container visualization near player
local function createContainerVisualization(container)
    -- This would create 3D props/markers for containers
    -- For now, we'll use a simple notification system
    
    if container.current_location == "warehouse" then
        -- Containers in warehouse
        local warehouseCoords = vector3(1000.0, -1000.0, 30.0) -- Replace with actual coords
        -- Add blip or prop visualization
    elseif container.current_location:match("restaurant_") then
        -- Containers at restaurant
        local restaurantId = tonumber(container.current_location:match("restaurant_(%d+)"))
        if restaurantId and Config.Restaurants and Config.Restaurants[restaurantId] then
            local restaurantCoords = Config.Restaurants[restaurantId].position
            -- Add blip or prop visualization
        end
    end
end

-- Update container quality visualization
local function updateContainerQualityDisplay(containerId, quality)
    -- Update any visual indicators for container quality
    local qualityColor = quality >= 80 and "green" or (quality >= 50 and "yellow" or "red")
    
    -- Update UI elements if container menu is open
    if currentContainerMenu and currentContainerMenu.containerId == containerId then
        -- Refresh container display
        TriggerEvent('containers:refreshDisplay')
    end
end

-- ============================================
-- CONTAINER INTERACTION SYSTEM
-- ============================================

-- Open container management menu
local function openContainerMenu()
    if not hasContainerAccess() then
        lib.notify({
            title = '🚫 Access Denied',
            description = 'Container system access restricted to warehouse and restaurant staff',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local jobAccess = getPlayerJobAccess()
    local restaurantId = getPlayerRestaurantId()
    
    local options = {
        {
            title = "📦 View My Containers",
            description = "Check containers assigned to your location",
            icon = "fas fa-boxes",
            onSelect = function()
                if jobAccess == "warehouse" then
                    TriggerEvent('containers:viewWarehouseContainers')
                elseif jobAccess == "restaurant" and restaurantId then
                    TriggerServerEvent('containers:getRestaurantContainers', restaurantId)
                else
                    lib.notify({
                        title = 'No Location',
                        description = 'Unable to determine your work location',
                        type = 'error',
                        duration = 5000,
                        position = Config.UI and Config.UI.notificationPosition or "top",
                        markdown = Config.UI and Config.UI.enableMarkdown or false
                    })
                end
            end
        },
        {
            title = "🔍 Container Quality Check",
            description = "Inspect container quality and condition",
            icon = "fas fa-search",
            onSelect = function()
                TriggerEvent('containers:openQualityCheck')
            end
        },
        {
            title = "📊 Container Statistics",
            description = "View container usage and performance stats",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerEvent('containers:viewStatistics')
            end
        }
    }
    
    -- Add warehouse-specific options
    if jobAccess == "warehouse" then
        table.insert(options, {
            title = "🚛 Load Delivery Vehicle",
            description = "Load containers into delivery vehicle",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerEvent('containers:loadDeliveryVehicle')
            end
        })
        
        table.insert(options, {
            title = "📋 Container Inventory",
            description = "Manage container stock and reorder",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerEvent('containers:manageInventory')
            end
        })
    end
    
    lib.registerContext({
        id = "container_main_menu",
        title = "📦 Container Management",
        options = options
    })
    lib.showContext("container_main_menu")
end

-- View warehouse containers
RegisterNetEvent('containers:viewWarehouseContainers')
AddEventHandler('containers:viewWarehouseContainers', function()
    TriggerServerEvent('containers:getWarehouseContainers')
end)

-- Show warehouse containers
RegisterNetEvent('containers:showWarehouseContainers')
AddEventHandler('containers:showWarehouseContainers', function(containers)
    local options = {
        {
            title = "← Back to Container Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openContainerMenu()
            end
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "📭 No Containers",
            description = "No containers currently in warehouse",
            disabled = true
        })
    else
        -- Group containers by status
        local groupedContainers = {}
        for _, container in ipairs(containers) do
            local status = container.status
            if not groupedContainers[status] then
                groupedContainers[status] = {}
            end
            table.insert(groupedContainers[status], container)
        end
        
        -- Display containers by status
        for status, statusContainers in pairs(groupedContainers) do
            local statusIcon = status == "filled" and "✅" or (status == "loaded" and "🚛" or "📦")
            table.insert(options, {
                title = string.format("── %s %s Containers ──", statusIcon, status:gsub("^%l", string.upper)),
                description = #statusContainers .. " containers",
                disabled = true
            })
            
            for _, container in ipairs(statusContainers) do
                local typeInfo = getContainerTypeInfo(container.container_type)
                local itemLabel = getItemLabel(container.contents_item)
                local ageText = formatTime(container.filled_timestamp)
                
                table.insert(options, {
                    title = string.format("%s %s", typeInfo.icon, container.container_id),
                    description = string.format("%d x %s\nAge: %s | Quality: %s", 
                        container.contents_amount, itemLabel, ageText, formatQuality(container.quality_level)),
                    metadata = {
                        ["Container ID"] = container.container_id,
                        ["Type"] = typeInfo.name,
                        ["Contents"] = container.contents_amount .. " x " .. itemLabel,
                        ["Quality"] = formatQuality(container.quality_level),
                        ["Age"] = ageText,
                        ["Status"] = status:gsub("^%l", string.upper)
                    },
                    onSelect = function()
                        TriggerEvent('containers:inspectContainer', container)
                    end
                })
            end
        end
    end
    
    lib.registerContext({
        id = "warehouse_containers",
        title = "🏭 Warehouse Containers",
        options = options
    })
    lib.showContext("warehouse_containers")
end)

-- Show restaurant containers
RegisterNetEvent('containers:showRestaurantContainers')
AddEventHandler('containers:showRestaurantContainers', function(containers)
    local options = {
        {
            title = "← Back to Container Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openContainerMenu()
            end
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "📭 No Deliveries",
            description = "No container deliveries received yet",
            disabled = true
        })
        
        table.insert(options, {
            title = "💡 How to Get Containers",
            description = "Place ingredient orders through the restaurant menu to receive container deliveries",
            disabled = true
        })
    else
        -- Sort containers by delivery time (most recent first)
        table.sort(containers, function(a, b)
            return (a.delivered_timestamp or 0) > (b.delivered_timestamp or 0)
        end)
        
        for _, container in ipairs(containers) do
            local typeInfo = getContainerTypeInfo(container.container_type)
            local itemLabel = getItemLabel(container.contents_item)
            local deliveryAge = formatTime(container.delivered_timestamp or container.filled_timestamp)
            
            table.insert(options, {
                title = string.format("%s %s", typeInfo.icon, container.container_id),
                description = string.format("%d x %s\nDelivered: %s ago | Quality: %s", 
                    container.contents_amount, itemLabel, deliveryAge, formatQuality(container.quality_level)),
                metadata = {
                    ["Container ID"] = container.container_id,
                    ["Type"] = typeInfo.name,
                    ["Contents"] = container.contents_amount .. " x " .. itemLabel,
                    ["Quality"] = formatQuality(container.quality_level),
                    ["Delivered"] = deliveryAge .. " ago",
                    ["Expiration"] = container.expiration_timestamp and formatTime(container.expiration_timestamp) or "N/A"
                },
                onSelect = function()
                    TriggerEvent('containers:inspectContainer', container)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_containers",
        title = "🏪 Restaurant Containers",
        options = options
    })
    lib.showContext("restaurant_containers")
end)

-- Inspect individual container
RegisterNetEvent('containers:inspectContainer')
AddEventHandler('containers:inspectContainer', function(container)
    local typeInfo = getContainerTypeInfo(container.container_type)
    local itemLabel = getItemLabel(container.contents_item)
    local currentTime = GetGameTimer()
    
    -- Calculate container age and expiration
    local age = formatTime(container.filled_timestamp)
    local expirationText = "Unknown"
    if container.expiration_timestamp then
        local timeToExpiration = container.expiration_timestamp - currentTime
        if timeToExpiration > 0 then
            expirationText = "Expires in " .. formatTime(timeToExpiration)
        else
            expirationText = "⚠️ EXPIRED " .. formatTime(math.abs(timeToExpiration)) .. " ago"
        end
    end
    
    local options = {
        {
            title = "← Back to Containers",
            icon = "fas fa-arrow-left",
            onSelect = function()
                local jobAccess = getPlayerJobAccess()
                if jobAccess == "warehouse" then
                    TriggerEvent('containers:viewWarehouseContainers')
                else
                    local restaurantId = getPlayerRestaurantId()
                    if restaurantId then
                        TriggerServerEvent('containers:getRestaurantContainers', restaurantId)
                    end
                end
            end
        },
        {
            title = "📋 Container Details",
            description = string.format("ID: %s\nType: %s\nContents: %d x %s", 
                container.container_id, typeInfo.name, container.contents_amount, itemLabel),
            disabled = true
        },
        {
            title = "🔍 Quality Information",
            description = string.format("Current Quality: %s\nAge: %s\n%s", 
                formatQuality(container.quality_level), age, expirationText),
            disabled = true
        }
    }
    
    -- Add action options based on container status and player access
    local jobAccess = getPlayerJobAccess()
    
    if container.status == "delivered" and jobAccess == "restaurant" then
        table.insert(options, {
            title = "📤 Unpack Container",
            description = "Remove items from container and add to restaurant inventory",
            icon = "fas fa-box-open",
            onSelect = function()
                TriggerEvent('containers:unpackContainer', container)
            end
        })
    end
    
    if jobAccess == "warehouse" then
        table.insert(options, {
            title = "🔧 Quality Check",
            description = "Perform detailed quality inspection",
            icon = "fas fa-clipboard-check",
            onSelect = function()
                TriggerServerEvent('containers:performQualityCheck', container.container_id)
            end
        })
        
        if container.status == "filled" then
            table.insert(options, {
                title = "🚛 Load for Delivery",
                description = "Load this container into delivery vehicle",
                icon = "fas fa-truck-loading",
                onSelect = function()
                    TriggerServerEvent('containers:loadSingleContainer', container.container_id)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "container_inspect",
        title = string.format("%s Container %s", typeInfo.icon, container.container_id),
        options = options
    })
    lib.showContext("container_inspect")
end)

-- ============================================
-- CONTAINER ACTIONS
-- ============================================

-- Unpack container (restaurant action)
RegisterNetEvent('containers:unpackContainer')
AddEventHandler('containers:unpackContainer', function(container)
    lib.alertDialog({
        header = '📤 Unpack Container',
        content = string.format(
            'Unpack **%d x %s** from container?\n\nThis will add the items to your restaurant inventory and mark the container as empty.',
            container.contents_amount,
            getItemLabel(container.contents_item)
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = "Unpack Items",
            cancel = "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            TriggerServerEvent('containers:unpackContainer', container.container_id)
        end
    end)
end)

-- Container unpacked notification
RegisterNetEvent('containers:containerUnpacked')
AddEventHandler('containers:containerUnpacked', function(success, message, items)
    if success then
        lib.notify({
            title = '📤 Container Unpacked',
            description = message or 'Items successfully added to restaurant inventory',
            type = 'success',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    else
        lib.notify({
            title = '❌ Unpacking Failed',
            description = message or 'Failed to unpack container',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    end
end)

-- ============================================
-- QUALITY MONITORING SYSTEM
-- ============================================

-- Start quality monitoring thread
local function startQualityMonitoring()
    if qualityUpdateThread.active then return end
    
    qualityUpdateThread.active = true
    
    Citizen.CreateThread(function()
        while qualityUpdateThread.active do
            -- Check for container quality updates
            if hasContainerAccess() then
                local jobAccess = getPlayerJobAccess()
                if jobAccess == "warehouse" then
                    TriggerServerEvent('containers:getQualityUpdates', 'warehouse')
                elseif jobAccess == "restaurant" then
                    local restaurantId = getPlayerRestaurantId()
                    if restaurantId then
                        TriggerServerEvent('containers:getQualityUpdates', 'restaurant', restaurantId)
                    end
                end
            end
            
            Citizen.Wait(30000) -- Check every 30 seconds
        end
    end)
end

-- Stop quality monitoring
local function stopQualityMonitoring()
    qualityUpdateThread.active = false
end

-- Handle quality updates
RegisterNetEvent('containers:qualityUpdate')
AddEventHandler('containers:qualityUpdate', function(containerId, oldQuality, newQuality, degradationFactor)
    -- Update local container data if we have it
    for _, container in ipairs(playerContainers) do
        if container.container_id == containerId then
            container.quality_level = newQuality
            break
        end
    end
    
    -- Show notification for significant quality changes
    local qualityDrop = oldQuality - newQuality
    if qualityDrop > 10 then -- More than 10% quality drop
        local degradationReasons = {
            ["time_aging"] = "natural aging",
            ["transport"] = "rough handling during transport",
            ["temperature_breach"] = "temperature control failure"
        }
        
        lib.notify({
            title = '⚠️ Container Quality Alert',
            description = string.format('Container %s quality dropped to %.1f%% due to %s', 
                containerId, newQuality, degradationReasons[degradationFactor] or "unknown factors"),
            type = newQuality < 30 and 'error' or 'warning',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    end
    
    -- Update visualization
    updateContainerQualityDisplay(containerId, newQuality)
end)

-- ============================================
-- CONTAINER ORDERING INTEGRATION
-- ============================================

-- Enhanced order system with container selection
RegisterNetEvent('containers:showOrderWithContainers')
AddEventHandler('containers:showOrderWithContainers', function(availableItems)
    local restaurantId = getPlayerRestaurantId()
    if not restaurantId then
        lib.notify({
            title = 'No Restaurant Access',
            description = 'You must be employed at a restaurant to place orders',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local orderItems = {}
    
    -- Create order interface with container information
    local input = lib.inputDialog('📦 Order with Containers', {
        {
            type = 'select',
            label = 'Select Item',
            description = 'Choose ingredient to order',
            options = availableItems,
            required = true
        },
        {
            type = 'number',
            label = 'Quantity',
            description = 'Number of items to order',
            min = 1,
            max = 100,
            required = true
        }
    })
    
    if input then
        local selectedItem = input[1]
        local quantity = input[2]
        
        table.insert(orderItems, {
            ingredient = selectedItem,
            quantity = quantity
        })
        
        -- Calculate container requirements
        local containersNeeded = math.ceil(quantity / 12) -- 12 items per container
        local containerCost = containersNeeded * 15 -- $15 per container
        
        lib.alertDialog({
            header = '📦 Confirm Container Order',
            content = string.format(
                '**Order Summary:**\n• Item: %s\n• Quantity: %d\n• Containers Required: %d\n• Container Cost: $%d\n\nProceed with order?',
                getItemLabel(selectedItem),
                quantity,
                containersNeeded,
                containerCost
            ),
            centered = true,
            cancel = true,
            labels = {
                confirm = "Place Order",
                cancel = "Cancel"
            }
        }):next(function(confirmed)
            if confirmed then
                TriggerServerEvent('restaurant:orderIngredientsWithContainers', orderItems, restaurantId)
            end
        end)
    end
end)

-- ============================================
-- UI AND NOTIFICATIONS
-- ============================================

-- Container alert notification
RegisterNetEvent('containers:showAlert')
AddEventHandler('containers:showAlert', function(alertType, message, containerId)
    local alertTypes = {
        ["quality_critical"] = {icon = "🚨", type = "error", title = "Critical Quality Alert"},
        ["quality_warning"] = {icon = "⚠️", type = "warning", title = "Quality Warning"},
        ["expiration_near"] = {icon = "⏰", type = "warning", title = "Expiration Warning"},
        ["delivery_complete"] = {icon = "✅", type = "success", title = "Delivery Complete"}
    }
    
    local alert = alertTypes[alertType] or {icon = "📦", type = "info", title = "Container Alert"}
    
    lib.notify({
        title = alert.icon .. " " .. alert.title,
        description = message .. (containerId and ("\nContainer: " .. containerId) or ""),
        type = alert.type,
        duration = 12000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end)

-- ============================================
-- INITIALIZATION AND CLEANUP
-- ============================================

-- Initialize container system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CONTAINERS] Client system initialized")
        
        -- Start quality monitoring if player has access
        if hasContainerAccess() then
            startQualityMonitoring()
        end
    end
end)

-- Handle job changes
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Restart quality monitoring with new job
    stopQualityMonitoring()
    
    if hasContainerAccess() then
        startQualityMonitoring()
    end
    
    -- Update current restaurant ID
    currentRestaurantId = getPlayerRestaurantId()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopQualityMonitoring()
    end
end)

-- ============================================
-- COMMANDS AND EXPORTS
-- ============================================

-- Container management command
RegisterCommand('containers', function()
    openContainerMenu()
end)

-- Container status command
RegisterCommand('containerstatus', function()
    local jobAccess = getPlayerJobAccess()
    local restaurantId = getPlayerRestaurantId()
    
    local statusText = string.format(
        "**Container System Status:**\n• Job Access: %s\n• Restaurant ID: %s\n• Monitoring: %s",
        jobAccess,
        restaurantId or "None",
        qualityUpdateThread.active and "Active" or "Inactive"
    )
    
    lib.alertDialog({
        header = '📦 Container Status',
        content = statusText,
        centered = true,
        cancel = true
    })
end)

-- Export functions for other scripts
exports('openContainerMenu', openContainerMenu)
exports('getPlayerRestaurantId', getPlayerRestaurantId)
exports('hasContainerAccess', hasContainerAccess)

print("[CONTAINERS] Client interface loaded")