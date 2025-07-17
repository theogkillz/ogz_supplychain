fx_version 'cerulean'
game 'gta5'

author 'The OG KiLLz - Enterprise Evolution'
description 'OGz_SupplyChainMaster - Enterprise Edition'
version '3.0.0'
lua54 'yes'

-- SHARED SCRIPTS (Load Order Critical!)
shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    
    -- Core Configuration (MUST load first)
    'config/config_main.lua',
    'config/config_economics.lua',
    'config/config_rewards.lua',
    'config/config_notifications.lua',
    'config/config_admin.lua',
    
    -- System Configurations
    'config/config_restaurants.lua',    -- NEW for restaurant owners
    'config/config_docks.lua',         -- NEW for docks import  
    'config/config_warehouse.lua',     -- NEW extracted from main
    'config/config_containers.lua',    -- ✅ Already perfect
    'config/config_manufacturing.lua', -- ✅ Already perfect
    'config/config_locations.lua',     -- ✅ Already perfect
    'config/config_items.lua',         -- ✅ Already perfect
    
    -- Shared Utilities
    'shared/sh_constants.lua',         -- NEW global constants
    'shared/sh_utils.lua',            -- NEW shared utilities
    'shared/sh_validation.lua',       -- NEW validation functions
    'shared/sh_calculations.lua',     -- NEW shared calculations
}

-- SERVER SCRIPTS (Organized by System)
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    -- Core Foundation
    'server/core/sv_main.lua',              -- Migrated from sv_main.lua
    'server/core/sv_database.lua',          -- Migrated from sv_database.lua
    'server/core/sv_events.lua',            -- NEW event coordination
    
    -- Economics & Market Systems  
    'server/systems/economics/sv_market_dynamics.lua',    -- Migrated from sv_market_pricing.lua
    'server/systems/economics/sv_pricing_engine.lua',     -- NEW advanced pricing
    'server/systems/economics/sv_supply_demand.lua',      -- NEW demand analysis
    
    -- Restaurant System (Enhanced + New Ownership)
    'server/systems/restaurants/sv_restaurant_core.lua',     -- Migrated from sv_restaurant.lua
    'server/systems/restaurants/sv_restaurant_ownership.lua', -- NEW ownership system
    'server/systems/restaurants/sv_restaurant_staff.lua',    -- NEW staff management
    'server/systems/restaurants/sv_restaurant_finances.lua', -- NEW financial tracking
    
    -- Warehouse System  
    'server/systems/warehouse/sv_warehouse_core.lua',        -- Migrated from sv_warehouse.lua
    'server/systems/warehouse/sv_warehouse_orders.lua',      -- NEW extracted logic
    'server/systems/warehouse/sv_warehouse_containers.lua',  -- Migrated from sv_warehouse_containers.lua
    
    -- NEW Docks Import System
    'server/systems/docks/sv_docks_core.lua',               -- NEW docks management
    'server/systems/docks/sv_docks_workers.lua',            -- NEW dock worker system
    'server/systems/docks/sv_docks_imports.lua',            -- NEW import processing
    'server/systems/docks/sv_docks_containers.lua',         -- NEW container handling
    
    -- Container System
    'server/systems/containers/sv_containers_core.lua',      -- Migrated from sv_containers.lua
    'server/systems/containers/sv_containers_quality.lua',  -- Migrated from sv_rewards_containers.lua
    'server/systems/containers/sv_containers_tracking.lua', -- NEW tracking features
    
    -- Manufacturing System
    'server/systems/manufacturing/sv_manufacturing_core.lua', -- Migrated from sv_manufacturing.lua
    
    -- Rewards & Achievement System
    'server/systems/rewards/sv_rewards_core.lua',           -- Migrated from sv_rewards.lua  
    'server/systems/rewards/sv_achievements.lua',           -- Migrated from sv_achievements.lua
    'server/systems/rewards/sv_team_deliveries.lua',        -- Migrated from sv_team_deliveries.lua
    'server/systems/rewards/sv_vehicle_rewards.lua',        -- Migrated from sv_vehicle_achievements.lua
    
    -- Staff Management (NEW)
    'server/systems/staff/sv_staff_core.lua',               -- NEW staff system
    'server/systems/staff/sv_staff_timesheets.lua',         -- NEW timesheet tracking
    'server/systems/staff/sv_staff_payroll.lua',            -- NEW payroll calculation
    
    -- Analytics & Tracking
    'server/systems/analytics/sv_stock_alerts.lua',         -- Migrated from sv_stock_alerts.lua  
    'server/systems/analytics/sv_performance_tracking.lua', -- Migrated from sv_performance_tracking.lua
    'server/systems/analytics/sv_leaderboard.lua',          -- Migrated from sv_leaderboard.lua
    
    -- Integration Layer
    'server/integration/integration_qbcore.lua',            -- NEW framework integration
    'server/integration/integration_ox_inventory.lua',      -- NEW inventory integration
    
    -- Admin & Management
    'server/admin/sv_admin_core.lua',                       -- Migrated from sv_admin.lua
    'server/admin/sv_admin_commands.lua',                   -- NEW admin commands
    'server/admin/sv_admin_analytics.lua',                  -- NEW admin analytics
    
    -- Communication Systems
    'server/api/sv_discord_webhooks.lua',                   -- NEW Discord integration
    'server/api/sv_notifications.lua',                      -- Migrated from sv_notifications.lua
}

