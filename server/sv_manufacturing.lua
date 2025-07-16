-- ============================================
-- MANUFACTURING SYSTEM - SERVER LOGIC
-- Professional ingredient creation system
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Manufacturing state tracking
local activeManufacturingProcesses = {}
local manufacturingSkills = {}
local facilityStatus = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Check if player has manufacturing access
local function hasManufacturingAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end
    
    local playerJob = Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Get player's manufacturing skill level
local function getManufacturingSkill(citizenid, category)
    if not manufacturingSkills[citizenid] then
        manufacturingSkills[citizenid] = {}
    end
    
    if not manufacturingSkills[citizenid][category] then
        -- Load from database
        MySQL.Async.fetchScalar('SELECT skill_level FROM manufacturing_skills WHERE citizenid = ? AND category = ?', 
            {citizenid, category}, function(level)
            manufacturingSkills[citizenid][category] = level or 0
        end)
        return 0
    end
    
    return manufacturingSkills[citizenid][category] or 0
end

-- Update manufacturing skill
local function updateManufacturingSkill(citizenid, category, experience)
    local currentSkill = getManufacturingSkill(citizenid, category)
    local skillConfig = Config.ManufacturingSkills and Config.ManufacturingSkills.skillCategories and 
                       Config.ManufacturingSkills.skillCategories[category]
    
    if not skillConfig then return end
    
    local maxLevel = skillConfig.maxLevel or 100
    local experienceRate = skillConfig.experienceRate or 1.0
    
    -- Calculate new experience (simplified leveling)
    local adjustedExperience = experience * experienceRate
    local newSkill = math.min(maxLevel, currentSkill + (adjustedExperience / 100))
    
    -- Update in memory and database
    if not manufacturingSkills[citizenid] then
        manufacturingSkills[citizenid] = {}
    end
    manufacturingSkills[citizenid][category] = newSkill
    
    MySQL.Async.execute([[
        INSERT INTO manufacturing_skills (citizenid, category, skill_level, total_experience)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            skill_level = VALUES(skill_level),
            total_experience = total_experience + ?,
            updated_at = CURRENT_TIMESTAMP
    ]], {citizenid, category, newSkill, adjustedExperience, adjustedExperience})
    
    -- Check for skill level milestone
    if math.floor(newSkill) > math.floor(currentSkill) then
        local src = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = '🎯 Skill Level Up!',
                description = string.format('**%s** skill increased to level **%d**!', 
                    skillConfig.name or category, math.floor(newSkill)),
                type = 'success',
                duration = 8000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
    end
end

-- Calculate processing cost
local function calculateProcessingCost(recipe, quantity, qualityLevel)
    local costs = Config.Manufacturing and Config.Manufacturing.processingCosts
    if not costs then return 100 end -- Fallback cost
    
    local baseCost = costs.baseProcessingFee or 50
    
    -- Add electricity and maintenance costs
    local processingTime = (recipe.processingTime or 60) * quantity
    local electricityCost = (processingTime / 3600) * (costs.electricityCost or 10) -- Per hour
    local maintenanceCost = (costs.maintenanceFee or 5) * quantity
    
    -- Quality bonus cost
    local qualityCost = 0
    if qualityLevel == "premium" or qualityLevel == "organic" then
        qualityCost = (costs.qualityBonusCost or 15) * quantity
    end
    
    return math.floor(baseCost + electricityCost + maintenanceCost + qualityCost)
end

-- Calculate processing time with bonuses
local function calculateProcessingTime(recipe, quantity, citizenid, qualityLevel)
    local timing = Config.Manufacturing and Config.Manufacturing.timing
    if not timing then
        return 60000 -- Fallback: 60 seconds
    end
    
    local baseTime = timing.baseProcessingTime or 30000
    local timePerItem = (timing.timePerItem or 5000) * (quantity - 1) -- First item included in base time
    
    -- Quality processing multiplier
    local qualityMultiplier = 1.0
    if qualityLevel == "premium" then
        qualityMultiplier = timing.qualityProcessingMultiplier or 1.2
    elseif qualityLevel == "organic" then
        qualityMultiplier = (timing.qualityProcessingMultiplier or 1.2) * 1.2
    end
    
    local totalTime = (baseTime + timePerItem) * qualityMultiplier
    
    -- Apply skill bonuses
    local skillLevel = getManufacturingSkill(citizenid, recipe.category)
    local speedBonus = 0
    
    if Config.ManufacturingSkills and Config.ManufacturingSkills.levelBonuses then
        for level, bonus in pairs(Config.ManufacturingSkills.levelBonuses) do
            if skillLevel >= level and bonus and bonus.speedBonus then
                speedBonus = bonus.speedBonus
            end
        end
    end
    
    -- Apply speed bonus (reduce processing time)
    totalTime = totalTime * (1 - speedBonus)
    
    -- Cap processing time
    return math.min(totalTime, timing.maxProcessingTime or 300000)
