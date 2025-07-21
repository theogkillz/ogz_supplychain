-- sql/install.sql
-- OGz SupplyChain Master - Complete Database Schema
-- Version 2.0.0

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Orders table
CREATE TABLE IF NOT EXISTS `supply_orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner_id` VARCHAR(50) DEFAULT NULL,
  `ingredient` VARCHAR(100) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `status` ENUM('pending','accepted','in_progress','completed','cancelled','failed') DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `restaurant_id` INT(11) NOT NULL,
  `total_cost` DECIMAL(10,2) DEFAULT NULL,
  `order_group_id` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_order_group_id` (`order_group_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_restaurant_id` (`restaurant_id`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Restaurant stock
CREATE TABLE IF NOT EXISTS `supply_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(100) DEFAULT NULL,
  `quantity` INT(11) DEFAULT 0,
  `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_ingredient` (`restaurant_id`, `ingredient`),
  INDEX `idx_restaurant_id` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Warehouse stock
CREATE TABLE IF NOT EXISTS `supply_warehouse_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ingredient` VARCHAR(100) DEFAULT NULL,
  `quantity` INT(11) DEFAULT 0,
  `min_stock` INT(11) DEFAULT 25,
  `max_stock` INT(11) DEFAULT 1000,
  `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ingredient` (`ingredient`),
  INDEX `idx_quantity` (`quantity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- RESTAURANT TABLES
-- =====================================================

-- Restaurant owners
CREATE TABLE IF NOT EXISTS `supply_restaurant_owners` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) NOT NULL,
  `owner_citizenid` VARCHAR(50) NOT NULL,
  `purchase_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `purchase_price` DECIMAL(10,2) DEFAULT NULL,
  `is_active` BOOLEAN DEFAULT TRUE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_owner` (`restaurant_id`),
  INDEX `idx_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Restaurant statistics
CREATE TABLE IF NOT EXISTS `supply_restaurant_stats` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) NOT NULL,
  `total_orders` INT(11) DEFAULT 0,
  `total_revenue` DECIMAL(12,2) DEFAULT 0.00,
  `total_expenses` DECIMAL(12,2) DEFAULT 0.00,
  `last_order_date` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_stats` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- DELIVERY TABLES
-- =====================================================

-- Delivery records
CREATE TABLE IF NOT EXISTS `supply_deliveries` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `order_group_id` VARCHAR(50) NOT NULL,
  `player_id` VARCHAR(50) NOT NULL,
  `restaurant_id` INT(11) NOT NULL,
  `total_reward` DECIMAL(10,2) DEFAULT NULL,
  `delivery_time` INT(11) DEFAULT NULL COMMENT 'Time in seconds',
  `team_size` INT(11) DEFAULT 1,
  `quality_score` INT(11) DEFAULT 100,
  `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_player_id` (`player_id`),
  INDEX `idx_order_group` (`order_group_id`),
  INDEX `idx_completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Delivery logs
CREATE TABLE IF NOT EXISTS `supply_delivery_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `order_group_id` VARCHAR(50) NOT NULL,
  `player_id` VARCHAR(50) NOT NULL,
  `status` VARCHAR(50) DEFAULT NULL,
  `data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_order_group` (`order_group_id`),
  INDEX `idx_player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Driver statistics
CREATE TABLE IF NOT EXISTS `supply_driver_stats` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `deliveries` INT(11) DEFAULT 0,
  `earnings` DECIMAL(12,2) DEFAULT 0.00,
  `total_time` INT(11) DEFAULT 0 COMMENT 'Total delivery time in seconds',
  `average_time` INT(11) DEFAULT 0,
  `best_time` INT(11) DEFAULT NULL,
  `streak` INT(11) DEFAULT 0,
  `last_delivery` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_citizenid` (`citizenid`),
  INDEX `idx_deliveries` (`deliveries`),
  INDEX `idx_earnings` (`earnings`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- CONTAINER TABLES
-- =====================================================

-- Container registry
CREATE TABLE IF NOT EXISTS `supply_containers` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `container_id` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `status` ENUM('available','rented','in_use','in_transit','damaged','maintenance','retired') DEFAULT 'available',
  `current_quality` INT(11) DEFAULT 100,
  `location` VARCHAR(255) DEFAULT NULL,
  `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_container_id` (`container_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Container rentals
CREATE TABLE IF NOT EXISTS `supply_container_rentals` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `container_id` VARCHAR(50) NOT NULL,
  `renter_id` VARCHAR(50) NOT NULL,
  `rental_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `rental_end` TIMESTAMP NULL DEFAULT NULL,
  `rental_cost` DECIMAL(10,2) DEFAULT NULL,
  `deposit_amount` DECIMAL(10,2) DEFAULT NULL,
  `deposit_returned` BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (`id`),
  INDEX `idx_container` (`container_id`),
  INDEX `idx_renter` (`renter_id`),
  INDEX `idx_active` (`rental_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Container quality tracking
