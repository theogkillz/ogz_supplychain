-- client/systems/warehouse/cl_warehouse_unloading.lua
-- Warehouse Unloading and Delivery Completion

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Unloading state
local unloadedBoxes = 0
local isUnloading = false

-- Start unloading phase
RegisterNetEvent("SupplyChain:Client:StartUnloading")
AddEventHandler("SupplyChain:Client:StartUnloading", function(restaurantId, van, orders)
    if not DoesEntityExist(van) then
        Framework.Notify(nil, "Delivery van not found", "error")
        return
    end
    
    isUnloading = true
    unloadedBoxes = 0
    
    Framework.Notify(nil, "Grab boxes from the van and deliver them to the restaurant", "info")
    
    -- Create van unloading zone
    CreateVanUnloadingZone(van, restaurantId, orders)
end)

-- Create van unloading zone
function CreateVanUnloadingZone(van, restaurantId, orders)
    local vanTargetName = "van_unload_" .. GetGameTimer()
    local hasBox = false
    local boxProp = nil
    
    CreateThread(function()
        while DoesEntityExist(van) and unloadedBoxes < Config.Warehouse.requiredBoxesPerDelivery do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            
            -- Calculate rear position
            local vanRear = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )
            
            -- Remove and recreate zone
            exports.ox_target:removeZone(vanTargetName)
            
            if not hasBox then
                exports.ox_target:addBoxZone({
                    coords = vanRear,
                    size = vector3(3.0, 3.0, 2.0),
                    rotation = vanHeading,
                    debug = Config.Debug.showZones,
                    name = vanTargetName,
                    options = {
                        {
                            label = "Grab Box from Van",
                            icon = "fas fa-box",
                            onSelect = function()
                                GrabBoxFromVan(orders, function(prop)
                                    hasBox = true
                                    boxProp = prop
                                    CreateDeliveryZone(restaurantId, van, orders, boxProp, function()
                                        hasBox = false
                                        boxProp = nil
                                    end)
                                end)
                            end
                        }
                    }
                })
            end
            
            -- Draw marker
            DrawMarker(1, vanRear.x, vanRear.y, vanRear.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                3.0, 3.0, 0.5, 255, 255, 0, 100, false, true, 2, false, nil, nil, false)
            
            Wait(1000)
        end
        
        -- Cleanup
        exports.ox_target:removeZone(vanTargetName)
    end)
end

-- Grab box from van
function GrabBoxFromVan(orders, callback)
    local playerPed = PlayerPedId()
    
    -- Get item info
    local itemNames = exports.ox_inventory:Items() or {}
    local currentItem = orders[unloadedBoxes + 1]
    local itemLabel = currentItem and itemNames[currentItem.itemName] and itemNames[currentItem.itemName].label or "item"
    
    -- Progress bar
    if lib.progressBar({
        duration = 3000,
        label = string.format("Grabbing %s...", itemLabel),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        },
        anim = {
            dict = Constants.Animations.Carry.dict,
            clip = Constants.Animations.Carry.anim
        }
    }) then
        -- Create carry prop
        local coords = GetEntityCoords(playerPed)
        local model = GetHashKey(Config.Warehouse.carryBoxProp)
        
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(100)
        end
        
        local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, 57005),
            0.12, 0.05, 0.1, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
        
        -- Play carry animation
        RequestAnimDict(Constants.Animations.Carry.dict)
        while not HasAnimDictLoaded(Constants.Animations.Carry.dict) do
            Wait(0)
        end
        TaskPlayAnim(playerPed, Constants.Animations.Carry.dict, Constants.Animations.Carry.anim, 
            8.0, -8.0, -1, 50, 0, false, false, false)
        
        Framework.Notify(nil, string.format("%s grabbed. Deliver to the restaurant", itemLabel), "success")
        
        -- Update status
        TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress,
            orders[1].orderGroupId or "unknown",
            Constants.DeliveryStatus.UNLOADING,
            { unloadedBoxes = unloadedBoxes }
        )
        
        callback(prop)
    end
end

