-- ============================================
-- MODULAR WAREHOUSE CONTAINER INTEGRATION
-- sv_warehouse_containers.lua (NEW SEPARATE FILE)
-- This file enhances existing warehouse functionality with containers
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- CONTAINER-ENHANCED WAREHOUSE FUNCTIONS
-- ============================================

-- Check if container system is enabled
local function isContainerSystemEnabled()
    return Config.DynamicContainers and Config.DynamicContainers.enabled
end

-- Enhanced order processing with container creation
local function processWarehouseOrderWithContainers(orderGroupId, restaurantId, orders)
    if not isContainerSystemEnabled() then
        -- Fall back to original system
        TriggerEvent('warehouse:processOrderOriginal', orderGroupId, restaurantId, orders)
        return
    end
    
    local containers = {}
    local totalContainerCost = 0
    local containerCreationSuccess = true
    
    -- Process each order item and create containers
    for _, order in ipairs(orders) do
        local ingredient = order.itemName:lower()
        local quantity = order.quantity
        
        -- Create containers (max 12 items per container, no mixing)
        while quantity > 0 and containerCreationSuccess do
            local containerQuantity = math.min(quantity, Config.DynamicContainers.system.maxItemsPerContainer)
            
            -- Use the container creation export
            local containerId = exports[GetCurrentResourceName()]:createContainer(
                ingredient, containerQuantity, orderGroupId, restaurantId
            )
            
            if containerId then
                table.insert(containers, {
                    containerId = containerId,
                    ingredient = ingredient,
                    quantity = containerQuantity,
                    orderItemId = order.id
                })
                
                -- Calculate container cost
                local containerType = determineOptimalContainer(ingredient, containerQuantity)
                local containerConfig = Config.DynamicContainers.containerTypes[containerType]
                totalContainerCost = totalContainerCost + (containerConfig and containerConfig.cost or 15)
                
                quantity = quantity - containerQuantity
            else
                print("[WAREHOUSE CONTAINERS] Failed to create container for " .. ingredient)
                containerCreationSuccess = false
                break
            end
        end
        
        if not containerCreationSuccess then break end
    end
    
    if containerCreationSuccess then
        -- Load containers into delivery vehicle
        exports[GetCurrentResourceName()]:loadContainersIntoVehicle(orderGroupId)
        
        -- Trigger enhanced vehicle spawn
        TriggerEvent('warehouse:spawnContainerVehicle', orderGroupId, restaurantId, orders, containers, totalContainerCost)
    else
        -- Cleanup any created containers and fall back to original system
        for _, container in ipairs(containers) do
            MySQL.Async.execute('DELETE FROM supply_containers WHERE container_id = ?', {container.containerId})
        end
        TriggerEvent('warehouse:processOrderOriginal', orderGroupId, restaurantId, orders)
    end
end

-- Determine optimal container type for ingredient
local function determineOptimalContainer(ingredient, quantity)
    if not Config.DynamicContainers or not Config.DynamicContainers.containerTypes then
        return "ogz_crate" -- Default fallback
    end
    
    local containerTypes = Config.DynamicContainers.containerTypes
    local bestContainer = nil
    local bestScore = 0
    
    for containerType, config in pairs(containerTypes) do
        local score = 0
        
        -- Check if ingredient is suitable for this container
        local isSuitable = false
        
        -- Check exact item match
        if config.suitableItems then
            for _, suitableItem in ipairs(config.suitableItems) do
                if ingredient:lower() == suitableItem:lower() then
                    isSuitable = true
                    score = score + 100 -- High score for exact match
                    break
                end
            end
        end
        
        -- Check category match if no exact item match
        if not isSuitable and config.suitableCategories then
            local ingredientCategory = getIngredientCategory(ingredient)
            for _, category in ipairs(config.suitableCategories) do
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
            local containerInventory = exports[GetCurrentResourceName()]:getContainerInventory()
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
    
    return bestContainer or Config.DynamicContainers.autoSelection.fallbackContainer or "ogz_crate"
end

