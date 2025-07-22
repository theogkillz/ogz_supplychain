fx_version 'cerulean'
game 'gta5'

author 'The OG KiLLz'
description 'OGz SupplyChain Master - Enterprise Supply Chain Management System'
version '2.0.0'

lua54 'yes'

-- Shared Scripts (Load Order Important)
shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    
    -- Core Systems (Must load first)
    'shared/core/sh_framework.lua',
    'shared/core/sh_state.lua',
    'shared/core/sh_constants.lua',
    
    -- Configuration Files
    'shared/config/config_main.lua',
    'shared/config/config_locations.lua',
    'shared/config/config_items.lua',
    'shared/config/config_economics.lua',
    'shared/config/config_rewards.lua',
    'shared/config/config_containers.lua'
}

-- Client Scripts
client_scripts {
    -- Core Systems
    'client/core/cl_main.lua',
    
    -- Restaurant System
    'client/systems/restaurants/cl_restaurant_core.lua',
    'client/systems/restaurants/cl_restaurant_menu.lua',
    'client/systems/restaurants/cl_restaurant_menu_v2.lua',
    'client/systems/restaurants/cl_restaurant_zones.lua',
    
    -- Warehouse System
    'client/systems/warehouse/cl_warehouse_core.lua',
    'client/systems/warehouse/cl_warehouse_menu.lua',
    'client/systems/warehouse/cl_warehouse_delivery.lua',
    'client/systems/warehouse/cl_warehouse_delivery_v2.lua',
    'client/systems/warehouse/cl_warehouse_zones.lua',
    'client/systems/warehouse/cl_warehouse_unloading.lua',
    'client/systems/warehouse/cl_container_system.lua',
    'client/systems/warehouse/cl_emergency_orders.lua',
    
    -- Economic System
    'client/systems/economics/cl_market_display.lua',

    -- Seller System
    'client/systems/seller/cl_seller_core.lua',

    -- Analytics System
    'client/systems/analytics/cl_achievements.lua'
}

-- Server Scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    -- Core Systems
    'server/core/sv_main.lua',
    
    -- Restaurant System
    'server/systems/restaurants/sv_restaurant_core.lua',
    'server/systems/restaurants/sv_restaurant_orders_v2.lua',
    
    -- Warehouse System
    'server/systems/warehouse/sv_warehouse_core.lua',
    'server/systems/warehouse/sv_container_system.lua',
    'server/systems/warehouse/sv_emergency_orders.lua',
    
    -- Economic System
    'server/systems/economics/sv_market_dynamics.lua',
    
    -- Team System
    'server/systems/team/sv_team_core.lua',
    
    -- Analytics System
    'server/systems/analytics/sv_achievements.lua',
    
    -- Admin System
    'server/admin/sv_admin_commands.lua'
}

-- Dependencies
dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
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
    'GetRecentUnlocks',

    -- Multi-Order System
    'GetShoppingCart',
    'ClearShoppingCart',
    'GetDeliveryState',
    'IsDeliveryActive',
    'OpenWarehouseMenu',
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