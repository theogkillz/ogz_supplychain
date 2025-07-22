-- Restaurant Menu System v2.0 - Shopping Cart Implementation

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants
local StateManager = SupplyChain.StateManager

-- Shopping Cart State
local ShoppingCart = {
    items = {},        -- { itemName = { quantity = X, label = "", price = Y, containerType = "" } }
    containers = {},   -- { containerType = { items = {}, totalItems = 0 } }
    totalCost = 0,
    totalContainers = 0
}

-- Container Helper Functions
local function GetBestContainerForItem(itemName, itemData)
    -- Check each container type for compatibility
    for containerType, container in pairs(Config.Containers.types) do
        -- Check if item is in compatible items list
        for _, compatible in ipairs(container.compatibleItems) do
            if compatible == itemName or 
               compatible == "all_dry_goods" or
               (itemData.category and string.find(compatible, itemData.category)) then
                return containerType, container
            end
        end
    end
    
    -- Fallback to standard crate
    return "ogz_crate", Config.Containers.types["ogz_crate"]
end

local function CalculateContainersNeeded()
    ShoppingCart.containers = {}
    ShoppingCart.totalContainers = 0
    
    -- Group items by their best container type
    for itemName, itemData in pairs(ShoppingCart.items) do
        local containerType = itemData.containerType or "ogz_crate"
        
        if not ShoppingCart.containers[containerType] then
            ShoppingCart.containers[containerType] = {
                items = {},
                totalItems = 0,
                containerInfo = Config.Containers.types[containerType]
            }
        end
        
        -- Add item to container group
        table.insert(ShoppingCart.containers[containerType].items, {
            name = itemName,
            quantity = itemData.quantity,
            label = itemData.label
        })
        
        ShoppingCart.containers[containerType].totalItems = 
            ShoppingCart.containers[containerType].totalItems + itemData.quantity
    end
    
    -- Calculate actual containers needed
    for containerType, containerData in pairs(ShoppingCart.containers) do
        local containersNeeded = math.ceil(containerData.totalItems / 12) -- Max 12 items per container
        containerData.containersNeeded = containersNeeded
        ShoppingCart.totalContainers = ShoppingCart.totalContainers + containersNeeded
    end
end

-- Main Restaurant Menu with Categories
RegisterNetEvent("SupplyChain:Client:OpenRestaurantMenu")
AddEventHandler("SupplyChain:Client:OpenRestaurantMenu", function(data)
    local restaurantId = data.restaurantId
    local restaurant = data.restaurant
    local warehouseStock = data.warehouseStock or {}
    local dynamicPrices = data.dynamicPrices or {}
    
    -- Clear cart if new session
    if data.clearCart then
        ShoppingCart = {
            items = {},
            containers = {},
            totalCost = 0,
            totalContainers = 0
        }
    end
    
    local options = {}
    
    -- Cart Summary Header
    if next(ShoppingCart.items) then
        table.insert(options, {
            title = "🛒 Shopping Cart",
            description = string.format("Items: %d | Containers: %d | Total: $%d", 
                GetCartItemCount(), ShoppingCart.totalContainers, ShoppingCart.totalCost),
            icon = "fas fa-shopping-cart",
            iconColor = "#4CAF50",
            onSelect = function()
                ShowShoppingCart(data)
            end
        })
        
        table.insert(options, {
            title = "─────────────────────",
            disabled = true
        })
    end
    
    -- Search Option
    table.insert(options, {
        title = "🔍 Search Items",
        description = "Search for specific ingredients",
        icon = "fas fa-search",
        onSelect = function()
            SearchItems(data)
        end
    })
    
    -- Category Menu
    local restaurantItems = Config.Items[restaurant.job]
    if not restaurantItems then
        Framework.Notify(nil, "No items configured for this restaurant", "error")
        return
    end
    
    -- Create category options
    for category, items in pairs(restaurantItems) do
        local categoryItemCount = 0
        local availableItems = 0
        
        -- Count items in category
        for item, _ in pairs(items) do
            categoryItemCount = categoryItemCount + 1
            if (warehouseStock[item] or 0) > 0 then
                availableItems = availableItems + 1
            end
        end
        
        table.insert(options, {
            title = GetCategoryIcon(category) .. " " .. category,
            description = string.format("%d/%d items available", availableItems, categoryItemCount),
            icon = "fas fa-folder-open",
            arrow = true,
            metadata = {
                {label = "Category", value = category},
                {label = "Available Items", value = availableItems},
                {label = "Total Items", value = categoryItemCount}
            },
            onSelect = function()
                ShowCategoryItems(data, category)
            end
        })
    end
    
    -- Footer Options
    if next(ShoppingCart.items) then
        table.insert(options, {
            title = "─────────────────────",
            disabled = true
        })
        
        table.insert(options, {
            title = "✅ Submit Order",
            description = "Submit the current order",
            icon = "fas fa-check-circle",
            iconColor = "#4CAF50",
            onSelect = function()
                SubmitOrder(restaurantId)
            end
        })
        
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items from cart",
            icon = "fas fa-trash",
            iconColor = "#F44336",
            onSelect = function()
                ClearCart(data)
            end
        })
    end
    
    -- Quick Reorder Option
    table.insert(options, {
        title = "⚡ Quick Reorder",
        description = "Reorder common items quickly",
        icon = "fas fa-redo",
        onSelect = function()
            ShowQuickReorder(data)
        end
    })
    
    lib.registerContext({
        id = "restaurant_menu_main",
        title = restaurant.name .. " - Order System",
        options = options
    })
    
    lib.showContext("restaurant_menu_main")
