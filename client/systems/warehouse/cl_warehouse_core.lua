-- Updated Warehouse Core System with Menu Integration

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Local variables
local currentOrder = {}
local currentOrderRestaurantId = nil
local boxCount = 0
local lastDeliveryTime = 0
local DELIVERY_COOLDOWN = Config.Warehouse.deliveryCooldown * 1000
local REQUIRED_BOXES = Config.Warehouse.requiredBoxesPerDelivery
local deliveryVan = nil
local isInDelivery = false
local currentTeam = nil

-- Initialize warehouse system
CreateThread(function()
    while not Framework or not Framework.IsLoggedIn() do
        Wait(1000)
    end
    
    print("^2[SupplyChain]^7 Warehouse client system initialized")
end)

-- Core warehouse functions
local Warehouse = {}

function Warehouse.OpenMainMenu()
    -- Trigger the new menu system
    TriggerEvent("SupplyChain:Client:OpenWarehouseMenu")
end

function Warehouse.AcceptOrder(orderGroupId, restaurantId)
    -- Check cooldown
    local currentTime = GetGameTimer()
    if currentTime - lastDeliveryTime < DELIVERY_COOLDOWN then
        local remainingTime = math.ceil((DELIVERY_COOLDOWN - (currentTime - lastDeliveryTime)) / 1000)
        Framework.Notify(nil, string.format("Please wait %d seconds before accepting another delivery", remainingTime), "error")
        return
    end
    
    TriggerServerEvent(Constants.Events.Server.AcceptDelivery, orderGroupId, restaurantId)
end

function Warehouse.StartDelivery(restaurantId, orders)
    if isInDelivery then
        Framework.Notify(nil, "You already have an active delivery", "error")
        return
    end
    
    isInDelivery = true
    currentOrder = orders
    currentOrderRestaurantId = restaurantId
    boxCount = 0
    lastDeliveryTime = GetGameTimer()
    
    -- Start delivery process
    TriggerEvent("SupplyChain:Client:SpawnDeliveryVehicle", restaurantId, orders)
end

function Warehouse.CompleteDelivery()
    if not isInDelivery or boxCount < REQUIRED_BOXES then
        Framework.Notify(nil, "Invalid delivery state", "error")
        return
    end
    
    TriggerServerEvent(Constants.Events.Server.CompleteDelivery, currentOrderRestaurantId, currentOrder)
    
    -- Reset state
    isInDelivery = false
    currentOrder = {}
    currentOrderRestaurantId = nil
    boxCount = 0
    
    if DoesEntityExist(deliveryVan) then
        DeleteVehicle(deliveryVan)
        deliveryVan = nil
    end
end

function Warehouse.CancelDelivery()
    if not isInDelivery then return end
    
    local orderGroupId = currentOrder[1] and currentOrder[1].orderGroupId
    if orderGroupId then
        TriggerServerEvent(Constants.Events.Server.CancelDelivery, orderGroupId)
    end
    
    -- Clean up
    isInDelivery = false
    currentOrder = {}
    currentOrderRestaurantId = nil
    boxCount = 0
    
    if DoesEntityExist(deliveryVan) then
        DeleteVehicle(deliveryVan)
        deliveryVan = nil
    end
    
    Framework.Notify(nil, "Delivery cancelled", "error")
end

-- Event Handlers
RegisterNetEvent("SupplyChain:Client:ViewContainerOrders")
AddEventHandler("SupplyChain:Client:ViewContainerOrders", function()
    -- Request orders from server
    TriggerServerEvent("SupplyChain:Server:RequestContainerOrders")
end)

RegisterNetEvent(Constants.Events.Client.ShowPendingOrders)
AddEventHandler(Constants.Events.Client.ShowPendingOrders, function(orders)
    if not orders or #orders == 0 then
        Framework.Notify(nil, "No pending orders available", "info")
        return
    end
    
    -- Use the old menu system for compatibility
    TriggerEvent("SupplyChain:Client:CreateOrdersMenu", orders)
end)

RegisterNetEvent(Constants.Events.Client.StartDelivery)
AddEventHandler(Constants.Events.Client.StartDelivery, function(restaurantId, orders)
    Warehouse.StartDelivery(restaurantId, orders)
end)

-- Handle multi-order acceptance response
RegisterNetEvent("SupplyChain:Client:MultiOrderAccepted")
AddEventHandler("SupplyChain:Client:MultiOrderAccepted", function(data)
    if data.success then
        Framework.Notify(nil, string.format("Accepted %d containers for delivery!", data.totalContainers), "success")
        
        -- Update state for multi-order
        isInDelivery = true
        currentOrder = data.orderData
        currentOrderRestaurantId = data.restaurantId
        lastDeliveryTime = GetGameTimer()
        
        -- Spawn vehicle prompt
        lib.alertDialog({
            header = 'Orders Accepted!',
            content = string.format([[
You have accepted delivery of **%d containers** to **%s**.

Next steps:
1. Spawn a delivery van from the vehicle menu
2. Load all containers from the warehouse
3. Deliver to the restaurant
4. Return the van for payment

**Remember:** Each container can hold up to 12 items and containers are type-specific!
            ]], data.totalContainers, data.restaurantName),
            centered = true,
            cancel = false
        })
    else
        Framework.Notify(nil, data.message or "Failed to accept orders", "error")
    end
end)

