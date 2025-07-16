-- ============================================
-- DYNAMIC CONTAINER SYSTEM - CLIENT INTERFACE
-- Advanced container management UI and interactions
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Client state
local nearbyContainers = {}
local containerZones = {}
local currentRestaurantContainers = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Format time from milliseconds to readable format
local function formatTime(milliseconds)
    if not milliseconds or milliseconds <= 0 then return "Unknown" end
    
    local seconds = math.floor(milliseconds / 1000)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Get quality color and icon based on quality level
local function getQualityInfo(quality)
    local qualityGrades = Config.DynamicContainers.qualityManagement.qualityGrades
    
    for grade, info in pairs(qualityGrades) do
        if quality >= info.min then
            return info.color, info.icon, info.label
        end
    end
    
    return "#FF0000", "❌", "Spoiled"
end

-- Calculate remaining time until expiration
local function getTimeUntilExpiration(expirationTime)
    local currentTime = GetGameTimer()
    local timeLeft = expirationTime - currentTime
    
    if timeLeft <= 0 then
        return "Expired", "#FF0000"
    elseif timeLeft < 3600000 then -- Less than 1 hour
        return formatTime(timeLeft), "#FF6B35"
    elseif timeLeft < 7200000 then -- Less than 2 hours
        return formatTime(timeLeft), "#FFA500"
    else
        return formatTime(timeLeft), "#00FF00"
    end
end

-- Get container type display info
local function getContainerTypeInfo(containerType)
    local config = Config.DynamicContainers.containerTypes[containerType]
    if config then
        return config.name, config.icon, config.color
    end
    return containerType, "fas fa-box", "#888888"
end

-- ============================================
-- RESTAURANT CONTAINER MANAGEMENT
-- ============================================

-- Open restaurant container management menu
RegisterNetEvent("containers:openRestaurantMenu")
AddEventHandler("containers:openRestaurantMenu", function(restaurantId)
    TriggerServerEvent("containers:getRestaurantContainers", restaurantId)
end)

