-- ============================================
-- DYNAMIC CONTAINER SYSTEM - SERVER LOGIC
-- The most advanced container management system in FiveM
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Container state management
local activeContainers = {}
local containerInventory = {}
local qualityDegradationThread = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Generate unique container ID
local function generateContainerId(containerType)
    local prefix = Config.DynamicContainers.system.containerIdPrefix
    local timestamp = GetGameTimer()
    local random = math.random(1000, 9999)
    return string.format("%s%s_%d_%d", prefix, containerType:upper(), timestamp, random)
end

-- Get current game time (using GetGameTimer for consistency)
local function getCurrentTime()
    return GetGameTimer()
end

-- Calculate expiration time based on container type and contents
local function calculateExpirationTime(containerType, ingredient)
    local baseExpiration = 24 * 60 * 60 * 1000 -- 24 hours in milliseconds
    local containerConfig = Config.DynamicContainers.containerTypes[containerType]
    
    if containerConfig and containerConfig.preservationMultiplier then
        baseExpiration = baseExpiration * containerConfig.preservationMultiplier
    end
    
    -- Special cases for specific ingredients
    local expirationMultipliers = {
        ["slaughter_meat"] = 0.5,           -- Meat expires faster
        ["milk"] = 0.6,                     -- Dairy needs refrigeration
        ["fresh_lettuce"] = 0.4,            -- Fresh produce spoils quickly
        ["flour"] = 5.0,                    -- Dry goods last longer
        ["frozen_beef"] = 10.0              -- Frozen items last much longer
    }
    
    local multiplier = expirationMultipliers[ingredient] or 1.0
    return getCurrentTime() + (baseExpiration * multiplier)
end

-- Determine optimal container type for ingredient
local function determineOptimalContainer(ingredient, quantity)
    local containerTypes = Config.DynamicContainers.containerTypes
    local bestContainer = nil
    local bestScore = 0
    
    for containerType, config in pairs(containerTypes) do
        local score = 0
        
        -- Check if ingredient is suitable for this container
        local isSuitable = false
        for _, suitableItem in ipairs(config.suitableItems or {}) do
            if ingredient:lower() == suitableItem:lower() then
                isSuitable = true
                score = score + 100 -- High score for exact match
                break
            end
        end
        
        -- Check category match if no exact item match
        if not isSuitable then
            local ingredientCategory = getIngredientCategory(ingredient)
            for _, category in ipairs(config.suitableCategories or {}) do
                if ingredientCategory == category then
                    isSuitable = true
                    score = score + 50 -- Medium score for category match
                    break
                end
            end
        end
        
        if isSuitable then
            -- Add preservation bonus to score
            score = score + (config.preservationMultiplier * 10)
            
            -- Subtract cost factor
            score = score - (config.cost * 0.5)
            
            -- Check availability
            local available = containerInventory[containerType] or 0
            if available > 0 then
                score = score + (available * 0.1)
            else
                score = 0 -- No containers available
            end
            
            if score > bestScore then
                bestScore = score
                bestContainer = containerType
            end
        end
    end
    
    return bestContainer or Config.DynamicContainers.autoSelection.fallbackContainer
end

-- Get ingredient category for container selection
local function getIngredientCategory(ingredient)
    local categoryMappings = {
        -- Meat products
        ["slaughter_meat"] = "meat",
        ["slaughter_ground_meat"] = "meat", 
        ["slaughter_chicken"] = "meat",
        ["slaughter_pork"] = "meat",
        ["slaughter_beef"] = "meat",
        
        -- Dairy products
        ["milk"] = "dairy",
        ["cheese"] = "dairy",
        ["butter"] = "dairy",
        
        -- Vegetables
        ["tomato"] = "vegetables",
        ["lettuce"] = "vegetables",
        ["onion"] = "vegetables",
        ["potato"] = "vegetables",
        
        -- Fruits
        ["apple"] = "fruits",
        ["orange"] = "fruits",
        ["banana"] = "fruits",
        
        -- Frozen items
        ["frozen_beef"] = "frozen",
        ["frozen_chicken"] = "frozen",
        ["ice_cream"] = "frozen",
        
        -- Dry goods
        ["flour"] = "dry_goods",
        ["sugar"] = "dry_goods",
        ["rice"] = "dry_goods"
    }
    
    return categoryMappings[ingredient:lower()] or "dry_goods"
end

