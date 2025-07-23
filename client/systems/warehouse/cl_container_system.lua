-- Advanced Container Client System

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Container state
local activeContainer = nil
local containerProp = nil
local qualityUpdateThread = nil
local temperatureAlertShown = false

-- Container rental menu
RegisterNetEvent(Constants.Events.Client.ShowContainerMenu)
AddEventHandler(Constants.Events.Client.ShowContainerMenu, function()
    OpenContainerRentalMenu()
end)

-- Open container rental menu
function OpenContainerRentalMenu()
    local options = {}
    
    -- Add container types
    for containerType, config in pairs(Config.Containers.types) do
        local hourlyRate = Config.Containers.rental.hourlyRates[containerType] or 10
        
        table.insert(options, {
            title = config.name,
            description = string.format("Capacity: %d items | Temperature: %d-%d°C", 
                config.capacity, 
                config.temperature.ideal.min, 
                config.temperature.ideal.max
            ),
            icon = "fas fa-cube",
            metadata = {
                {label = "Hourly Rate", value = "$" .. hourlyRate},
                {label = "Deposit", value = "$" .. config.deposit},
                {label = "Capacity", value = config.capacity .. " items"},
                {label = "Type", value = containerType:upper()}
            },
            onSelect = function()
                OpenRentalDurationMenu(containerType, config)
            end
        })
    end
    
    lib.registerContext({
        id = "container_rental_menu",
        title = "Container Rental Service",
        options = options
    })
    
    lib.showContext("container_rental_menu")
end

-- Rental duration menu
function OpenRentalDurationMenu(containerType, config)
    local hourlyRate = Config.Containers.rental.hourlyRates[containerType] or 10
    
    local options = {
        {
            title = "2 Hours",
            description = string.format("Cost: $%d + $%d deposit", hourlyRate * 2, config.deposit),
            icon = "fas fa-clock",
            onSelect = function()
                ConfirmRental(containerType, 2)
            end
        },
        {
            title = "4 Hours",
            description = string.format("Cost: $%d + $%d deposit", hourlyRate * 4, config.deposit),
            icon = "fas fa-clock",
            onSelect = function()
                ConfirmRental(containerType, 4)
            end
        },
        {
            title = "8 Hours (Full Day)",
            description = string.format("Cost: $%d + $%d deposit", hourlyRate * 8, config.deposit),
            icon = "fas fa-business-time",
            onSelect = function()
                ConfirmRental(containerType, 8)
            end
        },
        {
            title = "24 Hours",
            description = string.format("Cost: $%d + $%d deposit", hourlyRate * 24, config.deposit),
            icon = "fas fa-calendar-day",
            onSelect = function()
                ConfirmRental(containerType, 24)
            end
        }
    }
    
    -- Add bulk discount info
    local bulkDiscounts = Config.Containers.rental.bulkDiscounts
    if bulkDiscounts and #bulkDiscounts > 0 then
        table.insert(options, {
            title = "Bulk Discounts Available",
            description = "Rent multiple containers for discounts",
            icon = "fas fa-percentage",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "container_duration_menu",
        title = config.name .. " Rental",
        menu = "container_rental_menu",
        options = options
    })
    
    lib.showContext("container_duration_menu")
end

-- Confirm rental
function ConfirmRental(containerType, duration)
    local config = Config.Containers.types[containerType]
    local hourlyRate = Config.Containers.rental.hourlyRates[containerType] or 10
    local rentalCost = hourlyRate * duration
    local totalCost = rentalCost + config.deposit
    
    lib.registerContext({
        id = "container_rental_confirm",
        title = "Confirm Container Rental",
        options = {
            {
                title = config.name,
                description = string.format("Duration: %d hours", duration),
                icon = "fas fa-cube",
                disabled = true
            },
            {
                title = "Cost Breakdown",
                description = string.format("Rental: $%d | Deposit: $%d | Total: $%d", 
                    rentalCost, config.deposit, totalCost),
                icon = "fas fa-dollar-sign",
                disabled = true
            },
            {
                title = "Terms & Conditions",
                description = "Deposit refunded based on container condition at return",
                icon = "fas fa-file-contract",
                disabled = true
            },
            {
                title = "Confirm Rental",
                icon = "fas fa-check",
                onSelect = function()
                    TriggerServerEvent(Constants.Events.Server.RentContainer, containerType, duration)
                end
            },
            {
                title = "Cancel",
                icon = "fas fa-times",
                menu = "container_duration_menu"
            }
        }
    })
    
    lib.showContext("container_rental_confirm")
