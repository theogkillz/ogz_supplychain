-- ============================================
-- GLOBAL CONSTANTS - Used across all scripts
-- ============================================

-- Job Access Constants
JOBS = {
    WAREHOUSE = {"hurst", "admin", "god"},
    DELIVERY = {"hurst", "admin", "god"},
    MANAGEMENT = {"admin", "god"}
}

-- Container System Constants
CONTAINER_LIMITS = {
    ITEMS_PER_CONTAINER = 12,
    CONTAINERS_PER_BOX = 5,
    MAX_BOXES_PER_DELIVERY = 10
}

-- Delivery System Constants
DELIVERY = {
    COOLDOWN_MS = 300000,  -- 5 minutes
    REQUIRED_BOXES = 3,
    MIN_DELIVERY_TIME = 300,  -- 5 minutes
    MAX_DELIVERY_TIME = 1800, -- 30 minutes
    PERFECT_DELIVERY_TIME = 1200 -- 20 minutes
}

-- Economy Constants
ECONOMY = {
    MIN_DELIVERY_PAY = 200,
    MAX_DELIVERY_PAY = 2500,
    BASE_PAY_PER_BOX = 75,
    DRIVER_PAY_PERCENTAGE = 0.22
}

-- Cache Constants
CACHE = {
    DURATION_MS = 30000,  -- 30 seconds
    MAX_SIZE = 1000
}

-- Notification Positions
NOTIFICATION_POSITIONS = {
    DEFAULT = 'center-right',
    TOP = 'top',
    BOTTOM = 'bottom'
}

-- Achievement Tiers
ACHIEVEMENT_TIERS = {
    ROOKIE = "rookie",
    EXPERIENCED = "experienced", 
    PROFESSIONAL = "professional",
    ELITE = "elite",
    LEGENDARY = "legendary"
}

-- Export for global access
_G.SUPPLY_CONSTANTS = {
    JOBS = JOBS,
    CONTAINER_LIMITS = CONTAINER_LIMITS,
    DELIVERY = DELIVERY,
    ECONOMY = ECONOMY,
    CACHE = CACHE,
    NOTIFICATION_POSITIONS = NOTIFICATION_POSITIONS,
    ACHIEVEMENT_TIERS = ACHIEVEMENT_TIERS
}