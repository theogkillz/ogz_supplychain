-- Creating the supply_orders table
CREATE TABLE IF NOT EXISTS `supply_orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `status` ENUM('pending','accepted','completed') DEFAULT 'pending',
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

