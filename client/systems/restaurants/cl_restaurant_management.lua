-- ===============================================
-- RESTAURANT BUSINESS MANAGEMENT SYSTEM
-- Enterprise business ownership and financial management
-- File: client/systems/restaurants/cl_restaurant_management.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()
local job = Framework.GetPlayerJob()
local hasAccess = Framework.HasJob("hurst")
-- ===============================================
-- STATE MANAGEMENT
-- ===============================================

local isBusinessMenuOpen = false
local currentDashboardData = {}
local currentFinancialData = {}

-- ===============================================
-- BUSINESS MANAGEMENT ENTRY POINT
-- ===============================================

-- Main business management menu
RegisterNetEvent("restaurant:openBusinessManagement")
AddEventHandler("restaurant:openBusinessManagement", function(restaurantId)
    if isBusinessMenuOpen then return end
    
    -- Check ownership first
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        if not ownershipData.isOwner then
            exports.ogz_supplychain:errorNotify("Access Denied", "You must own this restaurant to access business management")
            return
        end
        
        isBusinessMenuOpen = true
        
        -- Load dashboard data
        QBCore.Functions.TriggerCallback('restaurant:getDashboardData', function(dashboardData)
            currentDashboardData = dashboardData
            showBusinessDashboard(restaurantId)
        end, restaurantId)
    end, restaurantId)
end)

-- ===============================================
-- BUSINESS DASHBOARD
-- ===============================================

function showBusinessDashboard(restaurantId)
    local restaurant = Config.Restaurants[restaurantId]
    local today = currentDashboardData.today or {}
    local week = currentDashboardData.week or {}
    local staff = currentDashboardData.staff or {}
    
    local options = {
        {
            title = "← Back to Restaurant",
            icon = "fas fa-arrow-left",
            onSelect = function()
                isBusinessMenuOpen = false
                TriggerEvent("restaurant:openMainMenu", { restaurantId = restaurantId })
            end
        },
        {
            title = "📊 Today's Performance",
            description = string.format("Revenue: $%s • Profit: $%s • Customers: %d", 
                SupplyUtils.formatMoney(today.revenue or 0),
                SupplyUtils.formatMoney(today.profit or 0), 
                today.customers or 0),
            icon = "fas fa-chart-line",
            disabled = true
        },
        {
            title = "📈 Weekly Summary", 
            description = string.format("Revenue: $%s • Profit: $%s", 
                SupplyUtils.formatMoney(week.revenue or 0),
                SupplyUtils.formatMoney(week.profit or 0)),
            icon = "fas fa-calendar-week",
            disabled = true
        },
        {
            title = "👥 Staff Overview",
            description = string.format("%d total staff • %d on duty • Daily wages: $%s",
                staff.total or 0, staff.onDuty or 0, SupplyUtils.formatMoney(staff.dailyWages or 0)),
            icon = "fas fa-users",
            disabled = true
        },
        {
            title = "💰 Financial Reports",
            description = "View detailed profit/loss and cash flow",
            icon = "fas fa-file-invoice-dollar",
            onSelect = function()
                openFinancialReports(restaurantId)
            end
        },
        {
            title = "⚙️ Business Settings",
            description = "Configure restaurant operations and preferences",
            icon = "fas fa-cog",
            onSelect = function()
                openBusinessSettings(restaurantId)
            end
        },
        {
            title = "🎯 Performance Analytics",
            description = "Advanced business intelligence and trends",
            icon = "fas fa-analytics",
            onSelect = function()
                openPerformanceAnalytics(restaurantId)
            end
        }
    }
    
    -- Add alerts if any
    if currentDashboardData.alerts and #currentDashboardData.alerts > 0 then
        table.insert(options, {
            title = "🚨 Business Alerts (" .. #currentDashboardData.alerts .. ")",
            description = "Important notifications requiring attention",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                showBusinessAlerts(restaurantId)
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_business_dashboard",
        title = "🏪 " .. restaurant.name .. " - Business Dashboard",
        options = options,
        onExit = function()
            isBusinessMenuOpen = false
        end
    })
    lib.showContext("restaurant_business_dashboard")
end

-- ===============================================
-- FINANCIAL REPORTS
-- ===============================================