end)

-- Category Items Display
function ShowCategoryItems(menuData, category)
    local restaurantId = menuData.restaurantId
    local restaurant = menuData.restaurant
    local warehouseStock = menuData.warehouseStock or {}
    local dynamicPrices = menuData.dynamicPrices or {}
    
    local itemNames = exports.ox_inventory:Items() or {}
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back to Categories",
        icon = "fas fa-arrow-left",
        menu = "restaurant_menu_main"
    })
    
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    -- Category items
    local categoryItems = Config.Items[restaurant.job][category]
    if categoryItems then
        for item, details in pairs(categoryItems) do
            local itemLabel = itemNames[item] and itemNames[item].label or details.label or item
            local stockQuantity = warehouseStock[item] or 0
            local price = dynamicPrices[item] or details.price
            local inCart = ShoppingCart.items[item] and ShoppingCart.items[item].quantity or 0
            
            -- Determine best container for item
            local containerType, containerInfo = GetBestContainerForItem(item, details)
            
            table.insert(options, {
                title = itemLabel,
                description = string.format("Stock: %d | Price: $%d | In Cart: %d", 
                    stockQuantity, price, inCart),
                icon = itemNames[item] and ("nui://ox_inventory/web/images/" .. item .. ".png") or "fas fa-box",
                disabled = stockQuantity == 0,
                metadata = {
                    {label = "Category", value = category},
                    {label = "In Stock", value = stockQuantity},
                    {label = "Unit Price", value = "$" .. price},
                    {label = "Container Type", value = containerInfo.name},
                    {label = "In Cart", value = inCart}
                },
                onSelect = function()
                    AddItemToCart(item, itemLabel, price, stockQuantity, containerType, menuData)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_category_items",
        title = restaurant.name .. " - " .. category,
        menu = "restaurant_menu_main",
        options = options
    })
    
    lib.showContext("restaurant_category_items")
end

-- Add Item to Cart
function AddItemToCart(item, label, price, maxStock, containerType, menuData)
    local currentInCart = ShoppingCart.items[item] and ShoppingCart.items[item].quantity or 0
    local availableToAdd = maxStock - currentInCart
    
    if availableToAdd <= 0 then
        Framework.Notify(nil, "Maximum stock already in cart", "error")
        return
    end
    
    local input = lib.inputDialog("Add " .. label .. " to Cart", {
        {
            type = "number",
            label = "Quantity",
            description = string.format("Available: %d (Already in cart: %d)", availableToAdd, currentInCart),
            min = 1,
            max = availableToAdd,
            default = math.min(12, availableToAdd), -- Default to container max or available
            required = true
        },
        {
            type = "input",
            label = "Container Info",
            description = "Recommended container type",
            default = Config.Containers.types[containerType].name,
            disabled = true
        }
    })
    
    if input and input[1] then
        local quantity = tonumber(input[1])
        
        if not ShoppingCart.items[item] then
            ShoppingCart.items[item] = {
                quantity = 0,
                label = label,
                price = price,
                containerType = containerType
            }
        end
        
        ShoppingCart.items[item].quantity = ShoppingCart.items[item].quantity + quantity
        ShoppingCart.totalCost = ShoppingCart.totalCost + (price * quantity)
        
        -- Recalculate containers
        CalculateContainersNeeded()
        
        Framework.Notify(nil, string.format("Added %dx %s to cart", quantity, label), "success")
        
        -- Refresh menu
        ShowCategoryItems(menuData, menuData.currentCategory or "Meats")
    end
