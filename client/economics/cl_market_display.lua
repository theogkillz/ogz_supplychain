-- Market Dynamics Client Display System

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants

-- Market state
local currentMarketData = nil
local marketEventActive = false
local priceUpdateThread = nil

-- Market event notification
RegisterNetEvent("SupplyChain:Client:MarketEvent")
AddEventHandler("SupplyChain:Client:MarketEvent", function(eventData)
    marketEventActive = true
    
    -- Play sound effect
    PlaySoundFrontend(-1, "WAYPOINT_SET", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    
    -- Show notification with animation
    lib.notify({
        id = 'market_event',
        title = "📈 " .. eventData.name,
        description = eventData.description,
        duration = 10000,
        type = eventData.type == "shortage" and "error" or "success",
        icon = "fas fa-chart-line",
        iconAnimation = "beat",
        style = {
            [eventData.type == "shortage" and "backgroundColor" or "backgroundColor"] = 
                eventData.type == "shortage" and "#dc2626" or "#16a34a"
        }
    })
    
    -- Show persistent indicator
    ShowMarketEventIndicator(eventData)
end)

-- Show market event indicator
function ShowMarketEventIndicator(eventData)
    CreateThread(function()
        local endTime = eventData.endTime * 1000 -- Convert to milliseconds
        
        while marketEventActive and GetGameTimer() < endTime do
            local remaining = math.floor((endTime - GetGameTimer()) / 1000)
            local minutes = math.floor(remaining / 60)
            local seconds = remaining % 60
            
            lib.showTextUI(string.format(
                "[Market Event] %s | %s | Ends in: %d:%02d",
                eventData.name,
                eventData.item:upper(),
                minutes,
                seconds
            ), {
                position = "right-center",
                icon = eventData.type == "shortage" and "fas fa-exclamation-triangle" or "fas fa-percentage",
                style = {
                    backgroundColor = eventData.type == "shortage" and '#dc2626' or '#16a34a',
                    color = 'white',
                    borderRadius = '4px'
                }
            })
            
            Wait(1000)
        end
        
        lib.hideTextUI()
        marketEventActive = false
    end)
end

-- Show market report
RegisterNetEvent("SupplyChain:Client:ShowMarketReport")
AddEventHandler("SupplyChain:Client:ShowMarketReport", function(marketData)
    currentMarketData = marketData
    OpenMarketReportMenu()
end)

-- Open market report menu
function OpenMarketReportMenu()
    if not currentMarketData then
        TriggerServerEvent("SupplyChain:Server:GetMarketReport")
        return
    end
    
    local options = {}
    
    -- Add summary
    table.insert(options, {
        title = "Market Overview",
        description = string.format("Last Update: %s", 
            os.date("%H:%M", currentMarketData.lastUpdate or os.time())),
        icon = "fas fa-chart-line",
        disabled = true
    })
    
    -- Add categories
    local categories = {
        { name = "Proteins", items = {"patty", "chicken", "fish", "bacon"} },
        { name = "Produce", items = {"lettuce", "tomato", "onion", "pickle"} },
        { name = "Bakery", items = {"bun"} },
        { name = "Dairy", items = {"cheese"} },
        { name = "Supplies", items = {"oil", "sauce", "salt", "pepper"} }
    }
    
    for _, category in ipairs(categories) do
        table.insert(options, {
            title = category.name,
            description = "View " .. category.name:lower() .. " prices and trends",
            icon = "fas fa-folder",
            onSelect = function()
                ShowCategoryPrices(category)
            end
        })
    end
    
    -- Add market event info if active
    if currentMarketData.events and currentMarketData.events.active then
        table.insert(options, {
            title = "🚨 Active Market Event",
            description = currentMarketData.events.active.description,
            icon = "fas fa-exclamation-triangle",
            iconColor = "orange",
            metadata = {
                {label = "Type", value = currentMarketData.events.active.type:upper()},
                {label = "Item", value = currentMarketData.events.active.item:upper()},
                {label = "Effect", value = string.format("%.0f%%", 
                    (currentMarketData.events.active.multiplier - 1) * 100)}
            }
        })
    end
    
    lib.registerContext({
        id = "market_report_menu",
        title = "📊 Market Report",
        options = options
    })
    
    lib.showContext("market_report_menu")
end

-- Show category prices
function ShowCategoryPrices(category)
    local options = {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    for _, itemName in ipairs(category.items) do
        local priceData = currentMarketData.prices[itemName]
        if priceData then
            local trend = currentMarketData.trends[itemName] or { direction = "stable" }
            local itemLabel = itemNames[itemName] and itemNames[itemName].label or itemName
            
            -- Determine trend icon and color
            local trendIcon = "fas fa-minus"
            local trendColor = "grey"
            if trend.direction == "rising" then
                trendIcon = "fas fa-arrow-up"
                trendColor = "red"
            elseif trend.direction == "falling" then
                trendIcon = "fas fa-arrow-down"
                trendColor = "green"
            end
            
            -- Calculate price change
            local priceChange = ((priceData.current - priceData.base) / priceData.base) * 100
            
            table.insert(options, {
                title = itemLabel,
                description = string.format("$%.2f (Base: $%.2f)", 
                    priceData.current, priceData.base),
                icon = trendIcon,
                iconColor = trendColor,
                metadata = {
                    {label = "Price Change", value = string.format("%+.1f%%", priceChange)},
                    {label = "Supply Level", value = priceData.supply .. "%"},
                    {label = "Demand Level", value = priceData.demand .. "%"},
                    {label = "Trend", value = trend.direction:upper()},
                    {label = "Multiplier", value = string.format("%.2fx", priceData.multiplier)}
                },
                onSelect = function()
                    ShowPriceHistory(itemName, itemLabel)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "category_prices_menu",
        title = category.name .. " Prices",
        menu = "market_report_menu",
        options = options
    })
    
    lib.showContext("category_prices_menu")
end

-- Show price history (simplified visualization)
function ShowPriceHistory(itemName, itemLabel)
    local priceData = currentMarketData.prices[itemName]
    local trend = currentMarketData.trends[itemName] or { direction = "stable", strength = 0 }
    
    -- Create visual representation
    local content = string.format([[
        **%s Price Analysis**
        
        Current Price: **$%.2f**
        Base Price: $%.2f
        24h Average: $%.2f
        
        **Market Factors:**
        Supply Level: %d%%
        Demand Level: %d%%
        Price Multiplier: %.2fx
        
        **Trend Analysis:**
        Direction: %s
        Strength: %.1f%%
        
        **Price Factors:**
        - Supply: %s
        - Demand: %s  
        - Time: %s
        - Players: %s
    ]],
        itemLabel,
        priceData.current,
        priceData.base,
        trend.average or priceData.current,
        priceData.supply,
        priceData.demand,
        priceData.multiplier,
        trend.direction:upper(),
        trend.strength * 100,
        GetFactorDescription("supply", priceData.supply),
        GetFactorDescription("demand", priceData.demand),
        GetTimeFactorDescription(),
        GetPlayerFactorDescription()
    )
    
    -- Add event info if item is affected
    if currentMarketData.events and currentMarketData.events.active and 
       currentMarketData.events.active.item == itemName then
        content = content .. string.format([[
            
            **🚨 ACTIVE EVENT:**
            %s
            Effect: %.0f%% price %s
        ]], 
            currentMarketData.events.active.description,
            math.abs((currentMarketData.events.active.multiplier - 1) * 100),
            currentMarketData.events.active.multiplier > 1 and "increase" or "decrease"
        )
    end
    
    lib.alertDialog({
        header = itemLabel .. " Market Analysis",
        content = content,
        centered = true,
        cancel = true,
        size = 'lg'
    })
end

-- Live price ticker (optional HUD element)
function ShowPriceTicker(items)
    if priceUpdateThread then return end
    
    priceUpdateThread = CreateThread(function()
        local tickerItems = items or {"patty", "bun", "lettuce", "cheese"}
        local index = 1
        
        while true do
            if currentMarketData and currentMarketData.prices then
                local item = tickerItems[index]
                local priceData = currentMarketData.prices[item]
                
                if priceData then
                    local itemNames = exports.ox_inventory:Items() or {}
                    local label = itemNames[item] and itemNames[item].label or item
                    local trend = currentMarketData.trends[item] or { direction = "stable" }
                    
                    -- Show ticker
                    lib.showTextUI(string.format(
                        "%s: $%.2f %s",
                        label,
                        priceData.current,
                        trend.direction == "rising" and "📈" or 
                        trend.direction == "falling" and "📉" or "➖"
                    ), {
                        position = "bottom-right",
                        icon = "fas fa-dollar-sign",
                        style = {
                            backgroundColor = '#1f2937',
                            color = trend.direction == "rising" and '#ef4444' or 
                                   trend.direction == "falling" and '#10b981' or '#ffffff',
                            borderRadius = '4px',
                            padding = '8px 12px'
                        }
                    })
                    
                    Wait(3000)
                    lib.hideTextUI()
                    Wait(500)
                    
                    -- Next item
                    index = index % #tickerItems + 1
                end
            end
            
            Wait(100)
        end
    end)
end

-- Utility functions
function GetFactorDescription(factor, value)
    if factor == "supply" then
        if value < 10 then return "CRITICAL ⚠️"
        elseif value < 25 then return "Very Low"
        elseif value < 50 then return "Low"
        elseif value < 75 then return "Normal"
        elseif value < 90 then return "High"
        else return "Oversupplied" end
    elseif factor == "demand" then
        if value < 25 then return "Very Low"
        elseif value < 50 then return "Low"
        elseif value < 75 then return "Normal"
        elseif value < 90 then return "High"
        else return "Very High 🔥" end
    end
end

function GetTimeFactorDescription()
    local hour = GetClockHours()
    if (hour >= 11 and hour <= 14) or (hour >= 17 and hour <= 21) then
        return "Peak Hours (+20%)"
    elseif hour >= 2 and hour <= 6 then
        return "Off-Peak (-20%)"
    else
        return "Normal Hours"
    end
end

function GetPlayerFactorDescription()
    local playerCount = #GetActivePlayers()
    if playerCount >= Config.Economics.dynamicPricing.peakThreshold then
        return "High Activity (+15%)"
    elseif playerCount <= 5 then
        return "Low Activity (-10%)"
    else
        return "Normal Activity"
    end
end

-- Commands
RegisterCommand('market', function()
    TriggerServerEvent("SupplyChain:Server:GetMarketReport")
end, false)

RegisterCommand('ticker', function()
    if priceUpdateThread then
        -- Stop ticker
        priceUpdateThread = nil
        lib.hideTextUI()
        Framework.Notify(nil, "Price ticker stopped", "info")
    else
        -- Start ticker
        ShowPriceTicker()
        Framework.Notify(nil, "Price ticker started", "success")
    end
end, false)

-- Export market functions
exports('GetCurrentMarketData', function()
    return currentMarketData
end)

exports('IsMarketEventActive', function()
    return marketEventActive
end)

exports('ShowMarketReport', function()
    OpenMarketReportMenu()
end)