-- ============================================
-- WAREHOUSE VEHICLE SPAWNING SYSTEM
-- Enhanced vehicle spawning with multi-box support
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- VEHICLE SPAWNING SYSTEM
-- ============================================

-- Enhanced Spawn Delivery Van with Multi-Box Support
RegisterNetEvent("warehouse:spawnVehicles")
AddEventHandler("warehouse:spawnVehicles", function(restaurantId, orders)
    local boxesNeeded, containersNeeded, totalItems, itemsList = exports.ogz_supplychain:calculateDeliveryBoxes(orders)
    
    print("[WAREHOUSE] Delivery calculated:", boxesNeeded, "boxes,", containersNeeded, "containers for", totalItems, "items")
    
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then
        print("[ERROR] No warehouse configuration found")
        exports.ogz_supplychain:errorNotify(
            "Configuration Error",
            "No warehouse configuration found."
        )
        return
    end

    -- Dynamic delivery briefing based on order size
    local briefingText = ""
    local deliveryType = "Standard"
    
    if boxesNeeded == 1 then
        briefingText = "Small delivery: Load 1 box with " .. containersNeeded .. " containers."
        deliveryType = "Small"
    elseif boxesNeeded <= 3 then
        briefingText = "Medium delivery: Load " .. boxesNeeded .. " boxes (" .. containersNeeded .. " containers total)."
        deliveryType = "Medium"
    elseif boxesNeeded <= 6 then
        briefingText = "Large delivery: Load " .. boxesNeeded .. " boxes (" .. containersNeeded .. " containers total)."
        deliveryType = "Large"
    else
        briefingText = "MEGA DELIVERY: Load " .. boxesNeeded .. " boxes (" .. containersNeeded .. " containers total). This is a massive order!"
        deliveryType = "Mega"
    end

    lib.alertDialog({
        header = "📦 " .. deliveryType .. " Delivery Job",
        content = briefingText,
        centered = true,
        cancel = true
    })

    -- Screen transition
    DoScreenFadeOut(2500)
    Citizen.Wait(2500)

    local playerPed = PlayerPedId()
    
    -- Dynamic vehicle selection based on order size
    local vehicleModel = "speedo" -- Default
    if boxesNeeded <= 2 then
        vehicleModel = "pony" -- Small van
    elseif boxesNeeded <= 5 then
        vehicleModel = "speedo" -- Medium van
    elseif boxesNeeded <= 8 then
        vehicleModel = "mule" -- Large truck
    else
        vehicleModel = "mule3" -- Mega truck
    end
    
    local vehicleHash = GetHashKey(vehicleModel)
    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Citizen.Wait(100)
    end

    -- Spawn vehicle
    local van = CreateVehicle(vehicleHash, 
        warehouseConfig.vehicle.position.x, 
        warehouseConfig.vehicle.position.y, 
        warehouseConfig.vehicle.position.z, 
        warehouseConfig.vehicle.position.w, 
        true, false)
    
    -- Setup vehicle
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    SetEntityCleanupByEngine(van, false)
    
    -- Vehicle keys
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    -- Set delivery tracking data
    local deliveryStartTime = GetGameTimer()
    local currentDeliveryData = { 
        orderGroupId = orders[1] and orders[1].orderGroupId,
        restaurantId = restaurantId,
        startTime = deliveryStartTime,
        boxesTotal = boxesNeeded,
        deliveryType = deliveryType
    }
    
    print("[WAREHOUSE] Van spawned:", vehicleModel, "Entity ID:", van, "for", boxesNeeded, "boxes")

    DoScreenFadeIn(2500)

    -- Success notification with vehicle info
    exports.ogz_supplychain:vehicleNotify(
        deliveryType .. " Delivery Ready",
        string.format("%s van spawned • %d boxes (%d containers) need loading", 
            vehicleModel:gsub("^%l", string.upper), boxesNeeded, containersNeeded)
    )

    -- Position player near vehicle
    SetEntityCoords(playerPed, 
        warehouseConfig.vehicle.position.x + 2.0, 
        warehouseConfig.vehicle.position.y, 
        warehouseConfig.vehicle.position.z, 
        false, false, false, true)
    
    -- Trigger appropriate loading system
    if boxesNeeded > 1 then
        TriggerEvent("warehouse:loadMultipleBoxes", warehouseConfig, van, restaurantId, orders, boxesNeeded)
    else
        TriggerEvent("warehouse:loadSingleBox", warehouseConfig, van, restaurantId, orders)
    end
end)

-- ============================================
-- ACHIEVEMENT-ENHANCED VEHICLE SPAWNING
-- ============================================

