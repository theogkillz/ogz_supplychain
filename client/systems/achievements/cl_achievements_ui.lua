-- ============================================
-- ACHIEVEMENT UI SYSTEM - ENTERPRISE CLIENT
-- Comprehensive achievement display and management
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Achievement state management
local playerAchievements = {}
local achievementProgress = {}
local currentTier = "rookie"

-- ============================================
-- ACHIEVEMENT DISPLAY FUNCTIONS
-- ============================================

-- Get achievement icon and styling
local function getAchievementIcon(achievementId, completed)
    local icons = {
        first_delivery = completed and "🚚" or "📦",
        speed_demon = completed and "⚡" or "🏃",
        big_hauler = completed and "🏗️" or "📋",
        perfect_week = completed and "👑" or "📅",
        century_club = completed and "💯" or "🎯",
        team_player = completed and "👥" or "🤝",
        market_master = completed and "📈" or "💹",
        safety_first = completed and "🛡️" or "⚠️",
        efficient_driver = completed and "⚙️" or "🔧",
        loyal_employee = completed and "💎" or "⭐"
    }
    return icons[achievementId] or (completed and "🏆" or "🎯")
end

-- Get achievement category styling
local function getCategoryIcon(category)
    local categoryIcons = {
        delivery = "🚛",
        performance = "⚡",
        teamwork = "👥",
        safety = "🛡️",
        loyalty = "💎",
        special = "🌟"
    }
    return categoryIcons[category] or "🏆"
end

-- Get tier styling and information
local function getTierInfo(tier)
    local tierData = {
        rookie = { name = "Rookie Driver", icon = "🚗", color = "🟫", description = "Just getting started" },
        experienced = { name = "Experienced Driver", icon = "🚙", color = "🔵", description = "Building experience" },
        professional = { name = "Professional Driver", icon = "🚐", color = "🟣", description = "Skilled professional" },
        elite = { name = "Elite Driver", icon = "🚛", color = "🟡", description = "Top-tier performance" },
        legendary = { name = "Legendary Driver", icon = "🏆", color = "🔴", description = "Ultimate achievement" }
    }
    return tierData[tier] or tierData.rookie
end

-- Calculate achievement completion percentage
local function calculateCompletionPercentage(achievements)
    if not achievements or #achievements == 0 then return 0 end
    
    local completed = 0
    local total = 0
    
    for _, achievement in ipairs(achievements) do
        total = total + 1
        if achievement.completed then
            completed = completed + 1
        end
    end
    
    return math.floor((completed / total) * 100)
end

-- ============================================
-- MAIN ACHIEVEMENT MENU
-- ============================================

-- Open main achievement dashboard
RegisterNetEvent("achievements:openDashboard")
AddEventHandler("achievements:openDashboard", function()
    -- Validate access using enterprise patterns
    if not exports.ogz_supplychain:validatePlayerAccess("achievements") then
        return
    end
    
    TriggerServerEvent("achievements:getPlayerData")
end)

