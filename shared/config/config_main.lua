-- Unified Configuration System

Config = Config or {}

-- Core Settings
Config.Core = {
    framework = 'qbox',              -- 'qbcore' or 'qbox'
    debug = false,                   -- Enable debug prints
    locale = 'en',                   -- Language setting
    resourceName = GetCurrentResourceName()
}

-- UI Settings
Config.UI = {
    useLationUI = true,              -- Enable lation_ui styling
    theme = "dark",                  -- lation_ui theme (dark, light)
    notificationPosition = "center-right",
    enableMarkdown = true,
    enableSounds = true
}

-- Economic Settings
Config.Economics = {
    enabled = true,
    dynamicPricing = {
        enabled = true,
        minMultiplier = 0.5,         -- Minimum price multiplier
        maxMultiplier = 1.5,         -- Maximum price multiplier
        peakThreshold = 20,          -- Player count for peak pricing
        lowThreshold = 5,            -- Player count for discount
        updateInterval = 300         -- Update frequency (seconds)
    },
    inflationRate = 1.02,            -- Annual inflation rate
    taxRate = 0.15,                  -- Tax on transactions
    bonusMultipliers = {
        speed = 1.5,                 -- Speed delivery bonus
        volume = 1.2,                -- High volume bonus
        quality = 1.3,               -- Quality preservation bonus
        team = 1.25                  -- Team delivery bonus
    }
}

-- Reward Settings
Config.Rewards = {
    driverPaymentPercentage = 0.22,  -- 22% of order value
    minimumDeliveryPay = 50,
    maximumDeliveryPay = 2500,
    basePayPerBox = 25,
    streakBonuses = {
        [5] = 1.1,                   -- 5 deliveries = 10% bonus
        [10] = 1.2,                  -- 10 deliveries = 20% bonus
        [25] = 1.3,                  -- 25 deliveries = 30% bonus
        [50] = 1.5                   -- 50 deliveries = 50% bonus
    },
    teamBonuses = {
        [2] = 1.15,                  -- 2 players = 15% bonus
        [3] = 1.25,                  -- 3 players = 25% bonus
        [4] = 1.35                   -- 4 players = 35% bonus
    }
}

-- Container Settings
Config.Containers = {
    enabled = true,
    types = {
        ["ogz_crate"] = {
            name = "Standard Crate",
            cost = 15,
            capacity = 12,
            qualityDegradation = 2.5,    -- % per hour
            temperatureRange = {min = 15, max = 30}
        },
        ["ogz_cooler"] = {
            name = "Refrigerated Container",
            cost = 25,
            capacity = 10,
            qualityDegradation = 1.5,
            temperatureRange = {min = 2, max = 8}
        },
        ["ogz_freezer"] = {
            name = "Freezer Container",
            cost = 35,
            capacity = 8,
            qualityDegradation = 1.0,
            temperatureRange = {min = -18, max = -10}
        },
        ["ogz_insulated"] = {
            name = "Insulated Container",
            cost = 20,
            capacity = 10,
            qualityDegradation = 2.0,
            temperatureRange = {min = 10, max = 25}
        },
        ["ogz_ventilated"] = {
            name = "Ventilated Container",
            cost = 18,
            capacity = 14,
            qualityDegradation = 2.2,
            temperatureRange = {min = 15, max = 35}
        },
        ["ogz_specialized"] = {
            name = "Specialized Container",
            cost = 45,
            capacity = 6,
            qualityDegradation = 0.5,
            temperatureRange = {min = -25, max = 50}
        }
    },
    qualityThresholds = {
        excellent = 90,
        good = 75,
        fair = 50,
        poor = 25
    }
}

-- Team Settings
Config.Teams = {
    enabled = true,
    maxMembers = 4,                  -- Maximum players per delivery team
    requireProximity = true,         -- Must be near to invite
    proximityDistance = 50.0,        -- Distance for invites
    disbandOnDisconnect = true       -- Disband team if leader disconnects
}