-- Get ingredient category for container selection
local function getIngredientCategory(ingredient)
    local categoryMappings = {
        -- Meat products
        ["slaughter_meat"] = "meat", ["slaughter_ground_meat"] = "meat", 
        ["slaughter_chicken"] = "meat", ["slaughter_pork"] = "meat", ["slaughter_beef"] = "meat",
        
        -- Dairy products
        ["milk"] = "dairy", ["cheese"] = "dairy", ["butter"] = "dairy",
        
        -- Vegetables
        ["tomato"] = "vegetables", ["lettuce"] = "vegetables", ["onion"] = "vegetables", 
        ["potato"] = "vegetables", ["carrot"] = "vegetables",
        
        -- Fruits
        ["apple"] = "fruits", ["orange"] = "fruits", ["banana"] = "fruits",
        
        -- Frozen items
        ["frozen_beef"] = "frozen", ["frozen_chicken"] = "frozen", ["ice_cream"] = "frozen",
        
        -- Dry goods
        ["flour"] = "dry_goods", ["sugar"] = "dry_goods", ["rice"] = "dry_goods"
    }
    
    return categoryMappings[ingredient:lower()] or "dry_goods"
end

-- ============================================
-- EVENT HANDLERS FOR CONTAINER INTEGRATION
-- ============================================

-- Enhanced accept order with container logic
RegisterNetEvent('warehouse:acceptOrderWithContainers')
AddEventHandler('warehouse:acceptOrderWithContainers', function(orderGroupId, restaurantId)
    local workerId = source
    
    -- Check warehouse access (reuse existing function from main warehouse file)
    if not hasWarehouseAccess or not hasWarehouseAccess(workerId) then
        TriggerClientEvent('ox_lib:notify', workerId, {
            title = 'Access Denied',
            description = 'Warehouse access required.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Get order details
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE order_group_id = ?', {orderGroupId}, function(orderResults)
        if not orderResults or #orderResults == 0 then
            TriggerClientEvent('ox_lib:notify', workerId, {
                title = 'Error',
                description = 'Order not found or already processed.',
                type = 'error',
                duration = 10000
            })
            return
        end

        local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
        if not restaurantJob then
            TriggerClientEvent('ox_lib:notify', workerId, {
                title = 'Error',
                description = 'Invalid restaurant ID.',
                type = 'error',
                duration = 10000
            })
            return
        end

        local orders = {}
        local stockQueries = {}
        
        -- Validate all orders and check stock
        for _, order in ipairs(orderResults) do
            local ingredient = order.ingredient:lower()
            local itemData = nil
            
            -- Find item in restaurant config
            if Config.Items[restaurantJob] then
                for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                    if categoryItems[ingredient] then
                        itemData = categoryItems[ingredient]
                        break
                    end
                end
            end
            
            if not itemData then
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Error',
                    description = 'Item not found: ' .. ingredient,
                    type = 'error',
                    duration = 10000
                })
                return
            end

            -- Check warehouse stock
            local stockResults = MySQL.Sync.fetchAll('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', {ingredient})
            if not stockResults or #stockResults == 0 or stockResults[1].quantity < order.quantity then
                local itemNames = exports.ox_inventory:Items() or {}
                local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
                
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Insufficient Stock',
                    description = 'Not enough stock for **' .. itemLabel .. '**',
                    type = 'error',
                    duration = 10000
                })
                return
            end

            table.insert(orders, {
                id = order.id,
                orderGroupId = order.order_group_id,
                ownerId = order.owner_id,
                itemName = ingredient,
                quantity = order.quantity,
                totalCost = order.total_cost,
                restaurantId = order.restaurant_id
            })
            
            -- Prepare stock update queries
            table.insert(stockQueries, {
                query = 'UPDATE supply_warehouse_stock SET quantity = quantity - ? WHERE ingredient = ?',
                values = {order.quantity, ingredient}
            })
            table.insert(stockQueries, {
                query = 'UPDATE supply_orders SET status = ? WHERE id = ?',
                values = {'accepted', order.id}
            })
        end

        -- Execute stock updates
        MySQL.Async.transaction(stockQueries, function(success)
            if success then
                -- Process order with container system
                processWarehouseOrderWithContainers(orderGroupId, restaurantId, orders)
                
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = '📦 Container Order Accepted',
                    description = 'Order accepted! Preparing containers for delivery...',
                    type = 'success',
                    duration = 10000
                })
            else
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Error',
                    description = 'Failed to process order.',
                    type = 'error',
                    duration = 10000
                })
            end
        end)
    end)
end)

