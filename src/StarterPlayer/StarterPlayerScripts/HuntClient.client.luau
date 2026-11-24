--player side of a hunt: the scare when it notices you, the faint light, hiding in the office and getting back up
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local ev = RS:WaitForChild("MonsterEvent")

local OFFICE_MIN = Vector3.new(30.5, 0, -27)
local OFFICE_MAX = Vector3.new(40, 0, -15.2)
--far back left corner seen from the doorway, tucked beside the safe against the back wall
local HIDE_SPOT = Vector3.new(33.55, 0, -24.75)
local HIDE_FACE = Vector3.new(34.4, 0, -15)
local WINDOW = Vector3.new(35, 5.2, -15)
--where the office door slab sits when it is fully in its frame
local DOOR_SHUT_POS = Vector3.new(35, 4.5, -15)
local officeDoor = workspace:WaitForChild("ChipotleMap"):WaitForChild("BackRooms"):WaitForChild("OfficeDoorModel")

local function makeSound(id, vol, speed)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = vol
    s.PlaybackSpeed = speed or 1
    s.Parent = script
    return s
end
local sting = makeSound("9113938822", 0.6, 0.8)
local thump = makeSound("9116698408", 0.7, 0.55)
local hiss = makeSound("9113971584", 0.5, 0.9)


local function root()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local map = workspace:WaitForChild("ChipotleMap")
--every room that can be hidden in, the corner they tuck into, which way they face and what they stare at
local ROOMS = {
    office = {min = OFFICE_MIN, max = OFFICE_MAX, door = officeDoor, corner = HIDE_SPOT, face = HIDE_FACE, look = WINDOW, shutPos = DOOR_SHUT_POS},
    walkin = {min = Vector3.new(3.5, 0, -27.5), max = Vector3.new(18.5, 0, -14.05), door = map:WaitForChild("BackHallway"):WaitForChild("NorthSide"):WaitForChild("FreezerDoor"), corner = Vector3.new(15.4, 0, -26.4), face = Vector3.new(11, 0, -14), look = Vector3.new(11, 4.6, -14)},
    bathA = {min = Vector3.new(10.5, 0, 0.5), max = Vector3.new(16.5, 0, 11.85), door = map:WaitForChild("Restrooms"):WaitForChild("RestroomDoorA"), corner = Vector3.new(11.5, 0, 1.5), face = Vector3.new(13, 0, 12), look = Vector3.new(13, 4.4, 12)},
    bathB = {min = Vector3.new(17.5, 0, 0.5), max = Vector3.new(23.5, 0, 11.85), door = map:WaitForChild("Restrooms"):WaitForChild("RestroomDoorB"), corner = Vector3.new(18.4, 0, 1.5), face = Vector3.new(20.5, 0, 12), look = Vector3.new(20.5, 4.4, 12)},
}
--where each door slab sits when it is shut, read before anyone opens one
for _, room in pairs(ROOMS) do
    if not room.shutPos then
        local slab = room.door.PrimaryPart or room.door:FindFirstChildWhichIsA("BasePart", true)
        if slab and room.door:GetAttribute("Open") ~= true then room.shutPos = slab.Position end
    end
end


local function roomAt()
    local r = root()
    if not r then return nil end
    local p = r.Position
    for name, room in pairs(ROOMS) do
        if p.X > room.min.X and p.X < room.max.X and p.Z > room.min.Z and p.Z < room.max.Z then return room, name end
    end
    return nil
end

local function inOffice()
    local _, name = roomAt()
    return name == "office"
end


--the door is really sitting in its frame on this screen and the server agrees the swing has finished
local function roomDoorShut(room)
    if not room then return false end
    local door = room.door
    if door:GetAttribute("Open") == true then return false end
    if door:GetAttribute("Shut") ~= true then return false end
    local slab = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
    if not slab then return false end
    if not room.shutPos then return true end
    return (slab.Position - room.shutPos).Magnitude < 0.25
end


local function officeDoorShut()
    return roomDoorShut(ROOMS.office)
end




local function monsterHead()
    local m = workspace:FindFirstChild("NightMonster")
    return m and m:FindFirstChild("Head")
