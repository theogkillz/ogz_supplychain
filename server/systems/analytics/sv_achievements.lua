-- Advanced Achievement System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Achievement tracking
local playerAchievements = {}
local achievementDefinitions = {}

-- Initialize achievement system
CreateThread(function()
    -- Load achievement definitions
    LoadAchievementDefinitions()
    
    -- Load player achievements
    LoadPlayerAchievements()
    
    print("^2[SupplyChain]^7 Achievement system initialized")
end)

-- Load achievement definitions
function LoadAchievementDefinitions()
    -- Load from database
    MySQL.Async.fetchAll('SELECT * FROM supply_achievements', {}, function(results)
        for _, achievement in ipairs(results) do
            achievementDefinitions[achievement.achievement_id] = {
                id = achievement.achievement_id,
                name = achievement.name,
                description = achievement.description,
                category = achievement.category,
                rewardCash = achievement.reward_cash,
                rewardXP = achievement.reward_xp,
                requirement = json.decode(achievement.requirement or '{}'),
                icon = achievement.icon
            }
        end
    end)
    
    -- Add hardcoded achievements if missing
    EnsureDefaultAchievements()
end

-- Ensure default achievements exist
function EnsureDefaultAchievements()
    local defaultAchievements = {
        -- Delivery achievements
        {
            id = "first_delivery",
            name = "First Steps",
            description = "Complete your first delivery",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 100,
            rewardXP = 10,
            requirement = { type = "delivery_count", value = 1 }
        },
        {
            id = "delivery_10",
            name = "Regular Driver",
            description = "Complete 10 deliveries",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 250,
            rewardXP = 25,
            requirement = { type = "delivery_count", value = 10 }
        },
        {
            id = "delivery_50",
            name = "Experienced Driver",
            description = "Complete 50 deliveries",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 500,
            rewardXP = 50,
            requirement = { type = "delivery_count", value = 50 }
        },
        {
            id = "delivery_100",
            name = "Professional Driver",
            description = "Complete 100 deliveries",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "delivery_count", value = 100 }
        },
        {
            id = "delivery_500",
            name = "Elite Driver",
            description = "Complete 500 deliveries",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 5000,
            rewardXP = 500,
            requirement = { type = "delivery_count", value = 500 }
        },
        {
            id = "delivery_1000",
            name = "Legendary Driver",
            description = "Complete 1000 deliveries",
            category = Constants.AchievementCategory.DELIVERY,
            rewardCash = 10000,
            rewardXP = 1000,
            requirement = { type = "delivery_count", value = 1000 }
        },
        
        -- Speed achievements
        {
            id = "speed_demon",
            name = "Speed Demon",
            description = "Complete a delivery in under 5 minutes",
            category = Constants.AchievementCategory.SPEED,
            rewardCash = 500,
            rewardXP = 50,
            requirement = { type = "delivery_time", value = 300 }
        },
        {
            id = "lightning_fast",
            name = "Lightning Fast",
            description = "Complete a delivery in under 3 minutes",
            category = Constants.AchievementCategory.SPEED,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "delivery_time", value = 180 }
        },
        {
            id = "time_traveler",
            name = "Time Traveler",
            description = "Complete a delivery in under 2 minutes",
            category = Constants.AchievementCategory.SPEED,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "delivery_time", value = 120 }
        },
        
        -- Team achievements
        {
            id = "team_player",
            name = "Team Player",
            description = "Complete 10 team deliveries",
            category = Constants.AchievementCategory.TEAM,
            rewardCash = 500,
            rewardXP = 50,
            requirement = { type = "team_deliveries", value = 10 }
        },
        {
            id = "squad_goals",
            name = "Squad Goals",
            description = "Complete 50 team deliveries",
            category = Constants.AchievementCategory.TEAM,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "team_deliveries", value = 50 }
        },
        {
            id = "dream_team",
            name = "Dream Team",
            description = "Complete 100 team deliveries",
            category = Constants.AchievementCategory.TEAM,
            rewardCash = 5000,
            rewardXP = 500,
            requirement = { type = "team_deliveries", value = 100 }
        },
        
        -- Quality achievements
        {
            id = "quality_control",
            name = "Quality Control",
            description = "Complete 10 perfect quality deliveries",
            category = Constants.AchievementCategory.QUALITY,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "perfect_deliveries", value = 10 }
        },
        {
            id = "perfectionist",
            name = "Perfectionist",
            description = "Complete 50 perfect quality deliveries",
            category = Constants.AchievementCategory.QUALITY,
            rewardCash = 5000,
            rewardXP = 500,
            requirement = { type = "perfect_deliveries", value = 50 }
        },
        {
            id = "zero_damage",
            name = "Zero Damage Master",
            description = "Complete 100 perfect quality deliveries",
            category = Constants.AchievementCategory.QUALITY,
            rewardCash = 10000,
            rewardXP = 1000,
            requirement = { type = "perfect_deliveries", value = 100 }
        },
        
        -- Economy achievements
        {
            id = "money_maker",
            name = "Money Maker",
            description = "Earn $10,000 from deliveries",
            category = Constants.AchievementCategory.ECONOMY,
            rewardCash = 500,
            rewardXP = 50,
            requirement = { type = "total_earnings", value = 10000 }
        },
        {
            id = "entrepreneur",
            name = "Entrepreneur",
            description = "Earn $50,000 from deliveries",
            category = Constants.AchievementCategory.ECONOMY,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "total_earnings", value = 50000 }
        },
        {
            id = "tycoon",
            name = "Supply Chain Tycoon",
            description = "Earn $250,000 from deliveries",
            category = Constants.AchievementCategory.ECONOMY,
            rewardCash = 10000,
            rewardXP = 1000,
            requirement = { type = "total_earnings", value = 250000 }
        },
        
        -- Special achievements
        {
            id = "night_owl",
            name = "Night Owl",
            description = "Complete 50 deliveries at night",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "night_deliveries", value = 50 }
        },
        {
            id = "early_bird",
            name = "Early Bird",
            description = "Complete 50 deliveries in the morning",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "morning_deliveries", value = 50 }
        },
        {
            id = "weekend_warrior",
            name = "Weekend Warrior",
            description = "Complete 100 weekend deliveries",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "weekend_deliveries", value = 100 }
        },
        {
            id = "first_emergency",
            name = "Emergency Responder",
            description = "Complete your first emergency order",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 500,
            rewardXP = 50,
            requirement = { type = "emergency_deliveries", value = 1 }
        },
        {
            id = "emergency_expert",
            name = "Emergency Expert",
            description = "Complete 25 emergency orders",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 5000,
            rewardXP = 500,
            requirement = { type = "emergency_deliveries", value = 25 }
        },
        {
            id = "warehouse_hero",
            name = "Warehouse Hero",
            description = "Prevent a critical stockout",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "special", value = "hero_moment" }
        },
        {
            id = "streak_master",
            name = "Streak Master",
            description = "Achieve a 25 delivery streak",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 2500,
            rewardXP = 250,
            requirement = { type = "delivery_streak", value = 25 }
        },
        {
            id = "container_expert",
            name = "Container Expert",
            description = "Use containers 100 times",
            category = Constants.AchievementCategory.SPECIAL,
            rewardCash = 1000,
            rewardXP = 100,
            requirement = { type = "container_usage", value = 100 }
        }
    }
    
    -- Insert missing achievements
    for _, achievement in ipairs(defaultAchievements) do
        if not achievementDefinitions[achievement.id] then
            MySQL.Async.insert([[
                INSERT IGNORE INTO supply_achievements 
                (achievement_id, name, description, category, reward_cash, reward_xp, requirement, icon)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                achievement.id,
                achievement.name,
                achievement.description,
                achievement.category,
                achievement.rewardCash,
                achievement.rewardXP,
                json.encode(achievement.requirement),
                achievement.icon or "fas fa-trophy"
            })
            
            achievementDefinitions[achievement.id] = achievement
        end
    end
end

-- Load player achievements
function LoadPlayerAchievements()
    MySQL.Async.fetchAll('SELECT * FROM supply_player_achievements', {}, function(results)
        for _, record in ipairs(results) do
            if not playerAchievements[record.citizenid] then
                playerAchievements[record.citizenid] = {}
            end
            
            playerAchievements[record.citizenid][record.achievement_id] = {
                unlockedAt = record.unlocked_at,
                progress = record.progress,
                claimed = record.claimed
            }
        end
    end)
end

-- Unlock achievement
RegisterNetEvent(Constants.Events.Server.UnlockAchievement)
AddEventHandler(Constants.Events.Server.UnlockAchievement, function(achievementId, targetPlayerId)
    local src = targetPlayerId or source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    local citizenId = GetPlayerCitizenId(src)
    local achievement = achievementDefinitions[achievementId]
    
    if not achievement then
        print("^1[SupplyChain]^7 Unknown achievement: " .. tostring(achievementId))
        return
    end
    
    -- Check if already unlocked
    if playerAchievements[citizenId] and playerAchievements[citizenId][achievementId] then
        return
    end
    
    -- Initialize player achievements if needed
    if not playerAchievements[citizenId] then
        playerAchievements[citizenId] = {}
    end
    
    -- Unlock achievement
    playerAchievements[citizenId][achievementId] = {
        unlockedAt = os.time(),
        progress = achievement.requirement.value or 0,
        claimed = false
    }
    
    -- Save to database
    MySQL.Async.insert([[
        INSERT INTO supply_player_achievements 
        (citizenid, achievement_id, progress)
        VALUES (?, ?, ?)
    ]], {
        citizenId,
        achievementId,
        achievement.requirement.value or 0
    })
    
    -- Grant rewards
    if achievement.rewardCash > 0 then
        Framework.AddMoney(player, 'bank', achievement.rewardCash, 'Achievement reward')
    end
    
    if achievement.rewardXP > 0 and Config.Rewards.experience.enabled then
        AddPlayerExperience(src, achievement.rewardXP)
    end
    
    -- Notify player
    TriggerClientEvent("SupplyChain:Client:AchievementUnlocked", src, achievement)
    
    -- Log achievement
    MySQL.Async.insert([[
        INSERT INTO supply_system_logs (player_id, action, data)
        VALUES (?, ?, ?)
    ]], {
        citizenId,
        "achievement_unlocked",
        json.encode({
            achievementId = achievementId,
            name = achievement.name,
            rewards = {
                cash = achievement.rewardCash,
                xp = achievement.rewardXP
            }
        })
    })
end)

-- Check achievement progress
RegisterNetEvent("SupplyChain:Server:CheckAchievementProgress")
AddEventHandler("SupplyChain:Server:CheckAchievementProgress", function(playerId, achievementType, value)
    local citizenId = GetPlayerCitizenId(playerId)
    
    for achievementId, achievement in pairs(achievementDefinitions) do
        if achievement.requirement.type == achievementType then
            -- Check if already unlocked
            if not (playerAchievements[citizenId] and playerAchievements[citizenId][achievementId]) then
                -- Check if requirement met
                if CheckAchievementRequirement(playerId, achievement, value) then
                    TriggerEvent(Constants.Events.Server.UnlockAchievement, achievementId, playerId)
                else
                    -- Update progress
                    UpdateAchievementProgress(playerId, achievementId, value)
                end
            end
        end
    end
end)

-- Check achievement requirement
function CheckAchievementRequirement(playerId, achievement, currentValue)
    local citizenId = GetPlayerCitizenId(playerId)
    local req = achievement.requirement
    
    if req.type == "delivery_count" then
        return GetPlayerDeliveryCount(citizenId) >= req.value
        
    elseif req.type == "delivery_time" then
        return currentValue and currentValue <= req.value
        
    elseif req.type == "team_deliveries" then
        return GetPlayerTeamDeliveries(citizenId) >= req.value
        
    elseif req.type == "perfect_deliveries" then
        return GetPlayerPerfectDeliveries(citizenId) >= req.value
        
    elseif req.type == "total_earnings" then
        return GetPlayerTotalEarnings(citizenId) >= req.value
        
    elseif req.type == "night_deliveries" then
        return GetPlayerTimeBasedDeliveries(citizenId, "night") >= req.value
        
    elseif req.type == "morning_deliveries" then
        return GetPlayerTimeBasedDeliveries(citizenId, "morning") >= req.value
        
    elseif req.type == "weekend_deliveries" then
        return GetPlayerWeekendDeliveries(citizenId) >= req.value
        
    elseif req.type == "emergency_deliveries" then
        return GetPlayerEmergencyDeliveries(citizenId) >= req.value
        
    elseif req.type == "delivery_streak" then
        return GetPlayerCurrentStreak(citizenId) >= req.value
        
    elseif req.type == "container_usage" then
        return GetPlayerContainerUsage(citizenid) >= req.value
        
    elseif req.type == "special" then
        return currentValue == req.value
    end
    
    return false
end

-- Update achievement progress
function UpdateAchievementProgress(playerId, achievementId, progress)
    local citizenId = GetPlayerCitizenId(playerId)
    
    if not playerAchievements[citizenId] then
        playerAchievements[citizenId] = {}
    end
    
    if not playerAchievements[citizenId][achievementId] then
        playerAchievements[citizenId][achievementId] = {
            progress = 0,
            claimed = false
        }
    end
    
    playerAchievements[citizenId][achievementId].progress = progress
    
    -- Update database
    MySQL.Async.execute([[
        INSERT INTO supply_player_achievements (citizenid, achievement_id, progress)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE progress = ?
    ]], {
        citizenId,
        achievementId,
        progress,
        progress
    })
end

-- Get player achievements
RegisterNetEvent("SupplyChain:Server:GetPlayerAchievements")
AddEventHandler("SupplyChain:Server:GetPlayerAchievements", function()
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    local citizenId = GetPlayerCitizenId(src)
    local achievements = {}
    
    -- Build achievement list with progress
    for achievementId, definition in pairs(achievementDefinitions) do
        local playerData = playerAchievements[citizenId] and playerAchievements[citizenId][achievementId]
        
        table.insert(achievements, {
            id = achievementId,
            name = definition.name,
            description = definition.description,
            category = definition.category,
            icon = definition.icon,
            rewardCash = definition.rewardCash,
            rewardXP = definition.rewardXP,
            requirement = definition.requirement,
            unlocked = playerData ~= nil,
            unlockedAt = playerData and playerData.unlockedAt,
            progress = GetAchievementProgress(citizenId, achievementId, definition),
            claimed = playerData and playerData.claimed or false
        })
    end
    
    -- Sort by category and locked status
    table.sort(achievements, function(a, b)
        if a.category ~= b.category then
            return a.category < b.category
        end
        if a.unlocked ~= b.unlocked then
            return a.unlocked
        end
        return a.name < b.name
    end)
    
    TriggerClientEvent(Constants.Events.Client.ShowAchievements, src, achievements)
end)

-- Get achievement progress
function GetAchievementProgress(citizenId, achievementId, definition)
    local req = definition.requirement
    local current = 0
    local target = req.value or 0
    
    if req.type == "delivery_count" then
        current = GetPlayerDeliveryCount(citizenId)
    elseif req.type == "team_deliveries" then
        current = GetPlayerTeamDeliveries(citizenId)
    elseif req.type == "perfect_deliveries" then
        current = GetPlayerPerfectDeliveries(citizenId)
    elseif req.type == "total_earnings" then
        current = GetPlayerTotalEarnings(citizenId)
    elseif req.type == "night_deliveries" then
        current = GetPlayerTimeBasedDeliveries(citizenId, "night")
    elseif req.type == "morning_deliveries" then
        current = GetPlayerTimeBasedDeliveries(citizenid, "morning")
    elseif req.type == "weekend_deliveries" then
        current = GetPlayerWeekendDeliveries(citizenId)
    elseif req.type == "emergency_deliveries" then
        current = GetPlayerEmergencyDeliveries(citizenId)
    elseif req.type == "container_usage" then
        current = GetPlayerContainerUsage(citizenId)
    end
    
    return {
        current = math.min(current, target),
        target = target,
        percentage = target > 0 and math.floor((current / target) * 100) or 0
    }
end

-- Player stat queries (cached for performance)
local statCache = {}
local CACHE_DURATION = 300 -- 5 minutes

function GetPlayerDeliveryCount(citizenId)
    return GetCachedStat(citizenId, "delivery_count", function()
        return MySQL.scalar.await('SELECT deliveries FROM supply_driver_stats WHERE citizenid = ?', { citizenId }) or 0
    end)
end

function GetPlayerTeamDeliveries(citizenId)
    return GetCachedStat(citizenId, "team_deliveries", function()
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM supply_deliveries 
            WHERE player_id = ? AND team_size > 1
        ]], { citizenId }) or 0
    end)