CREATE TABLE IF NOT EXISTS `supply_container_quality_tracking` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `container_id` VARCHAR(50) NOT NULL,
  `quality_before` INT(11) DEFAULT NULL,
  `quality_after` INT(11) DEFAULT NULL,
  `temperature_breach` BOOLEAN DEFAULT FALSE,
  `damage_incidents` INT(11) DEFAULT 0,
  `tracking_data` JSON DEFAULT NULL,
  `recorded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_container` (`container_id`),
  INDEX `idx_recorded_at` (`recorded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TEAM TABLES
-- =====================================================

-- Teams
CREATE TABLE IF NOT EXISTS `supply_teams` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `team_id` VARCHAR(50) NOT NULL,
  `leader_id` VARCHAR(50) NOT NULL,
  `order_group_id` VARCHAR(50) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `disbanded_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_team_id` (`team_id`),
  INDEX `idx_leader` (`leader_id`),
  INDEX `idx_order_group` (`order_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Team members
CREATE TABLE IF NOT EXISTS `supply_team_members` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `team_id` VARCHAR(50) NOT NULL,
  `player_id` VARCHAR(50) NOT NULL,
  `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `left_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_team` (`team_id`),
  INDEX `idx_player` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Team deliveries
CREATE TABLE IF NOT EXISTS `supply_team_deliveries` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `team_id` VARCHAR(50) NOT NULL,
  `order_group_id` VARCHAR(50) NOT NULL,
  `total_reward` DECIMAL(10,2) DEFAULT NULL,
  `member_count` INT(11) DEFAULT NULL,
  `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_team` (`team_id`),
  INDEX `idx_order_group` (`order_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- ECONOMIC TABLES
-- =====================================================

-- Market history
CREATE TABLE IF NOT EXISTS `supply_market_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `item` VARCHAR(100) NOT NULL,
  `base_price` DECIMAL(10,2) DEFAULT NULL,
  `market_price` DECIMAL(10,2) DEFAULT NULL,
  `supply_level` INT(11) DEFAULT NULL,
  `demand_level` INT(11) DEFAULT NULL,
  `price_multiplier` DECIMAL(5,3) DEFAULT 1.000,
  `recorded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_item` (`item`),
  INDEX `idx_recorded_at` (`recorded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Price history (24-hour rolling)
CREATE TABLE IF NOT EXISTS `supply_price_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `item` VARCHAR(100) NOT NULL,
  `price` DECIMAL(10,2) DEFAULT NULL,
  `recorded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_item_time` (`item`, `recorded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions
CREATE TABLE IF NOT EXISTS `supply_transactions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `player_id` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `amount` DECIMAL(10,2) DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_player` (`player_id`),
  INDEX `idx_type` (`type`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- ANALYTICS TABLES
-- =====================================================

-- Leaderboard
CREATE TABLE IF NOT EXISTS `supply_leaderboard` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `deliveries` INT(11) DEFAULT 0,
  `earnings` DECIMAL(12,2) DEFAULT 0.00,
  `average_time` INT(11) DEFAULT NULL,
  `best_time` INT(11) DEFAULT NULL,
  `streak` INT(11) DEFAULT 0,
  `rank` INT(11) DEFAULT NULL,
  `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_citizenid` (`citizenid`),
  INDEX `idx_deliveries` (`deliveries`),
  INDEX `idx_earnings` (`earnings`),
  INDEX `idx_rank` (`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Player statistics
CREATE TABLE IF NOT EXISTS `supply_player_stats` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `experience` INT(11) DEFAULT 0,
  `level` INT(11) DEFAULT 1,
  `total_deliveries` INT(11) DEFAULT 0,
  `solo_deliveries` INT(11) DEFAULT 0,
  `team_deliveries` INT(11) DEFAULT 0,
  `perfect_deliveries` INT(11) DEFAULT 0,
  `containers_used` INT(11) DEFAULT 0,
  `distance_traveled` DECIMAL(10,2) DEFAULT 0.00,
  `last_activity` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_citizenid` (`citizenid`),
  INDEX `idx_level` (`level`),
  INDEX `idx_experience` (`experience`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Achievements
CREATE TABLE IF NOT EXISTS `supply_achievements` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `achievement_id` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `category` VARCHAR(50) DEFAULT NULL,
  `reward_cash` INT(11) DEFAULT 0,
  `reward_xp` INT(11) DEFAULT 0,
  `requirement` JSON DEFAULT NULL,
  `icon` VARCHAR(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_achievement_id` (`achievement_id`),
  INDEX `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Player achievements
CREATE TABLE IF NOT EXISTS `supply_player_achievements` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `achievement_id` VARCHAR(50) NOT NULL,
  `unlocked_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `progress` INT(11) DEFAULT 0,
  `claimed` BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_achievement` (`citizenid`, `achievement_id`),
  INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- SYSTEM TABLES
-- =====================================================

-- Emergency orders
CREATE TABLE IF NOT EXISTS `supply_emergency_orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `order_id` VARCHAR(50) NOT NULL,
  `ingredient` VARCHAR(100) NOT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `priority` INT(11) DEFAULT 1,
  `reward_multiplier` DECIMAL(5,2) DEFAULT 1.00,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `accepted_by` VARCHAR(50) DEFAULT NULL,
  `completed` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_id` (`order_id`),
  INDEX `idx_priority` (`priority`),
  INDEX `idx_expires` (`expires_at`),
  INDEX `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Stock alerts
CREATE TABLE IF NOT EXISTS `supply_stock_alerts` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ingredient` VARCHAR(100) NOT NULL,
  `alert_type` ENUM('low','critical','stockout') DEFAULT NULL,
  `current_stock` INT(11) DEFAULT NULL,
  `threshold` INT(11) DEFAULT NULL,
  `alerted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `resolved` BOOLEAN DEFAULT FALSE,
  `resolved_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_ingredient` (`ingredient`),
  INDEX `idx_alert_type` (`alert_type`),
  INDEX `idx_resolved` (`resolved`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- System logs
CREATE TABLE IF NOT EXISTS `supply_system_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `player_id` VARCHAR(50) DEFAULT NULL,
  `action` VARCHAR(100) NOT NULL,
  `data` JSON DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_player` (`player_id`),
  INDEX `idx_action` (`action`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- FUTURE TABLES (Placeholders)
-- =====================================================

-- Manufacturing facilities
CREATE TABLE IF NOT EXISTS `supply_manufacturing_facilities` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `facility_id` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `location` VARCHAR(255) DEFAULT NULL,
  `type` VARCHAR(50) DEFAULT NULL,
  `capacity` INT(11) DEFAULT NULL,
  `efficiency` DECIMAL(5,2) DEFAULT 1.00,
  `active` BOOLEAN DEFAULT TRUE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_facility_id` (`facility_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dock imports
CREATE TABLE IF NOT EXISTS `supply_dock_imports` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `shipment_id` VARCHAR(50) NOT NULL,
  `origin` VARCHAR(100) DEFAULT NULL,
  `cargo_type` VARCHAR(50) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `arrival_date` TIMESTAMP NULL DEFAULT NULL,
  `processed` BOOLEAN DEFAULT FALSE,
  `processed_by` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shipment_id` (`shipment_id`),
  INDEX `idx_arrival_date` (`arrival_date`),
  INDEX `idx_processed` (`processed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- DEFAULT DATA
-- =====================================================

-- Insert default warehouse stock
-- INSERT IGNORE INTO `supply_warehouse_stock` (`ingredient`, `quantity`, `min_stock`, `max_stock`) VALUES
-- ('bun', 500, 50, 1000),
-- ('patty', 300, 50, 800),
-- ('lettuce', 200, 25, 500),
-- ('cheese', 150, 25, 400),
-- ('tomato', 100, 25, 300),
-- ('onion', 100, 25, 300),
-- ('pickle', 150, 25, 400),
-- ('bacon', 100, 25, 300),
-- ('chicken', 200, 50, 500),
-- ('fish', 100, 25, 300),
-- ('potato', 300, 50, 800),
-- ('oil', 100, 25, 300),
-- ('salt', 200, 25, 500),
-- ('pepper', 200, 25, 500),
-- ('sauce', 150, 25, 400);

-- -- Insert default achievements
-- INSERT IGNORE INTO `supply_achievements` (`achievement_id`, `name`, `description`, `category`, `reward_cash`, `reward_xp`) VALUES
-- ('first_delivery', 'First Steps', 'Complete your first delivery', 'delivery', 100, 10),
-- ('delivery_10', 'Regular Driver', 'Complete 10 deliveries', 'delivery', 250, 25),
-- ('delivery_50', 'Experienced Driver', 'Complete 50 deliveries', 'delivery', 500, 50),
-- ('delivery_100', 'Professional Driver', 'Complete 100 deliveries', 'delivery', 1000, 100),
-- ('speed_demon', 'Speed Demon', 'Complete a delivery in under 5 minutes', 'speed', 500, 50),
-- ('team_player', 'Team Player', 'Complete 10 team deliveries', 'team', 500, 50),
-- ('perfectionist', 'Perfectionist', 'Complete 10 deliveries with 100% quality', 'quality', 1000, 100);

-- -- =====================================================
-- -- CLEANUP OLD DATA (Optional)
-- -- =====================================================

-- -- Remove old price history (older than 7 days)
-- DELETE FROM `supply_price_history` WHERE `recorded_at` < DATE_SUB(NOW(), INTERVAL 7 DAY);

-- -- Remove old delivery logs (older than 30 days)
-- DELETE FROM `supply_delivery_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- -- Remove old system logs (older than 90 days)
-- DELETE FROM `supply_system_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 90 DAY);