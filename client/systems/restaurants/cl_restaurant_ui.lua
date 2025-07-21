-- ===============================================
-- RESTAURANT CORE UI SYSTEM
-- Enterprise-grade restaurant ordering interface
-- File: client/systems/restaurants/cl_restaurant_ui.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()
local job = Framework.GetPlayerJob()
local hasAccess = Framework.HasJob("hurst")
-- ===============================================
-- STATE MANAGEMENT (Local Scope)
-- ===============================================

-- Shopping cart state
local shoppingCart = {}
local cartTotalCost = 0
local cartBoxCount = 0
local cartContainerCount = 0

-- UI state tracking
local isMenuOpen = false
local currentRestaurantId = nil

-- ===============================================
-- INITIALIZATION & TARGETING
-- ===============================================

-- Initialize restaurant computer targets
Citizen.CreateThread(function()
    for id, restaurant in pairs(Config.Restaurants) do
        -- Create restaurant computer interaction
        exports.ogz_supplychain:createBoxZone({
            name = "restaurant_computer_" .. id,
            coords = restaurant.position,
            size = vector3(1.5, 1.5, 1.0),
            heading = restaurant.heading,
            options = {
                {
                    type = "client",
                    event = "restaurant:openMainMenu",
                    icon = "fas fa-laptop",
                    label = "Restaurant Management",
                    restaurantId = id,
                    canInteract = function()
                        return exports.ogz_supplychain:validatePlayerAccess("restaurant")
                    end
                }
            }
        })
    end
end)

-- ===============================================
-- CART MANAGEMENT SYSTEM
-- ===============================================

-- Clear shopping cart
local function clearCart()
    shoppingCart = {}
    cartTotalCost = 0
    cartBoxCount = 0
    cartContainerCount = 0
end

-- Calculate containers and boxes needed
local function calculateCartTotals()
    cartTotalCost = 0
    local totalItems = 0
    
    for _, cartItem in ipairs(shoppingCart) do
        cartTotalCost = cartTotalCost + (cartItem.price * cartItem.quantity)
        totalItems = totalItems + cartItem.quantity
    end
    
    local boxesNeeded, containersNeeded = SupplyUtils.calculateContainers(totalItems)
    cartBoxCount = boxesNeeded
    cartContainerCount = containersNeeded
end

-- Add item to cart with validation
local function addToCart(ingredient, quantity, label, price)
    if not SupplyValidation.isValidQuantity(quantity, 999) then
        exports.ogz_supplychain:errorNotify("Invalid Quantity", "Please enter a valid quantity")
        return false
    end
    
    -- Check if item already in cart
    for i, cartItem in ipairs(shoppingCart) do
        if cartItem.ingredient == ingredient then
            cartItem.quantity = cartItem.quantity + quantity
            calculateCartTotals()
            return true
        end
    end
    
    -- Add new item to cart
    table.insert(shoppingCart, {
        ingredient = ingredient,
        quantity = quantity,
        label = label,
        price = price
    })
    calculateCartTotals()
    return true
end

-- Remove item from cart
local function removeFromCart(index)
    if shoppingCart[index] then
        table.remove(shoppingCart, index)
        calculateCartTotals()
        return true
    end
    return false
end

-- ===============================================
-- MAIN MENU SYSTEM
-- ===============================================

-- Main restaurant menu entry point
RegisterNetEvent("restaurant:openMainMenu")
AddEventHandler("restaurant:openMainMenu", function(data)
    if isMenuOpen then return end
    
    local restaurantId = data.restaurantId
    if not SupplyValidation.isValidRestaurantId(restaurantId) then
        exports.ogz_supplychain:errorNotify("Invalid Restaurant", "Restaurant not found")
        return
    end
    
    currentRestaurantId = restaurantId
    isMenuOpen = true
    
    -- Check ownership/staff access
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        if ownershipData.isOwner then
            openOwnerMainMenu(restaurantId, ownershipData)
        elseif ownershipData.isStaff then
            openStaffMainMenu(restaurantId, ownershipData)
        else
            -- Check traditional job access
            local playerData = QBX.PlayerData
            local PlayerJob = PlayerData.job
            local restaurantJob = Config.Restaurants[restaurantId].job
            
            if PlayerJob and PlayerJob.name == restaurantJob then
                openEmployeeMainMenu(restaurantId)
            else
                exports.ogz_supplychain:errorNotify("Access Denied", "You do not have permission to access this restaurant")
                isMenuOpen = false
            end
        end
    end, restaurantId)
