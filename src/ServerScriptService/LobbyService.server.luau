--the start screen's play button, and the trip back to it after a lost run
--every server is one shift of up to four players, there are no lobbies and no teleports
local RS = game:GetService("ReplicatedStorage")

local request = Instance.new("RemoteFunction")
request.Name = "LobbyRequest"
request.Parent = RS

local handlers = {}

--play: straight on to picking a character
handlers.play = function(plr)
    plr:SetAttribute("MenuDone", true)
    return true
end

--died with nobody left alive: all the way back to the start screen
handlers.toLobby = function(plr)
    local wasDead = plr:GetAttribute("Dead")
    plr:SetAttribute("Dead", nil)
    plr:SetAttribute("Waiting", nil)
    --a caught body is parked under the map, it gets a fresh one
    if wasDead then task.spawn(function() plr:LoadCharacter() end) end
    plr:SetAttribute("MenuDone", false)
    return true
end

request.OnServerInvoke = function(plr, kind, arg)
    local h = handlers[kind]
    if not h then return false, "unknown request" end
    local ok, a, b = pcall(h, plr, arg)
    if not ok then
        warn("lobby " .. tostring(kind) .. ": " .. tostring(a))
        return false, "something went wrong"
    end
    return a, b
end
