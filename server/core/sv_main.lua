-- Server Core Initialization

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Add this at the TOP of server/core/sv_main.lua, right after the local declarations:

-- Debug: Check what config values are available
CreateThread(function()
    Wait(100) -- Wait for configs to load
    
    print("^3[DEBUG] Checking Config structure:^7")
    
    -- Check if Config exists
    if Config then
        print("^2[DEBUG] Config exists^7")
        
        -- Check if Economics exists
        if Config.Economics then
            print("^2[DEBUG] Config.Economics exists^7")
            
            -- Check what's inside Economics
            print("^3[DEBUG] Config.Economics keys:^7")
            for k, v in pairs(Config.Economics) do
                print("  - " .. tostring(k) .. " = " .. type(v))
            end
            
            -- Check specifically for dynamicPricing
            if Config.Economics.dynamicPricing then
                print("^2[DEBUG] Config.Economics.dynamicPricing exists^7")
                print("  - enabled = " .. tostring(Config.Economics.dynamicPricing.enabled))
            else
                print("^1[DEBUG] Config.Economics.dynamicPricing is NIL^7")
            end
            
            -- Check for market
            if Config.Economics.market then
                print("^2[DEBUG] Config.Economics.market exists^7")
            end
        else
            print("^1[DEBUG] Config.Economics is NIL^7")
        end
        
        -- Check Stock
        if Config.Stock then
            print("^2[DEBUG] Config.Stock exists^7")
            if Config.Stock.stockLevels then
                print("^2[DEBUG] Config.Stock.stockLevels exists^7")
            else
                print("^1[DEBUG] Config.Stock.stockLevels is NIL^7")
            end
        else
            print("^1[DEBUG] Config.Stock is NIL^7")
        end
    else
        print("^1[DEBUG] Config is NIL^7")
    end
end)

-- Server initialization
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print("^2[SupplyChain]^7 Server initializing...")
    
    -- Verify dependencies
    if not VerifyDependencies() then
        print("^1[SupplyChain]^7 Failed to verify dependencies!")
        return
    end
    
    -- Initialize database
    InitializeDatabase()
    
    -- Initialize systems
    InitializeSystems()
    
    -- Start update loops
    StartUpdateLoops()
    
    -- Register callbacks
    RegisterCallbacks()
    
    -- Reset temporary states
    ResetTemporaryStates()
    
    print("^2[SupplyChain]^7 Server initialized successfully!")
end)

-- Verify all dependencies are loaded
function VerifyDependencies()
    local dependencies = {
        'oxmysql',
        'ox_lib',
        'ox_inventory'
    }
    
    for _, dep in ipairs(dependencies) do
        if GetResourceState(dep) ~= 'started' then
            print(string.format("^1[SupplyChain]^7 Required dependency '%s' is not started!", dep))
            return false
        end
    end
    
    return true
end

-- Initialize database tables
function InitializeDatabase()
    -- This would normally create tables if they don't exist
    -- For now, we assume tables are created via SQL file
    print("^2[SupplyChain]^7 Database initialized")
end

-- Initialize all systems
function InitializeSystems()
    -- Initialize restaurant stashes
    if Config.Restaurants then
        for restaurantId, restaurant in pairs(Config.Restaurants) do
            local stashId = "restaurant_stock_" .. tostring(restaurantId)
            exports.ox_inventory:RegisterStash(
                stashId,
                restaurant.name .. " Stock",
                50,  -- slots
                100000,  -- weight
                false,  -- not shared
                { [restaurant.job] = 0 }  -- job access
            )
            print(string.format("^2[SupplyChain]^7 Registered stash for %s", restaurant.name))
            
            -- Register service trays
            if restaurant.trays then
                for trayId, _ in pairs(restaurant.trays) do
                    local trayStashId = "order-tray-" .. restaurant.job .. "-" .. trayId
                    exports.ox_inventory:RegisterStash(
                        trayStashId,
                        "Order Tray",
                        10,  -- slots
                        50000,  -- weight
                        true  -- shared
                    )
                end
            end
            
            -- Register storage areas
            if restaurant.storage then
                for storageId, storage in pairs(restaurant.storage) do
                    local storageStashId = "storage-" .. restaurant.job .. "-" .. storageId
                    exports.ox_inventory:RegisterStash(
                        storageStashId,
                        storage.targetLabel or "Storage",
                        storage.inventory.slots or 20,
                        storage.inventory.weight or 50000,
                        false,  -- not shared
                        { [restaurant.job] = 0 }  -- job access
                    )
                end
            end
        end
    end
    
    -- Load initial warehouse stock
    LoadWarehouseStock()
    
    -- Initialize market prices
    UpdateMarketPrices()
    
    print("^2[SupplyChain]^7 All systems initialized")
end

-- Start update loops
function StartUpdateLoops()
    -- Warehouse stock update loop
    CreateThread(function()
        while true do
            Wait(Config.Warehouse.stockUpdateInterval * 1000)
            LoadWarehouseStock()
        end
    end)
    
    -- Market price update loop
    if Config.Economics and Config.Economics.dynamicPricing and Config.Economics.dynamicPricing.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Economics.dynamicPricing.updateInterval * 1000)
                UpdateMarketPrices()
            end
        end)
    end
    
    -- Emergency order check loop
    if Config.EmergencyOrders.enabled then
        CreateThread(function()
            while true do
                Wait(Config.EmergencyOrders.checkInterval * 1000)
                CheckForEmergencyOrders()
            end
        end)
    end
    
    -- State cleanup loop
    CreateThread(function()
        while true do
            Wait(300000) -- 5 minutes
            StateManager.CleanupStaleData()
        end
    end)
    
    print("^2[SupplyChain]^7 Update loops started")
end

