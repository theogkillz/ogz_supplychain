-- Economic System Configuration

Config = Config or {}

Config.Economics = {
    -- Market Dynamics
    market = {
        enabled = true,
        updateInterval = 300,                    -- Update prices every 5 minutes
        priceHistoryDays = 7,                   -- Keep 7 days of price history
        volatility = 0.15,                      -- 15% maximum price swing
        
        -- Supply and Demand Factors
        factors = {
            playerCount = {
                enabled = true,
                weight = 0.3,                   -- 30% influence on price
                thresholds = {
                    low = {players = 10, multiplier = 0.8},
                    normal = {players = 30, multiplier = 1.0},
                    high = {players = 50, multiplier = 1.2},
                    peak = {players = 80, multiplier = 1.5}
                }
            },
            
            timeOfDay = {
                enabled = true,
                weight = 0.2,                   -- 20% influence on price
                schedule = {
                    {hour = 6, multiplier = 0.9},   -- Morning discount
                    {hour = 12, multiplier = 1.2},  -- Lunch rush
                    {hour = 18, multiplier = 1.3},  -- Dinner rush
                    {hour = 22, multiplier = 0.8}   -- Late night
                }
            },
            
            stockLevels = {
                enabled = true,
                weight = 0.3,                   -- 30% influence on price
                thresholds = {
                    surplus = {percent = 80, multiplier = 0.7},
                    normal = {percent = 50, multiplier = 1.0},
                    low = {percent = 25, multiplier = 1.3},
                    critical = {percent = 10, multiplier = 1.8}
                }
            },
            
            emergencyOrders = {
                enabled = true,
                weight = 0.2,                   -- 20% influence on price
                multiplier = 2.0                -- Double price during emergencies
            }
        }
    },
    
    -- Reward Calculations
    rewards = {
        -- Base reward structure
        base = {
            deliveryFee = 50,                   -- Base fee per delivery
            perBoxBonus = 25,                   -- Bonus per box delivered
            distanceMultiplier = 0.15,          -- 15 cents per meter
            fuelCompensation = 15               -- Flat fuel compensation
        },
        
        -- Performance bonuses
        bonuses = {
            speed = {
                enabled = true,
                thresholds = {
                    {time = 300, multiplier = 1.5},   -- Under 5 minutes = 50% bonus
                    {time = 600, multiplier = 1.25},  -- Under 10 minutes = 25% bonus
                    {time = 900, multiplier = 1.1}    -- Under 15 minutes = 10% bonus
                }
            },
            
            volume = {
                enabled = true,
                thresholds = {
                    {boxes = 5, multiplier = 1.1},    -- 5+ boxes = 10% bonus
                    {boxes = 10, multiplier = 1.25},  -- 10+ boxes = 25% bonus
                    {boxes = 20, multiplier = 1.5}    -- 20+ boxes = 50% bonus
                }
            },
            
            streak = {
                enabled = true,
                resetTime = 3600,               -- Reset after 1 hour of inactivity
                bonuses = {
                    {deliveries = 3, multiplier = 1.05},
                    {deliveries = 5, multiplier = 1.1},
                    {deliveries = 10, multiplier = 1.2},
                    {deliveries = 20, multiplier = 1.35},
                    {deliveries = 50, multiplier = 1.5}
                }
            },
            
            quality = {
                enabled = true,
                thresholds = {
                    excellent = {quality = 90, multiplier = 1.3},
                    good = {quality = 75, multiplier = 1.15},
                    fair = {quality = 50, multiplier = 1.0},
                    poor = {quality = 25, multiplier = 0.5}
                }
            }
        },
        
        -- Team bonuses
        team = {
            enabled = true,
            bonuses = {
                {members = 2, multiplier = 1.15},
                {members = 3, multiplier = 1.25},
                {members = 4, multiplier = 1.35}
            },
            splitMethod = "equal"              -- "equal" or "contribution"
        },
        
        -- Penalties
        penalties = {
            damage = {
                enabled = true,
                perIncident = 50,              -- $50 per damage incident
                maxPenalty = 500                -- Maximum penalty per delivery
            },
            
            late = {
                enabled = true,
                graceTime = 1800,               -- 30 minutes grace period
                perMinute = 5,                  -- $5 per minute late
                maxPenalty = 250                -- Maximum late penalty
            },
            
            cancelled = {
                enabled = true,
                penalty = 100,                  -- Penalty for cancelling accepted order
                cooldown = 600                  -- 10 minute cooldown after cancel
            }
        }
    },
    
    -- Business Economics
    business = {
        -- Restaurant operating costs
        restaurants = {
            dailyOverhead = 1000,               -- Daily operating cost
            staffWages = 15,                    -- Hourly wage per staff
            utilities = 500,                    -- Daily utilities
            
            -- Profit margins
            margins = {
                food = 0.3,                     -- 30% margin on food
                drinks = 0.5,                   -- 50% margin on drinks
                supplies = 0.1                  -- 10% margin on supplies
            }
        },
        
        -- Warehouse operations
        warehouse = {
            storageFeePer100 = 50,              -- $50 per 100 units stored
            handlingFee = 0.05,                 -- 5% handling fee
            insuranceRate = 0.02,               -- 2% insurance on value
            
            -- Bulk discounts
            bulkDiscounts = {
                {units = 100, discount = 0.05},
                {units = 500, discount = 0.1},
                {units = 1000, discount = 0.15},
                {units = 5000, discount = 0.2}
            }
        },
        
        -- Container economics
        containers = {
            rentalRates = {
                standard = 15,                  -- Per hour
                refrigerated = 25,
                frozen = 35,
                specialized = 50
            },
            
            damageDeposit = 500,                -- Refundable deposit
            cleaningFee = 25,                   -- If returned dirty
            lateFee = 50                        -- Per hour late
        }
    },
    
    -- Taxation
    taxation = {
        enabled = true,
        salesTax = 0.08,                        -- 8% sales tax
        importDuty = 0.15,                      -- 15% on imports
        businessTax = 0.12,                     -- 12% business tax
        
        -- Tax brackets for players
        incomeTax = {
            {income = 10000, rate = 0.05},
            {income = 50000, rate = 0.1},
            {income = 100000, rate = 0.15},
            {income = 500000, rate = 0.2}
        }
    },
    
    -- Economic Events
    events = {
        enabled = true,
        
        -- Market events
        marketCrash = {
            chance = 0.01,                      -- 1% chance per update
            duration = 3600,                    -- 1 hour
            priceMultiplier = 0.5               -- 50% price drop
        },
        
        surge = {
            chance = 0.05,                      -- 5% chance per update
            duration = 1800,                    -- 30 minutes
            priceMultiplier = 2.0               -- Double prices
        },
        
        shortage = {
            triggerPercent = 15,                -- Trigger at 15% stock
            priceMultiplier = 1.5,              -- 50% price increase
            emergencyOrderBonus = 1000          -- Bonus for emergency deliveries
        }
    }
}