end)

-- Owner main menu
function openOwnerMainMenu(restaurantId, ownershipData)
    local options = {
        {
            title = "🏪 Business Management",
            description = "Manage your restaurant business operations",
            icon = "fas fa-building",
            onSelect = function()
                TriggerEvent("restaurant:openBusinessManagement", restaurantId)
            end
        },
        {
            title = "👥 Staff Management", 
            description = "Hire, manage and schedule staff members",
            icon = "fas fa-users",
            onSelect = function()
                TriggerEvent("restaurant:openStaffManagement", restaurantId)
            end
        },
        {
            title = "🛒 Order Supplies",
            description = "Order ingredients with owner discounts",
            icon = "fas fa-shopping-cart",
            onSelect = function()
                openOrderingMenu(restaurantId, true) -- true = owner benefits
            end
        },
        {
            title = "📋 Current Orders",
            description = "View pending supply deliveries",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerServerEvent("restaurant:getCurrentOrders", restaurantId)
            end
        },
        {
            title = "📦 Restaurant Stock",
            description = "View current inventory",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerServerEvent("restaurant:requestStock", restaurantId)
            end
        },
        {
            title = "🚨 Stock Alerts",
            description = "Check ingredient alerts and recommendations",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerEvent("restaurant:openStockAlerts", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_owner_main",
        title = "🏪 " .. Config.Restaurants[restaurantId].name .. " (Owner)",
        options = options,
        onExit = function()
            isMenuOpen = false
            currentRestaurantId = nil
        end
    })
    lib.showContext("restaurant_owner_main")
end

-- Staff main menu
function openStaffMainMenu(restaurantId, ownershipData)
    local options = {
        {
            title = "🛒 Order Supplies",
            description = "Order ingredients for the restaurant",
            icon = "fas fa-shopping-cart",
            onSelect = function()
                openOrderingMenu(restaurantId, false) -- false = no owner benefits
            end
        },
        {
            title = "📋 Current Orders",
            description = "View pending supply deliveries",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerServerEvent("restaurant:getCurrentOrders", restaurantId)
            end
        },
        {
            title = "📦 Restaurant Stock",
            description = "View current inventory",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerServerEvent("restaurant:requestStock", restaurantId)
            end
        }
    }
    
    -- Add staff-specific options based on permissions
    if table.contains(ownershipData.permissions, "manage_inventory") or table.contains(ownershipData.permissions, "all") then
        table.insert(options, {
            title = "🚨 Stock Alerts",
            description = "Check ingredient alerts and recommendations",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerEvent("restaurant:openStockAlerts", restaurantId)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_staff_main",
        title = "🏪 " .. Config.Restaurants[restaurantId].name .. " (" .. ownershipData.position:gsub("^%l", string.upper) .. ")",
        options = options,
        onExit = function()
            isMenuOpen = false
            currentRestaurantId = nil
        end
    })
    lib.showContext("restaurant_staff_main")
end

-- Employee main menu (traditional job system)
function openEmployeeMainMenu(restaurantId)
    local playerData = QBX.PlayerData
    local isBoss = PlayerData.job and PlayerData.job.isboss
    
    local options = {
        {
            title = "🛒 Order Supplies",
            description = "Order ingredients for the restaurant",
            icon = "fas fa-shopping-cart",
            onSelect = function()
                openOrderingMenu(restaurantId, false)
            end,
            disabled = not isBoss
        },
        {
            title = "📋 Current Orders",
            description = "View pending supply deliveries",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerServerEvent("restaurant:getCurrentOrders", restaurantId)
            end
        },
        {
            title = "📦 Restaurant Stock",
            description = "View current inventory",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerServerEvent("restaurant:requestStock", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_employee_main",
        title = "🏪 " .. Config.Restaurants[restaurantId].name .. " (Employee)",
        options = options,
        onExit = function()
            isMenuOpen = false
            currentRestaurantId = nil
        end
    })
    lib.showContext("restaurant_employee_main")
end

-- ===============================================
-- ORDERING SYSTEM
-- ===============================================

-- Open ordering menu
function openOrderingMenu(restaurantId, hasOwnerBenefits)
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openMainMenu", { restaurantId = restaurantId })
            end
        },
        {
            title = "🛒 Shopping Cart (" .. #shoppingCart .. " items)",
            description = string.format("📦 %d boxes • 🏭 %d containers • 💰 $%s", 
                cartBoxCount, cartContainerCount, SupplyUtils.formatMoney(cartTotalCost)),
            icon = "fas fa-shopping-cart",
            onSelect = function()
                openCartMenu(restaurantId, hasOwnerBenefits)
            end,
            disabled = #shoppingCart == 0
        },
        {
            title = "📂 Browse Categories",
            description = "Order ingredients by category",
            icon = "fas fa-list",
            onSelect = function()
                openCategorySelection(restaurantId, hasOwnerBenefits)
            end
        },
        {
            title = "📈 Price History",
            description = "View ingredient price trends",
            icon = "fas fa-chart-line",
            onSelect = function()
                openIngredientPicker(restaurantId)
            end
        },
        {
            title = "🔄 Quick Reorder",
            description = "Reorder frequently used items",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent("restaurant:getQuickReorderItems", restaurantId)
            end
        }
    }
    
    if hasOwnerBenefits then
        table.insert(options, 3, {
            title = "💎 Owner Benefits",
            description = "View your ownership benefits and discounts",
            icon = "fas fa-crown",
            onSelect = function()
                showOwnerBenefits(restaurantId)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_ordering_menu",
        title = "📦 Order Supplies" .. (hasOwnerBenefits and " (Owner)" or ""),
        options = options
    })
    lib.showContext("restaurant_ordering_menu")
