-- ============================================
-- MANUFACTURING UI & FACILITY MANAGEMENT
-- Professional facility interface and setup
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- FACILITY INITIALIZATION & SETUP
-- ============================================

-- Enhanced facility setup with enterprise validation
Citizen.CreateThread(function()
    print("[MANUFACTURING] Starting facility setup...")
    
    if not Config.ManufacturingFacilities then
        print("[ERROR] Config.ManufacturingFacilities not defined")
        return
    end
    
    print("[MANUFACTURING] Found " .. #Config.ManufacturingFacilities .. " facilities to set up")
    
    for facilityId, facility in pairs(Config.ManufacturingFacilities) do
        print("[MANUFACTURING] Setting up facility " .. facilityId .. ": " .. facility.name)
        
        -- Validate facility data using enterprise patterns
        if not facility.position then
            print("[ERROR] Facility " .. facilityId .. " missing position")
            goto continue
        end
        
        -- Create target zone with enterprise ox_target management
        local targetSuccess = pcall(function()
            exports.ogz_supplychain:createBoxZone({
                coords = facility.position,
                size = vector3(3.0, 3.0, 3.0),
                rotation = facility.heading,
                debug = false, -- Production mode
                options = {
                    {
                        name = "manufacturing_facility_" .. facilityId,
                        icon = "fas fa-industry",
                        label = "Access " .. facility.name,
                        groups = {"hurst"},
                        onSelect = function()
                            print("[MANUFACTURING] Facility " .. facilityId .. " accessed")
                            TriggerEvent("manufacturing:openFacilityMenu", facilityId)
                        end
                    }
                }
            })
        end)
        
        if not targetSuccess then
            print("[ERROR] Failed to create target zone for facility " .. facilityId)
            goto continue
        else
            print("[SUCCESS] Target zone created for facility " .. facilityId)
        end
        
        -- Spawn facility ped with enterprise validation
        local pedModel = GetHashKey(facility.ped.model)
        print("[MANUFACTURING] Requesting ped model: " .. facility.ped.model .. " (hash: " .. pedModel .. ")")
        
        RequestModel(pedModel)
        local attempts = 0
        while not HasModelLoaded(pedModel) and attempts < 50 do
            Citizen.Wait(100)
            attempts = attempts + 1
        end
        
        if not HasModelLoaded(pedModel) then
            print("[ERROR] Failed to load ped model for facility " .. facilityId .. ": " .. facility.ped.model)
            goto continue
        end
        
        local ped = CreatePed(4, pedModel, 
            facility.position.x, 
            facility.position.y, 
            facility.position.z - 1.0, 
            facility.ped.heading, 
            false, true)
        
        if not DoesEntityExist(ped) then
            print("[ERROR] Failed to create ped for facility " .. facilityId)
            goto continue
        end
        
        -- Configure ped with enterprise standards
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetModelAsNoLongerNeeded(pedModel)
        
        print("[SUCCESS] Ped created for facility " .. facilityId)
        
        -- Create facility blip with enterprise styling
        local blip = AddBlipForCoord(facility.position.x, facility.position.y, facility.position.z)
        SetBlipSprite(blip, facility.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, facility.blip.scale)
        SetBlipColour(blip, facility.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(facility.blip.label)
        EndTextCommandSetBlipName(blip)
        
        print("[SUCCESS] Blip created for facility " .. facilityId)
        
        ::continue::
        Citizen.Wait(100)
    end
    
    print("[MANUFACTURING] Facility setup complete")
    
    -- Enterprise success notification
    Citizen.Wait(5000)
    exports.ogz_supplychain:successNotify(
        '🏭 Manufacturing Facilities',
        'Manufacturing facilities have been set up. Check your map for blips.'
    )
end)

-- ============================================
-- MAIN FACILITY MENU SYSTEM
-- ============================================

-- Open facility main menu with enterprise validation
RegisterNetEvent("manufacturing:openFacilityMenu")
AddEventHandler("manufacturing:openFacilityMenu", function(facilityId)
    -- Universal job access validation
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    local facility = Config.ManufacturingFacilities[facilityId]
    
    if not facility then
        exports.ogz_supplychain:errorNotify(
            "Error",
            "Facility not found"
        )
        return
    end
    
    -- Set current facility for component coordination
    TriggerEvent("manufacturing:setCurrentFacility", facilityId)
    
    local options = {
        {
            title = "🏭 Start Manufacturing",
            description = "Begin ingredient production process",
            icon = "fas fa-play",
            onSelect = function()
                TriggerServerEvent("manufacturing:getRecipes", facilityId)
            end
        },
        {
            title = "📊 View My Stats",
            description = "Check manufacturing skills and progress",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("manufacturing:openPlayerStats")
            end
        },
        {
            title = "🏗️ Facility Status",
            description = "View current facility operations",
            icon = "fas fa-info-circle",
            onSelect = function()
                TriggerEvent("manufacturing:openFacilityStatus")
            end
        },
        {
            title = "📚 Recipe Guide",
            description = "Browse available recipes and requirements",
            icon = "fas fa-book",
            onSelect = function()
                TriggerEvent("manufacturing:openRecipeGuide", facilityId)
            end
        }
    }
    
    lib.registerContext({
        id = "manufacturing_main_menu",
        title = "🏭 " .. facility.name,
        options = options
    })
    lib.showContext("manufacturing_main_menu")
end)

-- ============================================
-- FACILITY STATUS DISPLAY
-- ============================================

-- Show facility status with enterprise formatting
RegisterNetEvent("manufacturing:openFacilityStatus")
AddEventHandler("manufacturing:openFacilityStatus", function()
    TriggerServerEvent("manufacturing:getFacilityStatus")
end)

-- Display facility status data
RegisterNetEvent("manufacturing:showFacilityStatus")
AddEventHandler("manufacturing:showFacilityStatus", function(facilityStats)
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:returnToFacilityMenu")
            end
        }
    }
    
    if not facilityStats or next(facilityStats) == nil then
        table.insert(options, {
            title = "🟢 All Facilities Available",
            description = "No active manufacturing processes",
            disabled = true
        })
    else
        table.insert(options, {
            title = "🏭 Facility Status Overview",
            description = "Current manufacturing operations",
            disabled = true
        })
        
        for facilityId, stats in pairs(facilityStats) do
            local facility = Config.ManufacturingFacilities[facilityId]
            if facility then
                local statusIcon = stats.activeProcesses > 0 and "🟡" or "🟢"
                local timeRemaining = stats.estimatedCompletion > 0 and 
                    (stats.estimatedCompletion - os.time()) or 0
                
                table.insert(options, {
                    title = statusIcon .. " " .. facility.name,
                    description = string.format(
                        "Active processes: %d%s",
                        stats.activeProcesses,
                        timeRemaining > 0 and string.format("\nCompletes in: %s", 
                            exports.ogz_supplychain:formatTime(timeRemaining)) or ""
                    ),
                    disabled = true
                })
            end
        end
    end
    
    lib.registerContext({
        id = "manufacturing_facility_status",
        title = "🏗️ Facility Status",
        options = options
    })
    lib.showContext("manufacturing_facility_status")
end)

