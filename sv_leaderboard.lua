QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('warehouse:getLeaderboard')
AddEventHandler('warehouse:getLeaderboard', function()
    local playerId = source
    MySQL.Async.fetchAll('SELECT * FROM supply_leaderboard ORDER BY deliveries DESC LIMIT @limit', {
        ['@limit'] = Config.Leaderboard.maxEntries
    }, function(results)
        TriggerClientEvent('warehouse:showLeaderboard', playerId, results)
    end)
end)

RegisterNetEvent('pay:driver')
AddEventHandler('pay:driver', function(driverId, amount)
    local xPlayer = QBCore.Functions.GetPlayer(driverId)
    if xPlayer then
        xPlayer.Functions.AddMoney('bank', amount, "Delivery payment")
        TriggerClientEvent('ox_lib:notify', driverId, {
            title = 'Payment Received',
            description = 'Paid $' .. amount .. ' for delivery.',
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', driverId, {
            title = 'Error',
            description = 'Player not found for payment.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)