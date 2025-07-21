-- ============================================
-- CONTAINER DYNAMIC SYSTEM - CORE LOGIC
-- Container state management and business logic
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()


-- ============================================
-- STATE MANAGEMENT
-- ============================================

-- Client state variables
local containerState = {
    nearbyContainers = {},
    playerContainers = {},
    currentRestaurantId = nil,
    currentContainerMenu = nil,
    isSystemActive = false
}

-- ============================================
-- PLAYER JOB & ACCESS MANAGEMENT
-- ============================================

-- Get player's restaurant ID based on job
local function getPlayerRestaurantId()
    local playerData = playerdata.job
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
    local playerData = playerdata.job
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

-- ============================================
-- CONTAINER TYPE & DISPLAY UTILITIES
-- ============================================

-- Get container type display information
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

-- ============================================
-- CONTAINER VISUALIZATION SYSTEM
-- ============================================

-- Create container visualization near player
local function createContainerVisualization(container)
    -- Create 3D props/markers for containers based on location
    
    if container.current_location == "warehouse" then
        -- Containers in warehouse - could add warehouse visualization
        local warehouseCoords = Config.Warehouses and Config.Warehouses[1] and Config.Warehouses[1].position
        if warehouseCoords then
            -- Add blip or prop visualization for warehouse containers
            containerState.nearbyContainers[container.container_id] = {
                coords = warehouseCoords,
                container = container
            }
        end
    elseif container.current_location:match("restaurant_") then
        -- Containers at restaurant
        local restaurantId = tonumber(container.current_location:match("restaurant_(%d+)"))
        if restaurantId and Config.Restaurants and Config.Restaurants[restaurantId] then
            local restaurantCoords = Config.Restaurants[restaurantId].position
            if restaurantCoords then
                -- Add container visualization at restaurant
                containerState.nearbyContainers[container.container_id] = {
                    coords = restaurantCoords,
                    container = container
                }
            end
        end
    end
end

-- Update container quality visualization
local function updateContainerQualityDisplay(containerId, quality)
    -- Update any visual indicators for container quality
    local qualityColor = quality >= 80 and "green" or (quality >= 50 and "yellow" or "red")
    
    -- Update UI elements if container menu is open
    if containerState.currentContainerMenu and containerState.currentContainerMenu.containerId == containerId then
        -- Refresh container display
        TriggerEvent('containers:refreshDisplay')
    end
    
    -- Update nearby container visualization
    if containerState.nearbyContainers[containerId] then
        containerState.nearbyContainers[containerId].container.quality_level = quality
        -- Update any 3D visualization here
    end
end

-- ============================================
-- CONTAINER DATA MANAGEMENT
-- ============================================

-- Update player containers data
local function updatePlayerContainers(containers)
    containerState.playerContainers = containers or {}
    
    -- Update visualizations for nearby containers
    for _, container in ipairs(containerState.playerContainers) do
        createContainerVisualization(container)
    end
end

-- Get container by ID from player containers
local function getContainerById(containerId)
    for _, container in ipairs(containerState.playerContainers) do
        if container.container_id == containerId then
            return container
        end
    end
    return nil
end

-- ============================================
-- CONTAINER ACTION BUILDERS
-- ============================================

-- Build container display option for menus
local function buildContainerDisplayOption(container, context)
    local typeInfo = getContainerTypeInfo(container.container_type)
    local itemLabel = getItemLabel(container.contents_item)
    local contextType = context or "warehouse"
    
    local timeText = ""
    if contextType == "restaurant" then
        local deliveryAge = formatTime(container.delivered_timestamp or container.filled_timestamp)
        timeText = "Delivered: " .. deliveryAge .. " ago"
    else
        local age = formatTime(container.filled_timestamp)
        timeText = "Age: " .. age
    end
    
    return {
        title = string.format("%s %s", typeInfo.icon, container.container_id),
        description = string.format("%d x %s\n%s | Quality: %s", 
            container.contents_amount, itemLabel, timeText, formatQuality(container.quality_level)),
        metadata = {
            ["Container ID"] = container.container_id,
            ["Type"] = typeInfo.name,
            ["Contents"] = container.contents_amount .. " x " .. itemLabel,
            ["Quality"] = formatQuality(container.quality_level),
            ["Age/Delivery"] = timeText,
            ["Status"] = container.status and container.status:gsub("^%l", string.upper) or "Unknown"
        }
    }
