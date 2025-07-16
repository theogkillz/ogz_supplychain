-- ============================================
-- CLIENT-SIDE VEHICLE MODIFICATION
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Job validation for achievement features
local function hasAchievementAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    return playerJob == "hurst"
end

-- Vehicle modification validation
local function applyAchievementMods(vehicle, achievementTier)
    -- Validate job access before applying mods
    if not hasAchievementAccess() then
        lib.notify({
            title = "🚫 Vehicle Access Denied",
            description = "Achievement vehicle modifications restricted to Hurst Industries employees",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with modification logic...
end

-- Apply achievement-based modifications to vehicle
local function applyAchievementMods(vehicle, achievementTier)
    if not DoesEntityExist(vehicle) then return end
    
    local tierData = Config.AchievementVehicles.performanceTiers[achievementTier]
    if not tierData then return end
    
    -- Apply performance modifications
    for modType, level in pairs(tierData.performanceMods) do
        SetVehicleMod(vehicle, modType, level, false)
    end
    
    -- Apply visual modifications
    local colorTint = tierData.colorTint
    SetVehicleCustomPrimaryColour(vehicle, colorTint.r, colorTint.g, colorTint.b)
    
    -- Apply special effects for higher tiers
    if tierData.specialEffects then
        if tierData.specialEffects.underglow then
            -- Add underglow effect (simplified)
            SetVehicleNeonLightEnabled(vehicle, 0, true)
            SetVehicleNeonLightEnabled(vehicle, 1, true) 
            SetVehicleNeonLightEnabled(vehicle, 2, true)
            SetVehicleNeonLightEnabled(vehicle, 3, true)
            SetVehicleNeonLightsColour(vehicle, colorTint.r, colorTint.g, colorTint.b)
        end
        
        if tierData.specialEffects.customLivery then
            local liveryIndex = Config.AchievementVehicles.visualEffects.liveries[achievementTier]
            if liveryIndex then
                SetVehicleLivery(vehicle, liveryIndex)
            end
        end
    end
    
    
    -- Apply engine modifications for performance
    SetVehicleEnginePowerMultiplier(vehicle, tierData.speedMultiplier)
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Show achievement notification
    lib.notify({
        title = '🏆 ' .. tierData.name .. ' Vehicle',
        description = tierData.description,
        type = 'success',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- Achievement status command with validation
RegisterCommand('mystats', function()
    if not hasAchievementAccess() then
        local PlayerData = QBCore.Functions.GetPlayerData()
        local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
        
        lib.notify({
            title = "🚫 Access Denied",
            description = "Achievement system restricted to Hurst Industries employees. Current job: " .. currentJob,
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerServerEvent('achievements:getPlayerTier')
end)

-- ============================================
-- INTEGRATION WITH EXISTING VEHICLE SPAWNING
-- ============================================

-- Enhanced warehouse vehicle spawning with achievements
RegisterNetEvent("warehouse:spawnVehiclesWithAchievements")
AddEventHandler("warehouse:spawnVehiclesWithAchievements", function(restaurantId, orders, containers, achievementTier)
    -- Use existing spawn logic but add achievement mods
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Determine vehicle based on order size and achievement tier
    local totalBoxes = calculateTotalBoxes(orders, containers)
    local vehicleModel = determineVehicleModel(totalBoxes, containers, achievementTier)
    
    -- Spawn vehicle using existing logic
    lib.requestModel(vehicleModel, 10000)
    
    local spawnCoords = findOptimalSpawnLocation(playerCoords)
    local vehicle = CreateVehicle(vehicleModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    
    if DoesEntityExist(vehicle) then
        -- Apply standard vehicle setup
        setupDeliveryVehicle(vehicle, vehicleModel)
        
        -- Apply achievement-based modifications
        applyAchievementMods(vehicle, achievementTier)
        
        -- Continue with existing delivery setup
        TriggerEvent("warehouse:startDelivery", restaurantId, vehicle, orders)
    end
end)

-- Enhanced team delivery vehicle spawning
RegisterNetEvent("team:spawnAchievementVehicle")
AddEventHandler("team:spawnAchievementVehicle", function(teamData, achievementTier)
    -- Use existing team spawn logic with achievement mods
    local warehouseConfig = Config.Warehouses[1]
    local playerPed = PlayerPedId()
    
    -- Determine vehicle based on team size and achievement tier
    local vehicleModel = "speedo"
    if teamData.memberRole == "leader" and teamData.boxesAssigned > 5 then
        vehicleModel = achievementTier == "elite" or achievementTier == "legendary" and "mule3" or "mule"
    end
    
    RequestModel(GetHashKey(vehicleModel))
    while not HasModelLoaded(GetHashKey(vehicleModel)) do
        Citizen.Wait(100)
    end
    
    local spawnOffset = (teamData.memberRole == "leader") and 0 or math.random(-5, 5)
    local van = CreateVehicle(GetHashKey(vehicleModel),
        warehouseConfig.vehicle.position.x + spawnOffset,
        warehouseConfig.vehicle.position.y + spawnOffset,
        warehouseConfig.vehicle.position.z,
        warehouseConfig.vehicle.position.w,
        true, false)
    
    if DoesEntityExist(van) then
        -- Standard vehicle setup
        SetEntityAsMissionEntity(van, true, true)
        SetVehicleHasBeenOwnedByPlayer(van, true)
        SetVehicleNeedsToBeHotwired(van, false)
        SetVehRadioStation(van, "OFF")
        SetVehicleEngineOn(van, true, true, false)
        
        -- Apply achievement modifications
        applyAchievementMods(van, achievementTier)
        
        -- Achievement tier bonus notification for teams
        if achievementTier ~= "rookie" then
            lib.notify({
                title = '🎉 Team Achievement Bonus!',
                description = string.format('Team leader has %s tier - enhanced vehicle performance!', 
                    Config.AchievementVehicles.performanceTiers[achievementTier].name),
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
        
        -- Continue with team loading
        TriggerEvent("team:loadTeamBoxes", warehouseConfig, van, teamData)
    end
end)

-- Achievement status command for players
RegisterCommand('mystats', function()
    TriggerServerEvent('achievements:getPlayerTier')
end)

RegisterNetEvent('achievements:showPlayerTier')
AddEventHandler('achievements:showPlayerTier', function(tierData, stats)
    local tier = tierData.tier
    local tierInfo = Config.AchievementVehicles.performanceTiers[tier]
    
    lib.alertDialog({
        header = '🏆 Your Achievement Status',
        content = string.format(
            '**Current Tier:** %s\n\n**Vehicle Benefits:**\n%s\n\n**Your Stats:**\n• Deliveries: %d\n• Average Rating: %.1f%%\n• Team Deliveries: %d\n\n**Next Tier:** %s',
            tierInfo.name,
            tierInfo.description,
            stats.totalDeliveries,
            stats.avgRating,
            stats.teamDeliveries,
            tierData.nextTier or "Maximum tier reached!"
        ),
        centered = true,
        cancel = true
    })
end)

-- Export for other scripts
exports('applyAchievementMods', applyAchievementMods)

print("[ACHIEVEMENTS] Vehicle performance system loaded")