end

function GetPlayerPerfectDeliveries(citizenId)
    return GetCachedStat(citizenId, "perfect_deliveries", function()
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM supply_deliveries 
            WHERE player_id = ? AND quality_score >= 95
        ]], { citizenId }) or 0
    end)
end

function GetPlayerTotalEarnings(citizenId)
    return GetCachedStat(citizenId, "total_earnings", function()
        return MySQL.scalar.await('SELECT earnings FROM supply_driver_stats WHERE citizenid = ?', { citizenId }) or 0
    end)
end

function GetPlayerTimeBasedDeliveries(citizenId, timeType)
    return GetCachedStat(citizenId, timeType .. "_deliveries", function()
        local hourCondition = ""
        if timeType == "night" then
            hourCondition = "HOUR(completed_at) >= 22 OR HOUR(completed_at) < 6"
        elseif timeType == "morning" then
            hourCondition = "HOUR(completed_at) >= 6 AND HOUR(completed_at) < 12"
        end
        
        return MySQL.scalar.await(string.format([[
            SELECT COUNT(*) FROM supply_deliveries 
            WHERE player_id = ? AND %s
        ]], hourCondition), { citizenId }) or 0
    end)
end

function GetPlayerWeekendDeliveries(citizenId)
    return GetCachedStat(citizenId, "weekend_deliveries", function()
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM supply_deliveries 
            WHERE player_id = ? AND DAYOFWEEK(completed_at) IN (1, 7)
        ]], { citizenId }) or 0
    end)
