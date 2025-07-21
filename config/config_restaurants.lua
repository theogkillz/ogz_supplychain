-- ===============================================
-- RESTAURANT OWNERSHIP CONFIGURATION
-- ===============================================

Config.RestaurantOwnership = {
    enabled = true,
    
    -- Purchase System
    purchaseSystem = {
        enabled = true,
        requireBusinessLicense = true,       -- Requires 'business_license' item
        requireCreditCheck = false,          -- Future feature
        maxOwnedRestaurants = 3,            -- Max restaurants per player
        minimumCashRequired = 25000,        -- Minimum cash to attempt purchase
        
        -- Financing options
        financing = {
            enabled = true,
            minimumDownPayment = 0.25,      -- 25% minimum down payment
            maximumDownPayment = 1.0,       -- 100% can pay full price
            interestRate = 0.05,            -- 5% annual interest rate
            maximumTermMonths = 48,         -- 4 years maximum financing
            latePaymentPenalty = 500,       -- $500 late payment fee
            maxMissedPayments = 3           -- Repo after 3 missed payments
        },
        
        -- Restaurant pricing tiers
        pricingTiers = {
            basic = {
                multiplier = 1.0,           -- Base price
                description = "Standard location with basic amenities"
            },
            premium = {
                multiplier = 1.5,           -- 50% more expensive
                description = "Prime location with high foot traffic"
            },
            luxury = {
                multiplier = 2.0,           -- Double price
                description = "Exclusive location with premium amenities"
            }
        }
    },
    
    -- Owner Benefits
    ownerBenefits = {
        -- Supply chain advantages
        bulkDiscounts = {
            tier1 = { threshold = 1000, discount = 0.05, name = "Volume Buyer" },      -- 5% off $1k+ orders
            tier2 = { threshold = 2500, discount = 0.10, name = "Bulk Purchaser" },    -- 10% off $2.5k+ orders  
            tier3 = { threshold = 5000, discount = 0.15, name = "Wholesale Client" },  -- 15% off $5k+ orders
            tier4 = { threshold = 10000, discount = 0.20, name = "Enterprise Customer" } -- 20% off $10k+ orders
        },
        
        -- Delivery priorities
        deliveryBenefits = {
            prioritySlots = 3,              -- 3 priority delivery slots
            expeditedDelivery = true,       -- 50% faster delivery times
            qualityGuarantee = true,        -- Guaranteed minimum quality
            lateDeliveryCompensation = 100  -- $100 credit for late deliveries
        },
        
        -- Business operations
        operationalBenefits = {
            higherCommissionRates = 1.2,    -- 20% higher commission rates
            extendedPaymentTerms = true,    -- 30-day payment terms with suppliers
            exclusiveSuppliers = true,      -- Access to premium ingredient suppliers
            emergencyOrdering = true,       -- 24/7 emergency order capability
            advancedAnalytics = true,       -- Detailed business intelligence reports
            menuPricingControl = true,      -- Dynamic menu pricing control
            staffBonusPool = 0.1           -- 10% of profits go to staff bonus pool
        }
    },
    
    -- Staff Management System
    staffManagement = {
        enabled = true,
        maxStaffPerRestaurant = 12,
        autoPayroll = true,                 -- Automatic daily payroll
        
        -- Position definitions with wages and permissions
        positions = {
            owner = {
                basePay = 0,               -- Owners get profit share, not wages
                permissions = {
                    "all"                  -- Complete access
                },
                canHire = true,
                canFire = true,
                canSetWages = true,
                canAccessFinancials = true,
                description = "Restaurant owner with full control"
            },
            
            manager = {
                basePay = 30,             -- $30/hour
                permissions = {
                    "hire_staff", "fire_staff", "manage_inventory", 
                    "access_reports", "set_schedules", "handle_registers",
                    "supply_ordering", "quality_control"
                },
                canHire = true,
                canFire = true,
                canSetWages = false,
                canAccessFinancials = true,
                bonusEligible = true,
                description = "Restaurant manager with operational control"
            },
            
            chef = {
                basePay = 25,             -- $25/hour
                permissions = {
                    "kitchen_access", "recipe_management", "inventory_request",
                    "quality_control", "food_preparation", "menu_suggestions"
                },
                canHire = false,
                canFire = false,
                canSetWages = false,
                canAccessFinancials = false,
                bonusEligible = true,
                overtimeRate = 1.5,       -- Time and a half for overtime
                description = "Head chef responsible for food quality and kitchen operations"
            },
            
            cashier = {
                basePay = 18,             -- $18/hour
                permissions = {
                    "register_access", "customer_service", "handle_payments",
                    "process_orders", "inventory_view"
                },
                canHire = false,
                canFire = false,
                canSetWages = false,
                canAccessFinancials = false,
                commissionEligible = true, -- Eligible for sales commissions
                description = "Front-of-house cashier and customer service"
            },
            
            server = {
                basePay = 15,             -- $15/hour + tips
                permissions = {
                    "customer_service", "table_service", "order_taking",
                    "food_delivery", "tip_collection"
                },
                canHire = false,
                canFire = false,
                canSetWages = false,
                canAccessFinancials = false,
                tipEligible = true,       -- Eligible for customer tips
                description = "Table service and customer relations"
            },
            
            cleaner = {
                basePay = 12,             -- $12/hour
                permissions = {
                    "cleaning_access", "maintenance_basic", "inventory_cleaning"
                },
                canHire = false,
                canFire = false,
                canSetWages = false,
                canAccessFinancials = false,
                description = "Restaurant cleaning and basic maintenance"
            }
        },
        
        -- Payroll settings
        payroll = {
            frequency = "daily",          -- daily, weekly, bi-weekly
            overtimeThreshold = 8,        -- Hours before overtime kicks in
            maxHoursPerDay = 12,          -- Maximum hours per shift
            bonusDistribution = "performance", -- performance, equal, seniority
            tipPooling = true,            -- Share tips among eligible staff
            automaticTaxes = true         -- Automatic tax deductions
        }
    },
    
    -- Financial Management
    financialManagement = {
        enabled = true,
        
        -- Business expenses (daily)
        operatingExpenses = {
            rent = {
                basic = 500,              -- $500/day basic rent
                premium = 750,            -- $750/day premium location
                luxury = 1200             -- $1200/day luxury location
            },
            utilities = {
                base = 150,               -- Base utility cost
                perEmployee = 25,         -- Additional cost per employee
                seasonal = {
                    summer = 1.2,         -- 20% higher in summer (AC)
                    winter = 1.1          -- 10% higher in winter (heating)
                }
            },
            insurance = 100,              -- $100/day business insurance
            maintenance = 75,             -- $75/day maintenance fund
            licenses = 50                 -- $50/day license/permit fees
        },
        
        -- Revenue tracking
        revenueStreams = {
            registerSales = {
                enabled = true,
                commissionRate = 0.15,    -- 15% commission to restaurant
                taxRate = 0.08           -- 8% sales tax
            },
            deliveryOrders = {
                enabled = true,
                commissionRate = 0.12,    -- 12% commission (lower due to delivery costs)
                deliveryFee = 5          -- $5 delivery fee
            },
            cateringOrders = {
                enabled = true,
                commissionRate = 0.20,    -- 20% commission (premium service)
                minimumOrder = 200       -- $200 minimum catering order
            }
        },
        
        -- Financial reports
        reporting = {
            dailyReports = true,          -- Generate daily P&L
            weeklyReports = true,         -- Weekly performance summary
            monthlyReports = true,        -- Monthly financial statements
            quarterlyReports = true,      -- Quarterly business reviews
            automaticEmails = false,      -- Email reports to owner
            reportRetention = 365         -- Keep reports for 1 year
        },
        
        -- Banking integration
        banking = {
            businessAccount = true,       -- Separate business bank account
            automaticPayments = true,     -- Auto-pay rent, utilities, etc.
            profitDistribution = {
                ownerShare = 0.70,        -- 70% to owner
                staffBonusPool = 0.15,    -- 15% to staff bonuses
                businessReinvestment = 0.10, -- 10% reinvested in business
                emergencyFund = 0.05      -- 5% emergency fund
            }
        }
    },
    
    -- Quality Standards Integration (with OGZ supply chain)
    qualityStandards = {
        enabled = true,
        
        -- Default quality requirements
        defaultStandards = {
            minimumQuality = "good",      -- good, excellent
            temperatureControl = true,    -- Require temperature monitoring
            expirationChecks = true,     -- Check expiration dates
            autoRejectBelowStandard = false, -- Auto-reject deliveries below standard
            premiumBonusRate = 0.05      -- 5% bonus for premium quality ingredients
        },
        
        -- Ingredient-specific standards
        categoryStandards = {
            meats = {
                minimumQuality = "excellent", -- Higher standard for meats
                maxAge = 3,                   -- Maximum 3 days old
                temperatureRequired = "frozen"
            },
            dairy = {
                minimumQuality = "good",
                maxAge = 5,
                temperatureRequired = "refrigerated"
            },
            vegetables = {
                minimumQuality = "good",
                maxAge = 7,
                temperatureRequired = "refrigerated"
            },
            dryGoods = {
                minimumQuality = "fair",
                maxAge = 30,
                temperatureRequired = "room_temp"
            }
        }
    },
    
    -- Customer Service & Sales
    customerService = {
        enabled = true,
        
        -- Menu management
        menuManagement = {
            dynamicPricing = true,        -- Owners can adjust prices
            seasonalMenus = true,         -- Different menus by season
            dailySpecials = true,         -- Daily special items
            itemLimits = true,           -- Daily limits on popular items
            profitMarginTracking = true, -- Track profit margins per item
            popularityTracking = true    -- Track item popularity
        },
        
        -- Customer loyalty
        loyaltyProgram = {
            enabled = false,             -- Future feature
            pointsPerDollar = 1,
            rewardThreshold = 100
        },
        
        -- Service standards
        serviceStandards = {
            maxOrderWaitTime = 300,      -- 5 minutes max order wait
            qualityAssurance = true,     -- Quality checks before serving
            customerFeedback = true,     -- Collect customer reviews
            complaintHandling = true     -- Staff training for complaints
        }
    }
}

