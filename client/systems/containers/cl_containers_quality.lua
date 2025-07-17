-- ============================================
-- CONTAINER QUALITY MONITORING SYSTEM
-- Quality tracking, degradation alerts, and monitoring
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- QUALITY MONITORING STATE
-- ============================================

-- Quality monitoring variables
local qualityMonitoring = {
    active = false,
    thread = nil,
    lastUpdate = 0,
    alertHistory = {},
    monitoringInterval = 30000, -- 30 seconds
    criticalThreshold = 30,     -- Below 30% is critical
    warningThreshold = 50       -- Below 50% is warning
}

-- Container alert tracking
local containerAlerts = {}

-- ============================================
-- QUALITY MONITORING CORE
-- ============================================

-- Start quality monitoring thread
local function startQualityMonitoring()
    if qualityMonitoring.active then 
        return 
    end
    
    local hasAccess = exports.ogz_supplychain:hasContainerAccess()
    if not hasAccess then
        return
    end
    
    qualityMonitoring.active = true
    print("[CONTAINERS] Starting quality monitoring system")
    
    Citizen.CreateThread(function()
        while qualityMonitoring.active do
            -- Check for container quality updates
            local jobAccess = exports.ogz_supplychain:getPlayerJobAccess()
            
            if jobAccess == "warehouse" then
                TriggerServerEvent('containers:getQualityUpdates', 'warehouse')
            elseif jobAccess == "restaurant" then
                local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
                if restaurantId then
                    TriggerServerEvent('containers:getQualityUpdates', 'restaurant', restaurantId)
                end
            end
            
            qualityMonitoring.lastUpdate = GetGameTimer()
            Citizen.Wait(qualityMonitoring.interval)
        end
    end)
end

-- Stop quality monitoring
local function stopQualityMonitoring()
    if not qualityMonitoring.active then 
        return 
    end
    
    qualityMonitoring.active = false
    print("[CONTAINERS] Stopping quality monitoring system")
end

-- ============================================
-- QUALITY UPDATE HANDLERS
-- ============================================

-- Handle quality updates from server
RegisterNetEvent('containers:qualityUpdate')
AddEventHandler('containers:qualityUpdate', function(containerId, oldQuality, newQuality, degradationFactor)
    -- Update local container data
    local containerState = exports.ogz_supplychain:getContainerState()
    for _, container in ipairs(containerState.playerContainers) do
        if container.container_id == containerId then
            container.quality_level = newQuality
            break
        end
    end
    
    -- Process quality change and trigger alerts if needed
    processQualityChange(containerId, oldQuality, newQuality, degradationFactor)
    
    -- Update visualization
    exports.ogz_supplychain:updateContainerQualityDisplay(containerId, newQuality)
end)

-- Process quality change and determine if alerts are needed
local function processQualityChange(containerId, oldQuality, newQuality, degradationFactor)
    local qualityDrop = oldQuality - newQuality
    
    -- Check for significant quality changes
    if qualityDrop > 10 then -- More than 10% quality drop
        triggerQualityAlert(containerId, "significant_drop", {
            oldQuality = oldQuality,
            newQuality = newQuality,
            degradationFactor = degradationFactor,
            qualityDrop = qualityDrop
        })
    end
    
    -- Check for critical/warning thresholds
    if newQuality <= qualityMonitoring.criticalThreshold and oldQuality > qualityMonitoring.criticalThreshold then
        triggerQualityAlert(containerId, "quality_critical", {
            quality = newQuality,
            threshold = qualityMonitoring.criticalThreshold
        })
    elseif newQuality <= qualityMonitoring.warningThreshold and oldQuality > qualityMonitoring.warningThreshold then
        triggerQualityAlert(containerId, "quality_warning", {
            quality = newQuality,
            threshold = qualityMonitoring.warningThreshold
        })
    end
end

-- ============================================
-- QUALITY ALERT SYSTEM
-- ============================================

