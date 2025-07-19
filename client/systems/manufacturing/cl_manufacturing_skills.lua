-- ============================================
-- MANUFACTURING SKILLS & ANALYTICS
-- Player statistics and skill progression
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Skills and analytics state
local playerStats = {}
local skillProgressCache = {}

-- ============================================
-- PLAYER STATISTICS DISPLAY
-- ============================================

-- Open player stats interface
RegisterNetEvent("manufacturing:openPlayerStats")
AddEventHandler("manufacturing:openPlayerStats", function()
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    TriggerServerEvent("manufacturing:getPlayerStats")
end)

-- Show comprehensive player manufacturing stats
RegisterNetEvent("manufacturing:showPlayerStats")
AddEventHandler("manufacturing:showPlayerStats", function(stats)
    playerStats = stats
    
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:returnToFacilityMenu")
            end
        },
        {
            title = "📊 Production Statistics",
            description = string.format(
                "🎯 Total Batches: %d\n📦 Items Produced: %d\n⭐ Success Rate: %.1f%%\n🧪 Unique Recipes: %d",
                stats.stats.total_batches or 0,
                stats.stats.total_output or 0,
                (stats.stats.success_rate or 0) * 100,
                stats.stats.unique_recipes or 0
            ),
            onSelect = function()
                TriggerEvent("manufacturing:showDetailedStats", stats.stats)
            end
        }
    }
    
    -- Show skill levels with enterprise formatting
    if stats.skills and #stats.skills > 0 then
        table.insert(options, {
            title = "🎯 Manufacturing Skills",
            description = "Your current skill levels",
            disabled = true
        })
        
        for _, skill in ipairs(stats.skills) do
            local categoryConfig = stats.skillCategories[skill.category]
            local categoryName = categoryConfig and categoryConfig.name or skill.category
            local skillLevel = math.floor(skill.skill_level)
            local maxLevel = categoryConfig and categoryConfig.maxLevel or 100
            local progressPercent = (skillLevel / maxLevel) * 100
            
            -- Determine skill tier for visual representation
            local skillTier = "🔧"
            if skillLevel >= 75 then
                skillTier = "🏆"
            elseif skillLevel >= 50 then
                skillTier = "⭐"
            elseif skillLevel >= 25 then
                skillTier = "📈"
            end
            
            table.insert(options, {
                title = string.format("%s %s", skillTier, categoryName),
                description = string.format("Level %d/%d (%.1f%%)", skillLevel, maxLevel, progressPercent),
                metadata = {
                    ["Skill Level"] = skillLevel .. "/" .. maxLevel,
                    ["Total Experience"] = skill.total_experience or 0,
                    ["Progress"] = string.format("%.1f%%", progressPercent),
                    ["Next Milestone"] = getNextMilestone(skillLevel)
                },
                onSelect = function()
                    TriggerEvent("manufacturing:showSkillDetails", skill, categoryConfig)
                end
            })
        end
    else
        table.insert(options, {
            title = "🎯 No Skills Yet",
            description = "Start manufacturing to develop your skills!",
            onSelect = function()
                TriggerEvent("manufacturing:showSkillGuide")
            end
        })
    end
    
    -- Achievement progress
    table.insert(options, {
        title = "🏆 Achievement Progress",
        description = "View manufacturing achievements",
        icon = "fas fa-trophy",
        onSelect = function()
            TriggerEvent("manufacturing:showAchievements")
        end
    })
    
    lib.registerContext({
        id = "manufacturing_player_stats",
        title = "📊 My Manufacturing Stats",
        options = options
    })
    lib.showContext("manufacturing_player_stats")
end)

-- ============================================
-- DETAILED STATISTICS BREAKDOWN
-- ============================================

-- Show detailed production statistics
RegisterNetEvent("manufacturing:showDetailedStats")
AddEventHandler("manufacturing:showDetailedStats", function(stats)
    local options = {
        {
            title = "← Back to Stats",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openPlayerStats")
            end
        },
        {
            title = "📈 Production Analytics",
            description = "Comprehensive production data",
            disabled = true
        }
    }
    
    -- Production volume metrics
    table.insert(options, {
        title = "📦 Production Volume",
        description = "Total manufacturing output",
        metadata = {
            ["Total Batches"] = stats.total_batches or 0,
            ["Items Produced"] = stats.total_output or 0,
            ["Average per Batch"] = stats.total_batches > 0 and 
                math.floor((stats.total_output or 0) / stats.total_batches) or 0
        },
        disabled = true
    })
    
    -- Quality metrics
    local successRate = (stats.success_rate or 0) * 100
    local qualityTier = "🔴"
    if successRate >= 90 then
        qualityTier = "🟢"
    elseif successRate >= 75 then
        qualityTier = "🟡"
    end
    
    table.insert(options, {
        title = qualityTier .. " Quality Performance",
        description = "Production quality tracking",
        metadata = {
            ["Success Rate"] = string.format("%.1f%%", successRate),
            ["Premium Productions"] = stats.premium_count or 0,
            ["Organic Productions"] = stats.organic_count or 0,
            ["Quality Score"] = calculateQualityScore(stats)
        },
        disabled = true
    })
    
    -- Efficiency metrics
    table.insert(options, {
        title = "⚡ Manufacturing Efficiency",
        description = "Speed and cost optimization",
        metadata = {
            ["Average Processing Time"] = exports.ogz_supplychain:formatTime(stats.avg_processing_time or 0),
            ["Total Processing Cost"] = "$" .. exports.ogz_supplychain:formatMoney(stats.total_cost or 0),
            ["Cost per Item"] = "$" .. (stats.total_output > 0 and 
                math.floor((stats.total_cost or 0) / stats.total_output) or 0)
        },
        disabled = true
    })
    
    lib.registerContext({
        id = "manufacturing_detailed_stats",
        title = "📈 Production Analytics",
        options = options
    })
    lib.showContext("manufacturing_detailed_stats")
end)

