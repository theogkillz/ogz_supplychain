-- Reward System Configuration

Config = Config or {}

Config.Rewards = {
    -- Delivery Rewards
    delivery = {
        base = {
            minimumPay = 50,
            maximumPay = 2500,
            perBoxAmount = 25,
            distanceBonus = 0.15,        -- Per meter
            fuelCompensation = 15
        },
        
        -- Speed Bonuses
        speedBonuses = {
            enabled = true,
            thresholds = {
                { time = 300, bonus = 500, multiplier = 1.5 },    -- Under 5 minutes
                { time = 600, bonus = 250, multiplier = 1.25 },   -- Under 10 minutes
                { time = 900, bonus = 100, multiplier = 1.1 }     -- Under 15 minutes
            }
        },
        
        -- Volume Bonuses
        volumeBonuses = {
            enabled = true,
            thresholds = {
                { boxes = 5, bonus = 100, multiplier = 1.1 },
                { boxes = 10, bonus = 250, multiplier = 1.2 },
                { boxes = 20, bonus = 500, multiplier = 1.3 },
                { boxes = 50, bonus = 1000, multiplier = 1.5 }
            }
        },
        
        -- Streak System
        streakBonuses = {
            enabled = true,
            resetTime = 3600,    -- Reset after 1 hour of inactivity
            bonuses = {
                { deliveries = 3, bonus = 50, multiplier = 1.05 },
                { deliveries = 5, bonus = 100, multiplier = 1.1 },
                { deliveries = 10, bonus = 250, multiplier = 1.2 },
                { deliveries = 25, bonus = 500, multiplier = 1.3 },
                { deliveries = 50, bonus = 1000, multiplier = 1.5 },
                { deliveries = 100, bonus = 2500, multiplier = 2.0 }
            }
        },
        
        -- Team Bonuses
        teamBonuses = {
            enabled = true,
            bonuses = {
                { members = 2, bonus = 150, multiplier = 1.15 },
                { members = 3, bonus = 300, multiplier = 1.25 },
                { members = 4, bonus = 500, multiplier = 1.35 }
            },
            splitMethod = "equal",    -- "equal", "contribution", or "leader"
            leaderBonus = 0.1        -- 10% extra for team leader
        },
        
        -- Quality Bonuses (Container System)
        qualityBonuses = {
            enabled = true,
            thresholds = {
                { quality = 95, name = "Perfect", bonus = 500, multiplier = 1.5 },
                { quality = 90, name = "Excellent", bonus = 250, multiplier = 1.3 },
                { quality = 75, name = "Good", bonus = 100, multiplier = 1.15 },
                { quality = 50, name = "Fair", bonus = 0, multiplier = 1.0 },
                { quality = 25, name = "Poor", bonus = -100, multiplier = 0.5 }
            }
        },
        
        -- Emergency Delivery Bonuses
        emergencyBonuses = {
            enabled = true,
            multipliers = {
                critical = 2.0,    -- Critical emergency
                urgent = 1.5,      -- Urgent delivery
                priority = 1.25    -- Priority delivery
            },
            heroBonus = 1000      -- Preventing stockout
        }
    },
    
    -- Manufacturing Rewards
    manufacturing = {
        perItemCrafted = 10,
        qualityBonuses = {
            premium = 1.5,
            standard = 1.0,
            budget = 0.75
        },
        skillBonuses = {
            novice = 1.0,
            apprentice = 1.1,
            journeyman = 1.2,
            expert = 1.3,
            master = 1.5
        },
        bulkBonuses = {
            { amount = 10, multiplier = 1.1 },
            { amount = 50, multiplier = 1.2 },
            { amount = 100, multiplier = 1.3 },
            { amount = 500, multiplier = 1.5 }
        }
    },
    
    -- Dock Worker Rewards
    dockWorker = {
        perContainerProcessed = 75,
        importBonuses = {
            standard = 1.0,
            priority = 1.25,
            express = 1.5,
            overnight = 2.0
        },
        experienceBonuses = {
            rookie = 1.0,
            experienced = 1.2,
            veteran = 1.5,
            supervisor = 2.0
        },
        shiftBonuses = {
            day = 1.0,
            evening = 1.1,
            night = 1.25,
            weekend = 1.5
        }
    },
    
    -- Achievement Rewards
    achievements = {
        -- Delivery Achievements
        delivery = {
            { id = "first_delivery", name = "First Steps", reward = 100, xp = 10 },
            { id = "delivery_10", name = "Regular Driver", reward = 250, xp = 25 },
            { id = "delivery_50", name = "Experienced Driver", reward = 500, xp = 50 },
            { id = "delivery_100", name = "Professional Driver", reward = 1000, xp = 100 },
            { id = "delivery_500", name = "Elite Driver", reward = 5000, xp = 500 },
            { id = "delivery_1000", name = "Legendary Driver", reward = 10000, xp = 1000 }
        },
        
        -- Speed Achievements
        speed = {
            { id = "speed_demon", name = "Speed Demon", condition = "5min_delivery", reward = 500, xp = 50 },
            { id = "lightning_fast", name = "Lightning Fast", condition = "3min_delivery", reward = 1000, xp = 100 },
            { id = "time_traveler", name = "Time Traveler", condition = "2min_delivery", reward = 2500, xp = 250 }
        },
        
        -- Team Achievements
        team = {
            { id = "team_player", name = "Team Player", condition = "10_team_deliveries", reward = 500, xp = 50 },
            { id = "squad_goals", name = "Squad Goals", condition = "50_team_deliveries", reward = 2500, xp = 250 },
            { id = "dream_team", name = "Dream Team", condition = "100_team_deliveries", reward = 5000, xp = 500 }
        },
        
        -- Quality Achievements
        quality = {
            { id = "quality_control", name = "Quality Control", condition = "10_perfect_deliveries", reward = 1000, xp = 100 },
            { id = "perfectionist", name = "Perfectionist", condition = "50_perfect_deliveries", reward = 5000, xp = 500 },
            { id = "zero_damage", name = "Zero Damage", condition = "100_perfect_deliveries", reward = 10000, xp = 1000 }
        },
        
        -- Special Achievements
        special = {
            { id = "night_owl", name = "Night Owl", condition = "50_night_deliveries", reward = 1000, xp = 100 },
            { id = "early_bird", name = "Early Bird", condition = "50_morning_deliveries", reward = 1000, xp = 100 },
            { id = "weekend_warrior", name = "Weekend Warrior", condition = "100_weekend_deliveries", reward = 2500, xp = 250 },
            { id = "emergency_hero", name = "Emergency Hero", condition = "25_emergency_deliveries", reward = 5000, xp = 500 }
        }
    },
    
    -- Penalties
    penalties = {
        -- Damage Penalties
        damage = {
            enabled = true,
            perIncident = 50,
            qualityThresholds = {
                { quality = 75, penalty = 0 },      -- No penalty above 75%
                { quality = 50, penalty = 100 },
                { quality = 25, penalty = 250 },
                { quality = 0, penalty = 500 }
            },
            maxPenalty = 1000
        },
        
        -- Late Delivery Penalties
        lateDelivery = {
            enabled = true,
            graceTime = 1800,        -- 30 minutes grace period
            perMinuteLate = 5,
            maxPenalty = 500
        },
        
        -- Cancelled Order Penalties
        cancellation = {
            enabled = true,
            penalty = 100,
            cooldown = 600,          -- 10 minute cooldown
            repeatOffenderMultiplier = 2.0
        },
        
        -- Vehicle Damage
        vehicleDamage = {
            enabled = true,
            thresholds = {
                { damage = 900, penalty = 0 },      -- No penalty above 900 health
                { damage = 700, penalty = 100 },
                { damage = 500, penalty = 250 },
                { damage = 300, penalty = 500 },
                { damage = 0, penalty = 1000 }
            }
        }
    },
    
    -- XP System
    experience = {
        enabled = true,
        
        -- XP Gains
        gains = {
            delivery = 10,
            perfectDelivery = 25,
            teamDelivery = 15,
            emergencyDelivery = 50,
            manufacturing = 5,
            dockWork = 8
        },
        
        -- Levels
        levels = {
            { level = 1, xpRequired = 0, title = "Rookie" },
            { level = 5, xpRequired = 100, title = "Beginner" },
            { level = 10, xpRequired = 500, title = "Intermediate" },
            { level = 20, xpRequired = 2000, title = "Advanced" },
            { level = 30, xpRequired = 5000, title = "Expert" },
            { level = 40, xpRequired = 10000, title = "Master" },
            { level = 50, xpRequired = 20000, title = "Legend" }
        },
        
        -- Level Rewards
        levelRewards = {
            [5] = { cash = 500, item = "delivery_uniform" },
            [10] = { cash = 1000, item = "premium_container" },
            [20] = { cash = 2500, item = "speed_boost" },
            [30] = { cash = 5000, item = "quality_scanner" },
            [40] = { cash = 10000, item = "elite_vehicle" },
            [50] = { cash = 25000, item = "legendary_badge" }
        }
    }
}

