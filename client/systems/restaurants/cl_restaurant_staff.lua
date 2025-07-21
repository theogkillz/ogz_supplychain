-- ===============================================
-- RESTAURANT STAFF MANAGEMENT SYSTEM
-- Enterprise staff operations and HR management
-- File: client/systems/restaurants/cl_restaurant_staff.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()
local job = Framework.GetPlayerJob()
local hasAccess = Framework.HasJob("hurst")
-- ===============================================
-- STATE MANAGEMENT
-- ===============================================

local isStaffMenuOpen = false
local currentStaffData = {}
local nearbyPlayers = {}

-- ===============================================
-- STAFF MANAGEMENT ENTRY POINT
-- ===============================================

-- Main staff management menu
RegisterNetEvent("restaurant:openStaffManagement")
AddEventHandler("restaurant:openStaffManagement", function(restaurantId)
    if isStaffMenuOpen then return end
    
    -- Check ownership/management permissions
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        if not ownershipData.isOwner and not table.contains(ownershipData.permissions, "hire_staff") then
            exports.ogz_supplychain:errorNotify("Access Denied", "You do not have staff management permissions")
            return
        end
        
        isStaffMenuOpen = true
        
        -- Load staff data
        QBCore.Functions.TriggerCallback('restaurant:getStaffData', function(staffData)
            currentStaffData = staffData
            showStaffDashboard(restaurantId, ownershipData)
        end, restaurantId)
    end, restaurantId)
end)

-- ===============================================
-- STAFF DASHBOARD
-- ===============================================

function showStaffDashboard(restaurantId, ownershipData)
    local restaurant = Config.Restaurants[restaurantId]
    local totalStaff = #currentStaffData
    local onDutyStaff = 0
    local totalWages = 0
    
    -- Calculate stats
    for _, staff in ipairs(currentStaffData) do
        if staff.on_duty == 1 then
            onDutyStaff = onDutyStaff + 1
        end
        totalWages = totalWages + (staff.hourly_wage or 0)
    end
    
    local options = {
        {
            title = "← Back to Restaurant",
            icon = "fas fa-arrow-left",
            onSelect = function()
                isStaffMenuOpen = false
                TriggerEvent("restaurant:openMainMenu", { restaurantId = restaurantId })
            end
        },
        {
            title = "👥 Staff Overview",
            description = string.format("%d total employees • %d on duty • $%s/hour total wages",
                totalStaff, onDutyStaff, SupplyUtils.formatMoney(totalWages)),
            icon = "fas fa-users",
            disabled = true
        },
        {
            title = "🆕 Hire New Employee",
            description = "Recruit and hire new staff members",
            icon = "fas fa-user-plus",
            onSelect = function()
                openHiringInterface(restaurantId, ownershipData)
            end
        },
        {
            title = "📋 Manage Employees",
            description = "View and manage current staff",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                showEmployeeList(restaurantId, ownershipData)
            end
        },
        {
            title = "💰 Payroll Management",
            description = "Process payroll and view wage reports",
            icon = "fas fa-money-check-alt",
            onSelect = function()
                openPayrollManagement(restaurantId, ownershipData)
            end
        },
        {
            title = "📅 Staff Schedule",
            description = "Manage employee schedules and shifts",
            icon = "fas fa-calendar-alt",
            onSelect = function()
                openStaffSchedule(restaurantId, ownershipData)
            end
        },
        {
            title = "📊 Performance Reports",
            description = "View staff performance and analytics",
            icon = "fas fa-chart-bar",
            onSelect = function()
                openPerformanceReports(restaurantId, ownershipData)
            end
        },
        {
            title = "🎯 Staff Training",
            description = "Manage employee training and development",
            icon = "fas fa-graduation-cap",
            onSelect = function()
                openStaffTraining(restaurantId, ownershipData)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_staff_dashboard",
        title = "👥 " .. restaurant.name .. " - Staff Management",
        options = options,
        onExit = function()
            isStaffMenuOpen = false
        end
    })
    lib.showContext("restaurant_staff_dashboard")
end

