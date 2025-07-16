-- ============================================
-- MODULAR RESTAURANT CONTAINER INTEGRATION
-- sv_restaurant_containers.lua (NEW SEPARATE FILE)
-- This file enhances existing restaurant functionality with containers
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- CONTAINER-ENHANCED RESTAURANT FUNCTIONS
-- ============================================

-- Check if container system is enabled
local function isContainerSystemEnabled()
    return Config.DynamicContainers and Config.DynamicContainers.enabled
end

-- Calculate container costs for an order
local function calculateContainerCosts(orderItems, restaurantId)
    if not isContainerSystemEnabled() then
        return 0, {}
    end
    
    local totalContainerCost = 0
    local containerBreakdown = {}
    
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = orderItem.quantity
        
        -- Calculate containers needed (max 12 items per container, no mixing)
        local containersNeeded = math.ceil(quantity / Config.DynamicContainers.system.maxItemsPerContainer)
        
        -- Determine optimal container type
        local containerType = determineOptimalContainer(ingredient, quantity)
        local containerConfig = Config.DynamicContainers.containerTypes[containerType]
        local costPerContainer = containerConfig and containerConfig.cost or 15
        
        local ingredientContainerCost = costPerContainer * containersNeeded
        totalContainerCost = totalContainerCost + ingredientContainerCost
        
        table.insert(containerBreakdown, {
            ingredient = ingredient,
            quantity = quantity,
            containersNeeded = containersNeeded,
            containerType = containerType,
            costPerContainer = costPerContainer,
            totalCost = ingredientContainerCost,
            containerName = containerConfig and containerConfig.name or containerType
        })
    end
    
    return totalContainerCost, containerBreakdown
end

-- Determine optimal container type (same logic as warehouse)
local function determineOptimalContainer(ingredient, quantity)
    if not Config.DynamicContainers or not Config.DynamicContainers.containerTypes then
        return "ogz_crate"
    end
    
    -- Simple optimization logic for restaurant ordering
    local categoryMappings = {
        -- Meat products -> cooler
        ["slaughter_meat"] = "ogz_cooler", ["slaughter_ground_meat"] = "ogz_cooler",
        ["slaughter_chicken"] = "ogz_cooler", ["slaughter_pork"] = "ogz_cooler", ["slaughter_beef"] = "ogz_cooler",
        
        -- Dairy products -> cooler
        ["milk"] = "ogz_cooler", ["cheese"] = "ogz_cooler", ["butter"] = "ogz_cooler",
        
        -- Fresh produce -> produce containers
        ["lettuce"] = "ogz_produce", ["tomato"] = "ogz_produce", ["herbs"] = "ogz_produce",
        
        -- Frozen items -> freezer
        ["frozen_beef"] = "ogz_freezer", ["frozen_chicken"] = "ogz_freezer", ["ice_cream"] = "ogz_freezer",
        
        -- Dry goods -> crate
        ["flour"] = "ogz_crate", ["sugar"] = "ogz_crate", ["rice"] = "ogz_crate"
    }
    
    return categoryMappings[ingredient:lower()] or "ogz_crate"
end

-- Get dynamic price multiplier (from existing system)
local function getPriceMultiplier()
    local playerCount = #GetPlayers()
    local baseMultiplier = 1.0
    if Config.DynamicPricing and Config.DynamicPricing.enabled then
        if playerCount > Config.DynamicPricing.peakThreshold then
            baseMultiplier = baseMultiplier + 0.2
        elseif playerCount < Config.DynamicPricing.lowThreshold then
            baseMultiplier = baseMultiplier - 0.1
        end
        return math.max(Config.DynamicPricing.minMultiplier, math.min(Config.DynamicPricing.maxMultiplier, baseMultiplier))
    end
    return baseMultiplier
end

-- Generate unique order group ID
local function generateOrderGroupId()
    return "container_order_" .. GetGameTimer() .. "_" .. math.random(1000, 9999)
end

-- ============================================
-- EVENT HANDLERS FOR CONTAINER INTEGRATION
-- ============================================