-- Create delivery zone at restaurant
function CreateDeliveryZone(restaurantId, van, orders, boxProp, callback)
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then return end
    
    local deliveryPos = restaurant.deliveryBox
    local targetName = "delivery_zone_" .. GetGameTimer()
    
    -- Create blip
    local blip = AddBlipForCoord(deliveryPos.x, deliveryPos.y, deliveryPos.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, Constants.BlipColors.Yellow)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Point")
    EndTextCommandSetBlipName(blip)
    
    -- Create target zone
    exports.ox_target:addBoxZone({
        coords = vector3(deliveryPos.x, deliveryPos.y, deliveryPos.z + 0.5),
        size = vector3(3.0, 3.0, 3.0),
        rotation = 0,
        debug = Config.Debug.showZones,
        name = targetName,
        options = {
            {
                label = "Deliver Box",
                icon = "fas fa-box",
                onSelect = function()
                    DeliverBox(orders, boxProp, function()
                        -- Cleanup
                        RemoveBlip(blip)
                        exports.ox_target:removeZone(targetName)
                        
                        unloadedBoxes = unloadedBoxes + 1
                        
                        if unloadedBoxes >= Config.Warehouse.requiredBoxesPerDelivery then
                            CompleteDelivery(van, restaurantId, orders)
                        else
                            Framework.Notify(nil, string.format("%d boxes delivered. %d remaining", 
                                unloadedBoxes, Config.Warehouse.requiredBoxesPerDelivery - unloadedBoxes), "info")
                        end
                        
                        callback()
                    end)
                end,
                canInteract = function()
                    return DoesEntityExist(boxProp)
                end
            }
        }
    })
    
    -- Draw marker thread
    CreateThread(function()
        while unloadedBoxes < Config.Warehouse.requiredBoxesPerDelivery and DoesEntityExist(boxProp) do
            DrawMarker(1, deliveryPos.x, deliveryPos.y, deliveryPos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                3.0, 3.0, 0.5, 255, 255, 0, 100, false, true, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end

-- Deliver individual box
function DeliverBox(orders, boxProp, callback)
    if not DoesEntityExist(boxProp) then
        Framework.Notify(nil, "You are not carrying a box", "error")
        return
    end
    
    local playerPed = PlayerPedId()
    
    -- Get item info
    local itemNames = exports.ox_inventory:Items() or {}
    local currentItem = orders[unloadedBoxes + 1]
    local itemLabel = currentItem and itemNames[currentItem.itemName] and itemNames[currentItem.itemName].label or "item"
    
    -- Progress bar
    if lib.progressBar({
        duration = 3000,
        label = string.format("Delivering %s...", itemLabel),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        },
        anim = {
            dict = Constants.Animations.Carry.dict,
            clip = Constants.Animations.Carry.anim
        }
    }) then
        -- Delete box
        if DoesEntityExist(boxProp) then
            DeleteObject(boxProp)
        end
        
        ClearPedTasks(playerPed)
        
        -- Update restaurant stock
        TriggerServerEvent("SupplyChain:Server:UpdateRestaurantStock", 
            currentItem.restaurantId or restaurantId,
            currentItem.itemName,
            currentItem.quantity
        )
        
        Framework.Notify(nil, string.format("%s delivered successfully!", itemLabel), "success")
        
        callback()
    end
end

-- Complete delivery
function CompleteDelivery(van, restaurantId, orders)
    isUnloading = false
    
    lib.alertDialog({
        header = "Delivery Complete",
        content = "Great work! Return the van to the warehouse to complete the job.",
        centered = true,
        cancel = false
    })
    
    -- Create return waypoint
    local warehouse = Config.Warehouses[1]
    if warehouse and warehouse.vehicle then
        local returnPos = warehouse.vehicle.position
        SetNewWaypoint(returnPos.x, returnPos.y)
        
        -- Create return blip
        local blip = AddBlipForCoord(returnPos.x, returnPos.y, returnPos.z)
        SetBlipSprite(blip, 1)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, Constants.BlipColors.Blue)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Return Van")
        EndTextCommandSetBlipName(blip)
        
        -- Monitor van return
        CreateThread(function()
            local isTextUIShown = false
            
            while DoesEntityExist(van) do
                local playerPed = PlayerPedId()
                local vanPos = GetEntityCoords(van)
                local distance = #(vanPos - returnPos)
                
                if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                    if not isTextUIShown then
                        lib.showTextUI("[E] Return Van", {
                            icon = "fas fa-parking"
                        })
                        isTextUIShown = true
                    end
                    
                    -- Draw marker
                    DrawMarker(1, returnPos.x, returnPos.y, returnPos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        5.0, 5.0, 0.5, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                    
                    if IsControlJustPressed(0, Constants.Keys.INTERACT) then
                        if lib.progressBar({
                            duration = 3000,
                            label = "Returning Van...",
                            position = 'bottom',
                            useWhileDead = false,
                            canCancel = false,
                            disable = {
                                move = true,
                                car = true,
                                combat = true,
                                sprint = true
                            },
                            anim = {
                                dict = Constants.Animations.Repair.dict,
                                clip = Constants.Animations.Repair.anim
                            }
                        }) then
                            lib.hideTextUI()
                            RemoveBlip(blip)
                            
                            -- Complete delivery
                            local Warehouse = exports['ogz_supplychain']:GetWarehouseFunctions()
                            Warehouse.CompleteDelivery()
                            
                            -- Delete van
                            DeleteVehicle(van)
                            
                            lib.alertDialog({
                                header = "Job Complete!",
                                content = "Thank you for your hard work! Your payment has been processed.",
                                centered = true,
                                cancel = false
                            })
                            
                            break
                        end
                    end
                else
                    if isTextUIShown then
                        lib.hideTextUI()
                        isTextUIShown = false
                    end
                end
                
                Wait(0)
            end
            
            -- Cleanup if van is destroyed
            if isTextUIShown then
                lib.hideTextUI()
            end
            RemoveBlip(blip)
        end)
    end
end

-- Export unloading state
exports('IsUnloading', function()
    return isUnloading
end)

exports('GetUnloadedBoxes', function()
    return unloadedBoxes
end)