-- ===============================================
-- DOCKS IMPORT SYSTEM - CONFIGURATION
-- Extends existing config_main.lua with international import functionality
-- ===============================================

-- Add to your existing config_main.lua file

-- ===============================================
-- DOCKS IMPORT SYSTEM CONFIGURATION
-- ===============================================

Config.DocksImport = {
    enabled = true,
    
    -- Port Infrastructure
    portInfrastructure = {
        -- Main port location and operational areas
        portLocation = {
            name = "Los Santos International Port",
            coords = vector3(-162.69, -2407.18, 6.0), -- Adjust coordinates as needed
            heading = 270.0,
            radius = 150.0
        },
        
        -- Port operational zones
        operationalZones = {
            -- Container unloading areas
            unloadingZones = {
                {
                    name = "Berth A - Container Terminal",
                    coords = vector3(-180.5, -2420.8, 6.0),
                    radius = 25.0,
                    maxConcurrentOps = 3,
                    containerTypes = {"standard", "refrigerated", "oversized"}
                },
                {
                    name = "Berth B - Bulk Cargo",
                    coords = vector3(-150.2, -2380.6, 6.0),
                    radius = 20.0,
                    maxConcurrentOps = 2,
                    containerTypes = {"bulk", "liquid", "dry_goods"}
                },
                {
                    name = "Berth C - Refrigerated Terminal",
                    coords = vector3(-200.8, -2450.3, 6.0),
                    radius = 18.0,
                    maxConcurrentOps = 2,
                    containerTypes = {"refrigerated", "frozen", "temperature_controlled"}
                }
            },
            
            -- Customs and inspection areas
            customsZones = {
                {
                    name = "Customs Inspection Facility",
                    coords = vector3(-190.0, -2400.0, 6.0),
                    radius = 15.0,
                    maxConcurrentInspections = 5,
                    inspectionTypes = {"documents", "physical", "agricultural", "security"}
                }
            },
            
            -- Storage and forwarding areas
            storageZones = {
                {
                    name = "Temporary Storage Yard",
                    coords = vector3(-170.0, -2390.0, 6.0),
                    radius = 30.0,
                    maxStorageCapacity = 200,
                    storageTypes = {"short_term", "quarantine", "disputed"}
                }
            },
            
            -- Administrative areas
            adminZones = {
                {
                    name = "Port Authority Office",
                    coords = vector3(-165.0, -2405.0, 6.0),
                    radius = 10.0,
                    access = {"port_admin", "dock_supervisor", "customs_officer"}
                }
            }
        },
        
        -- Port operating schedule
        operatingHours = {
            enabled = true,
            openTime = 6,  -- 6 AM
            closeTime = 22, -- 10 PM
            weekendOperations = true,
            holidayOperations = false,
            nightShiftMultiplier = 1.25, -- 25% pay bonus for night work
            overtimeThreshold = 8 -- Hours before overtime
        }
    },
    
    -- Dock Worker Job Configuration
    dockWorker = {
        jobName = "dockworker",
        enabled = true,
        
        -- Worker classifications and pay rates
        classifications = {
            trainee = {
                name = "Dock Trainee",
                basePayRate = 18.50,      -- $18.50/hour
                maxOperationsPerShift = 3,
                allowedOperations = {"basic_unloading", "container_moving"},
                bonusMultiplier = 1.0,
                description = "Entry-level dock worker learning the basics"
            },
            
            worker = {
                name = "Dock Worker",
                basePayRate = 25.00,      -- $25/hour
                maxOperationsPerShift = 5,
                allowedOperations = {"unloading", "inspection", "container_handling", "basic_customs"},
                bonusMultiplier = 1.1,
                description = "Experienced dock worker handling standard operations"
            },
            
            specialist = {
                name = "Dock Specialist",
                basePayRate = 32.50,      -- $32.50/hour
                maxOperationsPerShift = 6,
                allowedOperations = {"all_operations", "quality_inspection", "hazmat_handling", "equipment_operation"},
                bonusMultiplier = 1.25,
                description = "Specialized worker with advanced certifications"
            },
            
            supervisor = {
                name = "Dock Supervisor",
                basePayRate = 45.00,      -- $45/hour
                maxOperationsPerShift = 8,
                allowedOperations = {"all_operations", "crew_management", "emergency_response", "port_coordination"},
                bonusMultiplier = 1.4,
                canAssignWork = true,
                canOverrideOperations = true,
                description = "Senior supervisor managing dock operations and crew"
            }
        },
        
        -- Performance-based bonuses
        performanceBonuses = {
            efficiency = {
                excellent = { threshold = 95, bonus = 100, name = "Efficiency Expert" },    -- 95%+ efficiency = $100 bonus
                good = { threshold = 85, bonus = 50, name = "Efficient Worker" },           -- 85%+ efficiency = $50 bonus
                satisfactory = { threshold = 75, bonus = 25, name = "Satisfactory" }       -- 75%+ efficiency = $25 bonus
            },
            
            safety = {
                zero_incidents = { bonus = 75, name = "Safety Champion" },                 -- No incidents = $75 bonus
                safety_first = { bonus = 25, name = "Safety Conscious" }                   -- Minor safety focus = $25 bonus
            },
            
            quality = {
                perfect_inspections = { bonus = 60, name = "Quality Inspector" },          -- Perfect quality checks = $60 bonus
                thorough_work = { bonus = 30, name = "Detail Oriented" }                   -- Good quality work = $30 bonus
            },
            
            teamwork = {
                crew_leader = { bonus = 40, name = "Crew Leader" },                        -- Leading team efforts = $40 bonus
                team_player = { bonus = 20, name = "Team Player" }                         -- Good cooperation = $20 bonus
            }
        },
        
        -- Equipment and certifications
        equipment = {
            basic = ["hand_truck", "pallet_jack", "safety_gear"],
            intermediate = ["forklift", "container_spreader", "inspection_tools"],
            advanced = ["crane_operation", "hazmat_equipment", "refrigeration_controls"],
            supervisor = ["port_management_system", "emergency_equipment", "communication_gear"]
        },
        
        -- Shift patterns
        shifts = {
            morning = { start = 6, end = 14, multiplier = 1.0 },      -- 6 AM - 2 PM
            afternoon = { start = 14, end = 22, multiplier = 1.05 },  -- 2 PM - 10 PM
            night = { start = 22, end = 6, multiplier = 1.25 },       -- 10 PM - 6 AM (next day)
            overtime = { multiplier = 1.5 }                           -- Time and a half
        }
    },
    
    -- International Suppliers Configuration
    suppliers = {
        enabled = true,
        
        -- Supplier relationship mechanics
        relationshipSystem = {
            enabled = true,
            
            -- Relationship levels affect pricing, priority, and terms
            levels = {
                new = { 
                    discountRate = 0.0, 
                    paymentTerms = "immediate", 
                    priorityShipping = false,
                    qualityGuarantee = false,
                    name = "New Customer"
                },
                established = { 
                    discountRate = 0.02,     -- 2% discount
                    paymentTerms = "NET15", 
                    priorityShipping = false,
                    qualityGuarantee = true,
                    name = "Established Customer",
                    requirement = { orders = 5, totalValue = 25000 }
                },
                preferred = { 
                    discountRate = 0.05,     -- 5% discount
                    paymentTerms = "NET30", 
                    priorityShipping = true,
                    qualityGuarantee = true,
                    name = "Preferred Customer",
                    requirement = { orders = 15, totalValue = 75000 }
                },
                premium = { 
                    discountRate = 0.08,     -- 8% discount
                    paymentTerms = "NET45", 
                    priorityShipping = true,
                    qualityGuarantee = true,
                    exclusiveAccess = true,
                    name = "Premium Partner",
                    requirement = { orders = 30, totalValue = 200000 }
                }
            }
        },
        
        -- Supplier categories and characteristics
        categories = {
            agricultural = {
                name = "Agricultural Suppliers",
                typicalLeadTime = 7,                    -- 7 days average shipping
                seasonalVariation = true,
                qualityVariance = 0.15,                 -- 15% quality variance
                priceVolatility = 0.20,                 -- 20% price variance
                specializations = {"vegetables", "fruits", "grains", "herbs"}
            },
            
            livestock = {
                name = "Livestock & Dairy",
                typicalLeadTime = 10,                   -- 10 days for livestock transport
                seasonalVariation = false,
                qualityVariance = 0.10,                 -- 10% quality variance  
                priceVolatility = 0.15,                 -- 15% price variance
                specializations = {"beef", "pork", "poultry", "dairy", "lamb"}
            },
            
            seafood = {
                name = "Seafood Suppliers",
                typicalLeadTime = 5,                    -- 5 days for fresh seafood
                seasonalVariation = true,
                qualityVariance = 0.25,                 -- 25% quality variance (perishable)
                priceVolatility = 0.30,                 -- 30% price variance (market fluctuations)
                specializations = {"fish", "shellfish", "seaweed", "processed_seafood"}
            },
            
            processed = {
                name = "Processed Foods",
                typicalLeadTime = 14,                   -- 14 days for processed goods
                seasonalVariation = false,
                qualityVariance = 0.08,                 -- 8% quality variance (controlled processing)
                priceVolatility = 0.12,                 -- 12% price variance
                specializations = {"canned_goods", "frozen_foods", "packaged_items", "preserves"}
            },
            
            specialty = {
                name = "Specialty & Exotic",
                typicalLeadTime = 21,                   -- 21 days for specialty items
                seasonalVariation = true,
                qualityVariance = 0.20,                 -- 20% quality variance
                priceVolatility = 0.35,                 -- 35% price variance (luxury/rare items)
                specializations = {"spices", "exotic_fruits", "rare_ingredients", "luxury_items"}
            },
            
            bulk = {
                name = "Bulk Commodities",
                typicalLeadTime = 28,                   -- 28 days for bulk shipments
                seasonalVariation = false,
                qualityVariance = 0.05,                 -- 5% quality variance (standardized)
                priceVolatility = 0.10,                 -- 10% price variance
                specializations = {"flour", "sugar", "salt", "cooking_oil", "rice"}
            }
        },
        
        -- Global pricing factors
        pricingFactors = {
            -- Currency exchange rate simulation
            exchangeRates = {
                enabled = true,
                baseRate = 1.0,                         -- USD baseline
                fluctuationRange = 0.05,                -- ±5% daily fluctuation
                updateInterval = 3600,                  -- Update every hour
                economicEvents = true                   -- Random economic events affect rates
            },
            
            -- Seasonal pricing adjustments
            seasonalAdjustments = {
                spring = { agricultural = 0.95, seafood = 1.10 },  -- Spring: cheaper produce, pricier seafood
                summer = { agricultural = 0.90, seafood = 1.20 },  -- Summer: cheapest produce, most expensive seafood
                autumn = { agricultural = 1.05, seafood = 0.95 },  -- Autumn: harvest costs, cheaper seafood
                winter = { agricultural = 1.15, seafood = 0.85 }   -- Winter: expensive produce, cheap seafood
            },
            
            -- Global economic factors
            globalFactors = {
                fuelPrices = { impact = 0.15, volatility = 0.10 }, -- Fuel affects shipping costs
                weatherEvents = { impact = 0.25, frequency = 0.05 }, -- Weather delays and damage
                politicalStability = { impact = 0.20, updateFrequency = "weekly" }, -- Political events
                tradeAgreements = { impact = 0.10, duration = "permanent" } -- Trade policy changes
            }
        }
    },
    
    -- Import Operations Configuration
    importOperations = {
        enabled = true,
        
        -- Container handling specifications
        containerHandling = {
            -- Container types and specifications
            containerTypes = {
                standard_20ft = {
                    name = "20ft Standard Container",
                    maxWeight = 28080,                  -- kg
                    maxVolume = 33.2,                   -- cubic meters
                    handlingTime = 45,                  -- minutes
                    unloadingCost = 150,                -- dollars
                    suitable_for = {"dry_goods", "packaged_items", "small_equipment"}
                },
                
                standard_40ft = {
                    name = "40ft Standard Container", 
                    maxWeight = 30480,                  -- kg
                    maxVolume = 67.7,                   -- cubic meters
                    handlingTime = 60,                  -- minutes
                    unloadingCost = 200,                -- dollars
                    suitable_for = {"general_cargo", "machinery", "bulk_packaged"}
                },
                
                high_cube_40ft = {
                    name = "40ft High Cube Container",
                    maxWeight = 30480,                  -- kg
                    maxVolume = 76.4,                   -- cubic meters
                    handlingTime = 65,                  -- minutes
                    unloadingCost = 220,                -- dollars
                    suitable_for = {"large_items", "lightweight_bulk", "machinery"}
                },
                
                refrigerated_40ft = {
                    name = "40ft Refrigerated Container",
                    maxWeight = 27700,                  -- kg (less due to cooling equipment)
                    maxVolume = 59.3,                   -- cubic meters
                    handlingTime = 90,                  -- minutes (temperature checks)
                    unloadingCost = 350,                -- dollars (specialized handling)
                    temperatureRange = {-29, 30},       -- Celsius
                    suitable_for = {"frozen_foods", "fresh_produce", "pharmaceuticals", "dairy"}
                },
                
                open_top_40ft = {
                    name = "40ft Open Top Container",
                    maxWeight = 30480,                  -- kg
                    maxVolume = 65.0,                   -- cubic meters
                    handlingTime = 75,                  -- minutes (crane required)
                    unloadingCost = 280,                -- dollars
                    suitable_for = {"oversized_cargo", "heavy_machinery", "raw_materials"}
                },
                
                tank_20ft = {
                    name = "20ft Tank Container",
                    maxWeight = 30480,                  -- kg
                    maxVolume = 25.0,                   -- cubic meters (liquid)
                    handlingTime = 120,                 -- minutes (specialized equipment)
                    unloadingCost = 450,                -- dollars
                    suitable_for = {"liquid_foods", "cooking_oil", "beverages", "chemicals"}
                }
            },
            
            -- Unloading process configuration
            unloadingProcess = {
                standardProcedure = {
                    initialInspection = 300,            -- 5 minutes
                    documentVerification = 600,         -- 10 minutes
                    containerPositioning = 900,         -- 15 minutes
                    actualUnloading = 1800,            -- 30 minutes (varies by container)
                    qualityCheck = 1200,               -- 20 minutes
                    inventoryLogging = 600,            -- 10 minutes
                    forwarding = 300                   -- 5 minutes
                },
                
                expeditedProcedure = {
                    timeReduction = 0.7,               -- 30% faster
                    costIncrease = 1.5,                -- 50% more expensive
                    qualityCheckReduction = 0.8        -- Slightly reduced quality checking
                },
                
                thoroughInspection = {
                    timeIncrease = 1.5,                -- 50% longer
                    costIncrease = 1.2,                -- 20% more expensive
                    qualityImprovement = 1.25          -- 25% better quality assurance
                }
            }
        },
        
        -- Quality control and inspection
        qualityControl = {
            enabled = true,
            
            -- Inspection levels
            inspectionLevels = {
                basic = {
                    name = "Basic Visual Inspection",
                    timeRequired = 300,                 -- 5 minutes
                    costPer100Items = 25,               -- $25 per 100 items
                    accuracyRate = 0.80,                -- 80% accuracy in detecting issues
                    detectableIssues = {"obvious_damage", "contamination", "packaging_failure"}
                },
                
                standard = {
                    name = "Standard Quality Check",
                    timeRequired = 900,                 -- 15 minutes
                    costPer100Items = 60,               -- $60 per 100 items
                    accuracyRate = 0.90,                -- 90% accuracy
                    detectableIssues = {"damage", "contamination", "quality_degradation", "labeling_errors"}
                },
                
                thorough = {
                    name = "Comprehensive Inspection",
                    timeRequired = 1800,                -- 30 minutes
                    costPer100Items = 120,              -- $120 per 100 items
                    accuracyRate = 0.95,                -- 95% accuracy
                    detectableIssues = {"all_issues", "minor_defects", "compliance_violations", "authenticity"}
                },
                
                laboratory = {
                    name = "Laboratory Analysis",
                    timeRequired = 7200,                -- 2 hours (offsite)
                    costPer100Items = 300,              -- $300 per 100 items
                    accuracyRate = 0.99,                -- 99% accuracy
                    detectableIssues = {"chemical_contamination", "nutritional_analysis", "authenticity_verification", "safety_testing"}
                }
            },
            
            -- Quality standards integration with existing system
            qualityStandards = {
                inheritance = true,                     -- Inherit from existing container system
                enhancedStandards = {
                    import_premium = 0.15,              -- 15% quality bonus for verified imports
                    origin_certification = 0.10,       -- 10% bonus for certified origin
                    laboratory_verified = 0.25          -- 25% bonus for lab-verified quality
                }
            }
        },
        
        -- Customs and regulatory compliance
        customsProcessing = {
            enabled = true,
            
            -- Documentation requirements
            requiredDocuments = {
                commercial_invoice = { processingTime = 300, required = true },
                bill_of_lading = { processingTime = 180, required = true },
                packing_list = { processingTime = 240, required = true },
                certificate_of_origin = { processingTime = 600, required = false },
                health_certificate = { processingTime = 900, required = "food_items" },
                quality_certificate = { processingTime = 720, required = "premium_goods" },
                import_permit = { processingTime = 1200, required = "restricted_items" }
            },
            
            -- Processing fees
            processingFees = {
                base_processing = 150,                  -- Base customs fee
                document_verification = 25,             -- Per document
                physical_inspection = 200,              -- If physical inspection required
                laboratory_testing = 500,               -- If lab testing required
                expedited_processing = 300,             -- Rush processing
                storage_per_day = 75                    -- Daily storage fees for delays
            },
            
            -- Inspection probability (triggers physical inspection)
            inspectionProbability = {
                new_supplier = 0.75,                    -- 75% chance for new suppliers
                established_supplier = 0.25,            -- 25% chance for established
                high_value_cargo = 0.50,               -- 50% for high-value shipments
                food_items = 0.60,                     -- 60% for food products
                random_inspection = 0.15               -- 15% random inspection rate
            }
        }
    },
    
    -- Market Integration & Economic Impact
    marketIntegration = {
        enabled = true,
        
        -- Price impact mechanics
        priceImpact = {
            -- How imports affect local market prices
            supplyImpactFormula = {
                base_impact = 0.10,                     -- 10% base price reduction per major import
                volume_multiplier = 0.05,               -- 5% additional per 1000 units imported
                quality_multiplier = 0.03,              -- 3% additional for premium quality
                competition_factor = 0.15,              -- 15% if competing with existing supply
                saturation_point = 5000,                -- Market saturation threshold
                recovery_time_days = 14                 -- Days for market to normalize
            },
            
            -- Quality premium effects
            qualityPremiums = {
                standard = 1.0,                         -- No premium
                premium = 1.15,                         -- 15% premium
                organic = 1.25,                         -- 25% premium
                luxury = 1.50                          -- 50% premium
            }
        },
        
        -- Supply chain integration
        warehouseIntegration = {
            enabled = true,
            
            -- How imports feed into existing warehouse system
            distributionRules = {
                direct_to_warehouse = 0.80,             -- 80% goes directly to warehouse
                quality_quarantine = 0.15,              -- 15% held for quality verification
                customs_hold = 0.05,                    -- 5% held for customs issues
                automatic_forwarding = true,            -- Auto-forward after processing
                priority_based_on_orders = true         -- Prioritize based on pending orders
            },
            
            -- Integration with existing container system
            containerIntegration = {
                convert_import_containers = true,       -- Convert import containers to warehouse containers
                preserve_quality_data = true,           -- Maintain quality tracking
                preserve_origin_data = true,            -- Track country of origin
                apply_landed_cost = true                -- Include import costs in pricing
            }
        },
        
        -- Economic simulation
        economicFactors = {
            globalSupplyShocks = {
                enabled = true,
                frequency = 0.02,                       -- 2% chance per day
                impact_range = {0.15, 0.40},           -- 15-40% price impact
                duration_days = {7, 21},               -- 1-3 weeks duration
                affected_categories = {"all"}          -- Can affect any category
            },
            
            seasonalDemand = {
                enabled = true,
                holiday_periods = {
                    thanksgiving = { impact = 1.25, categories = {"agricultural", "processed"} },
                    christmas = { impact = 1.40, categories = {"specialty", "luxury"} },
                    summer = { impact = 1.15, categories = {"seafood", "beverages"} }
                }
            }
        }
    },
    
    -- Notifications and Alerts
    notifications = {
        enabled = true,
        
        -- Alert types for dock operations
        alertTypes = {
            shipment_arrived = {
                enabled = true,
                recipients = {"dock_workers", "port_admin", "warehouse_manager"},
                urgency = "normal"
            },
            
            customs_delay = {
                enabled = true,
                recipients = {"port_admin", "customs_officer", "importer"},
                urgency = "high"
            },
            
            quality_issue = {
                enabled = true,
                recipients = {"quality_inspector", "port_admin", "supplier"},
                urgency = "high"
            },
            
            container_ready = {
                enabled = true,
                recipients = {"warehouse_manager", "delivery_drivers"},
                urgency = "normal"
            },
            
            payment_due = {
                enabled = true,
                recipients = {"port_admin", "accounting"},
                urgency = "medium"
            }
        }
    }
}

