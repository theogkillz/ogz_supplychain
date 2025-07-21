Config = Config or {}

Config.Core = 'qbox' -- qbcore or qbox
Config.Inventory = 'ox' -- ox_inventory
Config.Target = 'ox' -- ox_target
Config.Progress = 'ox' -- ox_lib
Config.Notify = 'ox' -- ox_lib
Config.Menu = 'ox' -- ox_lib

Config.UI = {
    useLationUI = true, -- Enable lation_ui styling
    theme = "dark", -- lation_ui theme (dark, light)
    notificationPosition = "center-right",
    enableMarkdown = true
}

Config.DynamicPricing = {
    enabled = true,
    minMultiplier = 0.5, -- Minimum price multiplier
    maxMultiplier = 1.5, -- Maximum price multiplier
    peakThreshold = 20, -- Player count for peak pricing
    lowThreshold = 5 -- Player count for discount
}

Config.Teams = {
    enabled = true,
    maxMembers = 2 -- Maximum players per delivery team
}

Config.Leaderboard = {
    enabled = true,
    maxEntries = 10 -- Number of leaderboard entries to show
}

Config.LowStock = {
    enabled = true,
    threshold = 25 -- Notify when stock is below this
}

Config.maxBoxes = 6 -- Max boxes for team deliveries (2 players)
Config.DriverPayPrec = 0.22 -- Driver payment percentage
Config.CarryBoxProp = 'ng_proc_box_01a' -- Box prop for carrying
Config.SellProgress = 8000 -- Selling duration (ms)
Config.SellingAnimDict = 'missheistdockssetup1ig_12@idle_b'
Config.SellingAnimName = 'talk_gantry_idle_b_worker1'