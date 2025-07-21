-- Warehouse Delivery Mechanics

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Delivery state
local hasBox = false
local boxProp = nil
local boxBlips = {}
local boxEntities = {}
local targetZones = {}
local deliveryBlip = nil
local boxCount = 0
local REQUIRED_BOXES = Config.Warehouse.requiredBoxesPerDelivery

-- Box loading phase
RegisterNetEvent("SupplyChain:Client:StartBoxLoading")
AddEventHandler("SupplyChain:Client:StartBoxLoading", function(warehouseConfig, van, restaurantId, orders)
    if not DoesEntityExist(van) then
        Framework.Notify(nil, "Delivery van not found", "error")
        return
    end
    
    -- Reset state
    boxCount = 0
    hasBox = false
    boxProp = nil
    boxBlips = {}
    boxEntities = {}
    targetZones = {}
    
    -- Load models
    local boxModel = GetHashKey(Config.Warehouse.carryBoxProp)
    local palletModel = GetHashKey("prop_pallet_02a")
    RequestModel(boxModel)
    RequestModel(palletModel)
    while not HasModelLoaded(boxModel) or not HasModelLoaded(palletModel) do
        Wait(100)
    end
    
    -- Create pallet
    local palletPos = warehouseConfig.boxPositions[1]
    local pallet = nil
    if palletPos then
        pallet = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
        PlaceObjectOnGroundProperly(pallet)
    end
    
    -- Create box pickup zones
    for i, pos in ipairs(warehouseConfig.boxPositions) do
        if i > REQUIRED_BOXES then break end
        
        -- Create box prop
        local box = CreateObject(boxModel, pos.x, pos.y, pos.z, true, true, true)
        PlaceObjectOnGroundProperly(box)
        table.insert(boxEntities, box)
        
        -- Create blip
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, Constants.BlipColors.Yellow)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Box Pickup")
        EndTextCommandSetBlipName(blip)
        table.insert(boxBlips, blip)
        
        -- Create marker thread
        CreateThread(function()
            while DoesEntityExist(box) do
                DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    1.0, 1.0, 0.5, 255, 255, 0, 100, false, true, 2, false, nil, nil, false)
                Wait(0)
            end
        end)
        
        -- Create target zone
        local zoneName = "box_pickup_" .. i
        exports.ox_target:addBoxZone({
            coords = vector3(pos.x, pos.y, pos.z),
            size = vector3(2.0, 2.0, 2.0),
            rotation = 0,
            debug = Config.Debug.showZones,
            name = zoneName,
            options = {
                {
                    label = "Pick Up Box",
                    icon = "fas fa-box",
                    onSelect = function()
                        PickupBox(box, i, orders)
                    end,
                    canInteract = function()
                        return not hasBox and boxCount < REQUIRED_BOXES
                    end
                }
            }
        })
        table.insert(targetZones, zoneName)
    end
    
    -- Create van loading zone
    CreateVanLoadingZone(van, orders)
    
    -- Add van blip
    local vanCoords = GetEntityCoords(van)
    local vanBlip = AddBlipForCoord(vanCoords.x, vanCoords.y, vanCoords.z)
    SetBlipSprite(vanBlip, 1)
    SetBlipDisplay(vanBlip, 4)
    SetBlipScale(vanBlip, 1.0)
    SetBlipColour(vanBlip, Constants.BlipColors.Blue)
    SetBlipAsShortRange(vanBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Van")
    EndTextCommandSetBlipName(vanBlip)
    
    -- First instruction
    local itemNames = exports.ox_inventory:Items() or {}
    local firstItem = orders[1]
    local itemLabel = firstItem and itemNames[firstItem.itemName] and itemNames[firstItem.itemName].label or "items"
    Framework.Notify(nil, string.format("Pick up %s from the marked pallet", itemLabel), "info")
end)

