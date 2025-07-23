-- Warehouse Menu System v2.0 - Container Orders Support

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Local state
local pendingOrders = {}
local activeDelivery = nil

-- Main warehouse menu
RegisterNetEvent("SupplyChain:Client:OpenWarehouseMenu")
AddEventHandler("SupplyChain:Client:OpenWarehouseMenu", function(data)
    local playerJob = Framework.GetJob()
    local hasAccess = false
    for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
        if playerJob == allowedJob then
            hasAccess = true
            break
        end
    end
    if not hasAccess then
        Framework.Notify(nil, "You must be a warehouse worker to access this", "error")
        return
    end
    
    -- Request latest orders from server
    TriggerServerEvent("SupplyChain:Server:RequestContainerOrders")
end)

-- Show main menu
RegisterNetEvent("SupplyChain:Client:ShowWarehouseMainMenu")
AddEventHandler("SupplyChain:Client:ShowWarehouseMainMenu", function(orders, stats)
    pendingOrders = orders or {}
    local options = {}
    
    -- Header with stats
    if stats then
        table.insert(options, {
            title = "📊 Today's Statistics",
            description = string.format("Deliveries: %d | Containers: %d | Earnings: $%d", 
                stats.deliveries or 0, stats.containers or 0, stats.earnings or 0),
            icon = "fas fa-chart-line",
            disabled = true
        })
        
        table.insert(options, {
            title = "─────────────────────",
            disabled = true
        })
    end
    
    -- View container orders
    table.insert(options, {
        title = "📦 View Container Orders",
        description = string.format("%d pending orders", #pendingOrders),
        icon = "fas fa-boxes",
        iconColor = #pendingOrders > 0 and "#4CAF50" or "#757575",
        arrow = true,
        disabled = #pendingOrders == 0,
        metadata = {
            {label = "Pending Orders", value = #pendingOrders},
            {label = "Status", value = #pendingOrders > 0 and "Available" or "No Orders"}
        },
        onSelect = function()
            ShowContainerOrders()
        end
    })
    
    -- Active delivery status
    if activeDelivery then
        table.insert(options, {
            title = "🚚 Active Delivery",
            description = string.format("Restaurant: %s | Containers: %d", 
                activeDelivery.restaurant, activeDelivery.containers),
            icon = "fas fa-truck",
            iconColor = "#FF9800",
            metadata = {
                {label = "Order ID", value = activeDelivery.orderId},
                {label = "Status", value = activeDelivery.status}
            },
            onSelect = function()
                ShowActiveDeliveryDetails()
            end
        })
    end
    
    -- Team management
    local currentTeam = exports['ogz_supplychain']:GetCurrentTeam()
    if currentTeam then
        table.insert(options, {
            title = "👥 Team Status",
            description = string.format("Team: %s | Members: %d", 
                currentTeam.name, #currentTeam.members + 1),
            icon = "fas fa-users",
            iconColor = "#2196F3",
            arrow = true,
            onSelect = function()
                ShowTeamMenu(currentTeam)
            end
        })
    else
        table.insert(options, {
            title = "👥 Create/Join Team",
            description = "Work together for bonus rewards",
            icon = "fas fa-user-plus",
            arrow = true,
            onSelect = function()
                ShowTeamCreationMenu()
            end
        })
    end
    
    -- Vehicle management
    table.insert(options, {
        title = "🚐 Vehicle Management",
        description = "Spawn or return delivery vehicles",
        icon = "fas fa-truck-loading",
        arrow = true,
        onSelect = function()
            ShowVehicleMenu()
        end
    })
    
    -- Container inventory
    table.insert(options, {
        title = "📦 Container Inventory",
        description = "Check available container types",
        icon = "fas fa-warehouse",
        arrow = true,
        onSelect = function()
            ShowContainerInventory()
        end
    })
    
    -- Training/Help
    table.insert(options, {
        title = "❓ Delivery Guide",
        description = "Learn about the delivery process",
        icon = "fas fa-question-circle",
        onSelect = function()
            ShowDeliveryGuide()
        end
    })
    
    lib.registerContext({
        id = "warehouse_main_menu",
        title = "🏭 Warehouse Management",
        options = options
    })
    
    lib.showContext("warehouse_main_menu")
end)

-- Container orders menu
function ShowContainerOrders()
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        menu = "warehouse_main_menu"
    })
    
    if #pendingOrders == 0 then
        table.insert(options, {
            title = "No pending orders",
            description = "Check back later for new orders",
            icon = "fas fa-inbox",
            disabled = true
        })
    else
        -- Group orders by restaurant
        local ordersByRestaurant = {}
        for _, order in ipairs(pendingOrders) do
            local restaurantId = order.restaurantId
            if not ordersByRestaurant[restaurantId] then
                ordersByRestaurant[restaurantId] = {
                    orders = {},
                    totalContainers = 0,
                    totalItems = 0,
                    restaurant = Config.Restaurants[restaurantId]
                }
            end
            table.insert(ordersByRestaurant[restaurantId].orders, order)
            ordersByRestaurant[restaurantId].totalContainers = 
                ordersByRestaurant[restaurantId].totalContainers + order.totalContainers
            ordersByRestaurant[restaurantId].totalItems = 
                ordersByRestaurant[restaurantId].totalItems + order.totalItems
        end
        
        -- Display grouped orders
        for restaurantId, data in pairs(ordersByRestaurant) do
            local restaurant = data.restaurant
            if restaurant then
                -- Calculate estimated payment
                local estimatedPay = CalculateEstimatedPayment(data.totalContainers)
                
                table.insert(options, {
                    title = string.format("🍔 %s", restaurant.name),
                    description = string.format("%d orders | %d containers | %d items", 
                        #data.orders, data.totalContainers, data.totalItems),
                    icon = "fas fa-store",
                    iconColor = GetRestaurantColor(restaurantId),
                    arrow = true,
                    metadata = {
                        {label = "Total Containers", value = data.totalContainers},
                        {label = "Total Items", value = data.totalItems},
                        {label = "Est. Payment", value = "$" .. estimatedPay},
                        {label = "Distance", value = CalculateDistance(restaurant.delivery) .. "m"}
                    },
                    onSelect = function()
                        ShowRestaurantOrders(restaurantId, data)
                    end
                })
            end
        end
        
        -- Sort by priority/urgency
        table.insert(options, {
            title = "─────────────────────",
            disabled = true
        })
        
        table.insert(options, {
            title = "🚨 View Urgent Orders",
            description = "Orders that need immediate attention",
            icon = "fas fa-exclamation-triangle",
            iconColor = "#F44336",
            onSelect = function()
                ShowUrgentOrders()
            end
        })
    end
    
    lib.registerContext({
        id = "warehouse_container_orders",
        title = "📦 Container Orders",
        menu = "warehouse_main_menu",
        options = options
    })
    
    lib.showContext("warehouse_container_orders")
end

-- Show orders for specific restaurant
function ShowRestaurantOrders(restaurantId, data)
    local options = {}
    local restaurant = data.restaurant
    
    -- Back button
    table.insert(options, {
        title = "← Back to Orders",
        icon = "fas fa-arrow-left",
        menu = "warehouse_container_orders"
    })
    
    -- Restaurant info
    table.insert(options, {
        title = "📍 " .. restaurant.name,
        description = "Delivery Location",
        icon = "fas fa-map-marker-alt",
        disabled = true,
        metadata = {
            {label = "Address", value = GetStreetName(restaurant.delivery)},
            {label = "Distance", value = CalculateDistance(restaurant.delivery) .. "m"}
        }
    })
    
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    -- List individual orders
    for i, order in ipairs(data.orders) do
        local orderAge = GetOrderAge(order.orderTime)
        local priority = GetOrderPriority(order, orderAge)
        
        -- Build container summary
        local containerSummary = {}
        for _, container in ipairs(order.containers) do
            local containerInfo = Config.Containers.types[container.type]
            table.insert(containerSummary, string.format("%dx %s", 
                container.count, containerInfo.name))
        end
        
        -- Build item preview
        local itemPreview = {}
        local itemCount = 0
        for _, item in ipairs(order.items) do
            itemCount = itemCount + 1
            if itemCount <= 3 then
                table.insert(itemPreview, string.format("%dx %s", 
                    item.quantity, item.label))
            end
        end
        if itemCount > 3 then
            table.insert(itemPreview, string.format("... and %d more items", itemCount - 3))
        end
        
        table.insert(options, {
            title = string.format("%s Order #%d", GetPriorityIcon(priority), i),
            description = table.concat(containerSummary, " | "),
            icon = "fas fa-clipboard-list",
            iconColor = GetPriorityColor(priority),
            metadata = {
                {label = "Order ID", value = order.id},
                {label = "Items", value = table.concat(itemPreview, ", ")},
                {label = "Age", value = orderAge},
                {label = "Priority", value = priority}
            },
            onSelect = function()
                ShowOrderDetails(order)
            end
        })
    end
    
    -- Accept all orders button
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    table.insert(options, {
        title = "✅ Accept All Orders",
        description = string.format("Start delivery for %d containers", data.totalContainers),
        icon = "fas fa-check-circle",
        iconColor = "#4CAF50",
        onSelect = function()
            local confirmInput = lib.inputDialog("Confirm Delivery", {
                {
                    type = "checkbox",
                    label = string.format("I understand I need to deliver %d containers to %s", 
                        data.totalContainers, restaurant.name),
                    required = true
                }
            })
            
            if confirmInput and confirmInput[1] then
                AcceptRestaurantOrders(restaurantId, data.orders)
            end
        end
    })
    
    lib.registerContext({
        id = "warehouse_restaurant_orders",
        title = "📦 " .. restaurant.name .. " Orders",
        menu = "warehouse_container_orders",
        options = options
    })
    
    lib.showContext("warehouse_restaurant_orders")
end

-- Show detailed order information
function ShowOrderDetails(order)
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        menu = "warehouse_restaurant_orders"
    })
    
    -- Order header
    table.insert(options, {
        title = "📋 Order Details",
        description = "Order ID: " .. order.id,
        icon = "fas fa-info-circle",
        disabled = true,
        metadata = {
            {label = "Created", value = GetFormattedTime(order.orderTime)},
            {label = "Status", value = order.status},
            {label = "Total Value", value = "$" .. order.totalCost}
        }
    })
    
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    -- Container breakdown
    table.insert(options, {
        title = "📦 Container Requirements",
        icon = "fas fa-boxes",
        disabled = true
    })
    
    for _, container in ipairs(order.containers) do
        local containerInfo = Config.Containers.types[container.type]
        local itemList = {}
        
        for _, item in ipairs(container.items) do
            table.insert(itemList, string.format("%dx %s", item.quantity, item.label))
        end
        
        table.insert(options, {
            title = string.format("  %s x%d", containerInfo.name, container.count),
            description = "Contents: " .. table.concat(itemList, ", "),
            icon = "fas fa-box",
            disabled = true,
            metadata = {
                {label = "Container Cost", value = "$" .. containerInfo.cost},
                {label = "Temperature", value = GetTemperatureRange(containerInfo)},
                {label = "Capacity", value = containerInfo.capacity .. " items"}
            }
        })
    end
    
    -- Accept single order
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    table.insert(options, {
        title = "✅ Accept This Order",
        description = string.format("Deliver %d containers", order.totalContainers),
        icon = "fas fa-check",
        iconColor = "#4CAF50",
        onSelect = function()
            AcceptSingleOrder(order)
        end
    })
    
    lib.registerContext({
        id = "warehouse_order_details",
        title = "Order #" .. order.id,
        menu = "warehouse_restaurant_orders",
        options = options
    })
    
    lib.showContext("warehouse_order_details")
end

-- Accept orders
function AcceptRestaurantOrders(restaurantId, orders)
    -- Check if already in delivery
    if exports['ogz_supplychain']:IsInDelivery() then
        Framework.Notify(nil, "You already have an active delivery", "error")
        return
    end
    
    -- Prepare consolidated order data
    local consolidatedOrder = {
        orderId = "MULTI_" .. os.time(),
        restaurantId = restaurantId,
        orders = orders,
        totalContainers = 0,
        totalItems = 0,
        containers = {}
    }
    
    -- Consolidate containers
    local containerGroups = {}
    for _, order in ipairs(orders) do
        consolidatedOrder.totalItems = consolidatedOrder.totalItems + order.totalItems
        
        for _, container in ipairs(order.containers) do
            if not containerGroups[container.type] then
                containerGroups[container.type] = {
                    type = container.type,
                    count = 0,
                    items = {}
                }
            end
            containerGroups[container.type].count = 
                containerGroups[container.type].count + container.count
            
            -- Merge items
            for _, item in ipairs(container.items) do
                table.insert(containerGroups[container.type].items, item)
            end
        end
    end
    
    -- Convert to array
    for _, containerData in pairs(containerGroups) do
        table.insert(consolidatedOrder.containers, containerData)
        consolidatedOrder.totalContainers = 
            consolidatedOrder.totalContainers + containerData.count
    end
    
    -- Send to server
    TriggerServerEvent("SupplyChain:Server:AcceptMultipleOrders", consolidatedOrder)
    
    lib.hideContext()
end

function AcceptSingleOrder(order)
    if exports['ogz_supplychain']:IsInDelivery() then
        Framework.Notify(nil, "You already have an active delivery", "error")
        return
    end
    
    TriggerServerEvent("SupplyChain:Server:AcceptWarehouseOrder", order.id)
    lib.hideContext()
end

-- Helper functions
function CalculateEstimatedPayment(containerCount)
    local base = Config.Rewards.delivery.base or 100
    local perContainer = Config.Rewards.delivery.perContainer or 25
    return base + (containerCount * perContainer)
end

function CalculateDistance(position)
    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(playerPos - position)
    return math.floor(distance)
end

function GetRestaurantColor(restaurantId)
    local colors = {
        burgershot = "#FF6B00",
        pizzathis = "#FF0000",
        tacofarmer = "#00FF00",
        noodleexchange = "#FFD700"
    }
    return colors[restaurantId] or "#2196F3"
end

function GetOrderAge(orderTime)
    local currentTime = os.time()
    local age = currentTime - orderTime
    
    if age < 300 then -- 5 minutes
        return "New"
    elseif age < 900 then -- 15 minutes
        return math.floor(age / 60) .. " min"
    elseif age < 3600 then -- 1 hour
        return math.floor(age / 60) .. " min"
    else
        return math.floor(age / 3600) .. " hours"
    end
end

function GetOrderPriority(order, age)
    if order.priority == "emergency" then
        return "🚨 Emergency"
    elseif age == "New" then
        return "🟢 Normal"
    elseif string.find(age, "hour") then
        return "🔴 Urgent"
    elseif tonumber(string.match(age, "(%d+)")) > 30 then
        return "🟡 High"
    else
        return "🟢 Normal"
    end
end

function GetPriorityIcon(priority)
    if string.find(priority, "Emergency") then return "🚨"
    elseif string.find(priority, "Urgent") then return "🔴"
    elseif string.find(priority, "High") then return "🟡"
    else return "🟢" end
end

function GetPriorityColor(priority)
    if string.find(priority, "Emergency") then return "#FF0000"
    elseif string.find(priority, "Urgent") then return "#FF4444"
    elseif string.find(priority, "High") then return "#FFA500"
    else return "#4CAF50" end
end

function GetStreetName(coords)
    local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetName)
