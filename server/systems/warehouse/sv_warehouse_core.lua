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

-- ============================================
-- MULTI-ORDER SYSTEM ADDITIONS
-- Add these event handlers to support container orders
-- ============================================

-- Request container orders handler
RegisterNetEvent("SupplyChain:Server:RequestContainerOrders")
AddEventHandler("SupplyChain:Server:RequestContainerOrders", function()
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end
    
    -- Verify warehouse worker
    local playerJob = Framework.GetJob(player)
    if playerJob ~= Config.Warehouse.warehouseJob then
        Framework.Notify(source, "You must be a warehouse worker", "error")
        return
    end
    
    -- Get all pending orders from ActiveOrders table
    local pendingOrders = {}
    
    -- Check if ActiveOrders exists (from sv_restaurant_orders_v2.lua)
    if ActiveOrders then
        for orderId, order in pairs(ActiveOrders) do
            if order.status == "pending" then
                table.insert(pendingOrders, order)
            end
        end
    else
        -- Fallback to database query if ActiveOrders not available
        local dbOrders = exports.oxmysql:executeSync([[
            SELECT * FROM supply_orders 
            WHERE status = 'pending' 
            ORDER BY created_at ASC
        ]])
        
        for _, dbOrder in ipairs(dbOrders or {}) do
            local orderData = json.decode(dbOrder.order_data)
            if orderData then
                orderData.id = dbOrder.order_id
                table.insert(pendingOrders, orderData)
            end
        end
    end
    
    -- Get worker stats for today
    local playerId = Framework.GetIdentifier(player)
    local stats = {
        deliveries = 0,
        containers = 0,
        earnings = 0
    }
    
    -- Query database for today's stats
    local result = exports.oxmysql:executeSync([[
        SELECT 
            COUNT(DISTINCT order_id) as deliveries,
            SUM(total_boxes) as containers,
            SUM(payment) as earnings
        FROM supply_deliveries
        WHERE player_id = ? 
        AND DATE(created_at) = CURDATE()
        AND status = 'completed'
    ]], {playerId})
    
    if result and result[1] then
        stats.deliveries = result[1].deliveries or 0
        stats.containers = result[1].containers or 0
        stats.earnings = result[1].earnings or 0
    end
    
    -- Send to client
    TriggerClientEvent("SupplyChain:Server:SendContainerOrders", source, pendingOrders, stats)
end)

