-- ===============================================
-- DOCKS IMPORT SYSTEM - MANAGEMENT INTERFACE
-- Client-side interface for dock operations and import management
-- File: cl_docks_import.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- State management
local currentShiftData = {}
local activeOperations = {}
local containerData = {}
local supplierData = {}
local portSchedule = {}

-- ===============================================
-- DOCK WORKER TARGETS & ZONES
-- ===============================================

-- Create dock operation targets and zones
Citizen.CreateThread(function()
    if not Config.DocksImport or not Config.DocksImport.enabled then return end
    
    local portConfig = Config.DocksImport.portInfrastructure
    
    -- Main Port Authority Office
    if portConfig.operationalZones.adminZones then
        for _, adminZone in pairs(portConfig.operationalZones.adminZones) do
            exports.ox_target:addBoxZone({
                coords = adminZone.coords,
                size = vector3(3.0, 3.0, 2.0),
                rotation = 0,
                debug = Config.debug or false,
                options = {
                    {
                        name = "port_authority_management",
                        icon = "fas fa-anchor",
                        label = "Port Authority Management",
                        onSelect = function()
                            TriggerEvent("docks:openPortManagement")
                        end,
                        canInteract = function()
                            return checkPortManagementAccess()
                        end
                    },
                    {
                        name = "import_order_system",
                        icon = "fas fa-ship",
                        label = "Import Order System",
                        onSelect = function()
                            TriggerEvent("docks:openImportOrderSystem")
                        end,
                        canInteract = function()
                            return checkImportOrderAccess()
                        end
                    }
                }
            })
        end
    end
    
    -- Container Unloading Zones
    if portConfig.operationalZones.unloadingZones then
        for zoneId, unloadingZone in pairs(portConfig.operationalZones.unloadingZones) do
            exports.ox_target:addBoxZone({
                coords = unloadingZone.coords,
                size = vector3(8.0, 8.0, 3.0),
                rotation = 0,
                debug = Config.debug or false,
                options = {
                    {
                        name = "container_unloading_" .. zoneId,
                        icon = "fas fa-boxes",
                        label = "Container Unloading Operations",
                        onSelect = function()
                            TriggerEvent("docks:openUnloadingInterface", zoneId)
                        end,
                        canInteract = function()
                            return checkDockWorkerAccess()
                        end
                    },
                    {
                        name = "container_inspection_" .. zoneId,
                        icon = "fas fa-search",
                        label = "Container Inspection",
                        onSelect = function()
                            TriggerEvent("docks:openInspectionInterface", zoneId)
                        end,
                        canInteract = function()
                            return checkInspectionAccess()
                        end
                    }
                }
            })
        end
    end
    
    -- Customs Zones
    if portConfig.operationalZones.customsZones then
        for _, customsZone in pairs(portConfig.operationalZones.customsZones) do
            exports.ox_target:addBoxZone({
                coords = customsZone.coords,
                size = vector3(5.0, 5.0, 2.5),
                rotation = 0,
                debug = Config.debug or false,
                options = {
                    {
                        name = "customs_processing",
                        icon = "fas fa-clipboard-check",
                        label = "Customs Processing",
                        onSelect = function()
                            TriggerEvent("docks:openCustomsInterface")
                        end,
                        canInteract = function()
                            return checkCustomsAccess()
                        end
                    }
                }
            })
        end
    end
    
    -- Storage Zones
    if portConfig.operationalZones.storageZones then
        for _, storageZone in pairs(portConfig.operationalZones.storageZones) do
            exports.ox_target:addBoxZone({
                coords = storageZone.coords,
                size = vector3(10.0, 10.0, 3.0),
                rotation = 0,
                debug = Config.debug or false,
                options = {
                    {
                        name = "container_storage",
                        icon = "fas fa-warehouse",
                        label = "Container Storage Management",
                        onSelect = function()
                            TriggerEvent("docks:openStorageInterface")
                        end,
                        canInteract = function()
                            return checkStorageAccess()
                        end
                    }
                }
            })
        end
    end
    
    -- Dock Worker Clock In/Out Station
    exports.ox_target:addBoxZone({
        coords = vector3(portConfig.portLocation.coords.x + 5, portConfig.portLocation.coords.y, portConfig.portLocation.coords.z),
        size = vector3(2.0, 2.0, 2.0),
        rotation = 0,
        debug = Config.debug or false,
        options = {
            {
                name = "dock_worker_station",
                icon = "fas fa-clock",
                label = "Dock Worker Station",
                onSelect = function()
                    TriggerEvent("docks:openWorkerStation")
                end,
                canInteract = function()
                    return checkDockWorkerAccess()
                end
            }
        }
    })
end)

