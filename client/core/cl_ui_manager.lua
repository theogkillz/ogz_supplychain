-- ============================================
-- ENTERPRISE UI MANAGEMENT SYSTEM
-- Central UI state and menu coordination
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- UI STATE MANAGEMENT
-- ============================================

local UIState = {
    currentMenu = nil,
    menuHistory = {},
    activeTextUI = false,
    activeProgress = false,
    lastNotificationTime = 0
}

-- ============================================
-- UNIVERSAL UI HELPERS
-- ============================================

-- Safe notification system with rate limiting
local function showNotification(title, description, type, duration)
    local currentTime = GetGameTimer()
    
    -- Rate limit notifications (max 1 per 500ms)
    if currentTime - UIState.lastNotificationTime < 500 then
        return false
    end
    
    UIState.lastNotificationTime = currentTime
    
    lib.notify({
        title = title or "Supply Chain",
        description = description or "Operation completed",
        type = type or "info",
        duration = duration or 5000,
        position = Config.UI and Config.UI.notificationPosition or "center-right",
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
    
    return true
end

-- Safe text UI management
local function showTextUI(text, options)
    if UIState.activeTextUI then
        lib.hideTextUI()
    end
    
    lib.showTextUI(text, options or {})
    UIState.activeTextUI = true
end

local function hideTextUI()
    if UIState.activeTextUI then
        lib.hideTextUI()
        UIState.activeTextUI = false
    end
end

-- Safe progress bar system
local function showProgress(config)
    if UIState.activeProgress then
        return false -- Already showing progress
    end
    
    UIState.activeProgress = true
    
    local success = lib.progressBar({
        duration = config.duration or 3000,
        position = config.position or "bottom",
        label = config.label or "Processing...",
        useWhileDead = config.useWhileDead or false,
        canCancel = config.canCancel or false,
        disable = config.disable or {
            move = true,
            car = true,
            combat = true,
            sprint = true
        },
        anim = config.anim or {
            dict = "mini@repair",
            clip = "fixing_a_ped"
        }
    })
    
    UIState.activeProgress = false
    return success
end

-- Menu history management
local function pushMenu(menuId)
    table.insert(UIState.menuHistory, UIState.currentMenu)
    UIState.currentMenu = menuId
end

local function popMenu()
    local previousMenu = table.remove(UIState.menuHistory)
    UIState.currentMenu = previousMenu
    return previousMenu
end

local function clearMenuHistory()
    UIState.menuHistory = {}
    UIState.currentMenu = nil
end

-- ============================================
-- ENTERPRISE MENU SYSTEMS
-- ============================================

-- Standard back button option
local function createBackButton(targetEvent, targetData)
    return {
        title = "← Back",
        description = "Return to previous menu",
        icon = "fas fa-arrow-left",
        onSelect = function()
            if targetEvent then
                TriggerEvent(targetEvent, targetData)
            else
                local previousMenu = popMenu()
                if previousMenu then
                    lib.showContext(previousMenu)
                end
            end
        end
    }
end

-- Standard loading menu
local function showLoadingMenu(title, message)
    local options = {
        {
            title = "🔄 " .. (title or "Loading"),
            description = message or "Please wait while the system processes your request...",
            disabled = true
        }
    }
    
    lib.registerContext({
        id = "loading_menu",
        title = "Loading...",
        options = options
    })
    lib.showContext("loading_menu")
    pushMenu("loading_menu")
end

-- Error menu display
local function showErrorMenu(title, message, canRetry, retryCallback)
    local options = {
        {
            title = "❌ " .. (title or "Error"),
            description = message or "An unexpected error occurred. Please try again.",
            disabled = true
        }
    }
    
    if canRetry and retryCallback then
        table.insert(options, {
            title = "🔄 Retry",
            description = "Attempt the operation again",
            icon = "fas fa-redo",
            onSelect = retryCallback
        })
    end
    
    table.insert(options, createBackButton())
    
    lib.registerContext({
        id = "error_menu",
        title = "Error",
        options = options
    })
    lib.showContext("error_menu")
    pushMenu("error_menu")
end

-- Confirmation dialog wrapper
local function showConfirmation(config)
    return lib.alertDialog({
        header = config.header or "Confirm Action",
        content = config.content or "Are you sure you want to proceed?",
        centered = config.centered or true,
        cancel = config.cancel or true,
        labels = {
            confirm = config.confirmLabel or "Confirm",
            cancel = config.cancelLabel or "Cancel"
        }
    })
end

-- Input dialog wrapper
local function showInput(title, fields)
    return lib.inputDialog(title or "Input Required", fields or {
        { type = "input", label = "Value", required = true }
    })
end

-- ============================================
-- SYSTEM INTEGRATION EVENTS
-- ============================================

-- Handle job change UI updates
RegisterNetEvent('supplychain:jobChanged')
AddEventHandler('supplychain:jobChanged', function(JobInfo)
    -- Close any open menus when job changes
    clearMenuHistory()
    hideTextUI()
    
    showNotification(
        "Job Updated",
        "Your job has been updated to: " .. (JobInfo.name or "unemployed"),
        "info",
        3000
    )
end)

-- Handle system shutdown
RegisterNetEvent('supplychain:clientShutdown')
AddEventHandler('supplychain:clientShutdown', function()
    -- Clean up UI state
    clearMenuHistory()
    hideTextUI()
    
    if UIState.activeProgress then
        lib.progressCancel()
        UIState.activeProgress = false
    end
end)

-- Emergency UI reset
RegisterNetEvent('supplychain:resetUI')
AddEventHandler('supplychain:resetUI', function()
    clearMenuHistory()
    hideTextUI()
    
    if UIState.activeProgress then
        lib.progressCancel()
        UIState.activeProgress = false
    end
    
    lib.hideContext()
    
    showNotification(
        "UI Reset",
        "User interface has been reset to default state",
        "success",
        3000
    )
end)

-- ============================================
-- EXPORTS FOR OTHER SYSTEMS
-- ============================================

-- UI Helper exports
exports('showNotification', showNotification)
exports('showTextUI', showTextUI)
exports('hideTextUI', hideTextUI)
exports('showProgress', showProgress)
exports('showLoadingMenu', showLoadingMenu)
exports('showErrorMenu', showErrorMenu)
exports('showConfirmation', showConfirmation)
exports('showInput', showInput)

-- Menu management exports
exports('pushMenu', pushMenu)
exports('popMenu', popMenu)
exports('clearMenuHistory', clearMenuHistory)
exports('createBackButton', createBackButton)

-- State management exports
exports('getUIState', function()
    return UIState
end)

print("[UI] Enterprise UI management system loaded")