-- Display comprehensive achievement dashboard
RegisterNetEvent("achievements:showDashboard")
AddEventHandler("achievements:showDashboard", function(achievementData)
    playerAchievements = achievementData.achievements or {}
    currentTier = achievementData.currentTier or "rookie"
    
    local tierInfo = getTierInfo(currentTier)
    local completionPercentage = calculateCompletionPercentage(playerAchievements)
    
    local options = {
        {
            title = "← Back to Warehouse",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        },
        {
            title = tierInfo.color .. " " .. tierInfo.name,
            description = string.format(
                "%s **%s**\n🏆 %d%% achievements completed\n📊 %d total achievements\n💫 %s",
                tierInfo.icon,
                tierInfo.name,
                completionPercentage,
                #playerAchievements,
                tierInfo.description
            ),
            metadata = {
                ["Current Tier"] = tierInfo.name,
                ["Completion"] = completionPercentage .. "%",
                ["Total Achievements"] = tostring(#playerAchievements),
                ["Next Tier"] = achievementData.nextTier or "Maximum reached"
            },
            onSelect = function()
                TriggerEvent("achievements:showTierProgress", achievementData)
            end
        },
        {
            title = "🏆 View All Achievements",
            description = "Browse all available achievements",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerEvent("achievements:showAllAchievements", playerAchievements)
            end
        },
        {
            title = "📊 Achievement Categories",
            description = "View achievements by category",
            icon = "fas fa-folder-open",
            onSelect = function()
                TriggerEvent("achievements:showCategories", playerAchievements)
            end
        },
        {
            title = "⏳ In Progress",
            description = "View achievements you're working on",
            icon = "fas fa-clock",
            onSelect = function()
                TriggerEvent("achievements:showInProgress", playerAchievements)
            end
        },
        {
            title = "🌟 Recent Achievements",
            description = "View recently earned achievements",
            icon = "fas fa-star",
            onSelect = function()
                TriggerEvent("achievements:showRecent", playerAchievements)
            end
        },
        {
            title = "🚗 Vehicle Benefits",
            description = "View vehicle performance bonuses",
            icon = "fas fa-car",
            onSelect = function()
                TriggerEvent("achievements:showVehicleBenefits", currentTier)
            end
        },
        {
            title = "📈 Achievement Statistics",
            description = "View detailed achievement analytics",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("achievements:showStatistics", achievementData.statistics)
            end
        }
    }
    
    lib.registerContext({
        id = "achievements_dashboard",
        title = "🏆 Achievement Dashboard",
        options = options
    })
    lib.showContext("achievements_dashboard")
end)

-- ============================================
-- TIER PROGRESSION DISPLAY
-- ============================================

-- Show tier progression and requirements
RegisterNetEvent("achievements:showTierProgress")
AddEventHandler("achievements:showTierProgress", function(achievementData)
    local currentTierInfo = getTierInfo(currentTier)
    local nextTier = achievementData.nextTier
    local nextTierInfo = nextTier and getTierInfo(nextTier) or nil
    
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("achievements:showDashboard", achievementData)
            end
        },
        {
            title = currentTierInfo.color .. " Current Tier: " .. currentTierInfo.name,
            description = string.format(
                "%s **%s**\n🎯 %s\n🚗 %s vehicle performance",
                currentTierInfo.icon,
                currentTierInfo.name,
                currentTierInfo.description,
                currentTier == "rookie" and "Standard" or "Enhanced"
            ),
            disabled = true
        }
    }
    
    -- Show current tier benefits
    if Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers then
        local tierConfig = Config.AchievementVehicles.performanceTiers[currentTier]
        if tierConfig then
            table.insert(options, {
                title = "🚗 Current Vehicle Benefits",
                description = tierConfig.description,
                metadata = {
                    ["Speed Multiplier"] = string.format("%.2fx", tierConfig.speedMultiplier or 1.0),
                    ["Acceleration Bonus"] = string.format("+%.0f%%", (tierConfig.accelerationBonus or 0) * 100),
                    ["Fuel Efficiency"] = string.format("%.2fx", tierConfig.fuelEfficiency or 1.0)
                },
                disabled = true
            })
        end
    end
    
    -- Show next tier requirements
    if nextTierInfo then
        table.insert(options, {
            title = "🎯 Next Tier: " .. nextTierInfo.name,
            description = string.format(
                "%s **%s**\n📋 Requirements: %s\n🚗 Enhanced vehicle performance",
                nextTierInfo.icon,
                nextTierInfo.name,
                achievementData.nextTierRequirements or "Complete more achievements"
            ),
            metadata = {
                ["Next Tier"] = nextTierInfo.name,
                ["Progress"] = achievementData.tierProgress or "0%",
                ["Requirements"] = achievementData.nextTierRequirements or "Unknown"
            },
            onSelect = function()
                TriggerEvent("achievements:showTierRequirements", nextTier, achievementData)
            end
        })
    else
        table.insert(options, {
            title = "👑 Maximum Tier Reached!",
            description = "You have achieved the highest tier available",
            disabled = true
        })
    end
    
    -- Show tier progression history
    if achievementData.tierHistory and #achievementData.tierHistory > 0 then
        table.insert(options, {
            title = "📈 Tier Progression History",
            description = "View your advancement through the tiers",
            onSelect = function()
                TriggerEvent("achievements:showTierHistory", achievementData.tierHistory)
            end
        })
    end
    
    lib.registerContext({
        id = "tier_progress",
        title = "🎯 Tier Progression",
        options = options
    })
    lib.showContext("tier_progress")
end)

-- ============================================
-- ACHIEVEMENT BROWSING
-- ============================================

-- Show all achievements with enterprise organization
RegisterNetEvent("achievements:showAllAchievements")
AddEventHandler("achievements:showAllAchievements", function(achievements)
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("achievements:openDashboard")
            end
        }
    }
    
    if not achievements or #achievements == 0 then
        table.insert(options, {
            title = "🎯 No Achievements Yet",
            description = "Complete deliveries to start earning achievements!",
            disabled = true
        })
    else
        -- Sort achievements: completed first, then by category
        table.sort(achievements, function(a, b)
            if a.completed ~= b.completed then
                return a.completed
            end
            return (a.category or "general") < (b.category or "general")
        end)
        
        for _, achievement in ipairs(achievements) do
            local icon = getAchievementIcon(achievement.achievementId, achievement.completed)
            local statusColor = achievement.completed and "🟢" or "🟡"
            local progressText = ""
            
            if not achievement.completed and achievement.progress and achievement.target then
                progressText = string.format(" (%d/%d)", achievement.progress, achievement.target)
            elseif achievement.completed and achievement.earnedDate then
                progressText = " ✓"
            end
            
            table.insert(options, {
                title = icon .. " " .. achievement.name .. " " .. statusColor,
                description = achievement.description .. progressText,
                metadata = {
                    ["Achievement"] = achievement.name,
                    ["Category"] = achievement.category or "General",
                    ["Status"] = achievement.completed and "Completed" or "In Progress",
                    ["Progress"] = achievement.completed and "100%" or 
                        (achievement.progress and achievement.target and 
                         string.format("%.1f%%", (achievement.progress / achievement.target) * 100) or "0%"),
                    ["Reward"] = achievement.reward and ("$" .. exports.ogz_supplychain:formatMoney(achievement.reward)) or "Experience"
                },
                onSelect = function()
                    TriggerEvent("achievements:showAchievementDetails", achievement)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "all_achievements",
        title = "🏆 All Achievements",
        options = options
    })
    lib.showContext("all_achievements")
