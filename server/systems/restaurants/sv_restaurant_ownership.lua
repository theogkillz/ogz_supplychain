-- ============================================
-- RESTAURANT OWNERSHIP SYSTEM - ENTERPRISE FOUNDATION
-- server/systems/restaurants/sv_restaurant_ownership.lua
-- Complete restaurant ownership with staff management and financial tracking
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Restaurant ownership data
local restaurantOwners = {}
local restaurantFinances = {}
local staffManagement = {}

-- ============================================
-- RESTAURANT OWNERSHIP CORE FUNCTIONS
-- ============================================

-- Initialize restaurant ownership system
local function initializeRestaurantOwnership()
    -- Load existing restaurant owners from database
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_owners', {}, function(results)
        if results then
            for _, owner in ipairs(results) do
                restaurantOwners[owner.restaurant_id] = {
                    owner_citizenid = owner.owner_citizenid,
                    owner_name = owner.owner_name,
                    purchase_date = owner.purchase_date,
                    purchase_price = owner.purchase_price,
                    ownership_percentage = owner.ownership_percentage or 100,
                    active = owner.active == 1
                }
            end
        end
    end)
    
    print("[RESTAURANT OWNERSHIP] System initialized - " .. table.maxn(restaurantOwners) .. " restaurants loaded")
end

-- Check if player owns a restaurant
local function playerOwnsRestaurant(citizenid, restaurantId)
    if restaurantId then
        local ownership = restaurantOwners[restaurantId]
        return ownership and ownership.owner_citizenid == citizenid and ownership.active
    else
        -- Check if player owns any restaurant
        for id, ownership in pairs(restaurantOwners) do
            if ownership.owner_citizenid == citizenid and ownership.active then
                return true, id
            end
        end
        return false, nil
    end
end

-- Calculate restaurant purchase price
local function calculateRestaurantPrice(restaurantId)
    if not Config.RestaurantOwnership or not Config.RestaurantOwnership.restaurants[restaurantId] then
        return 0
    end
    
    local basePrice = Config.RestaurantOwnership.restaurants[restaurantId].basePrice or 500000
    local locationMultiplier = Config.RestaurantOwnership.restaurants[restaurantId].locationMultiplier or 1.0
    local popularityBonus = Config.RestaurantOwnership.restaurants[restaurantId].popularityBonus or 0
    
    return math.floor(basePrice * locationMultiplier + popularityBonus)
end

-- ============================================
-- RESTAURANT PURCHASE SYSTEM
-- ============================================