-- Helper function to calculate dynamic price
function Config.Economics.CalculateDynamicPrice(basePrice, item, currentStock, maxStock)
    if not Config.Economics.market.enabled then
        return basePrice
    end
    
    local price = basePrice
    local factors = Config.Economics.market.factors
    
    -- Apply player count factor
    if factors.playerCount.enabled then
        local playerCount = GetNumPlayerIndices and GetNumPlayerIndices() or 30
        local playerMultiplier = 1.0
        
        for _, threshold in ipairs({factors.playerCount.thresholds.peak, 
                                   factors.playerCount.thresholds.high,
                                   factors.playerCount.thresholds.normal,
                                   factors.playerCount.thresholds.low}) do
            if playerCount >= threshold.players then
                playerMultiplier = threshold.multiplier
                break
            end
        end
        
        price = price * (1 + (playerMultiplier - 1) * factors.playerCount.weight)
    end
    
    -- Apply stock level factor
    if factors.stockLevels.enabled and currentStock and maxStock then
        local stockPercent = (currentStock / maxStock) * 100
        local stockMultiplier = 1.0
        
        if stockPercent >= factors.stockLevels.thresholds.surplus.percent then
            stockMultiplier = factors.stockLevels.thresholds.surplus.multiplier
        elseif stockPercent <= factors.stockLevels.thresholds.critical.percent then
            stockMultiplier = factors.stockLevels.thresholds.critical.multiplier
        elseif stockPercent <= factors.stockLevels.thresholds.low.percent then
            stockMultiplier = factors.stockLevels.thresholds.low.multiplier
        end
        
        price = price * (1 + (stockMultiplier - 1) * factors.stockLevels.weight)
    end
    
    -- Apply time of day factor
    if factors.timeOfDay.enabled then
        local hour = GetClockHours and GetClockHours() or 12
        local timeMultiplier = 1.0
        
        for i = #factors.timeOfDay.schedule, 1, -1 do
            if hour >= factors.timeOfDay.schedule[i].hour then
                timeMultiplier = factors.timeOfDay.schedule[i].multiplier
                break
            end
        end
        
        price = price * (1 + (timeMultiplier - 1) * factors.timeOfDay.weight)
    end
    
    -- Ensure price stays within volatility bounds
    local minPrice = basePrice * (1 - Config.Economics.market.volatility)
    local maxPrice = basePrice * (1 + Config.Economics.market.volatility)
    
    return math.floor(math.min(maxPrice, math.max(minPrice, price)))