function openFinancialReports(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getFinancialData', function(financialData)
        currentFinancialData = financialData
        
        local monthly = financialData.monthly or {}
        local cashFlow = financialData.cashFlow or {}
        
        local options = {
            {
                title = "← Back to Dashboard",
                icon = "fas fa-arrow-left",
                onSelect = function()
                    showBusinessDashboard(restaurantId)
                end
            },
            {
                title = "📊 Monthly Financial Summary",
                description = "Comprehensive 30-day financial overview",
                disabled = true
            },
            {
                title = "💰 Total Revenue",
                description = "$" .. SupplyUtils.formatMoney(monthly.revenue or 0),
                icon = "fas fa-dollar-sign",
                metadata = {
                    ["Monthly Revenue"] = "$" .. SupplyUtils.formatMoney(monthly.revenue or 0),
                    ["Daily Average"] = "$" .. SupplyUtils.formatMoney((monthly.revenue or 0) / 30)
                }
            },
            {
                title = "💸 Total Expenses",
                description = "$" .. SupplyUtils.formatMoney(monthly.expenses or 0),
                icon = "fas fa-credit-card",
                metadata = {
                    ["Monthly Expenses"] = "$" .. SupplyUtils.formatMoney(monthly.expenses or 0),
                    ["Daily Average"] = "$" .. SupplyUtils.formatMoney((monthly.expenses or 0) / 30)
                }
            },
            {
                title = "📈 Net Profit",
                description = "$" .. SupplyUtils.formatMoney(monthly.profit or 0),
                icon = monthly.profit >= 0 and "fas fa-arrow-up" or "fas fa-arrow-down",
                metadata = {
                    ["Monthly Profit"] = "$" .. SupplyUtils.formatMoney(monthly.profit or 0),
                    ["Daily Average"] = "$" .. SupplyUtils.formatMoney(cashFlow.dailyAverage or 0),
                    ["Trend"] = cashFlow.trend or "Stable"
                }
            },
            {
                title = "💹 Profit Margin",
                description = string.format("%.1f%% profit margin", 
                    monthly.revenue > 0 and ((monthly.profit or 0) / monthly.revenue * 100) or 0),
                icon = "fas fa-percentage"
            },
            {
                title = "📋 Export Financial Report",
                description = "Generate detailed financial statement",
                icon = "fas fa-file-export",
                onSelect = function()
                    TriggerServerEvent("restaurant:generateFinancialReport", restaurantId, "monthly")
                    exports.ogz_supplychain:successNotify("Report Generated", "Financial report has been generated")
                end
            }
        }
        
        lib.registerContext({
            id = "restaurant_financial_reports",
            title = "💰 Financial Reports",
            options = options
        })
        lib.showContext("restaurant_financial_reports")
    end, restaurantId)
end

-- ===============================================
-- BUSINESS SETTINGS
-- ===============================================

function openBusinessSettings(restaurantId)
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                showBusinessDashboard(restaurantId)
            end
        },
        {
            title = "⚙️ Business Configuration",
            description = "Core business settings and preferences",
            disabled = true
        },
        {
            title = "🎯 Quality Standards",
            description = "Set ingredient quality requirements",
            icon = "fas fa-star",
            onSelect = function()
                openQualityStandards(restaurantId)
            end
        },
        {
            title = "💳 Payment Settings",
            description = "Configure commission rates and payment terms",
            icon = "fas fa-credit-card",
            onSelect = function()
                openPaymentSettings(restaurantId)
            end
        },
        {
            title = "👥 Staff Policies",
            description = "Set staff wages, schedules, and policies",
            icon = "fas fa-users-cog",
            onSelect = function()
                openStaffPolicies(restaurantId)
            end
        },
        {
            title = "📦 Supply Chain Preferences",
            description = "Configure ordering and delivery preferences", 
            icon = "fas fa-truck",
            onSelect = function()
                openSupplyChainSettings(restaurantId)
            end
        },
        {
            title = "🔐 Access Control",
            description = "Manage restaurant access and permissions",
            icon = "fas fa-key",
            onSelect = function()
                openAccessControl(restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_business_settings",
        title = "⚙️ Business Settings",
        options = options
    })
    lib.showContext("restaurant_business_settings")
end

