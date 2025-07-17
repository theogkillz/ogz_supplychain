Config = Config or {}

-- ===================================
-- NOTIFICATION CONFIGURATION
-- ===================================
Config.Notifications = {
    discord = {
        enabled = false,
        webhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE",
        botName = "Supply Chain AI",
        botAvatar = "https://i.imgur.com/your_bot_avatar.png",
        
        channels = {
            market_events = "YOUR_MARKET_WEBHOOK_URL",
            emergency_orders = "YOUR_EMERGENCY_WEBHOOK_URL", 
            achievements = "YOUR_ACHIEVEMENTS_WEBHOOK_URL",
            system_alerts = "YOUR_SYSTEM_WEBHOOK_URL"
        }
    },
    
    phone = {
        enabled = true,
        resource = "lb-phone",
        
        types = {
            new_orders = true,
            emergency_alerts = true,
            market_changes = true,
            team_invites = true,
            achievement_unlocked = true,
            stock_alerts = true
        }
    }
}