-- ============================================
-- CONTAINER UI & INTERACTION SYSTEMS
-- Container menus, dialogs, and user interfaces
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- CONTAINER STATIONS SETUP
-- ============================================

-- Container Station Initialization
Citizen.CreateThread(function()
    if not Config.ContainerStations then
        print("[ERROR] Config.ContainerStations not defined")
        return
    end
    
    for _, station in ipairs(Config.ContainerStations) do
        -- Create station interaction zone using enterprise system
        local stationZone = exports.ogz_supplychain:createBoxZone({
            coords = station.position,
            size = vector3(2.0, 2.0, 1.0),
            name = "container_station_" .. station.name,
            options = {
                {
                    label = "Get Containers",
                    icon = "fas fa-box",
                    onSelect = function()
                        TriggerEvent("containers:openSupplyMenu", station)
                    end
                }
            }
        })
        
        -- Create station blip
        local blip = AddBlipForCoord(station.position.x, station.position.y, station.position.z)
        SetBlipSprite(blip, 478)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.5)
        SetBlipColour(blip, 25)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Container Station")
        EndTextCommandSetBlipName(blip)
    end
end)

-- ============================================
-- CONTAINER SUPPLY MENU SYSTEM
-- ============================================

-- Container Supply Menu
RegisterNetEvent("containers:openSupplyMenu")
AddEventHandler("containers:openSupplyMenu", function(station)
    local options = {}
    
    for _, containerType in ipairs(station.containerTypes) do
        table.insert(options, {
            title = containerType:gsub("_", " "):gsub("^%l", string.upper),
            description = "Take empty containers for packing",
            icon = "fas fa-box",
            onSelect = function()
                TriggerEvent("containers:showContainerTakeDialog", containerType)
            end
        })
    end
    
    lib.registerContext({
        id = "container_supply_menu",
        title = "📦 " .. station.name,
        options = options
    })
    lib.showContext("container_supply_menu")
end)

-- Container take dialog
RegisterNetEvent("containers:showContainerTakeDialog")
AddEventHandler("containers:showContainerTakeDialog", function(containerType)
    local input = exports.ogz_supplychain:showInput("Take Containers", {
        { 
            type = "number", 
            label = "Amount", 
            placeholder = "Enter quantity",
            min = 1, 
            max = 50, 
            required = true 
        }
    })
    
    if input and input[1] and tonumber(input[1]) > 0 then
        local amount = tonumber(input[1])
        TriggerServerEvent("containers:giveEmpty", containerType, amount)
    end
end)

-- ============================================
-- MAIN CONTAINER MENU SYSTEM
-- ============================================

-- Open container management menu
local function openContainerMenu()
    -- Validate access using enterprise system
    local hasAccess, message = exports.ogz_supplychain:validatePlayerAccess("containers")
    if not hasAccess then
        exports.ogz_supplychain:showAccessDenied("containers", message)
        return
    end
    
    local jobAccess = exports.ogz_supplychain:getPlayerJobAccess()
    local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
    
    local options = {
        {
            title = "📦 View My Containers",
            description = "Check containers assigned to your location",
            icon = "fas fa-boxes",
            onSelect = function()
                if jobAccess == "warehouse" then
                    TriggerEvent('containers:viewWarehouseContainers')
                elseif jobAccess == "restaurant" and restaurantId then
                    TriggerServerEvent('containers:getRestaurantContainers', restaurantId)
                else
                    exports.ogz_supplychain:errorNotify(
                        "No Location",
                        "Unable to determine your work location"
                    )
                end
            end
        },
        {
            title = "🔍 Container Quality Check",
            description = "Inspect container quality and condition",
            icon = "fas fa-search",
            onSelect = function()
                TriggerEvent('containers:openQualityCheck')
            end
        },
        {
            title = "📊 Container Statistics",
            description = "View container usage and performance stats",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerEvent('containers:viewStatistics')
            end
        }
    }
    
    -- Add warehouse-specific options
    if jobAccess == "warehouse" then
        table.insert(options, {
            title = "🚛 Load Delivery Vehicle",
            description = "Load containers into delivery vehicle",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerEvent('containers:loadDeliveryVehicle')
            end
        })
        
        table.insert(options, {
            title = "📋 Container Inventory",
            description = "Manage container stock and reorder",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerEvent('containers:manageInventory')
            end
        })
    end
    
    lib.registerContext({
        id = "container_main_menu",
        title = "📦 Container Management",
        options = options
    })
    lib.showContext("container_main_menu")
end

-- ============================================
-- CONTAINER DISPLAY MENUS
-- ============================================

