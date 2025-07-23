-- Warehouse Zones System (Simplified - No Ped Creation)

local Framework = SupplyChain.Framework
local Constants = SupplyChain.Constants
local Warehouse = exports['ogz_supplychain']:GetWarehouseFunctions()

-- This file only handles zone menu functionality
-- Ped creation is handled by cl_warehouse_peds.lua

-- Open warehouse menu
function OpenWarehouseMenu()
    local options = {
        {
            title = "View Stock",
            description = "Check warehouse stock levels",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerServerEvent(Constants.Events.Server.GetWarehouseStock)
            end
        },
        {
            title = "View Orders",
            description = "View pending orders for delivery",
            icon = "fas fa-box",
            onSelect = function()
                -- Use the new warehouse menu system
                exports['ogz_supplychain']:OpenWarehouseMenu()
            end
        },
        {
            title = "Emergency Orders",
            description = "View critical supply needs",
            icon = "fas fa-exclamation-triangle",
            iconColor = "red",
            onSelect = function()
                exports['ogz_supplychain']:OpenEmergencyOrdersMenu()
            end
        },
        {
            title = "Market Report",
            description = "View current market prices and trends",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("SupplyChain:Server:GetMarketReport")
            end
        },
        {
            title = "Container Rental",
            description = "Rent specialized containers",
            icon = "fas fa-cube",
            onSelect = function()
                TriggerEvent(Constants.Events.Client.ShowContainerMenu)
            end
        },
        {
            title = "Leaderboard",
            description = "View top delivery drivers",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerServerEvent(Constants.Events.Server.GetLeaderboard)
            end
        }
    }
    
    -- Add team options if in delivery
    if exports['ogz_supplychain']:IsInDelivery() then
        table.insert(options, {
            title = "Team Management",
            description = "Manage your delivery team",
            icon = "fas fa-users",
            onSelect = function()
                OpenTeamMenu()
            end
        })
    end
    
    lib.registerContext({
        id = "warehouse_main_menu",
        title = "Warehouse Operations",
        options = options
    })
    
    lib.showContext("warehouse_main_menu")
end

-- Create orders menu
RegisterNetEvent("SupplyChain:Client:CreateOrdersMenu")
AddEventHandler("SupplyChain:Client:CreateOrdersMenu", function(orders)
    local options = {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    for _, order in ipairs(orders) do
        -- Build item descriptions
        local itemDescriptions = {}
        local totalBoxes = 0
        
        for _, item in ipairs(order.items) do
            local itemLabel = itemNames[item.itemName] and itemNames[item.itemName].label or item.itemName
            table.insert(itemDescriptions, string.format("%s (x%d)", itemLabel, item.quantity))
            totalBoxes = totalBoxes + 1
        end
        
        -- Calculate potential reward
        local baseReward = Config.Rewards.delivery.base.minimumPay + (totalBoxes * Config.Rewards.delivery.base.perBoxAmount)
        
        table.insert(options, {
            title = string.format("Order for %s", order.restaurantName),
            description = string.format("Items: %s", table.concat(itemDescriptions, ", ")),
            icon = "fas fa-truck",
            metadata = {
                {label = "Total Value", value = "$" .. order.totalCost},
                {label = "Base Reward", value = "$" .. baseReward},
                {label = "Boxes", value = totalBoxes}
            },
            onSelect = function()
                OpenOrderActionMenu(order)
            end
        })
    end
    
    if #options == 0 then
        Framework.Notify(nil, "No pending orders available", "info")
        return
    end
    
    lib.registerContext({
        id = "warehouse_orders_menu",
        title = "Pending Orders",
        menu = "warehouse_main_menu",
        options = options
    })
    
    lib.showContext("warehouse_orders_menu")
end)

-- Order action menu
function OpenOrderActionMenu(order)
    local options = {
        {
            title = "Form Team",
            description = "Invite players to join this delivery",
            icon = "fas fa-users",
            onSelect = function()
                TriggerServerEvent(Constants.Events.Server.CreateTeam, order.orderGroupId)
                OpenTeamInviteMenu(order)
            end
        },
        {
            title = "Accept Solo",
            description = "Accept the order for solo delivery",
            icon = "fas fa-truck",
            onSelect = function()
                Warehouse.AcceptOrder(order.orderGroupId, order.restaurantId)
            end
        },
        {
            title = "View Details",
            description = "View detailed order information",
            icon = "fas fa-info-circle",
            onSelect = function()
                ShowOrderDetails(order)
            end
        }
    }
    
    lib.registerContext({
        id = "order_action_menu",
        title = "Order Actions",
        menu = "warehouse_orders_menu",
        options = options
    })
    
    lib.showContext("order_action_menu")
end

-- Team invite menu
function OpenTeamInviteMenu(order)
    local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), Config.Teams.proximityDistance, true)
    local options = {}
    
    for _, player in ipairs(nearbyPlayers) do
        table.insert(options, {
            title = string.format("Player %d", player.id),
            description = string.format("Distance: %.1fm", player.distance),
            icon = "fas fa-user",
            onSelect = function()
                TriggerServerEvent(Constants.Events.Server.InviteToTeam, player.id, order.orderGroupId)
                Framework.Notify(nil, "Invite sent!", "success")
            end
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = "No Players Nearby",
            description = "No players within range to invite",
            icon = "fas fa-exclamation",
            disabled = true
        })
    end
    
    -- Add start delivery option
    table.insert(options, {
        title = "Start Delivery",
        description = "Begin the delivery with current team",
        icon = "fas fa-truck",
        onSelect = function()
            Warehouse.AcceptOrder(order.orderGroupId, order.restaurantId)
        end
    })
    
    lib.registerContext({
        id = "team_invite_menu",
        title = "Invite to Delivery Team",
        menu = "order_action_menu",
        options = options
    })
    
    lib.showContext("team_invite_menu")
