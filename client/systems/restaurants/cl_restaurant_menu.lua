-- Restaurant Menu System

local Framework = SupplyChain.Framework
local Restaurant = exports['ogz_supplychain']:GetRestaurantFunctions()

-- Order menu creation
RegisterNetEvent("SupplyChain:Client:CreateOrderMenu")
AddEventHandler("SupplyChain:Client:CreateOrderMenu", function(data)
    local restaurantId = data.restaurantId
    local restaurant = data.restaurant
    local warehouseStock = data.warehouseStock or {}
    local dynamicPrices = data.dynamicPrices or {}
    
    local itemNames = exports.ox_inventory:Items() or {}
    local orderItems = {}
    local options = {}
    
    -- Add search option
    table.insert(options, {
        title = "Search Items",
        description = "Search for specific ingredients",
        icon = "fas fa-search",
        onSelect = function()
            local input = lib.inputDialog("Search Ingredients", {
                { type = "input", label = "Enter ingredient name" }
            })
            
            if input and input[1] then
                -- Re-open menu with search filter
                TriggerEvent("SupplyChain:Client:CreateOrderMenu", {
                    restaurantId = restaurantId,
                    restaurant = restaurant,
                    warehouseStock = warehouseStock,
                    dynamicPrices = dynamicPrices,
                    searchQuery = input[1]
                })
            end
        end
    })
    
    -- Get restaurant items
    local restaurantItems = Config.Items[restaurant.job]
    if not restaurantItems then
        Framework.Notify(nil, "No items configured for this restaurant", "error")
        return
    end
    
    -- Add items to menu
    for category, items in pairs(restaurantItems) do
        -- Category header
        table.insert(options, {
            title = "--- " .. category .. " ---",
            disabled = true
        })
        
        for item, details in pairs(items) do
            -- Apply search filter if provided
            if not data.searchQuery or string.find(string.lower(item), string.lower(data.searchQuery)) or 
               string.find(string.lower(details.label or item), string.lower(data.searchQuery)) then
                
                local itemLabel = itemNames[item] and itemNames[item].label or details.label or item
                local stockQuantity = warehouseStock[item] or 0
                local price = dynamicPrices[item] or details.price
                
                table.insert(options, {
                    title = itemLabel,
                    description = string.format("Stock: %d | Price: $%d per unit", stockQuantity, price),
                    icon = itemNames[item] and ("nui://ox_inventory/web/images/" .. item .. ".png") or "fas fa-box",
                    disabled = stockQuantity == 0,
                    metadata = {
                        {label = "Category", value = category},
                        {label = "In Stock", value = stockQuantity},
                        {label = "Unit Price", value = "$" .. price}
                    },
                    onSelect = function()
                        local input = lib.inputDialog("Order " .. itemLabel, {
                            { 
                                type = "number", 
                                label = "Quantity", 
                                description = "How many units?",
                                min = 1, 
                                max = stockQuantity,
                                default = 1,
                                required = true 
                            }
                        })
                        
                        if input and input[1] and tonumber(input[1]) > 0 then
                            local amount = tonumber(input[1])
                            Restaurant.AddToOrder(item, amount, itemLabel)
                            
                            -- Re-open menu
                            TriggerEvent("SupplyChain:Client:OpenRestaurantMenu", {
                                restaurantId = data.restaurantId,
                                restaurant = data.restaurant,
                                warehouseStock = warehouseStock,
                                dynamicPrices = dynamicPrices,
                                clearCart = true
                            })
                        end
                    end
                })
            end
        end
    end
    
    -- Add quick reorder option
    table.insert(options, {
        title = "Quick Reorder",
        description = "Reorder common items quickly",
        icon = "fas fa-redo",
        onSelect = function()
            TriggerEvent("SupplyChain:Client:QuickReorderMenu", {
                restaurantId = restaurantId,
                restaurant = restaurant
            })
        end
    })
    
    -- Add submit order option
    table.insert(options, {
        title = "Submit Order",
        description = "Submit the current order",
        icon = "fas fa-check",
        onSelect = function()
            Restaurant.SubmitOrder()
            lib.hideContext()
        end
    })
    
    -- Register and show context menu
    lib.registerContext({
        id = "restaurant_order_menu",
        title = restaurant.name .. " - Order Ingredients",
        options = options
    })
    
    lib.showContext("restaurant_order_menu")
end)