-- Enhanced vehicle spawning with container data
RegisterNetEvent('warehouse:spawnContainerVehicle')
AddEventHandler('warehouse:spawnContainerVehicle', function(orderGroupId, restaurantId, orders, containers, containerCost)
    local workerId = source
    
    -- Calculate total boxes from containers
    local totalBoxes = #containers
    
    -- Enhance orders with container information
    for _, order in ipairs(orders) do
        order.containerDelivery = true
        order.totalBoxes = totalBoxes
        order.containerCost = containerCost
    end
    
    -- Trigger enhanced client vehicle spawn
    TriggerClientEvent('warehouse:spawnVehiclesWithContainers', workerId, restaurantId, orders, containers)
end)

-- Enhanced delivery completion with container processing
RegisterNetEvent('update:stockWithContainers')
AddEventHandler('update:stockWithContainers', function(restaurantId, orders)
    local src = source
    
    if not restaurantId or not orders or #orders == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid delivery data.',
            type = 'error',
            duration = 10000
        })
        return
    end

    local orderGroupId = orders[1].orderGroupId
    local queries = {}
    local totalCost = 0
    
    -- Process each order
    for _, order in ipairs(orders) do
        local ingredient = order.itemName:lower()
        local quantity = tonumber(order.quantity)
        local orderCost = order.totalCost or 0
        
        if ingredient and quantity then
            table.insert(queries, {
                query = 'UPDATE supply_orders SET status = ? WHERE id = ? AND order_group_id = ?',
                values = {'completed', order.id, orderGroupId}
            })
            table.insert(queries, {
                query = 'INSERT INTO supply_stock (restaurant_id, ingredient, quantity) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + ?',
                values = {restaurantId, ingredient, quantity, quantity}
            })
            
            totalCost = totalCost + orderCost
        end
    end

    MySQL.Async.transaction(queries, function(success)
        if success then
            -- Complete container delivery to restaurant
            exports[GetCurrentResourceName()]:completeContainerDelivery(orderGroupId, restaurantId)
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📦 Container Delivery Complete',
                description = 'Containers delivered to restaurant! Restaurant staff can now open containers.',
                type = 'success',
                duration = 12000
            })
            
            -- Calculate enhanced delivery rewards
            local xPlayer = QBCore.Functions.GetPlayer(src)
            if xPlayer then
                local deliveryTime = orders[1].deliveryTime or 900
                local totalBoxes = #orders
                
                -- Enhanced reward calculation with container bonuses
                TriggerEvent('rewards:calculateDeliveryRewardWithContainers', src, {
                    basePay = totalCost * (Config.DriverPayPrec or 0.5),
                    deliveryTime = deliveryTime,
                    boxes = totalBoxes,
                    orderGroupId = orderGroupId,
                    totalCost = totalCost,
                    isPerfect = deliveryTime < 1200,
                    containerDelivery = true,
                    containerQuality = {
                        averageQuality = 95.0, -- This would come from vehicle tracking
                    },
                    containerOptimization = {
                        perfectMatch = true,
                        temperatureControlMaintained = true,
                        handlingScore = 95
                    },
                    preservationData = {
                        qualityLoss = 5.0,
                        temperatureBreaches = 0
                    }
                })
                
                -- Track performance for leaderboard
                TriggerEvent('leaderboard:trackDelivery', src, {
                    boxes = totalBoxes,
                    deliveryTime = deliveryTime,
                    earnings = totalCost * (Config.DriverPayPrec or 0.5),
                    isPerfect = deliveryTime < 1200
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Failed to complete delivery.',
                type = 'error',
                duration = 10000
            })
        end
    end)
end)

-- Intercept original warehouse events to route through container system
RegisterNetEvent('warehouse:acceptOrder')
AddEventHandler('warehouse:acceptOrder', function(orderGroupId, restaurantId)
    if isContainerSystemEnabled() then
        -- Route through container system
        TriggerEvent('warehouse:acceptOrderWithContainers', orderGroupId, restaurantId)
    else
        -- Route through original system
        TriggerEvent('warehouse:acceptOrderOriginal', orderGroupId, restaurantId)
    end
end)

RegisterNetEvent('update:stock')
AddEventHandler('update:stock', function(restaurantId, orders)
    if isContainerSystemEnabled() then
        -- Route through container system
        TriggerEvent('update:stockWithContainers', restaurantId, orders)
    else
        -- Route through original system
        TriggerEvent('update:stockOriginal', restaurantId, orders)
    end
end)

