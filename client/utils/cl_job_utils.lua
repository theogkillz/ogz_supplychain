function GetPlayerJobName()
    local job = Framework.GetPlayerJob()
    return job and job.name or "unemployed"
end

function HasJobAccess(requiredJobs)
    return Framework.HasJob(requiredJobs)
end