end

-- Shopping Cart View
function ShowShoppingCart(menuData)
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back to Menu",
        icon = "fas fa-arrow-left",
        menu = "restaurant_menu_main"
    })
    
    -- Cart Summary
    table.insert(options, {
        title = "📊 Cart Summary",
        description = string.format("Total Items: %d | Containers Needed: %d | Total Cost: $%d",
            GetCartItemCount(), ShoppingCart.totalContainers, ShoppingCart.totalCost),
        icon = "fas fa-info-circle",
        disabled = true
    })
    
    table.insert(options, {
        title = "─────────────────────",
        disabled = true
    })
    
    -- Container Groups
    for containerType, containerData in pairs(ShoppingCart.containers) do
        local containerInfo = containerData.containerInfo
        
        -- Container header
        table.insert(options, {
            title = string.format("📦 %s (x%d containers)", 
                containerInfo.name, containerData.containersNeeded),
            description = string.format("%d items total | $%d per container", 
                containerData.totalItems, containerInfo.cost),
            icon = "fas fa-box",
            iconColor = "#2196F3",
            disabled = true
        })
        
        -- Items in this container type
        for _, item in ipairs(containerData.items) do
            local cartItem = ShoppingCart.items[item.name]
            table.insert(options, {
                title = "  • " .. item.label,
                description = string.format("Quantity: %d | $%d each | Total: $%d", 
                    item.quantity, cartItem.price, cartItem.price * item.quantity),
                icon = "fas fa-minus-circle",
                iconColor = "#F44336",
                onSelect = function()
                    ModifyCartItem(item.name, menuData)
                end
            })
        end
        
        table.insert(options, {
            title = "─────────────────────",
            disabled = true
        })
    end
    
    -- Actions
    if next(ShoppingCart.items) then
        table.insert(options, {
            title = "✅ Confirm Order",
            description = "Submit this order to the warehouse",
            icon = "fas fa-check-circle",
            iconColor = "#4CAF50",
            onSelect = function()
                ConfirmOrder(menuData.restaurantId)
            end
        })
        
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items from cart",
            icon = "fas fa-trash",
            iconColor = "#F44336",
            onSelect = function()
                ClearCart(menuData)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_shopping_cart",
        title = "Shopping Cart",
        menu = "restaurant_menu_main",
        options = options
    })
    
    lib.showContext("restaurant_shopping_cart")
end

-- Modify Cart Item
function ModifyCartItem(itemName, menuData)
    local item = ShoppingCart.items[itemName]
    if not item then return end
    
    local input = lib.inputDialog("Modify " .. item.label, {
        {
            type = "number",
            label = "New Quantity",
            description = "Enter 0 to remove from cart",
            min = 0,
            max = menuData.warehouseStock[itemName] or item.quantity,
            default = item.quantity,
            required = true
        }
    })
    
    if input and input[1] ~= nil then
        local newQuantity = tonumber(input[1])
        local difference = newQuantity - item.quantity
        
        if newQuantity == 0 then
            -- Remove item
            ShoppingCart.totalCost = ShoppingCart.totalCost - (item.price * item.quantity)
            ShoppingCart.items[itemName] = nil
            Framework.Notify(nil, "Item removed from cart", "info")
        else
            -- Update quantity
            ShoppingCart.items[itemName].quantity = newQuantity
            ShoppingCart.totalCost = ShoppingCart.totalCost + (item.price * difference)
            Framework.Notify(nil, "Cart updated", "success")
        end
        
        -- Recalculate containers
        CalculateContainersNeeded()
        
        -- Refresh cart view
        ShowShoppingCart(menuData)
    end
