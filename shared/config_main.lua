Config = Config or {}

Config.Core = 'qbox' -- qbcore or qbox
Config.Inventory = 'ox' -- ox_inventory
Config.Target = 'ox' -- ox_target
Config.Progress = 'ox' -- ox_lib
Config.Notify = 'ox' -- ox_lib
Config.Menu = 'ox' -- ox_lib

Config.UI = {
    notificationPosition = 'center-right',
    enableMarkdown = true,
    theme = 'default'
}

-- Admin Configuration
Config.AdminSystem = {
    -- Admin permission levels
    permissions = {
        superadmin = 'god',      -- Full access
        admin = 'admin',         -- Most features
        moderator = 'mod'        -- Basic monitoring
    },
    
    -- Command configuration
    commands = {
        enabled = true,
        prefix = 'supply',       -- /supply [action]
        chatSuggestions = true
    }
}

-- ===================================
-- JOB RESTRICTIONS
-- ===================================
Config.Jobs = {
    -- Authorized warehouse jobs
    warehouse = {"hurst", "admin", "god"},  -- Hurst Industries + admin access
    
    -- Future expansion capability
    delivery = {"hurst", "admin", "god"},   -- Can add more jobs here later
    management = {"admin", "god"}           -- Admin/management only features
}

-- Notification Configuration
Config.Notifications = {
    discord = {
        enabled = false,
        webhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE", -- Replace with your webhook
        botName = "Supply Chain AI",
        botAvatar = "https://i.imgur.com/your_bot_avatar.png",
        
        -- Channel configuration
        channels = {
            market_events = "YOUR_MARKET_WEBHOOK_URL",
            emergency_orders = "YOUR_EMERGENCY_WEBHOOK_URL", 
            achievements = "YOUR_ACHIEVEMENTS_WEBHOOK_URL",
            system_alerts = "YOUR_SYSTEM_WEBHOOK_URL"
        }
    },
    
    phone = {
        enabled = true,
        resource = "lb-phone", -- Change to your phone resource
        
        -- Notification types
        types = {
            new_orders = true,
            emergency_alerts = true,
            market_changes = true,
            team_invites = true,
            achievement_unlocked = true,
            stock_alerts = true
        }
    }
}

Config.Leaderboard = {
    enabled = true,
    maxEntries = 10 -- Number of leaderboard entries to show
}

Config.LowStock = {
    enabled = true,
    threshold = 25 -- Notify when stock is below this
}

Config.maxBoxes = 6 -- Max boxes for team deliveries (2 players)
Config.DriverPayPrec = 0.22 -- Driver payment percentage

-- ===================================
-- DELIVERY PROPS CONFIGURATION
-- ===================================
Config.DeliveryProps = {
    boxProp = "ng_proc_box_01a",              -- Individual box prop
    palletProp = "prop_boxpile_06b",          -- Stacked box pallet prop
    palletOffset = vector3(0, 0, 0),          -- Pallet positioning offset
    deliveryMarker = {
        type = 1,                             -- Marker type (cylinder)
        size = vector3(3.0, 3.0, 1.0),       -- Marker size
        color = {r = 0, g = 255, b = 0, a = 100}, -- Green with transparency
        bobUpAndDown = false,
        faceCamera = false,
        rotate = true
    }
}

-- Maintain backward compatibility
Config.CarryBoxProp = Config.DeliveryProps.boxProp

-- ===================================
-- VEHICLE CONFIGURATION
-- ===================================
Config.VehicleSelection = {
    -- Small deliveries (1-3 boxes)
    small = {
        maxBoxes = 3,
        models = {"speedo"},
        spawnChance = 1.0
    },
    
    -- Medium deliveries (4-7 boxes)  
    medium = {
        maxBoxes = 7,
        models = {"speedo", "mule"},
        spawnChance = 0.8
    },
    
    -- Large deliveries (8+ boxes)
    large = {
        maxBoxes = 15,
        models = {"mule", "pounder"},
        spawnChance = 1.0
    }
}

-- ===================================
-- CONTAINER SYSTEM CONFIGURATION
-- ===================================
Config.ContainerSystem = {
    itemsPerContainer = 12,        -- Items that fit in one container
    containersPerBox = 5,          -- Containers that fit in one delivery box
    maxBoxesPerDelivery = 10       -- Maximum boxes per delivery van
}