-- ===============================================
-- ACCESS CONTROL FUNCTIONS
-- ===============================================

function checkPortManagementAccess()
    local playerData = QBX.PlayerData
    if not PlayerData then return false end
    
    return PlayerData.job.name == "dockworker" and PlayerData.job.isboss or
           PlayerData.job.name == "admin" or PlayerData.job.name == "god"
end

function checkImportOrderAccess()
    local playerData = QBX.PlayerData
    if not PlayerData then return false end
    
    return PlayerData.job.name == "dockworker" or
           Config.JobValidation.validateWarehouseAccess(PlayerData.job.name)
end

function checkDockWorkerAccess()
    local playerData = QBX.PlayerData
    if not PlayerData then return false end
    
    return Config.JobValidation.validateDockWorkerAccess(PlayerData.job.name)
end

function checkInspectionAccess()
    return checkDockWorkerAccess() -- Can be expanded for specialized inspectors
end

function checkCustomsAccess()
    return checkDockWorkerAccess() -- Can be expanded for customs officers
end

function checkStorageAccess()
    return checkDockWorkerAccess()
end

-- ===============================================
-- PORT MANAGEMENT SYSTEM
-- ===============================================

RegisterNetEvent("docks:openPortManagement")
AddEventHandler("docks:openPortManagement", function()
    QBCore.Functions.TriggerCallback('docks:getPortOverviewData', function(data)
        showPortManagementDashboard(data)
    end)
end)

function showPortManagementDashboard(data)
    local options = {
        {
            title = "🚢 Port Overview",
            description = string.format("Active Vessels: %d | Pending Operations: %d | Containers: %d", 
                data.activeVessels or 0, data.pendingOperations or 0, data.totalContainers or 0),
            disabled = true
        },
        
        {
            title = "📋 Vessel Schedule",
            description = "Manage incoming and outgoing vessels",
            icon = "fas fa-calendar-alt",
            onSelect = function()
                TriggerEvent("docks:openVesselSchedule")
            end
        },
        
        {
            title = "📦 Container Operations",
            description = "Monitor container unloading and processing",
            icon = "fas fa-boxes",
            onSelect = function()
                TriggerEvent("docks:openContainerOperations")
            end
        },
        
        {
            title = "👥 Worker Management",
            description = "Manage dock worker assignments and performance",
            icon = "fas fa-hard-hat",
            onSelect = function()
                TriggerEvent("docks:openWorkerManagement")
            end
        },
        
        {
            title = "📊 Performance Analytics",
            description = "View port efficiency and financial reports",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("docks:openPortAnalytics")
            end
        },
        
        {
            title = "⚙️ Port Settings",
            description = "Configure port operations and policies",
            icon = "fas fa-cog",
            onSelect = function()
                TriggerEvent("docks:openPortSettings")
            end
        }
    }
    
    lib.registerContext({
        id = "port_management_dashboard",
        title = "🚢 Los Santos Port Authority",
        options = options
    })
    lib.showContext("port_management_dashboard")
end

-- ===============================================
-- IMPORT ORDER SYSTEM
-- ===============================================

RegisterNetEvent("docks:openImportOrderSystem")
AddEventHandler("docks:openImportOrderSystem", function()
    QBCore.Functions.TriggerCallback('docks:getSupplierData', function(suppliers)
        supplierData = suppliers
        showImportOrderSystem()
    end)
end)