end

-- Calculate yield with bonuses
local function calculateYield(recipe, quantity, citizenid, qualityLevel, qualitySuccess)
    local baseYield = recipe.outputs and recipe.outputs[next(recipe.outputs)] and 
                     recipe.outputs[next(recipe.outputs)].quantity or 1
    baseYield = baseYield * quantity
    
    if not qualitySuccess then
        -- Quality control failed, reduced yield
        return math.floor(baseYield * 0.7)
    end
    
    local yieldMultiplier = 1.0
    
    -- Quality yield multiplier
    local qualityControl = Config.Manufacturing and Config.Manufacturing.qualityControl
    if qualityControl then
        if qualityLevel == "premium" and qualityControl.premiumQuality then
            yieldMultiplier = qualityControl.premiumQuality.yieldMultiplier or 1.0
        elseif qualityLevel == "organic" and qualityControl.organicQuality then
            yieldMultiplier = qualityControl.organicQuality.yieldMultiplier or 1.0
        end
    end
    
    -- Apply skill bonuses
    local skillLevel = getManufacturingSkill(citizenid, recipe.category)
    local yieldBonus = 0
    
    if Config.ManufacturingSkills and Config.ManufacturingSkills.levelBonuses then
        for level, bonus in pairs(Config.ManufacturingSkills.levelBonuses) do
            if skillLevel >= level and bonus and bonus.yieldBonus then
                yieldBonus = bonus.yieldBonus
            end
        end
    end
    
    yieldMultiplier = yieldMultiplier * (1 + yieldBonus)
    
    return math.floor(baseYield * yieldMultiplier)
end

-- Check if recipe can be processed at facility
local function canProcessRecipeAtFacility(recipe, facilityId)
    local facility = Config.ManufacturingFacilities and Config.ManufacturingFacilities[facilityId]
    if not facility then return false end
    
    -- Check if facility specialization matches recipe
    if recipe.facility_specialization and facility.specializations then
        for _, specialization in ipairs(facility.specializations) do
            if specialization == recipe.facility_specialization then
                return true
            end
        end
        return false
    end
    
    return true
end

-- Quality control check
local function performQualityControl(recipe, qualityLevel, skillLevel)
    local qualityControl = Config.Manufacturing and Config.Manufacturing.qualityControl
    if not qualityControl then
        return true, 1.0 -- Default success if no quality config
    end
    
    local qualityConfig = qualityControl[qualityLevel .. "Quality"]
    if not qualityConfig then
        qualityConfig = qualityControl.standardQuality or {successRate = 0.8, requiredSkill = 0}
    end
    
    -- Check skill requirement
    if qualityConfig.requiredSkill and skillLevel < qualityConfig.requiredSkill then
        return false, "Insufficient skill level for " .. qualityLevel .. " quality"
    end
    
    -- Random success check
    local successRoll = math.random()
    local successRate = qualityConfig.successRate or 0.8
    
    -- Skill bonus to success rate (up to 10% bonus at max skill)
    local skillBonus = (skillLevel / 100) * 0.1
    successRate = math.min(1.0, successRate + skillBonus)
    
    return successRoll <= successRate, successRate
end

-- ============================================
-- MAIN MANUFACTURING FUNCTIONS
-- ============================================

