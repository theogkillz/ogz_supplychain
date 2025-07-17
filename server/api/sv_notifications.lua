-- ============================================
-- NOTIFICATION API - ENTERPRISE EDITION
-- Professional notification system with Discord & mobile integration
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Send Discord webhook with enhanced error handling
local function sendDiscordWebhook(webhookURL, embeds, content)
    if not Config.Notifications or not Config.Notifications.discord or not Config.Notifications.discord.enabled or not webhookURL then
        return false, "Discord notifications disabled or URL missing"
    end
    
    local data = {
        username = Config.Notifications.discord.botName or "Supply Chain AI",
        avatar_url = Config.Notifications.discord.botAvatar,
        content = content or "",
        embeds = embeds
    }
    
    PerformHttpRequest(webhookURL, function(statusCode, response)
        if statusCode ~= 200 and statusCode ~= 204 then
            print("[DISCORD ERROR] Failed to send webhook: " .. statusCode .. " - " .. (response or "No response"))
        else
            print("[DISCORD] Webhook sent successfully")
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
    
    return true, "Webhook sent"
end

-- Send phone notification with multi-resource support
local function sendPhoneNotification(playerId, title, message, app)
    if not Config.Notifications or not Config.Notifications.phone or not Config.Notifications.phone.enabled then
        return false, "Phone notifications disabled"
    end
    
    local phoneResource = Config.Notifications.phone.resource
    
    if phoneResource == "qb-phone" then
        TriggerClientEvent('qb-phone:client:CustomNotification', playerId, title, message, "fas fa-truck", "#FF6B35", 8000)
    elseif phoneResource == "lb-phone" then
        exports["lb-phone"]:SendNotification(playerId, {
            app = app or "Messages",
            title = title,
            content = message,
            time = 8000
        })
    elseif phoneResource == "qs-smartphone" then
        TriggerClientEvent('qs-smartphone:client:notification', playerId, {
            title = title,
            message = message,
            icon = "fas fa-truck",
            timeout = 8000
        })
    elseif phoneResource == "gksphone" then
        TriggerClientEvent('gksphone:NewMail', playerId, {
            sender = "Supply Chain",
            subject = title,
            message = message,
            button = {}
        })
    else
        print("[NOTIFICATIONS WARNING] Unknown phone resource: " .. phoneResource)
        return false, "Unknown phone resource"
    end
    
    return true, "Phone notification sent"
end

-- Enhanced notification with multiple delivery methods
local function sendEnhancedNotification(playerId, notificationData)
    local success = false
    local methods = {}
    
    -- Send in-game notification
    TriggerClientEvent('ox_lib:notify', playerId, {
        title = notificationData.title,
        description = notificationData.description,
        type = notificationData.type or 'info',
        duration = notificationData.duration or 8000,
        position = Config.UI and Config.UI.notificationPosition or 'center-right',
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
    methods.ingame = true
    success = true
    
    -- Send phone notification if enabled
    if notificationData.includePhone then
        local phoneSuccess, phoneMessage = sendPhoneNotification(
            playerId, 
            notificationData.title, 
            notificationData.description:gsub("%*%*(.-)%*%*", "%1"), -- Remove markdown for phone
            notificationData.app
        )
        methods.phone = phoneSuccess
        if phoneSuccess then success = true end
    end
    
    -- Send Discord webhook if enabled and configured
    if notificationData.includeDiscord and notificationData.webhookURL then
        local discordSuccess, discordMessage = sendDiscordWebhook(
            notificationData.webhookURL,
            notificationData.embed and {notificationData.embed} or nil,
            notificationData.discordContent
        )
        methods.discord = discordSuccess
        if discordSuccess then success = true end
    end
    
    return success, methods
end

-- ============================================
-- MARKET EVENT NOTIFICATIONS
-- ============================================

-- Market Event Notifications (ENHANCED)
RegisterNetEvent('notifications:marketEvent')
AddEventHandler('notifications:marketEvent', function(eventType, ingredient, oldPrice, newPrice, percentage)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    local change = ((newPrice - oldPrice) / oldPrice) * 100
    
    -- Create enhanced Discord embed
    local embed = {
        title = "🚨 MARKET ALERT",
        description = string.format("**%s** %s detected!", itemLabel, eventType:upper()),
        color = eventType == "shortage" and 15158332 or 3066993, -- Red for shortage, green for surplus
        fields = {
            {
                name = "📊 Price Change",
                value = string.format("$%d → $%d (%+.1f%%)", oldPrice, newPrice, change),
                inline = true
            },
            {
                name = "📦 Stock Level", 
                value = string.format("%.1f%%", percentage),
                inline = true
            },
            {
                name = "⏰ Event Time",
                value = os.date("%H:%M:%S"),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Market Monitoring"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Send Discord webhook
    local webhookURL = Config.Notifications and Config.Notifications.discord and 
                      Config.Notifications.discord.channels and 
                      Config.Notifications.discord.channels.market_events
    if webhookURL then
        sendDiscordWebhook(webhookURL, {embed})
    end
    
    -- Send targeted notifications to relevant players
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            -- Notify restaurant owners and warehouse workers
            if SupplyValidation.validateJob(playerJob, JOBS.RESTAURANT) or 
               SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE) then
                
                sendEnhancedNotification(playerId, {
                    title = "📊 Market Alert",
                    description = string.format("%s %s! Price: $%d (%+.1f%%)", 
                        itemLabel, eventType, newPrice, change),
                    type = eventType == "shortage" and "warning" or "success",
                    duration = 12000,
                    includePhone = true,
                    app = "SupplyChain"
                })
            end
        end
    end
end)

-- ============================================
-- EMERGENCY ORDER NOTIFICATIONS
-- ============================================

-- Emergency Order Notifications (ENHANCED)
RegisterNetEvent('notifications:emergencyOrder')
AddEventHandler('notifications:emergencyOrder', function(orderData)
    -- Create enhanced Discord embed
    local embed = {
        title = "🚨 EMERGENCY ORDER",
        description = string.format("%s **%s** needed at %s!", 
            orderData.priorityName, orderData.itemLabel, orderData.restaurantName),
        color = 15158332, -- Red
        fields = {
            {
                name = "💰 Emergency Pay",
                value = "$" .. SupplyUtils.formatMoney(orderData.emergencyPay),
                inline = true
            },
            {
                name = "📦 Stock Status",
                value = string.format("Restaurant: %d | Warehouse: %d", 
                    orderData.stockData.restaurantStock, orderData.stockData.warehouseStock),
                inline = true
            },
            {
                name = "⏰ Time Limit",
                value = math.floor(orderData.timeRemaining / 60) .. " minutes",
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Emergency System"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Send Discord webhook
    local webhookURL = Config.Notifications and Config.Notifications.discord and 
                      Config.Notifications.discord.channels and 
                      Config.Notifications.discord.channels.emergency_orders
    if webhookURL then
        sendDiscordWebhook(webhookURL, {embed})
    end
    
    -- Send targeted notifications to drivers
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            if SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE) then
                sendEnhancedNotification(playerId, {
                    title = "🚨 Emergency Order",
                    description = string.format("%s needed! Pay: %s", 
                        orderData.itemLabel, SupplyUtils.formatMoney(orderData.emergencyPay)),
                    type = "error",
                    duration = 15000,
                    includePhone = true,
                    app = "SupplyChain"
                })
            end
        end
    end
end)

-- ============================================
-- ACHIEVEMENT NOTIFICATIONS
-- ============================================

-- Achievement Notifications (ENHANCED)
RegisterNetEvent('notifications:achievement')
AddEventHandler('notifications:achievement', function(playerId, achievementData)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end
    
    local playerName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    
    -- Create enhanced Discord embed
    local embed = {
        title = "🏆 ACHIEVEMENT UNLOCKED",
        description = string.format("**%s** earned: %s %s!", 
            playerName, achievementData.icon, achievementData.name),
        color = 16776960, -- Gold
        fields = {
            {
                name = "📝 Description",
                value = achievementData.description,
                inline = false
            },
            {
                name = "💰 Reward",
                value = "$" .. SupplyUtils.formatMoney(achievementData.reward),
                inline = true
            },
            {
                name = "⏰ Earned At",
                value = os.date("%H:%M:%S"),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Achievement System"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Send Discord webhook
    local webhookURL = Config.Notifications and Config.Notifications.discord and 
                      Config.Notifications.discord.channels and 
                      Config.Notifications.discord.channels.achievements
    if webhookURL then
        sendDiscordWebhook(webhookURL, {embed})
    end
    
    -- Send enhanced notification to player
    sendEnhancedNotification(playerId, {
        title = "🏆 Achievement Unlocked!",
        description = string.format("%s %s earned! Reward: %s", 
            achievementData.icon, achievementData.name, SupplyUtils.formatMoney(achievementData.reward)),
        type = "success",
        duration = 15000,
        includePhone = true,
        app = "SupplyChain"
    })
end)

-- ============================================
-- TEAM DELIVERY NOTIFICATIONS
-- ============================================

-- Team Delivery Notifications (ENHANCED)
RegisterNetEvent('notifications:teamDelivery')
AddEventHandler('notifications:teamDelivery', function(eventType, teamData)
    if eventType == "created" then
        -- Notify available drivers about new team
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local xPlayer = QBCore.Functions.GetPlayer(playerId)
            if xPlayer then
                local playerJob = xPlayer.PlayerData.job.name
                
                if SupplyValidation.validateJob(playerJob, JOBS.WAREHOUSE) then
                    sendEnhancedNotification(playerId, {
                        title = "👥 Team Delivery Available",
                        description = string.format("%s started a %d-box team delivery! Join for bonus pay!", 
                            teamData.leaderName, teamData.totalBoxes),
                        type = "info",
                        duration = 12000,
                        includePhone = true,
                        app = "SupplyChain"
                    })
                end
            end
        end
        
    elseif eventType == "completed" then
        -- Enhanced Discord notification for completed team delivery
        local embed = {
            title = "🚛 TEAM DELIVERY COMPLETED",
            description = string.format("**%d-driver convoy** completed %d-box delivery!", 
                teamData.memberCount, teamData.totalBoxes),
            color = 3066993, -- Green
            fields = {
                {
                    name = "👥 Team Size",
                    value = string.format("%d drivers", teamData.memberCount),
                    inline = true
                },
                {
                    name = "📦 Total Boxes",
                    value = tostring(teamData.totalBoxes),
                    inline = true
                },
                {
                    name = "🎯 Coordination",
                    value = string.format("%.1fs sync", teamData.syncTime or 0),
                    inline = true
                }
            },
            footer = {
                text = "Supply Chain AI • Team System"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        
        -- Send Discord webhook
        local webhookURL = Config.Notifications and Config.Notifications.discord and 
                          Config.Notifications.discord.webhookURL
        if webhookURL then
            sendDiscordWebhook(webhookURL, {embed})
        end
    end
end)

-- ============================================
-- STOCK ALERT NOTIFICATIONS
-- ============================================

-- Stock Alert Notifications (ENHANCED)
RegisterNetEvent('notifications:stockAlert')
AddEventHandler('notifications:stockAlert', function(alertData)
    -- Send targeted notifications to restaurant owners
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            local isBoss = xPlayer.PlayerData.job.isboss
            
            -- Check if this item is relevant to their restaurant
            if isBoss and SupplyValidation.validateJob(playerJob, JOBS.RESTAURANT) then
                for restaurantId, restaurant in pairs(Config.Restaurants or {}) do
                    if restaurant.job == playerJob then
                        local restaurantItems = Config.Items[playerJob] or {}
                        for category, categoryItems in pairs(restaurantItems) do
                            if categoryItems[alertData.ingredient] then
                                local alertIcon = alertData.alertLevel == "critical" and "🚨" or "⚠️"
                                
                                sendEnhancedNotification(playerId, {
                                    title = alertIcon .. " Stock Alert",
                                    description = string.format("%s is %s! Only %.1f%% remaining", 
                                        alertData.itemLabel, alertData.alertLevel, alertData.percentage),
                                    type = alertData.alertLevel == "critical" and "error" or "warning",
                                    duration = 12000,
                                    includePhone = true,
                                    app = "SupplyChain"
                                })
                                break
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================
-- SYSTEM STATUS NOTIFICATIONS
-- ============================================

-- System Status Notifications (for admins)
RegisterNetEvent('notifications:systemStatus')
AddEventHandler('notifications:systemStatus', function(statusData)
    local embed = {
        title = "⚙️ SYSTEM STATUS",
        description = "Supply Chain System Health Report",
        color = statusData.status == "healthy" and 3066993 or 15158332,
        fields = {
            {
                name = "📊 Active Orders",
                value = tostring(statusData.activeOrders or 0),
                inline = true
            },
            {
                name = "🚛 Active Drivers",
                value = tostring(statusData.activeDrivers or 0),
                inline = true
            },
            {
                name = "💰 Market Status",
                value = statusData.marketStatus or "normal",
                inline = true
            },
            {
                name = "🚨 Emergency Orders",
                value = tostring(statusData.emergencyOrders or 0),
                inline = true
            },
            {
                name = "⚠️ Critical Stock Items",
                value = tostring(statusData.criticalStock or 0),
                inline = true
            },
            {
                name = "📈 Avg Price Multiplier",
                value = string.format("%.2fx", statusData.avgMultiplier or 1.0),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • System Monitor"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local webhookURL = Config.Notifications and Config.Notifications.discord and 
                      Config.Notifications.discord.channels and 
                      Config.Notifications.discord.channels.system_alerts
    if webhookURL then
        sendDiscordWebhook(webhookURL, {embed})
    end
end)

-- ============================================
-- NOTIFICATION PREFERENCES
-- ============================================

-- Phone notification preferences
RegisterNetEvent('notifications:updatePreferences')
AddEventHandler('notifications:updatePreferences', function(preferences)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Save preferences to database with enhanced validation
    MySQL.Async.execute([[
        INSERT INTO supply_notification_preferences (
            citizenid, new_orders, emergency_alerts, market_changes, 
            team_invites, achievements, stock_alerts, phone_enabled, discord_enabled
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            new_orders = VALUES(new_orders),
            emergency_alerts = VALUES(emergency_alerts),
            market_changes = VALUES(market_changes),
            team_invites = VALUES(team_invites),
            achievements = VALUES(achievements),
            stock_alerts = VALUES(stock_alerts),
            phone_enabled = VALUES(phone_enabled),
            discord_enabled = VALUES(discord_enabled),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        xPlayer.PlayerData.citizenid,
        preferences.new_orders and 1 or 0,
        preferences.emergency_alerts and 1 or 0,
        preferences.market_changes and 1 or 0,
        preferences.team_invites and 1 or 0,
        preferences.achievements and 1 or 0,
        preferences.stock_alerts and 1 or 0,
        preferences.phone_enabled and 1 or 0,
        preferences.discord_enabled and 1 or 0
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '📱 Notification Preferences Updated',
        description = 'Your notification settings have been saved successfully.',
        type = 'success',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or 'center-right',
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
end)

-- Get notification preferences
RegisterNetEvent('notifications:getPreferences')
AddEventHandler('notifications:getPreferences', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_notification_preferences WHERE citizenid = ?', 
        {xPlayer.PlayerData.citizenid}, function(results)
        
        local preferences = {
            new_orders = true,
            emergency_alerts = true,
            market_changes = true,
            team_invites = true,
            achievements = true,
            stock_alerts = true,
            phone_enabled = true,
            discord_enabled = false
        }
        
        if results and results[1] then
            local saved = results[1]
            preferences = {
                new_orders = saved.new_orders == 1,
                emergency_alerts = saved.emergency_alerts == 1,
                market_changes = saved.market_changes == 1,
                team_invites = saved.team_invites == 1,
                achievements = saved.achievements == 1,
                stock_alerts = saved.stock_alerts == 1,
                phone_enabled = saved.phone_enabled == 1,
                discord_enabled = saved.discord_enabled == 1
            }
        end
        
        TriggerClientEvent('notifications:showPreferences', src, preferences)
    end)
end)

-- ============================================
-- TESTING & ADMIN FUNCTIONS
-- ============================================

-- Send test notification (for setup)
RegisterCommand('testsupplynotif', function(source, args)
    if source == 0 then -- Console only
        local testEmbed = {
            title = "🧪 TEST NOTIFICATION",
            description = "Supply Chain notification system is working!",
            color = 3066993,
            fields = {
                {
                    name = "✅ Status",
                    value = "All systems operational",
                    inline = true
                },
                {
                    name = "⏰ Time",
                    value = os.date("%H:%M:%S"),
                    inline = true
                }
            },
            footer = {
                text = "Supply Chain AI • Test Message"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        
        local webhookURL = Config.Notifications and Config.Notifications.discord and 
                          Config.Notifications.discord.webhookURL
        if webhookURL then
            sendDiscordWebhook(webhookURL, {testEmbed}, "Test notification from Supply Chain AI!")
            print("[NOTIFICATIONS] Test Discord webhook sent!")
        else
            print("[NOTIFICATIONS] No webhook URL configured for testing")
        end
    end
end)

-- Broadcast notification to all players (admin only)
RegisterCommand('broadcastsupply', function(source, args, rawCommand)
    if source ~= 0 and not exports['ogz_supplychain']:hasAdminPermission(source, 'admin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Admin permissions required.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local message = table.concat(args, " ")
    if not message or message == "" then
        local usage = "Usage: broadcastsupply [message]"
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Usage',
                description = usage,
                type = 'info',
                duration = 5000
            })
        end
        return
    end
    
    -- Send to all players
    TriggerClientEvent('ox_lib:notify', -1, {
        title = '📢 Supply Chain Announcement',
        description = message,
        type = 'info',
        duration = 15000,
        position = Config.UI and Config.UI.notificationPosition or 'center-right',
        markdown = Config.UI and Config.UI.enableMarkdown or true
    })
    
    -- Log to console
    print("[BROADCAST] " .. message)
end, false)

-- ============================================
-- EXPORTS (FOR SYSTEM INTEGRATION)
-- ============================================

exports('sendDiscordWebhook', sendDiscordWebhook)
exports('sendPhoneNotification', sendPhoneNotification)
exports('sendEnhancedNotification', sendEnhancedNotification)

-- Legacy exports for compatibility
exports('sendAchievementNotification', function(citizenid, newTier, oldTier)
    local src = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not src then return end
    
    TriggerEvent('notifications:achievement', src, {
        name = newTier .. " Tier",
        description = "Achievement tier advancement",
        icon = "🏆",
        reward = 5000
    })
end)

exports('sendSurplusAlert', function(surplusLevel, ingredientCount)
    TriggerEvent('notifications:systemStatus', {
        status = surplusLevel == "critical" and "warning" or "healthy",
        surplusLevel = surplusLevel,
        affectedItems = ingredientCount
    })
end)

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("^2[NOTIFICATIONS] 🏗️ Enterprise notification system loaded^0")
        
        local discordStatus = Config.Notifications and Config.Notifications.discord and 
                             Config.Notifications.discord.enabled and "ENABLED" or "DISABLED"
        local phoneStatus = Config.Notifications and Config.Notifications.phone and 
                           Config.Notifications.phone.enabled and "ENABLED" or "DISABLED"
        
        print("^2[NOTIFICATIONS] Discord webhooks: " .. discordStatus .. "^0")
        print("^2[NOTIFICATIONS] Phone notifications: " .. phoneStatus .. "^0")
        
        -- Create notification preferences table if it doesn't exist
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS supply_notification_preferences (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                new_orders BOOLEAN DEFAULT 1,
                emergency_alerts BOOLEAN DEFAULT 1,
                market_changes BOOLEAN DEFAULT 1,
                team_invites BOOLEAN DEFAULT 1,
                achievements BOOLEAN DEFAULT 1,
                stock_alerts BOOLEAN DEFAULT 1,
                phone_enabled BOOLEAN DEFAULT 1,
                discord_enabled BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_preferences (citizenid)
            )
        ]])
        
        print("^2[NOTIFICATIONS] 📊 Notification preferences table initialized^0")
    end
end)

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/testsupplynotif', 'Test Discord webhook (Console only)')
TriggerEvent('chat:addSuggestion', '/broadcastsupply', 'Broadcast message to all players (Admin)', {
    { name = 'message', help = 'Message to broadcast' }
})

print("^2[NOTIFICATIONS] 🏆 Enterprise notification API initialized^0")