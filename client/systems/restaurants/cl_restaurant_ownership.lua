-- ===============================================
-- RESTAURANT MANAGEMENT INTERFACE
-- Client-side management system for restaurant owners
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- State management
local currentRestaurantId = nil
local ownershipData = {}
local staffData = {}
local financialData = {}

-- ===============================================
-- RESTAURANT OWNERSHIP TARGETS & ZONES
-- ===============================================

-- Create management computer targets for all restaurants
Citizen.CreateThread(function()
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.ownership and restaurant.ownership.enabled then
            -- Management computer targets
            if restaurant.ownership.management then
                for _, mgmtPoint in pairs(restaurant.ownership.management) do
                    exports.ox_target:addBoxZone({
                        coords = mgmtPoint.coords,
                        size = vector3(1.5, 1.5, 1.0),
                        rotation = 0,
                        debug = Config.debug or false,
                        options = {
                            {
                                name = "restaurant_management_" .. restaurantId,
                                icon = "fas fa-laptop",
                                label = mgmtPoint.label or "Restaurant Management",
                                onSelect = function()
                                    TriggerEvent("restaurant:openManagementSystem", restaurantId)
                                end,
                                canInteract = function()
                                    return checkManagementAccess(restaurantId)
                                end
                            }
                        }
                    })
                end
            end
            
            -- Staff station targets
            if restaurant.ownership.stations then
                -- Kitchen stations
                if restaurant.ownership.stations.kitchen then
                    for _, station in pairs(restaurant.ownership.stations.kitchen) do
                        exports.ox_target:addBoxZone({
                            coords = station.coords,
                            size = vector3(1.0, 1.0, 1.0),
                            rotation = 0,
                            debug = Config.debug or false,
                            options = {
                                {
                                    name = "kitchen_station_" .. restaurantId,
                                    icon = "fas fa-fire",
                                    label = station.label,
                                    onSelect = function()
                                        TriggerEvent("restaurant:useKitchenStation", restaurantId, station.type)
                                    end,
                                    canInteract = function()
                                        return checkStationAccess(restaurantId, "kitchen_access")
                                    end
                                }
                            }
                        })
                    end
                end
                
                -- Service stations  
                if restaurant.ownership.stations.service then
                    for _, station in pairs(restaurant.ownership.stations.service) do
                        exports.ox_target:addBoxZone({
                            coords = station.coords,
                            size = vector3(1.0, 1.0, 1.0),
                            rotation = 0,
                            debug = Config.debug or false,
                            options = {
                                {
                                    name = "service_station_" .. restaurantId,
                                    icon = station.type == "register" and "fas fa-cash-register" or "fas fa-box",
                                    label = station.label,
                                    onSelect = function()
                                        if station.type == "register" then
                                            TriggerEvent("restaurant:openRegisterSystem", restaurantId)
                                        else
                                            TriggerEvent("restaurant:useServiceStation", restaurantId, station.type)
                                        end
                                    end,
                                    canInteract = function()
                                        return checkStationAccess(restaurantId, "register_access")
                                    end
                                }
                            }
                        })
                    end
                end
            end
            
            -- Storage access
            if restaurant.ownership.storage then
                for storageType, storage in pairs(restaurant.ownership.storage) do
                    exports.ox_target:addBoxZone({
                        coords = storage.coords,
                        size = vector3(1.0, 1.0, 1.0),
                        rotation = 0,
                        debug = Config.debug or false,
                        options = {
                            {
                                name = "restaurant_storage_" .. restaurantId .. "_" .. storageType,
                                icon = "fas fa-warehouse",
                                label = storage.label,
                                onSelect = function()
                                    TriggerEvent("restaurant:openStorage", restaurantId, storageType)
                                end,
                                canInteract = function()
                                    return checkStorageAccess(restaurantId)
                                end
                            }
                        }
                    })
                end
            end
        end
    end
end)

-- ===============================================
-- ACCESS CONTROL FUNCTIONS
-- ===============================================

function checkManagementAccess(restaurantId)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return false end
    
    -- Check traditional job access
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if PlayerData.job.name == restaurantJob and PlayerData.job.isboss then
        return true
    end
    
    -- Check ownership/staff access (server will validate)
    return true -- Temporarily allow, server will validate
end

function checkStationAccess(restaurantId, requiredPermission)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return false end
    
    -- Check traditional job access
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if PlayerData.job.name == restaurantJob then
        return true
    end
    
    -- Server will validate ownership/staff permissions
    return true
end

function checkStorageAccess(restaurantId)
    return checkStationAccess(restaurantId, "inventory_access")
end

-- ===============================================
-- MAIN MANAGEMENT SYSTEM
-- ===============================================

