-- ============================================
-- ENTERPRISE NOTIFICATION INTEGRATION SYSTEM
-- Centralized notification management and delivery
-- ============================================

-- ============================================
-- NOTIFICATION CATEGORIES AND TEMPLATES
-- ============================================

local NotificationTemplates = {
    -- System notifications
    system = {
        icon = "🔧",
        type = "info",
        duration = 5000,
        position = "center-right"
    },
    
    -- Success notifications
    success = {
        icon = "✅",
        type = "success", 
        duration = 6000,
        position = "center-right"
    },
    
    -- Error notifications
    error = {
        icon = "❌",
        type = "error",
        duration = 8000,
        position = "center-right"
    },
    
    -- Warning notifications
    warning = {
        icon = "⚠️",
        type = "warning",
        duration = 7000,
        position = "center-right"
    },
    
    -- Achievement notifications
    achievement = {
        icon = "🏆",
        type = "success",
        duration = 10000,
        position = "top"
    },
    
    -- Market notifications
    market = {
        icon = "📈",
        type = "info",
        duration = 8000,
        position = "center-right"
    },
    
    -- Container notifications
    container = {
        icon = "📦",
        type = "info",
        duration = 6000,
        position = "center-right"
    },
    
    -- Vehicle notifications
    vehicle = {
        icon = "🚛",
        type = "info",
        duration = 7000,
        position = "center-right"
    },
    
    -- Team notifications
    team = {
        icon = "👥",
        type = "info",
        duration = 8000,
        position = "center-right"
    },
    
    -- Emergency notifications
    emergency = {
        icon = "🚨",
        type = "error",
        duration = 12000,
        position = "top"
    }
}

-- ============================================
-- NOTIFICATION STATE MANAGEMENT
-- ============================================

local NotificationState = {
    lastNotificationTime = 0,
    notificationQueue = {},
    rateLimitWindow = 500, -- milliseconds
    maxQueueSize = 10
}

-- ============================================
-- CORE NOTIFICATION FUNCTIONS
-- ============================================

