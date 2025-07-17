-- ============================================
-- WAREHOUSE ORDER MANAGEMENT SYSTEM
-- Order processing, validation, and acceptance
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- ORDER CALCULATION UTILITIES
-- ============================================

-- Enhanced box calculation with container logic
local function calculateDeliveryBoxes(orders)
    local totalItems = 0
    local itemsList = {}
    
    -- Handle both single orders and order groups
    if orders[1] and orders[1].items then
        -- Order group format
        for _, orderGroup in ipairs(orders) do
            for _, item in ipairs(orderGroup.items) do
                totalItems = totalItems + item.quantity
                table.insert(itemsList, item.quantity .. "x " .. item.itemName)
            end
        end
    else
        -- Single order format
        for _, order in ipairs(orders) do
            totalItems = totalItems + order.quantity
            table.insert(itemsList, order.quantity .. "x " .. (order.itemName or order.ingredient))
        end
    end
    
    local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
    local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return boxesNeeded, containersNeeded, totalItems, itemsList
end

-- ============================================
-- ORDER DISPLAY SYSTEM
-- ============================================

-- Order Details Display
RegisterNetEvent("warehouse:showOrderDetails")
AddEventHandler("warehouse:showOrderDetails", function(orders)
    if not orders or #orders == 0 then
        exports.ogz_supplychain:errorNotify(
            "No Orders",
            "There are no active orders at the moment."
        )
        return
    end

    local options = {}
    local itemNames = exports.ox_inventory:Items()
    
    for _, orderGroup in ipairs(orders) do
        local restaurantId = orderGroup.restaurantId
        local restaurantData = Config.Restaurants[restaurantId]
        local restaurantName = restaurantData and restaurantData.name or "Unknown Business"
        
        -- Calculate delivery info for this order
        local boxesNeeded, containersNeeded, totalItems = calculateDeliveryBoxes({orderGroup})
        
        -- Create description with all items in the order
        local itemList = {}
        for _, item in ipairs(orderGroup.items) do
            local itemLabel = itemNames[item.itemName:lower()] and itemNames[item.itemName:lower()].label or item.itemName
            table.insert(itemList, item.quantity .. "x " .. itemLabel)
        end
        
        -- Determine order complexity
        local complexityIcon = "📦"
        local complexityDesc = "Standard Delivery"
        if boxesNeeded >= 5 then
            complexityIcon = "🚛"
            complexityDesc = "Large Delivery"
        elseif boxesNeeded >= 8 then
            complexityIcon = "🏗️"
            complexityDesc = "Mega Delivery"
        end
        
        table.insert(options, {
            title = string.format("%s Order: %s", complexityIcon, orderGroup.orderGroupId),
            description = string.format(
                "📦 **%d boxes** (%d containers)\n🏪 **%s**\n📋 %s\n💰 **$%d**\n📊 %s", 
                boxesNeeded,
                containersNeeded,
                restaurantName, 
                table.concat(itemList, ", "), 
                orderGroup.totalCost,
                complexityDesc
            ),
            metadata = {
                ["Order ID"] = orderGroup.orderGroupId,
                ["Restaurant"] = restaurantName,
                ["Boxes Required"] = boxesNeeded .. " boxes",
                ["Containers"] = containersNeeded .. " containers",
                ["Total Items"] = totalItems .. " items",
                ["Total Cost"] = "$" .. orderGroup.totalCost,
                ["Complexity"] = complexityDesc
            },
            onSelect = function()
                TriggerEvent("warehouse:showOrderActions", orderGroup, boxesNeeded, containersNeeded)
            end
        })
    end
    
    lib.registerContext({
        id = "order_menu",
        title = "📋 Active Orders",
        options = options
    })
    lib.showContext("order_menu")
end)

-- ============================================
-- ORDER ACTION SYSTEM
-- ============================================

