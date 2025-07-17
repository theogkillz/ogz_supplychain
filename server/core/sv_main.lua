-- ============================================
-- CORE MAIN SERVER - ENTERPRISE EDITION
-- Universal job validation and system initialization
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- SYSTEM INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^2[CORE] 🚀 Supply Chain Enterprise System Starting...^0')
        
        if not Config.Restaurants then
            print("^1[ERROR] Config.Restaurants not loaded in sv_main.lua^0")
            return
        end
        
        -- Initialize restaurant stashes
        for id, restaurant in pairs(Config.Restaurants) do
            local stashId = "restaurant_stock_" .. tostring(id)
            local stashName = "Restaurant Stock " .. (restaurant.name or "Unknown")
            
            exports.ox_inventory:RegisterStash(stashId, stashName, 50, 100000, false, { [restaurant.job] = 0 })
            print(string.format("^2[CORE] ✅ Registered stash: %s^0", stashId))
        end
        
        -- Reset any stuck orders to pending state
        MySQL.Async.execute('UPDATE supply_orders SET status = @newStatus WHERE status = @oldStatus', {
            ['@newStatus'] = 'pending',
            ['@oldStatus'] = 'accepted'
        }, function(rowsAffected)
            if rowsAffected > 0 then
                print(string.format("^2[CORE] ✅ Reset %d stuck orders to pending^0", rowsAffected))
            end
        end)
        
        print('^2[CORE] 🏆 Enterprise Supply Chain System Loaded Successfully!^0')
    end
end)

-- ============================================
-- UNIVERSAL VALIDATION SYSTEM
-- ============================================

-- Universal validation helper (MAINTAINED FOR COMPATIBILITY)
local function validatePlayerAccess(source, feature)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, "Player not found"
    end
    
    local playerJob = Player.PlayerData.job.name
    local currentJob = playerJob or "unemployed"
    
    -- Use config validation functions
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
    end
    
    if not hasAccess then
        local errorMessage = Config.JobValidation.getAccessDeniedMessage(feature, currentJob)
        return false, errorMessage
    end
    
    return true, "Access granted"
end

-- ============================================
-- SYSTEM VALIDATION FUNCTIONS
-- ============================================

-- Warehouse access validation
local function hasWarehouseAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE)
end

-- Manufacturing access validation  
local function hasManufacturingAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Achievement access validation
local function hasAchievementAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Container access validation
local function hasContainerAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- ============================================
-- EVENT HANDLERS (MAINTAINED FOR COMPATIBILITY)
-- ============================================

-- Universal validation event (PRESERVED)
RegisterNetEvent('system:validateAccess')
AddEventHandler('system:validateAccess', function(feature)
    local src = source
    local hasAccess, message = validatePlayerAccess(src, feature)
    
    TriggerClientEvent('system:accessValidationResult', src, feature, hasAccess, message)
end)

-- Validation request events (NEW - for modular system)
RegisterNetEvent('core:validateWarehouseAccess')
AddEventHandler('core:validateWarehouseAccess', function()
    local src = source
    local hasAccess = hasWarehouseAccess(src)
    TriggerClientEvent('core:warehouseAccessResult', src, hasAccess)
end)

RegisterNetEvent('core:validateManufacturingAccess') 
AddEventHandler('core:validateManufacturingAccess', function()
    local src = source
    local hasAccess = hasManufacturingAccess(src)
    TriggerClientEvent('core:manufacturingAccessResult', src, hasAccess)
end)

RegisterNetEvent('core:validateAchievementAccess')
AddEventHandler('core:validateAchievementAccess', function()
    local src = source
    local hasAccess = hasAchievementAccess(src)
    TriggerClientEvent('core:achievementAccessResult', src, hasAccess)
end)

-- ============================================
-- EXPORTS (MAINTAINED FOR FULL COMPATIBILITY)
-- ============================================

-- Legacy exports (PRESERVED)
exports('validatePlayerAccess', validatePlayerAccess)

-- New modular exports
exports('hasWarehouseAccess', hasWarehouseAccess)
exports('hasManufacturingAccess', hasManufacturingAccess) 
exports('hasAchievementAccess', hasAchievementAccess)
exports('hasContainerAccess', hasContainerAccess)

-- ============================================
-- SYSTEM MONITORING
-- ============================================

-- System health check
local function performHealthCheck()
    local health = {
        database = true,
        config = Config and Config.Restaurants and true or false,
        timestamp = os.time()
    }
    
    -- Test database connection
    MySQL.Async.fetchScalar('SELECT 1', {}, function(result)
        health.database = result == 1
    end)
    
    return health
end

-- Export health check
exports('getSystemHealth', performHealthCheck)

-- ============================================
-- STARTUP VALIDATION
-- ============================================

-- Validate critical configs on startup
Citizen.CreateThread(function()
    Wait(2000) -- Allow other systems to load
    
    -- Validate essential configs
    local validationErrors = {}
    
    if not Config.Jobs or not Config.Jobs.warehouse then
        table.insert(validationErrors, "Config.Jobs.warehouse missing")
    end
    
    if not Config.Restaurants then
        table.insert(validationErrors, "Config.Restaurants missing")
    end
    
    if not Config.Items then
        table.insert(validationErrors, "Config.Items missing")
    end
    
    if #validationErrors > 0 then
        print("^1[CORE ERROR] Critical configuration errors detected:^0")
        for _, error in ipairs(validationErrors) do
            print("^1[CORE ERROR] " .. error .. "^0")
        end
    else
        print("^2[CORE] ✅ All critical configurations validated^0")
    end
end)

print("^2[CORE] 🏗️ Core main system initialized^0")