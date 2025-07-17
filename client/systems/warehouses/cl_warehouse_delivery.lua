-- ============================================
-- WAREHOUSE DELIVERY COORDINATION SYSTEM
-- Delivery tracking, completion, and van return
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- DELIVERY STATE MANAGEMENT
-- ============================================

-- Global delivery tracking variables
local deliveryState = {
    orderGroupId = nil,
    currentDeliveryData = {},
    deliveryStartTime = 0,
    deliveryBoxesRemaining = 0,
    totalDeliveryBoxes = 0,
    deliveryMarker = nil,
    isDeliveryActive = false
}

-- ============================================
-- DELIVERY INITIALIZATION SYSTEM
-- ============================================

-- Start Delivery with Enhanced Tracking
RegisterNetEvent("warehouse:startDelivery")
AddEventHandler("warehouse:startDelivery", function(restaurantId, van, orders)
    print("[DELIVERY] Starting enhanced delivery to restaurant:", restaurantId)
    
    if not DoesEntityExist(van) then
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found. Please restart the job."
        )
        return
    end
    
    -- Calculate total boxes needed for delivery
    local boxesNeeded, containersNeeded, totalItems = exports.ogz_supplychain:calculateDeliveryBoxes(orders)
    
    -- Initialize delivery state
    deliveryState.deliveryBoxesRemaining = boxesNeeded
    deliveryState.totalDeliveryBoxes = boxesNeeded
    deliveryState.isDeliveryActive = true
    deliveryState.currentDeliveryData = { 
        orderGroupId = orders[1] and orders[1].orderGroupId,
        restaurantId = restaurantId,
        startTime = GetGameTimer()
    }
    
    exports.ogz_supplychain:containerNotify(
        "Delivery Started",
        string.format("Drive to delivery location and deliver %d boxes", boxesNeeded)
    )

    local deliveryPosition = Config.Restaurants[restaurantId].delivery
    if not deliveryPosition then
        exports.ogz_supplychain:errorNotify(
            "Configuration Error",
            "No delivery position configured for this restaurant."
        )
        return
    end

    -- Set waypoint and create blip
    SetNewWaypoint(deliveryPosition.x, deliveryPosition.y)
    local blip = AddBlipForCoord(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location")
    EndTextCommandSetBlipName(blip)

    -- Monitor van arrival at delivery location
    TriggerEvent("warehouse:monitorDeliveryArrival", restaurantId, van, orders, deliveryPosition, blip)
end)

-- ============================================
-- DELIVERY ARRIVAL MONITORING
-- ============================================

-- Monitor van arrival at delivery location
RegisterNetEvent("warehouse:monitorDeliveryArrival")
AddEventHandler("warehouse:monitorDeliveryArrival", function(restaurantId, van, orders, deliveryPosition, blip)
    Citizen.CreateThread(function()
        local isTextUIShown = false
        
        while DoesEntityExist(van) and deliveryState.isDeliveryActive do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vector3(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z))
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    exports.ogz_supplychain:showTextUI("[E] Park Van & Start Delivery", "fas fa-parking")
                    isTextUIShown = true
                end
                
                if IsControlJustPressed(0, 38) then -- E key
                    if distance < 10.0 then
                        exports.ogz_supplychain:hideTextUI()
                        isTextUIShown = false
                        RemoveBlip(blip)
                        TriggerEvent("warehouse:setupDeliveryZone", restaurantId, van, orders)
                        break
                    else
                        exports.ogz_supplychain:errorNotify(
                            "Distance Error",
                            "Van is too far from the delivery zone."
                        )
                    end
                end
            else
                if isTextUIShown then
                    exports.ogz_supplychain:hideTextUI()
                    isTextUIShown = false
                end
            end
            
            Citizen.Wait(0)
        end
        
        if isTextUIShown then
            exports.ogz_supplychain:hideTextUI()
        end
        RemoveBlip(blip)
    end)
end)

-- ============================================
-- DELIVERY ZONE SETUP SYSTEM
-- ============================================