-- Enhanced order submission with container options
RegisterNetEvent('restaurant:orderIngredientsWithContainers')
AddEventHandler('restaurant:orderIngredientsWithContainers', function(orderItems, restaurantId, useContainers)
    local playerId = source
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not xPlayer then
        print("[RESTAURANT CONTAINERS] Player not found:", playerId)
        return
    end
    
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Order Error',
            description = 'Invalid restaurant ID.',
            type = 'error',
            duration = 10000
        })
        return
    end
    
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    local restaurantItems = Config.Items[restaurantJob] or {}
    local totalCost = 0
    local orderGroupId = generateOrderGroupId()
    local queries = {}
    local priceMultiplier = getPriceMultiplier()
    
    -- Calculate container costs if using containers
    local containerCost = 0
    local containerBreakdown = {}
    
    if useContainers and isContainerSystemEnabled() then
        containerCost, containerBreakdown = calculateContainerCosts(orderItems, restaurantId)
    end

    -- Validate all items and calculate total cost
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        if not quantity or quantity <= 0 then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Invalid quantity for ' .. orderItem.label .. '.',
                type = 'error',
                duration = 10000
            })
            return
        end
        
        -- Find item in nested structure
        local item = nil
        for category, categoryItems in pairs(restaurantItems) do
            if categoryItems[ingredient] then
                item = categoryItems[ingredient]
                break
            end
        end
        
        if not item then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Ingredient not found: ' .. orderItem.label,
                type = 'error',
                duration = 10000
            })
            return
        end
        
        local dynamicPrice = math.floor((item.price or 0) * priceMultiplier)
        totalCost = totalCost + (dynamicPrice * quantity)
    end

    -- Add container costs to total
    local finalCost = totalCost + containerCost

    -- Check if player has enough money
    if xPlayer.PlayerData.money.bank < finalCost then
        local missingAmount = finalCost - xPlayer.PlayerData.money.bank
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Insufficient Funds',
            description = string.format('Need $%d total\n💰 Items: $%d\n📦 Containers: $%d\n❌ Missing: $%d', 
                finalCost, totalCost, containerCost, missingAmount),
            type = 'error',
            duration = 12000
        })
        return
    end

    -- Process each item in the order
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        -- Find the item again (already validated)
        local item = nil
        for category, categoryItems in pairs(restaurantItems) do
            if categoryItems[ingredient] then
                item = categoryItems[ingredient]
                break
            end
        end

        local dynamicPrice = math.floor(item.price * priceMultiplier)
        local itemCost = dynamicPrice * quantity
        
        table.insert(queries, {
            query = 'INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id, container_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            values = {playerId, ingredient, quantity, 'pending', restaurantId, itemCost, orderGroupId, useContainers and 1 or 0}
        })
    end

    -- Remove money and execute queries
    xPlayer.Functions.RemoveMoney('bank', finalCost, "Ordered ingredients" .. (useContainers and " with containers" or ""))
    
    MySQL.Async.transaction(queries, function(success)
        if success then
            local itemList = {}
            for _, orderItem in ipairs(orderItems) do
                table.insert(itemList, orderItem.quantity .. " **" .. orderItem.label .. "**")
            end
            
            local priceChangeText = ""
            if priceMultiplier ~= 1.0 then
                priceChangeText = " (Market: **" .. math.floor((priceMultiplier - 1) * 100) .. "%**)"
            end
            
            local containerText = ""
            if useContainers and containerCost > 0 then
                local totalContainers = 0
                for _, breakdown in ipairs(containerBreakdown) do
                    totalContainers = totalContainers + breakdown.containersNeeded
                end
                containerText = string.format("\n📦 **%d containers** (+$%d)", totalContainers, containerCost)
            end
            
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '✅ Order Submitted Successfully',
                description = string.format('**Order Total: $%d**\n💰 Items: $%d%s%s\n\n📋 Items: %s', 
                    finalCost, totalCost, priceChangeText, containerText, table.concat(itemList, ", ")),
                type = 'success',
                duration = 15000
            })
            
            -- Show container breakdown if containers were used
            if useContainers and #containerBreakdown > 0 then
                Citizen.SetTimeout(2000, function()
                    TriggerClientEvent('restaurant:showContainerBreakdown', playerId, containerBreakdown)
                end)
            end
        else
            xPlayer.Functions.AddMoney('bank', finalCost, "Order failed - refund")
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Error processing order. Money refunded.',
                type = 'error',
                duration = 10000
            })
        end
    end)
end)

