-- Warehouse Peds and Interaction Zones

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Local storage for spawned peds
local warehousePeds = {}
local containerRentalPeds = {}
local blips = {}

-- Initialize warehouse peds and zones
CreateThread(function()
    -- Wait for everything to load
    while not Framework or not Config or not Config.Warehouses do
        Wait(1000)
    end
    
    Wait(2000) -- Extra delay to ensure everything is ready
    
    -- Spawn warehouse worker peds
    for warehouseId, warehouse in pairs(Config.Warehouses) do
        if warehouse.active then
            -- Create warehouse worker ped
            local pedModel = GetHashKey(warehouse.pedModel or 's_m_y_construct_02')
            RequestModel(pedModel)
            while not HasModelLoaded(pedModel) do
                Wait(100)
            end
            
            local ped = CreatePed(4, pedModel, 
                warehouse.position.x, 
                warehouse.position.y, 
                warehouse.position.z - 1.0, 
                warehouse.heading or 0.0, 
                false, true)
            
            -- Configure ped
            SetEntityAsMissionEntity(ped, true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetPedCanPlayAmbientAnims(ped, true)
            
            -- Add clipboard prop
            local clipboardModel = GetHashKey("p_amb_clipboard_01")
            RequestModel(clipboardModel)
            while not HasModelLoaded(clipboardModel) do
                Wait(100)
            end
            
            local clipboard = CreateObject(clipboardModel, 0, 0, 0, true, true, true)
            AttachEntityToEntity(clipboard, ped, GetPedBoneIndex(ped, 36029), 
                0.16, 0.08, 0.1, -130.0, -50.0, 0.0, true, true, false, true, 1, true)
            
            SetModelAsNoLongerNeeded(clipboardModel)
            
            -- Play animation
            RequestAnimDict("amb@world_human_clipboard@male@base")
            while not HasAnimDictLoaded("amb@world_human_clipboard@male@base") do
                Wait(100)
            end
            TaskPlayAnim(ped, "amb@world_human_clipboard@male@base", "base", 8.0, -8.0, -1, 1, 0, false, false, false)
            
            -- Store ped reference
            warehousePeds[warehouseId] = {
                ped = ped,
                clipboard = clipboard,
                warehouse = warehouse
            }
            
            -- Create interaction zone for warehouse worker
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = "warehouse_worker_menu_" .. warehouseId,
                    icon = "fas fa-warehouse",
                    label = "Warehouse Orders",
                    distance = 2.5,
                    groups = Config.Warehouse.jobAccess,
                    onSelect = function()
                        -- Open the warehouse menu
                        exports['ogz_supplychain']:OpenWarehouseMenu()
                    end
                },
                {
                    name = "warehouse_worker_info_" .. warehouseId,
                    icon = "fas fa-info-circle",
                    label = "Warehouse Information",
                    distance = 2.5,
                    onSelect = function()
                        ShowWarehouseInfo(warehouse)
                    end
                }
            })
            
            -- Create warehouse blip
            if warehouse.blip then
                local blip = AddBlipForCoord(warehouse.position.x, warehouse.position.y, warehouse.position.z)
                SetBlipSprite(blip, warehouse.blip.sprite or 473)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, warehouse.blip.scale or 0.7)
                SetBlipColour(blip, warehouse.blip.color or 16)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(warehouse.name or "Warehouse")
                EndTextCommandSetBlipName(blip)
                
                table.insert(blips, blip)
            end
            
            SetModelAsNoLongerNeeded(pedModel)
        end
    end
    
    -- Spawn container rental peds
    SpawnContainerRentalPeds()
    
    print("^2[SupplyChain]^7 Warehouse peds and zones initialized")
end)

