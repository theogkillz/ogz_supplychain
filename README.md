# 🚀 **DYNAMIC CONTAINER SYSTEM - COMPLETE INSTALLATION GUIDE**

## **THE MOST ADVANCED CONTAINER LOGISTICS SYSTEM FOR FIVEM**

---

## 📋 **TABLE OF CONTENTS**

1. [Prerequisites](#prerequisites)
2. [File Installation](#file-installation)
3. [Database Setup](#database-setup)
4. [Configuration](#configuration)
5. [Integration Steps](#integration-steps)
6. [Testing & Verification](#testing--verification)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

---

## 🔧 **PREREQUISITES**

### **Required Dependencies:**
- ✅ **QBox Framework** (Latest version)
- ✅ **MySQL Database** (Version 5.7+ or 8.0+)
- ✅ **ox_inventory** (Inventory system)
- ✅ **ox_lib** (UI Library)
- ✅ **qb-vehiclekeys** (Optional - for vehicle key system)
- ✅ **cdn-fuel** (Optional - for fuel system)

### **Server Requirements:**
- 🖥️ **RAM:** Minimum 4GB (8GB+ recommended)
- 💾 **Storage:** 500MB free space
- 🌐 **MySQL:** Dedicated database or shared with sufficient space
- ⚡ **Performance:** Medium to high-performance server

### **Existing System Requirements:**
- 📦 Working supply chain system (restaurant ordering, warehouse, delivery)
- 🎯 Restaurant system with job-based access
- 💰 Economy system (QBCore banking)
- 📱 Notification system (ox_lib)

---

## 📁 **FILE INSTALLATION**

### **Step 1: Download and Extract Files**

Create the following file structure in your resource:

```
your-supply-resource/
├── server/
│   ├── sv_containers_dynamic.lua          # Core container system
│   ├── sv_admin_containers.lua            # Admin tools
│   ├── sv_rewards_containers.lua          # Enhanced rewards
│   ├── integration_warehouse_containers.lua # Warehouse integration
│   └── integration_restaurant_containers.lua # Restaurant integration
├── client/
│   ├── cl_containers_dynamic.lua          # Container UI
│   └── cl_vehicle_containers.lua          # Vehicle system
├── config/
│   └── config_containers.lua              # Container configuration
└── sql/
    └── container_migration.sql            # Database setup
```

### **Step 2: Add Files to Resource**

**Add to your `fxmanifest.lua`:**

```lua
-- Container System Files
server_scripts {
    -- Existing server files...
    'server/sv_containers_dynamic.lua',
    'server/sv_admin_containers.lua', 
    'server/sv_rewards_containers.lua',
    'server/integration_warehouse_containers.lua',
    'server/integration_restaurant_containers.lua',
}

client_scripts {
    -- Existing client files...
    'client/cl_containers_dynamic.lua',
    'client/cl_vehicle_containers.lua',
}

shared_scripts {
    -- Existing shared files...
    'config/config_containers.lua',
}
```

### **Step 3: Copy Configuration**

Create `config/config_containers.lua` and copy the container configuration from the artifacts above.

---

## 🗄️ **DATABASE SETUP**

### **Step 1: Backup Your Database**
```sql
-- Create backup before migration
mysqldump -u username -p your_database > backup_before_containers.sql
```

### **Step 2: Run Migration Script**

Execute the complete migration script:

```bash
# Method 1: MySQL Command Line
mysql -u username -p your_database < container_migration.sql

# Method 2: phpMyAdmin
# Import the container_migration.sql file through the Import tab

# Method 3: HeidiSQL/MySQL Workbench
# Open and execute the migration script
```

### **Step 3: Verify Database Setup**

Run this query to verify installation:

```sql
-- Check if all tables were created
SELECT TABLE_NAME, TABLE_ROWS 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'your_database' 
AND TABLE_NAME LIKE 'supply_container%';

-- Should return:
-- supply_containers
-- supply_container_inventory  
-- supply_container_quality_log
-- supply_container_usage_stats
-- supply_container_alerts
-- supply_container_quality_tracking
```

---

## ⚙️ **CONFIGURATION**

### **Step 1: Basic Configuration**

Edit `config/config_containers.lua`:

```lua
Config.DynamicContainers = {
    enabled = true,  -- Enable/disable the entire system
    
    system = {
        maxItemsPerContainer = 12,  -- NEVER change this
        qualityDegradationEnabled = true,
        temperatureTrackingEnabled = true,
        expirationSystem = true,
    },
    
    -- Configure for your server economy
    containerTypes = {
        ["ogz_cooler"] = {
            cost = 25,  -- Adjust for your economy
            -- ... other settings
        },
        -- ... configure each container type
    }
}
```

### **Step 2: Economy Balance**

Adjust costs for your server economy:

```lua
-- In your main config file, add:
Config.EconomyBalance = {
    minimumDeliveryPay = 500,        -- Minimum pay per delivery
    basePayPerBox = 100,             -- Pay per container/box
    maximumDeliveryPay = 5000,       -- Maximum pay (anti-exploit)
}
```

### **Step 3: Restaurant Integration**

Ensure your restaurants are properly configured:

```lua
Config.Restaurants = {
    [1] = {
        name = "Burger Shot",
        job = "burgershot",
        coords = vector3(-1194.99, -906.18, 13.99),
        -- ... other settings
    },
    -- ... add all your restaurants
}
```

---

## 🔗 **INTEGRATION STEPS**

### **Step 1: Integrate with Existing Warehouse System**

**In your existing `sv_warehouse.lua`, add:**

```lua
-- At the top of the file
local containerSystemEnabled = Config.DynamicContainers and Config.DynamicContainers.enabled

-- Replace your existing acceptOrder event with:
RegisterNetEvent('warehouse:acceptOrder')
AddEventHandler('warehouse:acceptOrder', function(orderGroupId, restaurantId)
    if containerSystemEnabled then
        -- Use container-enhanced system
        TriggerEvent('warehouse:acceptOrderWithContainers', orderGroupId, restaurantId)
    else
        -- Use original system (your existing code)
        -- ... your original code here
    end
end)
```

### **Step 2: Integrate with Restaurant System**

**In your existing `sv_restaurant.lua`, add:**

```lua
-- Replace your existing order event with:
RegisterNetEvent('restaurant:orderIngredients') 
AddEventHandler('restaurant:orderIngredients', function(orderItems, restaurantId)
    local useContainers = Config.DynamicContainers and Config.DynamicContainers.enabled
    
    if useContainers then
        -- Use container system
        TriggerEvent('restaurant:orderIngredientsWithContainers', orderItems, restaurantId, true)
    else
        -- Use original system (your existing code)
        -- ... your original code here
    end
end)
```

### **Step 3: Integrate with Reward System**

**In your existing `sv_rewards.lua`, add:**

```lua
-- Replace your existing reward calculation event with:
RegisterNetEvent('rewards:calculateDeliveryReward')
AddEventHandler('rewards:calculateDeliveryReward', function(playerId, deliveryData)
    if deliveryData.containerDelivery then
        -- Use container-enhanced rewards
        TriggerEvent('rewards:calculateDeliveryRewardWithContainers', playerId, deliveryData)
    else
        -- Use original system (your existing function)
        -- ... your original code here
    end
end)
```

### **Step 4: Update Client-Side Vehicle System**

**In your vehicle spawning system, add:**

```lua
-- Instead of TriggerClientEvent('warehouse:spawnVehicles', ...)
-- Use: TriggerClientEvent('warehouse:spawnVehiclesWithContainers', ...)

-- This will enable container tracking and quality monitoring
```

---

## ✅ **TESTING & VERIFICATION**

### **Step 1: Basic System Test**

1. **Restart your server**
2. **Check console for errors** (should see "Container system initialized")
3. **Test admin commands**:
   ```
   /containerstatus
   /testcontainer ogz_crate tomato 10 1
   ```

### **Step 2: Functional Testing**

**Test Container Creation:**
```lua
-- As restaurant owner/manager:
1. Go to restaurant ordering system
2. Select ingredients 
3. Choose "Use Container System" option
4. Place order
5. Check if containers appear in warehouse
```

**Test Delivery System:**
```lua
-- As warehouse worker:
1. Accept container order
2. Spawn delivery vehicle
3. Drive to restaurant (carefully!)
4. Check container quality during delivery
5. Complete delivery
```

**Test Restaurant Container Opening:**
```lua
-- As restaurant employee:
1. Use command: /opencontainers
2. View delivered containers
3. Open containers individually or in bulk
4. Verify items added to inventory
```

### **Step 3: Performance Testing**

Monitor these metrics:
- ✅ Server performance (should not exceed 2ms additional processing)
- ✅ Database queries (check for slow queries)
- ✅ Memory usage (monitor for memory leaks)

### **Step 4: Integration Testing**

Test all integrated systems:
- ✅ Restaurant ordering works with containers
- ✅ Warehouse accepts container orders
- ✅ Delivery vehicles spawn correctly
- ✅ Quality tracking works during transport
- ✅ Rewards calculate container bonuses
- ✅ Admin commands function properly

---

## 🔧 **TROUBLESHOOTING**

### **Common Issues & Solutions**

#### **🚨 Issue: "Container system failed to initialize"**
**Solution:**
```lua
-- Check config file syntax
-- Verify Config.DynamicContainers.enabled = true
-- Check server console for specific error messages
```

#### **🚨 Issue: "No containers available"**
**Solution:**
```sql
-- Check container inventory
SELECT * FROM supply_container_inventory;

-- If empty, run the migration script again
-- Or manually restock:
/emergencyrestock ogz_crate 100
```

#### **🚨 Issue: "Container quality not updating"**
**Solution:**
```lua
-- Check if quality degradation is enabled
Config.DynamicContainers.system.qualityDegradationEnabled = true

-- Verify database tables exist:
SHOW TABLES LIKE 'supply_container%';
```

#### **🚨 Issue: "Restaurant employees can't open containers"**
**Solution:**
```lua
-- Verify restaurant job configuration
-- Check Config.Restaurants table
-- Ensure restaurant IDs match between config and database
```

#### **🚨 Issue: "Delivery vehicles not spawning"**
**Solution:**
```lua
-- Check vehicle models exist in your server
-- Verify spawn locations are clear
-- Check qb-vehiclekeys integration
```

### **Performance Issues**

#### **Slow Database Queries:**
```sql
-- Add missing indexes
ALTER TABLE supply_containers ADD INDEX idx_performance (status, restaurant_id, filled_timestamp);

-- Optimize tables
OPTIMIZE TABLE supply_containers;
ANALYZE TABLE supply_containers;
```

#### **High Memory Usage:**
```lua
-- Increase cleanup frequency in config
-- Check for memory leaks in container tracking threads
-- Monitor active container count
```

### **Debug Commands**

Use these commands for debugging:

```lua
-- Check container system status
/containerstatus

-- Search specific containers  
/searchcontainer order_12345

-- Test container creation
/testcontainer ogz_cooler milk 8 1

-- Check player permissions
/supplytest

-- View container analytics
/containeranalytics 7d
```

---

## 🔬 **ADVANCED CONFIGURATION**

### **Custom Container Types**

Add your own container types:

```lua
Config.DynamicContainers.containerTypes["custom_container"] = {
    name = "Custom Container",
    item = "custom_container",  -- Must exist in ox_inventory
    maxCapacity = 12,
    cost = 30,
    suitableCategories = {"custom_items"},
    preservationMultiplier = 1.3,
    temperatureControlled = false,
    -- ... other properties
}
```

### **Custom Quality Degradation**

Configure degradation rates:

```lua
Config.DynamicContainers.system.degradationRates = {
    base = 0.02,        -- 2% per hour base rate
    temperature = 0.15, -- 15% if temperature fails
    handling = 0.05,    -- 5% for rough handling  
    transport = 0.01,   -- 1% during transport
    time = 0.03        -- 3% natural aging
}
```

### **Custom Reward Bonuses**

Adjust container-specific bonuses:

```lua
Config.DynamicContainers.integration.rewards = {
    qualityBonuses = {
        excellent = 1.15,  -- 15% bonus for excellent quality
        good = 1.05,       -- 5% bonus for good quality
        fair = 1.0,        -- No bonus
        poor = 0.9,        -- 10% penalty
        spoiled = 0.5      -- 50% penalty
    },
    containerEfficiencyBonus = {
        perfectContainerMatch = 150,        -- $150 for perfect match
        temperatureControlMaintained = 100  -- $100 for temp control
    }
}
```

### **Integration with Other Systems**

#### **Discord Webhooks:**
```lua
Config.Notifications.discord = {
    enabled = true,
    webhookURL = "your_webhook_url",
    botName = "Supply Chain AI",
    channels = {
        container_alerts = "webhook_url_1",
        quality_reports = "webhook_url_2"
    }
}
```

#### **Phone System Integration:**
```lua
Config.Notifications.phone = {
    enabled = true,
    resource = "qb-phone",  -- or "lb-phone", "qs-smartphone"
}
```

### **Performance Optimization**

#### **Caching Configuration:**
```lua
Config.DynamicContainers.advanced.caching = {
    enabled = true,
    cacheDuration = 30000,     -- 30 seconds
    maxCacheSize = 1000,       -- Max cached items
    autoCleanup = true
}
```

#### **Database Optimization:**
```lua
Config.DynamicContainers.advanced.database = {
    batchSize = 100,           -- Batch operations
    queryTimeout = 5000,       -- 5 second timeout
    connectionPool = true,     -- Use connection pooling
    indexOptimization = true   -- Auto-optimize indexes
}
```

---

## 🎯 **FINAL VERIFICATION CHECKLIST**

**Before Going Live:**

- ✅ **Database migration completed successfully**
- ✅ **All config files properly configured**
- ✅ **Container inventory populated with initial stock**
- ✅ **Admin commands working**
- ✅ **Restaurant ordering system integrated**
- ✅ **Warehouse system integrated**
- ✅ **Delivery system working with quality tracking**
- ✅ **Reward system calculating container bonuses**
- ✅ **Performance tested under load**
- ✅ **Backup created before deployment**

**Post-Deployment Monitoring:**

- 📊 **Monitor server performance**
- 📈 **Track container usage metrics**
- 🔍 **Watch for error logs**
- 👥 **Gather player feedback**
- 📞 **Monitor support tickets**

---

## 🆘 **SUPPORT**

**If you encounter issues:**

1. **Check the console logs** for specific error messages
2. **Verify all dependencies** are properly installed
3. **Test with minimal configuration** first
4. **Check database connectivity** and permissions
5. **Review integration steps** for any missed modifications

**Common Support Resources:**
- 📖 **Documentation**: This installation guide
- 🐛 **Debug Commands**: Use `/containerstatus` and `/supplytest`
- 📊 **Analytics**: Use `/containeranalytics` for system insights
- 🔧 **Admin Tools**: Use admin commands for troubleshooting

---

## 🚀 **CONGRATULATIONS!**

You have successfully installed **THE MOST ADVANCED CONTAINER LOGISTICS SYSTEM IN FIVEM HISTORY!**

Your server now features:
- 📦 **6 specialized container types** with unique properties
- 🌡️ **Real-time quality tracking** and temperature monitoring
- 💰 **Enhanced reward system** with quality bonuses
- 📊 **Comprehensive analytics** and reporting
- 🛠️ **Advanced admin tools** for management
- ⚡ **Performance-optimized** database operations
- 🎯 **Seamless integration** with existing systems

**Your players will experience the most immersive and realistic supply chain delivery system ever created for FiveM!**

---

*Installation Guide Version 1.0 - Dynamic Container System*
*Last Updated: [Current Date]*