end

-- Build container action options based on context
local function buildContainerActionOptions(container)
    local options = {}
    local jobAccess = getPlayerJobAccess()
    
    -- Restaurant-specific actions
    if container.status == "delivered" and jobAccess == "restaurant" then
        table.insert(options, {
            title = "📤 Unpack Container",
            description = "Remove items from container and add to restaurant inventory",
            icon = "fas fa-box-open",
            onSelect = function()
                TriggerEvent('containers:showUnpackDialog', container)
            end
        })
    end
    
    -- Warehouse-specific actions
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
        
        if container.status == "empty" then
            table.insert(options, {
                title = "♻️ Recycle Container",
                description = "Clean and prepare container for reuse",
                icon = "fas fa-recycle",
                onSelect = function()
                    TriggerServerEvent('containers:recycleContainer', container.container_id)
                end
            })
        end
    end
    
    return options
end

-- ============================================
-- CONTAINER EVENT HANDLERS
-- ============================================

-- View warehouse containers
RegisterNetEvent('containers:viewWarehouseContainers')
AddEventHandler('containers:viewWarehouseContainers', function()
    TriggerServerEvent('containers:getWarehouseContainers')
end)

-- Handle container unpacking
RegisterNetEvent('containers:unpackContainer')
AddEventHandler('containers:unpackContainer', function(container)
    -- This event is now handled by the UI system but we maintain the logic here
    TriggerServerEvent('containers:unpackContainer', container.container_id)
end)

-- Handle quality check results
RegisterNetEvent('containers:qualityCheckResult')
AddEventHandler('containers:qualityCheckResult', function(containerId, qualityData)
    local container = getContainerById(containerId)
    if container then
        -- Update local container data
        container.quality_level = qualityData.current_quality
        
        -- Show detailed quality report
        local qualityReport = string.format(
            "**Quality Inspection Report**\n\n" ..
            "Container: %s\n" ..
            "Current Quality: %s\n" ..
            "Degradation Rate: %.2f%%/hour\n" ..
            "Estimated Expiration: %s\n" ..
            "Condition: %s",
            containerId,
            formatQuality(qualityData.current_quality),
            qualityData.degradation_rate or 0,
            qualityData.estimated_expiration or "Unknown",
            qualityData.condition or "Normal"
        )
        
        exports.ogz_supplychain:showInfo("🔧 Quality Check Results", qualityReport)
    end
end)

-- Handle container loading results
RegisterNetEvent('containers:containerLoaded')
AddEventHandler('containers:containerLoaded', function(containerId, vehicleId, success, message)
    if success then
        -- Update container status in local data
        local container = getContainerById(containerId)
        if container then
            container.status = "loaded"
        end
        
        exports.ogz_supplychain:successNotify(
            "Container Loaded",
            message or string.format("Container %s loaded into delivery vehicle", containerId)
        )
    else
        exports.ogz_supplychain:errorNotify(
            "Loading Failed",
            message or "Failed to load container into vehicle"
        )
    end
end)

-- ============================================
-- CONTAINER DELIVERY INTEGRATION
-- ============================================

-- Handle delivery vehicle loading
RegisterNetEvent('containers:loadDeliveryVehicle')
AddEventHandler('containers:loadDeliveryVehicle', function()
    -- Get available containers for loading
    TriggerServerEvent('containers:getAvailableForLoading')
end)