-- Load container inventory from database
local function loadContainerInventory()
    MySQL.Async.fetchAll('SELECT container_type, available_quantity FROM supply_container_inventory', {}, function(results)
        containerInventory = {}
        for _, row in ipairs(results or {}) do
            containerInventory[row.container_type] = row.available_quantity
        end
        print("[CONTAINERS] Loaded container inventory: " .. json.encode(containerInventory))
    end)
end

-- Update container quality based on degradation factors
local function updateContainerQuality(containerId, degradationFactor)
    MySQL.Async.fetchAll('SELECT quality_level, container_type FROM supply_containers WHERE container_id = ?', 
        {containerId}, function(results)
        
        if results and results[1] then
            local currentQuality = results[1].quality_level
            local containerType = results[1].container_type
            local config = Config.DynamicContainers.containerTypes[containerType]
            
            -- Calculate quality retention rate
            local baseRetention = config and config.qualityRetention or 0.90
            local degradationRate = Config.DynamicContainers.qualityManagement.degradationFactors[degradationFactor]
            
            if degradationRate then
                local newQuality = math.max(0, currentQuality - (currentQuality * degradationRate.rate))
                
                MySQL.Async.execute([[
                    UPDATE supply_containers 
                    SET quality_level = ?, updated_at = CURRENT_TIMESTAMP 
                    WHERE container_id = ?
                ]], {newQuality, containerId}, function(success)
                    if success then
                        -- Log quality change
                        MySQL.Async.execute([[
                            INSERT INTO supply_container_quality_log 
                            (container_id, quality_check_timestamp, quality_before, quality_after, degradation_factor, notes)
                            VALUES (?, ?, ?, ?, ?, ?)
                        ]], {
                            containerId, getCurrentTime(), currentQuality, newQuality, 
                            degradationFactor, "Automated quality update"
                        })
                        
                        -- Check for quality alerts
                        checkQualityAlerts(containerId, newQuality)
                    end
                end)
            end
        end
    end)
end

-- Check and create quality alerts if needed
local function checkQualityAlerts(containerId, quality)
    local alerts = Config.DynamicContainers.qualityManagement.alerts
    
    if quality <= alerts.criticalThreshold then
        createContainerAlert(containerId, 'quality_critical', 'critical', 
            string.format('Container quality critically low: %.1f%%', quality))
    elseif quality <= alerts.warningThreshold then
        createContainerAlert(containerId, 'degraded', 'warning',
            string.format('Container quality degraded: %.1f%%', quality))
    end
end