end

-- Helper function to calculate delivery reward
function Config.Economics.CalculateDeliveryReward(distance, boxes, deliveryTime, quality, teamSize, streak)
    local reward = Config.Economics.rewards.base.deliveryFee
    
    -- Add per box bonus
    reward = reward + (boxes * Config.Economics.rewards.base.perBoxBonus)
    
    -- Add distance bonus
    reward = reward + (distance * Config.Economics.rewards.base.distanceMultiplier)
    
    -- Add fuel compensation
    reward = reward + Config.Economics.rewards.base.fuelCompensation
    
    -- Apply speed bonus
    if Config.Economics.rewards.bonuses.speed.enabled then
        for _, threshold in ipairs(Config.Economics.rewards.bonuses.speed.thresholds) do
            if deliveryTime <= threshold.time then
                reward = reward * threshold.multiplier
                break
            end
        end
    end
    
    -- Apply volume bonus
    if Config.Economics.rewards.bonuses.volume.enabled then
        for _, threshold in ipairs(Config.Economics.rewards.bonuses.volume.thresholds) do
            if boxes >= threshold.boxes then
                reward = reward * threshold.multiplier
                break
            end
        end
    end
    
    -- Apply quality bonus
    if Config.Economics.rewards.bonuses.quality.enabled and quality then
        if quality >= Config.Economics.rewards.bonuses.quality.thresholds.excellent.quality then
            reward = reward * Config.Economics.rewards.bonuses.quality.thresholds.excellent.multiplier
        elseif quality >= Config.Economics.rewards.bonuses.quality.thresholds.good.quality then
            reward = reward * Config.Economics.rewards.bonuses.quality.thresholds.good.multiplier
        elseif quality >= Config.Economics.rewards.bonuses.quality.thresholds.fair.quality then
            reward = reward * Config.Economics.rewards.bonuses.quality.thresholds.fair.multiplier
        else
            reward = reward * Config.Economics.rewards.bonuses.quality.thresholds.poor.multiplier
        end
    end
    
    -- Apply team bonus
    if Config.Economics.rewards.team.enabled and teamSize > 1 then
        for _, bonus in ipairs(Config.Economics.rewards.team.bonuses) do
            if teamSize >= bonus.members then
                reward = reward * bonus.multiplier
                break
            end
        end
    end
    
    -- Apply streak bonus
    if Config.Economics.rewards.bonuses.streak.enabled and streak then
        for _, bonus in ipairs(Config.Economics.rewards.bonuses.streak.bonuses) do
            if streak >= bonus.deliveries then
                reward = reward * bonus.multiplier
            end
        end
    end
    
    return math.floor(reward)
end

Config.Economics.inflationRate = 1.02
Config.Economics.taxRate = 0.15
Config.Economics.bonusMultipliers = {
    speed = 1.5,
    volume = 1.2,
    quality = 1.3,
    team = 1.25
}

-- Also ensure this is present (if not already):
Config.Economics.lowThreshold = 5  -- For dynamic pricing

print("^2[SupplyChain]^7 Economics configuration loaded")