-- Rate-limited notification display
local function showNotification(category, title, description, customConfig)
    local currentTime = GetGameTimer()
    
    -- Rate limiting check
    if currentTime - NotificationState.lastNotificationTime < NotificationState.rateLimitWindow then
        -- Queue notification if under rate limit
        if #NotificationState.notificationQueue < NotificationState.maxQueueSize then
            table.insert(NotificationState.notificationQueue, {
                category = category,
                title = title,
                description = description,
                customConfig = customConfig,
                queueTime = currentTime
            })
        end
        return false
    end
    
    NotificationState.lastNotificationTime = currentTime
    
    -- Get template for category
    local template = NotificationTemplates[category] or NotificationTemplates.system
    
    -- Merge custom config with template
    local config = {}
    for k, v in pairs(template) do
        config[k] = v
    end
    
    if customConfig then
        for k, v in pairs(customConfig) do
            config[k] = v
        end
    end
    
    -- Format title with icon
    local formattedTitle = string.format("%s %s", config.icon, title or "Notification")
    
    -- Send notification
    lib.notify({
        title = formattedTitle,
        description = description or "Operation completed",
        type = config.type,
        duration = config.duration,
        position = Config.UI and Config.UI.notificationPosition or config.position,
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
    
    return true
end

-- Process notification queue
local function processNotificationQueue()
    if #NotificationState.notificationQueue == 0 then
        return
    end
    
    local currentTime = GetGameTimer()
    
    -- Check if enough time has passed for next notification
    if currentTime - NotificationState.lastNotificationTime >= NotificationState.rateLimitWindow then
        local notification = table.remove(NotificationState.notificationQueue, 1)
        
        if notification then
            showNotification(
                notification.category,
                notification.title,
                notification.description,
                notification.customConfig
            )
        end
    end
end

-- ============================================
-- SPECIALIZED NOTIFICATION FUNCTIONS
-- ============================================

-- System notifications
local function systemNotify(title, description, config)
    return showNotification("system", title, description, config)
end

-- Success notifications
local function successNotify(title, description, config)
    return showNotification("success", title, description, config)
end

-- Error notifications
local function errorNotify(title, description, config)
    return showNotification("error", title, description, config)
end

-- Warning notifications
local function warningNotify(title, description, config)
    return showNotification("warning", title, description, config)
end

-- Achievement notifications
local function achievementNotify(title, description, config)
    return showNotification("achievement", title, description, config)
end

-- Market notifications
local function marketNotify(title, description, config)
    return showNotification("market", title, description, config)
end

-- Container notifications
local function containerNotify(title, description, config)
    return showNotification("container", title, description, config)
end

-- Vehicle notifications
local function vehicleNotify(title, description, config)
    return showNotification("vehicle", title, description, config)
end

-- Team notifications
local function teamNotify(title, description, config)
    return showNotification("team", title, description, config)
end

-- Emergency notifications
local function emergencyNotify(title, description, config)
    return showNotification("emergency", title, description, config)
end

-- ============================================
-- BATCH NOTIFICATION SYSTEMS
-- ============================================

-- Show multiple related notifications
local function showBatchNotifications(notifications, delayBetween)
    local delay = delayBetween or 1000
    
    for i, notification in ipairs(notifications) do
        Citizen.SetTimeout((i - 1) * delay, function()
            showNotification(
                notification.category or "system",
                notification.title,
                notification.description,
                notification.config
            )
        end)
    end
end

-- Progress-based notifications
local function showProgressNotifications(config)
    local startTitle = config.startTitle or "Process Started"
    local startDesc = config.startDescription or "Beginning operation..."
    
    local progressTitle = config.progressTitle or "Processing"
    local progressDesc = config.progressDescription or "Operation in progress..."
    
    local completeTitle = config.completeTitle or "Process Complete"
    local completeDesc = config.completeDescription or "Operation completed successfully!"
    
    -- Start notification
    systemNotify(startTitle, startDesc)
    
    -- Progress notification (if duration provided)
    if config.duration and config.showProgress then
        Citizen.SetTimeout(math.floor(config.duration / 2), function()
            systemNotify(progressTitle, progressDesc, { duration = 3000 })
        end)
    end
    
    -- Completion notification
    Citizen.SetTimeout(config.duration or 5000, function()
        successNotify(completeTitle, completeDesc)
    end)
end

-- ============================================
-- SPECIALIZED ALERT SYSTEMS
-- ============================================

-- Critical alert dialog
local function showCriticalAlert(title, message, callback)
    lib.alertDialog({
        header = "🚨 " .. (title or "Critical Alert"),
        content = message or "A critical situation requires your attention!",
        centered = true,
        cancel = false,
        size = 'md'
    }):next(function()
        if callback then
            callback()
        end
    end)
end

-- Confirmation with notification
local function confirmWithNotification(config)
    return lib.alertDialog({
        header = config.header or "Confirm Action",
        content = config.content or "Are you sure you want to proceed?",
        centered = true,
        cancel = true,
        labels = {
            confirm = config.confirmLabel or "Confirm",
            cancel = config.cancelLabel or "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            if config.successTitle and config.successDescription then
                successNotify(config.successTitle, config.successDescription)
            end
            if config.onConfirm then
                config.onConfirm()
            end
        else
            if config.cancelTitle and config.cancelDescription then
                systemNotify(config.cancelTitle, config.cancelDescription)
            end
            if config.onCancel then
                config.onCancel()
            end
        end
        return confirmed
    end)
end

-- ============================================
-- SYSTEM INTEGRATION
-- ============================================

-- Queue processing thread
Citizen.CreateThread(function()
    while true do
        processNotificationQueue()
        Citizen.Wait(100)
    end
end)

-- System event handlers
RegisterNetEvent('supplychain:clientShutdown')
AddEventHandler('supplychain:clientShutdown', function()
    -- Clear notification queue
    NotificationState.notificationQueue = {}
end)

-- ============================================
-- EXPORTS
-- ============================================

-- General notification function
exports('notify', showNotification)

-- Specialized notification functions
exports('systemNotify', systemNotify)
exports('successNotify', successNotify)
exports('errorNotify', errorNotify)
exports('warningNotify', warningNotify)
exports('achievementNotify', achievementNotify)
exports('marketNotify', marketNotify)
exports('containerNotify', containerNotify)
exports('vehicleNotify', vehicleNotify)
exports('teamNotify', teamNotify)
exports('emergencyNotify', emergencyNotify)

-- Batch and specialized systems
exports('showBatchNotifications', showBatchNotifications)
exports('showProgressNotifications', showProgressNotifications)
exports('showCriticalAlert', showCriticalAlert)
exports('confirmWithNotification', confirmWithNotification)

-- State management
exports('getNotificationState', function()
    return NotificationState
end)

exports('clearNotificationQueue', function()
    NotificationState.notificationQueue = {}
end)

print("[NOTIFICATIONS] Enterprise notification system loaded")