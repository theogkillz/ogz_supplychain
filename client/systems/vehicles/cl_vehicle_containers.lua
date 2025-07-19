-- ============================================
-- VEHICLE CONTAINER SYSTEM - CLIENT LOGIC
-- Container loading and quality tracking during delivery
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']

-- Client state management
local currentDeliveryData = {
    vehicle = nil,
    containers = {},
    containerStates = {},
    handlingScore = 100,
    temperatureBreaches = 0,
    restaurantId = nil,
    qualityMonitoringActive = false
}

local deliveryBlips = {}
local deliveryRoute = nil
local qualityMonitoringThread = nil

-- Show quality warning (MUST BE FIRST - called by others)
local function showQualityWarning(message)
    lib.notify({
        title = '⚠️ Quality Warning',
        description = message,
        type = 'warning',
        duration = 6000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Check if vehicle is on fire (MUST BE SECOND - called by others)
local function IsVehicleOnFire(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return IsEntityOnFire(vehicle)
end

-- Show container quality alert (MUST BE THIRD - called by others)
local function showContainerQualityAlert(message)
    lib.notify({
        title = '📦 Container Alert',
        description = message,
        type = 'error',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Check driving behavior and update quality (NOW SAFE - dependencies above)
local function checkDrivingBehavior(vehicle)
    if not DoesEntityExist(vehicle) or not currentDeliveryData then return end
    
    local playerPed = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(playerPed, false)
    
    if currentVehicle ~= vehicle then return end
    
    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
    local maxSpeed = GetVehicleMaxSpeed(vehicle) * 3.6
    local speedPercentage = speed / maxSpeed
    
    -- Check for harsh driving
    if speedPercentage > 0.8 then
        if currentDeliveryData.handlingScore then
            currentDeliveryData.handlingScore = math.max(0, currentDeliveryData.handlingScore - 0.5)
        end
    end
    
    -- Check for sudden stops/accelerations
    local acceleration = GetVehicleAcceleration(vehicle)
    if math.abs(acceleration) > 5.0 then
        if currentDeliveryData.temperatureBreaches then
            currentDeliveryData.temperatureBreaches = currentDeliveryData.temperatureBreaches + 1
        end
        
        if currentDeliveryData.temperatureBreaches and currentDeliveryData.temperatureBreaches > 3 then
            showQualityWarning("Rough handling detected! Container quality may be affected.")
        end
    end
end

-- Check vehicle condition (NOW SAFE - dependencies above)
local function checkVehicleCondition(vehicle)
    if not DoesEntityExist(vehicle) or not currentDeliveryData then return end
    
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    -- Check for vehicle damage
    if engineHealth < 800 or bodyHealth < 800 then
        if currentDeliveryData.temperatureBreaches then
            currentDeliveryData.temperatureBreaches = currentDeliveryData.temperatureBreaches + 1
        end
    end
    
    -- Check for fire
    if IsVehicleOnFire(vehicle) then
        if currentDeliveryData.containers then
            for _, container in ipairs(currentDeliveryData.containers) do
                if currentDeliveryData.containerStates and currentDeliveryData.containerStates[container.container_id] then
                    currentDeliveryData.containerStates[container.container_id].quality = 0
                end
            end
        end
        
        showContainerQualityAlert("🚨 Vehicle fire! All containers destroyed!")
    end
end

-- Update container quality based on conditions (NOW SAFE - dependencies above)
local function updateContainerQuality()
    if not currentDeliveryData or not currentDeliveryData.containerStates then return end
    
    for containerId, state in pairs(currentDeliveryData.containerStates) do
        local qualityLoss = 0
        
        -- Time-based degradation
        local currentTime = GetGameTimer()
        local timeSinceLastCheck = currentTime - state.lastCheck
        local minutesPassed = timeSinceLastCheck / (1000 * 60)
        
        qualityLoss = qualityLoss + (minutesPassed * 0.1) -- 0.1% per minute
        
        -- Handling-based degradation
        if currentDeliveryData.handlingScore and currentDeliveryData.handlingScore < 80 then
            qualityLoss = qualityLoss + 0.5
        end
        
        -- Temperature breach penalties
        if currentDeliveryData.temperatureBreaches and currentDeliveryData.temperatureBreaches > 0 then
            qualityLoss = qualityLoss + (currentDeliveryData.temperatureBreaches * 0.2)
        end
        
        -- Apply quality loss
        state.quality = math.max(0, state.quality - qualityLoss)
        state.lastCheck = currentTime
        
        -- Show warnings for low quality
        if state.quality < 30 and state.quality > 25 then
            showContainerQualityAlert(string.format("Container %s quality critical: %.1f%%", containerId, state.quality))
        elseif state.quality < 50 and state.quality > 45 then
            showContainerQualityAlert(string.format("Container %s quality low: %.1f%%", containerId, state.quality))
        end
    end
end

-- Update container quality based on conditions
local function updateContainerQuality()
    if not currentDeliveryData or not currentDeliveryData.containerStates then return end
    
    for containerId, state in pairs(currentDeliveryData.containerStates) do
        local qualityLoss = 0
        
        -- Time-based degradation
        local currentTime = GetGameTimer()
        local timeSinceLastCheck = currentTime - state.lastCheck
        local minutesPassed = timeSinceLastCheck / (1000 * 60)
        
        qualityLoss = qualityLoss + (minutesPassed * 0.1) -- 0.1% per minute
        
        -- Handling-based degradation
        if currentDeliveryData.handlingScore and currentDeliveryData.handlingScore < 80 then
            qualityLoss = qualityLoss + 0.5
        end
        
        -- Temperature breach penalties
        if currentDeliveryData.temperatureBreaches and currentDeliveryData.temperatureBreaches > 0 then
            qualityLoss = qualityLoss + (currentDeliveryData.temperatureBreaches * 0.2)
        end
        
        -- Apply quality loss
        state.quality = math.max(0, state.quality - qualityLoss)
        state.lastCheck = currentTime
        
        -- Show warnings for low quality
        if state.quality < 30 and state.quality > 25 then
            showContainerQualityAlert(string.format("Container %s quality critical: %.1f%%", containerId, state.quality))
        elseif state.quality < 50 and state.quality > 45 then
            showContainerQualityAlert(string.format("Container %s quality low: %.1f%%", containerId, state.quality))
        end
    end
end

-- ============================================
-- MISSING FUNCTION DEFINITIONS
-- ============================================

-- Find optimal spawn location for vehicle
local function findOptimalSpawnLocation(playerCoords)
    local spawnOffset = 5.0
    local testCoords = {
        vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x - spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y + spawnOffset, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y - spawnOffset, playerCoords.z, 0.0)
    }
    
    for _, coords in ipairs(testCoords) do
        local groundZ = coords.z
        local foundGround, groundCoords = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
        
        if foundGround then
            return vector4(coords.x, coords.y, groundCoords, 0.0)
        end
    end
    
    return vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0)
end

-- Calculate total boxes needed for orders
local function calculateTotalBoxes(orders, containers)
    local totalItems = 0
    
    if orders then
        for _, order in ipairs(orders) do
            totalItems = totalItems + (order.quantity or 0)
        end
    end
    
    if containers then
        for _, container in ipairs(containers) do
            totalItems = totalItems + (container.contents_amount or 0)
        end
    end
    
    return math.ceil(totalItems / 12), totalItems
end

-- Determine appropriate vehicle model based on load
local function determineVehicleModel(totalBoxes, containers, achievementTier)
    local vehicleModel = "speedo"
    
    if totalBoxes <= 2 then
        vehicleModel = "pony"
    elseif totalBoxes <= 5 then
        vehicleModel = "speedo"
    elseif totalBoxes <= 10 then
        vehicleModel = "mule"
    else
        vehicleModel = "mule3"
    end
    
    return vehicleModel
end

-- Setup delivery vehicle with standard configurations
local function setupDeliveryVehicle(vehicle, vehicleModel)
    if not DoesEntityExist(vehicle) then return end
    
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleEngineOn(vehicle, true, true, false)
    
    if exports['LegacyFuel'] then
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    end
    
    if exports['qb-vehiclekeys'] then
        exports['qb-vehiclekeys']:GiveKeys(GetVehicleNumberPlateText(vehicle))
    end
end

-- Create vehicle blip for delivery
local function createVehicleBlip(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 477)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Vehicle")
    EndTextCommandSetBlipName(blip)
    
    return blip
end

-- Setup container monitoring system
local function setupContainerMonitoring(vehicle, containers)
    if not currentDeliveryData then return end
    
    currentDeliveryData.vehicle = vehicle
    currentDeliveryData.containers = containers or {}
    currentDeliveryData.containerStates = {}
    
    for _, container in ipairs(currentDeliveryData.containers) do
        currentDeliveryData.containerStates[container.container_id] = {
            quality = container.quality_level or 100,
            temperature = 20, -- Celsius
            lastCheck = GetGameTimer()
        }
    end
end

-- Start container quality tracking
local function startContainerQualityTracking(vehicle)
    if qualityMonitoringThread then return end
    
    currentDeliveryData.qualityMonitoringActive = true
    
    qualityMonitoringThread = Citizen.CreateThread(function()
        while currentDeliveryData.qualityMonitoringActive and DoesEntityExist(vehicle) do
            checkDrivingBehavior(vehicle)
            checkVehicleCondition(vehicle)
            updateContainerQuality()
            
            Citizen.Wait(5000) -- Check every 5 seconds
        end
        
        qualityMonitoringThread = nil
    end)
end

-- Show loading instructions to player
local function showLoadingInstructions(containerCount)
    lib.notify({
        title = '📦 Container Loading',
        description = string.format('Loading %d containers into vehicle. Drive carefully to maintain quality!', containerCount),
        type = 'info',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Start vehicle loading process
local function startVehicleLoading(vehicle, containers)
    local playerPed = PlayerPedId()
    
    lib.progressBar({
        duration = 3000 + (#containers * 1000), -- 3 seconds + 1 second per container
        position = 'bottom',
        label = 'Loading containers...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })
    
    setupContainerMonitoring(vehicle, containers)
    showLoadingInstructions(#containers)
    startContainerQualityTracking(vehicle)
end

-- Check if area is clear for vehicle spawn
local function IsAreaClear(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance < radius then
                return false
            end
        end
    end
    
    return true
end

-- Show quality warning
local function showQualityWarning(message)
    lib.notify({
        title = '⚠️ Quality Warning',
        description = message,
        type = 'warning',
        duration = 6000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Show container quality alert
local function showContainerQualityAlert(message)
    lib.notify({
        title = '📦 Container Alert',
        description = message,
        type = 'error',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Check if vehicle is on fire
local function IsVehicleOnFire(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return IsEntityOnFire(vehicle)
end

-- Create delivery blip
local function createDeliveryBlip(restaurantId)
    if not Config.Restaurants or not Config.Restaurants[restaurantId] then return nil end
    
    local restaurant = Config.Restaurants[restaurantId]
    local blip = AddBlipForCoord(restaurant.position.x, restaurant.position.y, restaurant.position.z)
    
    SetBlipSprite(blip, 478)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 2)
    SetBlipRoute(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Destination")
    EndTextCommandSetBlipName(blip)
    
    return blip
end

-- Set delivery route
local function setDeliveryRoute(restaurantId)
    if not Config.Restaurants or not Config.Restaurants[restaurantId] then return end
    
    local restaurant = Config.Restaurants[restaurantId]
    local blip = createDeliveryBlip(restaurantId)
    
    if blip then
        table.insert(deliveryBlips, blip)
    end
    
    lib.notify({
        title = '🗺️ Route Set',
        description = 'Follow the GPS route to ' .. (restaurant.name or 'the restaurant'),
        type = 'info',
        duration = 5000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Start delivery tracking
local function startDeliveryTracking(vehicle)
    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()
        
        while currentDeliveryData.qualityMonitoringActive and DoesEntityExist(vehicle) do
            local currentVehicle = GetVehiclePedIsIn(playerPed, false)
            
            if currentVehicle == vehicle then
                -- Update GPS and tracking here
            end
            
            Citizen.Wait(1000)
        end
    end)
end

-- Show delivery prompt
local function showDeliveryPrompt(restaurantId)
    lib.notify({
        title = '📦 Delivery Available',
        description = 'Press [E] to complete delivery',
        type = 'info',
        duration = 5000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Complete delivery
local function completeDelivery(restaurantId)
    if not currentDeliveryData then return end
    
    TriggerServerEvent('containers:completeDelivery', 'delivery_group', restaurantId)
    
    lib.notify({
        title = '✅ Delivery Complete',
        description = 'Containers delivered successfully!',
        type = 'success',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- Show delivery completion summary
local function showDeliveryCompletionSummary(qualityData, paymentInfo)
    local averageQuality = 0
    local containerCount = 0
    
    if currentDeliveryData and currentDeliveryData.containerStates then
        for _, state in pairs(currentDeliveryData.containerStates) do
            averageQuality = averageQuality + state.quality
            containerCount = containerCount + 1
        end
        
        if containerCount > 0 then
            averageQuality = averageQuality / containerCount
        end
    end
    
    lib.alertDialog({
        header = '📦 Delivery Summary',
        content = string.format(
            '**Delivery Completed!**\n\n• Containers Delivered: %d\n• Average Quality: %.1f%%\n• Handling Score: %.1f%%\n• Temperature Breaches: %d\n\nGreat work!',
            containerCount,
            averageQuality,
            currentDeliveryData.handlingScore or 100,
            currentDeliveryData.temperatureBreaches or 0
        ),
        centered = true,
        cancel = true
    })
end

-- Cleanup delivery
local function cleanupDelivery()
    -- Stop quality monitoring
    if qualityMonitoringThread then
        currentDeliveryData.qualityMonitoringActive = false
        qualityMonitoringThread = nil
    end
    
    -- Remove blips
    for _, blip in ipairs(deliveryBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    deliveryBlips = {}
    
    -- Reset delivery data
    currentDeliveryData = {
        vehicle = nil,
        containers = {},
        containerStates = {},
        handlingScore = 100,
        temperatureBreaches = 0,
        restaurantId = nil,
        qualityMonitoringActive = false
    }
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Load containers with enhanced vehicle system
RegisterNetEvent("containers:loadVehicleWithContainers")
AddEventHandler("containers:loadVehicleWithContainers", function(restaurantId, containers)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Determine vehicle based on container count
    local totalBoxes = calculateTotalBoxes(nil, containers)
    local vehicleModel = determineVehicleModel(totalBoxes, containers, "standard")
    
    -- Find spawn location
    local spawnCoords = findOptimalSpawnLocation(playerCoords)
    
    -- Check if area is clear
    if not IsAreaClear(vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z), 5.0) then
        lib.notify({
            title = 'Spawn Blocked',
            description = 'Clear the area around you before spawning delivery vehicle',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    -- Spawn vehicle
    lib.requestModel(vehicleModel, 10000)
    local vehicle = CreateVehicle(GetHashKey(vehicleModel), spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    
    if DoesEntityExist(vehicle) then
        setupDeliveryVehicle(vehicle, vehicleModel)
        
        -- Create vehicle blip
        local vehicleBlip = createVehicleBlip(vehicle)
        if vehicleBlip then
            table.insert(deliveryBlips, vehicleBlip)
        end
        
        -- Start container loading process
        startVehicleLoading(vehicle, containers)
        
        -- Set delivery route
        if currentDeliveryData then
            currentDeliveryData.restaurantId = restaurantId
        end
        
        createDeliveryBlip(restaurantId)
        setDeliveryRoute(restaurantId)
        
        -- Start delivery tracking
        startDeliveryTracking(vehicle)
        
        lib.notify({
            title = '🚛 Vehicle Ready',
            description = string.format('Delivery vehicle loaded with %d containers. Follow GPS to destination.', #containers),
            type = 'success',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    end
end)

-- Delivery zone detection
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 and currentDeliveryData and currentDeliveryData.qualityMonitoringActive then
            if currentDeliveryData.restaurantId and Config.Restaurants and Config.Restaurants[currentDeliveryData.restaurantId] then
                local restaurant = Config.Restaurants[currentDeliveryData.restaurantId]
                local distance = #(playerCoords - restaurant.position)
                
                if distance < 10.0 then
                    showDeliveryPrompt(currentDeliveryData.restaurantId)
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        completeDelivery(currentDeliveryData.restaurantId)
                    end
                end
            end
        end
        
        Citizen.Wait(500)
    end
end)

-- Container delivery completion
RegisterNetEvent('containers:deliveryCompleted')
AddEventHandler('containers:deliveryCompleted', function(qualityData, paymentInfo)
    showDeliveryCompletionSummary(qualityData, paymentInfo)
    
    Citizen.SetTimeout(3000, function()
        cleanupDelivery()
    end)
end)

-- Container quality update from server
RegisterNetEvent('containers:updateQuality')
AddEventHandler('containers:updateQuality', function(containerId, newQuality)
    if currentDeliveryData and currentDeliveryData.containerStates and currentDeliveryData.containerStates[containerId] then
        currentDeliveryData.containerStates[containerId].quality = newQuality
    end
end)

-- ============================================
-- CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        cleanupDelivery()
    end
end)

-- Export functions
exports('startContainerDelivery', function(restaurantId, containers)
    TriggerEvent("containers:loadVehicleWithContainers", restaurantId, containers)
end)

print("[CONTAINERS] Vehicle container system loaded")