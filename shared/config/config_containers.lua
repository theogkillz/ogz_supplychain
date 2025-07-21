-- Container System Configuration

Config = Config or {}

Config.Containers = {
    enabled = true,
    
    -- Container Types
    types = {
        ["ogz_crate"] = {
            name = "Standard Crate",
            model = "prop_boxpile_07d",
            cost = 15,
            deposit = 50,
            capacity = 12,
            weight = 5000,
            
            -- Temperature Settings
            temperature = {
                ideal = { min = 15, max = 30 },
                acceptable = { min = 10, max = 35 },
                critical = { min = 5, max = 40 }
            },
            
            -- Quality Degradation
            degradation = {
                baseRate = 2.5,              -- % per hour
                temperatureMultiplier = 1.5,  -- Applied when outside ideal range
                movementMultiplier = 1.2,     -- Applied during transport
                stackingMultiplier = 0.8      -- Reduced degradation when properly stacked
            },
            
            -- Compatible Items
            compatibleItems = {
                "all_dry_goods",
                "packaged_items",
                "non_perishables"
            },
            
            -- Visual Settings
            appearance = {
                clean = { dirt = 0.0, damage = 0.0 },
                used = { dirt = 0.3, damage = 0.1 },
                damaged = { dirt = 0.6, damage = 0.5 }
            }
        },
        
        ["ogz_cooler"] = {
            name = "Refrigerated Container",
            model = "prop_box_ammo03a",
            cost = 25,
            deposit = 100,
            capacity = 10,
            weight = 4000,
            
            temperature = {
                ideal = { min = 2, max = 8 },
                acceptable = { min = 0, max = 10 },
                critical = { min = -2, max = 15 }
            },
            
            degradation = {
                baseRate = 1.5,
                temperatureMultiplier = 2.0,  -- More sensitive to temperature
                movementMultiplier = 1.1,
                stackingMultiplier = 0.9,
                powerRequired = true,         -- Needs power to maintain temp
                powerDrainRate = 5            -- Units per hour
            },
            
            compatibleItems = {
                "dairy_products",
                "fresh_produce",
                "prepared_foods",
                "beverages"
            },
            
            features = {
                temperatureMonitor = true,
                alarmSystem = true,
                batteryBackup = 4             -- Hours of backup power
            }
        },
        
        ["ogz_freezer"] = {
            name = "Freezer Container",
            model = "prop_box_ammo04a",
            cost = 35,
            deposit = 150,
            capacity = 8,
            weight = 3500,
            
            temperature = {
                ideal = { min = -18, max = -10 },
                acceptable = { min = -22, max = -5 },
                critical = { min = -25, max = 0 }
            },
            
            degradation = {
                baseRate = 1.0,
                temperatureMultiplier = 3.0,  -- Very sensitive to temperature
                movementMultiplier = 1.0,
                stackingMultiplier = 1.0,
                powerRequired = true,
                powerDrainRate = 8
            },
            
            compatibleItems = {
                "frozen_foods",
                "ice_cream",
                "frozen_meat",
                "frozen_vegetables"
            },
            
            features = {
                temperatureMonitor = true,
                alarmSystem = true,
                batteryBackup = 2,
                quickFreeze = true
            }
        },
        
        ["ogz_insulated"] = {
            name = "Insulated Container",
            model = "prop_box_tea01a",
            cost = 20,
            deposit = 75,
            capacity = 10,
            weight = 4500,
            
            temperature = {
                ideal = { min = 10, max = 25 },
                acceptable = { min = 5, max = 30 },
                critical = { min = 0, max = 40 }
            },
            
            degradation = {
                baseRate = 2.0,
                temperatureMultiplier = 1.0,  -- Good insulation
                movementMultiplier = 1.1,
                stackingMultiplier = 0.85
            },
            
            compatibleItems = {
                "temperature_sensitive",
                "electronics",
                "chemicals",
                "medicine"
            },
            
            features = {
                shockAbsorption = true,
                moistureControl = true
            }
        },
        
        ["ogz_ventilated"] = {
            name = "Ventilated Container",
            model = "prop_fruitstand_01",
            cost = 18,
            deposit = 60,
            capacity = 14,
            weight = 5500,
            
            temperature = {
                ideal = { min = 15, max = 35 },
                acceptable = { min = 10, max = 40 },
                critical = { min = 5, max = 45 }
            },
            
            degradation = {
                baseRate = 2.2,
                temperatureMultiplier = 1.2,
                movementMultiplier = 1.3,
                stackingMultiplier = 0.7,     -- Better for produce
                airflowBonus = 0.8            -- Reduces degradation
            },
            
            compatibleItems = {
                "fresh_produce",
                "live_plants",
                "bread_products",
                "bulk_grains"
            },
            
            features = {
                airCirculation = true,
                humidityControl = true,
                pestControl = true
            }
        },
        
        ["ogz_specialized"] = {
            name = "Specialized Container",
            model = "prop_box_guncase_01a",
            cost = 45,
            deposit = 200,
            capacity = 6,
            weight = 3000,
            
            temperature = {
                ideal = { min = -25, max = 50 },
                acceptable = { min = -30, max = 60 },
                critical = { min = -40, max = 70 }
            },
            
            degradation = {
                baseRate = 0.5,               -- Minimal degradation
                temperatureMultiplier = 0.5,   -- Highly resistant
                movementMultiplier = 0.8,
                stackingMultiplier = 1.0,
                requiresSpecialHandling = true
            },
            
            compatibleItems = {
                "hazardous_materials",
                "fragile_items",
                "high_value_goods",
                "medical_supplies"
            },
            
            features = {
                temperatureControl = true,
                shockAbsorption = true,
                securityLock = true,
                gpsTracking = true,
                customClimate = true
            }
        }
    },
    
    -- Quality System
    quality = {
        -- Quality Thresholds
        thresholds = {
            perfect = { min = 95, name = "Perfect", color = "green" },
            excellent = { min = 90, name = "Excellent", color = "lime" },
            good = { min = 75, name = "Good", color = "yellow" },
            fair = { min = 50, name = "Fair", color = "orange" },
            poor = { min = 25, name = "Poor", color = "red" },
            damaged = { min = 0, name = "Damaged", color = "darkred" }
        },
        
        -- Factors Affecting Quality
        factors = {
            temperature = {
                weight = 0.4,
                degradationRate = 5          -- % per hour outside ideal range
            },
            handling = {
                weight = 0.3,
                dropPenalty = 10,            -- % per drop
                roughHandlingPenalty = 5      -- % per incident
            },
            time = {
                weight = 0.2,
                baseDecay = 1                -- % per hour
            },
            environment = {
                weight = 0.1,
                rainPenalty = 2,
                extremeHeatPenalty = 3,
                extremeColdPenalty = 3
            }
        }
    },
    
    -- Temperature Monitoring
    temperatureMonitoring = {
        enabled = true,
        updateInterval = 60,                 -- Check every minute
        
        -- Breach Alerts
        breachAlerts = {
            minor = {
                deviation = 2,               -- Degrees from acceptable
                notification = "warning"
            },
            major = {
                deviation = 5,               -- Degrees from acceptable
                notification = "error"
            },
            critical = {
                deviation = 10,              -- Degrees from acceptable
                notification = "critical"
            }
        },
        
        -- Environmental Effects
        environmentalEffects = {
            sunny = { modifier = 2 },
            cloudy = { modifier = 0 },
            rain = { modifier = -1 },
            thunder = { modifier = -2 },
            snow = { modifier = -3 },
            blizzard = { modifier = -5 }
        }
    },
    
    -- Container Tracking
    tracking = {
        enabled = true,
        
        -- GPS Tracking
        gps = {
            updateInterval = 30,             -- Seconds
            batteryLife = 72,                -- Hours
            accuracy = 5                     -- Meters
        },
        
        -- History Logging
        history = {
            maxEntries = 100,
            logEvents = {
                "created",
                "loaded",
                "unloaded",
                "temperature_breach",
                "quality_change",
                "damage_incident",
                "delivered",
                "returned"
            }
        }
    },
    
    -- Container Maintenance
    maintenance = {
        enabled = true,
        
        -- Cleaning
        cleaning = {
            cost = 25,
            time = 300,                      -- Seconds
            qualityRestore = 10              -- % quality restored
        },
        
        -- Repair
        repair = {
            costPerPercent = 5,              -- $ per % of damage
            time = 600,                      -- Base seconds
            minQuality = 50                  -- Minimum quality after repair
        },
        
        -- Inspection
        inspection = {
            cost = 10,
            time = 120,
            interval = 168                   -- Hours between required inspections
        }
    },
    
    -- Physics Settings
    physics = {
        -- Weight affects vehicle handling
        weightMultiplier = 1.2,
        
        -- Stacking
        maxStackHeight = 3,
        stabilityDecrease = 0.8,             -- Per level of stacking
        
        -- Collision
        collisionDamage = {
            low = { speed = 10, damage = 5 },
            medium = { speed = 20, damage = 15 },
            high = { speed = 30, damage = 30 },
            extreme = { speed = 50, damage = 50 }
        }
    },
    
    -- Rental System
    rental = {
        enabled = true,
        
        -- Pricing
        hourlyRates = {
            ogz_crate = 5,
            ogz_cooler = 8,
            ogz_freezer = 12,
            ogz_insulated = 7,
            ogz_ventilated = 6,
            ogz_specialized = 20
        },
        
        -- Discounts
        bulkDiscounts = {
            { containers = 5, discount = 0.05 },
            { containers = 10, discount = 0.10 },
            { containers = 25, discount = 0.15 },
            { containers = 50, discount = 0.20 }
        },
        
        -- Late Fees
        lateFees = {
            graceTime = 900,                 -- 15 minutes grace
            feePerHour = 10,
            maxFee = 200
        }
    }
}

