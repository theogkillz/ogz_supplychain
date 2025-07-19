-- ============================================
-- ACHIEVEMENT TRACKING SYSTEM - ENTERPRISE CLIENT
-- Real-time achievement progress monitoring and validation
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Tracking state management
local activeTracking = {}
local sessionStats = {}
local achievementProgress = {}
local trackingEnabled = true

-- ============================================
-- TRACKING INITIALIZATION
-- ============================================

-- Initialize achievement tracking system
local function initializeTracking()
    sessionStats = {
        deliveries = 0,
        totalDistance = 0,
        totalTime = 0,
        perfectDeliveries = 0,
        teamDeliveries = 0,
        manufacturingBatches = 0,
        safetyViolations = 0,
        sessionStart = GetGameTimer()
    }
    
    -- Request current achievement progress from server
    TriggerServerEvent("achievements:requestProgress")
    
    print("[ACHIEVEMENTS] Tracking system initialized")
end

-- Load achievement progress from server
RegisterNetEvent("achievements:receiveProgress")
AddEventHandler("achievements:receiveProgress", function(progress)
    achievementProgress = progress or {}
    print("[ACHIEVEMENTS] Progress data loaded: " .. #achievementProgress .. " achievements")
end)

-- ============================================
-- DELIVERY TRACKING FUNCTIONS
-- ============================================

-- Track delivery start
RegisterNetEvent("achievements:trackDeliveryStart")
AddEventHandler("achievements:trackDeliveryStart", function(deliveryData)
    if not trackingEnabled then return end
    
    activeTracking.delivery = {
        startTime = GetGameTimer(),
        startPosition = GetEntityCoords(PlayerPedId()),
        restaurantId = deliveryData.restaurantId,
        boxCount = deliveryData.boxCount or 1,
        isTeamDelivery = deliveryData.isTeamDelivery or false,
        teamRole = deliveryData.teamRole,
        safetyViolations = 0,
        vehicleDamage = 0
    }
    
    -- Start safety monitoring
    if activeTracking.delivery.isTeamDelivery then
        TriggerEvent("achievements:startTeamTracking", deliveryData)
    end
    
    TriggerEvent("achievements:startSafetyMonitoring")
    
    print("[ACHIEVEMENTS] Delivery tracking started")
end)

-- Track delivery completion
RegisterNetEvent("achievements:trackDeliveryComplete")
AddEventHandler("achievements:trackDeliveryComplete", function(deliveryResult)
    if not trackingEnabled or not activeTracking.delivery then return end
    
    local delivery = activeTracking.delivery
    local endTime = GetGameTimer()
    local totalTime = (endTime - delivery.startTime) / 1000 -- Convert to seconds
    local endPosition = GetEntityCoords(PlayerPedId())
    local distance = #(delivery.startPosition - endPosition)
    
    -- Update session stats
    sessionStats.deliveries = sessionStats.deliveries + 1
    sessionStats.totalTime = sessionStats.totalTime + totalTime
    sessionStats.totalDistance = sessionStats.totalDistance + distance
    
    if delivery.isTeamDelivery then
        sessionStats.teamDeliveries = sessionStats.teamDeliveries + 1
    end
    
    -- Check for perfect delivery
    local isPerfect = delivery.safetyViolations == 0 and 
                     delivery.vehicleDamage < 100 and 
                     totalTime <= (Config.DriverRewards and Config.DriverRewards.perfectDelivery and 
                                  Config.DriverRewards.perfectDelivery.maxTime or 1200)
    
    if isPerfect then
        sessionStats.perfectDeliveries = sessionStats.perfectDeliveries + 1
    end
    
    -- Prepare tracking data for server
    local trackingData = {
        deliveryTime = totalTime,
        distance = distance,
        boxCount = delivery.boxCount,
        isPerfect = isPerfect,
        isTeamDelivery = delivery.isTeamDelivery,
        teamRole = delivery.teamRole,
        safetyViolations = delivery.safetyViolations,
        vehicleDamage = delivery.vehicleDamage,
        restaurantId = delivery.restaurantId,
        sessionStats = sessionStats
    }
    
    -- Send to server for achievement processing
    TriggerServerEvent("achievements:processDeliveryTracking", trackingData)
    
    -- Clear active tracking
    activeTracking.delivery = nil
    TriggerEvent("achievements:stopSafetyMonitoring")
    
    print("[ACHIEVEMENTS] Delivery tracking completed: " .. totalTime .. "s, " .. distance .. " units")
end)

-- ============================================
-- MANUFACTURING TRACKING
-- ============================================

-- Track manufacturing activity
RegisterNetEvent("achievements:trackManufacturing")
AddEventHandler("achievements:trackManufacturing", function(manufacturingData)
    if not trackingEnabled then return end
    
    sessionStats.manufacturingBatches = sessionStats.manufacturingBatches + 1
    
    local trackingData = {
        recipeId = manufacturingData.recipeId,
        category = manufacturingData.category,
        quantity = manufacturingData.quantity,
        qualityLevel = manufacturingData.qualityLevel,
        qualitySuccess = manufacturingData.qualitySuccess,
        sessionStats = sessionStats
    }
    
    TriggerServerEvent("achievements:processManufacturingTracking", trackingData)
    
    print("[ACHIEVEMENTS] Manufacturing tracked: " .. manufacturingData.recipeId)
end)

-- ============================================
-- TEAM DELIVERY TRACKING
-- ============================================

-- Track team delivery coordination
RegisterNetEvent("achievements:startTeamTracking")
AddEventHandler("achievements:startTeamTracking", function(teamData)
    activeTracking.team = {
        teamId = teamData.teamId,
        memberRole = teamData.memberRole,
        teamSize = teamData.teamSize,
        startTime = GetGameTimer(),
        coordinationEvents = {}
    }
    
    print("[ACHIEVEMENTS] Team tracking started for " .. teamData.memberRole)
end)

-- Track team coordination events
RegisterNetEvent("achievements:trackTeamCoordination")
AddEventHandler("achievements:trackTeamCoordination", function(eventType, eventData)
    if not activeTracking.team then return end
    
    table.insert(activeTracking.team.coordinationEvents, {
        type = eventType,
        timestamp = GetGameTimer(),
        data = eventData
    })
    
    print("[ACHIEVEMENTS] Team coordination tracked: " .. eventType)
end)

-- Track team delivery completion
RegisterNetEvent("achievements:trackTeamComplete")
AddEventHandler("achievements:trackTeamComplete", function(teamResult)
    if not activeTracking.team then return end
    
    local teamTracking = activeTracking.team
    local teamData = {
        teamId = teamTracking.teamId,
        memberRole = teamTracking.memberRole,
        teamSize = teamTracking.teamSize,
        totalTime = (GetGameTimer() - teamTracking.startTime) / 1000,
        coordinationEvents = teamTracking.coordinationEvents,
        syncBonus = teamResult.syncBonus,
        teamBonus = teamResult.teamBonus
    }
    
    TriggerServerEvent("achievements:processTeamTracking", teamData)
    
    activeTracking.team = nil
    print("[ACHIEVEMENTS] Team delivery tracking completed")
end)

-- ============================================
-- SAFETY MONITORING
-- ============================================

-- Start safety monitoring during deliveries
RegisterNetEvent("achievements:startSafetyMonitoring")
AddEventHandler("achievements:startSafetyMonitoring", function()
    if not activeTracking.delivery then return end
    
    Citizen.CreateThread(function()
        local lastVehicle = nil
        local initialDamage = 0
        
        while activeTracking.delivery do
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle ~= 0 then
                -- Track initial damage
                if vehicle ~= lastVehicle then
                    initialDamage = GetVehicleEngineHealth(vehicle) + GetVehicleBodyHealth(vehicle)
                    lastVehicle = vehicle
                end
                
                -- Monitor current damage
                local currentDamage = GetVehicleEngineHealth(vehicle) + GetVehicleBodyHealth(vehicle)
                activeTracking.delivery.vehicleDamage = initialDamage - currentDamage
                
                -- Check for safety violations
                local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
                
                -- Speeding violation
                if speed > 120 then
                    TriggerEvent("achievements:recordSafetyViolation", "speeding", speed)
                end
                
                -- Reckless driving detection
                if GetVehicleWheelsOnGround(vehicle) < 4 then
                    TriggerEvent("achievements:recordSafetyViolation", "airborne", 0)
                end
            end
            
            Citizen.Wait(1000) -- Check every second
        end
    end)
end)

-- Record safety violations
RegisterNetEvent("achievements:recordSafetyViolation")
AddEventHandler("achievements:recordSafetyViolation", function(violationType, severity)
    if not activeTracking.delivery then return end
    
    activeTracking.delivery.safetyViolations = activeTracking.delivery.safetyViolations + 1
    sessionStats.safetyViolations = sessionStats.safetyViolations + 1
    
    print("[ACHIEVEMENTS] Safety violation recorded: " .. violationType)
end)

-- Stop safety monitoring
RegisterNetEvent("achievements:stopSafetyMonitoring")
AddEventHandler("achievements:stopSafetyMonitoring", function()
    -- Safety monitoring will stop when activeTracking.delivery is cleared
    print("[ACHIEVEMENTS] Safety monitoring stopped")
end)

-- ============================================
-- PROGRESS MONITORING
-- ============================================

-- Monitor continuous progress (daily/weekly streaks, etc.)
Citizen.CreateThread(function()
    while true do
        if trackingEnabled then
            -- Check session milestones
            TriggerEvent("achievements:checkSessionMilestones")
            
            -- Update server with session progress every 5 minutes
            if sessionStats.deliveries > 0 then
                TriggerServerEvent("achievements:updateSessionProgress", sessionStats)
            end
        end
        
        Citizen.Wait(300000) -- 5 minutes
    end
end)

-- Check for session-based achievement milestones
RegisterNetEvent("achievements:checkSessionMilestones")
AddEventHandler("achievements:checkSessionMilestones", function()
    local sessionTime = (GetGameTimer() - sessionStats.sessionStart) / 1000 / 3600 -- Hours
    
    -- Check for session achievements
    if sessionStats.deliveries >= 10 and sessionTime <= 2 then
        TriggerEvent("achievements:triggerSessionAchievement", "speed_session", {
            deliveries = sessionStats.deliveries,
            time = sessionTime
        })
    end
    
    if sessionStats.perfectDeliveries >= 5 then
        TriggerEvent("achievements:triggerSessionAchievement", "perfect_session", {
            perfectDeliveries = sessionStats.perfectDeliveries
        })
    end
    
    if sessionStats.teamDeliveries >= 3 then
        TriggerEvent("achievements:triggerSessionAchievement", "team_session", {
            teamDeliveries = sessionStats.teamDeliveries
        })
    end
end)

-- Trigger session-based achievements
RegisterNetEvent("achievements:triggerSessionAchievement")
AddEventHandler("achievements:triggerSessionAchievement", function(achievementType, data)
    TriggerServerEvent("achievements:validateSessionAchievement", achievementType, data)
end)

-- ============================================
-- ACHIEVEMENT VALIDATION RESPONSES
-- ============================================

-- Handle achievement earned from server
RegisterNetEvent("achievements:achievementEarned")
AddEventHandler("achievements:achievementEarned", function(achievementData)
    -- Show UI notification
    TriggerEvent("achievements:showEarnedNotification", achievementData)
    
    -- Update local progress
    achievementProgress[achievementData.achievementId] = achievementData
    
    -- Trigger any special effects
    if achievementData.specialEffects then
        TriggerEvent("achievements:playSpecialEffects", achievementData.specialEffects)
    end
    
    print("[ACHIEVEMENTS] Achievement earned: " .. achievementData.name)
end)

-- Handle tier advancement from server
RegisterNetEvent("achievements:tierAdvanced")
AddEventHandler("achievements:tierAdvanced", function(newTier, oldTier, tierData)
    -- Show tier advancement UI
    TriggerEvent("achievements:showTierAdvancement", newTier, oldTier)
    
    -- Update vehicle benefits
    TriggerEvent("achievements:updateVehicleBenefits", newTier)
    
    print("[ACHIEVEMENTS] Tier advanced: " .. oldTier .. " -> " .. newTier)
end)

-- Handle progress updates from server
RegisterNetEvent("achievements:progressUpdated")
AddEventHandler("achievements:progressUpdated", function(progressData)
    for achievementId, progress in pairs(progressData) do
        achievementProgress[achievementId] = progress
        
        -- Show progress notification for significant milestones
        if progress.progress and progress.target then
            local percentage = (progress.progress / progress.target) * 100
            if percentage >= 25 and percentage % 25 < 1 then -- Every 25%
                exports.ogz_supplychain:infoNotify(
                    "🎯 Achievement Progress",
                    string.format("**%s**: %.0f%% complete (%d/%d)", 
                        progress.name, percentage, progress.progress, progress.target)
                )
            end
        end
    end
end)

-- ============================================
-- SPECIAL TRACKING EVENTS
-- ============================================

-- Track market-related achievements
RegisterNetEvent("achievements:trackMarketActivity")
AddEventHandler("achievements:trackMarketActivity", function(activityType, data)
    if not trackingEnabled then return end
    
    local marketData = {
        activityType = activityType,
        data = data,
        timestamp = GetGameTimer()
    }
    
    TriggerServerEvent("achievements:processMarketTracking", marketData)
end)

-- Track restaurant management achievements
RegisterNetEvent("achievements:trackRestaurantActivity")
AddEventHandler("achievements:trackRestaurantActivity", function(activityType, data)
    if not trackingEnabled then return end
    
    local restaurantData = {
        activityType = activityType,
        data = data,
        timestamp = GetGameTimer()
    }
    
    TriggerServerEvent("achievements:processRestaurantTracking", restaurantData)
end)

-- Track warehouse efficiency
RegisterNetEvent("achievements:trackWarehouseActivity")
AddEventHandler("achievements:trackWarehouseActivity", function(activityType, data)
    if not trackingEnabled then return end
    
    local warehouseData = {
        activityType = activityType,
        data = data,
        timestamp = GetGameTimer()
    }
    
    TriggerServerEvent("achievements:processWarehouseTracking", warehouseData)
end)

-- ============================================
-- SYSTEM INTEGRATION EVENTS
-- ============================================

-- Integration with delivery system
RegisterNetEvent("delivery:started")
AddEventHandler("delivery:started", function(deliveryData)
    TriggerEvent("achievements:trackDeliveryStart", deliveryData)
end)

RegisterNetEvent("delivery:completed")
AddEventHandler("delivery:completed", function(deliveryResult)
    TriggerEvent("achievements:trackDeliveryComplete", deliveryResult)
end)

-- Integration with manufacturing system
RegisterNetEvent("manufacturing:processCompleted")
AddEventHandler("manufacturing:processCompleted", function(result)
    TriggerEvent("achievements:trackManufacturing", {
        recipeId = result.recipeId,
        category = result.category,
        quantity = result.quantity,
        qualityLevel = result.quality,
        qualitySuccess = result.qualitySuccess
    })
end)

-- Integration with team system
RegisterNetEvent("team:deliveryStarted")
AddEventHandler("team:deliveryStarted", function(teamData)
    TriggerEvent("achievements:startTeamTracking", teamData)
end)

RegisterNetEvent("team:deliveryCompleted")
AddEventHandler("team:deliveryCompleted", function(teamResult)
    TriggerEvent("achievements:trackTeamComplete", teamResult)
end)

-- ============================================
-- TRACKING CONTROL FUNCTIONS
-- ============================================

-- Enable/disable tracking
RegisterNetEvent("achievements:setTrackingEnabled")
AddEventHandler("achievements:setTrackingEnabled", function(enabled)
    trackingEnabled = enabled
    print("[ACHIEVEMENTS] Tracking " .. (enabled and "enabled" or "disabled"))
end)

-- Reset session stats
RegisterNetEvent("achievements:resetSessionStats")
AddEventHandler("achievements:resetSessionStats", function()
    sessionStats = {
        deliveries = 0,
        totalDistance = 0,
        totalTime = 0,
        perfectDeliveries = 0,
        teamDeliveries = 0,
        manufacturingBatches = 0,
        safetyViolations = 0,
        sessionStart = GetGameTimer()
    }
    print("[ACHIEVEMENTS] Session stats reset")
end)

-- ============================================
-- DEBUG AND TESTING FUNCTIONS
-- ============================================

-- Debug command to show current tracking state
RegisterCommand('achstats', function()
    if not exports.ogz_supplychain:validatePlayerAccess("achievements") then
        return
    end
    
    local sessionTime = (GetGameTimer() - sessionStats.sessionStart) / 1000 / 60 -- Minutes
    
    exports.ogz_supplychain:infoNotify(
        "📊 Session Stats",
        string.format("Time: %.1fm • Deliveries: %d • Perfect: %d • Team: %d • Manufacturing: %d", 
            sessionTime, sessionStats.deliveries, sessionStats.perfectDeliveries, 
            sessionStats.teamDeliveries, sessionStats.manufacturingBatches)
    )
end)

-- Debug command to test achievement
RegisterCommand('testach', function(source, args)
    if not exports.ogz_supplychain:validatePlayerAccess("admin") then
        return
    end
    
    if args[1] then
        TriggerServerEvent("achievements:debugTestAchievement", args[1])
    end
end)

-- ============================================
-- INITIALIZATION AND CLEANUP
-- ============================================

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.SetTimeout(2000, function() -- Wait for other systems to load
            initializeTracking()
        end)
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Send final session stats to server
        if sessionStats.deliveries > 0 then
            TriggerServerEvent("achievements:finalSessionUpdate", sessionStats)
        end
    end
end)

-- Save progress on player disconnect
RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    if sessionStats.deliveries > 0 then
        TriggerServerEvent("achievements:finalSessionUpdate", sessionStats)
    end
end)

-- ============================================
-- EXPORTS FOR INTEGRATION
-- ============================================

-- Export tracking functions for other components
exports('trackDeliveryStart', function(deliveryData)
    TriggerEvent("achievements:trackDeliveryStart", deliveryData)
end)

exports('trackDeliveryComplete', function(deliveryResult)
    TriggerEvent("achievements:trackDeliveryComplete", deliveryResult)
end)

exports('trackManufacturing', function(manufacturingData)
    TriggerEvent("achievements:trackManufacturing", manufacturingData)
end)

exports('trackMarketActivity', function(activityType, data)
    TriggerEvent("achievements:trackMarketActivity", activityType, data)
end)

exports('getSessionStats', function()
    return sessionStats
end)

exports('getAchievementProgress', function()
    return achievementProgress
end)

exports('isTrackingEnabled', function()
    return trackingEnabled
end)

print("[ACHIEVEMENTS TRACKING] Enterprise achievement tracking system initialized")