-- Core Restaurant Client System

local Framework = SupplyChain.Framework
local currentOrderRestaurantId = nil
local currentOrderItems = {}

-- Initialize restaurant system
CreateThread(function()
    -- Wait for framework to be ready
    while not Framework or not Framework.IsLoggedIn() do
        Wait(1000)
    end
    
    print("^2[SupplyChain]^7 Restaurant client system initialized")
end)

-- Core restaurant functions
local Restaurant = {}

function Restaurant.GetCurrentRestaurant()
    local job = Framework.GetJob()
    if not job then return nil end
    
    return Config.GetRestaurantByJob(job.name)
end

function Restaurant.IsRestaurantEmployee(restaurantId)
    local job = Framework.GetJob()
    if not job then return false end
    
    local restaurant = Config.Restaurants[restaurantId]
    return restaurant and restaurant.job == job.name
end

function Restaurant.OpenOrderMenu(restaurantId)
    currentOrderRestaurantId = restaurantId
    TriggerServerEvent("SupplyChain:Server:GetWarehouseStockForOrder", restaurantId)
end

function Restaurant.AddToOrder(item, quantity, label)
    table.insert(currentOrderItems, {
        ingredient = item,
        quantity = quantity,
        label = label
    })
    
    Framework.Notify(nil, string.format("%d x %s added to order", quantity, label), "success")
end

function Restaurant.SubmitOrder()
    if #currentOrderItems == 0 then
        Framework.Notify(nil, "No items selected for order", "error")
        return
    end
    
    TriggerServerEvent("SupplyChain:Server:CreateRestaurantOrder", currentOrderItems, currentOrderRestaurantId)
    currentOrderItems = {}
    currentOrderRestaurantId = nil
end

function Restaurant.OpenStockMenu(restaurantId)
    TriggerServerEvent("SupplyChain:Server:GetRestaurantStock", restaurantId)
end

function Restaurant.WithdrawStock(restaurantId, itemName, amount)
    TriggerServerEvent("SupplyChain:Server:WithdrawRestaurantStock", restaurantId, itemName, amount)
end

-- Event Handlers
RegisterNetEvent("SupplyChain:Client:OpenOrderMenu")
AddEventHandler("SupplyChain:Client:OpenOrderMenu", function(data)
    if not data or not data.restaurantId then
        Framework.Notify(nil, "Invalid restaurant data", "error")
        return
    end
    
    local restaurantId = data.restaurantId
    local warehouseStock = data.warehouseStock or {}
    local dynamicPrices = data.dynamicPrices or {}
    
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        Framework.Notify(nil, "Invalid restaurant configuration", "error")
        return
    end
end)
    
    -- Trigger menu creation
    RegisterNetEvent("SupplyChain:Client:InteractWithOrderPoint")
    AddEventHandler("SupplyChain:Client:InteractWithOrderPoint", function(data)
    -- Get warehouse stock and prices
    local warehouseStock = StateManager.GetWarehouseStock() or {}
    local dynamicPrices = exports['ogz_supplychain']:GetDynamicPrices()
    
    -- Open new shopping cart menu
    TriggerEvent("SupplyChain:Client:OpenRestaurantMenu", {
        restaurantId = data.restaurantId,
        restaurant = data.restaurant,
        warehouseStock = warehouseStock,
        dynamicPrices = dynamicPrices,
        clearCart = true -- Clear cart on new session
    })
end)

RegisterNetEvent("SupplyChain:Client:ShowRestaurantStock")
AddEventHandler("SupplyChain:Client:ShowRestaurantStock", function(restaurantId, stockData)
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant then
        Framework.Notify(nil, "Invalid restaurant configuration", "error")
        return
    end
    
    -- Open stock interface
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    exports.ox_inventory:openInventory('stash', stashId)
end)

RegisterNetEvent("SupplyChain:Client:OrderComplete")
AddEventHandler("SupplyChain:Client:OrderComplete", function(success, message)
    if success then
        Framework.Notify(nil, message or "Order submitted successfully!", "success")
    else
        Framework.Notify(nil, message or "Failed to submit order", "error")
    end
    
    currentOrderItems = {}
    currentOrderRestaurantId = nil
end)

-- Business Events (Billing, Chairs, etc.)
RegisterNetEvent('SupplyChain:Client:ChargeCustomer')
AddEventHandler('SupplyChain:Client:ChargeCustomer', function(data)
    TriggerEvent(Config.BillingEvents.restaurant)
end)

