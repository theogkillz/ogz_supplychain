-- Warehouse Delivery System v2.0 - Multi-Box Support

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Delivery State
local DeliveryState = {
    isActive = false,
    hasBox = false,
    boxProp = nil,
    currentBox = nil,
    
    -- Order details
    orderData = nil,
    restaurantId = nil,
    
    -- Box tracking
    totalBoxes = 0,
    boxesLoaded = 0,
    boxesDelivered = 0,
    boxDetails = {}, -- { boxId = { containerType = "", items = {}, prop = nil } }
    
    -- Entities
    van = nil,
    pallets = {},
    boxEntities = {},
    blips = {},
    zones = {},
    
    -- Locations
    warehouseConfig = nil,
    deliveryLocation = nil
}

-- Initialize delivery job
RegisterNetEvent("SupplyChain:Client:StartMultiBoxDelivery")
AddEventHandler("SupplyChain:Client:StartMultiBoxDelivery", function(data)
    if DeliveryState.isActive then
        Framework.Notify(nil, "Delivery already in progress", "error")
        return
    end
    
    DeliveryState.isActive = true
    DeliveryState.orderData = data.orderData
    DeliveryState.restaurantId = data.restaurantId
    DeliveryState.warehouseConfig = data.warehouseConfig
    DeliveryState.van = data.van
    DeliveryState.totalBoxes = data.orderData.totalContainers
    
    -- Reset counters
    DeliveryState.boxesLoaded = 0
    DeliveryState.boxesDelivered = 0
    DeliveryState.boxDetails = {}
    
    if not DoesEntityExist(DeliveryState.van) then
        Framework.Notify(nil, "Delivery van not found", "error")
        CleanupDelivery()
        return
    end
    
    -- Start box loading phase
    StartBoxLoadingPhase()
end)

-- Box Loading Phase
function StartBoxLoadingPhase()
    Framework.Notify(nil, string.format("Load %d containers into the van", DeliveryState.totalBoxes), "info")
    
    -- Request models
    local boxModels = {
        ogz_crate = GetHashKey("prop_boxpile_07d"),
        ogz_cooler = GetHashKey("prop_box_ammo03a"),
        ogz_freezer = GetHashKey("prop_box_ammo04a"),
        ogz_insulated = GetHashKey("prop_box_tea01a"),
        ogz_ventilated = GetHashKey("prop_fruitstand_01"),
        ogz_specialized = GetHashKey("prop_box_guncase_01a")
    }
    
    local palletModel = GetHashKey("prop_pallet_02a")
    RequestModel(palletModel)
    
    for _, model in pairs(boxModels) do
        RequestModel(model)
    end
    
    -- Wait for models
    while not HasModelLoaded(palletModel) do
        Wait(100)
    end
    
    -- Create organized pallet area
    CreatePalletArea()
    
    -- Create boxes based on order
    CreateOrderBoxes(boxModels)
    
    -- Create van loading zone
    CreateVanLoadingZone()
    
    -- Add instruction UI
    lib.showTextUI("[Warehouse Loading]\nPick up containers from pallets and load into van", {
        position = "top-center",
        icon = "fas fa-box"
    })
end

-- Create pallet area with containers
function CreatePalletArea()
    local palletModel = GetHashKey("prop_pallet_02a")
    local basePos = DeliveryState.warehouseConfig.boxPositions[1]
    
    -- Create pallets in organized rows
    local palletCount = math.ceil(DeliveryState.totalBoxes / 4) -- 4 boxes per pallet
    local row = 0
    local col = 0
    
    for i = 1, palletCount do
        local offset = vector3(col * 2.5, row * 2.5, 0)
        local palletPos = basePos + offset
        
        local pallet = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
        PlaceObjectOnGroundProperly(pallet)
        table.insert(DeliveryState.pallets, pallet)
        
        col = col + 1
        if col >= 3 then -- 3 pallets per row
            col = 0
            row = row + 1
        end
    end
end

