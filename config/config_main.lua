Config = Config or {}

-- ===================================
-- CORE FRAMEWORK SETTINGS
-- ===================================
Config.Core = 'qbox' -- qbcore or qbox
Config.Inventory = 'ox' -- ox_inventory
Config.Target = 'ox' -- ox_target
Config.Progress = 'ox' -- ox_lib
Config.Notify = 'ox' -- ox_lib
Config.Menu = 'ox' -- ox_lib

-- ===================================
-- UI CONFIGURATION
-- ===================================
Config.UI = {
    notificationPosition = 'center-right',
    enableMarkdown = true,
    theme = 'default'
}

-- ===================================
-- JOB ACCESS CONTROL
-- ===================================
Config.Jobs = {
    warehouse = {"hurst", "admin", "god"},
    delivery = {"hurst", "admin", "god"},
    management = {"admin", "god"}
}

-- Universal job validation functions
Config.JobValidation = {
    validateHurstAccess = function(playerJob)
        return playerJob == "hurst"
    end,
    
    validateAchievementAccess = function(playerJob)
        return playerJob == "hurst"
    end,
    
    validateNPCAccess = function(playerJob)
        return playerJob == "hurst"
    end,
    
    validateVehicleOwnership = function(playerJob)
        return playerJob == "hurst"
    end,
    
    validateManufacturingAccess = function(playerJob)
        return playerJob == "hurst"
    end,
    
    validateWarehouseAccess = function(playerJob)
        return playerJob == "hurst"
    end,
    
    getAccessDeniedMessage = function(feature, currentJob)
        local messages = {
            achievement = "🚫 Achievement system restricted to Hurst Industries employees",
            npc = "🚫 NPC delivery system restricted to Hurst Industries employees",
            vehicle = "🚫 Vehicle ownership restricted to Hurst Industries employees",
            manufacturing = "🚫 Manufacturing access restricted to Hurst Industries employees",
            warehouse = "🚫 Warehouse access restricted to Hurst Industries employees"
        }
        
        local baseMessage = messages[feature] or "🚫 Access restricted to Hurst Industries employees"
        return string.format("%s. Current job: %s", baseMessage, currentJob or "unemployed")
    end
}

-- ===================================
-- BASIC SYSTEM SETTINGS
-- ===================================
Config.Leaderboard = {
    enabled = true,
    maxEntries = 10
}

Config.LowStock = {
    enabled = true,
    threshold = 25
}

Config.maxBoxes = 6
Config.DriverPayPrec = 0.22

-- ===================================
-- CONTAINER SYSTEM INTEGRATION
-- ===================================
Config.ContainerSystem = {
    itemsPerContainer = 12,
    containersPerBox = 5,
    maxBoxesPerDelivery = 10
}

Config.ItemsPerBox = Config.ContainerSystem.itemsPerContainer * Config.ContainerSystem.containersPerBox

-- ===================================
-- DELIVERY PROPS CONFIGURATION
-- ===================================
Config.DeliveryProps = {
    boxProp = "ng_proc_box_01a",
    palletProp = "prop_boxpile_06b",
    palletOffset = vector3(0, 0, 0),
    deliveryMarker = {
        type = 1,
        size = vector3(3.0, 3.0, 1.0),
        color = {r = 0, g = 255, b = 0, a = 100},
        bobUpAndDown = false,
        faceCamera = false,
        rotate = true
    }
}

-- ===================================
-- VEHICLE CONFIGURATION
-- ===================================
Config.VehicleSelection = {
    small = {
        maxBoxes = 3,
        models = {"speedo"},
        spawnChance = 1.0
    },
    medium = {
        maxBoxes = 7,
        models = {"speedo", "mule"},
        spawnChance = 0.8
    },
    large = {
        maxBoxes = 15,
        models = {"mule", "pounder"},
        spawnChance = 1.0
    }
}

-- Maintain backward compatibility
Config.CarryBoxProp = Config.DeliveryProps.boxProp