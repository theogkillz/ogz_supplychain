-- ============================================
-- CONTAINER DYNAMIC SYSTEM - SERVER LOGIC  
-- ============================================

-- FiveM Global Declarations
local exports = exports
local QBCore = exports['qb-core']:GetCoreObject()

-- Wait for QBCore to be ready
local function waitForQBCore()
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Citizen.Wait(100)
    end
end

Citizen.CreateThread(function()
    waitForQBCore()
end)

-- Validation function
local function validatePlayerAccess(source, requiredJob)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == (requiredJob or "hurst"), playerJob
end

-- Container state management
local activeContainers = {}
local containerInventory = {}
local qualityDegradationThread = {}

-- ============================================
-- FORWARD DECLARATIONS (FIXES SCOPE ISSUES)
-- ============================================

local createContainerAlert
local notifyContainerAlert
local checkQualityAlerts
local getIngredientCategory
local startQualityMonitoring
local notifyRestaurantDelivery
local checkAndReorderContainers
local getItemPrice

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Generate unique container ID
local function generateContainerId(containerType)
    local prefix = "CONT_"
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

-- Get ingredient category for container selection
getIngredientCategory = function(ingredient)
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
        ["ogz_milk_cow"] = "dairy",
        ["ogz_cheese_block"] = "dairy",
        ["ogz_butter_fresh"] = "dairy",
        
        -- Vegetables
        ["tomato"] = "vegetables",
        ["lettuce"] = "vegetables",
        ["onion"] = "vegetables",
        ["potato"] = "vegetables",
        ["ogz_tomato"] = "vegetables",
        ["ogz_onion"] = "vegetables",
        ["ogz_potato"] = "vegetables",
        
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
        ["rice"] = "dry_goods",
        ["ogz_wheat_plant"] = "dry_goods",
        ["ogz_flour_basic"] = "dry_goods"
    }
    
    return categoryMappings[ingredient:lower()] or "dry_goods"
end

-- Determine optimal container type for ingredient
local function determineOptimalContainer(ingredient, quantity)
    -- Simple fallback container selection
    local category = getIngredientCategory(ingredient)
    
    local containerMap = {
        ["meat"] = "refrigerated",
        ["dairy"] = "refrigerated", 
        ["frozen"] = "freezer",
        ["vegetables"] = "standard",
        ["fruits"] = "standard",
        ["dry_goods"] = "standard"
    }
    
    local containerType = containerMap[category] or "standard"
    
    -- Check if we have containers available
    local available = containerInventory[containerType] or 0
    if available <= 0 then
        containerType = "standard" -- Fallback to standard
    end
    
    return containerType
end

-- Load container inventory from database
local function loadContainerInventory()
    -- Initialize with default inventory if database doesn't exist
    containerInventory = {
        ["standard"] = 100,
        ["refrigerated"] = 50,
        ["freezer"] = 25,
        ["insulated"] = 30
    }
    
    -- Try to load from database
    MySQL.Async.fetchAll('SELECT container_type, available_quantity FROM supply_container_inventory', {}, function(results)
        if results and #results > 0 then
            containerInventory = {}
            for _, row in ipairs(results) do
                containerInventory[row.container_type] = row.available_quantity
            end
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
            
            -- Simple degradation calculation
            local degradationRates = {
                ["time_aging"] = 0.01,      -- 1% per check
                ["transport"] = 0.05,       -- 5% for rough transport
                ["temperature_breach"] = 0.15 -- 15% for temperature issues
            }
            
            local degradationRate = degradationRates[degradationFactor] or 0.01
            local newQuality = math.max(0, currentQuality - (currentQuality * degradationRate))
            
            MySQL.Async.execute([[
                UPDATE supply_containers 
                SET quality_level = ?, updated_at = CURRENT_TIMESTAMP 
                WHERE container_id = ?
            ]], {newQuality, containerId}, function(success)
                if success then
                    -- Check for quality alerts
                    checkQualityAlerts(containerId, newQuality)
                end
            end)
        end
    end)
end

-- ============================================
-- ALERT SYSTEM FUNCTIONS
-- ============================================

-- Check and create quality alerts if needed
checkQualityAlerts = function(containerId, quality)
    if quality <= 30 then
        createContainerAlert(containerId, "critical", "Container quality critically low!")
        return "critical"
    elseif quality <= 50 then
        createContainerAlert(containerId, "warning", "Container quality degrading")
        return "warning"
    end
    return "good"
end

-- Create container alert - FIXED PARAMETERS
createContainerAlert = function(containerId, alertType, message)
    local alertData = {
        containerId = containerId,
        alertType = alertType,
        message = message,
        timestamp = os.time(),
        acknowledged = false
    }
    
    -- Store alert in database
    MySQL.Async.execute([[
        INSERT INTO supply_container_alerts (container_id, alert_type, message, created_at)
        VALUES (?, ?, ?, ?)
    ]], {containerId, alertType, message, os.time()}, function(success)
        if success then
            -- Trigger real-time notification
            notifyContainerAlert(alertData)
        end
    end)
end

-- Notify players about container alerts
notifyContainerAlert = function(alertData)
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job.name == "hurst" then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '📦 Container Alert',
                description = alertData.message,
                type = alertData.alertType == "critical" and "error" or "warning",
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
    end
end

