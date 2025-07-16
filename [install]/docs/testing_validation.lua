-- ============================================
-- CONTAINER SYSTEM TESTING & VALIDATION SCRIPT
-- Comprehensive testing suite for Dynamic Container System
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

local showTestResults
local type = type

-- Test results tracking
local testResults = {
    passed = 0,
    failed = 0,
    tests = {},
    startTime = 0,
    endTime = 0
}

-- Test configuration
local TEST_CONFIG = {
    testPlayer = nil,           -- Will be set to admin running tests
    testRestaurantId = 1,       -- Default test restaurant
    testIngredient = "tomato",  -- Default test ingredient
    testQuantity = 10,          -- Default test quantity
    timeoutMs = 30000,          -- 30 second timeout for async tests
    verboseOutput = true        -- Detailed console output
}

-- ============================================
-- TEST UTILITY FUNCTIONS
-- ============================================

-- Log test result
local function logTest(testName, passed, message, details)
    local status = passed and "✅ PASS" or "❌ FAIL"
    local result = {
        name = testName,
        passed = passed,
        message = message,
        details = details or {},
        timestamp = os.time()
    }
    
    table.insert(testResults.tests, result)
    
    if passed then
        testResults.passed = testResults.passed + 1
    else
        testResults.failed = testResults.failed + 1
    end
    
    if TEST_CONFIG.verboseOutput then
        print(string.format("[TEST] %s: %s - %s", status, testName, message))
        if details and type(details) == "table" then
            for key, value in pairs(details) do
                print(string.format("  -> %s: %s", key, tostring(value)))
            end
        end
    end
end

-- Execute async test with timeout
local function executeAsyncTest(testName, testFunction, timeoutMs)
    local timeout = timeoutMs or TEST_CONFIG.timeoutMs
    local completed = false
    local result = false
    local message = "Test timed out"
    local details = {}
    
    -- Start test
    testFunction(function(success, msg, data)
        completed = true
        result = success
        message = msg or (success and "Test completed successfully" or "Test failed")
        details = data or {}
    end)
    
    -- Wait for completion or timeout
    local startTime = GetGameTimer()
    Citizen.CreateThread(function()
        while not completed and (GetGameTimer() - startTime) < timeout do
            Citizen.Wait(100)
        end
        
        if not completed then
            result = false
            message = "Test timed out after " .. timeout .. "ms"
        end
        
        logTest(testName, result, message, details)
    end)
end

-- Get test player
local function getTestPlayer()
    if TEST_CONFIG.testPlayer then
        return QBCore.Functions.GetPlayer(TEST_CONFIG.testPlayer)
    end
    return nil
end

-- ============================================
-- DATABASE TESTS
-- ============================================

