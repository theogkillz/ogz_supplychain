-- ===============================================
-- RESTAURANT FINANCIAL INTEGRATION SYSTEM
-- Server-side financial tracking and business logic
-- File: sv_restaurant_ownership.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- RESTAURANT OWNERSHIP MANAGEMENT
-- ===============================================

-- Purchase Restaurant
RegisterNetEvent('restaurant:purchaseRestaurant')
AddEventHandler('restaurant:purchaseRestaurant', function(restaurantId, paymentType, amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant or not restaurant.ownership or not restaurant.ownership.enabled then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'This restaurant is not available for purchase.',
            type = 'error'
        })
        return
    end
    
    local purchasePrice = restaurant.ownership.purchasePrice or 150000
    
    -- Check if restaurant is already owned
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM supply_restaurant_ownership WHERE restaurant_id = ? AND is_active = 1', 
    {restaurantId}, function(ownedCount)
        if ownedCount > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Restaurant Unavailable',
                description = 'This restaurant is already owned by someone else.',
                type = 'error'
            })
            return
        end
        
        -- Check player requirements
        local requirements = Config.RestaurantOwnership.purchaseSystem
        
        -- Check business license requirement
        if requirements.requireBusinessLicense then
            local hasLicense = exports.ox_inventory:GetItemCount(src, 'business_license')
            if hasLicense < 1 then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'License Required',
                    description = 'You need a business license to purchase a restaurant.',
                    type = 'error'
                })
                return
            end
        end
        
        -- Check maximum owned restaurants
        MySQL.Async.fetchScalar('SELECT COUNT(*) FROM supply_restaurant_ownership WHERE owner_citizenid = ? AND is_active = 1', 
        {xPlayer.PlayerData.citizenid}, function(ownedRestaurants)
            if ownedRestaurants >= requirements.maxOwnedRestaurants then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Ownership Limit',
                    description = string.format('You can only own %d restaurants.', requirements.maxOwnedRestaurants),
                    type = 'error'
                })
                return
            end
            
            if paymentType == "cash" then
                -- Full cash purchase
                if xPlayer.PlayerData.money.bank >= purchasePrice then
                    xPlayer.Functions.RemoveMoney('bank', purchasePrice, "Restaurant purchase")
                    
                    -- Create ownership record
                    MySQL.Async.execute([[
                        INSERT INTO supply_restaurant_ownership 
                        (restaurant_id, owner_citizenid, owner_name, purchase_price, down_payment, remaining_balance)
                        VALUES (?, ?, ?, ?, ?, ?)
                    ]], {restaurantId, xPlayer.PlayerData.citizenid, xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname, 
                         purchasePrice, purchasePrice, 0}, function(success)
                        if success then
                            -- Add owner as staff
                            addRestaurantStaff(restaurantId, xPlayer.PlayerData.citizenid, 
                                xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname, 
                                'owner', 0, '["all"]')
                            
                            -- Initialize default settings
                            initializeRestaurantSettings(restaurantId)
                            
                            TriggerClientEvent('ox_lib:notify', src, {
                                title = 'Congratulations!',
                                description = string.format('You now own %s! Welcome to the business world.', restaurant.name),
                                type = 'success'
                            })
                            
                            -- Log the purchase
                            logFinancialTransaction(restaurantId, 'expense', purchasePrice, 'Restaurant purchase', nil, xPlayer.PlayerData.citizenid)
                        else
                            xPlayer.Functions.AddMoney('bank', purchasePrice, "Restaurant purchase failed - refund")
                            TriggerClientEvent('ox_lib:notify', src, {
                                title = 'Purchase Failed',
                                description = 'There was an error processing your purchase. Money refunded.',
                                type = 'error'
                            })
                        end
                    end)
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Insufficient Funds',
                        description = string.format('You need $%s to purchase this restaurant.', purchasePrice),
                        type = 'error'
                    })
                end
            else
                -- Financing option - will be handled by separate event
                TriggerEvent('restaurant:processFinancing', src, restaurantId, amount)
            end
        end)
    end)
