-- ============================================
-- OX_TARGET INTEGRATION SYSTEM
-- Centralized targeting and interaction management
-- ============================================

-- ============================================
-- TARGET ZONE MANAGEMENT
-- ============================================

local activeZones = {}
local zoneCounter = 0

-- Generate unique zone names
local function generateZoneName(prefix)
    zoneCounter = zoneCounter + 1
    return string.format("%s_%d_%d", prefix or "zone", zoneCounter, GetGameTimer())
end

-- Safe zone creation with tracking
local function createBoxZone(config)
    local zoneName = config.name or generateZoneName(config.prefix or "supply_zone")
    
    -- Validate required parameters
    if not config.coords then
        print("[TARGET] Error: coords required for zone creation")
        return nil
    end
    
    if not config.options or #config.options == 0 then
        print("[TARGET] Error: options required for zone creation")
        return nil
    end
    
    -- Create zone with ox_target
    local success, error = pcall(function()
        exports.ox_target:addBoxZone({
            coords = config.coords,
            size = config.size or vector3(2.0, 2.0, 2.0),
            rotation = config.rotation or 0,
            debug = config.debug or false,
            name = zoneName,
            options = config.options
        })
    end)
    
    if success then
        activeZones[zoneName] = {
            type = "box",
            coords = config.coords,
            created = GetGameTimer()
        }
        print("[TARGET] Created box zone: " .. zoneName)
        return zoneName
    else
        print("[TARGET] Failed to create zone: " .. tostring(error))
        return nil
    end
end

-- Safe zone creation for spheres
local function createSphereZone(config)
    local zoneName = config.name or generateZoneName(config.prefix or "sphere_zone")
    
    if not config.coords then
        print("[TARGET] Error: coords required for sphere zone creation")
        return nil
    end
    
    local success, error = pcall(function()
        exports.ox_target:addSphereZone({
            coords = config.coords,
            radius = config.radius or 2.0,
            debug = config.debug or false,
            name = zoneName,
            options = config.options or {}
        })
    end)
    
    if success then
        activeZones[zoneName] = {
            type = "sphere",
            coords = config.coords,
            created = GetGameTimer()
        }
        print("[TARGET] Created sphere zone: " .. zoneName)
        return zoneName
    else
        print("[TARGET] Failed to create sphere zone: " .. tostring(error))
        return nil
    end
end

-- Safe zone removal
local function removeZone(zoneName)
    if not zoneName then
        return false
    end
    
    local success, error = pcall(function()
        exports.ox_target:removeZone(zoneName)
    end)
    
    if success then
        activeZones[zoneName] = nil
        print("[TARGET] Removed zone: " .. zoneName)
        return true
    else
        print("[TARGET] Failed to remove zone " .. zoneName .. ": " .. tostring(error))
        return false
    end
end

-- Remove multiple zones by pattern
local function removeZonesByPattern(pattern)
    local removedCount = 0
    
    for zoneName, _ in pairs(activeZones) do
        if string.find(zoneName, pattern) then
            if removeZone(zoneName) then
                removedCount = removedCount + 1
            end
        end
    end
    
    print("[TARGET] Removed " .. removedCount .. " zones matching pattern: " .. pattern)
    return removedCount
end

-- ============================================
-- STANDARD INTERACTION BUILDERS
-- ============================================

-- Build warehouse interaction
local function buildWarehouseInteraction(warehouseId, config)
    return {
        name = "warehouse_" .. warehouseId,
        icon = "fas fa-warehouse",
        label = config.label or "Access Warehouse",
        groups = config.jobs or {"hurst"},
        onSelect = function()
            TriggerEvent("warehouse:openProcessingMenu")
        end
    }
end

-- Build restaurant interaction
local function buildRestaurantInteraction(restaurantId, config)
    return {
        name = "restaurant_" .. restaurantId,
        icon = "fas fa-laptop",
        label = config.label or "Order Ingredients",
        groups = config.job,
        onSelect = function()
            TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
        end
    }
end

