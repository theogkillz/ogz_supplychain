-- Server Handlers v2.0 - Multi-Order System

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants
local StateManager = SupplyChain.StateManager

-- Active orders tracking
local ActiveOrders = {}
local ActiveDeliveries = {}

-- Create restaurant order with containers
RegisterNetEvent(Constants.Events.Server.CreateRestaurantOrder)
AddEventHandler(Constants.Events.Server.CreateRestaurantOrder, function(orderData)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end
    
    -- Validate restaurant access
    local playerJob = Framework.GetJob(player)
    if not playerJob or playerJob ~= orderData.restaurantId then
        Framework.Notify(source, "You don't have permission to order for this restaurant", "error")
        return
    end
    
    -- Generate order ID
    local orderId = "ORD_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    -- Calculate total items and validate stock
    local totalItems = 0
    local orderValid = true
    local warehouseStock = StateManager.GetWarehouseStock()
    
    for _, item in ipairs(orderData.items) do
        totalItems = totalItems + item.quantity
        
        -- Check warehouse stock
        if not warehouseStock[item.name] or warehouseStock[item.name] < item.quantity then
            Framework.Notify(source, string.format("Insufficient stock for %s", item.label), "error")
            orderValid = false
            break
        end
    end
    
    if not orderValid then return end
    
    -- Create order record
    local order = {
        id = orderId,
        restaurantId = orderData.restaurantId,
        orderedBy = Framework.GetIdentifier(player),
        orderTime = os.time(),
        status = "pending",
        
        -- Items and containers
        items = orderData.items,
        containers = orderData.containers,
        totalItems = totalItems,
        totalContainers = orderData.totalContainers,
        
        -- Costs
        itemCost = orderData.totalCost,
        containerCost = 0,
        totalCost = orderData.totalCost,
        
        -- Tracking
        assignedTo = nil,
        deliveryStartTime = nil,
        deliveryEndTime = nil,
        containersDelivered = 0
    }
    
    -- Calculate container costs
    for _, container in ipairs(orderData.containers) do
        local containerInfo = Config.Containers.types[container.type]
        if containerInfo then
            order.containerCost = order.containerCost + (containerInfo.cost * container.count)
        end
    end
    order.totalCost = order.itemCost + order.containerCost
    
    -- Reserve items in warehouse
    for _, item in ipairs(orderData.items) do
        StateManager.UpdateWarehouseStock(item.name, -item.quantity)
    end
    
    -- Store order
    ActiveOrders[orderId] = order
    
    -- Notify warehouse workers
    local warehouseWorkers = GetWarehouseWorkers()
    for _, workerId in ipairs(warehouseWorkers) do
        TriggerClientEvent("SupplyChain:Client:NewOrderNotification", workerId, {
            orderId = orderId,
            restaurant = Config.Restaurants[orderData.restaurantId].name,
            totalContainers = order.totalContainers,
            priority = order.totalItems > 50 and "high" or "normal"
        })
    end
    
    -- Save to database
    exports.oxmysql:execute([[
        INSERT INTO supply_orders 
        (order_id, restaurant_id, ordered_by, order_data, status, created_at) 
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], {
        orderId,
        orderData.restaurantId,
        Framework.GetIdentifier(player),
        json.encode(order),
        "pending"
    })
    
    Framework.Notify(source, string.format("Order #%s created successfully!", orderId), "success")
    
    -- Log event
    print(string.format("^3[SupplyChain]^7 Restaurant order created: %s (%d containers, %d items)", 
        orderId, order.totalContainers, order.totalItems))
end)

-- Warehouse worker accepts order
RegisterNetEvent(Constants.Events.Server.AcceptWarehouseOrder)
AddEventHandler(Constants.Events.Server.AcceptWarehouseOrder, function(orderId)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end
    
    -- Validate warehouse worker
    local playerJob = Framework.GetJob(player)
    if playerJob ~= Config.Warehouse.warehouseJob then
        Framework.Notify(source, "You must be a warehouse worker to accept orders", "error")
        return
    end
    
    local order = ActiveOrders[orderId]
    if not order then
        Framework.Notify(source, "Order not found", "error")
        return
    end
    
    if order.status ~= "pending" then
        Framework.Notify(source, "This order has already been accepted", "error")
        return
    end
    
    -- Update order
    order.status = "preparing"
    order.assignedTo = Framework.GetIdentifier(player)
    order.deliveryStartTime = os.time()
    
    -- Create delivery record
    ActiveDeliveries[source] = {
        orderId = orderId,
        workerId = source,
        startTime = os.time(),
        containersLoaded = 0,
        containersDelivered = 0,
        vanSpawned = false
    }
    
    -- Spawn delivery van
    local warehouseId = GetPlayerWarehouseId(source)
    local warehouseConfig = Config.Warehouses[warehouseId]
    
    if warehouseConfig then
        -- Spawn van with callback
        TriggerClientEvent("SupplyChain:Client:SpawnDeliveryVan", source, {
            orderId = orderId,
            spawnPos = warehouseConfig.vanSpawn,
            heading = warehouseConfig.vanSpawn.w or 0.0
        })
    end
    
    Framework.Notify(source, string.format("Order #%s accepted. Spawn a van to begin loading.", orderId), "success")
end)

-- Van spawned callback
RegisterNetEvent(Constants.Events.Server.VanSpawned)
AddEventHandler(Constants.Events.Server.VanSpawned, function(data)
    local source = source
    local delivery = ActiveDeliveries[source]
    if not delivery then return end
    
    delivery.vanSpawned = true
    local order = ActiveOrders[delivery.orderId]
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

-- Update delivery progress
RegisterNetEvent(Constants.Events.Server.UpdateDeliveryProgress)
AddEventHandler(Constants.Events.Server.UpdateDeliveryProgress, function(data)
    local source = source
    local delivery = ActiveDeliveries[source]
    if not delivery then return end
    
    local order = ActiveOrders[delivery.orderId]
    if not order then return end
    
    -- Update based on status
    if data.status == "loading" then
        delivery.containersLoaded = data.boxesLoaded or 0
        
        -- Update database
        exports.oxmysql:execute([[
            UPDATE supply_delivery_tracking 
            SET containers_loaded = ?, updated_at = NOW() 
            WHERE order_id = ?
        ]], {delivery.containersLoaded, delivery.orderId})
        
    elseif data.status == "in_transit" then
        order.status = "in_transit"
        delivery.departureTime = os.time()
        
    elseif data.status == "arrived" then
        order.status = "delivering"
        delivery.arrivalTime = os.time()
    end
    
    -- Notify restaurant
    NotifyRestaurant(order.restaurantId, {
        orderId = order.id,
        status = order.status,
        eta = CalculateETA(delivery, order)
    })
end)

-- Deliver container (updates stock)
RegisterNetEvent(Constants.Events.Server.DeliverContainer)
AddEventHandler(Constants.Events.Server.DeliverContainer, function(data)
    local source = source
    local delivery = ActiveDeliveries[source]
    if not delivery then return end
    
    local order = ActiveOrders[delivery.orderId]
    if not order then return end
    
    -- Update delivered count
    delivery.containersDelivered = data.progress.delivered
    order.containersDelivered = data.progress.delivered
    
    -- Update restaurant stock for items in this container
    local containerData = data.containerData
    if containerData and containerData.items then
        for _, item in ipairs(containerData.items) do
            StateManager.UpdateRestaurantStock(order.restaurantId, item.name, item.quantity)
            
            -- Log stock update
            exports.oxmysql:execute([[
                INSERT INTO supply_stock_updates 
                (restaurant_id, item_name, quantity, update_type, updated_by) 
                VALUES (?, ?, ?, 'delivery', ?)
            ]], {
                order.restaurantId,
                item.name,
                item.quantity,
                delivery.workerId
            })
        end
    end
    
    -- Notify progress
    if data.progress.delivered < data.progress.total then
        Framework.Notify(source, string.format("Container delivered (%d/%d)", 
            data.progress.delivered, data.progress.total), "success")
    end
end)

-- Complete delivery and process payment
RegisterNetEvent(Constants.Events.Server.CompleteMultiBoxDelivery)
AddEventHandler(Constants.Events.Server.CompleteMultiBoxDelivery, function(data)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end
    
    local delivery = ActiveDeliveries[source]
    if not delivery then return end
    
    local order = ActiveOrders[delivery.orderId]
    if not order then return end
    
    -- Verify all containers delivered
    if order.containersDelivered < order.totalContainers then
        Framework.Notify(source, "Not all containers were delivered!", "error")
        return
    end
    
    -- Calculate delivery time
    local deliveryTime = os.time() - delivery.startTime
    local deliveryMinutes = math.floor(deliveryTime / 60)
    
    -- Calculate payment
    local payment = CalculateDeliveryPayment({
        baseRate = Config.Rewards.delivery.base,
        containerCount = order.totalContainers,
        deliveryTime = deliveryMinutes,
        distance = CalculateDeliveryDistance(order.restaurantId),
        teamBonus = false -- TODO: Add team support
    })
    
    -- Add container handling bonus
    local containerBonus = order.totalContainers * Config.Rewards.delivery.perContainer
    payment.total = payment.total + containerBonus
    
    -- Process payment
    Framework.AddMoney(player, "bank", payment.total)
    
    -- Update order status
    order.status = "completed"
    order.deliveryEndTime = os.time()
    order.paymentAmount = payment.total
    
    -- Update database
    exports.oxmysql:execute([[
        UPDATE supply_orders 
        SET status = 'completed', 
            delivery_time = ?, 
            payment_amount = ?,
            completed_at = NOW() 
        WHERE order_id = ?
    ]], {
        deliveryMinutes,
        payment.total,
        order.id
    })
    
    -- Achievement check
    CheckDeliveryAchievements(source, {
        containersDelivered = order.totalContainers,
        deliveryTime = deliveryMinutes,
        payment = payment.total
    })
    
    -- Send detailed notification
    TriggerClientEvent("SupplyChain:Client:DeliveryComplete", source, {
        orderId = order.id,
        restaurant = Config.Restaurants[order.restaurantId].name,
        payment = payment,
        stats = {
            containers = order.totalContainers,
            items = order.totalItems,
            time = deliveryMinutes .. " minutes"
        }
    })
    
    -- Cleanup
    ActiveDeliveries[source] = nil
    
    -- Archive order after delay
    SetTimeout(300000, function() -- 5 minutes
        ActiveOrders[order.id] = nil
    end)
    
    print(string.format("^2[SupplyChain]^7 Delivery completed: %s (%d containers, $%d payment)", 
        order.id, order.totalContainers, payment.total))
end)

-- Helper Functions

function GetWarehouseWorkers()
    local workers = {}
    local players = Framework.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local player = Framework.GetPlayer(playerId)
        if player then
            local job = Framework.GetJob(player)
            if job == Config.Warehouse.warehouseJob then
                table.insert(workers, playerId)
            end
        end
    end
    
    return workers
end

function GetPlayerWarehouseId(source)
    -- For now, return first warehouse
    -- TODO: Add warehouse assignment system
    for warehouseId, _ in pairs(Config.Warehouses) do
        return warehouseId
    end
end

function NotifyRestaurant(restaurantId, data)
    local players = Framework.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local player = Framework.GetPlayer(playerId)
        if player then
            local job = Framework.GetJob(player)
            if job == restaurantId then
                TriggerClientEvent("SupplyChain:Client:OrderUpdate", playerId, data)
            end
        end
    end
end

function CalculateETA(delivery, order)
    if not delivery.departureTime then
        return "Preparing"
    end
    
    local elapsed = os.time() - delivery.departureTime
    local estimatedTotal = 600 -- 10 minutes estimate
    local remaining = math.max(0, estimatedTotal - elapsed)
    
    return string.format("%d minutes", math.ceil(remaining / 60))
end

function CalculateDeliveryDistance(restaurantId)
    -- Simple distance calculation
    -- TODO: Implement actual distance calculation
    return 2500 -- Default 2.5km
end

function CalculateDeliveryPayment(data)
    local payment = {
        base = data.baseRate,
        distance = math.floor(data.distance * 0.01), -- $0.01 per meter
        containers = data.containerCount * 25, -- $25 per container
        speed = 0,
        team = 0,
        total = 0
    }
    
    -- Speed bonus
    local expectedTime = data.containerCount * 5 -- 5 minutes per container
    if data.deliveryTime < expectedTime then
        payment.speed = math.floor((expectedTime - data.deliveryTime) * 10) -- $10 per minute saved
    end
    
    -- Calculate total
    payment.total = payment.base + payment.distance + payment.containers + payment.speed + payment.team
    
    return payment
end

function CheckDeliveryAchievements(source, stats)
    -- Check various achievements
    if stats.containersDelivered >= 10 then
        TriggerEvent("SupplyChain:Server:UnlockAchievement", source, "container_master")
    end
    
    if stats.deliveryTime <= 10 and stats.containersDelivered >= 5 then
        TriggerEvent("SupplyChain:Server:UnlockAchievement", source, "speed_demon")
    end
    
    if stats.payment >= 1000 then
        TriggerEvent("SupplyChain:Server:UnlockAchievement", source, "big_earner")
    end
end

-- Exports
exports('GetActiveOrders', function()
    return ActiveOrders
end)

exports('GetActiveDeliveries', function()
    return ActiveDeliveries
end)