-- Enhanced ordering menu with container options
RegisterNetEvent("restaurant:openOrderMenuWithContainers")
AddEventHandler("restaurant:openOrderMenuWithContainers", function(data)
    local src = source
    local restaurantId = data.restaurantId
    local warehouseStock = data.warehouseStock
    local dynamicPrices = data.dynamicPrices
    
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant.",
            type = "error",
            duration = 10000
        })
        return
    end

    local restaurantJob = Config.Restaurants[restaurantId].job
    local restaurantItems = Config.Items[restaurantJob] or {}
    
    -- Send enhanced menu data to client
    TriggerClientEvent("restaurant:showEnhancedOrderMenu", src, {
        restaurantId = restaurantId,
        restaurantName = Config.Restaurants[restaurantId].name,
        warehouseStock = warehouseStock,
        dynamicPrices = dynamicPrices,
        restaurantItems = restaurantItems,
        containerSystemEnabled = isContainerSystemEnabled(),
        containerTypes = Config.DynamicContainers and Config.DynamicContainers.containerTypes or {}
    })
end)

-- Container opening system for restaurants
RegisterNetEvent("containers:openContainer")
AddEventHandler("containers:openContainer", function(containerId, extractedQuantity)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Get container details
    MySQL.Async.fetchAll('SELECT * FROM supply_containers WHERE container_id = ?', {containerId}, function(results)
        if results and results[1] then
            local container = results[1]
            
            -- Verify container belongs to player's restaurant
            local playerJob = xPlayer.PlayerData.job.name
            local restaurantId = nil
            for id, restaurant in pairs(Config.Restaurants) do
                if restaurant.job == playerJob then
                    restaurantId = id
                    break
                end
            end
            
            if not restaurantId or container.restaurant_id ~= restaurantId then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Access Denied',
                    description = 'This container does not belong to your restaurant.',
                    type = 'error',
                    duration = 8000
                })
                return
            end
            
            -- Check if container is already opened
            if container.status == 'opened' then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Container Already Opened',
                    description = 'This container has already been opened.',
                    type = 'error',
                    duration = 8000
                })
                return
            end
            
            -- Add items to player inventory
            local success = xPlayer.Functions.AddItem(container.contents_item, extractedQuantity)
            
            if success then
                -- Update container status
                MySQL.Async.execute([[
                    UPDATE supply_containers 
                    SET status = 'opened', opened_timestamp = ?, updated_at = CURRENT_TIMESTAMP 
                    WHERE container_id = ?
                ]], {GetGameTimer(), containerId})
                
                -- Update restaurant stock tracking
                local stashId = "restaurant_stock_" .. tostring(restaurantId)
                exports.ox_inventory:AddItem(stashId, container.contents_item, extractedQuantity)
                
                -- Log container opening for analytics
                MySQL.Async.execute([[
                    INSERT INTO supply_container_usage_stats 
                    (restaurant_id, container_type, ingredient, total_containers_used, stat_date)
                    VALUES (?, ?, ?, 1, CURDATE())
                    ON DUPLICATE KEY UPDATE
                        total_containers_used = total_containers_used + 1,
                        last_updated = CURRENT_TIMESTAMP
                ]], {restaurantId, container.container_type, container.contents_item})
                
                print(string.format("[RESTAURANT CONTAINERS] %s opened container %s: %d x %s", 
                    xPlayer.PlayerData.charinfo.firstname, containerId, extractedQuantity, container.contents_item))
                
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Inventory Full',
                    description = 'Your inventory is full. Cannot extract items from container.',
                    type = 'error',
                    duration = 8000
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Container Not Found',
                description = 'Container not found or invalid ID.',
                type = 'error',
                duration = 8000
            })
        end
    end)
end)

