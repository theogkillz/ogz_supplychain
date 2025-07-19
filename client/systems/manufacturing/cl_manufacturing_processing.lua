-- ============================================
-- MANUFACTURING PROCESSING & QUALITY CONTROL
-- Production workflow and batch processing
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Processing state
local currentProcessing = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Calculate container requirements using enterprise system
local function calculateContainers(totalItems)
    local containerSystem = Config.Manufacturing.containerSystem
    local itemsPerContainer = containerSystem.itemsPerContainer
    local containersPerBox = containerSystem.containersPerBox
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return containersNeeded, boxesNeeded
end

-- Get player's inventory count for item using enterprise integration
local function getInventoryCount(item)
    return exports.ox_inventory:GetItemCount(cache.serverId, item) or 0
end

-- Get item label from ox_inventory with enterprise error handling
local function getItemLabel(item)
    local itemNames = exports.ox_inventory:Items() or {}
    return itemNames[item] and itemNames[item].label or item
end

-- ============================================
-- PRODUCTION SELECTION & CONFIGURATION
-- ============================================

-- Select quantity and quality with enterprise input handling
RegisterNetEvent("manufacturing:selectQuantityAndQuality")
AddEventHandler("manufacturing:selectQuantityAndQuality", function(recipe, facilityId, qualityLevel)
    local input = exports.ogz_supplychain:showInput("Manufacturing Batch Configuration", {
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

-- ============================================
-- PRODUCTION CONFIRMATION & COST CALCULATION
-- ============================================

-- Confirm production with comprehensive cost breakdown
RegisterNetEvent("manufacturing:confirmProduction")
AddEventHandler("manufacturing:confirmProduction", function(recipe, facilityId, quantity, qualityLevel)
    -- Calculate costs using enterprise formula
    local costs = Config.Manufacturing.processingCosts
    local timing = Config.Manufacturing.timing
    
    local baseCost = costs.baseProcessingFee
    local processingTime = timing.baseProcessingTime + (timing.timePerItem * (quantity - 1))
    local electricityCost = (processingTime / 3600000) * costs.electricityCost
    local maintenanceCost = costs.maintenanceFee * quantity
    
    local qualityCost = 0
    if qualityLevel == "premium" or qualityLevel == "organic" then
        qualityCost = costs.qualityBonusCost * quantity
        processingTime = processingTime * timing.qualityProcessingMultiplier
    end
    
    local totalCost = math.floor(baseCost + electricityCost + maintenanceCost + qualityCost)
    local totalTime = math.floor(processingTime / 1000)
    
    -- Calculate output with enterprise precision
    local baseYield = recipe.outputs[next(recipe.outputs)].quantity * quantity
    local containers, boxes = calculateContainers(baseYield)
    
    -- Get output item info
    local outputItem = next(recipe.outputs)
    local outputLabel = getItemLabel(outputItem)
    
    -- Enterprise confirmation dialog
    lib.alertDialog({
        header = "🏭 Confirm Manufacturing Order",
        content = string.format(
            "**Recipe:** %s\n**Quantity:** %d batches\n**Quality:** %s\n\n" ..
            "**💰 Total Cost:** $%s\n**⏱️ Processing Time:** %s\n**📦 Expected Output:** ~%d %s\n**🏭 Containers:** %d containers (%d boxes)\n\n" ..
            "Proceed with manufacturing?",
            recipe.name,
            quantity,
            qualityLevel:gsub("^%l", string.upper),
            exports.ogz_supplychain:formatMoney(totalCost),
            exports.ogz_supplychain:formatTime(totalTime),
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
-- PROCESSING FEEDBACK & PROGRESS TRACKING
-- ============================================

-- Show processing started feedback with enterprise progress tracking
RegisterNetEvent("manufacturing:processStarted")
AddEventHandler("manufacturing:processStarted", function(data)
    currentProcessing = data
    
    exports.ogz_supplychain:successNotify(
        "🏭 Manufacturing Started",
        string.format(
            "Processing will complete in **%s**\nCost: $%s",
            exports.ogz_supplychain:formatTime(math.floor(data.processingTime / 1000)),
            exports.ogz_supplychain:formatMoney(data.processingCost)
        )
    )
    
    -- Enterprise progress bar
    exports.ogz_supplychain:showProgress({
        duration = data.processingTime,
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
    
    -- Enterprise countdown notification system
    local remainingTime = math.floor(data.processingTime / 1000)
    local countdownThread = Citizen.CreateThread(function()
        while remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1
            
            -- Milestone notifications using enterprise system
            if remainingTime == 30 then
                exports.ogz_supplychain:infoNotify(
                    "⏰ Manufacturing Update",
                    "Process will complete in 30 seconds"
                )
            elseif remainingTime == 10 then
                exports.ogz_supplychain:warningNotify(
                    "🔥 Almost Ready!",
                    "Manufacturing completing in 10 seconds"
                )
            end
        end
    end)
end)

-- ============================================
-- PRODUCTION COMPLETION HANDLING
-- ============================================

-- Manufacturing process completed with enterprise success tracking
RegisterNetEvent("manufacturing:processCompleted")
AddEventHandler("manufacturing:processCompleted", function(result)
    exports.ogz_supplychain:successNotify(
        "🎉 Manufacturing Complete!",
        string.format(
            "Produced **%d %s**\nQuality: %s",
            result.quantity,
            result.itemLabel,
            result.quality
        )
    )
    
    -- Clear processing state
    currentProcessing = {}
    
    -- Trigger enterprise achievement tracking
    TriggerEvent("achievements:trackManufacturing", {
        type = "production_complete",
        quantity = result.quantity,
        quality = result.quality,
        item = result.itemLabel
    })
end)

-- ============================================
-- EMERGENCY PRODUCTION SYSTEM
-- ============================================

-- Handle emergency production requests with priority processing
RegisterNetEvent("manufacturing:startEmergencyProduction")
AddEventHandler("manufacturing:startEmergencyProduction", function(recipe, quantity)
    -- Get current facility
    local currentFacility = exports['ogz_supplychain']:getCurrentManufacturingFacility()
    
    if not currentFacility then
        exports.ogz_supplychain:errorNotify(
            "Error",
            "No facility selected for emergency production"
        )
        return
    end
    
    -- Validate emergency production access
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    -- Emergency production alert
    exports.ogz_supplychain:warningNotify(
        "🚨 Emergency Production",
        "Priority manufacturing request initiated"
    )
    
    -- Trigger emergency processing on server
    TriggerServerEvent("manufacturing:emergencyProduction", recipe.id, quantity, currentFacility)
end)

-- ============================================
-- QUALITY CONTROL INTERFACE
-- ============================================

-- Show quality control results
RegisterNetEvent("manufacturing:showQualityResults")
AddEventHandler("manufacturing:showQualityResults", function(qualityData)
    local qualityIcon = "✅"
    local qualityColor = "success"
    
    if not qualityData.success then
        qualityIcon = "❌"
        qualityColor = "error"
    elseif qualityData.level == "premium" then
        qualityIcon = "⭐"
        qualityColor = "warning"
    elseif qualityData.level == "organic" then
        qualityIcon = "🌿"
        qualityColor = "info"
    end
    
    local options = {
        {
            title = "← Back to Production",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:returnToFacilityMenu")
            end
        },
        {
            title = qualityIcon .. " Quality Control Results",
            description = "Production quality assessment",
            disabled = true
        },
        {
            title = "📊 Quality Level",
            description = qualityData.level:gsub("^%l", string.upper),
            metadata = {
                ["Success Rate"] = string.format("%.1f%%", (qualityData.successRate or 0) * 100),
                ["Yield Multiplier"] = string.format("%.1fx", qualityData.yieldMultiplier or 1.0),
                ["Final Result"] = qualityData.success and "Passed" or "Failed"
            },
            disabled = true
        }
    }
    
    if qualityData.bonuses and #qualityData.bonuses > 0 then
        table.insert(options, {
            title = "🎯 Quality Bonuses",
            description = "Applied bonuses for this production",
            disabled = true
        })
        
        for _, bonus in ipairs(qualityData.bonuses) do
            table.insert(options, {
                title = "+" .. bonus.name,
                description = bonus.description,
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "manufacturing_quality_results",
        title = "🔬 Quality Control",
        options = options
    })
    lib.showContext("manufacturing_quality_results")
end)

-- ============================================
-- BATCH PROCESSING MANAGEMENT
-- ============================================

-- Handle batch processing with enterprise coordination
RegisterNetEvent("manufacturing:processBatch")
AddEventHandler("manufacturing:processBatch", function(batchData)
    if not exports.ogz_supplychain:validatePlayerAccess("manufacturing") then
        return
    end
    
    -- Validate batch configuration
    if not batchData.recipe or not batchData.quantity or batchData.quantity <= 0 then
        exports.ogz_supplychain:errorNotify(
            "Batch Error",
            "Invalid batch configuration"
        )
        return
    end
    
    -- Calculate batch requirements
    local totalIngredients = {}
    for ingredient, amount in pairs(batchData.recipe.inputs or {}) do
        totalIngredients[ingredient] = amount * batchData.quantity
    end
    
    -- Validate ingredient availability
    local hasAllIngredients = true
    local missingIngredients = {}
    
    for ingredient, required in pairs(totalIngredients) do
        local available = getInventoryCount(ingredient)
        if available < required then
            hasAllIngredients = false
            table.insert(missingIngredients, {
                item = getItemLabel(ingredient),
                required = required,
                available = available,
                missing = required - available
            })
        end
    end
    
    if not hasAllIngredients then
        TriggerEvent("manufacturing:showMissingIngredients", missingIngredients)
        return
    end
    
    -- Start batch processing
    TriggerEvent("manufacturing:selectQuantityAndQuality", batchData.recipe, batchData.facilityId, "standard")
end)

-- ============================================
-- PROCESSING STATE MANAGEMENT
-- ============================================

-- Get current processing status
RegisterNetEvent("manufacturing:getCurrentProcessing")
AddEventHandler("manufacturing:getCurrentProcessing", function()
    return currentProcessing
end)

-- Clear processing state
RegisterNetEvent("manufacturing:clearProcessing")
AddEventHandler("manufacturing:clearProcessing", function()
    currentProcessing = {}
end)

-- Check if currently processing
RegisterNetEvent("manufacturing:isProcessing")
AddEventHandler("manufacturing:isProcessing", function()
    return next(currentProcessing) ~= nil
end)

-- ============================================
-- EXPORTS FOR COMPONENT COORDINATION
-- ============================================

-- Export processing state for other components
exports('getCurrentProcessing', function()
    return currentProcessing
end)

-- Export processing validation
exports('isCurrentlyProcessing', function()
    return next(currentProcessing) ~= nil
end)

-- Export emergency production trigger
exports('triggerEmergencyProduction', function(recipe, quantity)
    TriggerEvent("manufacturing:startEmergencyProduction", recipe, quantity)
end)

-- Export batch processing
exports('startBatchProcessing', function(batchData)
    TriggerEvent("manufacturing:processBatch", batchData)
end)

print("[MANUFACTURING] Processing & Quality Control initialized")