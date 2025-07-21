fx_version 'cerulean'
game 'gta5'

author 'The OG KiLLz'
description 'OGz SupplyChain Master - Enterprise Supply Chain Management System'
version '1.0.0'

lua54 'yes'

-- Shared Scripts (Load Order Important)
shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    
    -- Core Systems (Must load first)
    'shared/core/sh_framework_bridge.lua',
    'shared/core/sh_globals.lua',
    'shared/core/sh_constants.lua',
    
    -- Configuration Files
    'shared/config/config_main.lua',
    'shared/config/config_locations.lua',
    'shared/config/config_items.lua',
    'shared/config/config_economics.lua',
    'shared/config/config_rewards.lua',
    'shared/config/config_containers.lua',
    'shared/config/config_warehouse.lua',
    'shared/config/config_manufacturing.lua',
    'shared/config/config_docks.lua',
    
    -- Utilities
    'shared/utils/sh_validation.lua',
    'shared/utils/sh_calculations.lua',
    'shared/utils/sh_utils.lua'
}

-- Client Scripts
client_scripts {
    -- Core Systems
    'client/core/cl_main.lua',
    'client/core/cl_framework.lua',
    'client/core/cl_events.lua',
    
    -- Restaurant System
    'client/systems/restaurants/cl_restaurant_core.lua',
    'client/systems/restaurants/cl_restaurant_menu.lua',
    'client/systems/restaurants/cl_restaurant_zones.lua',
    
    -- Warehouse System
    'client/systems/warehouse/cl_warehouse_core.lua',
    'client/systems/warehouse/cl_warehouse_delivery.lua',
    'client/systems/warehouse/cl_warehouse_zones.lua',
    'client/systems/warehouse/cl_warehouse_unloading.lua',
    'client/systems/warehouse/cl_container_system.lua',
    'client/systems/warehouse/cl_emergency_orders.lua',
    
    -- Seller System
    'client/systems/seller/cl_seller_core.lua',

    -- Economic System
    'client/systems/economics/cl_market_display.lua',
    
    -- Container System (Future)
    -- 'client/systems/containers/cl_container_core.lua',
    -- 'client/systems/containers/cl_container_quality.lua',
    
    -- Manufacturing System (Future)
    -- 'client/systems/manufacturing/cl_manufacturing_core.lua',
    
    -- Docks System (Future)
    -- 'client/systems/docks/cl_docks_core.lua',
    
    -- Team System
    'client/systems/team/cl_team_core.lua',
    
    -- UI Systems
    'client/ui/cl_notifications.lua',
    'client/ui/cl_menus.lua',
    
    -- Analytics
    'client/systems/analytics/cl_achievements.lua',
    
    -- Utilities
    'client/utils/cl_utils.lua'
}

-- Server Scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    -- Core Systems
    'server/core/sv_main.lua',
    'server/core/sv_database.lua',
    'server/core/sv_framework.lua',
    'server/core/sv_events.lua',
    
    -- Restaurant System
    'server/systems/restaurants/sv_restaurant_core.lua',
    'server/systems/restaurants/sv_restaurant_orders.lua',
    'server/systems/restaurants/sv_restaurant_stock.lua',
    
    -- Warehouse System
    'server/systems/warehouse/sv_warehouse_core.lua',
    'server/systems/warehouse/sv_warehouse_delivery.lua',
    'server/systems/warehouse/sv_warehouse_stock.lua',
    'server/systems/warehouse/sv_container_system.lua',
    'server/systems/warehouse/sv_emergency_orders.lua',
    
    -- Economic System
    'server/systems/economics/sv_market_dynamics.lua',
    'server/systems/economics/sv_economy_tracker.lua',
    
    -- Container System (Future)
    -- 'server/systems/containers/sv_container_core.lua',
    -- 'server/systems/containers/sv_container_quality.lua',
    
    -- Manufacturing System (Future)
    -- 'server/systems/manufacturing/sv_manufacturing_core.lua',
    
    -- Docks System (Future)
    -- 'server/systems/docks/sv_docks_core.lua',
    
    -- Team System
    'server/systems/team/sv_team_core.lua',
    'server/systems/team/sv_team_rewards.lua',
    
    -- Seller/Farming System
    'server/systems/seller/sv_seller_core.lua',
    
    -- Analytics System
    'server/systems/analytics/sv_leaderboard.lua',
    'server/systems/analytics/sv_statistics.lua',
    'server/systems/analytics/sv_stock_alerts.lua',
    
    -- Emergency Orders (Future)
    -- 'server/systems/emergency/sv_emergency_orders.lua',
    
    -- Admin System
    'server/admin/sv_admin_core.lua',
    'server/admin/sv_admin_commands.lua',
    
    -- API
    'server/api/sv_exports.lua',
    'server/api/sv_callbacks.lua'
}

-- UI Files (if using custom UI)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg'
}

-- Dependencies
dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
    '/onesync'  -- Required for some features
}

-- Optional Dependencies (for enhanced features)
optional_dependencies {
    'lation_ui',     -- Enhanced UI
    'okokBilling',   -- Billing system
    'qb-menu',       -- Alternative menu
    'qb-input'       -- Alternative input
}

-- Exports
client_exports {
    -- Client Framework
    'GetFramework',
    'GetConstants',
    
    -- Client Restaurant
    'GetRestaurantFunctions',
    'GetCurrentIngredients',
    'GetOrderItemCount',
    
    -- Client Warehouse
    'GetWarehouseFunctions',
    'IsInDelivery',
    'GetDeliveryVan',
    'GetCurrentTeam',
    'GetCurrentOrder',
    'GetBoxCount',
    'GetCurrentRestaurantId',
    'IsUnloading',
    'GetUnloadedBoxes',
    
    -- Client Container
    'GetActiveContainer',
    'HasActiveContainer',
    
    -- Client Emergency
    'GetActiveEmergencies',
    'IsInEmergencyDelivery',
    'OpenEmergencyOrdersMenu',
    
    -- Client Market
    'GetCurrentMarketData',
    'IsMarketEventActive',
    'ShowMarketReport',
    
    -- Client Achievements
    'GetPlayerAchievements',
    'ShowAchievements',
    'GetRecentUnlocks'
}

-- Server Exports
server_exports {
    -- Core
    'GetFramework',
    'GetStateManager',
    
    -- Warehouse
    'GetWarehouseStock',
    'UpdateMarketPrices',
    'CheckEmergencyOrders',
    'GetActiveDeliveries',
    'GetDeliveryTeams',
    
    -- Restaurant
    'CreateRestaurantOrder',
    
    -- Team
    'GetTeamData',
    'IsInTeam',
    'GetPlayerTeam',
    
    -- Container
    'GetActiveContainer',
    'GetPlayerRental',
    'GetContainerQuality',
    
    -- Market
    'GetMarketPrices',
    'GetItemPrice',
    'GetPriceTrend',
    'TriggerMarketEvent',
    
    -- Emergency
    'GetEmergencyOrders',
    'CreateEmergencyOrder',
    'CheckEmergencyConditions',
    
    -- Achievements
    'GetPlayerAchievements',
    'UnlockAchievement',
    'CheckAchievementProgress'
}

-- Data files for items (if needed)
data_file 'ITEM_DATA_FILE' 'data/items.json'

-- Convars for server configuration
convar_defaults {
    ['supply_chain_debug'] = 'false',
    ['supply_chain_max_teams'] = '10',
    ['supply_chain_cache_time'] = '30000',
    ['supply_chain_economy_update'] = '300'
}