-- Setup Delivery Zone with Ground Marker
RegisterNetEvent("warehouse:setupDeliveryZone")
AddEventHandler("warehouse:setupDeliveryZone", function(restaurantId, van, orders)
    print("[DELIVERY] Setting up delivery zone with", deliveryState.deliveryBoxesRemaining, "boxes to deliver")
    
    local deliverBoxPosition = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].deliveryBox
    if not deliverBoxPosition then
        print("[ERROR] No deliveryBox position defined for restaurant " .. tostring(restaurantId))
        deliverBoxPosition = vector3(-1177.39, -890.98, 12.79) -- Fallback position
    end

    -- Start the delivery loop
    TriggerEvent("warehouse:startDeliveryLoop", restaurantId, van, orders, deliverBoxPosition)
end)

-- ============================================
-- DELIVERY LOOP MANAGEMENT
-- ============================================

-- Delivery Loop Handler
RegisterNetEvent("warehouse:startDeliveryLoop")
AddEventHandler("warehouse:startDeliveryLoop", function(restaurantId, van, orders, deliverBoxPosition)
    if deliveryState.deliveryBoxesRemaining <= 0 then
        -- All boxes delivered, complete delivery
        TriggerEvent("warehouse:completeDelivery", restaurantId, van, orders)
        return
    end
    
    exports.ogz_supplychain:systemNotify(
        "Delivery Progress",
        string.format("%d of %d boxes remaining", 
            deliveryState.deliveryBoxesRemaining, 
            deliveryState.totalDeliveryBoxes)
    )
    
    -- Start with grabbing box from van
    TriggerEvent("warehouse:grabBoxFromVan", restaurantId, van, orders, deliverBoxPosition)
end)

-- ============================================
-- VAN BOX GRABBING SYSTEM
-- ============================================

-- Enhanced Grab Box from Van
RegisterNetEvent("warehouse:grabBoxFromVan")
AddEventHandler("warehouse:grabBoxFromVan", function(restaurantId, van, orders, deliverBoxPosition)
    print("[DELIVERY] Setting up enhanced grab box from van")
    
    if not DoesEntityExist(van) then
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found."
        )
        return
    end

    local playerPed = PlayerPedId()
    local hasBox = false
    local boxProp = nil
    local vanTargetName = "van_grab_" .. tostring(van)
    local propName = Config.DeliveryProps.boxProp
    local model = GetHashKey(propName)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    -- Get item label for notification
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = "supplies"
    if orders and #orders > 0 then
        if orders[1].items and #orders[1].items > 0 then
            local itemKey = orders[1].items[1].itemName or "supplies"
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        elseif orders[1].itemName then
            local itemKey = orders[1].itemName
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        end
    end

    exports.ogz_supplychain:containerNotify(
        "Grab Box from Van",
        string.format("Get box %d/%d from van rear", 
            deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
            deliveryState.totalDeliveryBoxes)
    )

    -- Dynamic van target zone update
    local function updateGrabBoxZone()
        while DoesEntityExist(van) and not hasBox and deliveryState.isDeliveryActive do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            -- Remove and recreate zone for moving van
            exports.ogz_supplychain:removeZone(vanTargetName)
            
            local grabZone = exports.ogz_supplychain:createBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                name = vanTargetName,
                options = {
                    {
                        label = string.format("Grab Box (%d/%d)", 
                            deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
                            deliveryState.totalDeliveryBoxes),
                        icon = "fas fa-box",
                        onSelect = function()
                            if hasBox then
                                exports.ogz_supplychain:errorNotify(
                                    "Already Carrying",
                                    "You are already carrying a box."
                                )
                                return
                            end
                            
                            local success = exports.ogz_supplychain:showProgress({
                                duration = 3000,
                                label = string.format("Grabbing box %d/%d...", 
                                    deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
                                    deliveryState.totalDeliveryBoxes),
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            })
                            
                            if success then
                                -- Create box prop and attach to player
                                local playerCoords = GetEntityCoords(playerPed)
                                boxProp = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                                AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                                    0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                                hasBox = true
                                
                                -- Apply carrying animation
                                local animDict = "anim@heists@box_carry@"
                                RequestAnimDict(animDict)
                                while not HasAnimDictLoaded(animDict) do
                                    Citizen.Wait(0)
                                end
                                TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                                exports.ogz_supplychain:successNotify(
                                    "Box Grabbed",
                                    "Take it to the green delivery marker."
                                )

                                exports.ogz_supplychain:removeZone(vanTargetName)
                                TriggerEvent("warehouse:deliverBoxWithMarker", restaurantId, van, orders, boxProp, deliverBoxPosition)
                            end
                        end
                    }
                }
            })
            
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateGrabBoxZone)
end)