-- ===============================================
-- HIRING INTERFACE
-- ===============================================

function openHiringInterface(restaurantId, ownershipData)
    -- Get nearby players
    getNearbyPlayers(function(players)
        local options = {
            {
                title = "← Back to Staff Dashboard",
                icon = "fas fa-arrow-left",
                onSelect = function()
                    showStaffDashboard(restaurantId, ownershipData)
                end
            },
            {
                title = "🆕 Hire New Employee",
                description = "Select a player to hire",
                disabled = true
            }
        }
        
        if #players == 0 then
            table.insert(options, {
                title = "👥 No Players Nearby",
                description = "No eligible players found in the area",
                disabled = true
            })
        else
            for _, player in ipairs(players) do
                table.insert(options, {
                    title = player.name,
                    description = string.format("ID: %d • Distance: %.1fm", player.id, player.distance),
                    icon = "fas fa-user",
                    onSelect = function()
                        openPositionSelection(restaurantId, player.id, player.name, ownershipData)
                    end
                })
            end
        end
        
        lib.registerContext({
            id = "restaurant_hiring_interface",
            title = "🆕 Hire New Employee",
            options = options
        })
        lib.showContext("restaurant_hiring_interface")
    end)
end

function openPositionSelection(restaurantId, targetPlayerId, targetName, ownershipData)
    local positions = Config.RestaurantOwnership.staffManagement.positions
    
    local options = {
        {
            title = "← Back to Hiring",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openHiringInterface(restaurantId, ownershipData)
            end
        },
        {
            title = string.format("👤 Hiring: %s", targetName),
            description = "Select position and wage",
            disabled = true
        }
    }
    
    for position, details in pairs(positions) do
        if position ~= "owner" then -- Can't hire owners
            table.insert(options, {
                title = SupplyUtils.capitalizeFirst(position),
                description = string.format("Base: $%d/hour • %s", details.basePay, details.description),
                icon = "fas fa-briefcase",
                onSelect = function()
                    local input = lib.inputDialog("Set Employment Details", {
                        {
                            type = "number",
                            label = "Hourly Wage",
                            placeholder = tostring(details.basePay),
                            min = 10,
                            max = 50,
                            required = true
                        },
                        {
                            type = "textarea",
                            label = "Welcome Message (Optional)",
                            placeholder = "Welcome to our team!",
                            max = 200
                        }
                    })
                    if input and input[1] then
                        local wage = tonumber(input[1])
                        local welcomeMsg = input[2] or "Welcome to our team!"
                        
                        lib.alertDialog({
                            header = "Confirm Hiring",
                            content = string.format(
                                "Hire **%s** as **%s** for **$%d/hour**?\n\n%s",
                                targetName, SupplyUtils.capitalizeFirst(position), wage, welcomeMsg
                            ),
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = "Hire Employee",
                                cancel = "Cancel"
                            }
                        }):next(function(confirmed)
                            if confirmed then
                                TriggerServerEvent("restaurant:hireEmployee", restaurantId, targetPlayerId, position, wage)
                                exports.ogz_supplychain:successNotify("Hiring Initiated", "Sending job offer to " .. targetName)
                                isStaffMenuOpen = false
                            end
                        end)
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_position_selection",
        title = "📝 Select Position",
        options = options
    })
    lib.showContext("restaurant_position_selection")
end

-- ===============================================
-- EMPLOYEE MANAGEMENT
-- ===============================================

