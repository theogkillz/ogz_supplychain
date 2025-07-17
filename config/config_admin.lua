Config = Config or {}

-- ===================================
-- ADMIN SYSTEM CONFIGURATION
-- ===================================
Config.AdminSystem = {
    permissions = {
        superadmin = 'god',
        admin = 'admin',
        moderator = 'mod'
    },
    
    commands = {
        enabled = true,
        prefix = 'supply',
        chatSuggestions = true
    }
}

-- ===================================
-- STOCK ALERTS CONFIGURATION
-- ===================================
Config.StockAlerts = {
    thresholds = {
        critical = 5,
        low = 20,
        moderate = 50,
        healthy = 80
    },
    
    maxStock = {
        default = 500,
        high_demand = 1000,
        seasonal = 200,
        specialty = 100
    },
    
    prediction = {
        analysisWindow = 7,
        forecastDays = 3,
        minDataPoints = 5,
        confidenceThreshold = 0.7
    },
    
    notifications = {
        checkInterval = 300,
        alertCooldown = 1800,
        maxAlertsPerCheck = 5
    }
}