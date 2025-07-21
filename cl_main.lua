QBCore = exports['qb-core']:GetCoreObject()
currentOrder = {}
currentOrderRestaurantId = nil
boxCount = 0
lastDeliveryTime = 0
DELIVERY_COOLDOWN = 300000 -- 5 minutes in milliseconds
REQUIRED_BOXES = 3 -- Fixed number of boxes to deliver