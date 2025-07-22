-- server/systems/warehouse/sv_warehouse_core.lua
-- Warehouse Server Core System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Active deliveries tracking
local activeDeliveries = {}
local deliveryTeams = {}

-- Get pending orders
RegisterNetEvent(Constants.Events.Server.GetPendingOrders)
AddEventHandler(Constants.Events.Server.GetPendingOrders, function()
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Check job access
    local job = Framework.GetPlayerJob(player)
    local hasAccess = false
    
    for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
        if job.name == allowedJob then
            hasAccess = true
            break
        end
    end
    
    if not hasAccess then
        Framework.Notify(src, "You don't have access to warehouse operations", "error")
        return
    end
    
    -- Get pending orders
    MySQL.Async.fetchAll([[
        SELECT o.*, r.name as restaurant_name
        FROM supply_orders o
        LEFT JOIN supply_restaurants r ON o.restaurant_id = r.id
        WHERE o.status = ?
        ORDER BY o.created_at ASC
    ]], { Constants.OrderStatus.PENDING }, function(results)
        -- Group orders by order_group_id
        local groupedOrders = {}
        
        for _, order in ipairs(results) do
            local groupId = order.order_group_id
            if not groupedOrders[groupId] then
                groupedOrders[groupId] = {
                    orderGroupId = groupId,
                    restaurantId = order.restaurant_id,
                    restaurantName = Config.Restaurants[order.restaurant_id] and Config.Restaurants[order.restaurant_id].name or "Unknown",
                    items = {},
                    totalCost = 0,
                    createdAt = order.created_at
                }
            end
            
            table.insert(groupedOrders[groupId].items, {
                id = order.id,
                itemName = order.ingredient,
                quantity = order.quantity,
                totalCost = order.total_cost or 0
            })
            
            groupedOrders[groupId].totalCost = groupedOrders[groupId].totalCost + (order.total_cost or 0)
        end
        
        -- Convert to array
        local orders = {}
        for _, group in pairs(groupedOrders) do
            table.insert(orders, group)
        end
        
        TriggerClientEvent(Constants.Events.Client.ShowPendingOrders, src, orders)
    end)
end)

-- Accept delivery order
RegisterNetEvent(Constants.Events.Server.AcceptDelivery)
AddEventHandler(Constants.Events.Server.AcceptDelivery, function(orderGroupId, restaurantId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Check if player already has active delivery
    if activeDeliveries[src] then
        Framework.Notify(src, "You already have an active delivery", "error")
        return
    end
    
    -- Verify order exists and is pending
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE order_group_id = ? AND status = ?', {
        orderGroupId, Constants.OrderStatus.PENDING
    }, function(orders)
        if not orders or #orders == 0 then
            Framework.Notify(src, "Order not found or already accepted", "error")
            return
        end
        
        -- Update order status
        MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', {
            Constants.OrderStatus.ACCEPTED, orderGroupId
        }, function(affectedRows)
            if affectedRows > 0 then
                -- Create active delivery
                activeDeliveries[src] = {
                    orderGroupId = orderGroupId,
                    restaurantId = restaurantId,
                    items = orders,
                    startTime = os.time(),
                    team = deliveryTeams[orderGroupId] or { src }
                }
                
                -- Update state manager
                StateManager.UpdateOrderStatus(orderGroupId, Constants.OrderStatus.ACCEPTED)
                
                -- Prepare items for client
                local clientOrders = {}
                for _, order in ipairs(orders) do
                    table.insert(clientOrders, {
                        id = order.id,
                        itemName = order.ingredient,
                        quantity = order.quantity,
                        totalCost = order.total_cost
                    })
                end
                
                -- Spawn vehicle and start delivery
                TriggerClientEvent(Constants.Events.Client.StartDelivery, src, restaurantId, clientOrders)
                
                -- Notify team members
                if deliveryTeams[orderGroupId] then
                    for _, memberId in ipairs(deliveryTeams[orderGroupId]) do
                        if memberId ~= src then
                            activeDeliveries[memberId] = activeDeliveries[src]
                            TriggerClientEvent(Constants.Events.Client.StartDelivery, memberId, restaurantId, clientOrders)
                        end
                    end
                end
                
                Framework.Notify(src, "Delivery accepted! Load the boxes and deliver to the restaurant", "success")
            else
                Framework.Notify(src, "Failed to accept order", "error")
            end
        end)
    end)
end)