-- Show order action menu
RegisterNetEvent("warehouse:showOrderActions")
AddEventHandler("warehouse:showOrderActions", function(orderGroup, boxesNeeded, containersNeeded)
    local restaurantId = orderGroup.restaurantId
    local restaurantData = Config.Restaurants[restaurantId]
    local restaurantName = restaurantData and restaurantData.name or "Unknown Business"
    
    -- Check if team delivery is available
    local canTeamDeliver = boxesNeeded >= (Config.TeamDeliveries and Config.TeamDeliveries.minBoxesForTeam or 5)
    
    local options = {
        {
            title = "← Back to Orders",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent("warehouse:getPendingOrders")
            end
        },
        {
            title = "📋 Order Summary",
            description = string.format(
                "**%s**\nBoxes: %d • Containers: %d\nValue: $%d",
                restaurantName,
                boxesNeeded,
                containersNeeded,
                orderGroup.totalCost
            ),
            disabled = true
        },
        { 
            title = "✅ Solo Delivery", 
            description = string.format("Accept and complete alone (%d boxes)", boxesNeeded),
            icon = "fas fa-user",
            onSelect = function() 
                -- Confirmation for large orders
                if boxesNeeded >= 5 then
                    exports.ogz_supplychain:confirmWithNotification({
                        header = "Large Order Confirmation",
                        content = string.format(
                            "This is a **large order** with **%d boxes**.\n\nAre you sure you want to handle this solo?",
                            boxesNeeded
                        ),
                        confirmLabel = "Accept Solo",
                        successTitle = "Order Accepted",
                        successDescription = string.format("Processing %d-box delivery to %s", boxesNeeded, restaurantName),
                        onConfirm = function()
                            TriggerServerEvent("warehouse:acceptOrder", orderGroup.orderGroupId, restaurantId)
                        end
                    })
                else
                    TriggerServerEvent("warehouse:acceptOrder", orderGroup.orderGroupId, restaurantId)
                end
            end 
        }
    }
    
    -- Add team delivery options for large orders
    if canTeamDeliver then
        table.insert(options, {
            title = "🚛 Create Team Delivery",
            description = "Start a team delivery for this large order",
            icon = "fas fa-users",
            onSelect = function()
                TriggerEvent("team:showDeliveryTypeMenu", orderGroup.orderGroupId, restaurantId, boxesNeeded)
            end
        })
        
        table.insert(options, {
            title = "👥 Join Existing Team",
            description = "Look for teams needing drivers",
            icon = "fas fa-user-plus",
            onSelect = function()
                TriggerServerEvent("team:getAvailableTeams")
            end
        })
    end
    
    table.insert(options, {
        title = "❌ Deny Order", 
        description = "Reject this order",
        icon = "fas fa-times",
        onSelect = function()
            exports.ogz_supplychain:confirmWithNotification({
                header = "Confirm Order Rejection",
                content = string.format(
                    "Are you sure you want to reject this order?\n\n**Order:** %s\n**Value:** $%d",
                    orderGroup.orderGroupId,
                    orderGroup.totalCost
                ),
                confirmLabel = "Reject Order",
                successTitle = "Order Rejected",
                successDescription = "Order has been returned to the queue",
                onConfirm = function()
                    TriggerServerEvent("warehouse:denyOrder", orderGroup.orderGroupId)
                end
            })
        end 
    })
    
    lib.registerContext({
        id = "order_action_menu",
        title = "📦 Order Actions",
        options = options
    })
    lib.showContext("order_action_menu")
end)

-- ============================================
-- ORDER STATUS NOTIFICATIONS
-- ============================================

-- Order accepted notification
RegisterNetEvent("warehouse:orderAccepted")
AddEventHandler("warehouse:orderAccepted", function(orderData)
    exports.ogz_supplychain:successNotify(
        "Order Accepted",
        string.format("Processing order %s - %d boxes", orderData.orderGroupId, orderData.boxes or 1)
    )
end)

-- Order denied notification
RegisterNetEvent("warehouse:orderDenied")
AddEventHandler("warehouse:orderDenied", function(orderData)
    exports.ogz_supplychain:systemNotify(
        "Order Rejected",
        string.format("Order %s has been rejected", orderData.orderGroupId)
    )
end)

-- No orders available notification
RegisterNetEvent("warehouse:noOrdersAvailable")
AddEventHandler("warehouse:noOrdersAvailable", function()
    exports.ogz_supplychain:systemNotify(
        "No Orders",
        "No pending orders available at this time"
    )
end)

-- ============================================
-- ORDER VALIDATION SYSTEM
-- ============================================

-- Validate order before acceptance
local function validateOrderAcceptance(orderGroup)
    -- Check player job access
    local hasAccess = exports.ogz_supplychain:validatePlayerAccess("warehouse")
    if not hasAccess then
        return false, "No warehouse access"
    end
    
    -- Check if player is already on a delivery
    local playerState = exports.ogz_supplychain:getPlayerState()
    if playerState.hasOrder then
        return false, "Already processing an order"
    end
    
    -- Check delivery cooldown
    if exports.ogz_supplychain:isDeliveryCooldownActive() then
        local cooldownRemaining = math.ceil(playerState.cooldownRemaining / 1000)
        return false, string.format("Delivery cooldown active (%d seconds remaining)", cooldownRemaining)
    end
    
    return true, "Order can be accepted"
end

-- ============================================
-- EXPORTS
-- ============================================

exports('calculateDeliveryBoxes', calculateDeliveryBoxes)
exports('validateOrderAcceptance', validateOrderAcceptance)
exports('showOrderActions', function(orderGroup, boxesNeeded, containersNeeded)
    TriggerEvent("warehouse:showOrderActions", orderGroup, boxesNeeded, containersNeeded)
end)

print("[WAREHOUSE] Order management system loaded")