function showEmployeeList(restaurantId, ownershipData)
    local options = {
        {
            title = "← Back to Staff Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                showStaffDashboard(restaurantId, ownershipData)
            end
        },
        {
            title = "👥 Current Employees",
            description = string.format("%d employees total", #currentStaffData),
            disabled = true
        }
    }
    
    if #currentStaffData == 0 then
        table.insert(options, {
            title = "📭 No Employees",
            description = "No staff members hired yet",
            disabled = true
        })
    else
        -- Sort staff by position and name
        table.sort(currentStaffData, function(a, b)
            if a.position == b.position then
                return a.employee_name < b.employee_name
            end
            return a.position < b.position
        end)
        
        for _, staff in ipairs(currentStaffData) do
            local statusIcon = staff.on_duty == 1 and "🟢" or "🔴"
            local positionIcon = getPositionIcon(staff.position)
            
            table.insert(options, {
                title = string.format("%s %s %s", statusIcon, positionIcon, staff.employee_name),
                description = string.format("%s • $%d/hour • %s", 
                    SupplyUtils.capitalizeFirst(staff.position),
                    staff.hourly_wage or 0,
                    staff.on_duty == 1 and "On Duty" or "Off Duty"
                ),
                icon = "fas fa-user",
                onSelect = function()
                    openEmployeeDetails(restaurantId, staff, ownershipData)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_employee_list",
        title = "👥 Employee List",
        options = options
    })
    lib.showContext("restaurant_employee_list")
end

function openEmployeeDetails(restaurantId, employee, ownershipData)
    local canFire = ownershipData.isOwner or table.contains(ownershipData.permissions, "fire_staff")
    local canEditWages = ownershipData.isOwner or table.contains(ownershipData.permissions, "set_wages")
    
    local options = {
        {
            title = "← Back to Employee List",
            icon = "fas fa-arrow-left",
            onSelect = function()
                showEmployeeList(restaurantId, ownershipData)
            end
        },
        {
            title = "👤 " .. employee.employee_name,
            description = string.format("Employee ID: %s", employee.employee_citizenid),
            disabled = true
        },
        {
            title = "📋 Position Information",
            description = string.format("Position: %s • Wage: $%d/hour", 
                SupplyUtils.capitalizeFirst(employee.position), employee.hourly_wage or 0),
            icon = "fas fa-briefcase",
            disabled = true
        },
        {
            title = "⏰ Work Status",
            description = employee.on_duty == 1 and "Currently on duty" or "Currently off duty",
            icon = employee.on_duty == 1 and "fas fa-clock" or "fas fa-pause-circle",
            disabled = true
        },
        {
            title = "📊 View Performance",
            description = "View employee performance and statistics",
            icon = "fas fa-chart-line",
            onSelect = function()
                showEmployeePerformance(restaurantId, employee, ownershipData)
            end
        },
        {
            title = "💰 Wage History",
            description = "View payroll and wage history",
            icon = "fas fa-money-bill-wave",
            onSelect = function()
                showEmployeeWageHistory(restaurantId, employee, ownershipData)
            end
        }
    }
    
    if canEditWages then
        table.insert(options, {
            title = "📝 Edit Wage",
            description = "Change employee hourly wage",
            icon = "fas fa-edit",
            onSelect = function()
                local input = lib.inputDialog("Edit Wage", {
                    {
                        type = "number",
                        label = "New Hourly Wage",
                        placeholder = tostring(employee.hourly_wage),
                        min = 10,
                        max = 50,
                        required = true
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("restaurant:updateEmployeeWage", restaurantId, employee.employee_citizenid, input[1])
                    exports.ogz_supplychain:successNotify("Wage Updated", 
                        string.format("%s wage updated to $%d/hour", employee.employee_name, input[1]))
                end
            end
        })
    end
    
    if canFire and employee.position ~= "owner" then
        table.insert(options, {
            title = "🚫 Terminate Employee",
            description = "Fire employee (permanent action)",
            icon = "fas fa-user-times",
            onSelect = function()
                local input = lib.inputDialog("Termination Reason", {
                    {
                        type = "textarea",
                        label = "Reason for Termination",
                        placeholder = "Enter reason for termination",
                        required = true,
                        max = 200
                    }
                })
                if input and input[1] then
                    lib.alertDialog({
                        header = "⚠️ Confirm Termination",
                        content = string.format(
                            "Are you sure you want to fire **%s**?\n\nReason: %s\n\n**This action cannot be undone.**",
                            employee.employee_name, input[1]
                        ),
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Fire Employee",
                            cancel = "Cancel"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            TriggerServerEvent("restaurant:fireEmployee", restaurantId, employee.employee_citizenid, input[1])
                            exports.ogz_supplychain:successNotify("Employee Terminated", employee.employee_name .. " has been fired")
                            isStaffMenuOpen = false
                        end
                    end)
                end
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_employee_details",
        title = "👤 " .. employee.employee_name,
        options = options
    })
    lib.showContext("restaurant_employee_details")
end

-- ===============================================
-- PAYROLL MANAGEMENT
-- ===============================================

function openPayrollManagement(restaurantId, ownershipData)
    QBCore.Functions.TriggerCallback('restaurant:getPayrollData', function(payrollData)
        local options = {
            {
                title = "← Back to Staff Dashboard",
                icon = "fas fa-arrow-left",
                onSelect = function()
                    showStaffDashboard(restaurantId, ownershipData)
                end
            },
            {
                title = "💰 Payroll Management",
                description = "Process wages and view payroll reports",
                disabled = true
            },
            {
                title = "📅 Daily Payroll Summary",
                description = string.format("Today's wages: $%s • %d employees paid",
                    SupplyUtils.formatMoney(payrollData.dailyTotal or 0),
                    payrollData.employeesPaid or 0),
                icon = "fas fa-calendar-day",
                disabled = true
            },
            {
                title = "📊 Weekly Payroll Report",
                description = "View 7-day payroll summary and trends",
                icon = "fas fa-chart-line",
                onSelect = function()
                    showPayrollReport(restaurantId, "weekly", payrollData)
                end
            },
            {
                title = "📋 Monthly Payroll Report",
                description = "View 30-day payroll summary and costs",
                icon = "fas fa-file-invoice-dollar",
                onSelect = function()
                    showPayrollReport(restaurantId, "monthly", payrollData)
                end
            },
            {
                title = "💳 Process Manual Payroll",
                description = "Manually process wages for current shift",
                icon = "fas fa-hand-holding-usd",
                onSelect = function()
                    lib.alertDialog({
                        header = "Process Manual Payroll",
                        content = "Process wages for all employees currently on duty?\n\nThis will calculate hours worked and pay wages immediately.",
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Process Payroll",
                            cancel = "Cancel"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            TriggerServerEvent("restaurant:processManualPayroll", restaurantId)
                            exports.ogz_supplychain:successNotify("Payroll Processed", "Manual payroll has been processed")
                        end
                    end)
                end
            },
            {
                title = "⚙️ Payroll Settings",
                description = "Configure automatic payroll and wage settings",
                icon = "fas fa-cog",
                onSelect = function()
                    openPayrollSettings(restaurantId, ownershipData)
                end
            }
        }
        
        lib.registerContext({
            id = "restaurant_payroll_management",
            title = "💰 Payroll Management",
            options = options
        })
        lib.showContext("restaurant_payroll_management")
    end, restaurantId)
end

function showPayrollReport(restaurantId, period, payrollData)
    local reportData = payrollData[period] or {}
    
    local options = {
        {
            title = "← Back to Payroll",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openPayrollManagement(restaurantId, {})
            end
        },
        {
            title = string.format("📊 %s Payroll Report", SupplyUtils.capitalizeFirst(period)),
            description = string.format("Total wages: $%s • Average daily: $%s",
                SupplyUtils.formatMoney(reportData.totalWages or 0),
                SupplyUtils.formatMoney((reportData.totalWages or 0) / (period == "weekly" and 7 or 30))),
            disabled = true
        }
    }
    
    if reportData.employees then
        for _, emp in ipairs(reportData.employees) do
            table.insert(options, {
                title = emp.name,
                description = string.format("Position: %s • Total: $%s • Hours: %.1f",
                    SupplyUtils.capitalizeFirst(emp.position),
                    SupplyUtils.formatMoney(emp.totalWages),
                    emp.totalHours or 0),
                icon = "fas fa-user",
                metadata = {
                    ["Position"] = SupplyUtils.capitalizeFirst(emp.position),
                    ["Total Wages"] = "$" .. SupplyUtils.formatMoney(emp.totalWages),
                    ["Hours Worked"] = string.format("%.1f hours", emp.totalHours or 0),
                    ["Average Hourly"] = "$" .. string.format("%.2f", emp.averageHourly or 0)
                }
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_payroll_report",
        title = string.format("📊 %s Payroll", SupplyUtils.capitalizeFirst(period)),
        options = options
    })
    lib.showContext("restaurant_payroll_report")
end

-- ===============================================
-- STAFF SCHEDULE
-- ===============================================

function openStaffSchedule(restaurantId, ownershipData)
    local options = {
        {
            title = "← Back to Staff Dashboard",
            icon = "fas fa-arrow-left",
            onSelect = function()
                showStaffDashboard(restaurantId, ownershipData)
            end
        },
        {
            title = "📅 Staff Schedule Management",
            description = "Manage employee schedules and shifts",
            disabled = true
        },
        {
            title = "📋 Today's Schedule",
            description = "View who is scheduled to work today",
            icon = "fas fa-calendar-day",
            onSelect = function()
                showDailySchedule(restaurantId, "today")
            end
        },
        {
            title = "📆 Weekly Schedule",
            description = "View and edit the weekly staff schedule",
            icon = "fas fa-calendar-week",
            onSelect = function()
                showWeeklySchedule(restaurantId, ownershipData)
            end
        },
        {
            title = "⏰ Clock In/Out Log",
            description = "View employee clock in/out history",
            icon = "fas fa-clock",
            onSelect = function()
                showClockInOutLog(restaurantId)
            end
        },
        {
            title = "📊 Schedule Analytics",
            description = "View scheduling patterns and efficiency",
            icon = "fas fa-chart-bar",
            onSelect = function()
                showScheduleAnalytics(restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_staff_schedule",
        title = "📅 Staff Schedule",
        options = options
    })
    lib.showContext("restaurant_staff_schedule")
end

-- ===============================================
-- PERFORMANCE REPORTS
-- ===============================================

function openPerformanceReports(restaurantId, ownershipData)
    QBCore.Functions.TriggerCallback('restaurant:getStaffPerformance', function(performanceData)
        local options = {
            {
                title = "← Back to Staff Dashboard",
                icon = "fas fa-arrow-left",
                onSelect = function()
                    showStaffDashboard(restaurantId, ownershipData)
                end
            },
            {
                title = "📊 Staff Performance Reports",
                description = "Analyze employee performance and productivity",
                disabled = true
            },
            {
                title = "🏆 Top Performers",
                description = "View highest performing employees",
                icon = "fas fa-trophy",
                onSelect = function()
                    showTopPerformers(restaurantId, performanceData.topPerformers)
                end
            },
            {
                title = "📈 Performance Trends",
                description = "View performance trends over time",
                icon = "fas fa-chart-line",
                onSelect = function()
                    showPerformanceTrends(restaurantId, performanceData.trends)
                end
            },
            {
                title = "⚠️ Performance Issues",
                description = "Identify employees needing improvement",
                icon = "fas fa-exclamation-triangle",
                onSelect = function()
                    showPerformanceIssues(restaurantId, performanceData.issues)
                end
            },
            {
                title = "📋 Generate Performance Review",
                description = "Create comprehensive performance report",
                icon = "fas fa-file-alt",
                onSelect = function()
                    TriggerServerEvent("restaurant:generatePerformanceReport", restaurantId)
                    exports.ogz_supplychain:successNotify("Report Generated", "Performance report has been created")
                end
            }
        }
        
        lib.registerContext({
            id = "restaurant_performance_reports",
            title = "📊 Performance Reports",
            options = options
        })
        lib.showContext("restaurant_performance_reports")
    end, restaurantId)
end

-- ===============================================
-- CLOCK IN/OUT SYSTEM
-- ===============================================

-- Staff duty toggle interface
RegisterNetEvent("restaurant:openDutyToggle")
AddEventHandler("restaurant:openDutyToggle", function(restaurantId)
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        if not ownershipData.isStaff then
            exports.ogz_supplychain:errorNotify("Not Employed", "You are not employed at this restaurant")
            return
        end
        
        local options = {
            {
                title = "⏰ Clock In",
                description = "Start your work shift",
                icon = "fas fa-play",
                onSelect = function()
                    TriggerServerEvent("restaurant:toggleDuty", restaurantId)
                end
            },
            {
                title = "⏸️ Clock Out", 
                description = "End your work shift",
                icon = "fas fa-pause",
                onSelect = function()
                    TriggerServerEvent("restaurant:toggleDuty", restaurantId)
                end
            },
            {
                title = "📊 My Stats",
                description = "View your work statistics",
                icon = "fas fa-chart-bar",
                onSelect = function()
                    TriggerServerEvent("restaurant:getMyWorkStats", restaurantId)
                end
            }
        }
        
        lib.registerContext({
            id = "restaurant_duty_toggle",
            title = "⏰ Work Schedule",
            options = options
        })
        lib.showContext("restaurant_duty_toggle")
    end, restaurantId)
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function getNearbyPlayers(callback)
    local players = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= 10.0 then -- Within 10 meters
                local targetName = GetPlayerName(playerId)
                table.insert(players, {
                    id = GetPlayerServerId(playerId),
                    name = targetName,
                    distance = distance
                })
            end
        end
    end
    
    callback(players)
end

function getPositionIcon(position)
    local icons = {
        owner = "👑",
        manager = "👔",
        chef = "👨‍🍳",
        cashier = "💰",
        server = "🍽️",
        cleaner = "🧹"
    }
    return icons[position] or "👤"
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
-- EVENT HANDLERS
-- ===============================================

-- Handle successful employee hire
RegisterNetEvent("restaurant:employeeHired")
AddEventHandler("restaurant:employeeHired", function(employeeName, position, wage)
    exports.ogz_supplychain:successNotify("Employee Hired", 
        string.format("%s hired as %s for $%d/hour", employeeName, position, wage))
end)

-- Handle employee termination
RegisterNetEvent("restaurant:employeeFired")
AddEventHandler("restaurant:employeeFired", function(employeeName, reason)
    exports.ogz_supplychain:successNotify("Employee Terminated", 
        string.format("%s has been terminated. Reason: %s", employeeName, reason))
end)

-- Handle duty status changes
RegisterNetEvent("restaurant:dutyStatusChanged")
AddEventHandler("restaurant:dutyStatusChanged", function(onDuty, position, hoursWorked, wageEarned)
    if onDuty then
        exports.ogz_supplychain:successNotify("Clocked In", 
            string.format("You are now on duty as %s", SupplyUtils.capitalizeFirst(position)))
    else
        exports.ogz_supplychain:successNotify("Clocked Out", 
            string.format("Shift complete! Worked %.2f hours, earned $%s", 
            hoursWorked or 0, SupplyUtils.formatMoney(wageEarned or 0)))
    end
end)

-- Handle work statistics
RegisterNetEvent("restaurant:showWorkStats")
AddEventHandler("restaurant:showWorkStats", function(stats)
    local options = {
        {
            title = "📊 My Work Statistics",
            description = "Your performance at this restaurant",
            disabled = true
        },
        {
            title = "⏰ Total Hours Worked",
            description = string.format("%.1f hours", stats.totalHours or 0),
            icon = "fas fa-clock"
        },
        {
            title = "💰 Total Wages Earned",
            description = "$" .. SupplyUtils.formatMoney(stats.totalWages or 0),
            icon = "fas fa-dollar-sign"
        },
        {
            title = "📅 Days Worked",
            description = string.format("%d days", stats.daysWorked or 0),
            icon = "fas fa-calendar"
        },
        {
            title = "⭐ Performance Rating",
            description = string.format("%.1f/5.0", stats.performanceRating or 0),
            icon = "fas fa-star"
        }
    }
    
    lib.registerContext({
        id = "restaurant_work_stats",
        title = "📊 My Work Stats",
        options = options
    })
    lib.showContext("restaurant_work_stats")
end)

-- ===============================================
-- CLEANUP
-- ===============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        isStaffMenuOpen = false
        currentStaffData = {}
        nearbyPlayers = {}
    end
end)