-- Spawn container rental peds
function SpawnContainerRentalPeds()
    -- Container Rental Location 1 (Near Warehouse)
    local rentalLocations = {
        {
            coords = vector4(-75.5, 6510.2, 31.49, 45.0),
            name = "Container Rental North",
            pedModel = "s_m_y_dockwork_01"
        },
        {
            coords = vector4(-90.2, 6520.8, 31.49, 225.0),
            name = "Container Rental South",
            pedModel = "s_m_m_warehouse_01"
        }
    }
    
    for i, location in ipairs(rentalLocations) do
        -- Spawn rental ped
        local pedModel = GetHashKey(location.pedModel)
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do
            Wait(100)
        end
        
        local ped = CreatePed(4, pedModel, 
            location.coords.x, 
            location.coords.y, 
            location.coords.z - 1.0, 
            location.coords.w, 
            false, true)
        
        -- Configure ped
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        
        -- Play idle animation
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
        
        -- Store ped reference
        containerRentalPeds[i] = {
            ped = ped,
            location = location
        }
        
        -- Create interaction zone for container rental
        exports.ox_target:addLocalEntity(ped, {
            {
                name = "container_rental_menu_" .. i,
                icon = "fas fa-box",
                label = "Rent Containers",
                distance = 2.5,
                onSelect = function()
                    -- Open container rental menu
                    TriggerEvent(Constants.Events.Client.ShowContainerMenu)
                end
            },
            {
                name = "container_rental_return_" .. i,
                icon = "fas fa-undo",
                label = "Return Container",
                distance = 2.5,
                canInteract = function()
                    return exports['ogz_supplychain']:HasActiveContainer()
                end,
                onSelect = function()
                    TriggerEvent("SupplyChain:Client:InitiateContainerReturn")
                end
            },
            {
                name = "container_rental_info_" .. i,
                icon = "fas fa-info-circle",
                label = "Container Information",
                distance = 2.5,
                onSelect = function()
                    ShowContainerRentalInfo()
                end
            }
        })
        
        -- Create blip for container rental
        local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
        SetBlipSprite(blip, 478)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(location.name)
        EndTextCommandSetBlipName(blip)
        
        table.insert(blips, blip)
        
        SetModelAsNoLongerNeeded(pedModel)
    end
end

-- Show warehouse information
function ShowWarehouseInfo(warehouse)
    lib.alertDialog({
        header = warehouse.name or "Warehouse Information",
        content = [[
**Warehouse Operations**

This warehouse handles supply chain logistics for all restaurants in the area.

**Services Available:**
- View and accept delivery orders
- Team coordination
- Container management
- Performance tracking

**Working Hours:** 24/7
**Requirements:** Valid employment

To start working, speak with the warehouse manager to view available orders.
        ]],
        centered = true,
        cancel = false
    })
end

-- Show container rental information
function ShowContainerRentalInfo()
    local content = [[
**Container Rental Services**

We provide specialized containers for supply chain logistics.

**Available Containers:**
]]
    
    -- Add container types from config
    for containerType, config in pairs(Config.Containers.types) do
        local rate = Config.Containers.rental.hourlyRates[containerType] or 10
        content = content .. string.format("\n• **%s** - $%d/hour", config.name, rate)
    end
    
    content = content .. [[


**Terms & Conditions:**
- Deposit required (refundable)
- Quality affects deposit return
- Late fees apply after grace period
- Damage penalties may apply
    ]]
    
    lib.alertDialog({
        header = "Container Rental Information",
        content = content,
        centered = true,
        cancel = false
    })
end

-- Vehicle spawn helper
RegisterNetEvent("SupplyChain:Client:ShowVehicleSpawnMenu")
AddEventHandler("SupplyChain:Client:ShowVehicleSpawnMenu", function()
    -- Check if player has active delivery
    if not exports['ogz_supplychain']:IsInDelivery() then
        Framework.Notify(nil, "You need to accept a delivery order first", "error")
        return
    end
    
    -- Check if vehicle already exists
    local currentVan = exports['ogz_supplychain']:GetDeliveryVan()
    if DoesEntityExist(currentVan) then
        -- Offer to return vehicle
        lib.registerContext({
            id = 'vehicle_return_menu',
            title = 'Vehicle Management',
            options = {
                {
                    title = 'Return Current Vehicle',
                    description = 'Return your current delivery vehicle',
                    icon = 'fas fa-undo',
                    onSelect = function()
                        DeleteVehicle(currentVan)
                        Framework.Notify(nil, "Vehicle returned", "success")
                    end
                },
                {
                    title = 'Cancel',
                    icon = 'fas fa-times'
                }
            }
        })
        lib.showContext('vehicle_return_menu')
    else
        -- Spawn new vehicle
        TriggerEvent("SupplyChain:Client:RequestVehicleSpawn")
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Clean up warehouse peds
    for _, pedData in pairs(warehousePeds) do
        if DoesEntityExist(pedData.ped) then
            DeletePed(pedData.ped)
        end
        if DoesEntityExist(pedData.clipboard) then
            DeleteObject(pedData.clipboard)
        end
    end
    
    -- Clean up rental peds
    for _, pedData in pairs(containerRentalPeds) do
        if DoesEntityExist(pedData.ped) then
            DeletePed(pedData.ped)
        end
    end
    
    -- Clean up blips
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)

-- Export functions
exports('RefreshWarehousePeds', function()
    -- Clean up existing peds first
    for _, pedData in pairs(warehousePeds) do
        if DoesEntityExist(pedData.ped) then
            DeletePed(pedData.ped)
        end
    end
    warehousePeds = {}
    
    -- Respawn
    CreateThread(function()
        Wait(1000)
        -- Re-run initialization
    end)
end)