-- Trigger quality alert with cooldown to prevent spam
local function triggerQualityAlert(containerId, alertType, alertData)
    local currentTime = GetGameTimer()
    local alertKey = containerId .. "_" .. alertType
    
    -- Check cooldown (5 minutes for same alert type on same container)
    if containerAlerts[alertKey] and (currentTime - containerAlerts[alertKey]) < 300000 then
        return
    end
    
    containerAlerts[alertKey] = currentTime
    
    -- Generate alert message based on type
    local alertMessage = generateQualityAlertMessage(alertType, alertData)
    
    -- Send alert notification
    TriggerEvent('containers:showAlert', alertType, alertMessage, containerId)
    
    -- Log alert in history
    table.insert(qualityMonitoring.alertHistory, {
        timestamp = currentTime,
        containerId = containerId,
        alertType = alertType,
        alertData = alertData
    })
    
    -- Keep only last 50 alerts
    if #qualityMonitoring.alertHistory > 50 then
        table.remove(qualityMonitoring.alertHistory, 1)
    end
end

-- Generate quality alert messages
local function generateQualityAlertMessage(alertType, alertData)
    local degradationReasons = {
        ["time_aging"] = "natural aging",
        ["transport"] = "rough handling during transport",
        ["temperature_breach"] = "temperature control failure",
        ["improper_storage"] = "improper storage conditions"
    }
    
    if alertType == "significant_drop" then
        return string.format(
            'Quality dropped %.1f%% (%.1f%% → %.1f%%) due to %s',
            alertData.qualityDrop,
            alertData.oldQuality,
            alertData.newQuality,
            degradationReasons[alertData.degradationFactor] or "unknown factors"
        )
    elseif alertType == "quality_critical" then
        return string.format(
            'Quality critically low at %.1f%% (below %d%% threshold)',
            alertData.quality,
            alertData.threshold
        )
    elseif alertType == "quality_warning" then
        return string.format(
            'Quality declining at %.1f%% (below %d%% threshold)',
            alertData.quality,
            alertData.threshold
        )
    elseif alertType == "expiration_near" then
        return string.format(
            'Container expires in %s',
            alertData.timeToExpiration or "unknown time"
        )
    else
        return "Container quality alert"
    end
end

-- ============================================
-- EXPIRATION MONITORING
-- ============================================

-- Monitor container expiration times
local function checkContainerExpirations()
    local containerState = exports.ogz_supplychain:getContainerState()
    local currentTime = GetGameTimer()
    
    for _, container in ipairs(containerState.playerContainers) do
        if container.expiration_timestamp then
            local timeToExpiration = container.expiration_timestamp - currentTime
            
            -- Alert if expiring within 1 hour
            if timeToExpiration > 0 and timeToExpiration <= 3600000 then -- 1 hour in milliseconds
                local alertKey = container.container_id .. "_expiration_near"
                
                -- Check if we already alerted (cooldown: 30 minutes)
                if not containerAlerts[alertKey] or (currentTime - containerAlerts[alertKey]) > 1800000 then
                    containerAlerts[alertKey] = currentTime
                    
                    local timeText = exports.ogz_supplychain:formatTime(timeToExpiration)
                    triggerQualityAlert(container.container_id, "expiration_near", {
                        timeToExpiration = timeText
                    })
                end
            end
        end
    end
end

-- ============================================
-- QUALITY CHECK INTERFACE
-- ============================================

-- Open quality check menu
RegisterNetEvent('containers:openQualityCheck')
AddEventHandler('containers:openQualityCheck', function()
    local hasAccess, message = exports.ogz_supplychain:validatePlayerAccess("containers")
    if not hasAccess then
        exports.ogz_supplychain:showAccessDenied("containers", message)
        return
    end
    
    TriggerServerEvent('containers:getQualityCheckData')
end)