-- ============================================
-- FACILITY COORDINATION EVENTS
-- ============================================

-- Store current facility for component coordination
local currentFacility = nil

-- Set current facility (used by other components)
RegisterNetEvent("manufacturing:setCurrentFacility")
AddEventHandler("manufacturing:setCurrentFacility", function(facilityId)
    currentFacility = facilityId
end)

-- Get current facility (exported for other components)
RegisterNetEvent("manufacturing:getCurrentFacility")
AddEventHandler("manufacturing:getCurrentFacility", function()
    return currentFacility
end)

-- Return to facility menu (universal navigation)
RegisterNetEvent("manufacturing:returnToFacilityMenu")
AddEventHandler("manufacturing:returnToFacilityMenu", function()
    if currentFacility then
        TriggerEvent("manufacturing:openFacilityMenu", currentFacility)
    else
        exports.ogz_supplychain:errorNotify(
            "Navigation Error",
            "No facility selected"
        )
    end
end)

-- ============================================
-- FACILITY INFORMATION DISPLAY
-- ============================================

-- Show facility details and capabilities
RegisterNetEvent("manufacturing:showFacilityInfo")
AddEventHandler("manufacturing:showFacilityInfo", function(facilityId)
    local facility = Config.ManufacturingFacilities[facilityId]
    if not facility then return end
    
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openFacilityMenu", facilityId)
            end
        },
        {
            title = "🏭 " .. facility.name,
            description = "Facility Information",
            disabled = true
        },
        {
            title = "📍 Location",
            description = string.format("X: %.1f, Y: %.1f, Z: %.1f", 
                facility.position.x, facility.position.y, facility.position.z),
            disabled = true
        },
        {
            title = "🔧 Specializations",
            description = table.concat(facility.specializations, ", "),
            disabled = true
        }
    }
    
    -- Show processing stations if available
    if facility.processingStations and #facility.processingStations > 0 then
        table.insert(options, {
            title = "⚙️ Processing Stations",
            description = #facility.processingStations .. " stations available",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "manufacturing_facility_info",
        title = "ℹ️ Facility Information",
        options = options
    })
    lib.showContext("manufacturing_facility_info")