end

function GetFormattedTime(timestamp)
    return os.date("%H:%M", timestamp)
end

function GetTemperatureRange(containerInfo)
    if containerInfo.temperature then
        return string.format("%d°C to %d°C", 
            containerInfo.temperature.ideal.min, 
            containerInfo.temperature.ideal.max)
    end
    return "Ambient"
end

function ShowActiveDeliveryDetails()
    -- TODO: Show active delivery progress
    Framework.Notify(nil, "Active delivery details coming soon", "info")
end

function ShowTeamMenu(team)
    -- TODO: Team management menu
    Framework.Notify(nil, "Team menu coming soon", "info")
end

function ShowTeamCreationMenu()
    -- TODO: Team creation menu
    Framework.Notify(nil, "Team creation coming soon", "info")
end

function ShowVehicleMenu()
    -- TODO: Vehicle management menu
    Framework.Notify(nil, "Vehicle menu coming soon", "info")
end

function ShowContainerInventory()
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        menu = "warehouse_main_menu"
    })
    
    -- Show each container type
    for containerType, containerInfo in pairs(Config.Containers.types) do
        table.insert(options, {
            title = containerInfo.name,
            description = containerInfo.description or "Standard container",
            icon = "fas fa-box",
            disabled = true,
            metadata = {
                {label = "Capacity", value = containerInfo.capacity .. " items"},
                {label = "Cost", value = "$" .. containerInfo.cost},
                {label = "Temperature", value = GetTemperatureRange(containerInfo)}
            }
        })
    end
    
    lib.registerContext({
        id = "warehouse_container_inventory",
        title = "📦 Container Types",
        menu = "warehouse_main_menu",
        options = options
    })
    
    lib.showContext("warehouse_container_inventory")
end

function ShowDeliveryGuide()
    lib.alertDialog({
        header = 'Delivery Process Guide',
        content = [[
**Multi-Container Delivery System**

1. **Accept Orders**: Review pending orders and their container requirements
2. **Spawn Vehicle**: Get your delivery van from the vehicle menu
3. **Load Containers**: Pick up the exact number of containers from pallets
4. **Secure Load**: Place all containers in the van before departing
5. **Deliver**: Drive to restaurant and unload each container
6. **Complete**: Return van to warehouse for payment

**Tips:**
- Group orders by restaurant for efficiency
- Check container types for proper handling
- Containers can hold max 12 items each
- Payment only after van is returned
        ]],
        centered = true,
        cancel = false
    })
end

-- Server response handlers
RegisterNetEvent("SupplyChain:Server:SendContainerOrders")
AddEventHandler("SupplyChain:Server:SendContainerOrders", function(orders, stats)
    TriggerEvent("SupplyChain:Client:ShowWarehouseMainMenu", orders, stats)
end)

-- Export menu trigger
exports('OpenWarehouseMenu', function()
    TriggerEvent("SupplyChain:Client:OpenWarehouseMenu")
end)