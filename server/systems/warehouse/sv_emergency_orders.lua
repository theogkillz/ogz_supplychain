-- Advanced Emergency Order System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Emergency order tracking
local emergencyOrders = {}
local activeAlerts = {}
local lastEmergencyCheck = 0

-- Initialize emergency system
CreateThread(function()
    if not Config.EmergencyOrders.enabled then return end
    
    -- Start monitoring
    StartEmergencyMonitoring()
    
    -- Load existing emergency orders
    LoadEmergencyOrders()
    
    print("^2[SupplyChain]^7 Emergency order system initialized")
end)

-- Load emergency orders from database
function LoadEmergencyOrders()
    MySQL.Async.fetchAll([[
        SELECT * FROM supply_emergency_orders 
        WHERE completed = 0 AND (expires_at IS NULL OR expires_at > NOW())
    ]], {}, function(results)
        for _, order in ipairs(results) do
            emergencyOrders[order.order_id] = {
                id = order.order_id,
                ingredient = order.ingredient,
                quantity = order.quantity,
                priority = order.priority,
                rewardMultiplier = order.reward_multiplier,
                expiresAt = order.expires_at,
                acceptedBy = order.accepted_by,
                createdAt = order.created_at
            }
            
            StateManager.AddEmergencyOrder(order.order_id, emergencyOrders[order.order_id])
        end
        
        if #results > 0 then
            print(string.format("^2[SupplyChain]^7 Loaded %d active emergency orders", #results))
        end
    end)
end

-- Start emergency monitoring
function StartEmergencyMonitoring()
    CreateThread(function()
        while true do
            Wait(Config.EmergencyOrders.checkInterval * 1000)
            
            CheckForEmergencyConditions()
            CheckExpiredOrders()
        end
    end)
end

-- Check for emergency conditions
function CheckForEmergencyConditions()
    local currentTime = os.time()
    
    -- Cooldown check
    if currentTime - lastEmergencyCheck < Config.EmergencyOrders.cooldown then
        return
    end
    
    -- Get current stock levels
    MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock', {}, function(stockData)
        for _, stock in ipairs(stockData) do
            local stockPercentage = (stock.quantity / (Config.Stock.stockLevels[stock.ingredient] or 1000)) * 100
            
            -- Check for stockout
            if stock.quantity <= 0 and not activeAlerts[stock.ingredient] then
                CreateEmergencyOrder(stock.ingredient, Constants.EmergencyPriority.CRITICAL, "stockout")
                activeAlerts[stock.ingredient] = currentTime
                
            -- Check for critical stock
            elseif stock.quantity <= Config.EmergencyOrders.triggers.criticalStock then
                if not activeAlerts[stock.ingredient] or 
                   currentTime - activeAlerts[stock.ingredient] > Config.EmergencyOrders.cooldown then
                    CreateEmergencyOrder(stock.ingredient, Constants.EmergencyPriority.URGENT, "critical")
                    activeAlerts[stock.ingredient] = currentTime
                end
                
            -- Check for urgent stock
            elseif stock.quantity <= Config.EmergencyOrders.triggers.urgentStock then
                if not activeAlerts[stock.ingredient] or 
                   currentTime - activeAlerts[stock.ingredient] > Config.EmergencyOrders.cooldown then
                    CreateEmergencyOrder(stock.ingredient, Constants.EmergencyPriority.HIGH, "urgent")
                    activeAlerts[stock.ingredient] = currentTime
                end
                
            -- Check for low stock
            elseif stock.quantity <= Config.Stock.lowStockThreshold then
                if not activeAlerts[stock.ingredient] or 
                   currentTime - activeAlerts[stock.ingredient] > Config.EmergencyOrders.cooldown then
                    CreateEmergencyOrder(stock.ingredient, Constants.EmergencyPriority.MEDIUM, "low")
                    activeAlerts[stock.ingredient] = currentTime
                end
            end
            
            -- Check demand surge
            CheckDemandSurge(stock.ingredient)
        end
        
        lastEmergencyCheck = currentTime
    end)
end

-- Check for demand surge
function CheckDemandSurge(ingredient)
    MySQL.Async.fetchScalar([[
        SELECT SUM(quantity) FROM supply_orders 
        WHERE ingredient = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    ]], { ingredient }, function(recentDemand)
        if recentDemand and recentDemand > Config.EmergencyOrders.triggers.demandSurge then
            -- Calculate surge multiplier
            local surgeMultiplier = recentDemand / Config.EmergencyOrders.triggers.demandSurge
            
            if surgeMultiplier > 2.0 then
                CreateEmergencyOrder(ingredient, Constants.EmergencyPriority.HIGH, "demand_surge", {
                    surgeMultiplier = surgeMultiplier,
                    recentDemand = recentDemand
                })
            end
        end
    end)
end

-- Create emergency order
function CreateEmergencyOrder(ingredient, priority, reason, extraData)
    local orderId = GenerateEmergencyOrderId()
    
    -- Calculate quantity needed
    local targetStock = Config.Stock.restockAmount or 500
    local currentStock = 0
    
    MySQL.Async.fetchScalar('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', 
        { ingredient }, function(stock)
        currentStock = stock or 0
        local quantityNeeded = math.max(50, targetStock - currentStock)
        
        -- Get priority config
        local priorityConfig = Config.EmergencyOrders.priorities[GetPriorityName(priority)]
        if not priorityConfig then
            priorityConfig = Config.EmergencyOrders.priorities.medium
        end
        
        -- Calculate reward
        local baseReward = quantityNeeded * (Config.Rewards.delivery.base.perBoxAmount or 25)
        local rewardMultiplier = priorityConfig.multiplier
        
        -- Apply surge pricing if demand surge
        if reason == "demand_surge" and extraData and extraData.surgeMultiplier then
            rewardMultiplier = rewardMultiplier * (1 + (extraData.surgeMultiplier - 1) * 0.5)
        end
        
        -- Create order data
        local orderData = {
            id = orderId,
            ingredient = ingredient,
            quantity = quantityNeeded,
            priority = priority,
            rewardMultiplier = rewardMultiplier,
            reason = reason,
            expiresAt = os.time() + priorityConfig.timeLimit,
            createdAt = os.time()
        }
        
        -- Save to database
        MySQL.Async.insert([[
            INSERT INTO supply_emergency_orders 
            (order_id, ingredient, quantity, priority, reward_multiplier, expires_at)
            VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
        ]], {
            orderId,
            ingredient,
            quantityNeeded,
            priority,
            rewardMultiplier,
            orderData.expiresAt
        }, function(insertId)
            if insertId then
                -- Track order
                emergencyOrders[orderId] = orderData
                StateManager.AddEmergencyOrder(orderId, orderData)
                
                -- Create stock alert
                CreateStockAlert(ingredient, reason, currentStock)
                
                -- Notify drivers
                NotifyEmergencyOrder(orderData)
                
                -- Trigger bonus events
                if priority >= Constants.EmergencyPriority.URGENT then
                    TriggerHeroMomentOpportunity(orderData)
                end
            end
        end)
    end)
end

-- Accept emergency order
RegisterNetEvent("SupplyChain:Server:AcceptEmergencyOrder")
AddEventHandler("SupplyChain:Server:AcceptEmergencyOrder", function(orderId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    local order = emergencyOrders[orderId]
    if not order then
        Framework.Notify(src, "Emergency order no longer available", "error")
        return
    end
    
    if order.acceptedBy then
        Framework.Notify(src, "This emergency order has already been accepted", "error")
        return
    end
    
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
        Framework.Notify(src, "You don't have access to emergency orders", "error")
        return
    end
    
    -- Mark as accepted
    order.acceptedBy = GetPlayerCitizenId(src)
    
    MySQL.Async.execute('UPDATE supply_emergency_orders SET accepted_by = ? WHERE order_id = ?', {
        order.acceptedBy,
        orderId
    })
    
    -- Create special delivery
    CreateEmergencyDelivery(src, order)
    
    -- Notify player
    Framework.Notify(src, string.format(
        "Emergency order accepted! Deliver %d %s ASAP! Reward: %dx normal rate",
        order.quantity,
        order.ingredient,
        order.rewardMultiplier
    ), "success")
    
    -- Update state
    StateManager.UpdateEmergencyOrderStatus(orderId, "accepted")
end)

-- Create emergency delivery
function CreateEmergencyDelivery(playerId, emergencyOrder)
    -- Create warehouse order
    local orderGroupId = "EMRG-" .. emergencyOrder.id
    
    MySQL.Async.insert([[
        INSERT INTO supply_orders 
        (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        "WAREHOUSE",
        emergencyOrder.ingredient,
        emergencyOrder.quantity,
        Constants.OrderStatus.ACCEPTED,
        999, -- Special ID for warehouse restocking
        0,   -- No cost for emergency
        orderGroupId
    }, function(insertId)
        if insertId then
            -- Start emergency delivery
            TriggerClientEvent("SupplyChain:Client:StartEmergencyDelivery", playerId, {
                orderGroupId = orderGroupId,
                emergencyOrder = emergencyOrder,
                timeLimit = emergencyOrder.expiresAt - os.time()
            })
            
            -- Start timer
            StartEmergencyTimer(playerId, emergencyOrder)
        end
    end)
end

-- Complete emergency order
RegisterNetEvent("SupplyChain:Server:CompleteEmergencyOrder")
AddEventHandler("SupplyChain:Server:CompleteEmergencyOrder", function(orderId, deliveryTime)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    local order = emergencyOrders[orderId]
    if not order or order.acceptedBy ~= GetPlayerCitizenId(src) then
        Framework.Notify(src, "Invalid emergency order", "error")
        return
    end
    
    -- Calculate rewards
    local baseReward = order.quantity * Config.Rewards.delivery.base.perBoxAmount
    local totalReward = baseReward * order.rewardMultiplier
    
    -- Hero bonus for preventing stockout
    local heroBonus = 0
    if order.priority == Constants.EmergencyPriority.CRITICAL then
        heroBonus = Config.EmergencyOrders.heroBonus or 1000
        totalReward = totalReward + heroBonus
    end
    
    -- Time bonus
    local timeRemaining = order.expiresAt - os.time()
    if timeRemaining > 300 then -- More than 5 minutes early
        totalReward = totalReward * 1.1
    end
    
    -- Pay player
    Framework.AddMoney(player, 'bank', math.floor(totalReward), 'Emergency delivery completion')
    
    -- Update stock
    MySQL.Async.execute([[
        UPDATE supply_warehouse_stock 
        SET quantity = quantity + ? 
        WHERE ingredient = ?
    ]], { order.quantity, order.ingredient })
    
    -- Mark as completed
    MySQL.Async.execute('UPDATE supply_emergency_orders SET completed = 1 WHERE order_id = ?', { orderId })
    
    -- Clear from active orders
    emergencyOrders[orderId] = nil
    StateManager.RemoveEmergencyOrder(orderId)
    
    -- Clear alert
    activeAlerts[order.ingredient] = nil
    
    -- Update stats
    UpdateEmergencyStats(src, order, totalReward, deliveryTime)
    
    -- Notify
    local message = string.format(
        "Emergency delivery completed!\nDelivered: %d %s\nReward: $%d",
        order.quantity,
        order.ingredient,
        math.floor(totalReward)
    )
    
    if heroBonus > 0 then
        message = message .. string.format("\nHero Bonus: $%d", heroBonus)
    end
    
    Framework.Notify(src, message, "success")
    
    -- Achievement check
    CheckEmergencyAchievements(src, order)
end)

-- Notify emergency order
function NotifyEmergencyOrder(order)
    local priorityName = GetPriorityName(order.priority)
    local priorityConfig = Config.EmergencyOrders.priorities[priorityName]
    
    -- Get all online warehouse workers
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local player = Framework.GetPlayer(tonumber(playerId))
        if player then
            local job = Framework.GetPlayerJob(player)
            for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
                if job.name == allowedJob then
                    -- Send different notifications based on priority
                    if order.priority >= Constants.EmergencyPriority.URGENT then
                        -- Critical notification with sound
                        TriggerClientEvent("SupplyChain:Client:EmergencyAlert", tonumber(playerId), {
                            type = "critical",
                            title = "🚨 EMERGENCY ORDER",
                            message = string.format(
                                "%s shortage! Need %d units ASAP!\nReward: %dx normal rate",
                                order.ingredient:upper(),
                                order.quantity,
                                order.rewardMultiplier
                            ),
                            duration = 10000,
                            order = order
                        })
                    else
                        -- Normal notification
                        Framework.Notify(tonumber(playerId), 
                            string.format("Emergency: Low %s stock. Bonus rewards available!", order.ingredient),
                            "warning"
                        )
                    end
                    break
                end
            end
        end
    end
end

-- Hero moment opportunity
function TriggerHeroMomentOpportunity(order)
    if order.priority ~= Constants.EmergencyPriority.CRITICAL then return end
    
    -- Special notification for critical stockouts
    SetTimeout(60000, function() -- After 1 minute
        if emergencyOrders[order.id] and not emergencyOrders[order.id].acceptedBy then
            -- Send urgent reminder
            local players = GetPlayers()
            for _, playerId in ipairs(players) do
                local player = Framework.GetPlayer(tonumber(playerId))
                if player then
                    local job = Framework.GetPlayerJob(player)
                    for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
                        if job.name == allowedJob then
                            TriggerClientEvent("SupplyChain:Client:HeroMoment", tonumber(playerId), {
                                ingredient = order.ingredient,
                                reward = Config.EmergencyOrders.heroBonus,
                                orderId = order.id
                            })
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- Start emergency timer
function StartEmergencyTimer(playerId, order)
    local timerId = "emergency_" .. order.id
    
    CreateThread(function()
        local startTime = os.time()
        
        while emergencyOrders[order.id] and emergencyOrders[order.id].acceptedBy do
            Wait(5000)
            
            local elapsed = os.time() - startTime
            local remaining = order.expiresAt - os.time()
            
            if remaining <= 0 then
                -- Order expired
                ExpireEmergencyOrder(order.id, playerId)
                break
            elseif remaining <= 60 then
                -- Final warning
                TriggerClientEvent("SupplyChain:Client:EmergencyWarning", playerId, {
                    timeRemaining = remaining,
                    critical = true
                })
            elseif remaining <= 300 and remaining % 60 <= 5 then
                -- Regular warnings
                TriggerClientEvent("SupplyChain:Client:EmergencyWarning", playerId, {
                    timeRemaining = remaining,
                    critical = false
                })
            end
        end
    end)
end

-- Expire emergency order
function ExpireEmergencyOrder(orderId, playerId)
    local order = emergencyOrders[orderId]
    if not order then return end
    
    -- Penalty for failure
    if playerId and Config.EmergencyOrders.failurePenalty then
        local player = Framework.GetPlayer(playerId)
        if player then
            Framework.RemoveMoney(player, 'bank', Config.EmergencyOrders.failurePenalty, 
                'Emergency order failure')
            Framework.Notify(playerId, 
                string.format("Emergency order failed! Penalty: $%d", Config.EmergencyOrders.failurePenalty),
                "error"
            )
        end
    end
    
    -- Mark as expired
    MySQL.Async.execute([[
        UPDATE supply_emergency_orders 
        SET completed = 1, expires_at = NOW() 
        WHERE order_id = ?
    ]], { orderId })
    
    -- Remove from active
    emergencyOrders[orderId] = nil
    StateManager.RemoveEmergencyOrder(orderId)
    
    -- Create new emergency if still needed
    SetTimeout(30000, function()
        CheckForEmergencyConditions()
    end)
end

-- Check expired orders
function CheckExpiredOrders()
    local currentTime = os.time()
    
    for orderId, order in pairs(emergencyOrders) do
        if order.expiresAt and currentTime > order.expiresAt then
            ExpireEmergencyOrder(orderId)
        end
    end
end

-- Create stock alert
function CreateStockAlert(ingredient, alertType, currentStock)
    MySQL.Async.insert([[
        INSERT INTO supply_stock_alerts 
        (ingredient, alert_type, current_stock, threshold)
        VALUES (?, ?, ?, ?)
    ]], {
        ingredient,
        alertType,
        currentStock,
        Config.Stock.lowStockThreshold
    })
end

-- Update emergency stats
function UpdateEmergencyStats(playerId, order, reward, deliveryTime)
    local citizenId = GetPlayerCitizenId(playerId)
    
    MySQL.Async.execute([[
        UPDATE supply_player_stats 
        SET emergency_deliveries = emergency_deliveries + 1,
            emergency_earnings = emergency_earnings + ?
        WHERE citizenid = ?
    ]], { reward, citizenId })
    
    -- Log delivery
    MySQL.Async.insert([[
        INSERT INTO supply_deliveries 
        (order_group_id, player_id, restaurant_id, total_reward, delivery_time, quality_score)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        "EMRG-" .. order.id,
        citizenId,
        999, -- Warehouse ID
        reward,
        deliveryTime,
        100 -- Perfect score for emergency
    })
end

-- Check emergency achievements
function CheckEmergencyAchievements(playerId, order)
    local citizenId = GetPlayerCitizenId(playerId)
    
    -- Check hero achievement
    if order.priority == Constants.EmergencyPriority.CRITICAL then
        TriggerEvent("SupplyChain:Server:UnlockAchievement", "warehouse_hero", playerId)
    end
    
    -- Check emergency count achievements
    MySQL.Async.fetchScalar([[
        SELECT COUNT(*) FROM supply_deliveries 
        WHERE player_id = ? AND order_group_id LIKE 'EMRG-%'
    ]], { citizenId }, function(count)
        if count >= 25 then
            TriggerEvent("SupplyChain:Server:UnlockAchievement", "emergency_expert", playerId)
        elseif count >= 10 then
            TriggerEvent("SupplyChain:Server:UnlockAchievement", "emergency_responder", playerId)
        elseif count >= 1 then
            TriggerEvent("SupplyChain:Server:UnlockAchievement", "first_emergency", playerId)
        end
    end)
end

-- Utility functions
function GenerateEmergencyOrderId()
    return string.format("EMRG-%s-%d", os.date("%Y%m%d%H%M"), math.random(1000, 9999))
end

function GetPriorityName(priority)
    local names = {
        [Constants.EmergencyPriority.LOW] = "low",
        [Constants.EmergencyPriority.MEDIUM] = "medium",
        [Constants.EmergencyPriority.HIGH] = "high",
        [Constants.EmergencyPriority.URGENT] = "urgent",
        [Constants.EmergencyPriority.CRITICAL] = "critical"
    }
    return names[priority] or "medium"
end

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

-- Export functions
exports('GetEmergencyOrders', function()
    return emergencyOrders
end)

exports('CreateEmergencyOrder', CreateEmergencyOrder)
exports('CheckEmergencyConditions', CheckForEmergencyConditions)