end)

-- ===============================================
-- SUPPLY CHAIN INTEGRATION (OWNER BENEFITS)
-- ===============================================

-- Enhanced order processing with owner benefits
RegisterNetEvent('restaurant:orderIngredientsAsOwner')
AddEventHandler('restaurant:orderIngredientsAsOwner', function(orderItems, restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Check if player owns this restaurant
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_ownership WHERE restaurant_id = ? AND owner_citizenid = ? AND is_active = 1', 
    {restaurantId, xPlayer.PlayerData.citizenid}, function(ownership)
        if not ownership or #ownership == 0 then
            -- Fall back to regular ordering system
            TriggerEvent('restaurant:orderIngredients', orderItems, restaurantId)
            return
        end
        
        -- Process as owner order with benefits
        local totalCost = 0
        local orderGroupId = "owner_" .. os.time() .. "_" .. math.random(1000, 9999)
        local queries = {}
        
        -- Calculate base cost
        local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
        local restaurantItems = Config.Items[restaurantJob] or {}
        
        for _, orderItem in ipairs(orderItems) do
            local ingredient = orderItem.ingredient:lower()
            local quantity = tonumber(orderItem.quantity)
            
            -- Find item price
            local itemPrice = 0
            for category, categoryItems in pairs(restaurantItems) do
                if categoryItems[ingredient] and categoryItems[ingredient].price then
                    itemPrice = categoryItems[ingredient].price
                    break
                end
            end
            
            totalCost = totalCost + (itemPrice * quantity)
        end
        
        -- Apply owner bulk discount
        local bulkDiscount = calculateOwnerBulkDiscount(totalCost)
        local discountAmount = totalCost * bulkDiscount
        local finalCost = totalCost - discountAmount
        
        -- Check if owner has enough money
        if xPlayer.PlayerData.money.bank >= finalCost then
            xPlayer.Functions.RemoveMoney('bank', finalCost, "Owner ingredient order")
            
            -- Create enhanced orders with owner benefits
            for _, orderItem in ipairs(orderItems) do
                local ingredient = orderItem.ingredient:lower()
                local quantity = tonumber(orderItem.quantity)
                
                -- Find item price
                local itemPrice = 0
                for category, categoryItems in pairs(restaurantItems) do
                    if categoryItems[ingredient] and categoryItems[ingredient].price then
                        itemPrice = categoryItems[ingredient].price
                        break
                    end
                end
                
                local itemCost = (itemPrice * quantity) * (1 - bulkDiscount)
                
                table.insert(queries, {
                    query = [[
                        INSERT INTO supply_orders 
                        (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id, 
                         ordered_by_owner, owner_discount_applied, priority_delivery, quality_standard_required) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ]],
                    values = {src, ingredient, quantity, 'pending', restaurantId, itemCost, orderGroupId, 
                             1, bulkDiscount, 1, 'good'}
                })
            end
            
            MySQL.Async.transaction(queries, function(success)
                if success then
                    -- Log as business expense
                    logFinancialTransaction(restaurantId, 'supply_order', finalCost, 
                        string.format('Owner ingredient order (%d%% discount)', math.floor(bulkDiscount * 100)), 
                        orderGroupId, xPlayer.PlayerData.citizenid)
                    
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Owner Order Placed',
                        description = string.format('Order placed with %d%% owner discount ($%s saved). Priority delivery assigned.', 
                            math.floor(bulkDiscount * 100), math.floor(discountAmount)),
                        type = 'success'
                    })
                    
                    -- Notify warehouse of priority order
                    TriggerEvent('warehouse:priorityOrderReceived', orderGroupId, restaurantId)
                else
                    xPlayer.Functions.AddMoney('bank', finalCost, "Order failed - refund")
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Order Failed',
                        description = 'There was an error processing your order. Money refunded.',
                        type = 'error'
                    })
                end
            end)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Insufficient Funds',
                description = string.format('You need $%s for this order.', math.floor(finalCost)),
                type = 'error'
            })
        end
    end)
end)

