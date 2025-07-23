-- Framework Bridge Pattern for QBCore/QBox compatibility

SupplyChain = SupplyChain or {}
SupplyChain.Framework = {}

-- Detect framework type
local frameworkName = GetResourceState('qb-core') == 'started' and 'qbcore' or 
                     GetResourceState('qbx_core') == 'started' and 'qbox' or nil

if not frameworkName then
    error("No compatible framework detected. Please ensure QBCore or QBox is running.")
end

-- Framework object storage
local Framework = nil
local isServer = IsDuplicityVersion()

-- Initialize framework
if frameworkName == 'qbcore' then
    Framework = exports['qb-core']:GetCoreObject()
elseif frameworkName == 'qbox' then
    Framework = exports.qbx_core
end

-- Store framework type
SupplyChain.Framework.Type = frameworkName
SupplyChain.Framework.Object = Framework

-- Unified Player Functions
if isServer then
    -- Server-side player functions
    
    function SupplyChain.Framework.GetPlayer(source)
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayer(source)
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetPlayer(source)
        end
    end
    
    function SupplyChain.Framework.GetPlayerByCitizenId(citizenid)
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayerByCitizenId(citizenid)
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetPlayerByCitizenId(citizenid)
        end
    end
    
    function SupplyChain.Framework.GetPlayers()
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayers()
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetAllPlayers()
        end
    end
    
    -- Money functions
    function SupplyChain.Framework.AddMoney(player, account, amount, reason)
        if frameworkName == 'qbcore' then
            return player.Functions.AddMoney(account, amount, reason)
        elseif frameworkName == 'qbox' then
            return player.Functions.AddMoney(account, amount, reason)
        end
    end
    
    function SupplyChain.Framework.RemoveMoney(player, account, amount, reason)
        if frameworkName == 'qbcore' then
            return player.Functions.RemoveMoney(account, amount, reason)
        elseif frameworkName == 'qbox' then
            return player.Functions.RemoveMoney(account, amount, reason)
        end
    end
    
    function SupplyChain.Framework.GetMoney(player, account)
        if frameworkName == 'qbcore' then
            return player.Functions.GetMoney(account)
        elseif frameworkName == 'qbox' then
            return player.Functions.GetMoney(account)
        end
    end
    
    -- Job functions
    function SupplyChain.Framework.GetPlayerJob(player)
        if frameworkName == 'qbcore' then
            return player.PlayerData.job
        elseif frameworkName == 'qbox' then
            return player.PlayerData.job
        end
    end
    
    function SupplyChain.Framework.SetPlayerJob(player, job, grade)
        if frameworkName == 'qbcore' then
            return player.Functions.SetJob(job, grade)
        elseif frameworkName == 'qbox' then
            return player.Functions.SetJob(job, grade)
        end
    end
    
    -- Item functions
    function SupplyChain.Framework.AddItem(player, item, amount, metadata)
        if frameworkName == 'qbcore' then
            return player.Functions.AddItem(item, amount, nil, metadata)
        elseif frameworkName == 'qbox' then
            return exports.ox_inventory:AddItem(player.PlayerData.source, item, amount, metadata)
        end
    end
    
    function SupplyChain.Framework.RemoveItem(player, item, amount)
        if frameworkName == 'qbcore' then
            return player.Functions.RemoveItem(item, amount)
        elseif frameworkName == 'qbox' then
            return exports.ox_inventory:RemoveItem(player.PlayerData.source, item, amount)
        end
    end
    
    function SupplyChain.Framework.GetItemCount(player, item)
        if frameworkName == 'qbcore' then
            local itemData = player.Functions.GetItemByName(item)
            return itemData and itemData.amount or 0
        elseif frameworkName == 'qbox' then
            return exports.ox_inventory:GetItemCount(player.PlayerData.source, item)
        end
    end
    
else
    -- Client-side player functions
    
    function SupplyChain.Framework.GetPlayerData()
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayerData()
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetPlayerData()
        end
    end
    
    function SupplyChain.Framework.GetJob()
        local playerData = SupplyChain.Framework.GetPlayerData()
        return playerData and playerData.job or nil
    end
    
    function SupplyChain.Framework.IsLoggedIn()
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayerData().citizenid ~= nil
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetPlayerData().citizenid ~= nil
        end
    end
    
    function SupplyChain.Framework.GetClosestPlayer()
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetClosestPlayer()
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetClosestPlayer()
        end
    end
    
    function SupplyChain.Framework.GetPlayersFromCoords(coords, distance)
        if frameworkName == 'qbcore' then
            return Framework.Functions.GetPlayersFromCoords(coords, distance)
        elseif frameworkName == 'qbox' then
            return exports.qbx_core:GetPlayersFromCoords(coords, distance)
        end
    end
end

-- Shared utility functions
function SupplyChain.Framework.TriggerCallback(name, cb, ...)
    if frameworkName == 'qbcore' then
        if isServer then
            Framework.Functions.CreateCallback(name, cb)
        else
            Framework.Functions.TriggerCallback(name, cb, ...)
        end
    elseif frameworkName == 'qbox' then
        if isServer then
            exports.qbx_core:CreateCallback(name, cb)
        else
            exports.qbx_core:TriggerCallback(name, cb, ...)
        end
    end
end

-- Notification wrapper
function SupplyChain.Framework.Notify(source, message, type, duration)
    if isServer then
        TriggerClientEvent('SupplyChain:Client:Notify', source, message, type, duration)
    else
        -- Client-side notification - ox_lib will automatically use lation_ui if available
        lib.notify({
            title = 'Supply Chain',
            description = message,
            type = type or 'info',
            duration = duration or 5000,
            position = Config.UI.notificationPosition or 'center-right',
            style = Config.UI.theme == 'dark' and {
                backgroundColor = '#141517',
                color = '#C1C2C5',
                ['.description'] = {
                    color = '#909296'
                }
            } or nil,
            icon = 'box',
            iconColor = type == 'error' and '#C53030' or 
                       type == 'success' and '#2F8B26' or '#3B82F6'
        })
    end
end

-- Event registration wrapper
function SupplyChain.Framework.RegisterEvent(eventName, handler)
    if isServer then
        RegisterNetEvent(eventName, handler)
    else
        RegisterNetEvent(eventName)
        AddEventHandler(eventName, handler)
    end
end

-- Export the framework bridge
exports('GetFramework', function()
    return SupplyChain.Framework
end)

-- Initialize notification handler on client
if not isServer then
    RegisterNetEvent('SupplyChain:Client:Notify')
    AddEventHandler('SupplyChain:Client:Notify', function(message, type, duration)
        SupplyChain.Framework.Notify(nil, message, type, duration)
    end)
end

print(string.format("^2[SupplyChain]^7 Framework Bridge initialized for %s", frameworkName))