-- ============================================
-- DYNAMIC CONTAINER SYSTEM - DATABASE SCHEMA
-- The most advanced container tracking system in FiveM
-- ============================================

-- Main container tracking table
CREATE TABLE IF NOT EXISTS supply_containers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    container_id VARCHAR(100) UNIQUE NOT NULL, -- Unique container identifier
    container_type VARCHAR(50) NOT NULL,        -- ogz_cooler, ogz_crate, etc.
    contents_item VARCHAR(100) NOT NULL,        -- What ingredient is inside
    contents_amount INT NOT NULL,               -- How many items (max 12)
    quality_level DECIMAL(5,2) DEFAULT 100.00,  -- Quality percentage (100% = perfect)
    
    -- Order tracking
    order_group_id VARCHAR(100) NOT NULL,
    restaurant_id INT NOT NULL,
    
    -- Timestamps (using BIGINT for GetGameTimer compatibility)
    filled_timestamp BIGINT NOT NULL,
    expiration_timestamp BIGINT,
    delivered_timestamp BIGINT DEFAULT 0,
    opened_timestamp BIGINT DEFAULT 0,
    
    -- Container status tracking
    status ENUM('filled', 'loaded', 'in_transit', 'delivered', 'opened', 'empty') DEFAULT 'filled',
    current_location VARCHAR(100) DEFAULT 'warehouse',
    
    -- Quality factors
    temperature_maintained BOOLEAN DEFAULT TRUE,
    handling_care_level INT DEFAULT 100, -- 0-100, affects quality
    preservation_bonus DECIMAL(3,2) DEFAULT 1.00,
    
    -- Advanced metadata (JSON for flexibility)
    metadata JSON,
    
    -- Tracking fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    INDEX idx_order_group (order_group_id),
    INDEX idx_restaurant (restaurant_id),
    INDEX idx_status (status),
    INDEX idx_container_type (container_type),
    INDEX idx_contents (contents_item)
);

-- Container type definitions and availability
CREATE TABLE IF NOT EXISTS supply_container_inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    container_type VARCHAR(50) NOT NULL,
    available_quantity INT DEFAULT 0,
    total_capacity INT DEFAULT 0,
    cost_per_unit DECIMAL(8,2) DEFAULT 0.00,
    
    -- Container specifications
    max_item_capacity INT DEFAULT 12,
    suitable_categories JSON, -- ["meat", "dairy", "vegetables"]
    preservation_multiplier DECIMAL(3,2) DEFAULT 1.00,
    temperature_controlled BOOLEAN DEFAULT FALSE,
    
    -- Restock information
    reorder_threshold INT DEFAULT 10,
    last_restocked TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_container_type (container_type)
);

-- Container quality tracking
CREATE TABLE IF NOT EXISTS supply_container_quality_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    container_id VARCHAR(100) NOT NULL,
    quality_check_timestamp BIGINT NOT NULL,
    quality_before DECIMAL(5,2),
    quality_after DECIMAL(5,2),
    degradation_factor VARCHAR(50), -- 'temperature', 'time', 'handling', 'transport'
    notes TEXT,
    
    FOREIGN KEY (container_id) REFERENCES supply_containers(container_id) ON DELETE CASCADE,
    INDEX idx_container_quality (container_id),
    INDEX idx_timestamp (quality_check_timestamp)
);

-- Restaurant container usage analytics
CREATE TABLE IF NOT EXISTS supply_container_usage_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    restaurant_id INT NOT NULL,
    container_type VARCHAR(50) NOT NULL,
    ingredient VARCHAR(100) NOT NULL,
    
    -- Usage metrics
    total_containers_used INT DEFAULT 0,
    average_quality_received DECIMAL(5,2) DEFAULT 100.00,
    average_delivery_time BIGINT DEFAULT 0,
    
    -- Efficiency metrics
    containers_opened_fresh INT DEFAULT 0, -- Quality > 90%
    containers_opened_degraded INT DEFAULT 0, -- Quality < 70%
    total_waste_amount INT DEFAULT 0,
    
    -- Date tracking
    stat_date DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_restaurant_container_date (restaurant_id, container_type, ingredient, stat_date),
    INDEX idx_restaurant_stats (restaurant_id),
    INDEX idx_stat_date (stat_date)
);