-- ===============================================
-- ENHANCED RESTAURANT CONFIGURATION
-- Extends your existing Config.Restaurants
-- ===============================================

-- Function to enhance existing restaurant configs with ownership features
local function enhanceRestaurantConfig(restaurantId, baseConfig)
    -- Add ownership-specific configuration to existing restaurants
    baseConfig.ownership = {
        enabled = true,
        purchasePrice = baseConfig.ownership_price or 150000, -- Default $150k
        pricingTier = baseConfig.pricing_tier or "basic",
        
        -- Management areas (like MT-Restaurants management points)
        management = baseConfig.management_points or {
            { coords = vector3(baseConfig.position.x + 1, baseConfig.position.y, baseConfig.position.z), 
              radius = 1.0, label = "Restaurant Management" }
        },
        
        -- Staff work stations
        stations = baseConfig.stations or {
            kitchen = {
                { coords = vector3(baseConfig.position.x - 2, baseConfig.position.y - 1, baseConfig.position.z), 
                  radius = 0.8, type = "cooking", label = "Kitchen Station" },
                { coords = vector3(baseConfig.position.x - 1, baseConfig.position.y - 1, baseConfig.position.z), 
                  radius = 0.8, type = "prep", label = "Food Prep" }
            },
            service = {
                { coords = vector3(baseConfig.position.x + 2, baseConfig.position.y, baseConfig.position.z), 
                  radius = 0.8, type = "register", label = "Register/POS" },
                { coords = vector3(baseConfig.position.x + 1, baseConfig.position.y + 1, baseConfig.position.z), 
                  radius = 0.8, type = "pickup", label = "Order Pickup" }
            }
        },
        
        -- Storage areas
        storage = baseConfig.storage or {
            main = { coords = vector3(baseConfig.position.x - 3, baseConfig.position.y, baseConfig.position.z), 
                    radius = 0.8, slots = 50, weight = 500, label = "Main Storage" },
            freezer = { coords = vector3(baseConfig.position.x - 4, baseConfig.position.y, baseConfig.position.z), 
                       radius = 0.8, slots = 25, weight = 200, label = "Freezer Storage" }
        },
        
        -- Restaurant zone boundaries
        zone = baseConfig.zone or {
            points = {
                vector3(baseConfig.position.x - 10, baseConfig.position.y - 10, baseConfig.position.z),
                vector3(baseConfig.position.x + 10, baseConfig.position.y - 10, baseConfig.position.z),
                vector3(baseConfig.position.x + 10, baseConfig.position.y + 10, baseConfig.position.z),
                vector3(baseConfig.position.x - 10, baseConfig.position.y + 10, baseConfig.position.z)
            },
            thickness = 8.0
        },
        
        -- Financial settings specific to this restaurant
        finances = {
            dailyRent = baseConfig.daily_rent or 500,
            utilityMultiplier = baseConfig.utility_multiplier or 1.0,
            commissionRate = baseConfig.commission_rate or 0.15,
            taxRate = baseConfig.tax_rate or 0.08
        },
        
        -- Default quality standards for this restaurant
        qualityDefaults = {
            minimumQuality = baseConfig.min_quality or "good",
            autoReject = baseConfig.auto_reject or false,
            premiumBonus = baseConfig.premium_bonus or 0.05
        }
    }
    
    return baseConfig
