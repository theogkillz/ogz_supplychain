-- ============================================
-- CLIENT VEHICLE SYSTEM WITH CONTAINER INTEGRATION
-- Enhanced vehicle spawning and delivery system
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Client state
local currentDeliveryVehicle = nil
local currentDeliveryData = nil
local deliveryBlip = nil
local vehicleBlip = nil
local containerTrackingBlips = {}
local deliveryStartTime = nil
local containerQualityThread = nil

-- ============================================
-- CONTAINER-ENHANCED VEHICLE SPAWNING
-- ============================================

-- Spawn delivery vehicle with container support
RegisterNetEvent('warehouse:spawnVehiclesWithContainers')
AddEventHandler('warehouse:spawnVehiclesWithContainers', function(restaurantId, orders, containers)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Enhanced spawn location finding
    local spawnCoords = findOptimalSpawnLocation(playerCoords)
    if not spawnCoords then
        lib.notify({
            title = 'Spawn Error',
            description = 'Could not find suitable vehicle spawn location',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Determine vehicle type based on order size
    local totalBoxes = calculateTotalBoxes(orders, containers)
    local vehicleModel = determineVehicleModel(totalBoxes, containers)
    
    -- Load vehicle model
    lib.requestModel(vehicleModel, 10000)
    
    -- Spawn vehicle
    currentDeliveryVehicle = CreateVehicle(vehicleModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    
    if not DoesEntityExist(currentDeliveryVehicle) then
        lib.notify({
            title = 'Vehicle Spawn Failed',
            description = 'Failed to spawn delivery vehicle',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Configure vehicle
    setupDeliveryVehicle(currentDeliveryVehicle, vehicleModel)
    
    -- Set up delivery data
    currentDeliveryData = {
        restaurantId = restaurantId,
        orders = orders,
        containers = containers or {},
        totalBoxes = totalBoxes,
        vehicleModel = vehicleModel,
        startTime = GetGameTimer(),
        qualityChecks = {},
        temperatureBreaches = 0,
        handlingScore = 100
    }
    
    -- Create vehicle blip
    createVehicleBlip(currentDeliveryVehicle)
    
    -- Set up container monitoring if containers are used
    if containers and #containers > 0 then
        setupContainerMonitoring(containers)
        startContainerQualityTracking()
    end
    
    -- Show loading instructions
    showLoadingInstructions(totalBoxes, containers)
    
    -- Start loading process
    startVehicleLoading()
end)

-- ============================================
-- VEHICLE CONFIGURATION AND SETUP
-- ============================================

-- Find optimal spawn location for delivery vehicle
local function findOptimalSpawnLocation(playerCoords)
    local spawnPoints = {
        vector4(-1180.0, -2008.0, 13.2, 135.0), -- Warehouse 1
        vector4(-1190.0, -2018.0, 13.2, 135.0), -- Warehouse 2
        vector4(-1200.0, -2028.0, 13.2, 135.0), -- Warehouse 3
    }
    
    for _, point in ipairs(spawnPoints) do
        if IsAreaClear(point.x, point.y, point.z, 5.0, true, false, false, false) then
            return point
        end
    end
    
    -- Fallback: find clear area near player
    local found, coords = GetSafeCoordForPed(playerCoords.x + 10, playerCoords.y + 10, playerCoords.z, true, 16)
    if found then
        return vector4(coords.x, coords.y, coords.z, 0.0)
    end
    
    return nil
end

-- Determine vehicle model based on delivery size and container types
local function determineVehicleModel(totalBoxes, containers)
    local vehicleConfigs = {
        small = { model = "boxville", capacity = 20, name = "Small Delivery Van" },
        medium = { model = "boxville2", capacity = 40, name = "Medium Delivery Truck" },
        large = { model = "boxville3", capacity = 60, name = "Large Delivery Truck" },
        refrigerated = { model = "pounder", capacity = 50, name = "Refrigerated Truck" }
    }
    
    -- Check if refrigerated vehicle needed
    local needsRefrigeration = false
    if containers then
        for _, container in ipairs(containers) do
            if container.containerType and Config.DynamicContainers.containerTypes[container.containerType] then
                local config = Config.DynamicContainers.containerTypes[container.containerType]
                if config.requiresRefrigeration or config.temperatureControlled then
                    needsRefrigeration = true
                    break
                end
            end
        end
    end
    
    if needsRefrigeration then
        return vehicleConfigs.refrigerated.model
    elseif totalBoxes <= 20 then
        return vehicleConfigs.small.model
    elseif totalBoxes <= 40 then
        return vehicleConfigs.medium.model
    else
        return vehicleConfigs.large.model
    end
end

-- Calculate total boxes from orders and containers
local function calculateTotalBoxes(orders, containers)
    if containers and #containers > 0 then
        return #containers -- One container = one box
    end
    
    local totalItems = 0
    for _, order in ipairs(orders) do
        totalItems = totalItems + order.quantity
    end
    
    local itemsPerBox = 12 -- Default container capacity
    return math.ceil(totalItems / itemsPerBox)
end

-- Setup delivery vehicle properties
local function setupDeliveryVehicle(vehicle, model)
    -- Set vehicle properties
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Fuel and condition
    exports['cdn-fuel']:SetFuel(vehicle, 100.0) -- Full fuel
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    
    -- Lock vehicle to player
    local playerPed = PlayerPedId()
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Give keys to player (if using key system)
    if exports['qb-vehiclekeys'] then
        exports['qb-vehiclekeys']:GiveKeys(GetVehicleNumberPlateText(vehicle))
    end
    
    -- Add delivery vehicle identifier
    SetVehicleNumberPlateText(vehicle, "HURST" .. math.random(10, 99))
    
    -- Visual modifications for delivery vehicles
    if model == "pounder" then
        -- Refrigerated truck setup
        SetVehicleLivery(vehicle, 0) -- Delivery company livery
        SetVehicleColours(vehicle, 0, 0) -- White color scheme
    else
        -- Standard delivery van setup
        SetVehicleColours(vehicle, 0, 0) -- White color scheme
    end
end

-- Create vehicle tracking blip
local function createVehicleBlip(vehicle)
    if vehicleBlip then
        RemoveBlip(vehicleBlip)
    end
    
    vehicleBlip = AddBlipForEntity(vehicle)
    SetBlipSprite(vehicleBlip, 67) -- Delivery truck icon
    SetBlipColour(vehicleBlip, 5) -- Yellow
    SetBlipScale(vehicleBlip, 0.8)
    SetBlipAsShortRange(vehicleBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("📦 Delivery Vehicle")
    EndTextCommandSetBlipName(vehicleBlip)
end

-- ============================================
-- CONTAINER MONITORING SYSTEM
-- ============================================

-- Setup container monitoring for quality tracking
local function setupContainerMonitoring(containers)
    currentDeliveryData.containerStates = {}
    
    for _, container in ipairs(containers) do
        currentDeliveryData.containerStates[container.containerId] = {
            initialQuality = 100.0, -- Assume 100% when loaded
            currentQuality = 100.0,
            temperatureBreach = false,
            lastQualityCheck = GetGameTimer(),
            degradationEvents = {}
        }
    end
end

-- Start container quality tracking thread
local function startContainerQualityTracking()
    if containerQualityThread then return end
    
    containerQualityThread = true
    
    Citizen.CreateThread(function()
        while containerQualityThread and currentDeliveryVehicle and DoesEntityExist(currentDeliveryVehicle) do
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle == currentDeliveryVehicle then
                -- Check driving behavior for container quality
                checkDrivingBehavior(vehicle)
                
                -- Check vehicle condition
                checkVehicleCondition(vehicle)
                
                -- Update container quality
                updateContainerQuality()
            end
            
            Citizen.Wait(5000) -- Check every 5 seconds
        end
        
        containerQualityThread = nil
    end)
end

-- Check driving behavior affecting container quality
local function checkDrivingBehavior(vehicle)
    local speed = GetEntitySpeed(vehicle) * 2.237 -- Convert to MPH
    local acceleration = GetVehicleAcceleration(vehicle)
    local isOnFire = IsVehicleOnFire(vehicle)
    local hasCollided = HasEntityCollidedWithAnything(vehicle)
    
    local qualityImpact = 0
    local degradationReason = nil
    
    -- Speed penalty
    if speed > 80 then
        qualityImpact = qualityImpact - 0.5 -- High speed reduces quality
        degradationReason = "excessive_speed"
    end
    
    -- Acceleration/braking penalty
    if math.abs(acceleration) > 5.0 then
        qualityImpact = qualityImpact - 1.0 -- Harsh acceleration/braking
        degradationReason = "rough_driving"
    end
    
    -- Collision penalty
    if hasCollided then
        qualityImpact = qualityImpact - 5.0 -- Major impact
        degradationReason = "collision"
        currentDeliveryData.handlingScore = math.max(0, currentDeliveryData.handlingScore - 10)
    end
    
    -- Fire penalty (critical)
    if isOnFire then
        qualityImpact = qualityImpact - 25.0 -- Massive quality loss
        degradationReason = "fire_damage"
        currentDeliveryData.temperatureBreaches = currentDeliveryData.temperatureBreaches + 1
    end
    
    -- Apply quality impact if any
    if qualityImpact < 0 and currentDeliveryData.containerStates then
        for containerId, state in pairs(currentDeliveryData.containerStates) do
            state.currentQuality = math.max(0, state.currentQuality + qualityImpact)
            
            if degradationReason then
                table.insert(state.degradationEvents, {
                    reason = degradationReason,
                    impact = math.abs(qualityImpact),
                    timestamp = GetGameTimer()
                })
            end
        end
        
        -- Show quality warning if significant impact
        if qualityImpact <= -5.0 then
            showQualityWarning(degradationReason, math.abs(qualityImpact))
        end
    end
end

-- Check vehicle condition for container integrity
local function checkVehicleCondition(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    -- Engine issues affect refrigerated containers
    if engineHealth < 500 and currentDeliveryData.containers then
        for _, container in ipairs(currentDeliveryData.containers) do
            if container.containerType then
                local config = Config.DynamicContainers.containerTypes[container.containerType]
                if config and config.temperatureControlled then
                    -- Temperature control failure
                    local state = currentDeliveryData.containerStates[container.containerId]
                    if state then
                        state.temperatureBreach = true
                        state.currentQuality = math.max(0, state.currentQuality - 2.0)
                        
                        table.insert(state.degradationEvents, {
                            reason = "temperature_control_failure",
                            impact = 2.0,
                            timestamp = GetGameTimer()
                        })
                    end
                end
            end
        end
        
        currentDeliveryData.temperatureBreaches = currentDeliveryData.temperatureBreaches + 1
    end
    
    -- Body damage affects container security
    if bodyHealth < 300 then
        if currentDeliveryData.containerStates then
            for containerId, state in pairs(currentDeliveryData.containerStates) do
                state.currentQuality = math.max(0, state.currentQuality - 1.0)
                
                table.insert(state.degradationEvents, {
                    reason = "vehicle_damage",
                    impact = 1.0,
                    timestamp = GetGameTimer()
                })
            end
        end
    end
end

-- Update container quality based on time and conditions
local function updateContainerQuality()
    if not currentDeliveryData.containerStates then return end
    
    local currentTime = GetGameTimer()
    
    for containerId, state in pairs(currentDeliveryData.containerStates) do
        local timeSinceLastCheck = currentTime - state.lastQualityCheck
        local timeBasedDegradation = (timeSinceLastCheck / 1000) * 0.01 -- 0.01% per second
        
        state.currentQuality = math.max(0, state.currentQuality - timeBasedDegradation)
        state.lastQualityCheck = currentTime
        
        -- Check for quality alerts
        if state.currentQuality <= 30 and state.currentQuality > 25 then
            showContainerQualityAlert(containerId, state.currentQuality, 'warning')
        elseif state.currentQuality <= 25 then
            showContainerQualityAlert(containerId, state.currentQuality, 'critical')
        end
    end
end

-- Show quality warning to player
local function showQualityWarning(reason, impact)
    local reasonMessages = {
        excessive_speed = "⚡ Driving too fast!",
        rough_driving = "🚗 Smooth driving protects containers!",
        collision = "💥 Collision detected!",
        fire_damage = "🔥 FIRE! Containers critically damaged!",
        temperature_control_failure = "❄️ Refrigeration system failure!"
    }
    
    local message = reasonMessages[reason] or "Container quality affected!"
    
    lib.notify({
        title = '📦 Container Quality Warning',
        description = string.format('%s\n⚠️ Quality reduced by %.1f%%', message, impact),
        type = impact >= 10 and 'error' or 'warning',
        duration = 5000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Play warning sound
    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
end

-- Show container quality alert
local function showContainerQualityAlert(containerId, quality, alertType)
    local qualityIcon = quality <= 25 and "🚨" or "⚠️"
    local qualityLabel = quality <= 25 and "CRITICAL" or "WARNING"
    
    lib.notify({
        title = string.format('%s Container Quality %s', qualityIcon, qualityLabel),
        description = string.format('Container %s\nQuality: **%.1f%%**\nTake care with remaining delivery!', 
            containerId:sub(-6), quality),
        type = alertType,
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- ============================================
-- LOADING AND DELIVERY PROCESS
-- ============================================

-- Show loading instructions to player
local function showLoadingInstructions(totalBoxes, containers)
    local containerText = ""
    if containers and #containers > 0 then
        local containerTypes = {}
        for _, container in ipairs(containers) do
            local containerType = container.containerType
            if not containerTypes[containerType] then
                containerTypes[containerType] = 0
            end
            containerTypes[containerType] = containerTypes[containerType] + 1
        end
        
        local typesList = {}
        for containerType, count in pairs(containerTypes) do
            local config = Config.DynamicContainers.containerTypes[containerType]
            local name = config and config.name or containerType
            table.insert(typesList, string.format("%d %s", count, name))
        end
        
        containerText = string.format("\n📦 **Container Types:**\n%s", table.concat(typesList, "\n"))
    end
    
    lib.notify({
        title = '📦 Loading Instructions',
        description = string.format(
            '🚛 **Delivery Vehicle Ready**\n\n📦 Total Boxes: **%d**%s\n\n🎯 **Next Steps:**\n• Get in the vehicle\n• Drive carefully to preserve quality\n• Deliver to restaurant',
            totalBoxes, containerText
        ),
        type = 'info',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- Start vehicle loading process
local function startVehicleLoading()
    deliveryStartTime = GetGameTimer()
    
    -- Create delivery route blip
    createDeliveryBlip(currentDeliveryData.restaurantId)
    
    -- Set GPS route
    setDeliveryRoute(currentDeliveryData.restaurantId)
    
    -- Start delivery tracking
    startDeliveryTracking()
end

-- Create delivery destination blip
local function createDeliveryBlip(restaurantId)
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then return end
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    
    deliveryBlip = AddBlipForCoord(restaurant.coords.x, restaurant.coords.y, restaurant.coords.z)
    SetBlipSprite(deliveryBlip, 1) -- Destination marker
    SetBlipColour(deliveryBlip, 2) -- Green
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("🎯 Delivery Destination: " .. restaurant.name)
    EndTextCommandSetBlipName(deliveryBlip)
end

-- Set GPS route to restaurant
local function setDeliveryRoute(restaurantId)
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then return end
    
    SetNewWaypoint(restaurant.coords.x, restaurant.coords.y)
    
    lib.notify({
        title = '🗺️ Route Set',
        description = string.format('GPS route set to **%s**\nFollow the yellow line on your map', restaurant.name),
        type = 'info',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- Start delivery tracking thread
local function startDeliveryTracking()
    Citizen.CreateThread(function()
        while currentDeliveryVehicle and DoesEntityExist(currentDeliveryVehicle) and currentDeliveryData do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local restaurant = Config.Restaurants[currentDeliveryData.restaurantId]
            
            if restaurant then
                local distance = #(playerCoords - restaurant.coords)
                
                -- Check if player is near delivery location
                if distance <= 10.0 then
                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                    if vehicle == currentDeliveryVehicle then
                        showDeliveryPrompt()
                    end
                end
            end
            
            Citizen.Wait(1000)
        end
    end)
end

-- Show delivery completion prompt
local function showDeliveryPrompt()
    lib.showTextUI('[E] Complete Delivery', {
        position = "top-center",
        icon = 'truck',
        style = {
            borderRadius = 5,
            backgroundColor = '#48BB78',
            color = 'white'
        }
    })
    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            if IsControlJustReleased(0, 38) then -- E key
                lib.hideTextUI()
                completeDelivery()
                break
            end
            
            local playerCoords = GetEntityCoords(PlayerPedId())
            local restaurant = Config.Restaurants[currentDeliveryData.restaurantId]
            local distance = #(playerCoords - restaurant.coords)
            
            if distance > 15.0 then
                lib.hideTextUI()
                break
            end
        end
    end)
end

-- Complete delivery process
local function completeDelivery()
    if not currentDeliveryData then return end
    
    local deliveryTime = GetGameTimer() - deliveryStartTime
    local vehicle = currentDeliveryVehicle
    
    -- Calculate final quality scores
    local avgQuality = 100.0
    local qualityBonus = 0
    
    if currentDeliveryData.containerStates then
        local totalQuality = 0
        local containerCount = 0
        
        for _, state in pairs(currentDeliveryData.containerStates) do
            totalQuality = totalQuality + state.currentQuality
            containerCount = containerCount + 1
        end
        
        if containerCount > 0 then
            avgQuality = totalQuality / containerCount
        end
    end
    
    -- Calculate quality bonus
    if avgQuality >= 95 then
        qualityBonus = 200 -- Excellent quality bonus
    elseif avgQuality >= 85 then
        qualityBonus = 100 -- Good quality bonus
    elseif avgQuality >= 70 then
        qualityBonus = 50  -- Fair quality bonus
    end
    
    -- Calculate handling bonus
    local handlingBonus = 0
    if currentDeliveryData.handlingScore >= 95 then
        handlingBonus = 150 -- Perfect handling
    elseif currentDeliveryData.handlingScore >= 85 then
        handlingBonus = 75  -- Good handling
    end
    
    -- Show completion animation
    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, "mini@repair", "fixing_a_ped", 8.0, -8.0, 3000, 0, 0, false, false, false)
    
    if lib.progressBar({
        duration = 5000,
        position = "bottom",
        label = "Unloading containers...",
        canCancel = false,
        disable = { move = true, car = true, combat = true, sprint = true },
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    }) then
        
        -- Trigger server-side delivery completion
        if currentDeliveryData.containers and #currentDeliveryData.containers > 0 then
            TriggerServerEvent('containers:completeDelivery', 
                currentDeliveryData.orders[1].orderGroupId, 
                currentDeliveryData.restaurantId)
        end
        
        TriggerServerEvent('update:stockWithContainers', currentDeliveryData.restaurantId, currentDeliveryData.orders)
        
        -- Show completion summary
        showDeliveryCompletionSummary(deliveryTime, avgQuality, qualityBonus, handlingBonus)
        
        -- Cleanup
        cleanupDelivery()
    end
end

-- Show delivery completion summary
local function showDeliveryCompletionSummary(deliveryTime, avgQuality, qualityBonus, handlingBonus)
    local minutes = math.floor(deliveryTime / 60000)
    local seconds = math.floor((deliveryTime % 60000) / 1000)
    
    local qualityIcon = avgQuality >= 90 and "⭐" or avgQuality >= 70 and "✅" or "⚠️"
    local qualityLabel = avgQuality >= 90 and "Excellent" or avgQuality >= 70 and "Good" or "Fair"
    
    local bonusText = ""
    if qualityBonus > 0 or handlingBonus > 0 then
        bonusText = string.format("\n\n🎉 **Bonuses Earned:**\n%s%s",
            qualityBonus > 0 and string.format("📦 Quality Bonus: +$%d\n", qualityBonus) or "",
            handlingBonus > 0 and string.format("🚗 Handling Bonus: +$%d", handlingBonus) or ""
        )
    end
    
    lib.notify({
        title = '🎉 Delivery Complete!',
        description = string.format(
            '✅ **Delivery Successful**\n\n⏱️ Time: %dm %ds\n%s Avg Quality: **%.1f%%** (%s)\n🚗 Handling Score: **%d/100**%s',
            minutes, seconds,
            qualityIcon, avgQuality, qualityLabel,
            currentDeliveryData.handlingScore,
            bonusText
        ),
        type = 'success',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- Cleanup delivery state
local function cleanupDelivery()
    -- Stop quality tracking
    containerQualityThread = nil
    
    -- Remove blips
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    if vehicleBlip then
        RemoveBlip(vehicleBlip)
        vehicleBlip = nil
    end
    
    -- Clean up container blips
    for _, blip in pairs(containerTrackingBlips) do
        RemoveBlip(blip)
    end
    containerTrackingBlips = {}
    
    -- Delete vehicle after delay
    if currentDeliveryVehicle and DoesEntityExist(currentDeliveryVehicle) then
        Citizen.SetTimeout(30000, function() -- 30 second delay
            if DoesEntityExist(currentDeliveryVehicle) then
                DeleteVehicle(currentDeliveryVehicle)
            end
        end)
    end
    
    -- Reset state
    currentDeliveryVehicle = nil
    currentDeliveryData = nil
    deliveryStartTime = nil
end

-- ============================================
-- EXPORT FUNCTIONS
-- ============================================

-- Export for other scripts
exports('getCurrentDeliveryVehicle', function() return currentDeliveryVehicle end)
exports('getCurrentDeliveryData', function() return currentDeliveryData end)
exports('isOnDelivery', function() return currentDeliveryVehicle ~= nil end)

print("[CONTAINERS] Vehicle integration client loaded successfully!")