-- Container alerts and notifications
CREATE TABLE IF NOT EXISTS supply_container_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    container_id VARCHAR(100),
    alert_type ENUM('expiring', 'degraded', 'temperature_breach', 'overdue', 'quality_critical') NOT NULL,
    alert_level ENUM('info', 'warning', 'critical') DEFAULT 'warning',
    
    message TEXT NOT NULL,
    restaurant_id INT,
    driver_id INT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by INT,
    acknowledged_at TIMESTAMP NULL,
    
    FOREIGN KEY (container_id) REFERENCES supply_containers(container_id) ON DELETE CASCADE,
    INDEX idx_alert_type (alert_type),
    INDEX idx_alert_level (alert_level),
    INDEX idx_restaurant_alerts (restaurant_id)
);

-- ============================================
-- INITIAL DATA - CONTAINER TYPES & INVENTORY
-- ============================================

INSERT INTO supply_container_inventory (
    container_type, available_quantity, total_capacity, cost_per_unit,
    max_item_capacity, suitable_categories, preservation_multiplier, temperature_controlled
) VALUES 
    ('ogz_cooler', 100, 200, 25.00, 12, '["meat", "dairy", "frozen", "seafood"]', 1.50, TRUE),
    ('ogz_crate', 150, 300, 15.00, 12, '["vegetables", "fruits", "dry_goods", "spices"]', 1.00, FALSE),
    ('ogz_thermal', 50, 100, 35.00, 12, '["hot_food", "cooked_items", "prepared_meals"]', 2.00, TRUE),
    ('ogz_freezer', 30, 60, 45.00, 12, '["frozen_goods", "ice_cream", "frozen_meat"]', 3.00, TRUE),
    ('ogz_produce', 120, 250, 18.00, 12, '["fresh_vegetables", "fresh_fruits", "herbs"]', 1.25, FALSE),
    ('ogz_bulk', 80, 150, 12.00, 12, '["grains", "flour", "sugar", "bulk_items"]', 0.80, FALSE)
ON DUPLICATE KEY UPDATE 
    available_quantity = VALUES(available_quantity),
    cost_per_unit = VALUES(cost_per_unit);

-- ============================================
-- ADVANCED INDEXES FOR PERFORMANCE
-- ============================================

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_container_status_restaurant ON supply_containers(status, restaurant_id);
CREATE INDEX IF NOT EXISTS idx_container_expiration ON supply_containers(expiration_timestamp, status);
CREATE INDEX IF NOT EXISTS idx_container_delivery_tracking ON supply_containers(order_group_id, status, filled_timestamp);
CREATE INDEX IF NOT EXISTS idx_quality_degradation ON supply_containers(quality_level, container_type, filled_timestamp);

-- Full-text search for container metadata (MySQL 5.7+)
-- ALTER TABLE supply_containers ADD FULLTEXT(metadata);

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- Active containers in transit
CREATE OR REPLACE VIEW active_containers_in_transit AS
SELECT 
    c.*,
    ci.preservation_multiplier,
    ci.temperature_controlled,
    r.name as restaurant_name
FROM supply_containers c
JOIN supply_container_inventory ci ON c.container_type = ci.container_type
LEFT JOIN (
    SELECT 
        1 as restaurant_id, 'Burger Shot' as name UNION ALL
    SELECT 
        2 as restaurant_id, 'Pizza This' as name UNION ALL
    SELECT 
        3 as restaurant_id, 'Taco Bomb' as name
) r ON c.restaurant_id = r.restaurant_id
WHERE c.status IN ('filled', 'loaded', 'in_transit');

-- Container quality summary by restaurant
CREATE OR REPLACE VIEW container_quality_summary AS
SELECT 
    restaurant_id,
    container_type,
    contents_item,
    COUNT(*) as total_containers,
    AVG(quality_level) as avg_quality,
    MIN(quality_level) as min_quality,
    MAX(quality_level) as max_quality,
    SUM(CASE WHEN quality_level < 70 THEN 1 ELSE 0 END) as degraded_containers,
    DATE(FROM_UNIXTIME(filled_timestamp/1000)) as fill_date
FROM supply_containers 
WHERE status IN ('delivered', 'opened')
GROUP BY restaurant_id, container_type, contents_item, DATE(FROM_UNIXTIME(filled_timestamp/1000));

-- ============================================
-- STORED PROCEDURES FOR COMMON OPERATIONS
-- ============================================

DELIMITER //