-- Start manufacturing process
local function startManufacturing(src, recipeId, quantity, qualityLevel, facilityId)
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return false, "Player not found" end
    
    local citizenid = xPlayer.PlayerData and xPlayer.PlayerData.citizenid
    if not citizenid then return false, "Invalid player data" end
    
    local recipe = Config.ManufacturingRecipes and Config.ManufacturingRecipes[recipeId]
    
    if not recipe then
        return false, "Recipe not found"
    end
    
    -- Validate facility
    if not canProcessRecipeAtFacility(recipe, facilityId) then
        return false, "This recipe cannot be processed at this facility"
    end
    
    -- Validate quantity
    local maxItems = Config.Manufacturing and Config.Manufacturing.containerSystem and 
                    Config.Manufacturing.containerSystem.maxItemsPerBatch or 50
    if quantity <= 0 or quantity > maxItems then
        return false, "Invalid quantity"
    end
    
    -- Check skill requirements
    local skillLevel = getManufacturingSkill(citizenid, recipe.category)
    if recipe.skillRequired and skillLevel < recipe.skillRequired then
        return false, "Insufficient skill level. Required: " .. recipe.skillRequired .. ", Current: " .. math.floor(skillLevel)
    end
    
    -- Check ingredients
    local hasIngredients = true
    local missingIngredients = {}
    
    if recipe.inputs then
        for ingredient, requiredAmount in pairs(recipe.inputs) do
            local totalRequired = requiredAmount * quantity
            local playerAmount = exports.ox_inventory:GetItemCount(src, ingredient) or 0
            
            if playerAmount < totalRequired then
                hasIngredients = false
                table.insert(missingIngredients, {
                    item = ingredient,
                    required = totalRequired,
                    current = playerAmount,
                    missing = totalRequired - playerAmount
                })
            end
        end
    end
    
    if not hasIngredients then
        return false, "Missing ingredients", missingIngredients
    end
    
    -- Calculate processing cost
    local processingCost = calculateProcessingCost(recipe, quantity, qualityLevel)
    
    -- Check if player can afford processing cost
    local playerMoney = xPlayer.PlayerData and xPlayer.PlayerData.money and xPlayer.PlayerData.money.cash or 0
    if playerMoney < processingCost then
        return false, "Insufficient cash for processing. Cost: $" .. processingCost
    end
    
    -- Remove money for processing
    if not xPlayer.Functions.RemoveMoney('cash', processingCost, "Manufacturing processing cost") then
        return false, "Failed to deduct processing cost"
    end
    
    -- Remove ingredients
    if recipe.inputs then
        for ingredient, requiredAmount in pairs(recipe.inputs) do
            local totalRequired = requiredAmount * quantity
            if not exports.ox_inventory:RemoveItem(src, ingredient, totalRequired) then
                -- Refund money if ingredient removal fails
                xPlayer.Functions.AddMoney('cash', processingCost, "Manufacturing refund")
                return false, "Failed to remove ingredients"
            end
        end
    end
    
    -- Perform quality control check
    local qualitySuccess, qualityRate = performQualityControl(recipe, qualityLevel, skillLevel)
    
    -- Calculate processing time
    local processingTime = calculateProcessingTime(recipe, quantity, citizenid, qualityLevel)
    
    -- Create manufacturing process
    local processId = citizenid .. "_" .. os.time()
    activeManufacturingProcesses[processId] = {
        playerId = src,
        citizenid = citizenid,
        recipeId = recipeId,
        recipe = recipe,
        quantity = quantity,
        qualityLevel = qualityLevel,
        qualitySuccess = qualitySuccess,
        facilityId = facilityId,
        startTime = os.time(),
        endTime = os.time() + math.floor(processingTime / 1000),
        processingCost = processingCost
    }
    
    -- Log manufacturing start
    MySQL.Async.execute([[
        INSERT INTO manufacturing_logs (
            citizenid, recipe_id, quantity, quality_level, facility_id,
            processing_cost, processing_time, start_time, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'processing')
    ]], {
        citizenid, recipeId, quantity, qualityLevel, facilityId,
        processingCost, processingTime, os.time()
    })
    
    return true, "Manufacturing started", {
        processId = processId,
        processingTime = processingTime,
        processingCost = processingCost,
        qualitySuccess = qualitySuccess,
        endTime = os.time() + math.floor(processingTime / 1000)
    }
end

