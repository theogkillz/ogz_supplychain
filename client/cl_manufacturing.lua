-- ============================================
-- MANUFACTURING SYSTEM - CLIENT INTERFACE
-- Professional ingredient creation interface
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Client state
local currentFacility = nil
local availableRecipes = {}
local currentProcessing = {}
local playerStats = {}

-- ============================================
-- JOB ACCESS VALIDATION
-- ============================================

-- Check if player has manufacturing access
local function hasManufacturingAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    if not playerJob then
        return false
    end
    
    -- Check if player's job is "hurst"
    return playerJob == "hurst"
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Format time display
local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    if minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Format money display
local function formatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

-- Calculate container requirements
local function calculateContainers(totalItems)
    local containerSystem = Config.Manufacturing.containerSystem
    local itemsPerContainer = containerSystem.itemsPerContainer
    local containersPerBox = containerSystem.containersPerBox
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return containersNeeded, boxesNeeded
end

-- Get player's inventory count for item
local function getInventoryCount(item)
    return exports.ox_inventory:GetItemCount(cache.serverId, item) or 0
end

-- Get item label from ox_inventory
local function getItemLabel(item)
    local itemNames = exports.ox_inventory:Items() or {}
    return itemNames[item] and itemNames[item].label or item
end

-- ============================================
-- MANUFACTURING FACILITY SETUP
-- ============================================

