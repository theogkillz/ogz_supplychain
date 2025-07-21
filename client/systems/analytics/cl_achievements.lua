-- Achievement Client UI System

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Achievement state
local playerAchievements = {}
local recentUnlocks = {}
local notificationQueue = {}
local isShowingNotification = false

-- Achievement unlocked notification
RegisterNetEvent("SupplyChain:Client:AchievementUnlocked")
AddEventHandler("SupplyChain:Client:AchievementUnlocked", function(achievement)
    -- Add to queue
    table.insert(notificationQueue, achievement)
    
    -- Process queue
    if not isShowingNotification then
        ProcessAchievementQueue()
    end
end)

-- Process achievement notification queue
function ProcessAchievementQueue()
    if #notificationQueue == 0 then
        isShowingNotification = false
        return
    end
    
    isShowingNotification = true
    local achievement = table.remove(notificationQueue, 1)
    
    -- Play achievement sound
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- Screen effect
    StartScreenEffect("SuccessFranklin", 1000, false)
    
    -- Show achievement banner
    ShowAchievementBanner(achievement)
    
    -- Add to recent unlocks
    table.insert(recentUnlocks, 1, {
        achievement = achievement,
        unlockedAt = GetGameTimer()
    })
    
    -- Limit recent unlocks
    if #recentUnlocks > 5 then
        table.remove(recentUnlocks)
    end
    
    -- Process next in queue after delay
    SetTimeout(4000, function()
        ProcessAchievementQueue()
    end)
end

-- Show achievement banner
function ShowAchievementBanner(achievement)
    -- Create custom notification with animation
    lib.notify({
        id = 'achievement_' .. achievement.id,
        title = "🏆 Achievement Unlocked!",
        description = string.format("**%s**\n%s", achievement.name, achievement.description),
        duration = 4000,
        type = "success",
        icon = achievement.icon or "fas fa-trophy",
        iconAnimation = "bounce",
        style = {
            backgroundColor = '#fbbf24',
            color = '#000000',
            fontWeight = 'bold',
            ['.icon'] = {
                animation = 'bounce 1s ease-in-out infinite'
            }
        }
    })
    
    -- Show rewards if any
    if achievement.rewardCash > 0 or achievement.rewardXP > 0 then
        SetTimeout(1000, function()
            local rewardText = ""
            if achievement.rewardCash > 0 then
                rewardText = rewardText .. string.format("$%d", achievement.rewardCash)
            end
            if achievement.rewardXP > 0 then
                if rewardText ~= "" then rewardText = rewardText .. " + " end
                rewardText = rewardText .. string.format("%d XP", achievement.rewardXP)
            end
            
            lib.notify({
                title = "Rewards Earned",
                description = rewardText,
                type = "success",
                duration = 3000,
                icon = "fas fa-gift"
            })
        end)
    end
end

-- Show achievements menu
RegisterNetEvent(Constants.Events.Client.ShowAchievements)
AddEventHandler(Constants.Events.Client.ShowAchievements, function(achievements)
    playerAchievements = achievements
    OpenAchievementsMenu()
end)