end

-- Submit Order
function SubmitOrder(restaurantId)
    if not next(ShoppingCart.items) then
        Framework.Notify(nil, "Cart is empty", "error")
        return
    end
    
    -- Prepare order data with container information
    local orderData = {
        restaurantId = restaurantId,
        items = {},
        containers = {},
        totalCost = ShoppingCart.totalCost,
        totalContainers = ShoppingCart.totalContainers
    }
    
    -- Convert cart items to order format
    for itemName, itemData in pairs(ShoppingCart.items) do
        table.insert(orderData.items, {
            name = itemName,
            quantity = itemData.quantity,
            label = itemData.label,
            price = itemData.price,
            containerType = itemData.containerType
        })
    end
    
    -- Add container breakdown
    for containerType, containerData in pairs(ShoppingCart.containers) do
        table.insert(orderData.containers, {
            type = containerType,
            count = containerData.containersNeeded,
            items = containerData.items,
            cost = containerData.containerInfo.cost
        })
    end
    
    -- Send to server
    TriggerServerEvent(Constants.Events.Server.CreateRestaurantOrder, orderData)
    
    -- Clear cart
    ShoppingCart = {
        items = {},
        containers = {},
        totalCost = 0,
        totalContainers = 0
    }
    
    lib.hideContext()
    Framework.Notify(nil, "Order submitted successfully!", "success")
end

-- Helper Functions
function GetCartItemCount()
    local count = 0
    for _, item in pairs(ShoppingCart.items) do
        count = count + item.quantity
    end
    return count
end

function GetCategoryIcon(category)
    local icons = {
        Meats = "🥩",
        Vegetables = "🥬",
        Fruits = "🍎",
        Dairy = "🥛",
        DryGoods = "📦"
    }
    return icons[category] or "📦"
end

function ClearCart(menuData)
    ShoppingCart = {
        items = {},
        containers = {},
        totalCost = 0,
        totalContainers = 0
    }
    Framework.Notify(nil, "Cart cleared", "info")
    
    -- Reopen main menu
    TriggerEvent("SupplyChain:Client:OpenRestaurantMenu", menuData)
end

function SearchItems(data)
    local input = lib.inputDialog("Search Items", {
        { type = "input", label = "Enter item name", required = true }
    })
    
    if input and input[1] then
        -- Create filtered menu
        ShowSearchResults(data, input[1])
    end
end

function ShowSearchResults(menuData, searchQuery)
    local restaurantId = menuData.restaurantId
    local restaurant = menuData.restaurant
    local warehouseStock = menuData.warehouseStock or {}
    local dynamicPrices = menuData.dynamicPrices or {}
    
    local itemNames = exports.ox_inventory:Items() or {}
    local options = {}
    local foundItems = 0
    
    -- Back button
    table.insert(options, {
        title = "← Back to Menu",
        icon = "fas fa-arrow-left",
        menu = "restaurant_menu_main"
    })
    
    -- Search all categories
    for category, items in pairs(Config.Items[restaurant.job]) do
        for item, details in pairs(items) do
            local itemLabel = itemNames[item] and itemNames[item].label or details.label or item
            
            -- Check if item matches search
            if string.find(string.lower(item), string.lower(searchQuery)) or
               string.find(string.lower(itemLabel), string.lower(searchQuery)) then
                
                foundItems = foundItems + 1
                local stockQuantity = warehouseStock[item] or 0
                local price = dynamicPrices[item] or details.price
                local inCart = ShoppingCart.items[item] and ShoppingCart.items[item].quantity or 0
                local containerType, containerInfo = GetBestContainerForItem(item, details)
                
                table.insert(options, {
                    title = itemLabel,
                    description = string.format("Category: %s | Stock: %d | Price: $%d | In Cart: %d", 
                        category, stockQuantity, price, inCart),
                    icon = itemNames[item] and ("nui://ox_inventory/web/images/" .. item .. ".png") or "fas fa-box",
                    disabled = stockQuantity == 0,
                    metadata = {
                        {label = "Category", value = category},
                        {label = "In Stock", value = stockQuantity},
                        {label = "Unit Price", value = "$" .. price},
                        {label = "Container", value = containerInfo.name}
                    },
                    onSelect = function()
                        AddItemToCart(item, itemLabel, price, stockQuantity, containerType, menuData)
                    end
                })
            end
        end
    end
    
    if foundItems == 0 then
        table.insert(options, {
            title = "No items found",
            description = "Try a different search term",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "restaurant_search_results",
        title = "Search Results: " .. searchQuery,
        menu = "restaurant_menu_main",
        options = options
    })
    
    lib.showContext("restaurant_search_results")
