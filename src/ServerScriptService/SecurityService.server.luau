local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ev = RS:WaitForChild("SecurityEvent")
local map = workspace:WaitForChild("ChipotleMap")
local chair = map:WaitForChild("BackRooms"):WaitForChild("OfficeChair")
local seat = chair:WaitForChild("OfficeSeat")
local prompt = chair:WaitForChild("ChairSeat"):WaitForChild("PromptPoint"):WaitForChild("ChairPrompt")
local cams = map:WaitForChild("SecurityCameras")

local seated = {}
--standing spot for after the player leaves the chair
local STAND = CFrame.lookAt(Vector3.new(36, 3.1, -16.8), Vector3.new(35, 3.1, -13))

--camera power: watching drains it, every flash costs a chunk, being away from the desk charges it back
--it runs out and the cameras shut off until it has charged back to RESTART
local DRAIN = 0.22
local RECHARGE = 0.9
local RESTART = 20
local DIFF_DRAIN = {Easy = 0.6, Normal = 1, Hard = 1.3}

prompt.Triggered:Connect(function(player)
    if seated[player] or seat.Occupant then return end
    if player:GetAttribute("InCutscene") then return end
    if player:GetAttribute("CamPowerOut") then
        ev:FireClient(player, "noPower")
        return
    end
    if not player:GetAttribute("ClockedIn") then
        RS:WaitForChild("ClockInEvent"):FireClient(player, "needClockIn")
        return
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    seated[player] = true
    seat:Sit(hum)
    ev:FireClient(player, "seated")
end)

local function stand(player)
    if not seated[player] then return end
    seated[player] = nil
    player.ReplicationFocus = nil
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum then hum.Sit = false end
    task.wait(0.15)
    if root then root.CFrame = STAND end
    ev:FireClient(player, "stood")
end

ev.OnServerEvent:Connect(function(player, kind, arg)
    if not seated[player] then return end
    if kind == "leave" then
        stand(player)
    elseif kind == "focus" then
        --keep the area around the camera streamed in while it is being watched
        local id = tonumber(arg)
        local cam = id and cams:FindFirstChild("SecurityCam" .. math.floor(id))
        if cam and cam.PrimaryPart then player.ReplicationFocus = cam.PrimaryPart end
    end
end)

Players.PlayerRemoving:Connect(function(player) seated[player] = nil end)

--full battery for everyone at the start of every night
workspace:GetAttributeChangedSignal("NightActive"):Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        p:SetAttribute("CamPower", 100)
        p:SetAttribute("CamPowerOut", false)
    end
    --the night is over, anyone still on the cameras gets out of the chair
    if not workspace:GetAttribute("NightActive") then
        for p in pairs(seated) do task.spawn(stand, p) end
    end
end)

local last = os.clock()
while true do
    task.wait(0.25)
    local dt = os.clock() - last
    last = os.clock()
    if workspace:GetAttribute("NightActive") then
        local diff = workspace:GetAttribute("Difficulty") or "Normal"
        local nightNum = workspace:GetAttribute("NightNumber") or 1
        --later nights drain faster, up to a third more on night 5
        local rate = DRAIN * (DIFF_DRAIN[diff] or 1) * (1 + 0.35 * (math.clamp(nightNum, 1, 5) - 1) / 4)
        for _, p in ipairs(Players:GetPlayers()) do
            local power = p:GetAttribute("CamPower") or 100
            if seated[p] then
                power = math.max(0, power - rate * dt)
            else
                power = math.min(100, power + RECHARGE * dt)
            end
            p:SetAttribute("CamPower", power)
            if power <= 0 and not p:GetAttribute("CamPowerOut") then
                p:SetAttribute("CamPowerOut", true)
                if seated[p] then
                    ev:FireClient(p, "noPower")
                    task.spawn(stand, p)
                end
            elseif p:GetAttribute("CamPowerOut") and power >= RESTART then
                p:SetAttribute("CamPowerOut", false)
            end
        end
    end
end