-- ===============================================
-- INTEGRATION HOOKS WITH EXISTING SYSTEMS
-- ===============================================

-- Dock Worker Job Integration (extends existing job system)
if Config.Jobs then
    Config.Jobs.warehouse = Config.Jobs.warehouse or {}
    table.insert(Config.Jobs.warehouse, "dockworker")
    
    Config.Jobs.dockworker = {"dockworker", "admin", "god"}
end

-- Enhanced job validation for dock workers
Config.JobValidation.validateDockWorkerAccess = function(playerJob)
    return playerJob == "dockworker" or Config.JobValidation.validateWarehouseAccess(playerJob)
end

Config.JobValidation.validateDockOperationAccess = function(playerJob, operationType)
    if not Config.JobValidation.validateDockWorkerAccess(playerJob) then
        return false
    end
    
    -- Additional validation based on operation type
    local classification = getDockWorkerClassification(playerJob) -- Server-side function
    local allowedOps = Config.DocksImport.dockWorker.classifications[classification].allowedOperations
    
    return table.contains(allowedOps, operationType) or table.contains(allowedOps, "all_operations")
end

-- Integration with existing notification system
if Config.Notifications then
    Config.Notifications.docks = {
        shipment_arrival = "🚢 Shipment has arrived at the port",
        customs_cleared = "✅ Customs clearance completed",
        quality_passed = "🎯 Quality inspection passed",
        container_ready = "📦 Container ready for warehouse transfer",
        operation_completed = "✅ Dock operation completed successfully"
    }