end)

-- ============================================
-- ACHIEVEMENT CATEGORIES
-- ============================================

-- Show achievements organized by category
RegisterNetEvent("achievements:showCategories")
AddEventHandler("achievements:showCategories", function(achievements)
    -- Group achievements by category
    local categories = {}
    for _, achievement in ipairs(achievements or {}) do
        local category = achievement.category or "general"
        if not categories[category] then
            categories[category] = {}
        end
        table.insert(categories[category], achievement)
    end
    
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("achievements:openDashboard")
            end
        }
    }
    
    for category, categoryAchievements in pairs(categories) do
        local categoryIcon = getCategoryIcon(category)
        local completed = 0
        local total = #categoryAchievements
        
        for _, achievement in ipairs(categoryAchievements) do
            if achievement.completed then
                completed = completed + 1
            end
        end
        
        table.insert(options, {
            title = categoryIcon .. " " .. category:gsub("^%l", string.upper),
            description = string.format(
                "%d/%d achievements completed (%.1f%%)",
                completed,
                total,
                (completed / total) * 100
            ),
            metadata = {
                ["Category"] = category:gsub("^%l", string.upper),
                ["Completed"] = completed .. "/" .. total,
                ["Completion Rate"] = string.format("%.1f%%", (completed / total) * 100)
            },
            onSelect = function()
                TriggerEvent("achievements:showCategoryDetails", category, categoryAchievements)
            end
        })
    end
    
    lib.registerContext({
        id = "achievement_categories",
        title = "📂 Achievement Categories",
        options = options
    })
    lib.showContext("achievement_categories")
end)

-- ============================================
-- IN-PROGRESS ACHIEVEMENTS
-- ============================================

-- Show achievements currently in progress
RegisterNetEvent("achievements:showInProgress")
AddEventHandler("achievements:showInProgress", function(achievements)
    local inProgress = {}
    
    for _, achievement in ipairs(achievements or {}) do
        if not achievement.completed and achievement.progress and achievement.target then
            table.insert(inProgress, achievement)
        end
    end
    
    -- Sort by completion percentage (highest first)
    table.sort(inProgress, function(a, b)
        local aPercent = (a.progress / a.target) * 100
        local bPercent = (b.progress / b.target) * 100
        return aPercent > bPercent
    end)
    
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("achievements:openDashboard")
            end
        }
    }
    
    if #inProgress == 0 then
        table.insert(options, {
            title = "🎯 No Active Progress",
            description = "Complete deliveries to start working on achievements!",
            disabled = true
        })
    else
        table.insert(options, {
            title = "⏳ Achievements in Progress",
            description = string.format("%d achievements being worked on", #inProgress),
            disabled = true
        })
        
        for _, achievement in ipairs(inProgress) do
            local icon = getAchievementIcon(achievement.achievementId, false)
            local progressPercent = (achievement.progress / achievement.target) * 100
            local progressBar = string.rep("█", math.floor(progressPercent / 10)) .. 
                               string.rep("░", 10 - math.floor(progressPercent / 10))
            
            table.insert(options, {
                title = icon .. " " .. achievement.name,
                description = string.format(
                    "%s\n%s %.1f%% (%d/%d)",
                    achievement.description,
                    progressBar,
                    progressPercent,
                    achievement.progress,
                    achievement.target
                ),
                metadata = {
                    ["Achievement"] = achievement.name,
                    ["Progress"] = achievement.progress .. "/" .. achievement.target,
                    ["Completion"] = string.format("%.1f%%", progressPercent),
                    ["Remaining"] = (achievement.target - achievement.progress) .. " needed"
                },
                onSelect = function()
                    TriggerEvent("achievements:showProgressDetails", achievement)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "achievements_in_progress",
        title = "⏳ In Progress",
        options = options
    })
    lib.showContext("achievements_in_progress")
end)

-- ============================================
-- VEHICLE BENEFITS DISPLAY
-- ============================================

