--the monster walks the store for real: pathfinds between rooms, opens doors, reacts to cameras and to the player
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PFS = game:GetService("PathfindingService")
local CS = game:GetService("CollectionService")

local map = workspace:WaitForChild("ChipotleMap")
local rigs = RS:WaitForChild("MonsterRigs")
local ev = RS:WaitForChild("MonsterEvent")
local secEv = RS:WaitForChild("SecurityEvent")
local camInfo = RS:WaitForChild("SecurityCams")
local backRooms = map:WaitForChild("BackRooms")
local officeDoor = backRooms:WaitForChild("OfficeDoorModel")
local officeSeat = backRooms:WaitForChild("OfficeChair"):WaitForChild("OfficeSeat")

local rad = math.rad

local function flat(x, z) return Vector3.new(x, 0, z) end




local function flatten(v) return Vector3.new(v.X, 0, v.Z) end

local function rand(a, b) return a + math.random() * (b - a) end

----------------------------------------------------------------- tuning
local CREEP_SPEED = 6
local WALK_SPEED = 9
local HUNT_SPEED = 18.5
local FLEE_SPEED = 22
local CAM_RANGE = 58
--matches the wider 88 degree feed lens
local CAM_COS = math.cos(rad(56))
local FLASH_RANGE = 52
--camera power one flash uses, out of 100
local FLASH_COST = 7
local NOTICE_RANGE = 55
local HEAR_RANGE = 14
local CATCH_RANGE = 4.6
local HUNT_GIVEUP = 22
local FREEZE_LIMIT = 4
local OFFICE_MIN = Vector3.new(30.5, -5, -27)
local OFFICE_MAX = Vector3.new(40, 20, -15.2)
local OFFICE_EYE = Vector3.new(36.2, 4.45, -20)
--standing in the hall right outside the office door
local OFFICE_FRONT = flat(35, -12.6)
local HIDDEN = CFrame.new(0, -300, 0)
local SCALE = {Monster1 = 1.2}

--where it waits for each camera and which way it faces there
local SPOTS = {
    [1] = {at = flat(-62.6, 16), face = flat(-55, 16), door = true},
    [2] = {at = flat(13, 21.7), face = flat(13, 12), door = true},
    [3] = {at = flat(16.5, 13.6), face = flat(22, 16)},
    [4] = {at = flat(23.1, 16), face = flat(30, 16), door = true},
    [5] = {at = flat(11.6, -11.4), face = flat(30, -11)},
    [6] = {at = flat(35, -13.1), face = flat(35, -20), door = true},
    [7] = {at = flat(43.4, 15.9), face = flat(30, 15.9)},
}
--the two real ways into the building
--stand is where its hands reach the door, push doors swing away from it, pull doors swing toward it
local ENTRIES = {
    [1] = {out = flat(-64, 24), inside = flat(-55, 16), doorAt = flat(-60, 16), stand = flat(-62.1, 16), push = true, face = flat(-50, 16)},
    [2] = {out = flat(19, 25), inside = flat(13, 15), doorAt = flat(13, 19.75), stand = flat(9.9, 21.1), push = false, hinge = flat(15.3, 19.75), leaf = 4.6, openAngle = 95},
}
local BREAK_TIME = 2.8
local INTERIOR = {3, 4, 5, 7}

----------------------------------------------------------------- state
local rig, root, head, hum = nil, nil, nil, nil
local joints, base, tracks, sounds = {}, {}, {}, {}
local feet, scale, rigWidth = 3, 1, 4
local curPos, curY, yaw, sideYaw = Vector3.zero, 0.5, 0, 0
--extra height for climbing over things
local liftY = 0
local state = "hidden"
local mode = "creep"
local lurkSpot = nil
local flashed = false
--set while it bursts in on a timed out task or a caught player, nothing stops those
local flashImmune = false
local flashCamId = nil
local flashTime = 0
--while set the monster walks off with its head locked on this point
local retreatStare = nil
--true while lining up at a door it is about to break open by hand
local skipDoors = false
--true while it is on its way to look in the office, it already knows where they are
local noNotice = false
local nightToken = 0
local activeNight = -1
local strideDist = 0
local opened = {}
--true once it is fully inside the store, the flash stops working from then on
local entered = false
--seconds the body has been pressed against something it cannot get past
local stuckTime = 0
--set while it is lined up on a way in, being looked at does not scare it off then
local committed = false
--"seen" when a player on foot looked at it too long, flee() then bolts instead of backing off from a camera
local spookKind = nil
local spookPlayer = nil
local lastBolt = -99

--once the shift is failed only the kill itself keeps running, every other behaviour stops where it is
local jobFailing = false
local failThread = nil

local function cancelled()
    return nightToken ~= activeNight or (jobFailing and coroutine.running() ~= failThread)
end

----------------------------------------------------------------- who is watching what
local focus = {}
local lastWatched = {}
secEv.OnServerEvent:Connect(function(player, kind, arg)
    if kind == "focus" then
        focus[player] = tonumber(arg)
    elseif kind == "leave" then
        focus[player] = nil
    end
end)
Players.PlayerRemoving:Connect(function(player) focus[player] = nil end)


local function isFocused(id)
    for _, camId in pairs(focus) do
        if camId == id then return true end
    end
    return false
end




local function isSeated(plr)
    local char = plr.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.SeatPart == officeSeat
end


--everyone still on the shift, a caught player is out until the next night
local function alivePlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if hum and hum.Health > 0 and r and r.Position.Y > -100 and not p:GetAttribute("Dead") then table.insert(list, p) end
    end
    return list
end

local function inOffice(plr)
    local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    local p = r.Position
    return p.X > OFFICE_MIN.X and p.X < OFFICE_MAX.X and p.Z > OFFICE_MIN.Z and p.Z < OFFICE_MAX.Z
end

--only true once the office door has really swung into its frame, not the moment someone pressed close
local function officeShut()
    return officeDoor:GetAttribute("Open") ~= true and officeDoor:GetAttribute("Shut") == true
end


local function monsterInOffice()
    return curPos.X > OFFICE_MIN.X and curPos.X < OFFICE_MAX.X and curPos.Z > OFFICE_MIN.Z and curPos.Z < OFFICE_MAX.Z
end

----------------------------------------------------------------- doors
local doors = {}