-- Pickup box function
function PickupBox(boxEntity, boxIndex, orders)
    if hasBox then
        Framework.Notify(nil, "You are already carrying a box", "error")
        return
    end
    
    local van = exports['ogz_supplychain']:GetDeliveryVan()
    if not DoesEntityExist(van) then
        Framework.Notify(nil, "Delivery van not found", "error")
        return
    end
    
    -- Get item info
    local itemNames = exports.ox_inventory:Items() or {}
    local currentItem = orders[boxCount + 1]
    local itemLabel = currentItem and itemNames[currentItem.itemName] and itemNames[currentItem.itemName].label or "item"
    
    -- Progress bar
    if lib.progressBar({
        duration = 3000,
        label = string.format("Picking up %s...", itemLabel),
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
        -- Delete box entity
        if DoesEntityExist(boxEntity) then
            DeleteObject(boxEntity)
            for i, entity in ipairs(boxEntities) do
                if entity == boxEntity then
                    table.remove(boxEntities, i)
                    break
                end
            end
        end
        
        -- Create carry prop
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local model = GetHashKey(Config.Warehouse.carryBoxProp)
        
        boxProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 57005),
            0.12, 0.05, 0.1, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
        
        hasBox = true
        
        -- Play carry animation
        RequestAnimDict(Constants.Animations.Carry.dict)
        while not HasAnimDictLoaded(Constants.Animations.Carry.dict) do
            Wait(0)
        end
        TaskPlayAnim(playerPed, Constants.Animations.Carry.dict, Constants.Animations.Carry.anim, 
            8.0, -8.0, -1, 50, 0, false, false, false)
        
        Framework.Notify(nil, string.format("Load %s into the van", itemLabel), "success")
    end
end

-- Create van loading zone
function CreateVanLoadingZone(van, orders)
    local vanTargetName = "van_load_" .. GetGameTimer()
    
    CreateThread(function()
        while DoesEntityExist(van) and boxCount < REQUIRED_BOXES do
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
            exports.ox_target:addBoxZone({
                coords = vanRear,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = Config.Debug.showZones,
                name = vanTargetName,
                options = {
                    {
                        label = "Load Box",
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            LoadBoxIntoVan(orders)
                        end,
                        canInteract = function()
                            return hasBox
                        end
                    }
                }
            })
            
            -- Draw marker
            DrawMarker(1, vanRear.x, vanRear.y, vanRear.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                3.0, 3.0, 0.5, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
            
            Wait(1000)
        end
        
        -- Cleanup
        exports.ox_target:removeZone(vanTargetName)
    end)
end

-- Load box into van
function LoadBoxIntoVan(orders)
    if not hasBox or not DoesEntityExist(boxProp) then
        Framework.Notify(nil, "You need to pick up a box first", "error")
        return
    end
    
    local playerPed = PlayerPedId()
    local van = exports['ogz_supplychain']:GetDeliveryVan()
    
    -- Check distance to van
    local vanPos = GetEntityCoords(van)
    local playerPos = GetEntityCoords(playerPed)
    if #(playerPos - vanPos) > 5.0 then
        Framework.Notify(nil, "Move closer to the van's rear", "error")
        return
    end
    
    -- Get item info
    local itemNames = exports.ox_inventory:Items() or {}
    local currentItem = orders[boxCount + 1]
    local itemLabel = currentItem and itemNames[currentItem.itemName] and itemNames[currentItem.itemName].label or "item"
    
    -- Progress bar
    if lib.progressBar({
        duration = 3000,
        label = string.format("Loading %s...", itemLabel),
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
        -- Remove box
        if DoesEntityExist(boxProp) then
            DeleteObject(boxProp)
            boxProp = nil
        end
        
        hasBox = false
        boxCount = boxCount + 1
        ClearPedTasks(playerPed)
        
        -- Update delivery progress
        TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress, 
            orders[1].orderGroupId or "unknown",
            Constants.DeliveryStatus.LOADING,
            { boxesLoaded = boxCount }
        )
        
        Framework.Notify(nil, string.format("%s loaded. %d boxes left", itemLabel, REQUIRED_BOXES - boxCount), "success")
        
        -- Check if all boxes loaded
        if boxCount >= REQUIRED_BOXES then
            -- Cleanup
            for _, blip in ipairs(boxBlips) do
                RemoveBlip(blip)
            end
            for _, zone in ipairs(targetZones) do
                exports.ox_target:removeZone(zone)
            end
            for _, entity in ipairs(boxEntities) do
                if DoesEntityExist(entity) then
                    DeleteObject(entity)
                end
            end
            
            -- Start delivery phase
            local restaurantId = exports['ogz_supplychain']:GetCurrentRestaurantId()
            TriggerEvent("SupplyChain:Client:StartDeliveryPhase", restaurantId, van, orders)
        end
    end
end

-- Delivery phase
RegisterNetEvent("SupplyChain:Client:StartDeliveryPhase")
AddEventHandler("SupplyChain:Client:StartDeliveryPhase", function(restaurantId, van, orders)
    lib.alertDialog({
        header = "Van Loaded",
        content = "Drive to the restaurant delivery location. Check your GPS for directions!",
        centered = true,
        cancel = false
    })
    
    -- Get delivery location
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        Framework.Notify(nil, "Invalid restaurant configuration", "error")
        return
    end
    
    local deliveryPos = restaurant.delivery
    
    -- Set waypoint
    SetNewWaypoint(deliveryPos.x, deliveryPos.y)
    
    -- Create delivery blip
    deliveryBlip = AddBlipForCoord(deliveryPos.x, deliveryPos.y, deliveryPos.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipScale(deliveryBlip, 0.7)
    SetBlipColour(deliveryBlip, Constants.BlipColors.Green)
    SetBlipAsShortRange(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location")
    EndTextCommandSetBlipName(deliveryBlip)
    
    Framework.Notify(nil, "Drive to the delivery location marked on your GPS", "info")
    
    -- Update status
    TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress,
        orders[1].orderGroupId or "unknown",
        Constants.DeliveryStatus.IN_TRANSIT,
        { destination = restaurant.name }
    )
    
    -- Monitor arrival
    CreateThread(function()
        local isTextUIShown = false
        
        while DoesEntityExist(van) do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - deliveryPos)
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Park Van", {
                        icon = "fas fa-parking"
                    })
                    isTextUIShown = true
                end
                
                -- Draw marker
                DrawMarker(1, deliveryPos.x, deliveryPos.y, deliveryPos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    5.0, 5.0, 0.5, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                if IsControlJustPressed(0, Constants.Keys.INTERACT) then
                    lib.hideTextUI()
                    RemoveBlip(deliveryBlip)
                    
                    -- Update status
                    TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress,
                        orders[1].orderGroupId or "unknown",
                        Constants.DeliveryStatus.ARRIVED,
                        { arrivalTime = GetGameTimer() }
                    )
                    
                    -- Start unloading
                    TriggerEvent("SupplyChain:Client:StartUnloading", restaurantId, van, orders)
                    break
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            
            Wait(0)
        end
    end)
end)

-- Export current restaurant ID
exports('GetCurrentRestaurantId', function()
    return currentOrderRestaurantId
end)