end

-- Category selection menu
function openCategorySelection(restaurantId, hasOwnerBenefits)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local items = Config.Items[restaurantJob] or {}
    
    local options = {
        {
            title = "← Back to Ordering",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openOrderingMenu(restaurantId, hasOwnerBenefits)
            end
        }
    }
    
    -- Add categories
    for category, categoryItems in pairs(items) do
        if type(categoryItems) == "table" and next(categoryItems) then
            local categoryIcon = getCategoryIcon(category)
            local itemCount = SupplyUtils.tableLength(categoryItems)
            
            table.insert(options, {
                title = category,
                description = string.format("%d items available", itemCount),
                icon = categoryIcon,
                onSelect = function()
                    openCategoryMenu(restaurantId, category, hasOwnerBenefits)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_category_selection",
        title = "📂 Select Category",
        options = options
    })
    lib.showContext("restaurant_category_selection")
end

-- Category items menu
function openCategoryMenu(restaurantId, category, hasOwnerBenefits)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local categoryItems = Config.Items[restaurantJob][category] or {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openCategorySelection(restaurantId, hasOwnerBenefits)
            end
        },
        {
            title = "🛒 View Cart (" .. #shoppingCart .. ")",
            description = string.format("📦 %d boxes • 💰 $%s", cartBoxCount, SupplyUtils.formatMoney(cartTotalCost)),
            icon = "fas fa-shopping-cart",
            onSelect = function()
                openCartMenu(restaurantId, hasOwnerBenefits)
            end,
            disabled = #shoppingCart == 0
        }
    }
    
    -- Sort items alphabetically
    local sortedItems = {}
    for ingredient, details in pairs(categoryItems) do
        if type(details) == "table" then
            local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or details.label or details.name or ingredient
            table.insert(sortedItems, {
                ingredient = ingredient,
                details = details,
                label = itemLabel
            })
        end
    end
    table.sort(sortedItems, function(a, b) return a.label < b.label end)
    
    -- Add items to menu
    for _, item in ipairs(sortedItems) do
        table.insert(options, {
            title = item.label,
            description = string.format("💰 $%s each", SupplyUtils.formatMoney(item.details.price)),
            icon = itemNames[item.ingredient] and itemNames[item.ingredient].image or "fas fa-box",
            metadata = {
                Price = "$" .. SupplyUtils.formatMoney(item.details.price),
                Category = category
            },
            onSelect = function()
                local input = lib.inputDialog("Add " .. item.label .. " to Cart", {
                    { 
                        type = "number", 
                        label = "Quantity", 
                        placeholder = "Enter amount", 
                        min = 1, 
                        max = 999, 
                        required = true 
                    }
                })
                if input and input[1] and tonumber(input[1]) > 0 then
                    local quantity = tonumber(input[1])
                    if addToCart(item.ingredient, quantity, item.label, item.details.price) then
                        exports.ogz_supplychain:successNotify("Added to Cart", 
                            string.format("%dx %s ($%s)", quantity, item.label, 
                            SupplyUtils.formatMoney(item.details.price * quantity)))
                        
                        -- Refresh menu to show updated cart
                        openCategoryMenu(restaurantId, category, hasOwnerBenefits)
                    end
                end
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_category_menu",
        title = string.format("📂 %s - %d items", category, #sortedItems),
        options = options
    })
    lib.showContext("restaurant_category_menu")
end

-- Shopping cart menu
function openCartMenu(restaurantId, hasOwnerBenefits)
    local options = {
        {
            title = "← Back to Ordering",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openOrderingMenu(restaurantId, hasOwnerBenefits)
            end
        }
    }
    
    if #shoppingCart == 0 then
        table.insert(options, {
            title = "🛒 Cart is Empty",
            description = "Add items from the categories",
            disabled = true
        })
    else
        -- Cart summary
        local summaryText = string.format("📦 %d boxes • 🏭 %d containers • 💰 Total: $%s", 
            cartBoxCount, cartContainerCount, SupplyUtils.formatMoney(cartTotalCost))
        
        if hasOwnerBenefits then
            -- Calculate potential discount
            local discount = calculatePotentialDiscount(cartTotalCost)
            if discount > 0 then
                summaryText = summaryText .. string.format("\n💎 Owner Discount: %d%% (Save $%s)", 
                    math.floor(discount * 100), SupplyUtils.formatMoney(cartTotalCost * discount))
            end
        end
        
        table.insert(options, {
            title = "📋 Order Summary",
            description = summaryText,
            disabled = true
        })
        
        -- Cart items
        for i, cartItem in ipairs(shoppingCart) do
            table.insert(options, {
                title = string.format("%dx %s", cartItem.quantity, cartItem.label),
                description = string.format("$%s each • Subtotal: $%s", 
                    SupplyUtils.formatMoney(cartItem.price), 
                    SupplyUtils.formatMoney(cartItem.price * cartItem.quantity)),
                icon = "fas fa-times",
                onSelect = function()
                    if removeFromCart(i) then
                        exports.ogz_supplychain:successNotify("Removed from Cart", cartItem.label .. " removed")
                        openCartMenu(restaurantId, hasOwnerBenefits)
                    end
                end
            })
        end
        
        -- Action buttons
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items",
            icon = "fas fa-trash",
            onSelect = function()
                clearCart()
                exports.ogz_supplychain:successNotify("Cart Cleared", "All items removed")
                openCartMenu(restaurantId, hasOwnerBenefits)
            end
        })
        
        table.insert(options, {
            title = "✅ Submit Order",
            description = string.format("Place order for $%s (%d boxes)", 
                SupplyUtils.formatMoney(cartTotalCost), cartBoxCount),
            icon = "fas fa-check",
            onSelect = function()
                submitOrder(restaurantId, hasOwnerBenefits)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_cart_menu",
        title = string.format("🛒 Shopping Cart (%d items)", #shoppingCart),
        options = options
    })
    lib.showContext("restaurant_cart_menu")
end

-- ===============================================
-- ORDER SUBMISSION
-- ===============================================

function submitOrder(restaurantId, hasOwnerBenefits)
    if #shoppingCart == 0 then
        exports.ogz_supplychain:errorNotify("Cart Empty", "No items to order")
        return
    end
    
    -- Convert cart to order format
    local orderItems = {}
    for _, cartItem in ipairs(shoppingCart) do
        table.insert(orderItems, {
            ingredient = cartItem.ingredient,
            quantity = cartItem.quantity,
            label = cartItem.label
        })
    end
    
    -- Submit order with appropriate benefits
    if hasOwnerBenefits then
        TriggerServerEvent("restaurant:orderIngredientsAsOwner", orderItems, restaurantId)
    else
        TriggerServerEvent("restaurant:orderIngredients", orderItems, restaurantId)
    end
    
    -- Clear cart and close menus
    clearCart()
    isMenuOpen = false
    currentRestaurantId = nil
    
    exports.ogz_supplychain:successNotify("Order Submitted", 
        string.format("Order sent to warehouse (%d boxes, %d containers)", cartBoxCount, cartContainerCount))
end

-- ===============================================
-- ADDITIONAL FEATURES
-- ===============================================

-- Show owner benefits
function showOwnerBenefits(restaurantId)
    local benefits = Config.RestaurantOwnership.ownerBenefits.bulkDiscounts
    
    local options = {
        {
            title = "← Back to Ordering",
            icon = "fas fa-arrow-left", 
            onSelect = function()
                openOrderingMenu(restaurantId, true)
            end
        },
        {
            title = "👑 Owner Benefits",
            description = "Your exclusive ownership advantages",
            disabled = true
        }
    }
    
    for tier, discount in pairs(benefits) do
        table.insert(options, {
            title = discount.name,
            description = string.format("%d%% discount on orders $%s+", 
                math.floor(discount.discount * 100), SupplyUtils.formatMoney(discount.threshold)),
            icon = "fas fa-percentage"
        })
    end
    
    lib.registerContext({
        id = "owner_benefits_menu",
        title = "💎 Owner Benefits",
        options = options
    })
    lib.showContext("owner_benefits_menu")
end

-- Price history picker
function openIngredientPicker(restaurantId)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local allItems = Config.Items[restaurantJob] or {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    local options = {
        {
            title = "← Back to Ordering",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openOrderingMenu(restaurantId, false)
            end
        }
    }
    
    -- Collect all ingredients
    local ingredients = {}
    for category, categoryItems in pairs(allItems) do
        for ingredient, details in pairs(categoryItems) do
            if type(details) == "table" then
                local label = itemNames[ingredient] and itemNames[ingredient].label or details.label or ingredient
                table.insert(ingredients, {
                    ingredient = ingredient,
                    label = label,
                    category = category
                })
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(ingredients, function(a, b) return a.label < b.label end)
    
    -- Add to menu
    for _, item in ipairs(ingredients) do
        table.insert(options, {
            title = item.label,
            description = string.format("View price history for %s", item.label),
            onSelect = function()
                TriggerServerEvent('market:getPriceHistory', item.ingredient, "restaurant")
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_ingredient_picker",
        title = "📈 Select Ingredient for Price History",
        options = options
    })
    lib.showContext("restaurant_ingredient_picker")
end

-- ===============================================
-- EVENT HANDLERS
-- ===============================================

-- Display current orders
RegisterNetEvent("restaurant:showCurrentOrders")
AddEventHandler("restaurant:showCurrentOrders", function(orders, restaurantId)
    local itemNames = exports.ox_inventory:Items() or {}
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openMainMenu", { restaurantId = restaurantId })
            end
        }
    }
    
    if #orders == 0 then
        table.insert(options, {
            title = "📦 No Active Orders",
            description = "All orders have been completed",
            disabled = true
        })
    else
        for _, order in ipairs(orders) do
            local statusIcon = {
                pending = "⏳",
                accepted = "🚛", 
                in_transit = "🚚"
            }
            
            local itemLabel = itemNames[order.ingredient] and itemNames[order.ingredient].label or order.ingredient
            
            table.insert(options, {
                title = string.format("%s Order #%s", statusIcon[order.status] or "📦", order.order_group_id),
                description = string.format("%dx %s - $%s (%s)", 
                    order.quantity, itemLabel, SupplyUtils.formatMoney(order.total_cost), order.status),
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_current_orders",
        title = "📋 Current Orders Status",
        options = options
    })
    lib.showContext("restaurant_current_orders")
end)