-- ============================================
-- BOX DELIVERY SYSTEM
-- ============================================

-- Enhanced Deliver Box with Ground Marker
RegisterNetEvent("warehouse:deliverBoxWithMarker")
AddEventHandler("warehouse:deliverBoxWithMarker", function(restaurantId, van, orders, boxProp, deliverBoxPosition)
    print("[DELIVERY] Setting up delivery with ground marker")
    
    if not boxProp or not DoesEntityExist(boxProp) then
        exports.ogz_supplychain:errorNotify(
            "Box Error",
            "You are not carrying a box."
        )
        return
    end

    local playerPed = PlayerPedId()
    local targetName = "delivery_zone_" .. restaurantId .. "_" .. tostring(GetGameTimer())

    -- Create delivery target zone
    local deliveryZone = exports.ogz_supplychain:createBoxZone({
        coords = vector3(deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z + 0.5),
        size = vector3(4.0, 4.0, 3.0),
        name = targetName,
        options = {
            {
                label = string.format("Deliver Box (%d/%d)", 
                    deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
                    deliveryState.totalDeliveryBoxes),
                icon = "fas fa-box",
                onSelect = function()
                    if not boxProp or not DoesEntityExist(boxProp) then
                        exports.ogz_supplychain:errorNotify(
                            "Box Error",
                            "You are not carrying a box."
                        )
                        return
                    end
                    
                    local success = exports.ogz_supplychain:showProgress({
                        duration = 3000,
                        label = string.format("Delivering box %d/%d...", 
                            deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
                            deliveryState.totalDeliveryBoxes),
                        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                    })
                    
                    if success then
                        -- Clean up box and animations
                        DeleteObject(boxProp)
                        ClearPedTasks(playerPed)
                        exports.ogz_supplychain:removeZone(targetName)
                        
                        -- Update delivery progress
                        deliveryState.deliveryBoxesRemaining = deliveryState.deliveryBoxesRemaining - 1
                        
                        if deliveryState.deliveryBoxesRemaining > 0 then
                            exports.ogz_supplychain:successNotify(
                                "Box Delivered",
                                string.format("%d boxes remaining. Get next box from van.", 
                                    deliveryState.deliveryBoxesRemaining)
                            )
                            
                            -- Continue delivery loop
                            TriggerEvent("warehouse:startDeliveryLoop", restaurantId, van, orders, deliverBoxPosition)
                        else
                            -- All boxes delivered - complete delivery
                            TriggerEvent("warehouse:completeDelivery", restaurantId, van, orders)
                        end
                    end
                end
            }
        }
    })

    exports.ogz_supplychain:containerNotify(
        "Delivery Zone Active",
        string.format("Drop Box %d/%d at business door", 
            deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining + 1, 
            deliveryState.totalDeliveryBoxes)
    )
end)

-- ============================================
-- DELIVERY COMPLETION SYSTEM
-- ============================================

-- Complete Delivery Handler - Stock Update Happens HERE
RegisterNetEvent("warehouse:completeDelivery")
AddEventHandler("warehouse:completeDelivery", function(restaurantId, van, orders)
    print("[DELIVERY] Completing delivery - all boxes delivered")
    
    -- Calculate delivery performance
    local deliveryEndTime = GetGameTimer()
    local totalDeliveryTime = math.floor((deliveryEndTime - deliveryState.currentDeliveryData.startTime) / 1000)
    
    -- Add delivery time to orders data for reward calculation
    for _, order in ipairs(orders) do
        order.deliveryTime = totalDeliveryTime
    end
    
    -- CRITICAL: Stock update happens immediately upon delivery completion
    TriggerServerEvent("update:stock", restaurantId, orders)
    
    -- Reset delivery state
    deliveryState.isDeliveryActive = false
    deliveryState.deliveryBoxesRemaining = 0
    
    exports.ogz_supplychain:achievementNotify(
        "🎉 All Boxes Delivered!",
        string.format("Successfully delivered all %d boxes! Stock updated immediately. Return the van to complete job.", 
            deliveryState.totalDeliveryBoxes)
    )
    
    -- Start van return process
    TriggerEvent("warehouse:returnTruck", van, restaurantId, orders)
end)

