Config = Config or {}

-- ============================================
-- MARKET-DYNAMIC NPC DELIVERY SYSTEM
-- NPCs only available during surplus conditions
-- ============================================
Config.NPCDeliverySystem = {
    enabled = true,
    
    surplusThresholds = {
        moderate_surplus = {
            stockPercentage = 80,
            npcPayMultiplier = 0.7,
            maxConcurrentJobs = 1,
            cooldownMinutes = 30,
            playerRequirement = "initiate",
            description = "Moderate surplus - basic NPC assistance available"
        },
        
        high_surplus = {
            stockPercentage = 90,
            npcPayMultiplier = 0.8,
            maxConcurrentJobs = 2,
            cooldownMinutes = 20,
            playerRequirement = "initiate",
            description = "High surplus - enhanced NPC assistance available"
        },
        
        critical_surplus = {
            stockPercentage = 95,
            npcPayMultiplier = 0.9,
            maxConcurrentJobs = 3,
            cooldownMinutes = 15,
            playerRequirement = "initiate",
            emergencyMode = true,
            description = "Critical surplus - maximum NPC assistance to clear backlog"
        }
    },
    
    npcBehavior = {
        guaranteedCompletion = true,
        randomFailureChance = 0.05,
        baseCompletionTime = 300,
        timeVariation = 120,
        noTimeBonus = true,
        noQualityBonus = true,
        basicPayOnly = true,
    },
    
    marketIntegration = {
        reducesPrices = true,
        priceReductionFactor = 0.02,
        preventsMarketCrash = true,
        balancingEffect = true,
    },
    
    playerRequirements = {
        mustBeOnDuty = true,
        mustInitiateJob = true,
        cannotBePassive = true,
        limitPerPlayer = 2,
        requiresWarehouseAccess = true,
    }
}

-- ===================================
-- SYSTEM INTEGRATION
-- ===================================
Config.SystemIntegration = {
    achievements = {
        enabled = true,
        vehicleModsEnabled = true,
        trackDeliveryRating = true,
        trackTeamDeliveries = true,
        updateInterval = 60
    },
    
    npcSystem = {
        enabled = true,
        requireSurplus = true,
        allowPassiveIncome = false,
        maxConcurrentPerPlayer = 2,
        integrationWithMarket = true
    }
}