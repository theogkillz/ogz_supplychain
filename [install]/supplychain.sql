-- Creating the supply_orders table
CREATE TABLE IF NOT EXISTS `supply_orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `status` ENUM('pending','accepted','completed','denied') DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  `restaurant_id` INT(11) NOT NULL,
  `total_cost` DECIMAL(10,2) DEFAULT NULL,
  `order_group_id` VARCHAR(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_order_group_id` (`order_group_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_restaurant_id` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_stock table
CREATE TABLE IF NOT EXISTS `supply_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_ingredient` (`restaurant_id`, `ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_warehouse_stock table
CREATE TABLE IF NOT EXISTS `supply_warehouse_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_leaderboard table (MISSING IN GROK VERSION)
CREATE TABLE IF NOT EXISTS `supply_leaderboard` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `deliveries` INT(11) DEFAULT 0,
  `earnings` DECIMAL(10,2) DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Enhanced driver statistics table
CREATE TABLE IF NOT EXISTS `supply_driver_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `delivery_date` date NOT NULL,
  `completed_deliveries` int(11) DEFAULT 0,
  `total_deliveries` int(11) DEFAULT 0,
  `total_boxes_delivered` int(11) DEFAULT 0,
  `total_delivery_time` int(11) DEFAULT 0,
  `total_earnings` decimal(10,2) DEFAULT 0.00,
  `perfect_deliveries` int(11) DEFAULT 0,
  `performance_rating` int(11) DEFAULT 0,
  `consecutive_days` int(11) DEFAULT 0,
  `last_delivery` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_driver_date` (`citizenid`, `delivery_date`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_delivery_date` (`delivery_date`),
  KEY `idx_performance_rating` (`performance_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

- Achievements table
CREATE TABLE IF NOT EXISTS `supply_achievements` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `achievement_id` varchar(50) NOT NULL,
    `earned_date` int(11) NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_achievement` (`citizenid`, `achievement_id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_achievement_id` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Delivery Logs Table (for detailed analytics)
CREATE TABLE IF NOT EXISTS `supply_delivery_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `order_group_id` varchar(100) NOT NULL,
    `restaurant_id` int(11) NOT NULL,
    `boxes_delivered` int(11) NOT NULL,
    `delivery_time` int(11) NOT NULL,
    `base_pay` decimal(10,2) NOT NULL,
    `bonus_pay` decimal(10,2) DEFAULT 0.00,
    `total_pay` decimal(10,2) NOT NULL,
    `is_perfect_delivery` tinyint(1) DEFAULT 0,
    `is_team_delivery` tinyint(1) DEFAULT 0,
    `team_id` varchar(100) DEFAULT NULL,
    `speed_multiplier` decimal(4,2) DEFAULT 1.00,
    `streak_multiplier` decimal(4,2) DEFAULT 1.00,
    `daily_multiplier` decimal(4,2) DEFAULT 1.00,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_restaurant_id` (`restaurant_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_is_perfect` (`is_perfect_delivery`),
    KEY `idx_team_delivery` (`is_team_delivery`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Driver streak tracking
CREATE TABLE IF NOT EXISTS `supply_driver_streaks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `perfect_streak` int(11) DEFAULT 0,
  `best_streak` int(11) DEFAULT 0,
  `last_delivery` int(11) DEFAULT 0,
  `streak_broken_count` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_citizenid` (`citizenid`),
  KEY `idx_perfect_streak` (`perfect_streak`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Reward logs table
CREATE TABLE IF NOT EXISTS `supply_reward_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `order_group_id` varchar(50) NOT NULL,
    `base_pay` decimal(10,2) NOT NULL,
    `bonus_amount` decimal(10,2) DEFAULT 0.00,
    `final_payout` decimal(10,2) NOT NULL,
    `speed_multiplier` decimal(4,2) DEFAULT 1.00,
    `streak_multiplier` decimal(4,2) DEFAULT 1.00,
    `daily_multiplier` decimal(4,2) DEFAULT 1.00,
    `perfect_delivery` tinyint(1) DEFAULT 0,
    `delivery_time` int(11) NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Daily bonus tracking
CREATE TABLE IF NOT EXISTS `supply_daily_bonuses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `bonus_date` date NOT NULL,
  `deliveries_completed` int(11) DEFAULT 0,
  `current_multiplier` decimal(4,2) DEFAULT 1.00,
  `total_bonus_earned` decimal(10,2) DEFAULT 0.00,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_driver_date` (`citizenid`, `bonus_date`),
  KEY `idx_bonus_date` (`bonus_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Team Delivery Database Table

CREATE TABLE IF NOT EXISTS `supply_team_deliveries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `team_id` varchar(100) NOT NULL,
  `order_group_id` varchar(100) NOT NULL,
  `restaurant_id` int(11) NOT NULL,
  `leader_citizenid` varchar(50) NOT NULL,
  `member_count` int(11) NOT NULL,
  `total_boxes` int(11) NOT NULL,
  `delivery_type` varchar(50) NOT NULL,
  `coordination_bonus` decimal(10,2) DEFAULT 0.00,
  `team_multiplier` decimal(4,2) DEFAULT 1.00,
  `completion_time` int(11) NOT NULL,
  `total_payout` decimal(10,2) DEFAULT 0.00,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_team_id` (`team_id`),
  KEY `idx_leader_citizenid` (`leader_citizenid`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Team delivery members tracking
CREATE TABLE IF NOT EXISTS `supply_team_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `team_id` varchar(100) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `boxes_assigned` int(11) NOT NULL,
  `completion_time` int(11) DEFAULT 0,
  `individual_payout` decimal(10,2) DEFAULT 0.00,
  `role` enum('leader','member') DEFAULT 'member',
  `joined_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_team_id` (`team_id`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Stock Analytics and Alerts Database Tables

-- Stock Alerts Table
CREATE TABLE IF NOT EXISTS `supply_stock_alerts` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `alert_level` enum('critical','low','moderate','healthy') NOT NULL,
    `current_stock` int(11) NOT NULL,
    `threshold_percentage` decimal(5,2) NOT NULL,
    `predicted_stockout_date` datetime DEFAULT NULL,
    `resolved` tinyint(1) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `resolved_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_alert_level` (`alert_level`),
    KEY `idx_resolved` (`resolved`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Usage pattern analytics
CREATE TABLE IF NOT EXISTS `supply_usage_analytics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `analysis_date` date NOT NULL,
  `avg_daily_usage` decimal(8,2) DEFAULT 0.00,
  `peak_usage` decimal(8,2) DEFAULT 0.00,
  `min_usage` decimal(8,2) DEFAULT 0.00,
  `usage_variance` decimal(8,2) DEFAULT 0.00,
  `trend` enum('increasing','decreasing','stable','unknown') DEFAULT 'unknown',
  `confidence_score` decimal(4,3) DEFAULT 0.000,
  `prediction_accuracy` decimal(4,3) DEFAULT NULL,
  `data_points` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_date` (`ingredient`, `analysis_date`),
  KEY `idx_analysis_date` (`analysis_date`),
  KEY `idx_trend` (`trend`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restock recommendations tracking
CREATE TABLE IF NOT EXISTS `supply_restock_suggestions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `current_stock` int(11) NOT NULL,
  `suggested_quantity` int(11) NOT NULL,
  `priority` enum('high','normal','low') DEFAULT 'normal',
  `reasoning` text DEFAULT NULL,
  `days_of_stock_remaining` decimal(4,1) DEFAULT NULL,
  `confidence_score` decimal(4,3) DEFAULT 0.000,
  `suggestion_status` enum('pending','acknowledged','ordered','dismissed') DEFAULT 'pending',
  `cost_estimate` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ingredient` (`ingredient`),
  KEY `idx_priority` (`priority`),
  KEY `idx_suggestion_status` (`suggestion_status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Stock Snapshots Table (for trend analysis)
CREATE TABLE IF NOT EXISTS `supply_stock_snapshots` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `warehouse_stock` int(11) NOT NULL,
    `total_restaurant_stock` int(11) DEFAULT 0,
    `daily_usage` int(11) DEFAULT 0,
    `predicted_days_remaining` decimal(5,2) DEFAULT NULL,
    `snapshot_date` date NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_ingredient_date` (`ingredient`, `snapshot_date`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_snapshot_date` (`snapshot_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Demand forecasting data
CREATE TABLE IF NOT EXISTS `supply_demand_forecasts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `forecast_date` date NOT NULL,
  `predicted_usage` decimal(8,2) NOT NULL,
  `confidence_interval_low` decimal(8,2) DEFAULT NULL,
  `confidence_interval_high` decimal(8,2) DEFAULT NULL,
  `actual_usage` decimal(8,2) DEFAULT NULL,
  `forecast_accuracy` decimal(5,2) DEFAULT NULL,
  `model_version` varchar(20) DEFAULT 'v1.0',
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_forecast_date` (`ingredient`, `forecast_date`),
  KEY `idx_forecast_date` (`forecast_date`),
  KEY `idx_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dynamic Market Pricing Database Tables

-- Market Snapshots Table
CREATE TABLE IF NOT EXISTS `supply_market_snapshots` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `base_price` decimal(10,2) NOT NULL,
    `multiplier` decimal(4,2) NOT NULL DEFAULT 1.00,
    `final_price` decimal(10,2) NOT NULL,
    `stock_level` int(11) NOT NULL,
    `demand_level` enum('low','normal','high') DEFAULT 'normal',
    `player_count` int(11) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_multiplier` (`multiplier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Market events tracking (shortages, surpluses, etc.)
CREATE TABLE IF NOT EXISTS `supply_market_events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `event_type` enum('shortage','surplus','spike','crash','volatility') NOT NULL,
  `trigger_condition` varchar(255) DEFAULT NULL,
  `price_before` decimal(10,2) NOT NULL,
  `price_after` decimal(10,2) NOT NULL,
  `multiplier_applied` decimal(6,3) NOT NULL,
  `duration` int(11) DEFAULT NULL,
  `stock_level_at_trigger` int(11) DEFAULT NULL,
  `player_count_at_trigger` int(11) DEFAULT NULL,
  `started_at` int(11) NOT NULL,
  `ended_at` int(11) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ingredient` (`ingredient`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_started_at` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Demand analysis data
CREATE TABLE IF NOT EXISTS `supply_demand_analysis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `analysis_date` date NOT NULL,
  `hour_of_day` tinyint(2) NOT NULL,
  `order_count` int(11) DEFAULT 0,
  `total_quantity` int(11) DEFAULT 0,
  `unique_buyers` int(11) DEFAULT 0,
  `average_order_size` decimal(8,2) DEFAULT 0.00,
  `peak_order_time` time DEFAULT NULL,
  `demand_score` decimal(6,3) DEFAULT 0.000,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_date_hour` (`ingredient`, `analysis_date`, `hour_of_day`),
  KEY `idx_analysis_date` (`analysis_date`),
  KEY `idx_demand_score` (`demand_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Market Settings Table (for admin stock adjustments)
CREATE TABLE IF NOT EXISTS `supply_market_settings` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `max_stock` int(11) DEFAULT 500,
    `min_stock_threshold` int(11) DEFAULT 25,
    `base_price` decimal(10,2) DEFAULT 10.00,
    `category` enum('default','high_demand','seasonal','specialty') DEFAULT 'default',
    `enabled` tinyint(1) DEFAULT 1,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_ingredient` (`ingredient`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Player market notifications preferences
CREATE TABLE IF NOT EXISTS `supply_market_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `notification_type` enum('price_alerts','shortage_alerts','surplus_alerts','market_trends') NOT NULL,
  `ingredient_filter` text DEFAULT NULL,
  `threshold_percentage` decimal(5,2) DEFAULT 20.00,
  `is_enabled` tinyint(1) DEFAULT 1,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_notification_type` (`notification_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Add market transaction logging table
CREATE TABLE IF NOT EXISTS `supply_market_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_group_id` varchar(100) NOT NULL,
  `player_id` int(11) NOT NULL,
  `restaurant_id` int(11) NOT NULL,
  `total_cost` decimal(10,2) NOT NULL,
  `market_impact` decimal(10,2) DEFAULT 0.00,
  `transaction_type` enum('purchase','sale') NOT NULL,
  `transaction_time` int(11) NOT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_id` (`player_id`),
  KEY `idx_transaction_time` (`transaction_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

CREATE TABLE IF NOT EXISTS `supply_notification_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `new_orders` tinyint(1) DEFAULT 1,
  `emergency_alerts` tinyint(1) DEFAULT 1,
  `market_changes` tinyint(1) DEFAULT 1,
  `team_invites` tinyint(1) DEFAULT 1,
  `achievements` tinyint(1) DEFAULT 1,
  `stock_alerts` tinyint(1) DEFAULT 1,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Emergency Orders Table
CREATE TABLE IF NOT EXISTS `supply_emergency_orders` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `restaurant_id` int(11) NOT NULL,
    `ingredient` varchar(100) NOT NULL,
    `priority_level` enum('emergency','urgent','critical') NOT NULL,
    `quantity_needed` int(11) NOT NULL,
    `bonus_multiplier` decimal(4,2) DEFAULT 1.50,
    `timeout_minutes` int(11) DEFAULT 60,
    `completed` tinyint(1) DEFAULT 0,
    `completed_by` varchar(50) DEFAULT NULL,
    `completed_at` timestamp NULL DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_restaurant_id` (`restaurant_id`),
    KEY `idx_priority_level` (`priority_level`),
    KEY `idx_completed` (`completed`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Ownership Table
CREATE TABLE IF NOT EXISTS `supply_restaurant_ownership` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `owner_citizenid` varchar(50) NOT NULL,
  `owner_name` varchar(100) NOT NULL,
  `purchase_price` decimal(10,2) NOT NULL,
  `purchase_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `ownership_type` enum('individual','partnership','corporation') DEFAULT 'individual',
  `business_license` varchar(50) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant` (`restaurant_id`),
  KEY `idx_owner_citizenid` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Staff Management
CREATE TABLE IF NOT EXISTS `supply_restaurant_staff` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `employee_citizenid` varchar(50) NOT NULL,
  `employee_name` varchar(100) NOT NULL,
  `position` enum('owner','manager','employee','temp') DEFAULT 'employee',
  `permissions` json DEFAULT NULL,
  `hourly_wage` decimal(8,2) DEFAULT 0.00,
  `hired_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_employee` (`restaurant_id`, `employee_citizenid`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_employee_citizenid` (`employee_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Financial Tracking
CREATE TABLE IF NOT EXISTS `supply_restaurant_finances` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `transaction_type` enum('revenue','expense','supply_order','staff_payment','maintenance') NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `reference_id` varchar(100) DEFAULT NULL, -- Links to order_group_id, etc.
  `created_by` varchar(50) DEFAULT NULL,
  `transaction_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_transaction_type` (`transaction_type`),
  KEY `idx_transaction_date` (`transaction_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Settings/Preferences
CREATE TABLE IF NOT EXISTS `supply_restaurant_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `setting_name` varchar(100) NOT NULL,
  `setting_value` text DEFAULT NULL,
  `updated_by` varchar(50) DEFAULT NULL,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_setting` (`restaurant_id`, `setting_name`),
  KEY `idx_restaurant_id` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- ===============================================
-- DOCKS IMPORT SYSTEM - DATABASE SCHEMA
-- Extends OGZ-SupplyChain with international import functionality
-- ===============================================

-- International Suppliers Management
CREATE TABLE IF NOT EXISTS `supply_international_suppliers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_name` varchar(100) NOT NULL,
  `supplier_code` varchar(20) NOT NULL,
  `country_origin` varchar(50) NOT NULL,
  `continent` varchar(30) NOT NULL,
  `supplier_type` enum('agricultural','livestock','seafood','processed','specialty','bulk') DEFAULT 'agricultural',
  `reliability_rating` decimal(3,2) DEFAULT 5.00,
  `quality_rating` decimal(3,2) DEFAULT 5.00,
  `price_competitiveness` decimal(3,2) DEFAULT 5.00,
  `shipping_time_days` int(11) DEFAULT 7,
  `minimum_order_value` decimal(10,2) DEFAULT 5000.00,
  `preferred_payment_terms` varchar(50) DEFAULT 'NET30',
  `certifications` json DEFAULT NULL,
  `specialties` json DEFAULT NULL,
  `seasonal_availability` json DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `reputation_score` int(11) DEFAULT 100,
  `total_orders_completed` int(11) DEFAULT 0,
  `average_delivery_time` decimal(4,1) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_supplier_code` (`supplier_code`),
  KEY `idx_country_origin` (`country_origin`),
  KEY `idx_supplier_type` (`supplier_type`),
  KEY `idx_reliability_rating` (`reliability_rating`),
  KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Supplier Product Catalog
CREATE TABLE IF NOT EXISTS `supply_supplier_catalog` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `supplier_id` int(11) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `product_code` varchar(50) NOT NULL,
  `category` varchar(50) NOT NULL,
  `base_price_per_unit` decimal(8,2) NOT NULL,
  `currency` varchar(10) DEFAULT 'USD',
  `minimum_order_quantity` int(11) DEFAULT 100,
  `maximum_order_quantity` int(11) DEFAULT 10000,
  `quality_grade` enum('standard','premium','organic','luxury') DEFAULT 'standard',
  `shelf_life_days` int(11) DEFAULT 30,
  `storage_requirements` varchar(100) DEFAULT 'dry_storage',
  `seasonal_multiplier` json DEFAULT NULL,
  `availability_calendar` json DEFAULT NULL,
  `certifications` json DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_available` tinyint(1) DEFAULT 1,
  `last_price_update` timestamp DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_supplier_product` (`supplier_id`, `product_code`),
  FOREIGN KEY (`supplier_id`) REFERENCES `supply_international_suppliers`(`id`) ON DELETE CASCADE,
  KEY `idx_category` (`category`),
  KEY `idx_quality_grade` (`quality_grade`),
  KEY `idx_is_available` (`is_available`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Import Orders Management
CREATE TABLE IF NOT EXISTS `supply_import_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `import_order_id` varchar(100) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `ordered_by` varchar(50) NOT NULL,
  `order_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `requested_delivery_date` date DEFAULT NULL,
  `estimated_arrival_date` date DEFAULT NULL,
  `actual_arrival_date` date DEFAULT NULL,
  `total_items` int(11) DEFAULT 0,
  `total_containers` int(11) DEFAULT 0,
  `total_value` decimal(12,2) DEFAULT 0.00,
  `currency` varchar(10) DEFAULT 'USD',
  `exchange_rate` decimal(8,4) DEFAULT 1.0000,
  `shipping_cost` decimal(10,2) DEFAULT 0.00,
  `customs_fees` decimal(8,2) DEFAULT 0.00,
  `insurance_cost` decimal(8,2) DEFAULT 0.00,
  `total_landed_cost` decimal(12,2) DEFAULT 0.00,
  `payment_terms` varchar(50) DEFAULT 'NET30',
  `payment_status` enum('pending','partial','paid','overdue') DEFAULT 'pending',
  `order_status` enum('draft','submitted','confirmed','shipped','in_transit','customs','arrived','processing','completed','cancelled') DEFAULT 'draft',
  `priority` enum('standard','urgent','emergency') DEFAULT 'standard',
  `special_instructions` text DEFAULT NULL,
  `tracking_number` varchar(100) DEFAULT NULL,
  `vessel_name` varchar(100) DEFAULT NULL,
  `port_of_origin` varchar(100) DEFAULT NULL,
  `port_of_destination` varchar(100) DEFAULT 'Los Santos Port',
  `customs_cleared` tinyint(1) DEFAULT 0,
  `quality_inspection_passed` tinyint(1) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_import_order_id` (`import_order_id`),
  FOREIGN KEY (`supplier_id`) REFERENCES `supply_international_suppliers`(`id`),
  KEY `idx_ordered_by` (`ordered_by`),
  KEY `idx_order_status` (`order_status`),
  KEY `idx_estimated_arrival` (`estimated_arrival_date`),
  KEY `idx_priority` (`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Import Order Line Items
CREATE TABLE IF NOT EXISTS `supply_import_order_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `import_order_id` varchar(100) NOT NULL,
  `supplier_product_id` int(11) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `quantity_ordered` int(11) NOT NULL,
  `quantity_received` int(11) DEFAULT 0,
  `unit_price` decimal(8,2) NOT NULL,
  `currency` varchar(10) DEFAULT 'USD',
  `line_total` decimal(10,2) NOT NULL,
  `container_type_required` varchar(50) DEFAULT 'standard',
  `quality_grade_ordered` varchar(50) DEFAULT 'standard',
  `quality_grade_received` varchar(50) DEFAULT NULL,
  `expiration_date` date DEFAULT NULL,
  `lot_number` varchar(50) DEFAULT NULL,
  `inspection_notes` text DEFAULT NULL,
  `condition_on_arrival` enum('excellent','good','fair','poor','damaged') DEFAULT NULL,
  `accepted_quantity` int(11) DEFAULT 0,
  `rejected_quantity` int(11) DEFAULT 0,
  `rejection_reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`supplier_product_id`) REFERENCES `supply_supplier_catalog`(`id`),
  KEY `idx_import_order_id` (`import_order_id`),
  KEY `idx_quality_grade_received` (`quality_grade_received`),
  KEY `idx_condition_on_arrival` (`condition_on_arrival`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dock Operations & Worker Activities
CREATE TABLE IF NOT EXISTS `supply_dock_operations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `operation_id` varchar(100) NOT NULL,
  `import_order_id` varchar(100) NOT NULL,
  `operation_type` enum('unloading','inspection','customs','processing','forwarding') NOT NULL,
  `assigned_worker` varchar(50) DEFAULT NULL,
  `worker_name` varchar(100) DEFAULT NULL,
  `start_time` timestamp DEFAULT CURRENT_TIMESTAMP,
  `end_time` timestamp NULL DEFAULT NULL,
  `operation_status` enum('pending','in_progress','completed','failed','cancelled') DEFAULT 'pending',
  `containers_processed` int(11) DEFAULT 0,
  `items_processed` int(11) DEFAULT 0,
  `quality_checks_performed` int(11) DEFAULT 0,
  `issues_found` int(11) DEFAULT 0,
  `operation_notes` text DEFAULT NULL,
  `efficiency_rating` decimal(3,2) DEFAULT NULL,
  `completion_time_minutes` int(11) DEFAULT NULL,
  `base_pay` decimal(8,2) DEFAULT 0.00,
  `bonus_pay` decimal(8,2) DEFAULT 0.00,
  `total_pay` decimal(8,2) DEFAULT 0.00,
  `equipment_used` json DEFAULT NULL,
  `weather_conditions` varchar(50) DEFAULT NULL,
  `difficulty_rating` enum('easy','normal','hard','extreme') DEFAULT 'normal',
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_operation_id` (`operation_id`),
  KEY `idx_import_order_id` (`import_order_id`),
  KEY `idx_assigned_worker` (`assigned_worker`),
  KEY `idx_operation_type` (`operation_type`),
  KEY `idx_operation_status` (`operation_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Container Tracking Integration (extends existing container system)
CREATE TABLE IF NOT EXISTS `supply_import_containers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `container_id` varchar(100) NOT NULL,
  `import_order_id` varchar(100) NOT NULL,
  `container_type` varchar(50) NOT NULL,
  `container_size` enum('20ft','40ft','40ft_hc','45ft') DEFAULT '40ft',
  `seal_number` varchar(50) DEFAULT NULL,
  `weight_gross` decimal(8,2) DEFAULT NULL,
  `weight_net` decimal(8,2) DEFAULT NULL,
  `temperature_controlled` tinyint(1) DEFAULT 0,
  `target_temperature` decimal(4,1) DEFAULT NULL,
  `current_temperature` decimal(4,1) DEFAULT NULL,
  `humidity_level` decimal(4,1) DEFAULT NULL,
  `position_at_dock` varchar(20) DEFAULT NULL,
  `unloading_priority` int(11) DEFAULT 1,
  `customs_status` enum('pending','inspecting','cleared','hold','rejected') DEFAULT 'pending',
  `inspection_required` tinyint(1) DEFAULT 1,
  `inspection_completed` tinyint(1) DEFAULT 0,
  `quality_grade_verified` varchar(50) DEFAULT NULL,
  `damage_assessment` enum('none','minor','moderate','major','total_loss') DEFAULT 'none',
  `forwarded_to_warehouse` tinyint(1) DEFAULT 0,
  `forwarding_date` timestamp NULL DEFAULT NULL,
  `storage_location` varchar(50) DEFAULT NULL,
  `handling_instructions` text DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_container_id` (`container_id`),
  KEY `idx_import_order_id` (`import_order_id`),
  KEY `idx_customs_status` (`customs_status`),
  KEY `idx_forwarded_to_warehouse` (`forwarded_to_warehouse`),
  KEY `idx_unloading_priority` (`unloading_priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dock Worker Performance & Statistics
CREATE TABLE IF NOT EXISTS `supply_dock_worker_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `worker_citizenid` varchar(50) NOT NULL,
  `worker_name` varchar(100) NOT NULL,
  `shift_date` date NOT NULL,
  `shift_start` timestamp DEFAULT CURRENT_TIMESTAMP,
  `shift_end` timestamp NULL DEFAULT NULL,
  `total_hours_worked` decimal(4,2) DEFAULT 0.00,
  `operations_completed` int(11) DEFAULT 0,
  `containers_processed` int(11) DEFAULT 0,
  `total_items_handled` int(11) DEFAULT 0,
  `quality_inspections_performed` int(11) DEFAULT 0,
  `issues_identified` int(11) DEFAULT 0,
  `efficiency_score` decimal(4,2) DEFAULT 0.00,
  `safety_incidents` int(11) DEFAULT 0,
  `base_earnings` decimal(8,2) DEFAULT 0.00,
  `bonus_earnings` decimal(8,2) DEFAULT 0.00,
  `total_earnings` decimal(8,2) DEFAULT 0.00,
  `performance_rating` decimal(3,2) DEFAULT 5.00,
  `supervisor_notes` text DEFAULT NULL,
  `equipment_certifications` json DEFAULT NULL,
  `overtime_hours` decimal(4,2) DEFAULT 0.00,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_worker_date` (`worker_citizenid`, `shift_date`),
  KEY `idx_worker_citizenid` (`worker_citizenid`),
  KEY `idx_shift_date` (`shift_date`),
  KEY `idx_performance_rating` (`performance_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Market Impact Tracking (integrates with existing market system)
CREATE TABLE IF NOT EXISTS `supply_import_market_impact` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `import_order_id` varchar(100) NOT NULL,
  `ingredient_affected` varchar(100) NOT NULL,
  `quantity_imported` int(11) NOT NULL,
  `import_date` date NOT NULL,
  `pre_import_price` decimal(8,2) DEFAULT NULL,
  `post_import_price` decimal(8,2) DEFAULT NULL,
  `price_change_percentage` decimal(5,2) DEFAULT NULL,
  `market_impact_score` decimal(4,2) DEFAULT 0.00,
  `supply_level_before` int(11) DEFAULT 0,
  `supply_level_after` int(11) DEFAULT 0,
  `demand_satisfaction_rating` decimal(3,2) DEFAULT NULL,
  `market_stabilization_effect` enum('stabilizing','destabilizing','neutral') DEFAULT 'neutral',
  `competitive_advantage_gained` tinyint(1) DEFAULT 0,
  `import_quality_premium` decimal(4,3) DEFAULT 0.000,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_import_order_id` (`import_order_id`),
  KEY `idx_ingredient_affected` (`ingredient_affected`),
  KEY `idx_import_date` (`import_date`),
  KEY `idx_market_impact_score` (`market_impact_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Customs & Regulatory Compliance
CREATE TABLE IF NOT EXISTS `supply_customs_documentation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `import_order_id` varchar(100) NOT NULL,
  `document_type` enum('commercial_invoice','bill_of_lading','packing_list','certificate_of_origin','health_certificate','quality_certificate','import_permit') NOT NULL,
  `document_number` varchar(100) DEFAULT NULL,
  `issued_by` varchar(100) DEFAULT NULL,
  `issue_date` date DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `document_status` enum('pending','submitted','approved','rejected','expired') DEFAULT 'pending',
  `verification_required` tinyint(1) DEFAULT 1,
  `verification_completed` tinyint(1) DEFAULT 0,
  `verification_date` timestamp NULL DEFAULT NULL,
  `verified_by` varchar(50) DEFAULT NULL,
  `compliance_notes` text DEFAULT NULL,
  `rejection_reason` varchar(255) DEFAULT NULL,
  `fees_associated` decimal(8,2) DEFAULT 0.00,
  `processing_time_hours` int(11) DEFAULT NULL,
  `document_hash` varchar(255) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_import_order_id` (`import_order_id`),
  KEY `idx_document_type` (`document_type`),
  KEY `idx_document_status` (`document_status`),
  KEY `idx_expiry_date` (`expiry_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Port Infrastructure & Scheduling
CREATE TABLE IF NOT EXISTS `supply_port_schedule` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vessel_name` varchar(100) NOT NULL,
  `vessel_type` enum('container_ship','bulk_carrier','reefer_ship','general_cargo') DEFAULT 'container_ship',
  `scheduled_arrival` timestamp NOT NULL,
  `actual_arrival` timestamp NULL DEFAULT NULL,
  `scheduled_departure` timestamp NOT NULL,
  `actual_departure` timestamp NULL DEFAULT NULL,
  `berth_assigned` varchar(20) DEFAULT NULL,
  `containers_aboard` int(11) DEFAULT 0,
  `import_orders_count` int(11) DEFAULT 0,
  `total_cargo_value` decimal(12,2) DEFAULT 0.00,
  `priority_level` enum('standard','high','urgent','emergency') DEFAULT 'standard',
  `weather_delay` tinyint(1) DEFAULT 0,
  `customs_delay` tinyint(1) DEFAULT 0,
  `mechanical_issues` tinyint(1) DEFAULT 0,
  `port_congestion_delay` tinyint(1) DEFAULT 0,
  `estimated_processing_time` int(11) DEFAULT 480,
  `actual_processing_time` int(11) DEFAULT NULL,
  `vessel_status` enum('scheduled','approaching','docked','unloading','departed','delayed','cancelled') DEFAULT 'scheduled',
  `captain_name` varchar(100) DEFAULT NULL,
  `shipping_line` varchar(100) DEFAULT NULL,
  `port_agent` varchar(100) DEFAULT NULL,
  `special_requirements` text DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_vessel_name` (`vessel_name`),
  KEY `idx_scheduled_arrival` (`scheduled_arrival`),
  KEY `idx_vessel_status` (`vessel_status`),
  KEY `idx_priority_level` (`priority_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- ===============================================
-- INTEGRATION WITH EXISTING OGZ TABLES
-- ===============================================

-- Extend existing supply_warehouse_stock for import tracking
ALTER TABLE `supply_warehouse_stock` 
ADD COLUMN `import_source` enum('domestic','imported','mixed') DEFAULT 'domestic',
ADD COLUMN `last_import_date` date DEFAULT NULL,
ADD COLUMN `import_quality_premium` decimal(4,3) DEFAULT 0.000,
ADD COLUMN `supplier_id` int(11) DEFAULT NULL,
ADD COLUMN `import_batch_id` varchar(100) DEFAULT NULL;

-- Add indexes for performance
ALTER TABLE `supply_warehouse_stock`
ADD INDEX `idx_import_source` (`import_source`),
ADD INDEX `idx_last_import_date` (`last_import_date`);

-- Extend existing supply_containers table for import containers
ALTER TABLE `supply_containers` 
ADD COLUMN `import_container_id` varchar(100) DEFAULT NULL,
ADD COLUMN `country_of_origin` varchar(50) DEFAULT NULL,
ADD COLUMN `import_inspection_passed` tinyint(1) DEFAULT 1,
ADD COLUMN `customs_cleared` tinyint(1) DEFAULT 1,
ADD COLUMN `landed_cost_per_unit` decimal(8,2) DEFAULT NULL;

-- Add indexes for import container tracking
ALTER TABLE `supply_containers`
ADD INDEX `idx_import_container_id` (`import_container_id`),
ADD INDEX `idx_country_of_origin` (`country_of_origin`);

-- ===============================================
-- DEFAULT INTERNATIONAL SUPPLIERS
-- ===============================================

-- Insert sample international suppliers
INSERT IGNORE INTO `supply_international_suppliers` (`supplier_name`, `supplier_code`, `country_origin`, `continent`, `supplier_type`, `reliability_rating`, `quality_rating`, `price_competitiveness`, `shipping_time_days`, `minimum_order_value`, `specialties`) VALUES
('Pacific Harvest Co.', 'PHC001', 'Japan', 'Asia', 'seafood', 4.8, 4.9, 3.5, 10, 8000.00, '["premium_fish", "seaweed", "specialty_seafood"]'),
('Euro Fresh Farms', 'EFF002', 'Netherlands', 'Europe', 'agricultural', 4.5, 4.7, 4.2, 7, 5000.00, '["organic_vegetables", "greenhouse_produce", "flowers"]'),
('Amazon Bounty Ltd.', 'ABL003', 'Brazil', 'South America', 'agricultural', 4.2, 4.1, 4.8, 14, 3000.00, '["tropical_fruits", "coffee", "exotic_spices"]'),
('Outback Provisions', 'OBP004', 'Australia', 'Oceania', 'livestock', 4.6, 4.8, 3.8, 21, 10000.00, '["premium_beef", "lamb", "dairy_products"]'),
('Nordic Naturals', 'NN005', 'Norway', 'Europe', 'seafood', 4.9, 4.9, 3.2, 12, 7500.00, '["salmon", "arctic_fish", "sustainable_seafood"]'),
('African Spice Trading', 'AST006', 'South Africa', 'Africa', 'specialty', 4.0, 4.3, 4.5, 18, 2500.00, '["exotic_spices", "herbs", "traditional_seasonings"]'),
('Maple Leaf Exports', 'MLE007', 'Canada', 'North America', 'agricultural', 4.7, 4.6, 4.0, 5, 4000.00, '["grain", "maple_products", "organic_produce"]'),
('Himalayan Harvest', 'HH008', 'India', 'Asia', 'specialty', 4.3, 4.2, 4.7, 16, 3500.00, '["exotic_spices", "rice_varieties", "lentils"]');

-- Insert sample supplier catalog items
INSERT IGNORE INTO `supply_supplier_catalog` (`supplier_id`, `product_name`, `product_code`, `category`, `base_price_per_unit`, `minimum_order_quantity`, `quality_grade`, `shelf_life_days`) VALUES
(1, 'Premium Bluefin Tuna', 'PHC-TUNA-001', 'Seafood', 45.00, 50, 'luxury', 7),
(1, 'Fresh Sea Bass', 'PHC-BASS-002', 'Seafood', 18.50, 100, 'premium', 5),
(2, 'Organic Heirloom Tomatoes', 'EFF-TOM-001', 'Vegetables', 8.75, 200, 'organic', 14),
(2, 'Dutch Greenhouse Lettuce', 'EFF-LET-002', 'Vegetables', 4.20, 300, 'premium', 10),
(3, 'Exotic Tropical Fruit Mix', 'ABL-FRUIT-001', 'Fruits', 12.30, 150, 'premium', 8),
(3, 'Brazilian Coffee Beans', 'ABL-COFFEE-001', 'Specialty', 22.50, 100, 'premium', 365),
(4, 'Wagyu Beef Cuts', 'OBP-BEEF-001', 'Meat', 85.00, 25, 'luxury', 21),
(4, 'Premium Lamb Chops', 'OBP-LAMB-001', 'Meat', 32.50, 50, 'premium', 18),
(5, 'Norwegian Atlantic Salmon', 'NN-SALMON-001', 'Seafood', 28.75, 75, 'premium', 10),
(6, 'Exotic African Spice Blend', 'AST-SPICE-001', 'Spices', 15.60, 50, 'premium', 730),
(7, 'Canadian Organic Grain', 'MLE-GRAIN-001', 'Grains', 6.25, 500, 'organic', 180),
(8, 'Himalayan Pink Salt', 'HH-SALT-001', 'Specialty', 12.80, 100, 'premium', 1095);

-- ===============================================
-- USEFUL QUERIES FOR TESTING
-- ===============================================

-- Check active import orders
SELECT 
    io.import_order_id,
    s.supplier_name,
    io.order_status,
    io.total_value,
    io.estimated_arrival_date,
    COUNT(ioi.id) as line_items
FROM supply_import_orders io
JOIN supply_international_suppliers s ON io.supplier_id = s.id
LEFT JOIN supply_import_order_items ioi ON io.import_order_id = ioi.import_order_id
WHERE io.order_status IN ('confirmed', 'shipped', 'in_transit', 'arrived')
GROUP BY io.id;

-- Get dock worker performance summary
SELECT 
    worker_citizenid,
    worker_name,
    SUM(total_hours_worked) as total_hours,
    SUM(operations_completed) as total_operations,
    AVG(efficiency_score) as avg_efficiency,
    SUM(total_earnings) as total_earnings
FROM supply_dock_worker_stats 
WHERE shift_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY worker_citizenid
ORDER BY avg_efficiency DESC;

-- Check container processing status
SELECT 
    ic.container_id,
    io.import_order_id,
    s.supplier_name,
    ic.customs_status,
    ic.inspection_completed,
    ic.forwarded_to_warehouse
FROM supply_import_containers ic
JOIN supply_import_orders io ON ic.import_order_id = io.import_order_id
JOIN supply_international_suppliers s ON io.supplier_id = s.id
WHERE ic.forwarded_to_warehouse = 0;

-- Market impact analysis
SELECT 
    ima.ingredient_affected,
    COUNT(*) as import_events,
    AVG(ima.price_change_percentage) as avg_price_impact,
    SUM(ima.quantity_imported) as total_imported,
    AVG(ima.market_impact_score) as avg_market_impact
FROM supply_import_market_impact ima
WHERE ima.import_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY ima.ingredient_affected
ORDER BY avg_market_impact DESC;

-- ===============================================
-- COMPLETION MESSAGE
-- ===============================================

SELECT 
    'Docks Import System Database Complete!' as message,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME LIKE 'supply_%' 
     AND TABLE_NAME IN ('supply_international_suppliers', 'supply_supplier_catalog', 'supply_import_orders', 'supply_import_order_items', 'supply_dock_operations', 'supply_import_containers', 'supply_dock_worker_stats', 'supply_import_market_impact', 'supply_customs_documentation', 'supply_port_schedule')) as new_tables_created,
    'Ready for Docks Configuration Phase!' as next_step;

    
-- ===============================================
-- INSERT DEFAULT MARKET SETTINGS (OPTIONAL)
-- ===============================================

INSERT IGNORE INTO `supply_market_settings` (`ingredient`, `max_stock`, `min_stock_threshold`, `base_price`, `category`) VALUES
('reign_packed_groundchicken', 750, 50, 8.50, 'high_demand'),
('reign_packed_groundmeat', 750, 50, 8.00, 'high_demand');
('reign_packed_groundpork', 600, 40, 13.75, 'default'),
('reign_rawchicken', 500, 35, 8.50, 'default'),
('reign_rawbeef', 500, 35, 11.00, 'default'),
('reign_rawpork', 400, 30, 9.25, 'default'),
('reign_flour', 1000, 75, 3.50, 'high_demand'),
('reign_milk', 800, 60, 4.25, 'high_demand'),
('reign_cheese', 300, 25, 18.50, 'specialty'),
('reign_lettuce', 400, 30, 2.75, 'default'),
('reign_tomato', 400, 30, 3.25, 'default'),
('reign_potato', 600, 45, 2.50, 'default');

-- ===============================================
-- SAMPLE TEST DATA (OPTIONAL - UNCOMMENT IF NEEDED)
-- ===============================================

-- Insert sample stock alerts for testing
INSERT IGNORE INTO `supply_stock_alerts` (`ingredient`, `alert_level`, `current_stock`, `threshold_percentage`) VALUES
('reign_packed_groundchicken', 'low', 45, 18.5),
('reign_cheese', 'critical', 8, 4.2),
('reign_flour', 'moderate', 230, 35.8);

-- Insert sample market snapshot
INSERT IGNORE INTO `supply_market_snapshots` (`ingredient`, `base_price`, `multiplier`, `final_price`, `stock_level`) VALUES
('reign_packed_groundchicken', 12.50, 1.35, 16.88, 45),
('reign_flour', 3.50, 0.95, 3.33, 230),
('reign_cheese', 18.50, 2.10, 38.85, 8);

-- Add some initial warehouse stock
INSERT IGNORE INTO `supply_warehouse_stock` (`ingredient`, `quantity`) VALUES
('reign_packed_groundchicken', 245),
('reign_packed_groundmeat', 278);
('reign_flour', 230),
('reign_cheese', 8),
('reign_milk', 150),
('reign_lettuce', 95),
('reign_tomato', 82),
('reign_potato', 180);

-- ===============================================
-- COMPLETION MESSAGE
-- ===============================================

SELECT 'Supply Chain Database Reset Complete!' as message,
       (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'supply_%') as tables_created;