RegisterNetEvent("restaurant:openManagementSystem")
AddEventHandler("restaurant:openManagementSystem", function(restaurantId)
    currentRestaurantId = restaurantId
    
    -- Get current ownership status from server
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(data)
        ownershipData = data
        showMainManagementMenu(restaurantId)
    end, restaurantId)
end)

function showMainManagementMenu(restaurantId)
    local restaurantName = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].name or "Restaurant"
    local options = {}
    
    -- Always available: Basic restaurant functions
    table.insert(options, {
        title = "🛒 Order Ingredients",
        description = "Standard ingredient ordering system",
        icon = "fas fa-shopping-cart",
        onSelect = function()
            TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
        end
    })
    
    -- Owner-specific options
    if ownershipData and ownershipData.isOwner then
        table.insert(options, {
            title = "👑 Owner Dashboard",
            description = "Business overview and key metrics",
            icon = "fas fa-crown",
            onSelect = function()
                TriggerEvent("restaurant:openOwnerDashboard", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "💰 Financial Reports",
            description = "Revenue, expenses, and profit analysis",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("restaurant:openFinancialDashboard", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "👥 Staff Management",
            description = "Hire, fire, and manage restaurant staff",
            icon = "fas fa-users",
            onSelect = function()
                TriggerEvent("restaurant:openStaffManagement", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "📋 Menu Management",
            description = "Set prices and manage menu items",
            icon = "fas fa-utensils",
            onSelect = function()
                TriggerEvent("restaurant:openMenuManagement", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "⚙️ Business Settings",
            description = "Configure restaurant operations",
            icon = "fas fa-cog",
            onSelect = function()
                TriggerEvent("restaurant:openBusinessSettings", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "📦 Owner Supply Orders",
            description = "Place orders with owner benefits and discounts",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerEvent("restaurant:openOwnerSupplyMenu", restaurantId)
            end
        })
    end
    
    -- Manager options
    if ownershipData and (ownershipData.isOwner or ownershipData.position == "manager") then
        table.insert(options, {
            title = "📊 Daily Reports",
            description = "View daily performance and operations",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerEvent("restaurant:openDailyReports", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "⏰ Staff Scheduling",
            description = "Manage employee schedules and shifts",
            icon = "fas fa-calendar",
            onSelect = function()
                TriggerEvent("restaurant:openStaffScheduling", restaurantId)
            end
        })
    end
    
    -- Staff options
    if ownershipData and ownershipData.isStaff then
        table.insert(options, {
            title = "🕐 Clock In/Out",
            description = "Manage your work hours",
            icon = "fas fa-clock",
            onSelect = function()
                TriggerEvent("restaurant:toggleDuty", restaurantId)
            end
        })
    end
    
    -- Purchase option (if not owned)
    if not ownershipData or not ownershipData.isOwner then
        local restaurant = Config.Restaurants[restaurantId]
        if restaurant and restaurant.ownership and restaurant.ownership.enabled then
            table.insert(options, {
                title = "🏪 Purchase Restaurant",
                description = "Buy this restaurant and become the owner",
                icon = "fas fa-shopping-cart",
                onSelect = function()
                    TriggerEvent("restaurant:openPurchaseMenu", restaurantId)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_management_main",
        title = restaurantName .. " - Management System",
        options = options
    })
    lib.showContext("restaurant_management_main")
end

-- ===============================================
-- OWNER DASHBOARD
-- ===============================================

RegisterNetEvent("restaurant:openOwnerDashboard")
AddEventHandler("restaurant:openOwnerDashboard", function(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getDashboardData', function(data)
        showOwnerDashboard(restaurantId, data)
    end, restaurantId)
end)

function showOwnerDashboard(restaurantId, data)
    local restaurantName = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].name or "Restaurant"
    
    local options = {
        {
            title = "← Back to Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openManagementSystem", restaurantId)
            end
        },
        
        -- Today's Performance
        {
            title = "📊 Today's Performance",
            description = string.format("Revenue: $%s | Profit: $%s | Customers: %d", 
                formatCurrency(data.today.revenue or 0),
                formatCurrency(data.today.profit or 0),
                data.today.customers or 0),
            disabled = true
        },
        
        -- This Week
        {
            title = "📈 This Week",
            description = string.format("Revenue: $%s | Avg Daily Profit: $%s", 
                formatCurrency(data.week.revenue or 0),
                formatCurrency((data.week.profit or 0) / 7)),
            disabled = true
        },
        
        -- Staff Summary
        {
            title = "👥 Staff Summary",
            description = string.format("%d Active Staff | %d On Duty | $%s Daily Wages", 
                data.staff.total or 0,
                data.staff.onDuty or 0,
                formatCurrency(data.staff.dailyWages or 0)),
            disabled = true
        },
        
        -- Quick Actions
        {
            title = "⚡ Quick Actions",
            description = "Common management tasks",
            icon = "fas fa-bolt",
            arrow = true,
            onSelect = function()
                showQuickActions(restaurantId)
            end
        },
        
        -- Alerts & Notifications
        {
            title = "🔔 Business Alerts",
            description = string.format("%d active alerts requiring attention", #(data.alerts or {})),
            icon = "fas fa-bell",
            arrow = true,
            onSelect = function()
                showBusinessAlerts(restaurantId, data.alerts or {})
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_owner_dashboard",
        title = "👑 " .. restaurantName .. " - Owner Dashboard",
        options = options
    })
    lib.showContext("restaurant_owner_dashboard")
end

-- ===============================================
-- STAFF MANAGEMENT
-- ===============================================

RegisterNetEvent("restaurant:openStaffManagement")
AddEventHandler("restaurant:openStaffManagement", function(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getStaffData', function(staff)
        staffData = staff
        showStaffManagement(restaurantId)
    end, restaurantId)
end)

function showStaffManagement(restaurantId)
    local options = {
        {
            title = "← Back to Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openManagementSystem", restaurantId)
            end
        },
        
        {
            title = "➕ Hire New Employee",
            description = "Recruit new staff member",
            icon = "fas fa-plus",
            onSelect = function()
                TriggerEvent("restaurant:openHireMenu", restaurantId)
            end
        },
        
        {
            title = "💰 Payroll Management",
            description = "View and manage staff payments",
            icon = "fas fa-money-bill",
            onSelect = function()
                TriggerEvent("restaurant:openPayrollManagement", restaurantId)
            end
        },
        
        {
            title = "📋 Staff Overview",
            description = string.format("%d total employees", #(staffData or {})),
            disabled = true
        }
    }
    
    -- Add current staff members
    if staffData and #staffData > 0 then
        for _, employee in ipairs(staffData) do
            local statusIcon = employee.on_duty and "🟢" or "🔴"
            local performanceStars = string.rep("⭐", math.floor(employee.performance_rating or 0))
            
            table.insert(options, {
                title = statusIcon .. " " .. employee.employee_name,
                description = string.format("%s | $%s/hr | %s", 
                    employee.position:gsub("^%l", string.upper),
                    employee.hourly_wage,
                    performanceStars),
                metadata = {
                    Position = employee.position,
                    Wage = "$" .. employee.hourly_wage .. "/hour",
                    Status = employee.on_duty and "On Duty" or "Off Duty",
                    Performance = performanceStars
                },
                onSelect = function()
                    TriggerEvent("restaurant:openEmployeeMenu", restaurantId, employee)
                end
            })
        end
    else
        table.insert(options, {
            title = "👥 No Staff Hired",
            description = "Hire your first employee to get started",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "restaurant_staff_management",
        title = "👥 Staff Management",
        options = options
    })
    lib.showContext("restaurant_staff_management")
end

-- ===============================================
-- FINANCIAL DASHBOARD
-- ===============================================

RegisterNetEvent("restaurant:openFinancialDashboard")
AddEventHandler("restaurant:openFinancialDashboard", function(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getFinancialData', function(data)
        financialData = data
        showFinancialDashboard(restaurantId)
    end, restaurantId)
end)

function showFinancialDashboard(restaurantId)
    local restaurantName = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].name or "Restaurant"
    
    local options = {
        {
            title = "← Back to Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openManagementSystem", restaurantId)
            end
        },
        
        -- Profit & Loss Summary
        {
            title = "💹 Monthly Profit & Loss",
            description = string.format("Revenue: $%s | Expenses: $%s | Net: $%s", 
                formatCurrency(financialData.monthly.revenue or 0),
                formatCurrency(financialData.monthly.expenses or 0),
                formatCurrency(financialData.monthly.profit or 0)),
            disabled = true
        },
        
        -- Cash Flow
        {
            title = "💰 Current Cash Flow",
            description = string.format("Daily Average: $%s | Weekly Trend: %s", 
                formatCurrency(financialData.cashFlow.dailyAverage or 0),
                financialData.cashFlow.trend or "Stable"),
            disabled = true
        },
        
        -- Detailed Reports
        {
            title = "📊 Detailed Reports",
            description = "View comprehensive financial reports",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerEvent("restaurant:openDetailedReports", restaurantId)
            end
        },
        
        -- Expense Breakdown
        {
            title = "📉 Expense Analysis",
            description = "Analyze business expenses and identify savings",
            icon = "fas fa-chart-pie",
            onSelect = function()
                TriggerEvent("restaurant:openExpenseAnalysis", restaurantId)
            end
        },
        
        -- Payment Management
        {
            title = "💳 Payment Management",
            description = "Manage restaurant payments and financing",
            icon = "fas fa-credit-card",
            onSelect = function()
                TriggerEvent("restaurant:openPaymentManagement", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_financial_dashboard",
        title = "💰 " .. restaurantName .. " - Financial Dashboard",
        options = options
    })
    lib.showContext("restaurant_financial_dashboard")
end

-- ===============================================
-- PURCHASE SYSTEM
-- ===============================================

RegisterNetEvent("restaurant:openPurchaseMenu")
AddEventHandler("restaurant:openPurchaseMenu", function(restaurantId)
    local restaurant = Config.Restaurants[restaurantId]
    if not restaurant or not restaurant.ownership then return end
    
    local purchasePrice = restaurant.ownership.purchasePrice or 150000
    local minimumDown = purchasePrice * 0.25 -- 25% minimum down payment
    
    local options = {
        {
            title = "🏪 Purchase " .. (restaurant.name or "Restaurant"),
            description = string.format("Purchase Price: $%s", formatCurrency(purchasePrice)),
            disabled = true
        },
        
        {
            title = "💰 Cash Purchase",
            description = string.format("Pay full price: $%s", formatCurrency(purchasePrice)),
            icon = "fas fa-money-bill",
            onSelect = function()
                TriggerServerEvent("restaurant:purchaseRestaurant", restaurantId, "cash", purchasePrice)
            end
        },
        
        {
            title = "💳 Financing Options",
            description = string.format("Minimum down payment: $%s", formatCurrency(minimumDown)),
            icon = "fas fa-credit-card",
            onSelect = function()
                TriggerEvent("restaurant:openFinancingMenu", restaurantId, purchasePrice)
            end
        },
        
        {
            title = "📋 Requirements",
            description = "View purchase requirements and terms",
            icon = "fas fa-clipboard-check",
            onSelect = function()
                TriggerEvent("restaurant:showPurchaseRequirements", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_purchase_menu",
        title = "🏪 Restaurant Purchase",
        options = options
    })
    lib.showContext("restaurant_purchase_menu")
end)

-- ===============================================
-- REGISTER/POS SYSTEM
-- ===============================================

RegisterNetEvent("restaurant:openRegisterSystem")
AddEventHandler("restaurant:openRegisterSystem", function(restaurantId)
    local options = {
        {
            title = "💰 Process Sale",
            description = "Ring up customer order",
            icon = "fas fa-cash-register",
            onSelect = function()
                TriggerEvent("restaurant:startCustomerSale", restaurantId)
            end
        },
        
        {
            title = "📋 Daily Sales",
            description = "View today's sales summary",
            icon = "fas fa-receipt",
            onSelect = function()
                TriggerEvent("restaurant:viewDailySales", restaurantId)
            end
        },
        
        {
            title = "🔄 Process Refund",
            description = "Handle customer refunds",
            icon = "fas fa-undo",
            onSelect = function()
                TriggerEvent("restaurant:processRefund", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_register_system",
        title = "💰 Register/POS System",
        options = options
    })
    lib.showContext("restaurant_register_system")
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function formatCurrency(amount)
    if not amount or amount == 0 then return "0" end
    return string.format("%s", math.floor(amount))
end

function showQuickActions(restaurantId)
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOwnerDashboard", restaurantId)
            end
        },
        
        {
            title = "📦 Emergency Supply Order",
            description = "Place urgent ingredient order",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerEvent("restaurant:emergencySupplyOrder", restaurantId)
            end
        },
        
        {
            title = "👥 View Staff Status",
            description = "Check who's currently working",
            icon = "fas fa-users",
            onSelect = function()
                TriggerEvent("restaurant:viewStaffStatus", restaurantId)
            end
        },
        
        {
            title = "💰 Today's Revenue",
            description = "Quick revenue summary",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("restaurant:todaysRevenue", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_quick_actions",
        title = "⚡ Quick Actions",
        options = options
    })
    lib.showContext("restaurant_quick_actions")
end

function showBusinessAlerts(restaurantId, alerts)
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOwnerDashboard", restaurantId)
            end
        }
    }
    
    if #alerts == 0 then
        table.insert(options, {
            title = "✅ No Active Alerts",
            description = "Your restaurant is running smoothly!",
            disabled = true
        })
    else
        for _, alert in ipairs(alerts) do
            local alertIcon = alert.level == "critical" and "🚨" or 
                             alert.level == "warning" and "⚠️" or "ℹ️"
                             
            table.insert(options, {
                title = alertIcon .. " " .. alert.title,
                description = alert.message,
                onSelect = function()
                    TriggerEvent("restaurant:handleAlert", restaurantId, alert)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_business_alerts",
        title = "🔔 Business Alerts",
        options = options
    })
    lib.showContext("restaurant_business_alerts")
end

-- ===============================================
-- INITIALIZATION
-- ===============================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2[OGZ-SupplyChain]^7 Restaurant Management Interface Loaded!")
        print("^3[INFO]^7 Management computers created for " .. (Config.Restaurants and #Config.Restaurants or 0) .. " restaurants")
    end
end)