-- Calculated values (don't modify)
Config.ItemsPerBox = Config.ContainerSystem.itemsPerContainer * Config.ContainerSystem.containersPerBox -- 60 items per box

-- ===================================
-- DYNAMIC PRICING CONFIGURATION
-- ===================================
Config.DynamicPricing = {
    enabled = true,
    peakThreshold = 20,      -- Player count for peak pricing
    lowThreshold = 5,        -- Player count for low pricing
    minMultiplier = 0.8,     -- Minimum price multiplier
    maxMultiplier = 1.5      -- Maximum price multiplier
}

-- ===================================
-- BALANCED ECONOMY CONFIGURATION
-- ===================================

-- DELIVERY BASE PAY CALCULATION
Config.EconomyBalance = {
    -- Base pay per box (reasonable starting point)
    basePayPerBox = 75,          -- $75 per box
    minimumDeliveryPay = 200,    -- Minimum $200 per delivery
    maximumDeliveryPay = 2500,   -- Maximum $2500 per delivery (prevents exploits)
    
    -- Distance multipliers (if you want to add distance-based pay)
    distanceBonus = {
        enabled = false,         -- Disabled for now
        perKm = 5               -- $5 per km
    }
}

-- ===================================
-- FIXED TEAM DELIVERIES CONFIGURATION  
-- ===================================
Config.TeamDeliveries = {
    minBoxesForTeam = 5,
    maxTeamSize = 4,
    
    -- FIXED team bonuses (were broken before)
    teamBonuses = {
        duo = { size = 2, multiplier = 1.25, name = "🤝 Dynamic Duo" },      -- Was 0.6 (BROKEN!)
        squad = { size = 3, multiplier = 1.45, name = "⚡ Power Squad" },    -- Reasonable bonus
        convoy = { size = 4, multiplier = 1.65, name = "🚛 Epic Convoy" }    -- Good but not excessive
    },
    
    -- Coordination bonuses (flat amounts, not multipliers)
    coordinationBonuses = {
        perfect_sync = { maxTimeDiff = 30, bonus = 150, name = "🎯 Perfect Sync" },    -- Was 1000!
        close_timing = { maxTimeDiff = 60, bonus = 75, name = "⏰ Close Timing" },     -- Was 500!
        good_teamwork = { maxTimeDiff = 120, bonus = 35, name = "🤝 Good Teamwork" }   -- Was 250!
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
    -- CONSERVATIVE Speed Bonuses (was way too high)
    speedBonuses = {
        lightning = { maxTime = 300, multiplier = 1.4, name = "⚡ Lightning Fast", icon = "⚡" },    -- Was 2.5x!
        express = { maxTime = 600, multiplier = 1.25, name = "🚀 Express Delivery", icon = "🚀" },  -- Was 2.0x!
        fast = { maxTime = 900, multiplier = 1.15, name = "⏰ Fast Delivery", icon = "⏰" },        -- Was 1.5x!
        standard = { maxTime = 1800, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    -- SMALLER Volume Bonuses (flat amounts)
    volumeBonuses = {
        mega = { minBoxes = 15, bonus = 200, name = "🏗️ Mega Haul", icon = "🏗️" },     -- Was 5000!
        large = { minBoxes = 10, bonus = 125, name = "📦 Large Haul", icon = "📦" },    -- Was 2500!
        medium = { minBoxes = 5, bonus = 50, name = "📋 Medium Haul", icon = "📋" },    -- Was 1000!
        small = { minBoxes = 1, bonus = 0, name = "📦 Standard", icon = "📦" }
    },
    
    -- REASONABLE Streak Bonuses (was way too high)
    streakBonuses = {
        legendary = { streak = 20, multiplier = 1.6, name = "👑 Legendary Streak", icon = "👑" },  -- Was 3.0x!
        master = { streak = 15, multiplier = 1.45, name = "🔥 Master Streak", icon = "🔥" },       -- Was 2.5x!
        expert = { streak = 10, multiplier = 1.3, name = "⭐ Expert Streak", icon = "⭐" },        -- Was 2.0x!
        skilled = { streak = 5, multiplier = 1.15, name = "💎 Skilled Streak", icon = "💎" },     -- Was 1.5x!
        basic = { streak = 0, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    -- CONSERVATIVE Daily Multipliers
    dailyMultipliers = {
        { deliveries = 1, multiplier = 1.0, name = "Getting Started" },
        { deliveries = 3, multiplier = 1.05, name = "Warming Up" },        -- Was 1.1x
        { deliveries = 5, multiplier = 1.1, name = "In the Zone" },        -- Was 1.2x
        { deliveries = 8, multiplier = 1.15, name = "On Fire" },           -- Was 1.3x
        { deliveries = 12, multiplier = 1.2, name = "Unstoppable" },       -- Was 1.5x
        { deliveries = 20, multiplier = 1.3, name = "LEGENDARY" }          -- Was 2.0x!
    },
    
    -- Perfect Delivery Criteria
    perfectDelivery = {
        maxTime = 1200,           -- Under 20 minutes
        noVehicleDamage = true,   -- Van must be in good condition
        onTimeBonus = 100         -- Was 500! Now reasonable
    }
}

-- ===================================
-- ACHIEVEMENT REWARDS (BALANCED)
-- ===================================
Config.AchievementRewards = {
    first_delivery = { reward = 150, name = "First Steps" },       -- Was 500
    speed_demon = { reward = 300, name = "Speed Demon" },          -- Was 1000  
    big_hauler = { reward = 450, name = "Big Hauler" },            -- Was 1500
    perfect_week = { reward = 1250, name = "Perfect Week" },       -- Was 5000
    century_club = { reward = 2500, name = "Century Club" }        -- Was 10000
}

-- ===================================
-- ECONOMY MATH EXAMPLES
-- ===================================
--[[
EXAMPLE CALCULATIONS (Balanced System):

SMALL DELIVERY (3 boxes):
Base: 3 × $75 = $225
Speed Bonus (fast): $225 × 1.15 = $259
Volume Bonus: +$0 (under 5 boxes)
Daily Bonus (5th delivery): $259 × 1.1 = $285
Streak Bonus (10 streak): $285 × 1.3 = $371
Perfect Delivery: +$100
TOTAL: $471 ✅ Reasonable!

LARGE DELIVERY (12 boxes):
Base: 12 × $75 = $900
Speed Bonus (express): $900 × 1.25 = $1,125
Volume Bonus: +$125 (large haul)
Daily Bonus (20th delivery): $1,125 × 1.3 = $1,463
Streak Bonus (20 streak): $1,463 × 1.6 = $2,341
Perfect Delivery: +$100
Volume Bonus: +$125
TOTAL: $2,566 ✅ High but reasonable for massive perfect delivery!

TEAM DELIVERY (4 people, 16 boxes total, 4 each):
Individual Base: 4 × $75 = $300
Team Multiplier: $300 × 1.65 = $495
Coordination Bonus: +$150 (perfect sync)
Other bonuses apply individually
TOTAL PER PERSON: ~$800-1200 depending on performance ✅

OLD SYSTEM COMPARISON:
Same large delivery under old system:
$900 × 2.5 × 3.0 × 2.0 + 5000 + 500 = $18,000+ 💸 MONEY PRINTER!
]]--

-- ===================================
-- STOCK ALERTS CONFIGURATION
-- ===================================
Config.StockAlerts = {
    -- Alert thresholds (percentage of maximum stock)
    thresholds = {
        critical = 5,    -- Red alerts - Urgent action needed
        low = 20,        -- Yellow alerts - Restock soon
        moderate = 50,   -- Blue alerts - Plan ahead
        healthy = 80     -- Green - Good stock levels
    },
    
    -- Maximum recommended stock levels per item
    maxStock = {
        default = 500,           -- Default max stock
        high_demand = 1000,      -- Popular items
        seasonal = 200,          -- Seasonal items
        specialty = 100          -- Rare/expensive items
    },
    
    -- Prediction settings
    prediction = {
        analysisWindow = 7,      -- Days to analyze for patterns
        forecastDays = 3,        -- Days to predict ahead
        minDataPoints = 5,       -- Minimum orders needed for prediction
        confidenceThreshold = 0.7 -- Minimum confidence for predictions
    },
    
    -- Notification settings
    notifications = {
        checkInterval = 300,     -- Check every 5 minutes
        alertCooldown = 1800,    -- Don't spam same alert for 30 minutes
        maxAlertsPerCheck = 5    -- Max alerts per check cycle
    }
}

-- Market Configuration
Config.MarketPricing = {
    -- Enable/disable dynamic pricing
    enabled = true,
    
    -- Base pricing factors
    factors = {
        stockLevel = {
            enabled = true,
            weight = 0.4,           -- 40% of price calculation
            criticalMultiplier = 2.5, -- 5% stock = 2.5x price
            lowMultiplier = 1.8,      -- 20% stock = 1.8x price
            moderateMultiplier = 1.3, -- 50% stock = 1.3x price
            healthyMultiplier = 1.0   -- 80%+ stock = normal price
        },
        
        demand = {
            enabled = true,
            weight = 0.3,           -- 30% of price calculation
            analysisWindow = 6,     -- Hours to analyze demand
            highDemandMultiplier = 1.5,
            normalDemandMultiplier = 1.0,
            lowDemandMultiplier = 0.9
        },
        
        playerActivity = {
            enabled = true,
            weight = 0.2,           -- 20% of price calculation
            peakThreshold = 25,     -- 25+ players = peak pricing
            moderateThreshold = 15, -- 15+ players = moderate pricing
            lowThreshold = 5,       -- 5+ players = low pricing
            peakMultiplier = 1.3,
            moderateMultiplier = 1.1,
            lowMultiplier = 0.9
        },
        
        timeOfDay = {
            enabled = true,
            weight = 0.1,           -- 10% of price calculation
            peakHours = {19, 20, 21, 22}, -- 7PM-10PM peak hours
            moderateHours = {16, 17, 18, 23}, -- 4PM-6PM, 11PM moderate
            peakMultiplier = 1.2,
            moderateMultiplier = 1.05,
            offPeakMultiplier = 0.95
        }
    },
    
    -- Price limits
    limits = {
        minMultiplier = 0.7,    -- Never go below 70% of base price
        maxMultiplier = 3.0,    -- Never go above 300% of base price
        maxChangePerUpdate = 0.1 -- Max 10% change per update cycle
    },
    
    -- Update intervals
    intervals = {
        priceUpdate = 300,      -- Update prices every 5 minutes
        marketSnapshot = 1800,  -- Save market snapshot every 30 minutes
        demandAnalysis = 3600   -- Analyze demand every hour
    },
    
    -- Special events (temporary price modifications)
    events = {
        shortage = {
            enabled = true,
            threshold = 3,      -- Items with <3% stock
            multiplier = 2.0,   -- 2x base multiplier
            duration = 3600     -- 1 hour duration
        },
        surplus = {
            enabled = true,
            threshold = 95,     -- Items with >95% stock
            multiplier = 0.8,   -- 20% discount
            duration = 1800     -- 30 minute duration
        }
    }
}

-- Emergency Order Configuration
Config.EmergencyOrders = {
    enabled = true,
    
    -- Trigger conditions
    triggers = {
        restaurantStockout = 0,     -- Restaurant completely out
        warehouseStockout = 0,      -- Warehouse completely out
        criticalStock = 5,          -- Under 5 units total
        highDemandShortage = 10     -- High demand + low stock
    },
    
    -- Emergency bonuses
    bonuses = {
        emergencyMultiplier = 0.5,  -- 2.5x base delivery pay
        urgentMultiplier = 0.2,     -- 2x for urgent
        criticalMultiplier = 0.7,   -- 3x for critical
        speedBonus = 75,          -- +$1000 for under 10 min delivery
        heroBonus = 120            -- +$2000 for preventing complete stockout
    },
    
    -- Priority levels
    priorities = {
        critical = {
            level = 3,
            name = "🚨 CRITICAL",
            color = "error",
            timeout = 1800,  -- 30 minutes
            broadcastToAll = true
        },
        urgent = {
            level = 2, 
            name = "⚠️ URGENT",
            color = "warning",
            timeout = 3600,  -- 1 hour
            broadcastToAll = false
        },
        emergency = {
            level = 1,
            name = "🔥 EMERGENCY",
            color = "info", 
            timeout = 7200,  -- 2 hours
            broadcastToAll = false
        }
    }
}