-- ============================================
-- FRAMEWORK BRIDGE
-- Handles compatibility between QBCore and QBox
-- ============================================

Framework = {}

-- Detect framework type
local function detectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    end
    return 'unknown'
end

Framework.Type = detectFramework()

-- Client-side framework functions
if not IsDuplicityVersion() then
    if Framework.Type == 'qbox' then
        -- QBox uses exports and LocalPlayer state
        Framework.GetPlayerData = function()
            return exports.qbx_core:GetPlayerData()
        end
        
        Framework.GetPlayerJob = function()
            local playerData = exports.qbx_core:GetPlayerData()
            return playerData and playerData.job
        end
        
        Framework.IsPlayerLoaded = function()
            return LocalPlayer.state.isLoggedIn
        end
        
    elseif Framework.Type == 'qbcore' then
        -- QBCore uses exports
        local QBCore = exports['qb-core']:GetCoreObject()
        
        Framework.GetPlayerData = function()
            return QBCore.Functions.GetPlayerData()
        end
        
        Framework.GetPlayerJob = function()
            local playerData = QBCore.Functions.GetPlayerData()
            return playerData and playerData.job
        end
        
        Framework.IsPlayerLoaded = function()
            local playerData = QBCore.Functions.GetPlayerData()
            return playerData ~= nil and playerData.citizenid ~= nil
        end
    end
    
-- Server-side framework functions
else
    if Framework.Type == 'qbox' then
        -- QBox server functions
        Framework.GetPlayer = function(source)
            return exports.qbx_core:GetPlayer(source)
        end
        
        Framework.GetPlayerJob = function(source)
            local player = exports.qbx_core:GetPlayer(source)
            return player and player.PlayerData and player.PlayerData.job
        end
        
        Framework.AddMoney = function(source, moneyType, amount, reason)
            local player = exports.qbx_core:GetPlayer(source)
            if player then
                player.Functions.AddMoney(moneyType, amount, reason)
                return true
            end
            return false
        end
        
        Framework.RemoveMoney = function(source, moneyType, amount, reason)
            local player = exports.qbx_core:GetPlayer(source)
            if player then
                return player.Functions.RemoveMoney(moneyType, amount, reason)
            end
            return false
        end
        
        Framework.AddItem = function(source, item, amount, metadata)
            local player = exports.qbx_core:GetPlayer(source)
            if player then
                return player.Functions.AddItem(item, amount, metadata)
            end
            return false
        end
        
        Framework.RemoveItem = function(source, item, amount)
            local player = exports.qbx_core:GetPlayer(source)
            if player then
                return player.Functions.RemoveItem(item, amount)
            end
            return false
        end
        
    elseif Framework.Type == 'qbcore' then
        -- QBCore server functions
        local QBCore = exports['qb-core']:GetCoreObject()
        
        Framework.GetPlayer = function(source)
            return QBCore.Functions.GetPlayer(source)
        end
        
        Framework.GetPlayerJob = function(source)
            local player = QBCore.Functions.GetPlayer(source)
            return player and player.PlayerData and player.PlayerData.job
        end
        
        Framework.AddMoney = function(source, moneyType, amount, reason)
            local player = QBCore.Functions.GetPlayer(source)
            if player then
                player.Functions.AddMoney(moneyType, amount, reason)
                return true
            end
            return false
        end
        
        Framework.RemoveMoney = function(source, moneyType, amount, reason)
            local player = QBCore.Functions.GetPlayer(source)
            if player then
                return player.Functions.RemoveMoney(moneyType, amount, reason)
            end
            return false
        end
        
        Framework.AddItem = function(source, item, amount, metadata)
            local player = QBCore.Functions.GetPlayer(source)
            if player then
                return player.Functions.AddItem(item, amount, metadata)
            end
            return false
        end
        
        Framework.RemoveItem = function(source, item, amount)
            local player = QBCore.Functions.GetPlayer(source)
            if player then
                return player.Functions.RemoveItem(item, amount)
            end
            return false
        end
    end
end

-- Universal helper functions
Framework.HasJob = function(job, grade)
    if not IsDuplicityVersion() then
        -- Client side
        local playerJob = Framework.GetPlayerJob()
        if not playerJob then return false end
        
        if type(job) == 'string' then
            return playerJob.name == job and (not grade or playerJob.grade.level >= grade)
        elseif type(job) == 'table' then
            for _, jobName in ipairs(job) do
                if playerJob.name == jobName and (not grade or playerJob.grade.level >= grade) then
                    return true
                end
            end
        end
        return false
    else
        error("Framework.HasJob called on server side - provide source parameter")
    end
end

Framework.HasJobServer = function(source, job, grade)
    local playerJob = Framework.GetPlayerJob(source)
    if not playerJob then return false end
    
    if type(job) == 'string' then
        return playerJob.name == job and (not grade or playerJob.grade.level >= grade)
    elseif type(job) == 'table' then
        for _, jobName in ipairs(job) do
            if playerJob.name == jobName and (not grade or playerJob.grade.level >= grade) then
                return true
            end
        end
    end
    return false
end

-- Export the framework
_G.Framework = Framework

print(string.format("[FRAMEWORK] Detected: %s", Framework.Type))