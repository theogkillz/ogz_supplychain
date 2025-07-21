-- ============================================
-- CORE EVENT COORDINATION SYSTEM
-- Central event management and validation
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()
-- Import QBox modules
local job = Framework.GetPlayerJob()
local hasAccess = Framework.HasJob("hurst")

-- ============================================
-- UNIVERSAL CLIENT VALIDATION SYSTEM
-- ============================================

-- Universal client validation
local function validatePlayerAccess(feature)
    local playerData = playerdata.job
    if not playerData or not playerData.job then
        return false, "No job data available"
    end
    
    local playerJob = playerData.job.name
    local currentJob = playerJob or "unemployed"
    
    -- Use config validation
    local hasAccess = false
    if feature == "achievement" then
        hasAccess = Config.JobValidation.validateAchievementAccess(playerJob)
    elseif feature == "npc" then
        hasAccess = Config.JobValidation.validateNPCAccess(playerJob)
    elseif feature == "vehicle" then
        hasAccess = Config.JobValidation.validateVehicleOwnership(playerJob)
    elseif feature == "manufacturing" then
        hasAccess = Config.JobValidation.validateManufacturingAccess(playerJob)
    elseif feature == "warehouse" then
        hasAccess = Config.JobValidation.validateWarehouseAccess(playerJob)
    elseif feature == "restaurant" then
        hasAccess = Config.JobValidation.validateRestaurantAccess(playerJob)
    end
    
    if not hasAccess then
        local errorMessage = Config.JobValidation.getAccessDeniedMessage(feature, currentJob)
        return false, errorMessage
    end
    
    return true, "Access granted"
end

-- Universal access denied notification
local function showAccessDenied(feature, customMessage)
    local playerData = playerdata.job
    local currentJob = playerData and playerData.job and playerData.job.name or "unemployed"
    
    local message = customMessage or Config.JobValidation.getAccessDeniedMessage(feature, currentJob)
    
    lib.notify({
        title = "🚫 Access Denied",
        description = message,
        type = "error",
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- ============================================
-- CORE EVENT HANDLERS
-- ============================================

-- Show Leaderboard Event (Universal)
RegisterNetEvent("warehouse:showLeaderboard")
AddEventHandler("warehouse:showLeaderboard", function(leaderboard)
    local options = {}
    for i, entry in ipairs(leaderboard) do
        table.insert(options, {
            title = string.format("#%d: %s", i, entry.name),
            description = string.format("**Deliveries**: %d\n**Earnings**: $%d", entry.deliveries, entry.earnings),
            metadata = {
                Deliveries = tostring(entry.deliveries),
                Earnings = "$" .. tostring(entry.earnings)
            }
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = "No Drivers Yet",
            description = "Complete deliveries to appear on the leaderboard!",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "leaderboard_menu",
        title = "Top Delivery Drivers",
        options = options
    })
    lib.showContext("leaderboard_menu")
end)

-- ============================================
-- SYSTEM INITIALIZATION
-- ============================================

-- Resource start handler
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CORE] Supply Chain client system initialized")
        
        -- Initialize core systems
        TriggerEvent('supplychain:clientReady')
    end
end)

-- Resource stop handler
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CORE] Supply Chain client system shutting down")
        
        -- Cleanup operations
        TriggerEvent('supplychain:clientShutdown')
    end
end)

-- Job change handler
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    print("[CORE] Job updated to: " .. (JobInfo.name or "unemployed"))
    
    -- Notify all subsystems of job change
    TriggerEvent('supplychain:jobChanged', JobInfo)
end)

-- ============================================
-- EXPORTS FOR OTHER SYSTEMS
-- ============================================

-- Export validation helper
exports('validatePlayerAccess', validatePlayerAccess)

-- Export notification helper
exports('showAccessDenied', showAccessDenied)

-- Export core utilities
exports('getCoreObject', function()
    return QBCore
end)

print("[CORE] Event coordination system loaded")