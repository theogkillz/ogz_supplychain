-- ============================================
-- WAREHOUSE UI CORE SYSTEM
-- Main warehouse interface and job validation
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- JOB VALIDATION
-- ============================================

-- Job validation helper function
local function hasWarehouseAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    if not playerJob then
        return false
    end
    
    -- Check if player's job is in authorized list
    for _, authorizedJob in ipairs(Config.Jobs.warehouse) do
        if playerJob == authorizedJob then
            return true
        end
    end
    
    return false
end

-- ============================================
-- WAREHOUSE TARGETS AND PEDS SETUP
-- ============================================

-- Warehouse setup thread
Citizen.CreateThread(function()
    for index, warehouse in ipairs(Config.WarehousesLocation) do
        -- Create target zone using enterprise system
        local targetZone = exports.ogz_supplychain:createBoxZone({
            coords = warehouse.position,
            size = vector3(1.0, 0.5, 3.5),
            rotation = warehouse.heading,
            name = "warehouse_processing_" .. tostring(index),
            options = {
                exports.ogz_supplychain:buildWarehouseInteraction(index, {
                    label = "Process Orders",
                    jobs = Config.Jobs.warehouse
                })
            }
        })

        -- Create warehouse ped
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

        -- Create warehouse blip
        local blip = AddBlipForCoord(warehouse.position.x, warehouse.position.y, warehouse.position.z)
        SetBlipSprite(blip, 473)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 16)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Warehouse")
        EndTextCommandSetBlipName(blip)
        
        Citizen.Wait(0)
    end
end)

-- ============================================
-- MAIN WAREHOUSE MENU
-- ============================================

-- Warehouse Main Menu
RegisterNetEvent("warehouse:openProcessingMenu")
AddEventHandler("warehouse:openProcessingMenu", function()
    -- Validate job access using enterprise system
    local hasAccess, message = exports.ogz_supplychain:validatePlayerAccess("warehouse")
    if not hasAccess then
        exports.ogz_supplychain:showAccessDenied("warehouse", message)
        return
    end
    
    local options = {
        { 
            title = "View Stock", 
            description = "Check warehouse inventory levels",
            icon = "fas fa-warehouse",
            onSelect = function() 
                TriggerServerEvent("warehouse:getStocks") 
            end 
        },
        { 
            title = "View Orders", 
            description = "Process pending delivery orders",
            icon = "fas fa-clipboard-list",
            onSelect = function() 
                TriggerServerEvent("warehouse:getPendingOrders") 
            end 
        },
        {
            title = "🚨 Stock Alerts Dashboard",
            description = "Monitor inventory levels and predictions",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("stockalerts:openDashboard")
            end
        },
        {
            title = "📦 Restock Suggestions",
            description = "AI-powered reorder recommendations",
            icon = "fas fa-magic",
            onSelect = function()
                TriggerServerEvent("stockalerts:getSuggestions")
            end
        },
        {
            title = "🤖 NPC Delivery Management",
            description = "Manage NPC drivers for surplus inventory",
            icon = "fas fa-robot",
            onSelect = function()
                TriggerEvent("npc:openManagementMenu")
            end
        },
        {
            title = "🏆 Driver Leaderboards",
            description = "View top performing drivers and rankings",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerEvent("leaderboard:openMenu")
            end
        },
        {
            title = "📊 My Performance",
            description = "View your personal delivery statistics",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("leaderboard:getPersonalStats")
            end
        },
        {
            title = "🎯 My Driver Status",
            description = "View current streaks and upcoming bonuses",
            icon = "fas fa-fire",
            onSelect = function()
                TriggerServerEvent("rewards:getPlayerStatus")
            end
        },
        {
            title = "🏆 My Achievement Status",
            description = "View vehicle performance tier and progress",
            icon = "fas fa-medal",
            onSelect = function()
                TriggerServerEvent("achievements:getPlayerTier")
            end
        }
    }
    
    lib.registerContext({
        id = "main_menu",
        title = "🏢 Hurst Industries - Warehouse Operations",
        options = options
    })
    lib.showContext("main_menu")
end)

-- ============================================
-- STOCK DISPLAY SYSTEM
-- ============================================

-- Warehouse Stock Display
RegisterNetEvent("restaurant:showStockDetails")
AddEventHandler("restaurant:showStockDetails", function(stock, query)
    if not stock or next(stock) == nil then
        exports.ogz_supplychain:errorNotify(
            "No Stock",
            "There is no stock available in the warehouse."
        )
        return
    end

    local options = {
        {
            title = "🔍 Search",
            description = "Search for an ingredient",
            icon = "fas fa-search",
            onSelect = function()
                local input = exports.ogz_supplychain:showInput("Search Stock", {
                    { type = "input", label = "Enter ingredient name" }
                })
                if input and input[1] then
                    TriggerEvent("restaurant:showStockDetails", stock, input[1])
                end
            end
        }
    }
    
    query = query or ""
    local itemNames = exports.ox_inventory:Items()
    
    for ingredient, quantity in pairs(stock) do
        if string.find(string.lower(ingredient), string.lower(query)) then
            local itemData = itemNames[ingredient]
            local label = itemData and itemData.label or ingredient
            table.insert(options, {
                title = string.format("📦 %s", label),
                description = string.format("Quantity: **%d units**", quantity),
                metadata = {
                    ["Ingredient"] = label,
                    ["Quantity"] = quantity .. " units",
                    ["Item Key"] = ingredient
                }
            })
        end
    end
    
    lib.registerContext({
        id = "stock_menu",
        title = "📊 Warehouse Stock",
        options = options
    })
    lib.showContext("stock_menu")
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('hasWarehouseAccess', hasWarehouseAccess)
exports('openProcessingMenu', function()
    TriggerEvent("warehouse:openProcessingMenu")
end)

print("[WAREHOUSE UI] Core warehouse interface loaded")