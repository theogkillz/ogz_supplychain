-- Restaurant Server Core System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Get warehouse stock for ordering
RegisterNetEvent(Constants.Events.Server.GetWarehouseStockForOrder)
AddEventHandler(Constants.Events.Server.GetWarehouseStockForOrder, function(restaurantId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Verify restaurant access
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        Framework.Notify(src, "Invalid restaurant", "error")
        return
    end
    
    local job = Framework.GetPlayerJob(player)
    if job.name ~= restaurant.job then
        Framework.Notify(src, "You don't work at this restaurant", "error")
        return
    end
    
    -- Get warehouse stock
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(results)
        local warehouseStock = {}
        for _, row in ipairs(results) do
            warehouseStock[row.ingredient] = row.quantity
        end
        
        -- Get dynamic prices
        local dynamicPrices = StateManager.GetMarketPrices() or {}
        
        -- Send data to client
        TriggerClientEvent(Constants.Events.Client.OpenOrderMenu, src, {
            restaurantId = restaurantId,
            warehouseStock = warehouseStock,
            dynamicPrices = dynamicPrices
        })
    end)
end)

-- Create restaurant order
RegisterNetEvent(Constants.Events.Server.CreateRestaurantOrder)
AddEventHandler(Constants.Events.Server.CreateRestaurantOrder, function(orderItems, restaurantId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player or not orderItems or #orderItems == 0 then
        Framework.Notify(src, "Invalid order data", "error")
        return
    end
    
    -- Verify restaurant access
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        Framework.Notify(src, "Invalid restaurant", "error")
        return
    end
    
    local job = Framework.GetPlayerJob(player)
    if job.name ~= restaurant.job then
        Framework.Notify(src, "You don't work at this restaurant", "error")
        return
    end
    
    -- Generate order group ID
    local orderGroupId = string.format("GRP-%s-%d", os.date("%Y%m%d%H%M%S"), math.random(1000, 9999))
    local totalCost = 0
    local dynamicPrices = StateManager.GetMarketPrices() or {}
    
    -- Begin transaction
    local queries = {}
    
    -- Create individual orders for each item
    for _, item in ipairs(orderItems) do
        local ingredient = item.ingredient
        local quantity = tonumber(item.quantity)
        
        if ingredient and quantity and quantity > 0 then
            -- Get price
            local itemConfig = GetItemConfig(restaurant.job, ingredient)
            local price = dynamicPrices[ingredient] or (itemConfig and itemConfig.price) or 10
            local itemCost = price * quantity
            totalCost = totalCost + itemCost
            
            -- Insert order
            table.insert(queries, {
                query = [[
                    INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]],
                values = {
                    GetPlayerDatabaseId(src),
                    ingredient,
                    quantity,
                    Constants.OrderStatus.PENDING,
                    restaurantId,
                    itemCost,
                    orderGroupId
                }
            })
        end
    end
    
    -- Execute transaction
    MySQL.Async.transaction(queries, function(success)
        if success then
            -- Add to state manager
            StateManager.AddOrder(orderGroupId, {
                restaurantId = restaurantId,
                items = orderItems,
                totalCost = totalCost,
                status = Constants.OrderStatus.PENDING
            })
            
            -- Charge restaurant
            if totalCost > 0 then
                local hasMoney = Framework.GetMoney(player, 'bank') >= totalCost
                if hasMoney then
                    Framework.RemoveMoney(player, 'bank', totalCost, 'Restaurant order')
                    
                    -- Log transaction
                    LogTransaction(src, 'restaurant_order', -totalCost, {
                        orderGroupId = orderGroupId,
                        restaurantId = restaurantId
                    })
                    
                    Framework.Notify(src, string.format("Order placed successfully! Total: $%d", totalCost), "success")
                    TriggerClientEvent(Constants.Events.Client.OrderComplete, src, true)
                    
                    -- Notify warehouse workers
                    NotifyWarehouseWorkers({
                        title = "New Order",
                        description = string.format("%s has placed a new order", restaurant.name),
                        type = "info"
                    })
                else
                    -- Rollback order
                    MySQL.Async.execute('DELETE FROM supply_orders WHERE order_group_id = ?', { orderGroupId })
                    StateManager.RemoveOrder(orderGroupId)
                    
                    Framework.Notify(src, "Insufficient funds in bank account", "error")
                    TriggerClientEvent(Constants.Events.Client.OrderComplete, src, false, "Insufficient funds")
                end
            end
        else
            Framework.Notify(src, "Failed to create order", "error")
            TriggerClientEvent(Constants.Events.Client.OrderComplete, src, false, "Database error")
        end
    end)
end)

-- Get restaurant stock
RegisterNetEvent(Constants.Events.Server.GetRestaurantStock)
AddEventHandler(Constants.Events.Server.GetRestaurantStock, function(restaurantId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Verify access
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then return end
    
    local job = Framework.GetPlayerJob(player)
    if job.name ~= restaurant.job then
        Framework.Notify(src, "Access denied", "error")
        return
    end
    
    -- Get stock from database
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_stock WHERE restaurant_id = ?', {
        restaurantId
    }, function(results)
        local stock = {}
        for _, row in ipairs(results) do
            stock[row.ingredient] = row.quantity
        end
        
        TriggerClientEvent(Constants.Events.Client.ShowRestaurantStock, src, restaurantId, stock)
    end)
end)

