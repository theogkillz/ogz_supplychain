-- ============================================
-- WAREHOUSE CONTAINER LOADING SYSTEM
-- Enhanced multi-box loading with pallet props
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- SINGLE BOX LOADING SYSTEM
-- ============================================

-- Single Box Loading System (for small orders)
RegisterNetEvent("warehouse:loadSingleBox")
AddEventHandler("warehouse:loadSingleBox", function(warehouseConfig, van, restaurantId, orders)
    print("[LOADING] Starting single box system...")
    
    if not DoesEntityExist(van) then
        print("[ERROR] Van does not exist")
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found. Please restart the job."
        )
        return
    end

    local playerPed = PlayerPedId()
    local boxCount = 0
    local maxBoxes = 1
    local hasBox = false
    local boxProp = nil
    local boxBlips = {}
    local boxEntities = {}
    local targetZones = {}
    local vanTargetName = "van_load"

    -- Load box prop model
    local propName = Config.DeliveryProps.boxProp
    local model = GetHashKey(propName)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        print("[ERROR] No boxPositions defined")
        exports.ogz_supplychain:errorNotify(
            "Configuration Error",
            "No box pickup locations available."
        )
        return
    end

    -- Get item label from orders
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

    print("[LOADING] Creating single box for item:", itemLabel)

    -- Create single box
    local pos = boxPositions[1]
    local box = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    if DoesEntityExist(box) then
        PlaceObjectOnGroundProperly(box)
        table.insert(boxEntities, box)
        
        -- Light effect
        Citizen.CreateThread(function()
            while DoesEntityExist(box) do
                DrawLightWithRange(pos.x, pos.y, pos.z + 0.5, 0, 255, 0, 2.0, 1.0)
                Citizen.Wait(0)
            end
        end)
    end

    -- Create blip
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 4)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Box Pickup")
    EndTextCommandSetBlipName(blip)
    table.insert(boxBlips, blip)

    -- Create pickup target zone
    local zoneName = "box_pickup_single"
    local pickupZone = exports.ogz_supplychain:createBoxZone({
        coords = vector3(pos.x, pos.y, pos.z),
        size = vector3(2.0, 2.0, 2.0),
        name = zoneName,
        options = {
            {
                label = "Pick Up Box",
                icon = "fas fa-box",
                onSelect = function()
                    TriggerEvent("warehouse:pickupSingleBox", box, van, itemLabel, model, boxBlips, boxEntities, zoneName)
                end
            }
        }
    })
    
    table.insert(targetZones, zoneName)

    -- Setup van loading zone
    TriggerEvent("warehouse:setupVanLoadingZone", van, hasBox, boxProp, maxBoxes, boxCount, restaurantId, orders, itemLabel)

    exports.ogz_supplychain:containerNotify(
        "Box Available",
        string.format("Pick up %s from the marked location and load it into the van.", itemLabel)
    )
end)

-- Handle single box pickup
RegisterNetEvent("warehouse:pickupSingleBox")
AddEventHandler("warehouse:pickupSingleBox", function(box, van, itemLabel, model, boxBlips, boxEntities, zoneName)
    local playerPed = PlayerPedId()
    
    if not DoesEntityExist(van) then
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found. Please restart the job."
        )
        return
    end
    
    local success = exports.ogz_supplychain:showProgress({
        duration = 3000,
        label = "Picking Up Box...",
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    })
    
    if success then
        if DoesEntityExist(box) then
            DeleteObject(box)
        end
        
        -- Create carried box prop
        local playerCoords = GetEntityCoords(playerPed)
        local boxProp = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
        AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
            0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

        -- Apply carrying animation
        local animDict = "anim@heists@box_carry@"
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Citizen.Wait(0)
        end
        TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

        exports.ogz_supplychain:successNotify(
            "Box Picked Up",
            string.format("Load %s into the van.", itemLabel)
        )
        
        -- Remove pickup zone
        exports.ogz_supplychain:removeZone(zoneName)
        
        -- Store box prop for van loading
        TriggerEvent("warehouse:setCarriedBox", boxProp)
    end
end)

-- ============================================
-- ENHANCED MULTI-BOX LOADING SYSTEM
-- ============================================

