-- Centralized State Management for SupplyChain

SupplyChain = SupplyChain or {}

-- Initialize global state structure
SupplyChain.State = {
    -- Active orders tracking
    ActiveOrders = {},
    
    -- Delivery teams
    Teams = {},
    
    -- Warehouse stock cache (30-second intelligent caching)
    WarehouseStock = {
        data = {},
        lastUpdate = 0,
        cacheTime = 30000 -- 30 seconds
    },
    
    -- Restaurant data cache
    RestaurantStock = {},
    
    -- Market dynamics
    MarketPrices = {
        data = {},
        lastUpdate = 0,
        cacheTime = 300000 -- 5 minutes
    },
    
    -- Performance metrics
    Metrics = {
        totalDeliveries = 0,
        activeDeliveries = 0,
        averageDeliveryTime = 0,
        systemUptime = 0
    },
    
    -- Emergency orders
    EmergencyOrders = {},
    
    -- Container tracking
    ActiveContainers = {},
    
    -- Player statistics cache
    PlayerStats = {}
}

-- Cache management functions
SupplyChain.Cache = {}

function SupplyChain.Cache.IsValid(cache)
    if not cache or not cache.lastUpdate then return false end
    return (GetGameTimer and GetGameTimer() or os.time() * 1000) - cache.lastUpdate < (cache.cacheTime or 30000)
end

function SupplyChain.Cache.Update(cache, data)
    cache.data = data
    cache.lastUpdate = GetGameTimer and GetGameTimer() or os.time() * 1000
    return cache
end

function SupplyChain.Cache.Get(cache)
    if SupplyChain.Cache.IsValid(cache) then
        return cache.data
    end
    return nil
end

function SupplyChain.Cache.Clear(cache)
    cache.data = {}
    cache.lastUpdate = 0
end

-- State management functions
SupplyChain.StateManager = {}

-- Orders
function SupplyChain.StateManager.AddOrder(orderGroupId, orderData)
    SupplyChain.State.ActiveOrders[orderGroupId] = {
        data = orderData,
        status = 'pending',
        createdAt = GetGameTimer and GetGameTimer() or os.time() * 1000,
        team = nil
    }
end

function SupplyChain.StateManager.UpdateOrderStatus(orderGroupId, status)
    if SupplyChain.State.ActiveOrders[orderGroupId] then
        SupplyChain.State.ActiveOrders[orderGroupId].status = status
        SupplyChain.State.ActiveOrders[orderGroupId].updatedAt = GetGameTimer and GetGameTimer() or os.time() * 1000
    end
end

function SupplyChain.StateManager.RemoveOrder(orderGroupId)
    SupplyChain.State.ActiveOrders[orderGroupId] = nil
end

-- Teams
function SupplyChain.StateManager.CreateTeam(teamId, leaderId)
    SupplyChain.State.Teams[teamId] = {
        leader = leaderId,
        members = {},
        orderGroupId = nil,
        createdAt = GetGameTimer and GetGameTimer() or os.time() * 1000
    }
end

function SupplyChain.StateManager.AddTeamMember(teamId, playerId)
    if SupplyChain.State.Teams[teamId] then
        table.insert(SupplyChain.State.Teams[teamId].members, playerId)
        return true
    end
    return false
end

function SupplyChain.StateManager.DisbandTeam(teamId)
    SupplyChain.State.Teams[teamId] = nil
end

-- Warehouse Stock
function SupplyChain.StateManager.UpdateWarehouseStock(stockData)
    SupplyChain.Cache.Update(SupplyChain.State.WarehouseStock, stockData)
end

function SupplyChain.StateManager.GetWarehouseStock()
    return SupplyChain.Cache.Get(SupplyChain.State.WarehouseStock)
end

-- Market Prices
function SupplyChain.StateManager.UpdateMarketPrices(priceData)
    SupplyChain.Cache.Update(SupplyChain.State.MarketPrices, priceData)
