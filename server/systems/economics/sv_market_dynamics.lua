-- server/systems/economics/sv_market_dynamics.lua
-- Advanced Market Dynamics Engine

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Market state
local marketData = {
    prices = {},
    history = {},
    trends = {},
    events = {},
    lastUpdate = 0
}

-- Price history tracking
local priceHistory = {}
local HISTORY_LIMIT = 288 -- 24 hours at 5-minute intervals

-- Initialize market system
CreateThread(function()
    -- Load initial market data
    LoadMarketData()
    
    -- Start price update cycle
    if Config and Config.Economics and Config.Economics.dynamicPricing and Config.Economics.dynamicPricing.enabled then
        StartPriceUpdateCycle()
    end
    
    -- Start market event system
    if Config and Config.Economics and Config.Economics.marketEvents then
        StartMarketEventSystem()
    end
    
    -- Start trend analysis
    StartTrendAnalysis()
    
    print("^2[SupplyChain]^7 Market dynamics engine initialized")
end)

-- Load market data from database
function LoadMarketData()
    -- Load current prices
    MySQL.Async.fetchAll('SELECT * FROM supply_market_history ORDER BY recorded_at DESC LIMIT 100', {}, function(results)
        for _, record in ipairs(results) do
            if not marketData.prices[record.item] then
                marketData.prices[record.item] = {
                    current = record.market_price,
                    base = record.base_price,
                    multiplier = record.price_multiplier,
                    supply = record.supply_level,
                    demand = record.demand_level
                }
            end
        end
        
        -- Initialize missing items
        for restaurant, categories in pairs(Config.Items) do
            for category, items in pairs(categories) do
                for itemName, itemConfig in pairs(items) do
                    if not marketData.prices[itemName] then
                        marketData.prices[itemName] = {
                            current = itemConfig.price or 10,
                            base = itemConfig.price or 10,
                            multiplier = 1.0,
                            supply = 100,
                            demand = 50
                        }
                    end
                end
            end
        end
        
        StateManager.UpdateMarketPrices(marketData.prices)
    end)
    
    -- Load price history
    MySQL.Async.fetchAll([[
        SELECT * FROM supply_price_history 
        WHERE recorded_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ORDER BY recorded_at DESC
    ]], {}, function(results)
        for _, record in ipairs(results) do
            if not priceHistory[record.item] then
                priceHistory[record.item] = {}
            end
            table.insert(priceHistory[record.item], {
                price = record.price,
                time = record.recorded_at
            })
        end
    end)
end

-- Price update cycle
function StartPriceUpdateCycle()
    CreateThread(function()
        while true do
            local updateInterval = 300 -- Default 5 minutes
            if Config and Config.Economics and Config.Economics.dynamicPricing and Config.Economics.dynamicPricing.updateInterval then
                updateInterval = Config.Economics.dynamicPricing.updateInterval
            end
            
            Wait(updateInterval * 1000)
            
            UpdateMarketPrices()
        end
    end)
end