-- Show quality check results
RegisterNetEvent('containers:showQualityCheckData')
AddEventHandler('containers:showQualityCheckData', function(qualityData)
    local options = {
        {
            title = "📊 Quality Overview",
            description = string.format(
                "Average Quality: %.1f%%\nContainers Monitored: %d\nCritical Alerts: %d",
                qualityData.averageQuality or 0,
                qualityData.totalContainers or 0,
                qualityData.criticalCount or 0
            ),
            disabled = true
        }
    }
    
    -- Add quality distribution
    if qualityData.qualityDistribution then
        table.insert(options, {
            title = "── Quality Distribution ──",
            disabled = true
        })
        
        local distributions = {
            {range = "80-100%", icon = "🟢", key = "excellent"},
            {range = "50-79%", icon = "🟡", key = "good"},
            {range = "20-49%", icon = "🟠", key = "poor"},
            {range = "0-19%", icon = "🔴", key = "critical"}
        }
        
        for _, dist in ipairs(distributions) do
            local count = qualityData.qualityDistribution[dist.key] or 0
            table.insert(options, {
                title = string.format("%s %s", dist.icon, dist.range),
                description = string.format("%d containers", count),
                disabled = true
            })
        end
    end
    
    -- Add recent alerts
    if #qualityMonitoring.alertHistory > 0 then
        table.insert(options, {
            title = "🚨 Recent Quality Alerts",
            description = "View recent quality alerts and issues",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerEvent('containers:showRecentAlerts')
            end
        })
    end
    
    -- Add monitoring controls
    table.insert(options, {
        title = qualityMonitoring.active and "⏸️ Pause Monitoring" or "▶️ Start Monitoring",
        description = qualityMonitoring.active and "Temporarily pause quality monitoring" or "Start quality monitoring system",
        icon = qualityMonitoring.active and "fas fa-pause" or "fas fa-play",
        onSelect = function()
            if qualityMonitoring.active then
                stopQualityMonitoring()
                exports.ogz_supplychain:systemNotify("Quality Monitoring", "Monitoring paused")
            else
                startQualityMonitoring()
                exports.ogz_supplychain:systemNotify("Quality Monitoring", "Monitoring started")
            end
            -- Refresh menu
            TriggerServerEvent('containers:getQualityCheckData')
        end
    })
    
    lib.registerContext({
        id = "quality_check_menu",
        title = "🔍 Container Quality Check",
        options = options
    })
    lib.showContext("quality_check_menu")
end)

-- ============================================
-- RECENT ALERTS INTERFACE
-- ============================================

