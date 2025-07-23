-- Advanced Container Management System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Container tracking
local activeContainers = {}
local containerRentals = {}
local qualityUpdateTimers = {}

-- Initialize container system
CreateThread(function()
    -- Load existing containers from database
    LoadContainers()
    
    -- Start quality monitoring
    StartQualityMonitoring()
    
    -- Start temperature monitoring
    if Config.Containers.temperatureMonitoring.enabled then
        StartTemperatureMonitoring()
    end
    
    print("^2[SupplyChain]^7 Container system initialized")
end)

-- Load containers from database
function LoadContainers()
    MySQL.Async.fetchAll('SELECT * FROM supply_containers WHERE status != ?', {
        Constants.ContainerStatus.RETIRED
    }, function(results)
        for _, container in ipairs(results) do
            activeContainers[container.container_id] = {
                id = container.container_id,
                type = container.type,
                status = container.status,
                quality = container.current_quality,
                location = container.location,
                lastUpdate = container.last_update
            }
        end
        
        print(string.format("^2[SupplyChain]^7 Loaded %d active containers", #results))
    end)
end

-- Rent container
RegisterNetEvent(Constants.Events.Server.RentContainer)
AddEventHandler(Constants.Events.Server.RentContainer, function(containerType, duration)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Check if player already has active rental
    if containerRentals[src] then
        Framework.Notify(src, "You already have an active container rental", "error")
        return
    end
    
    -- Get container config
    local containerConfig = Config.Containers.types[containerType]
    if not containerConfig then
        Framework.Notify(src, "Invalid container type", "error")
        return
    end
    
    -- Calculate cost
    local hourlyRate = Config.Containers.rental.hourlyRates[containerType] or 10
    local rentalCost = hourlyRate * duration
    local totalCost = rentalCost + containerConfig.deposit
    
    -- Check if player can afford
    if Framework.GetMoney(player, 'bank') < totalCost then
        Framework.Notify(src, string.format("Insufficient funds. Need $%d", totalCost), "error")
        return
    end
    
    -- Find available container
    local availableContainer = nil
    for containerId, container in pairs(activeContainers) do
        if container.type == containerType and container.status == Constants.ContainerStatus.AVAILABLE then
            availableContainer = container
            break
        end
    end
    
    if not availableContainer then
        -- Create new container
        local containerId = GenerateContainerId(containerType)
        
        MySQL.Async.insert([[
            INSERT INTO supply_containers (container_id, type, status, current_quality)
            VALUES (?, ?, ?, ?)
        ]], {
            containerId,
            containerType,
            Constants.ContainerStatus.RENTED,
            100
        }, function(insertId)
            if insertId then
                availableContainer = {
                    id = containerId,
                    type = containerType,
                    status = Constants.ContainerStatus.RENTED,
                    quality = 100
                }
                activeContainers[containerId] = availableContainer
            end
        end)
        
        -- Wait for insert
        Wait(100)
    end
    
    if not availableContainer then
        Framework.Notify(src, "No containers available", "error")
        return
    end
    
    -- Process payment
    Framework.RemoveMoney(player, 'bank', totalCost, 'Container rental')
    
    -- Create rental record
    MySQL.Async.insert([[
        INSERT INTO supply_container_rentals 
        (container_id, renter_id, rental_cost, deposit_amount)
        VALUES (?, ?, ?, ?)
    ]], {
        availableContainer.id,
        GetPlayerCitizenId(src),
        rentalCost,
        containerConfig.deposit
    })
    
    -- Update container status
    availableContainer.status = Constants.ContainerStatus.RENTED
    MySQL.Async.execute('UPDATE supply_containers SET status = ? WHERE container_id = ?', {
        Constants.ContainerStatus.RENTED,
        availableContainer.id
    })
    
    -- Track rental
    containerRentals[src] = {
        containerId = availableContainer.id,
        containerType = containerType,
        startTime = os.time(),
        duration = duration * 3600, -- Convert hours to seconds
        deposit = containerConfig.deposit,
        quality = 100
    }
    
    -- Start quality tracking
    StartQualityTracking(src, availableContainer.id)
    
    -- Send container data to client
    TriggerClientEvent("SupplyChain:Client:ContainerRented", src, {
        containerId = availableContainer.id,
        containerType = containerType,
        config = containerConfig,
        duration = duration
    })
    
    Framework.Notify(src, string.format("Container rented for %d hours. Total: $%d", duration, totalCost), "success")
end)

-- Return container
RegisterNetEvent(Constants.Events.Server.ReturnContainer)
AddEventHandler(Constants.Events.Server.ReturnContainer, function(containerId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    local rental = containerRentals[src]
    if not rental or rental.containerId ~= containerId then
        Framework.Notify(src, "No active rental found for this container", "error")
        return
    end
    
    -- Get container
    local container = activeContainers[containerId]
    if not container then
        Framework.Notify(src, "Container not found", "error")
        return
    end
    
    -- Calculate rental duration and fees
    local rentalDuration = os.time() - rental.startTime
    local lateFee = 0
    
    if rentalDuration > rental.duration then
        local lateHours = math.ceil((rentalDuration - rental.duration) / 3600)
        lateFee = lateHours * Config.Containers.rental.lateFees.feePerHour
        lateFee = math.min(lateFee, Config.Containers.rental.lateFees.maxFee)
    end
    
    -- Calculate deposit return based on quality
    local qualityPenalty = 0
    if container.quality < 90 then
        qualityPenalty = math.floor((100 - container.quality) * rental.deposit / 100)
    end
    
    local depositReturn = rental.deposit - qualityPenalty - lateFee
    
    -- Process return
    if depositReturn > 0 then
        Framework.AddMoney(player, 'bank', depositReturn, 'Container deposit return')
    end
    
    -- Update container status
    container.status = Constants.ContainerStatus.AVAILABLE
    MySQL.Async.execute('UPDATE supply_containers SET status = ? WHERE container_id = ?', {
        Constants.ContainerStatus.AVAILABLE,
        containerId
    })
    
    -- Update rental record
    MySQL.Async.execute([[
        UPDATE supply_container_rentals 
        SET rental_end = NOW(), deposit_returned = ?
        WHERE container_id = ? AND renter_id = ? AND rental_end IS NULL
    ]], {
        depositReturn > 0,
        containerId,
        GetPlayerCitizenId(src)
    })
    
    -- Stop quality tracking
    StopQualityTracking(src)
    
    -- Clear rental
    containerRentals[src] = nil
    
    -- Send summary
    local summary = string.format(
        "Container returned\nQuality: %d%%\nDeposit: $%d\nPenalties: $%d\nReturned: $%d",
        container.quality,
        rental.deposit,
        qualityPenalty + lateFee,
        depositReturn
    )
    
    Framework.Notify(src, summary, depositReturn > 0 and "success" or "warning")
    
    -- Log quality tracking
    LogContainerQuality(containerId, rental.quality, container.quality)
end)

-- Update container status
RegisterNetEvent(Constants.Events.Server.UpdateContainerStatus)
AddEventHandler(Constants.Events.Server.UpdateContainerStatus, function(containerId, status, data)
    local src = source
    local container = activeContainers[containerId]
    
    if not container then return end
    
    -- Verify ownership
    local rental = containerRentals[src]
    if not rental or rental.containerId ~= containerId then
        Framework.Notify(src, "You don't have access to this container", "error")
        return
    end
    
    -- Update status
    container.status = status
    
    -- Handle specific statuses
    if status == Constants.ContainerStatus.IN_TRANSIT then
        -- Start movement quality degradation
        StartMovementDegradation(containerId)
    elseif status == Constants.ContainerStatus.IN_USE then
        -- Stop movement degradation
        StopMovementDegradation(containerId)
    end
    
    -- Update database
    MySQL.Async.execute('UPDATE supply_containers SET status = ?, location = ? WHERE container_id = ?', {
        status,
        data and data.location or nil,
        containerId
    })
    
    -- Notify client
    TriggerClientEvent(Constants.Events.Client.UpdateContainerQuality, src, containerId, container.quality)
end)

-- Start quality monitoring
function StartQualityMonitoring()
    CreateThread(function()
        while true do
            Wait(60000) -- Check every minute
            
            for playerId, rental in pairs(containerRentals) do
                local container = activeContainers[rental.containerId]
                if container then
                    -- Calculate quality degradation
                    local degradation = CalculateQualityDegradation(container, rental)
                    
                    if degradation > 0 then
                        container.quality = math.max(0, container.quality - degradation)
                        
                        -- Update database
                        MySQL.Async.execute('UPDATE supply_containers SET current_quality = ? WHERE container_id = ?', {
                            container.quality,
                            container.id
                        })
                        
                        -- Notify player if significant drop
                        if degradation >= 5 then
                            TriggerClientEvent(Constants.Events.Client.UpdateContainerQuality, playerId, 
                                container.id, container.quality)
                        end
                        
                        -- Check for alerts
                        CheckQualityAlerts(playerId, container)
                    end
                end
            end
        end
    end)
end

-- Calculate quality degradation
function CalculateQualityDegradation(container, rental)
    local containerConfig = Config.Containers.types[container.type]
    if not containerConfig then return 0 end
    
    local degradation = 0
    local conditions = {}
    
    -- Base degradation
    degradation = containerConfig.degradation.baseRate / 60 -- Per minute
    
    -- Temperature check (simplified - would use weather API)
    local currentTemp = GetCurrentTemperature()
    if currentTemp < containerConfig.temperature.ideal.min or 
       currentTemp > containerConfig.temperature.ideal.max then
        conditions.outsideTemperature = true
        degradation = degradation * containerConfig.degradation.temperatureMultiplier
    end
    
    -- Movement check
    if container.status == Constants.ContainerStatus.IN_TRANSIT then
        conditions.inTransport = true
        degradation = degradation * containerConfig.degradation.movementMultiplier
    end
    
    -- Time elapsed
    conditions.timeElapsed = 60 -- 1 minute
    
    return Config.Containers.CalculateQualityLoss(container.type, container.quality, conditions)
end

-- Temperature monitoring
function StartTemperatureMonitoring()
    CreateThread(function()
        while true do
            Wait(Config.Containers.temperatureMonitoring.updateInterval * 1000)
            
            for playerId, rental in pairs(containerRentals) do
                local container = activeContainers[rental.containerId]
                if container then
                    local containerConfig = Config.Containers.types[container.type]
                    if containerConfig and containerConfig.degradation.powerRequired then
                        -- Check temperature breach
                        local currentTemp = GetCurrentTemperature()
                        local idealRange = containerConfig.temperature.ideal
                        
                        if currentTemp < idealRange.min or currentTemp > idealRange.max then
                            local deviation = math.min(
                                math.abs(currentTemp - idealRange.min),
                                math.abs(currentTemp - idealRange.max)
                            )
                            
                            -- Send temperature alert
                            for alertType, alert in pairs(Config.Containers.temperatureMonitoring.breachAlerts) do
                                if deviation >= alert.deviation then
                                    TriggerClientEvent(Constants.Events.Client.ContainerAlert, playerId, {
                                        containerId = container.id,
                                        type = "temperature",
                                        severity = alertType,
                                        message = string.format("Temperature breach: %d°C (ideal: %d-%d°C)", 
                                            currentTemp, idealRange.min, idealRange.max)
                                    })
                                    
                                    -- Log breach
                                    MySQL.Async.insert([[
                                        INSERT INTO supply_container_quality_tracking
                                        (container_id, temperature_breach, tracking_data)
                                        VALUES (?, ?, ?)
                                    ]], {
                                        container.id,
                                        true,
                                        json.encode({
                                            temperature = currentTemp,
                                            ideal = idealRange,
                                            deviation = deviation
                                        })
                                    })
                                    
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Quality tracking
function StartQualityTracking(playerId, containerId)
    qualityUpdateTimers[playerId] = containerId
end

function StopQualityTracking(playerId)
    qualityUpdateTimers[playerId] = nil
end

-- Check quality alerts
function CheckQualityAlerts(playerId, container)
    local qualityStatus = Config.Containers.GetQualityStatus(container.quality)
    
    if qualityStatus.name == "Poor" or qualityStatus.name == "Damaged" then
        TriggerClientEvent(Constants.Events.Client.ContainerAlert, playerId, {
            containerId = container.id,
            type = "quality",
            severity = qualityStatus.name == "Damaged" and "critical" or "major",
            message = string.format("Container quality is %s (%d%%)", qualityStatus.name, math.floor(container.quality or 100))
        })
    end
end

-- Log container quality
function LogContainerQuality(containerId, qualityBefore, qualityAfter)
    MySQL.Async.insert([[
        INSERT INTO supply_container_quality_tracking
        (container_id, quality_before, quality_after)
        VALUES (?, ?, ?)
    ]], {
        containerId,
        qualityBefore,
        qualityAfter
    })
end

-- Utility functions
function GenerateContainerId(containerType)
    return string.format("%s-%s-%d", 
        string.upper(string.sub(containerType, 1, 3)),
        os.date("%Y%m%d"),
        math.random(1000, 9999)
    )
end

function GetCurrentTemperature()
    -- This would integrate with weather system
    -- For now, return a random temperature
    local hour = os.date("*t").hour
    local baseTemp = 20
    
    -- Simulate day/night temperature variation
    if hour >= 6 and hour <= 18 then
        baseTemp = baseTemp + math.random(0, 10)
    else
        baseTemp = baseTemp - math.random(0, 5)
    end
    
    return baseTemp
end

function GetPlayerCitizenId(playerId)
    local player = Framework.GetPlayer(playerId)
    if player then
        if Framework.Type == 'qbcore' then
            return player.PlayerData.citizenid
        else
            return player.citizenid
        end
    end
    return nil
end

-- Movement degradation
local movementTimers = {}

function StartMovementDegradation(containerId)
    if movementTimers[containerId] then return end
    
    movementTimers[containerId] = CreateThread(function()
        while activeContainers[containerId] and 
              activeContainers[containerId].status == Constants.ContainerStatus.IN_TRANSIT do
            Wait(30000) -- Every 30 seconds
            
            local container = activeContainers[containerId]
            if container then
                -- Apply movement degradation
                local containerConfig = Config.Containers.types[container.type]
                if containerConfig then
                    local degradation = containerConfig.degradation.baseRate * 
                                      containerConfig.degradation.movementMultiplier * 0.5
                    
                    container.quality = math.max(0, container.quality - degradation)
                    
                    -- Update database
                    MySQL.Async.execute('UPDATE supply_containers SET current_quality = ? WHERE container_id = ?', {
                        container.quality,
                        container.id
                    })
                end
            end
        end
        
        movementTimers[containerId] = nil
    end)
end

function StopMovementDegradation(containerId)
    if movementTimers[containerId] then
        -- Thread will stop on next iteration
        movementTimers[containerId] = nil
    end
end

-- Export container functions
exports('GetActiveContainer', function(containerId)
    return activeContainers[containerId]
end)

exports('GetPlayerRental', function(playerId)
    return containerRentals[playerId]
end)

exports('GetContainerQuality', function(containerId)
    local container = activeContainers[containerId]
    return container and container.quality or 0
end)