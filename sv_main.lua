QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if not Config.Restaurants then
            print("[ERROR] Config.Restaurants not loaded in sv_main.lua")
            return
        end
        for id, restaurant in pairs(Config.Restaurants) do
            exports.ox_inventory:RegisterStash("restaurant_stock_" .. tostring(id), "Restaurant Stock " .. (restaurant.name or "Unknown"), 50, 100000, false, { [restaurant.job] = 0 })
            print("[DEBUG] Registered stash: restaurant_stock_" .. tostring(id))
        end
        MySQL.Async.execute('UPDATE supply_orders SET status = @newStatus WHERE status = @oldStatus', {
            ['@newStatus'] = 'pending',
            ['@oldStatus'] = 'accepted'
        }, function(rowsAffected)
            print("[DEBUG] Reset " .. rowsAffected .. " accepted orders to pending")
        end)
    end
end)