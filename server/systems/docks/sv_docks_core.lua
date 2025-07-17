-- ============================================
-- DOCKS IMPORT SYSTEM - ENTERPRISE FOUNDATION
-- server/systems/docks/sv_docks_core.lua
-- International trade mechanics with dock worker careers
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Docks system data
local activeShipments = {}
local dockWorkers = {}
local importSchedule = {}
local cargoManifests = {}

-- ============================================
-- INTERNATIONAL IMPORT SYSTEM
-- ============================================

-- Initialize docks import system
local function initializeDocksSystem()
    -- Load active shipments from database
    MySQL.Async.fetchAll('SELECT * FROM supply_import_shipments WHERE status != "completed"', {}, function(results)
        if results then
            for _, shipment in ipairs(results) do
                activeShipments[shipment.shipment_id] = {
                    shipmentId = shipment.shipment_id,
                    origin = shipment.origin,
                    cargoType = shipment.cargo_type,
                    quantity = shipment.quantity,
                    value = shipment.estimated_value,
                    arrivalTime = shipment.arrival_time,
                    status = shipment.status,
                    priority = shipment.priority,
                    requiresInspection = shipment.requires_inspection == 1
                }
            end
        end
    end)
    
    -- Load dock worker registrations
    MySQL.Async.fetchAll('SELECT * FROM supply_dock_workers WHERE active = 1', {}, function(results)
        if results then
            for _, worker in ipairs(results) do
                dockWorkers[worker.citizenid] = {
                    citizenid = worker.citizenid,
                    name = worker.name,
                    experience = worker.experience,
                    specialization = worker.specialization,
                    certifications = worker.certifications and json.decode(worker.certifications) or {},
                    shiftStart = worker.shift_start,
                    active = true
                }
            end
        end
    end)
    
    print("[DOCKS IMPORT] System initialized - " .. table.maxn(activeShipments) .. " active shipments, " .. table.maxn(dockWorkers) .. " workers")
end