RegisterNetEvent(Constants.Events.Client.TeamUpdate)
AddEventHandler(Constants.Events.Client.TeamUpdate, function(teamData)
    currentTeam = teamData
    
    -- Update UI or notify
    if teamData then
        local memberCount = #teamData.members + 1 -- +1 for leader
        Framework.Notify(nil, string.format("Team updated: %d members", memberCount), "info")
    end
end)

RegisterNetEvent(Constants.Events.Client.TeamDisband)
AddEventHandler(Constants.Events.Client.TeamDisband, function()
    currentTeam = nil
    Framework.Notify(nil, "Team has been disbanded", "info")
end)

-- Spawn delivery vehicle (updated for multi-container)
RegisterNetEvent("SupplyChain:Client:SpawnDeliveryVehicle")
AddEventHandler("SupplyChain:Client:SpawnDeliveryVehicle", function(restaurantId, orders)
    local warehouseConfig = Config.Warehouses[GetNearestWarehouse()] or Config.Warehouses[1]
    if not warehouseConfig or not warehouseConfig.vehicle then
        Framework.Notify(nil, "No warehouse configuration found", "error")
        return
    end
    
    -- Calculate total containers needed
    local totalContainers = 0
    if orders.totalContainers then
        totalContainers = orders.totalContainers
    else
        -- Legacy support
        totalContainers = REQUIRED_BOXES
    end
    
    -- Alert dialog
    lib.alertDialog({
        header = "New Delivery Job",
        content = string.format("Load %d containers from the warehouse into the van, then deliver them to the restaurant!", totalContainers),
        centered = true,
        cancel = false
    })
    
    -- Fade out
    DoScreenFadeOut(2500)
    Wait(2500)
    
    -- Spawn vehicle
    local vehicleModel = GetHashKey(warehouseConfig.vehicle.model)
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(100)
    end
    
    local spawnPos = warehouseConfig.vehicle.position
    deliveryVan = CreateVehicle(vehicleModel, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
    
    -- Configure vehicle
    SetEntityAsMissionEntity(deliveryVan, true, true)
    SetVehicleHasBeenOwnedByPlayer(deliveryVan, true)
    SetVehicleNeedsToBeHotwired(deliveryVan, false)
    SetVehRadioStation(deliveryVan, "OFF")
    SetVehicleEngineOn(deliveryVan, true, true, false)
    SetEntityCleanupByEngine(deliveryVan, false)
    NetworkRegisterEntityAsNetworked(deliveryVan)
    
    -- Give keys
    local plate = GetVehicleNumberPlateText(deliveryVan)
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    
    -- Teleport player
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, spawnPos.x + 2.0, spawnPos.y, spawnPos.z, true, true, true, false)
    
    -- Fade in
    DoScreenFadeIn(2500)
    
    Framework.Notify(nil, string.format("Van spawned! Load %d containers from the warehouse", totalContainers), "success")
    
    -- Wait for network
    local netId = NetworkGetNetworkIdFromEntity(deliveryVan)
    
    -- Notify server that van is spawned
    TriggerServerEvent(Constants.Events.Server.VanSpawned, {
        vanNetId = netId,
        restaurantId = restaurantId
    })
end)

-- Helper function to get nearest warehouse
function GetNearestWarehouse()
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearestId = nil
    local nearestDist = 999999
    
    for warehouseId, warehouse in pairs(Config.Warehouses) do
        if warehouse.blip and warehouse.blip.coords then
            local dist = #(playerPos - warehouse.blip.coords)
            if dist < nearestDist then
                nearestDist = dist
                nearestId = warehouseId
            end
        end
    end
    
    return nearestId or "warehouse_1"
end

-- Request server to spawn vehicle menu
RegisterNetEvent("SupplyChain:Client:RequestVehicleSpawn")
AddEventHandler("SupplyChain:Client:RequestVehicleSpawn", function()
    if not isInDelivery then
        Framework.Notify(nil, "You need to accept a delivery order first", "error")
        return
    end
    
    if DoesEntityExist(deliveryVan) then
        Framework.Notify(nil, "You already have a delivery vehicle", "error")
        return
    end
    
    -- Spawn vehicle for current order
    TriggerEvent("SupplyChain:Client:SpawnDeliveryVehicle", currentOrderRestaurantId, currentOrder)
end)

-- Export warehouse functions
exports('GetWarehouseFunctions', function()
    return Warehouse
end)

exports('IsInDelivery', function()
    return isInDelivery
end)

exports('GetDeliveryVan', function()
    return deliveryVan
end)

exports('GetCurrentTeam', function()
    return currentTeam
end)

exports('GetCurrentRestaurantId', function()
    return currentOrderRestaurantId
end)