-- Open achievements menu
function OpenAchievementsMenu()
    local categories = {
        [Constants.AchievementCategory.DELIVERY] = { name = "Delivery", icon = "fas fa-truck", unlocked = 0, total = 0 },
        [Constants.AchievementCategory.SPEED] = { name = "Speed", icon = "fas fa-tachometer-alt", unlocked = 0, total = 0 },
        [Constants.AchievementCategory.TEAM] = { name = "Team", icon = "fas fa-users", unlocked = 0, total = 0 },
        [Constants.AchievementCategory.QUALITY] = { name = "Quality", icon = "fas fa-star", unlocked = 0, total = 0 },
        [Constants.AchievementCategory.ECONOMY] = { name = "Economy", icon = "fas fa-dollar-sign", unlocked = 0, total = 0 },
        [Constants.AchievementCategory.SPECIAL] = { name = "Special", icon = "fas fa-medal", unlocked = 0, total = 0 }
    }
    
    -- Count achievements per category
    for _, achievement in ipairs(playerAchievements) do
        local cat = categories[achievement.category]
        if cat then
            cat.total = cat.total + 1
            if achievement.unlocked then
                cat.unlocked = cat.unlocked + 1
            end
        end
    end
    
    -- Create options
    local options = {}
    
    -- Summary
    local totalUnlocked = 0
    local totalAchievements = #playerAchievements
    for _, achievement in ipairs(playerAchievements) do
        if achievement.unlocked then
            totalUnlocked = totalUnlocked + 1
        end
    end
    
    table.insert(options, {
        title = "Achievement Progress",
        description = string.format("%d/%d achievements unlocked (%.0f%%)", 
            totalUnlocked, totalAchievements, (totalUnlocked / totalAchievements) * 100),
        icon = "fas fa-chart-pie",
        disabled = true
    })
    
    -- Category buttons
    for categoryId, categoryData in pairs(categories) do
        if categoryData.total > 0 then
            table.insert(options, {
                title = categoryData.name,
                description = string.format("%d/%d unlocked", categoryData.unlocked, categoryData.total),
                icon = categoryData.icon,
                progress = categoryData.total > 0 and (categoryData.unlocked / categoryData.total) * 100 or 0,
                onSelect = function()
                    ShowCategoryAchievements(categoryId, categoryData.name)
                end
            })
        end
    end
    
    -- Recent unlocks
    if #recentUnlocks > 0 then
        table.insert(options, {
            title = "Recent Unlocks",
            description = "View recently unlocked achievements",
            icon = "fas fa-clock",
            iconColor = "green",
            onSelect = function()
                ShowRecentUnlocks()
            end
        })
    end
    
    lib.registerContext({
        id = "achievements_menu",
        title = "🏆 Achievements",
        options = options
    })
    
    lib.showContext("achievements_menu")
end

-- Show category achievements
function ShowCategoryAchievements(category, categoryName)
    local options = {}
    
    for _, achievement in ipairs(playerAchievements) do
        if achievement.category == category then
            local icon = achievement.icon or "fas fa-trophy"
            local iconColor = achievement.unlocked and "gold" or "grey"
            
            local metadata = {
                {label = "Progress", value = string.format("%d/%d", 
                    achievement.progress.current, achievement.progress.target)},
                {label = "Completion", value = achievement.progress.percentage .. "%"}
            }
            
            if achievement.rewardCash > 0 then
                table.insert(metadata, {label = "Reward", value = "$" .. achievement.rewardCash})
            end
            if achievement.rewardXP > 0 then
                table.insert(metadata, {label = "XP", value = achievement.rewardXP})
            end
            if achievement.unlocked then
                table.insert(metadata, {
                    label = "Unlocked", 
                    value = os.date("%m/%d/%Y", achievement.unlockedAt)
                })
            end
            
            table.insert(options, {
                title = achievement.name,
                description = achievement.description,
                icon = icon,
                iconColor = iconColor,
                progress = achievement.progress.percentage,
                metadata = metadata,
                disabled = achievement.unlocked
            })
        end
    end
    
    -- Sort: unlocked last, then by progress
    table.sort(options, function(a, b)
        if a.disabled ~= b.disabled then
            return not a.disabled
        end
        return (a.progress or 0) > (b.progress or 0)
    end)
    
    lib.registerContext({
        id = "category_achievements",
        title = categoryName .. " Achievements",
        menu = "achievements_menu",
        options = options
    })
    
    lib.showContext("category_achievements")
end