-- Generate import schedule
local function generateImportSchedule()
    local schedule = {}
    local baseTime = os.time()
    
    -- Generate 24-48 hours of import schedule
    for i = 1, 12 do -- 12 shipments over 48 hours
        local arrivalTime = baseTime + (i * 4 * 3600) + math.random(-1800, 1800) -- Every 4 hours +/- 30 min
        local origin = Config.DocksImport.origins[math.random(1, #Config.DocksImport.origins)]
        local cargoTypes = Config.DocksImport.cargoTypes[origin.name] or {"general"}
        local cargoType = cargoTypes[math.random(1, #cargoTypes)]
        
        local shipmentId = "SHIP_" .. string.format("%06d", math.random(100000, 999999))
        
        table.insert(schedule, {
            shipmentId = shipmentId,
            origin = origin,
            cargoType = cargoType,
            arrivalTime = arrivalTime,
            quantity = math.random(50, 500),
            estimatedValue = math.random(10000, 100000),
            priority = math.random() > 0.8 and "high" or "normal",
            requiresInspection = math.random() > 0.7
        })
    end
    
    return schedule
end

-- ============================================
-- SHIPMENT ARRIVAL SYSTEM
-- ============================================

-- Process arriving shipment
local function processArrivingShipment(shipmentData)
    local shipmentId = shipmentData.shipmentId
    
    -- Add to active shipments
    activeShipments[shipmentId] = shipmentData
    activeShipments[shipmentId].status = "arrived"
    activeShipments[shipmentId].actualArrival = os.time()
    
    -- Generate cargo manifest
    cargoManifests[shipmentId] = generateCargoManifest(shipmentData)
    
    -- Store in database
    MySQL.Async.execute([[
        INSERT INTO supply_import_shipments (
            shipment_id, origin, cargo_type, quantity, estimated_value,
            arrival_time, actual_arrival, status, priority, requires_inspection
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        shipmentId, shipmentData.origin.name, shipmentData.cargoType,
        shipmentData.quantity, shipmentData.estimatedValue,
        shipmentData.arrivalTime, shipmentData.actualArrival,
        shipmentData.status, shipmentData.priority,
        shipmentData.requiresInspection and 1 or 0
    })
    
    -- Notify dock workers about arrival
    notifyDockWorkers('shipment_arrival', {
        shipmentId = shipmentId,
        origin = shipmentData.origin.name,
        cargoType = shipmentData.cargoType,
        priority = shipmentData.priority,
        requiresInspection = shipmentData.requiresInspection
    })
    
    print(string.format("[DOCKS IMPORT] Shipment %s arrived from %s with %s cargo", 
        shipmentId, shipmentData.origin.name, shipmentData.cargoType))
end

-- Generate cargo manifest
function generateCargoManifest(shipmentData)
    local manifest = {
        shipmentId = shipmentData.shipmentId,
        containers = {},
        totalItems = 0,
        specialItems = {},
        hazardousMaterials = false
    }
    
    -- Generate container list based on cargo type
    local cargoConfig = Config.DocksImport.cargoConfigs[shipmentData.cargoType] or {}
    local containerCount = math.ceil(shipmentData.quantity / (cargoConfig.itemsPerContainer or 20))
    
    for i = 1, containerCount do
        local containerId = shipmentData.shipmentId .. "_C" .. string.format("%03d", i)
        local itemsInContainer = math.min(shipmentData.quantity - manifest.totalItems, cargoConfig.itemsPerContainer or 20)
        
        -- Generate specific items for this container
        local containerItems = generateContainerItems(shipmentData.cargoType, itemsInContainer)
        
        table.insert(manifest.containers, {
            containerId = containerId,
            itemCount = itemsInContainer,
            items = containerItems,
            weight = itemsInContainer * (cargoConfig.avgWeight or 10),
            requiresRefrigeration = cargoConfig.requiresRefrigeration or false,
            customsCode = cargoConfig.customsCode or "GEN001"
        })
        
        manifest.totalItems = manifest.totalItems + itemsInContainer
        
        -- Check for special items
        for _, item in ipairs(containerItems) do
            if item.special then
                table.insert(manifest.specialItems, {
                    containerId = containerId,
                    item = item
                })
            end
            
            if item.hazardous then
                manifest.hazardousMaterials = true
            end
        end
    end
    
    return manifest
end

-- Generate items for container
function generateContainerItems(cargoType, itemCount)
    local items = {}
    local itemPool = Config.DocksImport.itemPools[cargoType] or Config.DocksImport.itemPools.general
    
    for i = 1, itemCount do
        local itemData = itemPool[math.random(1, #itemPool)]
        local quantity = math.random(itemData.minQuantity or 1, itemData.maxQuantity or 5)
        
        table.insert(items, {
            itemName = itemData.name,
            quantity = quantity,
            value = quantity * (itemData.value or 10),
            special = itemData.special or false,
            hazardous = itemData.hazardous or false,
            perishable = itemData.perishable or false
        })
    end
    
    return items
end

-- ============================================
-- DOCK WORKER SYSTEM
-- ============================================

-- Register as dock worker
RegisterNetEvent('docks:registerWorker')
AddEventHandler('docks:registerWorker', function(specialization)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local playerName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    
    -- Check if already registered
    if dockWorkers[citizenid] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚓ Already Registered',
            description = 'You are already registered as a dock worker.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Validate specialization
    local validSpecializations = {"general", "containers", "hazmat", "refrigerated", "heavy_machinery"}
    if not specialization or not table.contains(validSpecializations, specialization) then
        specialization = "general"
    end
    
    -- Register worker
    dockWorkers[citizenid] = {
        citizenid = citizenid,
        name = playerName,
        experience = 0,
        specialization = specialization,
        certifications = {},
        shiftStart = os.time(),
        active = true
    }
    
    -- Store in database
    MySQL.Async.execute([[
        INSERT INTO supply_dock_workers (
            citizenid, name, experience, specialization, shift_start, active
        ) VALUES (?, ?, ?, ?, ?, ?)
    ]], {citizenid, playerName, 0, specialization, os.time(), 1})
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '⚓ DOCK WORKER REGISTERED!',
        description = string.format(
            '**Welcome to the docks!**\n🔧 **Specialization:** %s\n⚡ You can now work on import shipments\n💼 Use `/docks` to view available work',
            specialization:gsub("_", " "):gsub("(%a)", string.upper, 1)
        ),
        type = 'success',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    print(string.format("[DOCKS IMPORT] %s registered as dock worker (specialization: %s)", playerName, specialization))
end)

-- Claim shipment work
RegisterNetEvent('docks:claimShipment')
AddEventHandler('docks:claimShipment', function(shipmentId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Check if registered dock worker
    if not dockWorkers[citizenid] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚓ Access Denied',
            description = 'You must be a registered dock worker to claim shipments.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Check if shipment exists and is available
    local shipment = activeShipments[shipmentId]
    if not shipment or shipment.status ~= "arrived" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚓ Shipment Unavailable',
            description = 'This shipment is not available for processing.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Assign shipment to worker
    shipment.status = "processing"
    shipment.assignedWorker = citizenid
    shipment.claimTime = os.time()
    
    -- Update database
    MySQL.Async.execute([[
        UPDATE supply_import_shipments 
        SET status = 'processing', assigned_worker = ?, claim_time = ?
        WHERE shipment_id = ?
    ]], {citizenid, os.time(), shipmentId})
    
    -- Send shipment details to worker
    TriggerClientEvent('docks:startShipmentProcessing', src, {
        shipment = shipment,
        manifest = cargoManifests[shipmentId],
        workerData = dockWorkers[citizenid]
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '⚓ SHIPMENT CLAIMED!',
        description = string.format(
            '**Shipment:** %s\n🌍 **Origin:** %s\n📦 **Cargo:** %s\n⚡ Begin processing containers',
            shipmentId,
            shipment.origin.name,
            shipment.cargoType
        ),
        type = 'success',
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- ============================================
-- CONTAINER PROCESSING SYSTEM
-- ============================================

-- Process container
RegisterNetEvent('docks:processContainer')
AddEventHandler('docks:processContainer', function(shipmentId, containerId, processingData)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local shipment = activeShipments[shipmentId]
    
    -- Validate worker assignment
    if not shipment or shipment.assignedWorker ~= citizenid then
        return
    end
    
    local manifest = cargoManifests[shipmentId]
    local container = nil
    
    -- Find container in manifest
    for _, cont in ipairs(manifest.containers) do
        if cont.containerId == containerId then
            container = cont
            break
        end
    end
    
    if not container then return end
    
    -- Calculate processing success based on worker skill and container complexity
    local worker = dockWorkers[citizenid]
    local successRate = calculateProcessingSuccess(worker, container, processingData)
    local success = math.random() <= successRate
    
    if success then
        -- Successful processing - add items to warehouse
        for _, item in ipairs(container.items) do
            -- Add items to warehouse stock
            MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock WHERE ingredient = ?', 
                {item.itemName:lower()}, function(stockResults)
                
                if #stockResults > 0 then
                    MySQL.Async.execute('UPDATE supply_warehouse_stock SET quantity = quantity + ? WHERE ingredient = ?', {
                        item.quantity, item.itemName:lower()
                    })
                else
                    MySQL.Async.execute('INSERT INTO supply_warehouse_stock (ingredient, quantity) VALUES (?, ?)', {
                        item.itemName:lower(), item.quantity
                    })
                end
            end)
        end
        
        -- Award experience and payment
        local basePayment = container.itemCount * Config.DocksImport.basePayPerItem
        local bonusPayment = processingData.timeBonus or 0
        local totalPayment = basePayment + bonusPayment
        
        xPlayer.Functions.AddMoney('cash', totalPayment, "Dock work: container processing")
        
        -- Add experience
        worker.experience = worker.experience + (container.itemCount * 2)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚓ Container Processed',
            description = string.format(
                '✅ **%s** processed successfully\n📦 **%d items** added to warehouse\n💰 **Payment:** $%d',
                containerId,
                container.itemCount,
                totalPayment
            ),
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
    else
        -- Processing failed
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚓ Processing Failed',
            description = string.format('❌ **%s** processing failed\n🔧 Check equipment and try again', containerId),
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Update container status
    container.processed = success
    container.processedBy = citizenid
    container.processedAt = os.time()
    
    -- Check if all containers are processed
    local allProcessed = true
    for _, cont in ipairs(manifest.containers) do
        if not cont.processed then
            allProcessed = false
            break
        end
    end
    
    if allProcessed then
        completeShipmentProcessing(shipmentId)
    end
end)

-- Calculate processing success rate
function calculateProcessingSuccess(worker, container, processingData)
    local baseRate = 0.7 -- 70% base success rate
    
    -- Experience bonus
    local experienceBonus = math.min(worker.experience / 1000, 0.2) -- Up to 20% bonus
    
    -- Specialization bonus
    local specializationBonus = 0
    if worker.specialization == "containers" then
        specializationBonus = 0.1
    elseif worker.specialization == "hazmat" and container.hazardousMaterials then
        specializationBonus = 0.15
    elseif worker.specialization == "refrigerated" and container.requiresRefrigeration then
        specializationBonus = 0.15
    end
    
    -- Time penalty for rushing
    local timeBonus = (processingData.processingTime or 30) >= 30 and 0.05 or -0.1
    
    return math.min(baseRate + experienceBonus + specializationBonus + timeBonus, 0.95)
end

-- Complete shipment processing
function completeShipmentProcessing(shipmentId)
    local shipment = activeShipments[shipmentId]
    if not shipment then return end
    
    shipment.status = "completed"
    shipment.completedAt = os.time()
    
    -- Update database
    MySQL.Async.execute('UPDATE supply_import_shipments SET status = "completed", completed_at = ? WHERE shipment_id = ?', 
        {os.time(), shipmentId})
    
    -- Calculate completion bonus
    local worker = dockWorkers[shipment.assignedWorker]
    if worker then
        local completionBonus = math.floor(shipment.estimatedValue * 0.05) -- 5% of shipment value
        local xPlayer = QBCore.Functions.GetPlayerByCitizenId(shipment.assignedWorker)
        
        if xPlayer then
            local Player = QBCore.Functions.GetPlayer(xPlayer)
            if Player then
                Player.Functions.AddMoney('bank', completionBonus, "Shipment completion bonus")
                
                TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                    title = '⚓ SHIPMENT COMPLETED!',
                    description = string.format(
                        '🎉 **%s** fully processed!\n💎 **Completion Bonus:** $%d\n⭐ **Experience gained**',
                        shipmentId,
                        completionBonus
                    ),
                    type = 'success',
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end
        
        -- Add completion experience
        worker.experience = worker.experience + 50
    end
    
    -- Clean up
    activeShipments[shipmentId] = nil
    cargoManifests[shipmentId] = nil
    
    print(string.format("[DOCKS IMPORT] Shipment %s completed by worker %s", shipmentId, shipment.assignedWorker))
end

-- ============================================
-- NOTIFICATION SYSTEM
-- ============================================

-- Notify dock workers
function notifyDockWorkers(notificationType, data)
    for citizenid, worker in pairs(dockWorkers) do
        if worker.active then
            local xPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            if xPlayer then
                local Player = QBCore.Functions.GetPlayer(xPlayer)
                if Player then
                    TriggerClientEvent('docks:workerNotification', Player.PlayerData.source, notificationType, data)
                end
            end
        end
    end
end

-- ============================================
-- EXPORT FUNCTIONS
-- ============================================

exports('getActiveShipments', function() return activeShipments end)
exports('getDockWorker', function(citizenid) return dockWorkers[citizenid] end)
exports('isRegisteredDockWorker', function(citizenid) return dockWorkers[citizenid] ~= nil end)

-- ============================================
-- AUTOMATED SYSTEMS
-- ============================================

-- Shipment arrival scheduler
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Check every 5 minutes
        
        -- Generate new shipments if needed
        if table.maxn(activeShipments) < 3 then
            local schedule = generateImportSchedule()
            for _, shipment in ipairs(schedule) do
                if shipment.arrivalTime <= os.time() + 3600 then -- Arriving within 1 hour
                    processArrivingShipment(shipment)
                    break -- Only process one at a time
                end
            end
        end
    end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(5000) -- Wait for database connection
        initializeDocksSystem()
        print("[DOCKS IMPORT] International import system loaded!")
    end
end)

-- Command to open docks menu
RegisterCommand('docks', function(source, args, rawCommand)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    if dockWorkers[citizenid] then
        TriggerClientEvent('docks:openWorkerMenu', src, {
            workerData = dockWorkers[citizenid],
            activeShipments = activeShipments
        })
    else
        TriggerClientEvent('docks:openRegistrationMenu', src)
    end
end, false)

print("[DOCKS IMPORT] Foundation system loaded successfully!")