-- Quick reorder menu
RegisterNetEvent("SupplyChain:Client:QuickReorderMenu")
AddEventHandler("SupplyChain:Client:QuickReorderMenu", function(data)
    local restaurantId = data.restaurantId
    local restaurant = data.restaurant
    
    -- Common quick order presets
    local presets = {
        {
            name = "Basic Restock",
            items = {
                {item = "bun", amount = 50},
                {item = "patty", amount = 50},
                {item = "lettuce", amount = 25}
            }
        },
        {
            name = "Weekend Rush",
            items = {
                {item = "bun", amount = 100},
                {item = "patty", amount = 100},
                {item = "lettuce", amount = 50},
                {item = "potato", amount = 75}
            }
        },
        {
            name = "Emergency Restock",
            items = {
                {item = "bun", amount = 25},
                {item = "patty", amount = 25}
            }
        }
    }
    
    local options = {}
    
    for _, preset in ipairs(presets) do
        local itemList = {}
        for _, item in ipairs(preset.items) do
            table.insert(itemList, string.format("%dx %s", item.amount, item.item))
        end
        
        table.insert(options, {
            title = preset.name,
            description = table.concat(itemList, ", "),
            icon = "fas fa-box-open",
            onSelect = function()
                -- Add all preset items to order
                for _, item in ipairs(preset.items) do
                    Restaurant.AddToOrder(item.item, item.amount, item.item)
                end
                
                Restaurant.SubmitOrder()
                Framework.Notify(nil, "Quick order submitted!", "success")
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_quick_order",
        title = "Quick Reorder",
        menu = "restaurant_order_menu",
        options = options
    })
    
    lib.showContext("restaurant_quick_order")
end)

-- Food preparation menu
RegisterNetEvent("SupplyChain:Client:PrepareFood")
AddEventHandler("SupplyChain:Client:PrepareFood", function(data)
    local job = data.job
    local locationId = data.locationId
    local restaurantId = data.restaurantId
    
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant or not restaurant.cookLocations or not restaurant.cookLocations[locationId] then
        Framework.Notify(nil, "Invalid preparation location", "error")
        return
    end
    
    local cookLocation = restaurant.cookLocations[locationId]
    local options = {}
    
    for _, recipe in pairs(cookLocation.items) do
        local hasItems = true
        local requirements = {}
        
        -- Check required items
        if recipe.requiredItems then
            for _, req in pairs(recipe.requiredItems) do
                local itemCount = exports.ox_inventory:GetItemCount(req.item)
                local itemInfo = exports.ox_inventory:Items(req.item)
                local itemName = itemInfo and itemInfo.label or req.item
                
                table.insert(requirements, string.format("%dx %s", req.amount, itemName))
                
                if itemCount < req.amount then
                    hasItems = false
                end
            end
        end
        
        local itemInfo = exports.ox_inventory:Items(recipe.item)
        local itemName = itemInfo and itemInfo.label or recipe.item
        
        table.insert(options, {
            title = itemName,
            description = #requirements > 0 and "Requires: " .. table.concat(requirements, ", ") or "No requirements",
            icon = itemInfo and ("nui://ox_inventory/web/images/" .. recipe.item .. ".png") or recipe.icon or "fas fa-utensils",
            disabled = not hasItems,
            metadata = recipe.requiredItems and {
                {label = "Prep Time", value = (recipe.time / 1000) .. "s"}
            } or nil,
            onSelect = function()
                local input = lib.inputDialog("Prepare " .. itemName, {
                    { 
                        type = "number", 
                        label = "Quantity", 
                        description = "How many to prepare?",
                        min = 1, 
                        max = 10,
                        default = 1,
                        required = true 
                    }
                })
                
                if input and input[1] and tonumber(input[1]) > 0 then
                    local quantity = tonumber(input[1])
                    
                    -- Check if player has enough items for quantity
                    local canMake = true
                    if recipe.requiredItems then
                        for _, req in pairs(recipe.requiredItems) do
                            if exports.ox_inventory:GetItemCount(req.item) < (req.amount * quantity) then
                                canMake = false
                                break
                            end
                        end
                    end
                    
                    if not canMake then
                        Framework.Notify(nil, "Not enough ingredients for that quantity", "error")
                        return
                    end
                    
                    TriggerEvent("SupplyChain:Client:StartCooking", {
                        recipe = recipe,
                        quantity = quantity,
                        locationId = locationId,
                        restaurantId = restaurantId
                    })
                end
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_cooking_menu",
        title = cookLocation.targetLabel or "Prepare Food",
        options = options
    })
    
    lib.showContext("restaurant_cooking_menu")
end)

-- Cooking process
RegisterNetEvent("SupplyChain:Client:StartCooking")
AddEventHandler("SupplyChain:Client:StartCooking", function(data)
    local recipe = data.recipe
    local quantity = data.quantity
    
    for i = 1, quantity do
        if lib.progressCircle({
            duration = recipe.time,
            label = recipe.progressLabel or "Preparing...",
            position = 'bottom',
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true
            },
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_ped'
            }
        }) then
            TriggerServerEvent("SupplyChain:Server:CompleteRecipe", {
                recipe = recipe,
                quantity = 1
            })
            
            if i < quantity then
                Wait(1000) -- Brief pause between preparations
            end
        else
            Framework.Notify(nil, "Preparation cancelled", "error")
            break
        end
    end
    
    ClearPedTasks(PlayerPedId())
end)