-- Enhanced vehicle spawning with achievement bonuses
RegisterNetEvent("warehouse:spawnVehiclesWithAchievements")
AddEventHandler("warehouse:spawnVehiclesWithAchievements", function(restaurantId, orders, containers, achievementTier)
    -- Calculate delivery requirements
    local totalBoxes = exports.ogz_supplychain:calculateDeliveryBoxes(orders, containers)
    
    -- Get player position
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Determine vehicle model based on load and achievement tier
    local vehicleModel = determineVehicleModel(totalBoxes, containers, achievementTier)
    
    -- Find optimal spawn location
    local spawnCoords = findOptimalSpawnLocation(playerCoords)
    
    -- Request vehicle model
    lib.requestModel(vehicleModel, 10000)
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(GetHashKey(vehicleModel), 
        spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    
    if DoesEntityExist(vehicle) then
        -- Apply standard vehicle setup
        setupDeliveryVehicle(vehicle, vehicleModel)
        
        -- Apply achievement-based modifications
        if exports.ogz_supplychain:applyAchievementMods then
            exports.ogz_supplychain:applyAchievementMods(vehicle, achievementTier)
        end
        
        -- Enhanced notification for achievement vehicles
        local tierInfo = Config.AchievementVehicles and 
            Config.AchievementVehicles.performanceTiers and 
            Config.AchievementVehicles.performanceTiers[achievementTier]
        
        if tierInfo and achievementTier ~= "rookie" then
            exports.ogz_supplychain:achievementNotify(
                tierInfo.name .. " Vehicle",
                tierInfo.description .. " • Enhanced performance activated!"
            )
        end
        
        -- Continue with delivery setup
        TriggerEvent("warehouse:startDelivery", restaurantId, vehicle, orders)
    end
end)

-- ============================================
-- VEHICLE UTILITY FUNCTIONS
-- ============================================

-- Determine vehicle model based on load size and tier
local function determineVehicleModel(totalBoxes, containers, achievementTier)
    local vehicleModel = "speedo" -- Default
    
    -- Base vehicle selection on load size
    if totalBoxes <= 2 then
        vehicleModel = "pony" -- Small deliveries
    elseif totalBoxes <= 5 then
        vehicleModel = "speedo" -- Medium deliveries
    elseif totalBoxes <= 10 then
        vehicleModel = "mule" -- Large deliveries
    else
        vehicleModel = "mule3" -- Extra large deliveries
    end
    
    -- Achievement tier can upgrade vehicle
    if achievementTier == "elite" or achievementTier == "legendary" then
        if vehicleModel == "pony" then
            vehicleModel = "speedo" -- Upgrade small to medium
        elseif vehicleModel == "speedo" then
            vehicleModel = "mule" -- Upgrade medium to large
        elseif vehicleModel == "mule" then
            vehicleModel = "mule3" -- Upgrade large to extra large
        end
    end
    
    return vehicleModel
end

-- Find optimal spawn location for vehicle
local function findOptimalSpawnLocation(playerCoords)
    local spawnOffset = 5.0
    local testCoords = {
        vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x - spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y + spawnOffset, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y - spawnOffset, playerCoords.z, 0.0)
    }
    
    -- Test each location for clearance
    for _, coords in ipairs(testCoords) do
        local groundZ = coords.z
        local foundGround, groundCoords = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
        
        if foundGround then
            return vector4(coords.x, coords.y, groundCoords, 0.0)
        end
    end
    
    -- Fallback to warehouse spawn point
    local warehouseConfig = Config.Warehouses[1]
    if warehouseConfig and warehouseConfig.vehicle then
        return warehouseConfig.vehicle.position
    end
    
    -- Final fallback to player position with offset
    return vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0)
end

-- Setup delivery vehicle with standard configurations
local function setupDeliveryVehicle(vehicle, vehicleModel)
    if not DoesEntityExist(vehicle) then return end
    
    -- Standard vehicle setup
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Set fuel to full if fuel system exists
    if exports['LegacyFuel'] then
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    end
    
    -- Add vehicle keys if using a key system
    if exports['qb-vehiclekeys'] then
        exports['qb-vehiclekeys']:GiveKeys(GetVehicleNumberPlateText(vehicle))
    end
    
    print("[WAREHOUSE] Vehicle setup complete:", vehicleModel)
end

-- ============================================
-- VEHICLE CLEANUP SYSTEM
-- ============================================

-- Emergency vehicle cleanup
local function cleanupDeliveryVehicles()
    local playerPed = PlayerPedId()
    local vehicles = GetGamePool('CVehicle')
    local cleanedCount = 0
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local plate = GetVehicleNumberPlateText(vehicle)
            if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
                if GetVehiclePedIsIn(playerPed, false) ~= vehicle then
                    DeleteVehicle(vehicle)
                    cleanedCount = cleanedCount + 1
                end
            end
        end
    end
    
    if cleanedCount > 0 then
        exports.ogz_supplychain:systemNotify(
            "Vehicles Cleaned",
            string.format("Removed %d abandoned delivery vehicles", cleanedCount)
        )
    end
    
    return cleanedCount
end

-- ============================================
-- EXPORTS
-- ============================================

exports('cleanupDeliveryVehicles', cleanupDeliveryVehicles)
exports('setupDeliveryVehicle', setupDeliveryVehicle)
exports('determineVehicleModel', determineVehicleModel)

print("[WAREHOUSE] Vehicle spawning system loaded")