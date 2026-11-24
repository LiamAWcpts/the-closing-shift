--this game is played alone or with friends only
--the first player in a server owns it, anyone after that has to be a friend of someone here
--or have come in through someone's profile or invite, a stranger who lands here is sent off to a server of their own
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

--studio test players are never friends with each other, so none of this runs there
if RunService:IsStudio() then return end



local function knowsSomeoneHere(plr)
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= plr then
            --clicked join on this person's profile, or accepted their invite
            if plr.FollowUserId == other.UserId then return true end
            local ok, friends = pcall(function() return plr:IsFriendsWith(other.UserId) end)
            if ok and friends then return true end
        end
    end
    return false
end

Players.PlayerAdded:Connect(function(plr)
    --alone in the server: this is their own shift
    if #Players:GetPlayers() <= 1 then return end
    if knowsSomeoneHere(plr) then return end
    --how many times this player has already been moved on, so they never bounce forever
    local bounces = 0
    pcall(function()
        local data = plr:GetJoinData().TeleportData
        if type(data) == "table" and type(data.bounces) == "number" then bounces = data.bounces end
    end)
    local options = Instance.new("TeleportOptions")
    options:SetTeleportData({bounces = bounces + 1})
    --after two tries at a fresh public server, they get a private one of their own
    if bounces >= 2 then options.ShouldReserveServer = true end
    local ok = pcall(function() TeleportService:TeleportAsync(game.PlaceId, {plr}, options) end)
    if not ok then
        plr:Kick("this shift is private to a group of friends, rejoin to start your own")
    end
end)