-- Calculate owner bulk discount based on order value
function calculateOwnerBulkDiscount(orderValue)
    local discounts = Config.RestaurantOwnership.ownerBenefits.bulkDiscounts
    
    for tier, discount in pairs(discounts) do
        if orderValue >= discount.threshold then
            return discount.discount
        end
    end
    
    return 0
end

-- ===============================================
-- STAFF MANAGEMENT SYSTEM
-- ===============================================

-- Hire Staff
RegisterNetEvent('restaurant:hireEmployee')
AddEventHandler('restaurant:hireEmployee', function(restaurantId, targetPlayerId, position, wage)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local targetPlayer = QBCore.Functions.GetPlayer(targetPlayerId)
    
    if not xPlayer or not targetPlayer then return end
    
    -- Check if source is owner/manager
    checkRestaurantPermission(src, restaurantId, 'hire_staff', function(hasPermission, permissionData)
        if not hasPermission then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Access Denied',
                description = 'You do not have permission to hire staff.',
                type = 'error'
            })
            return
        end
        
        -- Check if position is valid
        local positions = Config.RestaurantOwnership.staffManagement.positions
        if not positions[position] then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Invalid Position',
                description = 'The specified position does not exist.',
                type = 'error'
            })
            return
        end
        
        -- Check current staff count
        MySQL.Async.fetchScalar('SELECT COUNT(*) FROM supply_restaurant_staff WHERE restaurant_id = ? AND is_active = 1', 
        {restaurantId}, function(currentStaff)
            local maxStaff = Config.RestaurantOwnership.staffManagement.maxStaffPerRestaurant
            if currentStaff >= maxStaff then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Staff Limit Reached',
                    description = string.format('Maximum staff limit (%d) reached.', maxStaff),
                    type = 'error'
                })
                return
            end
            
            -- Add staff member
            addRestaurantStaff(restaurantId, targetPlayer.PlayerData.citizenid, 
                targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
                position, wage, json.encode(positions[position].permissions))
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Employee Hired',
                description = string.format('%s hired as %s for $%s/hour.', 
                    targetPlayer.PlayerData.charinfo.firstname, position, wage),
                type = 'success'
            })
            
            TriggerClientEvent('ox_lib:notify', targetPlayerId, {
                title = 'Job Offer',
                description = string.format('You have been hired as %s at %s for $%s/hour!', 
                    position, Config.Restaurants[restaurantId].name, wage),
                type = 'success'
            })
        end)
    end)
end)

-- Fire Staff
RegisterNetEvent('restaurant:fireEmployee')
AddEventHandler('restaurant:fireEmployee', function(restaurantId, employeeCitizenId, reason)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    checkRestaurantPermission(src, restaurantId, 'fire_staff', function(hasPermission, permissionData)
        if not hasPermission then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Access Denied',
                description = 'You do not have permission to fire staff.',
                type = 'error'
            })
            return
        end
        
        -- Deactivate staff member
        MySQL.Async.execute('UPDATE supply_restaurant_staff SET is_active = 0 WHERE restaurant_id = ? AND employee_citizenid = ?', 
        {restaurantId, employeeCitizenId}, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Employee Terminated',
                    description = 'Employee has been removed from the restaurant.',
                    type = 'success'
                })
                
                -- Notify the fired employee if online
                local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(employeeCitizenId)
                if targetPlayer then
                    TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
                        title = 'Employment Terminated',
                        description = string.format('You have been terminated from %s. Reason: %s', 
                            Config.Restaurants[restaurantId].name, reason or 'Not specified'),
                        type = 'error'
                    })
                end
            end
        end)
    end)
end)