-- Create boxes based on order containers
function CreateOrderBoxes(boxModels)
    local boxId = 1
    local palletIndex = 1
    local boxesOnPallet = 0
    
    -- Create boxes for each container type in the order
    for _, container in ipairs(DeliveryState.orderData.containers) do
        local containerType = container.type
        local model = boxModels[containerType] or boxModels.ogz_crate
        
        for i = 1, container.count do
            -- Get pallet position
            local pallet = DeliveryState.pallets[palletIndex]
            if not pallet then break end
            
            local palletPos = GetEntityCoords(pallet)
            local boxOffset = GetBoxOffsetOnPallet(boxesOnPallet)
            local boxPos = palletPos + boxOffset
            
            -- Create box
            local box = CreateObject(model, boxPos.x, boxPos.y, boxPos.z + 0.5, true, true, true)
            
            -- Store box details
            DeliveryState.boxDetails[boxId] = {
                entity = box,
                containerType = containerType,
                containerInfo = Config.Containers.types[containerType],
                items = container.items,
                loaded = false,
                delivered = false
            }
            
            table.insert(DeliveryState.boxEntities, box)
            
            -- Create pickup zone for this box
            CreateBoxPickupZone(box, boxId, containerType)
            
            -- Visual indicator
            CreateBoxBlip(box, containerType)
            
            boxId = boxId + 1
            boxesOnPallet = boxesOnPallet + 1
            
            -- Move to next pallet if current is full
            if boxesOnPallet >= 4 then
                palletIndex = palletIndex + 1
                boxesOnPallet = 0
            end
        end
    end
end

-- Get box position offset on pallet
function GetBoxOffsetOnPallet(index)
    local offsets = {
        vector3(-0.5, -0.5, 0.1),  -- Bottom left
        vector3(0.5, -0.5, 0.1),   -- Bottom right
        vector3(-0.5, 0.5, 0.1),   -- Top left
        vector3(0.5, 0.5, 0.1)     -- Top right
    }
    return offsets[(index % 4) + 1]
end

-- Create pickup zone for box
function CreateBoxPickupZone(box, boxId, containerType)
    local boxPos = GetEntityCoords(box)
    local zoneName = "box_pickup_" .. boxId
    
    exports.ox_target:addBoxZone({
        coords = boxPos,
        size = vector3(1.5, 1.5, 2.0),
        rotation = 0,
        debug = Config.Debug.showZones,
        name = zoneName,
        options = {
            {
                label = "Pick Up " .. Config.Containers.types[containerType].name,
                icon = "fas fa-hand-holding-box",
                onSelect = function()
                    PickupContainer(boxId)
                end,
                canInteract = function()
                    return not DeliveryState.hasBox and 
                           not DeliveryState.boxDetails[boxId].loaded
                end
            }
        }
    })
    
    table.insert(DeliveryState.zones, zoneName)
end

-- Create box blip
function CreateBoxBlip(box, containerType)
    local boxPos = GetEntityCoords(box)
    local containerInfo = Config.Containers.types[containerType]
    
    local blip = AddBlipForCoord(boxPos.x, boxPos.y, boxPos.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.6)
    SetBlipColour(blip, GetContainerBlipColor(containerType))
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(containerInfo.name)
    EndTextCommandSetBlipName(blip)
    
    table.insert(DeliveryState.blips, blip)
end

-- Get container blip color
function GetContainerBlipColor(containerType)
    local colors = {
        ogz_cooler = 3,      -- Blue
        ogz_freezer = 84,    -- Light Blue
        ogz_crate = 5,       -- Yellow
        ogz_insulated = 2,   -- Green
        ogz_ventilated = 47, -- Orange
        ogz_specialized = 83 -- Purple
    }
    return colors[containerType] or 5
end