-- Display restaurant stock
RegisterNetEvent("restaurant:showResturantStock")
AddEventHandler("restaurant:showResturantStock", function(restaurantId)
    if not SupplyValidation.isValidRestaurantId(restaurantId) then
        exports.ogz_supplychain:errorNotify("Invalid Restaurant", "Restaurant not found")
        return
    end
    
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    
    -- Open restaurant stock stash
    local success = exports.ox_inventory:openInventory('stash', stashId)
    if not success then
        exports.ogz_supplychain:errorNotify("Error", "Failed to open restaurant stock")
    end
end)

-- Quick reorder menu
RegisterNetEvent("restaurant:showQuickReorderMenu")
AddEventHandler("restaurant:showQuickReorderMenu", function(quickItems, restaurantId)
    local itemNames = exports.ox_inventory:Items() or {}
    
    local options = {
        {
            title = "← Back to Ordering",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openOrderingMenu(restaurantId, false)
            end
        }
    }
    
    if #quickItems == 0 then
        table.insert(options, {
            title = "📦 No Recent Orders",
            description = "No order history found for quick reorder",
            disabled = true
        })
    else
        table.insert(options, {
            title = "📊 Frequently Ordered Items (30 days)",
            description = "Click to add common quantities to cart",
            disabled = true
        })
        
        for _, item in ipairs(quickItems) do
            local itemLabel = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient
            local avgQuantity = math.ceil(item.total_quantity / item.order_count)
            
            table.insert(options, {
                title = itemLabel,
                description = string.format("Ordered %d times • Avg: %d units", 
                    item.order_count, avgQuantity),
                onSelect = function()
                    local input = lib.inputDialog("Quick Reorder: " .. itemLabel, {
                        { 
                            type = "number", 
                            label = "Quantity", 
                            placeholder = "Suggested: " .. avgQuantity,
                            default = avgQuantity,
                            min = 1, 
                            max = 999, 
                            required = true 
                        }
                    })
                    if input and input[1] and tonumber(input[1]) > 0 then
                        local quantity = tonumber(input[1])
                        
                        -- Get price from config
                        local restaurantJob = Config.Restaurants[restaurantId].job
                        local price = getIngredientPrice(item.ingredient, restaurantJob)
                        
                        if addToCart(item.ingredient, quantity, itemLabel, price) then
                            exports.ogz_supplychain:successNotify("Added to Cart", 
                                string.format("%dx %s (Quick Reorder)", quantity, itemLabel))
                            TriggerEvent("restaurant:showQuickReorderMenu", quickItems, restaurantId)
                        end
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_quick_reorder",
        title = "🔄 Quick Reorder",
        options = options
    })
    lib.showContext("restaurant_quick_reorder")
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function getCategoryIcon(category)
    local icons = {
        Meats = "fas fa-drumstick-bite",
        Vegetables = "fas fa-carrot",
        Fruits = "fas fa-apple-alt",
        Dairy = "fas fa-cheese",
        DryGoods = "fas fa-seedling"
    }
    return icons[category] or "fas fa-box"
end

function getIngredientPrice(ingredient, restaurantJob)
    if not Config.Items[restaurantJob] then return 0 end
    
    for category, categoryItems in pairs(Config.Items[restaurantJob]) do
        if categoryItems[ingredient] and categoryItems[ingredient].price then
            return categoryItems[ingredient].price
        end
    end
    return 0
end

function calculatePotentialDiscount(orderValue)
    if not Config.RestaurantOwnership or not Config.RestaurantOwnership.ownerBenefits then return 0 end
    
    local discounts = Config.RestaurantOwnership.ownerBenefits.bulkDiscounts
    local highestDiscount = 0
    
    for tier, discount in pairs(discounts) do
        if orderValue >= discount.threshold and discount.discount > highestDiscount then
            highestDiscount = discount.discount
        end
    end
    
    return highestDiscount
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- ===============================================
-- CLEANUP
-- ===============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        isMenuOpen = false
        currentRestaurantId = nil
        clearCart()
    end
end)