-- Procedure to create a new container
CREATE PROCEDURE IF NOT EXISTS CreateContainer(
    IN p_container_type VARCHAR(50),
    IN p_contents_item VARCHAR(100),
    IN p_contents_amount INT,
    IN p_order_group_id VARCHAR(100),
    IN p_restaurant_id INT,
    OUT p_container_id VARCHAR(100)
)
BEGIN
    DECLARE container_capacity INT DEFAULT 12;
    DECLARE container_available INT DEFAULT 0;
    
    -- Generate unique container ID
    SET p_container_id = CONCAT(p_container_type, '_', UNIX_TIMESTAMP(), '_', FLOOR(RAND() * 10000));
    
    -- Check container availability
    SELECT available_quantity INTO container_available 
    FROM supply_container_inventory 
    WHERE container_type = p_container_type;
    
    IF container_available > 0 THEN
        -- Create the container
        INSERT INTO supply_containers (
            container_id, container_type, contents_item, contents_amount,
            order_group_id, restaurant_id, filled_timestamp, 
            expiration_timestamp, status, current_location
        ) VALUES (
            p_container_id, p_container_type, p_contents_item, 
            LEAST(p_contents_amount, container_capacity),
            p_order_group_id, p_restaurant_id, 
            UNIX_TIMESTAMP() * 1000,
            (UNIX_TIMESTAMP() + 86400) * 1000, -- 24 hour expiration
            'filled', 'warehouse'
        );
        
        -- Update container inventory
        UPDATE supply_container_inventory 
        SET available_quantity = available_quantity - 1 
        WHERE container_type = p_container_type;
    ELSE
        SET p_container_id = NULL;
    END IF;
END //

-- Procedure to update container quality
CREATE PROCEDURE IF NOT EXISTS UpdateContainerQuality(
    IN p_container_id VARCHAR(100),
    IN p_degradation_factor VARCHAR(50)
)
BEGIN
    DECLARE current_quality DECIMAL(5,2);
    DECLARE new_quality DECIMAL(5,2);
    DECLARE degradation_rate DECIMAL(3,2) DEFAULT 0.05; -- 5% degradation
    
    SELECT quality_level INTO current_quality 
    FROM supply_containers 
    WHERE container_id = p_container_id;
    
    -- Calculate degradation based on factor
    CASE p_degradation_factor
        WHEN 'temperature' THEN SET degradation_rate = 0.15;
        WHEN 'time' THEN SET degradation_rate = 0.05;
        WHEN 'handling' THEN SET degradation_rate = 0.10;
        WHEN 'transport' THEN SET degradation_rate = 0.03;
        ELSE SET degradation_rate = 0.05;
    END CASE;
    
    SET new_quality = GREATEST(0, current_quality - (current_quality * degradation_rate));
    
    -- Update container quality
    UPDATE supply_containers 
    SET quality_level = new_quality, 
        updated_at = CURRENT_TIMESTAMP
    WHERE container_id = p_container_id;
    
    -- Log quality change
    INSERT INTO supply_container_quality_log (
        container_id, quality_check_timestamp, quality_before, 
        quality_after, degradation_factor
    ) VALUES (
        p_container_id, UNIX_TIMESTAMP() * 1000, 
        current_quality, new_quality, p_degradation_factor
    );
    
    -- Create alert if quality is critical
    IF new_quality < 30 THEN
        INSERT INTO supply_container_alerts (
            container_id, alert_type, alert_level, message
        ) VALUES (
            p_container_id, 'quality_critical', 'critical',
            CONCAT('Container quality critically low: ', new_quality, '%')
        );
    END IF;
END //

DELIMITER ;

-- ============================================
-- CLEANUP PROCEDURES
-- ============================================

-- Event to clean up old container data (run daily)
CREATE EVENT IF NOT EXISTS cleanup_old_containers
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- Delete containers older than 30 days
    DELETE FROM supply_containers 
    WHERE status = 'opened' 
    AND opened_timestamp < (UNIX_TIMESTAMP() - (30 * 24 * 3600)) * 1000;
    
    -- Delete old quality logs (keep 90 days)
    DELETE FROM supply_container_quality_log 
    WHERE quality_check_timestamp < (UNIX_TIMESTAMP() - (90 * 24 * 3600)) * 1000;
    
    -- Archive old usage stats (keep 1 year)
    DELETE FROM supply_container_usage_stats 
    WHERE stat_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);
END;

-- Enable event scheduler
SET GLOBAL event_scheduler = ON;