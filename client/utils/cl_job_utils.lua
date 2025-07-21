-- ============================================
-- CLIENT JOB UTILITIES
-- Helper functions for job access validation
-- ============================================

-- Get current player job name
function GetPlayerJobName()
    local job = Framework.GetPlayerJob()
    return job and job.name or "unemployed"
end

-- Check if player has job access
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

-- Get player's job grade level
function GetPlayerJobGrade()
    local job = Framework.GetPlayerJob()
    return job and job.grade and job.grade.level or 0
end

-- Check if player is boss of their job
function IsPlayerBoss()
    local job = Framework.GetPlayerJob()
    return job and job.isboss or false
end

-- Check if player has specific permission for their job
function HasJobPermission(permission)
    -- This can be expanded based on your permission system
    local job = Framework.GetPlayerJob()
    if not job then return false end
    
    -- Admin/God always have permission
    if job.name == "admin" or job.name == "god" then
        return true
    end
    
    -- Boss has all permissions for their job
    if job.isboss then
        return true
    end
    
    -- Add more permission logic as needed
    return false
end

-- Export functions for use in other resources
exports('GetPlayerJobName', GetPlayerJobName)
exports('HasJobAccess', HasJobAccess)
exports('GetPlayerJobGrade', GetPlayerJobGrade)
exports('IsPlayerBoss', IsPlayerBoss)
exports('HasJobPermission', HasJobPermission)