-- Enhanced Multi-Box Loading System with Pallet Props
RegisterNetEvent("warehouse:loadMultipleBoxes")
AddEventHandler("warehouse:loadMultipleBoxes", function(warehouseConfig, van, restaurantId, orders, totalBoxes)
    print("[LOADING] Starting enhanced multi-box loading system for", totalBoxes, "boxes")
    
    if not DoesEntityExist(van) then
        exports.ogz_supplychain:errorNotify(
            "Vehicle Error",
            "Delivery van not found. Please restart the job."
        )
        return
    end

    local playerPed = PlayerPedId()
    local boxesLoaded = 0
    local hasBox = false
    local boxProp = nil
    local palletBlip = nil
    local palletEntity = nil
    local targetZones = {}
    local vanTargetName = "van_load_multi"
    local palletZoneName = "pallet_pickup_multi"

    -- Load both box and pallet models
    local boxModel = GetHashKey(Config.DeliveryProps.boxProp)
    local palletModel = GetHashKey(Config.DeliveryProps.palletProp)
    
    RequestModel(boxModel)
    RequestModel(palletModel)
    while not HasModelLoaded(boxModel) or not HasModelLoaded(palletModel) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        print("[ERROR] No boxPositions defined")
        return
    end

    -- Create single pallet prop instead of individual boxes
    local palletPos = boxPositions[1]
    palletEntity = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
    if DoesEntityExist(palletEntity) then
        PlaceObjectOnGroundProperly(palletEntity)
        
        -- Enhanced pallet light effect with pulsing based on order size
        Citizen.CreateThread(function()
            while DoesEntityExist(palletEntity) and boxesLoaded < totalBoxes do
                local lightColor = { r = 0, g = 255, b = 0 } -- Green for available
                if totalBoxes > 5 then 
                    lightColor = { r = 255, g = 165, b = 0 } -- Orange for large orders
                elseif totalBoxes > 8 then
                    lightColor = { r = 255, g = 0, b = 0 } -- Red for mega orders
                end
                
                DrawLightWithRange(palletPos.x, palletPos.y, palletPos.z + 1.0, 
                    lightColor.r, lightColor.g, lightColor.b, 3.0, 1.5)
                Citizen.Wait(0)
            end
        end)
    end

    -- Create blip for pallet
    palletBlip = AddBlipForCoord(palletPos.x, palletPos.y, palletPos.z)
    SetBlipSprite(palletBlip, 1)
    SetBlipDisplay(palletBlip, 4)
    SetBlipScale(palletBlip, 0.8)
    SetBlipColour(palletBlip, 2)
    SetBlipAsShortRange(palletBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(string.format("Box Pallet (%d boxes needed)", totalBoxes))
    EndTextCommandSetBlipName(palletBlip)

    -- Setup pallet interaction system
    TriggerEvent("warehouse:setupPalletInteraction", palletPos, totalBoxes, boxModel, palletZoneName, boxesLoaded)
    
    -- Setup van loading system
    TriggerEvent("warehouse:setupMultiBoxVanLoading", van, totalBoxes, boxesLoaded, vanTargetName, restaurantId, orders, palletBlip, palletEntity, targetZones)

    exports.ogz_supplychain:containerNotify(
        "Pallet Loading System",
        string.format("Grab boxes from the pallet and load %d boxes into the van", totalBoxes)
    )
end)

-- ============================================
-- PALLET INTERACTION SYSTEM
-- ============================================

-- Setup pallet interaction zones
RegisterNetEvent("warehouse:setupPalletInteraction")
AddEventHandler("warehouse:setupPalletInteraction", function(palletPos, totalBoxes, boxModel, palletZoneName, boxesLoaded)
    local function updatePalletZone()
        local currentLoaded = exports.ogz_supplychain:getBoxesLoaded() or 0
        
        local palletZone = exports.ogz_supplychain:createBoxZone({
            coords = vector3(palletPos.x, palletPos.y, palletPos.z),
            size = vector3(3.0, 3.0, 2.0),
            name = palletZoneName,
            options = {
                {
                    label = string.format("Grab Box (%d/%d loaded)", currentLoaded, totalBoxes),
                    icon = "fas fa-box",
                    onSelect = function()
                        TriggerEvent("warehouse:grabBoxFromPallet", boxModel, totalBoxes, palletZoneName)
                    end
                }
            }
        })
    end
    
    -- Initial setup
    updatePalletZone()
    
    -- Update zone when boxes are loaded
    RegisterNetEvent("warehouse:updatePalletZone")
    AddEventHandler("warehouse:updatePalletZone", updatePalletZone)
end)

-- Handle box grabbing from pallet
RegisterNetEvent("warehouse:grabBoxFromPallet")
AddEventHandler("warehouse:grabBoxFromPallet", function(boxModel, totalBoxes, palletZoneName)
    local playerPed = PlayerPedId()
    local currentLoaded = exports.ogz_supplychain:getBoxesLoaded() or 0
    
    if exports.ogz_supplychain:hasCarriedBox() then
        exports.ogz_supplychain:errorNotify(
            "Already Carrying",
            "You are already carrying a box."
        )
        return
    end
    
    if currentLoaded >= totalBoxes then
        exports.ogz_supplychain:systemNotify(
            "Complete",
            "All boxes have been loaded into the van."
        )
        return
    end
    
    local success = exports.ogz_supplychain:showProgress({
        duration = 2500,
        label = "Grabbing box from pallet...",
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    })
    
    if success then
        -- Create box in player's hands
        local playerCoords = GetEntityCoords(playerPed)
        local boxProp = CreateObject(boxModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
        AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
            0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

        -- Apply carrying animation
        local animDict = "anim@heists@box_carry@"
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Citizen.Wait(0)
        end
        TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

        exports.ogz_supplychain:successNotify(
            "Box Grabbed",
            string.format("Load into van (%d/%d)", currentLoaded + 1, totalBoxes)
        )
        
        -- Store carried box state
        TriggerEvent("warehouse:setCarriedBox", boxProp)
    end
end)

-- ============================================
-- VAN LOADING COORDINATION
-- ============================================

-- Van loading state management
local vanLoadingState = {
    hasBox = false,
    boxProp = nil,
    boxesLoaded = 0
}

-- Set carried box state
RegisterNetEvent("warehouse:setCarriedBox")
AddEventHandler("warehouse:setCarriedBox", function(boxProp)
    vanLoadingState.hasBox = true
    vanLoadingState.boxProp = boxProp
end)

-- Clear carried box state
RegisterNetEvent("warehouse:clearCarriedBox")
AddEventHandler("warehouse:clearCarriedBox", function()
    if vanLoadingState.boxProp and DoesEntityExist(vanLoadingState.boxProp) then
        DeleteObject(vanLoadingState.boxProp)
    end
    vanLoadingState.hasBox = false
    vanLoadingState.boxProp = nil
    ClearPedTasks(PlayerPedId())
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('hasCarriedBox', function() return vanLoadingState.hasBox end)
exports('getBoxesLoaded', function() return vanLoadingState.boxesLoaded end)
exports('setBoxesLoaded', function(count) vanLoadingState.boxesLoaded = count end)

print("[WAREHOUSE] Container loading system loaded")