end)

-- ============================================
-- NAVIGATION HELPERS
-- ============================================

-- Universal back navigation for manufacturing menus
RegisterNetEvent("manufacturing:navigateBack")
AddEventHandler("manufacturing:navigateBack", function(targetMenu)
    if targetMenu == "main" then
        TriggerEvent("manufacturing:returnToFacilityMenu")
    elseif targetMenu == "recipes" then
        if currentFacility then
            TriggerServerEvent("manufacturing:getRecipes", currentFacility)
        end
    elseif targetMenu == "stats" then
        TriggerEvent("manufacturing:openPlayerStats")
    elseif targetMenu == "guide" then
        if currentFacility then
            TriggerEvent("manufacturing:openRecipeGuide", currentFacility)
        end
    end
end)

-- ============================================
-- DEBUG AND UTILITY COMMANDS
-- ============================================

-- Debug command to check facility status
RegisterCommand('checkfacilities', function()
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    print("[DEBUG] Checking manufacturing facilities...")
    
    if not Config.ManufacturingFacilities then
        print("No facilities configured")
        return
    end
    
    for facilityId, facility in pairs(Config.ManufacturingFacilities) do
        local playerPos = GetEntityCoords(PlayerPedId())
        local distance = #(playerPos - facility.position)
        
        print(string.format("Facility %d: %s - Distance: %.2f", facilityId, facility.name, distance))
        
        exports.ogz_supplychain:infoNotify(
            'Facility ' .. facilityId,
            facility.name .. ' - Distance: ' .. math.floor(distance) .. 'm'
        )
    end
end)

-- Debug command to teleport to facilities
RegisterCommand('tpfacility', function(source, args)
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    local facilityId = tonumber(args[1])
    
    if not facilityId or not Config.ManufacturingFacilities[facilityId] then
        exports.ogz_supplychain:errorNotify(
            'Invalid Facility',
            'Use: /tpfacility [1-5]'
        )
        return
    end
    
    local facility = Config.ManufacturingFacilities[facilityId]
    local playerPed = PlayerPedId()
    
    SetEntityCoords(playerPed, facility.position.x, facility.position.y, facility.position.z + 1.0, false, false, false, true)
    
    exports.ogz_supplychain:successNotify(
        'Teleported',
        'Teleported to ' .. facility.name
    )
end)

-- ============================================
-- EXPORTS FOR OTHER COMPONENTS
-- ============================================

-- Export current facility for other manufacturing components
exports('getCurrentFacility', function()
    return currentFacility
end)

-- Export facility validation
exports('validateFacility', function(facilityId)
    return Config.ManufacturingFacilities and Config.ManufacturingFacilities[facilityId] ~= nil
end)

-- Export facility navigation
exports('navigateToFacility', function(facilityId)
    if Config.ManufacturingFacilities and Config.ManufacturingFacilities[facilityId] then
        TriggerEvent("manufacturing:openFacilityMenu", facilityId)
        return true
    end
    return false
end)

print("[MANUFACTURING] UI & Facility Management initialized")