-- ============================================
-- SKILL PROGRESSION SYSTEM
-- ============================================

-- Show individual skill details and progression
RegisterNetEvent("manufacturing:showSkillDetails")
AddEventHandler("manufacturing:showSkillDetails", function(skill, categoryConfig)
    local skillLevel = math.floor(skill.skill_level)
    local maxLevel = categoryConfig.maxLevel or 100
    local progressPercent = (skillLevel / maxLevel) * 100
    
    local options = {
        {
            title = "← Back to Stats",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openPlayerStats")
            end
        },
        {
            title = "🎯 " .. categoryConfig.name,
            description = "Skill progression details",
            disabled = true
        }
    }
    
    -- Current skill status
    table.insert(options, {
        title = "📊 Current Level",
        description = string.format("Level %d of %d", skillLevel, maxLevel),
        metadata = {
            ["Experience Points"] = skill.total_experience or 0,
            ["Progress"] = string.format("%.1f%%", progressPercent),
            ["Experience Rate"] = string.format("%.1fx", categoryConfig.experienceRate or 1.0)
        },
        disabled = true
    })
    
    -- Skill bonuses
    local currentBonuses = getSkillBonuses(skillLevel)
    if currentBonuses then
        table.insert(options, {
            title = "⭐ Active Bonuses",
            description = "Current skill bonuses",
            metadata = {
                ["Yield Bonus"] = string.format("+%.1f%%", (currentBonuses.yieldBonus or 0) * 100),
                ["Speed Bonus"] = string.format("+%.1f%%", (currentBonuses.speedBonus or 0) * 100)
            },
            disabled = true
        })
    end
    
    -- Next milestone
    local nextMilestone = getNextMilestone(skillLevel)
    if nextMilestone then
        local nextBonuses = getSkillBonuses(nextMilestone)
        table.insert(options, {
            title = "🎯 Next Milestone",
            description = string.format("Level %d rewards", nextMilestone),
            metadata = {
                ["Levels to Go"] = nextMilestone - skillLevel,
                ["Yield Bonus"] = nextBonuses and string.format("+%.1f%%", (nextBonuses.yieldBonus or 0) * 100) or "N/A",
                ["Speed Bonus"] = nextBonuses and string.format("+%.1f%%", (nextBonuses.speedBonus or 0) * 100) or "N/A"
            },
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "manufacturing_skill_details",
        title = "🎯 " .. categoryConfig.name .. " Skills",
        options = options
    })
    lib.showContext("manufacturing_skill_details")
end)

-- ============================================
-- ACHIEVEMENT TRACKING
-- ============================================

-- Show manufacturing achievements
RegisterNetEvent("manufacturing:showAchievements")
AddEventHandler("manufacturing:showAchievements", function()
    TriggerServerEvent("manufacturing:getAchievements")
end)

