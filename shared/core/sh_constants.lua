-- Shared Constants for SupplyChain System

SupplyChain = SupplyChain or {}
SupplyChain.Constants = {}

-- System Version
SupplyChain.Constants.VERSION = "2.0.0"
SupplyChain.Constants.MIN_GAME_BUILD = 2802

-- Event Names
SupplyChain.Constants.Events = {
    -- Client Events
    Client = {
        -- Restaurant
        OpenOrderMenu = "SupplyChain:Client:OpenOrderMenu",
        CreateOrderMenu = "SupplyChain:Client:CreateOrderMenu",
        ShowRestaurantStock = "SupplyChain:Client:ShowRestaurantStock",
        OrderComplete = "SupplyChain:Client:OrderComplete",
        PrepareFood = "SupplyChain:Client:PrepareFood",
        StartCooking = "SupplyChain:Client:StartCooking",
        
        -- Warehouse
        OpenWarehouseMenu = "SupplyChain:Client:OpenWarehouseMenu",
        ShowPendingOrders = "SupplyChain:Client:ShowPendingOrders",
        StartDelivery = "SupplyChain:Client:StartDelivery",
        LoadBoxes = "SupplyChain:Client:LoadBoxes",
        DeliverBoxes = "SupplyChain:Client:DeliverBoxes",
        ReturnVehicle = "SupplyChain:Client:ReturnVehicle",
        
        -- Team
        TeamInvite = "SupplyChain:Client:TeamInvite",
        TeamUpdate = "SupplyChain:Client:TeamUpdate",
        TeamDisband = "SupplyChain:Client:TeamDisband",
        
        -- Containers
        ShowContainerMenu = "SupplyChain:Client:ShowContainerMenu",
        UpdateContainerQuality = "SupplyChain:Client:UpdateContainerQuality",
        ContainerAlert = "SupplyChain:Client:ContainerAlert",
        
        -- Notifications
        Notify = "SupplyChain:Client:Notify",
        ShowProgress = "SupplyChain:Client:ShowProgress",
        HideProgress = "SupplyChain:Client:HideProgress",
        
        -- Analytics
        ShowLeaderboard = "SupplyChain:Client:ShowLeaderboard",
        ShowStatistics = "SupplyChain:Client:ShowStatistics",
        ShowAchievements = "SupplyChain:Client:ShowAchievements",

        -- Multi-Order System
        OpenRestaurantMenu = "SupplyChain:Client:OpenRestaurantMenu",
        StartMultiBoxDelivery = "SupplyChain:Client:StartMultiBoxDelivery",
        NewOrderNotification = "SupplyChain:Client:NewOrderNotification",
        OrderUpdate = "SupplyChain:Client:OrderUpdate",
        DeliveryComplete = "SupplyChain:Client:DeliveryComplete",
        SpawnDeliveryVan = "SupplyChain:Client:SpawnDeliveryVan"
    },
    
    -- Server Events
    Server = {
        -- Restaurant
        CreateRestaurantOrder = "SupplyChain:Server:CreateRestaurantOrder",
        GetWarehouseStockForOrder = "SupplyChain:Server:GetWarehouseStockForOrder",
        GetRestaurantStock = "SupplyChain:Server:GetRestaurantStock",
        WithdrawRestaurantStock = "SupplyChain:Server:WithdrawRestaurantStock",
        CompleteRecipe = "SupplyChain:Server:CompleteRecipe",
        
        -- Warehouse
        GetPendingOrders = "SupplyChain:Server:GetPendingOrders",
        AcceptDelivery = "SupplyChain:Server:AcceptDelivery",
        UpdateDeliveryProgress = "SupplyChain:Server:UpdateDeliveryProgress",
        CompleteDelivery = "SupplyChain:Server:CompleteDelivery",
        CancelDelivery = "SupplyChain:Server:CancelDelivery",
        GetWarehouseStock = "SupplyChain:Server:GetWarehouseStock",
        
        -- Team
        CreateTeam = "SupplyChain:Server:CreateTeam",
        InviteToTeam = "SupplyChain:Server:InviteToTeam",
        JoinTeam = "SupplyChain:Server:JoinTeam",
        LeaveTeam = "SupplyChain:Server:LeaveTeam",
        DisbandTeam = "SupplyChain:Server:DisbandTeam",
        
        -- Containers
        RentContainer = "SupplyChain:Server:RentContainer",
        ReturnContainer = "SupplyChain:Server:ReturnContainer",
        UpdateContainerStatus = "SupplyChain:Server:UpdateContainerStatus",
        
        -- Economy
        UpdateMarketPrices = "SupplyChain:Server:UpdateMarketPrices",
        ProcessPayment = "SupplyChain:Server:ProcessPayment",
        
        -- Analytics
        RecordDelivery = "SupplyChain:Server:RecordDelivery",
        UpdatePlayerStats = "SupplyChain:Server:UpdatePlayerStats",
        GetLeaderboard = "SupplyChain:Server:GetLeaderboard",
        UnlockAchievement = "SupplyChain:Server:UnlockAchievement",
        
        -- Multi-Order System
        AcceptWarehouseOrder = "SupplyChain:Server:AcceptWarehouseOrder",
        VanSpawned = "SupplyChain:Server:VanSpawned",
        DeliverContainer = "SupplyChain:Server:DeliverContainer",
        CompleteMultiBoxDelivery = "SupplyChain:Server:CompleteMultiBoxDelivery"
    }
}