end

-- Show order details
function ShowOrderDetails(order)
    local itemNames = exports.ox_inventory:Items() or {}
    local content = string.format([[
        **Restaurant:** %s  
        **Order Value:** $%d  
        **Created:** %s ago
        
        **Items:**
    ]], order.restaurantName, order.totalCost, GetTimeAgo(order.createdAt))
    
    for _, item in ipairs(order.items) do
        local itemLabel = itemNames[item.itemName] and itemNames[item.itemName].label or item.itemName
        content = content .. string.format("\n- %s x%d ($%d)", itemLabel, item.quantity, item.totalCost)
    end
    
    -- Add reward calculations
    local baseReward = Config.Rewards.delivery.base.minimumPay + (#order.items * Config.Rewards.delivery.base.perBoxAmount)
    content = content .. string.format([[
        
        **Reward Calculations:**
        Base Pay: $%d
        Speed Bonus: Up to %.0f%%
        Team Bonus: Up to %.0f%%
        Max Potential: $%d
    ]], 
        baseReward,
        (Config.Rewards.delivery.speedBonuses.thresholds[1].multiplier - 1) * 100,
        (Config.Rewards.delivery.teamBonuses.bonuses[#Config.Rewards.delivery.teamBonuses.bonuses].multiplier - 1) * 100,
        math.floor(baseReward * Config.Rewards.delivery.speedBonuses.thresholds[1].multiplier * Config.Rewards.delivery.teamBonuses.bonuses[#Config.Rewards.delivery.teamBonuses.bonuses].multiplier)
    )
    
    lib.alertDialog({
        header = "Order Details",
        content = content,
        centered = true,
        cancel = true,
        size = 'lg'
    })
end

-- Team management menu
function OpenTeamMenu()
    local team = exports['ogz_supplychain']:GetCurrentTeam()
    if not team then
        Framework.Notify(nil, "You are not in a team", "error")
        return
    end
    
    local options = {}
    
    -- Show team leader
    table.insert(options, {
        title = team.leader.name .. " (Leader)",
        icon = "fas fa-crown",
        disabled = true
    })
    
    -- Show team members
    for _, member in ipairs(team.members) do
        table.insert(options, {
            title = member.name,
            icon = "fas fa-user",
            disabled = true
        })
    end
    
    -- Add leave option
    table.insert(options, {
        title = "Leave Team",
        description = "Leave the current delivery team",
        icon = "fas fa-sign-out-alt",
        onSelect = function()
            TriggerServerEvent(Constants.Events.Server.LeaveTeam, team.orderGroupId)
        end
    })
    
    lib.registerContext({
        id = "team_management_menu",
        title = "Delivery Team",
        options = options
    })
    
    lib.showContext("team_management_menu")
end

-- Show warehouse stock
RegisterNetEvent("SupplyChain:Client:ShowWarehouseStock")
AddEventHandler("SupplyChain:Client:ShowWarehouseStock", function(stock)
    local options = {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    -- Add search option
    table.insert(options, {
        title = "Search Stock",
        description = "Search for specific items",
        icon = "fas fa-search",
        onSelect = function()
            local input = lib.inputDialog("Search Stock", {
                { type = "input", label = "Item name" }
            })
            
            if input and input[1] then
                ShowFilteredStock(stock, input[1])
            end
        end
    })
    
    -- Sort items alphabetically
    local sortedItems = {}
    for item, quantity in pairs(stock) do
        table.insert(sortedItems, {item = item, quantity = quantity})
    end
    table.sort(sortedItems, function(a, b) return a.item < b.item end)
    
    -- Add items to menu
    for _, data in ipairs(sortedItems) do
        local itemLabel = itemNames[data.item] and itemNames[data.item].label or data.item
        local stockLevel = "normal"
        
        if data.quantity <= Config.Stock.criticalStockThreshold then
            stockLevel = "critical"
        elseif data.quantity <= Config.Stock.lowStockThreshold then
            stockLevel = "low"
        end
        
        table.insert(options, {
            title = itemLabel,
            description = string.format("Quantity: %d", data.quantity),
            icon = itemNames[data.item] and ("nui://ox_inventory/web/images/" .. data.item .. ".png") or "fas fa-box",
            metadata = {
                {label = "Stock Level", value = stockLevel:upper()},
                {label = "Units", value = data.quantity}
            }
        })
    end
    
    lib.registerContext({
        id = "warehouse_stock_menu",
        title = "Warehouse Stock",
        menu = "warehouse_main_menu",
        options = options
    })
    
    lib.showContext("warehouse_stock_menu")
end)

-- Show filtered stock
function ShowFilteredStock(stock, query)
    local options = {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    for item, quantity in pairs(stock) do
        if string.find(string.lower(item), string.lower(query)) or 
           (itemNames[item] and string.find(string.lower(itemNames[item].label), string.lower(query))) then
            
            local itemLabel = itemNames[item] and itemNames[item].label or item
            table.insert(options, {
                title = itemLabel,
                description = string.format("Quantity: %d", quantity),
                icon = itemNames[item] and ("nui://ox_inventory/web/images/" .. item .. ".png") or "fas fa-box",
                metadata = {
                    {label = "Units", value = quantity}
                }
            })
        end
    end
    
    if #options == 0 then
        Framework.Notify(nil, "No items found matching your search", "error")
        return
    end
    
    lib.registerContext({
        id = "warehouse_stock_filtered",
        title = "Stock Search Results",
        menu = "warehouse_stock_menu",
        options = options
    })
    
    lib.showContext("warehouse_stock_filtered")
end

-- Team invite handler
RegisterNetEvent(Constants.Events.Client.TeamInvite)
AddEventHandler(Constants.Events.Client.TeamInvite, function(data)
    lib.registerContext({
        id = 'team_invite_notification',
        title = 'Delivery Team Invite',
        options = {
            {
                title = string.format('%s invited you to join their delivery team', data.inviterName),
                disabled = true
            },
            {
                title = 'Accept',
                icon = 'fas fa-check',
                onSelect = function()
                    TriggerServerEvent(Constants.Events.Server.JoinTeam, data.orderGroupId)
                end
            },
            {
                title = 'Decline',
                icon = 'fas fa-times',
                onSelect = function()
                    Framework.Notify(nil, "You declined the team invite", "error")
                end
            }
        }
    })
    
    lib.showContext('team_invite_notification')
end)

-- Utility function for time ago
function GetTimeAgo(timestamp)
    if type(timestamp) == "string" then
        -- Parse SQL timestamp
        return "recently"
    end
    
    local now = os.time()
    local diff = now - (timestamp or now)
    
    if diff < 60 then
        return diff .. " seconds"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. " minutes"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. " hours"
    else
        return math.floor(diff / 86400) .. " days"
    end
end

print("^2[SupplyChain]^7 Warehouse zone functions loaded")