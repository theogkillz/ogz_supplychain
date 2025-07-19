-- ============================================
-- MANUFACTURING RECIPES & PLANNING
-- Recipe management and production planning
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Recipe and planning state
local availableRecipes = {}

-- ============================================
-- RECIPE DISPLAY SYSTEM
-- ============================================

-- Show available recipes with enterprise categorization
RegisterNetEvent("manufacturing:showRecipes")
AddEventHandler("manufacturing:showRecipes", function(recipes, facilityId)
    availableRecipes = recipes
    
    if #recipes == 0 then
        exports.ogz_supplychain:infoNotify(
            "No Recipes Available",
            "This facility has no recipes available for your skill level"
        )
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
    
    -- Group recipes by category with enterprise organization
    local categorizedRecipes = {}
    for _, recipe in ipairs(recipes) do
        if not categorizedRecipes[recipe.category] then
            categorizedRecipes[recipe.category] = {}
        end
        table.insert(categorizedRecipes[recipe.category], recipe)
    end
    
    -- Add category headers and recipes with comprehensive validation
    for category, categoryRecipes in pairs(categorizedRecipes) do
        table.insert(options, {
            title = "── " .. category:gsub("^%l", string.upper) .. " ──",
            description = #categoryRecipes .. " recipes available",
            disabled = true
        })
        
        for _, recipe in ipairs(categoryRecipes) do
            -- Comprehensive ingredient validation
            local canCraft, missingIngredients = validateRecipeIngredients(recipe)
            
            local statusIcon = canCraft and "✅" or "❌"
            local skillText = recipe.skillRequired and recipe.skillRequired > 0 and 
                string.format(" (Skill: %d)", recipe.skillRequired) or ""
            
            table.insert(options, {
                title = statusIcon .. " " .. recipe.name,
                description = recipe.description .. skillText,
                metadata = {
                    ["Category"] = recipe.category,
                    ["Skill Required"] = recipe.skillRequired or 0,
                    ["Processing Time"] = exports.ogz_supplychain:formatTime(recipe.processingTime or 60),
                    ["Can Craft"] = canCraft and "Yes" or "Missing ingredients",
                    ["Difficulty"] = getRecipeDifficulty(recipe)
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

-- ============================================
-- INDIVIDUAL RECIPE MANAGEMENT
-- ============================================

-- Open comprehensive recipe details and production options
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
    
    -- Comprehensive ingredient display
    table.insert(options, {
        title = "🧪 Required Ingredients",
        description = "Raw materials needed for production",
        disabled = true
    })
    
    for ingredient, required in pairs(recipe.inputs or {}) do
        local playerAmount = exports.ox_inventory:GetItemCount(cache.serverId, ingredient) or 0
        local statusIcon = playerAmount >= required and "✅" or "❌"
        local itemLabel = getItemLabel(ingredient)
        
        table.insert(options, {
            title = statusIcon .. " " .. itemLabel,
            description = string.format("Required: %d | You have: %d", required, playerAmount),
            metadata = {
                ["Item"] = itemLabel,
                ["Required"] = required,
                ["Available"] = playerAmount,
                ["Status"] = playerAmount >= required and "Sufficient" or "Insufficient"
            },
            disabled = true
        })
    end
    
    -- Enhanced output display
    table.insert(options, {
        title = "🎯 Output Products",
        description = "What you'll produce",
        disabled = true
    })
    
    for outputItem, outputData in pairs(recipe.outputs or {}) do
        local itemLabel = getItemLabel(outputItem)
        table.insert(options, {
            title = "📦 " .. itemLabel,
            description = string.format("Base yield: %d per batch", outputData.quantity),
            metadata = {
                ["Base Quantity"] = outputData.quantity,
                ["Quality"] = outputData.quality or "standard",
                ["Estimated Value"] = "$" .. ((outputData.value or 50) * outputData.quantity)
            },
            disabled = true
        })
    end
    
    -- Production options with enterprise quality levels
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
    
    -- Recipe planning tools
    table.insert(options, {
        title = "📊 Production Calculator",
        description = "Calculate costs and requirements for batch sizes",
        icon = "fas fa-calculator",
        onSelect = function()
            TriggerEvent("manufacturing:openProductionCalculator", recipe)
        end
    })
    
    lib.registerContext({
        id = "manufacturing_recipe_menu",
        title = "🧪 " .. recipe.name,
        options = options
    })
    lib.showContext("manufacturing_recipe_menu")
end)

-- ============================================
-- RECIPE PLANNING & CALCULATION TOOLS
-- ============================================

-- Open production calculator for planning
RegisterNetEvent("manufacturing:openProductionCalculator")
AddEventHandler("manufacturing:openProductionCalculator", function(recipe)
    local input = exports.ogz_supplychain:showInput("Production Calculator", {
        {
            type = "number",
            label = "Calculate for Quantity",
            description = "Enter number of batches to calculate requirements",
            placeholder = "Enter quantity",
            min = 1,
            max = 50,
            required = true,
            default = 5
        }
    })
    
    if input and input[1] then
        local quantity = tonumber(input[1])
        if quantity > 0 then
            TriggerEvent("manufacturing:showProductionCalculation", recipe, quantity)
        end
    end
end)

-- Display comprehensive production calculations
RegisterNetEvent("manufacturing:showProductionCalculation")
AddEventHandler("manufacturing:showProductionCalculation", function(recipe, quantity)
    local options = {
        {
            title = "← Back to Recipe",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:openRecipeMenu", recipe, 
                    exports['ogz_supplychain']:getCurrentManufacturingFacility())
            end
        },
        {
            title = "📊 Production Calculation",
            description = string.format("Requirements for %d batches of %s", quantity, recipe.name),
            disabled = true
        }
    }
    
    -- Calculate ingredient requirements
    local totalIngredients = {}
    local totalCost = 0
    
    for ingredient, required in pairs(recipe.inputs or {}) do
        local totalRequired = required * quantity
        totalIngredients[ingredient] = totalRequired
        
        -- Estimate ingredient cost (placeholder - could be from market data)
        local estimatedCost = totalRequired * 10 -- $10 per unit estimate
        totalCost = totalCost + estimatedCost
    end
    
    -- Display ingredient requirements
    table.insert(options, {
        title = "📦 Total Ingredient Requirements",
        description = "Materials needed for this production run",
        disabled = true
    })
    
    for ingredient, totalRequired in pairs(totalIngredients) do
        local playerAmount = exports.ox_inventory:GetItemCount(cache.serverId, ingredient) or 0
        local statusIcon = playerAmount >= totalRequired and "✅" or "❌"
        local itemLabel = getItemLabel(ingredient)
        
        table.insert(options, {
            title = statusIcon .. " " .. itemLabel,
            description = string.format("Need: %d | Have: %d", totalRequired, playerAmount),
            disabled = true
        })
    end
    
    -- Calculate processing details
    local baseTime = recipe.processingTime or 60
    local totalTime = baseTime * quantity
    local processingCost = calculateEstimatedProcessingCost(recipe, quantity)
    
    table.insert(options, {
        title = "⏱️ Processing Summary",
        description = "Time and cost breakdown",
        metadata = {
            ["Total Processing Time"] = exports.ogz_supplychain:formatTime(totalTime),
            ["Estimated Processing Cost"] = "$" .. exports.ogz_supplychain:formatMoney(processingCost),
            ["Estimated Material Cost"] = "$" .. exports.ogz_supplychain:formatMoney(totalCost),
            ["Total Estimated Cost"] = "$" .. exports.ogz_supplychain:formatMoney(totalCost + processingCost)
        },
        disabled = true
    })
    
    -- Expected output
    local outputItem = next(recipe.outputs)
    local outputData = recipe.outputs[outputItem]
    local expectedOutput = outputData.quantity * quantity
    
    table.insert(options, {
        title = "🎯 Expected Output",
        description = "Production yield estimation",
        metadata = {
            ["Output Item"] = getItemLabel(outputItem),
            ["Expected Quantity"] = expectedOutput,
            ["Quality"] = "Standard (varies by production choice)",
            ["Estimated Value"] = "$" .. exports.ogz_supplychain:formatMoney(expectedOutput * (outputData.value or 50))
        },
        disabled = true
    })
    
    -- Quick start production option
    table.insert(options, {
        title = "🚀 Start This Production Run",
        description = "Begin manufacturing with calculated quantities",
        icon = "fas fa-rocket",
        onSelect = function()
            TriggerEvent("manufacturing:selectQuantityAndQuality", recipe, 
                exports['ogz_supplychain']:getCurrentManufacturingFacility(), "standard")
        end
    })
    
    lib.registerContext({
        id = "manufacturing_production_calculator",
        title = "📊 Production Calculator",
        options = options
    })
    lib.showContext("manufacturing_production_calculator")
end)

-- ============================================
-- RECIPE GUIDE SYSTEM
-- ============================================

-- Open comprehensive recipe guide for facility
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
        
        for recipeId, recipe in pairs(Config.ManufacturingRecipes or {}) do
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
                local difficultyRating = getRecipeDifficulty(recipe)
                
                table.insert(options, {
                    title = "📖 " .. recipe.name,
                    description = recipe.description .. skillText,
                    metadata = {
                        ["Skill Required"] = recipe.skillRequired or 0,
                        ["Category"] = recipe.category,
                        ["Processing Time"] = exports.ogz_supplychain:formatTime(recipe.processingTime or 60),
                        ["Difficulty"] = difficultyRating,
                        ["Specialization"] = specialization
                    },
                    onSelect = function()
                        TriggerEvent("manufacturing:showRecipeDetails", recipe)
                    end
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

-- ============================================
-- MISSING INGREDIENTS HANDLING
-- ============================================

-- Show missing ingredients with comprehensive sourcing information
RegisterNetEvent("manufacturing:showMissingIngredients")
AddEventHandler("manufacturing:showMissingIngredients", function(missingIngredients)
    local options = {
        {
            title = "← Back to Recipes",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:navigateBack", "recipes")
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
            metadata = {
                ["Required"] = missing.required,
                ["Current"] = missing.current,
                ["Missing"] = missing.missing,
                ["Availability"] = getSourcingInfo(missing.item)
            },
            disabled = true
        })
    end
    
    -- Ingredient sourcing suggestions
    table.insert(options, {
        title = "💡 Sourcing Suggestions",
        description = "Where to find missing ingredients",
        onSelect = function()
            TriggerEvent("manufacturing:showSourcingGuide", missingIngredients)
        end
    })
    
    lib.registerContext({
        id = "manufacturing_missing_ingredients",
        title = "❌ Missing Ingredients",
        options = options
    })
    lib.showContext("manufacturing_missing_ingredients")
end)

-- ============================================
-- RECIPE VALIDATION & UTILITY FUNCTIONS
-- ============================================

-- Validate recipe ingredients comprehensively
function validateRecipeIngredients(recipe)
    local canCraft = true
    local missingIngredients = {}
    
    if recipe.inputs then
        for ingredient, required in pairs(recipe.inputs) do
            local playerAmount = exports.ox_inventory:GetItemCount(cache.serverId, ingredient) or 0
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
    end
    
    return canCraft, missingIngredients
end

-- Get item label with enterprise error handling
function getItemLabel(item)
    local itemNames = exports.ox_inventory:Items() or {}
    return itemNames[item] and itemNames[item].label or item
end

-- Calculate recipe difficulty rating
function getRecipeDifficulty(recipe)
    local difficulty = "Beginner"
    local skillReq = recipe.skillRequired or 0
    local ingredientCount = recipe.inputs and #recipe.inputs or 0
    
    if skillReq >= 50 or ingredientCount >= 5 then
        difficulty = "Expert"
    elseif skillReq >= 25 or ingredientCount >= 3 then
        difficulty = "Intermediate"
    end
    
    return difficulty
end

-- Get ingredient sourcing information
function getSourcingInfo(ingredient)
    -- This could be expanded to integrate with warehouse/market systems
    return "Check warehouse or purchase from suppliers"
end

-- Calculate estimated processing cost
function calculateEstimatedProcessingCost(recipe, quantity)
    local costs = Config.Manufacturing and Config.Manufacturing.processingCosts
    if not costs then return 100 * quantity end
    
    local baseCost = costs.baseProcessingFee or 50
    local maintenanceCost = (costs.maintenanceFee or 15) * quantity
    return baseCost + maintenanceCost
end

-- ============================================
-- SOURCING GUIDE SYSTEM
-- ============================================

-- Show ingredient sourcing guide
RegisterNetEvent("manufacturing:showSourcingGuide")
AddEventHandler("manufacturing:showSourcingGuide", function(missingIngredients)
    local options = {
        {
            title = "← Back to Missing Ingredients",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("manufacturing:showMissingIngredients", missingIngredients)
            end
        },
        {
            title = "💡 Ingredient Sourcing Guide",
            description = "How to obtain missing ingredients",
            disabled = true
        }
    }
    
    -- Sourcing methods
    table.insert(options, {
        title = "🏪 Warehouse System",
        description = "Check supply warehouse for available ingredients",
        onSelect = function()
            exports.ogz_supplychain:infoNotify(
                "Warehouse Integration",
                "Navigate to warehouse to check ingredient availability"
            )
        end
    })
    
    table.insert(options, {
        title = "🚚 Supply Orders",
        description = "Place orders for specific ingredients",
        onSelect = function()
            exports.ogz_supplychain:infoNotify(
                "Supply Orders",
                "Use the ordering system to request specific ingredients"
            )
        end
    })
    
    table.insert(options, {
        title = "🌱 Alternative Production",
        description = "Some ingredients can be manufactured elsewhere",
        onSelect = function()
            TriggerEvent("manufacturing:showAlternativeProduction", missingIngredients)
        end
    })
    
    lib.registerContext({
        id = "manufacturing_sourcing_guide",
        title = "💡 Sourcing Guide",
        options = options
    })
    lib.showContext("manufacturing_sourcing_guide")
end)

-- ============================================
-- EXPORTS FOR COMPONENT COORDINATION
-- ============================================

-- Export recipe validation
exports('validateRecipeIngredients', validateRecipeIngredients)

-- Export available recipes
exports('getAvailableRecipes', function()
    return availableRecipes
end)

-- Export recipe difficulty calculation
exports('getRecipeDifficulty', getRecipeDifficulty)

-- Export sourcing information
exports('getSourcingInfo', getSourcingInfo)

-- Export production calculator trigger
exports('openProductionCalculator', function(recipe)
    TriggerEvent("manufacturing:openProductionCalculator", recipe)
end)

print("[MANUFACTURING] Recipes & Planning initialized")