-- Update delivery progress
RegisterNetEvent(Constants.Events.Server.UpdateDeliveryProgress)
AddEventHandler(Constants.Events.Server.UpdateDeliveryProgress, function(orderGroupId, status, data)
    local src = source
    local delivery = activeDeliveries[src]
    
    if not delivery or delivery.orderGroupId ~= orderGroupId then
        Framework.Notify(src, "No active delivery found", "error")
        return
    end
    
    -- Update status
    delivery.status = status
    delivery.lastUpdate = os.time()
    
    -- Log progress
    MySQL.Async.insert([[
        INSERT INTO supply_delivery_logs (order_group_id, player_id, status, data, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], {
        orderGroupId,
        GetPlayerCitizenId(src),
        status,
        json.encode(data or {})
    })
    
    -- Notify team members
    if delivery.team then
        for _, memberId in ipairs(delivery.team) do
            if memberId ~= src then
                TriggerClientEvent(Constants.Events.Client.TeamUpdate, memberId, {
                    type = 'delivery_progress',
                    status = status,
                    data = data
                })
            end
        end
    end
end)

-- Complete delivery
RegisterNetEvent(Constants.Events.Server.CompleteDelivery)
AddEventHandler(Constants.Events.Server.CompleteDelivery, function(restaurantId, deliveredItems)
    local src = source
    local player = Framework.GetPlayer(src)
    local delivery = activeDeliveries[src]
    
    if not delivery then
        Framework.Notify(src, "No active delivery found", "error")
        return
    end
    
    -- Calculate delivery time
    local deliveryTime = os.time() - delivery.startTime
    
    -- Update stock in restaurant
    local queries = {}
    for _, item in ipairs(deliveredItems) do
        -- Add to restaurant stock
        table.insert(queries, {
            query = [[
                INSERT INTO supply_stock (restaurant_id, ingredient, quantity)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE quantity = quantity + ?
            ]],
            values = { restaurantId, item.itemName, item.quantity, item.quantity }
        })
        
        -- Also add to restaurant stash
        local stashId = "restaurant_stock_" .. tostring(restaurantId)
        exports.ox_inventory:AddItem(stashId, item.itemName, item.quantity)
    end
    
    -- Update order status
    table.insert(queries, {
        query = 'UPDATE supply_orders SET status = ? WHERE order_group_id = ?',
        values = { Constants.OrderStatus.COMPLETED, delivery.orderGroupId }
    })
    
    -- Execute transaction
    MySQL.Async.transaction(queries, function(success)
        if success then
            -- Calculate rewards
            local baseReward = Config.Rewards.delivery.base.minimumPay
            local boxCount = #deliveredItems
            local teamSize = #delivery.team
            
            -- Calculate modifiers
            local modifiers = {
                speed = 1.0,
                volume = 1.0,
                team = 1.0,
                quality = 1.0
            }
            
            -- Speed bonus
            for _, threshold in ipairs(Config.Rewards.delivery.speedBonuses.thresholds) do
                if deliveryTime <= threshold.time then
                    modifiers.speed = threshold.multiplier
                    break
                end
            end
            
            -- Volume bonus
            for _, threshold in ipairs(Config.Rewards.delivery.volumeBonuses.thresholds) do
                if boxCount >= threshold.boxes then
                    modifiers.volume = threshold.multiplier
                    break
                end
            end
            
            -- Team bonus
            if teamSize > 1 then
                for _, bonus in ipairs(Config.Rewards.delivery.teamBonuses.bonuses) do
                    if teamSize >= bonus.members then
                        modifiers.team = bonus.multiplier
                        break
                    end
                end
            end
            
            -- Calculate final reward
            local totalReward = Config.Rewards.CalculateDeliveryReward(
                baseReward + (boxCount * Config.Rewards.delivery.base.perBoxAmount),
                modifiers
            )
            
            -- Pay team members
            local rewardPerMember = math.floor(totalReward / teamSize)
            
            for _, memberId in ipairs(delivery.team) do
                local member = Framework.GetPlayer(memberId)
                if member then
                    Framework.AddMoney(member, 'bank', rewardPerMember, 'Delivery completion')
                    Framework.Notify(memberId, string.format("Delivery completed! Earned: $%d", rewardPerMember), "success")
                    
                    -- Update stats
                    UpdatePlayerStats(memberId, {
                        deliveries = 1,
                        earnings = rewardPerMember,
                        deliveryTime = deliveryTime
                    })
                end
                
                -- Clean up active delivery
                activeDeliveries[memberId] = nil
            end
            
            -- Clean up team
            if deliveryTeams[delivery.orderGroupId] then
                deliveryTeams[delivery.orderGroupId] = nil
            end
            
            -- Update state manager
            StateManager.UpdateOrderStatus(delivery.orderGroupId, Constants.OrderStatus.COMPLETED)
            StateManager.IncrementDeliveries()
            
            -- Log completion
            LogDeliveryCompletion(src, delivery, totalReward, deliveryTime)
        else
            Framework.Notify(src, "Failed to complete delivery", "error")
        end
    end)
end)

-- Cancel delivery
RegisterNetEvent(Constants.Events.Server.CancelDelivery)
AddEventHandler(Constants.Events.Server.CancelDelivery, function(orderGroupId)
    local src = source
    local delivery = activeDeliveries[src]
    
    if not delivery or delivery.orderGroupId ~= orderGroupId then
        Framework.Notify(src, "No active delivery found", "error")
        return
    end
    
    -- Apply penalty
    if Config.Rewards.penalties.cancellation.enabled then
        local player = Framework.GetPlayer(src)
        if player then
            Framework.RemoveMoney(player, 'bank', Config.Rewards.penalties.cancellation.penalty, 'Delivery cancellation')
        end
    end
    
    -- Reset order status
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', {
        Constants.OrderStatus.PENDING, orderGroupId
    })
    
    -- Clean up
    for _, memberId in ipairs(delivery.team) do
        activeDeliveries[memberId] = nil
        TriggerClientEvent(Constants.Events.Client.HideProgress, memberId)
        Framework.Notify(memberId, "Delivery cancelled", "error")
    end
    
    if deliveryTeams[orderGroupId] then
        deliveryTeams[orderGroupId] = nil
    end
    
    StateManager.UpdateOrderStatus(orderGroupId, Constants.OrderStatus.PENDING)
end)