-- Database Tables
SupplyChain.Constants.Database = {
    Tables = {
        -- Core Tables
        Orders = "supply_orders",
        OrderItems = "supply_order_items",
        Stock = "supply_stock",
        WarehouseStock = "supply_warehouse_stock",
        
        -- Restaurant Tables
        RestaurantOwners = "supply_restaurant_owners",
        RestaurantStock = "supply_restaurant_stock",
        RestaurantStats = "supply_restaurant_stats",
        
        -- Delivery Tables
        Deliveries = "supply_deliveries",
        DeliveryLogs = "supply_delivery_logs",
        DriverStats = "supply_driver_stats",
        
        -- Container Tables
        Containers = "supply_containers",
        ContainerRentals = "supply_container_rentals",
        ContainerQuality = "supply_container_quality_tracking",
        
        -- Team Tables
        Teams = "supply_teams",
        TeamMembers = "supply_team_members",
        TeamDeliveries = "supply_team_deliveries",
        
        -- Economic Tables
        MarketHistory = "supply_market_history",
        PriceHistory = "supply_price_history",
        Transactions = "supply_transactions",
        
        -- Analytics Tables
        Leaderboard = "supply_leaderboard",
        PlayerStats = "supply_player_stats",
        Achievements = "supply_achievements",
        PlayerAchievements = "supply_player_achievements",
        
        -- System Tables
        EmergencyOrders = "supply_emergency_orders",
        StockAlerts = "supply_stock_alerts",
        SystemLogs = "supply_system_logs"
    }
}

-- Order Status
SupplyChain.Constants.OrderStatus = {
    PENDING = "pending",
    ACCEPTED = "accepted",
    IN_PROGRESS = "in_progress",
    COMPLETED = "completed",
    CANCELLED = "cancelled",
    FAILED = "failed"
}

-- Delivery Status
SupplyChain.Constants.DeliveryStatus = {
    PREPARING = "preparing",
    LOADING = "loading",
    IN_TRANSIT = "in_transit",
    ARRIVED = "arrived",
    UNLOADING = "unloading",
    COMPLETED = "completed",
    RETURNED = "returned"
}

-- Container Status
SupplyChain.Constants.ContainerStatus = {
    AVAILABLE = "available",
    RENTED = "rented",
    IN_USE = "in_use",
    IN_TRANSIT = "in_transit",
    DAMAGED = "damaged",
    MAINTENANCE = "maintenance",
    RETIRED = "retired"
}