-- Display achievement progress
RegisterNetEvent("manufacturing:displayAchievements")
AddEventHandler("manufacturing:displayAchievements", function(achievements)
    local options = {
        {
            title = "← Back to Stats",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openPlayerStats")
            end
        },
        {
            title = "🏆 Manufacturing Achievements",
            description = "Production milestones and rewards",
            disabled = true
        }
    }
    
    -- Group achievements by category
    local achievementCategories = {
        production = "🏭 Production Milestones",
        quality = "⭐ Quality Excellence", 
        efficiency = "⚡ Efficiency Masters",
        specialization = "🎯 Specialization Mastery"
    }
    
    for category, title in pairs(achievementCategories) do
        local categoryAchievements = {}
        
        for _, achievement in ipairs(achievements or {}) do
            if achievement.category == category then
                table.insert(categoryAchievements, achievement)
            end
        end
        
        if #categoryAchievements > 0 then
            table.insert(options, {
                title = title,
                description = string.format("%d achievements", #categoryAchievements),
                disabled = true
            })
            
            for _, achievement in ipairs(categoryAchievements) do
                local statusIcon = achievement.completed and "✅" or "⏳"
                local progressText = achievement.completed and "Completed" or
                    string.format("%d/%d", achievement.progress or 0, achievement.target or 1)
                
                table.insert(options, {
                    title = statusIcon .. " " .. achievement.name,
                    description = achievement.description,
                    metadata = {
                        ["Progress"] = progressText,
                        ["Reward"] = achievement.reward or "Experience",
                        ["Category"] = category:gsub("^%l", string.upper)
                    },
                    disabled = true
                })
            end
        end
    end
    
    if #achievements == 0 then
        table.insert(options, {
            title = "🎯 Start Your Journey",
            description = "Complete your first manufacturing batch to unlock achievements!",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "manufacturing_achievements",
        title = "🏆 Manufacturing Achievements",
        options = options
    })
    lib.showContext("manufacturing_achievements")
end)

-- ============================================
-- SKILL PROGRESSION HELPERS
-- ============================================

-- Get next skill milestone
function getNextMilestone(currentLevel)
    local milestones = {25, 50, 75, 100}
    for _, milestone in ipairs(milestones) do
        if currentLevel < milestone then
            return milestone
        end
    end
    return nil
end

-- Get skill bonuses for level
function getSkillBonuses(level)
    if not Config.ManufacturingSkills or not Config.ManufacturingSkills.levelBonuses then
        return nil
    end
    
    local bestBonus = nil
    for milestoneLevel, bonus in pairs(Config.ManufacturingSkills.levelBonuses) do
        if level >= milestoneLevel then
            bestBonus = bonus
        end
    end
    return bestBonus
end

-- Calculate overall quality score
function calculateQualityScore(stats)
    local successRate = (stats.success_rate or 0) * 100
    local premiumRatio = (stats.total_batches or 0) > 0 and 
        ((stats.premium_count or 0) / stats.total_batches * 100) or 0
    local organicRatio = (stats.total_batches or 0) > 0 and 
        ((stats.organic_count or 0) / stats.total_batches * 100) or 0
    
    return math.floor(successRate + (premiumRatio * 0.5) + (organicRatio * 1.0))
end

-- ============================================
-- SKILL TRACKING EVENTS
-- ============================================

-- Track skill progression from manufacturing activities
RegisterNetEvent("manufacturing:trackSkillGain")
AddEventHandler("manufacturing:trackSkillGain", function(skillData)
    -- Update local skill cache
    if not skillProgressCache[skillData.category] then
        skillProgressCache[skillData.category] = {}
    end
    
    skillProgressCache[skillData.category].lastGain = skillData.experience
    skillProgressCache[skillData.category].timestamp = GetGameTimer()
    
    -- Show skill gain notification
    if skillData.experience > 0 then
        exports.ogz_supplychain:infoNotify(
            "🎯 Skill Progress",
            string.format("+%d XP in %s", skillData.experience, skillData.categoryName or skillData.category)
        )
    end
    
    -- Check for level up
    if skillData.levelUp then
        exports.ogz_supplychain:successNotify(
            "🎉 Level Up!",
            string.format("%s skill reached level %d!", skillData.categoryName, skillData.newLevel)
        )
    end
end)

-- ============================================
-- ANALYTICS EXPORT FUNCTIONS
-- ============================================

-- Export player statistics for other components
exports('getPlayerStats', function()
    return playerStats
end)

-- Export skill progression data
exports('getSkillProgress', function()
    return skillProgressCache
end)

-- Export quality score calculation
exports('calculateQualityScore', calculateQualityScore)

-- Export skill bonus lookup
exports('getSkillBonuses', getSkillBonuses)

-- Export achievement tracking trigger
exports('trackAchievement', function(achievementData)
    TriggerServerEvent("achievements:trackManufacturing", achievementData)
end)

-- ============================================
-- SKILL GUIDE SYSTEM
-- ============================================

-- Show skill development guide for new players
RegisterNetEvent("manufacturing:showSkillGuide")
AddEventHandler("manufacturing:showSkillGuide", function()
    local options = {
        {
            title = "← Back to Stats",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openPlayerStats")
            end
        },
        {
            title = "🎯 Skill Development Guide",
            description = "Learn how to improve your manufacturing skills",
            disabled = true
        }
    }
    
    -- Show skill categories
    if Config.ManufacturingSkills and Config.ManufacturingSkills.skillCategories then
        for category, config in pairs(Config.ManufacturingSkills.skillCategories) do
            table.insert(options, {
                title = "📚 " .. config.name,
                description = string.format("Max Level: %d | Experience Rate: %.1fx", 
                    config.maxLevel, config.experienceRate),
                metadata = {
                    ["Category"] = category,
                    ["How to Level"] = "Complete " .. category .. " recipes",
                    ["Bonuses"] = "Unlock yield and speed bonuses"
                },
                disabled = true
            })
        end
    end
    
    -- Tips section
    table.insert(options, {
        title = "💡 Skill Development Tips",
        description = "Maximize your skill progression",
        disabled = true
    })
    
    table.insert(options, {
        title = "⭐ Focus on Quality",
        description = "Premium and organic recipes give more experience",
        disabled = true
    })
    
    table.insert(options, {
        title = "🔄 Diversify Production",
        description = "Work on multiple skill categories for balanced growth",
        disabled = true
    })
    
    lib.registerContext({
        id = "manufacturing_skill_guide",
        title = "📚 Skill Development Guide",
        options = options
    })
    lib.showContext("manufacturing_skill_guide")
end)

print("[MANUFACTURING] Skills & Analytics initialized")