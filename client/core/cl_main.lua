-- ============================================
-- CORE MAIN SYSTEM - ENTERPRISE EDITION
-- Universal export functions + core state management
-- QBox Framework Compatible Version
-- ============================================

-- QBox playerdata is accessed differently
local QBX = exports.qbx_core
local PlayerData = {}

-- ============================================
-- WAIT FOR PLAYER DATA TO LOAD
-- ============================================
CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            PlayerData = QBX:GetPlayerData()
            break
        end
        Wait(100)
    end
end)

-- Update PlayerData when it changes
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBX:GetPlayerData()
end)

RegisterNetEvent('qbx:client:playerLoaded', function(data)
    PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('qbx:client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

-- ============================================
-- CORE VARIABLES
-- ============================================

local CoreState = {
    initialized = false,
    currentOrder = {},
    currentOrderRestaurantId = nil,
    lastDeliveryTime = 0,
    deliveryCooldown = 300000, -- 5 minutes in milliseconds
}

-- ============================================
-- UNIVERSAL EXPORT FUNCTIONS
-- These are called throughout the entire system
-- ============================================

-- Universal job validation
local function validatePlayerAccess(feature)
    -- ✅ PROPER QBox: Use PlayerData
    local playerJob = PlayerData.job and PlayerData.job.name
    
    -- ✅ CRITICAL: Ensure we ALWAYS return boolean
    if not playerJob then
        print("[ACCESS] No valid player job for feature: " .. tostring(feature))
        return false -- Always return boolean, never nil
    end
    
    -- Define job access per feature
    local accessRules = {
        warehouse = {"hurst", "admin", "god"},
        delivery = {"hurst", "admin", "god"}, 
        manufacturing = {"hurst", "admin", "god"},
        restaurant = {"all"}, -- Handled per-restaurant in business logic
        admin = {"admin", "god"},
        achievements = {"hurst", "admin", "god"},
        npc = {"hurst", "admin", "god"},
        vehicle = {"hurst", "admin", "god"},
        container = {"hurst", "admin", "god"}
    }
    
    local allowedJobs = accessRules[feature] or {"hurst"}
    
    -- Special case: "all" means any job is allowed
    if allowedJobs[1] == "all" then
        return true
    end
    
    -- Check if job is allowed
    for _, job in ipairs(allowedJobs) do
        if playerJob == job then
            return true
        end
    end
    
    -- ✅ CRITICAL: ALWAYS return boolean - never nil
    return false
end

-- Universal success notification
local function successNotify(title, description, options)
    local notifyData = {
        title = title,
        description = description,
        type = "success",
        duration = (options and options.duration) or 5000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal error notification  
local function errorNotify(title, description, options)
    local notifyData = {
        title = title,
        description = description,
        type = "error",
        duration = (options and options.duration) or 8000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal info notification
local function infoNotify(title, description, options)
    local notifyData = {
        title = title,
        description = description,
        type = "info", 
        duration = (options and options.duration) or 6000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal warning notification
local function warningNotify(title, description, options)
    local notifyData = {
        title = title,
        description = description,
        type = "warning",
        duration = (options and options.duration) or 7000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal system notification
local function systemNotify(title, description, options)
    return infoNotify(title, description, options)
end

-- Universal vehicle notification (styled for delivery system)
local function vehicleNotify(title, description, options)
    local notifyData = {
        title = "🚛 " .. title,
        description = description,
        type = "info",
        duration = (options and options.duration) or 6000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal achievement notification
local function achievementNotify(title, description, options)
    local notifyData = {
        title = "🏆 " .. title,
        description = description,
        type = "success",
        duration = (options and options.duration) or 10000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    }
    
    lib.notify(notifyData)
    return true
end

-- Universal ox_target box zone creation
local function createBoxZone(config)
    if not config.coords or not config.options then
        print("[ERROR] createBoxZone: Missing required config")
        return false
    end
    
    -- Generate unique zone name if not provided
    local zoneName = config.name or ("supply_zone_" .. math.random(1000000, 9999999))
    
    -- ✅ FIXED: Use correct ox_target API with proper structure
    local success, result = pcall(function()
        return exports.ox_target:addBoxZone({
            name = zoneName, -- ✅ FIXED: Include the zone name in the config
            coords = config.coords,
            size = config.size or vector3(2.0, 2.0, 2.0),
            rotation = config.rotation or 0,
            debug = config.debug or false,
            options = config.options -- ✅ FIXED: Distance is handled in each option, not here
        })
    end)
    
    if success then
        print("[TARGET] Created box zone: " .. zoneName)
        return result -- ✅ FIXED: Return the actual zone ID from ox_target
    else
        print("[ERROR] Failed to create box zone: " .. zoneName .. " - " .. tostring(result))
        return false
    end
end

-- Universal progress bar
local function showProgress(config)
    if not config then return false end
    
    return lib.progressBar({
        duration = config.duration or 5000,
        label = config.label or "Processing...",
        useWhileDead = config.useWhileDead or false,
        canCancel = config.canCancel or false,
        disable = config.disable or {
            move = false,
            car = false,
            combat = true
        },
        anim = config.anim
    })
end

-- Universal input dialog
local function showInput(title, fields)
    return lib.inputDialog(title, fields)
end

-- Universal confirmation with notification
local function confirmWithNotification(config)
    lib.alertDialog({
        header = config.title or "Confirm Action",
        content = config.message or "Are you sure?",
        centered = true,
        cancel = true
    }):next(function(confirmed)
        if confirmed and config.onConfirm then
            config.onConfirm()
            if config.successMessage then
                successNotify("Confirmed", config.successMessage)
            end
        elseif not confirmed and config.onCancel then
            config.onCancel()
        end
    end)
end

-- Universal money formatting
local function formatMoney(amount)
    if not amount or amount == 0 then return "0" end
    
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Universal time formatting  
local function formatTime(seconds)
    if not seconds or seconds < 0 then return "00:00" end
    
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Show access denied message
local function showAccessDenied(feature, customMessage)
    local messages = Config.AccessDeniedMessages or {}
    local message = customMessage or messages[feature] or 
        "🚫 Access denied - insufficient permissions"
    
    errorNotify("Access Denied", message)
    return false
end

-- Container calculation helper (from shared utilities)
local function calculateDeliveryBoxes(orders)
    return SupplyUtils.calculateDeliveryBoxes(orders)
end

-- Build warehouse interaction (missing export)
local function buildWarehouseInteraction(warehouseId, config)
    -- Handle both old single-parameter and new dual-parameter calls
    local options = config or {}
    local label = options.label or "Access Warehouse"
    local jobs = options.jobs or Config.Jobs.warehouse
    
    return {
        {
            name = "warehouse_access_" .. warehouseId,
            icon = "fas fa-warehouse",
            label = label,
            groups = jobs, -- ✅ FIXED: Use 'groups' for job restrictions in ox_target
            distance = 2.5, -- ✅ FIXED: Distance should be in each option, not at zone level
            onSelect = function()
                -- Validate access before opening menu
                if exports.ogz_supplychain:validatePlayerAccess("warehouse") then
                    TriggerEvent("warehouse:openProcessingMenu")
                else
                    exports.ogz_supplychain:showAccessDenied("warehouse")
                end
            end
        }
    }
end

-- ============================================
-- CORE INITIALIZATION
-- ============================================

-- Initialize core systems
local function initializeCoreSystem()
    if CoreState.initialized then
        return
    end
    
    -- Mark as initialized
    CoreState.initialized = true
    
    -- Notify subsystems
    TriggerEvent('supplychain:coreInitialized', CoreState)
    
    print("[CORE] Supply Chain core system initialized")
end

-- Handle player loaded (QBox pattern)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- Small delay to ensure everything is loaded
    Citizen.SetTimeout(1000, function()
        initializeCoreSystem()
        
        successNotify(
            "System Ready",
            "Supply Chain system loaded successfully!"
        )
    end)
end)

-- Also handle QBox player loaded event
RegisterNetEvent('qbx:playerLoaded', function()
    -- Small delay to ensure everything is loaded
    Citizen.SetTimeout(1000, function()
        initializeCoreSystem()
        
        successNotify(
            "System Ready",
            "Supply Chain system loaded successfully!"
        )
    end)
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

-- Monitor player job changes (QBox pattern)
CreateThread(function()
    local currentJob = PlayerData.job and PlayerData.job.name
    
    while true do
        Wait(1000) -- Check every second
        
        local newJob = PlayerData.job and PlayerData.job.name
        
        if newJob ~= currentJob then
            currentJob = newJob
            
            print("[CORE] Job updated to: " .. (currentJob or "unemployed"))
            
            -- Clear current order if job changed
            if CoreState.currentOrder and next(CoreState.currentOrder) ~= nil then
                CoreState.currentOrder = {}
                CoreState.currentOrderRestaurantId = nil
                
                systemNotify(
                    "Job Changed",
                    "Current order cleared due to job change"
                )
            end
        end
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
            if LocalPlayer.state.isLoggedIn then
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
        "**Core State:**\n• Initialized: %s\n• Has Order: %s\n• Restaurant ID: %s\n• Cooldown: %d seconds\n• Current Job: %s",
        tostring(state.initialized),
        tostring(state.hasOrder),
        tostring(state.restaurantId or "None"),
        math.floor(state.cooldownRemaining / 1000),
        tostring(PlayerData.job and PlayerData.job.name or "None")
    )
    
    lib.alertDialog({
        header = "🔧 Core System State",
        content = stateText,
        centered = true,
        cancel = true
    })
end, false)

-- ============================================
-- UNIVERSAL EXPORTS
-- These are called throughout the entire system
-- ============================================

-- Core state exports
exports('getPlayerState', getPlayerState)
exports('updateOrderState', updateOrderState)
exports('markDeliveryCompleted', markDeliveryCompleted)
exports('isDeliveryCooldownActive', isDeliveryCooldownActive)
exports('getCoreState', function() return CoreState end)

-- Universal system exports
exports('validatePlayerAccess', validatePlayerAccess)
exports('showAccessDenied', showAccessDenied)

-- Universal notification exports
exports('successNotify', successNotify)
exports('errorNotify', errorNotify)
exports('infoNotify', infoNotify)
exports('warningNotify', warningNotify)
exports('systemNotify', systemNotify)
exports('vehicleNotify', vehicleNotify)
exports('achievementNotify', achievementNotify)

-- Universal UI exports
exports('createBoxZone', createBoxZone)
exports('showProgress', showProgress)
exports('showInput', showInput)
exports('confirmWithNotification', confirmWithNotification)

-- Universal utility exports
exports('formatMoney', formatMoney)
exports('formatTime', formatTime)
exports('calculateDeliveryBoxes', calculateDeliveryBoxes)

-- Warehouse system exports
exports('buildWarehouseInteraction', buildWarehouseInteraction)

-- ============================================
-- CLIENT-SIDE NOTIFICATION HANDLER
-- Properly handle server-side notifications using ox_lib
-- ============================================

-- Handle server-side notifications properly
RegisterNetEvent('ogz_supplychain:notify')
AddEventHandler('ogz_supplychain:notify', function(data)
    lib.notify({
        title = data.title,
        description = data.description,
        type = data.type or 'info',
        duration = data.duration or 5000,
        position = Config.UI and Config.UI.notificationPosition or 'center-right',
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
end)

print("[CORE] ✅ Client-side notification handler registered")

print("[CORE] Main system loaded - Enterprise Edition (QBox Compatible)")