-- Quality standards configuration
function openQualityStandards(restaurantId)
    local options = {
        {
            title = "← Back to Settings",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openBusinessSettings(restaurantId)
            end
        },
        {
            title = "⭐ Minimum Quality Standard",
            description = "Set minimum acceptable ingredient quality",
            icon = "fas fa-star",
            onSelect = function()
                local input = lib.inputDialog("Set Quality Standard", {
                    {
                        type = "select",
                        label = "Minimum Quality",
                        options = {
                            {value = "fair", label = "Fair - Basic quality"},
                            {value = "good", label = "Good - Standard quality"},
                            {value = "excellent", label = "Excellent - Premium quality"}
                        },
                        required = true
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "quality", "minimum_standard", input[1])
                    exports.ogz_supplychain:successNotify("Quality Standard Updated", "Minimum quality set to " .. input[1])
                end
            end
        },
        {
            title = "🚫 Auto-Reject Below Standard",
            description = "Automatically reject deliveries below quality standard",
            icon = "fas fa-times-circle",
            onSelect = function()
                local input = lib.inputDialog("Auto-Reject Settings", {
                    {
                        type = "checkbox",
                        label = "Enable auto-reject",
                        checked = false
                    }
                })
                if input then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "quality", "auto_reject", input[1])
                    exports.ogz_supplychain:successNotify("Auto-Reject Updated", input[1] and "Enabled" or "Disabled")
                end
            end
        },
        {
            title = "💎 Premium Quality Bonus",
            description = "Extra payment for premium quality ingredients",
            icon = "fas fa-gem",
            onSelect = function()
                local input = lib.inputDialog("Premium Bonus Rate", {
                    {
                        type = "number",
                        label = "Bonus Percentage",
                        placeholder = "5",
                        min = 0,
                        max = 50,
                        step = 1
                    }
                })
                if input and input[1] then
                    local bonus = tonumber(input[1]) / 100
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "quality", "premium_bonus", tostring(bonus))
                    exports.ogz_supplychain:successNotify("Premium Bonus Set", string.format("%d%% bonus for premium quality", input[1]))
                end
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_quality_standards",
        title = "⭐ Quality Standards",
        options = options
    })
    lib.showContext("restaurant_quality_standards")
end

