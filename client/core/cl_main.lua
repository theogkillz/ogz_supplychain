-- Client Core Initialization

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Global client variables
currentOrder = {}
currentOrderRestaurantId = nil
boxCount = 0
lastDeliveryTime = 0

-- Client initialization
CreateThread(function()
    -- Wait for player to be loaded
    while not Framework or not Framework.IsLoggedIn() do
        Wait(1000)
    end
    
    print("^2[SupplyChain]^7 Client systems initializing...")
    
    -- Initialize player data
    InitializePlayerData()
    
    -- Register key bindings
    RegisterKeyBindings()
    
    -- Start update loops
    StartClientLoops()
    
    print("^2[SupplyChain]^7 Client systems initialized successfully!")
end)

-- Initialize player data
function InitializePlayerData()
    local playerData = Framework.GetPlayerData()
    
    if playerData then
        -- Store relevant data
        PlayerJob = playerData.job
        PlayerGang = playerData.gang
        
        -- Check for restaurant access
        CheckRestaurantAccess()
        
        -- Check for warehouse access
        CheckWarehouseAccess()
    end
end

-- Check restaurant access
function CheckRestaurantAccess()
    if not PlayerJob then return end
    
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.job == PlayerJob.name then
            print(string.format("^2[SupplyChain]^7 Player has access to %s", restaurant.name))
            break
        end
    end
end

-- Check warehouse access
function CheckWarehouseAccess()
    if not PlayerJob then return end
    
    for _, jobName in ipairs(Config.Warehouse.jobAccess) do
        if PlayerJob.name == jobName then
            print("^2[SupplyChain]^7 Player has warehouse access")
            break
        end
    end
end

-- Register key bindings
function RegisterKeyBindings()
    -- Open supply chain menu (M key)
    RegisterKeyMapping('supplychain_menu', 'Open Supply Chain Menu', 'keyboard', 'M')
    RegisterCommand('supplychain_menu', function()
        OpenMainMenu()
    end, false)
    
    -- Cancel current action (X key)
    RegisterKeyMapping('supplychain_cancel', 'Cancel Current Action', 'keyboard', 'X')
    RegisterCommand('supplychain_cancel', function()
        CancelCurrentAction()
    end, false)
end

-- Start client loops
function StartClientLoops()
    -- Job update listener
    CreateThread(function()
        while true do
            Wait(1000)
            
            local currentData = Framework.GetPlayerData()
            if currentData and currentData.job then
                if not PlayerJob or PlayerJob.name ~= currentData.job.name then
                    PlayerJob = currentData.job
                    CheckRestaurantAccess()
                    CheckWarehouseAccess()
                end
            end
        end
    end)
    
    -- Performance optimization - cleanup distant objects
    if Config.Debug.performanceMode then
        CreateThread(function()
            while true do
                Wait(5000)
                
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                
                -- Cleanup distant props
                local objects = GetGamePool('CObject')
                for _, object in ipairs(objects) do
                    local model = GetEntityModel(object)
                    if model == GetHashKey(Config.Warehouse.carryBoxProp) then
                        local objCoords = GetEntityCoords(object)
                        if #(playerCoords - objCoords) > 100.0 then
                            if NetworkGetEntityIsNetworked(object) then
                                DeleteEntity(object)
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Open main menu based on job
function OpenMainMenu()
    local playerData = Framework.GetPlayerData()
    if not playerData or not playerData.job then
        Framework.Notify(nil, "Unable to access menu", "error")
        return
    end
    
    local options = {}
    
    -- Restaurant options
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.job == playerData.job.name then
            table.insert(options, {
                title = "Restaurant Management",
                description = "Access restaurant features",
                icon = "fas fa-utensils",
                onSelect = function()
                    OpenRestaurantMenu(restaurantId)
                end
            })
            break
        end
    end
    
    -- Warehouse options
    local hasWarehouseAccess = false
    for _, jobName in ipairs(Config.Warehouse.jobAccess) do
        if playerData.job.name == jobName then
            hasWarehouseAccess = true
            break
        end
    end
    
    if hasWarehouseAccess then
        table.insert(options, {
            title = "Warehouse Operations",
            description = "Access warehouse features",
            icon = "fas fa-warehouse",
            onSelect = function()
                local Warehouse = exports['ogz_supplychain']:GetWarehouseFunctions()
                Warehouse.OpenMainMenu()
            end
        })
    end
    
    -- Player stats
    table.insert(options, {
        title = "My Statistics",
        description = "View your performance stats",
        icon = "fas fa-chart-line",
        onSelect = function()
            TriggerServerEvent("SupplyChain:Server:GetPlayerStats")
        end
    })
    
    -- Achievements
    table.insert(options, {
        title = "Achievements",
        description = "View your achievements",
        icon = "fas fa-trophy",
        onSelect = function()
            TriggerServerEvent("SupplyChain:Server:GetPlayerAchievements")
        end
    })
    
    if #options == 0 then
        Framework.Notify(nil, "No supply chain features available for your job", "error")
        return
    end
    
    lib.registerContext({
        id = "supplychain_main_menu",
        title = "Supply Chain System",
        options = options
    })
    
    lib.showContext("supplychain_main_menu")
end

-- Open restaurant menu
function OpenRestaurantMenu(restaurantId)
    local options = {
        {
            title = "Order Ingredients",
            description = "Order supplies from warehouse",
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerServerEvent(Constants.Events.Server.GetWarehouseStockForOrder, restaurantId)
            end
        },
        {
            title = "Check Stock",
            description = "View current restaurant stock",
            icon = "fas fa-box",
            onSelect = function()
                TriggerEvent(Constants.Events.Client.ShowRestaurantStock, restaurantId)
            end
        },
        {
            title = "Quick Reorder",
            description = "Reorder common supplies",
            icon = "fas fa-redo",
            onSelect = function()
                TriggerEvent("SupplyChain:Client:QuickReorderMenu", {
                    restaurantId = restaurantId,
                    restaurant = Config.Restaurants[restaurantId]
                })
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_menu",
        title = Config.Restaurants[restaurantId].name .. " Management",
        menu = "supplychain_main_menu",
        options = options
    })
    
    lib.showContext("restaurant_menu")
end

-- Cancel current action
function CancelCurrentAction()
    -- Cancel delivery if active
    if exports['ogz_supplychain']:IsInDelivery() then
        lib.registerContext({
            id = 'cancel_confirmation',
            title = 'Cancel Delivery?',
            options = {
                {
                    title = 'Are you sure you want to cancel the current delivery?',
                    description = 'You will receive a penalty for cancelling',
                    disabled = true
                },
                {
                    title = 'Yes, Cancel',
                    icon = 'fas fa-check',
                    onSelect = function()
                        local Warehouse = exports['ogz_supplychain']:GetWarehouseFunctions()
                        Warehouse.CancelDelivery()
                    end
                },
                {
                    title = 'No, Continue',
                    icon = 'fas fa-times',
                    onSelect = function()
                        Framework.Notify(nil, "Delivery continued", "success")
                    end
                }
            }
        })
        
        lib.showContext('cancel_confirmation')
        return
    end
    
    -- Clear any active UI
    lib.hideContext()
    lib.hideTextUI()
    
    -- Clear ped tasks
    ClearPedTasks(PlayerPedId())
    
    Framework.Notify(nil, "Action cancelled", "info")
end

-- Event Handlers

-- Job update
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    CheckRestaurantAccess()
    CheckWarehouseAccess()
end)