end

----------------------------------------------------------------- red flash and vignette
local flashGui = Instance.new("ScreenGui")
flashGui.Name = "HuntFlash"
flashGui.IgnoreGuiInset = true
flashGui.ResetOnSpawn = false
flashGui.DisplayOrder = 40
flashGui.Parent = playerGui
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(110, 8, 8)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = flashGui
local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.new(0, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.Parent = flashGui
local vg = Instance.new("UIGradient")
vg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0)})
vg.Parent = vignette

----------------------------------------------------------------- the moment it notices you



--the view is pulled onto its face and pushed in close, then the player has their eyes back
local function scare(target)
    if typeof(target) ~= "Vector3" then return end
    if player:GetAttribute("Seated") or player:GetAttribute("Hiding") then return end
    sting.TimePosition = 0
    sting:Play()
    thump:Play()
    hiss:Play()
    flash.BackgroundTransparency = 0.5
    TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    vignette.BackgroundTransparency = 0.1
    TweenService:Create(vignette, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    --a cold light on its face so it reads even in the dark
    local h = monsterHead()
    local faceLight
    if h then
        faceLight = Instance.new("PointLight")
        faceLight.Color = Color3.fromRGB(200, 210, 235)
        faceLight.Brightness = 1.6
        faceLight.Range = 7
        faceLight.Parent = h
        TweenService:Create(faceLight, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 0}):Play()
        task.delay(1.5, function() faceLight:Destroy() end)
    end
    local fov0 = camera.FieldOfView
    local startRot = camera.CFrame.Rotation
    local t0 = os.clock()
    local turn = 0.32
    local hold = 0.45
    RunService:UnbindFromRenderStep("HuntScare")
    RunService:BindToRenderStep("HuntScare", Enum.RenderPriority.Camera.Value + 1, function()
        local t = os.clock() - t0
        local a = math.clamp(t / turn, 0, 1)
        local e = TweenService:GetValue(a, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local pos = camera.CFrame.Position
        local face = (h and h.Parent) and h.Position or target
        local want = CFrame.lookAt(pos, face)
        camera.CFrame = (CFrame.new(pos) * startRot):Lerp(want, e) * CFrame.Angles(0, 0, math.noise(t * 20, 3) * 0.03 * (1 - a * 0.5))
        --pushes in on the face, then lets go so the player can look away
        camera.FieldOfView = fov0 - 18 * e
        if t >= turn + hold then RunService:UnbindFromRenderStep("HuntScare") end
    end)
    task.delay(turn + hold, function()
        TweenService:Create(camera, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {FieldOfView = fov0}):Play()
    end)
end

----------------------------------------------------------------- faint light while it hunts


local function updateGlow()
    local r = root()
    if not r then return end
    local l = r:FindFirstChild("HuntLight")
    if not l then
        l = Instance.new("PointLight")
        l.Name = "HuntLight"
        l.Brightness = 0.35
        l.Range = 11
        l.Color = Color3.fromRGB(150, 160, 190)
        l.Shadows = false
        l.Parent = r
    end
    l.Enabled = workspace:GetAttribute("Hunting") == true
end
workspace:GetAttributeChangedSignal("Hunting"):Connect(updateGlow)
player.CharacterAdded:Connect(function() task.wait(0.5) updateGlow() end)

----------------------------------------------------------------- hiding
local hiding = false
local hideToken = 0
local poseBlend = 0
local poseTarget = 0

--sat on the floor, knees pulled up, arms around them, head low
local HIDE_POSE = {
    LeftHip = CFrame.Angles(math.rad(98), 0, math.rad(-10)),
    RightHip = CFrame.Angles(math.rad(98), 0, math.rad(10)),
    LeftKnee = CFrame.Angles(math.rad(-125), 0, 0),
    RightKnee = CFrame.Angles(math.rad(-125), 0, 0),
    LeftAnkle = CFrame.Angles(math.rad(25), 0, 0),
    RightAnkle = CFrame.Angles(math.rad(25), 0, 0),
    Waist = CFrame.Angles(math.rad(-22), 0, 0),
    Neck = CFrame.Angles(math.rad(-10), 0, 0),
    LeftShoulder = CFrame.Angles(math.rad(62), 0, math.rad(18)),
    RightShoulder = CFrame.Angles(math.rad(62), 0, math.rad(-18)),
    LeftElbow = CFrame.Angles(math.rad(80), 0, 0),
    RightElbow = CFrame.Angles(math.rad(80), 0, 0),
}


local function joints()
    local c = player.Character
    local list = {}
    if not c then return list end
    for _, j in ipairs(c:GetDescendants()) do
        if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and HIDE_POSE[j.Name] then list[j.Name] = j end
    end
    return list
end


local function floorY(at)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character}
    local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), params)
    return hit and hit.Position.Y or 0.56