end

function GetPlayerEmergencyDeliveries(citizenId)
    return GetCachedStat(citizenId, "emergency_deliveries", function()
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM supply_deliveries 
            WHERE player_id = ? AND order_group_id LIKE 'EMRG-%'
        ]], { citizenId }) or 0
    end)
end

function GetPlayerContainerUsage(citizenId)
    return GetCachedStat(citizenId, "container_usage", function()
        return MySQL.scalar.await('SELECT containers_used FROM supply_player_stats WHERE citizenid = ?', { citizenId }) or 0
    end)
end

function GetPlayerCurrentStreak(citizenId)
    return MySQL.scalar.await('SELECT streak FROM supply_driver_stats WHERE citizenid = ?', { citizenId }) or 0
end

function GetCachedStat(citizenId, statType, fetchFunction)
    local cacheKey = citizenId .. "_" .. statType
    local cached = statCache[cacheKey]
    
    if cached and os.time() - cached.time < CACHE_DURATION then
        return cached.value
    end
    
    local value = fetchFunction()
    statCache[cacheKey] = {
        value = value,
        time = os.time()
    }
    
    return value
end

-- Add player experience
function AddPlayerExperience(playerId, amount)
    local citizenId = GetPlayerCitizenId(playerId)
    
    MySQL.Async.execute([[
        INSERT INTO supply_player_stats (citizenid, experience)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE experience = experience + ?
    ]], {
        citizenId,
        amount,
        amount
    })
    
    -- Check for level up
    CheckPlayerLevel(playerId, citizenId)