-- Helper Functions
function Config.Containers.GetContainerByType(containerType)
    return Config.Containers.types[containerType]
end

function Config.Containers.CalculateQualityLoss(containerType, currentQuality, conditions)
    local container = Config.Containers.types[containerType]
    if not container then return 0 end
    
    local degradation = container.degradation.baseRate
    
    -- Apply condition multipliers
    if conditions.outsideTemperature then
        degradation = degradation * container.degradation.temperatureMultiplier
    end
    
    if conditions.inTransport then
        degradation = degradation * container.degradation.movementMultiplier
    end
    
    if conditions.properlyStacked then
        degradation = degradation * container.degradation.stackingMultiplier
    end
    
    -- Calculate time-based loss
    local timeFactor = (conditions.timeElapsed or 3600) / 3600 -- Convert to hours
    local qualityLoss = degradation * timeFactor
    
    return math.min(qualityLoss, currentQuality)
end

function Config.Containers.GetQualityStatus(quality)
    for _, threshold in pairs(Config.Containers.quality.thresholds) do
        if quality >= threshold.min then
            return threshold
        end
    end
    return Config.Containers.quality.thresholds.damaged
end

function Config.Containers.IsItemCompatible(containerType, itemType)
    local container = Config.Containers.types[containerType]
    if not container then return false end
    
    for _, compatible in ipairs(container.compatibleItems) do
        if compatible == itemType or compatible == "all_dry_goods" then
            return true
        end
    end
    
    return false
end

print("^2[SupplyChain]^7 Containers configuration loaded")