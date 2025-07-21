-- Admin Commands for Testing and Management

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Test framework bridge
RegisterCommand('sc_test_framework', function(source, args, rawCommand)
    local src = source
    
    -- Server console test
    if src == 0 then
        print("^2[SupplyChain Test]^7 Framework Type: " .. tostring(Framework.Type))
        print("^2[SupplyChain Test]^7 Framework loaded: " .. (Framework.Object and "Yes" or "No"))
        return
    end
    
    -- Player test
    local player = Framework.GetPlayer(src)
    if player then
        local job = Framework.GetPlayerJob(player)
        Framework.Notify(src, string.format("Framework: %s | Job: %s", Framework.Type, job.name), "success")
    else
        Framework.Notify(src, "Failed to get player data", "error")
    end
end, false)

-- Test state manager
RegisterCommand('sc_test_state', function(source, args, rawCommand)
    local src = source
    
    -- Add test order
    local testOrderId = "TEST-" .. os.time()
    StateManager.AddOrder(testOrderId, {
        restaurantId = 1,
        items = {{ itemName = "test_item", quantity = 10 }},
        totalCost = 100,
        status = Constants.OrderStatus.PENDING
    })
    
    -- Get active orders
    local activeOrders = 0
    for _ in pairs(SupplyChain.State.ActiveOrders) do
        activeOrders = activeOrders + 1
    end
    
    if src == 0 then
        print("^2[SupplyChain Test]^7 State Manager working")
        print("^2[SupplyChain Test]^7 Active Orders: " .. activeOrders)
    else
        Framework.Notify(src, "State Manager Test: " .. activeOrders .. " active orders", "info")
    end
    
    -- Clean up test order
    StateManager.RemoveOrder(testOrderId)
end, false)

-- Add test warehouse stock
RegisterCommand('sc_add_stock', function(source, args, rawCommand)
    local src = source
    
    if src > 0 and not IsPlayerAceAllowed(src, "command.sc_add_stock") then
        Framework.Notify(src, "Insufficient permissions", "error")
        return
    end
    
    local item = args[1] or "bun"
    local amount = tonumber(args[2]) or 100
    
    MySQL.Async.execute([[
        INSERT INTO supply_warehouse_stock (ingredient, quantity)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE quantity = quantity + ?
    ]], { item, amount, amount }, function(affectedRows)
        local message = string.format("Added %d x %s to warehouse stock", amount, item)
        
        if src == 0 then
            print("^2[SupplyChain]^7 " .. message)
        else
            Framework.Notify(src, message, "success")
        end
        
        -- Refresh cache
        exports['ogz_supplychain']:GetWarehouseStock()
    end)
end, true)

-- Test restaurant order
RegisterCommand('sc_test_order', function(source, args, rawCommand)
    local src = source
    
    if src == 0 then
        print("This command must be run by a player")
        return
    end
    
    local player = Framework.GetPlayer(src)
    if not player then return end
    
    local job = Framework.GetPlayerJob(player)
    local restaurantId = nil
    
    -- Find restaurant for player's job
    for id, restaurant in pairs(Config.Restaurants) do
        if restaurant.job == job.name then
            restaurantId = id
            break
        end
    end
    
    if not restaurantId then
        Framework.Notify(src, "You don't work at a restaurant", "error")
        return
    end
    
    -- Create test order
    local testItems = {
        { ingredient = "bun", quantity = 10, label = "Buns" },
        { ingredient = "patty", quantity = 10, label = "Patties" },
        { ingredient = "lettuce", quantity = 5, label = "Lettuce" }
    }
    
    TriggerEvent(Constants.Events.Server.CreateRestaurantOrder, testItems, restaurantId)
    Framework.Notify(src, "Test order created", "success")
end, false)