-- Register server callbacks
function RegisterCallbacks()
    -- Get player statistics
    Framework.TriggerCallback('SupplyChain:GetPlayerStats', function(source, cb, targetId)
        local playerId = targetId or source
        local stats = MySQL.scalar.await('SELECT * FROM supply_player_stats WHERE citizenid = ?', {
            GetPlayerCitizenId(playerId)
        })
        cb(stats or {})
    end)
    
    -- Get warehouse stock
    Framework.TriggerCallback('SupplyChain:GetWarehouseStock', function(source, cb)
        local stock = StateManager.GetWarehouseStock()
        if not stock then
            -- Load from database if cache expired
            LoadWarehouseStock()
            stock = StateManager.GetWarehouseStock()
        end
        cb(stock or {})
    end)
    
    -- Check restaurant access
    Framework.TriggerCallback('SupplyChain:CanAccessRestaurant', function(source, cb, restaurantId)
        local player = Framework.GetPlayer(source)
        if not player then
            cb(false)
            return
        end
        
        local restaurant = Config.Restaurants[restaurantId]
        if not restaurant then
            cb(false)
            return
        end
        
        local job = Framework.GetPlayerJob(player)
        cb(job.name == restaurant.job)
    end)
    
    print("^2[SupplyChain]^7 Callbacks registered")
end

-- Reset temporary states
function ResetTemporaryStates()
    -- Reset accepted orders to pending
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE status = ?', {
        Constants.OrderStatus.PENDING,
        Constants.OrderStatus.ACCEPTED
    })
    
    -- Clear active teams
    MySQL.Async.execute('DELETE FROM supply_teams WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)')
    
    -- Reset container rentals
    MySQL.Async.execute('UPDATE supply_containers SET status = ? WHERE status = ? AND last_update < DATE_SUB(NOW(), INTERVAL 1 DAY)', {
        Constants.ContainerStatus.AVAILABLE,
        Constants.ContainerStatus.RENTED
    })
    
    print("^2[SupplyChain]^7 Temporary states reset")
end

-- Load warehouse stock into cache
function LoadWarehouseStock()
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(results)
        local stock = {}
        for _, row in ipairs(results) do
            stock[row.ingredient] = row.quantity
        end
        StateManager.UpdateWarehouseStock(stock)
        
        -- Check for low stock
        if Config.Stock.lowStockThreshold then
            for ingredient, quantity in pairs(stock) do
                if quantity <= Config.Stock.criticalStockThreshold then
                    TriggerEvent('SupplyChain:Server:CriticalStockAlert', ingredient, quantity)
                elseif quantity <= Config.Stock.lowStockThreshold then
                    TriggerEvent('SupplyChain:Server:LowStockAlert', ingredient, quantity)
                end
            end
        end
    end)
end

-- Update market prices
function UpdateMarketPrices()
    if not Config.Economics then return end
    
    local prices = {}
    local playerCount = #GetPlayers()
    local hour = os.date("*t").hour
    
    -- Calculate prices for all items
    for restaurant, categories in pairs(Config.Items) do
        for category, items in pairs(categories) do
            for item, details in pairs(items) do
                local basePrice = details.price or 10
                local dynamicPrice = Config.Economics.CalculateDynamicPrice(
                    basePrice,
                    item,
                    nil,  -- current stock (would be fetched)
                    nil   -- max stock
                )
                prices[item] = dynamicPrice
            end
        end
    end
    
    StateManager.UpdateMarketPrices(prices)
end

-- Check for emergency orders
function CheckForEmergencyOrders()
    MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock WHERE quantity <= ?', {
        Config.EmergencyOrders.triggers.criticalStock
    }, function(results)
        for _, stock in ipairs(results) do
            -- Create emergency order
            local orderId = GenerateOrderId()
            local priority = Constants.EmergencyPriority.CRITICAL
            
            if stock.quantity <= Config.EmergencyOrders.triggers.urgentStock then
                priority = Constants.EmergencyPriority.URGENT
            elseif stock.quantity <= Config.Stock.lowStockThreshold then
                priority = Constants.EmergencyPriority.HIGH
            end
            
            StateManager.AddEmergencyOrder(orderId, {
                ingredient = stock.ingredient,
                quantity = Config.Stock.restockAmount - stock.quantity,
                priority = priority,
                reward = Config.Rewards.delivery.base.minimumPay * Config.EmergencyOrders.priorities.critical.multiplier
            })
            
            -- Notify online warehouse workers
            NotifyWarehouseWorkers('emergency', {
                title = 'Emergency Order',
                description = string.format('Critical stock level for %s!', stock.ingredient),
                type = 'critical'
            })
        end
    end)
end

-- Utility Functions
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

function GenerateOrderId()
    return string.format("ORD-%s-%d", os.date("%Y%m%d"), math.random(1000, 9999))
end

function NotifyWarehouseWorkers(event, data)
    local players = Framework.GetPlayers()
    for _, playerId in ipairs(players) do
        local player = Framework.GetPlayer(playerId)
        if player then
            local job = Framework.GetPlayerJob(player)
            if job and Config.Warehouse.jobAccess then
                for _, allowedJob in ipairs(Config.Warehouse.jobAccess) do
                    if job.name == allowedJob then
                        TriggerClientEvent(Constants.Events.Client.Notify, playerId, data.description, data.type)
                        break
                    end
                end
            end
        end
    end
end

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print("^2[SupplyChain]^7 Cleaning up...")
    
    -- Save any cached data
    -- This would save warehouse stock, active orders, etc.
    
    print("^2[SupplyChain]^7 Cleanup complete")
end)

-- Export functions
exports('GetWarehouseStock', LoadWarehouseStock)
exports('UpdateMarketPrices', UpdateMarketPrices)
exports('CheckEmergencyOrders', CheckForEmergencyOrders)