-- Warehouse Settings
Config.Warehouse = {
    stockUpdateInterval = 30,        -- Stock cache update (seconds)
    maxOrdersPerGroup = 10,          -- Max items per order group
    deliveryCooldown = 300,          -- 5 minutes between deliveries
    requiredBoxesPerDelivery = 3,    -- Boxes needed per delivery
    carryBoxProp = 'ng_proc_box_01a',
    vehicleModel = 'speedo',
    jobAccess = {                    -- Jobs that can access warehouse
        'warehouse',
        'trucker',
        'delivery'
    }
}

-- Manufacturing Settings
Config.Manufacturing = {
    enabled = false,                 -- Not yet implemented
    skillProgression = {
        novice = {min = 0, max = 100, bonus = 1.0},
        apprentice = {min = 101, max = 500, bonus = 1.1},
        journeyman = {min = 501, max = 1000, bonus = 1.2},
        expert = {min = 1001, max = 5000, bonus = 1.3},
        master = {min = 5001, max = 99999, bonus = 1.5}
    }
}

-- Docks Settings
Config.Docks = {
    enabled = false,                 -- Not yet implemented
    importSchedule = 48,             -- Hours between shipments
    workerExperience = {
        rookie = {min = 0, max = 50, speed = 1.0},
        experienced = {min = 51, max = 200, speed = 1.2},
        veteran = {min = 201, max = 999999, speed = 1.5}
    }
}

-- Emergency Orders
Config.EmergencyOrders = {
    enabled = true,
    checkInterval = 180,             -- Check every 3 minutes
    triggers = {
        criticalStock = 5,
        urgentStock = 15,
        lowStock = 25
    },
    priorities = {
        critical = {level = 3, timeout = 1800, multiplier = 2.0},
        urgent = {level = 2, timeout = 3600, multiplier = 1.5},
        low = {level = 1, timeout = 7200, multiplier = 1.25}
    }
}

-- Leaderboard Settings
Config.Leaderboard = {
    enabled = true,
    maxEntries = 10,
    updateInterval = 300,            -- Update every 5 minutes
    categories = {
        'deliveries',
        'earnings',
        'streak',
        'teamwork'
    }
}

-- Stock Management
Config.Stock = {
    lowStockThreshold = 25,          -- Alert when below this
    criticalStockThreshold = 10,     -- Critical alert threshold
    maxStockCapacity = 1000,         -- Max items per ingredient
    restockAmount = 100              -- Default restock quantity
}

-- Seller/Distributor Settings
Config.Seller = {
    pedModel = "a_m_m_farmer_01",
    sellProgress = 8000,             -- Time to sell items (ms)
    sellingAnimDict = 'missheistdockssetup1ig_12@idle_b',
    sellingAnimName = 'talk_gantry_idle_b_worker1',
    location = {
        coords = vector3(-86.59, 6494.08, 31.51),
        heading = 221.43
    },
    blip = {
        label = 'Distributor',
        coords = vector3(-88.4297, 6493.5161, 30.1007),
        sprite = 1,
        color = 1,
        scale = 0.6
    }
}

-- Analytics Settings
Config.Analytics = {
    enabled = true,
    trackingInterval = 60,           -- Update stats every minute
    metricsRetention = 7,            -- Days to keep detailed metrics
    performanceAlerts = true         -- Alert on performance issues
}

-- Admin Settings
Config.Admin = {
    commands = {
        menu = 'supplychain',        -- Main admin menu
        stock = 'scstock',           -- Stock management
        economy = 'sceconomy',       -- Economic controls
        emergency = 'scemergency',   -- Emergency orders
        analytics = 'scanalytics'    -- Analytics dashboard
    },
    permissions = {
        'admin',
        'god'
    }
}

-- Debug Settings
Config.Debug = {
    showZones = false,               -- Show interaction zones
    showMarkers = false,             -- Show debug markers
    printEvents = false,             -- Print all events
    logDatabase = false              -- Log database queries
}

-- Export config
exports('GetConfig', function()
    return Config
end)

print("^2[SupplyChain]^7 Configuration system loaded")