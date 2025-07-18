-- ===============================================
-- SUPPLY CHAIN COMPLETE DATABASE RESET SCRIPT
-- ===============================================
-- This script will DROP all existing tables and recreate them fresh
-- Use with caution in production!

-- Disable foreign key checks temporarily
SET FOREIGN_KEY_CHECKS = 0;

-- ===============================================
-- DROP ALL EXISTING SUPPLY CHAIN TABLES
-- ===============================================

DROP TABLE IF EXISTS `supply_market_transactions`;
DROP TABLE IF EXISTS `supply_notification_preferences`;
DROP TABLE IF EXISTS `supply_market_notifications`;
DROP TABLE IF EXISTS `supply_demand_analysis`;
DROP TABLE IF EXISTS `supply_market_events`;
DROP TABLE IF EXISTS `supply_market_snapshots`;
DROP TABLE IF EXISTS `supply_market_settings`;
DROP TABLE IF EXISTS `supply_demand_forecasts`;
DROP TABLE IF EXISTS `supply_restock_suggestions`;
DROP TABLE IF EXISTS `supply_usage_analytics`;
DROP TABLE IF EXISTS `supply_stock_snapshots`;
DROP TABLE IF EXISTS `supply_stock_alerts`;
DROP TABLE IF EXISTS `supply_team_members`;
DROP TABLE IF EXISTS `supply_team_deliveries`;
DROP TABLE IF EXISTS `supply_daily_bonuses`;
DROP TABLE IF EXISTS `supply_reward_logs`;
DROP TABLE IF EXISTS `supply_driver_streaks`;
DROP TABLE IF EXISTS `supply_delivery_logs`;
DROP TABLE IF EXISTS `supply_achievements`;
DROP TABLE IF EXISTS `supply_driver_stats`;
DROP TABLE IF EXISTS `supply_leaderboard`;
DROP TABLE IF EXISTS `supply_emergency_orders`;
DROP TABLE IF EXISTS `supply_warehouse_stock`;
DROP TABLE IF EXISTS `supply_stock`;
DROP TABLE IF EXISTS `supply_orders`;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ===============================================
-- CREATE ALL TABLES FRESH
-- ===============================================

-- Core Orders Table
CREATE TABLE `supply_orders` (
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

-- Restaurant Stock Table
CREATE TABLE `supply_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_ingredient` (`restaurant_id`, `ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Warehouse Stock Table
CREATE TABLE `supply_warehouse_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Legacy Leaderboard Table (for compatibility)
CREATE TABLE `supply_leaderboard` (
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

-- Enhanced Driver Statistics Table
CREATE TABLE `supply_driver_stats` (
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

-- Achievements Table
CREATE TABLE `supply_achievements` (
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
CREATE TABLE `supply_delivery_logs` (
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

-- Driver Streak Tracking
CREATE TABLE `supply_driver_streaks` (
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

-- Reward Logs Table
CREATE TABLE `supply_reward_logs` (
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

-- Daily Bonus Tracking
CREATE TABLE `supply_daily_bonuses` (
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
CREATE TABLE `supply_team_deliveries` (
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

-- Team Delivery Members Tracking
CREATE TABLE `supply_team_members` (
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

-- Stock Alerts Table
CREATE TABLE `supply_stock_alerts` (
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

-- Usage Pattern Analytics
CREATE TABLE `supply_usage_analytics` (
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

-- Restock Recommendations Tracking
CREATE TABLE `supply_restock_suggestions` (
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
CREATE TABLE `supply_stock_snapshots` (
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

-- Demand Forecasting Data
CREATE TABLE `supply_demand_forecasts` (
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

-- Market Snapshots Table
CREATE TABLE `supply_market_snapshots` (
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

-- Market Events Tracking (shortages, surpluses, etc.)
CREATE TABLE `supply_market_events` (
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

-- Demand Analysis Data
CREATE TABLE `supply_demand_analysis` (
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
CREATE TABLE `supply_market_settings` (
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

-- Player Market Notifications Preferences
CREATE TABLE `supply_market_notifications` (
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

-- Market Transaction Logging Table
CREATE TABLE `supply_market_transactions` (
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

-- Notification Preferences
CREATE TABLE `supply_notification_preferences` (
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
CREATE TABLE `supply_emergency_orders` (
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