-- Show warehouse containers menu
RegisterNetEvent('containers:showWarehouseContainers')
AddEventHandler('containers:showWarehouseContainers', function(containers)
    local options = {
        {
            title = "← Back to Container Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openContainerMenu()
            end
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "📭 No Containers",
            description = "No containers currently in warehouse",
            disabled = true
        })
    else
        -- Group containers by status for better organization
        local groupedContainers = {}
        for _, container in ipairs(containers) do
            local status = container.status
            if not groupedContainers[status] then
                groupedContainers[status] = {}
            end
            table.insert(groupedContainers[status], container)
        end
        
        -- Display containers by status
        for status, statusContainers in pairs(groupedContainers) do
            local statusIcon = status == "filled" and "✅" or (status == "loaded" and "🚛" or "📦")
            table.insert(options, {
                title = string.format("── %s %s Containers ──", statusIcon, status:gsub("^%l", string.upper)),
                description = #statusContainers .. " containers",
                disabled = true
            })
            
            for _, container in ipairs(statusContainers) do
                local containerOption = exports.ogz_supplychain:buildContainerDisplayOption(container)
                containerOption.onSelect = function()
                    TriggerEvent('containers:inspectContainer', container)
                end
                table.insert(options, containerOption)
            end
        end
    end
    
    lib.registerContext({
        id = "warehouse_containers",
        title = "🏭 Warehouse Containers",
        options = options
    })
    lib.showContext("warehouse_containers")
end)

-- Show restaurant containers menu
RegisterNetEvent('containers:showRestaurantContainers')
AddEventHandler('containers:showRestaurantContainers', function(containers)
    local options = {
        {
            title = "← Back to Container Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                openContainerMenu()
            end
        }
    }
    
    if #containers == 0 then
        table.insert(options, {
            title = "📭 No Deliveries",
            description = "No container deliveries received yet",
            disabled = true
        })
        
        table.insert(options, {
            title = "💡 How to Get Containers",
            description = "Place ingredient orders through the restaurant menu to receive container deliveries",
            disabled = true
        })
    else
        -- Sort containers by delivery time (most recent first)
        table.sort(containers, function(a, b)
            return (a.delivered_timestamp or 0) > (b.delivered_timestamp or 0)
        end)
        
        for _, container in ipairs(containers) do
            local containerOption = exports.ogz_supplychain:buildContainerDisplayOption(container, "restaurant")
            containerOption.onSelect = function()
                TriggerEvent('containers:inspectContainer', container)
            end
            table.insert(options, containerOption)
        end
    end
    
    lib.registerContext({
        id = "restaurant_containers",
        title = "🏪 Restaurant Containers",
        options = options
    })
    lib.showContext("restaurant_containers")
end)

-- ============================================
-- CONTAINER INSPECTION INTERFACE
-- ============================================

-- Inspect individual container
RegisterNetEvent('containers:inspectContainer')
AddEventHandler('containers:inspectContainer', function(container)
    local typeInfo = exports.ogz_supplychain:getContainerTypeInfo(container.container_type)
    local itemLabel = exports.ogz_supplychain:getItemLabel(container.contents_item)
    local currentTime = GetGameTimer()
    
    -- Calculate container details
    local age = exports.ogz_supplychain:formatTime(container.filled_timestamp)
    local expirationText = "Unknown"
    if container.expiration_timestamp then
        local timeToExpiration = container.expiration_timestamp - currentTime
        if timeToExpiration > 0 then
            expirationText = "Expires in " .. exports.ogz_supplychain:formatTime(timeToExpiration)
        else
            expirationText = "⚠️ EXPIRED " .. exports.ogz_supplychain:formatTime(math.abs(timeToExpiration)) .. " ago"
        end
    end
    
    local options = {
        {
            title = "← Back to Containers",
            icon = "fas fa-arrow-left",
            onSelect = function()
                local jobAccess = exports.ogz_supplychain:getPlayerJobAccess()
                if jobAccess == "warehouse" then
                    TriggerEvent('containers:viewWarehouseContainers')
                else
                    local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
                    if restaurantId then
                        TriggerServerEvent('containers:getRestaurantContainers', restaurantId)
                    end
                end
            end
        },
        {
            title = "📋 Container Details",
            description = string.format("ID: %s\nType: %s\nContents: %d x %s", 
                container.container_id, typeInfo.name, container.contents_amount, itemLabel),
            disabled = true
        },
        {
            title = "🔍 Quality Information",
            description = string.format("Current Quality: %s\nAge: %s\n%s", 
                exports.ogz_supplychain:formatQuality(container.quality_level), age, expirationText),
            disabled = true
        }
    }
    
    -- Add action options based on container status and player access
    local actionOptions = exports.ogz_supplychain:buildContainerActionOptions(container)
    for _, option in ipairs(actionOptions) do
        table.insert(options, option)
    end
    
    lib.registerContext({
        id = "container_inspect",
        title = string.format("%s Container %s", typeInfo.icon, container.container_id),
        options = options
    })
    lib.showContext("container_inspect")
end)

-- ============================================
-- CONTAINER ORDER INTERFACE
-- ============================================

