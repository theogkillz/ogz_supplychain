-- ============================================
-- CORE MAIN SYSTEM - ENTERPRISE EDITION
-- Lightweight core with delegation to specialized systems
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- CORE VARIABLES
-- ============================================

local CoreState = {
    initialized = false,
    currentOrder = {},
    currentOrderRestaurantId = nil,
    lastDeliveryTime = 0,
    deliveryCooldown = 300000, -- 5 minutes in milliseconds
    playerData = nil
}

-- ============================================
-- CORE INITIALIZATION
-- ============================================

-- Initialize core systems
local function initializeCoreSystem()
    if CoreState.initialized then
        return
    end
    
    -- Get player data
    CoreState.playerData = QBCore.Functions.GetPlayerData()
    
    -- Mark as initialized
    CoreState.initialized = true
    
    -- Notify subsystems
    TriggerEvent('supplychain:coreInitialized', CoreState)
    
    print("[CORE] Supply Chain core system initialized")
end

-- Handle player loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    -- Small delay to ensure everything is loaded
    Citizen.SetTimeout(1000, function()
        initializeCoreSystem()
        
        -- Use notification system
        local notifySuccess = exports.ogz_supplychain:successNotify(
            "System Ready",
            "Supply Chain system loaded successfully!"
        )
        
        if not notifySuccess then
            -- Fallback notification if export isn't ready yet
            lib.notify({
                title = "✅ System Ready",
                description = "Supply Chain system loaded successfully!",
                type = "success",
                duration = 5000,
                position = Config.UI and Config.UI.notificationPosition or "center-right"
            })
        end
    end)
end)

-- ============================================
-- LEGACY EVENT HANDLERS
-- ============================================

-- Legacy leaderboard handler (now delegated to specialized system)
RegisterNetEvent("warehouse:showLeaderboard")
AddEventHandler("warehouse:showLeaderboard", function(leaderboard)
    -- This is now handled in cl_events.lua, but kept for compatibility
    print("[CORE] Leaderboard event received, delegating to events system")
end)

-- ============================================
-- CORE UTILITY FUNCTIONS
-- ============================================

-- Get current player state
local function getPlayerState()
    return {
        initialized = CoreState.initialized,
        hasOrder = CoreState.currentOrder and next(CoreState.currentOrder) ~= nil,
        restaurantId = CoreState.currentOrderRestaurantId,
        lastDelivery = CoreState.lastDeliveryTime,
        cooldownRemaining = math.max(0, CoreState.deliveryCooldown - (GetGameTimer() - CoreState.lastDeliveryTime))
    }
end

-- Update order state
local function updateOrderState(order, restaurantId)
    CoreState.currentOrder = order or {}
    CoreState.currentOrderRestaurantId = restaurantId
    
    -- Notify subsystems of order state change
    TriggerEvent('supplychain:orderStateChanged', CoreState.currentOrder, restaurantId)
end

-- Mark delivery completed
local function markDeliveryCompleted()
    CoreState.lastDeliveryTime = GetGameTimer()
    CoreState.currentOrder = {}
    CoreState.currentOrderRestaurantId = nil
    
    -- Notify subsystems
    TriggerEvent('supplychain:deliveryCompleted', CoreState.lastDeliveryTime)
end

-- Check delivery cooldown
local function isDeliveryCooldownActive()
    local timeElapsed = GetGameTimer() - CoreState.lastDeliveryTime
    return timeElapsed < CoreState.deliveryCooldown
end

-- ============================================
-- PLAYER STATE MONITORING
-- ============================================

-- Monitor player job changes
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    if CoreState.playerData then
        CoreState.playerData.job = JobInfo
    end
    
    print("[CORE] Job updated to: " .. (JobInfo.name or "unemployed"))
    
    -- Clear current order if job changed
    if CoreState.currentOrder and next(CoreState.currentOrder) ~= nil then
        CoreState.currentOrder = {}
        CoreState.currentOrderRestaurantId = nil
        
        exports.ogz_supplychain:systemNotify(
            "Job Changed",
            "Current order cleared due to job change",
            { duration = 3000 }
        )
    end
end)

-- ============================================
-- SYSTEM EVENTS
-- ============================================

-- Resource start handler
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CORE] Resource starting...")
        
        -- Small delay to ensure dependencies are loaded
        Citizen.SetTimeout(2000, function()
            if QBCore.Functions.GetPlayerData() then
                initializeCoreSystem()
            end
        end)
    end
end)

-- Resource stop handler
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CORE] Core system shutting down")
        CoreState.initialized = false
    end
end)

-- ============================================
-- COMMANDS
-- ============================================

-- Debug command to check core state
RegisterCommand('supplycorestate', function()
    local state = getPlayerState()
    local stateText = string.format(
        "**Core State:**\n• Initialized: %s\n• Has Order: %s\n• Restaurant ID: %s\n• Cooldown: %d seconds",
        tostring(state.initialized),
        tostring(state.hasOrder),
        tostring(state.restaurantId or "None"),
        math.floor(state.cooldownRemaining / 1000)
    )
    
    lib.alertDialog({
        header = "🔧 Core System State",
        content = stateText,
        centered = true,
        cancel = true
    })
end, false)

-- ============================================
-- EXPORTS
-- ============================================

-- Core state exports
exports('getPlayerState', getPlayerState)
exports('updateOrderState', updateOrderState)
exports('markDeliveryCompleted', markDeliveryCompleted)
exports('isDeliveryCooldownActive', isDeliveryCooldownActive)
exports('getCoreState', function() return CoreState end)

-- Legacy compatibility exports
exports('validatePlayerAccess', function(feature)
    return exports.ogz_supplychain:validatePlayerAccess(feature)
end)

exports('showAccessDenied', function(feature, customMessage)
    return exports.ogz_supplychain:showAccessDenied(feature, customMessage)
end)

print("[CORE] Main system loaded - Enterprise Edition")