-- Show restaurant containers
RegisterNetEvent("containers:showRestaurantContainers")
AddEventHandler("containers:showRestaurantContainers", function(containers)
    currentRestaurantContainers = containers
    
    local options = {
        {
            title = "🔄 Refresh Containers",
            description = "Update container list",
            icon = "fas fa-sync",
            onSelect = function()
                local PlayerData = QBCore.Functions.GetPlayerData()
                local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
                if restaurantId then
                    TriggerServerEvent("containers:getRestaurantContainers", restaurantId)
                end
            end
        },
        {
            title = "📊 Container Analytics",
            description = "View container usage statistics",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerEvent("containers:showAnalytics")
            end
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "📦 No Containers Available",
            description = "No delivered containers found",
            disabled = true
        })
    else
        -- Group containers by type and item
        local groupedContainers = {}
        for _, container in ipairs(containers) do
            local key = container.contents_item .. "_" .. container.container_type
            if not groupedContainers[key] then
                groupedContainers[key] = {
                    item = container.contents_item,
                    containerType = container.container_type,
                    containers = {},
                    totalQuantity = 0,
                    avgQuality = 0
                }
            end
            
            table.insert(groupedContainers[key].containers, container)
            groupedContainers[key].totalQuantity = groupedContainers[key].totalQuantity + container.contents_amount
        end
        
        -- Calculate average quality for each group
        for _, group in pairs(groupedContainers) do
            local totalQuality = 0
            for _, container in ipairs(group.containers) do
                totalQuality = totalQuality + container.quality_level
            end
            group.avgQuality = totalQuality / #group.containers
        end
        
        -- Create menu options for each group
        for _, group in pairs(groupedContainers) do
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[group.item] and itemNames[group.item].label or group.item
            local containerName, containerIcon, containerColor = getContainerTypeInfo(group.containerType)
            local qualityColor, qualityIcon, qualityLabel = getQualityInfo(group.avgQuality)
            
            table.insert(options, {
                title = string.format("%s %s", containerIcon, itemLabel),
                description = string.format(
                    "**%s**\n📦 %d containers • 🔢 %d total items\n%s Quality: **%.1f%%** (%s)",
                    containerName,
                    #group.containers,
                    group.totalQuantity,
                    qualityIcon,
                    group.avgQuality,
                    qualityLabel
                ),
                metadata = {
                    ["Container Type"] = containerName,
                    ["Total Containers"] = tostring(#group.containers),
                    ["Total Items"] = tostring(group.totalQuantity),
                    ["Average Quality"] = string.format("%.1f%%", group.avgQuality),
                    ["Quality Grade"] = qualityLabel
                },
                onSelect = function()
                    TriggerEvent("containers:showContainerGroup", group)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_containers",
        title = "📦 Container Management",
        options = options
    })
    lib.showContext("restaurant_containers")
end)

-- Show individual containers in a group
RegisterNetEvent("containers:showContainerGroup")
AddEventHandler("containers:showContainerGroup", function(group)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[group.item] and itemNames[group.item].label or group.item
    local containerName, containerIcon = getContainerTypeInfo(group.containerType)
    
    local options = {
        {
            title = "← Back to Container List",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("containers:showRestaurantContainers", currentRestaurantContainers)
            end
        },
        {
            title = "📦 Open All Containers",
            description = string.format("Open all %d containers at once", #group.containers),
            icon = "fas fa-boxes",
            onSelect = function()
                lib.alertDialog({
                    header = "Open All Containers",
                    content = string.format("Open all %d containers of %s?\n\nThis will extract all items to your restaurant inventory.", 
                        #group.containers, itemLabel),
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Open All",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        TriggerEvent("containers:openAllInGroup", group)
                    end
                end)
            end
        }
    }
    
    -- Sort containers by quality (best first)
    table.sort(group.containers, function(a, b)
        return a.quality_level > b.quality_level
    end)
    
    -- Add individual container options
    for i, container in ipairs(group.containers) do
        local qualityColor, qualityIcon, qualityLabel = getQualityInfo(container.quality_level)
        local timeText, timeColor = getTimeUntilExpiration(container.expiration_timestamp)
        
        table.insert(options, {
            title = string.format("%s Container #%d", qualityIcon, i),
            description = string.format(
                "🔢 **%d items** • %s **%.1f%%** quality\n⏰ Expires: **%s**\n📍 ID: %s",
                container.contents_amount,
                qualityIcon,
                container.quality_level,
                timeText,
                container.container_id:sub(-8) -- Show last 8 characters of ID
            ),
            metadata = {
                ["Container ID"] = container.container_id,
                ["Items"] = tostring(container.contents_amount),
                ["Quality"] = string.format("%.1f%% (%s)", container.quality_level, qualityLabel),
                ["Time Until Expiration"] = timeText,
                ["Preservation Bonus"] = string.format("%.1fx", container.preservation_bonus or 1.0)
            },
            onSelect = function()
                TriggerEvent("containers:openSingleContainer", container)
            end
        })
    end
    
    lib.registerContext({
        id = "container_group_details",
        title = string.format("%s %s (%d containers)", containerIcon, itemLabel, #group.containers),
        options = options
    })
    lib.showContext("container_group_details")
end)

-- Open single container
RegisterNetEvent("containers:openSingleContainer")
AddEventHandler("containers:openSingleContainer", function(container)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[container.contents_item] and itemNames[container.contents_item].label or container.contents_item
    local qualityColor, qualityIcon, qualityLabel = getQualityInfo(container.quality_level)
    local timeText, timeColor = getTimeUntilExpiration(container.expiration_timestamp)
    
    -- Calculate quality bonus/penalty
    local qualityMultiplier = 1.0
    local qualityGrades = Config.DynamicContainers.qualityManagement.qualityGrades
    for grade, info in pairs(qualityGrades) do
        if container.quality_level >= info.min then
            qualityMultiplier = info.multiplier
            break
        end
    end
    
    local adjustedQuantity = math.floor(container.contents_amount * qualityMultiplier)
    local qualityDifference = adjustedQuantity - container.contents_amount
    
    lib.alertDialog({
        header = "📦 Open Container",
        content = string.format(
            "**%s**\n\n🔢 Original Amount: %d items\n%s Quality: **%.1f%%** (%s)\n⚡ Quality Bonus: **%+d items**\n🎁 Final Amount: **%d items**\n\n⏰ Expires: %s\n\nOpen this container?",
            itemLabel,
            container.contents_amount,
            qualityIcon,
            container.quality_level,
            qualityLabel,
            qualityDifference,
            adjustedQuantity,
            timeText
        ),
        centered = true,
        cancel = true,
        size = 'md',
        labels = {
            confirm = "Open Container",
            cancel = "Keep Sealed"
        }
    }):next(function(confirmed)
        if confirmed then
            -- Play opening animation
            local playerPed = PlayerPedId()
            local animDict = "mini@repair"
            local animName = "fixing_a_ped"
            
            RequestAnimDict(animDict)
            while not HasAnimDictLoaded(animDict) do
                Citizen.Wait(0)
            end
            
            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, 3000, 0, 0, false, false, false)
            
            if lib.progressBar({
                duration = 3000,
                position = "bottom",
                label = "Opening container...",
                canCancel = false,
                disable = { move = true, car = true, combat = true, sprint = true },
                anim = { dict = animDict, clip = animName }
            }) then
                TriggerServerEvent("containers:openContainer", container.container_id, adjustedQuantity)
                
                lib.notify({
                    title = "📦 Container Opened",
                    description = string.format("Extracted **%d %s** %s", 
                        adjustedQuantity, 
                        itemLabel,
                        qualityDifference > 0 and "(quality bonus!)" or qualityDifference < 0 and "(quality penalty)" or ""
                    ),
                    type = adjustedQuantity >= container.contents_amount and 'success' or 'warning',
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                
                -- Refresh container list
                Citizen.SetTimeout(1000, function()
                    local PlayerData = QBCore.Functions.GetPlayerData()
                    local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
                    if restaurantId then
                        TriggerServerEvent("containers:getRestaurantContainers", restaurantId)
                    end
                end)
            end
        end
    end)
end)

-- Open all containers in a group
RegisterNetEvent("containers:openAllInGroup")
AddEventHandler("containers:openAllInGroup", function(group)
    local playerPed = PlayerPedId()
    local totalItems = 0
    local totalContainers = #group.containers
    
    if lib.progressBar({
        duration = 2000 * totalContainers, -- 2 seconds per container
        position = "bottom",
        label = string.format("Opening %d containers...", totalContainers),
        canCancel = false,
        disable = { move = true, car = true, combat = true, sprint = true },
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    }) then
        
        -- Calculate total items with quality adjustments
        for _, container in ipairs(group.containers) do
            local qualityMultiplier = 1.0
            local qualityGrades = Config.DynamicContainers.qualityManagement.qualityGrades
            for grade, info in pairs(qualityGrades) do
                if container.quality_level >= info.min then
                    qualityMultiplier = info.multiplier
                    break
                end
            end
            
            totalItems = totalItems + math.floor(container.contents_amount * qualityMultiplier)
            TriggerServerEvent("containers:openContainer", container.container_id, math.floor(container.contents_amount * qualityMultiplier))
        end
        
        local itemNames = exports.ox_inventory:Items() or {}
        local itemLabel = itemNames[group.item] and itemNames[group.item].label or group.item
        
        lib.notify({
            title = "📦 All Containers Opened",
            description = string.format("Extracted **%d %s** from %d containers!", totalItems, itemLabel, totalContainers),
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        -- Refresh container list
        Citizen.SetTimeout(2000, function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
            if restaurantId then
                TriggerServerEvent("containers:getRestaurantContainers", restaurantId)
            end
        end)
    end
end)

-- ============================================
-- CONTAINER ANALYTICS
-- ============================================

-- Show container analytics
RegisterNetEvent("containers:showAnalytics")
AddEventHandler("containers:showAnalytics", function()
    -- Request analytics data from server
    TriggerServerEvent("containers:getAnalytics")
end)

-- Display analytics data
RegisterNetEvent("containers:displayAnalytics")
AddEventHandler("containers:displayAnalytics", function(analyticsData)
    local options = {
        {
            title = "← Back to Containers",
            icon = "fas fa-arrow-left",
            onSelect = function()
                local PlayerData = QBCore.Functions.GetPlayerData()
                local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
                if restaurantId then
                    TriggerServerEvent("containers:getRestaurantContainers", restaurantId)
                end
            end
        },
        {
            title = "📊 Usage Summary",
            description = string.format(
                "🏆 Total Containers Used: %d\n📈 Average Quality: %.1f%%\n⏱️ Avg Delivery Time: %s\n♻️ Fresh Rate: %.1f%%",
                analyticsData.totalContainers or 0,
                analyticsData.avgQuality or 0,
                formatTime((analyticsData.avgDeliveryTime or 0) * 1000),
                analyticsData.freshRate or 0
            ),
            disabled = true
        }
    }
    
    if analyticsData.containerTypeStats then
        table.insert(options, {
            title = "📦 Container Type Performance",
            description = "Performance by container type",
            disabled = true
        })
        
        for containerType, stats in pairs(analyticsData.containerTypeStats) do
            local containerName, containerIcon = getContainerTypeInfo(containerType)
            
            table.insert(options, {
                title = string.format("%s %s", containerIcon, containerName),
                description = string.format(
                    "📊 Used: %d times • 🎯 Avg Quality: %.1f%%\n💰 Cost Efficiency: %.1f • 🏆 Success Rate: %.1f%%",
                    stats.used,
                    stats.avgQuality,
                    stats.costEfficiency,
                    stats.successRate
                ),
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "container_analytics",
        title = "📊 Container Analytics",
        options = options
    })
    lib.showContext("container_analytics")
end)

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Get restaurant ID from player job
local function getPlayerRestaurantId(jobName)
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.job == jobName then
            return restaurantId
        end
    end
    return nil
end

-- ============================================
-- INTEGRATION WITH EXISTING RESTAURANT MENU
-- ============================================

-- Add container management to restaurant menu (modify existing restaurant menu)
RegisterNetEvent("restaurant:openMainMenuWithContainers")
AddEventHandler("restaurant:openMainMenuWithContainers", function(restaurantData)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
    
    -- Add container option to existing restaurant menu
    if restaurantId then
        -- This would be integrated into the existing restaurant menu
        -- For now, we'll create a separate container menu access
        
        lib.notify({
            title = "📦 Container System Available",
            description = "Press **F6** to access container management",
            type = 'info',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- ============================================
-- KEYBINDS AND COMMANDS
-- ============================================

-- Container management keybind
RegisterKeyMapping('opencontainers', 'Open Container Management', 'keyboard', 'F6')

RegisterCommand('opencontainers', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then return end
    
    local restaurantId = getPlayerRestaurantId(PlayerData.job.name)
    if restaurantId then
        TriggerEvent("containers:openRestaurantMenu", restaurantId)
    else
        lib.notify({
            title = "Access Denied",
            description = "You must be a restaurant employee to access containers",
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end, false)

-- Admin command for container testing
RegisterCommand('testcontainer', function(source, args)
    if not args[1] then
        lib.notify({
            title = "Usage",
            description = "/testcontainer [container_type]",
            type = 'info',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local containerType = args[1]
    if Config.DynamicContainers.containerTypes[containerType] then
        TriggerServerEvent("containers:createTestContainer", containerType)
    else
        lib.notify({
            title = "Invalid Container Type",
            description = "Available types: " .. table.concat(table.keys(Config.DynamicContainers.containerTypes), ", "),
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end, false)

-- ============================================
-- VISUAL EFFECTS AND ENHANCEMENTS
-- ============================================

-- Container opening effects
local function playContainerOpenEffect()
    -- Play particle effect if available
    if Config.DynamicContainers.advanced and Config.DynamicContainers.advanced.visualEffects then
        -- Particle effects could be added here
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do
            Citizen.Wait(0)
        end
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_dst_cardboard", playerCoords.x, playerCoords.y, playerCoords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
    
    -- Play sound effect
    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

-- Container quality notification effects
RegisterNetEvent("containers:qualityAlert")
AddEventHandler("containers:qualityAlert", function(containerId, quality, alertType)
    local qualityColor, qualityIcon, qualityLabel = getQualityInfo(quality)
    
    lib.notify({
        title = string.format("%s Container Quality Alert", qualityIcon),
        description = string.format("Container %s\nQuality: **%.1f%%** (%s)", 
            containerId:sub(-8), quality, qualityLabel),
        type = alertType == 'critical' and 'error' or 'warning',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    if alertType == 'critical' then
        PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
    end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

-- Initialize container system on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if Config.DynamicContainers and Config.DynamicContainers.enabled then
            print("[CONTAINERS] Dynamic Container Client Interface initialized")
            
            -- Add help text for container management
            TriggerEvent('chat:addSuggestion', '/opencontainers', 'Open container management interface')
            TriggerEvent('chat:addSuggestion', '/testcontainer', 'Create test container (admin)', {
                { name = 'type', help = 'Container type (ogz_cooler, ogz_crate, etc.)' }
            })
        end
    end
end)

print("[CONTAINERS] Dynamic Container Client loaded successfully!")