-- Create container alert
local function createContainerAlert(containerId, alertType, alertLevel, message)
    MySQL.Async.execute([[
        INSERT INTO supply_container_alerts 
        (container_id, alert_type, alert_level, message, created_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {containerId, alertType, alertLevel, message})
    
    -- Send notifications to relevant players
    notifyContainerAlert(containerId, alertType, alertLevel, message)
end

-- Notify players about container alerts
local function notifyContainerAlert(containerId, alertType, alertLevel, message)
    -- Get container details for context
    MySQL.Async.fetchAll([[
        SELECT c.*, r.name as restaurant_name
        FROM supply_containers c
        LEFT JOIN (
            SELECT 1 as restaurant_id, 'Burger Shot' as name UNION ALL
            SELECT 2 as restaurant_id, 'Pizza This' as name UNION ALL
            SELECT 3 as restaurant_id, 'Taco Bomb' as name
        ) r ON c.restaurant_id = r.restaurant_id
        WHERE c.container_id = ?
    ]], {containerId}, function(results)
        
        if results and results[1] then
            local container = results[1]
            local players = QBCore.Functions.GetPlayers()
            
            for _, playerId in ipairs(players) do
                local xPlayer = QBCore.Functions.GetPlayer(playerId)
                if xPlayer then
                    local playerJob = xPlayer.PlayerData.job.name
                    
                    -- Notify warehouse workers and restaurant owners
                    if playerJob == "warehouse" or 
                       (container.restaurant_id and Config.Restaurants[container.restaurant_id] and 
                        Config.Restaurants[container.restaurant_id].job == playerJob) then
                        
                        local notificationType = alertLevel == 'critical' and 'error' or 'warning'
                        
                        TriggerClientEvent('ox_lib:notify', playerId, {
                            title = '📦 Container Alert',
                            description = string.format('**%s**\n🏪 %s\n📦 %s (%s)', 
                                message, 
                                container.restaurant_name or "Unknown",
                                container.contents_item,
                                container.container_type),
                            type = notificationType,
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            end
        end
    end)
end

-- ============================================
-- CONTAINER CREATION SYSTEM
-- ============================================

-- Create container for order
local function createContainer(ingredient, quantity, orderGroupId, restaurantId)
    -- Ensure quantity doesn't exceed container limit
    quantity = math.min(quantity, Config.DynamicContainers.system.maxItemsPerContainer)
    
    -- Determine optimal container type
    local containerType = determineOptimalContainer(ingredient, quantity)
    
    -- Check container availability
    local available = containerInventory[containerType] or 0
    if available <= 0 then
        print("[CONTAINERS] No containers available of type: " .. containerType)
        return nil, "No containers available of type: " .. containerType
    end
    
    -- Generate container ID
    local containerId = generateContainerId(containerType)
    
    -- Calculate expiration time
    local expirationTime = calculateExpirationTime(containerType, ingredient)
    
    -- Create container in database
    MySQL.Async.execute([[
        INSERT INTO supply_containers (
            container_id, container_type, contents_item, contents_amount,
            order_group_id, restaurant_id, filled_timestamp, expiration_timestamp,
            status, current_location, quality_level, preservation_bonus, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        containerId,
        containerType,
        ingredient,
        quantity,
        orderGroupId,
        restaurantId,
        getCurrentTime(),
        expirationTime,
        'filled',
        'warehouse',
        100.0, -- Start with 100% quality
        Config.DynamicContainers.containerTypes[containerType].preservationMultiplier,
        json.encode({
            created_by = "dynamic_system",
            auto_selected = true,
            selection_reason = "optimal_match"
        })
    }, function(success)
        if success then
            -- Update container inventory
            containerInventory[containerType] = containerInventory[containerType] - 1
            MySQL.Async.execute(
                'UPDATE supply_container_inventory SET available_quantity = available_quantity - 1 WHERE container_type = ?',
                {containerType}
            )
            
            print(string.format("[CONTAINERS] Created container %s: %d x %s in %s", 
                containerId, quantity, ingredient, containerType))
        end
    end)
    
    return containerId, nil
end

-- ============================================
-- ORDER PROCESSING INTEGRATION
-- ============================================

-- Enhanced order processing with container creation
local function processOrderWithContainers(orderItems, orderGroupId, restaurantId)
    local containers = {}
    local totalCost = 0
    
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = orderItem.quantity
        
        -- Create containers for this ingredient (max 12 items per container)
        while quantity > 0 do
            local containerQuantity = math.min(quantity, Config.DynamicContainers.system.maxItemsPerContainer)
            
            local containerId, error = createContainer(ingredient, containerQuantity, orderGroupId, restaurantId)
            
            if containerId then
                table.insert(containers, {
                    containerId = containerId,
                    ingredient = ingredient,
                    quantity = containerQuantity,
                    containerType = determineOptimalContainer(ingredient, containerQuantity)
                })
                
                -- Add container cost
                local containerType = determineOptimalContainer(ingredient, containerQuantity)
                local containerConfig = Config.DynamicContainers.containerTypes[containerType]
                totalCost = totalCost + (containerConfig and containerConfig.cost or 15)
                
                quantity = quantity - containerQuantity
            else
                print("[CONTAINERS] Failed to create container: " .. (error or "Unknown error"))
                return nil, error
            end
        end
    end
    
    return containers, totalCost
end

-- ============================================
-- DELIVERY SYSTEM INTEGRATION
-- ============================================

-- Load containers into delivery vehicle
local function loadContainersIntoVehicle(orderGroupId)
    MySQL.Async.fetchAll('SELECT * FROM supply_containers WHERE order_group_id = ? AND status = ?', 
        {orderGroupId, 'filled'}, function(results)
        
        if results then
            local containerIds = {}
            for _, container in ipairs(results) do
                table.insert(containerIds, container.container_id)
                
                -- Update container status
                MySQL.Async.execute(
                    'UPDATE supply_containers SET status = ?, current_location = ? WHERE container_id = ?',
                    {'loaded', 'delivery_vehicle', container.container_id}
                )
            end
            
            -- Start quality monitoring for containers in transit
            for _, containerId in ipairs(containerIds) do
                startQualityMonitoring(containerId)
            end
            
            print(string.format("[CONTAINERS] Loaded %d containers for order %s", #containerIds, orderGroupId))
        end
    end)
end

-- Start quality monitoring for container
local function startQualityMonitoring(containerId)
    if qualityDegradationThread[containerId] then
        return -- Already monitoring
    end
    
    qualityDegradationThread[containerId] = true
    
    Citizen.CreateThread(function()
        while qualityDegradationThread[containerId] do
            -- Check container status
            MySQL.Async.fetchAll('SELECT status FROM supply_containers WHERE container_id = ?', 
                {containerId}, function(results)
                
                if results and results[1] and results[1].status == 'in_transit' then
                    -- Apply time-based degradation
                    updateContainerQuality(containerId, 'time_aging')
                    
                    -- Random chance of other degradation factors during transport
                    if math.random() < 0.1 then -- 10% chance
                        updateContainerQuality(containerId, 'transport')
                    end
                    
                    -- Very small chance of temperature breach
                    if math.random() < 0.02 then -- 2% chance
                        updateContainerQuality(containerId, 'temperature_breach')
                    end
                else
                    -- Stop monitoring if container is delivered
                    qualityDegradationThread[containerId] = nil
                end
            end)
            
            Citizen.Wait(60000) -- Check every minute
        end
    end)
end

-- ============================================
-- RESTAURANT DELIVERY INTEGRATION
-- ============================================

-- Complete container delivery to restaurant
local function completeContainerDelivery(orderGroupId, restaurantId)
    MySQL.Async.fetchAll('SELECT * FROM supply_containers WHERE order_group_id = ? AND status IN (?, ?)', 
        {orderGroupId, 'loaded', 'in_transit'}, function(results)
        
        if results then
            local deliveredContainers = {}
            
            for _, container in ipairs(results) do
                -- Update container status to delivered
                MySQL.Async.execute([[
                    UPDATE supply_containers 
                    SET status = ?, current_location = ?, delivered_timestamp = ? 
                    WHERE container_id = ?
                ]], {'delivered', 'restaurant_' .. restaurantId, getCurrentTime(), container.container_id})
                
                -- Stop quality monitoring
                qualityDegradationThread[container.container_id] = nil
                
                table.insert(deliveredContainers, container)
            end
            
            -- Notify restaurant about delivered containers
            notifyRestaurantDelivery(restaurantId, deliveredContainers)
            
            print(string.format("[CONTAINERS] Delivered %d containers to restaurant %d", 
                #deliveredContainers, restaurantId))
        end
    end)
end

-- Notify restaurant about container delivery
local function notifyRestaurantDelivery(restaurantId, containers)
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then return end
    
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer and xPlayer.PlayerData.job.name == restaurantJob then
            
            local containerSummary = {}
            for _, container in ipairs(containers) do
                local key = container.contents_item
                if not containerSummary[key] then
                    containerSummary[key] = { count = 0, quantity = 0, types = {} }
                end
                containerSummary[key].count = containerSummary[key].count + 1
                containerSummary[key].quantity = containerSummary[key].quantity + container.contents_amount
                
                if not containerSummary[key].types[container.container_type] then
                    containerSummary[key].types[container.container_type] = 0
                end
                containerSummary[key].types[container.container_type] = 
                    containerSummary[key].types[container.container_type] + 1
            end
            
            local description = "📦 **Container Delivery Arrived!**\n"
            for ingredient, summary in pairs(containerSummary) do
                local itemNames = exports.ox_inventory:Items() or {}
                local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
                description = description .. string.format("• %d containers of **%s** (%d total items)\n", 
                    summary.count, itemLabel, summary.quantity)
            end
            
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '🚛 Container Delivery',
                description = description .. "\nCheck your container storage area!",
                type = 'success',
                duration = 15000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Initialize container system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if Config.DynamicContainers.enabled then
            print("[CONTAINERS] Initializing Dynamic Container System...")
            
            -- Load container inventory
            loadContainerInventory()
            
            -- Start automatic reordering if enabled
            if Config.DynamicContainers.inventory.automaticReordering.enabled then
                Citizen.CreateThread(function()
                    while true do
                        Citizen.Wait(Config.DynamicContainers.inventory.automaticReordering.checkInterval * 1000)
                        checkAndReorderContainers()
                    end
                end)
            end
            
            print("[CONTAINERS] Dynamic Container System initialized successfully!")
        else
            print("[CONTAINERS] Dynamic Container System is disabled in config")
        end
    end
end)

-- Enhanced restaurant order processing
RegisterNetEvent('restaurant:orderIngredientsWithContainers')
AddEventHandler('restaurant:orderIngredientsWithContainers', function(orderItems, restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Process order with container creation
    local orderGroupId = "container_" .. getCurrentTime() .. "_" .. math.random(1000, 9999)
    
    local containers, containerCost = processOrderWithContainers(orderItems, orderGroupId, restaurantId)
    
    if containers then
        -- Calculate total cost including containers
        local baseCost = 0
        for _, orderItem in ipairs(orderItems) do
            local restaurantJob = Config.Restaurants[restaurantId].job
            local price = getItemPrice(restaurantJob, orderItem.ingredient)
            baseCost = baseCost + (price * orderItem.quantity)
        end
        
        local totalCost = baseCost + containerCost
        
        -- Check if player can afford it
        if xPlayer.PlayerData.money.bank >= totalCost then
            xPlayer.Functions.RemoveMoney('bank', totalCost, "Container order with ingredients")
            
            -- Create orders in database
            for _, orderItem in ipairs(orderItems) do
                MySQL.Async.execute([[
                    INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]], {
                    src, orderItem.ingredient, orderItem.quantity, 'pending', 
                    restaurantId, (getItemPrice(Config.Restaurants[restaurantId].job, orderItem.ingredient) * orderItem.quantity),
                    orderGroupId
                })
            end
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📦 Container Order Placed',
                description = string.format('**%d containers** created for your order\n💰 Total: $%d (includes $%d for containers)', 
                    #containers, totalCost, containerCost),
                type = 'success',
                duration = 12000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Insufficient Funds',
                description = string.format('Need $%d (includes $%d for containers)', totalCost, containerCost),
                type = 'error',
                duration = 8000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Container Error',
            description = containerCost or "Failed to create containers for order",
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- Container delivery completion
RegisterNetEvent('containers:completeDelivery')
AddEventHandler('containers:completeDelivery', function(orderGroupId, restaurantId)
    completeContainerDelivery(orderGroupId, restaurantId)
end)

-- Get container info for restaurant
RegisterNetEvent('containers:getRestaurantContainers')
AddEventHandler('containers:getRestaurantContainers', function(restaurantId)
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT c.*, ci.preservation_multiplier, ci.temperature_controlled
        FROM supply_containers c
        JOIN supply_container_inventory ci ON c.container_type = ci.container_type
        WHERE c.restaurant_id = ? AND c.status = 'delivered'
        ORDER BY c.delivered_timestamp DESC
    ]], {restaurantId}, function(results)
        
        TriggerClientEvent('containers:showRestaurantContainers', src, results or {})
    end)
end)

-- ============================================
-- UTILITY FUNCTIONS FOR INTEGRATION
-- ============================================

-- Get item price from existing config
local function getItemPrice(restaurantJob, ingredient)
    if Config.Items and Config.Items[restaurantJob] then
        for category, items in pairs(Config.Items[restaurantJob]) do
            if items[ingredient] then
                return items[ingredient].price or 10
            end
        end
    end
    return 10 -- Default price
end

-- Check and reorder containers automatically
local function checkAndReorderContainers()
    local reorderThresholds = Config.DynamicContainers.inventory.reorderThresholds
    local reorderQuantities = Config.DynamicContainers.inventory.reorderQuantities
    local maxCost = Config.DynamicContainers.inventory.automaticReordering.maxCostPerReorder
    
    for containerType, threshold in pairs(reorderThresholds) do
        local available = containerInventory[containerType] or 0
        
        if available <= threshold then
            local reorderQty = reorderQuantities[containerType] or 50
            local containerConfig = Config.DynamicContainers.containerTypes[containerType]
            local totalCost = reorderQty * (containerConfig and containerConfig.cost or 15)
            
            if totalCost <= maxCost then
                -- Automatic reorder
                MySQL.Async.execute([[
                    UPDATE supply_container_inventory 
                    SET available_quantity = available_quantity + ?, last_restocked = CURRENT_TIMESTAMP 
                    WHERE container_type = ?
                ]], {reorderQty, containerType})
                
                containerInventory[containerType] = available + reorderQty
                
                print(string.format("[CONTAINERS] Auto-reordered %d containers of type %s for $%d", 
                    reorderQty, containerType, totalCost))
            end
        end
    end
end

-- Export functions for other scripts
exports('createContainer', createContainer)
exports('loadContainersIntoVehicle', loadContainersIntoVehicle)
exports('completeContainerDelivery', completeContainerDelivery)
exports('updateContainerQuality', updateContainerQuality)
exports('getContainerInventory', function() return containerInventory end)