end

function SupplyChain.StateManager.GetMarketPrices()
    return SupplyChain.Cache.Get(SupplyChain.State.MarketPrices)
end

-- Emergency Orders
function SupplyChain.StateManager.AddEmergencyOrder(orderId, orderData)
    SupplyChain.State.EmergencyOrders[orderId] = {
        data = orderData,
        priority = orderData.priority or 1,
        createdAt = GetGameTimer and GetGameTimer() or os.time() * 1000,
        expiresAt = (GetGameTimer and GetGameTimer() or os.time() * 1000) + (orderData.timeout or 3600000)
    }
end

function SupplyChain.StateManager.GetActiveEmergencyOrders()
    local currentTime = GetGameTimer and GetGameTimer() or os.time() * 1000
    local activeOrders = {}
    
    for orderId, order in pairs(SupplyChain.State.EmergencyOrders) do
        if order.expiresAt > currentTime then
            activeOrders[orderId] = order
        else
            -- Clean up expired orders
            SupplyChain.State.EmergencyOrders[orderId] = nil
        end
    end
    
    return activeOrders
end

-- Container Tracking
function SupplyChain.StateManager.RegisterContainer(containerId, containerData)
    SupplyChain.State.ActiveContainers[containerId] = {
        type = containerData.type,
        quality = 100,
        temperature = containerData.temperature or 20,
        items = containerData.items or {},
        createdAt = GetGameTimer and GetGameTimer() or os.time() * 1000,
        lastUpdate = GetGameTimer and GetGameTimer() or os.time() * 1000
    }
end

function SupplyChain.StateManager.UpdateContainerQuality(containerId, quality)
    if SupplyChain.State.ActiveContainers[containerId] then
        SupplyChain.State.ActiveContainers[containerId].quality = quality
        SupplyChain.State.ActiveContainers[containerId].lastUpdate = GetGameTimer and GetGameTimer() or os.time() * 1000
    end
end

-- Player Statistics
function SupplyChain.StateManager.UpdatePlayerStats(playerId, stats)
    SupplyChain.State.PlayerStats[playerId] = {
        deliveries = stats.deliveries or 0,
        earnings = stats.earnings or 0,
        streak = stats.streak or 0,
        lastDelivery = stats.lastDelivery or 0,
        achievements = stats.achievements or {}
    }
end

-- Metrics
function SupplyChain.StateManager.IncrementDeliveries()
    SupplyChain.State.Metrics.totalDeliveries = SupplyChain.State.Metrics.totalDeliveries + 1
end

function SupplyChain.StateManager.UpdateActiveDeliveries(count)
    SupplyChain.State.Metrics.activeDeliveries = count
end

-- Cleanup function for stale data
function SupplyChain.StateManager.CleanupStaleData()
    local currentTime = GetGameTimer and GetGameTimer() or os.time() * 1000
    local staleTime = 3600000 -- 1 hour
    
    -- Clean up old orders
    for orderGroupId, order in pairs(SupplyChain.State.ActiveOrders) do
        if order.status == 'completed' and currentTime - order.updatedAt > staleTime then
            SupplyChain.State.ActiveOrders[orderGroupId] = nil
        end
    end
    
    -- Clean up disbanded teams
    for teamId, team in pairs(SupplyChain.State.Teams) do
        if #team.members == 0 and currentTime - team.createdAt > 300000 then -- 5 minutes
            SupplyChain.State.Teams[teamId] = nil
        end
    end
end

-- Initialize cleanup thread (server-side only)
if IsDuplicityVersion then
    CreateThread(function()
        while true do
            Wait(300000) -- Run cleanup every 5 minutes
            SupplyChain.StateManager.CleanupStaleData()
        end
    end)
end

-- Export state manager
exports('GetStateManager', function()
    return SupplyChain.StateManager
end)

print("^2[SupplyChain]^7 Global State Management initialized")