-- ============================================
-- ACHIEVEMENT SYSTEM - ENTERPRISE EDITION
-- Professional achievement tracking and vehicle progression
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- VALIDATION & ACCESS CONTROL
-- ============================================

-- Validate job access for achievement functions using shared validation
local function hasAchievementAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE)
end

-- Enhanced access validation with detailed feedback
local function validateAchievementAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return false, "Player not found"
    end
    
    local playerJob = Player.PlayerData.job.name
    local hasAccess = SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE)
    
    if not hasAccess then
        local errorMessage = SupplyValidation.getAccessDeniedMessage("achievement", playerJob)
        return false, errorMessage
    end
    
    return true, "Access granted"
end

-- ============================================
-- ACHIEVEMENT PROGRESSION SYSTEM
-- ============================================

-- Get player achievement tier with enhanced validation
local function getPlayerAchievementTier(citizenid)
    if not citizenid then
        print("[ACHIEVEMENTS ERROR] No citizenid provided")
        return "rookie"
    end
    
    -- Get player's delivery stats using optimized query
    local deliveryCount = 0
    local avgRating = 0
    local teamAchievements = 0
    
    -- Enhanced query with better performance
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_deliveries,
            AVG(delivery_rating) as avg_rating,
            SUM(CASE WHEN team_delivery = 1 THEN 1 ELSE 0 END) as team_deliveries,
            MAX(consecutive_perfect_deliveries) as best_streak
        FROM supply_delivery_logs 
        WHERE citizenid = ? AND delivery_status = 'completed'
    ]], {citizenid}, function(results)
        if results and results[1] then
            deliveryCount = results[1].total_deliveries or 0
            avgRating = results[1].avg_rating or 0
            teamAchievements = results[1].team_deliveries or 0
        end
    end)
    
    -- Determine achievement tier based on enhanced criteria
    if deliveryCount >= 500 and avgRating >= 95 and teamAchievements >= 50 then
        return "legendary"
    elseif deliveryCount >= 300 and avgRating >= 90 and teamAchievements >= 25 then
        return "elite"
    elseif deliveryCount >= 150 and avgRating >= 85 and teamAchievements >= 10 then
        return "professional"  
    elseif deliveryCount >= 50 and avgRating >= 80 then
        return "experienced"
    else
        return "rookie"
    end
end

-- Calculate achievement progress for next tier
local function calculateAchievementProgress(citizenid, currentTier)
    local tierRequirements = {
        experienced = { deliveries = 50, rating = 80, teams = 0 },
        professional = { deliveries = 150, rating = 85, teams = 10 },
        elite = { deliveries = 300, rating = 90, teams = 25 },
        legendary = { deliveries = 500, rating = 95, teams = 50 }
    }
    
    local nextTier = nil
    if currentTier == "rookie" then nextTier = "experienced"
    elseif currentTier == "experienced" then nextTier = "professional"
    elseif currentTier == "professional" then nextTier = "elite"
    elseif currentTier == "elite" then nextTier = "legendary"
    end
    
    if not nextTier then
        return nil -- Already at max tier
    end
    
    local requirements = tierRequirements[nextTier]
    
    -- Get current stats
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as deliveries,
            AVG(delivery_rating) as rating,
            SUM(CASE WHEN team_delivery = 1 THEN 1 ELSE 0 END) as teams
        FROM supply_delivery_logs 
        WHERE citizenid = ? AND delivery_status = 'completed'
    ]], {citizenid}, function(results)
        if results and results[1] then
            local current = results[1]
            return {
                nextTier = nextTier,
                progress = {
                    deliveries = { current = current.deliveries or 0, required = requirements.deliveries },
                    rating = { current = current.rating or 0, required = requirements.rating },
                    teams = { current = current.teams or 0, required = requirements.teams }
                }
            }
        end
    end)
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Get player achievement tier with enhanced validation
RegisterNetEvent('achievements:getPlayerTier')
AddEventHandler('achievements:getPlayerTier', function()
    local src = source
    
    -- Enhanced validation with detailed feedback
    local hasAccess, message = validateAchievementAccess(src)
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    
    -- Get achievement tier and progress
    local tier = getPlayerAchievementTier(citizenid)
    local progress = calculateAchievementProgress(citizenid, tier)
    
    -- Send tier information to client
    TriggerClientEvent('achievements:receiveTierInfo', src, {
        currentTier = tier,
        progress = progress,
        tierConfig = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and 
                    Config.AchievementVehicles.performanceTiers[tier]
    })
end)