end


local function block()
    return Enum.ContextActionResult.Sink
end

local function setHeadVisible(on)
    local c = player.Character
    if not c then return end
    local head = c:FindFirstChild("Head")
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then
            local onHead = d == head or (head and d:IsDescendantOf(head)) or (d.Parent and d.Parent:IsA("Accessory"))
            if onHead then d.LocalTransparencyModifier = on and 0 or 1 end
        end
    end
end




local function release()
    RunService:UnbindFromRenderStep("HuntHide")
    poseTarget = 0
    CAS:UnbindAction("HuntHideBlock")
    for _, j in pairs(joints()) do j.Transform = CFrame.new() end
    local r = root()
    if r then r.Anchored = false end
    setHeadVisible(true)
    camera.CameraType = Enum.CameraType.Custom
    camera.FieldOfView = 70
    player:SetAttribute("Hiding", false)
    player:SetAttribute("InCutscene", false)
    hiding = false
    poseBlend = 0
end

--the seated pose rides on top of whatever the character animator does, every frame before render
RunService:BindToRenderStep("HuntHidePose", Enum.RenderPriority.Character.Value + 10, function(dt)
    if poseBlend <= 0 and poseTarget <= 0 then return end
    poseBlend = math.clamp(poseBlend + (poseTarget > poseBlend and dt / 0.8 or -dt / 1.6), 0, 1)
    local e = TweenService:GetValue(poseBlend, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local t = os.clock()
    for name, j in pairs(joints()) do
        local p = CFrame.new():Lerp(HIDE_POSE[name], e)
        --shivering, small and constant
        if name == "Waist" or name == "Neck" then p = p * CFrame.Angles(math.noise(t * 6, name == "Neck" and 1 or 2) * 0.03 * e, 0, 0) end
        j.Transform = p
    end
end)

local hideRoom = nil


local function hide(room)
    if hiding then return end
    local r = root()
    if not r then return end
    room = room or roomAt()
    if not room then return end
    --no crouching behind a door that is still open or still swinging
    if not roomDoorShut(room) then return end
    hideRoom = room
    local HIDE_SPOT, HIDE_FACE, WINDOW = room.corner, room.face, room.look
    hiding = true
    hideToken += 1
    local mine = hideToken
    player:SetAttribute("Hiding", true)
    player:SetAttribute("InCutscene", true)
    CAS:BindActionAtPriority("HuntHideBlock", block, false, Enum.ContextActionPriority.High.Value + 100,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.LeftShift)
    local fy = floorY(HIDE_SPOT)
    local fromCF = camera.CFrame
    local fromRoot = r.CFrame
    --same corner every time, whichever way they came in
    local seatRoot = CFrame.lookAt(Vector3.new(HIDE_SPOT.X, fy + 1.3, HIDE_SPOT.Z), Vector3.new(HIDE_FACE.X, fy + 1.3, HIDE_FACE.Z))
    local eye = seatRoot.Position + Vector3.new(0, 1.35, 0) + seatRoot.LookVector * 0.35
    r.Anchored = true
    camera.CameraType = Enum.CameraType.Scriptable
    poseTarget = 1
    setHeadVisible(false)
    local t0 = os.clock()
    RunService:UnbindFromRenderStep("HuntHide")
    RunService:BindToRenderStep("HuntHide", Enum.RenderPriority.Camera.Value + 2, function()
        if hideToken ~= mine then return end
        local t = os.clock() - t0
        local a = math.clamp(t / 1.1, 0, 1)
        local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        r.CFrame = fromRoot:Lerp(seatRoot, e)
        --quiet shaky breathing, eyes fixed on the door window
        local breath = math.sin(t * 2.1) * 0.03
        local shake = math.noise(t * 3, 1.7) * 0.01
        local look = CFrame.lookAt(eye, WINDOW)
        local sway = CFrame.new(shake, breath, 0) * CFrame.Angles(math.noise(t * 2, 4.1) * 0.01, math.noise(t * 2, 8.3) * 0.014, math.sin(t * 1.1) * 0.008)
        camera.CFrame = fromCF:Lerp(look, e) * sway
        camera.FieldOfView = 70 - 8 * e
    end)
end


--the monster is already gone when this is called, so a short breath and straight back up
local function recover(instant)
    if not hiding then return end
    hideToken += 1
    local mine = hideToken
    if instant then
        poseTarget = 0
        poseBlend = 0
        release()
        return
    end
    task.wait(0.5)
    if hideToken ~= mine then return end
    RunService:UnbindFromRenderStep("HuntHide")
    local room = hideRoom or ROOMS.office
    local HIDE_SPOT, HIDE_FACE = room.corner, room.face
    local r = root()
    local fromCF = camera.CFrame
    local fy = floorY(HIDE_SPOT)
    local standRoot = CFrame.lookAt(Vector3.new(HIDE_SPOT.X, fy + 3.1, HIDE_SPOT.Z + 0.6), Vector3.new(HIDE_FACE.X, fy + 3.1, HIDE_FACE.Z))
    local fromRoot = r and r.CFrame
    local toCF = CFrame.lookAt(standRoot.Position + Vector3.new(0, 1.5, 0), Vector3.new(HIDE_FACE.X, fy + 4.4, HIDE_FACE.Z))
    poseTarget = 0
    local t0 = os.clock()
    while true do
        local a = math.clamp((os.clock() - t0) / 0.8, 0, 1)
        local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        if r and fromRoot then r.CFrame = fromRoot:Lerp(standRoot, e) end
        camera.CFrame = fromCF:Lerp(toCF, e)
        camera.FieldOfView = 62 + 8 * e
        if a >= 1 or hideToken ~= mine then break end
        RunService.RenderStepped:Wait()
    end
    if hideToken ~= mine then return end
    release()
end

--the door swinging open ends the hiding, they are back on their feet and in plain sight
for _, room in pairs(ROOMS) do
    room.door:GetAttributeChangedSignal("Open"):Connect(function()
        if hiding and hideRoom == room and room.door:GetAttribute("Open") == true then task.spawn(recover, false) end
    end)
end

--got up from the cameras during a hunt, so drop straight into the corner
player:GetAttributeChangedSignal("Seated"):Connect(function()
    if player:GetAttribute("Seated") or not workspace:GetAttribute("Hunting") then return end
    task.wait(0.35)
    if workspace:GetAttribute("Hunting") and inOffice() and not hiding and officeDoorShut() then
        hide()
        ev:FireServer("hiding")
    end
end)

ev.OnClientEvent:Connect(function(kind, a)
    if kind == "scare" then
        scare(a)
    elseif kind == "hide" then
        --the server can be a moment ahead of the door drawn here, give it a beat to land in the frame
        task.spawn(function()
            local t0 = os.clock()
            local room = ROOMS[a] or roomAt()
            while not roomDoorShut(room) and os.clock() - t0 < 0.6 do task.wait() end
            if workspace:GetAttribute("Hunting") and roomAt() == room then hide(room) end
        end)
    elseif kind == "huntOver" then
        task.spawn(recover, false)
    elseif kind == "kill" then
        recover(true)
    end
end)

workspace:GetAttributeChangedSignal("NightActive"):Connect(function()
    if not workspace:GetAttribute("NightActive") then
        RunService:UnbindFromRenderStep("HuntScare")
        recover(true)
        updateGlow()
    end
end)