-- Build manufacturing interaction
local function buildManufacturingInteraction(facilityId, config)
    return {
        name = "manufacturing_" .. facilityId,
        icon = "fas fa-industry",
        label = config.label or "Access Manufacturing",
        groups = {"hurst"},
        onSelect = function()
            TriggerEvent("manufacturing:openFacilityMenu", facilityId)
        end
    }
end

-- Build container interaction
local function buildContainerInteraction(containerId, config)
    return {
        name = "container_" .. containerId,
        icon = "fas fa-box",
        label = config.label or "Interact with Container",
        onSelect = function()
            TriggerEvent("containers:openInteractionMenu", containerId)
        end
    }
end

-- ============================================
-- BULK ZONE OPERATIONS
-- ============================================

-- Create multiple zones from config
local function createZonesFromConfig(zonesConfig, zoneType)
    local createdZones = {}
    
    for id, config in pairs(zonesConfig or {}) do
        local zoneName = nil
        
        if zoneType == "warehouse" then
            config.options = { buildWarehouseInteraction(id, config) }
            zoneName = createBoxZone({
                coords = config.position,
                size = config.size or vector3(1.0, 0.5, 3.5),
                rotation = config.heading,
                options = config.options,
                name = "warehouse_processing_" .. id
            })
        elseif zoneType == "restaurant" then
            config.options = { buildRestaurantInteraction(id, config) }
            zoneName = createBoxZone({
                coords = config.position,
                size = config.size or vector3(1.5, 1.5, 1.0),
                rotation = config.heading,
                options = config.options,
                name = "restaurant_computer_" .. id
            })
        elseif zoneType == "manufacturing" then
            config.options = { buildManufacturingInteraction(id, config) }
            zoneName = createBoxZone({
                coords = config.position,
                size = config.size or vector3(3.0, 3.0, 3.0),
                rotation = config.heading,
                options = config.options,
                name = "manufacturing_facility_" .. id
            })
        end
        
        if zoneName then
            createdZones[id] = zoneName
        end
    end
    
    return createdZones
end

-- ============================================
-- CLEANUP AND MAINTENANCE
-- ============================================

-- Clean up old zones (older than specified time)
local function cleanupOldZones(maxAge)
    local currentTime = GetGameTimer()
    local cleanedCount = 0
    
    for zoneName, zoneData in pairs(activeZones) do
        if currentTime - zoneData.created > (maxAge or 600000) then -- Default 10 minutes
            if removeZone(zoneName) then
                cleanedCount = cleanedCount + 1
            end
        end
    end
    
    if cleanedCount > 0 then
        print("[TARGET] Cleaned up " .. cleanedCount .. " old zones")
    end
    
    return cleanedCount
end

-- Emergency cleanup all zones
local function emergencyCleanup()
    local totalZones = 0
    for _ in pairs(activeZones) do
        totalZones = totalZones + 1
    end
    
    for zoneName, _ in pairs(activeZones) do
        removeZone(zoneName)
    end
    
    print("[TARGET] Emergency cleanup removed " .. totalZones .. " zones")
    return totalZones
end

-- ============================================
-- SYSTEM EVENTS
-- ============================================

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        emergencyCleanup()
    end
end)

-- Periodic cleanup
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Every 5 minutes
        cleanupOldZones()
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('createBoxZone', createBoxZone)
exports('createSphereZone', createSphereZone)
exports('removeZone', removeZone)
exports('removeZonesByPattern', removeZonesByPattern)
exports('createZonesFromConfig', createZonesFromConfig)
exports('buildWarehouseInteraction', buildWarehouseInteraction)
exports('buildRestaurantInteraction', buildRestaurantInteraction)
exports('buildManufacturingInteraction', buildManufacturingInteraction)
exports('buildContainerInteraction', buildContainerInteraction)
exports('getActiveZones', function() return activeZones end)
exports('cleanupOldZones', cleanupOldZones)
exports('emergencyCleanup', emergencyCleanup)

print("[TARGET] ox_target integration system loaded")