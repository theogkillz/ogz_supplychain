-- ============================================
-- GLOBAL INITIALIZATION
-- This file ensures all globals are available
-- Load this FIRST in client scripts
-- ============================================

-- Ensure Framework is available globally
while not Framework do
    Wait(10)
    if _G.Framework then
        Framework = _G.Framework
        break
    end
end

-- Initialize PlayerData globally
PlayerData = {}

-- Session tracking for achievements
SessionStart = GetGameTimer()
SessionStats = {
    deliveries = 0,
    earnings = 0,
    perfectDeliveries = 0,
    teamDeliveries = 0
}

-- Wait for player to be fully loaded
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    
    -- Get initial player data
    PlayerData = exports.qbx_core:GetPlayerData()
    
    -- Trigger initialization for other systems
    TriggerEvent('ogz_supplychain:playerDataLoaded', PlayerData)
    
    print("[INIT] Player data loaded successfully")
end)

-- Keep PlayerData updated
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    TriggerEvent('ogz_supplychain:jobUpdated', JobInfo)
end)

RegisterNetEvent('qbx:client:OnJobUpdate', function(job)
    PlayerData.job = job
    TriggerEvent('ogz_supplychain:jobUpdated', job)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = exports.qbx_core:GetPlayerData()
    TriggerEvent('ogz_supplychain:playerDataLoaded', PlayerData)
end)

RegisterNetEvent('qbx:playerLoaded', function(data)
    PlayerData = data or exports.qbx_core:GetPlayerData()
    TriggerEvent('ogz_supplychain:playerDataLoaded', PlayerData)
end)

-- Global helper functions
function GetPlayerJob()
    return PlayerData.job
end

function GetPlayerJobName()
    return PlayerData.job and PlayerData.job.name or "unemployed"
end

function HasJobAccess(requiredJobs)
    if not PlayerData.job then return false end
    
    local playerJob = PlayerData.job.name
    
    if type(requiredJobs) == "string" then
        return playerJob == requiredJobs
    elseif type(requiredJobs) == "table" then
        for _, job in ipairs(requiredJobs) do
            if playerJob == job then
                return true
            end
        end
    end
    
    return false
end

-- Export initialization status
exports('isInitialized', function()
    return PlayerData ~= nil and PlayerData.job ~= nil
end)

print("[INIT] Global initialization complete")