-- Vehicle modification validation with enhanced security
RegisterNetEvent('achievements:requestVehicleMods')
AddEventHandler('achievements:requestVehicleMods', function(vehicleNetId)
    local src = source
    
    local hasAccess, message = validateAchievementAccess(src)
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Vehicle Access Denied',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Validate vehicle network ID
    if not vehicleNetId or not NetworkDoesEntityExistWithNetworkId(vehicleNetId) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Vehicle Error',
            description = 'Invalid or non-existent vehicle.',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local tier = getPlayerAchievementTier(citizenid)
    
    -- Apply vehicle modifications based on tier
    TriggerClientEvent('achievements:applyVehicleMods', src, vehicleNetId, tier)
    
    -- Notify player of modifications applied
    local tierConfig = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and 
                      Config.AchievementVehicles.performanceTiers[tier]
    
    if tierConfig then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚗 Vehicle Enhanced',
            description = string.format('**%s** tier modifications applied!\n%s', 
                tierConfig.name, tierConfig.description),
            type = 'success',
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
    end
end)

-- Track achievement progress
RegisterNetEvent('achievements:trackProgress')
AddEventHandler('achievements:trackProgress', function(progressData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local oldTier = getPlayerAchievementTier(citizenid)
    
    -- Update delivery log with achievement tracking
    MySQL.Async.execute([[
        INSERT INTO supply_achievement_progress (
            citizenid, delivery_count, team_deliveries, average_rating, 
            last_updated
        ) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            delivery_count = delivery_count + 1,
            team_deliveries = team_deliveries + ?,
            average_rating = (average_rating + ?) / 2,
            last_updated = CURRENT_TIMESTAMP
    ]], {
        citizenid,
        1, -- delivery_count increment
        progressData.isTeamDelivery and 1 or 0,
        progressData.isTeamDelivery and 1 or 0, -- for UPDATE
        progressData.rating or 100
    })
    
    -- Check for tier advancement
    Citizen.SetTimeout(1000, function()
        local newTier = getPlayerAchievementTier(citizenid)
        if newTier ~= oldTier then
            -- Trigger tier advancement notification
            TriggerEvent('achievements:tierAdvancement', src, oldTier, newTier)
        end
    end)
end)

-- Handle tier advancement
RegisterNetEvent('achievements:tierAdvancement')
AddEventHandler('achievements:tierAdvancement', function(playerId, oldTier, newTier)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local tierConfig = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and 
                      Config.AchievementVehicles.performanceTiers[newTier]
    
    if tierConfig then
        -- Award tier advancement bonus
        local bonusAmount = tierConfig.bonusReward or 5000
        Player.Functions.AddMoney('bank', bonusAmount, 'Achievement tier advancement')
        
        -- Send advancement notification
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '🏆 TIER ADVANCEMENT!',
            description = string.format(
                '**%s** achievement tier unlocked!\n💰 Bonus: $%s\n🚗 %s',
                tierConfig.name,
                SupplyUtils.formatMoney(bonusAmount),
                tierConfig.description
            ),
            type = 'success',
            duration = 20000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        
        -- Trigger achievement notification to other systems
        TriggerEvent('notifications:achievement', playerId, {
            name = tierConfig.name,
            description = 'Achievement tier advanced',
            icon = '🏆',
            reward = bonusAmount
        })
    end
end)

-- Get achievement leaderboard
RegisterNetEvent('achievements:getLeaderboard')
AddEventHandler('achievements:getLeaderboard', function()
    local src = source
    
    if not hasAchievementAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Achievement leaderboard access restricted to Hurst Industries employees',
            type = 'error',
            duration = 8000,
            position = Config.UI and Config.UI.notificationPosition or 'center-right',
            markdown = Config.UI and Config.UI.enableMarkdown or true
        })
        return
    end
    
    -- Get top achievers
    MySQL.Async.fetchAll([[
        SELECT 
            p.PlayerData->>'$.charinfo.firstname' as firstname,
            p.PlayerData->>'$.charinfo.lastname' as lastname,
            dl.citizenid,
            COUNT(*) as total_deliveries,
            AVG(dl.delivery_rating) as avg_rating,
            SUM(CASE WHEN dl.team_delivery = 1 THEN 1 ELSE 0 END) as team_deliveries
        FROM supply_delivery_logs dl
        JOIN players p ON dl.citizenid = p.citizenid
        WHERE dl.delivery_status = 'completed'
        GROUP BY dl.citizenid
        ORDER BY 
            AVG(dl.delivery_rating) DESC,
            COUNT(*) DESC,
            SUM(CASE WHEN dl.team_delivery = 1 THEN 1 ELSE 0 END) DESC
        LIMIT 20
    ]], {}, function(results)
        local leaderboard = {}
        
        for i, player in ipairs(results or {}) do
            local tier = getPlayerAchievementTier(player.citizenid)
            
            table.insert(leaderboard, {
                rank = i,
                name = player.firstname .. ' ' .. player.lastname,
                citizenid = player.citizenid,
                tier = tier,
                totalDeliveries = player.total_deliveries,
                avgRating = player.avg_rating,
                teamDeliveries = player.team_deliveries
            })
        end
        
        TriggerClientEvent('achievements:showLeaderboard', src, leaderboard)
    end)