-- Payment settings
function openPaymentSettings(restaurantId)
    local options = {
        {
            title = "← Back to Settings",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openBusinessSettings(restaurantId)
            end
        },
        {
            title = "💰 Commission Rate",
            description = "Percentage of sales revenue retained by restaurant",
            icon = "fas fa-percentage",
            onSelect = function()
                local input = lib.inputDialog("Set Commission Rate", {
                    {
                        type = "number",
                        label = "Commission Percentage",
                        placeholder = "15",
                        min = 5,
                        max = 30,
                        step = 1
                    }
                })
                if input and input[1] then
                    local rate = tonumber(input[1]) / 100
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "business", "commission_rate", tostring(rate))
                    exports.ogz_supplychain:successNotify("Commission Rate Updated", string.format("Set to %d%%", input[1]))
                end
            end
        },
        {
            title = "🏠 Daily Rent",
            description = "Daily rental cost for restaurant space",
            icon = "fas fa-home",
            onSelect = function()
                local input = lib.inputDialog("Set Daily Rent", {
                    {
                        type = "number",
                        label = "Daily Rent Amount",
                        placeholder = "500",
                        min = 100,
                        max = 2000
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "business", "daily_rent", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Daily Rent Updated", "$" .. SupplyUtils.formatMoney(input[1]) .. " per day")
                end
            end
        },
        {
            title = "⚡ Utility Costs",
            description = "Daily utility expenses (electricity, water, etc.)",
            icon = "fas fa-bolt",
            onSelect = function()
                local input = lib.inputDialog("Set Utility Costs", {
                    {
                        type = "number",
                        label = "Daily Utility Cost",
                        placeholder = "200",
                        min = 50,
                        max = 500
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "business", "utility_cost", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Utility Costs Updated", "$" .. SupplyUtils.formatMoney(input[1]) .. " per day")
                end
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_payment_settings",
        title = "💳 Payment Settings",
        options = options
    })
    lib.showContext("restaurant_payment_settings")
end

-- Staff policies
function openStaffPolicies(restaurantId)
    local options = {
        {
            title = "← Back to Settings",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openBusinessSettings(restaurantId)
            end
        },
        {
            title = "💰 Default Wage Rates",
            description = "Set standard hourly wages for each position",
            icon = "fas fa-dollar-sign",
            onSelect = function()
                showWageSettings(restaurantId)
            end
        },
        {
            title = "📅 Automatic Payroll",
            description = "Enable/disable automatic daily payroll processing",
            icon = "fas fa-calendar-check",
            onSelect = function()
                local input = lib.inputDialog("Payroll Settings", {
                    {
                        type = "checkbox",
                        label = "Enable automatic payroll",
                        checked = true
                    }
                })
                if input then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "operations", "auto_payroll", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Payroll Setting", input[1] and "Automatic payroll enabled" or "Automatic payroll disabled")
                end
            end
        },
        {
            title = "👥 Maximum Staff Count",
            description = "Set maximum number of employees",
            icon = "fas fa-users",
            onSelect = function()
                local input = lib.inputDialog("Staff Limit", {
                    {
                        type = "number",
                        label = "Maximum Staff",
                        placeholder = "8",
                        min = 1,
                        max = 20
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "operations", "max_staff", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Staff Limit Updated", "Maximum " .. input[1] .. " employees")
                end
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_staff_policies",
        title = "👥 Staff Policies",
        options = options
    })
    lib.showContext("restaurant_staff_policies")
end

-- Wage settings
function showWageSettings(restaurantId)
    local positions = Config.RestaurantOwnership.staffManagement.positions
    
    local options = {
        {
            title = "← Back to Staff Policies",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openStaffPolicies(restaurantId)
            end
        }
    }
    
    for position, details in pairs(positions) do
        if position ~= "owner" then -- Owners don't get wages
            table.insert(options, {
                title = SupplyUtils.capitalizeFirst(position),
                description = string.format("Current: $%d/hour • %s", details.basePay, details.description),
                icon = "fas fa-user",
                onSelect = function()
                    local input = lib.inputDialog("Set " .. SupplyUtils.capitalizeFirst(position) .. " Wage", {
                        {
                            type = "number",
                            label = "Hourly Wage",
                            placeholder = tostring(details.basePay),
                            min = 10,
                            max = 50
                        }
                    })
                    if input and input[1] then
                        TriggerServerEvent("restaurant:updateStaffWage", restaurantId, position, input[1])
                        exports.ogz_supplychain:successNotify("Wage Updated", 
                            string.format("%s wage set to $%d/hour", SupplyUtils.capitalizeFirst(position), input[1]))
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_wage_settings",
        title = "💰 Wage Settings",
        options = options
    })
    lib.showContext("restaurant_wage_settings")
end

-- Supply chain settings
function openSupplyChainSettings(restaurantId)
    local options = {
        {
            title = "← Back to Settings",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openBusinessSettings(restaurantId)
            end
        },
        {
            title = "🚚 Priority Delivery",
            description = "Enable priority delivery for owner orders",
            icon = "fas fa-shipping-fast",
            onSelect = function()
                local input = lib.inputDialog("Priority Delivery", {
                    {
                        type = "checkbox",
                        label = "Enable priority delivery",
                        checked = true
                    }
                })
                if input then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "supply", "priority_delivery", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Priority Delivery", input[1] and "Enabled" or "Disabled")
                end
            end
        },
        {
            title = "📦 Container Preferences",
            description = "Set preferred container types for deliveries",
            icon = "fas fa-box",
            onSelect = function()
                openContainerPreferences(restaurantId)
            end
        },
        {
            title = "⏰ Emergency Ordering",
            description = "24/7 emergency order capability",
            icon = "fas fa-clock",
            onSelect = function()
                local input = lib.inputDialog("Emergency Ordering", {
                    {
                        type = "checkbox",
                        label = "Enable 24/7 emergency orders",
                        checked = true
                    }
                })
                if input then
                    TriggerServerEvent("restaurant:updateBusinessSetting", restaurantId, "supply", "emergency_ordering", tostring(input[1]))
                    exports.ogz_supplychain:successNotify("Emergency Ordering", input[1] and "Enabled" or "Disabled")
                end
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_supply_settings",
        title = "📦 Supply Chain Settings",
        options = options
    })
    lib.showContext("restaurant_supply_settings")
end

-- Container preferences
function openContainerPreferences(restaurantId)
    local containerTypes = Config.DynamicContainers and Config.DynamicContainers.containerTypes or {}
    
    local options = {
        {
            title = "← Back to Supply Settings",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openSupplyChainSettings(restaurantId)
            end
        },
        {
            title = "📦 Preferred Container Types",
            description = "Select preferred containers for different ingredients",
            disabled = true
        }
    }
    
    for containerType, details in pairs(containerTypes) do
        table.insert(options, {
            title = details.name,
            description = string.format("$%d each • %s", details.cost, details.description),
            icon = details.icon or "fas fa-box",
            onSelect = function()
                local input = lib.inputDialog("Container Preference", {
                    {
                        type = "checkbox",
                        label = "Set as preferred container",
                        checked = false
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:setContainerPreference", restaurantId, containerType, input[1])
                    exports.ogz_supplychain:successNotify("Container Preference", 
                        input[1] and ("Set " .. details.name .. " as preferred") or ("Removed " .. details.name .. " preference"))
                end
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_container_preferences",
        title = "📦 Container Preferences",
        options = options
    })
    lib.showContext("restaurant_container_preferences")
end

-- ===============================================
-- PERFORMANCE ANALYTICS
-- ===============================================

function openPerformanceAnalytics(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getPerformanceAnalytics', function(analytics)
        local options = {
            {
                title = "← Back to Dashboard",
                icon = "fas fa-arrow-left",
                onSelect = function()
                    showBusinessDashboard(restaurantId)
                end
            },
            {
                title = "📊 Performance Metrics",
                description = "Advanced business intelligence and trends",
                disabled = true
            },
            {
                title = "📈 Revenue Trends",
                description = "7-day, 30-day, and 90-day revenue analysis",
                icon = "fas fa-chart-line",
                onSelect = function()
                    showRevenueTrends(restaurantId, analytics.revenue)
                end
            },
            {
                title = "👥 Customer Analytics",
                description = "Customer behavior and satisfaction metrics",
                icon = "fas fa-users",
                onSelect = function()
                    showCustomerAnalytics(restaurantId, analytics.customers)
                end
            },
            {
                title = "📦 Supply Chain Efficiency",
                description = "Delivery times, quality scores, and cost analysis",
                icon = "fas fa-truck",
                onSelect = function()
                    showSupplyChainAnalytics(restaurantId, analytics.supply)
                end
            },
            {
                title = "🎯 Profitability Analysis",
                description = "Profit margins, cost breakdowns, and optimization",
                icon = "fas fa-bullseye",
                onSelect = function()
                    showProfitabilityAnalysis(restaurantId, analytics.profitability)
                end
            }
        }
        
        lib.registerContext({
            id = "restaurant_performance_analytics",
            title = "🎯 Performance Analytics",
            options = options
        })
        lib.showContext("restaurant_performance_analytics")
    end, restaurantId)
end

-- ===============================================
-- BUSINESS ALERTS
-- ===============================================

function showBusinessAlerts(restaurantId)
    local alerts = currentDashboardData.alerts or {}
    
    local options = {
        {
            title = "← Back to Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                showBusinessDashboard(restaurantId)
            end
        }
    }
    
    if #alerts == 0 then
        table.insert(options, {
            title = "✅ No Active Alerts",
            description = "Your restaurant is operating smoothly",
            disabled = true
        })
    else
        for _, alert in ipairs(alerts) do
            local alertIcon = getAlertIcon(alert.level)
            
            table.insert(options, {
                title = alertIcon .. " " .. alert.title,
                description = alert.description,
                icon = "fas fa-exclamation-triangle",
                onSelect = function()
                    if alert.action then
                        TriggerServerEvent("restaurant:handleAlert", restaurantId, alert.id)
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_business_alerts",
        title = "🚨 Business Alerts",
        options = options
    })
    lib.showContext("restaurant_business_alerts")
end

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function getAlertIcon(level)
    local icons = {
        low = "ℹ️",
        medium = "⚠️",
        high = "🚨",
        critical = "💀"
    }
    return icons[level] or "ℹ️"
end

-- ===============================================
-- EVENT HANDLERS
-- ===============================================

-- Handle financial report generation
RegisterNetEvent("restaurant:financialReportGenerated")
AddEventHandler("restaurant:financialReportGenerated", function(reportData)
    exports.ogz_supplychain:successNotify("Report Ready", "Financial report has been generated and saved")
end)

-- Handle business setting updates
RegisterNetEvent("restaurant:businessSettingUpdated")
AddEventHandler("restaurant:businessSettingUpdated", function(setting, value)
    exports.ogz_supplychain:successNotify("Setting Updated", string.format("%s updated successfully", setting))
end)

-- ===============================================
-- CLEANUP
-- ===============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        isBusinessMenuOpen = false
        currentDashboardData = {}
        currentFinancialData = {}
    end
end)