-- ============================================
-- VAN RETURN SYSTEM
-- ============================================

-- Return Van (Clean Van Return Only - Stock Already Updated)
RegisterNetEvent("warehouse:returnTruck")
AddEventHandler("warehouse:returnTruck", function(van, restaurantId, orders)
    print("[DELIVERY] Starting van return process")
    
    if not DoesEntityExist(van) then
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found."
        )
        return
    end

    exports.ogz_supplychain:containerNotify(
        "Delivery Complete",
        "Great Work! Stock has been delivered and updated. Return the van to finish."
    )

    local playerPed = PlayerPedId()
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig or not warehouseConfig.vehicle then
        exports.ogz_supplychain:errorNotify(
            "Configuration Error",
            "No warehouse vehicle return position configured."
        )
        return
    end
    
    local vanReturnPosition = vector3(
        warehouseConfig.vehicle.position.x, 
        warehouseConfig.vehicle.position.y, 
        warehouseConfig.vehicle.position.z
    )
    
    -- Set waypoint and create return blip
    SetNewWaypoint(vanReturnPosition.x, vanReturnPosition.y)
    local blip = AddBlipForCoord(vanReturnPosition.x, vanReturnPosition.y, vanReturnPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Van Return Location")
    EndTextCommandSetBlipName(blip)

    -- Monitor van return
    TriggerEvent("warehouse:monitorVanReturn", van, vanReturnPosition, blip)
end)

-- ============================================
-- VAN RETURN MONITORING
-- ============================================

-- Monitor van return to warehouse
RegisterNetEvent("warehouse:monitorVanReturn")
AddEventHandler("warehouse:monitorVanReturn", function(van, vanReturnPosition, blip)
    Citizen.CreateThread(function()
        local isTextUIShown = false
        
        while DoesEntityExist(van) do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vanReturnPosition)
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    exports.ogz_supplychain:showTextUI("[E] Return Van", "fas fa-parking")
                    isTextUIShown = true
                end
                
                if IsControlJustPressed(0, 38) then -- E key
                    local success = exports.ogz_supplychain:showProgress({
                        duration = 3000,
                        label = "Returning Van...",
                        anim = { dict = "anim@scripted@heist@ig3_button_press@male@", clip = "button_press" }
                    })
                    
                    if success then
                        exports.ogz_supplychain:hideTextUI()
                        isTextUIShown = false
                        
                        exports.ogz_supplychain:achievementNotify(
                            "Van Returned",
                            "Delivery job complete! Thank you for your excellent work!"
                        )
                        
                        RemoveBlip(blip)
                        DeleteVehicle(van)
                        
                        -- Reset all delivery state for next job
                        deliveryState = {
                            orderGroupId = nil,
                            currentDeliveryData = {},
                            deliveryStartTime = 0,
                            deliveryBoxesRemaining = 0,
                            totalDeliveryBoxes = 0,
                            deliveryMarker = nil,
                            isDeliveryActive = false
                        }
                        
                        break
                    end
                end
            else
                if isTextUIShown then
                    exports.ogz_supplychain:hideTextUI()
                    isTextUIShown = false
                end
            end
            
            Citizen.Wait(0)
        end
        
        if isTextUIShown then
            exports.ogz_supplychain:hideTextUI()
        end
        RemoveBlip(blip)
    end)
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('getDeliveryState', function() return deliveryState end)
exports('isDeliveryActive', function() return deliveryState.isDeliveryActive end)
exports('getDeliveryProgress', function() 
    return {
        remaining = deliveryState.deliveryBoxesRemaining,
        total = deliveryState.totalDeliveryBoxes,
        percentage = math.floor(((deliveryState.totalDeliveryBoxes - deliveryState.deliveryBoxesRemaining) / deliveryState.totalDeliveryBoxes) * 100)
    }
end)

print("[WAREHOUSE] Delivery coordination system loaded")