-- ============================================
-- CONTAINER CREATION SYSTEM
-- ============================================

-- Create container for order
local function createContainer(ingredient, quantity, orderGroupId, restaurantId)
    -- Ensure quantity doesn't exceed container limit
    quantity = math.min(quantity, 12) -- Max 12 items per container
    
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
        1.0,   -- Base preservation
        json.encode({
            created_by = "dynamic_system",
            auto_selected = true,
            selection_reason = "optimal_match"
        })
    }, function(success)
        if success then
            -- Update container inventory
            containerInventory[containerType] = containerInventory[containerType] - 1
            
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
            local containerQuantity = math.min(quantity, 12)
            
            local containerId, error = createContainer(ingredient, containerQuantity, orderGroupId, restaurantId)
            
            if containerId then
                table.insert(containers, {
                    containerId = containerId,
                    ingredient = ingredient,
                    quantity = containerQuantity,
                    containerType = determineOptimalContainer(ingredient, containerQuantity)
                })
                
                -- Add container cost (simple pricing)
                totalCost = totalCost + 15 -- $15 per container
                
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
                startQualityMonitoring(containerId, 100) -- Start with 100% quality
            end
            
            print(string.format("[CONTAINERS] Loaded %d containers for order %s", #containerIds, orderGroupId))
        end
    end)
end

-- Start quality monitoring for container - FIXED PARAMETERS
startQualityMonitoring = function(containerId, initialQuality)
    if qualityDegradationThread[containerId] then
        return -- Already monitoring
    end
    
    -- Initialize container monitoring
    MySQL.Async.execute([[
        INSERT INTO supply_container_quality (container_id, current_quality, start_quality, last_check)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            current_quality = VALUES(current_quality),
            last_check = VALUES(last_check)
    ]], {containerId, initialQuality or 100, initialQuality or 100, os.time()})
    
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
    
    print("[CONTAINERS] Started quality monitoring for container: " .. containerId)
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
            notifyRestaurantDelivery(restaurantId, "delivery", deliveredContainers)
            
            print(string.format("[CONTAINERS] Delivered %d containers to restaurant %d", 
                #deliveredContainers, restaurantId))
        end
    end)
end

-- Notify restaurant about container delivery - FIXED PARAMETERS
notifyRestaurantDelivery = function(restaurantId, containerId, items)
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job.name == "restaurant" then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '📦 Delivery Arrived',
                description = string.format('Container delivery completed with %d items', #items),
                type = 'success',
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
    end
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Get item price - FIXED TO SINGLE PARAMETER
getItemPrice = function(ingredient)
    -- Fallback prices
    local fallbackPrices = {
        ["slaughter_ground_meat"] = 25,
        ["butcher_ground_chicken"] = 20,
        ["ogz_milk_cow"] = 15,
        ["ogz_tomato"] = 10,
        ["ogz_onion"] = 8,
        ["ogz_potato"] = 12,
        ["ogz_wheat_plant"] = 18
    }
    
    return fallbackPrices[ingredient] or 20 -- Default price
end

-- Check and reorder containers automatically
checkAndReorderContainers = function()
    local reorderThreshold = 10
    local reorderQuantity = 50
    
    for containerType, available in pairs(containerInventory) do
        if available <= reorderThreshold then
            -- Automatic reorder
            containerInventory[containerType] = available + reorderQuantity
            
            MySQL.Async.execute([[
                UPDATE supply_container_inventory 
                SET available_quantity = available_quantity + ?, last_restocked = CURRENT_TIMESTAMP 
                WHERE container_type = ?
            ]], {reorderQuantity, containerType})
            
            print(string.format("[CONTAINERS] Auto-reordered %d containers of type %s", 
                reorderQuantity, containerType))
        end
    end
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Initialize container system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CONTAINERS] Initializing Dynamic Container System...")
        
        -- Load container inventory
        loadContainerInventory()
        
        -- Start automatic reordering
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(300000) -- Check every 5 minutes
                checkAndReorderContainers()
            end
        end)
        
        print("[CONTAINERS] Dynamic Container System initialized successfully!")
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
            local price = getItemPrice(orderItem.ingredient)
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
                    restaurantId, (getItemPrice(orderItem.ingredient) * orderItem.quantity),
                    orderGroupId
                })
            end
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📦 Container Order Placed',
                description = string.format('**%d containers** created for your order\n💰 Total: $%d (includes $%d for containers)', 
                    #containers, totalCost, containerCost),
                type = 'success',
                duration = 12000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Insufficient Funds',
                description = string.format('Need $%d (includes $%d for containers)', totalCost, containerCost),
                type = 'error',
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Container Error',
            description = containerCost or "Failed to create containers for order",
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
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
        SELECT c.*
        FROM supply_containers c
        WHERE c.restaurant_id = ? AND c.status = 'delivered'
        ORDER BY c.delivered_timestamp DESC
    ]], {restaurantId}, function(results)
        
        TriggerClientEvent('containers:showRestaurantContainers', src, results or {})
    end)
end)

-- Export functions for other scripts
exports('createContainer', createContainer)
exports('loadContainersIntoVehicle', loadContainersIntoVehicle)
exports('completeContainerDelivery', completeContainerDelivery)
exports('updateContainerQuality', updateContainerQuality)
exports('getContainerInventory', function() return containerInventory end)

print("[CONTAINERS] Server logic initialized")