-- Enhanced order system with container selection
RegisterNetEvent('containers:showOrderWithContainers')
AddEventHandler('containers:showOrderWithContainers', function(availableItems)
    local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
    if not restaurantId then
        exports.ogz_supplychain:errorNotify(
            "No Restaurant Access",
            "You must be employed at a restaurant to place orders"
        )
        return
    end
    
    -- Create order interface with container information
    local input = exports.ogz_supplychain:showInput('📦 Order with Containers', {
        {
            type = 'select',
            label = 'Select Item',
            description = 'Choose ingredient to order',
            options = availableItems,
            required = true
        },
        {
            type = 'number',
            label = 'Quantity',
            description = 'Number of items to order',
            min = 1,
            max = 100,
            required = true
        }
    })
    
    if input then
        local selectedItem = input[1]
        local quantity = input[2]
        
        local orderItems = {{
            ingredient = selectedItem,
            quantity = quantity
        }}
        
        -- Calculate container requirements
        local containersNeeded = math.ceil(quantity / 12) -- 12 items per container
        local containerCost = containersNeeded * 15 -- $15 per container
        
        exports.ogz_supplychain:confirmWithNotification({
            header = '📦 Confirm Container Order',
            content = string.format(
                '**Order Summary:**\n• Item: %s\n• Quantity: %d\n• Containers Required: %d\n• Container Cost: $%d\n\nProceed with order?',
                exports.ogz_supplychain:getItemLabel(selectedItem),
                quantity,
                containersNeeded,
                containerCost
            ),
            confirmLabel = "Place Order",
            successTitle = "Order Placed",
            successDescription = "Container order sent to warehouse for processing",
            onConfirm = function()
                TriggerServerEvent('restaurant:orderIngredientsWithContainers', orderItems, restaurantId)
            end
        })
    end
end)

-- ============================================
-- CONTAINER ACTION DIALOGS
-- ============================================

-- Unpack container dialog
RegisterNetEvent('containers:showUnpackDialog')
AddEventHandler('containers:showUnpackDialog', function(container)
    exports.ogz_supplychain:confirmWithNotification({
        header = '📤 Unpack Container',
        content = string.format(
            'Unpack **%d x %s** from container?\n\nThis will add the items to your restaurant inventory and mark the container as empty.',
            container.contents_amount,
            exports.ogz_supplychain:getItemLabel(container.contents_item)
        ),
        confirmLabel = "Unpack Items",
        successTitle = "Container Unpacked",
        successDescription = "Items successfully added to restaurant inventory",
        onConfirm = function()
            TriggerServerEvent('containers:unpackContainer', container.container_id)
        end
    })
end)

-- ============================================
-- NOTIFICATION SYSTEM
-- ============================================

-- Container alert notification
RegisterNetEvent('containers:showAlert')
AddEventHandler('containers:showAlert', function(alertType, message, containerId)
    local alertTypes = {
        ["quality_critical"] = {icon = "🚨", type = "error", title = "Critical Quality Alert"},
        ["quality_warning"] = {icon = "⚠️", type = "warning", title = "Quality Warning"},
        ["expiration_near"] = {icon = "⏰", type = "warning", title = "Expiration Warning"},
        ["delivery_complete"] = {icon = "✅", type = "success", title = "Delivery Complete"}
    }
    
    local alert = alertTypes[alertType] or {icon = "📦", type = "info", title = "Container Alert"}
    
    local notificationMessage = message
    if containerId then
        notificationMessage = notificationMessage .. "\nContainer: " .. containerId
    end
    
    if alert.type == "error" then
        exports.ogz_supplychain:errorNotify(alert.title, notificationMessage)
    elseif alert.type == "warning" then
        exports.ogz_supplychain:warningNotify(alert.title, notificationMessage)
    elseif alert.type == "success" then
        exports.ogz_supplychain:successNotify(alert.title, notificationMessage)
    else
        exports.ogz_supplychain:containerNotify(alert.title, notificationMessage)
    end
end)

-- Container operation result notifications
RegisterNetEvent('containers:containerUnpacked')
AddEventHandler('containers:containerUnpacked', function(success, message, items)
    if success then
        exports.ogz_supplychain:successNotify(
            "📤 Container Unpacked",
            message or "Items successfully added to restaurant inventory"
        )
    else
        exports.ogz_supplychain:errorNotify(
            "❌ Unpacking Failed",
            message or "Failed to unpack container"
        )
    end
end)

-- ============================================
-- COMMANDS
-- ============================================

-- Container management command
RegisterCommand('containers', function()
    openContainerMenu()
end)

-- Container status command
RegisterCommand('containerstatus', function()
    local jobAccess = exports.ogz_supplychain:getPlayerJobAccess()
    local restaurantId = exports.ogz_supplychain:getPlayerRestaurantId()
    local monitoringActive = exports.ogz_supplychain:isQualityMonitoringActive()
    
    local statusText = string.format(
        "**Container System Status:**\n• Job Access: %s\n• Restaurant ID: %s\n• Quality Monitoring: %s",
        jobAccess,
        restaurantId or "None",
        monitoringActive and "Active" or "Inactive"
    )
    
    exports.ogz_supplychain:showInfo("📦 Container Status", statusText)
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('openContainerMenu', openContainerMenu)
exports('showContainerTakeDialog', function(containerType)
    TriggerEvent("containers:showContainerTakeDialog", containerType)
end)
exports('showUnpackDialog', function(container)
    TriggerEvent('containers:showUnpackDialog', container)
end)

print("[CONTAINERS] UI system loaded")