-- Show vehicle performance benefits from achievements
RegisterNetEvent("achievements:showVehicleBenefits")
AddEventHandler("achievements:showVehicleBenefits", function(tier)
    local tierInfo = getTierInfo(tier)
    
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("achievements:openDashboard")
            end
        },
        {
            title = tierInfo.color .. " " .. tierInfo.name .. " Benefits",
            description = "Vehicle performance enhancements from your achievement tier",
            disabled = true
        }
    }
    
    if Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers then
        local tierConfig = Config.AchievementVehicles.performanceTiers[tier]
        if tierConfig then
            table.insert(options, {
                title = "🚗 Performance Modifications",
                description = tierConfig.description,
                metadata = {
                    ["Tier"] = tierInfo.name,
                    ["Speed Multiplier"] = string.format("%.2fx", tierConfig.speedMultiplier or 1.0),
                    ["Acceleration"] = string.format("+%.0f%%", (tierConfig.accelerationBonus or 0) * 100),
                    ["Fuel Efficiency"] = string.format("%.2fx", tierConfig.fuelEfficiency or 1.0)
                },
                disabled = true
            })
            
            -- Show visual effects if available
            if tierConfig.specialEffects then
                table.insert(options, {
                    title = "✨ Visual Effects",
                    description = "Special visual enhancements for your tier",
                    metadata = {
                        ["Underglow"] = tierConfig.specialEffects.underglow and "Yes" or "No",
                        ["Custom Livery"] = tierConfig.specialEffects.customLivery and "Yes" or "No",
                        ["Horn Upgrade"] = tierConfig.specialEffects.hornUpgrade and "Yes" or "No"
                    },
                    disabled = true
                })
            end
        end
        
        -- Show all tier benefits for comparison
        table.insert(options, {
            title = "📊 All Tier Benefits",
            description = "Compare benefits across all achievement tiers",
            onSelect = function()
                TriggerEvent("achievements:showAllTierBenefits")
            end
        })
    end
    
    lib.registerContext({
        id = "vehicle_benefits",
        title = "🚗 Vehicle Benefits",
        options = options
    })
    lib.showContext("vehicle_benefits")
end)

-- ============================================
-- ACHIEVEMENT NOTIFICATIONS
-- ============================================

-- Display achievement earned notification
RegisterNetEvent("achievements:showEarnedNotification")
AddEventHandler("achievements:showEarnedNotification", function(achievementData)
    local icon = getAchievementIcon(achievementData.achievementId, true)
    
    -- Show celebration notification
    exports.ogz_supplychain:successNotify(
        "🎉 Achievement Unlocked!",
        string.format("**%s %s**\n%s", icon, achievementData.name, achievementData.description)
    )
    
    -- Show reward if applicable
    if achievementData.reward and achievementData.reward > 0 then
        Citizen.SetTimeout(2000, function()
            exports.ogz_supplychain:successNotify(
                "💰 Achievement Reward",
                string.format("You earned $%s for completing this achievement!", 
                    exports.ogz_supplychain:formatMoney(achievementData.reward))
            )
        end)
    end
    
    -- Play achievement sound
    PlaySoundFrontend(-1, "WAYPOINT_SET", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end)

-- Display tier advancement notification
RegisterNetEvent("achievements:showTierAdvancement")
AddEventHandler("achievements:showTierAdvancement", function(newTier, oldTier)
    local newTierInfo = getTierInfo(newTier)
    local oldTierInfo = getTierInfo(oldTier)
    
    lib.alertDialog({
        header = "🏆 TIER ADVANCEMENT!",
        content = string.format(
            "**Congratulations!**\n\nYou have advanced from **%s** to **%s %s**!\n\n🚗 Your vehicles now have enhanced performance\n💎 New benefits unlocked\n🎯 Access to exclusive content",
            oldTierInfo.name,
            newTierInfo.icon,
            newTierInfo.name
        ),
        centered = true,
        cancel = false,
        size = 'lg',
        labels = {
            cancel = "Awesome!"
        }
    })
    
    -- Play special tier advancement sound
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_MINI_GAME_SOUNDSET", true)
end)

-- ============================================
-- EXPORTS FOR INTEGRATION
-- ============================================

-- Export achievement UI functions for other components
exports('openAchievementDashboard', function()
    TriggerEvent("achievements:openDashboard")
end)

exports('showAchievementEarned', function(achievementData)
    TriggerEvent("achievements:showEarnedNotification", achievementData)
end)

exports('showTierAdvancement', function(newTier, oldTier)
    TriggerEvent("achievements:showTierAdvancement", newTier, oldTier)
end)

exports('getCurrentTier', function()
    return currentTier
end)

exports('getPlayerAchievements', function()
    return playerAchievements
end)

print("[ACHIEVEMENTS UI] Enterprise achievement UI system initialized")