-- Clock In/Out System
RegisterNetEvent('restaurant:toggleDuty')
AddEventHandler('restaurant:toggleDuty', function(restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_staff WHERE restaurant_id = ? AND employee_citizenid = ? AND is_active = 1', 
    {restaurantId, xPlayer.PlayerData.citizenid}, function(staff)
        if not staff or #staff == 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Not Employed',
                description = 'You are not employed at this restaurant.',
                type = 'error'
            })
            return
        end
        
        local employee = staff[1]
        local newDutyStatus = employee.on_duty == 1 and 0 or 1
        
        if newDutyStatus == 1 then
            -- Clock in
            MySQL.Async.execute('UPDATE supply_restaurant_staff SET on_duty = 1 WHERE id = ?', {employee.id})
            MySQL.Async.execute([[
                INSERT INTO supply_staff_timesheets (restaurant_id, employee_citizenid, clock_in, date_worked)
                VALUES (?, ?, NOW(), CURDATE())
            ]], {restaurantId, xPlayer.PlayerData.citizenid})
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Clocked In',
                description = string.format('Welcome back! You are now on duty as %s.', employee.position),
                type = 'success'
            })
        else
            -- Clock out
            MySQL.Async.execute('UPDATE supply_restaurant_staff SET on_duty = 0 WHERE id = ?', {employee.id})
            
            -- Calculate hours worked and wages
            MySQL.Async.fetchAll([[
                SELECT * FROM supply_staff_timesheets 
                WHERE restaurant_id = ? AND employee_citizenid = ? AND clock_out IS NULL
                ORDER BY clock_in DESC LIMIT 1
            ]], {restaurantId, xPlayer.PlayerData.citizenid}, function(timesheet)
                if timesheet and #timesheet > 0 then
                    local hoursWorked = (os.time() - timesheet[1].clock_in) / 3600 -- Convert to hours
                    local wageEarned = hoursWorked * employee.hourly_wage
                    
                    MySQL.Async.execute([[
                        UPDATE supply_staff_timesheets 
                        SET clock_out = NOW(), hours_worked = ?, wage_earned = ?
                        WHERE id = ?
                    ]], {hoursWorked, wageEarned, timesheet[1].id})
                    
                    -- Pay the employee
                    xPlayer.Functions.AddMoney('bank', math.floor(wageEarned), "Restaurant wages")
                    
                    -- Log expense
                    logFinancialTransaction(restaurantId, 'staff_wages', wageEarned, 
                        string.format('%s wages (%.2f hours)', employee.position, hoursWorked), 
                        nil, xPlayer.PlayerData.citizenid)
                    
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Clocked Out',
                        description = string.format('Shift complete! Earned $%s for %.2f hours.', 
                            math.floor(wageEarned), hoursWorked),
                        type = 'success'
                    })
                end
            end)
        end
    end)
end)

-- ===============================================
-- REGISTER/POS SALES SYSTEM
-- ===============================================

-- Process Customer Sale
RegisterNetEvent('restaurant:processSale')
AddEventHandler('restaurant:processSale', function(restaurantId, customerData, itemsSold, totalAmount, paymentMethod)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Check if player can access register
    checkRestaurantPermission(src, restaurantId, 'register_access', function(hasPermission, permissionData)
        if not hasPermission then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Access Denied',
                description = 'You do not have permission to use the register.',
                type = 'error'
            })
            return
        end
        
        local transactionId = "sale_" .. os.time() .. "_" .. math.random(1000, 9999)
        local taxRate = Config.RestaurantOwnership.financialManagement.revenueStreams.registerSales.taxRate or 0.08
        local commissionRate = Config.RestaurantOwnership.financialManagement.revenueStreams.registerSales.commissionRate or 0.15
        
        local taxAmount = totalAmount * taxRate
        local commissionAmount = totalAmount * commissionRate
        local netRevenue = totalAmount - taxAmount
        
        -- Record the sale
        MySQL.Async.execute([[
            INSERT INTO supply_restaurant_sales 
            (restaurant_id, employee_citizenid, customer_citizenid, customer_name, transaction_id, 
             items_sold, subtotal, tax_amount, total_amount, payment_method, commission_rate, commission_amount)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {restaurantId, xPlayer.PlayerData.citizenid, customerData.citizenid or nil, customerData.name or 'Walk-in Customer',
             transactionId, json.encode(itemsSold), totalAmount - taxAmount, taxAmount, totalAmount, paymentMethod, 
             commissionRate, commissionAmount}, function(success)
            if success then
                -- Update daily financial summary
                updateDailyFinancials(restaurantId, 'revenue', netRevenue, commissionAmount)
                
                -- Pay commission to employee if eligible
                local staffPositions = Config.RestaurantOwnership.staffManagement.positions
                if permissionData.position and staffPositions[permissionData.position] and staffPositions[permissionData.position].commissionEligible then
                    xPlayer.Functions.AddMoney('bank', math.floor(commissionAmount), "Sales commission")
                    
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Sale Processed',
                        description = string.format('Sale: $%s | Your commission: $%s', 
                            math.floor(totalAmount), math.floor(commissionAmount)),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Sale Processed',
                        description = string.format('Sale completed: $%s', math.floor(totalAmount)),
                        type = 'success'
                    })
                end
                
                -- Log revenue
                logFinancialTransaction(restaurantId, 'register_sales', netRevenue, 
                    string.format('Register sale - Transaction: %s', transactionId), 
                    transactionId, xPlayer.PlayerData.citizenid)
            end
        end)
    end)
