-- ===============================================
-- RESTAURANT OWNERSHIP INTEGRATION LAYER
-- Cross-system integration and validation services
-- File: client/systems/restaurants/cl_restaurant_ownership.lua
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()
local job = Framework.GetPlayerJob()
local hasAccess = Framework.HasJob("hurst")
-- ===============================================
-- STATE MANAGEMENT
-- ===============================================

local ownershipCache = {}
local restaurantZones = {}
local isInitialized = false

-- ===============================================
-- INITIALIZATION SYSTEM
-- ===============================================

-- Initialize ownership integration system
Citizen.CreateThread(function()
    Wait(2000) -- Wait for core systems to load
    
    -- Initialize restaurant zones
    initializeRestaurantZones()
    
    -- Initialize ownership validation cache
    initializeOwnershipCache()
    
    -- Set up periodic cache refresh
    setupCacheRefresh()
    
    isInitialized = true
    print("^2[OGZ-SupplyChain]^7 Restaurant Ownership Integration System Initialized")
end)

-- ===============================================
-- RESTAURANT ZONE MANAGEMENT
-- ===============================================

function initializeRestaurantZones()
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        if restaurant.ownership and restaurant.ownership.zone then
            local zone = restaurant.ownership.zone
            
            -- Create restaurant zone for proximity detection
            restaurantZones[restaurantId] = {
                coords = restaurant.position,
                radius = zone.radius or 25.0,
                points = zone.points,
                thickness = zone.thickness or 8.0,
                active = true
            }
            
            -- Create management zones if defined
            if restaurant.ownership.management then
                for _, mgmtPoint in ipairs(restaurant.ownership.management) do
                    exports.ogz_supplychain:createBoxZone({
                        name = "restaurant_management_" .. restaurantId,
                        coords = mgmtPoint.coords,
                        size = vector3(2.0, 2.0, 2.0),
                        heading = 0,
                        options = {
                            {
                                type = "client",
                                event = "restaurant:openOwnershipInterface",
                                icon = "fas fa-building",
                                label = mgmtPoint.label or "Restaurant Management",
                                restaurantId = restaurantId,
                                canInteract = function()
                                    return exports.ogz_supplychain:validatePlayerAccess("restaurant")
                                end
                            }
                        }
                    })
                end
            end
            
            -- Create staff work stations
            if restaurant.ownership.stations then
                setupStaffStations(restaurantId, restaurant.ownership.stations)
            end
        end
    end
end

function setupStaffStations(restaurantId, stations)
    for stationType, stationList in pairs(stations) do
        for i, station in ipairs(stationList) do
            local stationId = string.format("restaurant_%d_%s_%d", restaurantId, stationType, i)
            
            exports.ogz_supplychain:createBoxZone({
                name = stationId,
                coords = station.coords,
                size = vector3(1.5, 1.5, 1.0),
                heading = 0,
                options = {
                    {
                        type = "client",
                        event = "restaurant:useWorkStation",
                        icon = getStationIcon(stationType, station.type),
                        label = station.label or ("Use " .. SupplyUtils.capitalizeFirst(stationType)),
                        restaurantId = restaurantId,
                        stationType = stationType,
                        stationData = station,
                        canInteract = function()
                            return isStaffMember(restaurantId)
                        end
                    }
                }
            })
        end
    end
end

-- ===============================================
-- OWNERSHIP VALIDATION SYSTEM
-- ===============================================

function initializeOwnershipCache()
    ownershipCache = {
        data = {},
        lastUpdate = 0,
        refreshInterval = 60000, -- 1 minute
        isRefreshing = false
    }
end

function setupCacheRefresh()
    Citizen.CreateThread(function()
        while true do
            Wait(ownershipCache.refreshInterval)
            
            if not ownershipCache.isRefreshing then
                refreshOwnershipCache()
            end
        end
    end)
end

function refreshOwnershipCache()
    ownershipCache.isRefreshing = true
    
    -- Clear old cache
    ownershipCache.data = {}
    ownershipCache.lastUpdate = GetGameTimer()
    
    ownershipCache.isRefreshing = false
end

-- Get cached ownership data
function getCachedOwnershipData(restaurantId)
    if not ownershipCache.data[restaurantId] then
        return nil
    end
    
    local cacheAge = GetGameTimer() - ownershipCache.data[restaurantId].timestamp
    if cacheAge > ownershipCache.refreshInterval then
        return nil -- Cache expired
    end
    
    return ownershipCache.data[restaurantId].data
end