-- Emergency Priorities
SupplyChain.Constants.EmergencyPriority = {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
    URGENT = 4,
    CRITICAL = 5
}

-- Achievement Categories
SupplyChain.Constants.AchievementCategory = {
    DELIVERY = "delivery",
    SPEED = "speed",
    QUALITY = "quality",
    TEAM = "team",
    ECONOMY = "economy",
    SPECIAL = "special"
}

-- Notification Types
SupplyChain.Constants.NotificationType = {
    INFO = "info",
    SUCCESS = "success",
    WARNING = "warning",
    ERROR = "error",
    CRITICAL = "critical"
}

-- Time Constants (in milliseconds)
SupplyChain.Constants.Time = {
    SECOND = 1000,
    MINUTE = 60000,
    HOUR = 3600000,
    DAY = 86400000,
    WEEK = 604800000
}

-- Distance Constants
SupplyChain.Constants.Distance = {
    INTERACTION = 2.5,
    NEARBY = 10.0,
    LOADING_ZONE = 5.0,
    DELIVERY_ZONE = 10.0,
    TEAM_INVITE = 50.0
}

-- Quality Constants
SupplyChain.Constants.Quality = {
    PERFECT = 100,
    EXCELLENT = 90,
    GOOD = 75,
    FAIR = 50,
    POOR = 25,
    DAMAGED = 0
}

-- Animations
SupplyChain.Constants.Animations = {
    Carry = {
        dict = "anim@heists@box_carry@",
        anim = "idle"
    },
    Cooking = {
        dict = "mini@repair",
        anim = "fixing_a_ped"
    },
    Clipboard = {
        dict = "amb@world_human_clipboard@male@idle_a",
        anim = "idle_a"
    },
    Repair = {
        dict = "anim@scripted@heist@ig3_button_press@male@",
        anim = "button_press"
    }
}

-- Props
SupplyChain.Constants.Props = {
    Box = "ng_proc_box_01a",
    Pallet = "prop_pallet_02a",
    Till = "prop_till_01",
    Clipboard = "prop_notepad_01"
}

-- Blip Sprites
SupplyChain.Constants.Blips = {
    Restaurant = 106,
    Warehouse = 473,
    Delivery = 1,
    Team = 280,
    Emergency = 161,
    Container = 478,
    Docks = 410
}

-- Blip Colors
SupplyChain.Constants.BlipColors = {
    White = 0,
    Red = 1,
    Green = 2,
    Blue = 3,
    Yellow = 5,
    Purple = 7,
    Orange = 17,
    Grey = 40,
    Brown = 45
}

-- Key Bindings
SupplyChain.Constants.Keys = {
    INTERACT = 38,    -- E
    CANCEL = 73,      -- X
    MENU = 244,       -- M
    ACCEPT = 246,     -- Y
    DECLINE = 47      -- G
}

-- Limits
SupplyChain.Constants.Limits = {
    MAX_ORDER_ITEMS = 20,
    MAX_TEAM_SIZE = 4,
    MAX_CONTAINERS_PER_DELIVERY = 6,
    MAX_STREAK_COUNT = 100,
    MAX_QUALITY = 100,
    MIN_QUALITY = 0,
    MAX_TEMPERATURE_BREACH = 10,
    MAX_DELIVERY_DISTANCE = 5000
}

-- Cooldowns (in seconds)
SupplyChain.Constants.Cooldowns = {
    DELIVERY = 300,           -- 5 minutes
    ORDER = 60,              -- 1 minute
    TEAM_INVITE = 30,        -- 30 seconds
    CONTAINER_RENT = 600,    -- 10 minutes
    EMERGENCY_ORDER = 1800   -- 30 minutes
}

-- Export constants
exports('GetConstants', function()
    return SupplyChain.Constants
end)

print("^2[SupplyChain]^7 Constants loaded")