-- Purchase restaurant
RegisterNetEvent('restaurant:attemptPurchase')
AddEventHandler('restaurant:attemptPurchase', function(restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local playerName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    
    -- Validate restaurant ID
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Restaurant Purchase Error',
            description = 'Invalid restaurant selection.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Check if restaurant is already owned
    if restaurantOwners[restaurantId] and restaurantOwners[restaurantId].active then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Restaurant Unavailable',
            description = 'This restaurant is already owned by another player.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Check if player already owns a restaurant
    local alreadyOwns, ownedRestaurantId = playerOwnsRestaurant(citizenid)
    if alreadyOwns then
        local ownedName = Config.Restaurants[ownedRestaurantId].name
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Ownership Limit',
            description = string.format('You already own **%s**.\nSell your current restaurant first.', ownedName),
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Calculate purchase price
    local purchasePrice = calculateRestaurantPrice(restaurantId)
    
    -- Check if player has enough money
    if xPlayer.PlayerData.money.bank < purchasePrice then
        local missingAmount = purchasePrice - xPlayer.PlayerData.money.bank
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Insufficient Funds',
            description = string.format('**Restaurant Price:** $%s\n**Your Balance:** $%s\n**Missing:** $%s', 
                string.format('%d', purchasePrice),
                string.format('%d', xPlayer.PlayerData.money.bank),
                string.format('%d', missingAmount)
            ),
            type = 'error',
            duration = 12000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Process purchase
    if xPlayer.Functions.RemoveMoney('bank', purchasePrice, "Restaurant purchase: " .. Config.Restaurants[restaurantId].name) then
        
        -- Record ownership in database
        MySQL.Async.execute([[
            INSERT INTO supply_restaurant_owners (
                restaurant_id, owner_citizenid, owner_name, purchase_date, 
                purchase_price, ownership_percentage, active
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            restaurantId, citizenid, playerName, os.time(), 
            purchasePrice, 100, 1
        })
        
        -- Update local ownership data
        restaurantOwners[restaurantId] = {
            owner_citizenid = citizenid,
            owner_name = playerName,
            purchase_date = os.time(),
            purchase_price = purchasePrice,
            ownership_percentage = 100,
            active = true
        }
        
        -- Initialize restaurant finances
        restaurantFinances[restaurantId] = {
            totalRevenue = 0,
            totalExpenses = 0,
            dailyRevenue = 0,
            dailyExpenses = 0,
            lastReset = os.date("%Y-%m-%d")
        }
        
        -- Success notification
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🎉 RESTAURANT PURCHASED!',
            description = string.format(
                '**%s** is now yours!\n💰 **Purchase Price:** $%s\n🏪 **You are now the owner!**\n\n📊 Use `/restaurant` to manage your business',
                Config.Restaurants[restaurantId].name,
                string.format('%d', purchasePrice)
            ),
            type = 'success',
            duration = 20000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        -- Log the purchase
        print(string.format("[RESTAURANT OWNERSHIP] %s purchased %s for $%d", 
            playerName, Config.Restaurants[restaurantId].name, purchasePrice))
        
        -- Trigger ownership change event for other systems
        TriggerEvent('restaurant:ownershipChanged', restaurantId, citizenid, 'purchased')
        
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Purchase Failed',
            description = 'Transaction failed. Please try again.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- ============================================
-- RESTAURANT MANAGEMENT SYSTEM
-- ============================================

-- Open restaurant management menu
RegisterNetEvent('restaurant:openManagementMenu')
AddEventHandler('restaurant:openManagementMenu', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local ownsRestaurant, restaurantId = playerOwnsRestaurant(citizenid)
    
    if not ownsRestaurant then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Access Denied',
            description = 'You must own a restaurant to access management features.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Get restaurant financial data
    local finances = restaurantFinances[restaurantId] or {
        totalRevenue = 0, totalExpenses = 0, dailyRevenue = 0, dailyExpenses = 0
    }
    
    -- Get staff information
    local staffCount = 0
    if staffManagement[restaurantId] then
        for _, staff in pairs(staffManagement[restaurantId]) do
            if staff.active then staffCount = staffCount + 1 end
        end
    end
    
    -- Send management data to client
    TriggerClientEvent('restaurant:showManagementMenu', src, {
        restaurantId = restaurantId,
        restaurantData = Config.Restaurants[restaurantId],
        ownershipData = restaurantOwners[restaurantId],
        financialData = finances,
        staffCount = staffCount,
        managementOptions = {
            canHireStaff = true,
            canSetPrices = true,
            canViewAnalytics = true,
            canSellRestaurant = true
        }
    })
end)

-- ============================================
-- RESTAURANT SELLING SYSTEM  
-- ============================================

-- Sell restaurant
RegisterNetEvent('restaurant:sellRestaurant')
AddEventHandler('restaurant:sellRestaurant', function(restaurantId, askingPrice)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Verify ownership
    if not playerOwnsRestaurant(citizenid, restaurantId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Access Denied',
            description = 'You do not own this restaurant.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Calculate base selling price (80% of original purchase price + improvements)
    local ownership = restaurantOwners[restaurantId]
    local baseSellPrice = math.floor(ownership.purchase_price * 0.8)
    
    -- Add value for improvements/profits
    local finances = restaurantFinances[restaurantId]
    if finances and finances.totalRevenue > finances.totalExpenses then
        local profitBonus = math.floor((finances.totalRevenue - finances.totalExpenses) * 0.1)
        baseSellPrice = baseSellPrice + profitBonus
    end
    
    -- Validate asking price (can't be more than 120% of calculated value)
    local maxAskingPrice = math.floor(baseSellPrice * 1.2)
    if askingPrice and askingPrice > maxAskingPrice then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🏪 Price Too High',
            description = string.format('Maximum asking price: $%s\nSuggested price: $%s', 
                string.format('%d', maxAskingPrice),
                string.format('%d', baseSellPrice)
            ),
            type = 'error',
            duration = 12000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local finalSellPrice = askingPrice or baseSellPrice
    
    -- Process sale
    xPlayer.Functions.AddMoney('bank', finalSellPrice, "Restaurant sale: " .. Config.Restaurants[restaurantId].name)
    
    -- Update database
    MySQL.Async.execute('UPDATE supply_restaurant_owners SET active = 0, sale_date = ?, sale_price = ? WHERE restaurant_id = ? AND owner_citizenid = ?', 
        {os.time(), finalSellPrice, restaurantId, citizenid})
    
    -- Update local data
    restaurantOwners[restaurantId].active = false
    restaurantOwners[restaurantId].sale_date = os.time()
    restaurantOwners[restaurantId].sale_price = finalSellPrice
    
    -- Clear restaurant data
    restaurantFinances[restaurantId] = nil
    staffManagement[restaurantId] = nil
    
    -- Success notification
    TriggerClientEvent('ox_lib:notify', src, {
        title = '🏪 RESTAURANT SOLD!',
        description = string.format(
            '**%s** sold successfully!\n💰 **Sale Price:** $%s\n📈 **Profit/Loss:** %s$%s',
            Config.Restaurants[restaurantId].name,
            string.format('%d', finalSellPrice),
            finalSellPrice >= ownership.purchase_price and '+' or '',
            string.format('%d', finalSellPrice - ownership.purchase_price)
        ),
        type = 'success',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Log the sale
    print(string.format("[RESTAURANT OWNERSHIP] %s sold %s for $%d", 
        ownership.owner_name, Config.Restaurants[restaurantId].name, finalSellPrice))
    
    -- Trigger ownership change event
    TriggerEvent('restaurant:ownershipChanged', restaurantId, citizenid, 'sold')
end)

-- ============================================
-- FINANCIAL TRACKING SYSTEM
-- ============================================

-- Track restaurant revenue
RegisterNetEvent('restaurant:trackRevenue')
AddEventHandler('restaurant:trackRevenue', function(restaurantId, amount, source_type)
    if not restaurantOwners[restaurantId] or not restaurantOwners[restaurantId].active then
        return
    end
    
    if not restaurantFinances[restaurantId] then
        restaurantFinances[restaurantId] = {
            totalRevenue = 0, totalExpenses = 0, dailyRevenue = 0, dailyExpenses = 0,
            lastReset = os.date("%Y-%m-%d")
        }
    end
    
    local finances = restaurantFinances[restaurantId]
    
    -- Check if we need to reset daily stats
    local today = os.date("%Y-%m-%d")
    if finances.lastReset ~= today then
        finances.dailyRevenue = 0
        finances.dailyExpenses = 0
        finances.lastReset = today
    end
    
    -- Add revenue
    finances.totalRevenue = finances.totalRevenue + amount
    finances.dailyRevenue = finances.dailyRevenue + amount
    
    -- Update database
    MySQL.Async.execute([[
        INSERT INTO supply_restaurant_finances 
        (restaurant_id, transaction_type, amount, source_type, transaction_date)
        VALUES (?, 'revenue', ?, ?, ?)
    ]], {restaurantId, amount, source_type or 'order', os.time()})
end)

-- Track restaurant expenses
RegisterNetEvent('restaurant:trackExpense')
AddEventHandler('restaurant:trackExpense', function(restaurantId, amount, expense_type)
    if not restaurantOwners[restaurantId] or not restaurantOwners[restaurantId].active then
        return
    end
    
    if not restaurantFinances[restaurantId] then
        restaurantFinances[restaurantId] = {
            totalRevenue = 0, totalExpenses = 0, dailyRevenue = 0, dailyExpenses = 0,
            lastReset = os.date("%Y-%m-%d")
        }
    end
    
    local finances = restaurantFinances[restaurantId]
    
    -- Add expense
    finances.totalExpenses = finances.totalExpenses + amount
    finances.dailyExpenses = finances.dailyExpenses + amount
    
    -- Update database
    MySQL.Async.execute([[
        INSERT INTO supply_restaurant_finances 
        (restaurant_id, transaction_type, amount, source_type, transaction_date)
        VALUES (?, 'expense', ?, ?, ?)
    ]], {restaurantId, amount, expense_type or 'supplies', os.time()})
end)

-- ============================================
-- EXPORT FUNCTIONS
-- ============================================

-- Export ownership check function
exports('playerOwnsRestaurant', playerOwnsRestaurant)
exports('getRestaurantOwner', function(restaurantId)
    return restaurantOwners[restaurantId]
end)
exports('getRestaurantFinances', function(restaurantId)
    return restaurantFinances[restaurantId]
end)

-- ============================================
-- INITIALIZATION
-- ============================================

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(5000) -- Wait for database connection
        initializeRestaurantOwnership()
        print("[RESTAURANT OWNERSHIP] Restaurant ownership system loaded!")
    end
end)

-- Command to open restaurant management
RegisterCommand('restaurant', function(source, args, rawCommand)
    TriggerEvent('restaurant:openManagementMenu', source)
end, false)

print("[RESTAURANT OWNERSHIP] Foundation system loaded successfully!")