-- Get container analytics for restaurant
RegisterNetEvent("containers:getRestaurantAnalytics")
AddEventHandler("containers:getRestaurantAnalytics", function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local playerJob = xPlayer.PlayerData.job.name
    local restaurantId = nil
    for id, restaurant in pairs(Config.Restaurants) do
        if restaurant.job == playerJob then
            restaurantId = id
            break
        end
    end
    
    if not restaurantId then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You must be a restaurant employee to view analytics.',
            type = 'error',
            duration = 8000
        })
        return
    end
    
    -- Get container usage analytics
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_containers,
            AVG(quality_level) as avg_quality,
            AVG(TIMESTAMPDIFF(HOUR, filled_timestamp, opened_timestamp)) as avg_delivery_time,
            SUM(CASE WHEN quality_level >= 90 THEN 1 ELSE 0 END) / COUNT(*) * 100 as fresh_rate,
            container_type,
            COUNT(*) as container_type_count,
            AVG(quality_level) as container_type_avg_quality
        FROM supply_containers 
        WHERE restaurant_id = ? AND status = 'opened'
        AND opened_timestamp >= ? 
        GROUP BY container_type
    ]], {restaurantId, GetGameTimer() - (7 * 24 * 60 * 60 * 1000)}, function(results)
        
        local analyticsData = {
            totalContainers = 0,
            avgQuality = 0,
            avgDeliveryTime = 0,
            freshRate = 0,
            containerTypeStats = {}
        }
        
        if results and #results > 0 then
            local totalContainers = 0
            local totalQuality = 0
            
            for _, row in ipairs(results) do
                totalContainers = totalContainers + row.container_type_count
                totalQuality = totalQuality + (row.container_type_avg_quality * row.container_type_count)
                
                analyticsData.containerTypeStats[row.container_type] = {
                    used = row.container_type_count,
                    avgQuality = row.container_type_avg_quality,
                    costEfficiency = 85, -- Simplified calculation
                    successRate = row.container_type_avg_quality > 70 and 95 or 75
                }
            end
            
            if totalContainers > 0 then
                analyticsData.totalContainers = totalContainers
                analyticsData.avgQuality = totalQuality / totalContainers
                analyticsData.avgDeliveryTime = results[1].avg_delivery_time or 0
                analyticsData.freshRate = 85 -- Simplified calculation
            end
        end
        
        TriggerClientEvent('containers:displayAnalytics', src, analyticsData)
    end)
end)

-- Show container breakdown to player
RegisterNetEvent('restaurant:showContainerBreakdown')
AddEventHandler('restaurant:showContainerBreakdown', function(containerBreakdown)
    local src = source
    
    TriggerClientEvent('restaurant:displayContainerBreakdown', src, containerBreakdown)
end)

-- Intercept original restaurant events to route through container system
RegisterNetEvent('restaurant:orderIngredients')
AddEventHandler('restaurant:orderIngredients', function(orderItems, restaurantId)
    if isContainerSystemEnabled() then
        -- Route through container system (default to using containers)
        TriggerEvent('restaurant:orderIngredientsWithContainers', orderItems, restaurantId, true)
    else
        -- Route through original system
        TriggerEvent('restaurant:orderIngredientsOriginal', orderItems, restaurantId)
    end
end)

-- Enhanced order menu opening
RegisterNetEvent("warehouse:getStocksForOrder")
AddEventHandler("warehouse:getStocksForOrder", function(restaurantId)
    if isContainerSystemEnabled() then
        -- Route through container-enhanced menu
        TriggerEvent("restaurant:getStocksForOrderWithContainers", restaurantId)
    else
        -- Route through original system
        TriggerEvent("restaurant:getStocksForOrderOriginal", restaurantId)
    end
end)

-- Enhanced stock request handling
RegisterNetEvent("restaurant:getStocksForOrderWithContainers")
AddEventHandler("restaurant:getStocksForOrderWithContainers", function(restaurantId)
    local src = source
    
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId),
            type = "error",
            duration = 10000
        })
        return
    end

    local stock = {}
    local dynamicPrices = {}

    -- Get warehouse stock
    local result = MySQL.query.await('SELECT ingredient, quantity FROM supply_warehouse_stock')
    if result then
        for _, row in ipairs(result) do
            stock[row.ingredient] = row.quantity or 0
        end
    end

    local restaurantJob = Config.Restaurants[restaurantId].job
    if not restaurantJob or not Config.Items[restaurantJob] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Restaurant job or items not found.",
            type = "error",
            duration = 10000
        })
        return
    end

    local items = Config.Items[restaurantJob]
    for category, categoryItems in pairs(items) do
        for item, details in pairs(categoryItems) do
            dynamicPrices[item] = details.price or 0
        end
    end

    TriggerClientEvent("restaurant:openOrderMenuWithContainers", src, { 
        restaurantId = restaurantId, 
        warehouseStock = stock, 
        dynamicPrices = dynamicPrices 
    })
end)

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isContainerSystemEnabled() then
            print("[RESTAURANT CONTAINERS] Container-enhanced restaurant system loaded!")
            print("[RESTAURANT CONTAINERS] Intercepting restaurant events for container processing")
        else
            print("[RESTAURANT CONTAINERS] Container system disabled - using original restaurant logic")
        end
    end
end)

-- Export functions for integration
exports('calculateContainerCosts', calculateContainerCosts)
exports('determineOptimalContainer', determineOptimalContainer)
exports('isContainerSystemEnabled', isContainerSystemEnabled)

print("[RESTAURANT CONTAINERS] Restaurant container integration loaded successfully!")