-- Player loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    InitializePlayerData()
end)

-- Player stats received
RegisterNetEvent("SupplyChain:Client:ShowPlayerStats")
AddEventHandler("SupplyChain:Client:ShowPlayerStats", function(stats)
    if not stats then
        Framework.Notify(nil, "No statistics found", "error")
        return
    end
    
    local content = string.format([[
        **Delivery Statistics**
        Total Deliveries: %d
        Total Earnings: $%s
        Average Time: %s
        Best Time: %s
        Current Streak: %d
        
        **Experience**
        Level: %d
        XP: %d
        Next Level: %d XP
    ]],
        stats.deliveries or 0,
        lib.math.groupdigits(stats.earnings or 0),
        FormatTime(stats.average_time or 0),
        FormatTime(stats.best_time or 0),
        stats.streak or 0,
        stats.level or 1,
        stats.experience or 0,
        GetNextLevelXP(stats.level or 1)
    )
    
    lib.alertDialog({
        header = "Your Statistics",
        content = content,
        centered = true,
        cancel = true,
        size = 'md'
    })
end)

-- Leaderboard display
RegisterNetEvent(Constants.Events.Client.ShowLeaderboard)
AddEventHandler(Constants.Events.Client.ShowLeaderboard, function(leaderboard)
    if not leaderboard or #leaderboard == 0 then
        Framework.Notify(nil, "No leaderboard data available", "error")
        return
    end
    
    local options = {}
    
    for i, entry in ipairs(leaderboard) do
        local medal = ""
        if i == 1 then medal = "🥇 "
        elseif i == 2 then medal = "🥈 "
        elseif i == 3 then medal = "🥉 "
        end
        
        table.insert(options, {
            title = string.format("%s#%d - %s", medal, i, entry.name),
            description = string.format("Deliveries: %d | Earnings: $%s", 
                entry.deliveries, 
                lib.math.groupdigits(entry.earnings)
            ),
            icon = i <= 3 and "fas fa-medal" or "fas fa-user",
            metadata = {
                {label = "Average Time", value = FormatTime(entry.average_time or 0)},
                {label = "Best Time", value = FormatTime(entry.best_time or 0)},
                {label = "Streak", value = entry.streak or 0}
            }
        })
    end
    
    lib.registerContext({
        id = "leaderboard_menu",
        title = "Top Drivers Leaderboard",
        options = options
    })
    
    lib.showContext("leaderboard_menu")
end)

-- Utility Functions

function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "N/A" end
    
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    
    return string.format("%d:%02d", minutes, secs)
end

function GetNextLevelXP(currentLevel)
    if not Config.Rewards.experience.levels then return 0 end
    
    for _, level in ipairs(Config.Rewards.experience.levels) do
        if level.level > currentLevel then
            return level.xpRequired
        end
    end
    
    return 999999
end

-- Export functions
exports('GetCurrentOrder', function()
    return currentOrder
end)

exports('GetBoxCount', function()
    return boxCount
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Clean up any active props
    local objects = GetGamePool('CObject')
    for _, object in ipairs(objects) do
        local model = GetEntityModel(object)
        if model == GetHashKey(Config.Warehouse.carryBoxProp) or 
           model == GetHashKey("prop_pallet_02a") then
            if NetworkGetEntityIsNetworked(object) then
                DeleteEntity(object)
            end
        end
    end
    
    -- Clear UI
    lib.hideContext()
    lib.hideTextUI()
    
    print("^2[SupplyChain]^7 Client cleanup complete")
end)

print("^2[SupplyChain]^7 Client main system loaded")