-- Enhanced facility setup with debugging
Citizen.CreateThread(function()
    print("[MANUFACTURING] Starting facility setup...")
    
    if not Config.ManufacturingFacilities then
        print("[ERROR] Config.ManufacturingFacilities not defined")
        return
    end
    
    print("[MANUFACTURING] Found " .. #Config.ManufacturingFacilities .. " facilities to set up")
    
    for facilityId, facility in pairs(Config.ManufacturingFacilities) do
        print("[MANUFACTURING] Setting up facility " .. facilityId .. ": " .. facility.name)
        
        -- Validate facility data
        if not facility.position then
            print("[ERROR] Facility " .. facilityId .. " missing position")
            goto continue
        end
        
        -- Create target zone with enhanced debugging
        local targetSuccess = pcall(function()
            exports.ox_target:addBoxZone({
                coords = facility.position,
                size = vector3(3.0, 3.0, 3.0), -- Increased size for better interaction
                rotation = facility.heading,
                debug = true, -- Enable debug mode temporarily
                options = {
                    {
                        name = "manufacturing_facility_" .. facilityId,
                        icon = "fas fa-industry",
                        label = "Access " .. facility.name,
                        groups = {"hurst"}, -- Job validation
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
        
        -- Spawn facility ped with validation
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
        
        -- Configure ped
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetModelAsNoLongerNeeded(pedModel)
        
        print("[SUCCESS] Ped created for facility " .. facilityId)
        
        -- Create facility blip
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
        Citizen.Wait(100) -- Small delay between facility setups
    end
    
    print("[MANUFACTURING] Facility setup complete")
    
    -- Show summary to player
    Citizen.Wait(5000)
    lib.notify({
        title = '🏭 Manufacturing Facilities',
        description = 'Manufacturing facilities have been set up. Check your map for blips.',
        type = 'info',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- ============================================
-- MAIN MENU SYSTEM
-- ============================================

-- Open facility main menu
RegisterNetEvent("manufacturing:openFacilityMenu")
AddEventHandler("manufacturing:openFacilityMenu", function(facilityId)
    -- Validate job access
    if not hasManufacturingAccess() then
        local PlayerData = QBCore.Functions.GetPlayerData()
        local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
        
        lib.notify({
            title = "🚫 Access Denied",
            description = "Hurst Industries employees only. Current job: " .. currentJob,
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    currentFacility = facilityId
    local facility = Config.ManufacturingFacilities[facilityId]
    
    if not facility then
        lib.notify({
            title = "Error",
            description = "Facility not found",
            type = "error",
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
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
                TriggerServerEvent("manufacturing:getPlayerStats")
            end
        },
        {
            title = "🏗️ Facility Status",
            description = "View current facility operations",
            icon = "fas fa-info-circle",
            onSelect = function()
                TriggerServerEvent("manufacturing:getFacilityStatus")
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

-- Show available recipes
RegisterNetEvent("manufacturing:showRecipes")
AddEventHandler("manufacturing:showRecipes", function(recipes, facilityId)
    availableRecipes = recipes
    
    if #recipes == 0 then
        lib.notify({
            title = "No Recipes Available",
            description = "This facility has no recipes available for your skill level",
            type = "info",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openFacilityMenu", facilityId)
            end
        }
    }
    
    -- Group recipes by category
    local categorizedRecipes = {}
    for _, recipe in ipairs(recipes) do
        if not categorizedRecipes[recipe.category] then
            categorizedRecipes[recipe.category] = {}
        end
        table.insert(categorizedRecipes[recipe.category], recipe)
    end
    
    -- Add category headers and recipes
    for category, categoryRecipes in pairs(categorizedRecipes) do
        table.insert(options, {
            title = "── " .. category:gsub("^%l", string.upper) .. " ──",
            description = #categoryRecipes .. " recipes available",
            disabled = true
        })
        
        for _, recipe in ipairs(categoryRecipes) do
            -- Check if player has ingredients
            local canCraft = true
            local missingIngredients = {}
            
            for ingredient, required in pairs(recipe.inputs) do
                local playerAmount = getInventoryCount(ingredient)
                if playerAmount < required then
                    canCraft = false
                    table.insert(missingIngredients, {
                        item = getItemLabel(ingredient),
                        required = required,
                        current = playerAmount,
                        missing = required - playerAmount
                    })
                end
            end
            
            local statusIcon = canCraft and "✅" or "❌"
            local skillText = recipe.skillRequired and recipe.skillRequired > 0 and 
                string.format(" (Skill: %d)", recipe.skillRequired) or ""
            
            table.insert(options, {
                title = statusIcon .. " " .. recipe.name,
                description = recipe.description .. skillText,
                metadata = {
                    ["Category"] = recipe.category,
                    ["Skill Required"] = recipe.skillRequired or 0,
                    ["Processing Time"] = formatTime(recipe.processingTime),
                    ["Can Craft"] = canCraft and "Yes" or "Missing ingredients"
                },
                onSelect = function()
                    if canCraft then
                        TriggerEvent("manufacturing:openRecipeMenu", recipe, facilityId)
                    else
                        TriggerEvent("manufacturing:showMissingIngredients", missingIngredients)
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "manufacturing_recipes",
        title = "📋 Available Recipes",
        options = options
    })
    lib.showContext("manufacturing_recipes")
end)

-- Open individual recipe menu
RegisterNetEvent("manufacturing:openRecipeMenu")
AddEventHandler("manufacturing:openRecipeMenu", function(recipe, facilityId)
    local options = {
        {
            title = "← Back to Recipes",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent("manufacturing:getRecipes", facilityId)
            end
        },
        {
            title = "📝 Recipe Details",
            description = recipe.description,
            disabled = true
        }
    }
    
    -- Show ingredients required
    table.insert(options, {
        title = "🧪 Required Ingredients",
        description = "Raw materials needed for production",
        disabled = true
    })
    
    for ingredient, required in pairs(recipe.inputs) do
        local playerAmount = getInventoryCount(ingredient)
        local statusIcon = playerAmount >= required and "✅" or "❌"
        local itemLabel = getItemLabel(ingredient)
        
        table.insert(options, {
            title = statusIcon .. " " .. itemLabel,
            description = string.format("Required: %d | You have: %d", required, playerAmount),
            disabled = true
        })
    end
    
    -- Show output
    table.insert(options, {
        title = "🎯 Output Products",
        description = "What you'll produce",
        disabled = true
    })
    
    for outputItem, outputData in pairs(recipe.outputs) do
        local itemLabel = getItemLabel(outputItem)
        table.insert(options, {
            title = "📦 " .. itemLabel,
            description = string.format("Base yield: %d per batch", outputData.quantity),
            disabled = true
        })
    end
    
    -- Production options
    table.insert(options, {
        title = "🏭 Start Standard Production",
        description = "Begin manufacturing with standard quality",
        icon = "fas fa-play",
        onSelect = function()
            TriggerEvent("manufacturing:selectQuantityAndQuality", recipe, facilityId, "standard")
        end
    })
    
    table.insert(options, {
        title = "💎 Start Premium Production",
        description = "Higher quality output with better yield (costs more)",
        icon = "fas fa-star",
        onSelect = function()
            TriggerEvent("manufacturing:selectQuantityAndQuality", recipe, facilityId, "premium")
        end
    })
    
    table.insert(options, {
        title = "🌿 Start Organic Production",
        description = "Highest quality organic output (requires high skill)",
        icon = "fas fa-leaf",
        onSelect = function()
            TriggerEvent("manufacturing:selectQuantityAndQuality", recipe, facilityId, "organic")
        end
    })
    
    lib.registerContext({
        id = "manufacturing_recipe_menu",
        title = "🧪 " .. recipe.name,
        options = options
    })
    lib.showContext("manufacturing_recipe_menu")
end)

-- Select quantity and quality
RegisterNetEvent("manufacturing:selectQuantityAndQuality")
AddEventHandler("manufacturing:selectQuantityAndQuality", function(recipe, facilityId, qualityLevel)
    local input = lib.inputDialog("Manufacturing Batch Configuration", {
        {
            type = "number",
            label = "Quantity (batches)",
            description = "Number of batches to process",
            placeholder = "Enter batch quantity",
            min = 1,
            max = Config.Manufacturing.containerSystem.maxItemsPerBatch,
            required = true,
            default = 1
        },
        {
            type = "select",
            label = "Quality Level",
            description = "Higher quality = better yield but higher cost",
            options = {
                {label = "Standard Quality", value = "standard"},
                {label = "Premium Quality (+20% yield)", value = "premium"},
                {label = "Organic Quality (+10% yield, +100% value)", value = "organic"}
            },
            default = qualityLevel,
            required = true
        }
    })
    
    if input and input[1] and input[2] then
        local quantity = tonumber(input[1])
        local selectedQuality = input[2]
        
        if quantity > 0 then
            TriggerEvent("manufacturing:confirmProduction", recipe, facilityId, quantity, selectedQuality)
        end
    end
end)

-- Confirm production with cost breakdown
RegisterNetEvent("manufacturing:confirmProduction")
AddEventHandler("manufacturing:confirmProduction", function(recipe, facilityId, quantity, qualityLevel)
    -- Calculate costs and requirements
    local costs = Config.Manufacturing.processingCosts
    local timing = Config.Manufacturing.timing
    
    local baseCost = costs.baseProcessingFee
    local processingTime = timing.baseProcessingTime + (timing.timePerItem * (quantity - 1))
    local electricityCost = (processingTime / 3600000) * costs.electricityCost -- Convert to hours
    local maintenanceCost = costs.maintenanceFee * quantity
    
    local qualityCost = 0
    if qualityLevel == "premium" or qualityLevel == "organic" then
        qualityCost = costs.qualityBonusCost * quantity
        processingTime = processingTime * timing.qualityProcessingMultiplier
    end
    
    local totalCost = math.floor(baseCost + electricityCost + maintenanceCost + qualityCost)
    local totalTime = math.floor(processingTime / 1000) -- Convert to seconds
    
    -- Calculate output
    local baseYield = recipe.outputs[next(recipe.outputs)].quantity * quantity
    local containers, boxes = calculateContainers(baseYield)
    
    -- Get output item info
    local outputItem = next(recipe.outputs)
    local outputLabel = getItemLabel(outputItem)
    
    lib.alertDialog({
        header = "🏭 Confirm Manufacturing Order",
        content = string.format(
            "**Recipe:** %s\n**Quantity:** %d batches\n**Quality:** %s\n\n" ..
            "**💰 Total Cost:** $%s\n**⏱️ Processing Time:** %s\n**📦 Expected Output:** ~%d %s\n**🏭 Containers:** %d containers (%d boxes)\n\n" ..
            "Proceed with manufacturing?",
            recipe.name,
            quantity,
            qualityLevel:gsub("^%l", string.upper),
            formatMoney(totalCost),
            formatTime(totalTime),
            baseYield,
            outputLabel,
            containers,
            boxes
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = "Start Manufacturing",
            cancel = "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            TriggerServerEvent("manufacturing:startProcess", recipe.id, quantity, qualityLevel, facilityId)
        end
    end)
end)

-- ============================================
-- PROCESSING FEEDBACK SYSTEM
-- ============================================

-- Show processing started feedback
RegisterNetEvent("manufacturing:processStarted")
AddEventHandler("manufacturing:processStarted", function(data)
    currentProcessing = data
    
    lib.notify({
        title = "🏭 Manufacturing Started",
        description = string.format(
            "Processing will complete in **%s**\nCost: $%s",
            formatTime(math.floor(data.processingTime / 1000)),
            formatMoney(data.processingCost)
        ),
        type = "success",
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Show processing progress
    if lib.progressBar then
        lib.progressBar({
            duration = data.processingTime,
            position = "bottom",
            label = "Manufacturing in progress...",
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = false,
                car = false,
                combat = true,
                sprint = false
            },
            anim = {
                dict = "amb@world_human_hammering@male@base",
                clip = "base"
            }
        })
    end
    
    -- Countdown notification
    local remainingTime = math.floor(data.processingTime / 1000)
    local countdownThread = Citizen.CreateThread(function()
        while remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1
            
            -- Show milestone notifications
            if remainingTime == 30 then
                lib.notify({
                    title = "⏰ Manufacturing Update",
                    description = "Process will complete in 30 seconds",
                    type = "info",
                    duration = 5000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            elseif remainingTime == 10 then
                lib.notify({
                    title = "🔥 Almost Ready!",
                    description = "Manufacturing completing in 10 seconds",
                    type = "warning",
                    duration = 5000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end
    end)
end)

-- Manufacturing process completed
RegisterNetEvent("manufacturing:processCompleted")
AddEventHandler("manufacturing:processCompleted", function(result)
    lib.notify({
        title = "🎉 Manufacturing Complete!",
        description = string.format(
            "Produced **%d %s**\nQuality: %s",
            result.quantity,
            result.itemLabel,
            result.quality
        ),
        type = "success",
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- ============================================
-- STATISTICS AND PROGRESS DISPLAY
-- ============================================

-- Show player manufacturing stats
RegisterNetEvent("manufacturing:showPlayerStats")
AddEventHandler("manufacturing:showPlayerStats", function(stats)
    playerStats = stats
    
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentFacility then
                    TriggerEvent("manufacturing:openFacilityMenu", currentFacility)
                end
            end
        },
        {
            title = "📊 Production Statistics",
            description = string.format(
                "🎯 Total Batches: %d\n📦 Items Produced: %d\n⭐ Success Rate: %.1f%%\n🧪 Unique Recipes: %d",
                stats.stats.total_batches or 0,
                stats.stats.total_output or 0,
                (stats.stats.success_rate or 0) * 100,
                stats.stats.unique_recipes or 0
            ),
            disabled = true
        }
    }
    
    -- Show skill levels
    if stats.skills and #stats.skills > 0 then
        table.insert(options, {
            title = "🎯 Manufacturing Skills",
            description = "Your current skill levels",
            disabled = true
        })
        
        for _, skill in ipairs(stats.skills) do
            local categoryConfig = stats.skillCategories[skill.category]
            local categoryName = categoryConfig and categoryConfig.name or skill.category
            local skillLevel = math.floor(skill.skill_level)
            local maxLevel = categoryConfig and categoryConfig.maxLevel or 100
            local progressPercent = (skillLevel / maxLevel) * 100
            
            table.insert(options, {
                title = string.format("🔧 %s", categoryName),
                description = string.format("Level %d/%d (%.1f%%)", skillLevel, maxLevel, progressPercent),
                metadata = {
                    ["Skill Level"] = skillLevel .. "/" .. maxLevel,
                    ["Total Experience"] = skill.total_experience or 0,
                    ["Progress"] = string.format("%.1f%%", progressPercent)
                }
            })
        end
    else
        table.insert(options, {
            title = "🎯 No Skills Yet",
            description = "Start manufacturing to develop your skills!",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "manufacturing_player_stats",
        title = "📊 My Manufacturing Stats",
        options = options
    })
    lib.showContext("manufacturing_player_stats")
end)

-- Show facility status
RegisterNetEvent("manufacturing:showFacilityStatus")
AddEventHandler("manufacturing:showFacilityStatus", function(facilityStats)
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentFacility then
                    TriggerEvent("manufacturing:openFacilityMenu", currentFacility)
                end
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
                        timeRemaining > 0 and string.format("\nCompletes in: %s", formatTime(timeRemaining)) or ""
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
-- HELPER MENUS
-- ============================================

-- Show missing ingredients
RegisterNetEvent("manufacturing:showMissingIngredients")
AddEventHandler("manufacturing:showMissingIngredients", function(missingIngredients)
    local options = {
        {
            title = "← Back to Recipes",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentFacility then
                    TriggerServerEvent("manufacturing:getRecipes", currentFacility)
                end
            end
        },
        {
            title = "❌ Missing Ingredients",
            description = "You need these items to start manufacturing",
            disabled = true
        }
    }
    
    for _, missing in ipairs(missingIngredients) do
        table.insert(options, {
            title = "🔴 " .. missing.item,
            description = string.format("Need %d more (have %d/%d)", 
                missing.missing, missing.current, missing.required),
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "manufacturing_missing_ingredients",
        title = "❌ Missing Ingredients",
        options = options
    })
    lib.showContext("manufacturing_missing_ingredients")
end)

-- Open recipe guide
RegisterNetEvent("manufacturing:openRecipeGuide")
AddEventHandler("manufacturing:openRecipeGuide", function(facilityId)
    local facility = Config.ManufacturingFacilities[facilityId]
    
    local options = {
        {
            title = "← Back to Facility Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openFacilityMenu", facilityId)
            end
        },
        {
            title = "📚 Recipe Guide",
            description = "Browse all recipes available at this facility",
            disabled = true
        }
    }
    
    -- Show facility specializations
    table.insert(options, {
        title = "🏭 Facility Specializations",
        description = table.concat(facility.specializations, ", "),
        disabled = true
    })
    
    -- Group recipes by specialization
    for _, specialization in ipairs(facility.specializations) do
        local specializationRecipes = {}
        
        for recipeId, recipe in pairs(Config.ManufacturingRecipes) do
            if recipe.facility_specialization == specialization then
                table.insert(specializationRecipes, recipe)
            end
        end
        
        if #specializationRecipes > 0 then
            table.insert(options, {
                title = "── " .. specialization:gsub("_", " "):gsub("^%l", string.upper) .. " ──",
                description = #specializationRecipes .. " recipes",
                disabled = true
            })
            
            for _, recipe in ipairs(specializationRecipes) do
                local skillText = recipe.skillRequired and recipe.skillRequired > 0 and 
                    string.format(" (Skill: %d)", recipe.skillRequired) or ""
                
                table.insert(options, {
                    title = "📖 " .. recipe.name,
                    description = recipe.description .. skillText,
                    metadata = {
                        ["Skill Required"] = recipe.skillRequired or 0,
                        ["Category"] = recipe.category,
                        ["Processing Time"] = formatTime(recipe.processingTime)
                    }
                })
            end
        end
    end
    
    lib.registerContext({
        id = "manufacturing_recipe_guide",
        title = "📚 " .. facility.name .. " - Recipe Guide",
        options = options
    })
    lib.showContext("manufacturing_recipe_guide")
end)

print("[MANUFACTURING] Client interface initialized")

-- Debug command to check facility status
RegisterCommand('checkfacilities', function()
    print("[DEBUG] Checking manufacturing facilities...")
    
    if not Config.ManufacturingFacilities then
        print("No facilities configured")
        return
    end
    
    for facilityId, facility in pairs(Config.ManufacturingFacilities) do
        local playerPos = GetEntityCoords(PlayerPedId())
        local distance = #(playerPos - facility.position)
        
        print(string.format("Facility %d: %s - Distance: %.2f", facilityId, facility.name, distance))
        
        lib.notify({
            title = 'Facility ' .. facilityId,
            description = facility.name .. ' - Distance: ' .. math.floor(distance) .. 'm',
            type = 'info',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- Debug command to teleport to facilities
RegisterCommand('tpfacility', function(source, args)
    local facilityId = tonumber(args[1])
    
    if not facilityId or not Config.ManufacturingFacilities[facilityId] then
        lib.notify({
            title = 'Invalid Facility',
            description = 'Use: /tpfacility [1-5]',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local facility = Config.ManufacturingFacilities[facilityId]
    local playerPed = PlayerPedId()
    
    SetEntityCoords(playerPed, facility.position.x, facility.position.y, facility.position.z + 1.0, false, false, false, true)
    
    lib.notify({
        title = 'Teleported',
        description = 'Teleported to ' .. facility.name,
        type = 'success',
        duration = 5000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)