end

-- Example: Enhanced restaurant configuration
-- (Modify your existing Config.Restaurants entries)
if Config.Restaurants then
    for restaurantId, restaurantConfig in pairs(Config.Restaurants) do
        Config.Restaurants[restaurantId] = enhanceRestaurantConfig(restaurantId, restaurantConfig)
    end
end

-- ===============================================
-- RESTAURANT OWNERSHIP VALIDATION FUNCTIONS
-- ===============================================

-- Enhanced job validation (extends your existing Config.JobValidation)
Config.JobValidation.validateRestaurantOwnership = function(playerId, restaurantId)
    return {
        isOwner = false,        -- Will be set by server callback
        isStaff = false,        -- Will be set by server callback
        position = "none",      -- Will be set by server callback
        permissions = {}        -- Will be set by server callback
    }
end

-- Restaurant access validation (extends existing system)
Config.JobValidation.validateRestaurantAccess = function(playerId, restaurantId, requiredPermission)
    -- ✅ PROPER: Use the bridge layer exports that work with both frameworks
    local player = exports['qb-core']:GetPlayerData(playerId) -- Works with both QBCore and QBox bridge
    if not player or not player.PlayerData or not player.PlayerData.job then
        return false, "none"
    end
    
    local playerJob = player.PlayerData.job.name
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    
    -- Check traditional job access
    if playerJob == restaurantJob then
        return true, "employee"
    end
    
    -- Check admin/management access
    if playerJob == "admin" or playerJob == "god" then
        return true, "admin"
    end
    
    -- TODO: Check ownership/staff access (will use server callback in future)
    return false, "none"