-- Show available containers for loading
RegisterNetEvent('containers:showAvailableForLoading')
AddEventHandler('containers:showAvailableForLoading', function(containers)
    if #containers == 0 then
        exports.ogz_supplychain:systemNotify(
            "No Containers",
            "No filled containers available for loading"
        )
        return
    end
    
    local options = {}
    
    for _, container in ipairs(containers) do
        local containerOption = buildContainerDisplayOption(container)
        containerOption.onSelect = function()
            TriggerServerEvent('containers:loadSingleContainer', container.container_id)
        end
        table.insert(options, containerOption)
    end
    
    lib.registerContext({
        id = "containers_for_loading",
        title = "🚛 Load Containers",
        options = options
    })
    lib.showContext("containers_for_loading")
end)

-- ============================================
-- CONTAINER INVENTORY MANAGEMENT
-- ============================================

-- Handle container inventory management
RegisterNetEvent('containers:manageInventory')
AddEventHandler('containers:manageInventory', function()
    TriggerServerEvent('containers:getInventoryData')
end)

-- Show container inventory data
RegisterNetEvent('containers:showInventoryData')
AddEventHandler('containers:showInventoryData', function(inventoryData)
    local options = {
        {
            title = "📊 Inventory Overview",
            description = string.format(
                "Total Containers: %d\nEmpty: %d | Filled: %d | In Transit: %d",
                inventoryData.total or 0,
                inventoryData.empty or 0,
                inventoryData.filled or 0,
                inventoryData.in_transit or 0
            ),
            disabled = true
        }
    }
    
    -- Add container type breakdown
    if inventoryData.by_type then
        table.insert(options, {
            title = "── Container Types ──",
            disabled = true
        })
        
        for containerType, count in pairs(inventoryData.by_type) do
            local typeInfo = getContainerTypeInfo(containerType)
            table.insert(options, {
                title = string.format("%s %s", typeInfo.icon, typeInfo.name),
                description = string.format("Available: %d containers", count),
                disabled = true
            })
        end
    end
    
    -- Add reorder options
    table.insert(options, {
        title = "📦 Reorder Containers",
        description = "Order new containers from supplier",
        icon = "fas fa-shopping-cart",
        onSelect = function()
            TriggerEvent('containers:showReorderMenu')
        end
    })
    
    lib.registerContext({
        id = "container_inventory",
        title = "📋 Container Inventory",
        options = options
    })
    lib.showContext("container_inventory")
end)

-- ============================================
-- JOB CHANGE HANDLING
-- ============================================

-- Handle job changes and update system state
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Update current restaurant ID
    containerState.currentRestaurantId = getPlayerRestaurantId()
    
    -- Clear container data if access changed
    if not hasContainerAccess() then
        containerState.playerContainers = {}
        containerState.nearbyContainers = {}
        containerState.isSystemActive = false
    else
        containerState.isSystemActive = true
        
        -- Trigger quality monitoring restart in quality system
        TriggerEvent('containers:jobChanged', JobInfo)
    end
end)

-- ============================================
-- SYSTEM INITIALIZATION
-- ============================================

-- Initialize container dynamic system
local function initializeContainerSystem()
    containerState.currentRestaurantId = getPlayerRestaurantId()
    containerState.isSystemActive = hasContainerAccess()
    
    if containerState.isSystemActive then
        print("[CONTAINERS] Dynamic system initialized - Access granted")
    else
        print("[CONTAINERS] Dynamic system initialized - No access")
    end
end

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        initializeContainerSystem()
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('getPlayerRestaurantId', getPlayerRestaurantId)
exports('getPlayerJobAccess', getPlayerJobAccess)
exports('hasContainerAccess', hasContainerAccess)
exports('getContainerTypeInfo', getContainerTypeInfo)
exports('getItemLabel', getItemLabel)
exports('formatTime', formatTime)
exports('formatQuality', formatQuality)
exports('buildContainerDisplayOption', buildContainerDisplayOption)
exports('buildContainerActionOptions', buildContainerActionOptions)
exports('getContainerById', getContainerById)
exports('updateContainerQualityDisplay', updateContainerQualityDisplay)
exports('getContainerState', function() return containerState end)

print("[CONTAINERS] Dynamic logic system loaded")