-- Cache ownership data
function cacheOwnershipData(restaurantId, data)
    ownershipCache.data[restaurantId] = {
        data = data,
        timestamp = GetGameTimer()
    }
end

-- ===============================================
-- INTEGRATION HELPERS
-- ===============================================

-- Check if player is staff member
function isStaffMember(restaurantId)
    local cached = getCachedOwnershipData(restaurantId)
    if cached then
        return cached.isStaff or cached.isOwner
    end
    
    -- Fallback to server check
    local isStaff = false
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        cacheOwnershipData(restaurantId, ownershipData)
        isStaff = ownershipData.isStaff or ownershipData.isOwner
    end, restaurantId)
    
    return isStaff
end

-- Check if player owns restaurant
function isRestaurantOwner(restaurantId)
    local cached = getCachedOwnershipData(restaurantId)
    if cached then
        return cached.isOwner
    end
    
    -- Fallback to server check
    local isOwner = false
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        cacheOwnershipData(restaurantId, ownershipData)
        isOwner = ownershipData.isOwner
    end, restaurantId)
    
    return isOwner
end

-- Check if player has specific permission
function hasRestaurantPermission(restaurantId, permission)
    local cached = getCachedOwnershipData(restaurantId)
    if cached then
        return cached.isOwner or table.contains(cached.permissions or {}, permission) or table.contains(cached.permissions or {}, "all")
    end
    
    -- Fallback to server check
    local hasPermission = false
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        cacheOwnershipData(restaurantId, ownershipData)
        hasPermission = ownershipData.isOwner or table.contains(ownershipData.permissions or {}, permission) or table.contains(ownershipData.permissions or {}, "all")
    end, restaurantId)
    
    return hasPermission
end

-- Get player's restaurant access level
function getRestaurantAccessLevel(restaurantId)
    local cached = getCachedOwnershipData(restaurantId)
    if cached then
        if cached.isOwner then
            return "owner"
        elseif cached.isStaff then
            return cached.position or "staff"
        else
            return "none"
        end
    end
    
    -- Check traditional job access
    local playerData = QBX.PlayerData
    local PlayerJob = PlayerData.job
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    
    if PlayerJob and PlayerJob.name == restaurantJob then
        return PlayerJob.isboss and "boss" or "employee"
    end
    
    return "none"
end

-- ===============================================
-- PROXIMITY DETECTION
-- ===============================================

-- Check if player is in restaurant zone
function isInRestaurantZone(restaurantId)
    if not restaurantZones[restaurantId] then
        return false
    end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local zone = restaurantZones[restaurantId]
    
    if zone.points then
        -- Polygon zone check
        return isInsidePolygon(playerCoords, zone.points)
    else
        -- Circular zone check
        local distance = #(playerCoords - zone.coords)
        return distance <= zone.radius
    end
end

-- Get nearest restaurant to player
function getNearestRestaurant()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestId = nil
    local nearestDistance = math.huge
    
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        local distance = #(playerCoords - restaurant.position)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestId = restaurantId
        end
    end
    
    return nearestId, nearestDistance
end

-- ===============================================
-- PURCHASE SYSTEM INTEGRATION
-- ===============================================

-- Open restaurant purchase interface
RegisterNetEvent("restaurant:openPurchaseInterface")
AddEventHandler("restaurant:openPurchaseInterface", function(restaurantId)
    if not SupplyValidation.isValidRestaurantId(restaurantId) then
        exports.ogz_supplychain:errorNotify("Invalid Restaurant", "Restaurant not found")
        return
    end
    
    local restaurant = Config.Restaurants[restaurantId]
    local purchasePrice = restaurant.ownership and restaurant.ownership.purchasePrice or 150000
    local pricingTier = restaurant.ownership and restaurant.ownership.pricingTier or "basic"
    
    -- Check if restaurant is already owned
    QBCore.Functions.TriggerCallback('restaurant:checkRestaurantAvailability', function(isAvailable, currentOwner)
        if not isAvailable then
            exports.ogz_supplychain:errorNotify("Restaurant Unavailable", 
                string.format("This restaurant is already owned by %s", currentOwner or "someone else"))
            return
        end
        
        showPurchaseOptions(restaurantId, purchasePrice, pricingTier)
    end, restaurantId)
end)