-- Enhanced pending orders with container information
RegisterNetEvent('warehouse:getPendingOrdersWithContainers')
AddEventHandler('warehouse:getPendingOrdersWithContainers', function()
    local playerId = source
    
    if not hasWarehouseAccess or not hasWarehouseAccess(playerId) then
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE status = ?', {'pending'}, function(results)
        if not results then return end
        
        local ordersByGroup = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, order in ipairs(results) do
            local restaurantJob = Config.Restaurants[order.restaurant_id] and Config.Restaurants[order.restaurant_id].job
            if restaurantJob then
                local itemKey = order.ingredient:lower()
                local item = nil
                
                -- Find item in restaurant config
                if Config.Items[restaurantJob] then
                    for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                        if categoryItems[itemKey] then
                            item = categoryItems[itemKey]
                            break
                        end
                    end
                end
                
                if item then
                    local orderGroupId = order.order_group_id or tostring(order.id)
                    if not ordersByGroup[orderGroupId] then
                        ordersByGroup[orderGroupId] = {
                            orderGroupId = orderGroupId,
                            id = order.id,
                            ownerId = order.owner_id,
                            restaurantId = order.restaurant_id,
                            totalCost = 0,
                            items = {},
                            containerInfo = {
                                totalContainers = 0,
                                totalCost = 0,
                                breakdown = {}
                            }
                        }
                    end
                    
                    local itemLabel = itemNames[itemKey] and itemNames[itemKey].label or item.label or itemKey
                    
                    table.insert(ordersByGroup[orderGroupId].items, {
                        id = order.id,
                        itemName = itemKey,
                        itemLabel = itemLabel,
                        quantity = order.quantity,
                        totalCost = order.total_cost
                    })
                    
                    ordersByGroup[orderGroupId].totalCost = ordersByGroup[orderGroupId].totalCost + order.total_cost
                    
                    -- Calculate container requirements if container system enabled
                    if isContainerSystemEnabled() then
                        local containersNeeded = math.ceil(order.quantity / Config.DynamicContainers.system.maxItemsPerContainer)
                        local containerType = determineOptimalContainer(itemKey, order.quantity)
                        local containerConfig = Config.DynamicContainers.containerTypes[containerType]
                        local containerCost = containerConfig and containerConfig.cost or 15
                        
                        ordersByGroup[orderGroupId].containerInfo.totalContainers = 
                            ordersByGroup[orderGroupId].containerInfo.totalContainers + containersNeeded
                        ordersByGroup[orderGroupId].containerInfo.totalCost = 
                            ordersByGroup[orderGroupId].containerInfo.totalCost + (containerCost * containersNeeded)
                        
                        table.insert(ordersByGroup[orderGroupId].containerInfo.breakdown, {
                            ingredient = itemKey,
                            containers = containersNeeded,
                            containerType = containerType,
                            cost = containerCost * containersNeeded
                        })
                    end
                end
            end
        end
        
        local orders = {}
        for _, orderGroup in pairs(ordersByGroup) do
            table.insert(orders, orderGroup)
        end
        
        TriggerClientEvent('warehouse:showOrderDetails', playerId, orders)
    end)
end)

-- Intercept original pending orders request
RegisterNetEvent('warehouse:getPendingOrders')
AddEventHandler('warehouse:getPendingOrders', function()
    if isContainerSystemEnabled() then
        TriggerEvent('warehouse:getPendingOrdersWithContainers')
    else
        TriggerEvent('warehouse:getPendingOrdersOriginal')
    end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isContainerSystemEnabled() then
            print("[WAREHOUSE CONTAINERS] Container-enhanced warehouse system loaded!")
            print("[WAREHOUSE CONTAINERS] Intercepting warehouse events for container processing")
        else
            print("[WAREHOUSE CONTAINERS] Container system disabled - using original warehouse logic")
        end
    end
end)

-- Export functions for integration
exports('processWarehouseOrderWithContainers', processWarehouseOrderWithContainers)
exports('determineOptimalContainer', determineOptimalContainer)
exports('isContainerSystemEnabled', isContainerSystemEnabled)

print("[WAREHOUSE CONTAINERS] Warehouse container integration loaded successfully!")