local QBCore = exports['qb-core']:GetCoreObject()

-- Container Station Setup
Citizen.CreateThread(function()
    if not Config.ContainerStations then
        print("[ERROR] Config.ContainerStations not defined")
        return
    end
    
    for _, station in ipairs(Config.ContainerStations) do
        exports.ox_target:addBoxZone({
            coords = station.position,
            size = vector3(2.0, 2.0, 1.0),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = "container_station_" .. station.name,
                    icon = "fas fa-box",
                    label = "Get Containers",
                    onSelect = function()
                        TriggerEvent("containers:openSupplyMenu", station)
                    end
                }
            }
        })
        
        -- Add blip for container stations
        local blip = AddBlipForCoord(station.position.x, station.position.y, station.position.z)
        SetBlipSprite(blip, 478)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.5)
        SetBlipColour(blip, 25)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Container Station")
        EndTextCommandSetBlipName(blip)
    end
end)

-- Container Supply Menu
RegisterNetEvent("containers:openSupplyMenu")
AddEventHandler("containers:openSupplyMenu", function(station)
    local options = {}
    
    for _, containerType in ipairs(station.containerTypes) do
        table.insert(options, {
            title = containerType:gsub("_", " "):gsub("^%l", string.upper),
            description = "Take empty containers for packing",
            icon = "fas fa-box",
            onSelect = function()
                local input = lib.inputDialog("Take Containers", {
                    { type = "number", label = "Amount", min = 1, max = 50, required = true }
                })
                if input and input[1] and tonumber(input[1]) > 0 then
                    local amount = tonumber(input[1])
                    TriggerServerEvent("containers:giveEmpty", containerType, amount)
                end
            end
        })
    end
    
    lib.registerContext({
        id = "container_supply_menu",
        title = station.name,
        options = options
    })
    lib.showContext("container_supply_menu")
end)