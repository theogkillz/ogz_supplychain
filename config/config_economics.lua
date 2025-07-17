Config = Config or {}

-- ===================================
-- DYNAMIC PRICING CONFIGURATION
-- ===================================
Config.DynamicPricing = {
    enabled = true,
    peakThreshold = 20,
    lowThreshold = 5,
    minMultiplier = 0.8,
    maxMultiplier = 1.5
}

-- ===================================
-- BALANCED ECONOMY CONFIGURATION
-- ===================================
Config.EconomyBalance = {
    basePayPerBox = 75,
    minimumDeliveryPay = 200,
    maximumDeliveryPay = 2500,
    
    distanceBonus = {
        enabled = false,
        perKm = 5
    }
}

-- ===================================
-- MARKET PRICING SYSTEM
-- ===================================
Config.MarketPricing = {
    enabled = true,
    
    factors = {
        stockLevel = {
            enabled = true,
            weight = 0.4,
            criticalMultiplier = 2.5,
            lowMultiplier = 1.8,
            moderateMultiplier = 1.3,
            healthyMultiplier = 1.0
        },
        
        demand = {
            enabled = true,
            weight = 0.3,
            analysisWindow = 6,
            highDemandMultiplier = 1.5,
            normalDemandMultiplier = 1.0,
            lowDemandMultiplier = 0.9
        },
        
        playerActivity = {
            enabled = true,
            weight = 0.2,
            peakThreshold = 25,
            moderateThreshold = 15,
            lowThreshold = 5,
            peakMultiplier = 1.3,
            moderateMultiplier = 1.1,
            lowMultiplier = 0.9
        },
        
        timeOfDay = {
            enabled = true,
            weight = 0.1,
            peakHours = {19, 20, 21, 22},
            moderateHours = {16, 17, 18, 23},
            peakMultiplier = 1.2,
            moderateMultiplier = 1.05,
            offPeakMultiplier = 0.95
        }
    },
    
    limits = {
        minMultiplier = 0.7,
        maxMultiplier = 3.0,
        maxChangePerUpdate = 0.1
    },
    
    intervals = {
        priceUpdate = 300,
        marketSnapshot = 1800,
        demandAnalysis = 3600
    },
    
    events = {
        shortage = {
            enabled = true,
            threshold = 3,
            multiplier = 2.0,
            duration = 3600
        },
        surplus = {
            enabled = true,
            threshold = 95,
            multiplier = 0.8,
            duration = 1800
        }
    }
}

-- ===================================
-- EMERGENCY ORDER CONFIGURATION
-- ===================================
Config.EmergencyOrders = {
    enabled = true,
    
    triggers = {
        restaurantStockout = 0,
        warehouseStockout = 0,
        criticalStock = 5,
        highDemandShortage = 10
    },
    
    bonuses = {
        emergencyMultiplier = 0.5,
        urgentMultiplier = 0.2,
        criticalMultiplier = 0.7,
        speedBonus = 75,
        heroBonus = 120
    },
    
    priorities = {
        critical = {
            level = 3,
            name = "🚨 CRITICAL",
            color = "error",
            timeout = 1800,
            broadcastToAll = true
        },
        urgent = {
            level = 2, 
            name = "⚠️ URGENT",
            color = "warning",
            timeout = 3600,
            broadcastToAll = false
        },
        emergency = {
            level = 1,
            name = "🔥 EMERGENCY",
            color = "info", 
            timeout = 7200,
            broadcastToAll = false
        }
    }
}