end

-- ===============================================
-- INTEGRATION HOOKS
-- ===============================================

-- Hook into your existing supply chain system
Config.RestaurantOwnership.integrationHooks = {
    -- Order benefits for owners
    onOrderPlaced = function(playerId, restaurantId, orderItems, totalCost)
        -- Will be implemented in server-side integration
        return totalCost
    end,
    
    -- Quality check for owner standards
    onDeliveryReceived = function(restaurantId, containerData)
        -- Will be implemented in server-side integration
        return true
    end,
    
    -- Revenue tracking for sales
    onSaleCompleted = function(restaurantId, saleData)
        -- Will be implemented in server-side integration
        return true
    end
}

-- ===============================================
-- UI CONFIGURATION
-- ===============================================

Config.RestaurantOwnershipUI = {
    -- Management computer interface
    management = {
        title = "Restaurant Management System",
        position = "center",
        theme = "professional"
    },
    
    -- Financial dashboard
    financials = {
        showGraphs = true,
        showProfitLoss = true,
        showCashFlow = true,
        defaultPeriod = "30days"
    },
    
    -- Staff management interface
    staff = {
        showPerformance = true,
        showScheduling = true,
        showPayroll = true,
        maxDisplayed = 10
    }
}

-- ===============================================
-- NOTIFICATION INTEGRATION
-- ===============================================

-- Extend your existing notification system
if Config.Notifications then
    Config.Notifications.restaurant = {
        ownership = {
            purchase_success = "🏪 Restaurant purchased successfully!",
            payment_due = "💳 Restaurant payment due in 3 days",
            payment_overdue = "⚠️ Restaurant payment overdue!",
            staff_hired = "👥 New staff member hired",
            staff_fired = "👥 Staff member terminated",
            low_profit = "📉 Restaurant profits below threshold"
        }
    }
end

-- ✅ PROPER: Helper functions that work with both frameworks
function GetPlayerJobName()
    -- Works on client-side with both frameworks via bridge
    local playerData = exports['qb-core']:GetPlayerData() -- Bridge compatibility
    return (playerData and playerData.job and playerData.job.name) or "unemployed"
end

function HasJobAccess(requiredJobs)
    if not requiredJobs then return true end
    
    local playerJob = GetPlayerJobName()
    
    if type(requiredJobs) == "string" then
        return playerJob == requiredJobs
    elseif type(requiredJobs) == "table" then
        for _, job in ipairs(requiredJobs) do
            if playerJob == job then
                return true
            end
        end
    end
    
    return false
end

print("^2[OGZ-SupplyChain]^7 Restaurant Ownership Configuration Loaded!")
print("^3[INFO]^7 Enhanced " .. (Config.Restaurants and #Config.Restaurants or 0) .. " restaurants with ownership features")
print("^3[INFO]^7 Restaurant ownership system ready for implementation!")