end

-- Check player level
function CheckPlayerLevel(playerId, citizenId)
    MySQL.Async.fetchAll('SELECT experience, level FROM supply_player_stats WHERE citizenid = ?', 
        { citizenId }, function(results)
        if results[1] then
            local currentXP = results[1].experience
            local currentLevel = results[1].level or 1
            
            -- Check level thresholds
            for _, levelData in ipairs(Config.Rewards.experience.levels) do
                if levelData.level > currentLevel and currentXP >= levelData.xpRequired then
                    -- Level up!
                    MySQL.Async.execute('UPDATE supply_player_stats SET level = ? WHERE citizenid = ?', {
                        levelData.level,
                        citizenId
                    })
                    
                    -- Grant level rewards
                    local rewards = Config.Rewards.experience.levelRewards[levelData.level]
                    if rewards then
                        local player = Framework.GetPlayer(playerId)
                        if player and rewards.cash then
                            Framework.AddMoney(player, 'bank', rewards.cash, 'Level up reward')
                        end
                        
                        -- Give item rewards
                        if rewards.item then
                            exports.ox_inventory:AddItem(playerId, rewards.item, 1)
                        end
                    end
                    
                    -- Notify player
                    TriggerClientEvent("SupplyChain:Client:LevelUp", playerId, {
                        newLevel = levelData.level,
                        title = levelData.title,
                        rewards = rewards
                    })
                    
                    break
                end
            end
        end
    end)
end

-- Utility functions
function GetPlayerCitizenId(playerId)
    local player = Framework.GetPlayer(playerId)
    if player then
        if Framework.Type == 'qbcore' then
            return player.PlayerData.citizenid
        else
            return player.citizenid
        end
    end
    return nil
end

-- Export achievement functions
exports('GetPlayerAchievements', function(citizenId)
    return playerAchievements[citizenId] or {}
end)

exports('UnlockAchievement', function(playerId, achievementId)
    TriggerEvent(Constants.Events.Server.UnlockAchievement, achievementId, playerId)
end)

exports('CheckAchievementProgress', function(playerId, achievementType, value)
    TriggerEvent("SupplyChain:Server:CheckAchievementProgress", playerId, achievementType, value)
end)