local function addDoor(inst)
    local center, size
    if inst:IsA("Model") then
        local cf, s = inst:GetBoundingBox()
        center, size = cf.Position, s
    else
        center, size = inst.Position, inst.Size
    end
    local parts = {}
    if inst:IsA("BasePart") then table.insert(parts, inst) end
    for _, p in ipairs(inst:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(parts, p) end
    end
    --entry doors keep their frame and glass as loose parts next to them
    if inst:GetAttribute("DoorKind") == "Entry" then
        local key = string.sub(inst.Name, -1)
        for _, p in ipairs(inst.Parent:GetChildren()) do
            if p:GetAttribute("DoorGroup") == key then table.insert(parts, p) end
        end
    end
    table.insert(doors, {inst = inst, center = flatten(center), width = math.max(size.X, size.Z), parts = parts, outside = CS:HasTag(inst, "MonsterDoor")})
end
for _, d in ipairs(CS:GetTagged("InteractDoor")) do
    if d:IsDescendantOf(workspace) then addDoor(d) end
end
for _, d in ipairs(CS:GetTagged("MonsterDoor")) do addDoor(d) end

----------------------------------------------------------------- line of sight

local function baseFilter()
    local list = {map:FindFirstChild("Ambience"), map:FindFirstChild("GroundFog"), map:FindFirstChild("NightProps"), map:FindFirstChild("SecurityCameras")}
    if rig then table.insert(list, rig) end
    --doors that are open on the clients do not block anything
    for _, door in ipairs(doors) do
        if door.inst:GetAttribute("Open") then
            for _, p in ipairs(door.parts) do table.insert(list, p) end
        end
    end
    return list
end

local function clearLine(a, b, extra)
    local list = baseFilter()
    if extra then for _, e in ipairs(extra) do table.insert(list, e) end end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = list
    for _ = 1, 6 do
        local hit = workspace:Raycast(a, b - a, rp)
        if not hit then return true end
        --see through glass and other see through parts
        if hit.Instance.Transparency > 0.35 then
            rp:AddToFilter(hit.Instance)
        else
            return false
        end
    end
    return false
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true


--only a small step up counts as floor, so it can never climb furniture, counters or the roof
local function groundAt(x, z, fromY)
    local hit = workspace:Raycast(Vector3.new(x, fromY + 1.1, z), Vector3.new(0, -5, 0), groundParams)
    if hit and hit.Normal.Y > 0.6 then return hit.Position.Y end
    return fromY
end


--anything solid in the way at shin, chest and head height
local function bodyBlocked(dir, dist)
    local list = baseFilter()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(list, p.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = list
    params.RespectCanCollide = true
    local radius = 0.9 * scale
    for _, h in ipairs({1.3, 3, 5}) do
        local from = Vector3.new(curPos.X, curY + h * scale, curPos.Z)
        local hit = workspace:Raycast(from, dir * (radius + dist), params)
        if hit then return hit end
    end
    return nil
end

--a real line with nothing in between, glass counts as solid here
local function solidLine(a, b, extra)
    local list = baseFilter()
    if extra then for _, e in ipairs(extra) do table.insert(list, e) end end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = list
    return workspace:Raycast(a, b - a, params) == nil
end

----------------------------------------------------------------- rig and posing

local function destroyRig()
    if rig then rig:Destroy() end
    rig, root, head, hum = nil, nil, nil, nil
    joints, base, tracks, sounds = {}, {}, {}, {}
    state = "hidden"
    lurkSpot = nil
    opened = {}
    workspace:SetAttribute("MonsterSpot", 0)
end




local function makeSound(id, volume, speed, looped)
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. id
    snd.Volume = volume
    snd.PlaybackSpeed = speed or 1
    snd.Looped = looped or false
    --natural falloff, loud up close and fading smoothly with distance
    snd.RollOffMode = Enum.RollOffMode.InverseTapered
    snd.RollOffMinDistance = 7
    snd.RollOffMaxDistance = 85
    snd.Parent = root
    return snd
end

local function spawnRig(name)
    destroyRig()
    local source = rigs:FindFirstChild(name) or rigs:FindFirstChild("Monster1")
    rig = source:Clone()
    rig.Name = "NightMonster"
    --the rigs come with the newer constraint joints, swap them for classic motors so poses and animations both drive them
    for _, c in ipairs(rig:GetDescendants()) do
        if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
            local m = Instance.new("Motor6D")
            m.Name = c.Name
            m.Part0 = c.Attachment0.Parent
            m.Part1 = c.Attachment1.Parent
            m.C0 = c.Attachment0.CFrame
            m.C1 = c.Attachment1.CFrame
            m.Parent = c.Attachment1.Parent
            c:Destroy()
        elseif c:IsA("BallSocketConstraint") then
            c:Destroy()
        end
    end
    rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    scale = SCALE[source.Name] or 1.2
    rig:ScaleTo(rig:GetScale() * scale)
    rig:PivotTo(CFrame.new())
    local cf, size = rig:GetBoundingBox()
    feet = -(cf.Y - size.Y / 2)
    rigWidth = size.X
    root = rig:WaitForChild("HumanoidRootPart")
    head = rig:FindFirstChild("Head")
    root.Anchored = true
    for _, d in ipairs(rig:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
        elseif d:IsA("Motor6D") then
            joints[d.Name] = d
            base[d.Name] = d.C0
        end
    end
    hum = rig:FindFirstChildOfClass("Humanoid")
    hum.EvaluateStateMachine = false
    hum.BreakJointsOnDeath = false
    hum.RequiresNeck = false
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local function load(id)
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. id
        local ok, track = pcall(function() return animator:LoadAnimation(a) end)
        if ok then
            track.Looped = true
            return track
        end
    end
    rig:PivotTo(HIDDEN)
    rig.Parent = workspace
    --the body is animated on each client now, see MonsterAnimClient
    rig:SetAttribute("Mode", mode)
    sounds.knock = makeSound("9116200285", 1.1)
    sounds.creak = makeSound("9126254743", 1)
    --low breathy creature voice for when it locks eyes with something
    sounds.breath = makeSound("9113971584", 0.85, 0.85)
    sounds.flashHit = makeSound("9113971433", 1, 0.72)
    --metal giving way when a lock is forced
    sounds.clank = makeSound("9116698408", 1, 0.9)
    --break ins: a quiet rattle of the door in its frame while it leans on it, then the latch letting go
    sounds.rattle = makeSound("9118062766", 0)
    sounds.rattle.Looped = true
    sounds.latch = makeSound("9114829600", 0.55)
    sounds.step = {}
    for _, id in ipairs({"108290664490396", "96955798612091", "120195545352847", "112000835797556"}) do
        table.insert(sounds.step, makeSound(id, 0.55, 0.72))
    end
    groundParams.FilterDescendantsInstances = {rig, map:FindFirstChild("Ambience"), map:FindFirstChild("GroundFog"), map:FindFirstChild("NightProps")}
end


local function applyPose()
    root.CFrame = CFrame.new(curPos.X, curY + feet + liftY, curPos.Z) * CFrame.Angles(0, yaw + sideYaw, 0)
    if rig:GetAttribute("Mode") ~= mode then rig:SetAttribute("Mode", mode) end
end




--where the hands should land, nil lets them hang free
local function setHands(r, l)
    if not rig then return end
    rig:SetAttribute("HandR", r)
    rig:SetAttribute("HandL", l)
end



local function hide()
    for _, t in pairs(tracks) do t:Stop(0) end
    if root then root.CFrame = HIDDEN end
    state = "hidden"
    lurkSpot = nil
    entered = false
    liftY = 0
    setHands()
end


local function appearAt(pos, face)
    curPos = pos
    curY = groundAt(pos.X, pos.Z, 2)
    local d = face - pos
    yaw = math.atan2(-d.X, -d.Z)
    sideYaw = 0
    applyPose()
end


--joint angles sit on top of the rest pose, time 0 snaps
local function pose(name, angles, time)
    local j = joints[name]
    if not j then return end
    local target = base[name] * angles
    if not time or time <= 0 then
        j.C0 = target
    else
        TweenService:Create(j, TweenInfo.new(time, Enum.EasingStyle.Sine), {C0 = target}):Play()
    end
end


local function restPose(time)
    for name in pairs(joints) do pose(name, CFrame.new(), time) end
end


--hunched over, head cocked, arms hanging in front
local function sneakPose(time)
    pose("Waist", CFrame.Angles(rad(-22), 0, 0), time)
    pose("Neck", CFrame.Angles(rad(18), 0, rad(16)), time)
    pose("RightShoulder", CFrame.Angles(rad(28), 0, rad(-6)), time)
    pose("LeftShoulder", CFrame.Angles(rad(20), 0, rad(6)), time)
    pose("RightElbow", CFrame.Angles(rad(25), 0, 0), time)
    pose("LeftElbow", CFrame.Angles(rad(15), 0, 0), time)
end


local function walkPose(time)
    pose("Waist", CFrame.Angles(rad(-10), 0, 0), time)
    pose("Neck", CFrame.Angles(rad(8), 0, rad(10)), time)
    pose("RightShoulder", CFrame.new(), time)
    pose("LeftShoulder", CFrame.new(), time)
    pose("RightElbow", CFrame.new(), time)
    pose("LeftElbow", CFrame.new(), time)
end


local function runPose(time)
    restPose(time)
    pose("Waist", CFrame.Angles(rad(-24), 0, 0), time)
    pose("Neck", CFrame.Angles(rad(12), 0, 0), time)
end

--both hands flat on the door and the face pressed in
local function doorPose(time)
    pose("Waist", CFrame.Angles(rad(-10), 0, 0), time)
    pose("Neck", CFrame.Angles(rad(-6), 0, rad(22)), time)
    pose("RightShoulder", CFrame.Angles(rad(100), 0, rad(-8)), time)
    pose("LeftShoulder", CFrame.Angles(rad(92), 0, rad(8)), time)
    pose("RightElbow", CFrame.Angles(rad(10), 0, 0), time)
    pose("LeftElbow", CFrame.Angles(rad(10), 0, 0), time)
end

local function modePose(time)
    if mode == "creep" then sneakPose(time)
    elseif mode == "walk" then walkPose(time)
    else runPose(time) end
end


--turns the head straight at a point however far round that is, maxYaw stops it short of a full owl turn
local function lookAt(pos, tilt, maxYaw)
    if not head then return end
    local dir = root.CFrame:VectorToObjectSpace((pos - head.Position).Unit)
    local y = math.atan2(-dir.X, -dir.Z)
    if maxYaw then y = math.clamp(y, -maxYaw, maxYaw) end
    local p = math.asin(math.clamp(dir.Y, -1, 1))
    pose("Neck", CFrame.Angles(0, y, 0) * CFrame.Angles(p, 0, 0) * CFrame.Angles(0, 0, tilt or 0), 0)
end




local function setMoving(on)
    local walkTrack, runTrack = tracks.walk, tracks.run
    if not on then
        if walkTrack then walkTrack:Stop(0.25) end
        if runTrack then runTrack:Stop(0.25) end
        return
    end
    local speed = (mode == "creep" and CREEP_SPEED) or (mode == "walk" and WALK_SPEED) or HUNT_SPEED
    if mode == "run" then
        if walkTrack then walkTrack:Stop(0.2) end
        if runTrack then
            if not runTrack.IsPlaying then runTrack:Play(0.2) end
            runTrack:AdjustSpeed(speed / (20 * scale))
        end
    else
        if runTrack then runTrack:Stop(0.2) end
        if walkTrack then
            if not walkTrack.IsPlaying then walkTrack:Play(0.3) end
            walkTrack:AdjustSpeed(speed / (14 * scale))
        end
    end
end

--steps are played on each client in time with the feet
local function footstep() end

----------------------------------------------------------------- camera vision
local visible = {}
local prevVisible = {}


local function watchedVisible()
    for id in pairs(visible) do
        if isFocused(id) then return id end
    end
    return nil
end



local function updateVision()
    local now = {}
    if root and state ~= "hidden" and state ~= "killing" then
        local mid = root.Position
        --several points on the body, so glass bars, door frames or a paper sign never hide all of it
        local points = {mid}
        for _, n in ipairs({"Head", "UpperTorso", "RightHand", "LeftHand", "LowerTorso"}) do
            local p = rig:FindFirstChild(n)
            if p then table.insert(points, p.Position) end
        end
        for _, c in ipairs(camInfo:GetChildren()) do
            local id = c:GetAttribute("Id")
            if id then
                local pos = c:GetAttribute("Pos")
                local tgt = c:GetAttribute("Target")
                local dirCam = (tgt - pos).Unit
                local d = (mid - pos).Magnitude
                if d < CAM_RANGE then
                    for _, p in ipairs(points) do
                        local to = p - pos
                        if dirCam:Dot(to.Unit) > CAM_COS and clearLine(pos, p) then
                            now[id] = d
                            break
                        end
                    end
                end
            end
        end
    end
    for _, camId in pairs(focus) do lastWatched[camId] = time() end
    --a quick hit of static when it walks into the shot someone is watching
    for id in pairs(now) do
        if not prevVisible[id] and isFocused(id) then ev:FireAllClients("seen", id) end
    end
    prevVisible = now
    visible = now
    local mark = 0
    if lurkSpot then
        mark = lurkSpot
    elseif state ~= "hidden" then
        local best = math.huge
        for id, d in pairs(now) do
            if d < best then best = d mark = id end
        end
    end
    if workspace:GetAttribute("MonsterSpot") ~= mark then workspace:SetAttribute("MonsterSpot", mark) end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        local ok, err = pcall(updateVision)
        if not ok then warn("monster vision: " .. tostring(err)) end
    end
end)

----------------------------------------------------------------- noticing the player on foot


local function noticePlayer()
    if not root then return nil end
    local me = head and head.Position or root.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        local proot = char and char:FindFirstChild("HumanoidRootPart")
        if proot and h and h.Health > 0 and not isSeated(plr) then
            local d = (proot.Position - root.Position).Magnitude
            local eye = proot.Position + Vector3.new(0, 2.5, 0)
            if d < HEAR_RANGE and clearLine(me, eye, {char}) then return plr end
            if d < NOTICE_RANGE then
                local toMe = (root.Position - proot.Position).Unit
                if proot.CFrame.LookVector:Dot(toMe) > 0.55 and clearLine(eye, me, {char}) then return plr end
            end
        end
    end
    return nil
end

----------------------------------------------------------------- movement


local function turnToward(dir, dt, rate)
    local want = math.atan2(-dir.X, -dir.Z)
    local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
    yaw += diff * math.min(1, rate * dt)
    return math.abs(diff)
end


local function turnTo(point, time)
    local t = 0
    while t < time do
        local dt = RunService.Heartbeat:Wait()
        t += dt
        if cancelled() then return end
        turnToward(flatten(point) - curPos, dt, 6)
        applyPose()
    end
end

local function closeDoorsBehind()
    for door, closeAfter in pairs(opened) do
        if (curPos - door.center).Magnitude > 5.5 then
            local nearby = false
            for _, plr in ipairs(Players:GetPlayers()) do
                local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if r and (flatten(r.Position) - door.center).Magnitude < 7 then nearby = true end
            end
            if not nearby then
                opened[door] = nil
                if closeAfter then
                    --sneaking in it eases the outside door shut, running out it slams it
                    --the clients play the sound the frame the door meets the frame
                    if door.outside then door.inst:SetAttribute("Slam", mode == "run") end
                    door.inst:SetAttribute("Open", false)
                end
            end
        end
    end
end


--only doors between here and the next stop count, so it never opens one it is just standing next to
local function doorsAhead(dir, limit)
    local list = {}
    for _, door in ipairs(doors) do
        if not door.inst:GetAttribute("Open") then
            for k = 0, math.min(4, limit) do
                if (curPos + dir * k - door.center).Magnitude < 2.4 then
                    table.insert(list, door)
                    break
                end
            end
        end
    end
    return list
end



--reaches out, pushes the door, waits for it to swing
local function openDoors(list, fast)
    setMoving(false)
    pose("RightShoulder", CFrame.Angles(rad(88), 0, rad(-10)), fast and 0.08 or 0.4)
    pose("RightElbow", CFrame.Angles(rad(8), 0, 0), fast and 0.08 or 0.4)
    --palm goes flat on the door it is pushing
    local c = list[1].center
    setHands(Vector3.new(c.X, curY + 4.2 * scale / 1.2, c.Z))
    if not fast then task.wait(0.45) end
    for _, door in ipairs(list) do
        door.inst:SetAttribute("Open", true)
        opened[door] = door.outside or (mode == "creep" and math.random() < 0.5)
    end
    if not fast then sounds.creak:Play() end
    task.wait(fast and 0.2 or 0.5)
    setHands()
    if not fast then task.wait(0.3) end
    modePose(0.3)
    setMoving(true)
end


--one frame of walking toward a point, returns true once there
local function stepToward(target, speed, dt, fastDoors)
    local to = flatten(target) - curPos
    local d = to.Magnitude
    if d < 0.3 then return true end
    local dir = to / d
    local list = skipDoors and {} or doorsAhead(dir, d + 0.5)
    if #list > 0 then openDoors(list, fastDoors) end
    local off = turnToward(dir, dt, mode == "run" and 12 or 6)
    --a big turn happens on the spot first instead of moonwalking round it
    if off > rad(95) and mode ~= "run" then
        applyPose()
        return false
    end
    --wide bodies turn sideways to squeeze through doorways and tight gaps
    local squeeze = 0
    if rigWidth > 4.2 then
        for _, door in ipairs(doors) do
            if (curPos - door.center).Magnitude < 2.8 then squeeze = rad(90) end
        end
        if squeeze == 0 then
            local side = Vector3.new(-dir.Z, 0, dir.X) * (rigWidth / 2 + 0.1)
            local from = Vector3.new(curPos.X, curY + 2.5, curPos.Z)
            if workspace:Raycast(from, side, groundParams) or workspace:Raycast(from, -side, groundParams) then squeeze = rad(90) end
        end
    end
    sideYaw += (squeeze - sideYaw) * math.min(1, dt * 8)
    local stepLen = math.min(d, speed * dt)
    local move = dir
    local hit = bodyBlocked(dir, stepLen)
    if hit then
        --slides along whatever it touched instead of pushing into it
        local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
        move = nil
        if n.Magnitude > 0.1 then
            n = n.Unit
            local slide = dir - n * dir:Dot(n)
            if slide.Magnitude > 0.25 and not bodyBlocked(slide.Unit, stepLen) then
                move = slide.Unit
                stepLen *= slide.Magnitude
            end
        end
    end
    if not move then
        stuckTime += dt
        applyPose()
        return false
    end
    stuckTime = 0
    curPos += move * stepLen
    local g = groundAt(curPos.X, curPos.Z, curY)
    curY += (g - curY) * math.min(1, dt * 12)
    strideDist += stepLen
    local stride = (mode == "run" and 4.2 or 3.2) * scale
    if strideDist > stride then
        strideDist = 0
        footstep()
    end
    applyPose()
    return d - stepLen < 0.3
end




local function computePath(from, to)
    for _, r in ipairs({1.5, 1}) do
        local path = PFS:CreatePath({AgentRadius = r, AgentHeight = 7, AgentCanJump = false, WaypointSpacing = 3})
        local ok = pcall(function()
            path:ComputeAsync(Vector3.new(from.X, curY + 2.5, from.Z), Vector3.new(to.X, curY + 2.5, to.Z))
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            local pts = {}
            for _, w in ipairs(path:GetWaypoints()) do table.insert(pts, flatten(w.Position)) end
            return pts
        end
    end
    return nil
end

--waits until no watched camera can see it
----------------------------------------------------------------- never seen popping in or out
--past this the fog hides it anyway
--how far a player on foot can make it out, matches where the fog swallows it
local SIGHT_RANGE = 60

local function playerEyes()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local h = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if h and hum and hum.Health > 0 then table.insert(list, {eye = h.Position, char = char}) end
    end
    return list
end


--true if any player or a camera someone is watching has a clear line to one of these points
local function pointsSeen(points)
    for _, e in ipairs(playerEyes()) do
        for _, p in ipairs(points) do
            if (p - e.eye).Magnitude < SIGHT_RANGE and clearLine(e.eye, p, {e.char}) then return true end
        end
    end
    for _, c in ipairs(camInfo:GetChildren()) do
        local id = c:GetAttribute("Id")
        if id and isFocused(id) then
            local pos = c:GetAttribute("Pos")
            local dirCam = (c:GetAttribute("Target") - pos).Unit
            for _, p in ipairs(points) do
                local to = p - pos
                if to.Magnitude < CAM_RANGE and dirCam:Dot(to.Unit) > CAM_COS and clearLine(pos, p) then return true end
            end
        end
    end
    return false
end


--a whole standing body on that spot of ground
local function spotSeen(spot)
    local y = groundAt(spot.X, spot.Z, 2)
    local h = scale / 1.2
    local w = 0.9 * h
    return pointsSeen({
        Vector3.new(spot.X, y + 1.2 * h, spot.Z), Vector3.new(spot.X, y + 3.4 * h, spot.Z), Vector3.new(spot.X, y + 5.8 * h, spot.Z),
        Vector3.new(spot.X + w, y + 3.4 * h, spot.Z), Vector3.new(spot.X - w, y + 3.4 * h, spot.Z), Vector3.new(spot.X, y + 3.4 * h, spot.Z + w), Vector3.new(spot.X, y + 3.4 * h, spot.Z - w),
    })
end


--the body as it is right now
local function rigSeen()
    if not rig or not root or state == "hidden" or root.Position.Y < -100 then return false end
    if watchedVisible() then return true end
    local points = {root.Position}
    for _, n in ipairs({"Head", "UpperTorso", "LowerTorso"}) do
        local p = rig:FindFirstChild(n)
        if p then table.insert(points, p.Position) end
    end
    return pointsSeen(points)
end

local function waitUnseen(maxTime)
    local t = 0
    while rigSeen() and t < maxTime do
        t += task.wait(0.2)
        if cancelled() or flashed then return end
    end
end


--walks a real path, returns "arrived" "flashed" "notice" or "cancel"
local function walkTo(dest, newMode)
    mode = newMode
    if not retreatStare then state = "moving" end
    lurkSpot = nil
    local pts = computePath(curPos, dest)
    if not pts then
        --no route found: it heads straight there but walls still stop it, it never slips through anything
        pts = {dest}
    end
    stuckTime = 0
    local stuckCount = 0
    modePose(0.4)
    setMoving(true)
    local speed = (mode == "creep" and CREEP_SPEED) or (mode == "walk" and WALK_SPEED) or FLEE_SPEED
    local frozen = 0
    local unwatched = 1
    local checkTimer = 0
    local lookTimer = rand(5, 9)
    local i = 1
    while i <= #pts do
        local dt = RunService.Heartbeat:Wait()
        if cancelled() then return "cancel" end
        if flashed then setMoving(false) return "flashed" end
        checkTimer += dt
        if checkTimer > 0.2 then
            checkTimer = 0
            closeDoorsBehind()
            if mode ~= "run" and not retreatStare and not noNotice then
                local plr = noticePlayer()
                if plr then setMoving(false) return "notice", plr end
            end
        end
        local cam = (mode ~= "run" and not retreatStare) and watchedVisible() or nil
        if cam then unwatched = 0 else unwatched += dt end
        if cam and frozen < FREEZE_LIMIT then
            --caught on camera: it stops dead and looks straight into the lens
            if frozen == 0 then
                setMoving(false)
                sounds.breath:Play()
                ev:FireAllClients("stare", cam)
            end
            frozen += dt
            lookAt(camInfo["Cam" .. cam]:GetAttribute("Pos"), math.min(frozen * 0.15, rad(35)))
        elseif frozen > 0 and unwatched < 0.9 and frozen < FREEZE_LIMIT then
            --keeps still a beat after the camera leaves it
        else
            if frozen > 0 and not cam then
                frozen = 0
                modePose(0.4)
                setMoving(true)
            elseif frozen >= FREEZE_LIMIT and cam then
                --it keeps coming anyway, still staring at you
                if not (tracks.walk and tracks.walk.IsPlaying) then setMoving(true) end
                lookAt(camInfo["Cam" .. cam]:GetAttribute("Pos"), rad(30))
            end
            lookTimer -= dt
            if lookTimer <= 0 and mode == "creep" and not cam then
                lookTimer = rand(6, 10)
                if math.random() < 0.4 then
                    --stops to listen and looks around
                    setMoving(false)
                    pose("Neck", CFrame.Angles(rad(5), rad(55), rad(10)), 0.6)
                    task.wait(0.9)
                    pose("Neck", CFrame.Angles(rad(5), rad(-60), rad(-12)), 0.8)
                    task.wait(1.1)
                    modePose(0.5)
                    setMoving(true)
                end
            end
            if stepToward(pts[i], speed, dt, mode == "run") then i += 1 end
            --pressed against something: find a new way round, and give up rather than force through
            if stuckTime > 1.2 then
                stuckTime = 0
                stuckCount += 1
                if stuckCount > 2 then
                    setMoving(false)
                    return "blocked"
                end
                pts = computePath(curPos, dest) or pts
                i = 1
            end
            --walking off as if caught, head still turned back on the camera
            if retreatStare then lookAt(retreatStare, rad(32), rad(140)) end
        end
    end
    setMoving(false)
    closeDoorsBehind()
    return "arrived"
end

----------------------------------------------------------------- behaviour at a spot


local function twitch()
    local pick = math.random()
    if pick < 0.55 then
        pose("Neck", CFrame.Angles(rad(rand(-12, 22)), rad(rand(-45, 45)), rad(rand(-30, 30))), 0)
    elseif pick < 0.8 then
        local keep = curPos
        curPos = keep + Vector3.new(rand(-0.3, 0.3), 0, rand(-0.3, 0.3))
        applyPose()
        task.wait(0.06)
        curPos = keep
        applyPose()
    else
        pose("RightShoulder", CFrame.Angles(rad(rand(20, 70)), 0, rad(rand(-25, 5))), 0)
        task.wait(0.08)
        pose("RightShoulder", CFrame.Angles(rad(28), 0, rad(-6)), 0.3)
    end
end


local function bang()
    pose("RightShoulder", CFrame.Angles(rad(155), 0, rad(-8)), 0.16)
    task.wait(0.2)
    pose("RightShoulder", CFrame.Angles(rad(85), 0, rad(-8)), 0)
    local keep = curPos
    local fwd = root.CFrame.LookVector
    curPos = keep + flatten(fwd) * 0.3
    applyPose()
    task.wait(0.1)
    curPos = keep
    applyPose()
    pose("RightShoulder", CFrame.Angles(rad(100), 0, rad(-8)), 0.25)
end



--waits at a camera spot, returns "done" "flashed" "notice" or "cancel"
local function lurk(id, dwell)
    local spot = SPOTS[id]
    state = "lurking"
    lurkSpot = id
    turnTo(spot.face, 0.6)
    ev:FireAllClients("moved", id)
    if spot.door then doorPose(0.5) else sneakPose(0.5) end
    local t = 0
    local watchedFor = 0
    local staring = false
    local tilt = 0
    local nextTwitch = time() + 1
    local nextBang = time() + 1.2
    local checkTimer = 0
    while t < dwell do
        local dt = task.wait(0.1)
        t += dt
        if cancelled() then return "cancel" end
        if flashed then return "flashed" end
        checkTimer += dt
        if checkTimer > 0.3 then
            checkTimer = 0
            local plr = noticePlayer()
            if plr then return "notice", plr end
        end
        local cam = watchedVisible()
        if cam then watchedFor += dt else watchedFor = 0 end
        if watchedFor > 1.1 and not staring then
            --it notices the camera and goes dead still
            staring = true
            tilt = 0
            pose("RightShoulder", CFrame.new(), 0.6)
            pose("LeftShoulder", CFrame.new(), 0.6)
            pose("Waist", CFrame.new(), 0.6)
            sounds.breath:Play()
            ev:FireAllClients("stare", cam)
        elseif staring and watchedFor == 0 then
            staring = false
            if spot.door then doorPose(0.5) else sneakPose(0.5) end
        end
        if staring and cam then
            tilt = math.min(tilt + dt * 0.12, rad(38))
            lookAt(camInfo["Cam" .. cam]:GetAttribute("Pos"), tilt)
            if math.random() < 0.035 then
                --one frame closer to the lens then back
                local keep = curPos
                local camPos = camInfo["Cam" .. cam]:GetAttribute("Pos")
                curPos = keep + flatten(camPos - root.Position).Unit * 0.7
                applyPose()
                task.wait(0.07)
                curPos = keep
                applyPose()
            end
        elseif not staring then
            if time() >= nextTwitch then
                twitch()
                nextTwitch = time() + rand(0.3, 1.9)
            end
            if spot.door and time() >= nextBang then
                bang()
                nextBang = time() + rand(1.5, 3.4)
            end
        end
    end
    lurkSpot = nil
    return "done"
end

----------------------------------------------------------------- leaving, hunting, killing


local function nearestEntry()
    local best, bestD = 1, math.huge
    for i, e in ipairs(ENTRIES) do
        local d = (e.inside - curPos).Magnitude
        if d < bestD then best, bestD = i, d end
    end
    return best
end

--far corners of the lot and the backs of things, somewhere out of sight to come from or go to
local HIDE_SPOTS = {
    flat(-120, 88), flat(-120, 45), flat(-120, 0), flat(-120, -45), flat(-118, -64),
    flat(-70, -64), flat(-20, -64), flat(30, -64), flat(80, -64), flat(132, -64),
    flat(132, -20), flat(132, 20), flat(132, 45), flat(140, 77), flat(90, 90),
    flat(40, 90), flat(-10, 90), flat(-60, 90),
    flat(-68, -28), flat(-68, 30), flat(54, 28), flat(50, -34), flat(36, -50),
}


--the closest of them nobody can see right now
local function pickHidden(near, minDist)
    local best, bestD = nil, math.huge
    for _, s in ipairs(HIDE_SPOTS) do
        local d = (s - near).Magnitude
        if d < bestD and d >= (minDist or 0) and not spotSeen(s) then best, bestD = s, d end
    end
    return best
end

--defined further down, it runs off when someone on foot stares at it
local bolt


--only ever goes once nothing can see it, if eyes stay on it, it slips off somewhere dark first
local function vanish()
    if state == "hidden" or not root then return end
    --spooked on the way out, it runs instead of fading where they can see
    if flashed and spookKind == "seen" then
        spookKind = nil
        flashed = false
        bolt(spookPlayer)
        return
    end
    waitUnseen(3)
    if cancelled() then hide() return end
    --it is never removed while anyone can see it, it keeps slipping off until nobody can
    local tries = 0
    while rigSeen() and tries < 6 do
        tries += 1
        local spot = pickHidden(curPos, 12)
        if not spot then
            --nowhere hidden close by: it walks straight off into the fog, away from whoever is watching
            local away = Vector3.new(0, 0, 0)
            for _, e in ipairs(playerEyes()) do away += curPos - flatten(e.eye) end
            away = away.Magnitude > 0.1 and away.Unit or flatten(root.CFrame.LookVector)
            spot = curPos + away * 30
        end
        local keep = noNotice
        noNotice = true
        --still running if it was just spooked
        walkTo(spot, time() - lastBolt < 15 and "run" or "walk")
        noNotice = keep
        if cancelled() then hide() return end
        waitUnseen(6)
        if cancelled() then hide() return end
    end
    --last resort: stand still until nobody is looking
    local waited = 0
    while rigSeen() do
        waited += task.wait(0.3)
        if cancelled() then hide() return end
        --only a camera can still see it: the feed breaks into static and it is gone when the picture comes back
        local camId = watchedVisible()
        local eyesOn = false
        for _, e in ipairs(playerEyes()) do
            if (root.Position - e.eye).Magnitude < SIGHT_RANGE and clearLine(e.eye, root.Position, {e.char}) then eyesOn = true end
        end
        if waited > 20 and camId and not eyesOn then
            ev:FireAllClients("seen", camId)
            task.wait(0.08)
            break
        end
    end
    hide()
end



local function leave(newMode)
    local e = nearestEntry()
    local r = walkTo(ENTRIES[e].out, newMode)
    if r == "cancel" then return end
    vanish()
end

--caught by someone on foot: a twitch, then it runs flat out somewhere they cant see and is gone
bolt = function(plr)
    lurkSpot = nil
    retreatStare = nil
    state = "fleeing"
    setHands()
    liftY = 0
    lastBolt = time()
    local char = plr and plr.Character
    local h = char and char:FindFirstChild("Head")
    local eye = h and h.Position or (curPos + flatten(root.CFrame.LookVector) * 10)
    --the reaction is never the same twice, sometimes it stares back a moment, sometimes it is already gone
    local roll = math.random()
    if roll < 0.45 then
        lookAt(eye, rad(rand(-30, 30)))
        task.wait(rand(0.12, 0.35))
    elseif roll < 0.75 then
        lookAt(eye, rad(rand(25, 45)))
        pose("Waist", CFrame.Angles(rad(-30), 0, rad(rand(-12, 12))), 0)
        task.wait(rand(0.05, 0.15))
    end
    if cancelled() then return end
    --somewhere dark, further from them than it is now, roughly away from them, picked loosely so it is hard to guess
    local fromEye = flatten(eye)
    local away = curPos - fromEye
    away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
    local myDist = (curPos - fromEye).Magnitude
    local scored = {}
    for _, spot in ipairs(HIDE_SPOTS) do
        local d = (spot - curPos).Magnitude
        local fromThem = (spot - fromEye).Magnitude
        if d > 10 and d < 110 and fromThem > myDist and not spotSeen(spot) then
            local dir = (spot - curPos).Unit
            local score = dir:Dot(away) * 20 - d * 0.25 + math.random() * 18
            table.insert(scored, {spot = spot, score = score})
        end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    local pick = scored[math.random(1, math.min(3, #scored))]
    mode = "run"
    if pick then
        local keepN, keepD = noNotice, skipDoors
        noNotice = true
        walkTo(pick.spot, "run")
        noNotice, skipDoors = keepN, keepD
    end
    if cancelled() then return end
    --gone the moment nobody is looking
    vanish()
end


--caught in the flash: snaps its neck to the lens, holds, backs off, then slinks away still staring
local function flee()
    if spookKind == "seen" then
        spookKind = nil
        flashed = false
        bolt(spookPlayer)
        spookPlayer = nil
        flashed = false
        return
    end
    flashed = false
    lurkSpot = nil
    state = "fleeing"
    ev:FireAllClients("scared")
    for _, t in pairs(tracks) do t:Stop(0) end
    local info = flashCamId and camInfo:FindFirstChild("Cam" .. flashCamId)
    local camPos = info and info:GetAttribute("Pos") or (root.Position + root.CFrame.LookVector * 10)
    --a beat after the light hits
    local since = time() - flashTime
    if since < 0.22 then task.wait(0.22 - since) end
    if cancelled() then return end
    --the neck snaps round in a single frame, too far and twisted
    lookAt(camPos, rad(42))
    task.wait(0.05)
    lookAt(camPos, rad(34))
    --holds dead still
    task.wait(1.5)
    if cancelled() then return end
    --slowly backs away from the camera, body turning to face it, eyes never leaving it
    mode = "creep"
    local toCam = flatten(camPos) - curPos
    local away = toCam.Magnitude > 0.1 and -toCam.Unit or -flatten(root.CFrame.LookVector)
    --if a wall is right behind it, it edges off to the side instead
    local from0 = Vector3.new(curPos.X, curY + 2.5, curPos.Z)
    for _, ang in ipairs({0, 45, -45, 90, -90}) do
        local d = CFrame.Angles(0, rad(ang), 0):VectorToWorldSpace(away)
        if not workspace:Raycast(from0, d * 3, groundParams) then
            away = d
            break
        end
    end
    if tracks.walk then
        tracks.walk:Play(0.4)
        tracks.walk:AdjustSpeed(-0.3)
    end
    local t = 0
    local stepAcc = 0
    while t < 2.6 do
        local dt = RunService.Heartbeat:Wait()
        t += dt
        if cancelled() then return end
        turnToward(toCam, dt, 1.5)
        local from = Vector3.new(curPos.X, curY + 2.5, curPos.Z)
        if workspace:Raycast(from, away * 1.8, groundParams) then break end
        local stepLen = 2.1 * dt
        curPos += away * stepLen
        local g = groundAt(curPos.X, curPos.Z, curY)
        curY += (g - curY) * math.min(1, dt * 12)
        stepAcc += stepLen
        if stepAcc > 1.7 * scale then
            stepAcc = 0
            footstep()
        end
        applyPose()
        lookAt(camPos, rad(34))
    end
    if tracks.walk then tracks.walk:Stop(0.3) end
    if cancelled() then return end
    --then it turns and walks off, head twisted back on the lens
    retreatStare = camPos
    leave("walk")
    retreatStare = nil
    flashed = false
end

--closes the last few studs on its own feet so it is really standing over them, never reaching through a wall or a shut door
--returns "reached" "missed" or "cancel"
local function approachForKill(plr, maxTime, speed, moveMode)
    local t0 = time()
    local pts = {}
    local i = 1
    local pathTimer = 99
    mode = moveMode or "run"
    setMoving(true)
    stuckTime = 0
    while time() - t0 < maxTime do
        local dt = RunService.Heartbeat:Wait()
        if cancelled() then setMoving(false) return "cancel" end
        local char = plr.Character
        local proot = char and char:FindFirstChild("HumanoidRootPart")
        if not proot then break end
        local p = flatten(proot.Position)
        local chest = Vector3.new(curPos.X, curY + 3 * scale, curPos.Z)
        if (p - curPos).Magnitude <= 3.3 and solidLine(chest, proot.Position, {char}) then
            setMoving(false)
            return "reached"
        end
        pathTimer += dt
        if pathTimer > 0.3 then
            pathTimer = 0
            pts = computePath(curPos, p) or {p}
            i = math.min(2, #pts)
        end
        if pts[i] and stepToward(pts[i], speed or HUNT_SPEED, dt, true) then i += 1 end
        --wedged on a frame or a chair, a fresh path straight away
        if stuckTime > 0.6 then
            stuckTime = 0
            pathTimer = 99
        end
    end
    setMoving(false)
    return "missed"
end


--last resort for a kill that has to happen: the closest open spot right beside them, never on the far side of a wall
local function adjacentSpot(proot, char)
    local p = flatten(proot.Position)
    local best, bestD = nil, math.huge
    for k = 0, 11 do
        local a = k * math.pi / 6
        local spot = p + Vector3.new(math.sin(a), 0, math.cos(a)) * 3
        local chest = Vector3.new(spot.X, proot.Position.Y + 0.5, spot.Z)
        if solidLine(proot.Position, chest, {char}) then
            local d = (spot - curPos).Magnitude
            if d < bestD then best, bestD = spot, d end
        end
    end
    return best
end



--the caught player is out for the rest of the shift
--the night only ends once nobody is left standing, or straight away when the job itself was failed
local function finishKill(plr)
    task.wait(4.4)
    plr:SetAttribute("Dead", true)
    local char = plr.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    if r then
        r.Anchored = true
        char:PivotTo(CFrame.new(0, -400, 0))
    end
    if jobFailing or #alivePlayers() == 0 then
        workspace:SetAttribute("NightForceFail", true)
        task.wait(0.2)
        workspace:SetAttribute("NightForceFail", false)
        return "killed"
    end
    workspace:SetAttribute("MonsterKill", false)
    return "downed"
end


--returns nil when it could not really get to them, mustKill is a failed shift where it always gets them
local function catchKill(plr, mustKill)
    local reach = approachForKill(plr, mustKill and 6 or 0.9)
    if reach == "cancel" then return "cancel" end
    if reach ~= "reached" and not mustKill then return nil end
    state = "killing"
    lurkSpot = nil
    for _, t in pairs(tracks) do t:Stop(0.1) end
    restPose(0.2)
    local proot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if proot then
        local p = flatten(proot.Position)
        local dir = (curPos - p)
        if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
        --only a failed shift ever closes the last gap without walking it, and only into open space beside them
        if reach ~= "reached" then
            local spot = adjacentSpot(proot, plr.Character)
            curPos = spot or (p + dir.Unit * 3.2)
        end
        local d = p - curPos
        yaw = math.atan2(-d.X, -d.Z)
        sideYaw = 0
        applyPose()
    end
    workspace:SetAttribute("MonsterKill", true)
    ev:FireAllClients("kill", "caught", plr.UserId)
    return finishKill(plr)
end

--it comes all the way in and stands over them before it attacks, never from the doorway
local function officeKill(plr)
    state = "killing"
    lurkSpot = nil
    --gets to the office door first if it is somewhere else in the store
    if not monsterInOffice() and (curPos - OFFICE_FRONT).Magnitude > 4 then
        skipDoors = true
        noNotice = true
        local w = walkTo(OFFICE_FRONT, "run")
        skipDoors = false
        noNotice = false
        if w == "cancel" or cancelled() then return "cancel" end
        state = "killing"
    end
    restPose(0.6)
    pose("Neck", CFrame.Angles(0, 0, rad(30)), 0.6)
    if not officeDoor:GetAttribute("Open") then
        ev:FireAllClients("doorOpening")
        pose("RightShoulder", CFrame.Angles(rad(88), 0, 0), 0.5)
        task.wait(0.6)
        sounds.creak:Play()
        officeDoor:SetAttribute("Slam", false)
        officeDoor:SetAttribute("OpenTime", nil)
        officeDoor:SetAttribute("Open", true)
        task.wait(1.4)
        pose("RightShoulder", CFrame.new(), 0.4)
    end
    if cancelled() then return "cancel" end
    local char = plr and plr.Character
    if not char then return "cancel" end
    --slow creep in along a real path through the doorway until it is standing right over them with nothing in between
    --it never attacks from the doorway, a wedge on the frame just means a new path
    local reach = approachForKill(plr, 10, 3.5, "creep")
    if reach == "cancel" or cancelled() then return "cancel" end
    --stood up and away from the desk, it is a normal catch
    if not isSeated(plr) then return catchKill(plr, true) end
    if reach ~= "reached" then
        --could not get round to them in time, it takes the open spot right beside the chair
        local proot = char:FindFirstChild("HumanoidRootPart")
        local spot = proot and adjacentSpot(proot, char)
        if spot then
            curPos = spot
            applyPose()
        end
    end
    turnTo(OFFICE_EYE, 0.6)
    task.wait(0.6)
    if cancelled() then return "cancel" end
    lookAt(OFFICE_EYE, rad(35))
    workspace:SetAttribute("MonsterKill", true)
    ev:FireAllClients("kill", "office", plr.UserId)
    return finishKill(plr)
end


--chases a player on foot, returns "caught" "flashed" "lost" "toOffice" or "cancel"
local function hunt(plr)
    state = "hunting"
    lurkSpot = nil
    mode = "run"
    for _, t in pairs(tracks) do t:Stop(0.1) end
    --spots them, a second of dead stare, then it runs
    restPose(0.2)
    local proot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if proot then
        turnTo(proot.Position, 0.35)
        lookAt(proot.Position + Vector3.new(0, 2, 0), rad(20))
    end
    sounds.breath:Play()
    ev:FireAllClients("hunt", plr.UserId)
    task.wait(1.2)
    if cancelled() then return "cancel" end
    runPose(0.2)
    setMoving(true)
    local started = time()
    local lostFor = 0
    local pathTimer = 99
    local pts = {}
    local i = 1
    while true do
        local dt = RunService.Heartbeat:Wait()
        if cancelled() then return "cancel" end
        if flashed then setMoving(false) return "flashed" end
        local char = plr.Character
        proot = char and char:FindFirstChild("HumanoidRootPart")
        if not proot or not plr.Parent then setMoving(false) return "lost" end
        if isSeated(plr) then setMoving(false) return "toOffice" end
        local target = flatten(proot.Position)
        local d = (target - curPos).Magnitude
        pathTimer += dt
        local sees = false
        if pathTimer > 0.35 then
            sees = clearLine(head.Position, proot.Position + Vector3.new(0, 2, 0), {char})
            if sees then lostFor = 0 else lostFor += pathTimer end
            pathTimer = 0
            if d < CATCH_RANGE and sees then setMoving(false) return "caught" end
            pts = computePath(curPos, target) or {target}
            i = math.min(2, #pts)
        end
        if time() - started > HUNT_GIVEUP or lostFor > 6 then setMoving(false) return "lost" end
        if d < CATCH_RANGE + 1.5 then
            pts = {target}
            i = 1
        end
        if pts[i] and stepToward(pts[i], HUNT_SPEED, dt, true) then i += 1 end
    end
end

----------------------------------------------------------------- ai state
--every behaviour runs through one director, so only one encounter can ever be going at a time
local aiState = "idle"


local function setState(s)
    aiState = s
    workspace:SetAttribute("MonsterState", s)
end

--the three ways in, each with its own way of being forced
local ACCESS = {
    front = {kind = "double", out = flat(-66, 24), stand = flat(-62.1, 16), face = flat(-50, 16), inside = flat(-55, 16), doorAt = flat(-60, 16), cam = 1, spot = 1},
    side = {kind = "pull", out = flat(19, 26), stand = flat(9.9, 21.1), hinge = flat(15.3, 19.75), leaf = 4.6, openAngle = 95, inside = flat(13, 15), doorAt = flat(13, 19.75), cam = 2, spot = 2},
    window = {kind = "window", out = flat(-36, -49.5), stand = flat(-34.25, -40.9), face = flat(-34.25, -35.5), inside = flat(-34.25, -36.7), cam = 8, spot = 8},
}
local ACCESS_NAMES = {"front", "side", "window"}

--places outside the glass where it can stand and watch
local PEEKS = {
    {stand = flat(-62.6, 4), face = flat(-50, 4), back = flat(-67, 4)},
    {stand = flat(-62.6, -10), face = flat(-50, -10), back = flat(-67, -10)},
    {stand = flat(-28, 22.4), face = flat(-28, 10), back = flat(-28, 28)},
    {stand = flat(-8, 22.4), face = flat(-8, 10), back = flat(-8, 28)},
    --outside the pickup window, staring down the kitchen hallway
    {stand = flat(-37.6, -41.8), face = flat(-37.6, -35.5), back = flat(-37.6, -49.5), window = true},
}

--the dml window panes, so the monster can rattle and force them
local hallway = map:WaitForChild("KitchenHallway")
local paneRight, paper
for _, p in ipairs(hallway:GetChildren()) do
    if p.Name == "WindowGlass" and p.Position.X > -36 then paneRight = p end
    if p.Name == "WindowPaper" then paper = p end
end
local paneClosed = paneRight and paneRight.CFrame
local paperClosed = paper and paper.CFrame
local windowPrompt = hallway:WaitForChild("WindowHandle"):WaitForChild("PromptPoint"):WaitForChild("WindowPrompt")
local windowForced = false


local function setPane(offsetX, jitter)
    if not paneRight then return end
    local j = jitter or 0
    local shake = Vector3.new(rand(-j, j), rand(-j, j) * 0.5, rand(-j, j) * 0.4)
    paneRight.CFrame = paneClosed + Vector3.new(offsetX, 0, offsetX ~= 0 and -0.3 or 0) + shake
    if paper then paper.CFrame = paperClosed + Vector3.new(offsetX, 0, offsetX ~= 0 and -0.3 or 0) + shake end
end



local function restoreWindow()
    if windowForced and paneRight and not windowPrompt.Enabled then
        windowForced = false
        TweenService:Create(paneRight, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {CFrame = paneClosed}):Play()
        if paper then TweenService:Create(paper, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {CFrame = paperClosed}):Play() end
    end
end


local function doorsAt(point)
    local list = {}
    for _, door in ipairs(doors) do
        if door.outside and (door.center - point).Magnitude < 3.5 then table.insert(list, door) end
    end
    return list
end


local function setRattle(list, v)
    for _, door in ipairs(list) do door.inst:SetAttribute("Rattle", v) end
end


local function hitSound(snd, vol, speed)
    snd.Volume = vol
    snd.PlaybackSpeed = speed
    snd.TimePosition = 0
    snd:Play()
end




--hands go on whatever it is about to work on, the client reaches them there with ik
local function contactHands(ap)
    local y = curY + 4.4 * scale / 1.2
    if ap.kind == "double" then
        --push door: both palms low on the push bar, not up on the glass
        y = curY + 3.4 * scale / 1.2
        local fwd = (ap.face - ap.stand).Unit
        local side = Vector3.new(-fwd.Z, 0, fwd.X)
        local c = ap.stand + fwd * 1.2
        setHands(Vector3.new(c.X, y, c.Z) + side * 0.85, Vector3.new(c.X, y + 0.3, c.Z) - side * 0.85)
    elseif ap.kind == "pull" then
        local edge = ap.hinge + Vector3.new(-ap.leaf + 0.45, 0, 0.75)
        setHands(Vector3.new(edge.X, curY + 3.5 * scale / 1.2, edge.Z), Vector3.new(edge.X + 0.5, curY + 5 * scale / 1.2, edge.Z))
    else
        --low on the glass, under the paper sign, so the cameras can see them
        setHands(Vector3.new(-35.05, 5.2, -40.25), Vector3.new(-33.5, 5.05, -40.25))
    end
end


local function contactPose(ap, time)
    if ap.kind == "double" then
        turnTo(ap.face, 0.35)
        --leaning into a push bar at waist height, arms angled down to it
        pose("Waist", CFrame.Angles(rad(-14), 0, 0), time)
        pose("Neck", CFrame.Angles(rad(-4), 0, rad(14)), time)
        pose("RightShoulder", CFrame.Angles(rad(70), 0, rad(-8)), time)
        pose("LeftShoulder", CFrame.Angles(rad(70), 0, rad(8)), time)
        pose("RightElbow", CFrame.Angles(rad(14), 0, 0), time)
        pose("LeftElbow", CFrame.Angles(rad(14), 0, 0), time)
    elseif ap.kind == "pull" then
        turnTo(ap.hinge + Vector3.new(-ap.leaf + 0.35, 0, 0.2), 0.35)
        pose("Waist", CFrame.Angles(rad(-6), 0, 0), time)
        pose("Neck", CFrame.Angles(rad(4), 0, rad(-12)), time)
        pose("RightShoulder", CFrame.Angles(rad(82), 0, rad(-4)), time)
        pose("RightElbow", CFrame.Angles(rad(18), 0, 0), time)
        pose("LeftShoulder", CFrame.Angles(rad(14), 0, rad(6)), time)
    else
        turnTo(ap.face, 0.35)
        pose("Waist", CFrame.Angles(rad(-12), 0, 0), time)
        pose("Neck", CFrame.Angles(rad(-10), 0, rad(18)), time)
        pose("RightShoulder", CFrame.Angles(rad(118), 0, rad(-14)), time)
        pose("LeftShoulder", CFrame.Angles(rad(110), 0, rad(14)), time)
        pose("RightElbow", CFrame.Angles(rad(20), 0, 0), time)
        pose("LeftElbow", CFrame.Angles(rad(20), 0, 0), time)
    end
    contactHands(ap)
end


--one blow, heavier as force goes up
local function strike(ap, force, fwd)
    local keep = curPos
    if ap.kind == "pull" then
        --yanks the handle back
        curPos = keep - fwd * (0.15 + 0.35 * force)
        applyPose()
        hitSound(sounds.knock, 0.35 + 0.9 * force, 0.75 + 0.25 * force)
    elseif ap.kind == "window" then
        --palm comes off the glass and slaps it
        local r = rig:GetAttribute("HandR")
        if r then
            setHands(r - Vector3.new(0, 0, 0.5), rig:GetAttribute("HandL"))
            task.wait(0.06)
            setHands(r, rig:GetAttribute("HandL"))
        end
        curPos = keep + fwd * (0.1 + 0.2 * force)
        applyPose()
        hitSound(sounds.knock, 0.3 + 0.8 * force, 1.05 + 0.2 * force)
    else
        --shoulders into the doors
        curPos = keep + fwd * (0.15 + 0.35 * force)
        applyPose()
        if force < 0.35 then hitSound(sounds.knock, 0.3 + 0.9 * force, 0.8 + 0.3 * force) end
    end
    task.wait(0.07)
    curPos = keep
    applyPose()
end


--the escalating break in, total time t seconds until the way is open
--the flash works the whole time, even while the doors are swinging, returns "done" "flashed" or "cancel"
local function forceEntry(ap, total, allowFlash)
    state = "lurking"
    lurkSpot = ap.spot
    setState("breakin")
    local list = ap.kind ~= "window" and doorsAt(ap.doorAt) or {}
    contactPose(ap, 0.3)
    task.wait(0.3)
    local fwd = flatten(root.CFrame.LookVector)
    local isDoor = ap.kind ~= "window"
    --doors: a shorter struggle so the slow open still fits in the same time
    local breakAt = isDoor and total * 0.6 or total * 0.7
    local t = 0.3
    local nextHit = 0
    if isDoor then
        sounds.rattle.Volume = 0
        sounds.rattle.PlaybackSpeed = 1
        sounds.rattle.TimePosition = 0
        sounds.rattle:Play()
    end
    local function repelled()
        setRattle(list, 0)
        sounds.rattle:Stop()
        if ap.kind == "window" then setPane(0, 0) end
        lurkSpot = nil
        setHands()
        return "flashed"
    end
    while t < breakAt do
        local dt = RunService.Heartbeat:Wait()
        t += dt
        if cancelled() then setRattle(list, 0) sounds.rattle:Stop() setHands() return "cancel" end
        if allowFlash and flashed then return repelled() end
        --force builds from a nudge to full blows
        local force = math.clamp((t - 0.3) / (breakAt - 0.3), 0, 1) ^ 1.4
        if isDoor then
            --a brief, quiet struggle: the door only shifts a little in its frame and the rattle stays low, one steady pitch
            setRattle(list, 0.06 + 0.2 * force)
            sounds.rattle.Volume = 0.08 + 0.17 * force
            if t >= nextHit then
                --leans its weight into the bar, no blows and no knocking
                local keep = curPos
                curPos = keep + fwd * (0.06 + 0.1 * force)
                applyPose()
                task.delay(0.25, function()
                    if state == "lurking" then
                        curPos = keep
                        applyPose()
                    end
                end)
                nextHit = t + rand(1.1, 1.6)
            end
        else
            setRattle(list, 0.12 + 0.88 * force)
            setPane(0, 0.015 + 0.05 * force)
            if t >= nextHit then
                strike(ap, force, fwd)
                nextHit = t + (0.7 - 0.45 * force) * rand(0.85, 1.15)
            end
        end
    end
    --the latch gives
    setRattle(list, 0)
    local openTime = total - breakAt + 0.4
    if isDoor then
        sounds.rattle:Stop()
        --just the click of the latch letting go, the rest of the clip is cut
        sounds.latch.PlaybackSpeed = 1
        sounds.latch.TimePosition = 0
        sounds.latch:Play()
        task.delay(0.55, function() sounds.latch:Stop() end)
        --a small lurch forward as the bar drops, then a beat before it starts to push
        local keep = curPos
        curPos = keep + fwd * 0.2
        applyPose()
        task.wait(0.35)
        if cancelled() then setHands() return "cancel" end
        if allowFlash and flashed then return repelled() end
        curPos = keep
        applyPose()
        openTime = math.max(2.2, openTime - 0.35)
    else
        hitSound(sounds.clank, 1, 0.9)
    end
    if ap.kind == "window" then
        windowForced = true
        task.spawn(function()
            local a0 = time()
            while time() - a0 < 0.6 do
                local k = TweenService:GetValue((time() - a0) / 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                setPane(-3.5 * k, 0)
                RunService.Heartbeat:Wait()
            end
            setPane(-3.5, 0)
        end)
        --climbs through, bent double over the sill, both hands gripping it
        setHands(Vector3.new(-35.1, 4.35, -39.1), Vector3.new(-33.4, 4.35, -39.1))
        pose("Waist", CFrame.Angles(rad(-70), 0, 0), 0.35)
        pose("Neck", CFrame.Angles(rad(55), 0, rad(10)), 0.35)
        local start = curPos
        local a0 = time()
        local climb = math.max(openTime, 1.2)
        while time() - a0 < climb do
            if cancelled() then liftY = 0 setHands() return "cancel" end
            local k = (time() - a0) / climb
            --still half outside, a flash now drops it back out
            if allowFlash and flashed and k < 0.85 then
                liftY = 0
                curPos = start
                applyPose()
                pose("Waist", CFrame.new(), 0.3)
                pose("Neck", CFrame.new(), 0.3)
                return repelled()
            end
            curPos = start:Lerp(ap.inside, k)
            liftY = math.sin(k * math.pi) * 4
            applyPose()
            RunService.Heartbeat:Wait()
        end
        liftY = 0
        curPos = ap.inside
        applyPose()
        setHands()
        restPose(0.4)
        entered = true
    else
        --the door swings open slowly under its weight, with almost no sound
        for _, door in ipairs(list) do
            door.inst:SetAttribute("OpenTime", openTime)
            door.inst:SetAttribute("Open", true)
            opened[door] = true
        end
        local start = curPos
        local a0 = time()
        while time() - a0 < openTime do
            local dt = RunService.Heartbeat:Wait()
            if cancelled() then setHands() return "cancel" end
            if allowFlash and flashed then return repelled() end
            local k = TweenService:GetValue(math.clamp((time() - a0) / openTime, 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            if ap.kind == "double" then
                --leans in after the doors, hands riding the two leaves as they part
                curPos = start + fwd * 1.4 * k
                local side = Vector3.new(-fwd.Z, 0, fwd.X)
                local c = ap.stand + fwd * (1.2 + 1.2 * k)
                --palms stay on the push bars as the two leaves swing away
                local y = curY + 3.4 * scale / 1.2
                setHands(Vector3.new(c.X, y, c.Z) + side * (0.85 + 1.1 * k), Vector3.new(c.X, y + 0.3, c.Z) - side * (0.85 + 1.1 * k))
                pose("RightShoulder", CFrame.Angles(rad(70 - 8 * k), 0, rad(-8 - 34 * k)), 0)
                pose("LeftShoulder", CFrame.Angles(rad(70 - 8 * k), 0, rad(8 + 34 * k)), 0)
            else
                --hand rides the edge of the door as it yanks it open, then lets go
                local ang = rad(ap.openAngle * k)
                local edge = ap.hinge + Vector3.new(-math.cos(ang) * (ap.leaf - 0.45), 0, math.sin(ang) * (ap.leaf - 0.45) + 0.75)
                if k < 0.5 then
                    setHands(Vector3.new(edge.X, curY + 3.5 * scale / 1.2, edge.Z))
                    turnToward(edge - curPos, dt, 8)
                    curPos = start + Vector3.new(-0.35, 0, 1).Unit * 1.1 * (k / 0.5)
                else
                    setHands()
                end
            end
            applyPose()
        end
        setHands()
        task.delay(0.5, function()
            for _, door in ipairs(list) do door.inst:SetAttribute("OpenTime", nil) end
        end)
    end
    lurkSpot = nil
    return "done"
end


--walks from the dark out to a place, never popping in where a camera or the player can see
local function arriveAt(dest, face, newMode)
    setState("approaching")
    local back = (dest - face).Unit
    local from = nil
    for _, k in ipairs({6, 12, 20, 30}) do
        local p = dest + back * k
        if not spotSeen(p) then
            from = p
            break
        end
    end
    --nowhere close behind it is dark, it comes from the nearest dark corner instead
    local waited = 0
    while not from do
        from = pickHidden(dest)
        if from then break end
        waited += task.wait(0.5)
        if cancelled() or waited > 12 then return "cancel" end
    end
    appearAt(from, dest)
    --it is out there for real from this moment, so the cameras can see it and the flash can hit it
    state = "lurking"
    waitUnseen(6)
    if cancelled() then return "cancel" end
    if flashed then return "flashed" end
    skipDoors = true
    local r, p = walkTo(dest, newMode or "walk")
    skipDoors = false
    return r, p
end


--backs off into the dark and is gone
local function retreatOut(to)
    setState("retreating")
    lurkSpot = nil
    retreatStare = nil
    setHands()
    skipDoors = true
    walkTo(to, "walk")
    skipDoors = false
    vanish()
    setState("idle")
end

--the player this encounter is about, picked once and kept until they are gone
local focusPlayer = nil


local function firstPlayer()
    if focusPlayer and focusPlayer.Parent and not focusPlayer:GetAttribute("Dead") then return focusPlayer end
    local list = alivePlayers()
    if #list == 0 then return Players:GetPlayers()[1] end
    focusPlayer = list[math.random(1, #list)]
    return focusPlayer
end




local function playerHead(plr)
    local char = plr and plr.Character
    local h = char and char:FindFirstChild("Head")
    return h and h.Position, char
end

----------------------------------------------------------------- hunting
local hidingPlayer = nil




local function setHunting(on)
    workspace:SetAttribute("Hunting", on)
    local glow = rig and rig:FindFirstChild("HuntGlow")
    if on and rig and not glow then
        --barely there separation from the dark, not a spotlight
        glow = Instance.new("Highlight")
        glow.Name = "HuntGlow"
        glow.FillColor = Color3.fromRGB(150, 160, 185)
        glow.FillTransparency = 0.95
        glow.OutlineColor = Color3.fromRGB(120, 130, 155)
        glow.OutlineTransparency = 0.86
        glow.DepthMode = Enum.HighlightDepthMode.Occluded
        glow.Parent = rig
    elseif not on and glow then
        glow:Destroy()
    end
end

local SEARCH_POINTS = {flat(-40, 5), flat(-20, 8), flat(0, 10), flat(16, 14), flat(20, 0), flat(0, -10), flat(-20, -20), flat(15, -10), flat(30, -5), flat(35, -11), flat(43, 12)}
local WINDOW_Y = 5.2


local function officeClosed()
    return not officeDoor:GetAttribute("Open")
end

--every room a player can shut themselves into, only the office has a window in its door
local HIDES = {
    {name = "office", min = OFFICE_MIN, max = OFFICE_MAX, door = officeDoor, front = OFFICE_FRONT, window = true},
    {name = "walkin", min = Vector3.new(3.5, -5, -27.5), max = Vector3.new(18.5, 20, -14.05), door = map.BackHallway.NorthSide.FreezerDoor, front = flat(11, -9.8)},
    {name = "bathA", min = Vector3.new(10.5, -5, 0.5), max = Vector3.new(16.5, 20, 11.85), door = map.Restrooms.RestroomDoorA, front = flat(13, 14.4)},
    {name = "bathB", min = Vector3.new(17.5, -5, 0.5), max = Vector3.new(23.5, 20, 11.85), door = map.Restrooms.RestroomDoorB, front = flat(20.5, 14.4)},
}


local function inRoom(p, room)
    return p.X > room.min.X and p.X < room.max.X and p.Z > room.min.Z and p.Z < room.max.Z
end


--the hiding room a player is standing in, if any
local function roomOf(plr)
    local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not r then return nil end
    for _, room in ipairs(HIDES) do
        if inRoom(r.Position, room) then return room end
    end
    return nil
end

--only once the door has really swung into its frame
local function roomShut(room)
    return room.door:GetAttribute("Open") ~= true and room.door:GetAttribute("Shut") == true
end


local function monsterInRoom(room)
    if not rig or state == "hidden" then return false end
    return inRoom(curPos, room)
end


--safe in a room: door shut with them inside and the monster outside
local function protected(plr)
    local room = roomOf(plr)
    return room ~= nil and roomShut(room) and not isSeated(plr) and not monsterInRoom(room)
end

--none of these doors can be shut through the monster, they bounce off it and swing back open
for _, room in ipairs(HIDES) do
    if not room.window then
        local door = room.door
        local c = door:IsA("Model") and door:GetBoundingBox().Position or door.Position
        local center = flatten(c)
        door:GetAttributeChangedSignal("Open"):Connect(function()
            if door:GetAttribute("Open") or not rig or state == "hidden" then return end
            task.wait(0.15)
            if door:GetAttribute("Open") or state == "hidden" or (curPos - center).Magnitude > 2.6 then return end
            door:SetAttribute("Slam", false)
            door:SetAttribute("Open", true)
        end)
    end
end


--no window to look through: it stands at the door, listens with its head against it, tries it, then gives up
--returns "opened" if the door comes open on it, "gone" or "cancel"
local function inspectRoom(room, plr)
    setState("investigatingRoom")
    local function opened() return room.door:GetAttribute("Open") == true end
    skipDoors = true
    noNotice = true
    local w = walkTo(room.front, "run")
    if w == "blocked" then w = walkTo(room.front, "run") end
    skipDoors = false
    noNotice = false
    if w == "cancel" then return "cancel" end
    if opened() then return "opened" end
    if (curPos - room.front).Magnitude > 3.5 then return "gone" end
    setMoving(false)
    local entry = nil
    for _, d in ipairs(doors) do
        if d.inst == room.door then entry = d end
    end
    local doorC = entry and entry.center or room.front
    turnTo(doorC, 0.3)
    restPose(0.2)
    --both palms flat on the door, held just off it
    local fwd = (doorC - curPos)
    if fwd.Magnitude > 0.1 then
        fwd = fwd.Unit
        local side = Vector3.new(-fwd.Z, 0, fwd.X)
        local p = doorC - fwd * 0.75
        local y = curY + 4.4 * scale / 1.2
        setHands(Vector3.new(p.X, y, p.Z) + side * 0.85, Vector3.new(p.X, y + 0.3, p.Z) - side * 0.85)
    end
    sounds.breath:Play()
    --head tilted against the door, listening
    lookAt(doorC + Vector3.new(0, 3.5, 0), rad(26), rad(40))
    local function stop(r)
        if entry then setRattle({entry}, 0) end
        setHands()
        return r
    end
    local t0 = time()
    while time() - t0 < 2.8 do
        task.wait(0.1)
        if cancelled() then return stop("cancel") end
        if opened() then return stop("opened") end
        local k = time() - t0
        --two tries at the door, it never gets through a shut one
        if entry then setRattle({entry}, ((k > 0.9 and k < 1.4) or (k > 1.9 and k < 2.3)) and 0.2 or 0) end
    end
    stop()
    restPose(0.3)
    --backs off from the door before it goes
    local back = curPos + (curPos - doorC).Unit * 2.5
    walkTo(back, "walk")
    return "gone"
end


--the office door can't swing shut through the monster, it bounces off and swings back open
local function monsterInDoorSwing()
    if not rig or state == "hidden" then return false end
    return curPos.X > 32.4 and curPos.X < 37.6 and curPos.Z > -19.4 and curPos.Z < -13.6
end
officeDoor:GetAttributeChangedSignal("Open"):Connect(function()
    if officeDoor:GetAttribute("Open") or not monsterInDoorSwing() then return end
    task.wait(0.15)
    if officeDoor:GetAttribute("Open") or not monsterInDoorSwing() then return end
    officeDoor:SetAttribute("Slam", false)
    officeDoor:SetAttribute("OpenTime", nil)
    officeDoor:SetAttribute("Open", true)
end)

--per night and per hunt flags, kept in one table so the script stays under the 200 local limit
--patience: seconds it waits at the door for a job to finish, push: whether it comes in anyway once that runs out
--easy waits the job out, normal gives a few seconds, hard barely waits
--peeked: set once it has looked in through the office window during a hunt
local nightFlags = {patience = 28, push = false, peeked = false}

--a quick peek: runs to the office door, its eyes come up into the little window, a short stare, then it drops and bolts
--it never touches the door or the glass, its hands stay at its sides the whole time
--returns "seen" if they are sat at the cameras instead of hiding, "opened" if the door comes open on it, "gone" or "cancel"
local function inspectOffice(plr)
    nightFlags.peeked = true
    setState("investigatingOffice")
    --the peek only happens through a shut door, the moment it swings open the hiding is over
    local function doorOpened()
        return officeDoor:GetAttribute("Open") == true
    end
    skipDoors = true
    noNotice = true
    --hurries over, no slow creep down the hall
    local near = OFFICE_FRONT + Vector3.new(0, 0, 6)
    if (curPos - OFFICE_FRONT).Magnitude > 10 then
        local w0 = walkTo(near, "run")
        if w0 == "cancel" then skipDoors = false noNotice = false return "cancel" end
    end
    local w = walkTo(OFFICE_FRONT, "run")
    --wedged on the way, one more try from wherever it ended up
    if w == "blocked" then w = walkTo(OFFICE_FRONT, "run") end
    skipDoors = false
    noNotice = false
    if w == "cancel" then return "cancel" end
    if doorOpened() then return "opened" end
    if (curPos - OFFICE_FRONT).Magnitude > 3 then return "gone" end
    setMoving(false)
    mode = "creep"
    local faceLight = nil
    local eyes = {}
    local function restoreEyes()
        for p, old in pairs(eyes) do
            if p.Parent then
                p.Material = old.mat
                p.Color = old.color
            end
        end
        eyes = {}
    end
    local function bail(r)
        liftY = 0
        setHands()
        applyPose()
        if faceLight then faceLight:Destroy() faceLight = nil end
        restoreEyes()
        return r
    end
    local function liftTo(target, time)
        local from = liftY
        local t = 0
        while t < time do
            local dt = RunService.Heartbeat:Wait()
            t += dt
            if cancelled() or doorOpened() then return false end
            local e = TweenService:GetValue(math.clamp(t / time, 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            liftY = from + (target - from) * e
            applyPose()
        end
        return true
    end
    --squares up to the door, it was turned sideways to fit past the frame, and steps in close
    local close = flat(35, -13.2)
    local from = curPos
    local fromSide = sideYaw
    local fromYaw = yaw
    local turn = (0 - fromYaw + math.pi) % (2 * math.pi) - math.pi
    setHands()
    restPose(0.15)
    local t0 = time()
    while time() - t0 < 0.2 do
        RunService.Heartbeat:Wait()
        if cancelled() then return bail("cancel") end
        if doorOpened() then return bail("opened") end
        local k = TweenService:GetValue((time() - t0) / 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        sideYaw = fromSide * (1 - k)
        yaw = fromYaw + turn * k
        curPos = from:Lerp(close, k)
        applyPose()
    end
    sideYaw = 0
    yaw = 0
    curPos = close
    applyPose()
    --how far the body must sink for the eyes to sit level with the glass
    local headUp = head.Position.Y - (curY + feet + liftY)
    local peekLift = (WINDOW_Y + 0.12) - (curY + feet + headUp)
    local lowLift = peekLift - 1.5
    --sinks out of sight below the window, arms hanging
    if not liftTo(lowLift, 0.15) then return bail(cancelled() and "cancel" or "opened") end
    --the whites of the eyes catch the light, pupils stay black
    for _, p in ipairs(head:GetChildren()) do
        if p:IsA("BasePart") and p.Name:sub(1, 3) == "Eye" then
            eyes[p] = {mat = p.Material, color = p.Color}
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(205, 200, 186)
        end
    end
    faceLight = Instance.new("PointLight")
    faceLight.Name = "PeekLight"
    faceLight.Color = Color3.fromRGB(170, 180, 205)
    faceLight.Brightness = 0
    faceLight.Range = 3.2
    faceLight.Shadows = false
    faceLight.Parent = head
    TweenService:Create(faceLight, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Brightness = 1}):Play()
    sounds.breath:Play()
    --raises its head into the glass, just far enough for the eyes
    if not liftTo(peekLift, 0.3) then return bail(cancelled() and "cancel" or "opened") end
    if isSeated(plr) and hidingPlayer ~= plr then return bail("seen") end
    --dead still stare straight at the back corner where people hide
    lookAt(Vector3.new(33.6, 2.7, -24.6), 0)
    local stare = time()
    while time() - stare < 0.9 do
        task.wait(0.1)
        if cancelled() then return bail("cancel") end
        if doorOpened() then return bail("opened") end
        if isSeated(plr) and hidingPlayer ~= plr then return bail("seen") end
    end
    --then drops out of the window and is gone
    if faceLight then faceLight:Destroy() faceLight = nil end
    restoreEyes()
    if not liftTo(lowLift, 0.12) then return bail(cancelled() and "cancel" or "opened") end
    --backs off the door while it straightens up, so its head never shows in the glass again
    runPose(0.1)
    local backFrom = curPos
    local backTo = curPos + Vector3.new(0, 0, 3)
    local b0 = time()
    while time() - b0 < 0.25 do
        RunService.Heartbeat:Wait()
        if cancelled() then return bail("cancel") end
        local k = math.clamp((time() - b0) / 0.25, 0, 1)
        curPos = backFrom:Lerp(backTo, k)
        liftY = lowLift * (1 - k)
        applyPose()
    end
    liftY = 0
    applyPose()
    return "gone"
end


--the hunt, returns "killed" "survived" or "cancel"
--opens with the moment it notices the player, then chases or searches
local function huntSequence(plr, skipScare)
    nightFlags.peeked = false
    setState("hunting")
    state = "hunting"
    flashed = false
    entered = true
    hidingPlayer = nil
    setHands()
    setHunting(true)
    ev:FireAllClients("hunt", plr.UserId)
    --the office stays open so the player can dive in without stopping
    if not inOffice(plr) then officeDoor:SetAttribute("Open", true) end
    local scared = skipScare == true
    --the first time it gets a look at them it stops dead and stares before running
    local function noticeScare(eye, char)
        scared = true
        setMoving(false)
        local proot = char and char:FindFirstChild("HumanoidRootPart")
        if proot then turnTo(proot.Position, 0.25) end
        lookAt(eye, rad(16))
        pose("Waist", CFrame.Angles(rad(-14), 0, 0), 0.15)
        pose("RightShoulder", CFrame.Angles(rad(30), 0, rad(-18)), 0.15)
        pose("LeftShoulder", CFrame.Angles(rad(30), 0, rad(18)), 0.15)
        sounds.breath:Play()
        ev:FireClient(plr, "scare", head.Position)
        task.wait(0.85)
        runPose(0.2)
    end
    --sat at the cameras: the feed jumps to its face instead
    if scared then
        --already had its moment at the glass
    elseif isSeated(plr) then
        local best, bestD = nil, math.huge
        for id, dd in pairs(visible) do if dd < bestD then best, bestD = id, dd end end
        setMoving(false)
        lookAt(OFFICE_EYE, rad(16))
        sounds.breath:Play()
        ev:FireClient(plr, "scareCam", best or 0)
        task.wait(0.9)
        scared = true
    else
        local eye, char = playerHead(plr)
        if eye and clearLine(head.Position, eye, {char}) then noticeScare(eye, char) end
    end
    if cancelled() then return "cancel" end
    runPose(0.2)
    mode = "run"
    local started = time()
    local lastSeenPos = nil
    local lostFor = 0
    local pathTimer = 99
    local pts = {}
    local i = 1
    local searchTarget = nil
    stuckTime = 0
    while true do
        local dt = RunService.Heartbeat:Wait()
        if cancelled() then return "cancel" end
        local char = plr.Character
        local proot = char and char:FindFirstChild("HumanoidRootPart")
        if not proot or not plr.Parent then break end
        --safe only once the office door has really swung shut with them inside and it outside
        --an open door means no hiding, it keeps coming
        local room = roomOf(plr)
        if room and not isSeated(plr) and roomShut(room) and not monsterInRoom(room) then
            if hidingPlayer ~= plr then
                hidingPlayer = plr
                ev:FireClient(plr, "hide", room.name)
            end
            setMoving(false)
            local r
            if room.window then r = inspectOffice(plr) else r = inspectRoom(room, plr) end
            if r == "cancel" then return "cancel" end
            if r == "seen" then return officeKill(plr) end
            if r ~= "opened" then break end
            --the door came open while it was looking, nothing is hiding them now and it comes in
            hidingPlayer = nil
            if isSeated(plr) then return officeKill(plr) end
            mode = "run"
            runPose(0.2)
            setMoving(true)
            pathTimer = 99
        end
        if isSeated(plr) then
            setMoving(false)
            --door left open, it walks straight in to them
            if not officeShut() then return officeKill(plr) end
            --still at the cameras behind a shut door, it comes to the office and looks in
            local r = inspectOffice(plr)
            if r == "cancel" then return "cancel" end
            if r == "seen" or r == "opened" then return officeKill(plr) end
            break
        end
        local target = flatten(proot.Position)
        local d = (target - curPos).Magnitude
        pathTimer += dt
        if pathTimer > 0.35 then
            local eye = proot.Position + Vector3.new(0, 1.5, 0)
            local sees = clearLine(head.Position, eye, {char})
            if sees then
                if not scared then
                    noticeScare(char:FindFirstChild("Head") and char.Head.Position or eye, char)
                    if cancelled() then return "cancel" end
                end
                lostFor = 0
                lastSeenPos = target
                searchTarget = nil
                if aiState ~= "hunting" then setState("hunting") end
            else
                lostFor += pathTimer
                if aiState ~= "searching" and lostFor > 1.5 then setState("searching") end
            end
            pathTimer = 0
            --only a real reach with nothing solid in between, and never into a shut office
            if d < CATCH_RANGE and sees and not protected(plr) and solidLine(head.Position, eye, {char}) then
                setMoving(false)
                local k = catchKill(plr, false)
                if k then return k end
                --could not actually get its hands on them, back to the chase
                pathTimer = 99
                mode = "run"
                setMoving(true)
            end
            local goal
            if lostFor < 1.5 then
                goal = target
            elseif lastSeenPos and (lastSeenPos - curPos).Magnitude > 3 then
                goal = lastSeenPos
            else
                lastSeenPos = nil
                --checks the closest few places it has not looked yet
                if not searchTarget or (searchTarget - curPos).Magnitude < 3 then
                    local best, bestScore = nil, math.huge
                    for _, sp in ipairs(SEARCH_POINTS) do
                        local score = (sp - target).Magnitude * 0.7 + (sp - curPos).Magnitude * 0.3 + rand(0, 10)
                        if (sp - curPos).Magnitude > 4 and score < bestScore then best, bestScore = sp, score end
                    end
                    searchTarget = best
                end
                goal = searchTarget
            end
            --a target behind the shut office door means going to the door, never through the walls
            local hideRoom = roomOf(plr)
            if hideRoom and hideRoom.door:GetAttribute("Open") ~= true then goal = hideRoom.front end
            local newPts = computePath(curPos, goal)
            if newPts then
                pts = newPts
                i = math.min(2, #pts)
            elseif (goal - curPos).Magnitude < 6 then
                pts = {goal}
                i = 1
            end
        end
        if time() - started > 32 then break end
        local speed = lostFor < 1.5 and HUNT_SPEED or WALK_SPEED * 1.25
        mode = lostFor < 1.5 and "run" or "walk"
        if pts[i] and stepToward(pts[i], speed, dt, true) then i += 1 end
        if stuckTime > 1 then
            --wedged on something, take the next waypoint or pick somewhere else to search
            stuckTime = 0
            i += 1
            searchTarget = nil
            pathTimer = 99
        end
    end
    setMoving(false)
    return "survived"
end

----------------------------------------------------------------- encounters
local hunts = 0
--seconds a break in takes to get through, set by the difficulty each night
local breakTime = 5

--true while the player has a job open
local function busy()
    return (workspace:GetAttribute("TasksActive") or 0) > 0
end


--palms flat on whatever glass or door is in front of it, held off the surface so the fingers stay outside
local function handsOnSurface(face)
    local fwd = flatten(face) - curPos
    if fwd.Magnitude < 0.1 then return false end
    fwd = fwd.Unit
    local side = Vector3.new(-fwd.Z, 0, fwd.X)
    local y = curY + 4.4 * scale / 1.2
    local hit = workspace:Raycast(Vector3.new(curPos.X, y, curPos.Z), fwd * 4, groundParams)
    if not hit then return false end
    local p = hit.Position + hit.Normal * 0.75
    setHands(p + side * 0.85, p - side * 0.85 + Vector3.new(0, 0.3, 0))
    return true
end


--the watching spot outside the glass closest to where the player is
local function nearestPeek()
    local plr = firstPlayer()
    local eye = playerHead(plr)
    if not eye then return PEEKS[math.random(1, #PEEKS)] end
    local best, bestD = nil, math.huge
    for _, p in ipairs(PEEKS) do
        if not (p.window and windowPrompt.Enabled) then
            local d = (flatten(eye) - p.stand).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best or PEEKS[1]
end


--stands outside the glass and watches, near whatever the player is doing, sometimes so far back it is barely there
local function encounterPeek(distant)
    local p = math.random() < 0.75 and nearestPeek() or PEEKS[math.random(1, #PEEKS)]
    if p.window and windowPrompt.Enabled then p = PEEKS[1] end
    local stand = distant and (p.stand + (p.back - p.stand).Unit * 5) or p.stand
    local r = arriveAt(stand, p.face, "creep")
    if r == "cancel" then return end
    if r == "flashed" then flee() return end
    setState(distant and "observing" or "stalking")
    turnTo(p.face, 0.6)
    if distant or not handsOnSurface(p.face) then restPose(0.6) else doorPose(0.6) end
    local t = 0
    local dwell = rand(6, 10)
    local nextShift = time() + rand(2, 4)
    while t < dwell do
        local dt = task.wait(0.1)
        t += dt
        if cancelled() then setHands() return end
        if flashed then setHands() flee() return end
        local plr = firstPlayer()
        local eye = playerHead(plr)
        if eye and (eye - root.Position).Magnitude < 60 and clearLine(head.Position, eye, {plr.Character}) then
            lookAt(eye, rad(18))
        end
        --a small shift of weight now and then so it never looks like a statue
        if time() >= nextShift then
            nextShift = time() + rand(2, 4)
            twitch()
        end
    end
    setHands()
    restPose(0.5)
    retreatOut(p.back)
end

--walks slowly across the lot in plain view of the windows, stops to stare at the store, then carries on into the dark
local PROWLS = {
    {from = flat(-90, 50), stop = flat(-86, 6), face = flat(-60, 6), to = flat(-92, -48)},
    {from = flat(-78, 50), stop = flat(-14, 50), face = flat(-14, 15), to = flat(58, 52)},
    {from = flat(56, 52), stop = flat(-4, 50), face = flat(-4, 15), to = flat(-80, 52)},
    {from = flat(44, -62), stop = flat(-36, -58), face = flat(-36, -40), to = flat(-96, -62)},
}


local function encounterProwl()
    local route = PROWLS[math.random(1, #PROWLS)]
    local eye = playerHead(firstPlayer())
    if eye and math.random() < 0.75 then
        local best = math.huge
        for _, r in ipairs(PROWLS) do
            local d = (flatten(eye) - r.stop).Magnitude
            if d < best then best = d route = r end
        end
    end
    setState("stalking")
    local from = route.from
    if spotSeen(from) then
        from = nil
        for _, r in ipairs(PROWLS) do
            if not spotSeen(r.from) then
                route = r
                from = r.from
                break
            end
        end
        from = from or pickHidden(route.stop)
        if not from then return end
    end
    appearAt(from, route.stop)
    state = "lurking"
    noNotice = true
    local r = walkTo(route.stop, "creep")
    if r == "cancel" then noNotice = false return end
    if r == "flashed" or flashed then noNotice = false flee() return end
    --it stops and faces the glass, head tracking whoever is inside
    setState("observing")
    turnTo(route.face, 0.8)
    restPose(0.6)
    local t = 0
    local dwell = rand(3.5, 6)
    while t < dwell do
        t += task.wait(0.1)
        if cancelled() then noNotice = false return end
        if flashed then noNotice = false setHands() flee() return end
        local plr = firstPlayer()
        local e = playerHead(plr)
        if e and (e - root.Position).Magnitude < 80 then lookAt(e, rad(12)) end
    end
    setState("retreating")
    r = walkTo(route.to, "creep")
    noNotice = false
    if r == "cancel" then return end
    if r == "flashed" or flashed then flee() return end
    vanish()
end



--tries the door, then thinks better of it
local function encounterTest()
    local ap = ACCESS[ACCESS_NAMES[math.random(1, 2)]]
    local r = arriveAt(ap.stand, ap.face or ap.doorAt, "creep")
    if r == "cancel" then return end
    if r == "flashed" then flee() return end
    committed = true
    setState("testingEntrance")
    lurkSpot = ap.spot
    local list = doorsAt(ap.doorAt)
    contactPose(ap, 0.4)
    task.wait(0.4)
    local fwd = flatten(root.CFrame.LookVector)
    local t = 0
    local dur = rand(1.6, 2.6)
    while t < dur do
        local dt = task.wait(0.05)
        t += dt
        if cancelled() then setRattle(list, 0) setHands() return end
        if flashed then setRattle(list, 0) setHands() flee() return end
        setRattle(list, 0.18)
        if math.random() < 0.12 then strike(ap, 0.15, fwd) end
    end
    setRattle(list, 0)
    lurkSpot = nil
    setHands()
    task.wait(rand(0.8, 1.6))
    restPose(0.5)
    retreatOut(ap.out)
end

--something outside, never seen, just a door shaking in its frame
local function encounterDisturb()
    setState("roaming")
    local ap = ACCESS[ACCESS_NAMES[math.random(1, 2)]]
    local list = doorsAt(ap.doorAt)
    --the knock comes from the door itself since the monster is nowhere near
    local src = list[1] and (list[1].inst:IsA("Model") and list[1].inst.PrimaryPart or list[1].inst)
    local knock = sounds.knock:Clone()
    knock.Parent = src or root
    for i = 1, math.random(2, 3) do
        setRattle(list, 0.35)
        hitSound(knock, 0.55, 0.8)
        task.wait(0.35)
        setRattle(list, 0)
        task.wait(rand(0.8, 1.6))
        if cancelled() then break end
    end
    setRattle(list, 0)
    knock:Destroy()
    setState("idle")
end


--waiting at the way in while the player is busy with a job: watching, shifting, a light test of the handle
--returns "quiet" once no job has been open for a moment, or "flashed" "cancel" "timeout"
local function waitForQuiet(ap, maxWait)
    setState("stalking")
    lurkSpot = ap.spot
    local list = ap.kind ~= "window" and doorsAt(ap.doorAt) or {}
    local fwd = flatten(root.CFrame.LookVector)
    local t = 0
    local quietFor = 0
    local nextMove = time() + rand(1.5, 3)
    while t < maxWait do
        local dt = task.wait(0.1)
        t += dt
        if cancelled() then setRattle(list, 0) setHands() return "cancel" end
        if flashed then setRattle(list, 0) setHands() return "flashed" end
        if busy() then quietFor = 0 else quietFor += dt end
        --the job is done, give the player a beat to notice before it starts on the door
        if quietFor >= 1.5 then
            setRattle(list, 0)
            return "quiet"
        end
        local plr = firstPlayer()
        local eye = playerHead(plr)
        if eye and (eye - root.Position).Magnitude < 70 and clearLine(head.Position, eye, {plr.Character}) then
            lookAt(eye, rad(14))
        end
        if time() >= nextMove then
            nextMove = time() + rand(1.5, 3.5)
            local pick = math.random()
            if pick < 0.35 then
                --tries the handle once, quietly
                setState("testingEntrance")
                setRattle(list, 0.16)
                strike(ap, 0.08, fwd)
                task.delay(0.4, function() setRattle(list, 0) end)
                setState("stalking")
            else
                twitch()
            end
        end
    end
    setRattle(list, 0)
    return "timeout"
end


local function goHunt(plr, skipScare)
    hunts += 1
    local h = huntSequence(plr, skipScare)
    if h == "killed" or h == "cancel" then return h end
    --done hunting: before it leaves it always goes to the office and peeks in
    if not nightFlags.peeked and officeShut() then
        --door shut: eyes up into the little window
        local r = inspectOffice(plr)
        if r == "cancel" then return "cancel" end
        --sat at the cameras instead of hiding, it comes in for them
        if r == "seen" then return officeKill(plr) end
    elseif not nightFlags.peeked then
        --door open: it stops in the doorway and leans its head in for a look
        setState("investigatingOffice")
        nightFlags.peeked = true
        skipDoors = true
        noNotice = true
        local w = walkTo(OFFICE_FRONT, "walk")
        skipDoors = false
        noNotice = false
        if w == "cancel" or cancelled() then return "cancel" end
        setMoving(false)
        turnTo(flat(35, -20), 0.4)
        pose("Waist", CFrame.Angles(rad(-10), 0, rad(8)), 0.5)
        lookAt(OFFICE_EYE, rad(22))
        task.wait(1.6)
        if cancelled() then return "cancel" end
        --anyone sat at the cameras in there is right in front of it
        if isSeated(plr) then return officeKill(plr) end
        restPose(0.4)
    end
    --it bolts for the nearest way out, the hunt is over the moment it is properly gone
    setState("retreating")
    local leaving = true
    task.spawn(function()
        leave("run")
        leaving = false
    end)
    local t0 = time()
    while leaving and not cancelled() and time() - t0 < 8 do
        task.wait(0.1)
        if state == "hidden" or (curPos - OFFICE_FRONT).Magnitude > 26 then break end
    end
    if cancelled() then return "cancel" end
    setHunting(false)
    hidingPlayer = nil
    ev:FireAllClients("huntEnd", plr.UserId)
    ev:FireAllClients("huntOver")
    while leaving and not cancelled() do task.wait(0.2) end
    restoreWindow()
    setState("idle")
    return "survived"
end



--forces a way in, returns "killed" when the night is over
--if the player is in the middle of a job it only watches from the doorway until they finish
local function encounterBreakIn(apName)
    --the dml window is skipped while a customer is using it
    local choices = {}
    for _, n in ipairs(ACCESS_NAMES) do
        if n ~= "window" or not windowPrompt.Enabled then table.insert(choices, n) end
    end
    local ap = ACCESS[apName or choices[math.random(1, #choices)]]
    local r = arriveAt(ap.stand, ap.face or ap.doorAt, "walk")
    if r == "cancel" then return "cancel" end
    if r == "flashed" then flee() return "fled" end
    committed = true
    if busy() then
        turnTo(ap.face or ap.doorAt, 0.4)
        local q = waitForQuiet(ap, nightFlags.patience)
        if q == "cancel" then return "cancel" end
        if q == "flashed" then flee() return "fled" end
        if q == "timeout" and not nightFlags.push then
            --they were working the whole time, it gives up for now
            setHands()
            restPose(0.4)
            retreatOut(ap.out)
            return "fled"
        end
        --on normal and hard it stops waiting and starts on the door while they are still away
    end
    local f = forceEntry(ap, breakTime, true)
    if f == "cancel" then return "cancel" end
    if f == "flashed" then flee() return "fled" end
    setState("forcedEntry")
    --sneaks in a few steps before it starts hunting, still out in the doorway and still flashable
    if ap.kind ~= "window" then
        local w = walkTo(ap.inside, "creep")
        if w == "cancel" then return "cancel" end
        if w == "flashed" then flee() return "fled" end
    end
    entered = true
    restPose(0.3)
    local plr = firstPlayer()
    if not plr then return "cancel" end
    return goHunt(plr)
end


--catches the player wandering between jobs through the glass and comes straight in
local function encounterDetect()
    local plr = firstPlayer()
    local eye, char = playerHead(plr)
    --busy with a job, seated or in the office: no ambush, it goes about a normal break in instead
    if busy() or not eye or isSeated(plr) or inOffice(plr) then return encounterBreakIn() end
    --an entrance the player could actually see it at
    local options = {}
    for _, n in ipairs(ACCESS_NAMES) do
        local ap = ACCESS[n]
        if n ~= "window" or not windowPrompt.Enabled then
            local spot = Vector3.new(ap.stand.X, 5.5, ap.stand.Z)
            if (spot - eye).Magnitude < 70 and clearLine(eye, spot, {char}) then table.insert(options, n) end
        end
    end
    if #options == 0 then return encounterBreakIn() end
    local ap = ACCESS[options[math.random(1, #options)]]
    local r = arriveAt(ap.stand, ap.face or ap.doorAt, "creep")
    if r == "cancel" then return "cancel" end
    if r == "flashed" then flee() return "fled" end
    committed = true
    setState("observing")
    contactPose(ap, 0.4)
    --waits until it actually has eyes on them
    local t = 0
    while t < 8 do
        local dt = task.wait(0.15)
        t += dt
        if cancelled() then setHands() return "cancel" end
        if flashed then setHands() flee() return "fled" end
        --a job came in while it waited, back to watching instead
        if busy() then
            local q = waitForQuiet(ap, 24)
            if q == "cancel" then return "cancel" end
            if q == "flashed" then flee() return "fled" end
            if q == "timeout" then setHands() restPose(0.4) retreatOut(ap.out) return "fled" end
            contactPose(ap, 0.3)
        end
        eye, char = playerHead(plr)
        if eye and not isSeated(plr) and clearLine(head.Position, eye, {char}) then
            setState("detectionScare")
            lookAt(eye, rad(14))
            ev:FireClient(plr, "scare", head.Position)
            flashImmune = true
            local f = forceEntry(ap, 2, false)
            if f == "cancel" then return "cancel" end
            if ap.kind ~= "window" then walkTo(ap.inside, "run") end
            entered = true
            return goHunt(plr, true)
        end
    end
    --never saw them, so it just tries the door and goes
    setHands()
    restPose(0.4)
    retreatOut(ap.out)
    return "fled"
end


--a task ran out of time: it bursts in through the way closest to the player and hunts
local function encounterForced()
    workspace:SetAttribute("ForceHunt", false)
    flashImmune = true
    local plr = firstPlayer()
    if not plr then return "cancel" end
    local eye = playerHead(plr) or OFFICE_EYE
    local best, bestD = nil, math.huge
    for _, n in ipairs(ACCESS_NAMES) do
        if n ~= "window" or not windowPrompt.Enabled then
            local ap = ACCESS[n]
            local dd = (flatten(eye) - ap.inside).Magnitude
            if dd < bestD then best, bestD = ap, dd end
        end
    end
    committed = true
    local r = arriveAt(best.stand, best.face or best.doorAt, "run")
    if r == "cancel" then return "cancel" end
    local f = forceEntry(best, 1.8, false)
    if f == "cancel" then return "cancel" end
    if best.kind ~= "window" then walkTo(best.inside, "run") end
    entered = true
    return goHunt(plr)
end




--an error inside one encounter must never leave it frozen where it stands, it hides and the night goes on
local function safely(fn, ...)
    --every encounter picks who it is about fresh
    focusPlayer = nil
    committed = false
    spookKind = nil
    local ok, res = pcall(fn, ...)
    if ok then return res end
    warn("monster encounter failed: " .. tostring(res))
    if workspace:GetAttribute("Hunting") then
        setHunting(false)
        hidingPlayer = nil
        ev:FireAllClients("huntOver")
    end
    setHands()
    liftY = 0
    noNotice = false
    return "error"
end

----------------------------------------------------------------- stalking outside
--peeks round corners, crouches behind cars and walls, stares from far off, never hunts from it
local lastStalk = -99
local recentSpots = {}


local function stalkParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local list = baseFilter()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then table.insert(list, plr.Character) end
    end
    params.FilterDescendantsInstances = list
    return params, list
end


--out under the open sky, no roof or awning overhead
local function outdoors(pos)
    local params = stalkParams()
    return workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, 40, 0), params) == nil
end

--a free patch of outdoor ground big enough to stand on, returns its height
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true


local function standable(p)
    if p.X < -124 or p.X > 139 or p.Z < -69 or p.Z > 94 then return nil end
    local params, list = stalkParams()
    local hit = workspace:Raycast(Vector3.new(p.X, 12, p.Z), Vector3.new(0, -14, 0), params)
    if not hit or hit.Position.Y > 1.2 or hit.Normal.Y < 0.9 then return nil end
    local y = hit.Position.Y
    overlap.FilterDescendantsInstances = list
    if #workspace:GetPartBoundsInBox(CFrame.new(p.X, y + 3.2, p.Z), Vector3.new(2.4, 4.4, 2.4), overlap) > 0 then return nil end
    if not outdoors(Vector3.new(p.X, y + 5, p.Z)) then return nil end
    return y
end


--looks round the player for somewhere to watch from
--corner: hidden standing right behind something, a step to the side clears its head
--crouch: hidden down low right behind something, its head clears the top when it rises
--stare: out in the open far off
local function findStalkSpot(kind, eye, char)
    local h = scale / 1.2
    local best, bestScore = nil, -math.huge
    local checked = 0
    local flatEye = flatten(eye)
    local reach = kind == "stare" and 78 or 54
    local step = kind == "stare" and 6 or 3
    for x = -reach, reach, step do
        for z = -reach, reach, step do
            local p = flatEye + Vector3.new(x + rand(-0.8, 0.8), 0, z + rand(-0.8, 0.8))
            local r = (p - flatEye).Magnitude
            local inRange = (kind == "stare" and r >= 50 and r <= 78) or (kind ~= "stare" and r >= 14 and r <= 54)
            --inside the lot fence only
            local inLot = p.X > -124 and p.X < 139 and p.Z > -69 and p.Z < 94
            local fresh = true
            for _, q in ipairs(recentSpots) do
                if (q - p).Magnitude < 14 then fresh = false end
            end
            if inRange and inLot and fresh then
                checked += 1
                if checked % 40 == 0 then task.wait() end
                local y = groundAt(p.X, p.Z, 2)
                local dir = (p - flatEye).Unit
                local side = Vector3.new(-dir.Z, 0, dir.X)
                local function at(q, ht) return Vector3.new(q.X, y + ht * h, q.Z) end
                local function seen(q, ht) return clearLine(eye, at(q, ht), {char}) end
                --the whole width of the body, so a thin pole never counts as cover
                local function seenWide(q, ht)
                    return seen(q, ht) or seen(q + side * 0.9 * h, ht) or seen(q - side * 0.9 * h, ht)
                end
                --the thing it hides behind has to be right in front of it
                local function coverClose(ht)
                    local from = at(p, ht)
                    return workspace:Raycast(from, (eye - from).Unit * 3.2, groundParams) ~= nil
                end
                local ok, out = false, nil
                if kind == "stare" then
                    ok = seen(p, 5.6) and seen(p, 3.2) and seen(p, 1.2)
                elseif kind == "crouch" then
                    ok = coverClose(2.2) and not seenWide(p, 1) and not seenWide(p, 2.4) and not seenWide(p, 3.4) and seen(p, 5.2)
                elseif coverClose(3.4) and not seenWide(p, 1.2) and not seenWide(p, 3.4) and not seenWide(p, 5.6) then
                    --a step to one side clears the head while the body stays mostly behind
                    for _, sgn in ipairs(math.random() < 0.5 and {1, -1} or {-1, 1}) do
                        for _, d in ipairs({1.2, 1.8, 2.4, 3}) do
                            local q = p + side * sgn * d
                            if seen(q, 5.4) and not seenWide(p + side * sgn * d * 0.3, 3) then
                                if standable(q) then
                                    ok = true
                                    out = side * sgn * d
                                end
                                break
                            end
                        end
                        if ok then break end
                    end
                end
                if ok and standable(p) then
                    local score = -math.abs(r - (kind == "stare" and 64 or 30)) + math.random() * 8
                    if score > bestScore then
                        best = {pos = p, out = out, kind = kind}
                        bestScore = score
                    end
                end
            end
        end
    end
    return best
end


--lift eased over time, negative is lower
local function tweenLift(target, time)
    local from = liftY
    local t = 0
    while t < time do
        t += RunService.Heartbeat:Wait()
        liftY = from + (target - from) * math.min(1, t / time)
        applyPose()
    end
end


--palms on the top of whatever it crouches behind, or one hand on the wall at the corner
local function braceHands(spot, eye)
    local h = scale / 1.2
    local dir = flatten(eye) - curPos
    if dir.Magnitude < 0.1 then return end
    dir = dir.Unit
    local side = Vector3.new(-dir.Z, 0, dir.X)
    if spot.kind == "crouch" then
        local hit = workspace:Raycast(Vector3.new(curPos.X, curY + 2.2 * h, curPos.Z), dir * 4, groundParams)
        if hit then
            local top = workspace:Raycast(hit.Position - hit.Normal * 0.4 + Vector3.new(0, 4, 0), Vector3.new(0, -5, 0), groundParams)
            local y = top and top.Position.Y or hit.Position.Y
            --tall cover, the palms go flat on its face instead
            if y > curY + 4.2 * h then y = curY + 3 * h end
            local p = Vector3.new(hit.Position.X, y + 0.25, hit.Position.Z) + hit.Normal * 0.45
            setHands(p + side * 0.8, p - side * 0.8)
        end
    elseif spot.out then
        local hit = workspace:Raycast(Vector3.new(curPos.X, curY + 3.6 * h, curPos.Z), dir * 4, groundParams)
        if hit then
            local p = hit.Position + hit.Normal * 0.5 + spot.out.Unit * 0.5
            if root.CFrame:VectorToObjectSpace(spot.out).X > 0 then setHands(p, nil) else setHands(nil, p) end
        end
    end
end



--tucked in behind the cover
local function stalkHidePose(spot, eye)
    local h = scale / 1.2
    if spot.kind == "crouch" then
        pose("Waist", CFrame.Angles(rad(-55), 0, 0), 0.5)
        pose("Neck", CFrame.Angles(rad(42), 0, 0), 0.5)
        pose("RightShoulder", CFrame.Angles(rad(55), 0, rad(-12)), 0.5)
        pose("LeftShoulder", CFrame.Angles(rad(48), 0, rad(12)), 0.5)
        pose("RightElbow", CFrame.Angles(rad(40), 0, 0), 0.5)
        pose("LeftElbow", CFrame.Angles(rad(40), 0, 0), 0.5)
        tweenLift(-1.7 * h, 0.5)
    else
        pose("Waist", CFrame.Angles(rad(-12), 0, 0), 0.4)
        pose("Neck", CFrame.Angles(rad(6), 0, 0), 0.4)
        pose("RightShoulder", CFrame.Angles(rad(22), 0, rad(-6)), 0.4)
        pose("LeftShoulder", CFrame.Angles(rad(22), 0, rad(6)), 0.4)
        pose("RightElbow", CFrame.Angles(rad(30), 0, 0), 0.4)
        pose("LeftElbow", CFrame.Angles(rad(30), 0, 0), 0.4)
        tweenLift(-0.4 * h, 0.4)
    end
    braceHands(spot, eye)
end



--one look out from behind the cover, returns why it ended: done close spotted flashed cancel gone
local function peekFrom(spot, plr, obvious)
    local h = scale / 1.2
    local base = curPos
    local dwell = obvious and rand(4, 7) or rand(2, 3.6)
    local t = 0
    local lookedFor = 0
    local amt = 0
    local shift = 0
    local shiftGoal = 0
    local nextShift = time() + rand(1.2, 2.4)
    local reason = "done"
    local sgn = 1
    if spot.out and root.CFrame:VectorToObjectSpace(spot.out).X > 0 then sgn = -1 end
    while true do
        local dt = task.wait(0.05)
        t += dt
        if cancelled() then return "cancel" end
        if flashed then return "flashed" end
        local eye, char = playerHead(plr)
        if not eye then return "gone" end
        local want = t < dwell and 1 or 0
        --slow and careful out, quick back in
        amt += (want - amt) * math.min(1, dt * (want > amt and (obvious and 2.2 or 3) or 9))
        --weight shifting from foot to foot while it watches
        if time() >= nextShift then
            nextShift = time() + rand(1.4, 2.8)
            shiftGoal = rand(-1, 1)
        end
        shift += (shiftGoal - shift) * math.min(1, dt * 2)
        if spot.kind == "crouch" then
            --rises until its eyes clear the top
            liftY = (-1.7 + (obvious and 1.25 or 1) * amt) * h
            pose("Waist", CFrame.Angles(rad(-55 + 28 * amt), 0, rad(3 * shift)), 0)
            curPos = base + Vector3.new(0, 0, 0)
        else
            --leans out round the edge, the far hand stays on the wall
            curPos = base + spot.out * amt * (obvious and 1 or 0.75) + spot.out.Unit * 0.12 * shift
            pose("Waist", CFrame.Angles(rad(-10), 0, rad((14 * amt + 3 * shift) * sgn)), 0)
        end
        applyPose()
        if amt > 0.25 then
            lookAt(eye, rad((obvious and 8 or 20) * sgn), rad(85))
        else
            pose("Neck", CFrame.Angles(rad(spot.kind == "crouch" and 42 or 6), 0, 0), 0)
        end
        if want == 0 and amt < 0.05 then return reason end
        if want == 1 then
            --too close, or caught in a long straight look: it pulls back fast
            if (flatten(eye) - curPos).Magnitude < 15 then
                reason = "close"
                dwell = t
            end
            local proot = char and char:FindFirstChild("HumanoidRootPart")
            if proot and head and proot.CFrame.LookVector:Dot((head.Position - eye).Unit) > 0.9 and clearLine(eye, head.Position, {char}) then
                lookedFor += dt
            else
                lookedFor = 0
            end
            if lookedFor > (obvious and 1 or 0.6) then
                reason = "spotted"
                dwell = t
            end
        end
    end
end



--stands dead still out in the fog and watches
local function stareFrom(plr)
    setHands()
    restPose(0.8)
    tweenLift(0, 0.3)
    local t = 0
    local dwell = rand(5, 9)
    local lookedFor = 0
    while t < dwell do
        local dt = task.wait(0.1)
        t += dt
        if cancelled() then return "cancel" end
        if flashed then return "flashed" end
        local eye, char = playerHead(plr)
        if not eye then return "gone" end
        lookAt(eye, rad(6 + math.min(t, 8) * 2), rad(70))
        if (flatten(eye) - curPos).Magnitude < 38 then return "close" end
        local proot = char:FindFirstChild("HumanoidRootPart")
        if proot and head and proot.CFrame.LookVector:Dot((head.Position - eye).Unit) > 0.92 then lookedFor += dt else lookedFor = 0 end
        if lookedFor > 3 then return "spotted" end
    end
    return "done"
end




local function encounterStalk()
    lastStalk = time()
    local plr = firstPlayer()
    local eye, char = playerHead(plr)
    if not eye or isSeated(plr) then return "skip" end
    local outside = outdoors(eye)
    --out in the lot it follows from cover to cover
    local hops = outside and math.random(2, 3) or 1
    local done = 0
    setState("stalking")
    noNotice = true
    local function finish(r)
        noNotice = false
        liftY = 0
        setHands()
        return r
    end
    for hop = 1, hops do
        eye, char = playerHead(plr)
        if not eye then break end
        local roll = math.random()
        local kind = (roll < 0.42 and "corner") or (roll < 0.8 and "crouch") or "stare"
        local spot = findStalkSpot(kind, eye, char)
        if not spot and kind ~= "corner" then spot = findStalkSpot("corner", eye, char) end
        if not spot and kind ~= "crouch" then spot = findStalkSpot("crouch", eye, char) end
        if cancelled() then return finish("cancel") end
        if not spot then break end
        table.insert(recentSpots, 1, spot.pos)
        recentSpots[6] = nil
        --comes in from straight behind the cover if that is dark, otherwise the nearest dark corner
        if state == "hidden" then
            local dir = (spot.pos - flatten(eye)).Unit
            local from = nil
            for _, k in ipairs({12, 20, 30}) do
                local q = spot.pos + dir * k
                if standable(q) and not spotSeen(q) then
                    from = q
                    break
                end
            end
            from = from or pickHidden(spot.pos)
            if not from then break end
            appearAt(from, spot.pos)
            state = "lurking"
        end
        --low and quiet between cover
        liftY = -0.7 * scale / 1.2
        local w = walkTo(spot.pos, "creep")
        if w == "cancel" then return finish("cancel") end
        if w == "flashed" or flashed then finish() flee() return "fled" end
        eye, char = playerHead(plr)
        if not eye then break end
        --squares up to face them, no sideways squeeze left over from the walk
        sideYaw = 0
        turnTo(eye, 0.5)
        local res
        if spot.kind == "stare" then
            setState("observing")
            res = stareFrom(plr)
        else
            setState("stalking")
            stalkHidePose(spot, eye)
            task.wait(rand(0.6, 1.4))
            res = peekFrom(spot, plr, math.random() < 0.35)
        end
        if res == "cancel" then return finish("cancel") end
        if res == "flashed" then finish() flee() return "fled" end
        done += 1
        if res ~= "done" then break end
        eye = playerHead(plr)
        if not eye or not outdoors(eye) then break end
    end
    --slips off the way it came, staying behind the cover, and is gone
    if state ~= "hidden" then
        setHands()
        restPose(0.4)
        --back up to a low sneak, not the deep crouch
        tweenLift(-0.7 * scale / 1.2, 0.3)
        local eyeNow = playerHead(plr) or (curPos + Vector3.new(0, 0, 1))
        local away = flatten(curPos) - flatten(eyeNow)
        local goal = nil
        if away.Magnitude > 0.1 then
            local q = curPos + away.Unit * 18
            if standable(q) then goal = q end
        end
        goal = goal or pickHidden(curPos, 8)
        if goal then
            setState("retreating")
            local w = walkTo(goal, "creep")
            if w == "cancel" then return finish("cancel") end
            if w == "flashed" or flashed then finish() flee() return "fled" end
        end
        liftY = 0
        vanish()
    end
    finish()
    lastStalk = time()
    return done > 0 and "done" or "skip"
end

----------------------------------------------------------------- skittish outside
--out in the open it cant stand being looked at: about 1.5 seconds of someone on foot looking at it and it bolts
--anyone walking right up to it makes it bolt straight away
local SPOOK_TIME = 1.5
local SPOOK_CLOSE = 13
local SPOOK_RANGE = 60
local CALM = {testingEntrance = true, forcedEntry = true, detectionScare = true, hunting = true, searching = true, investigatingOffice = true, killing = true}
local seenFor = 0


local function lookingAtMe()
    if not root or not head then return nil, false end
    local points = {head.Position, root.Position}
    local ut = rig:FindFirstChild("UpperTorso")
    if ut then table.insert(points, ut.Position) end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local h = char and char:FindFirstChild("Head")
        local proot = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if h and proot and hum and hum.Health > 0 and not plr:GetAttribute("Dead") and not isSeated(plr) then
            local d = (flatten(proot.Position) - curPos).Magnitude
            if d < SPOOK_CLOSE and clearLine(h.Position, head.Position, {char}) then return plr, true end
            if d < SPOOK_RANGE then
                --the body faces where the first person camera looks
                local look = proot.CFrame.LookVector
                for _, p in ipairs(points) do
                    if look:Dot((p - h.Position).Unit) > 0.55 and clearLine(h.Position, p, {char}) then return plr, false end
                end
            end
        end
    end
    return nil, false
end
task.spawn(function()
    local last = time()
    while true do
        task.wait(0.1)
        local dt = time() - last
        last = time()
        local ok, err = pcall(function()
            local active = rig and root and activeNight == nightToken and state ~= "hidden" and state ~= "fleeing" and not CALM[aiState]
                and not committed and not flashed and not flashImmune and not jobFailing and not entered and mode ~= "run"
                and not workspace:GetAttribute("Hunting") and root.Position.Y > -100
            if not active or not outdoors(Vector3.new(curPos.X, curY + 3, curPos.Z)) then
                seenFor = 0
                return
            end
            local plr, tooClose = lookingAtMe()
            if plr then seenFor += dt else seenFor = math.max(0, seenFor - dt * 1.5) end
            if plr and (tooClose or seenFor >= SPOOK_TIME) then
                seenFor = 0
                spookKind = "seen"
                spookPlayer = plr
                flashCamId = nil
                flashTime = time()
                flashed = true
            end
        end)
        if not ok then warn("monster skittish: " .. tostring(err)) end
    end
end)

local function runNight(id)
    activeNight = id
    hunts = 0
    local start = workspace:GetAttribute("NightStart") or workspace:GetServerTimeNow()
    local function now() return workspace:GetServerTimeNow() - start end
    local diff = workspace:GetAttribute("Difficulty") or "Normal"
    --night 1 to 5 of the run on this difficulty, 0 on night 1 up to 1 on night 5
    local nightNum = workspace:GetAttribute("NightNumber") or 1
    local k = (math.clamp(nightNum, 1, 5) - 1) / 4
    --easy gives more time to get the flash off, hard less, and every night shaves a bit more off
    breakTime = (diff == "Easy" and 6.5) or (diff == "Hard" and 4) or 5
    breakTime *= 1 - 0.25 * k
    nightFlags.patience = (diff == "Easy" and 28) or (diff == "Hard" and 2) or 8
    nightFlags.push = diff ~= "Easy"
    --every slot is something the player can see or has to deal with, spread over the four minutes
    local plan
    if diff == "Easy" then
        plan = {
            {at = rand(28, 40), kind = "stalk"},
            {at = rand(95, 115), kind = "test"},
            {at = rand(160, 180), kind = "breakin"},
        }
    elseif diff == "Hard" then
        plan = {
            {at = rand(14, 20), kind = "stalk"},
            {at = rand(38, 46), kind = "breakin"},
            {at = rand(70, 78), kind = "test"},
            {at = rand(96, 104), kind = "breakin"},
            {at = rand(126, 134), kind = "stalk"},
            {at = rand(150, 158), kind = "detect"},
            {at = rand(180, 188), kind = "breakin"},
            {at = rand(206, 214), kind = "test"},
        }
    else
        plan = {
            {at = rand(20, 30), kind = "stalk"},
            {at = rand(52, 64), kind = "breakin"},
            {at = rand(95, 108), kind = math.random() < 0.5 and "test" or "stalk"},
            {at = rand(135, 148), kind = "detect"},
            {at = rand(180, 195), kind = math.random() < 0.5 and "stalk" or "test"},
        }
    end
    --the plan was laid out for a four hour night, the shift now runs to 5 am so it is stretched to fit
    for _, slot in ipairs(plan) do slot.at *= 1.25 end
    --later nights bring more visits
    if nightNum >= 3 then table.insert(plan, {at = rand(115, 135), kind = math.random() < 0.5 and "stalk" or "test"}) end
    if nightNum >= 4 and diff ~= "Easy" then table.insert(plan, {at = rand(160, 175), kind = "breakin"}) end
    --the middle visits come in a different order every night and drift off their usual times
    --the first one stays a stalk so the night still opens quietly
    if diff ~= "Easy" then
        local kinds = {}
        for i = 2, #plan do table.insert(kinds, plan[i].kind) end
        for i = #kinds, 2, -1 do
            local j = math.random(1, i)
            kinds[i], kinds[j] = kinds[j], kinds[i]
        end
        for i = 2, #plan do plan[i].kind = kinds[i - 1] end
    end
    for i = 2, #plan do plan[i].at += rand(-10, 10) end
    table.sort(plan, function(a, b) return a.at < b.at end)
    --the finale: one last attempt between 4:20 and 4:50 so the night ends on its hardest moment
    table.insert(plan, {at = rand(258, 272), kind = "finale"})
    workspace:SetAttribute("MonsterEvents", 0)
    workspace:SetAttribute("MonsterFinale", false)
    local lastEnd = -99
    local wasBusy = false
    for n, slot in ipairs(plan) do
        --the finale only needs a short breather after whatever came before it, and still goes as late as 4:50
        local breather = slot.kind == "finale" and 3 or 8
        local startAt = math.max(slot.at, lastEnd + breather)
        --a visit that got pushed back into the last minute is dropped so it never crowds out the finale
        if slot.kind ~= "finale" and startAt > 250 then continue end
        if startAt > 290 then break end
        --a long quiet gap gets a walk across the lot so it is seen out there between the real encounters
        local prowlAt = nil
        if startAt - now() > 26 then prowlAt = now() + rand(4, startAt - now() - 20) end
        local stalkCheck = 0
        while now() < startAt do
            --out in the lot it watches far more often, inside only now and then
            if time() >= stalkCheck and startAt - now() > 14 and not workspace:GetAttribute("ForceHunt") then
                stalkCheck = time() + 3
                local plr = firstPlayer()
                local eye = playerHead(plr)
                local outside = eye and outdoors(eye)
                local gap = outside and 14 or 45
                if eye and not isSeated(plr) and time() - lastStalk > gap and math.random() < (outside and 0.5 or 0.15) then
                    safely(encounterStalk)
                    if cancelled() then return end
                    vanish()
                    setState("idle")
                    lastEnd = now()
                    startAt = math.max(startAt, lastEnd + breather)
                    if prowlAt and prowlAt < now() + 10 then prowlAt = nil end
                end
            end
            --normal and hard: a job going off can pull the next break in forward so it lands while they are away
            local isBusy = busy()
            if isBusy and not wasBusy and slot.kind == "breakin" and diff ~= "Easy" and startAt - now() > 14 then
                if math.random() < (diff == "Hard" and 0.6 or 0.4) then startAt = now() + rand(5, 9) end
            end
            wasBusy = isBusy
            if prowlAt and now() >= prowlAt and not workspace:GetAttribute("ForceHunt") then
                prowlAt = nil
                safely(encounterProwl)
                if cancelled() then return end
                vanish()
                setState("idle")
                lastEnd = now()
                startAt = math.max(startAt, lastEnd + breather)
            end
            if cancelled() then return end
            --a timed out task jumps the queue
            if workspace:GetAttribute("ForceHunt") then
                flashed = false
                workspace:SetAttribute("MonsterEvents", (workspace:GetAttribute("MonsterEvents") or 0) + 1)
                local fr = safely(encounterForced)
                flashImmune = false
                if fr == "killed" or cancelled() then return end
                vanish()
                setState("idle")
                lastEnd = now()
                startAt = math.max(startAt, lastEnd + breather)
            end
            task.wait(0.2)
        end
        if cancelled() then return end
        flashed = false
        flashImmune = false
        local kind = slot.kind
        --if it never got in, the slot before the finale turns into a real attempt
        if n == #plan - 1 and hunts == 0 and diff ~= "Easy" then kind = "breakin" end
        --the finale is a break in with a shorter window, on the last night it does not wait for a job to finish at all
        if kind == "finale" then
            kind = "breakin"
            breakTime *= 0.85
            if nightNum >= 5 then nightFlags.patience = 0 nightFlags.push = true end
            workspace:SetAttribute("MonsterFinale", true)
        end
        workspace:SetAttribute("MonsterEvents", (workspace:GetAttribute("MonsterEvents") or 0) + 1)
        local result
        if kind == "stalk" then
            --half the time it watches from cover outside instead of from the glass
            local r = math.random() < 0.5 and safely(encounterStalk) or "skip"
            if r == "skip" and not cancelled() then safely(encounterPeek, math.random() < 0.25) end
        elseif kind == "test" then safely(encounterTest)
        elseif kind == "breakin" then result = safely(encounterBreakIn)
        elseif kind == "detect" then
            if hunts >= 3 then safely(encounterTest) else result = safely(encounterDetect) end
        end
        if result == "killed" or cancelled() then return end
        vanish()
        setState("idle")
        lastEnd = now()
    end
    --after the last planned slot a timed out task can still bring it in
    while not cancelled() do
        if workspace:GetAttribute("ForceHunt") then
            flashed = false
            local fr = safely(encounterForced)
            flashImmune = false
            if fr == "killed" or cancelled() then return end
            vanish()
            setState("idle")
        end
        task.wait(0.2)
    end
end




--a missed shift: it comes for the player wherever they are, a shut office door does not stop it this time
--somewhere in the store the player and the watched cameras cannot see
local function hallSpawn()
    for _, p in ipairs({OFFICE_FRONT + Vector3.new(0, 0, 14), flat(30, -5), flat(20, 0), flat(16, 14), flat(0, 10), flat(-20, 8)}) do
        if not spotSeen(p) then return p end
    end
    return OFFICE_FRONT + Vector3.new(0, 0, 14)
end


local function failKill(plr)
    local char = plr and plr.Character
    local proot = char and char:FindFirstChild("HumanoidRootPart")
    if not rig or not proot then return "cancel" end
    for _, t in pairs(tracks) do t:Stop(0) end
    setHands()
    liftY = 0
    restPose(0)
    lurkSpot = nil
    retreatStare = nil
    entered = true
    setState("hunting")
    setHunting(true)
    ev:FireAllClients("hunt", plr.UserId)
    if isSeated(plr) then
        --still at the cameras: up the hall and in through the office door
        appearAt(hallSpawn(), OFFICE_FRONT)
        skipDoors = true
        noNotice = true
        walkTo(OFFICE_FRONT, "run")
        skipDoors = false
        noNotice = false
        return officeKill(plr)
    end
    if inOffice(plr) then
        appearAt(hallSpawn(), OFFICE_FRONT)
        skipDoors = true
        noNotice = true
        walkTo(OFFICE_FRONT, "run")
        noNotice = false
        officeDoor:SetAttribute("Slam", false)
        officeDoor:SetAttribute("OpenTime", nil)
        sounds.creak:Play()
        officeDoor:SetAttribute("Open", true)
        task.wait(0.6)
        if cancelled() then skipDoors = false return "cancel" end
        walkTo(flat(35, -18), "run")
        skipDoors = false
        if cancelled() then return "cancel" end
        return catchKill(plr, true)
    end
    --out on the floor: it comes from somewhere they are not looking
    local eye = proot.Position + Vector3.new(0, 1.5, 0)
    local best, bestScore = nil, -math.huge
    for _, sp in ipairs(SEARCH_POINTS) do
        local d = (sp - flatten(proot.Position)).Magnitude
        if d > 12 and d < 40 then
            local seen = spotSeen(sp)
            local score = (seen and 0 or 100) - d
            if score > bestScore then best, bestScore = sp, score end
        end
    end
    best = best or (flatten(proot.Position) + Vector3.new(12, 0, 0))
    appearAt(best, flatten(proot.Position))
    mode = "run"
    runPose(0.1)
    setMoving(true)
    local t0 = time()
    local pts = {}
    local i = 1
    local pathTimer = 99
    while time() - t0 < 9 do
        local dt = RunService.Heartbeat:Wait()
        if cancelled() then return "cancel" end
        proot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not proot then break end
        local target = flatten(proot.Position)
        if (target - curPos).Magnitude < CATCH_RANGE then break end
        pathTimer += dt
        if pathTimer > 0.4 then
            pathTimer = 0
            pts = computePath(curPos, target) or {target}
            i = math.min(2, #pts)
        end
        if pts[i] and stepToward(pts[i], HUNT_SPEED * 1.1, dt, true) then i += 1 end
    end
    setMoving(false)
    return catchKill(plr, true)
end

----------------------------------------------------------------- night hooks



local function chosenMonster()
    return "Monster1"
end

workspace:GetAttributeChangedSignal("NightActive"):Connect(function()
    nightToken += 1
    jobFailing = false
    failThread = nil
    flashed = false
    flashImmune = false
    entered = false
    liftY = 0
    hidingPlayer = nil
    workspace:SetAttribute("Hunting", false)
    workspace:SetAttribute("ForceHunt", false)
    setState("idle")
    if workspace:GetAttribute("NightActive") then
        workspace:SetAttribute("MonsterKill", false)
        spawnRig(chosenMonster())
        task.spawn(runNight, nightToken)
    else
        destroyRig()
        --anyone caught comes back for the next night
        for _, p in ipairs(Players:GetPlayers()) do
            if p:GetAttribute("Dead") then
                p:SetAttribute("Dead", nil)
                p:SetAttribute("Waiting", nil)
                task.spawn(function() p:LoadCharacter() end)
            end
        end
        officeDoor:SetAttribute("Open", false)
        for _, door in ipairs(doors) do
            if door.outside then
                door.inst:SetAttribute("Slam", false)
                door.inst:SetAttribute("Rattle", 0)
                door.inst:SetAttribute("OpenTime", nil)
                door.inst:SetAttribute("Open", false)
            end
        end
        windowForced = true
        restoreWindow()
    end
end)

--the shift was failed: everything else stops and it comes for the player
workspace:GetAttributeChangedSignal("JobFailed"):Connect(function()
    if not workspace:GetAttribute("JobFailed") or not workspace:GetAttribute("NightActive") or jobFailing then return end
    jobFailing = true
    flashed = false
    task.spawn(function()
        failThread = coroutine.running()
        local plr = firstPlayer()
        if not rig then spawnRig(chosenMonster()) end
        local ok, res = pcall(failKill, plr)
        if not ok then warn("fail kill: " .. tostring(res)) end
        if res ~= "killed" then
            --something stopped the kill short, the night still ends
            workspace:SetAttribute("NightForceFail", true)
            task.wait(0.2)
            workspace:SetAttribute("NightForceFail", false)
        end
    end)
end)

local lastFlash = {}
ev.OnServerEvent:Connect(function(player, kind, arg)
    if kind == "pick" then
        if type(arg) == "string" and rigs:FindFirstChild(arg) then player:SetAttribute("Monster", arg) end
    elseif kind == "hiding" then
        --left the cameras during a hunt and tucked into the corner
        if workspace:GetAttribute("Hunting") and inOffice(player) and officeShut() then hidingPlayer = player end
    elseif kind == "flash" then
        if lastFlash[player] and time() - lastFlash[player] < 2.5 then return end
        --every flash costs camera power, an empty battery cannot flash
        local power = player:GetAttribute("CamPower") or 100
        if power < FLASH_COST then return end
        player:SetAttribute("CamPower", power - FLASH_COST)
        lastFlash[player] = time()
        local cam = focus[player]
        local d = cam and visible[cam]
        --vulnerable from the moment it shows up outside until it is fully inside the store
        local vulnerable = rig ~= nil and not entered and not flashImmune and state ~= "hidden" and state ~= "killing" and aiState ~= "hunting" and aiState ~= "searching" and aiState ~= "investigatingOffice"
        if d and d < FLASH_RANGE and vulnerable then
            flashed = true
            flashCamId = cam
            flashTime = time()
            --quiet wrong sounding breath the instant the light hits it
            if sounds.flashHit then sounds.flashHit:Play() end
        end
    end
end)