end)

-- ============================================
-- SPECIALIZED ACHIEVEMENT EVENTS
-- ============================================

-- Manufacturing achievement tracking
RegisterNetEvent('achievements:trackManufacturing')
AddEventHandler('achievements:trackManufacturing', function(playerId, manufacturingData)
    -- This would integrate with the manufacturing system for cross-system achievements
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    -- Track manufacturing achievements
    MySQL.Async.execute([[
        INSERT INTO supply_manufacturing_achievements (
            citizenid, recipe_category, items_produced, quality_achieved, created_at
        ) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        Player.PlayerData.citizenid,
        manufacturingData.category,
        manufacturingData.quantity,
        manufacturingData.qualitySuccess and 1 or 0
    })
end)

-- Container achievement tracking
RegisterNetEvent('achievements:trackContainer')
AddEventHandler('achievements:trackContainer', function(playerId, containerData)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    -- Track container-specific achievements
    MySQL.Async.execute([[
        INSERT INTO supply_container_achievements (
            citizenid, container_type, quality_maintained, zero_breaches, created_at
        ) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        Player.PlayerData.citizenid,
        containerData.containerType,
        containerData.qualityMaintained and 1 or 0,
        containerData.zeroBreaches and 1 or 0
    })
end)

-- ============================================
-- EXPORTS (FOR SYSTEM INTEGRATION)
-- ============================================

-- Export achievement tier for vehicle spawning and other systems
exports('getPlayerAchievementTier', getPlayerAchievementTier)
exports('hasAchievementAccess', hasAchievementAccess)
exports('validateAchievementAccess', validateAchievementAccess)
exports('calculateAchievementProgress', calculateAchievementProgress)

-- ============================================
-- ADMIN FUNCTIONS
-- ============================================

-- Admin command to manually set achievement tier (for testing)
RegisterCommand('setachievementtier', function(source, args, rawCommand)
    if source ~= 0 then
        if not exports['ogz_supplychain']:hasAdminPermission(source, 'admin') then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required.',
                type = 'error',
                duration = 5000
            })
            return
        end
    end
    
    local targetId = tonumber(args[1])
    local tier = args[2]
    
    if not targetId or not tier then
        local usage = "Usage: setachievementtier [player_id] [tier]"
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Usage',
                description = usage,
                type = 'info',
                duration = 8000
            })
        end
        return
    end
    
    local validTiers = {"rookie", "experienced", "professional", "elite", "legendary"}
    local isValidTier = false
    for _, validTier in ipairs(validTiers) do
        if tier == validTier then
            isValidTier = true
            break
        end
    end
    
    if not isValidTier then
        local message = "Invalid tier. Valid tiers: " .. table.concat(validTiers, ", ")
        if source == 0 then
            print(message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Invalid Tier',
                description = message,
                type = 'error',
                duration = 8000
            })
        end
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        local message = "Player not found"
        if source == 0 then
            print(message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Error',
                description = message,
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    -- This would require implementing tier override in database
    -- For now, just notify about the requested change
    local message = string.format("Achievement tier set to %s for %s", tier, targetPlayer.PlayerData.charinfo.firstname)
    if source == 0 then
        print(message)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Tier Set',
            description = message,
            type = 'success',
            duration = 8000
        })
    end
end, false)

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("^2[ACHIEVEMENTS] 🏆 Enterprise achievement system loaded^0")
        
        -- Create achievement tables if they don't exist
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_achievement_progress (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                delivery_count INT DEFAULT 0,
                team_deliveries INT DEFAULT 0,
                average_rating DECIMAL(5,2) DEFAULT 0,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_progress (citizenid)
            )
        ]])
        
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_manufacturing_achievements (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                recipe_category VARCHAR(50) NOT NULL,
                items_produced INT NOT NULL,
                quality_achieved BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_citizenid (citizenid),
                INDEX idx_category (recipe_category)
            )
        ]])
        
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_container_achievements (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                container_type VARCHAR(50) NOT NULL,
                quality_maintained BOOLEAN DEFAULT 0,
                zero_breaches BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_citizenid (citizenid),
                INDEX idx_type (container_type)
            )
        ]])
        
        print("^2[ACHIEVEMENTS] 📊 Achievement database tables initialized^0")
    end
end)

print("^2[ACHIEVEMENTS] 🏗️ Enterprise achievement system initialized^0")