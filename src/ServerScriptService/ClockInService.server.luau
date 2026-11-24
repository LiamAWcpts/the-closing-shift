--every night starts at the wall ipad, the office stays shut until the player has clocked in
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local ev = RS:WaitForChild("ClockInEvent")
local pad = workspace:WaitForChild("ChipotleMap"):WaitForChild("ClockIn")
local screen = pad:WaitForChild("Screen")
local prompt = screen:WaitForChild("PromptPoint"):WaitForChild("ClockInPrompt")

local DAYS = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
local MONTHS = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}


local function randomDate()
    return DAYS[math.random(1, 7)] .. ", " .. MONTHS[math.random(1, 12)] .. " " .. math.random(1, 28)
end

prompt.Triggered:Connect(function(player)
    if player:GetAttribute("ClockedIn") or player:GetAttribute("InCutscene") then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position - screen.Position).Magnitude > 10 then return end
    ev:FireClient(player, "open")
end)

ev.OnServerEvent:Connect(function(player, kind, code)
    if kind ~= "submit" or player:GetAttribute("ClockedIn") then return end
    --exactly seven digits, nothing else
    if type(code) ~= "string" or not string.match(code, "^%d%d%d%d%d%d%d$") then
        ev:FireClient(player, "bad")
        return
    end
    local date = randomDate()
    player:SetAttribute("ClockInDate", date)
    player:SetAttribute("ClockedIn", true)
    ev:FireClient(player, "ok", "12:00 AM", date)
end)

--a finished night means the next one starts with a fresh clock in
local wasActive = workspace:GetAttribute("NightActive") == true
workspace:GetAttributeChangedSignal("NightActive"):Connect(function()
    local now = workspace:GetAttribute("NightActive") == true
    if wasActive and not now then
        for _, p in ipairs(Players:GetPlayers()) do p:SetAttribute("ClockedIn", false) end
    end
    wasActive = now
end)

Players.PlayerAdded:Connect(function(p) p:SetAttribute("ClockedIn", false) end)
for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("ClockedIn") == nil then p:SetAttribute("ClockedIn", false) end end
