-- Emergency Orders Client System

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Emergency state
local activeEmergencies = {}
local emergencyBlips = {}
local alertCooldowns = {}
local isInEmergencyDelivery = false

-- Emergency alert handler
RegisterNetEvent("SupplyChain:Client:EmergencyAlert")
AddEventHandler("SupplyChain:Client:EmergencyAlert", function(data)
    -- Play alert sound based on severity
    if data.type == "critical" then
        -- Critical alert sound
        for i = 1, 3 do
            PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
            Wait(500)
        end
    else
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    
    -- Show notification
    lib.notify({
        id = 'emergency_' .. (data.order and data.order.id or os.time()),
        title = data.title,
        description = data.message,
        duration = data.duration or 8000,
        type = data.type == "critical" and "error" or "warning",
        icon = "fas fa-exclamation-triangle",
        iconAnimation = data.type == "critical" and "beat" or "fade"
    })
    
    -- Add to active emergencies
    if data.order then
        activeEmergencies[data.order.id] = data.order
        
        -- Create blip for critical orders
        if data.order.priority >= Constants.EmergencyPriority.URGENT then
            CreateEmergencyBlip(data.order)
        end
    end
    
    -- Show persistent UI for critical
    if data.type == "critical" then
        ShowEmergencyUI(data.order)
    end
end)

-- Hero moment notification
RegisterNetEvent("SupplyChain:Client:HeroMoment")
AddEventHandler("SupplyChain:Client:HeroMoment", function(data)
    -- Special effects
    StartScreenEffect("FocusIn", 500, false)
    
    -- Play heroic sound
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- Show special notification
    lib.notify({
        id = 'hero_moment',
        title = "🦸 HERO MOMENT AVAILABLE!",
        description = string.format(
            "Prevent %s STOCKOUT and earn $%d bonus!\nAccept the emergency order NOW!",
            data.ingredient:upper(),
            data.reward
        ),
        duration = 15000,
        type = "success",
        icon = "fas fa-medal",
        iconAnimation = "bounce",
        style = {
            backgroundColor = '#FFD700',
            color = '#000000'
        }
    })
    
    -- Add flashing waypoint
    local warehouse = Config.Warehouses[1]
    if warehouse then
        SetNewWaypoint(warehouse.position.x, warehouse.position.y)
    end
end)

-- Emergency warning (timer)
RegisterNetEvent("SupplyChain:Client:EmergencyWarning")
AddEventHandler("SupplyChain:Client:EmergencyWarning", function(data)
    local minutes = math.floor(data.timeRemaining / 60)
    local seconds = data.timeRemaining % 60
    
    if data.critical then
        -- Final warning
        lib.notify({
            title = "⏰ EMERGENCY DEADLINE!",
            description = string.format("Only %d:%02d remaining!", minutes, seconds),
            type = "error",
            duration = 5000,
            icon = "fas fa-clock",
            iconAnimation = "spin"
        })
        
        -- Flash screen
        StartScreenEffect("RaceTurbo", 500, false)
    else
        -- Regular warning
        lib.notify({
            title = "Emergency Timer",
            description = string.format("Time remaining: %d:%02d", minutes, seconds),
            type = "warning",
            duration = 3000,
            icon = "fas fa-stopwatch"
        })
    end
end)

-- Start emergency delivery
RegisterNetEvent("SupplyChain:Client:StartEmergencyDelivery")
AddEventHandler("SupplyChain:Client:StartEmergencyDelivery", function(data)
    isInEmergencyDelivery = true
    
    -- Show emergency UI
    ShowEmergencyDeliveryHUD(data)
    
    -- Create special waypoint
    local seller = Config.Seller
    if seller then
        local blip = AddBlipForCoord(seller.position.x, seller.position.y, seller.position.z)
        SetBlipSprite(blip, 440) -- Truck blip
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.2)
        SetBlipColour(blip, 1) -- Red
        SetBlipFlashes(blip, true)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("EMERGENCY PICKUP")
        EndTextCommandSetBlipName(blip)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, 1)
        
        table.insert(emergencyBlips, blip)
    end
    
    -- Alert dialog
    lib.alertDialog({
        header = "🚨 Emergency Delivery Started",
        content = string.format([[
            **Critical Supply Needed!**
            
            Item: %s
            Quantity: %d units
            Time Limit: %d minutes
            Reward Multiplier: %.1fx
            
            Rush to the supplier and deliver ASAP!
        ]], 
            data.emergencyOrder.ingredient:upper(),
            data.emergencyOrder.quantity,
            math.floor(data.timeLimit / 60),
            data.emergencyOrder.rewardMultiplier
        ),
        centered = true,
        cancel = false,
        labels = {
            confirm = "START EMERGENCY RUN"
        }
    })
    
    -- Start timer display
    StartEmergencyTimer(data.timeLimit, data.emergencyOrder.id)
end)

-- Show emergency UI
function ShowEmergencyUI(order)
    -- Create persistent UI element
    lib.showTextUI(string.format(
        "[EMERGENCY] %s needed! Reward: %.1fx | Accept at warehouse",
        order.ingredient:upper(),
        order.rewardMultiplier
    ), {
        position = "top-center",
        icon = "fas fa-exclamation-triangle",
        style = {
            borderRadius = 0,
            backgroundColor = '#dc2626',
            color = 'white',
            fontWeight = 'bold',
            animation = 'pulse 1s infinite'
        }
    })
    
    -- Auto-hide after 30 seconds unless critical
    if order.priority < Constants.EmergencyPriority.CRITICAL then
        SetTimeout(30000, function()
            lib.hideTextUI()
        end)
    end