-- Test database table existence
local function testDatabaseTables(callback)
    local requiredTables = {
        'supply_containers',
        'supply_container_inventory',
        'supply_container_quality_log',
        'supply_container_usage_stats',
        'supply_container_alerts',
        'supply_container_quality_tracking'
    }
    
    local foundTables = {}
    local missingTables = {}
    
    MySQL.Async.fetchAll([[
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME LIKE 'supply_container%'
    ]], {}, function(results)
        
        for _, row in ipairs(results or {}) do
            table.insert(foundTables, row.TABLE_NAME)
        end
        
        for _, requiredTable in ipairs(requiredTables) do
            local found = false
            for _, foundTable in ipairs(foundTables) do
                if foundTable == requiredTable then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(missingTables, requiredTable)
            end
        end
        
        local success = #missingTables == 0
        local message = success and 
            string.format("All %d required tables found", #requiredTables) or
            string.format("Missing %d tables", #missingTables)
        
        callback(success, message, {
            foundTables = foundTables,
            missingTables = missingTables,
            totalRequired = #requiredTables
        })
    end)
end

-- Test container inventory data
local function testContainerInventory(callback)
    MySQL.Async.fetchAll('SELECT * FROM supply_container_inventory', {}, function(results)
        local success = results and #results >= 6  -- Should have 6 container types minimum
        local message = success and 
            string.format("Container inventory loaded with %d types", #results) or
            "Container inventory empty or incomplete"
        
        local details = {}
        if results then
            for _, row in ipairs(results) do
                details[row.container_type] = {
                    available = row.available_quantity,
                    capacity = row.total_capacity,
                    cost = row.cost_per_unit
                }
            end
        end
        
        callback(success, message, details)
    end)
end

-- Test database indexes
local function testDatabaseIndexes(callback)
    MySQL.Async.fetchAll([[
        SELECT 
            TABLE_NAME,
            INDEX_NAME,
            COLUMN_NAME
        FROM information_schema.STATISTICS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME LIKE 'supply_container%'
        AND INDEX_NAME != 'PRIMARY'
    ]], {}, function(results)
        
        local indexCount = results and #results or 0
        local success = indexCount >= 10  -- Should have multiple indexes
        local message = success and 
            string.format("Database indexes configured (%d indexes)", indexCount) or
            string.format("Insufficient indexes (%d found, expected 10+)", indexCount)
        
        callback(success, message, {
            indexCount = indexCount,
            indexes = results or {}
        })
    end)
end

-- ============================================
-- CONFIGURATION TESTS
-- ============================================

-- Test config file loading
local function testConfigLoading(callback)
    local success = Config.DynamicContainers ~= nil
    local message = success and "Container configuration loaded" or "Container configuration missing"
    
    local details = {}
    if success then
        details.enabled = Config.DynamicContainers.enabled
        details.systemConfig = Config.DynamicContainers.system ~= nil
        details.containerTypes = 0
        
        if Config.DynamicContainers.containerTypes then
            for _ in pairs(Config.DynamicContainers.containerTypes) do
                details.containerTypes = details.containerTypes + 1
            end
        end
    end
    
    callback(success, message, details)
end

-- Test container type configurations
local function testContainerTypeConfig(callback)
    if not Config.DynamicContainers or not Config.DynamicContainers.containerTypes then
        callback(false, "Container types configuration missing", {})
        return
    end
    
    local containerTypes = Config.DynamicContainers.containerTypes
    local validTypes = 0
    local issues = {}
    
    for containerType, config in pairs(containerTypes) do
        local isValid = true
        
        -- Check required fields
        if not config.name then
            table.insert(issues, containerType .. ": missing name")
            isValid = false
        end
        if not config.cost or config.cost <= 0 then
            table.insert(issues, containerType .. ": invalid cost")
            isValid = false
        end
        if not config.maxCapacity or config.maxCapacity ~= 12 then
            table.insert(issues, containerType .. ": maxCapacity must be 12")
            isValid = false
        end
        
        if isValid then
            validTypes = validTypes + 1
        end
    end
    
    local totalTypes = 0
    for _ in pairs(containerTypes) do totalTypes = totalTypes + 1 end
    
    local success = validTypes == totalTypes and #issues == 0
    local message = success and 
        string.format("All %d container types valid", totalTypes) or
        string.format("%d/%d container types valid, %d issues", validTypes, totalTypes, #issues)
    
    callback(success, message, {
        totalTypes = totalTypes,
        validTypes = validTypes,
        issues = issues
    })
end

-- ============================================
-- SYSTEM FUNCTIONALITY TESTS
-- ============================================

-- Test container creation
local function testContainerCreation(callback)
    if not exports[GetCurrentResourceName()].createContainer then
        callback(false, "createContainer export not available", {})
        return
    end
    
    local testOrderId = "TEST_" .. GetGameTimer()
    local containerId = exports[GetCurrentResourceName()]:createContainer(
        TEST_CONFIG.testIngredient, 
        TEST_CONFIG.testQuantity, 
        testOrderId, 
        TEST_CONFIG.testRestaurantId
    )
    
    if containerId then
        -- Verify container was created in database
        MySQL.Async.fetchAll('SELECT * FROM supply_containers WHERE container_id = ?', {containerId}, function(results)
            local success = results and #results > 0
            local message = success and 
                string.format("Container created successfully: %s", containerId) or
                "Container creation failed - not found in database"
            
            local details = {}
            if success and results[1] then
                local container = results[1]
                details = {
                    containerId = container.container_id,
                    containerType = container.container_type,
                    contents = container.contents_item,
                    quantity = container.contents_amount,
                    quality = container.quality_level,
                    status = container.status
                }
            end
            
            callback(success, message, details)
        end)
    else
        callback(false, "Container creation returned nil", {})
    end
end

-- Test container quality updates
local function testQualitySystem(callback)
    -- First create a test container
    local testOrderId = "QUALITY_TEST_" .. GetGameTimer()
    local containerId = exports[GetCurrentResourceName()]:createContainer(
        TEST_CONFIG.testIngredient, 
        5, 
        testOrderId, 
        TEST_CONFIG.testRestaurantId
    )
    
    if not containerId then
        callback(false, "Failed to create test container for quality test", {})
        return
    end
    
    -- Test quality update
    if exports[GetCurrentResourceName()].updateContainerQuality then
        exports[GetCurrentResourceName()]:updateContainerQuality(containerId, 'time_aging')
        
        -- Wait a moment then check if quality was updated
        Citizen.SetTimeout(1000, function()
            MySQL.Async.fetchAll('SELECT quality_level FROM supply_containers WHERE container_id = ?', {containerId}, function(results)
                local success = results and #results > 0 and results[1].quality_level < 100
                local message = success and 
                    string.format("Quality system working - quality: %.1f%%", results[1].quality_level) or
                    "Quality system failed - no quality change detected"
                
                local details = {
                    containerId = containerId,
                    newQuality = results and results[1] and results[1].quality_level or "unknown"
                }
                
                callback(success, message, details)
            end)
        end)
    else
        callback(false, "updateContainerQuality export not available", {})
    end
end

-- Test container inventory management
local function testInventoryManagement(callback)
    -- Check initial inventory
    MySQL.Async.fetchAll('SELECT * FROM supply_container_inventory WHERE container_type = ?', {'ogz_crate'}, function(initial)
        if not initial or #initial == 0 then
            callback(false, "No container inventory found for ogz_crate", {})
            return
        end
        
        local initialQty = initial[1].available_quantity
        
        -- Create a container (should reduce inventory)
        local testOrderId = "INVENTORY_TEST_" .. GetGameTimer()
        local containerId = exports[GetCurrentResourceName()]:createContainer(
            TEST_CONFIG.testIngredient, 
            3, 
            testOrderId, 
            TEST_CONFIG.testRestaurantId
        )
        
        if not containerId then
            callback(false, "Failed to create container for inventory test", {})
            return
        end
        
        -- Check if inventory was reduced
        Citizen.SetTimeout(1000, function()
            MySQL.Async.fetchAll('SELECT * FROM supply_container_inventory WHERE container_type = ?', {'ogz_crate'}, function(after)
                local success = after and #after > 0 and after[1].available_quantity == (initialQty - 1)
                local message = success and 
                    string.format("Inventory management working - reduced from %d to %d", initialQty, after[1].available_quantity) or
                    string.format("Inventory management failed - expected %d, got %d", initialQty - 1, after and after[1] and after[1].available_quantity or "unknown")
                
                local details = {
                    initialQuantity = initialQty,
                    finalQuantity = after and after[1] and after[1].available_quantity or "unknown",
                    containerId = containerId
                }
                
                callback(success, message, details)
            end)
        end)
    end)
end

-- ============================================
-- INTEGRATION TESTS
-- ============================================

-- Test admin permission system
local function testAdminPermissions(callback)
    if not exports[GetCurrentResourceName()].hasContainerAdminPermission then
        callback(false, "hasContainerAdminPermission export not available", {})
        return
    end
    
    -- Test console permission (should be true)
    local consoleAccess = exports[GetCurrentResourceName()]:hasContainerAdminPermission(0, 'moderator')
    
    -- Test invalid player (should be false)
    local invalidAccess = exports[GetCurrentResourceName()]:hasContainerAdminPermission(999999, 'moderator')
    
    local success = consoleAccess == true and invalidAccess == false
    local message = success and 
        "Admin permission system working correctly" or
        "Admin permission system has issues"
    
    local details = {
        consoleAccess = consoleAccess,
        invalidPlayerAccess = invalidAccess
    }
    
    callback(success, message, details)
end

-- Test exports availability
local function testExportsAvailability(callback)
    local requiredExports = {
        'createContainer',
        'updateContainerQuality', 
        'getContainerInventory',
        'hasContainerAdminPermission'
    }
    
    local availableExports = {}
    local missingExports = {}
    
    for _, exportName in ipairs(requiredExports) do
        if exports[GetCurrentResourceName()][exportName] then
            table.insert(availableExports, exportName)
        else
            table.insert(missingExports, exportName)
        end
    end
    
    local success = #missingExports == 0
    local message = success and 
        string.format("All %d exports available", #requiredExports) or
        string.format("%d/%d exports missing", #missingExports, #requiredExports)
    
    callback(success, message, {
        availableExports = availableExports,
        missingExports = missingExports
    })
end

-- ============================================
-- PERFORMANCE TESTS
-- ============================================

-- Test database performance
local function testDatabasePerformance(callback)
    local startTime = GetGameTimer()
    local queries = {
        "SELECT COUNT(*) FROM supply_containers",
        "SELECT * FROM supply_container_inventory LIMIT 10", 
        "SELECT * FROM supply_containers WHERE status = 'filled' LIMIT 5"
    }
    
    local completedQueries = 0
    local totalTime = 0
    
    for i, query in ipairs(queries) do
        local queryStart = GetGameTimer()
        MySQL.Async.fetchAll(query, {}, function(results)
            local queryTime = GetGameTimer() - queryStart
            totalTime = totalTime + queryTime
            completedQueries = completedQueries + 1
            
            if completedQueries == #queries then
                local avgTime = totalTime / #queries
                local success = avgTime < 100  -- Should be under 100ms average
                local message = success and 
                    string.format("Database performance good - avg %.1fms", avgTime) or
                    string.format("Database performance slow - avg %.1fms", avgTime)
                
                callback(success, message, {
                    averageQueryTime = avgTime,
                    totalQueries = #queries,
                    totalTime = totalTime
                })
            end
        end)
    end
end

-- Test memory usage
local function testMemoryUsage(callback)
    -- This is a simplified memory test
    local initialMemory = collectgarbage("count")
    
    -- Create several test containers to check memory impact
    local containers = {}
    for i = 1, 10 do
        local testOrderId = "MEMORY_TEST_" .. i .. "_" .. GetGameTimer()
        local containerId = exports[GetCurrentResourceName()]:createContainer(
            TEST_CONFIG.testIngredient, 
            5, 
            testOrderId, 
            TEST_CONFIG.testRestaurantId
        )
        if containerId then
            table.insert(containers, containerId)
        end
    end
    
    Citizen.SetTimeout(2000, function()
        collectgarbage("collect")
        local finalMemory = collectgarbage("count")
        local memoryIncrease = finalMemory - initialMemory
        
        local success = memoryIncrease < 1000  -- Should be under 1MB increase for 10 containers
        local message = success and 
            string.format("Memory usage acceptable - %.1fKB increase", memoryIncrease) or
            string.format("Memory usage high - %.1fKB increase", memoryIncrease)
        
        callback(success, message, {
            initialMemory = initialMemory,
            finalMemory = finalMemory,
            memoryIncrease = memoryIncrease,
            containersCreated = #containers
        })
    end)
end

-- ============================================
-- MAIN TEST RUNNER
-- ============================================

-- Run all tests
local function runAllTests()
    testResults = {
        passed = 0,
        failed = 0,
        tests = {},
        startTime = GetGameTimer(),
        endTime = 0
    }
    
    print("🧪 ============================================")
    print("🧪 STARTING CONTAINER SYSTEM TESTS")
    print("🧪 ============================================")
    
    -- Database Tests
    print("\n📊 RUNNING DATABASE TESTS...")
    executeAsyncTest("Database Tables", testDatabaseTables)
    executeAsyncTest("Container Inventory", testContainerInventory)
    executeAsyncTest("Database Indexes", testDatabaseIndexes)
    
    -- Configuration Tests  
    print("\n⚙️ RUNNING CONFIGURATION TESTS...")
    executeAsyncTest("Config Loading", testConfigLoading)
    executeAsyncTest("Container Type Config", testContainerTypeConfig)
    
    -- System Functionality Tests
    print("\n🔧 RUNNING FUNCTIONALITY TESTS...")
    executeAsyncTest("Container Creation", testContainerCreation)
    executeAsyncTest("Quality System", testQualitySystem)
    executeAsyncTest("Inventory Management", testInventoryManagement)
    
    -- Integration Tests
    print("\n🔗 RUNNING INTEGRATION TESTS...")
    executeAsyncTest("Admin Permissions", testAdminPermissions)
    executeAsyncTest("Exports Availability", testExportsAvailability)
    
    -- Performance Tests
    print("\n⚡ RUNNING PERFORMANCE TESTS...")
    executeAsyncTest("Database Performance", testDatabasePerformance)
    executeAsyncTest("Memory Usage", testMemoryUsage)
    
    -- Wait for all tests to complete then show results
    Citizen.SetTimeout(45000, function()  -- 45 second total timeout
        showTestResults()
    end)
end

-- Show test results
local function showTestResults()
    testResults.endTime = GetGameTimer()
    local totalTime = testResults.endTime - testResults.startTime
    local totalTests = testResults.passed + testResults.failed
    local successRate = totalTests > 0 and (testResults.passed / totalTests * 100) or 0
    
    print("\n🧪 ============================================")
    print("🧪 CONTAINER SYSTEM TEST RESULTS")
    print("🧪 ============================================")
    print(string.format("⏱️  Total Time: %.1f seconds", totalTime / 1000))
    print(string.format("✅  Passed: %d", testResults.passed))
    print(string.format("❌  Failed: %d", testResults.failed))
    print(string.format("📊  Success Rate: %.1f%%", successRate))
    print("🧪 ============================================")
    
    if testResults.failed > 0 then
        print("\n❌ FAILED TESTS:")
        for _, test in ipairs(testResults.tests) do
            if not test.passed then
                print(string.format("   • %s: %s", test.name, test.message))
                if test.details and type(test.details) == "table" then
                    for key, value in pairs(test.details) do
                        if type(value) == "table" then
                            print(string.format("     - %s: %s", key, json.encode(value)))
                        else
                            print(string.format("     - %s: %s", key, tostring(value)))
                        end
                    end
                end
            end
        end
    end
    
    if testResults.passed > 0 then
        print("\n✅ PASSED TESTS:")
        for _, test in ipairs(testResults.tests) do
            if test.passed then
                print(string.format("   • %s: %s", test.name, test.message))
            end
        end
    end
    
    print("\n🧪 ============================================")
    
    local status = successRate >= 90 and "🟢 EXCELLENT" or 
                  successRate >= 70 and "🟡 GOOD" or 
                  successRate >= 50 and "🟠 NEEDS WORK" or 
                  "🔴 CRITICAL ISSUES"
    
    print(string.format("🎯 OVERALL STATUS: %s (%.1f%%)", status, successRate))
    print("🧪 ============================================")
    
    -- Send results to test admin if available
    if TEST_CONFIG.testPlayer then
        local xPlayer = QBCore.Functions.GetPlayer(TEST_CONFIG.testPlayer)
        if xPlayer then
            TriggerClientEvent('ox_lib:notify', TEST_CONFIG.testPlayer, {
                title = '🧪 Container Tests Complete',
                description = string.format('✅ %d passed, ❌ %d failed\n%s', 
                    testResults.passed, testResults.failed, status),
                type = successRate >= 70 and 'success' or 'error',
                duration = 15000,
                position = 'top',
                markdown = true
            })
        end
    end
end

-- ============================================
-- COMMANDS
-- ============================================

-- Test command for admins
RegisterCommand('testcontainers', function(source, args, rawCommand)
    if source ~= 0 and not exports[GetCurrentResourceName()]:hasContainerAdminPermission(source, 'admin') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Access Denied',
                description = 'Admin permissions required for testing.',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    TEST_CONFIG.testPlayer = source ~= 0 and source or nil
    
    -- Override test parameters if provided
    if args[1] then TEST_CONFIG.testRestaurantId = tonumber(args[1]) or 1 end
    if args[2] then TEST_CONFIG.testIngredient = args[2] end
    if args[3] then TEST_CONFIG.testQuantity = tonumber(args[3]) or 10 end
    
    if source == 0 then
        print("Starting container system tests from console...")
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = '🧪 Starting Container Tests',
            description = 'Running comprehensive test suite...',
            type = 'info',
            duration = 8000
        })
    end
    
    runAllTests()
end, false)

-- Quick health check command
RegisterCommand('containerhealth', function(source, args, rawCommand)
    if source ~= 0 and not exports[GetCurrentResourceName()]:hasContainerAdminPermission(source, 'moderator') then
        return
    end
    
    -- Quick health check
    MySQL.Async.fetchAll([[
        SELECT 
            (SELECT COUNT(*) FROM supply_containers) as total_containers,
            (SELECT COUNT(*) FROM supply_container_inventory) as container_types,
            (SELECT SUM(available_quantity) FROM supply_container_inventory) as total_inventory,
            (SELECT COUNT(*) FROM supply_container_alerts WHERE acknowledged = 0) as unread_alerts
    ]], {}, function(results)
        
        if results and results[1] then
            local data = results[1]
            local message = string.format(
                "📦 Containers: %d | 🏭 Types: %d | 📊 Inventory: %d | 🚨 Alerts: %d",
                data.total_containers, data.container_types, data.total_inventory, data.unread_alerts
            )
            
            if source == 0 then
                print("[CONTAINER HEALTH] " .. message)
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '💊 Container System Health',
                    description = message,
                    type = 'info',
                    duration = 10000
                })
            end
        end
    end)
end, false)

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/testcontainers', 'Run comprehensive container system tests (Admin)', {
    { name = 'restaurant_id', help = 'Test restaurant ID (default: 1)' },
    { name = 'ingredient', help = 'Test ingredient (default: tomato)' },
    { name = 'quantity', help = 'Test quantity (default: 10)' }
})

TriggerEvent('chat:addSuggestion', '/containerhealth', 'Quick container system health check')

-- Auto-run basic tests on startup (optional)
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if Config.DynamicContainers and Config.DynamicContainers.enabled then
            print("[CONTAINER TESTING] Testing framework loaded!")
            print("[CONTAINER TESTING] Use '/testcontainers' to run full test suite")
            print("[CONTAINER TESTING] Use '/containerhealth' for quick health check")
            
            -- Auto health check after 30 seconds
            Citizen.SetTimeout(30000, function()
                print("[CONTAINER TESTING] Running automatic health check...")
                TriggerServerEvent('containerhealth')
            end)
        end
    end
end)

print("[CONTAINER TESTING] Container system testing framework loaded!")