-- Complete manufacturing process
local function completeManufacturing(processId)
    local process = activeManufacturingProcesses[processId]
    if not process then return false, "Process not found" end
    
    local xPlayer = QBCore.Functions.GetPlayer(process.playerId)
    if not xPlayer then return false, "Player not found" end
    
    local recipe = process.recipe
    local quantity = process.quantity
    local qualityLevel = process.qualityLevel
    local qualitySuccess = process.qualitySuccess
    local citizenid = process.citizenid
    
    -- Calculate final yield
    local finalYield = calculateYield(recipe, quantity, citizenid, qualityLevel, qualitySuccess)
    
    -- Get output item
    local outputItem = recipe.outputs and next(recipe.outputs)
    local outputData = recipe.outputs and recipe.outputs[outputItem]
    
    if not outputItem then
        return false, "No output item defined in recipe"
    end
    
    -- Determine final output item name based on quality
    local finalOutputItem = outputItem
    if qualityLevel == "premium" and qualitySuccess then
        -- Use premium version if available, otherwise standard
        finalOutputItem = outputItem:gsub("_basic", "_premium") -- Naming convention
    elseif qualityLevel == "organic" and qualitySuccess then
        finalOutputItem = outputItem:gsub("_basic", "_organic"):gsub("_premium", "_organic")
    end
    
    -- Give output items
    local success = exports.ox_inventory:AddItem(process.playerId, finalOutputItem, finalYield)
    if not success then
        -- Try to give money equivalent if inventory full
        local itemValue = outputData and outputData.value or 50 -- Fallback value
        local refundAmount = finalYield * itemValue
        xPlayer.Functions.AddMoney('bank', refundAmount, "Manufacturing output refund")
        
        TriggerClientEvent('ox_lib:notify', process.playerId, {
            title = 'Inventory Full',
            description = string.format('Received $%d refund for %d %s (inventory full)', 
                refundAmount, finalYield, finalOutputItem),
            type = 'warning',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    else
        -- Successful manufacturing notification
        local qualityText = qualitySuccess and (" (" .. qualityLevel .. " quality)") or " (quality control failed)"
        local itemLabel = exports.ox_inventory:Items() and exports.ox_inventory:Items()[finalOutputItem] and 
            exports.ox_inventory:Items()[finalOutputItem].label or finalOutputItem
        
        TriggerClientEvent('manufacturing:processCompleted', process.playerId, {
            quantity = finalYield,
            itemLabel = itemLabel,
            quality = qualityLevel
        })
        
        TriggerClientEvent('ox_lib:notify', process.playerId, {
            title = '🏭 Manufacturing Complete!',
            description = string.format('Produced **%d %s**%s', 
                finalYield, itemLabel, qualityText),
            type = qualitySuccess and 'success' or 'warning',
            duration = 12000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
    end
    
    -- Update manufacturing skills
    local experienceRewards = Config.ManufacturingSkills and Config.ManufacturingSkills.experienceRewards
    local experienceGained = experienceRewards and experienceRewards[qualityLevel] or 10
    
    if qualitySuccess then
        experienceGained = experienceGained * quantity
    else
        experienceGained = experienceGained * quantity * 0.5 -- Reduced for failed quality
    end
    
    updateManufacturingSkill(citizenid, recipe.category, experienceGained)
    
    -- Update warehouse stock if integration enabled
    local warehouseIntegration = Config.ManufacturingIntegration and Config.ManufacturingIntegration.warehouseIntegration
    if warehouseIntegration and warehouseIntegration.enabled then
        MySQL.Async.execute([[
            INSERT INTO supply_warehouse_stock (ingredient, quantity)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE
                quantity = quantity + VALUES(quantity)
        ]], {finalOutputItem, finalYield})
        
        if warehouseIntegration.deliveryNotification then
            -- Notify warehouse workers
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local player = QBCore.Functions.GetPlayer(playerId)
                if player and player.PlayerData and player.PlayerData.job and 
                   player.PlayerData.job.name == "hurst" then
                    TriggerClientEvent('ox_lib:notify', playerId, {
                        title = '📦 New Stock Delivered',
                        description = string.format('%d %s added to warehouse', 
                            finalYield, exports.ox_inventory:Items() and exports.ox_inventory:Items()[finalOutputItem] and
                            exports.ox_inventory:Items()[finalOutputItem].label or finalOutputItem),
                        type = 'info',
                        duration = 8000,
                        position = Config.UI and Config.UI.notificationPosition or "top",
                        markdown = Config.UI and Config.UI.enableMarkdown or false
                    })
                end
            end
        end
    end
    
    -- Update manufacturing log
    MySQL.Async.execute([[
        UPDATE manufacturing_logs 
        SET status = 'completed', output_quantity = ?, quality_success = ?, end_time = ?
        WHERE citizenid = ? AND recipe_id = ? AND start_time = ?
    ]], {
        finalYield, qualitySuccess and 1 or 0, os.time(),
        citizenid, process.recipeId, process.startTime
    })
    
    -- Trigger achievement tracking
    local achievementConfig = Config.ManufacturingIntegration and Config.ManufacturingIntegration.achievements
    if achievementConfig and achievementConfig.enabled then
        TriggerEvent('achievements:trackManufacturing', process.playerId, {
            recipeId = process.recipeId,
            category = recipe.category,
            quantity = finalYield,
            qualityLevel = qualityLevel,
            qualitySuccess = qualitySuccess
        })
    end
    
    -- Clean up process
    activeManufacturingProcesses[processId] = nil
    
    return true, finalYield, finalOutputItem
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Get available recipes for facility
RegisterNetEvent('manufacturing:getRecipes')
AddEventHandler('manufacturing:getRecipes', function(facilityId)
    local src = source
    
    if not hasManufacturingAccess(src) then
        local Player = QBCore.Functions.GetPlayer(src)
        local currentJob = Player and Player.PlayerData and Player.PlayerData.job and 
                          Player.PlayerData.job.name or "unemployed"
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Hurst Industries employees only. Current job: ' .. currentJob,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local facility = Config.ManufacturingFacilities and Config.ManufacturingFacilities[facilityId]
    if not facility then return end
    
    local availableRecipes = {}
    if Config.ManufacturingRecipes then
        for recipeId, recipe in pairs(Config.ManufacturingRecipes) do
            if canProcessRecipeAtFacility(recipe, facilityId) then
                table.insert(availableRecipes, {
                    id = recipeId,
                    name = recipe.name,
                    category = recipe.category,
                    inputs = recipe.inputs,
                    outputs = recipe.outputs,
                    processingTime = recipe.processingTime,
                    skillRequired = recipe.skillRequired,
                    description = recipe.description
                })
            end
        end
    end
    
    TriggerClientEvent('manufacturing:showRecipes', src, availableRecipes, facilityId)
end)

-- Start manufacturing process
RegisterNetEvent('manufacturing:startProcess')
AddEventHandler('manufacturing:startProcess', function(recipeId, quantity, qualityLevel, facilityId)
    local src = source
    
    -- Validate job access
    if not hasManufacturingAccess(src) then
        local Player = QBCore.Functions.GetPlayer(src)
        local currentJob = Player and Player.PlayerData and Player.PlayerData.job and 
                          Player.PlayerData.job.name or "unemployed"
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Hurst Industries employees only. Current job: ' .. currentJob,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local success, message, data = startManufacturing(src, recipeId, quantity, qualityLevel, facilityId)
    
    if success then
        TriggerClientEvent('manufacturing:processStarted', src, data)
        
        -- Schedule completion
        if data and data.processingTime and data.processId then
            Citizen.SetTimeout(data.processingTime, function()
                completeManufacturing(data.processId)
            end)
        end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Manufacturing Failed',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        
        if data then -- Missing ingredients data
            TriggerClientEvent('manufacturing:showMissingIngredients', src, data)
        end
    end
end)

-- Get player manufacturing stats
RegisterNetEvent('manufacturing:getPlayerStats')
AddEventHandler('manufacturing:getPlayerStats', function()
    local src = source
    
    if not hasManufacturingAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Manufacturing access restricted to Hurst Industries employees',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData and xPlayer.PlayerData.citizenid
    if not citizenid then return end
    
    -- Get skills
    MySQL.Async.fetchAll('SELECT * FROM manufacturing_skills WHERE citizenid = ?', {citizenid}, function(skills)
        -- Get production stats
        MySQL.Async.fetchAll([[
            SELECT 
                COUNT(*) as total_batches,
                SUM(quantity) as total_items,
                SUM(output_quantity) as total_output,
                AVG(quality_success) as success_rate,
                COUNT(DISTINCT recipe_id) as unique_recipes
            FROM manufacturing_logs 
            WHERE citizenid = ? AND status = 'completed'
        ]], {citizenid}, function(stats)
            
            TriggerClientEvent('manufacturing:showPlayerStats', src, {
                skills = skills or {},
                stats = stats and stats[1] or {},
                skillCategories = Config.ManufacturingSkills and Config.ManufacturingSkills.skillCategories or {}
            })
        end)
    end)
end)

-- Get facility status
RegisterNetEvent('manufacturing:getFacilityStatus')
AddEventHandler('manufacturing:getFacilityStatus', function()
    local src = source
    
    if not hasManufacturingAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Manufacturing access restricted to Hurst Industries employees',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    -- Count active processes per facility
    local facilityStats = {}
    for processId, process in pairs(activeManufacturingProcesses) do
        local facilityId = process.facilityId
        if not facilityStats[facilityId] then
            facilityStats[facilityId] = {
                activeProcesses = 0,
                estimatedCompletion = 0
            }
        end
        facilityStats[facilityId].activeProcesses = facilityStats[facilityId].activeProcesses + 1
        facilityStats[facilityId].estimatedCompletion = math.max(facilityStats[facilityId].estimatedCompletion, process.endTime)
    end
    
    TriggerClientEvent('manufacturing:showFacilityStatus', src, facilityStats)
end)

-- ============================================
-- EMERGENCY PRODUCTION SYSTEM
-- ============================================

-- Handle emergency production requests
RegisterNetEvent('manufacturing:emergencyProduction')
AddEventHandler('manufacturing:emergencyProduction', function(recipeId, quantity, facilityId)
    local src = source
    
    local emergencyConfig = Config.ManufacturingIntegration and Config.ManufacturingIntegration.emergencyProduction
    if not emergencyConfig or not emergencyConfig.enabled then return end
    
    if not hasManufacturingAccess(src) then
        return
    end
    
    -- Emergency production gets priority processing
    local success, message, data = startManufacturing(src, recipeId, quantity, "standard", facilityId)
    
    if success then
        -- Apply emergency multipliers
        local emergencyTime = (data and data.processingTime or 60000) / (emergencyConfig and emergencyConfig.priorityMultiplier or 2)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚨 Emergency Production Started',
            description = string.format('Priority processing: %d seconds', math.floor(emergencyTime / 1000)),
            type = 'warning',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        
        -- Schedule emergency completion
        Citizen.SetTimeout(emergencyTime, function()
            local completed, yield, outputItem = completeManufacturing(data and data.processId or "unknown")
            if completed then
                -- Emergency bonus payment
                local bonusPayment = (data and data.processingCost or 0) * (emergencyConfig and emergencyConfig.bonusPayment or 0.5)
                local xPlayer = QBCore.Functions.GetPlayer(src)
                if xPlayer then
                    xPlayer.Functions.AddMoney('cash', bonusPayment, "Emergency production bonus")
                    
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '💰 Emergency Bonus',
                        description = string.format('Received $%d emergency production bonus!', bonusPayment),
                        type = 'success',
                        duration = 8000,
                        position = Config.UI and Config.UI.notificationPosition or "top",
                        markdown = Config.UI and Config.UI.enableMarkdown or false
                    })
                end
            end
        end)
    end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

-- Initialize manufacturing system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[MANUFACTURING] Manufacturing system initialized")
        
        -- Create database tables if they don't exist
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS manufacturing_skills (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                category VARCHAR(50) NOT NULL,
                skill_level DECIMAL(5,2) DEFAULT 0,
                total_experience INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_skill (citizenid, category)
            )
        ]])
        
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS manufacturing_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                recipe_id VARCHAR(100) NOT NULL,
                quantity INT NOT NULL,
                quality_level VARCHAR(20) DEFAULT 'standard',
                facility_id INT NOT NULL,
                processing_cost INT DEFAULT 0,
                processing_time INT DEFAULT 0,
                output_quantity INT DEFAULT 0,
                quality_success BOOLEAN DEFAULT 0,
                start_time INT NOT NULL,
                end_time INT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'processing',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_citizenid (citizenid),
                INDEX idx_recipe (recipe_id),
                INDEX idx_status (status)
            )
        ]])
        
        print("[MANUFACTURING] Database tables initialized")
    end
end)

-- Clean up disconnected players
AddEventHandler('playerDropped', function(reason)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData and xPlayer.PlayerData.citizenid
    if not citizenid then return end
    
    -- Cancel active manufacturing processes for disconnected player
    for processId, process in pairs(activeManufacturingProcesses) do
        if process.citizenid == citizenid then
            -- Refund processing cost
            MySQL.Async.execute([[
                UPDATE manufacturing_logs 
                SET status = 'cancelled' 
                WHERE citizenid = ? AND start_time = ?
            ]], {citizenid, process.startTime})
            
            activeManufacturingProcesses[processId] = nil
        end
    end
end)

-- Export functions for other scripts
exports('hasManufacturingAccess', hasManufacturingAccess)
exports('getManufacturingSkill', getManufacturingSkill)
exports('startEmergencyProduction', function(playerId, recipeId, quantity, facilityId)
    TriggerEvent('manufacturing:emergencyProduction', recipeId, quantity, facilityId)
end)

print("[MANUFACTURING] Server logic initialized")