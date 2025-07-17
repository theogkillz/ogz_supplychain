-- ============================================
-- RESTAURANT CORE SYSTEM - ENTERPRISE EDITION
-- Professional restaurant management and ordering
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Generate a unique order group ID
local function generateOrderGroupId()
    return "order_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Calculate dynamic price multiplier
local function getPriceMultiplier()
    local playerCount = #GetPlayers()
    local baseMultiplier = 1.0
    
    if Config.DynamicPricing and Config.DynamicPricing.enabled then
        if playerCount > Config.DynamicPricing.peakThreshold then
            baseMultiplier = baseMultiplier + 0.2
        elseif playerCount < Config.DynamicPricing.lowThreshold then
            baseMultiplier = baseMultiplier - 0.1
        end
        return math.max(
            Config.DynamicPricing.minMultiplier or 0.8, 
            math.min(Config.DynamicPricing.maxMultiplier or 1.5, baseMultiplier)
        )
    end
    return baseMultiplier
end

-- Validate restaurant access
local function hasRestaurantAccess(source, restaurantId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    
    return playerJob == restaurantJob or SupplyValidation.validateJob(playerJob, JOBS.MANAGEMENT)
end

-- ============================================
-- ORDER PROCESSING SYSTEM
-- ============================================

-- Handle Order Submission (PRESERVED FUNCTIONALITY)
RegisterNetEvent('restaurant:orderIngredients')
AddEventHandler('restaurant:orderIngredients', function(orderItems, restaurantId)
    local playerId = source
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not xPlayer then
        print("[RESTAURANT ERROR] Player not found:", playerId)
        return
    end
    
    -- Validate restaurant
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Order Error',
            description = 'Invalid restaurant ID.',
            type = 'error',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Validate access
    if not hasRestaurantAccess(playerId, restaurantId) then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Access Denied',
            description = 'You do not have permission to order for this restaurant.',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Order Error',
            description = 'Invalid restaurant configuration.',
            type = 'error',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    local restaurantItems = Config.Items[restaurantJob] or {}
    local totalCost = 0
    local orderGroupId = generateOrderGroupId()
    local queries = {}
    local priceMultiplier = getPriceMultiplier()

    -- Validate all items first
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        if not quantity or quantity <= 0 then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Invalid quantity for ' .. (orderItem.label or ingredient) .. '.',
                type = 'error',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
            return
        end
        
        -- Check nested structure (Meats, Vegetables, Fruits, etc.)
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
                description = 'Ingredient not found: ' .. (orderItem.label or ingredient),
                type = 'error',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
            return
        end
        
        local dynamicPrice = math.floor((item.price or 0) * priceMultiplier)
        totalCost = totalCost + (dynamicPrice * quantity)
    end

    -- Check if player has enough money
    if xPlayer.PlayerData.money.bank < totalCost then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Insufficient Funds',
            description = 'Not enough money in bank. Need $' .. SupplyUtils.formatMoney(totalCost),
            type = 'error',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    -- Process each item in the order
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        -- Find the item again (we already validated it exists)
        local item = nil
        for category, categoryItems in pairs(restaurantItems) do
            if categoryItems[ingredient] then
                item = categoryItems[ingredient]
                break
            end
        end

        if not item or not item.price then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Ingredient pricing error: ' .. (orderItem.label or ingredient),
                type = 'error',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
            return
        end

        local dynamicPrice = math.floor(item.price * priceMultiplier)
        local itemCost = dynamicPrice * quantity
        
        table.insert(queries, {
            query = 'INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            values = { playerId, ingredient, quantity, 'pending', restaurantId, itemCost, orderGroupId }
        })
    end

    -- Remove money and execute queries
    xPlayer.Functions.RemoveMoney('bank', totalCost, "Ordered ingredients")
    
    MySQL.Async.transaction(queries, function(success)
        if success then
            local itemList = {}
            for _, orderItem in ipairs(orderItems) do
                table.insert(itemList, orderItem.quantity .. " **" .. (orderItem.label or orderItem.ingredient) .. "**")
            end
            
            local priceChangeText = ""
            if priceMultiplier ~= 1.0 then
                local changePercent = math.floor((priceMultiplier - 1) * 100)
                priceChangeText = " (**" .. (changePercent >= 0 and "+" or "") .. changePercent .. "%** market adjustment)"
            end
            
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '✅ Order Submitted Successfully',
                description = string.format('**Order Total: $%s**\nOrdered %s%s', 
                    SupplyUtils.formatMoney(totalCost), 
                    table.concat(itemList, ", "), 
                    priceChangeText),
                type = 'success',
                duration = 12000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
            
            -- Trigger analytics tracking
            TriggerEvent('analytics:trackRestaurantOrder', playerId, {
                restaurantId = restaurantId,
                orderGroupId = orderGroupId,
                totalCost = totalCost,
                itemCount = #orderItems,
                priceMultiplier = priceMultiplier
            })
        else
            xPlayer.Functions.AddMoney('bank', totalCost, "Order failed - refund")
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Error processing order. Money refunded.',
                type = 'error',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
        end
    end)
end)

-- ============================================
-- RESTAURANT STOCK MANAGEMENT
-- ============================================

-- Request Restaurant Stock (PRESERVED)
RegisterNetEvent("restaurant:requestStock")
AddEventHandler("restaurant:requestStock", function(restaurantId)
    local src = source
    
    -- Validate restaurant ID
    local actualRestaurantId = restaurantId
    if not Config.Restaurants[restaurantId] then
        actualRestaurantId = tostring(restaurantId)
        if not Config.Restaurants[actualRestaurantId] then
            actualRestaurantId = tonumber(restaurantId)
        end
    end
    
    if not Config.Restaurants[actualRestaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Stock Error",
            description = "Invalid restaurant ID.",
            type = "error",
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    -- Validate access
    if not hasRestaurantAccess(src, actualRestaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You do not have permission to access this restaurant's stock.",
            type = "error",
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    local stashId = "restaurant_stock_" .. tostring(actualRestaurantId)
    
    -- Register/create the stash before client tries to open it
    exports.ox_inventory:RegisterStash(stashId, "Restaurant Stock", 50, 100000, false)
    
    TriggerClientEvent("restaurant:showResturantStock", src, actualRestaurantId)
end)

-- Withdraw Stock (PRESERVED)
RegisterNetEvent('restaurant:withdrawStock')
AddEventHandler('restaurant:withdrawStock', function(restaurantId, ingredient, amount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    
    if not player then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Player not found.',
            type = 'error',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end

    -- Validate access
    if not hasRestaurantAccess(src, restaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You cannot withdraw stock from this restaurant.',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    ingredient = ingredient:lower()
    local restaurantJob = Config.Restaurants[restaurantId].job
    
    -- Find item in nested structure
    local itemData = nil
    if Config.Items[restaurantJob] then
        for category, categoryItems in pairs(Config.Items[restaurantJob]) do
            if categoryItems[ingredient] then
                itemData = categoryItems[ingredient]
                break
            end
        end
    end
    
    if itemData then
        local amountNum = tonumber(amount)
        if amountNum and amountNum > 0 then
            local stashId = "restaurant_stock_" .. tostring(restaurantId)
            local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
            local currentAmount = 0
            
            for _, item in pairs(stashItems) do
                if item.name == ingredient then
                    currentAmount = item.count
                    break
                end
            end
            
            if currentAmount >= amountNum then
                exports.ox_inventory:RemoveItem(stashId, ingredient, amountNum)
                player.Functions.AddItem(ingredient, amountNum)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Stock Withdrawn',
                    description = string.format('Withdrawn %d %s', amountNum, itemData.label or ingredient),
                    type = 'success',
                    duration = 8000,
                    position = Config.UI and Config.UI.notificationPosition or 'center-right',
                    markdown = Config.UI and Config.UI.enableMarkdown or true
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Insufficient Stock',
                    description = string.format('Not enough %s in stock. Available: %d', itemData.label or ingredient, currentAmount),
                    type = 'error',
                    duration = 10000,
                    position = Config.UI and Config.UI.notificationPosition or 'center-right',
                    markdown = Config.UI and Config.UI.enableMarkdown or true
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Invalid amount.',
                type = 'error',
                duration = 5000,
                position = Config.UI and Config.UI.notificationPosition or 'center-right',
                markdown = Config.UI and Config.UI.enableMarkdown or true
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Item not found: ' .. ingredient,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- ============================================
-- STOCK ALERTS & ANALYTICS
-- ============================================

-- Get Restaurant Stock Alerts (ENHANCED)
RegisterNetEvent('restaurant:getStockAlerts')
AddEventHandler('restaurant:getStockAlerts', function(restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Validate access
    if not hasRestaurantAccess(src, restaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You cannot view alerts for this restaurant.",
            type = "error",
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then return end
    
    -- Get restaurant's ingredients from config
    local restaurantItems = Config.Items[restaurantJob] or {}
    local alerts = {}
    
    for category, categoryItems in pairs(restaurantItems) do
        for ingredient, itemData in pairs(categoryItems) do
            -- Get warehouse stock
            MySQL.Async.fetchAll('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', {ingredient}, function(warehouseResult)
                local warehouseStock = (warehouseResult and warehouseResult[1]) and warehouseResult[1].quantity or 0
                
                -- Get restaurant stock
                local stashId = "restaurant_stock_" .. tostring(restaurantId)
                local restaurantStock = 0
                local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
                if stashItems then
                    for _, item in pairs(stashItems) do
                        if item.name == ingredient then
                            restaurantStock = item.count or 0
                            break
                        end
                    end
                end
                
                -- Check if alert needed
                local maxStock = Config.StockAlerts and Config.StockAlerts.maxStock and 
                               Config.StockAlerts.maxStock.default or 500
                local percentage = (warehouseStock / maxStock) * 100
                
                if percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds and 
                                 Config.StockAlerts.thresholds.moderate or 50) then
                    local alertLevel = "moderate"
                    if percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds and 
                                     Config.StockAlerts.thresholds.critical or 5) then
                        alertLevel = "critical"
                    elseif percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds and 
                                         Config.StockAlerts.thresholds.low or 20) then
                        alertLevel = "low"
                    end
                    
                    local itemNames = exports.ox_inventory:Items() or {}
                    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or itemData.label or ingredient
                    
                    table.insert(alerts, {
                        ingredient = ingredient,
                        itemLabel = itemLabel,
                        warehouseStock = warehouseStock,
                        restaurantStock = restaurantStock,
                        percentage = percentage,
                        alertLevel = alertLevel,
                        price = itemData.price,
                        suggestedOrder = math.max(50, math.ceil((maxStock * 0.8) - warehouseStock)),
                        estimatedCost = math.max(50, math.ceil((maxStock * 0.8) - warehouseStock)) * (itemData.price or 0)
                    })
                end
            end)
        end
    end
    
    -- Wait a bit for all queries to complete
    Citizen.Wait(1000)
    TriggerClientEvent('restaurant:showStockAlerts', src, alerts, restaurantId)
end)

-- ============================================
-- QUICK ORDER SYSTEM
-- ============================================

-- Quick Order from Alerts (ENHANCED)
RegisterNetEvent('restaurant:quickOrder')
AddEventHandler('restaurant:quickOrder', function(restaurantId, ingredient, quantity)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Validate access
    if not hasRestaurantAccess(src, restaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You cannot place orders for this restaurant.',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Find item data
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then return end
    
    local itemData = nil
    local restaurantItems = Config.Items[restaurantJob] or {}
    for category, categoryItems in pairs(restaurantItems) do
        if categoryItems[ingredient] then
            itemData = categoryItems[ingredient]
            break
        end
    end
    
    if not itemData then return end
    
    local priceMultiplier = getPriceMultiplier()
    local totalCost = math.floor((itemData.price or 0) * priceMultiplier * quantity)
    
    -- Check money and process order
    if xPlayer.PlayerData.money.bank >= totalCost then
        xPlayer.Functions.RemoveMoney('bank', totalCost, "Quick order from alerts")
        
        local orderGroupId = "quick_" .. os.time() .. "_" .. math.random(1000, 9999)
        
        MySQL.Async.execute([[
            INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {src, ingredient, quantity, 'pending', restaurantId, totalCost, orderGroupId}, function(success)
            if success then
                local itemNames = exports.ox_inventory:Items() or {}
                local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or itemData.label or ingredient
                
                TriggerClientEvent('restaurant:orderSuccess', src, 
                    string.format('Quick order placed: %d %s for $%s', 
                        quantity, itemLabel, SupplyUtils.formatMoney(totalCost))
                )
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            description = 'Not enough money in bank.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- ============================================
-- ORDER STATUS & TRACKING
-- ============================================

-- Get Current Orders (PRESERVED)
RegisterNetEvent("restaurant:getCurrentOrders")
AddEventHandler("restaurant:getCurrentOrders", function(restaurantId)
    local src = source
    
    -- Validate access
    if not hasRestaurantAccess(src, restaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You cannot view orders for this restaurant.",
            type = "error",
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE restaurant_id = ? AND status IN (?, ?, ?)', 
    {restaurantId, 'pending', 'accepted', 'in_transit'}, function(results)
        TriggerClientEvent("restaurant:showCurrentOrders", src, results or {}, restaurantId)
    end)
end)

-- Get Quick Reorder Items (ENHANCED)
RegisterNetEvent("restaurant:getQuickReorderItems")
AddEventHandler("restaurant:getQuickReorderItems", function(restaurantId)
    local src = source
    
    -- Validate access
    if not hasRestaurantAccess(src, restaurantId) then
        return
    end
    
    -- Get recently ordered items for this restaurant
    MySQL.Async.fetchAll([[
        SELECT 
            wh.ingredient,
            wh.quantity as warehouse_stock,
            ms.max_stock,
            (wh.quantity / COALESCE(ms.max_stock, 500) * 100) as percentage
        FROM supply_warehouse_stock wh
        LEFT JOIN supply_market_settings ms ON wh.ingredient = ms.ingredient
        WHERE (wh.quantity / COALESCE(ms.max_stock, 500) * 100) <= 50
        ORDER BY percentage ASC
    ]], {}, function(results)
        TriggerClientEvent("restaurant:showQuickReorderMenu", src, results or {}, restaurantId)
    end)
end)

-- ============================================
-- BULK & SMART ORDERING
-- ============================================

-- Smart Order (AI Suggestion) (PRESERVED)
RegisterNetEvent('restaurant:smartOrder')
AddEventHandler('restaurant:smartOrder', function(restaurantId, ingredient, quantity)
    TriggerEvent('restaurant:quickOrder', source, restaurantId, ingredient, quantity)
end)

-- Bulk Smart Order (PRESERVED)
RegisterNetEvent('restaurant:bulkSmartOrder')
AddEventHandler('restaurant:bulkSmartOrder', function(restaurantId, suggestions)
    local src = source
    
    for _, suggestion in ipairs(suggestions) do
        TriggerEvent('restaurant:quickOrder', src, restaurantId, suggestion.ingredient, suggestion.suggestedQuantity)
        Citizen.Wait(100) -- Small delay between orders
    end
end)

-- ============================================
-- EXPORTS (FOR INTEGRATION)
-- ============================================

exports('hasRestaurantAccess', hasRestaurantAccess)
exports('getPriceMultiplier', getPriceMultiplier)
exports('generateOrderGroupId', generateOrderGroupId)

print("^2[RESTAURANT] 🏗️ Restaurant core system loaded^0")