QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
    if not Config.WarehousesLocation then
        print("[ERROR] Config.WarehousesLocation not loaded in cl_warehouse.lua")
        return
    end
    for index, warehouse in ipairs(Config.WarehousesLocation or {}) do
        exports.ox_target:addBoxZone({
            coords = warehouse.position,
            size = vector3(1.0, 0.5, 3.5),
            rotation = warehouse.heading,
            debug = false,
            options = {
                {
                    name = "warehouse_processing_" .. tostring(index),
                    icon = "fas fa-box",
                    label = "Process Orders",
                    onSelect = function()
                        TriggerEvent("warehouse:openProcessingMenu")
                    end
                }
            }
        })

        local pedModel = GetHashKey(warehouse.pedhash)
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do
            Wait(500)
        end
        local ped = CreatePed(4, pedModel, warehouse.position.x, warehouse.position.y, warehouse.position.z, warehouse.heading, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetModelAsNoLongerNeeded(pedModel)

        local blip = AddBlipForCoord(warehouse.position.x, warehouse.position.y, warehouse.position.z)
        SetBlipSprite(blip, 473)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 16)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Warehouse")
        EndTextCommandSetBlipName(blip)
    end
end)

RegisterNetEvent("warehouse:openProcessingMenu")
AddEventHandler("warehouse:openProcessingMenu", function()
    local options = {
        { title = "View Stock", description = "Check warehouse stock levels.", icon = "fas fa-warehouse", onSelect = function() TriggerServerEvent("warehouse:getStocks") end },
        { title = "View Orders", description = "View pending orders for delivery.", icon = "fas fa-box", onSelect = function() TriggerServerEvent("warehouse:getPendingOrders") end },
        { title = "Leaderboard", description = "View top delivery drivers.", icon = "fas fa-trophy", onSelect = function() TriggerServerEvent("warehouse:getLeaderboard") end }
    }
    lib.registerContext({
        id = "main_menu",
        title = "Warehouse Menu",
        options = options
    })
    lib.showContext("main_menu")
end)