-- Pickup container
function PickupContainer(boxId)
    local boxData = DeliveryState.boxDetails[boxId]
    if not boxData or not DoesEntityExist(boxData.entity) then
        Framework.Notify(nil, "Container not found", "error")
        return
    end
    
    if DeliveryState.hasBox then
        Framework.Notify(nil, "You are already carrying a container", "error")
        return
    end
    
    local playerPed = PlayerPedId()
    
    -- Show items in container
    local itemList = {}
    for _, item in ipairs(boxData.items) do
        table.insert(itemList, string.format("%dx %s", item.quantity, item.label))
    end
    
    -- Progress bar
    if lib.progressCircle({
        duration = 2000,
        label = string.format("Picking up %s", boxData.containerInfo.name),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    }) then
        -- Delete original box
        DeleteObject(boxData.entity)
        
        -- Create carry prop
        local coords = GetEntityCoords(playerPed)
        local model = GetEntityModel(boxData.entity)
        
        DeliveryState.boxProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(DeliveryState.boxProp, playerPed, GetPedBoneIndex(playerPed, 57005),
            0.05, 0.1, -0.3, 300.0, 250.0, 20.0, true, true, false, true, 1, true)
        
        -- Load carry animation
        RequestAnimDict("anim@heists@box_carry@")
        while not HasAnimDictLoaded("anim@heists@box_carry@") do
            Wait(0)
        end
        TaskPlayAnim(playerPed, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        
        DeliveryState.hasBox = true
        DeliveryState.currentBox = boxId
        
        -- Update UI
        lib.showTextUI(string.format("[Carrying %s]\nContains: %s\nLoad into van", 
            boxData.containerInfo.name, table.concat(itemList, ", ")), {
            position = "top-center",
            icon = "fas fa-box-open"
        })
        
        Framework.Notify(nil, "Take the container to the van", "info")
    end
end

-- Create van loading zone
function CreateVanLoadingZone()
    local vanZoneName = "van_loading_zone"
    
    CreateThread(function()
        while DeliveryState.isActive and DeliveryState.boxesLoaded < DeliveryState.totalBoxes do
            if DoesEntityExist(DeliveryState.van) then
                local vanPos = GetEntityCoords(DeliveryState.van)
                local vanHeading = GetEntityHeading(DeliveryState.van)
                
                -- Calculate rear position
                local rearOffset = GetOffsetFromEntityInWorldCoords(DeliveryState.van, 0.0, -3.5, 0.0)
                
                -- Draw marker
                DrawMarker(1, rearOffset.x, rearOffset.y, rearOffset.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                -- Check for interaction
                local playerPos = GetEntityCoords(PlayerPedId())
                if #(playerPos - rearOffset) < 2.0 and DeliveryState.hasBox then
                    if not DeliveryState.showingLoadPrompt then
                        lib.showTextUI("[E] Load Container", {
                            position = "center-right",
                            icon = "fas fa-truck-loading"
                        })
                        DeliveryState.showingLoadPrompt = true
                    end
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        LoadContainerIntoVan()
                    end
                else
                    if DeliveryState.showingLoadPrompt then
                        lib.hideTextUI()
                        DeliveryState.showingLoadPrompt = false
                    end
                end
            end
            
            Wait(0)
        end
        
        -- Cleanup
        if DeliveryState.showingLoadPrompt then
            lib.hideTextUI()
            DeliveryState.showingLoadPrompt = false
        end
    end)
end

-- Load container into van
function LoadContainerIntoVan()
    if not DeliveryState.hasBox or not DeliveryState.currentBox then
        Framework.Notify(nil, "You need to pick up a container first", "error")
        return
    end
    
    local boxData = DeliveryState.boxDetails[DeliveryState.currentBox]
    if not boxData then return end
    
    local playerPed = PlayerPedId()
    
    -- Progress bar
    if lib.progressCircle({
        duration = 2000,
        label = "Loading container into van",
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    }) then
        -- Remove carry prop
        if DoesEntityExist(DeliveryState.boxProp) then
            DeleteObject(DeliveryState.boxProp)
            DeliveryState.boxProp = nil
        end
        
        -- Clear animation
        ClearPedTasks(playerPed)
        
        -- Update state
        DeliveryState.hasBox = false
        DeliveryState.boxesLoaded = DeliveryState.boxesLoaded + 1
        DeliveryState.boxDetails[DeliveryState.currentBox].loaded = true
        DeliveryState.currentBox = nil
        
        -- Hide text UI
        lib.hideTextUI()
        
        -- Show progress
        Framework.Notify(nil, string.format("Container loaded (%d/%d)", 
            DeliveryState.boxesLoaded, DeliveryState.totalBoxes), "success")
        
        -- Check if all boxes loaded
        if DeliveryState.boxesLoaded >= DeliveryState.totalBoxes then
            StartDeliveryPhase()
        else
            lib.showTextUI(string.format("[Warehouse Loading]\nContainers loaded: %d/%d", 
                DeliveryState.boxesLoaded, DeliveryState.totalBoxes), {
                position = "top-center",
                icon = "fas fa-box"
            })
        end
        
        -- Update server
        TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress, {
            orderId = DeliveryState.orderData.orderId,
            status = "loading",
            boxesLoaded = DeliveryState.boxesLoaded,
            totalBoxes = DeliveryState.totalBoxes
        })
    end
end

-- Start delivery phase
function StartDeliveryPhase()
    lib.hideTextUI()
    
    -- Cleanup loading area
    for _, blip in ipairs(DeliveryState.blips) do
        RemoveBlip(blip)
    end
    for _, zone in ipairs(DeliveryState.zones) do
        exports.ox_target:removeZone(zone)
    end
    for _, pallet in ipairs(DeliveryState.pallets) do
        if DoesEntityExist(pallet) then
            DeleteObject(pallet)
        end
    end
    
    DeliveryState.blips = {}
    DeliveryState.zones = {}
    DeliveryState.pallets = {}
    
    -- Get delivery location
    local restaurant = Config.Restaurants[DeliveryState.restaurantId]
    if not restaurant then
        Framework.Notify(nil, "Invalid delivery destination", "error")
        CleanupDelivery()
        return
    end
    
    DeliveryState.deliveryLocation = restaurant.delivery
    
    -- Create delivery blip
    local deliveryBlip = AddBlipForCoord(DeliveryState.deliveryLocation.x, 
        DeliveryState.deliveryLocation.y, DeliveryState.deliveryLocation.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipColour(deliveryBlip, 2)
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location: " .. restaurant.name)
    EndTextCommandSetBlipName(deliveryBlip)
    
    table.insert(DeliveryState.blips, deliveryBlip)
    
    -- Alert dialog
    lib.alertDialog({
        header = 'Van Loaded!',
        content = string.format('All %d containers loaded.\n\nDeliver to: %s\nCheck your GPS for directions.', 
            DeliveryState.totalBoxes, restaurant.name),
        centered = true,
        cancel = false
    })
    
    -- Start monitoring arrival
    MonitorDeliveryArrival()
    
    -- Update server
    TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress, {
        orderId = DeliveryState.orderData.orderId,
        status = "in_transit",
        restaurantId = DeliveryState.restaurantId
    })
end

-- Monitor arrival at delivery location
function MonitorDeliveryArrival()
    CreateThread(function()
        local hasArrived = false
        
        while DeliveryState.isActive and not hasArrived do
            if DoesEntityExist(DeliveryState.van) then
                local vanPos = GetEntityCoords(DeliveryState.van)
                local distance = #(vanPos - DeliveryState.deliveryLocation)
                
                -- Draw marker when close
                if distance < 50.0 then
                    DrawMarker(1, DeliveryState.deliveryLocation.x, DeliveryState.deliveryLocation.y, 
                        DeliveryState.deliveryLocation.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        5.0, 5.0, 2.0, 255, 255, 0, 100, false, true, 2, false, nil, nil, false)
                end
                
                -- Check if arrived
                if distance < 10.0 then
                    local playerPed = PlayerPedId()
                    if IsPedInVehicle(playerPed, DeliveryState.van, false) then
                        lib.showTextUI('[E] Park and start unloading', {
                            position = "center-right",
                            icon = "fas fa-parking"
                        })
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            lib.hideTextUI()
                            hasArrived = true
                            StartUnloadingPhase()
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        lib.hideTextUI()
    end)
end

-- Start unloading phase
function StartUnloadingPhase()
    -- Clear route
    for _, blip in ipairs(DeliveryState.blips) do
        if DoesBlipExist(blip) then
            SetBlipRoute(blip, false)
        end
    end
    
    Framework.Notify(nil, string.format("Unload %d containers at the delivery point", 
        DeliveryState.totalBoxes), "info")
    
    -- Update server
    TriggerServerEvent(Constants.Events.Server.UpdateDeliveryProgress, {
        orderId = DeliveryState.orderData.orderId,
        status = "arrived",
        location = DeliveryState.deliveryLocation
    })
    
    -- Create unloading zone
    CreateUnloadingZone()
    
    -- Monitor unloading
    MonitorUnloading()
end

-- Create unloading zone at van
function CreateUnloadingZone()
    CreateThread(function()
        while DeliveryState.isActive and DeliveryState.boxesDelivered < DeliveryState.totalBoxes do
            if DoesEntityExist(DeliveryState.van) then
                local vanPos = GetEntityCoords(DeliveryState.van)
                local rearOffset = GetOffsetFromEntityInWorldCoords(DeliveryState.van, 0.0, -3.5, 0.0)
                
                -- Draw marker
                DrawMarker(1, rearOffset.x, rearOffset.y, rearOffset.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 1.0, 255, 128, 0, 100, false, true, 2, false, nil, nil, false)
                
                -- Check for interaction
                local playerPos = GetEntityCoords(PlayerPedId())
                if #(playerPos - rearOffset) < 2.0 and not DeliveryState.hasBox then
                    if not DeliveryState.showingUnloadPrompt then
                        lib.showTextUI('[E] Unload Container', {
                            position = "center-right",
                            icon = "fas fa-box"
                        })
                        DeliveryState.showingUnloadPrompt = true
                    end
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        UnloadContainerFromVan()
                    end
                else
                    if DeliveryState.showingUnloadPrompt then
                        lib.hideTextUI()
                        DeliveryState.showingUnloadPrompt = false
                    end
                end
            end
            
            Wait(0)
        end
        
        if DeliveryState.showingUnloadPrompt then
            lib.hideTextUI()
        end
    end)
end

-- Unload container from van
function UnloadContainerFromVan()
    -- Find next container to unload
    local containerToUnload = nil
    for boxId, boxData in pairs(DeliveryState.boxDetails) do
        if boxData.loaded and not boxData.delivered then
            containerToUnload = boxId
            break
        end
    end
    
    if not containerToUnload then
        Framework.Notify(nil, "No containers to unload", "error")
        return
    end
    
    local boxData = DeliveryState.boxDetails[containerToUnload]
    local playerPed = PlayerPedId()
    
    -- Progress bar
    if lib.progressCircle({
        duration = 2000,
        label = string.format("Unloading %s", boxData.containerInfo.name),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    }) then
        -- Create carry prop
        local coords = GetEntityCoords(playerPed)
        local model = Config.Containers.types[boxData.containerType].model or "prop_boxpile_07d"
        
        RequestModel(GetHashKey(model))
        while not HasModelLoaded(GetHashKey(model)) do
            Wait(0)
        end
        
        DeliveryState.boxProp = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(DeliveryState.boxProp, playerPed, GetPedBoneIndex(playerPed, 57005),
            0.05, 0.1, -0.3, 300.0, 250.0, 20.0, true, true, false, true, 1, true)
        
        -- Load carry animation
        RequestAnimDict("anim@heists@box_carry@")
        while not HasAnimDictLoaded("anim@heists@box_carry@") do
            Wait(0)
        end
        TaskPlayAnim(playerPed, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        
        DeliveryState.hasBox = true
        DeliveryState.currentBox = containerToUnload
        
        -- Show items
        local itemList = {}
        for _, item in ipairs(boxData.items) do
            table.insert(itemList, string.format("%dx %s", item.quantity, item.label))
        end
        
        lib.hideTextUI()
        lib.showTextUI(string.format("[Carrying %s]\nContains: %s\nDeliver to restaurant", 
            boxData.containerInfo.name, table.concat(itemList, ", ")), {
            position = "top-center",
            icon = "fas fa-box-open"
        })
        
        Framework.Notify(nil, "Take the container to the delivery point", "info")
    end
end

-- Monitor unloading at delivery point
function MonitorUnloading()
    CreateThread(function()
        while DeliveryState.isActive and DeliveryState.boxesDelivered < DeliveryState.totalBoxes do
            if DeliveryState.hasBox then
                local playerPos = GetEntityCoords(PlayerPedId())
                local distance = #(playerPos - DeliveryState.deliveryLocation)
                
                -- Draw delivery marker
                DrawMarker(1, DeliveryState.deliveryLocation.x, DeliveryState.deliveryLocation.y,
                    DeliveryState.deliveryLocation.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                if distance < 2.0 then
                    if not DeliveryState.showingDeliverPrompt then
                        lib.showTextUI('[E] Deliver Container', {
                            position = "center-right",
                            icon = "fas fa-check"
                        })
                        DeliveryState.showingDeliverPrompt = true
                    end
                    
                    if IsControlJustPressed(0, 38) then -- E key
                        DeliverContainer()
                    end
                else
                    if DeliveryState.showingDeliverPrompt then
                        lib.hideTextUI()
                        DeliveryState.showingDeliverPrompt = false
                    end
                end
            end
            
            Wait(0)
        end
        
        if DeliveryState.showingDeliverPrompt then
            lib.hideTextUI()
        end
    end)
end

-- Deliver container
function DeliverContainer()
    if not DeliveryState.hasBox or not DeliveryState.currentBox then
        Framework.Notify(nil, "You need to be carrying a container", "error")
        return
    end
    
    local boxData = DeliveryState.boxDetails[DeliveryState.currentBox]
    if not boxData then return end
    
    local playerPed = PlayerPedId()
    
    -- Progress bar
    if lib.progressCircle({
        duration = 2000,
        label = "Delivering container",
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    }) then
        -- Remove carry prop
        if DoesEntityExist(DeliveryState.boxProp) then
            DeleteObject(DeliveryState.boxProp)
            DeliveryState.boxProp = nil
        end
        
        -- Clear animation
        ClearPedTasks(playerPed)
        
        -- Update state
        DeliveryState.hasBox = false
        DeliveryState.boxesDelivered = DeliveryState.boxesDelivered + 1
        DeliveryState.boxDetails[DeliveryState.currentBox].delivered = true
        DeliveryState.currentBox = nil
        
        -- Hide text UI
        lib.hideTextUI()
        
        -- Show progress
        Framework.Notify(nil, string.format("Container delivered (%d/%d)", 
            DeliveryState.boxesDelivered, DeliveryState.totalBoxes), "success")
        
        -- Update server - this will update restaurant stock
        TriggerServerEvent(Constants.Events.Server.DeliverContainer, {
            orderId = DeliveryState.orderData.orderId,
            restaurantId = DeliveryState.restaurantId,
            containerId = DeliveryState.currentBox,
            containerData = boxData,
            progress = {
                delivered = DeliveryState.boxesDelivered,
                total = DeliveryState.totalBoxes
            }
        })
        
        -- Check if all delivered
        if DeliveryState.boxesDelivered >= DeliveryState.totalBoxes then
            CompleteDelivery()
        end
    end
end

-- Complete delivery
function CompleteDelivery()
    lib.alertDialog({
        header = 'Delivery Complete!',
        content = string.format('All %d containers delivered successfully.\n\nReturn the van to the warehouse to receive payment.', 
            DeliveryState.totalBoxes),
        centered = true,
        cancel = false
    })
    
    -- Create return blip
    local warehousePos = DeliveryState.warehouseConfig.vanSpawn
    local returnBlip = AddBlipForCoord(warehousePos.x, warehousePos.y, warehousePos.z)
    SetBlipSprite(returnBlip, 1)
    SetBlipDisplay(returnBlip, 4)
    SetBlipScale(returnBlip, 1.0)
    SetBlipColour(returnBlip, 3)
    SetBlipRoute(returnBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Return Van to Warehouse")
    EndTextCommandSetBlipName(returnBlip)
    
    table.insert(DeliveryState.blips, returnBlip)
    
    -- Monitor van return
    MonitorVanReturn()
end

-- Monitor van return to warehouse
function MonitorVanReturn()
    CreateThread(function()
        local hasReturned = false
        local warehousePos = DeliveryState.warehouseConfig.vanSpawn
        
        while DeliveryState.isActive and not hasReturned do
            if DoesEntityExist(DeliveryState.van) then
                local vanPos = GetEntityCoords(DeliveryState.van)
                local distance = #(vanPos - warehousePos)
                
                -- Draw marker when close
                if distance < 50.0 then
                    DrawMarker(1, warehousePos.x, warehousePos.y, warehousePos.z - 1.0, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        5.0, 5.0, 2.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                end
                
                -- Check if returned
                if distance < 5.0 then
                    local playerPed = PlayerPedId()
                    if IsPedInVehicle(playerPed, DeliveryState.van, false) then
                        lib.showTextUI('[E] Return Van', {
                            position = "center-right",
                            icon = "fas fa-truck"
                        })
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            lib.hideTextUI()
                            hasReturned = true
                            ReturnVan()
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        lib.hideTextUI()
    end)
end

-- Return van and complete job
function ReturnVan()
    local playerPed = PlayerPedId()
    
    -- Exit vehicle
    TaskLeaveVehicle(playerPed, DeliveryState.van, 0)
    Wait(2000)
    
    -- Delete van
    if DoesEntityExist(DeliveryState.van) then
        DeleteEntity(DeliveryState.van)
    end
    
    -- Trigger payment on server
    TriggerServerEvent(Constants.Events.Server.CompleteMultiBoxDelivery, {
        orderId = DeliveryState.orderData.orderId,
        restaurantId = DeliveryState.restaurantId,
        totalContainers = DeliveryState.totalBoxes,
        deliveryData = {
            startTime = DeliveryState.startTime,
            endTime = GetGameTimer(),
            containersDelivered = DeliveryState.boxesDelivered
        }
    })
    
    -- Cleanup
    CleanupDelivery()
    
    Framework.Notify(nil, "Delivery completed! Payment processed.", "success")
end

-- Cleanup function
function CleanupDelivery()
    -- Clear all blips
    for _, blip in ipairs(DeliveryState.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    -- Clear all zones
    for _, zone in ipairs(DeliveryState.zones) do
        exports.ox_target:removeZone(zone)
    end
    
    -- Clear all entities
    for _, entity in ipairs(DeliveryState.boxEntities) do
        if DoesEntityExist(entity) then
            DeleteObject(entity)
        end
    end
    
    for _, pallet in ipairs(DeliveryState.pallets) do
        if DoesEntityExist(pallet) then
            DeleteObject(pallet)
        end
    end
    
    if DoesEntityExist(DeliveryState.boxProp) then
        DeleteObject(DeliveryState.boxProp)
    end
    
    if DoesEntityExist(DeliveryState.van) then
        DeleteEntity(DeliveryState.van)
    end
    
    -- Clear animation
    ClearPedTasks(PlayerPedId())
    
    -- Hide any UI
    lib.hideTextUI()
    
    -- Reset state
    DeliveryState = {
        isActive = false,
        hasBox = false,
        boxProp = nil,
        currentBox = nil,
        orderData = nil,
        restaurantId = nil,
        totalBoxes = 0,
        boxesLoaded = 0,
        boxesDelivered = 0,
        boxDetails = {},
        van = nil,
        pallets = {},
        boxEntities = {},
        blips = {},
        zones = {},
        warehouseConfig = nil,
        deliveryLocation = nil
    }
end

-- Export delivery state
exports('GetDeliveryState', function()
    return DeliveryState
end)

exports('IsDeliveryActive', function()
    return DeliveryState.isActive
end)