end

-- Quick Reorder System
function ShowQuickReorder(menuData)
    -- Predefined order templates based on container optimization
    local presets = {
        {
            name = "Basic Meat Restock",
            description = "Standard meat supplies",
            containerType = "ogz_cooler",
            items = {
                {item = "butcher_ground_chicken", amount = 12},
                {item = "slaughter_ground_meat", amount = 12}
            }
        },
        {
            name = "Weekend Rush Pack",
            description = "High-volume weekend supplies",
            containerType = "ogz_cooler",
            items = {
                {item = "butcher_ground_chicken", amount = 24},
                {item = "slaughter_ground_meat", amount = 24},
                {item = "reign_lettuce", amount = 12}
            }
        },
        {
            name = "Vegetable Bundle",
            description = "Fresh produce pack",
            containerType = "ogz_produce",
            items = {
                {item = "reign_lettuce", amount = 24}
            }
        }
    }
    
    local options = {}
    
    -- Back button
    table.insert(options, {
        title = "← Back to Menu",
        icon = "fas fa-arrow-left",
        menu = "restaurant_menu_main"
    })
    
    for _, preset in ipairs(presets) do
        local itemList = {}
        local totalCost = 0
        local containersNeeded = 0
        
        -- Calculate preset details
        for _, item in ipairs(preset.items) do
            table.insert(itemList, string.format("%dx %s", item.amount, item.item))
            local itemData = Config.Items[menuData.restaurant.job]
            for cat, items in pairs(itemData) do
                if items[item.item] then
                    totalCost = totalCost + (items[item.item].price * item.amount)
                end
            end
        end
        
        -- Calculate containers
        local totalItems = 0
        for _, item in ipairs(preset.items) do
            totalItems = totalItems + item.amount
        end
        containersNeeded = math.ceil(totalItems / 12)
        
        table.insert(options, {
            title = preset.name,
            description = preset.description,
            icon = "fas fa-box-open",
            metadata = {
                {label = "Items", value = table.concat(itemList, ", ")},
                {label = "Containers", value = containersNeeded .. "x " .. preset.containerType},
                {label = "Est. Cost", value = "$" .. totalCost}
            },
            onSelect = function()
                -- Clear current cart
                ShoppingCart = {
                    items = {},
                    containers = {},
                    totalCost = 0,
                    totalContainers = 0
                }
                
                -- Add preset items
                for _, item in ipairs(preset.items) do
                    local itemData = nil
                    local itemLabel = item.item
                    local itemPrice = 0
                    
                    -- Find item data
                    for cat, items in pairs(Config.Items[menuData.restaurant.job]) do
                        if items[item.item] then
                            itemData = items[item.item]
                            itemLabel = itemData.label or item.item
                            itemPrice = menuData.dynamicPrices[item.item] or itemData.price
                            break
                        end
                    end
                    
                    if itemData then
                        ShoppingCart.items[item.item] = {
                            quantity = item.amount,
                            label = itemLabel,
                            price = itemPrice,
                            containerType = preset.containerType
                        }
                        ShoppingCart.totalCost = ShoppingCart.totalCost + (itemPrice * item.amount)
                    end
                end
                
                -- Calculate containers
                CalculateContainersNeeded()
                
                -- Submit order
                SubmitOrder(menuData.restaurantId)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_quick_reorder",
        title = "Quick Reorder Templates",
        menu = "restaurant_menu_main",
        options = options
    })
    
    lib.showContext("restaurant_quick_reorder")
end

-- Export functions for other scripts
exports('GetShoppingCart', function()
    return ShoppingCart
end)

exports('ClearShoppingCart', function()
    ShoppingCart = {
        items = {},
        containers = {},
        totalCost = 0,
        totalContainers = 0
    }
end)