end

-- Container rented event
RegisterNetEvent("SupplyChain:Client:ContainerRented")
AddEventHandler("SupplyChain:Client:ContainerRented", function(data)
    activeContainer = data
    
    -- Show container HUD
    ShowContainerHUD()
    
    -- Start quality monitoring
    StartQualityMonitoring()
    
    -- Create container prop if needed
    if Config.Containers.types[data.containerType].model then
        SpawnContainerProp(data.containerType)
    end
    
    Framework.Notify(nil, "Container rented successfully! Check your HUD for status", "success")
end)

-- Show container HUD
function ShowContainerHUD()
    if not activeContainer then return end
    
    local config = activeContainer.config
    
    lib.showTextUI(string.format(
        "[Container] Type: %s | Quality: %d%% | Temp: Optimal",
        config.name,
        activeContainer.quality or 100
    ), {
        position = "top-right",
        icon = "fas fa-cube"
    })
end

-- Update container quality
RegisterNetEvent(Constants.Events.Client.UpdateContainerQuality)
AddEventHandler(Constants.Events.Client.UpdateContainerQuality, function(containerId, quality)
    if activeContainer and activeContainer.containerId == containerId then
        activeContainer.quality = quality
        
        -- Update HUD
        ShowContainerHUD()
        
        -- Show warning if quality is low
        local qualityStatus = Config.Containers.GetQualityStatus(quality)
        if qualityStatus.name == "Poor" or qualityStatus.name == "Damaged" then
            lib.notify({
                title = "Container Warning",
                description = string.format("Container quality is %s (%d%%)", qualityStatus.name, quality),
                type = "warning",
                duration = 5000
            })
        end
    end
end)

-- Container alert
RegisterNetEvent(Constants.Events.Client.ContainerAlert)
AddEventHandler(Constants.Events.Client.ContainerAlert, function(alert)
    -- Play alert sound
    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- Show notification based on severity
    local notifType = "inform"
    if alert.severity == "critical" then
        notifType = "error"
    elseif alert.severity == "major" then
        notifType = "warning"
    end
    
    lib.notify({
        title = "Container Alert",
        description = alert.message,
        type = notifType,
        duration = 8000,
        icon = alert.type == "temperature" and "fas fa-temperature-high" or "fas fa-exclamation-triangle"
    })
    
    -- Show persistent alert for critical issues
    if alert.severity == "critical" and not temperatureAlertShown then
        temperatureAlertShown = true
        lib.alertDialog({
            header = "Critical Container Alert",
            content = alert.message .. "\n\nImmediate action required to prevent product loss!",
            centered = true,
            cancel = false
        })
    end
end)

-- Start quality monitoring
function StartQualityMonitoring()
    if qualityUpdateThread then return end
    
    qualityUpdateThread = CreateThread(function()
        while activeContainer do
            Wait(30000) -- Update every 30 seconds
            
            -- Visual quality indicators
            if containerProp and DoesEntityExist(containerProp) then
                local quality = activeContainer.quality or 100
                
                -- Add visual effects based on quality
                if quality < 50 then
                    -- Add smoke/damage effect
                    if not HasNamedPtfxAssetLoaded("core") then
                        RequestNamedPtfxAsset("core")
                        while not HasNamedPtfxAssetLoaded("core") do
                            Wait(100)
                        end
                    end
                    
                    UseParticleFxAssetNextCall("core")
                    StartParticleFxLoopedOnEntity(
                        "ent_amb_smoke_general",
                        containerProp,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.5,
                        false, false, false
                    )
                end
            end
            
            -- Update HUD
            ShowContainerHUD()
        end
        
        qualityUpdateThread = nil
    end)
end

-- Spawn container prop
function SpawnContainerProp(containerType)
    local config = Config.Containers.types[containerType]
    if not config.model then return end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local spawnCoords = coords + forward * 2.0
    
    local model = GetHashKey(config.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end
    
    containerProp = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, true)
    PlaceObjectOnGroundProperly(containerProp)
    SetEntityAsMissionEntity(containerProp, true, true)
    
    -- Add interaction
    exports.ox_target:addLocalEntity(containerProp, {
        {
            label = "Check Container Status",
            icon = "fas fa-info-circle",
            onSelect = function()
                ShowContainerStatus()
            end
        },
        {
            label = "Load Container",
            icon = "fas fa-truck-loading",
            onSelect = function()
                LoadContainerIntoVehicle()
            end,
            canInteract = function()
                local vehicle = GetClosestVehicle(5.0)
                return vehicle ~= 0
            end
        },
        {
            label = "Return Container",
            icon = "fas fa-undo",
            onSelect = function()
                ReturnContainer()
            end
        }
    })