-- Withdraw restaurant stock
RegisterNetEvent(Constants.Events.Server.WithdrawRestaurantStock)
AddEventHandler(Constants.Events.Server.WithdrawRestaurantStock, function(restaurantId, itemName, amount)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Verify access
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then return end
    
    local job = Framework.GetPlayerJob(player)
    if job.name ~= restaurant.job then
        Framework.Notify(src, "Access denied", "error")
        return
    end
    
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    
    -- Check if item exists in stash
    local count = exports.ox_inventory:GetItem(stashId, itemName, nil, true)
    if count >= amount then
        -- Remove from stash
        if exports.ox_inventory:RemoveItem(stashId, itemName, amount) then
            -- Add to player
            if exports.ox_inventory:AddItem(src, itemName, amount) then
                Framework.Notify(src, string.format("Withdrew %dx %s", amount, itemName), "success")
                
                -- Update database
                MySQL.Async.execute([[
                    UPDATE supply_stock 
                    SET quantity = quantity - ? 
                    WHERE restaurant_id = ? AND ingredient = ?
                ]], { amount, restaurantId, itemName })
                
                -- Log action
                LogAction(src, 'withdraw_stock', {
                    restaurantId = restaurantId,
                    item = itemName,
                    amount = amount
                })
            else
                -- Rollback
                exports.ox_inventory:AddItem(stashId, itemName, amount)
                Framework.Notify(src, "Failed to add items to inventory", "error")
            end
        else
            Framework.Notify(src, "Failed to remove items from stock", "error")
        end
    else
        Framework.Notify(src, "Not enough stock available", "error")
    end
end)

-- Complete recipe (cooking)
RegisterNetEvent(Constants.Events.Server.CompleteRecipe)
AddEventHandler(Constants.Events.Server.CompleteRecipe, function(data)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player or not data.recipe then return end
    
    local recipe = data.recipe
    local quantity = data.quantity or 1
    
    -- Check required items
    if recipe.requiredItems then
        for _, req in pairs(recipe.requiredItems) do
            local hasItem = exports.ox_inventory:GetItem(src, req.item, nil, true)
            if hasItem < (req.amount * quantity) then
                Framework.Notify(src, "Missing required items", "error")
                return
            end
        end
        
        -- Remove required items
        for _, req in pairs(recipe.requiredItems) do
            exports.ox_inventory:RemoveItem(src, req.item, req.amount * quantity)
        end
    end
    
    -- Give crafted item
    if exports.ox_inventory:AddItem(src, recipe.item, recipe.amount * quantity) then
        Framework.Notify(src, string.format("Successfully prepared %dx %s", recipe.amount * quantity, recipe.item), "success")
        
        -- Add experience/stats
        if Config.Rewards.experience.enabled then
            AddPlayerExperience(src, 'cooking', Config.Rewards.experience.gains.manufacturing * quantity)
        end
    else
        -- Refund items if failed
        if recipe.requiredItems then
            for _, req in pairs(recipe.requiredItems) do
                exports.ox_inventory:AddItem(src, req.item, req.amount * quantity)
            end
        end
        Framework.Notify(src, "Failed to create item", "error")
    end
end)

-- Utility Functions
function GetItemConfig(restaurantJob, itemName)
    local items = Config.Items[restaurantJob]
    if not items then return nil end
    
    for category, categoryItems in pairs(items) do
        if categoryItems[itemName] then
            return categoryItems[itemName]
        end
    end
    
    return nil
end

function GetPlayerDatabaseId(playerId)
    -- This would normally get the database ID
    -- For now, return citizen ID
    local player = Framework.GetPlayer(playerId)
    if player then
        if Framework.Type == 'qbcore' then
            return player.PlayerData.citizenid
        else
            return player.citizenid
        end
    end
    return nil
end

function NotifyWarehouseWorkers(notification)
    local players = Framework.GetPlayers()
    for _, playerId in ipairs(players) do
        local player = Framework.GetPlayer(playerId)
        if player then
            local job = Framework.GetPlayerJob(player)
            if job and Config.Warehouse.jobAccess then
                for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
                    if job.name == allowedJob then
                        Framework.Notify(playerId, notification.description, notification.type or "info")
                        break
                    end
                end
            end
        end
    end
end

function LogTransaction(playerId, type, amount, metadata)
    MySQL.Async.insert([[
        INSERT INTO supply_transactions (player_id, type, amount, metadata, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], {
        GetPlayerDatabaseId(playerId),
        type,
        amount,
        json.encode(metadata or {})
    })
end

function LogAction(playerId, action, data)
    MySQL.Async.insert([[
        INSERT INTO supply_system_logs (player_id, action, data, created_at)
        VALUES (?, ?, ?, NOW())
    ]], {
        GetPlayerDatabaseId(playerId),
        action,
        json.encode(data or {})
    })
end

function AddPlayerExperience(playerId, type, amount)
    local citizenId = GetPlayerDatabaseId(playerId)
    if not citizenId then return end
    
    MySQL.Async.execute([[
        INSERT INTO supply_player_stats (citizenid, experience, last_activity)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE
        experience = experience + ?,
        last_activity = NOW()
    ]], {
        citizenId,
        amount,
        amount
    })
    
    -- Check for level up
    -- This would check XP thresholds and grant rewards
end

-- Export functions
exports('CreateRestaurantOrder', function(orderItems, restaurantId, playerId)
    -- This allows other resources to create orders
    TriggerEvent(Constants.Events.Server.CreateRestaurantOrder, orderItems, restaurantId)
end)