end

-- ===============================================
-- ENHANCED CONTAINER SYSTEM INTEGRATION
-- ===============================================

-- Extend existing container configuration for imports
if Config.DynamicContainers then
    -- Add import container types
    Config.DynamicContainers.containerTypes["import_standard"] = {
        name = "Import Standard Container",
        item = "import_container_standard",
        maxCapacity = 20,                           -- Higher capacity for bulk imports
        cost = 0,                                   -- No cost (comes with import)
        suitableCategories = {"all"},
        preservationMultiplier = 1.1,              -- Slightly better preservation
        temperatureControlled = false,
        qualityBonus = 0.05,                       -- 5% quality bonus
        importContainer = true,                    -- Flag as import container
        requiresCustomsClearance = true
    }
    
    Config.DynamicContainers.containerTypes["import_refrigerated"] = {
        name = "Import Refrigerated Container",
        item = "import_container_refrigerated",
        maxCapacity = 18,                          -- Slightly less due to cooling equipment
        cost = 0,
        suitableCategories = {"Meats", "Dairy", "Seafood"},
        preservationMultiplier = 1.4,             -- Much better preservation
        temperatureControlled = true,
        qualityBonus = 0.15,                      -- 15% quality bonus
        importContainer = true,
        requiresCustomsClearance = true,
        requiresQualityInspection = true
    }
    
    Config.DynamicContainers.containerTypes["import_bulk"] = {
        name = "Import Bulk Container",
        item = "import_container_bulk",
        maxCapacity = 25,                          -- Highest capacity
        cost = 0,
        suitableCategories = {"DryGoods", "Grains"},
        preservationMultiplier = 1.0,             -- Standard preservation
        temperatureControlled = false,
        qualityBonus = 0.03,                      -- Small quality bonus
        importContainer = true,
        requiresCustomsClearance = true,
        bulkContainer = true
    }