-- Show recent quality alerts
RegisterNetEvent('containers:showRecentAlerts')
AddEventHandler('containers:showRecentAlerts', function()
    local options = {
        {
            title = "← Back to Quality Check",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent('containers:openQualityCheck')
            end
        }
    }
    
    if #qualityMonitoring.alertHistory == 0 then
        table.insert(options, {
            title = "📭 No Recent Alerts",
            description = "No quality alerts in recent history",
            disabled = true
        })
    else
        -- Sort alerts by timestamp (most recent first)
        local sortedAlerts = {}
        for _, alert in ipairs(qualityMonitoring.alertHistory) do
            table.insert(sortedAlerts, alert)
        end
        table.sort(sortedAlerts, function(a, b) return a.timestamp > b.timestamp end)
        
        -- Show last 10 alerts
        for i = 1, math.min(10, #sortedAlerts) do
            local alert = sortedAlerts[i]
            local alertTime = exports.ogz_supplychain:formatTime(alert.timestamp)
            local alertMessage = generateQualityAlertMessage(alert.alertType, alert.alertData)
            
            local alertIcon = "📦"
            if alert.alertType == "quality_critical" then
                alertIcon = "🚨"
            elseif alert.alertType == "quality_warning" then
                alertIcon = "⚠️"
            elseif alert.alertType == "expiration_near" then
                alertIcon = "⏰"
            end
            
            table.insert(options, {
                title = string.format("%s Container %s", alertIcon, alert.containerId),
                description = string.format("%s\n%s ago", alertMessage, alertTime),
                metadata = {
                    ["Container"] = alert.containerId,
                    ["Alert Type"] = alert.alertType:gsub("_", " "):gsub("^%l", string.upper),
                    ["Time"] = alertTime .. " ago"
                }
            })
        end
    end
    
    -- Add clear history option
    if #qualityMonitoring.alertHistory > 0 then
        table.insert(options, {
            title = "🗑️ Clear Alert History",
            description = "Clear all quality alert history",
            icon = "fas fa-trash",
            onSelect = function()
                qualityMonitoring.alertHistory = {}
                containerAlerts = {}
                exports.ogz_supplychain:systemNotify("Alert History", "Quality alert history cleared")
                TriggerEvent('containers:showRecentAlerts')
            end
        })
    end
    
    lib.registerContext({
        id = "recent_alerts_menu",
        title = "🚨 Recent Quality Alerts",
        options = options
    })
    lib.showContext("recent_alerts_menu")
end)

-- ============================================
-- CONTAINER STATISTICS
-- ============================================

-- View container statistics
RegisterNetEvent('containers:viewStatistics')
AddEventHandler('containers:viewStatistics', function()
    TriggerServerEvent('containers:getStatisticsData')
end)

-- Show container statistics
RegisterNetEvent('containers:showStatisticsData')
AddEventHandler('containers:showStatisticsData', function(statsData)
    local options = {
        {
            title = "📊 Container Performance",
            description = string.format(
                "Deliveries: %d | Avg Quality: %.1f%%\nUptime: %.1f%% | Efficiency: %.1f%%",
                statsData.totalDeliveries or 0,
                statsData.averageQuality or 0,
                statsData.systemUptime or 0,
                statsData.systemEfficiency or 0
            ),
            disabled = true
        }
    }
    
    -- Add quality trends
    if statsData.qualityTrends then
        table.insert(options, {
            title = "📈 Quality Trends",
            description = string.format(
                "Last 24h: %s%.1f%%\nLast 7d: %s%.1f%%",
                statsData.qualityTrends.daily >= 0 and "+" or "",
                statsData.qualityTrends.daily or 0,
                statsData.qualityTrends.weekly >= 0 and "+" or "",
                statsData.qualityTrends.weekly or 0
            ),
            disabled = true
        })
    end
    
    -- Add monitoring status
    table.insert(options, {
        title = "🔄 Monitoring Status",
        description = string.format(
            "Status: %s\nLast Update: %s\nAlerts Today: %d",
            qualityMonitoring.active and "Active" or "Inactive",
            qualityMonitoring.lastUpdate > 0 and exports.ogz_supplychain:formatTime(qualityMonitoring.lastUpdate) or "Never",
            statsData.alertsToday or 0
        ),
        disabled = true
    })
    
    lib.registerContext({
        id = "container_statistics",
        title = "📊 Container Statistics",
        options = options
    })
    lib.showContext("container_statistics")
end)

-- ============================================
-- SYSTEM LIFECYCLE MANAGEMENT
-- ============================================

-- Handle job changes
RegisterNetEvent('containers:jobChanged')
AddEventHandler('containers:jobChanged', function(JobInfo)
    -- Restart quality monitoring with new job permissions
    stopQualityMonitoring()
    
    if exports.ogz_supplychain:hasContainerAccess() then
        startQualityMonitoring()
    end
    
    -- Clear alerts for previous job
    containerAlerts = {}
end)

-- Enhanced monitoring thread with expiration checks
local function startEnhancedMonitoring()
    if qualityMonitoring.active then return end
    
    qualityMonitoring.active = true
    
    Citizen.CreateThread(function()
        while qualityMonitoring.active do
            -- Standard quality monitoring
            local jobAccess = exports.ogz_supplychain:getPlayerJobAccess()
            
            if jobAccess == "warehouse" then
                TriggerServerEvent('containers:getQualityUpdates', 'warehouse')
            elseif jobAccess == "restaurant" then
                local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
                if restaurantId then
                    TriggerServerEvent('containers:getQualityUpdates', 'restaurant', restaurantId)
                end
            end
            
            -- Check container expirations
            checkContainerExpirations()
            
            qualityMonitoring.lastUpdate = GetGameTimer()
            Citizen.Wait(qualityMonitoring.monitoringInterval)
        end
    end)
end

-- Initialize quality monitoring on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[CONTAINERS] Quality monitoring system initialized")
        
        -- Start monitoring if player has access
        if exports.ogz_supplychain:hasContainerAccess() then
            startEnhancedMonitoring()
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopQualityMonitoring()
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('startQualityMonitoring', startQualityMonitoring)
exports('stopQualityMonitoring', stopQualityMonitoring)
exports('isQualityMonitoringActive', function() return qualityMonitoring.active end)
exports('getQualityMonitoringStatus', function() return qualityMonitoring end)
exports('getAlertHistory', function() return qualityMonitoring.alertHistory end)
exports('triggerQualityAlert', triggerQualityAlert)

print("[CONTAINERS] Quality monitoring system loaded")