RegisterNetEvent("warehouse:showOrderDetails")
AddEventHandler("warehouse:showOrderDetails", function(orders)
    if not orders or #orders == 0 then
        lib.notify({
            title = "No Orders",
            description = "There are no active orders at the moment.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local itemNames = exports.ox_inventory:Items() or {}
    local options = {}
    for _, order in ipairs(orders) do
        local restaurantId = order.restaurantId
        local orderGroupId = order.orderGroupId
        local restaurantData = Config.Restaurants and Config.Restaurants[restaurantId] or {}
        local restaurantName = restaurantData.name or "Unknown Business"
        local itemDescriptions = {}
        for _, item in ipairs(order.items) do
            local itemLabel = itemNames[item.itemName] and itemNames[item.itemName].label or item.itemName
            table.insert(itemDescriptions, string.format("%s (x%d)", itemLabel, item.quantity))
        end
        table.insert(options, {
            title = string.format("Order for %s", restaurantName),
            description = string.format("**Items**: %s\n**Total Cost**: $%d", table.concat(itemDescriptions, ", "), order.totalCost),
            metadata = {
                Items = table.concat(itemDescriptions, ", "),
                Cost = "$" .. tostring(order.totalCost)
            },
            onSelect = function()
                lib.registerContext({
                    id = "order_action_menu",
                    title = "Order Actions",
                    options = {
                        {
                            title = "Form Team",
                            description = "Invite players to join this delivery.",
                            icon = "fas fa-users",
                            onSelect = function()
                                TriggerEvent("warehouse:openTeamMenu", { orderGroupId = orderGroupId, restaurantId = restaurantId })
                            end
                        },
                        {
                            title = "Accept Solo",
                            description = "Accept the order for solo delivery.",
                            icon = "fas fa-truck",
                            onSelect = function()
                                local currentTime = GetGameTimer()
                                if currentTime - lastDeliveryTime < DELIVERY_COOLDOWN then
                                    lib.notify({
                                        title = "Error",
                                        description = "Please wait " .. math.ceil((DELIVERY_COOLDOWN - (currentTime - lastDeliveryTime)) / 1000) .. " seconds before accepting another delivery.",
                                        type = "error",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                    return
                                end
                                TriggerServerEvent("warehouse:acceptOrder", orderGroupId, restaurantId)
                            end
                        },
                        {
                            title = "Deny Order",
                            description = "Deny this order.",
                            icon = "fas fa-times",
                            onSelect = function()
                                TriggerServerEvent("warehouse:denyOrder", orderGroupId)
                            end
                        }
                    }
                })
                lib.showContext("order_action_menu")
            end
        })
    end
    lib.registerContext({
        id = "order_menu",
        title = "Active Orders",
        options = options
    })
    lib.showContext("order_menu")
end)

RegisterNetEvent("warehouse:openTeamMenu")
AddEventHandler("warehouse:openTeamMenu", function(deliveryData)
    if not QBCore then
        print("[ERROR] QBCore not initialized in cl_warehouse.lua")
        lib.notify({
            title = "Error",
            description = "QBCore framework not loaded. Contact server admin.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local options = {
        {
            title = "Invite Player",
            description = "Invite a nearby player to join your delivery team.",
            icon = "fas fa-user-plus",
            onSelect = function()
                local nearbyPlayers = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 10.0)
                local playerOptions = {}
                for _, playerId in ipairs(nearbyPlayers) do
                    local xPlayer = QBCore.Functions.GetPlayer(playerId)
                    if xPlayer and playerId ~= PlayerId() then
                        table.insert(playerOptions, {
                            title = xPlayer.PlayerData.name,
                            description = "Invite this player to your delivery team.",
                            onSelect = function()
                                TriggerServerEvent("warehouse:inviteToTeam", playerId, deliveryData.orderGroupId)
                            end
                        })
                    end
                end
                if #playerOptions == 0 then
                    lib.notify({
                        title = "No Players Nearby",
                        description = "No players found within 10 meters.",
                        type = "error",
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    return
                end
                lib.registerContext({
                    id = "team_invite_menu",
                    title = "Invite to Delivery Team",
                    options = playerOptions
                })
                lib.showContext("team_invite_menu")
            end
        },
        {
            title = "Start Delivery",
            description = "Begin the delivery with your current team.",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerServerEvent("warehouse:acceptOrder", deliveryData.orderGroupId, deliveryData.restaurantId)
            end
        }
    }
    lib.registerContext({
        id = "team_menu",
        title = "Delivery Team Management",
        options = options
    })
    lib.showContext("team_menu")
end)

RegisterNetEvent("warehouse:receiveTeamInvite")
AddEventHandler("warehouse:receiveTeamInvite", function(inviterName, orderGroupId)
    lib.notify({
        title = "Delivery Team Invite",
        description = string.format("**%s** invited you to join a delivery team. Accept?", inviterName),
        type = "info",
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown,
        buttons = {
            {
                label = "Accept",
                onSelect = function()
                    TriggerServerEvent("warehouse:joinTeam", orderGroupId)
                end
            },
            {
                label = "Decline",
                onSelect = function()
                    lib.notify({
                        title = "Invite Declined",
                        description = "You declined the delivery team invite.",
                        type = "error",
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            }
        }
    })
end)

RegisterNetEvent("warehouse:spawnVehicles")
AddEventHandler("warehouse:spawnVehicles", function(restaurantId, orders)
    if not Config.Warehouses then
        print("[ERROR] Config.Warehouses not loaded in cl_warehouse.lua")
        lib.notify({
            title = "Error",
            description = "Warehouse configuration not loaded.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local currentTime = GetGameTimer()
    if currentTime - lastDeliveryTime < DELIVERY_COOLDOWN then
        lib.notify({
            title = "Error",
            description = "Please wait " .. math.ceil((DELIVERY_COOLDOWN - (currentTime - lastDeliveryTime)) / 1000) .. " seconds before starting another delivery.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local lastDeliveryTime = currentTime

    local warehouseConfig = Config.Warehouses and Config.Warehouses[1] or {}
    if not warehouseConfig or not warehouseConfig.vehicle then
        print("[ERROR] No warehouse configuration found")
        lib.notify({
            title = "Error",
            description = "No warehouse configuration found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    lib.alertDialog({
        header = "New Delivery Job",
        content = "Load 3 boxes from the warehouse into the van, then deliver them to the restaurant!",
        centered = true,
        cancel = true
    })

    DoScreenFadeOut(2500)
    Citizen.Wait(2500)

    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey("speedo")
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(100)
    end

    local van = CreateVehicle(vehicleModel, warehouseConfig.vehicle.position.x, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, warehouseConfig.vehicle.position.w, true, false)
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    SetEntityCleanupByEngine(van, false)
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    DoScreenFadeIn(2500)

    lib.notify({
        title = "Van Spawned",
        description = "The delivery van is ready. Load 3 boxes from the warehouse.",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    SetEntityCoords(playerPed, warehouseConfig.vehicle.position.x + 2.0, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, true, true, true, false)
    TriggerEvent("warehouse:loadBoxes", warehouseConfig, van, restaurantId, orders)
end)

RegisterNetEvent("warehouse:loadBoxes")
AddEventHandler("warehouse:loadBoxes", function(warehouseConfig, van, restaurantId, orders)
    if not DoesEntityExist(van) then
        lib.notify({
            title = "Error",
            description = "Delivery van not found. Please restart the job.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    if not exports.ox_target then
        lib.notify({
            title = "Error",
            description = "ox_target dependency missing. Contact server admin.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local boxCount = 0
    local maxBoxes = REQUIRED_BOXES
    local hasBox = false
    local boxProp = nil
    local boxBlips = {}
    local boxEntities = {}
    local targetZones = {}
    local vanTargetName = "van_load_" .. tostring(GetGameTimer())
    local pallet = nil

    local propName = Config.CarryBoxProp or "ng_proc_box_01a"
    local palletProp = "prop_pallet_02a"
    local model = GetHashKey(propName)
    local palletModel = GetHashKey(palletProp)
    RequestModel(model)
    RequestModel(palletModel)
    while not HasModelLoaded(model) or not HasModelLoaded(palletModel) do
        Citizen.Wait(100)
    end

    local palletPos = warehouseConfig.boxPositions and warehouseConfig.boxPositions[1]
    if palletPos then
        pallet = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
        if DoesEntityExist(pallet) then
            PlaceObjectOnGroundProperly(pallet)
        end
    end

    for i, pos in ipairs(warehouseConfig.boxPositions or {}) do
        local box = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
        if DoesEntityExist(box) then
            PlaceObjectOnGroundProperly(box)
            table.insert(boxEntities, box)
        end

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

        Citizen.CreateThread(function()
            while DoesEntityExist(box) do
                DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 255, 255, 0, 100, false, true, 2, false, "", "", false)
                Citizen.Wait(0)
            end
        end)

        local zoneName = "box_pickup_" .. i
        exports.ox_target:addBoxZone({
            coords = vector3(pos.x, pos.y, pos.z),
            size = vector3(2.0, 2.0, 2.0),
            rotation = 0,
            debug = false,
            name = zoneName,
            options = {
                {
                    label = "Pick Up Box",
                    icon = "fas fa-box",
                    onSelect = function()
                        if hasBox then
                            lib.notify({
                                title = "Error",
                                description = "You are already carrying a box.",
                                type = "error",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            return
                        end
                        if not DoesEntityExist(van) then
                            lib.notify({
                                title = "Error",
                                description = "Delivery van not found. Please restart the job.",
                                type = "error",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            return
                        end
                        local itemNames = exports.ox_inventory:Items() or {}
                        local itemLabel = orders[boxCount + 1] and itemNames[orders[boxCount + 1].itemName] and itemNames[orders[boxCount + 1].itemName].label or orders[boxCount + 1] and orders[boxCount + 1].itemName or "item"
                        if lib.progressBar({
                            duration = 3000,
                            position = "bottom",
                            label = "Picking Up Box (" .. itemLabel .. ")...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "anim@heists@box_carry@", clip = "idle" },
                            style = Config.UI.theme
                        }) then
                            if DoesEntityExist(box) then
                                DeleteObject(box)
                                for j, entity in ipairs(boxEntities) do
                                    if entity == box then
                                        table.remove(boxEntities, j)
                                        break
                                    end
                                end
                            end
                            local coords = GetEntityCoords(playerPed)
                            boxProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
                            if DoesEntityExist(boxProp) then
                                AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 57005),
                                    0.12, 0.05, 0.1, 0.0, 90.0, 0.0, true, true, false, true, 1, true)

                                hasBox = true
                                local animDict = "anim@heists@box_carry@"
                                RequestAnimDict(animDict)
                                while not HasAnimDictLoaded(animDict) do
                                    Citizen.Wait(0)
                                end
                                TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                                lib.notify({
                                    title = "Box Picked Up",
                                    description = "Load " .. itemLabel .. " into the van.",
                                    type = "success",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                            else
                                lib.notify({
                                    title = "Error",
                                    description = "Failed to create box object.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                            end
                        end
                    end
                }
            }
        })
        table.insert(targetZones, zoneName)
        if i >= REQUIRED_BOXES then break end
    end

    local vanCoords = GetEntityCoords(van)
    local vanBlip = AddBlipForCoord(vanCoords.x, vanCoords.y, vanCoords.z)
    SetBlipSprite(vanBlip, 1)
    SetBlipDisplay(vanBlip, 4)
    SetBlipScale(vanBlip, 1.0)
    SetBlipColour(vanBlip, 3)
    SetBlipAsShortRange(vanBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Van Location")
    EndTextCommandSetBlipName(vanBlip)

    local function updateVanTargetZone()
        while DoesEntityExist(van) and boxCount < maxBoxes do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )
            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = "Load Box",
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            if not hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You need to pick up a box first.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            if #(GetEntityCoords(playerPed) - vanBackPosition) > 3.0 then
                                lib.notify({
                                    title = "Error",
                                    description = "Move closer to the van's back.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            local itemNames = exports.ox_inventory:Items() or {}
                            local itemLabel = orders[boxCount + 1] and itemNames[orders[boxCount + 1].itemName] and itemNames[orders[boxCount + 1].itemName].label or orders[boxCount + 1] and orders[boxCount + 1].itemName or "item"
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = "Loading Box (" .. itemLabel .. ")...",
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "anim@heists@box_carry@", clip = "idle" },
                                style = Config.UI.theme
                            }) then
                                if boxProp and DoesEntityExist(boxProp) then
                                    DeleteObject(boxProp)
                                    boxProp = nil
                                    hasBox = false
                                    boxCount = boxCount + 1
                                    ClearPedTasks(playerPed)
                                    lib.notify({
                                        title = "Box Loaded",
                                        description = itemLabel .. " loaded into the van. " .. (maxBoxes - boxCount) .. " boxes left.",
                                        type = "success",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                    if boxCount >= maxBoxes then
                                        RemoveBlip(vanBlip)
                                        for _, blip in ipairs(boxBlips) do
                                            RemoveBlip(blip)
                                        end
                                        for _, zone in ipairs(targetZones) do
                                            exports.ox_target:removeZone(zone)
                                        end
                                        exports.ox_target:removeZone(vanTargetName)
                                        for _, entity in ipairs(boxEntities) do
                                            if DoesEntityExist(entity) then
                                                DeleteObject(entity)
                                            end
                                        end
                                        if pallet and DoesEntityExist(pallet) then
                                            DeleteObject(pallet)
                                            pallet = nil
                                        end
                                        TriggerEvent("warehouse:startDelivery", restaurantId, van, orders)
                                    end
                                else
                                    lib.notify({
                                        title = "Error",
                                        description = "Box object not found.",
                                        type = "error",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                end
                            end
                        end
                    }
                }
            })
            DrawMarker(1, vanBackPosition.x, vanBackPosition.y, vanBackPosition.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.5, 0, 255, 0, 100, false, true, 2, false, "", "", false)
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateVanTargetZone)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = orders[1] and itemNames[orders[1].itemName] and itemNames[orders[1].itemName].label or orders[1] and orders[1].itemName or "item"
    lib.notify({
        title = "Box Available",
        description = "Pick up " .. itemLabel .. " from the marked pallet in the warehouse.",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

RegisterNetEvent("warehouse:startDelivery")
AddEventHandler("warehouse:startDelivery", function(restaurantId, van, orders)
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_warehouse.lua")
        return
    end
    lib.alertDialog({
        header = "Van Loaded",
        content = "Drive to the restaurant delivery location. Check your GPS for directions!",
        centered = true,
        cancel = true
    })

    local deliveryPosition = Config.Restaurants and Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].delivery
    if not deliveryPosition then
        deliveryPosition = vector3(-1173.53, -892.72, 13.86)
        lib.notify({
            title = "Warning",
            description = "Delivery location not found. Using default location. Contact server admin.",
            type = "info",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end

    lib.notify({
        title = "Delivery Started",
        description = "Drive to the delivery location marked on your GPS.",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    SetNewWaypoint(deliveryPosition.x, deliveryPosition.y)
    local blip = AddBlipForCoord(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location")
    EndTextCommandSetBlipName(blip)

    local textUIId = "park_van_" .. restaurantId
    Citizen.CreateThread(function()
        local isTextUIShown = false
        while true do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vector3(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z))
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Park Van", {
                        icon = "fas fa-parking"
                    })
                    isTextUIShown = true
                end
                DrawMarker(1, deliveryPosition.x, deliveryPosition.y, deliveryPosition.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 0.5, 0, 255, 0, 100, false, true, 2, false, "", "", false)
                if IsControlJustPressed(0, 38) then
                    if distance < 10.0 then
                        lib.hideTextUI()
                        isTextUIShown = false
                        RemoveBlip(blip)
                        TriggerEvent("warehouse:grabBoxFromVan", restaurantId, van, orders)
                        break
                    else
                        lib.notify({
                            title = "Error",
                            description = "Van is too far from the delivery zone.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            if not DoesEntityExist(van) then
                if isTextUIShown then
                    lib.hideTextUI()
                end
                RemoveBlip(blip)
                break
            end
            Citizen.Wait(0)
        end
    end)
end)

RegisterNetEvent("warehouse:grabBoxFromVan")
AddEventHandler("warehouse:grabBoxFromVan", function(restaurantId, van, orders)
    if not DoesEntityExist(van) then
        lib.notify({
            title = "Error",
            description = "Delivery van not found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local hasBox = false
    local boxProp = nil
    local vanTargetName = "van_grab_" .. tostring(van)
    local propName = Config.CarryBoxProp or "ng_proc_box_01a"
    local model = GetHashKey(propName)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = orders[boxCount + 1] and itemNames[orders[boxCount + 1].itemName] and itemNames[boxCount + 1].itemName.label or orders[boxCount + 1] and orders[boxCount + 1].itemName or "item"
    lib.notify({
        title = "Grab Box",
        description = "Go to the van's rear to grab " .. itemLabel .. ".",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    local function updateGrabBoxZone()
        while DoesEntityExist(van) and not hasBox do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )
            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = "Grab Box from Van",
                        icon = "fas fa-box",
                        onSelect = function()
                            if hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You are already carrying a box.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = "Grabbing Box (" .. itemLabel .. ")...",
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "anim@heists@box_carry@", clip = "idle" },
                                style = Config.UI.theme
                            }) then
                                local coords = GetEntityCoords(playerPed)
                                boxProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
                                if DoesEntityExist(boxProp) then
                                    AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 57005),
                                        0.12, 0.05, 0.1, 0.0, 90.0, 0.0, true, true, false, true, 1, true)

                                    hasBox = true
                                    local animDict = "anim@heists@box_carry@"
                                    RequestAnimDict(animDict)
                                    while not HasAnimDictLoaded(animDict) do
                                        Citizen.Wait(0)
                                    end
                                    TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                                    lib.notify({
                                        title = "Box Grabbed",
                                        description = itemLabel .. " grabbed. Deliver to the restaurant.",
                                        type = "success",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })

                                    exports.ox_target:removeZone(vanTargetName)
                                    TriggerEvent("warehouse:deliverBoxes", restaurantId, van, orders, boxProp)
                                else
                                    lib.notify({
                                        title = "Error",
                                        description = "Failed to create box object.",
                                        type = "error",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                end
                            end
                        end
                    }
                }
            })
            DrawMarker(1, vanBackPosition.x, vanBackPosition.y, vanBackPosition.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.5, 0, 255, 0, 100, false, true, 2, false, "", "", false)
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateGrabBoxZone)
end)

RegisterNetEvent("warehouse:deliverBoxes")
AddEventHandler("warehouse:deliverBoxes", function(restaurantId, van, orders, boxProp)
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_warehouse.lua")
        return
    end
    if not boxProp or not DoesEntityExist(boxProp) then
        lib.notify({
            title = "Error",
            description = "You are not carrying a box.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local deliverBoxPosition = Config.Restaurants and Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].deliveryBox
    if not deliverBoxPosition then
        deliverBoxPosition = vector3(-1177.39, -890.98, 12.79)
        lib.notify({
            title = "Warning",
            description = "Delivery location not found. Using default location. Contact server admin.",
            type = "info",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end

    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = orders[boxCount + 1] and itemNames[orders[boxCount + 1].itemName] and itemNames[orders[boxCount + 1].itemName].label or orders[boxCount + 1] and orders[boxCount + 1].itemName or "item"
    local boxBlip = AddBlipForCoord(deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z)
    SetBlipSprite(boxBlip, 1)
    SetBlipScale(boxBlip, 0.7)
    SetBlipColour(boxBlip, 4)
    SetBlipAsShortRange(boxBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Box Delivery")
    EndTextCommandSetBlipName(boxBlip)

    local targetName = "delivery_zone_" .. restaurantId .. "_" .. tostring(GetGameTimer())
    exports.ox_target:addBoxZone({
        coords = vector3(deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z + 0.5),
        size = vector3(3.0, 3.0, 3.0),
        rotation = 0,
        debug = false,
        name = targetName,
        options = {
            {
                label = "Deliver Box",
                icon = "fas fa-box",
                onSelect = function()
                    if not boxProp or not DoesEntityExist(boxProp) then
                        lib.notify({
                            title = "Error",
                            description = "You are not carrying a box.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        return
                    end
                    if lib.progressBar({
                        duration = 3000,
                        position = "bottom",
                        label = "Delivering Box (" .. itemLabel .. ")...",
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "anim@heists@box_carry@", clip = "idle" },
                        style = Config.UI.theme
                    }) then
                        if DoesEntityExist(boxProp) then
                            DeleteObject(boxProp)
                            ClearPedTasks(playerPed)
                            TriggerServerEvent("update:stock", restaurantId, { orders[boxCount + 1] })
                            lib.notify({
                                title = "Box Delivered",
                                description = itemLabel .. " delivered. " .. (REQUIRED_BOXES - boxCount - 1) .. " boxes left.",
                                type = "success",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            RemoveBlip(boxBlip)
                            exports.ox_target:removeZone(targetName)
                            local boxCount = boxCount + 1
                            if boxCount >= REQUIRED_BOXES then
                                TriggerEvent("warehouse:returnTruck", van, restaurantId, orders)
                            else
                                TriggerEvent("warehouse:grabBoxFromVan", restaurantId, van, orders)
                            end
                        else
                            lib.notify({
                                title = "Error",
                                description = "Box object not found.",
                                type = "error",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                        end
                    end
                end
            }
        }
    })

    Citizen.CreateThread(function()
        while boxCount < REQUIRED_BOXES do
            DrawMarker(1, deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.5, 255, 255, 0, 100, false, true, 2, false, "", "", false)
            Citizen.Wait(0)
        end
    end)

    lib.notify({
        title = "Deliver Box",
        description = "Take " .. itemLabel .. " to the delivery point marked on your GPS.",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

RegisterNetEvent("warehouse:returnTruck")
AddEventHandler("warehouse:returnTruck", function(van, restaurantId, orders)
    if not Config.Warehouses then
        print("[ERROR] Config.Warehouses not loaded in cl_warehouse.lua")
        return
    end
    lib.alertDialog({
        header = "Delivery Complete",
        content = "Great Work! Return the van to the warehouse.",
        centered = true,
        cancel = true
    })

    local playerPed = PlayerPedId()
    local vanReturnPosition = Config.Warehouses and Config.Warehouses[1] and Config.Warehouses[1].vehicle and vector3(Config.Warehouses[1].vehicle.position.x, Config.Warehouses[1].vehicle.position.y, Config.Warehouses[1].vehicle.position.z) or vector3(0.0, 0.0, 0.0)
    SetNewWaypoint(vanReturnPosition.x, vanReturnPosition.y)

    local blip = AddBlipForCoord(vanReturnPosition.x, vanReturnPosition.y, vanReturnPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Van Return Location")
    EndTextCommandSetBlipName(blip)

    local textUIId = "return_van_" .. tostring(van)
    Citizen.CreateThread(function()
        local isTextUIShown = false
        while true do
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vanReturnPosition)
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Return Van", {
                        icon = "fas fa-parking"
                    })
                    isTextUIShown = true
                end
                DrawMarker(1, vanReturnPosition.x, vanReturnPosition.y, vanReturnPosition.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 0.5, 0, 255, 0, 100, false, true, 2, false, "", "", false)
                if IsControlJustPressed(0, 38) then
                    if lib.progressBar({
                        duration = 3000,
                        label = "Returning Van...",
                        position = "bottom",
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "anim@scripted@heist@ig3_button_press@male@", clip = "button_press" },
                        style = Config.UI.theme
                    }) then
                        lib.hideTextUI()
                        isTextUIShown = false
                        lib.alertDialog({
                            header = "Van Returned",
                            content = "Delivery complete! Thank you for your work!",
                            centered = true,
                            cancel = true
                        })
                        RemoveBlip(blip)
                        DeleteVehicle(van)
                        local boxCount = 0
                        break
                    end
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            if not DoesEntityExist(van) then
                if isTextUIShown then
                    lib.hideTextUI()
                end
                RemoveBlip(blip)
                local boxCount = 0
                break
            end
            Citizen.Wait(0)
        end
    end)
end)