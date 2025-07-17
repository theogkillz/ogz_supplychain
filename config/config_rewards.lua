Config = Config or {}

-- ===================================
-- FIXED TEAM DELIVERIES CONFIGURATION  
-- ===================================
Config.TeamDeliveries = {
    minBoxesForTeam = 5,
    maxTeamSize = 4,
    
    teamBonuses = {
        duo = { size = 2, multiplier = 1.25, name = "🤝 Dynamic Duo" },
        squad = { size = 3, multiplier = 1.45, name = "⚡ Power Squad" },
        convoy = { size = 4, multiplier = 1.65, name = "🚛 Epic Convoy" }
    },
    
    coordinationBonuses = {
        perfect_sync = { maxTimeDiff = 30, bonus = 150, name = "🎯 Perfect Sync" },
        close_timing = { maxTimeDiff = 60, bonus = 75, name = "⏰ Close Timing" },
        good_teamwork = { maxTimeDiff = 120, bonus = 35, name = "🤝 Good Teamwork" }
    },
    
    deliveryTypes = {
        split_load = {
            name = "📦 Split Load",
            description = "Each driver takes equal boxes",
            minBoxes = 4
        },
        convoy = {
            name = "🚛 Convoy Delivery", 
            description = "All drivers follow lead vehicle",
            minBoxes = 8
        },
        zone_delivery = {
            name = "🗺️ Zone Delivery",
            description = "Multiple delivery points in sequence",
            minBoxes = 10
        }
    }
}

-- ===================================
-- BALANCED DRIVER REWARDS SYSTEM
-- ===================================
Config.DriverRewards = {
    speedBonuses = {
        lightning = { maxTime = 300, multiplier = 1.4, name = "⚡ Lightning Fast", icon = "⚡" },
        express = { maxTime = 600, multiplier = 1.25, name = "🚀 Express Delivery", icon = "🚀" },
        fast = { maxTime = 900, multiplier = 1.15, name = "⏰ Fast Delivery", icon = "⏰" },
        standard = { maxTime = 1800, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    volumeBonuses = {
        mega = { minBoxes = 15, bonus = 200, name = "🏗️ Mega Haul", icon = "🏗️" },
        large = { minBoxes = 10, bonus = 125, name = "📦 Large Haul", icon = "📦" },
        medium = { minBoxes = 5, bonus = 50, name = "📋 Medium Haul", icon = "📋" },
        small = { minBoxes = 1, bonus = 0, name = "📦 Standard", icon = "📦" }
    },
    
    streakBonuses = {
        legendary = { streak = 20, multiplier = 1.6, name = "👑 Legendary Streak", icon = "👑" },
        master = { streak = 15, multiplier = 1.45, name = "🔥 Master Streak", icon = "🔥" },
        expert = { streak = 10, multiplier = 1.3, name = "⭐ Expert Streak", icon = "⭐" },
        skilled = { streak = 5, multiplier = 1.15, name = "💎 Skilled Streak", icon = "💎" },
        basic = { streak = 0, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    dailyMultipliers = {
        { deliveries = 1, multiplier = 1.0, name = "Getting Started" },
        { deliveries = 3, multiplier = 1.05, name = "Warming Up" },
        { deliveries = 5, multiplier = 1.1, name = "In the Zone" },
        { deliveries = 8, multiplier = 1.15, name = "On Fire" },
        { deliveries = 12, multiplier = 1.2, name = "Unstoppable" },
        { deliveries = 20, multiplier = 1.3, name = "LEGENDARY" }
    },
    
    perfectDelivery = {
        maxTime = 1200,
        noVehicleDamage = true,
        onTimeBonus = 100
    }
}

-- ===================================
-- ACHIEVEMENT REWARDS (BALANCED)
-- ===================================
Config.AchievementRewards = {
    first_delivery = { reward = 150, name = "First Steps" },
    speed_demon = { reward = 300, name = "Speed Demon" },
    big_hauler = { reward = 450, name = "Big Hauler" },
    perfect_week = { reward = 1250, name = "Perfect Week" },
    century_club = { reward = 2500, name = "Century Club" }
}

-- ===================================
-- ACHIEVEMENT VEHICLE SYSTEM
-- ===================================
Config.AchievementVehicles = {
    enabled = true,
    
    performanceTiers = {
        ["rookie"] = {
            name = "Rookie Driver",
            requirement = "Complete 10 deliveries",
            colorTint = {r = 200, g = 200, b = 200},
            performanceMods = {
                [11] = 0, [12] = 0, [13] = 0, [15] = 0, [18] = 0
            },
            speedMultiplier = 1.0,
            accelerationBonus = 0.0,
            fuelEfficiency = 1.0,
            description = "Standard delivery vehicle performance"
        },
        
        ["experienced"] = {
            name = "Experienced Driver", 
            requirement = "Complete 50 deliveries with 80%+ rating",
            colorTint = {r = 50, g = 150, b = 255},
            performanceMods = {
                [11] = 1, [12] = 1, [13] = 1, [15] = 0, [18] = 0
            },
            speedMultiplier = 1.05,
            accelerationBonus = 0.10,
            fuelEfficiency = 1.05,
            description = "Enhanced engine and braking performance"
        },
        
        ["professional"] = {
            name = "Professional Driver",
            requirement = "Complete 150 deliveries with 85%+ rating",
            colorTint = {r = 128, g = 0, b = 128},
            performanceMods = {
                [11] = 2, [12] = 2, [13] = 2, [15] = 1, [18] = 0
            },
            speedMultiplier = 1.10,
            accelerationBonus = 0.15,
            fuelEfficiency = 1.10,
            description = "Professional-grade performance upgrades"
        },
        
        ["elite"] = {
            name = "Elite Driver",
            requirement = "Complete 300 deliveries with 90%+ rating",
            colorTint = {r = 255, g = 215, b = 0},
            performanceMods = {
                [11] = 3, [12] = 2, [13] = 2, [15] = 2, [18] = 1
            },
            speedMultiplier = 1.15,
            accelerationBonus = 0.20,
            fuelEfficiency = 1.15,
            description = "Elite performance with turbo boost"
        },
        
        ["legendary"] = {
            name = "Legendary Driver",
            requirement = "Complete 500 deliveries with 95%+ rating + Team achievements",
            colorTint = {r = 255, g = 0, b = 0},
            performanceMods = {
                [11] = 4, [12] = 3, [13] = 3, [15] = 3, [18] = 1
            },
            speedMultiplier = 1.25,
            accelerationBonus = 0.30,
            fuelEfficiency = 1.25,
            specialEffects = {
                underglow = true,
                customLivery = true,
                hornUpgrade = true
            },
            description = "Maximum performance legendary vehicle"
        }
    },
    
    visualEffects = {
        underglow = {
            enabled = true,
            colors = {
                ["elite"] = {r = 255, g = 215, b = 0},
                ["legendary"] = {r = 255, g = 0, b = 0}
            }
        },
        
        liveries = {
            ["professional"] = 1,
            ["elite"] = 2,
            ["legendary"] = 3
        },
        
        hornSounds = {
            ["elite"] = "HORN_TRUCK_01",
            ["legendary"] = "HORN_TRUCK_02"
        }
    }
}