-- Team Management Server System

local Framework = SupplyChain.Framework
local StateManager = SupplyChain.StateManager
local Constants = SupplyChain.Constants

-- Get delivery teams from warehouse
local deliveryTeams = exports['ogz_supplychain']:GetDeliveryTeams()

-- Create team
RegisterNetEvent(Constants.Events.Server.CreateTeam)
AddEventHandler(Constants.Events.Server.CreateTeam, function(orderGroupId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Check if already in a team
    for teamId, team in pairs(deliveryTeams) do
        if team.leader == src or table.contains(team.members, src) then
            Framework.Notify(src, "You are already in a team", "error")
            return
        end
    end
    
    -- Create new team
    deliveryTeams[orderGroupId] = {
        leader = src,
        members = {},
        orderGroupId = orderGroupId,
        createdAt = os.time()
    }
    
    StateManager.CreateTeam(orderGroupId, src)
    
    Framework.Notify(src, "Team created! You can now invite players", "success")
    
    -- Log team creation
    MySQL.Async.insert([[
        INSERT INTO supply_teams (team_id, leader_id, order_group_id, created_at)
        VALUES (?, ?, ?, NOW())
    ]], {
        orderGroupId,
        GetPlayerCitizenId(src),
        orderGroupId
    })
end)

-- Invite to team
RegisterNetEvent(Constants.Events.Server.InviteToTeam)
AddEventHandler(Constants.Events.Server.InviteToTeam, function(targetId, orderGroupId)
    local src = source
    local player = Framework.GetPlayer(src)
    local targetPlayer = Framework.GetPlayer(targetId)
    
    if not player or not targetPlayer then
        Framework.Notify(src, "Player not found", "error")
        return
    end
    
    -- Check if team exists and player is leader
    local team = deliveryTeams[orderGroupId]
    if not team or team.leader ~= src then
        Framework.Notify(src, "You are not the team leader", "error")
        return
    end
    
    -- Check team size
    if #team.members >= Config.Teams.maxMembers - 1 then
        Framework.Notify(src, string.format("Team is full (max %d members)", Config.Teams.maxMembers), "error")
        return
    end
    
    -- Check if target is already in a team
    for _, t in pairs(deliveryTeams) do
        if t.leader == targetId or table.contains(t.members, targetId) then
            Framework.Notify(src, "Player is already in a team", "error")
            return
        end
    end
    
    -- Check proximity if required
    if Config.Teams.requireProximity then
        local playerPed = GetPlayerPed(src)
        local targetPed = GetPlayerPed(targetId)
        local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
        
        if distance > Config.Teams.proximityDistance then
            Framework.Notify(src, "Player is too far away", "error")
            return
        end
    end
    
    -- Send invite
    local playerName = GetPlayerName(src)
    TriggerClientEvent(Constants.Events.Client.TeamInvite, targetId, {
        inviterName = playerName,
        inviterId = src,
        orderGroupId = orderGroupId
    })
    
    Framework.Notify(src, string.format("Invite sent to %s", GetPlayerName(targetId)), "success")
end)

-- Join team
RegisterNetEvent(Constants.Events.Server.JoinTeam)
AddEventHandler(Constants.Events.Server.JoinTeam, function(orderGroupId)
    local src = source
    local player = Framework.GetPlayer(src)
    
    if not player then return end
    
    -- Check if team exists
    local team = deliveryTeams[orderGroupId]
    if not team then
        Framework.Notify(src, "Team no longer exists", "error")
        return
    end
    
    -- Check if already in a team
    for _, t in pairs(deliveryTeams) do
        if t.leader == src or table.contains(t.members, src) then
            Framework.Notify(src, "You are already in a team", "error")
            return
        end
    end
    
    -- Check team size
    if #team.members >= Config.Teams.maxMembers - 1 then
        Framework.Notify(src, "Team is full", "error")
        return
    end
    
    -- Add to team
    table.insert(team.members, src)
    StateManager.AddTeamMember(orderGroupId, src)
    
    -- Notify all team members
    Framework.Notify(team.leader, string.format("%s joined the team", GetPlayerName(src)), "success")
    for _, memberId in ipairs(team.members) do
        if memberId ~= src then
            Framework.Notify(memberId, string.format("%s joined the team", GetPlayerName(src)), "info")
        end
    end
    Framework.Notify(src, "You joined the team!", "success")
    
    -- Log team join
    MySQL.Async.insert([[
        INSERT INTO supply_team_members (team_id, player_id, joined_at)
        VALUES (?, ?, NOW())
    ]], {
        orderGroupId,
        GetPlayerCitizenId(src)
    })
    
    -- Send team update
    SendTeamUpdate(orderGroupId)
end)

-- Leave team
RegisterNetEvent(Constants.Events.Server.LeaveTeam)
AddEventHandler(Constants.Events.Server.LeaveTeam, function(orderGroupId)
    local src = source
    local team = deliveryTeams[orderGroupId]
    
    if not team then return end
    
    -- Check if leader
    if team.leader == src then
        -- Disband team if leader leaves
        TriggerEvent(Constants.Events.Server.DisbandTeam, orderGroupId)
        return
    end
    
    -- Remove from members
    for i, memberId in ipairs(team.members) do
        if memberId == src then
            table.remove(team.members, i)
            break
        end
    end
    
    -- Notify team
    Framework.Notify(team.leader, string.format("%s left the team", GetPlayerName(src)), "info")
    for _, memberId in ipairs(team.members) do
        Framework.Notify(memberId, string.format("%s left the team", GetPlayerName(src)), "info")
    end
    Framework.Notify(src, "You left the team", "info")
    
    -- Send team update
    SendTeamUpdate(orderGroupId)
end)

-- Disband team
RegisterNetEvent(Constants.Events.Server.DisbandTeam)
AddEventHandler(Constants.Events.Server.DisbandTeam, function(orderGroupId)
    local src = source
    local team = deliveryTeams[orderGroupId]
    
    if not team then return end
    
    -- Check if leader
    if team.leader ~= src then
        Framework.Notify(src, "Only the team leader can disband the team", "error")
        return
    end
    
    -- Notify all members
    Framework.Notify(team.leader, "Team disbanded", "info")
    for _, memberId in ipairs(team.members) do
        Framework.Notify(memberId, "Team has been disbanded", "info")
        TriggerClientEvent(Constants.Events.Client.TeamDisband, memberId)
    end
    
    -- Clean up
    deliveryTeams[orderGroupId] = nil
    StateManager.DisbandTeam(orderGroupId)
    
    -- Update database
    MySQL.Async.execute('UPDATE supply_teams SET disbanded_at = NOW() WHERE team_id = ?', { orderGroupId })
end)

-- Handle player disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    -- Check all teams
    for orderGroupId, team in pairs(deliveryTeams) do
        -- If leader disconnected
        if team.leader == src then
            if Config.Teams.disbandOnDisconnect then
                -- Disband team
                for _, memberId in ipairs(team.members) do
                    Framework.Notify(memberId, "Team leader disconnected. Team disbanded", "error")
                    TriggerClientEvent(Constants.Events.Client.TeamDisband, memberId)
                end
                
                deliveryTeams[orderGroupId] = nil
                StateManager.DisbandTeam(orderGroupId)
            else
                -- Promote first member to leader
                if #team.members > 0 then
                    local newLeader = team.members[1]
                    table.remove(team.members, 1)
                    team.leader = newLeader
                    
                    Framework.Notify(newLeader, "You are now the team leader", "success")
                    for _, memberId in ipairs(team.members) do
                        Framework.Notify(memberId, string.format("%s is now the team leader", GetPlayerName(newLeader)), "info")
                    end
                    
                    SendTeamUpdate(orderGroupId)
                else
                    -- No members, disband
                    deliveryTeams[orderGroupId] = nil
                    StateManager.DisbandTeam(orderGroupId)
                end
            end
        else
            -- Remove from members
            for i, memberId in ipairs(team.members) do
                if memberId == src then
                    table.remove(team.members, i)
                    
                    Framework.Notify(team.leader, string.format("%s disconnected from the team", GetPlayerName(src)), "info")
                    for _, mid in ipairs(team.members) do
                        Framework.Notify(mid, string.format("%s disconnected from the team", GetPlayerName(src)), "info")
                    end
                    
                    SendTeamUpdate(orderGroupId)
                    break
                end
            end
        end
    end
end)

