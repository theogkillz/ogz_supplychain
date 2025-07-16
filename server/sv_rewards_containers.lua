-- ============================================
-- ENHANCED REWARD SYSTEM WITH CONTAINER INTEGRATION
-- Advanced reward calculation with container quality bonuses
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- CONTAINER-ENHANCED REWARD CALCULATION
-- ============================================

-- Enhanced delivery reward calculation with container bonuses
local function calculateContainerDeliveryRewards(playerId, deliveryData)
    if not playerId or not deliveryData then
        print("[ERROR] Invalid parameters passed to calculateContainerDeliveryRewards")
        return 0, {}
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then
        print("[ERROR] Failed to get player object for ID:", playerId)
        return 0, {}
    end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Base reward calculation (from existing system)
    local boxes = deliveryData.boxes or 1
    local basePay = math.max(
        Config.EconomyBalance.minimumDeliveryPay,
        boxes * Config.EconomyBalance.basePayPerBox
    )
    basePay = math.min(basePay, Config.EconomyBalance.maximumDeliveryPay)
    
    local totalBonusFlat = 0
    local bonusBreakdown = {}
    local finalMultiplier = 1.0
    
    -- ============================================
    -- 1. CONTAINER QUALITY BONUSES
    -- ============================================
    
    local containerQualityBonus = 0
    local avgContainerQuality = 100.0
    
    if deliveryData.containerDelivery and deliveryData.containerQuality then
        avgContainerQuality = deliveryData.containerQuality.averageQuality or 100.0
        local qualityMultiplier = calculateQualityMultiplier(avgContainerQuality)
        
        -- Quality bonus calculation
        if avgContainerQuality >= 95 then
            containerQualityBonus = 300
            table.insert(bonusBreakdown, {
                type = "container_quality",
                name = "🌟 Pristine Container Quality",
                icon = "🌟",
                amount = containerQualityBonus,
                description = string.format("+$%d pristine quality bonus (%.1f%%)", containerQualityBonus, avgContainerQuality)
            })
        elseif avgContainerQuality >= 85 then
            containerQualityBonus = 200
            table.insert(bonusBreakdown, {
                type = "container_quality",
                name = "⭐ Excellent Container Quality",
                icon = "⭐",
                amount = containerQualityBonus,
                description = string.format("+$%d excellent quality bonus (%.1f%%)", containerQualityBonus, avgContainerQuality)
            })
        elseif avgContainerQuality >= 70 then
            containerQualityBonus = 100
            table.insert(bonusBreakdown, {
                type = "container_quality",
                name = "✅ Good Container Quality",
                icon = "✅",
                amount = containerQualityBonus,
                description = string.format("+$%d good quality bonus (%.1f%%)", containerQualityBonus, avgContainerQuality)
            })
        end
        
        totalBonusFlat = totalBonusFlat + containerQualityBonus
        
        -- Quality affects base pay multiplier
        finalMultiplier = finalMultiplier * qualityMultiplier
    end
    
    -- ============================================
    -- 2. CONTAINER TYPE OPTIMIZATION BONUS
    -- ============================================
    
    if deliveryData.containerDelivery and deliveryData.containerOptimization then
        local optimization = deliveryData.containerOptimization
        
        if optimization.perfectMatch then
            totalBonusFlat = totalBonusFlat + 150
            table.insert(bonusBreakdown, {
                type = "container_optimization",
                name = "🎯 Perfect Container Match",
                icon = "🎯",
                amount = 150,
                description = "+$150 optimal container selection"
            })
        end
        
        if optimization.temperatureControlMaintained then
            totalBonusFlat = totalBonusFlat + 100
            table.insert(bonusBreakdown, {
                type = "temperature_control",
                name = "❄️ Temperature Control Maintained",
                icon = "❄️",
                amount = 100,
                description = "+$100 perfect temperature control"
            })
        end
        
        if optimization.handlingScore and optimization.handlingScore >= 95 then
            totalBonusFlat = totalBonusFlat + 125
            table.insert(bonusBreakdown, {
                type = "perfect_handling",
                name = "🚗 Perfect Handling",
                icon = "🚗",
                amount = 125,
                description = string.format("+$125 perfect handling (%d/100)", optimization.handlingScore)
            })
        elseif optimization.handlingScore and optimization.handlingScore >= 85 then
            totalBonusFlat = totalBonusFlat + 75
            table.insert(bonusBreakdown, {
                type = "good_handling",
                name = "🚗 Excellent Handling",
                icon = "🚗",
                amount = 75,
                description = string.format("+$75 excellent handling (%d/100)", optimization.handlingScore)
            })
        end
    end
    
    -- ============================================
    -- 3. CONTAINER PRESERVATION BONUS
    -- ============================================
    
    if deliveryData.containerDelivery and deliveryData.preservationData then
        local preservation = deliveryData.preservationData
        
        -- Zero degradation bonus
        if preservation.qualityLoss <= 1.0 then
            totalBonusFlat = totalBonusFlat + 200
            table.insert(bonusBreakdown, {
                type = "preservation_master",
                name = "🛡️ Preservation Master",
                icon = "🛡️",
                amount = 200,
                description = "+$200 minimal quality loss (≤1%)"
            })
        elseif preservation.qualityLoss <= 5.0 then
            totalBonusFlat = totalBonusFlat + 100
            table.insert(bonusBreakdown, {
                type = "preservation_expert",
                name = "🛡️ Preservation Expert",
                icon = "🛡️",
                amount = 100,
                description = string.format("+$100 low quality loss (%.1f%%)", preservation.qualityLoss)
            })
        end
        
        -- No temperature breaches bonus
        if preservation.temperatureBreaches == 0 then
            totalBonusFlat = totalBonusFlat + 150
            table.insert(bonusBreakdown, {
                type = "temperature_expert",
                name = "🌡️ Temperature Expert",
                icon = "🌡️",
                amount = 150,
                description = "+$150 no temperature breaches"
            })
        end
    end
    
    -- ============================================
    -- 4. EXISTING REWARD SYSTEM INTEGRATION
    -- ============================================
    
    -- Speed bonus (from existing system)
    local speedBonus = nil
    for tier, bonus in pairs(Config.DriverRewards.speedBonuses) do
        if deliveryData.deliveryTime <= bonus.maxTime then
            speedBonus = bonus
            break
        end
    end
    
    if speedBonus and speedBonus.multiplier > 1.0 then
        finalMultiplier = finalMultiplier * speedBonus.multiplier
        table.insert(bonusBreakdown, {
            type = "speed",
            name = speedBonus.name,
            icon = speedBonus.icon,
            multiplier = speedBonus.multiplier,
            description = string.format("%.1fx speed bonus", speedBonus.multiplier)
        })
    end
    
    -- Volume bonus (from existing system)
    local volumeBonus = nil
    for tier, bonus in pairs(Config.DriverRewards.volumeBonuses) do
        if boxes >= bonus.minBoxes then
            volumeBonus = bonus
            break
        end
    end
    
    if volumeBonus and volumeBonus.bonus > 0 then
        totalBonusFlat = totalBonusFlat + volumeBonus.bonus
        table.insert(bonusBreakdown, {
            type = "volume",
            name = volumeBonus.name,
            icon = volumeBonus.icon,
            amount = volumeBonus.bonus,
            description = string.format("+$%d volume bonus", volumeBonus.bonus)
        })
    end
    
    -- Streak bonus (from existing system)
    MySQL.Async.fetchAll('SELECT perfect_streak FROM supply_driver_streaks WHERE citizenid = ?', 
        {citizenid}, function(result)
        
        local currentStreak = (result and result[1]) and result[1].perfect_streak or 0
        local isPerfectDelivery = deliveryData.deliveryTime <= Config.DriverRewards.perfectDelivery.maxTime and avgContainerQuality >= 90
        
        if isPerfectDelivery then
            currentStreak = currentStreak + 1
            
            MySQL.Async.execute([[
                INSERT INTO supply_driver_streaks (citizenid, perfect_streak, best_streak, last_delivery)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                    perfect_streak = ?,
                    best_streak = GREATEST(best_streak, ?),
                    last_delivery = ?
            ]], {citizenid, currentStreak, currentStreak, GetGameTimer(), currentStreak, currentStreak, GetGameTimer()})
        else
            currentStreak = 0
            MySQL.Async.execute([[
                UPDATE supply_driver_streaks 
                SET perfect_streak = 0, last_delivery = ?, streak_broken_count = streak_broken_count + 1
                WHERE citizenid = ?
            ]], {GetGameTimer(), citizenid})
        end
        
        -- Streak multiplier
        local streakMultiplier = 1.0
        for tier, bonus in pairs(Config.DriverRewards.streakBonuses) do
            if currentStreak >= bonus.streak then
                streakMultiplier = bonus.multiplier
                if bonus.multiplier > 1.0 then
                    table.insert(bonusBreakdown, {
                        type = "streak",
                        name = bonus.name .. " (" .. currentStreak .. " streak)",
                        icon = bonus.icon,
                        multiplier = bonus.multiplier,
                        description = string.format("%.1fx streak bonus", bonus.multiplier)
                    })
                end
                break
            end
        end
        
        finalMultiplier = finalMultiplier * streakMultiplier
        
        -- ============================================
        -- 5. FINAL CALCULATION AND PAYMENT
        -- ============================================
        
        local multipliedPay = math.floor(basePay * finalMultiplier)
        local finalPayout = multipliedPay + totalBonusFlat
        
        -- Container delivery bonus cap (higher than standard)
        local maxContainerPay = Config.EconomyBalance.maximumDeliveryPay * 1.5 -- 50% higher cap for container deliveries
        finalPayout = math.min(finalPayout, maxContainerPay)
        
        -- Award the money
        xPlayer.Functions.AddMoney('cash', finalPayout, "Container delivery payment with bonuses")
        
        -- Enhanced notification for container deliveries
        showContainerRewardNotification(playerId, {
            basePay = basePay,
            finalPayout = finalPayout,
            bonusBreakdown = bonusBreakdown,
            finalMultiplier = finalMultiplier,
            currentStreak = currentStreak,
            isPerfectDelivery = isPerfectDelivery,
            boxes = boxes,
            avgContainerQuality = avgContainerQuality,
            containerDelivery = true
        })
        
        -- Enhanced logging for container deliveries
        MySQL.Async.execute([[
            INSERT INTO supply_delivery_logs (
                citizenid, order_group_id, restaurant_id, boxes_delivered, 
                delivery_time, base_pay, bonus_pay, total_pay, 
                is_perfect_delivery, speed_multiplier, streak_multiplier, 
                container_delivery, container_quality_avg, container_bonus_amount
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            citizenid,
            deliveryData.orderGroupId or "unknown",
            deliveryData.restaurantId or 1,
            boxes,
            deliveryData.deliveryTime,
            basePay,
            totalBonusFlat,
            finalPayout,
            isPerfectDelivery and 1 or 0,
            speedBonus and speedBonus.multiplier or 1.0,
            streakMultiplier,
            1, -- container_delivery flag
            avgContainerQuality,
            containerQualityBonus
        })
    end)
end

-- Calculate quality multiplier based on container quality
local function calculateQualityMultiplier(quality)
    if quality >= 95 then
        return 1.20 -- 20% bonus for pristine quality
    elseif quality >= 85 then
        return 1.15 -- 15% bonus for excellent quality
    elseif quality >= 70 then
        return 1.10 -- 10% bonus for good quality
    elseif quality >= 50 then
        return 1.00 -- No bonus for fair quality
    elseif quality >= 30 then
        return 0.90 -- 10% penalty for poor quality
    else
        return 0.70 -- 30% penalty for spoiled quality
    end
end

-- Enhanced reward notification for container deliveries
local function showContainerRewardNotification(playerId, rewardData)
    local bonusText = ""
    local totalBonusAmount = 0
    local containerBonusText = ""
    
    if #rewardData.bonusBreakdown > 0 then
        bonusText = "\n\n🎉 **BONUSES EARNED:**\n"
        local containerBonuses = {}
        local standardBonuses = {}
        
        for _, bonus in ipairs(rewardData.bonusBreakdown) do
            if bonus.amount then
                totalBonusAmount = totalBonusAmount + bonus.amount
                
                -- Separate container-specific bonuses
                if bonus.type:match("container") or bonus.type:match("temperature") or bonus.type:match("preservation") or bonus.type:match("handling") then
                    table.insert(containerBonuses, bonus.icon .. " " .. bonus.description)
                else
                    table.insert(standardBonuses, bonus.icon .. " " .. bonus.description)
                end
            elseif bonus.multiplier then
                if bonus.type:match("container") then
                    table.insert(containerBonuses, bonus.icon .. " " .. bonus.description)
                else
                    table.insert(standardBonuses, bonus.icon .. " " .. bonus.description)
                end
            end
        end
        
        -- Build bonus text
        if #containerBonuses > 0 then
            containerBonusText = "\n📦 **Container Bonuses:**\n" .. table.concat(containerBonuses, "\n")
        end
        
        if #standardBonuses > 0 then
            bonusText = bonusText .. table.concat(standardBonuses, "\n")
        end
    end
    
    local streakText = ""
    if rewardData.currentStreak > 0 then
        streakText = "\n🔥 **PERFECT STREAK: " .. rewardData.currentStreak .. "**"
    end
    
    local qualityText = ""
    if rewardData.containerDelivery then
        local qualityIcon = rewardData.avgContainerQuality >= 90 and "🌟" or 
                           rewardData.avgContainerQuality >= 70 and "⭐" or "✅"
        qualityText = string.format("\n%s **Container Quality: %.1f%%**", qualityIcon, rewardData.avgContainerQuality)
    end
    
    local multiplierText = ""
    if rewardData.finalMultiplier > 1.0 then
        multiplierText = "\n⚡ **TOTAL MULTIPLIER: " .. string.format("%.2f", rewardData.finalMultiplier) .. "x**"
    end
    
    TriggerClientEvent('ox_lib:notify', playerId, {
        title = '📦 CONTAINER DELIVERY COMPLETED!',
        description = string.format(
            "📦 **%d containers delivered**\n💵 Base Pay: $%d\n💎 Bonus: +$%d\n💰 **TOTAL: $%d**%s%s%s%s%s",
            rewardData.boxes,
            rewardData.basePay,
            totalBonusAmount,
            rewardData.finalPayout,
            qualityText,
            containerBonusText,
            bonusText,
            multiplierText,
            streakText
        ),
        type = 'success',
        duration = 20000, -- Longer duration for container deliveries
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Special notification for quality milestones
    if rewardData.avgContainerQuality >= 95 then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '🌟 QUALITY MASTER!',
            description = string.format("🎯 **PRISTINE CONTAINER QUALITY!**\n⚡ %.1f%% average quality maintained!\n🏆 You're setting the standard for excellence!", rewardData.avgContainerQuality),
            type = 'success',
            duration = 12000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Achievement-style notifications for major container milestones
    if rewardData.currentStreak > 0 and rewardData.currentStreak % 10 == 0 then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '📦 CONTAINER STREAK MILESTONE!',
            description = string.format("🔥 **%d PERFECT CONTAINER DELIVERIES!**\n🎯 Quality + Speed mastery achieved!\n⚡ Multiplier boost: %.1fx!", rewardData.currentStreak, rewardData.finalMultiplier),
            type = 'success',
            duration = 15000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Enhanced reward calculation event for container deliveries
RegisterNetEvent('rewards:calculateDeliveryRewardWithContainers')
AddEventHandler('rewards:calculateDeliveryRewardWithContainers', function(playerId, deliveryData)
    calculateContainerDeliveryRewards(playerId, deliveryData)
end)

-- Container quality tracking for rewards
RegisterNetEvent('rewards:trackContainerQuality')
AddEventHandler('rewards:trackContainerQuality', function(playerId, qualityData)
    local src = playerId or source
    
    -- Store quality data for reward calculation
    -- This would be called from the vehicle system when containers are delivered
    
    MySQL.Async.execute([[
        INSERT INTO supply_container_quality_tracking (
            citizenid, order_group_id, avg_quality, quality_loss, 
            temperature_breaches, handling_score, tracking_date
        ) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        qualityData.citizenid,
        qualityData.orderGroupId,
        qualityData.averageQuality,
        qualityData.qualityLoss,
        qualityData.temperatureBreaches,
        qualityData.handlingScore
    })
end)

-- ============================================
-- CONTAINER ACHIEVEMENT SYSTEM
-- ============================================

local containerAchievements = {
    {
        id = "quality_perfectionist",
        name = "Quality Perfectionist",
        description = "Maintain 100% container quality for 5 consecutive deliveries",
        icon = "🌟",
        reward = 2500,
        condition = function(stats, delivery) 
            return delivery.containerQuality and delivery.containerQuality.averageQuality >= 100 and 
                   delivery.perfectQualityStreak >= 5 
        end
    },
    {
        id = "temperature_master",
        name = "Temperature Master", 
        description = "Complete 25 refrigerated deliveries with zero temperature breaches",
        icon = "❄️",
        reward = 5000,
        condition = function(stats, delivery)
            return delivery.refrigeratedDeliveryCount >= 25 and 
                   delivery.totalTemperatureBreaches == 0
        end
    },
    {
        id = "preservation_expert",
        name = "Preservation Expert",
        description = "Deliver 100 containers with less than 2% quality loss each",
        icon = "🛡️",
        reward = 7500,
        condition = function(stats, delivery)
            return stats.preservationExpertCount >= 100
        end
    },
    {
        id = "container_efficiency",
        name = "Container Efficiency Master",
        description = "Complete 50 deliveries with perfect container type matching",
        icon = "🎯",
        reward = 10000,
        condition = function(stats, delivery)
            return stats.perfectContainerMatches >= 50
        end
    }
}

-- Check container achievements
local function checkContainerAchievements(citizenid, deliveryData)
    if not deliveryData.containerDelivery then return end
    
    -- Get container-specific stats
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_container_deliveries,
            AVG(avg_quality) as overall_avg_quality,
            SUM(CASE WHEN quality_loss <= 2.0 THEN 1 ELSE 0 END) as preservation_expert_count,
            SUM(temperature_breaches) as total_temp_breaches,
            COUNT(*) FILTER (WHERE avg_quality >= 100) as perfect_quality_count
        FROM supply_container_quality_tracking 
        WHERE citizenid = ?
    ]], {citizenid}, function(result)
        
        if not result or not result[1] then return end
        
        local stats = result[1]
        
        for _, achievement in ipairs(containerAchievements) do
            -- Check if player already has this achievement
            MySQL.Async.fetchAll('SELECT * FROM supply_achievements WHERE citizenid = ? AND achievement_id = ?', 
                {citizenid, achievement.id}, function(existing)
                
                if not existing or #existing == 0 then
                    if achievement.condition(stats, deliveryData) then
                        -- Award achievement
                        MySQL.Async.execute([[
                            INSERT INTO supply_achievements (citizenid, achievement_id, earned_date)
                            VALUES (?, ?, ?)
                        ]], {citizenid, achievement.id, GetGameTimer()})
                        
                        -- Give reward
                        local xPlayer = QBCore.Functions.GetPlayer(QBCore.Functions.GetPlayerByCitizenId(citizenid))
                        if xPlayer then
                            xPlayer.Functions.AddMoney('bank', achievement.reward, "Container Achievement: " .. achievement.name)
                            
                            TriggerClientEvent('ox_lib:notify', xPlayer.PlayerData.source, {
                                title = '🏆 CONTAINER ACHIEVEMENT!',
                                description = achievement.icon .. ' **' .. achievement.name .. '**\n' .. achievement.description .. '\n💰 Reward: $' .. achievement.reward,
                                type = 'success',
                                duration = 20000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                        end
                    end
                end
            end)
        end
    end)
end

-- Export enhanced functions
exports('calculateContainerDeliveryRewards', calculateContainerDeliveryRewards)
exports('checkContainerAchievements', checkContainerAchievements)

print("[REWARDS] Container reward integration loaded successfully!")