end

-- Show emergency delivery HUD
function ShowEmergencyDeliveryHUD(data)
    -- This would ideally be a NUI element
    CreateThread(function()
        while isInEmergencyDelivery do
            Wait(0)
            
            -- Draw emergency header
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.8, 0.8)
            SetTextColour(255, 0, 0, 255)
            SetTextDropShadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("EMERGENCY DELIVERY ACTIVE")
            DrawText(0.5, 0.05)
        end
    end)
end

-- Start emergency timer
function StartEmergencyTimer(timeLimit, orderId)
    local endTime = GetGameTimer() + (timeLimit * 1000)
    
    CreateThread(function()
        while isInEmergencyDelivery and GetGameTimer() < endTime do
            local remaining = math.floor((endTime - GetGameTimer()) / 1000)
            local minutes = math.floor(remaining / 60)
            local seconds = remaining % 60
            
            -- Draw timer
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.6, 0.6)
            SetTextColour(255, 255, 255, 255)
            SetTextDropShadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString(string.format("TIME REMAINING: %02d:%02d", minutes, seconds))
            DrawText(0.5, 0.08)
            
            -- Warning colors
            if remaining < 60 then
                SetTextColour(255, 0, 0, 255)
            elseif remaining < 300 then
                SetTextColour(255, 255, 0, 255)
            end
            
            Wait(0)
        end
        
        if GetGameTimer() >= endTime and isInEmergencyDelivery then
            -- Time expired
            lib.notify({
                title = "Emergency Failed",
                description = "Time limit exceeded!",
                type = "error",
                duration = 5000
            })
            
            CleanupEmergency()
        end
    end)
end

-- Create emergency blip
function CreateEmergencyBlip(order)
    local warehouse = Config.Warehouses[1]
    if not warehouse then return end
    
    local blip = AddBlipForCoord(warehouse.position.x, warehouse.position.y, warehouse.position.z)
    SetBlipSprite(blip, 161) -- Star
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1) -- Red
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Emergency Order")
    EndTextCommandSetBlipName(blip)
    
    emergencyBlips[order.id] = blip
end

-- Open emergency orders menu
function OpenEmergencyOrdersMenu()
    local options = {}
    
    for orderId, order in pairs(activeEmergencies) do
        local priorityColors = {
            [Constants.EmergencyPriority.CRITICAL] = "red",
            [Constants.EmergencyPriority.URGENT] = "orange",
            [Constants.EmergencyPriority.HIGH] = "yellow",
            [Constants.EmergencyPriority.MEDIUM] = "blue"
        }
        
        local timeRemaining = order.expiresAt - os.time()
        local minutes = math.floor(timeRemaining / 60)
        
        table.insert(options, {
            title = string.format("%s - %s", order.ingredient:upper(), GetPriorityName(order.priority)),
            description = string.format("Quantity: %d | Time: %d min | Reward: %.1fx",
                order.quantity, minutes, order.rewardMultiplier),
            icon = "fas fa-exclamation-triangle",
            iconColor = priorityColors[order.priority] or "grey",
            metadata = {
                {label = "Priority", value = GetPriorityName(order.priority):upper()},
                {label = "Reward Multiplier", value = string.format("%.1fx", order.rewardMultiplier)},
                {label = "Time Remaining", value = string.format("%d minutes", minutes)}
            },
            onSelect = function()
                TriggerServerEvent("SupplyChain:Server:AcceptEmergencyOrder", orderId)
            end
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = "No Emergency Orders",
            description = "All stock levels are currently stable",
            icon = "fas fa-check-circle",
            iconColor = "green",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "emergency_orders_menu",
        title = "🚨 Emergency Orders",
        options = options
    })
    
    lib.showContext("emergency_orders_menu")
end

-- Complete emergency delivery
function CompleteEmergencyDelivery(orderId)
    if not isInEmergencyDelivery then return end
    
    -- Success effects
    StartScreenEffect("SuccessFranklin", 2000, false)
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- Cleanup
    CleanupEmergency()
    
    lib.notify({
        title = "Emergency Complete!",
        description = "Critical supply delivered successfully!",
        type = "success",
        duration = 5000,
        icon = "fas fa-check-circle"
    })
end

-- Cleanup emergency
function CleanupEmergency()
    isInEmergencyDelivery = false
    
    -- Remove blips
    for _, blip in pairs(emergencyBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    emergencyBlips = {}
    
    -- Clear UI
    lib.hideTextUI()
    
    -- Stop screen effects
    StopAllScreenEffects()
end

-- Market event end notification
RegisterNetEvent("SupplyChain:Client:MarketEventEnd")
AddEventHandler("SupplyChain:Client:MarketEventEnd", function()
    lib.notify({
        title = "Market Event Ended",
        description = "Prices have returned to normal",
        type = "info",
        duration = 5000,
        icon = "fas fa-chart-line"
    })
end)

-- Utility functions
function GetPriorityName(priority)
    local names = {
        [Constants.EmergencyPriority.LOW] = "Low",
        [Constants.EmergencyPriority.MEDIUM] = "Medium",
        [Constants.EmergencyPriority.HIGH] = "High",
        [Constants.EmergencyPriority.URGENT] = "Urgent",
        [Constants.EmergencyPriority.CRITICAL] = "CRITICAL"
    }
    return names[priority] or "Unknown"
end

-- Export emergency functions
exports('GetActiveEmergencies', function()
    return activeEmergencies
end)

exports('IsInEmergencyDelivery', function()
    return isInEmergencyDelivery
end)

exports('OpenEmergencyOrdersMenu', OpenEmergencyOrdersMenu)