function showPurchaseOptions(restaurantId, purchasePrice, pricingTier)
    local restaurant = Config.Restaurants[restaurantId]
    local financing = Config.RestaurantOwnership.purchaseSystem.financing
    
    local options = {
        {
            title = "🏪 " .. restaurant.name,
            description = string.format("Purchase Price: $%s • Tier: %s", 
                SupplyUtils.formatMoney(purchasePrice), SupplyUtils.capitalizeFirst(pricingTier)),
            disabled = true
        },
        {
            title = "💰 Cash Purchase",
            description = string.format("Pay full amount ($%s) immediately", SupplyUtils.formatMoney(purchasePrice)),
            icon = "fas fa-money-bill-wave",
            onSelect = function()
                confirmCashPurchase(restaurantId, purchasePrice)
            end
        }
    }
    
    if financing.enabled then
        local minDownPayment = math.floor(purchasePrice * financing.minimumDownPayment)
        
        table.insert(options, {
            title = "🏦 Financing Options",
            description = string.format("Minimum down payment: $%s (%.0f%%)", 
                SupplyUtils.formatMoney(minDownPayment), financing.minimumDownPayment * 100),
            icon = "fas fa-chart-line",
            onSelect = function()
                showFinancingOptions(restaurantId, purchasePrice, financing)
            end
        })
    end
    
    table.insert(options, {
        title = "📋 Restaurant Details",
        description = "View detailed information about this restaurant",
        icon = "fas fa-info-circle",
        onSelect = function()
            showRestaurantDetails(restaurantId, restaurant)
        end
    })
    
    lib.registerContext({
        id = "restaurant_purchase_interface",
        title = "🏪 Purchase Restaurant",
        options = options
    })
    lib.showContext("restaurant_purchase_interface")
end

