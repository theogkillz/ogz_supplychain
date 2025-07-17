-- ============================================
-- CALCULATION FUNCTIONS
-- ============================================

local Calculations = {}

-- Economic calculations
Calculations.calculateDynamicPrice = function(basePrice, playerCount)
    local multiplier = 1.0
    
    if Config.DynamicPricing and Config.DynamicPricing.enabled then
        if playerCount > Config.DynamicPricing.peakThreshold then
            multiplier = multiplier + 0.2
        elseif playerCount < Config.DynamicPricing.lowThreshold then
            multiplier = multiplier - 0.1
        end
        
        multiplier = math.max(
            Config.DynamicPricing.minMultiplier or 0.8, 
            math.min(Config.DynamicPricing.maxMultiplier or 1.5, multiplier)
        )
    end
    
    return math.floor(basePrice * multiplier)
end

Calculations.calculateBasePay = function(boxes)
    local basePay = math.max(
        ECONOMY.MIN_DELIVERY_PAY,
        boxes * ECONOMY.BASE_PAY_PER_BOX
    )
    return math.min(basePay, ECONOMY.MAX_DELIVERY_PAY)
end

-- Reward calculations (from your sv_rewards.lua patterns)
Calculations.getSpeedMultiplier = function(deliveryTime)
    if not Config.DriverRewards or not Config.DriverRewards.speedBonuses then return 1.0 end
    
    for tier, bonus in pairs(Config.DriverRewards.speedBonuses) do
        if deliveryTime <= bonus.maxTime then
            return bonus.multiplier
        end
    end
    return 1.0
end

Calculations.getVolumeBonus = function(boxes)
    if not Config.DriverRewards or not Config.DriverRewards.volumeBonuses then return 0 end
    
    for tier, bonus in pairs(Config.DriverRewards.volumeBonuses) do
        if boxes >= bonus.minBoxes then
            return bonus.bonus
        end
    end
    return 0
end

Calculations.getStreakMultiplier = function(streak)
    if not Config.DriverRewards or not Config.DriverRewards.streakBonuses then return 1.0 end
    
    for tier, bonus in pairs(Config.DriverRewards.streakBonuses) do
        if streak >= bonus.streak then
            return bonus.multiplier
        end
    end
    return 1.0
end

Calculations.getDailyMultiplier = function(deliveries)
    if not Config.DriverRewards or not Config.DriverRewards.dailyMultipliers then return 1.0 end
    
    local multiplier = 1.0
    for _, tier in ipairs(Config.DriverRewards.dailyMultipliers) do
        if deliveries >= tier.deliveries then
            multiplier = tier.multiplier
        end
    end
    return multiplier
end

-- Container quality calculations
Calculations.calculateQualityDegradation = function(currentQuality, degradationFactor)
    if not currentQuality or currentQuality <= 0 then return 0 end
    
    local degradationRate = 0.05 -- Default 5%
    
    if Config.DynamicContainers and Config.DynamicContainers.system and Config.DynamicContainers.system.degradationRates then
        degradationRate = Config.DynamicContainers.system.degradationRates[degradationFactor] or degradationRate
    end
    
    local newQuality = currentQuality - (currentQuality * degradationRate)
    return math.max(0, newQuality)
end

-- Team bonus calculations
Calculations.getTeamMultiplier = function(teamSize)
    if not Config.TeamDeliveries or not Config.TeamDeliveries.teamBonuses then return 1.0 end
    
    for _, bonus in pairs(Config.TeamDeliveries.teamBonuses) do
        if teamSize >= bonus.size then
            return bonus.multiplier
        end
    end
    return 1.0
end

Calculations.getCoordinationBonus = function(timeDifference)
    if not Config.TeamDeliveries or not Config.TeamDeliveries.coordinationBonuses then return 0 end
    
    for tier, bonus in pairs(Config.TeamDeliveries.coordinationBonuses) do
        if timeDifference <= bonus.maxTimeDiff then
            return bonus.bonus
        end
    end
    return 0
end

-- Performance calculations
Calculations.calculatePerformanceRating = function(stats)
    if not stats then return 0 end
    
    local deliveryRate = stats.completed_deliveries / math.max(stats.total_deliveries, 1)
    local timeEfficiency = math.min(stats.avg_delivery_time / 900, 1.0) -- 15 min benchmark
    local qualityScore = stats.avg_quality_rating or 1.0
    
    return math.floor((deliveryRate * 40) + ((1 - timeEfficiency) * 30) + (qualityScore * 30))
end

-- Market calculations
Calculations.calculateMarketMultiplier = function(stockLevel, maxStock, demandLevel)
    if not stockLevel or not maxStock or maxStock <= 0 then return 1.0 end
    
    local stockPercentage = (stockLevel / maxStock) * 100
    local baseMultiplier = 1.0
    
    -- Stock-based pricing
    if stockPercentage <= 5 then
        baseMultiplier = 2.5
    elseif stockPercentage <= 20 then
        baseMultiplier = 1.8
    elseif stockPercentage <= 50 then
        baseMultiplier = 1.3
    end
    
    -- Demand modifier
    local demandMultiplier = 1.0
    if demandLevel == "high" then
        demandMultiplier = 1.2
    elseif demandLevel == "low" then
        demandMultiplier = 0.9
    end
    
    return baseMultiplier * demandMultiplier
end

-- Export for global access
_G.SupplyCalculations = Calculations
return Calculations