-- Warehouse Client Core System

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
    TriggerServerEvent(Constants.Events.Server.GetPendingOrders)
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
    
    TriggerEvent("SupplyChain:Client:CreateOrdersMenu", orders)
end)

RegisterNetEvent(Constants.Events.Client.StartDelivery)
AddEventHandler(Constants.Events.Client.StartDelivery, function(restaurantId, orders)
    Warehouse.StartDelivery(restaurantId, orders)
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

-- Spawn delivery vehicle
RegisterNetEvent("SupplyChain:Client:SpawnDeliveryVehicle")
AddEventHandler("SupplyChain:Client:SpawnDeliveryVehicle", function(restaurantId, orders)
    local warehouseConfig = Config.Warehouses[1] -- Get nearest warehouse
    if not warehouseConfig or not warehouseConfig.vehicle then
        Framework.Notify(nil, "No warehouse configuration found", "error")
        return
    end
    
    -- Alert dialog
    lib.alertDialog({
        header = "New Delivery Job",
        content = "Load 3 boxes from the warehouse into the van, then deliver them to the restaurant!",
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
    
    -- Give keys
    local plate = GetVehicleNumberPlateText(deliveryVan)
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    
    -- Teleport player
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, spawnPos.x + 2.0, spawnPos.y, spawnPos.z, true, true, true, false)
    
    -- Fade in
    DoScreenFadeIn(2500)
    
    Framework.Notify(nil, "Van spawned! Load 3 boxes from the warehouse", "success")
    
    -- Start box loading
    TriggerEvent("SupplyChain:Client:StartBoxLoading", warehouseConfig, deliveryVan, restaurantId, orders)
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