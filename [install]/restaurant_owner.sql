-- ===============================================
-- RESTAURANT OWNER SYSTEM - DATABASE SCHEMA
-- Extends OGZ-SupplyChain with ownership features
-- ===============================================

-- Restaurant Ownership Management
CREATE TABLE IF NOT EXISTS `supply_restaurant_ownership` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `owner_citizenid` varchar(50) NOT NULL,
  `owner_name` varchar(100) NOT NULL,
  `purchase_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `purchase_price` decimal(12,2) NOT NULL,
  `down_payment` decimal(10,2) NOT NULL,
  `monthly_payment` decimal(10,2) DEFAULT 0.00,
  `remaining_balance` decimal(12,2) DEFAULT 0.00,
  `financing_months` int(11) DEFAULT 0,
  `next_payment_due` date DEFAULT NULL,
  `ownership_type` enum('individual','partnership','corporation') DEFAULT 'individual',
  `business_license` varchar(50) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant` (`restaurant_id`),
  KEY `idx_owner_citizenid` (`owner_citizenid`),
  KEY `idx_next_payment` (`next_payment_due`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Staff Management
CREATE TABLE IF NOT EXISTS `supply_restaurant_staff` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `employee_citizenid` varchar(50) NOT NULL,
  `employee_name` varchar(100) NOT NULL,
  `position` enum('owner','manager','chef','cashier','server','cleaner') NOT NULL,
  `hourly_wage` decimal(8,2) DEFAULT 0.00,
  `permissions` json DEFAULT NULL,
  `hire_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint(1) DEFAULT 1,
  `on_duty` tinyint(1) DEFAULT 0,
  `total_hours_worked` decimal(8,2) DEFAULT 0.00,
  `performance_rating` decimal(3,2) DEFAULT 5.00,
  `hired_by` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_employee_restaurant` (`restaurant_id`, `employee_citizenid`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_employee_citizenid` (`employee_citizenid`),
  KEY `idx_position` (`position`),
  KEY `idx_on_duty` (`on_duty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Staff Time Tracking
CREATE TABLE IF NOT EXISTS `supply_staff_timesheets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `employee_citizenid` varchar(50) NOT NULL,
  `clock_in` timestamp DEFAULT CURRENT_TIMESTAMP,
  `clock_out` timestamp NULL DEFAULT NULL,
  `hours_worked` decimal(4,2) DEFAULT 0.00,
  `wage_earned` decimal(8,2) DEFAULT 0.00,
  `break_time` int(11) DEFAULT 0,
  `overtime_hours` decimal(4,2) DEFAULT 0.00,
  `date_worked` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_restaurant_employee` (`restaurant_id`, `employee_citizenid`),
  KEY `idx_date_worked` (`date_worked`),
  KEY `idx_clock_out` (`clock_out`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Sales & Register Transactions
CREATE TABLE IF NOT EXISTS `supply_restaurant_sales` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `employee_citizenid` varchar(50) NOT NULL,
  `customer_citizenid` varchar(50) DEFAULT NULL,
  `customer_name` varchar(100) DEFAULT 'Walk-in Customer',
  `transaction_id` varchar(100) NOT NULL,
  `items_sold` json NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  `tax_amount` decimal(8,2) DEFAULT 0.00,
  `total_amount` decimal(10,2) NOT NULL,
  `payment_method` enum('cash','card','bank') DEFAULT 'cash',
  `commission_rate` decimal(4,3) DEFAULT 0.150,
  `commission_amount` decimal(8,2) NOT NULL,
  `sale_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  `order_type` enum('dine_in','takeout','delivery','catering') DEFAULT 'dine_in',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_transaction` (`transaction_id`),
  KEY `idx_restaurant_date` (`restaurant_id`, `sale_date`),
  KEY `idx_employee_date` (`employee_citizenid`, `sale_date`),
  KEY `idx_customer` (`customer_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Financial Tracking (Daily Summary)
CREATE TABLE IF NOT EXISTS `supply_restaurant_finances` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `financial_date` date NOT NULL,
  `total_revenue` decimal(10,2) DEFAULT 0.00,
  `register_sales` decimal(10,2) DEFAULT 0.00,
  `delivery_revenue` decimal(10,2) DEFAULT 0.00,
  `catering_revenue` decimal(10,2) DEFAULT 0.00,
  `total_expenses` decimal(10,2) DEFAULT 0.00,
  `supply_costs` decimal(10,2) DEFAULT 0.00,
  `staff_wages` decimal(10,2) DEFAULT 0.00,
  `utilities` decimal(8,2) DEFAULT 0.00,
  `rent` decimal(8,2) DEFAULT 0.00,
  `maintenance` decimal(8,2) DEFAULT 0.00,
  `taxes` decimal(8,2) DEFAULT 0.00,
  `other_expenses` decimal(8,2) DEFAULT 0.00,
  `net_profit` decimal(10,2) DEFAULT 0.00,
  `commission_paid` decimal(8,2) DEFAULT 0.00,
  `customers_served` int(11) DEFAULT 0,
  `avg_order_value` decimal(8,2) DEFAULT 0.00,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_date` (`restaurant_id`, `financial_date`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_financial_date` (`financial_date`),
  KEY `idx_net_profit` (`net_profit`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Business Settings
CREATE TABLE IF NOT EXISTS `supply_restaurant_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `setting_category` varchar(50) NOT NULL,
  `setting_name` varchar(100) NOT NULL,
  `setting_value` text DEFAULT NULL,
  `setting_type` enum('string','number','boolean','json') DEFAULT 'string',
  `description` varchar(255) DEFAULT NULL,
  `updated_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_setting` (`restaurant_id`, `setting_category`, `setting_name`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_setting_category` (`setting_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Menu Management
CREATE TABLE IF NOT EXISTS `supply_restaurant_menu` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `item_category` varchar(50) NOT NULL,
  `base_price` decimal(8,2) NOT NULL,
  `current_price` decimal(8,2) NOT NULL,
  `ingredients_required` json DEFAULT NULL,
  `preparation_time` int(11) DEFAULT 300,
  `is_available` tinyint(1) DEFAULT 1,
  `daily_limit` int(11) DEFAULT NULL,
  `items_sold_today` int(11) DEFAULT 0,
  `profit_margin` decimal(5,2) DEFAULT 0.00,
  `popularity_score` decimal(4,2) DEFAULT 0.00,
  `created_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_item` (`restaurant_id`, `item_name`),
  KEY `idx_restaurant_category` (`restaurant_id`, `item_category`),
  KEY `idx_is_available` (`is_available`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Quality Standards (Integration with OGZ supply chain)
CREATE TABLE IF NOT EXISTS `supply_restaurant_quality_standards` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `ingredient` varchar(100) NOT NULL,
  `minimum_quality` enum('poor','fair','good','excellent') DEFAULT 'good',
  `preferred_supplier` varchar(100) DEFAULT NULL,
  `max_age_days` int(11) DEFAULT 7,
  `temperature_requirement` enum('frozen','refrigerated','room_temp','hot') DEFAULT 'refrigerated',
  `auto_reject_below_standard` tinyint(1) DEFAULT 0,
  `premium_bonus_rate` decimal(4,3) DEFAULT 0.000,
  `set_by` varchar(50) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_ingredient` (`restaurant_id`, `ingredient`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Analytics & Performance Metrics
CREATE TABLE IF NOT EXISTS `supply_restaurant_analytics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `metric_date` date NOT NULL,
  `metric_name` varchar(100) NOT NULL,
  `metric_value` decimal(12,4) NOT NULL,
  `metric_category` varchar(50) NOT NULL,
  `comparison_previous` decimal(12,4) DEFAULT NULL,
  `trend` enum('up','down','stable') DEFAULT 'stable',
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_metric_date` (`restaurant_id`, `metric_name`, `metric_date`),
  KEY `idx_metric_category` (`metric_category`),
  KEY `idx_metric_date` (`metric_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restaurant Supplier Relationships (Links to OGZ supply chain)
CREATE TABLE IF NOT EXISTS `supply_restaurant_suppliers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` int(11) NOT NULL,
  `supplier_name` varchar(100) NOT NULL,
  `supplier_type` enum('warehouse','specialty','emergency','premium') DEFAULT 'warehouse',
  `relationship_level` int(11) DEFAULT 1,
  `total_orders` int(11) DEFAULT 0,
  `total_spent` decimal(12,2) DEFAULT 0.00,
  `average_delivery_time` int(11) DEFAULT 1800,
  `quality_rating` decimal(3,2) DEFAULT 5.00,
  `discount_rate` decimal(4,3) DEFAULT 0.000,
  `payment_terms` varchar(100) DEFAULT 'immediate',
  `last_order_date` timestamp NULL DEFAULT NULL,
  `is_preferred` tinyint(1) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_restaurant_supplier` (`restaurant_id`, `supplier_name`),
  KEY `idx_restaurant_id` (`restaurant_id`),
  KEY `idx_relationship_level` (`relationship_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- ===============================================
-- INTEGRATION WITH EXISTING OGZ TABLES
-- ===============================================

-- Add restaurant ownership tracking to existing supply_orders
ALTER TABLE `supply_orders` 
ADD COLUMN `ordered_by_owner` tinyint(1) DEFAULT 0,
ADD COLUMN `owner_discount_applied` decimal(4,3) DEFAULT 0.000,
ADD COLUMN `priority_delivery` tinyint(1) DEFAULT 0,
ADD COLUMN `quality_standard_required` enum('poor','fair','good','excellent') DEFAULT NULL;

-- Add indexes for better performance
ALTER TABLE `supply_orders` 
ADD INDEX `idx_ordered_by_owner` (`ordered_by_owner`),
ADD INDEX `idx_priority_delivery` (`priority_delivery`);

-- Add restaurant revenue tracking to existing delivery logs
ALTER TABLE `supply_delivery_logs`
ADD COLUMN `delivery_for_owner` tinyint(1) DEFAULT 0,
ADD COLUMN `owner_business_expense` decimal(10,2) DEFAULT 0.00;

-- ===============================================
-- DEFAULT RESTAURANT SETTINGS
-- ===============================================

-- Insert default settings for all restaurants
INSERT IGNORE INTO `supply_restaurant_settings` (`restaurant_id`, `setting_category`, `setting_name`, `setting_value`, `setting_type`, `description`) VALUES
(1, 'business', 'commission_rate', '0.15', 'number', 'Commission rate for register sales'),
(1, 'business', 'daily_rent', '500', 'number', 'Daily rent/lease payment'),
(1, 'business', 'utility_cost', '200', 'number', 'Daily utility costs'),
(1, 'business', 'tax_rate', '0.08', 'number', 'Sales tax rate'),
(1, 'operations', 'max_staff', '8', 'number', 'Maximum staff members'),
(1, 'operations', 'auto_payroll', 'true', 'boolean', 'Automatic daily payroll'),
(1, 'quality', 'minimum_standard', 'good', 'string', 'Minimum ingredient quality'),
(1, 'quality', 'auto_reject', 'false', 'boolean', 'Auto-reject low quality deliveries');

-- Sample data for testing (OPTIONAL - remove in production)
INSERT IGNORE INTO `supply_restaurant_ownership` (`restaurant_id`, `owner_citizenid`, `owner_name`, `purchase_price`, `down_payment`, `remaining_balance`) VALUES
(1, 'TEST12345', 'Test Owner', 150000.00, 45000.00, 105000.00);

INSERT IGNORE INTO `supply_restaurant_staff` (`restaurant_id`, `employee_citizenid`, `employee_name`, `position`, `hourly_wage`, `permissions`) VALUES
(1, 'TEST12345', 'Test Owner', 'owner', 0.00, '["all"]'),
(1, 'MGR12345', 'Test Manager', 'manager', 25.00, '["hire","fire","reports","inventory"]');

-- ===============================================
-- USEFUL QUERIES FOR TESTING
-- ===============================================

-- Check restaurant ownership
SELECT ro.*, rs.setting_value as commission_rate 
FROM supply_restaurant_ownership ro
LEFT JOIN supply_restaurant_settings rs ON ro.restaurant_id = rs.restaurant_id 
AND rs.setting_name = 'commission_rate'
WHERE ro.is_active = 1;

-- Get restaurant financial summary
SELECT 
    restaurant_id,
    SUM(total_revenue) as total_revenue,
    SUM(total_expenses) as total_expenses,
    SUM(net_profit) as total_profit,
    AVG(customers_served) as avg_customers,
    AVG(avg_order_value) as avg_order_value
FROM supply_restaurant_finances 
WHERE financial_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY restaurant_id;

-- Get top performing staff
SELECT 
    rs.restaurant_id,
    rs.employee_name,
    rs.position,
    SUM(rst.hours_worked) as total_hours,
    SUM(rst.wage_earned) as total_earnings,
    AVG(rs.performance_rating) as avg_rating
FROM supply_restaurant_staff rs
JOIN supply_staff_timesheets rst ON rs.restaurant_id = rst.restaurant_id 
AND rs.employee_citizenid = rst.employee_citizenid
WHERE rs.is_active = 1
GROUP BY rs.restaurant_id, rs.employee_citizenid
ORDER BY total_earnings DESC;

-- ===============================================
-- COMPLETION MESSAGE
-- ===============================================

SELECT 
    'Restaurant Owner Database Schema Complete!' as message,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME LIKE 'supply_restaurant_%') as new_tables_created,
    'Ready for Configuration Phase!' as next_step;