-- Get warehouse stock
RegisterNetEvent(Constants.Events.Server.GetWarehouseStock)
AddEventHandler(Constants.Events.Server.GetWarehouseStock, function()
    local src = source
    
    -- Get cached stock
    local stock = StateManager.GetWarehouseStock()
    
    if not stock then
        -- Load from database
        MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(results)
            stock = {}
            for _, row in ipairs(results) do
                stock[row.ingredient] = row.quantity
            end
            StateManager.UpdateWarehouseStock(stock)
            TriggerClientEvent("SupplyChain:Client:ShowWarehouseStock", src, stock)
        end)
    else
        TriggerClientEvent("SupplyChain:Client:ShowWarehouseStock", src, stock)
    end
end)

-- Utility Functions
function GetPlayerCitizenId(playerId)
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

function UpdatePlayerStats(playerId, stats)
    local citizenId = GetPlayerCitizenId(playerId)
    if not citizenId then return end
    
    MySQL.Async.execute([[
        INSERT INTO supply_player_stats (citizenid, deliveries, earnings, total_time, last_delivery)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
        deliveries = deliveries + ?,
        earnings = earnings + ?,
        total_time = total_time + ?,
        last_delivery = NOW()
    ]], {
        citizenId,
        stats.deliveries,
        stats.earnings,
        stats.deliveryTime,
        stats.deliveries,
        stats.earnings,
        stats.deliveryTime
    })
    
    -- Update leaderboard
    MySQL.Async.execute([[
        INSERT INTO supply_leaderboard (citizenid, name, deliveries, earnings)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        deliveries = deliveries + ?,
        earnings = earnings + ?
    ]], {
        citizenId,
        GetPlayerName(playerId),
        stats.deliveries,
        stats.earnings,
        stats.deliveries,
        stats.earnings
    })
end

function LogDeliveryCompletion(playerId, delivery, reward, time)
    MySQL.Async.insert([[
        INSERT INTO supply_deliveries (
            order_group_id, player_id, restaurant_id, 
            total_reward, delivery_time, team_size, 
            completed_at
        ) VALUES (?, ?, ?, ?, ?, ?, NOW())
    ]], {
        delivery.orderGroupId,
        GetPlayerCitizenId(playerId),
        delivery.restaurantId,
        reward,
        time,
        #delivery.team
    })
end

-- Check delivery achievements
function CheckDeliveryAchievements(playerId, delivery, deliveryTime, boxCount, teamSize)
    -- Add this safety check
    if not exports['ogz_supplychain'] then 
        print("^3[SupplyChain] Achievements system not ready^7")
        return 
    end
    
    -- Check delivery count achievements
    exports['ogz_supplychain']:CheckAchievementProgress(playerId, "delivery_count", nil)
    
    -- Check speed achievements
    if deliveryTime then
        exports['ogz_supplychain']:CheckAchievementProgress(playerId, "delivery_time", deliveryTime)
    end
    
    -- Check team achievements
    if teamSize and teamSize > 1 then
        exports['ogz_supplychain']:CheckAchievementProgress(playerId, "team_deliveries", nil)
    end
    
    -- Check quality achievements (assuming 100% for now)
    exports['ogz_supplychain']:CheckAchievementProgress(playerId, "perfect_deliveries", nil)
    
    -- Check time-based achievements
    local hour = os.date("*t").hour
    if hour >= 22 or hour < 6 then
        exports['ogz_supplychain']:CheckAchievementProgress(playerId, "night_deliveries", nil)
    elseif hour >= 6 and hour < 12 then
        exports['ogz_supplychain']:CheckAchievementProgress(playerId, "morning_deliveries", nil)
    end
    
    -- Check weekend deliveries
    local dayOfWeek = os.date("*t").wday
    if dayOfWeek == 1 or dayOfWeek == 7 then
        exports['ogz_supplychain']:CheckAchievementProgress(playerId, "weekend_deliveries", nil)
    end
end

-- Export functions
exports('GetActiveDeliveries', function()
    return activeDeliveries
end)

exports('GetDeliveryTeams', function()
    return deliveryTeams
end)