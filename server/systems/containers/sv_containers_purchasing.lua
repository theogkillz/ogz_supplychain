local QBCore = exports['qb-core']:GetCoreObject()

-- Give Empty Containers
RegisterNetEvent('containers:giveEmpty')
AddEventHandler('containers:giveEmpty', function(containerType, amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then return end
    
    -- Validate container type
    if not Config.ContainerMaterials or not Config.ContainerMaterials[containerType] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid container type.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Validate amount
    if not amount or amount <= 0 or amount > 50 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid amount (1-50).',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Give containers
    local success = xPlayer.Functions.AddItem(containerType, amount)
    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Containers Obtained',
            description = string.format('Received %d %s', amount, Config.ContainerMaterials[containerType].label),
            type = 'success',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Inventory full or item not found.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- Buy Container Materials
RegisterNetEvent('containers:buyMaterial')
AddEventHandler('containers:buyMaterial', function(containerType, amount, totalCost)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then return end
    
    -- Validate container type
    if not Config.ContainerMaterials or not Config.ContainerMaterials[containerType] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid container type.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Validate amount and cost
    local expectedCost = Config.ContainerMaterials[containerType].price * amount
    if totalCost ~= expectedCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Price mismatch. Try again.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Check if player has enough money
    if xPlayer.PlayerData.money.cash < totalCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            description = string.format('You need $%d cash.', totalCost),
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Remove money and give items
    if xPlayer.Functions.RemoveMoney('cash', totalCost, "Container materials purchase") then
        local success = xPlayer.Functions.AddItem(containerType, amount)
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Purchase Successful',
                description = string.format('Bought %d %s for $%d', amount, Config.ContainerMaterials[containerType].label, totalCost),
                type = 'success',
                duration = 5000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        else
            -- Refund money if item couldn't be added
            xPlayer.Functions.AddMoney('cash', totalCost, "Container purchase refund")
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Inventory full. Money refunded.',
                type = 'error',
                duration = 5000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
end)

-- Add this at the very end of sv_containers.lua
exports('completeContainerDelivery', function(orderGroupId, restaurantId)
    -- Update container status to delivered
    MySQL.Async.execute([[
        UPDATE supply_containers 
        SET status = 'delivered', updated_at = CURRENT_TIMESTAMP 
        WHERE order_group_id = ?
    ]], {orderGroupId})
    
    print(string.format("[CONTAINERS] Delivery completed for order %s to restaurant %s", orderGroupId, restaurantId))
    return true
end)