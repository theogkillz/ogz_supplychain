-- ============================================
-- SHARED UTILITY FUNCTIONS
-- ============================================

local Utils = {}

-- Money formatting (from your cl_leaderboard.lua)
Utils.formatMoney = function(amount)
    if not amount or amount == 0 then return "0" end
    
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Container calculations (from your cl_warehouse.lua)
Utils.calculateDeliveryBoxes = function(orders)
    local totalItems = 0
    local itemsList = {}
    
    -- Handle both single orders and order groups
    if orders[1] and orders[1].items then
        -- Order group format
        for _, orderGroup in ipairs(orders) do
            for _, item in ipairs(orderGroup.items) do
                totalItems = totalItems + item.quantity
                table.insert(itemsList, item.quantity .. "x " .. item.itemName)
            end
        end
    else
        -- Single order format
        for _, order in ipairs(orders) do
            totalItems = totalItems + order.quantity
            table.insert(itemsList, order.quantity .. "x " .. (order.itemName or order.ingredient))
        end
    end
    
    local itemsPerContainer = CONTAINER_LIMITS.ITEMS_PER_CONTAINER
    local containersPerBox = CONTAINER_LIMITS.CONTAINERS_PER_BOX
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return boxesNeeded, containersNeeded, totalItems, itemsList
end

-- Simple container calculation
Utils.calculateContainers = function(totalItems)
    local itemsPerContainer = CONTAINER_LIMITS.ITEMS_PER_CONTAINER
    local containersPerBox = CONTAINER_LIMITS.CONTAINERS_PER_BOX
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return boxesNeeded, containersNeeded
end

-- Generate unique order ID (from your sv_restaurant.lua)
Utils.generateOrderGroupId = function()
    return "order_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Table utilities
Utils.tableLength = function(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

Utils.tableEmpty = function(t)
    return next(t) == nil
end

-- String utilities
Utils.capitalizeFirst = function(str)
    if not str or str == "" then return str end
    return str:sub(1,1):upper() .. str:sub(2):lower()
end

Utils.sanitizeString = function(str)
    if not str then return "" end
    return str:gsub("[^%w%s]", ""):lower()
end

-- Time utilities
Utils.formatTime = function(seconds)
    if not seconds or seconds < 0 then return "00:00" end
    
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

Utils.getGameTimeMS = function()
    if IsDuplicityVersion() then
        return os.time() * 1000  -- Server
    else
        return GetGameTimer()    -- Client
    end
end

-- Distance calculations
Utils.getDistance = function(pos1, pos2)
    if not pos1 or not pos2 then return 999999 end
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

-- Notification helper (respects config)
Utils.notify = function(src, data)
    local notifyData = {
        title = data.title or "Notification",
        description = data.description or "",
        type = data.type or "info",
        duration = data.duration or 5000,
        position = data.position or (Config.UI and Config.UI.notificationPosition) or 'center-right',
        markdown = data.markdown or (Config.UI and Config.UI.enableMarkdown) or true
    }
    
    if IsDuplicityVersion() then
        -- Server side
        TriggerClientEvent('ox_lib:notify', src, notifyData)
    else
        -- Client side
        exports.ox_lib:notify(notifyData)
    end
end

-- Export for global access
_G.SupplyUtils = Utils
return Utils