end)

-- ===============================================
-- FINANCIAL REPORTING SYSTEM
-- ===============================================

-- Get Dashboard Data
QBCore.Functions.CreateCallback('restaurant:getDashboardData', function(source, cb, restaurantId)
    MySQL.Async.fetchAll([[
        SELECT 
            DATE(financial_date) as date,
            total_revenue,
            total_expenses,
            net_profit,
            customers_served,
            avg_order_value
        FROM supply_restaurant_finances 
        WHERE restaurant_id = ? 
        AND financial_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ORDER BY financial_date DESC
    ]], {restaurantId}, function(financials)
        
        -- Get staff summary
        MySQL.Async.fetchAll([[
            SELECT 
                COUNT(*) as total_staff,
                SUM(CASE WHEN on_duty = 1 THEN 1 ELSE 0 END) as on_duty_staff,
                SUM(hourly_wage) as total_hourly_wages
            FROM supply_restaurant_staff 
            WHERE restaurant_id = ? AND is_active = 1
        ]], {restaurantId}, function(staffSummary)
            
            local today = financials[1] or {}
            local weekRevenue = 0
            local weekProfit = 0
            
            for i = 1, math.min(7, #financials) do
                weekRevenue = weekRevenue + (financials[i].total_revenue or 0)
                weekProfit = weekProfit + (financials[i].net_profit or 0)
            end
            
            local dashboardData = {
                today = {
                    revenue = today.total_revenue or 0,
                    profit = today.net_profit or 0,
                    customers = today.customers_served or 0
                },
                week = {
                    revenue = weekRevenue,
                    profit = weekProfit
                },
                staff = {
                    total = staffSummary[1] and staffSummary[1].total_staff or 0,
                    onDuty = staffSummary[1] and staffSummary[1].on_duty_staff or 0,
                    dailyWages = staffSummary[1] and staffSummary[1].total_hourly_wages * 8 or 0
                },
                alerts = generateBusinessAlerts(restaurantId)
            }
            
            cb(dashboardData)
        end)
    end)
end)

-- Get Financial Data
QBCore.Functions.CreateCallback('restaurant:getFinancialData', function(source, cb, restaurantId)
    MySQL.Async.fetchAll([[
        SELECT 
            SUM(total_revenue) as monthly_revenue,
            SUM(total_expenses) as monthly_expenses,
            SUM(net_profit) as monthly_profit,
            AVG(net_profit) as daily_average
        FROM supply_restaurant_finances 
        WHERE restaurant_id = ? 
        AND financial_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    ]], {restaurantId}, function(monthlyData)
        
        local data = monthlyData[1] or {}
        local financialData = {
            monthly = {
                revenue = data.monthly_revenue or 0,
                expenses = data.monthly_expenses or 0,
                profit = data.monthly_profit or 0
            },
            cashFlow = {
                dailyAverage = data.daily_average or 0,
                trend = calculateTrend(restaurantId)
            }
        }
        
        cb(financialData)
    end)
end)

-- Get Staff Data
QBCore.Functions.CreateCallback('restaurant:getStaffData', function(source, cb, restaurantId)
    MySQL.Async.fetchAll([[
        SELECT * FROM supply_restaurant_staff 
        WHERE restaurant_id = ? AND is_active = 1
        ORDER BY position, employee_name
    ]], {restaurantId}, function(staff)
        cb(staff or {})
    end)
end)

-- Check Ownership Data
QBCore.Functions.CreateCallback('restaurant:getOwnershipData', function(source, cb, restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then 
        cb({isOwner = false, isStaff = false, position = "none", permissions = {}})
        return 
    end
    
    -- Check ownership
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_ownership WHERE restaurant_id = ? AND owner_citizenid = ? AND is_active = 1', 
    {restaurantId, xPlayer.PlayerData.citizenid}, function(ownership)
        if ownership and #ownership > 0 then
            cb({isOwner = true, isStaff = true, position = "owner", permissions = {"all"}})
            return
        end
        
        -- Check staff
        MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_staff WHERE restaurant_id = ? AND employee_citizenid = ? AND is_active = 1', 
        {restaurantId, xPlayer.PlayerData.citizenid}, function(staff)
            if staff and #staff > 0 then
                local employee = staff[1]
                local permissions = json.decode(employee.permissions or '[]')
                cb({
                    isOwner = false, 
                    isStaff = true, 
                    position = employee.position, 
                    permissions = permissions
                })
            else
                cb({isOwner = false, isStaff = false, position = "none", permissions = {}})
            end
        end)
    end)
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function addRestaurantStaff(restaurantId, citizenId, name, position, wage, permissions)
    MySQL.Async.execute([[
        INSERT INTO supply_restaurant_staff 
        (restaurant_id, employee_citizenid, employee_name, position, hourly_wage, permissions)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {restaurantId, citizenId, name, position, wage, permissions})
end

function checkRestaurantPermission(playerId, restaurantId, requiredPermission, callback)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then 
        callback(false, {})
        return 
    end
    
    -- Check ownership
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_ownership WHERE restaurant_id = ? AND owner_citizenid = ? AND is_active = 1', 
    {restaurantId, xPlayer.PlayerData.citizenid}, function(ownership)
        if ownership and #ownership > 0 then
            callback(true, {isOwner = true, position = "owner", permissions = {"all"}})
            return
        end
        
        -- Check staff permissions
        MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_staff WHERE restaurant_id = ? AND employee_citizenid = ? AND is_active = 1', 
        {restaurantId, xPlayer.PlayerData.citizenid}, function(staff)
            if staff and #staff > 0 then
                local employee = staff[1]
                local permissions = json.decode(employee.permissions or '[]')
                
                if table.contains(permissions, requiredPermission) or table.contains(permissions, "all") then
                    callback(true, {isOwner = false, position = employee.position, permissions = permissions})
                else
                    callback(false, {})
                end
            else
                callback(false, {})
            end
        end)
    end)
end

function logFinancialTransaction(restaurantId, transactionType, amount, description, referenceId, createdBy)
    MySQL.Async.execute([[
        INSERT INTO supply_restaurant_finances 
        (restaurant_id, financial_date, %s)
        VALUES (?, CURDATE(), ?)
        ON DUPLICATE KEY UPDATE %s = %s + ?
    ]], {transactionType, transactionType, transactionType}, 
    {restaurantId, amount, amount})
end

function updateDailyFinancials(restaurantId, type, amount, commission)
    local updateField = type == 'revenue' and 'total_revenue, commission_paid' or 'total_expenses'
    local values = type == 'revenue' and {restaurantId, amount, commission or 0, amount, commission or 0} or {restaurantId, amount, amount}
    
    MySQL.Async.execute(string.format([[
        INSERT INTO supply_restaurant_finances 
        (restaurant_id, financial_date, %s, customers_served)
        VALUES (?, CURDATE(), %s, 1)
        ON DUPLICATE KEY UPDATE 
        %s = %s + ?, 
        customers_served = customers_served + 1,
        net_profit = total_revenue - total_expenses
    ]], updateField, type == 'revenue' and '?, ?' or '?', updateField, updateField), values)
end

function initializeRestaurantSettings(restaurantId)
    local defaultSettings = {
        {'business', 'commission_rate', '0.15'},
        {'business', 'daily_rent', '500'},
        {'business', 'utility_cost', '200'},
        {'business', 'tax_rate', '0.08'},
        {'operations', 'max_staff', '8'},
        {'operations', 'auto_payroll', 'true'},
        {'quality', 'minimum_standard', 'good'},
        {'quality', 'auto_reject', 'false'}
    }
    
    for _, setting in ipairs(defaultSettings) do
        MySQL.Async.execute([[
            INSERT IGNORE INTO supply_restaurant_settings 
            (restaurant_id, setting_category, setting_name, setting_value, setting_type)
            VALUES (?, ?, ?, ?, 'string')
        ]], {restaurantId, setting[1], setting[2], setting[3]})
    end
end

function generateBusinessAlerts(restaurantId)
    local alerts = {}
    
    -- Add sample alerts logic here
    -- This would check for low profits, overdue payments, staff issues, etc.
    
    return alerts
end

function calculateTrend(restaurantId)
    -- Calculate profit trend over last 7 days vs previous 7 days
    return "Stable" -- Simplified for now
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- ===============================================
-- INTEGRATION WITH EXISTING SUPPLY CHAIN
-- ===============================================

-- Hook into existing delivery completion
AddEventHandler('delivery:completed', function(playerId, orderGroupId, restaurantId, deliveryData)
    -- Check if this was an owner order
    MySQL.Async.fetchScalar('SELECT ordered_by_owner FROM supply_orders WHERE order_group_id = ? LIMIT 1', 
    {orderGroupId}, function(isOwnerOrder)
        if isOwnerOrder == 1 then
            -- Owner order completed - log as business expense
            MySQL.Async.fetchScalar('SELECT SUM(total_cost) FROM supply_orders WHERE order_group_id = ?', 
            {orderGroupId}, function(totalCost)
                if totalCost then
                    logFinancialTransaction(restaurantId, 'supply_costs', totalCost, 
                        'Supply delivery completed', orderGroupId, nil)
                end
            end)
        end
    end)
end)

-- Daily financial processing (run via cron or scheduler)
function processDailyFinancials()
    -- Process rent, utilities, and other daily expenses for all owned restaurants
    MySQL.Async.fetchAll('SELECT * FROM supply_restaurant_ownership WHERE is_active = 1', {}, function(restaurants)
        for _, restaurant in ipairs(restaurants) do
            -- Get restaurant settings
            MySQL.Async.fetchAll([[
                SELECT setting_name, setting_value FROM supply_restaurant_settings 
                WHERE restaurant_id = ? AND setting_category = 'business'
            ]], {restaurant.restaurant_id}, function(settings)
                local dailyRent = 500
                local dailyUtilities = 200
                
                for _, setting in ipairs(settings) do
                    if setting.setting_name == 'daily_rent' then
                        dailyRent = tonumber(setting.setting_value) or 500
                    elseif setting.setting_name == 'utility_cost' then
                        dailyUtilities = tonumber(setting.setting_value) or 200
                    end
                end
                
                local totalDailyExpenses = dailyRent + dailyUtilities
                
                -- Log daily expenses
                logFinancialTransaction(restaurant.restaurant_id, 'rent', dailyRent, 'Daily rent', nil, nil)
                logFinancialTransaction(restaurant.restaurant_id, 'utilities', dailyUtilities, 'Daily utilities', nil, nil)
            end)
        end
    end)
end

print("^2[OGZ-SupplyChain]^7 Restaurant Financial Integration System Loaded!")
print("^3[INFO]^7 Owner benefits integrated with existing supply chain")
print("^3[INFO]^7 Financial tracking and staff management systems active")