-- Helper Functions
function Config.Rewards.CalculateDeliveryReward(baseAmount, modifiers)
    local total = baseAmount
    
    -- Apply all modifiers
    if modifiers.speed then
        total = total * modifiers.speed
    end
    
    if modifiers.volume then
        total = total * modifiers.volume
    end
    
    if modifiers.streak then
        total = total * modifiers.streak
    end
    
    if modifiers.team then
        total = total * modifiers.team
    end
    
    if modifiers.quality then
        total = total * modifiers.quality
    end
    
    if modifiers.emergency then
        total = total * modifiers.emergency
    end
    
    -- Apply min/max limits
    total = math.max(Config.Rewards.delivery.base.minimumPay, total)
    total = math.min(Config.Rewards.delivery.base.maximumPay, total)
    
    return math.floor(total)
end

function Config.Rewards.GetStreakMultiplier(deliveryCount)
    if not Config.Rewards.delivery.streakBonuses.enabled then
        return 1.0
    end
    
    local multiplier = 1.0
    for _, bonus in ipairs(Config.Rewards.delivery.streakBonuses.bonuses) do
        if deliveryCount >= bonus.deliveries then
            multiplier = bonus.multiplier
        end
    end
    
    return multiplier
end

function Config.Rewards.GetQualityMultiplier(quality)
    if not Config.Rewards.delivery.qualityBonuses.enabled then
        return 1.0
    end
    
    for _, threshold in ipairs(Config.Rewards.delivery.qualityBonuses.thresholds) do
        if quality >= threshold.quality then
            return threshold.multiplier
        end
    end
    
    return 0.5 -- Default poor quality
end

print("^2[SupplyChain]^7 Rewards configuration loaded")