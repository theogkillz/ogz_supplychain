-- ============================================
-- VALIDATION FUNCTIONS
-- ============================================

local Validation = {}

-- Job validation (from your cl_main.lua patterns)
Validation.validateJob = function(playerJob, requiredJobs)
    if not playerJob then return false end
    if type(requiredJobs) == "string" then
        return playerJob == requiredJobs
    end
    
    for _, job in ipairs(requiredJobs) do
        if playerJob == job then
            return true
        end
    end
    return false
end

-- Warehouse access validation (from your code patterns)
Validation.hasWarehouseAccess = function(playerJob)
    return Validation.validateJob(playerJob, JOBS.WAREHOUSE)
end

-- Restaurant access validation
Validation.hasRestaurantAccess = function(playerJob, restaurantJob)
    if not restaurantJob then return false end
    return playerJob == restaurantJob or Validation.validateJob(playerJob, JOBS.MANAGEMENT)
end

-- Admin access validation
Validation.hasAdminAccess = function(playerJob)
    return Validation.validateJob(playerJob, JOBS.MANAGEMENT)
end

-- Data validation
Validation.isPositiveNumber = function(value)
    local num = tonumber(value)
    return num and num > 0
end

Validation.isValidQuantity = function(quantity, maxQuantity)
    local qty = tonumber(quantity)
    if not qty or qty <= 0 then return false end
    if maxQuantity and qty > maxQuantity then return false end
    return true
end

Validation.isValidRestaurantId = function(restaurantId)
    if not restaurantId then return false end
    local id = tonumber(restaurantId) or restaurantId
    return Config.Restaurants and Config.Restaurants[id] ~= nil
end

Validation.isValidIngredient = function(ingredient, restaurantJob)
    if not ingredient or not restaurantJob then return false end
    if not Config.Items or not Config.Items[restaurantJob] then return false end
    
    local ingredientKey = ingredient:lower()
    for category, categoryItems in pairs(Config.Items[restaurantJob]) do
        if categoryItems[ingredientKey] then
            return true
        end
    end
    return false
end

-- Order validation
Validation.validateOrderItems = function(orderItems, restaurantJob)
    if not orderItems or #orderItems == 0 then
        return false, "No items in order"
    end
    
    for _, item in ipairs(orderItems) do
        if not item.ingredient or not item.quantity then
            return false, "Invalid item data"
        end
        
        if not Validation.isValidQuantity(item.quantity, 999) then
            return false, "Invalid quantity for " .. (item.label or item.ingredient)
        end
        
        if not Validation.isValidIngredient(item.ingredient, restaurantJob) then
            return false, "Invalid ingredient: " .. item.ingredient
        end
    end
    
    return true, "Valid order"
end

-- Container validation
Validation.isValidContainerType = function(containerType)
    return Config.DynamicContainers and 
           Config.DynamicContainers.containerTypes and 
           Config.DynamicContainers.containerTypes[containerType] ~= nil
end

-- Export for global access
_G.SupplyValidation = Validation
return Validation