-- Show active deliveries
RegisterCommand('sc_deliveries', function(source, args, rawCommand)
    local src = source
    local activeDeliveries = exports['ogz_supplychain']:GetActiveDeliveries()
    local count = 0
    
    for playerId, delivery in pairs(activeDeliveries) do
        count = count + 1
        local message = string.format("Player %d: Order %s to Restaurant %d", 
            playerId, delivery.orderGroupId, delivery.restaurantId)
        
        if src == 0 then
            print("^2[SupplyChain]^7 " .. message)
        else
            Framework.Notify(src, message, "info")
        end
    end
    
    if count == 0 then
        local message = "No active deliveries"
        if src == 0 then
            print("^2[SupplyChain]^7 " .. message)
        else
            Framework.Notify(src, message, "info")
        end
    end
end, false)

-- Reset all orders
RegisterCommand('sc_reset_orders', function(source, args, rawCommand)
    local src = source
    
    if src > 0 and not IsPlayerAceAllowed(src, "command.sc_reset_orders") then
        Framework.Notify(src, "Insufficient permissions", "error")
        return
    end
    
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE status = ?', {
        Constants.OrderStatus.PENDING,
        Constants.OrderStatus.ACCEPTED
    }, function(affectedRows)
        local message = string.format("Reset %d orders to pending", affectedRows)
        
        if src == 0 then
            print("^2[SupplyChain]^7 " .. message)
        else
            Framework.Notify(src, message, "success")
        end
    end)
end, true)

-- Show warehouse stock
RegisterCommand('sc_stock', function(source, args, rawCommand)
    local src = source
    
    MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock ORDER BY ingredient', {}, function(results)
        if src == 0 then
            print("^2[SupplyChain]^7 === Warehouse Stock ===")
            for _, item in ipairs(results) do
                print(string.format("  %s: %d units", item.ingredient, item.quantity))
            end
        else
            Framework.Notify(src, "Check console (F8) for stock list", "info")
            for _, item in ipairs(results) do
                print(string.format("%s: %d units", item.ingredient, item.quantity))
            end
        end
    end)
end, false)

-- Clear all data (DANGEROUS - Admin only)
RegisterCommand('sc_clear_all', function(source, args, rawCommand)
    local src = source
    
    if src > 0 and not IsPlayerAceAllowed(src, "command.sc_clear_all") then
        Framework.Notify(src, "Insufficient permissions", "error")
        return
    end
    
    if args[1] ~= "confirm" then
        local message = "Use: /sc_clear_all confirm (This will DELETE all supply chain data!)"
        if src == 0 then
            print("^1[SupplyChain]^7 " .. message)
        else
            Framework.Notify(src, message, "error")
        end
        return
    end
    
    -- Clear all tables
    local tables = {
        'supply_orders',
        'supply_stock',
        'supply_deliveries',
        'supply_delivery_logs',
        'supply_teams',
        'supply_team_members'
    }
    
    for _, table in ipairs(tables) do
        MySQL.Async.execute('DELETE FROM ' .. table, {})
    end
    
    local message = "All supply chain data cleared!"
    if src == 0 then
        print("^1[SupplyChain]^7 " .. message)
    else
        Framework.Notify(src, message, "success")
    end
end, true)

-- Main admin menu
RegisterCommand(Config.Admin.commands.menu or 'supplychain', function(source, args, rawCommand)
    local src = source
    
    if src == 0 then
        print("^2[SupplyChain]^7 Admin Commands:")
        print("  sc_test_framework - Test framework bridge")
        print("  sc_test_state - Test state manager")
        print("  sc_add_stock [item] [amount] - Add warehouse stock")
        print("  sc_test_order - Create test order (player only)")
        print("  sc_deliveries - Show active deliveries")
        print("  sc_reset_orders - Reset accepted orders")
        print("  sc_stock - Show warehouse stock")
        print("  sc_clear_all confirm - Clear all data (DANGEROUS)")
        return
    end
    
    -- Check admin permission
    local hasPermission = false
    for _, perm in ipairs(Config.Admin.permissions) do
        if IsPlayerAceAllowed(src, perm) then
            hasPermission = true
            break
        end
    end
    
    if not hasPermission then
        Framework.Notify(src, "Insufficient permissions", "error")
        return
    end
    
    -- Show admin menu (placeholder for UI)
    Framework.Notify(src, "Admin menu coming soon! Use individual commands for now", "info")
end, false)

print("^2[SupplyChain]^7 Admin commands loaded")