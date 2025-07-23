-- Restaurant Target Zones System

local Framework = SupplyChain.Framework

-- Create all restaurant zones
CreateThread(function()
    -- Wait for config to load
    while not Config or not Config.Restaurants do
        Wait(100)
    end
    
    -- Create zones for each restaurant
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        -- Order Station Zone
        if restaurant.position then
            exports.ox_target:addBoxZone({
                coords = restaurant.position,
                size = vector3(1.0, 1.0, 2.0),
                rotation = restaurant.heading or 0.0,
                debug = Config.Debug.showZones,
                options = {
                    {
                        name = "restaurant_order_" .. tostring(restaurantId),
                        icon = "fas fa-shopping-cart",
                        label = "Order Ingredients",
                        groups = restaurant.job,
                        onSelect = function()
                            -- Get warehouse stock and prices
                            local warehouseStock = StateManager and StateManager.GetWarehouseStock() or {}
                            local dynamicPrices = {}
                            
                            -- Try to get dynamic prices if market system is enabled
                            if Config.DynamicMarket and Config.DynamicMarket.enabled then
                                local success, prices = pcall(function()
                                    return exports['ogz_supplychain']:GetDynamicPrices()
                                end)
                                if success then
                                    dynamicPrices = prices or {}
                                end
                            end
                            
                            -- Trigger the new shopping cart menu
                            TriggerEvent("SupplyChain:Client:OpenRestaurantMenu", {
                                restaurantId = restaurantId,
                                restaurant = restaurant,
                                warehouseStock = warehouseStock,
                                dynamicPrices = dynamicPrices,
                                clearCart = true
                            })
                        end
                    },
                    {
                        name = "restaurant_stock_" .. tostring(restaurantId),
                        icon = "fas fa-box",
                        label = "Check Stock",
                        groups = restaurant.job,
                        onSelect = function()
                            TriggerEvent("SupplyChain:Client:ShowRestaurantStock", restaurantId)
                        end
                    }
                }
            })
        end
        
        -- Clock In Zone
        if restaurant.clockin then
            exports.ox_target:addBoxZone({
                coords = vector3(restaurant.clockin.coords.x, restaurant.clockin.coords.y, restaurant.clockin.coords.z),
                size = vec3(
                    restaurant.clockin.dimensions.length,
                    restaurant.clockin.dimensions.width,
                    restaurant.clockin.dimensions.height
                ),
                rotation = restaurant.clockin.coords.w,
                debug = Config.Debug.showZones,
                options = {
                    {
                        name = "clockin_" .. restaurant.job,
                        icon = "fas fa-clock",
                        label = "Clock In/Out",
                        groups = restaurant.job,
                        onSelect = function()
                            TriggerEvent("SupplyChain:Client:ToggleDuty", restaurant.job)
                        end,
                    },
                },
                distance = 2.0
            })
        end
        
        -- Register Zones
        if restaurant.registers then
            for registerId, register in pairs(restaurant.registers) do
                local coords = register.coords
                exports.ox_target:addBoxZone({
                    coords = vector3(coords.x, coords.y, coords.z - 0.2),
                    size = vec3(0.5, 0.5, 0.5),
                    rotation = coords.w,
                    debug = Config.Debug.showZones,
                    options = {
                        {
                            name = "register_charge_" .. restaurant.job .. "_" .. registerId,
                            icon = "fas fa-credit-card",
                            label = "Access Register",
                            groups = restaurant.job,
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:ChargeCustomer", {
                                    job = restaurant.job,
                                    restaurantId = restaurantId
                                })
                            end,
                        },
                        {
                            name = "register_menu_" .. restaurant.job .. "_" .. registerId,
                            icon = "fas fa-user-check",
                            label = "Show Menu",
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:ShowMenu", {
                                    job = restaurant.job,
                                    restaurantId = restaurantId
                                })
                            end,
                        },
                        {
                            name = "register_pay_" .. restaurant.job .. "_" .. registerId,
                            icon = "fas fa-money-bill",
                            label = "Pay",
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:CustomerPay", {
                                    job = restaurant.job,
                                    restaurantId = restaurantId
                                })
                            end,
                        }
                    },
                    distance = 2.0
                })
                
                -- Create register prop if specified
                if register.prop then
                    CreateThread(function()
                        local model = GetHashKey("prop_till_01")
                        RequestModel(model)
                        while not HasModelLoaded(model) do
                            Wait(100)
                        end
                        
                        local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
                        SetEntityHeading(prop, coords.w)
                        FreezeEntityPosition(prop, true)
                        SetModelAsNoLongerNeeded(model)
                    end)
                end
            end
        end
        
        -- Tray Zones
        if restaurant.trays then
            for trayId, tray in pairs(restaurant.trays) do
                local coords = tray.coords
                exports.ox_target:addBoxZone({
                    coords = vector3(coords.x, coords.y, coords.z - 0.62),
                    size = vec3(0.5, 0.5, 0.25),
                    rotation = coords.w,
                    debug = Config.Debug.showZones,
                    options = {
                        {
                            name = "tray_" .. restaurant.job .. "_" .. trayId,
                            icon = "fas fa-basket-shopping",
                            label = "Open Tray",
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:OpenTray", {
                                    job = restaurant.job,
                                    trayId = trayId
                                })
                            end,
                        },
                    },
                    distance = 2.0
                })
            end
        end
        
        -- Storage Zones
        if restaurant.storage then
            for storageId, storage in pairs(restaurant.storage) do
                local coords = storage.coords
                exports.ox_target:addBoxZone({
                    coords = vector3(coords.x, coords.y, coords.z - 0.62),
                    size = vec3(
                        storage.dimensions.width or 1.5,
                        storage.dimensions.length or 0.6,
                        storage.dimensions.height or 1.0
                    ),
                    rotation = coords.w,
                    debug = Config.Debug.showZones,
                    options = {
                        {
                            name = "storage_" .. restaurant.job .. "_" .. storageId,
                            icon = "fas fa-dolly",
                            label = storage.targetLabel,
                            groups = restaurant.job,
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:OpenStorage", {
                                    job = restaurant.job,
                                    storageId = storageId
                                })
                            end,
                        },
                    },
                    distance = 2.0
                })
            end
        end
        
        -- Cooking/Preparation Zones
        if restaurant.cookLocations then
            for cookId, cookLocation in pairs(restaurant.cookLocations) do
                local coords = cookLocation.coords
                exports.ox_target:addBoxZone({
                    coords = vector3(coords.x, coords.y, coords.z - 0.52),
                    size = vec3(
                        cookLocation.dimensions.length or 1.5,
                        cookLocation.dimensions.width or 0.6,
                        cookLocation.dimensions.height or 0.35
                    ),
                    rotation = coords.w,
                    debug = Config.Debug.showZones,
                    options = {
                        {
                            name = "cook_" .. restaurant.job .. "_" .. cookId,
                            icon = "fas fa-utensils",
                            label = cookLocation.targetLabel,
                            groups = restaurant.job,
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:PrepareFood", {
                                    job = restaurant.job,
                                    locationId = cookId,
                                    restaurantId = restaurantId
                                })
                            end,
                        },
                    },
                    distance = 2.0
                })
            end
        end
        
        -- Chair Zones
        if restaurant.chairs then
            for chairId, chair in pairs(restaurant.chairs) do
                local coords = chair.coords
                exports.ox_target:addBoxZone({
                    coords = vector3(coords.x, coords.y, coords.z - 0.65),
                    size = vec3(0.6, 0.6, 0.25),
                    rotation = coords.w,
                    debug = Config.Debug.showZones,
                    options = {
                        {
                            name = "chair_" .. restaurant.job .. "_" .. chairId,
                            icon = "fas fa-couch",
                            label = "Sit Down",
                            onSelect = function()
                                TriggerEvent("SupplyChain:Client:SitChair", {
                                    coords = coords,
                                    job = restaurant.job
                                })
                            end,
                        },
                    },
                    distance = 2.5
                })
            end
        end
    end
    
    -- Create blips for restaurants
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.blip then
            local blip = AddBlipForCoord(restaurant.position.x, restaurant.position.y, restaurant.position.z)
            SetBlipSprite(blip, restaurant.blip.sprite)
            SetBlipScale(blip, restaurant.blip.scale)
            SetBlipColour(blip, restaurant.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(restaurant.jobDisplay or restaurant.name)
            EndTextCommandSetBlipName(blip)
        end
    end
    
    print("^2[SupplyChain]^7 Restaurant zones initialized")
end)