-- Show recent unlocks
function ShowRecentUnlocks()
    local options = {}
    
    for _, unlock in ipairs(recentUnlocks) do
        local timeAgo = math.floor((GetGameTimer() - unlock.unlockedAt) / 1000 / 60)
        local achievement = unlock.achievement
        
        table.insert(options, {
            title = achievement.name,
            description = achievement.description,
            icon = achievement.icon or "fas fa-trophy",
            iconColor = "gold",
            metadata = {
                {label = "Unlocked", value = timeAgo .. " minutes ago"},
                {label = "Category", value = GetCategoryName(achievement.category)},
                {label = "Rewards", value = FormatRewards(achievement)}
            },
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "recent_unlocks",
        title = "Recent Achievement Unlocks",
        menu = "achievements_menu",
        options = options
    })
    
    lib.showContext("recent_unlocks")
end

-- Level up notification
RegisterNetEvent("SupplyChain:Client:LevelUp")
AddEventHandler("SupplyChain:Client:LevelUp", function(data)
    -- Epic level up effects
    StartScreenEffect("MinigameEndNeutral", 3000, false)
    
    -- Sound sequence
    CreateThread(function()
        PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
        Wait(500)
        PlaySoundFrontend(-1, "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET", true)
    end)
    
    -- Show level up banner
    lib.notify({
        id = 'level_up',
        title = "⬆️ LEVEL UP!",
        description = string.format(
            "**Level %d - %s**\nCongratulations on your promotion!",
            data.newLevel,
            data.title
        ),
        duration = 6000,
        type = "success",
        icon = "fas fa-arrow-up",
        iconAnimation = "bounce",
        style = {
            backgroundColor = '#8b5cf6',
            color = '#ffffff',
            fontSize = '18px',
            fontWeight = 'bold'
        }
    })
    
    -- Show rewards
    if data.rewards then
        SetTimeout(2000, function()
            local rewardText = ""
            if data.rewards.cash then
                rewardText = string.format("Cash Bonus: $%d", data.rewards.cash)
            end
            if data.rewards.item then
                if rewardText ~= "" then rewardText = rewardText .. "\n" end
                rewardText = rewardText .. "Item Reward: " .. data.rewards.item
            end
            
            lib.notify({
                title = "Level Rewards",
                description = rewardText,
                type = "success",
                duration = 4000,
                icon = "fas fa-gift"
            })
        end)
    end
end)

-- Show player stats with achievements
RegisterNetEvent("SupplyChain:Client:ShowPlayerStats")
AddEventHandler("SupplyChain:Client:ShowPlayerStats", function(stats)
    -- Count achievements
    local achievementCount = 0
    local totalAchievements = 0
    
    if playerAchievements and #playerAchievements > 0 then
        totalAchievements = #playerAchievements
        for _, achievement in ipairs(playerAchievements) do
            if achievement.unlocked then
                achievementCount = achievementCount + 1
            end
        end
    else
        -- Request achievements if not loaded
        TriggerServerEvent("SupplyChain:Server:GetPlayerAchievements")
    end
    
    local content = string.format([[
        **📊 Delivery Statistics**
        Total Deliveries: %d
        Solo Deliveries: %d
        Team Deliveries: %d
        Perfect Deliveries: %d
        
        **💰 Financial**
        Total Earnings: $%s
        Average per Delivery: $%s
        
        **⏱️ Performance**
        Average Time: %s
        Best Time: %s
        Current Streak: %d
        
        **📈 Experience**
        Level: %d - %s
        Experience: %d XP
        Next Level: %d XP
        Progress: %d%%
        
        **🏆 Achievements**
        Unlocked: %d/%d (%.0f%%)
        
        **📅 Activity**
        Last Delivery: %s
        Account Created: %s
    ]],
        stats.total_deliveries or stats.deliveries or 0,
        stats.solo_deliveries or 0,
        stats.team_deliveries or 0,
        stats.perfect_deliveries or 0,
        lib.math.groupdigits(stats.earnings or 0),
        lib.math.groupdigits(math.floor((stats.earnings or 0) / math.max(1, stats.deliveries or 1))),
        FormatTime(stats.average_time or 0),
        FormatTime(stats.best_time or 0),
        stats.streak or 0,
        stats.level or 1,
        GetLevelTitle(stats.level or 1),
        stats.experience or 0,
        GetNextLevelXP(stats.level or 1),
        CalculateLevelProgress(stats.experience or 0, stats.level or 1),
        achievementCount,
        totalAchievements,
        totalAchievements > 0 and (achievementCount / totalAchievements * 100) or 0,
        stats.last_delivery and "Recently" or "Never",
        stats.created_at and os.date("%m/%d/%Y", stats.created_at) or "Unknown"
    )
    
    lib.alertDialog({
        header = "Your Statistics",
        content = content,
        centered = true,
        cancel = true,
        size = 'lg',
        labels = {
            cancel = "Close",
            confirm = "View Achievements"
        }
    }, function(response)
        if response == "confirm" then
            TriggerServerEvent("SupplyChain:Server:GetPlayerAchievements")
        end
    end)
end)