end

-- Show container status
function ShowContainerStatus()
    if not activeContainer then return end
    
    local config = activeContainer.config
    local quality = activeContainer.quality or 100
    local qualityStatus = Config.Containers.GetQualityStatus(quality)
    
    local content = string.format([[
        **Container Information**
        Type: %s
        ID: %s
        Quality: %d%% (%s)
        Temperature: Optimal
        
        **Features:**
    ]], config.name, activeContainer.containerId, quality, qualityStatus.name)
    
    -- Add features
    if config.features then
        for feature, enabled in pairs(config.features) do
            if enabled then
                content = content .. string.format("\n- %s", feature:gsub("_", " "):gsub("^%l", string.upper))
            end
        end
    end
    
    -- Add rental info
    local remainingTime = (activeContainer.startTime + activeContainer.duration) - GetGameTimer()
    if remainingTime > 0 then
        local hours = math.floor(remainingTime / 3600000)
        local minutes = math.floor((remainingTime % 3600000) / 60000)
        content = content .. string.format("\n\n**Rental Time Remaining:** %d hours %d minutes", hours, minutes)
    end
    
    lib.alertDialog({
        header = "Container Status",
        content = content,
        centered = true,
        cancel = true
    })
end

-- Load container into vehicle
function LoadContainerIntoVehicle()
    local vehicle = GetClosestVehicle(5.0)
    if vehicle == 0 then
        Framework.Notify(nil, "No vehicle nearby", "error")
        return
    end
    
    -- Progress bar
    if lib.progressBar({
        duration = 5000,
        label = "Loading container...",
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = "anim@heists@box_carry@",
            clip = "idle"
        }
    }) then
        -- Update container status
        TriggerServerEvent(Constants.Events.Server.UpdateContainerStatus, 
            activeContainer.containerId, 
            Constants.ContainerStatus.IN_TRANSIT,
            { vehicle = GetVehicleNumberPlateText(vehicle) }
        )
        
        -- Attach to vehicle (simplified)
        if DoesEntityExist(containerProp) then
            AttachEntityToEntity(containerProp, vehicle, 
                GetEntityBoneIndexByName(vehicle, "bodyshell"),
                0.0, -2.0, 0.5, 0.0, 0.0, 0.0,
                true, true, false, true, 1, true
            )
        end
        
        Framework.Notify(nil, "Container loaded onto vehicle", "success")
    end
end

-- Return container
function ReturnContainer()
    lib.registerContext({
        id = 'container_return_confirm',
        title = 'Return Container?',
        options = {
            {
                title = string.format('Current Quality: %d%%', activeContainer.quality or 100),
                disabled = true
            },
            {
                title = 'Yes, Return Container',
                icon = 'fas fa-check',
                onSelect = function()
                    if lib.progressBar({
                        duration = 3000,
                        label = "Returning container...",
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            move = true,
                            car = true,
                            combat = true
                        }
                    }) then
                        TriggerServerEvent(Constants.Events.Server.ReturnContainer, activeContainer.containerId)
                        
                        -- Cleanup
                        if DoesEntityExist(containerProp) then
                            DeleteObject(containerProp)
                            containerProp = nil
                        end
                        
                        activeContainer = nil
                        lib.hideTextUI()
                        temperatureAlertShown = false
                    end
                end
            },
            {
                title = 'Cancel',
                icon = 'fas fa-times'
            }
        }
    })
    
    lib.showContext('container_return_confirm')
end

-- Get closest vehicle
function GetClosestVehicle(radius)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = 0
    local closestDistance = radius or 5.0
    
    for _, vehicle in ipairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)
        
        if distance < closestDistance then
            closestDistance = distance
            closestVehicle = vehicle
        end
    end
    
    return closestVehicle
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    if DoesEntityExist(containerProp) then
        DeleteObject(containerProp)
    end
    
    lib.hideTextUI()
end)

-- Export container functions
exports('GetActiveContainer', function()
    return activeContainer
end)

exports('HasActiveContainer', function()
    return activeContainer ~= nil
end)