function showImportOrderSystem()
    local options = {
        {
            title = "➕ Create New Import Order",
            description = "Place order with international suppliers",
            icon = "fas fa-plus",
            onSelect = function()
                TriggerEvent("docks:openSupplierSelection")
            end
        },
        
        {
            title = "📋 Active Import Orders",
            description = "View and manage current import orders",
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerEvent("docks:openActiveOrders")
            end
        },
        
        {
            title = "📈 Supplier Relationships",
            description = "Manage supplier partnerships and terms",
            icon = "fas fa-handshake",
            onSelect = function()
                TriggerEvent("docks:openSupplierRelationships")
            end
        },
        
        {
            title = "💰 Import Financials",
            description = "Track import costs and savings",
            icon = "fas fa-dollar-sign",
            onSelect = function()
                TriggerEvent("docks:openImportFinancials")
            end
        },
        
        {
            title = "🌍 Market Intelligence",
            description = "Global market trends and pricing",
            icon = "fas fa-globe",
            onSelect = function()
                TriggerEvent("docks:openMarketIntelligence")
            end
        }
    }
    
    lib.registerContext({
        id = "import_order_system",
        title = "🌍 International Import System",
        options = options
    })
    lib.showContext("import_order_system")
end

-- Supplier Selection Interface
RegisterNetEvent("docks:openSupplierSelection")
AddEventHandler("docks:openSupplierSelection", function()
    local options = {
        {
            title = "← Back to Import System",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("docks:openImportOrderSystem")
            end
        }
    }
    
    -- Group suppliers by continent for better organization
    local continents = {}
    for _, supplier in ipairs(supplierData) do
        if not continents[supplier.continent] then
            continents[supplier.continent] = {}
        end
        table.insert(continents[supplier.continent], supplier)
    end
    
    -- Add continent sections
    for continent, suppliers in pairs(continents) do
        table.insert(options, {
            title = "🌍 " .. continent,
            description = string.format("%d suppliers available", #suppliers),
            disabled = true
        })
        
        for _, supplier in ipairs(suppliers) do
            local reliabilityStars = string.rep("⭐", math.floor(supplier.reliability_rating))
            local specialtiesText = table.concat(supplier.specialties or {}, ", ")
            
            table.insert(options, {
                title = "🏢 " .. supplier.supplier_name,
                description = string.format("%s | %s | %d days shipping", 
                    supplier.country_origin, reliabilityStars, supplier.shipping_time_days),
                metadata = {
                    Country = supplier.country_origin,
                    Rating = reliabilityStars,
                    Specialties = specialtiesText,
                    ["Min Order"] = "$" .. supplier.minimum_order_value
                },
                onSelect = function()
                    TriggerEvent("docks:openSupplierCatalog", supplier.id, supplier.supplier_name)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "supplier_selection",
        title = "🌍 Select International Supplier",
        options = options
    })
    lib.showContext("supplier_selection")
end)

-- ===============================================
-- DOCK WORKER STATION
-- ===============================================

RegisterNetEvent("docks:openWorkerStation")
AddEventHandler("docks:openWorkerStation", function()
    QBCore.Functions.TriggerCallback('docks:getWorkerShiftData', function(shiftData)
        currentShiftData = shiftData
        showWorkerStation()
    end)
end)

function showWorkerStation()
    local onDuty = currentShiftData.on_duty or false
    local hoursWorked = currentShiftData.hours_worked or 0
    local todayEarnings = currentShiftData.today_earnings or 0
    local efficiency = currentShiftData.efficiency_score or 0
    
    local options = {
        {
            title = "📊 Shift Summary",
            description = string.format("Hours: %.2f | Earnings: $%d | Efficiency: %.1f%%", 
                hoursWorked, math.floor(todayEarnings), efficiency),
            disabled = true
        },
        
        {
            title = onDuty and "🔴 Clock Out" or "🟢 Clock In",
            description = onDuty and "End your shift and calculate pay" or "Start your dock worker shift",
            icon = "fas fa-clock",
            onSelect = function()
                TriggerServerEvent("docks:toggleDuty")
            end
        }
    }
    
    if onDuty then
        table.insert(options, {
            title = "⚡ Available Operations",
            description = "View and start dock operations",
            icon = "fas fa-tasks",
            onSelect = function()
                TriggerEvent("docks:openAvailableOperations")
            end
        })
        
        table.insert(options, {
            title = "📋 My Active Operations",
            description = "Monitor ongoing work assignments",
            icon = "fas fa-clipboard-check",
            onSelect = function()
                TriggerEvent("docks:openMyOperations")
            end
        })
    end
    
    table.insert(options, {
        title = "📈 Performance History",
        description = "View work history and achievements",
        icon = "fas fa-chart-line",
        onSelect = function()
            TriggerEvent("docks:openPerformanceHistory")
        end
    })
    
    table.insert(options, {
        title = "🎓 Training & Certifications",
        description = "Available training programs",
        icon = "fas fa-graduation-cap",
        onSelect = function()
            TriggerEvent("docks:openTrainingPrograms")
        end
    })
    
    lib.registerContext({
        id = "dock_worker_station",
        title = "🚢 Dock Worker Station",
        options = options
    })
    lib.showContext("dock_worker_station")
end

-- ===============================================
-- CONTAINER UNLOADING INTERFACE
-- ===============================================

RegisterNetEvent("docks:openUnloadingInterface")
AddEventHandler("docks:openUnloadingInterface", function(zoneId)
    QBCore.Functions.TriggerCallback('docks:getContainersForUnloading', function(containers)
        showUnloadingInterface(zoneId, containers)
    end, zoneId)
end)

function showUnloadingInterface(zoneId, containers)
    local zoneName = Config.DocksImport.portInfrastructure.operationalZones.unloadingZones[zoneId].name
    
    local options = {
        {
            title = "← Back to Port",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("docks:openPortManagement")
            end
        },
        
        {
            title = "📋 Zone Information",
            description = string.format("%s | %d containers pending", zoneName, #containers),
            disabled = true
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "✅ No Containers Pending",
            description = "All containers in this zone have been processed",
            disabled = true
        })
    else
        for _, container in ipairs(containers) do
            local statusIcon = container.customs_status == "cleared" and "✅" or
                              container.customs_status == "pending" and "⏳" or
                              container.customs_status == "hold" and "🚫" or "❓"
            
            local priorityIcon = container.unloading_priority == 1 and "🔴" or
                                container.unloading_priority == 2 and "🟡" or "🟢"
            
            table.insert(options, {
                title = priorityIcon .. " " .. container.container_id,
                description = string.format("%s | %s | %s", 
                    container.container_type, statusIcon .. " " .. container.customs_status, 
                    container.import_order_id),
                metadata = {
                    ["Container Type"] = container.container_type,
                    ["Customs Status"] = container.customs_status,
                    ["Priority"] = container.unloading_priority == 1 and "High" or
                                  container.unloading_priority == 2 and "Medium" or "Low",
                    ["Weight"] = container.weight_gross and (container.weight_gross .. " kg") or "Unknown"
                },
                onSelect = function()
                    TriggerEvent("docks:startContainerUnloading", container.container_id)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "container_unloading_interface",
        title = "📦 " .. zoneName,
        options = options
    })
    lib.showContext("container_unloading_interface")
end

-- ===============================================
-- CONTAINER INSPECTION INTERFACE
-- ===============================================

RegisterNetEvent("docks:openInspectionInterface")
AddEventHandler("docks:openInspectionInterface", function(zoneId)
    QBCore.Functions.TriggerCallback('docks:getContainersForInspection', function(containers)
        showInspectionInterface(zoneId, containers)
    end, zoneId)
end)

function showInspectionInterface(zoneId, containers)
    local options = {
        {
            title = "← Back to Unloading",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("docks:openUnloadingInterface", zoneId)
            end
        },
        
        {
            title = "🔍 Quality Inspection Overview",
            description = string.format("%d containers awaiting inspection", #containers),
            disabled = true
        }
    }
    
    for _, container in ipairs(containers) do
        local inspectionIcon = container.inspection_completed and "✅" or "⏳"
        local qualityIcon = container.quality_grade_verified == "excellent" and "💎" or
                           container.quality_grade_verified == "good" and "✅" or
                           container.quality_grade_verified == "fair" and "⚠️" or
                           container.quality_grade_verified == "poor" and "❌" or "❓"
        
        table.insert(options, {
            title = inspectionIcon .. " " .. container.container_id,
            description = string.format("Quality: %s | Damage: %s", 
                qualityIcon .. (container.quality_grade_verified or "Pending"),
                container.damage_assessment or "Unknown"),
            metadata = {
                ["Container Type"] = container.container_type,
                ["Temperature"] = container.current_temperature and (container.current_temperature .. "°C") or "N/A",
                ["Seal Status"] = container.seal_number and "Intact" or "Missing",
                ["Special Instructions"] = container.handling_instructions or "None"
            },
            onSelect = function()
                TriggerEvent("docks:startContainerInspection", container.container_id)
            end
        })
    end
    
    lib.registerContext({
        id = "container_inspection_interface",
        title = "🔍 Quality Inspection",
        options = options
    })
    lib.showContext("container_inspection_interface")
end)

-- ===============================================
-- CUSTOMS PROCESSING INTERFACE
-- ===============================================

RegisterNetEvent("docks:openCustomsInterface")
AddEventHandler("docks:openCustomsInterface", function()
    QBCore.Functions.TriggerCallback('docks:getCustomsPendingItems', function(pendingItems)
        showCustomsInterface(pendingItems)
    end)
end)

function showCustomsInterface(pendingItems)
    local options = {
        {
            title = "← Back to Port Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("docks:openPortManagement")
            end
        },
        
        {
            title = "📋 Customs Processing Overview",
            description = string.format("%d items pending customs clearance", #pendingItems),
            disabled = true
        }
    }
    
    for _, item in ipairs(pendingItems) do
        local documentStatus = item.documents_complete and "✅" or "📄"
        local inspectionStatus = item.inspection_required and (item.inspection_completed and "✅" or "⏳") or "➖"
        
        table.insert(options, {
            title = documentStatus .. " " .. item.import_order_id,
            description = string.format("Docs: %s | Inspection: %s | Value: $%s", 
                item.documents_complete and "Complete" or "Pending",
                item.inspection_required and (item.inspection_completed and "Done" or "Required") or "N/A",
                item.total_value),
            metadata = {
                ["Supplier"] = item.supplier_name,
                ["Origin"] = item.port_of_origin,
                ["Fees Due"] = "$" .. (item.customs_fees or 0),
                ["Priority"] = item.priority
            },
            onSelect = function()
                TriggerEvent("docks:processCustomsItem", item.import_order_id)
            end
        })
    end
    
    lib.registerContext({
        id = "customs_processing_interface",
        title = "🛃 Customs Processing",
        options = options
    })
    lib.showContext("customs_processing_interface")
end)

-- ===============================================
-- OPERATION PROCESSING EVENTS
-- ===============================================

-- Start Container Unloading
RegisterNetEvent("docks:startContainerUnloading")
AddEventHandler("docks:startContainerUnloading", function(containerId)
    QBCore.Functions.TriggerCallback('docks:canStartUnloading', function(canStart, reason)
        if not canStart then
            lib.notify({
                title = 'Cannot Start Operation',
                description = reason,
                type = 'error'
            })
            return
        end
        
        -- Start the unloading process
        local success = lib.progressCircle({
            duration = 45000, -- 45 seconds for demo (real time would be much longer)
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'amb@world_human_construction@male@base',
                clip = 'base',
                flag = 8
            },
            label = 'Unloading container...'
        })
        
        if success then
            TriggerServerEvent('docks:completeContainerUnloading', containerId)
        end
    end, containerId)
end)

-- Start Container Inspection
RegisterNetEvent("docks:startContainerInspection")
AddEventHandler("docks:startContainerInspection", function(containerId)
    -- Show inspection type selection
    local inspectionOptions = {
        {
            title = "🔍 Basic Visual Inspection",
            description = "Quick visual check (5 min) - $25 per 100 items",
            onSelect = function()
                TriggerEvent("docks:performInspection", containerId, "basic")
            end
        },
        {
            title = "🔍 Standard Quality Check", 
            description = "Thorough inspection (15 min) - $60 per 100 items",
            onSelect = function()
                TriggerEvent("docks:performInspection", containerId, "standard")
            end
        },
        {
            title = "🔍 Comprehensive Inspection",
            description = "Detailed analysis (30 min) - $120 per 100 items", 
            onSelect = function()
                TriggerEvent("docks:performInspection", containerId, "thorough")
            end
        },
        {
            title = "🧪 Laboratory Analysis",
            description = "Scientific testing (2 hours) - $300 per 100 items",
            onSelect = function()
                TriggerEvent("docks:performInspection", containerId, "laboratory")
            end
        }
    }
    
    lib.registerContext({
        id = "inspection_type_selection",
        title = "🔍 Select Inspection Type",
        options = inspectionOptions
    })
    lib.showContext("inspection_type_selection")
end)

-- Perform Inspection
RegisterNetEvent("docks:performInspection")
AddEventHandler("docks:performInspection", function(containerId, inspectionType)
    local inspectionConfig = Config.DocksImport.importOperations.qualityControl.inspectionLevels[inspectionType]
    
    local success = lib.progressCircle({
        duration = inspectionConfig.timeRequired,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = false,
            combat = true
        },
        anim = {
            dict = 'amb@world_human_clipboard@male@idle_a',
            clip = 'idle_c',
            flag = 8
        },
        label = 'Performing ' .. inspectionConfig.name .. '...'
    })
    
    if success then
        TriggerServerEvent('docks:completeContainerInspection', containerId, inspectionType)
    end
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function formatCurrency(amount)
    if not amount or amount == 0 then return "0" end
    return string.format("%s", math.floor(amount))
end

function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

-- ===============================================
-- NOTIFICATION HANDLERS
-- ===============================================

RegisterNetEvent("docks:showShiftStarted")
AddEventHandler("docks:showShiftStarted", function(classification)
    lib.notify({
        title = 'Shift Started',
        description = 'Welcome back! You are now on duty as ' .. classification,
        type = 'success'
    })
end)

RegisterNetEvent("docks:showShiftEnded")
AddEventHandler("docks:showShiftEnded", function(hoursWorked, totalPay, bonuses)
    local bonusText = ""
    if bonuses and #bonuses > 0 then
        bonusText = " (+" .. table.concat(bonuses, ", +") .. ")"
    end
    
    lib.notify({
        title = 'Shift Completed',
        description = string.format('Worked %.2f hours. Earned $%d%s', 
            hoursWorked, math.floor(totalPay), bonusText),
        type = 'success'
    })
end)

RegisterNetEvent("docks:showOperationCompleted")
AddEventHandler("docks:showOperationCompleted", function(operationType, earnings, efficiency)
    lib.notify({
        title = 'Operation Completed',
        description = string.format('%s completed. Earned $%d (%.1f%% efficiency)', 
            operationType, math.floor(earnings), efficiency),
        type = 'success'
    })
end)

-- ===============================================
-- INITIALIZATION
-- ===============================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2[OGZ-SupplyChain]^7 Docks Import Management Interface Loaded!")
        if Config.DocksImport and Config.DocksImport.enabled then
            print("^3[INFO]^7 Port operations interface active at Los Santos Port")
            print("^3[INFO]^7 Dock worker stations and targets created successfully")
        else
            print("^1[WARNING]^7 Docks Import System is disabled in configuration")
        end
    end
end)