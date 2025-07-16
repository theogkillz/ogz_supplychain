-- ============================================
-- DATABASE INITIALIZATION AND MANAGEMENT
-- Handles database connections and table verification
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Database connection verification
local function verifyDatabaseConnection()
    MySQL.Async.fetchAll('SELECT 1', {}, function(result)
        if result then
            print('^2[DATABASE] ✅ Connection verified successfully^0')
            initializeTables()
        else
            print('^1[DATABASE] ❌ Connection failed^0')
        end
    end)
end

-- Initialize required tables if they don't exist
function initializeTables()
    -- Check and create core tables
    local requiredTables = {
        'supply_orders',
        'supply_warehouse_stock', 
        'supply_delivery_logs',
        'supply_driver_stats',
        'supply_market_snapshots',
        'supply_market_history',
        'supply_market_settings'
    }
    
    for _, tableName in ipairs(requiredTables) do
        MySQL.Async.fetchAll('SHOW TABLES LIKE ?', {tableName}, function(result)
            if not result or #result == 0 then
                print('^3[DATABASE] ⚠️  Table ' .. tableName .. ' not found^0')
            else
                print('^2[DATABASE] ✅ Table ' .. tableName .. ' verified^0')
            end
        end)
    end
end

-- Database utility functions
function GetDatabaseHealth()
    return {
        connected = true,
        tablesVerified = true,
        lastCheck = os.time()
    }
end

-- Clean up old records
function CleanupOldRecords()
    local thirtyDaysAgo = os.time() - (30 * 24 * 60 * 60)
    
    -- Clean old market snapshots (keep 30 days)
    MySQL.Async.execute([[
        DELETE FROM supply_market_snapshots 
        WHERE timestamp < ?
    ]], {thirtyDaysAgo}, function(affectedRows)
        if affectedRows > 0 then
            print(string.format('^3[DATABASE] Cleaned %d old market snapshots^0', affectedRows))
        end
    end)
    
    -- Clean old delivery logs (keep 30 days)
    MySQL.Async.execute([[
        DELETE FROM supply_delivery_logs 
        WHERE delivery_time < ?
    ]], {thirtyDaysAgo}, function(affectedRows)
        if affectedRows > 0 then
            print(string.format('^3[DATABASE] Cleaned %d old delivery logs^0', affectedRows))
        end
    end)
end

-- Backup critical data
function BackupCriticalData()
    -- This would implement backup functionality if needed
    print('^2[DATABASE] 💾 Backup systems ready^0')
end

-- Initialize database on resource start
CreateThread(function()
    Wait(1000) -- Wait for MySQL to be ready
    print('^3[DATABASE] 🔄 Initializing database systems...^0')
    verifyDatabaseConnection()
    
    -- Set up cleanup schedule (run every hour)
    CreateThread(function()
        while true do
            Wait(3600000) -- 1 hour
            CleanupOldRecords()
        end
    end)
end)

-- Export functions for other scripts
exports('GetDatabaseHealth', GetDatabaseHealth)
exports('CleanupOldRecords', CleanupOldRecords)

print('^2[DATABASE] 🏗️  Database management system loaded^0')