-- Accept multiple orders handler
RegisterNetEvent("SupplyChain:Server:AcceptMultipleOrders")
AddEventHandler("SupplyChain:Server:AcceptMultipleOrders", function(consolidatedOrder)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end
    
    -- Verify warehouse worker
    local playerJob = Framework.GetJob(player)
    if playerJob ~= Config.Warehouse.warehouseJob then
        Framework.Notify(source, "You must be a warehouse worker", "error")
        return
    end
    
    -- Check if player already has active delivery
    if ActiveDeliveries and ActiveDeliveries[source] then
        Framework.Notify(source, "You already have an active delivery", "error")
        return
    end
    
    -- Verify all orders are still available
    local allAvailable = true
    local validOrders = {}
    
    if ActiveOrders then
        -- Check against ActiveOrders table
        for _, order in ipairs(consolidatedOrder.orders) do
            if not ActiveOrders[order.id] or ActiveOrders[order.id].status ~= "pending" then
                allAvailable = false
                break
            else
                table.insert(validOrders, ActiveOrders[order.id])
            end
        end
    else
        -- Fallback to database check
        for _, order in ipairs(consolidatedOrder.orders) do
            local dbCheck = exports.oxmysql:executeSync([[
                SELECT status FROM supply_orders 
                WHERE order_id = ? AND status = 'pending'
            ]], {order.id})
            
            if not dbCheck or #dbCheck == 0 then
                allAvailable = false
                break
            else
                table.insert(validOrders, order)
            end
        end
    end
    
    if not allAvailable then
        Framework.Notify(source, "Some orders are no longer available", "error")
        TriggerEvent("SupplyChain:Server:RequestContainerOrders", source)
        return
    end
    
    -- Update order statuses
    local playerId = Framework.GetIdentifier(player)
    local currentTime = os.time()
    
    -- Update in ActiveOrders if available
    if ActiveOrders then
        for _, order in ipairs(consolidatedOrder.orders) do
            if ActiveOrders[order.id] then
                ActiveOrders[order.id].status = "preparing"
                ActiveOrders[order.id].assignedTo = playerId
                ActiveOrders[order.id].deliveryStartTime = currentTime
            end
        end
    end
    
    -- Update in database
    for _, order in ipairs(consolidatedOrder.orders) do
        exports.oxmysql:execute([[
            UPDATE supply_orders 
            SET status = 'preparing', assigned_to = ?, updated_at = NOW() 
            WHERE order_id = ?
        ]], {playerId, order.id})
    end
    
    -- Create delivery record
    if not ActiveDeliveries then
        ActiveDeliveries = {}
    end
    
    ActiveDeliveries[source] = {
        orderId = consolidatedOrder.orderId,
        orderIds = {}, -- Track individual order IDs
        workerId = source,
        playerId = playerId,
        restaurantId = consolidatedOrder.restaurantId,
        startTime = currentTime,
        totalContainers = consolidatedOrder.totalContainers,
        containersLoaded = 0,
        containersDelivered = 0,
        vanSpawned = false
    }
    
    -- Store individual order IDs
    for _, order in ipairs(consolidatedOrder.orders) do
        table.insert(ActiveDeliveries[source].orderIds, order.id)
    end
    
    -- Get restaurant name
    local restaurant = Config.Restaurants[consolidatedOrder.restaurantId]
    local restaurantName = restaurant and restaurant.name or "Unknown"
    
    -- Create delivery record in database
    exports.oxmysql:execute([[
        INSERT INTO supply_deliveries 
        (delivery_id, player_id, restaurant_id, order_group_id, total_boxes, status, created_at) 
        VALUES (?, ?, ?, ?, ?, 'preparing', NOW())
    ]], {
        consolidatedOrder.orderId,
        playerId,
        consolidatedOrder.restaurantId,
        json.encode(ActiveDeliveries[source].orderIds),
        consolidatedOrder.totalContainers
    })
    
    -- Send success response
    TriggerClientEvent("SupplyChain:Client:MultiOrderAccepted", source, {
        success = true,
        orderId = consolidatedOrder.orderId,
        orderData = consolidatedOrder,
        restaurantId = consolidatedOrder.restaurantId,
        restaurantName = restaurantName,
        totalContainers = consolidatedOrder.totalContainers
    })
    
    print(string.format("^3[SupplyChain]^7 Worker %s accepted %d orders (%d containers) for %s", 
        GetPlayerName(source), #consolidatedOrder.orders, consolidatedOrder.totalContainers, restaurantName))
end)

-- Update the existing VanSpawned handler to support multi-order
local originalVanSpawnedHandler = RegisterNetEvent(Constants.Events.Server.VanSpawned)
if originalVanSpawnedHandler then
    RemoveEventHandler(originalVanSpawnedHandler)
end

RegisterNetEvent(Constants.Events.Server.VanSpawned)
AddEventHandler(Constants.Events.Server.VanSpawned, function(data)
    local source = source
    local delivery = ActiveDeliveries[source]
    if not delivery then return end
    
    delivery.vanSpawned = true
    local order = nil
    
    -- Check if we have the new multi-order format
    if delivery.orderId and string.sub(delivery.orderId, 1, 5) == "MULTI" then
        -- This is a multi-order delivery
        order = {
            id = delivery.orderId,
            restaurantId = delivery.restaurantId,
            totalContainers = delivery.totalContainers,
            containers = {},
            items = {}
        }
        
        -- Aggregate containers from all orders
        if ActiveOrders then
            for _, orderId in ipairs(delivery.orderIds or {}) do
                local subOrder = ActiveOrders[orderId]
                if subOrder and subOrder.containers then
                    for _, container in ipairs(subOrder.containers) do
                        table.insert(order.containers, container)
                    end
                    for _, item in ipairs(subOrder.items or {}) do
                        table.insert(order.items, item)
                    end
                end
            end
        end
    else
        -- Legacy single order support
        order = ActiveOrders and ActiveOrders[delivery.orderId]
    end
    
    if not order then return end
    
    -- Get warehouse config
    local warehouseId = GetPlayerWarehouseId(source)
    local warehouseConfig = Config.Warehouses[warehouseId]
    
    -- Start multi-box delivery
    TriggerClientEvent("SupplyChain:Client:StartMultiBoxDelivery", source, {
        orderData = order,
        restaurantId = order.restaurantId,
        warehouseConfig = warehouseConfig,
        van = data.vanNetId
    })
end)

-- Add debug command for warehouse stats
RegisterCommand("sc_warehousestats", function(source, args)
    if source == 0 then
        -- Console command
        print("^3[SupplyChain]^7 Warehouse Statistics:")
        
        if ActiveOrders then
            local pendingCount = 0
            local totalContainers = 0
            for orderId, order in pairs(ActiveOrders) do
                if order.status == "pending" then
                    pendingCount = pendingCount + 1
                    totalContainers = totalContainers + (order.totalContainers or 0)
                end
            end
            print(string.format("  Pending Orders: %d (%d containers)", pendingCount, totalContainers))
        end
        
        if ActiveDeliveries then
            print(string.format("  Active Deliveries: %d", #ActiveDeliveries))
            for workerId, delivery in pairs(ActiveDeliveries) do
                print(string.format("    - Worker %d: %s (%d/%d containers)", 
                    workerId, delivery.orderId, delivery.containersDelivered or 0, delivery.totalContainers or 0))
            end
        end
    else
        -- Player command
        local player = Framework.GetPlayer(source)
        if not player then return end
        
        local playerJob = Framework.GetJob(player)
        if playerJob ~= Config.Warehouse.warehouseJob and not Framework.HasPermission(player, "admin") then
            Framework.Notify(source, "You must be a warehouse worker to use this command", "error")
            return
        end
        
        -- Show player stats
        TriggerEvent("SupplyChain:Server:RequestContainerOrders", source)
    end
end, false)

-- Helper function (add if not exists)
function GetPlayerWarehouseId(source)
    -- For now, return first warehouse
    -- TODO: Add warehouse assignment system
    for warehouseId, _ in pairs(Config.Warehouses) do
        return warehouseId
    end
    return "warehouse_1"
end
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
    -- Safety check for exports
    local success, result = pcall(function()
        return exports['ogz_supplychain']
    end)
    
    if not success or not result then
        print("^3[SupplyChain] Achievement system not available yet^7")
        return
    end
    
    -- Check if the export function exists
    if not result.CheckAchievementProgress then
        print("^3[SupplyChain] CheckAchievementProgress export not found^7")
        return
    end
    
    -- Now safe to use exports
    result:CheckAchievementProgress(playerId, "delivery_count", nil)
    
    if deliveryTime then
        result:CheckAchievementProgress(playerId, "delivery_time", deliveryTime)
    end
    
    if teamSize and teamSize > 1 then
        result:CheckAchievementProgress(playerId, "team_deliveries", nil)
    end
    
    result:CheckAchievementProgress(playerId, "perfect_deliveries", nil)
    
    local hour = os.date("*t").hour
    if hour >= 22 or hour < 6 then
        result:CheckAchievementProgress(playerId, "night_deliveries", nil)
    elseif hour >= 6 and hour < 12 then
        result:CheckAchievementProgress(playerId, "morning_deliveries", nil)
    end
    
    local dayOfWeek = os.date("*t").wday
    if dayOfWeek == 1 or dayOfWeek == 7 then
        result:CheckAchievementProgress(playerId, "weekend_deliveries", nil)
    end
end

-- Export functions
exports('GetActiveDeliveries', function()
    return activeDeliveries
end)

exports('GetDeliveryTeams', function()
    return deliveryTeams
end)