-- Utility Functions
function SendTeamUpdate(orderGroupId)
    local team = deliveryTeams[orderGroupId]
    if not team then return end
    
    local teamData = {
        leader = {
            id = team.leader,
            name = GetPlayerName(team.leader)
        },
        members = {},
        orderGroupId = orderGroupId
    }
    
    for _, memberId in ipairs(team.members) do
        table.insert(teamData.members, {
            id = memberId,
            name = GetPlayerName(memberId)
        })
    end
    
    -- Send to all team members
    TriggerClientEvent(Constants.Events.Client.TeamUpdate, team.leader, teamData)
    for _, memberId in ipairs(team.members) do
        TriggerClientEvent(Constants.Events.Client.TeamUpdate, memberId, teamData)
    end
end

function GetPlayerCitizenId(playerId)
    local player = Framework.GetPlayer(playerId)
    if player then
        if Framework.Type == 'qbcore' then
            return player.PlayerData.citizenid
        else
            return player.citizenid
        end
    end
    return nil
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Export team functions
exports('GetTeamData', function(orderGroupId)
    return deliveryTeams[orderGroupId]
end)

exports('IsInTeam', function(playerId)
    for _, team in pairs(deliveryTeams) do
        if team.leader == playerId or table.contains(team.members, playerId) then
            return true, team
        end
    end
    return false, nil
end)

exports('GetPlayerTeam', function(playerId)
    for orderGroupId, team in pairs(deliveryTeams) do
        if team.leader == playerId or table.contains(team.members, playerId) then
            return team, orderGroupId
        end
    end
    return nil
end)