end

-- ===============================================
-- ECONOMIC INTEGRATION
-- ===============================================

-- Integration with existing market pricing
if Config.MarketPricing then
    -- Add import factors to existing market pricing
    Config.MarketPricing.factors.importSupply = {
        enabled = true,
        weight = 0.15,                            -- 15% of price calculation
        importImpactMultiplier = 0.25,           -- How much imports affect local prices
        qualityPremiumMultiplier = 1.2,          -- Premium for imported quality
        originPremiumMultiplier = 1.1            -- Premium for exotic origins
    }
    
    -- Add import events to market events
    Config.MarketPricing.events.import_arrival = {
        enabled = true,
        threshold = 1000,                         -- Shipments over 1000 units
        multiplier = 0.85,                       -- 15% temporary price reduction
        duration = 2400                          -- 40 minute duration
    }
end

-- ===============================================
-- UI INTEGRATION
-- ===============================================

Config.DocksUI = {
    management = {
        title = "Port Management System",
        position = "center",
        theme = "maritime"
    },
    
    operations = {
        showContainerStatus = true,
        showQualityData = true,
        showCustomsStatus = true,
        realTimeUpdates = true
    },
    
    workerInterface = {
        showPerformanceMetrics = true,
        showEarningsTracker = true,
        showOperationQueue = true,
        showSafetyReminders = true
    }
}

-- ===============================================
-- COMPATIBILITY FUNCTIONS
-- ===============================================

-- Helper functions for integration
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Validation function for dock operations
function validateDocksEnabled()
    return Config.DocksImport and Config.DocksImport.enabled
end

-- Get dock worker classification (placeholder - implement server-side)
function getDockWorkerClassification(playerJob)
    -- This will be implemented server-side
    return "worker" -- Default classification
end

print("^2[OGZ-SupplyChain]^7 Docks Import Configuration Loaded!")
print("^3[INFO]^7 International suppliers: " .. (Config.DocksImport.suppliers.enabled and "Enabled" or "Disabled"))
print("^3[INFO]^7 Port operations: " .. (Config.DocksImport.importOperations.enabled and "Active" or "Inactive"))
print("^3[INFO]^7 Market integration: " .. (Config.DocksImport.marketIntegration.enabled and "Connected" or "Standalone"))