-- CLIENT SCRIPTS (Organized by System)  
client_scripts {
    -- Core Foundation
    'client/core/cl_main.lua',                              -- Migrated from cl_main.lua
    'client/core/cl_events.lua',                            -- NEW event handling
    'client/core/cl_ui_manager.lua',                        -- NEW UI coordination
    
    -- Restaurant System
    'client/systems/restaurants/cl_restaurant_ui.lua',         -- Migrated from cl_restaurant.lua
    'client/systems/restaurants/cl_restaurant_management.lua', -- NEW ownership UI
    'client/systems/restaurants/cl_restaurant_staff.lua',      -- NEW staff management UI
    
    -- Warehouse System
    'client/systems/warehouses/cl_warehouse_ui.lua',           -- Core UI & job validation
    'client/systems/warehouses/cl_warehouse_orders.lua',       -- Order processing & acceptance  
    'client/systems/warehouses/cl_warehouse_vehicles.lua',     -- Vehicle spawning system
    'client/systems/warehouses/cl_warehouse_loading.lua',      -- Box loading systems
    'client/systems/warehouses/cl_warehouse_delivery.lua',     -- 🔥 W5 DELIVERY COORDINATION
    'client/systems/warehouses/cl_warehouse_sourcing.lua',     -- Seller/distributor system
    
    -- NEW Docks System
    'client/systems/docks/cl_docks_ui.lua',                    -- NEW docks interface
    'client/systems/docks/cl_docks_workers.lua',               -- NEW dock worker UI
    'client/systems/docks/cl_docks_operations.lua',            -- NEW import operations
    
    -- Container System
    'client/systems/containers/cl_containers_ui.lua',          -- Migrated from cl_containers.lua
    'client/systems/containers/cl_containers_dynamic.lua',     -- Migrated from cl_containers_dynamic.lua
    'client/systems/containers/cl_containers_quality.lua',     -- NEW quality monitoring
    
    -- Vehicle & Achievement System
    'client/systems/vehicles/cl_vehicle_spawning.lua',         -- NEW vehicle management
    'client/systems/vehicles/cl_vehicle_rewards.lua',          -- Migrated from cl_vehicle_achievements.lua
    'client/systems/achievements/cl_achievements_ui.lua',      -- Migrated from cl_leaderboard.lua
    'client/systems/achievements/cl_achievements_tracking.lua', -- NEW achievement tracking
    
    -- Manufacturing System
    'client/systems/manufacturing/cl_manufacturing_ui.lua',    -- Migrated from cl_manufacturing.lua
    
    -- Team & Market Systems
    'client/systems/team/cl_team_deliveries.lua',              -- Migrated from cl_team_deliveries.lua
    'client/systems/market/cl_market.lua',                     -- Migrated from cl_market.lua
    'client/systems/market/cl_stock_alerts.lua',               -- Migrated from cl_stock_alerts.lua
    
    -- Integration
    'client/integration/integration_ox_target.lua',            -- NEW ox_target integration
    'client/integration/integration_notifications.lua',       -- NEW notification integration
    
    -- Admin Tools
    'client/admin/cl_admin_tools.lua',                         -- Migrated from cl_admin.lua
}

dependencies {
    'ox_lib',
    'ox_target', 
    'ox_inventory',
    'oxmysql',
    'lation_ui'
}