-- Update market prices
function UpdateMarketPrices()
    local playerCount = #GetPlayers()
    local hour = os.date("*t").hour
    local dayOfWeek = os.date("*t").wday
    
    -- Get current warehouse stock levels
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(stockData)
        local warehouseStock = {}
        for _, stock in ipairs(stockData) do
            warehouseStock[stock.ingredient] = stock.quantity
        end
        
        -- Get recent order data for demand calculation
        MySQL.Async.fetchAll([[
            SELECT ingredient, SUM(quantity) as total_ordered 
            FROM supply_orders 
            WHERE created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
            GROUP BY ingredient
        ]], {}, function(orderData)
            local recentDemand = {}
            for _, order in ipairs(orderData) do
                recentDemand[order.ingredient] = order.total_ordered
            end
            
            -- Update prices for all items
            for itemName, priceData in pairs(marketData.prices) do
                local oldPrice = priceData.current
                
                -- Calculate new price
                local factors = CalculatePriceFactors(itemName, {
                    currentStock = warehouseStock[itemName] or 0,
                    recentDemand = recentDemand[itemName] or 0,
                    playerCount = playerCount,
                    hour = hour,
                    dayOfWeek = dayOfWeek,
                    currentPrice = priceData.current,
                    basePrice = priceData.base
                })
                
                -- Apply market events
                if marketData.events.active then
                    factors = ApplyMarketEvents(itemName, factors)
                end
                
                -- Calculate final price
                local newPrice = priceData.base * factors.totalMultiplier
                
                -- Apply price limits
                local minMultiplier = 0.5
                local maxMultiplier = 2.0
                if Config and Config.Economics and Config.Economics.dynamicPricing then
                    minMultiplier = Config.Economics.dynamicPricing.minMultiplier or 0.5
                    maxMultiplier = Config.Economics.dynamicPricing.maxMultiplier or 2.0
                end
                
                newPrice = math.max(priceData.base * minMultiplier, newPrice)
                newPrice = math.min(priceData.base * maxMultiplier, newPrice)
                newPrice = math.floor(newPrice * 100) / 100 -- Round to 2 decimals
                
                -- Update market data
                priceData.current = newPrice
                priceData.multiplier = factors.totalMultiplier
                priceData.supply = factors.supplyLevel
                priceData.demand = factors.demandLevel
                
                -- Record significant changes
                if math.abs(newPrice - oldPrice) / oldPrice > 0.05 then -- 5% change
                    LogPriceChange(itemName, oldPrice, newPrice, factors)
                end
                
                -- Update price history
                UpdatePriceHistory(itemName, newPrice)
            end
            
            -- Update state manager
            StateManager.UpdateMarketPrices(marketData.prices)
            
            -- Save to database
            SaveMarketSnapshot()
        end)
    end)
end

-- Calculate price factors
function CalculatePriceFactors(itemName, data)
    local factors = {
        supply = 1.0,
        demand = 1.0,
        time = 1.0,
        players = 1.0,
        trend = 1.0,
        totalMultiplier = 1.0
    }
    
    -- Supply factor
    local maxStock = Config and Config.Stock and Config.Stock.stockLevels and Config.Stock.stockLevels[itemName] or 1000
    local stockPercentage = data.currentStock / maxStock
    
    if stockPercentage < 0.1 then
        factors.supply = 1.5 -- Very low stock, high price
    elseif stockPercentage < 0.25 then
        factors.supply = 1.25
    elseif stockPercentage < 0.5 then
        factors.supply = 1.1
    elseif stockPercentage > 0.9 then
        factors.supply = 0.8 -- Oversupply, lower price
    elseif stockPercentage > 0.75 then
        factors.supply = 0.9
    end
    
    -- Demand factor
    local demandLevel = data.recentDemand / (data.playerCount or 1)
    if demandLevel > 10 then
        factors.demand = 1.3
    elseif demandLevel > 5 then
        factors.demand = 1.15
    elseif demandLevel < 1 then
        factors.demand = 0.85
    end
    
    -- Time-based factors
    if Config and Config.Economics and Config.Economics.dynamicPricing and Config.Economics.dynamicPricing.timeMultipliers then
        -- Peak hours (lunch/dinner)
        if (data.hour >= 11 and data.hour <= 14) or (data.hour >= 17 and data.hour <= 21) then
            factors.time = Config.Economics.dynamicPricing.timeMultipliers.peak or 1.2
        -- Off-peak hours
        elseif data.hour >= 2 and data.hour <= 6 then
            factors.time = Config.Economics.dynamicPricing.timeMultipliers.offPeak or 0.8
        else
            factors.time = Config.Economics.dynamicPricing.timeMultipliers.normal or 1.0
        end
        
        -- Weekend multiplier
        if data.dayOfWeek == 1 or data.dayOfWeek == 7 then
            factors.time = factors.time * (Config.Economics.dynamicPricing.timeMultipliers.weekend or 1.1)
        end
    end
    
    -- Player count factor
    local peakThreshold = 20
    if Config and Config.Economics and Config.Economics.dynamicPricing and Config.Economics.dynamicPricing.peakThreshold then
        peakThreshold = Config.Economics.dynamicPricing.peakThreshold
    end
    
    if data.playerCount >= peakThreshold then
        factors.players = 1.15
    elseif data.playerCount <= 5 then
        factors.players = 0.9
    end
    
    -- Trend factor (analyze price history)
    local trend = AnalyzePriceTrend(itemName)
    if trend.direction == "rising" and trend.strength > 0.1 then
        factors.trend = 1.05 -- Continue upward trend
    elseif trend.direction == "falling" and trend.strength > 0.1 then
        factors.trend = 0.95 -- Continue downward trend
    end
    
    -- Calculate total multiplier
    factors.totalMultiplier = factors.supply * factors.demand * factors.time * factors.players * factors.trend
    
    -- Store levels for display
    factors.supplyLevel = math.floor(stockPercentage * 100)
    factors.demandLevel = math.min(100, math.floor(demandLevel * 10))
    
    return factors
