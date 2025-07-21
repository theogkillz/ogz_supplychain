QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('update:stock')
AddEventHandler('update:stock', function(restaurantId, orders)
    local src = source
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in sv_warehouse.lua")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Configuration not loaded.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    if not restaurantId or not orders or #orders == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid restaurant ID or order data.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local orderGroupId = orders[1].orderGroupId
    local queries = {}
    local totalCost = 0
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    for _, order in ipairs(orders) do
        local ingredient = order.itemName:lower()
        local quantity = tonumber(order.quantity)
        local orderCost = order.totalCost or 0
        if ingredient and quantity then
            table.insert(queries, {
                query = 'UPDATE supply_orders SET status = @status WHERE id = @id AND order_group_id = @order_group_id',
                values = {
                    ['@status'] = 'completed',
                    ['@id'] = order.id,
                    ['@order_group_id'] = orderGroupId
                }
            })
            table.insert(queries, {
                query = 'INSERT INTO supply_stock (restaurant_id, ingredient, quantity) VALUES (@restaurant_id, @ingredient, @quantity) ON DUPLICATE KEY UPDATE quantity = quantity + @quantity',
                values = {
                    ['@restaurant_id'] = restaurantId,
                    ['@ingredient'] = ingredient,
                    ['@quantity'] = quantity
                }
            })
            exports.ox_inventory:AddItem(stashId, ingredient, quantity)
            totalCost = totalCost + orderCost
        else
            print("[ERROR] Invalid order data: ingredient or quantity is nil for order ID:", order.id)
        end
    end

    MySQL.Async.transaction(queries, function(success)
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Stock Updated',
                description = 'Orders completed and stock updated!',
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            local driverPayment = totalCost * Config.DriverPayPrec
            local xPlayer = QBCore.Functions.GetPlayer(src)
            if xPlayer then
                MySQL.Async.execute([[
                    INSERT INTO supply_leaderboard (citizenid, name, deliveries, earnings)
                    VALUES (@citizenid, @name, 1, @earnings)
                    ON DUPLICATE KEY UPDATE deliveries = deliveries + 1, earnings = earnings + @earnings
                ]], {
                    ['@citizenid'] = xPlayer.PlayerData.citizenid,
                    ['@name'] = xPlayer.PlayerData.name,
                    ['@earnings'] = driverPayment
                })
                TriggerEvent('pay:driver', src, driverPayment)
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Failed to update stock.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end)
end)

RegisterNetEvent('warehouse:getStocks')
AddEventHandler('warehouse:getStocks', function()
    local playerId = source
    MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock', {}, function(results)
        local stock = {}
        for _, item in ipairs(results) do
            stock[item.ingredient:lower()] = item.quantity
        end
        TriggerClientEvent('restaurant:showStockDetails', playerId, stock)
    end)
end)

RegisterNetEvent("warehouse:getStocksForOrder")
AddEventHandler("warehouse:getStocksForOrder", function(restaurantId)
    local src = source
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in sv_warehouse.lua")
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Configuration not loaded.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    print("[DEBUG] Config.Restaurants:", Config.Restaurants and "exists" or "nil")
    if Config.Restaurants then
        for k, v in ipairs(Config.Restaurants) do
            print("[DEBUG] Key:", k, "Value:", v.name or "no name")
        end
    end
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId),
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local stock = {}
    local dynamicPrices = {}
    local result = MySQL.query.await('SELECT ingredient, quantity FROM supply_stock WHERE restaurant_id = ?', { restaurantId })
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
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local items = Config.Items[restaurantJob]
    for category, categoryItems in pairs(items) do
        for item, details in pairs(categoryItems) do
            dynamicPrices[item] = details.price or 0
        end
    end

    TriggerClientEvent("restaurant:openOrderMenu", src, { restaurantId = restaurantId, warehouseStock = stock, dynamicPrices = dynamicPrices })
end)