-- Progress bar for current objective
function ShowObjectiveProgress(objective, current, target)
    lib.progressBar({
        duration = false,
        label = objective,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        anim = false
    })
    
    -- Update progress
    CreateThread(function()
        while current < target do
            Wait(100)
            lib.progressBar({
                duration = false,
                label = string.format("%s: %d/%d", objective, current, target),
                position = 'bottom',
                useWhileDead = false,
                canCancel = false,
                anim = false
            })
        end
        
        -- Complete
        lib.cancelProgress()
        lib.notify({
            title = "Objective Complete!",
            description = objective,
            type = "success"
        })
    end)
end

-- Utility functions
function GetCategoryName(category)
    local names = {
        [Constants.AchievementCategory.DELIVERY] = "Delivery",
        [Constants.AchievementCategory.SPEED] = "Speed",
        [Constants.AchievementCategory.TEAM] = "Team",
        [Constants.AchievementCategory.QUALITY] = "Quality",
        [Constants.AchievementCategory.ECONOMY] = "Economy",
        [Constants.AchievementCategory.SPECIAL] = "Special"
    }
    return names[category] or "Unknown"
end

function FormatRewards(achievement)
    local rewards = {}
    if achievement.rewardCash > 0 then
        table.insert(rewards, "$" .. achievement.rewardCash)
    end
    if achievement.rewardXP > 0 then
        table.insert(rewards, achievement.rewardXP .. " XP")
    end
    return #rewards > 0 and table.concat(rewards, " + ") or "None"
end

function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "N/A" end
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", minutes, secs)
end

function GetLevelTitle(level)
    for _, levelData in ipairs(Config.Rewards.experience.levels) do
        if levelData.level == level then
            return levelData.title
        end
    end
    return "Unknown"
end

function GetNextLevelXP(currentLevel)
    for _, levelData in ipairs(Config.Rewards.experience.levels) do
        if levelData.level > currentLevel then
            return levelData.xpRequired
        end
    end
    return 999999
end

function CalculateLevelProgress(currentXP, currentLevel)
    local currentLevelXP = 0
    local nextLevelXP = GetNextLevelXP(currentLevel)
    
    -- Find current level XP requirement
    for _, levelData in ipairs(Config.Rewards.experience.levels) do
        if levelData.level == currentLevel then
            currentLevelXP = levelData.xpRequired
            break
        end
    end
    
    local xpIntoLevel = currentXP - currentLevelXP
    local xpForLevel = nextLevelXP - currentLevelXP
    
    return math.floor((xpIntoLevel / xpForLevel) * 100)
end

-- Export achievement functions
exports('GetPlayerAchievements', function()
    return playerAchievements
end)

exports('ShowAchievements', function()
    if #playerAchievements == 0 then
        TriggerServerEvent("SupplyChain:Server:GetPlayerAchievements")
    else
        OpenAchievementsMenu()
    end
end)

exports('GetRecentUnlocks', function()
    return recentUnlocks
end)