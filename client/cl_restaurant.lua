QBCore = exports['qb-core']:GetCoreObject()

-- Track current restaurant ID for ordering (can be string or nil)
local currentOrderRestaurantId = nil

Citizen.CreateThread(function()
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_restaurant.lua. Check config_locations.lua")
        return
    end
    print("[DEBUG] Config.Restaurants:", Config.Restaurants and "exists" or "nil")
    if Config.Restaurants then
        for k, v in ipairs(Config.Restaurants) do
            print("[DEBUG] Key:", k, "Value:", v.name or "no name")
        end
    end
    for restaurantId, restaurant in ipairs(Config.Restaurants) do
        if not restaurant.job then
            print("[ERROR] Job not defined for restaurant ID: " .. tostring(restaurantId) .. " in config_locations.lua")
            return
        end
        local orderPos = restaurant.position

        -- Validate coordinates
        if not orderPos or type(orderPos) ~= "vector3" then
            print("[ERROR] Invalid or missing position coordinates for restaurant ID: " .. tostring(restaurantId) .. " in config_locations.lua")
            lib.notify({
                title = "Configuration Error",
                description = "Invalid position coordinates for restaurant ID: " .. tostring(restaurantId) .. ". Check config_locations.lua",
                type = "error",
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            goto continue
        end

        exports.ox_target:addBoxZone({
            coords = orderPos,
            size = vector3(1.0, 1.0, 2.0),
            rotation = restaurant.heading or 0.0,
            debug = false,
            options = {
                {
                    name = "restaurant_order_" .. tostring(restaurantId),
                    icon = "fas fa-shopping-cart",
                    label = "Order Ingredients",
                    job = restaurant.job,
                    onSelect = function()
                        TriggerServerEvent("warehouse:getStocksForOrder", restaurantId)
                    end
                }
            }
        })

        ::continue::
    end
end)

RegisterNetEvent("restaurant:openOrderMenu")
AddEventHandler("restaurant:openOrderMenu", function(data)
    if not data or not data.restaurantId then
        lib.notify({
            title = "Error",
            description = "Invalid restaurant data.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local restaurantId = data.restaurantId
    currentOrderRestaurantId = tostring(restaurantId)
    local warehouseStock = data.warehouseStock or {}
    local dynamicPrices = data.dynamicPrices or {}
    local skipStockCheck = data.skipStockCheck or false
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_restaurant.lua. Check config_locations.lua")
        lib.notify({
            title = "Error",
            description = "Configuration not loaded. Check config_locations.lua",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        print("[ERROR] Invalid restaurant ID: " .. tostring(restaurantId) .. " in config_locations.lua")
        lib.notify({
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId) .. ". Check config_locations.lua",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local restaurantJob = restaurant.job
    if not restaurantJob or not Config.Items[restaurantJob] then
        lib.notify({
            title = "Error",
            description = "No items configured for this restaurant.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local itemNames = exports.ox_inventory:Items() or {}
    local orderItems = {}
    local options = {}
    for category, items in pairs(Config.Items[restaurantJob]) do
        for item, details in pairs(items) do
            local itemLabel = itemNames[item] and itemNames[item].label or details.label or item
            local stockQuantity = warehouseStock[item] or 0
            table.insert(options, {
                title = itemLabel .. (skipStockCheck and "" or " (Stock: " .. stockQuantity .. ")"),
                description = skipStockCheck and "Order for $" .. (dynamicPrices[item] or details.price) or "Stock: " .. stockQuantity .. " | Price: $" .. (dynamicPrices[item] or details.price),
                icon = itemNames[item] and itemNames[item].image or "fas fa-box",
                onSelect = function()
                    local maxOrder = skipStockCheck and 100 or stockQuantity
                    local input = lib.inputDialog("Order " .. itemLabel, {
                        { type = "number", label = "Enter Amount", placeholder = "Amount", min = 1, max = maxOrder, required = true }
                    })
                    if input and input[1] and tonumber(input[1]) > 0 then
                        local amount = tonumber(input[1])
                        table.insert(orderItems, {
                            ingredient = item,
                            quantity = amount,
                            label = itemLabel
                        })
                        lib.notify({
                            title = "Item Added",
                            description = amount .. " x " .. itemLabel .. " added to order.",
                            type = "success",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    else
                        lib.notify({
                            title = "Error",
                            description = "Invalid amount entered.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            })
        end
    end

    table.insert(options, {
        title = "Submit Order",
        description = "Submit the selected items for ordering.",
        icon = "fas fa-check",
        onSelect = function()
            if #orderItems == 0 then
                lib.notify({
                    title = "Error",
                    description = "No items selected for order.",
                    type = "error",
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                return
            end
            TriggerServerEvent("restaurant:orderIngredients", orderItems, restaurantId)
            lib.hideContext()
            currentOrderRestaurantId = nil
        end
    })

    lib.registerContext({
        id = "order_menu",
        title = "Order Ingredients",
        options = options
    })
    lib.showContext("order_menu")
end)

RegisterNetEvent("restaurant:showResturantStock")
AddEventHandler("restaurant:showResturantStock", function(restaurantId)
    local restaurantIdStr = tostring(restaurantId)
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_restaurant.lua. Check config_locations.lua")
        lib.notify({
            title = "Error",
            description = "Configuration not loaded. Check config_locations.lua",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        print("[ERROR] Invalid restaurant ID: " .. tostring(restaurantId) .. " in config_locations.lua")
        lib.notify({
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId) .. ". Check config_locations.lua",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local stashId = "restaurant_stock_" .. restaurantIdStr
    local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
    local stock = {}
    local itemNames = exports.ox_inventory:Items() or {}
    for _, item in pairs(stashItems) do
        local itemName = item.name or item.item
        local itemAmount = item.count or item.amount or 0
        local label = itemNames[itemName] and itemNames[itemName].label or itemName
        table.insert(stock, {
            title = label .. ": " .. itemAmount,
            description = "Withdraw this item from the stash.",
            icon = itemNames[itemName] and itemNames[itemName].image or "fas fa-box",
            onSelect = function()
                local input = lib.inputDialog("Withdraw " .. label, {
                    { type = "number", label = "Enter Amount", placeholder = "Amount", min = 1, max = itemAmount, required = true }
                })
                if input and input[1] and tonumber(input[1]) > 0 then
                    local amount = tonumber(input[1])
                    TriggerServerEvent("restaurant:withdrawStock", restaurantId, itemName, amount)
                else
                    lib.notify({
                        title = "Error",
                        description = "Invalid amount entered.",
                        type = "error",
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        })
    end

    if #stock == 0 then
        lib.notify({
            title = "No Stock",
            description = "There are no items in the restaurant stash.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    lib.registerContext({
        id = "restaurant_stock_menu_" .. restaurantIdStr,
        title = restaurant.name .. " Stock",
        options = stock
    })
    lib.showContext("restaurant_stock_menu_" .. restaurantIdStr)
end)