--night music, room reverb, and muffling for sounds behind walls
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Config = require(RS:WaitForChild("MovementConfig"))
local monsterEv = RS:WaitForChild("MonsterEvent")

local OFFICE_MIN = Vector3.new(30.5, -5, -27)
local OFFICE_MAX = Vector3.new(40, 20, -15.2)
local STORE_MIN = Vector3.new(-60, -5, -40)
local STORE_MAX = Vector3.new(60, 30, 20)



local function inBox(p, a, b)
    return p.X > a.X and p.X < b.X and p.Y > a.Y and p.Y < b.Y and p.Z > a.Z and p.Z < b.Z
end

---------------------------------------------------------------- chase state for the music
--the player breathing is gone, this only tracks when the chase music should take over
local audioIds = require(RS:WaitForChild("AudioIds"))
local chased = false
monsterEv.OnClientEvent:Connect(function(kind, a)
    if kind == "hunt" and a == player.UserId then
        chased = true
    elseif kind == "huntEnd" and a == player.UserId then
        chased = false
    elseif kind == "kill" then
        chased = false
    end
end)

---------------------------------------------------------------- night music

--a low ambient bed for the whole night, the chase loop takes over while it is hunting you
local function musicLoop(id)
    local snd = Instance.new("Sound")
    snd.SoundId = id ~= "" and "rbxassetid://" .. id or ""
    snd.Looped = true
    snd.Volume = 0
    snd.Parent = SoundService
    return snd
end
local ambience = musicLoop(audioIds.nightAmbience)
local chase = musicLoop(audioIds.chaseLoop)
local killed = false
monsterEv.OnClientEvent:Connect(function(kind)
    if kind == "kill" then
        killed = true
        task.delay(6, function() killed = false end)
    end
end)


local function steer(snd, target, dt, rate)
    if snd.SoundId == "" then return end
    snd.Volume += (target - snd.Volume) * math.min(1, dt * rate)
    if target > 0 and not snd.IsPlaying then snd:Play()
    elseif target == 0 and snd.Volume < 0.003 and snd.IsPlaying then snd:Stop() end
end
RunService.Heartbeat:Connect(function(dt)
    local night = workspace:GetAttribute("NightActive") == true and not killed
    steer(ambience, night and (chased and 0.12 or 0.32) or 0, dt, 0.6)
    steer(chase, (night and chased) and 0.45 or 0, dt, chased and 2 or 0.5)
end)

---------------------------------------------------------------- room reverb from where the ears are
local currentReverb = nil
task.spawn(function()
    while true do
        local p = camera.CFrame.Position
        local want = Enum.ReverbType.ParkingLot
        if inBox(p, OFFICE_MIN, OFFICE_MAX) then
            want = Enum.ReverbType.LivingRoom
        elseif inBox(p, STORE_MIN, STORE_MAX) then
            want = Enum.ReverbType.Room
        end
        if want ~= currentReverb then
            currentReverb = want
            SoundService.AmbientReverb = want
        end
        task.wait(0.3)
    end
end)

---------------------------------------------------------------- muffling sounds that are behind walls
local tracked = {}

local function track(snd)
    if tracked[snd] then return end
    local eq = Instance.new("EqualizerSoundEffect")
    eq.Name = "Occlusion"
    eq.LowGain = 0 eq.MidGain = 0 eq.HighGain = 0
    eq.Parent = snd
    tracked[snd] = {eq = eq, level = 0}
    snd.Destroying:Connect(function() tracked[snd] = nil end)
end




--1 for a solid wall in the way, less for glass
local function blockedAmount(from, to, ignore)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = ignore
    local amount = 0
    for _ = 1, 4 do
        local hit = workspace:Raycast(from, to - from, rp)
        if not hit then break end
        if hit.Instance.Transparency > 0.3 then
            amount += 0.4
            rp:AddToFilter(hit.Instance)
        else
            return 1
        end
    end
    return math.min(1, amount)
end

task.spawn(function()
    while true do
        --pick up the monster sounds and door slams as they appear
        local rig = workspace:FindFirstChild("NightMonster")
        if rig then
            for _, s in ipairs(rig:GetDescendants()) do
                if s:IsA("Sound") then track(s) end
            end
        end
        local map = workspace:FindFirstChild("ChipotleMap")
        if map then
            for _, s in ipairs(map:GetDescendants()) do
                if s:IsA("Sound") and s.Name == "DoorSlam" then track(s) end
            end
        end
        task.wait(1)
    end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.1 then return end
    acc = 0
    local map = workspace:FindFirstChild("ChipotleMap")
    local ignore = {}
    for _, inst in ipairs({player.Character, workspace:FindFirstChild("NightMonster")}) do table.insert(ignore, inst) end
    if map then
        for _, name in ipairs({"GroundFog", "Ambience", "NightProps", "SecurityCameras"}) do
            local f = map:FindFirstChild(name)
            if f then table.insert(ignore, f) end
        end
    end
    local ear = camera.CFrame.Position
    for snd, info in pairs(tracked) do
        local src = snd.Parent
        if src and src:IsA("BasePart") and snd.IsPlaying then
            --the thing making the sound never blocks itself
            local list = table.clone(ignore)
            table.insert(list, src)
            if src.Parent and src.Parent:IsA("Model") then table.insert(list, src.Parent) end
            local target = blockedAmount(ear, src.Position, list)
            info.level += (target - info.level) * 0.4
            info.eq.HighGain = -24 * info.level
            info.eq.MidGain = -9 * info.level
            info.eq.LowGain = -2 * info.level
        end
    end
end)