RegisterNetEvent('SupplyChain:Client:CustomerPay')
AddEventHandler('SupplyChain:Client:CustomerPay', function(data)
    TriggerEvent(Config.BillingEvents.customer)
end)

RegisterNetEvent('SupplyChain:Client:OpenTray')
AddEventHandler('SupplyChain:Client:OpenTray', function(data)
    if type(data) == 'table' and data.job and data.trayId then
        local stashName = "order-tray-" .. data.job .. "-" .. data.trayId
        exports.ox_inventory:openInventory('stash', stashName)
    else
        Framework.Notify(nil, "Invalid tray data", "error")
    end
end)

RegisterNetEvent('SupplyChain:Client:OpenStorage')
AddEventHandler('SupplyChain:Client:OpenStorage', function(data)
    if type(data) == 'table' and data.job and data.storageId then
        local stashName = "storage-" .. data.job .. "-" .. data.storageId
        exports.ox_inventory:openInventory('stash', stashName)
    else
        Framework.Notify(nil, "Invalid storage data", "error")
    end
end)

RegisterNetEvent('SupplyChain:Client:ToggleDuty')
AddEventHandler('SupplyChain:Client:ToggleDuty', function(job)
    if lib.progressCircle({
        duration = 3000,
        label = 'Toggling Duty',
        position = 'bottom',
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true,
        },
        anim = {
            dict = 'amb@world_human_clipboard@male@idle_a',
            clip = 'idle_a'
        },
    }) then
        TriggerServerEvent('QBCore:ToggleDuty')
        Framework.Notify(nil, "Duty status toggled", "success")
    end
end)

RegisterNetEvent('SupplyChain:Client:ShowMenu')
AddEventHandler('SupplyChain:Client:ShowMenu', function(data)
    local restaurant = nil
    
    if data and data.restaurantId then
        restaurant = Config.Restaurants[data.restaurantId]
    elseif data and data.job then
        restaurant = Config.GetRestaurantByJob(data.job)
    end
    
    if not restaurant or not restaurant.menu then
        Framework.Notify(nil, "No menu available", "error")
        return
    end
    
    lib.alertDialog({
        header = restaurant.jobDisplay .. ' Menu',
        content = '![Menu Image](' .. restaurant.menu .. ')',
        centered = true,
        cancel = true,
        size = 'xl',
        labels = {
            confirm = 'OK'
        }
    })
end)

RegisterNetEvent('SupplyChain:Client:SitChair')
AddEventHandler('SupplyChain:Client:SitChair', function(data)
    local ped = PlayerPedId()
    local coords = data.coords
    
    if not coords or not coords.x or not coords.y or not coords.z then
        Framework.Notify(nil, "Invalid chair coordinates", "error")
        return
    end
    
    -- Adjust coordinates based on targeting system
    local adjustedCoords = vector3(coords.x, coords.y, coords.z - 0.5)
    
    -- Check distance
    if #(GetEntityCoords(ped) - adjustedCoords) > 2.0 then
        Framework.Notify(nil, "You are too far from the chair", "error")
        return
    end
    
    -- Check for nearby players
    local playersNearby = Framework.GetPlayersFromCoords(adjustedCoords, 0.5)
    for _, player in ipairs(playersNearby) do
        if player ~= PlayerId() then
            Framework.Notify(nil, "This seat is taken", "error")
            return
        end
    end
    
    -- Sit animation
    TaskGoStraightToCoord(ped, adjustedCoords.x, adjustedCoords.y, adjustedCoords.z, 1.0, 2000, coords.w or 0.0, 0.1)
    Wait(1200)
    TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR_MP_PLAYER", adjustedCoords.x, adjustedCoords.y, adjustedCoords.z, coords.w or 0.0, 0, true, true)
    
    Framework.Notify(nil, "You sat down. Press E to stand up", "success")
    
    -- Stand up thread
    CreateThread(function()
        while IsPedUsingScenario(ped, "PROP_HUMAN_SEAT_CHAIR_MP_PLAYER") do
            if IsControlJustPressed(0, 38) then -- E key
                ClearPedTasks(ped)
                break
            end
            Wait(0)
        end
    end)
end)

-- Export restaurant functions
exports('GetRestaurantFunctions', function()
    return Restaurant
end)