end

-- Market event system
function StartMarketEventSystem()
    CreateThread(function()
        while true do
            Wait(300000) -- Check every 5 minutes
            
            -- Random chance for market event
            local eventChance = 0.05 -- Default 5%
            if Config and Config.Economics and Config.Economics.marketEventChance then
                eventChance = Config.Economics.marketEventChance
            end
            
            if math.random() < eventChance then
                TriggerMarketEvent()
            end
        end
    end)
end

-- Trigger market event
function TriggerMarketEvent()
    local eventTypes = {
        {
            type = "shortage",
            name = "Supply Shortage",
            description = "Supplier issues cause %s shortage",
            items = {"patty", "chicken", "fish"},
            multiplier = 1.5,
            duration = 1800 -- 30 minutes
        },
        {
            type = "surplus",
            name = "Bumper Crop",
            description = "Oversupply of %s drives prices down",
            items = {"lettuce", "tomato", "onion"},
            multiplier = 0.7,
            duration = 1800
        },
        {
            type = "quality",
            name = "Premium Quality",
            description = "High-quality %s commands premium prices",
            items = {"cheese", "bacon", "sauce"},
            multiplier = 1.3,
            duration = 2400 -- 40 minutes
        },
        {
            type = "promotion",
            name = "Bulk Discount",
            description = "Warehouse offers discount on %s",
            items = {"bun", "oil", "potato"},
            multiplier = 0.8,
            duration = 1200 -- 20 minutes
        }
    }
    
    local event = eventTypes[math.random(#eventTypes)]
    local affectedItem = event.items[math.random(#event.items)]
    
    marketData.events.active = {
        type = event.type,
        name = event.name,
        description = string.format(event.description, affectedItem),
        item = affectedItem,
        multiplier = event.multiplier,
        startTime = os.time(),
        endTime = os.time() + event.duration
    }
    
    -- Notify all players
    TriggerClientEvent("SupplyChain:Client:MarketEvent", -1, marketData.events.active)
    
    -- Log event
    MySQL.Async.insert([[
        INSERT INTO supply_system_logs (action, data)
        VALUES (?, ?)
    ]], {
        "market_event",
        json.encode(marketData.events.active)
    })
    
    -- Schedule event end
    SetTimeout(event.duration * 1000, function()
        EndMarketEvent()
    end)
end

-- End market event
function EndMarketEvent()
    if marketData.events.active then
        TriggerClientEvent("SupplyChain:Client:MarketEventEnd", -1)
        marketData.events.active = nil
        
        -- Force price update
        UpdateMarketPrices()
    end
end

-- Apply market events to price
function ApplyMarketEvents(itemName, factors)
    if marketData.events.active and marketData.events.active.item == itemName then
        factors.totalMultiplier = factors.totalMultiplier * marketData.events.active.multiplier
    end
    
    return factors
end

-- Trend analysis
function StartTrendAnalysis()
    CreateThread(function()
        while true do
            Wait(60000) -- Analyze every minute
            
            for itemName, history in pairs(priceHistory) do
                if #history >= 5 then
                    local trend = CalculateTrend(history)
                    marketData.trends[itemName] = trend
                end
            end
        end
    end)
end

-- Calculate price trend
function CalculateTrend(history)
    local recentPrices = {}
    local limit = math.min(#history, 10)
    
    for i = 1, limit do
        table.insert(recentPrices, history[i].price)
    end
    
    -- Simple moving average
    local sum = 0
    for _, price in ipairs(recentPrices) do
        sum = sum + price
    end
    local average = sum / #recentPrices
    
    -- Determine trend direction
    local direction = "stable"
    local strength = 0
    
    if recentPrices[1] > average * 1.02 then
        direction = "rising"
        strength = (recentPrices[1] - average) / average
    elseif recentPrices[1] < average * 0.98 then
        direction = "falling"
        strength = (average - recentPrices[1]) / average
    end
    
    return {
        direction = direction,
        strength = strength,
        average = average,
        current = recentPrices[1]
    }
end

-- Analyze price trend
function AnalyzePriceTrend(itemName)
    if marketData.trends[itemName] then
        return marketData.trends[itemName]
    end
    
    return {
        direction = "stable",
        strength = 0,
        average = marketData.prices[itemName] and marketData.prices[itemName].current or 0,
        current = marketData.prices[itemName] and marketData.prices[itemName].current or 0
    }
end

-- Update price history
function UpdatePriceHistory(itemName, price)
    if not priceHistory[itemName] then
        priceHistory[itemName] = {}
    end
    
    table.insert(priceHistory[itemName], 1, {
        price = price,
        time = os.time()
    })
    
    -- Limit history size
    if #priceHistory[itemName] > HISTORY_LIMIT then
        table.remove(priceHistory[itemName])
    end
    
    -- Save to database
    MySQL.Async.insert('INSERT INTO supply_price_history (item, price) VALUES (?, ?)', {
        itemName, price
    })
end

-- Save market snapshot
function SaveMarketSnapshot()
    local queries = {}
    
    for itemName, priceData in pairs(marketData.prices) do
        table.insert(queries, {
            query = [[
                INSERT INTO supply_market_history 
                (item, base_price, market_price, supply_level, demand_level, price_multiplier)
                VALUES (?, ?, ?, ?, ?, ?)
            ]],
            values = {
                itemName,
                priceData.base,
                priceData.current,
                priceData.supply,
                priceData.demand,
                priceData.multiplier
            }
        })
    end
    
    if #queries > 0 then
        MySQL.Async.transaction(queries)
    end
end

-- Log price changes
function LogPriceChange(itemName, oldPrice, newPrice, factors)
    local changePercent = ((newPrice - oldPrice) / oldPrice) * 100
    
    MySQL.Async.insert([[
        INSERT INTO supply_system_logs (action, data)
        VALUES (?, ?)
    ]], {
        "price_change",
        json.encode({
            item = itemName,
            oldPrice = oldPrice,
            newPrice = newPrice,
            changePercent = changePercent,
            factors = factors
        })
    })
end

-- Server events
RegisterNetEvent(Constants.Events.Server.UpdateMarketPrices)
AddEventHandler(Constants.Events.Server.UpdateMarketPrices, function()
    UpdateMarketPrices()
end)

-- Get market report
RegisterNetEvent("SupplyChain:Server:GetMarketReport")
AddEventHandler("SupplyChain:Server:GetMarketReport", function()
    local src = source
    
    TriggerClientEvent("SupplyChain:Client:ShowMarketReport", src, {
        prices = marketData.prices,
        trends = marketData.trends,
        events = marketData.events,
        lastUpdate = marketData.lastUpdate
    })
end)

-- Export market functions
exports('GetMarketPrices', function()
    return marketData.prices
end)

exports('GetItemPrice', function(itemName)
    return marketData.prices[itemName] and marketData.prices[itemName].current or 0
end)

exports('GetPriceTrend', function(itemName)
    return marketData.trends[itemName] or { direction = "stable", strength = 0 }
end)

exports('TriggerMarketEvent', TriggerMarketEvent)