function confirmCashPurchase(restaurantId, purchasePrice)
    local restaurant = Config.Restaurants[restaurantId]
    
    lib.alertDialog({
        header = "💰 Confirm Cash Purchase",
        content = string.format(
            "Purchase **%s** for **$%s**?\n\nThis will be deducted from your bank account immediately.\n\n**Benefits:**\n• No monthly payments\n• Full ownership immediately\n• Maximum bulk discounts\n• Priority delivery service",
            restaurant.name,
            SupplyUtils.formatMoney(purchasePrice)
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = "Purchase Restaurant",
            cancel = "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            TriggerServerEvent("restaurant:purchaseRestaurant", restaurantId, "cash", purchasePrice)
        end
    end)
end

function showFinancingOptions(restaurantId, purchasePrice, financing)
    local options = {
        {
            title = "← Back to Purchase Options",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openPurchaseInterface", restaurantId)
            end
        },
        {
            title = "🏦 Financing Calculator",
            description = "Calculate monthly payments for different down payments",
            disabled = true
        }
    }
    
    -- Generate financing options
    local downPaymentOptions = {25, 35, 50, 75, 100}
    
    for _, percentage in ipairs(downPaymentOptions) do
        local downPayment = math.floor(purchasePrice * (percentage / 100))
        local financeAmount = purchasePrice - downPayment
        local monthlyPayment = calculateMonthlyPayment(financeAmount, financing.interestRate, financing.maximumTermMonths)
        
        table.insert(options, {
            title = string.format("%d%% Down Payment", percentage),
            description = string.format("Down: $%s • Monthly: $%s for %d months",
                SupplyUtils.formatMoney(downPayment),
                SupplyUtils.formatMoney(monthlyPayment),
                financing.maximumTermMonths),
            icon = "fas fa-percentage",
            onSelect = function()
                if percentage == 100 then
                    confirmCashPurchase(restaurantId, purchasePrice)
                else
                    confirmFinancedPurchase(restaurantId, downPayment, financeAmount, monthlyPayment)
                end
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_financing_options",
        title = "🏦 Financing Options",
        options = options
    })
    lib.showContext("restaurant_financing_options")
end

function confirmFinancedPurchase(restaurantId, downPayment, financeAmount, monthlyPayment)
    local restaurant = Config.Restaurants[restaurantId]
    
    lib.alertDialog({
        header = "🏦 Confirm Financing",
        content = string.format(
            "Finance **%s**?\n\n**Down Payment:** $%s\n**Financed Amount:** $%s\n**Monthly Payment:** $%s\n\n**Note:** Missing 3 consecutive payments will result in repossession.",
            restaurant.name,
            SupplyUtils.formatMoney(downPayment),
            SupplyUtils.formatMoney(financeAmount),
            SupplyUtils.formatMoney(monthlyPayment)
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = "Accept Financing",
            cancel = "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            TriggerServerEvent("restaurant:purchaseRestaurant", restaurantId, "financing", downPayment)
        end
    end)
end

-- ===============================================
-- WORK STATION HANDLERS
-- ===============================================

-- Handle work station usage
RegisterNetEvent("restaurant:useWorkStation")
AddEventHandler("restaurant:useWorkStation", function(data)
    local restaurantId = data.restaurantId
    local stationType = data.stationType
    local stationData = data.stationData
    
    -- Validate staff access
    if not isStaffMember(restaurantId) then
        exports.ogz_supplychain:errorNotify("Access Denied", "You are not employed at this restaurant")
        return
    end
    
    -- Handle different station types
    if stationType == "kitchen" then
        handleKitchenStation(restaurantId, stationData)
    elseif stationType == "service" then
        handleServiceStation(restaurantId, stationData)
    else
        exports.ogz_supplychain:errorNotify("Unknown Station", "Station type not recognized")
    end
end)

function handleKitchenStation(restaurantId, stationData)
    if stationData.type == "cooking" then
        -- Open cooking interface
        TriggerEvent("restaurant:openCookingInterface", restaurantId, stationData)
    elseif stationData.type == "prep" then
        -- Open food prep interface
        TriggerEvent("restaurant:openFoodPrepInterface", restaurantId, stationData)
    end
end

function handleServiceStation(restaurantId, stationData)
    if stationData.type == "register" then
        -- Open POS system
        TriggerEvent("restaurant:openPOSSystem", restaurantId, stationData)
    elseif stationData.type == "pickup" then
        -- Open order pickup interface
        TriggerEvent("restaurant:openOrderPickup", restaurantId, stationData)
    end
end

-- ===============================================
-- OWNERSHIP INTERFACE
-- ===============================================

-- Open ownership management interface
RegisterNetEvent("restaurant:openOwnershipInterface")
AddEventHandler("restaurant:openOwnershipInterface", function(data)
    local restaurantId = data.restaurantId
    
    QBCore.Functions.TriggerCallback('restaurant:getOwnershipData', function(ownershipData)
        cacheOwnershipData(restaurantId, ownershipData)
        
        if ownershipData.isOwner then
            -- Show owner interface
            TriggerEvent("restaurant:openBusinessManagement", restaurantId)
        elseif ownershipData.isStaff then
            -- Show staff interface
            TriggerEvent("restaurant:openDutyToggle", restaurantId)
        else
            -- Check if restaurant is for sale
            QBCore.Functions.TriggerCallback('restaurant:checkRestaurantAvailability', function(isAvailable)
                if isAvailable then
                    TriggerEvent("restaurant:openPurchaseInterface", restaurantId)
                else
                    exports.ogz_supplychain:errorNotify("Access Denied", "You do not have access to this restaurant")
                end
            end, restaurantId)
        end
    end, restaurantId)
end)

-- ===============================================
-- SUPPLY CHAIN INTEGRATION
-- ===============================================

-- Enhanced order integration for owners
AddEventHandler('restaurant:processOwnerOrder', function(restaurantId, orderItems, totalCost)
    -- Apply owner benefits
    local ownershipData = getCachedOwnershipData(restaurantId)
    if ownershipData and ownershipData.isOwner then
        -- Calculate bulk discount
        local discount = calculateBulkDiscount(totalCost)
        local discountAmount = totalCost * discount
        local finalCost = totalCost - discountAmount
        
        -- Process with owner benefits
        TriggerServerEvent("restaurant:orderIngredientsAsOwner", orderItems, restaurantId)
        
        if discount > 0 then
            exports.ogz_supplychain:successNotify("Owner Discount Applied", 
                string.format("%.0f%% discount saved $%s", discount * 100, SupplyUtils.formatMoney(discountAmount)))
        end
    else
        -- Process as regular order
        TriggerServerEvent("restaurant:orderIngredients", orderItems, restaurantId)
    end
end)

-- Quality standard integration
AddEventHandler('warehouse:deliveryQualityCheck', function(restaurantId, containerData)
    local ownershipData = getCachedOwnershipData(restaurantId)
    if ownershipData and ownershipData.isOwner then
        -- Check owner quality standards
        local qualityStandard = getRestaurantQualityStandard(restaurantId)
        
        if containerData.quality < qualityStandard.minimum then
            if qualityStandard.autoReject then
                -- Auto-reject delivery
                TriggerServerEvent("restaurant:rejectDelivery", restaurantId, containerData.deliveryId, "Below quality standard")
                exports.ogz_supplychain:errorNotify("Delivery Rejected", "Quality below your standards - delivery rejected automatically")
            else
                -- Warn about quality
                exports.ogz_supplychain:warningNotify("Quality Warning", 
                    string.format("Delivery quality (%.0f%%) below your standard (%.0f%%)", 
                    containerData.quality * 100, qualityStandard.minimum * 100))
            end
        end
    end
end)

-- ===============================================
-- UTILITY FUNCTIONS
-- ===============================================

function calculateMonthlyPayment(principal, annualRate, months)
    local monthlyRate = annualRate / 12
    if monthlyRate == 0 then
        return principal / months
    end
    
    local payment = principal * (monthlyRate * math.pow(1 + monthlyRate, months)) / (math.pow(1 + monthlyRate, months) - 1)
    return math.floor(payment)
end

function calculateBulkDiscount(orderValue)
    if not Config.RestaurantOwnership or not Config.RestaurantOwnership.ownerBenefits then
        return 0
    end
    
    local discounts = Config.RestaurantOwnership.ownerBenefits.bulkDiscounts
    local highestDiscount = 0
    
    for tier, discount in pairs(discounts) do
        if orderValue >= discount.threshold and discount.discount > highestDiscount then
            highestDiscount = discount.discount
        end
    end
    
    return highestDiscount
end

function getRestaurantQualityStandard(restaurantId)
    -- Default quality standards
    local defaults = {
        minimum = 0.7, -- 70% minimum quality
        autoReject = false
    }
    
    -- This would be retrieved from server in a real implementation
    return defaults
end

function getStationIcon(stationType, specificType)
    local icons = {
        kitchen = {
            cooking = "fas fa-fire",
            prep = "fas fa-cut"
        },
        service = {
            register = "fas fa-cash-register",
            pickup = "fas fa-shopping-bag"
        }
    }
    
    if icons[stationType] and icons[stationType][specificType] then
        return icons[stationType][specificType]
    end
    
    return "fas fa-tools"
end

function isInsidePolygon(point, polygon)
    -- Simple point-in-polygon algorithm
    local x, y = point.x, point.y
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
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
-- EXPORTS FOR OTHER SYSTEMS
-- ===============================================

-- Export ownership validation functions
exports('isRestaurantOwner', isRestaurantOwner)
exports('isStaffMember', isStaffMember)
exports('hasRestaurantPermission', hasRestaurantPermission)
exports('getRestaurantAccessLevel', getRestaurantAccessLevel)
exports('isInRestaurantZone', isInRestaurantZone)
exports('getNearestRestaurant', getNearestRestaurant)

-- ===============================================
-- EVENT HANDLERS
-- ===============================================

-- Handle successful restaurant purchase
RegisterNetEvent("restaurant:purchaseSuccess")
AddEventHandler("restaurant:purchaseSuccess", function(restaurantId, restaurantName, paymentType)
    refreshOwnershipCache() -- Refresh cache after purchase
    
    local message = paymentType == "cash" and "Restaurant purchased with cash!" or "Restaurant financed successfully!"
    exports.ogz_supplychain:successNotify("🏪 Congratulations!", 
        string.format("%s You now own %s!", message, restaurantName))
end)

-- Handle purchase failure
RegisterNetEvent("restaurant:purchaseFailure")
AddEventHandler("restaurant:purchaseFailure", function(reason)
    exports.ogz_supplychain:errorNotify("Purchase Failed", reason)
end)

-- Handle ownership data updates
RegisterNetEvent("restaurant:ownershipDataUpdate")
AddEventHandler("restaurant:ownershipDataUpdate", function(restaurantId, ownershipData)
    cacheOwnershipData(restaurantId, ownershipData)
end)

-- ===============================================
-- CLEANUP
-- ===============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ownershipCache = {}
        restaurantZones = {}
        isInitialized = false
    end
end)

-- ===============================================
-- DEBUG COMMANDS (Remove in production)
-- ===============================================

if Config.Core == 'qbox' and GetConvar('sv_environment', 'prod'):lower() ~= 'prod' then
    RegisterCommand('debugrestaurant', function(source, args)
        if args[1] == 'zones' then
            for id, zone in pairs(restaurantZones) do
                print(string.format("Restaurant %d: Active=%s, Coords=%s", id, zone.active, zone.coords))
            end
        elseif args[1] == 'cache' then
            print("Ownership Cache:")
            for id, data in pairs(ownershipCache.data) do
                print(string.format("Restaurant %d: Owner=%s, Staff=%s", id, data.data.isOwner, data.data.isStaff))
            end
        elseif args[1] == 'nearest' then
            local nearestId, distance = getNearestRestaurant()
            print(string.format("Nearest restaurant: ID=%s, Distance=%.2fm", nearestId or "none", distance))
        end
    end, false)
end