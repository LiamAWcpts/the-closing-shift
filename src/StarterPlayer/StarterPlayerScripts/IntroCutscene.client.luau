--opening cinematic: car, phone, knock, escape, broom, lights out, the void
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MovementConfig"))
local BroomPath = require(ReplicatedStorage:WaitForChild("IntroBroomPath"))

local player = Players.LocalPlayer
if player:GetAttribute("IntroDone") then return end

--wait for the character select screen
while not player:GetAttribute("CharacterPicked") do task.wait(0.1) end
--joined in the middle of a night: no intro, they go straight to watching their teammates
task.wait(0.6)
if player:GetAttribute("Waiting") then
    player:SetAttribute("IntroDone", true)
    player:SetAttribute("InCutscene", false)
    return
end

local camera = workspace.CurrentCamera
local map = workspace:WaitForChild("ChipotleMap")
local car = map:WaitForChild("PlayerCar")
local figure = map:WaitForChild("TheFigure")
local broom = map:WaitForChild("Broom")
local hall = map:WaitForChild("EntryHallway")

player:SetAttribute("InCutscene", true)

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local head = character:WaitForChild("Head")

--lock out every kind of input
local CAS = game:GetService("ContextActionService")
local savedJump = humanoid.JumpHeight
local savedJumpPower = humanoid.JumpPower
local playerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
local controls = nil
if playerModule then
    local ok, mod = pcall(require, playerModule)
    if ok then controls = mod:GetControls() end
end
--swallow every movement and jump input while the intro plays
local blockKeys = {
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
    Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3,
}


local function setControls(enabled)
    if enabled then
        CAS:UnbindAction("IntroBlockInput")
        humanoid.JumpHeight = savedJump
        humanoid.JumpPower = savedJumpPower
        if controls then controls:Enable() end
    else
        CAS:BindActionAtPriority("IntroBlockInput", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(blockKeys))
        humanoid.JumpHeight = 0
        humanoid.JumpPower = 0
        if controls then controls:Disable() end
    end
end
setControls(false)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)

---------------------------------------------------------------- settings
local CAR_ORIGIN = Vector3.new(-30, 0.4, 39)
local SEAT_EYE = CAR_ORIGIN + Vector3.new(-1.6, 4.05, 1.35)
local STAND_POS = Vector3.new(-55.5, 0.5, 16)
local DOOR_FOCUS = Vector3.new(-60, 0.5, 16)
local KNOCK_FEET = CFrame.lookAt(Vector3.new(-21.96, 0.4, 39.45), Vector3.new(-40, 0.4, 39.45))
local KNOCK_LEAN = 67
--where its face and palm sit against the passenger window
local GLASS_FACE = Vector3.new(-25.62, 4.95, 39.45)
local GLASS_HAND = Vector3.new(-26.58, 4.8, 38.6)
--knock sound loudness that counts as the hit
local KNOCK_HIT = 120
local EYE_RUN = 5.2

--every intro sound runs through one group so a skip can silence the fast forward
local introGroup = Instance.new("SoundGroup")
introGroup.Name = "IntroSounds"
introGroup.Volume = 1
introGroup.Parent = SoundService

local function sound(id, vol, looped)
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. id
    snd.Volume = vol
    snd.Looped = looped or false
    snd.SoundGroup = introGroup
    snd.Parent = SoundService
    return snd
end
local sKnock = sound("9116200285", 1.4)
local sCarDoor = sound("119661318727626", 0.9)
local sGlassDoor = sound("9114745537", 1)
local sWood = sound("9126254743", 0.6)
local sHeart = sound("9043365842", 0, true)
local sTap = sound("9126270852", 0.3)
local sGasp = sound("9125572450", 0.6)
local sGlassDoorB = sound("9114745537", 0.75)
local sSting = sound("9039981895", 0.9)
--door bang rattle 8 (pro sound effects): a heavy shove on double doors rattling in their frame
local sForce = sound("9114129572", 0.4)
local allSounds = {sKnock, sCarDoor, sGlassDoor, sWood, sHeart, sTap, sGasp, sGlassDoorB, sSting, sForce}
--the door shut and the broom going in each play once per intro no matter how often the code reaches them
local broomInPlayed = false

--the doors banging shut during the fight, the exact same hit at the exact same volume every time
--the clip starts with a quiet opening, 0.86 seconds in is the slam itself
local function playSlam()
    sGlassDoor:Stop()
    sGlassDoor.Volume = 1
    sGlassDoor.PlaybackSpeed = 1
    sGlassDoor.TimePosition = 0.86
    sGlassDoor:Play()
end


--its weight hitting the doors, no squeak and no slam, same every time
local function playForce()
    sForce:Stop()
    sForce.Volume = 0.4
    sForce.PlaybackSpeed = 1
    sForce.TimePosition = 0.05
    sForce:Play()
end


local function playBroomIn()
    if broomInPlayed then return end
    broomInPlayed = true
    sWood.TimePosition = 0
    sWood:Play()
end
local stepSounds = {}
for surface, ids in pairs(Config.FootstepSounds) do
    stepSounds[surface] = {}
    for _, id in ipairs(ids) do
        local snd = Instance.new("Sound") snd.SoundId = id snd.SoundGroup = introGroup snd.Parent = SoundService
        table.insert(stepSounds[surface], snd)
    end
end
local lastStepSound = nil



local function footstep(surface, vol)
    local list = stepSounds[surface]
    local snd = list[math.random(1, #list)]
    --never the same clip twice in a row
    if snd == lastStepSound and #list > 1 then snd = list[(table.find(list, snd) % #list) + 1] end
    lastStepSound = snd
    snd.Volume = vol or 0.5
    snd.PlaybackSpeed = 0.9 + math.random() * 0.07
    snd.TimePosition = 0
    snd:Play()
end

---------------------------------------------------------------- helpers

local function ease(a, style, dir)
    return TweenService:GetValue(a, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut)
end
--runs fn every frame with progress 0 to 1, blocks until done
--pace below 1 speeds a whole scene up, every animation, wait and fade scales with it together
local pace = 1
--skip fast forwards every scene behind a black screen so the store still ends up exactly how the intro leaves it
local skipping = false
local SKIP_PACE = 0.002

local function setPace(v)
    pace = skipping and SKIP_PACE or v
end

local function waitPaced(seconds)
    task.wait(seconds * pace)
end

local function animate(duration, fn)
    duration = duration * pace
    local t0 = os.clock()
    while true do
        local a = math.clamp((os.clock() - t0) / duration, 0, 1)
        fn(a)
        if a >= 1 then break end
        RunService.RenderStepped:Wait()
    end
end


local function tweenNumber(obj, prop, goal, time)
    TweenService:Create(obj, TweenInfo.new(time * pace, Enum.EasingStyle.Sine), {[prop] = goal}):Play()
end


--builds a frame from a direction the length runs along and a hint for its side
local function frameFromDir(pos, dir, hint)
    local y = dir.Unit
    local z = hint:Cross(y).Unit
    local x = y:Cross(z).Unit
    return CFrame.fromMatrix(pos, x, y)
end

---------------------------------------------------------------- camera layers
local camCF = CFrame.lookAt(SEAT_EYE, SEAT_EYE + Vector3.new(0.12, -0.42, -1))
local shake = 0
local tremble = 0
local sway = 1
local bobY = 0
local bobRoll = 0
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 70

---------------------------------------------------------------- overlay ui
local gui = Instance.new("ScreenGui")
gui.Name = "IntroGui" gui.IgnoreGuiInset = true gui.DisplayOrder = 50 gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1) fade.BackgroundColor3 = Color3.new(0, 0, 0) fade.BorderSizePixel = 0 fade.ZIndex = 5 fade.Parent = gui
local barTop = Instance.new("Frame")
barTop.Size = UDim2.fromScale(1, 0.085) barTop.BackgroundColor3 = Color3.new(0, 0, 0) barTop.BorderSizePixel = 0 barTop.Parent = gui
local barBottom = barTop:Clone() barBottom.AnchorPoint = Vector2.new(0, 1) barBottom.Position = UDim2.fromScale(0, 1) barBottom.Parent = gui

---------------------------------------------------------------- skip
--black cover the fast forward runs behind
local skipCover = Instance.new("Frame")
skipCover.Size = UDim2.fromScale(1, 1)
skipCover.BackgroundColor3 = Color3.new(0, 0, 0)
skipCover.BackgroundTransparency = 1
skipCover.BorderSizePixel = 0
skipCover.ZIndex = 20
skipCover.Parent = gui
--the button sits in its own gui so it stays clear of notches and rounded corners
local skipGui = Instance.new("ScreenGui")
skipGui.Name = "IntroSkipGui"
skipGui.ResetOnSpawn = false
skipGui.DisplayOrder = 51
skipGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
skipGui.Parent = player:WaitForChild("PlayerGui")
local skipBtn = Instance.new("TextButton")
skipBtn.AnchorPoint = Vector2.new(1, 1)
skipBtn.Position = UDim2.new(1, -18, 1, -14)
skipBtn.Size = UDim2.fromOffset(118, 44)
skipBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
skipBtn.BackgroundTransparency = 1
skipBtn.AutoButtonColor = false
skipBtn.Font = Enum.Font.GothamMedium
skipBtn.TextSize = 16
skipBtn.TextColor3 = Color3.fromRGB(225, 225, 225)
skipBtn.TextTransparency = 1
skipBtn.Text = "skip  >>"
skipBtn.Parent = skipGui
local skipCorner = Instance.new("UICorner") skipCorner.CornerRadius = UDim.new(1, 0) skipCorner.Parent = skipBtn
local skipStroke = Instance.new("UIStroke") skipStroke.Color = Color3.fromRGB(255, 255, 255) skipStroke.Transparency = 1 skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border skipStroke.Parent = skipBtn
task.delay(2, function()
    if skipping or not skipBtn.Parent then return end
    TweenService:Create(skipBtn, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.45, TextTransparency = 0.1}):Play()
    TweenService:Create(skipStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {Transparency = 0.8}):Play()
end)
skipBtn.Activated:Connect(function()
    if skipping then return end
    skipping = true
    skipBtn.Active = false
    TweenService:Create(skipBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
    TweenService:Create(skipStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
    TweenService:Create(introGroup, TweenInfo.new(0.25), {Volume = 0}):Play()
    TweenService:Create(skipCover, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
    task.delay(0.25, function() pace = SKIP_PACE end)
end)

---------------------------------------------------------------- character hidden and parked at the end spot
root.Anchored = true
--on a shift with others everyone ends up a step apart inside the doors instead of on the same spot
local PARK_OFFSETS = {Vector3.new(0, 0, 0), Vector3.new(0.6, 0, -2.2), Vector3.new(0.6, 0, 2.2), Vector3.new(2.6, 0, 0)}


local function parkCharacter()
    local y = STAND_POS.Y + humanoid.HipHeight + root.Size.Y / 2
    local i = table.find(Players:GetPlayers(), player) or 1
    local off = PARK_OFFSETS[((i - 1) % #PARK_OFFSETS) + 1]
    character:PivotTo(CFrame.lookAt(Vector3.new(STAND_POS.X, y, STAND_POS.Z) + off, Vector3.new(DOOR_FOCUS.X, y, DOOR_FOCUS.Z) + off))
end
parkCharacter()
local hideCharacter = true

---------------------------------------------------------------- world state at the start
--doors open
local doors = {}
for _, key in ipairs({"A", "B"}) do
    local slab = hall:WaitForChild("EntryDoor" .. key)
    local parts = {}
    --with streaming on, wait until every piece of the door has arrived
    local need = slab:GetAttribute("GroupCount") or 0
    local t0 = os.clock()
    repeat
        parts = {}
        for _, p in ipairs(hall:GetChildren()) do
            if p:GetAttribute("DoorGroup") == key then table.insert(parts, {part = p, off = p:GetAttribute("DoorOffset")}) end
        end
        if #parts < need then task.wait(0.1) end
    until #parts >= need or os.clock() - t0 > 10
    doors[key] = {slab = slab, parts = parts, hinge = slab:GetAttribute("Hinge"), closed = slab:GetAttribute("ClosedAngle")}
end


local function setDoor(key, angle)
    local d = doors[key]
    local cf = CFrame.new(d.hinge) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(1.5, 0, 0)
    d.slab.CFrame = cf
    for _, item in ipairs(d.parts) do item.part.CFrame = cf * item.off end
end
setDoor("A", 0) setDoor("B", 0)

--broom leaning on the wall by the door
broom:PivotTo(BroomPath.lean)

--the figure in every scene is the monster the player picked, the old stand-in body stays out of sight
local restFeet = figure:GetAttribute("RestFeet")
for _, p in ipairs(figure:GetDescendants()) do
    if p:IsA("BasePart") then p.CFrame = CFrame.new(0, -200, 0) end
end
local SCALES = {Monster1 = 1.2}
local fig, figRoot, feetToRoot = nil, nil, 3
local figJ, figBase = {}, {}
do
    local rigs = ReplicatedStorage:WaitForChild("MonsterRigs")
    local src = rigs:WaitForChild("Monster1")
    fig = src:Clone()
    fig.Name = "IntroMonster"
    --same joint swap the night monster gets, so it poses the same way
    for _, c in ipairs(fig:GetDescendants()) do
        if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
            local m = Instance.new("Motor6D")
            m.Name = c.Name
            m.Part0 = c.Attachment0.Parent
            m.Part1 = c.Attachment1.Parent
            m.C0 = c.Attachment0.CFrame
            m.C1 = c.Attachment1.CFrame
            m.Parent = c.Attachment1.Parent
            c:Destroy()
        elseif c:IsA("BallSocketConstraint") or c:IsA("LuaSourceContainer") then
            c:Destroy()
        end
    end
    fig:ScaleTo(fig:GetScale() * (SCALES[src.Name] or 1.2))
    fig:PivotTo(CFrame.new())
    local cf, size = fig:GetBoundingBox()
    feetToRoot = -(cf.Y - size.Y / 2)
    figRoot = fig:FindFirstChild("HumanoidRootPart")
    for _, d in ipairs(fig:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Anchored = false
        elseif d:IsA("Motor6D") then
            figJ[d.Name] = d
            figBase[d.Name] = d.C0
        end
    end
    figRoot.Anchored = true
    local hum = fig:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.EvaluateStateMachine = false
        hum.RequiresNeck = false
        hum.BreakJointsOnDeath = false
    end
    figRoot.CFrame = CFrame.new(0, -200, 0)
    fig.Parent = workspace
end


local function setJ(name, cf)
    local j = figJ[name]
    if j then j.C0 = figBase[name] * cf end
end



local function fkJ(parent, j)
    return parent * j.C0 * j.C1:Inverse()
end


local function figBody(rootCF)
    local lt = fkJ(rootCF, figJ.Root)
    local ut = fkJ(lt, figJ.Waist)
    local hd = fkJ(ut, figJ.Neck)
    return lt, ut, hd
end


local function rotBetween(u, v)
    local axis = u:Cross(v)
    local d = math.clamp(u:Dot(v), -1, 1)
    if axis.Magnitude < 1e-6 then return CFrame.new() end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

--turns a joint so the bone of its child part points at goal, the joint itself stays put
local function aimJoint(parentCF, name, bone, goal)
    local j = figJ[name]
    local base = figBase[name]
    local rest = parentCF * base * j.C1:Inverse()
    local restDir = rest:VectorToWorldSpace(bone).Unit
    local want = goal - (parentCF * base).Position
    if want.Magnitude < 1e-4 then return rest end
    local rw = rotBetween(restDir, want.Unit)
    local q = parentCF.Rotation:Inverse() * rw * parentCF.Rotation * base.Rotation
    j.C0 = CFrame.new(base.Position) * q
    return parentCF * j.C0 * j.C1:Inverse()
end


local function poseFigure(feet, lean, armR, armL, headRoll)
    if feet.Position.Y < -100 then
        figRoot.CFrame = CFrame.new(0, -200, 0)
        return
    end
    figRoot.CFrame = feet * CFrame.new(0, feetToRoot, 0)
    setJ("Waist", CFrame.Angles(math.rad(-lean), 0, 0))
    setJ("Neck", CFrame.Angles(0, 0, math.rad(headRoll or 0)))
    setJ("RightShoulder", CFrame.Angles(math.rad(armR), 0, 0))
    setJ("LeftShoulder", CFrame.Angles(math.rad(armL), 0, 0))
    setJ("RightElbow", CFrame.new())
    setJ("LeftElbow", CFrame.new())
end
poseFigure(CFrame.new(0, -200, 0), 0, 0, 0)

---------------------------------------------------------------- outside lights, run by the intro only
local exteriorRoots = {map:FindFirstChild("Lot"), map:FindFirstChild("ParkingLot"), map:FindFirstChild("Exterior"), map:FindFirstChild("Facade"), map:FindFirstChild("GroundFog"), car, figure}
local extUnits = {}
local unitByKey = {}
for _, f in ipairs(exteriorRoots) do
    if f then
        for _, p in ipairs(f:GetDescendants()) do
            if p:IsA("BasePart") then
                local lights = {}
                local guis = {}
                for _, c in ipairs(p:GetChildren()) do
                    if c:IsA("Light") and c.Enabled then
                        table.insert(lights, {obj = c, base = c.Brightness})
                    elseif c:IsA("BillboardGui") or (c:IsA("SurfaceGui") and c.LightInfluence < 1) then
                        table.insert(guis, c)
                    end
                end
                local neon = p.Material == Enum.Material.Neon
                if #lights > 0 or #guis > 0 or neon then
                    --parts sharing a flicker group act as one fixture
                    local key = p:GetAttribute("FlickerGroup") or p
                    local u = unitByKey[key]
                    if not u then
                        u = {lights = {}, guis = {}, neons = {}, flicker = false}
                        unitByKey[key] = u
                        table.insert(extUnits, u)
                    end
                    for _, l in ipairs(lights) do table.insert(u.lights, l) end
                    for _, g in ipairs(guis) do table.insert(u.guis, g) end
                    if neon then table.insert(u.neons, p) end
                    if p:GetAttribute("Flicker") then u.flicker = true end
                end
            end
        end
    end
end



local function setUnit(u, level)
    for _, l in ipairs(u.lights) do
        l.obj.Brightness = l.base * level
        l.obj.Enabled = level > 0
    end
    local on = level > 0.5
    for _, g in ipairs(u.guis) do g.Enabled = on end
    for _, n in ipairs(u.neons) do n.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic end
end
--normal stutters while the outside still exists
local exteriorMode = "ambient"
for _, u in ipairs(extUnits) do
    if u.flicker then
        task.spawn(function()
            task.wait(math.random() * 5)
            while exteriorMode == "ambient" do
                task.wait(math.random(2, 7) + math.random())
                for i = 1, math.random(2, 6) do
                    if exteriorMode ~= "ambient" then break end
                    setUnit(u, math.random(0, 30) / 100)
                    task.wait(0.03 + math.random() * 0.1)
                    if exteriorMode ~= "ambient" then break end
                    setUnit(u, 1)
                    task.wait(0.03 + math.random() * 0.12)
                end
            end
        end)
    end
end

--every outside light fails on its own rhythm, getting worse, then all die within a fifth of a second
local function exteriorFailure(duration)
    exteriorMode = "failing"
    local t0 = os.clock()
    local finished = 0
    for _, u in ipairs(extUnits) do
        task.spawn(function()
            local cut = duration + math.random() * 0.2
            while os.clock() - t0 < cut do
                local p = math.clamp((os.clock() - t0) / duration, 0, 1)
                local offChance = 0.08 + 0.62 * p ^ 1.5
                if math.random() < offChance then
                    setUnit(u, math.random(0, 12) / 100)
                else
                    setUnit(u, 0.55 + math.random() * 0.45)
                end
                task.wait((0.2 - 0.16 * p) * (0.4 + math.random()))
            end
            setUnit(u, 0)
            finished += 1
        end)
    end
    while finished < #extUnits do RunService.Heartbeat:Wait() end
    exteriorMode = "off"
end


--the outside goes dark but stays there: the lot can still be seen through the glass and walked
--a few lot lights limp back on at a fraction of their strength so anything moving out there still shows
local function blackout()
    exteriorMode = "off"
    if figure then figure.Parent = nil end
    for _, u in ipairs(extUnits) do setUnit(u, 0.55) end
    task.spawn(function()
        --now and then one of the weak lights stutters
        while true do
            task.wait(math.random(3, 8) + math.random())
            local u = extUnits[math.random(1, math.max(1, #extUnits))]
            if u and u.flicker then
                for i = 1, math.random(2, 4) do
                    setUnit(u, 0.05)
                    task.wait(0.05 + math.random() * 0.08)
                    setUnit(u, 0.55)
                    task.wait(0.05 + math.random() * 0.1)
                end
            end
        end
    end)
    --still air inside the store: a faint cold haze that gives depth, dark enough that the far lot melts into black
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        atmo.Density = 0.38
        atmo.Offset = 0.1
        atmo.Haze = 0.7
        atmo.Glare = 0
        atmo.Color = Color3.fromRGB(9, 10, 13)
        atmo.Decay = Color3.fromRGB(5, 5, 7)
    end
end

--driver door pieces relative to the hinge
local doorModel = car:WaitForChild("DriverDoor")
local carHinge = doorModel:GetAttribute("Hinge")
local carDoorParts = {}
for _, p in ipairs(doorModel:GetChildren()) do
    table.insert(carDoorParts, {part = p, off = carHinge:ToObjectSpace(p.CFrame)})
end


local function setCarDoor(angle)
    local cf = carHinge * CFrame.Angles(0, math.rad(angle), 0)
    for _, item in ipairs(carDoorParts) do item.part.CFrame = cf * item.off end
end

---------------------------------------------------------------- first person hands and phone
local vm = Instance.new("Folder") vm.Name = "IntroViewmodel" vm.Parent = camera
local skin = Color3.fromRGB(234, 184, 146)
local bodyColors = character:FindFirstChildOfClass("BodyColors")
if bodyColors then skin = bodyColors.RightArmColor3 end
skin = skin:Lerp(Color3.new(0, 0, 0), 0.55)
local sleeveCol = Color3.fromRGB(32, 32, 36)
local vmParts = {}


local function vmPart(name, size, off, col, mat)
    local p = Instance.new("Part")
    p.Name = name p.Size = size p.Color = col p.Material = mat or Enum.Material.SmoothPlastic
    p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
    p.Parent = vm
    table.insert(vmParts, {part = p, off = off})
    return p
end
vmPart("PhoneBody", Vector3.new(0.36, 0.74, 0.05), CFrame.new(), Color3.fromRGB(14, 14, 16))
local screenPart = vmPart("PhoneScreen", Vector3.new(0.33, 0.7, 0.01), CFrame.new(0, 0, 0.027), Color3.new(0, 0, 0))
--the characters own forearms and hands shrunk down so they hold the phone
local armModel = Instance.new("Model") armModel.Name = "IntroArms" armModel.Parent = vm
local armHum = Instance.new("Humanoid") armHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None armHum.Parent = armModel
for _, c in ipairs(character:GetChildren()) do
    if c:IsA("Shirt") then c:Clone().Parent = armModel end
end
local ARM_SCALE = 0.3




local function addArmPart(src, off)
    local p = src:Clone()
    for _, k in ipairs(p:GetChildren()) do
        if not k:IsA("SurfaceAppearance") and not k:IsA("SpecialMesh") then k:Destroy() end
    end
    p.Size = src.Size * ARM_SCALE
    --thin limbs like the plank character still need to read as arms on the phone
    p.Size = Vector3.new(math.max(p.Size.X, 0.2), p.Size.Y, math.max(p.Size.Z, 0.2))
    p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false p.Massless = true
    p.LocalTransparencyModifier = 0 p.Transparency = 0
    --dimmed so the arms dont glow in the dark car
    p.Color = src.Color:Lerp(Color3.new(0, 0, 0), 0.5)
    p.Parent = armModel
    table.insert(vmParts, {part = p, off = off})
end


--hand sits on the grip point and the forearm runs back toward the elbow
local function arm(side, grip, elbow)
    local hand = character:FindFirstChild(side .. "Hand")
    local lower = character:FindFirstChild(side .. "LowerArm")
    if not hand or not lower then return end
    local hy = hand.Size.Y * ARM_SCALE
    local ly = lower.Size.Y * ARM_SCALE
    local dir = (grip - elbow).Unit
    addArmPart(hand, frameFromDir(grip, dir, Vector3.new(0, 0, 1)))
    addArmPart(lower, frameFromDir(grip - dir * (hy / 2 + ly / 2), dir, Vector3.new(0, 0, 1)))
end
arm("Right", Vector3.new(0.21, -0.2, -0.2), Vector3.new(0.62, -1.0, 0.45))
arm("Left", Vector3.new(-0.21, -0.24, -0.2), Vector3.new(-0.62, -1.05, 0.45))
local phoneLight = Instance.new("PointLight") phoneLight.Range = 3 phoneLight.Brightness = 0.22 phoneLight.Shadows = false phoneLight.Parent = screenPart

local phoneOffset = CFrame.new(0.06, -0.3, -1.15) * CFrame.Angles(math.rad(10), math.rad(-4), math.rad(2))
local phoneVisible = true

--phone screen with a vertical feed of videos
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Back sg.PixelsPerStud = 900 sg.LightInfluence = 0 sg.Brightness = 0.85 sg.ClipsDescendants = true sg.Parent = screenPart
local clip = Instance.new("Frame") clip.Size = UDim2.fromScale(1, 1) clip.BackgroundColor3 = Color3.new(0, 0, 0) clip.BorderSizePixel = 0 clip.ClipsDescendants = true clip.Parent = sg
local videoColors = {
    Color3.fromRGB(226, 110, 84), Color3.fromRGB(52, 140, 152), Color3.fromRGB(118, 76, 170),
    Color3.fromRGB(214, 172, 62), Color3.fromRGB(64, 86, 140), Color3.fromRGB(74, 156, 96),
    Color3.fromRGB(180, 90, 120),
}
local count = #videoColors
local feed = Instance.new("Frame") feed.Size = UDim2.fromScale(1, count) feed.BackgroundTransparency = 1 feed.Parent = clip
local gradients = {}


local function round(f, r)
    local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(1, 0) c.Parent = f
end


local function box(parent, x, y, w, h, col, tr, r, rot)
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y) f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = col f.BackgroundTransparency = tr or 0 f.BorderSizePixel = 0 f.Rotation = rot or 0
    f.Parent = parent
    if r then round(f, r) end
    return f
end


--like, comment and share buttons plus caption bars over every clip
local function overlay(v)
    local col = Instance.new("Frame") col.AnchorPoint = Vector2.new(1, 0) col.Position = UDim2.new(1, -10, 0.42, 0) col.Size = UDim2.fromOffset(40, 220) col.BackgroundTransparency = 1 col.Parent = v
    local pfp = box(col, 2, 0, 36, 36, Color3.fromRGB(230, 230, 230), 0, UDim.new(1, 0))
    for i = 0, 2 do box(col, 5, 58 + i * 52, 30, 30, Color3.new(1, 1, 1), 0.15, UDim.new(1, 0)) end
    box(v, 14, 560, 150, 12, Color3.new(1, 1, 1), 0.2, UDim.new(0, 6))
    box(v, 14, 580, 200, 9, Color3.new(1, 1, 1), 0.45, UDim.new(0, 5))
    box(v, 14, 596, 120, 9, Color3.new(1, 1, 1), 0.45, UDim.new(0, 5))
    local track = box(v, 0, 623, 297, 3, Color3.new(1, 1, 1), 0.65)
    local prog = box(track, 0, 0, 0, 3, Color3.new(1, 1, 1), 0.1)
    prog.Name = "Progress"
    local top = Instance.new("TextLabel")
    top.Text = "Following    For You" top.Font = Enum.Font.GothamBold top.TextSize = 13 top.TextColor3 = Color3.new(1, 1, 1)
    top.BackgroundTransparency = 1 top.Position = UDim2.fromOffset(0, 22) top.Size = UDim2.new(1, 0, 0, 18) top.Parent = v
end
--short roblox clips from the creator store, cropped to fill the tall screen
--a fresh random handful from the pool every run, never the same clip twice
local VIDEO_POOL = {
    "5608321996", "5670806798", "5670802294", "5670824523", "5608368298", "5608292559",
    "5670794788", "5608290551", "5670826209", "5608333583", "5608392925", "5608386285", "5608389672",
    "5608349310", "5608285055", "5608398904", "5608268502", "5608339667", "5608413286", "5608410985",
}
--the pony clip is one more entry in the shuffle, it can land in any slot except the last
local PONY = #VIDEO_POOL + 1
local order = {}
for i = 1, PONY do order[i] = i end
for i = #order, 2, -1 do
    local j = math.random(1, i)
    order[i], order[j] = order[j], order[i]
end
if order[count] == PONY then
    local j = math.random(1, count - 1)
    order[count], order[j] = order[j], order[count]
end
local ponySlot = nil
local videoIds = {}
--which pool slot each shown clip came from, so it gets its matching sound
local videoSlot = {}
for i = 1, count do
    if order[i] == PONY then
        ponySlot = i
    else
        videoIds[i] = VIDEO_POOL[order[i]]
        videoSlot[i] = order[i]
    end
end
local videos = {}
local videoFrames = {}
for i = 1, count do
    if i == ponySlot then continue end
    local v = Instance.new("Frame")
    v.Size = UDim2.fromScale(1, 1 / count) v.Position = UDim2.fromScale(0, (i - 1) / count)
    v.BackgroundColor3 = Color3.new(0, 0, 0) v.BorderSizePixel = 0 v.ClipsDescendants = true v.Parent = feed
    local vf = Instance.new("VideoFrame")
    vf.AnchorPoint = Vector2.new(0.5, 0) vf.Position = UDim2.fromScale(0.5, 0) vf.Size = UDim2.fromScale(3.8, 1)
    vf.BackgroundColor3 = Color3.new(0, 0, 0) vf.BorderSizePixel = 0
    vf.Video = "rbxassetid://" .. videoIds[i] vf.Looped = true vf.Volume = 0
    vf.Parent = v
    videoFrames[i] = vf
    overlay(v)
    videos[i] = v
end

--the sound that plays with each clip, empty ids are skipped
local AUDIO_IDS = require(game:GetService("ReplicatedStorage"):WaitForChild("AudioIds"))
local clipSounds = {}
for i = 1, count do
    local id = ""
    if i == ponySlot then
        id = AUDIO_IDS.ponyClip or ""
    else
        id = AUDIO_IDS.phoneClips[videoSlot[i]] or ""
    end
    if id ~= "" then
        local snd = sound(id, 0.8, true)
        --plays from the phone in your hands, the normal track just a little muffled by the small speaker
        snd.Parent = screenPart
        snd.RollOffMode = Enum.RollOffMode.InverseTapered
        snd.RollOffMinDistance = 1.5
        snd.RollOffMaxDistance = 30
        local eq = Instance.new("EqualizerSoundEffect")
        eq.LowGain = -9 eq.MidGain = 1 eq.HighGain = -6
        eq.Parent = snd
        local crunch = Instance.new("DistortionSoundEffect")
        crunch.Level = 0.03
        crunch.Parent = snd
        clipSounds[i] = snd
        table.insert(allSounds, snd)
    end
end


local function playClip(i)
    for k, vf in pairs(videoFrames) do
        if k == i then vf.TimePosition = 0 vf:Play() else vf:Pause() end
    end
    for k, snd in pairs(clipSounds) do
        if k == i then
            --each video is only up for a moment, so longer tracks start partway in where they are already playing
            snd.TimePosition = snd.TimeLength > 5 and snd.TimeLength * 0.3 or 0
            snd:Play()
        else
            snd:Stop()
        end
    end
end

local function stopClips()
    for _, vf in pairs(videoFrames) do vf:Pause() end
    for _, snd in pairs(clipSounds) do snd:Stop() end
end

--two original cartoon ponies bouncing on a pastel field, sits in whatever slot the shuffle gave it
local ponyVideo = Instance.new("Frame")
ponyVideo.Size = UDim2.fromScale(1, 1 / count) ponyVideo.Position = UDim2.fromScale(0, ((ponySlot or count) - 1) / count)
ponyVideo.Visible = ponySlot ~= nil
ponyVideo.BackgroundColor3 = Color3.new(1, 1, 1) ponyVideo.BorderSizePixel = 0 ponyVideo.ClipsDescendants = true ponyVideo.Parent = feed
local sky = Instance.new("UIGradient")
sky.Color = ColorSequence.new(Color3.fromRGB(255, 182, 214), Color3.fromRGB(176, 160, 240)) sky.Rotation = 90 sky.Parent = ponyVideo
box(ponyVideo, -60, 430, 420, 300, Color3.fromRGB(150, 214, 150), 0, UDim.new(0.5, 0))
box(ponyVideo, 180, 40, 70, 70, Color3.fromRGB(255, 240, 170), 0, UDim.new(1, 0))


local function pony(parent, x, y, bodyCol, maneCol, eyeCol, flip)
    local holder = Instance.new("Frame") holder.BackgroundTransparency = 1 holder.Size = UDim2.fromOffset(130, 130) holder.Position = UDim2.fromOffset(x, y) holder.Parent = parent
    local sc = Instance.new("UIScale") sc.Scale = 1.45 sc.Parent = holder
    local function b(px, py, w, h, col, r, rot, tr)
        if flip then px = 130 - px - w rot = rot and -rot end
        return box(holder, px, py, w, h, col, tr or 0, r, rot)
    end
    b(12, 46, 16, 46, maneCol, UDim.new(1, 0), -28)
    for _, lx in ipairs({30, 46, 72, 88}) do
        b(lx, 80, 12, 30, bodyCol, UDim.new(0, 5))
        b(lx, 104, 12, 7, bodyCol:Lerp(Color3.new(0, 0, 0), 0.35), UDim.new(0, 3))
    end
    b(24, 50, 80, 44, bodyCol, UDim.new(0, 22))
    b(78, 26, 22, 34, bodyCol, UDim.new(0, 10), 22)
    b(76, 4, 46, 42, bodyCol, UDim.new(0, 20))
    b(104, 26, 24, 18, bodyCol:Lerp(Color3.new(1, 1, 1), 0.25), UDim.new(1, 0))
    b(84, -6, 12, 18, bodyCol, UDim.new(0, 5), 14)
    b(70, 0, 18, 40, maneCol, UDim.new(1, 0), -10)
    b(78, -4, 30, 14, maneCol, UDim.new(1, 0), -8)
    b(64, 16, 14, 34, maneCol, UDim.new(1, 0), 10)
    b(96, 12, 17, 22, Color3.new(1, 1, 1), UDim.new(1, 0))
    b(99, 15, 12, 17, eyeCol, UDim.new(1, 0))
    b(101, 16, 5, 5, Color3.new(1, 1, 1), UDim.new(1, 0))
    b(106, 26, 3, 3, Color3.new(1, 1, 1), UDim.new(1, 0))
    b(100, 36, 9, 4, Color3.fromRGB(255, 140, 170), UDim.new(1, 0), 0, 0.3)
    return holder
end
local ponyA = pony(ponyVideo, 20, 330, Color3.fromRGB(250, 206, 226), Color3.fromRGB(150, 110, 230), Color3.fromRGB(90, 60, 170), false)
local ponyB = pony(ponyVideo, 150, 350, Color3.fromRGB(190, 232, 250), Color3.fromRGB(255, 214, 110), Color3.fromRGB(40, 110, 160), true)
local sparkles = {}
for i = 1, 10 do
    local sp = box(ponyVideo, math.random(10, 280), math.random(130, 320), 8, 8, Color3.new(1, 1, 1), 0, nil, 45)
    table.insert(sparkles, sp)
end
for i = 1, 4 do
    local h = box(ponyVideo, math.random(30, 260), math.random(150, 300), 12, 12, Color3.fromRGB(255, 120, 170), 0.1, UDim.new(0, 3), 45)
    table.insert(sparkles, h)
end
overlay(ponyVideo)

local currentVideo = 1
local videoStart = os.clock()




local function videoColor()
    if currentVideo == ponySlot then return Color3.fromRGB(240, 190, 225) end
    return videoColors[currentVideo] or videoColors[1]
end

---------------------------------------------------------------- per frame

local function hide()
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end
    end
end

RunService:BindToRenderStep("IntroCutscene", Enum.RenderPriority.Camera.Value + 5, function(dt)
    if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
    local t = os.clock()
    shake = math.max(0, shake - dt * 2.2)
    local sh = shake + tremble
    local sx = math.noise(t * 22, 1.1) * sh * 0.12
    local sy = math.noise(t * 22, 2.3) * sh * 0.12
    local swayCF = CFrame.Angles(math.noise(t * 0.35, 3.7) * 0.014 * sway, math.noise(t * 0.3, 4.1) * 0.018 * sway, math.noise(t * 0.27, 5.3) * 0.007 * sway)
    local shakeRot = CFrame.Angles(math.noise(t * 18, 6.2) * sh * 0.02, math.noise(t * 18, 7.4) * sh * 0.02, 0)
    camera.CFrame = camCF * CFrame.new(sx, sy + bobY, 0) * swayCF * shakeRot * CFrame.Angles(0, 0, bobRoll)

    if phoneVisible then
        local base = camera.CFrame * phoneOffset
        for _, item in ipairs(vmParts) do
            item.part.CFrame = base * item.off
        end
        phoneLight.Color = phoneLight.Color:Lerp(videoColor(), math.min(1, dt * 6))
    end

    --videos keep playing: gradients drift, progress bars fill, ponies bounce
    for i, g in ipairs(gradients) do g.Offset = Vector2.new(0, math.sin(t * 0.8 + i) * 0.15) end
    local v = videos[currentVideo] or ponyVideo
    local prog = v:FindFirstChild("Progress", true)
    if prog then prog.Size = UDim2.fromOffset(math.clamp((t - videoStart) / 6, 0, 1) * 297, 3) end
    ponyA.Position = UDim2.fromOffset(-6, 300 - math.abs(math.sin(t * 3.1)) * 26)
    ponyA.Rotation = math.sin(t * 3.1) * 5
    ponyB.Position = UDim2.fromOffset(112, 326 - math.abs(math.sin(t * 3.1 + 1.4)) * 22)
    ponyB.Rotation = math.sin(t * 3.1 + 1.4) * -5
    for i, sp in ipairs(sparkles) do sp.BackgroundTransparency = 0.2 + 0.8 * math.abs(math.sin(t * 2.2 + i)) end

    if hideCharacter then hide() end
end)

---------------------------------------------------------------- scenes




local function swipe()
    --small flick of the phone instead of a finger
    task.spawn(function()
        local rest = phoneOffset
        animate(0.2, function(a)
            local k = math.sin(a * math.pi)
            phoneOffset = rest * CFrame.new(0, 0.02 * k, 0) * CFrame.Angles(math.rad(-3 * k), 0, 0)
        end)
        phoneOffset = rest
    end)
    waitPaced(0.05)
    currentVideo += 1
    videoStart = os.clock()
    playClip(currentVideo)
    TweenService:Create(feed, TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, -(currentVideo - 1))}):Play()
end

--bumped when the knock lands, so a small head adjustment still finishing can never drag the view back to the phone
local headToken = 0

local function sceneCar()
    --about six seconds in all, half of what it was
    tweenNumber(fade, "BackgroundTransparency", 1, 1.5)
    playClip(1)
    waitPaced(1.15)
    local holds = {0.32, 0.23, 0.39, 0.25, 0.34, 0.28}
    for _, h in ipairs(holds) do
        swipe()
        waitPaced(h)
        --tiny head adjustments while scrolling
        local base = camCF
        local mine = headToken
        task.spawn(function()
            local target = CFrame.lookAt(SEAT_EYE, SEAT_EYE + Vector3.new(0.12 + math.random(-6, 6) / 100, -0.42 + math.random(-4, 4) / 100, -1))
            animate(0.3, function(a)
                if headToken == mine then camCF = base:Lerp(target, ease(a)) end
            end)
        end)
    end
end


--bent down at the passenger window, face turned to the player, arms hanging, it only stares
local function poseAtWindow(handOut, headRoll)
    poseFigure(KNOCK_FEET, KNOCK_LEAN, 0, KNOCK_LEAN - 8, headRoll)
    --bends at the waist until the face is level with the glass, then shuffles so the face is right on it
    local base = KNOCK_FEET * CFrame.new(0, feetToRoot, 0)
    local lo, hi = 10, 110
    for _ = 1, 14 do
        local mid = (lo + hi) / 2
        setJ("Waist", CFrame.Angles(math.rad(-mid), 0, 0))
        local _, _, hd = figBody(base)
        if hd.Position.Y > GLASS_FACE.Y then lo = mid else hi = mid end
    end
    setJ("Waist", CFrame.Angles(math.rad(-(lo + hi) / 2), 0, 0))
    local _, _, hd = figBody(base)
    --face sits just outside the glass so no part of it ends up inside the car
    local rootCF = base + Vector3.new(GLASS_FACE.X + 0.45 - hd.Position.X, 0, GLASS_FACE.Z - hd.Position.Z)
    figRoot.CFrame = rootCF
    local _, ut = figBody(rootCF)
    --head twisted round to stare straight at the driver seat
    local nj = figJ.Neck
    local want = CFrame.lookAt(GLASS_FACE, SEAT_EYE) * CFrame.Angles(0, 0, math.rad(headRoll))
    local q = ut.Rotation:Inverse() * want.Rotation * nj.C1.Rotation
    nj.C0 = CFrame.new(figBase.Neck.Position) * q
end



--fingers splay flat against the glass while the hand is on it
local function setGlassHand(on)
    for _, p in ipairs(fig:GetChildren()) do
        if p:GetAttribute("Finger") and p.Name:sub(1, 5) == "Right" then
            local j = p:FindFirstChildOfClass("Motor6D")
            if j then j.C0 = figBase[j.Name] * CFrame.Angles(0, 0, math.rad(on and -10 or 15) * (p:GetAttribute("CurlSign") or 1)) end
        end
    end
end
local faceLight


local function sceneKnock()
    --it is already there while the player looks down at the phone
    poseAtWindow(0, 9)
    --faint cold light so the face reads through the glass
    faceLight = Instance.new("Part")
    faceLight.Name = "FaceLight" faceLight.Anchored = true faceLight.CanCollide = false faceLight.CanQuery = false faceLight.CanTouch = false
    faceLight.Transparency = 1 faceLight.Size = Vector3.new(0.2, 0.2, 0.2)
    faceLight.Position = Vector3.new(-27.7, 5.5, 39.7)
    local fl = Instance.new("PointLight") fl.Brightness = 0.9 fl.Range = 4.5 fl.Color = Color3.fromRGB(175, 190, 215) fl.Shadows = false fl.Parent = faceLight
    faceLight.Parent = workspace
    --one knock on the glass while the player is still looking down at the phone
    sKnock.Volume = 1.4
    sKnock.TimePosition = 0
    sKnock:Play()
    local t0 = os.clock()
    repeat RunService.RenderStepped:Wait() until sKnock.PlaybackLoudness > KNOCK_HIT or os.clock() - t0 > 0.6 * pace
    --the scare sting hits with the knock, as the face is revealed
    sSting:Play()
    shake = 1
    --clip is cut right after the first hit so there is only ever one knock
    task.delay(0.07, function()
        tweenNumber(sKnock, "Volume", 0, 0.05)
        waitPaced(0.06)
        sKnock:Stop()
    end)
    --startled: head whips to the window, phone falls away
    headToken += 1
    sGasp:Play()
    task.spawn(function()
        local from = phoneOffset
        local to = CFrame.new(0.3, -1.9, -0.9) * CFrame.Angles(math.rad(-70), math.rad(10), math.rad(35))
        animate(0.45, function(a) phoneOffset = from:Lerp(to, ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)) end)
        phoneVisible = false
        stopClips()
        for _, item in ipairs(vmParts) do item.part.Transparency = 1 end
        phoneLight.Enabled = false
    end)
    local from = camCF
    local to = CFrame.lookAt(SEAT_EYE + Vector3.new(-0.15, 0.05, 0.1), GLASS_FACE)
    animate(0.26, function(a) camCF = from:Lerp(to, ease(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)) end)
    sHeart:Play()
    tweenNumber(sHeart, "Volume", 0.6, 1.5)
    sway = 1.2
    tremble = 0.08
    --it never moves again, it just stares through the glass
    --the players focus narrows onto the face
    local fov0 = camera.FieldOfView
    task.spawn(function()
        animate(2.6, function(a) camera.FieldOfView = fov0 + (52 - fov0) * ease(a) end)
    end)
    waitPaced(3.2)
end

---------------------------------------------------------------- the figure on its own feet
local figChase, figRattleLoop, figLeave


--its sounds come out of its body so they sit right where it is
local function figSound(id, vol, speed)
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. id
    snd.Volume = vol
    snd.PlaybackSpeed = speed or 1
    snd.SoundGroup = introGroup
    snd.RollOffMode = Enum.RollOffMode.InverseTapered
    snd.RollOffMinDistance = 6
    snd.RollOffMaxDistance = 90
    snd.Parent = figRoot
    table.insert(allSounds, snd)
    return snd
end
local figSteps = {}
for _, id in ipairs({"9114521931", "9114521211", "9114520969", "9114522236", "9114522142", "9114522515"}) do
    table.insert(figSteps, figSound(id, 0.5, 0.85))
end
local fRattle = figSound("9114745537", 0.7, 0.8)
local fBreath = figSound("9113971584", 0.9, 0.8)

local FACE_DOOR = -math.pi / 2
local figPos = Vector3.new()
local figY = 0.4
local figYaw = 0
local figPhase = 0
local figStandX = -62.3
local doorsShut = false
local figArrived = false
local figGone = false
local figRattle = false
local figStill = true

local figRp = RaycastParams.new()
figRp.FilterType = Enum.RaycastFilterType.Exclude
figRp.FilterDescendantsInstances = {fig, character, broom, car}


local function figGround(x, z)
    local hit = workspace:Raycast(Vector3.new(x, figY + 2.5, z), Vector3.new(0, -5, 0), figRp)
    if hit then return hit.Position.Y end
    return figY
end


local function figStep(vol)
    local snd = figSteps[math.random(1, #figSteps)]
    snd.Volume = vol
    snd.PlaybackSpeed = 0.8 + math.random() * 0.1
    snd.TimePosition = 0
    snd:Play()
    --only the first slap of the clip, the tail is cut
    task.delay(0.22, function() snd:Stop() end)
end

--legs swing from the hips, knees fold as each leg comes through, arms pump against them
local function figGait(amt, lean)
    local s = math.sin(figPhase * 2 * math.pi)
    local c = math.cos(figPhase * 2 * math.pi)
    local hip = 34 * amt
    local knee = 62 * amt
    local arm = 30 * amt
    setJ("RightHip", CFrame.Angles(math.rad(hip * s), 0, 0))
    setJ("LeftHip", CFrame.Angles(math.rad(-hip * s), 0, 0))
    setJ("RightKnee", CFrame.Angles(math.rad(-knee * math.max(0, c) - 6 * amt), 0, 0))
    setJ("LeftKnee", CFrame.Angles(math.rad(-knee * math.max(0, -c) - 6 * amt), 0, 0))
    setJ("RightShoulder", CFrame.Angles(math.rad(-arm * s + 10 * amt), 0, math.rad(-6)))
    setJ("LeftShoulder", CFrame.Angles(math.rad(arm * s + 10 * amt), 0, math.rad(6)))
    setJ("RightElbow", CFrame.Angles(math.rad(10 + 25 * amt), 0, 0))
    setJ("LeftElbow", CFrame.Angles(math.rad(10 + 25 * amt), 0, 0))
    setJ("Waist", CFrame.Angles(math.rad(-lean), math.rad(8 * s * amt), 0))
    setJ("Neck", CFrame.Angles(math.rad(lean * 0.6), 0, math.rad(8)))
    --the hips sink as the planted leg angles out so the feet stay on the ground
    local drop = feetToRoot * 0.45 * (1 - math.cos(math.rad(hip * s))) + feetToRoot * 0.05 * amt
    figRoot.CFrame = CFrame.new(figPos.X, figY + feetToRoot - drop, figPos.Z) * CFrame.Angles(0, figYaw, 0)
end


local function figSpline(points, t)
    local n = #points - 1
    local seg = math.clamp(math.floor(t * n) + 1, 1, n)
    local u = t * n - (seg - 1)
    local p0 = points[math.max(seg - 1, 1)]
    local p1 = points[seg]
    local p2 = points[seg + 1]
    local p3 = points[math.min(seg + 2, #points)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
end


--moves the figure along a curved path on its own feet, done after duration seconds
--curve maps time to distance so it can speed up, stopIf ends it early
local function figPathRun(points, duration, amtMax, lean, curve, stopIf)
    local samples = {{d = 0, p = figSpline(points, 0)}}
    local total = 0
    for i = 1, 240 do
        local p = figSpline(points, i / 240)
        total += (p - samples[#samples].p).Magnitude
        table.insert(samples, {d = total, p = p})
    end
    local function posAt(d)
        for i = 2, #samples do
            if samples[i].d >= d then
                local a, b = samples[i - 1], samples[i]
                return a.p:Lerp(b.p, (d - a.d) / math.max(b.d - a.d, 1e-4))
            end
        end
        return samples[#samples].p
    end
    local stride = math.max(feetToRoot * 1.9, 3)
    local u = 0
    local lastD = 0
    local amt = 0.3
    local lastStep = math.floor(figPhase * 2 + 0.5)
    while u < 1 do
        local dt = RunService.RenderStepped:Wait()
        u = math.min(1, u + dt / math.max(duration * pace, 1e-3))
        local d = total * curve(u)
        local p = posAt(d)
        local move = Vector3.new(p.X - figPos.X, 0, p.Z - figPos.Z)
        if move.Magnitude > 1e-3 then
            local want = math.atan2(-move.X, -move.Z)
            local diff = (want - figYaw + math.pi) % (2 * math.pi) - math.pi
            figYaw += diff * math.min(1, dt * 10)
        end
        figPos = Vector3.new(p.X, 0, p.Z)
        figY += (figGround(p.X, p.Z) - figY) * math.min(1, dt * 12)
        local speed = (d - lastD) / math.max(dt, 1e-3)
        figPhase += (d - lastD) / (2 * stride)
        lastD = d
        amt += (math.clamp(speed / 9, 0.25, amtMax) - amt) * math.min(1, dt * 6)
        figGait(amt, lean)
        local step = math.floor(figPhase * 2 + 0.5)
        if step ~= lastStep then
            lastStep = step
            figStep(0.3 + 0.35 * amt)
        end
        if stopIf and stopIf() then return false end
    end
    return true
end

--degrees the doors are forced in, 0 is shut tight
local doorAmt = 0


local function doorsPushed(amt)
    doorAmt = amt
    setDoor("A", doors.A.closed + amt)
    setDoor("B", doors.B.closed - amt)
end


--turns a hand so the palm faces the glass and the fingers point straight up, returns the hand frame
local function flatPalm(side, forearm)
    local j = figJ[side .. "Wrist"]
    if not j then return forearm end
    --the palm is the hand's -x side on the right hand and +x on the left
    local x = side == "Right" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    local want = CFrame.fromMatrix(Vector3.zero, x, Vector3.new(0, -1, 0))
    local q = forearm.Rotation:Inverse() * want * j.C1.Rotation
    j.C0 = CFrame.new(figBase[side .. "Wrist"].Position) * q
    return forearm * j.C0 * j.C1:Inverse()
end

--fingers straight and flat so none of them poke through
local function flatFingers()
    for _, p in ipairs(fig:GetChildren()) do
        if p:GetAttribute("Finger") then
            local j = p:FindFirstChildOfClass("Motor6D")
            if j and figBase[j.Name] then j.C0 = figBase[j.Name] end
        end
    end
end


--palms flat on both doors, weight thrown in as push goes from 0 to 1
--the body slides so the palms sit right on the glass however far the doors have given
local function figDoorPose(push)
    setJ("RightHip", CFrame.Angles(math.rad(-14 - push * 6), 0, 0))
    setJ("RightKnee", CFrame.Angles(math.rad(-10), 0, 0))
    setJ("LeftHip", CFrame.Angles(math.rad(16), 0, 0))
    setJ("LeftKnee", CFrame.Angles(math.rad(-22 - push * 8), 0, 0))
    setJ("Waist", CFrame.Angles(math.rad(-(12 + push * 14)), math.rad(push * 4), 0))
    setJ("Neck", CFrame.Angles(math.rad(8 + push * 8), 0, math.rad(18)))
    setJ("RightShoulder", CFrame.Angles(math.rad(92), 0, math.rad(-10)))
    setJ("LeftShoulder", CFrame.Angles(math.rad(88), 0, math.rad(10)))
    setJ("RightElbow", CFrame.Angles(math.rad(16 - push * 10), 0, 0))
    setJ("LeftElbow", CFrame.Angles(math.rad(16 - push * 10), 0, 0))
    flatFingers()
    local rootCF = CFrame.new(figStandX, figY + feetToRoot - 0.25, 16) * CFrame.Angles(0, FACE_DOOR, 0)
    local _, ut = figBody(rootCF)
    local front = -math.huge
    for _, side in ipairs({"Right", "Left"}) do
        local upper = fkJ(ut, figJ[side .. "Shoulder"])
        local fore = fkJ(upper, figJ[side .. "Elbow"])
        local hand = flatPalm(side, fore)
        local part = fig:FindFirstChild(side .. "Hand")
        front = math.max(front, hand.Position.X + (part and part.Size.X / 2 or 0.3))
    end
    --outer face of the glass, it moves in as the doors give
    local glass = -60.2 - 0.03 + 1.9 * math.sin(math.rad(doorAmt))
    figRoot.CFrame = rootCF + Vector3.new(glass - front, 0, 0)
end


--stands right up to the doors
local function figFitDoor()
    figY = figGround(-62, 16)
    figStandX = -62.3
    figDoorPose(0)
end


--the head turns to stare at a point, tilted
local function figLook(point, tilt)
    local _, ut, hd = figBody(figRoot.CFrame)
    local nj = figJ.Neck
    local want = CFrame.lookAt(hd.Position, point) * CFrame.Angles(0, 0, math.rad(tilt))
    local q = ut.Rotation:Inverse() * want.Rotation * nj.C1.Rotation
    nj.C0 = CFrame.new(figBase.Neck.Position) * q
end


--true when any of the head or body is on screen with a clear line to the camera
local function figSeen()
    if skipping then return false end
    local camPos = camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {fig, character, broom}
    for _, n in ipairs({"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}) do
        local part = fig:FindFirstChild(n)
        if part then
            local p = part.Position
            local _, onScreen = camera:WorldToViewportPoint(p)
            if onScreen and (p - camPos).Magnitude < 95 then
                local clear = false
                for _ = 1, 6 do
                    local hit = workspace:Raycast(camPos, p - camPos, params)
                    if not hit then clear = true break end
                    --glass and other see through parts do not hide it
                    if hit.Instance.Transparency > 0.35 then
                        params:AddToFilter(hit.Instance)
                    else
                        break
                    end
                end
                if clear then return true end
            end
        end
    end
    return false
end


--peels off the glass, rounds the back of the car and runs them down to the doors
function figChase()
    task.spawn(function()
        local rootFrom = figRoot.CFrame
        local waistFrom = figJ.Waist.C0
        local neckFrom = figJ.Neck.C0
        local leftFrom = figJ.LeftShoulder.C0
        local rightFrom = figJ.RightShoulder.C0
        setGlassHand(false)
        local start = Vector3.new(math.max(rootFrom.X + 0.9, -23.4), 0, rootFrom.Z)
        local standCF = CFrame.new(start.X, 0.4 + feetToRoot, start.Z) * rootFrom.Rotation
        if faceLight then
            local l = faceLight:FindFirstChildOfClass("PointLight")
            if l then tweenNumber(l, "Brightness", 0, 0.4) end
        end
        animate(0.45, function(a)
            local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            figRoot.CFrame = rootFrom:Lerp(standCF, e)
            figJ.Waist.C0 = waistFrom:Lerp(figBase.Waist * CFrame.Angles(math.rad(-16), 0, 0), e)
            figJ.Neck.C0 = neckFrom:Lerp(figBase.Neck * CFrame.Angles(math.rad(10), 0, 0), e)
            figJ.LeftShoulder.C0 = leftFrom:Lerp(figBase.LeftShoulder, e)
            figJ.RightShoulder.C0 = rightFrom:Lerp(figBase.RightShoulder, e)
        end)
        if faceLight then faceLight:Destroy() faceLight = nil end
        figPos = start
        figY = 0.4
        figYaw = math.pi / 2
        figPhase = 0
        local path = {
            start, Vector3.new(-23.4, 0, 45.6), Vector3.new(-26.6, 0, 50.6), Vector3.new(-34, 0, 51.2), Vector3.new(-38.9, 0, 46.6),
            Vector3.new(-41.6, 0, 39.6), Vector3.new(-47.5, 0, 35), Vector3.new(-56, 0, 30.4), Vector3.new(-62.8, 0, 25.2),
            Vector3.new(-64.6, 0, 20.2), Vector3.new(-64, 0, 17.2), Vector3.new(-62.6, 0, 16),
        }
        --slow first strides then faster and faster
        figPathRun(path, 5.5, 1, 20, function(u) return 0.55 * u + 0.45 * u * u end)
        --catches up the last step and hits the glass the moment it shuts
        while not doorsShut do
            figGait(0.15, 12)
            RunService.RenderStepped:Wait()
        end
        local fromCF = figRoot.CFrame
        figFitDoor()
        local toCF = figRoot.CFrame
        animate(0.1, function(a) figRoot.CFrame = fromCF:Lerp(toCF, a) end)
        figDoorPose(0.6)
        shake = 1.1
        playForce()
        task.spawn(function()
            animate(0.12, function(a) doorsPushed(5 * math.sin(a * math.pi)) end)
            doorsPushed(0)
        end)
        figArrived = true
    end)
end


--small shoves while the player goes for the broom
function figRattleLoop()
    figStill = false
    task.spawn(function()
        while figRattle do
            local peak = 3 + math.random() * 4
            playForce()
            animate(0.14, function(a)
                local k = math.sin(a * math.pi)
                doorsPushed(peak * k)
                figDoorPose(0.3 + 0.6 * k)
            end)
            local w = os.clock() + (0.25 + math.random() * 0.3) * pace
            while figRattle and os.clock() < w do RunService.RenderStepped:Wait() end
        end
        doorsPushed(0)
        figDoorPose(0.3)
        figStill = true
    end)
end




--leaves round the right side of the building and only goes once nothing can see it
function figLeave()
    task.spawn(function()
        figPos = Vector3.new(figRoot.Position.X, 0, 16)
        figYaw = FACE_DOOR
        figPhase = 0
        local path = {
            figPos, Vector3.new(-63.4, 0, 13.4), Vector3.new(-64, 0, 4), Vector3.new(-64, 0, -8), Vector3.new(-63.6, 0, -19),
            Vector3.new(-61, 0, -24.6), Vector3.new(-54, 0, -27.6), Vector3.new(-47.6, 0, -29.6),
        }
        local unseenFor = 0
        local last = os.clock()
        local function gone()
            local now = os.clock()
            local dt = now - last
            last = now
            if figPos.Z > 6 then return false end
            if figSeen() then unseenFor = 0 else unseenFor += dt end
            return unseenFor > 0.3
        end
        local hidden = not figPathRun(path, 7, 0.55, 8, function(u) return u end, gone)
        --at the end of the path it holds still until nobody is looking
        while not hidden do
            figGait(0, 6)
            figLook(camera.CFrame.Position, 14)
            if gone() then hidden = true end
            RunService.RenderStepped:Wait()
        end
        poseFigure(CFrame.new(0, -200, 0), 0, 0, 0)
        figGone = true
    end)
end

local function sceneEscape()
    --it peels off the glass and comes after them
    figChase()
    --whip toward the driver door, turned by yaw and pitch so the big turn never rolls
    local from = camCF
    local look0 = from.LookVector
    local yaw0 = math.atan2(-look0.X, -look0.Z)
    local pitch0 = math.asin(math.clamp(look0.Y, -1, 1))
    local dir1 = Vector3.new(-1, -0.15, -0.25).Unit
    local yaw1 = math.atan2(-dir1.X, -dir1.Z)
    local pitch1 = math.asin(dir1.Y)
    local turn = (yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi
    local p0 = from.Position
    local p1 = SEAT_EYE + Vector3.new(-0.3, 0, 0)
    local fov0 = camera.FieldOfView
    shake = 0.5
    animate(0.34, function(a)
        local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        camera.FieldOfView = fov0 + (72 - fov0) * e
        camCF = CFrame.new(p0:Lerp(p1, e)) * CFrame.Angles(0, yaw0 + turn * e, 0) * CFrame.Angles(pitch0 + (pitch1 - pitch0) * e, 0, 0)
    end)
    sCarDoor:Play()
    task.spawn(function()
        animate(0.45, function(a) setCarDoor(-68 * ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) end)
    end)
    waitPaced(0.15)
    --scramble out and stand up
    local p1 = Vector3.new(-33.1, 4.6, 39.6)
    local p2 = Vector3.new(-35.2, 5.7, 38.9)
    local p3 = Vector3.new(-37, 0.4 + EYE_RUN, 38.2)
    local start = camCF
    local fovS = camera.FieldOfView
    animate(0.75, function(a)
        local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        camera.FieldOfView = fovS + (74 - fovS) * e
        local pos
        if e < 0.5 then pos = start.Position:Lerp(p1, e * 2):Lerp(p2, e * 0.6) else pos = p2:Lerp(p3, (e - 0.5) * 2) end
        local dir = Vector3.new(-1, -0.25 + 0.3 * e, -0.25 - 0.4 * e)
        camCF = CFrame.lookAt(pos, pos + dir)
    end)
    tremble = 0.05
end


--catmull rom spline so the run curves naturally
local function spline(points, t)
    local n = #points - 1
    local seg = math.clamp(math.floor(t * n) + 1, 1, n)
    local u = t * n - (seg - 1)
    local p0 = points[math.max(seg - 1, 1)]
    local p1 = points[seg]
    local p2 = points[seg + 1]
    local p3 = points[math.min(seg + 2, #points)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
end


local function sceneRun()
    local y = 0.4 + EYE_RUN
    local pts = {
        camCF.Position,
        Vector3.new(-39.5, y, 37.2), Vector3.new(-47, y, 34.2), Vector3.new(-56, y + 0.1, 30.6),
        Vector3.new(-63.2, y + 0.1, 25.2), Vector3.new(-65, y + 0.1, 19.8), Vector3.new(-63, y + 0.1, 16.4),
        Vector3.new(-60, y + 0.1, 16), Vector3.new(-57.4, y + 0.1, 16), Vector3.new(-56.4, y + 0.1, 16),
    }
    --arc length table for constant speed
    local samples = {}
    local total = 0
    local prev = spline(pts, 0)
    samples[1] = {t = 0, d = 0}
    for i = 1, 200 do
        local t = i / 200
        local p = spline(pts, t)
        total += (p - prev).Magnitude
        prev = p
        samples[#samples + 1] = {t = t, d = total}
    end
    local function tAt(d)
        for i = 2, #samples do
            if samples[i].d >= d then
                local a = samples[i - 1] local b = samples[i]
                return a.t + (b.t - a.t) * ((d - a.d) / math.max(b.d - a.d, 1e-4))
            end
        end
        return 1
    end
    local duration = 3.3
    --one foot lands every 4.6 studs of ground covered, about three steps a second at full run
    local stride = 4.6
    local lastStep = 0
    local doorPoint = Vector3.new(-60, y - 0.45, 16)
    local lookDir = (camCF.LookVector * Vector3.new(1, 0, 1)).Unit
    local fovR = camera.FieldOfView
    animate(duration, function(a)
        camera.FieldOfView = fovR + (78 - fovR) * math.min(1, a * 3)
        local dist = total * ease(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local t = tAt(dist)
        local pos = spline(pts, t)
        local ahead = spline(pts, math.min(1, t + 0.04))
        local fwd = (ahead - pos) * Vector3.new(1, 0, 1)
        if fwd.Magnitude > 0.01 then fwd = fwd.Unit else fwd = lookDir end
        --eyes stay locked on the entrance, only following the path in the last few studs
        local toDoor = doorPoint - pos
        local w = math.clamp((toDoor.Magnitude - 1.5) / 2.5, 0, 1)
        --once through the doorway the eyes only follow the path, never back over the shoulder
        --the doorway is the 8th point on the path
        if t >= 7 / (#pts - 1) then w = 0 end
        local dir = fwd:Lerp(toDoor.Unit, w) + Vector3.new(0, -0.06, 0)
        lookDir = lookDir:Lerp(dir.Unit, 0.3)
        --bob and steps both come from distance so they always line up
        local sf = math.sin(a * math.pi)
        local phase = dist / stride * math.pi
        bobY = (math.abs(math.sin(phase)) * 0.3 - 0.1) * sf
        bobRoll = math.sin(phase) * math.rad(1.3) * sf
        local step = math.floor(phase / math.pi)
        if step ~= lastStep then
            lastStep = step
            local surface = "Gritty"
            if pos.Z < 28.5 or pos.X < -59.5 then surface = "Concrete" end
            footstep(surface, 0.4 + 0.14 * sf)
        end
        camCF = CFrame.lookAt(pos, pos + lookDir)
    end)
    bobY = 0 bobRoll = 0
end

local function sceneDoor()
    --momentum carries a half step in while the body spins around to face the doors
    --yaw and pitch are turned separately so the view never flips or snaps
    local start = camCF
    local pos0 = start.Position
    local look0 = start.LookVector
    local yaw0 = math.atan2(-look0.X, -look0.Z)
    local pitch0 = math.asin(math.clamp(look0.Y, -1, 1))
    local yaw1 = math.atan2(1, 0)
    local pitch1 = math.rad(-9)
    --always the short way round
    local turn = (yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi
    local side = turn >= 0 and 1 or -1
    local pos1 = Vector3.new(-57.3, pos0.Y, 16)
    local fov0 = camera.FieldOfView
    local steps = {0.32, 0.74}
    local nextStep = 1
    animate(0.9, function(a)
        local e = ease(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local yaw = yaw0 + turn * e
        local pitch = pitch0 + (pitch1 - pitch0) * e
        --a little forward drift first, then a step back toward the doors
        local p = pos0:Lerp(pos1, e) + Vector3.new(math.sin(a * math.pi) * 0.45, 0, 0)
        --two quick footfalls during the turn, head leans into it
        bobY = -math.abs(math.sin(a * math.pi * 2)) * 0.09
        bobRoll = math.sin(a * math.pi) * math.rad(4) * side
        if steps[nextStep] and a >= steps[nextStep] then
            nextStep += 1
            footstep("Concrete", 0.32)
        end
        camera.FieldOfView = fov0 + (72 - fov0) * e
        camCF = CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
    end)
    bobY = 0 bobRoll = 0
    --pull both doors shut, the shut sound waits for the last shove in the fight
    task.spawn(function()
        animate(0.42, function(a) setDoor("A", doors.A.closed * ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)) end)
        shake = math.max(shake, 0.6)
    end)
    waitPaced(0.06)
    animate(0.42, function(a) setDoor("B", doors.B.closed * ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)) end)
    doorsShut = true
    shake = 0.8
    waitPaced(0.35)
end


--it throws its weight against the glass and the player throws theirs back
local function sceneHold()
    local t0 = os.clock()
    while not figArrived and os.clock() - t0 < 3 do RunService.RenderStepped:Wait() end
    local from = camCF
    local braced = CFrame.new(from.Position + Vector3.new(-1, -0.18, 0)) * from.Rotation
    footstep("Concrete", 0.35)
    animate(0.2, function(a) camCF = from:Lerp(braced, ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) end)
    local surges = {{9, 0.22, 0.36, 0.12}, {14, 0.2, 0.42, 0.2}, {21, 0.18, 0.55, 0.3}}
    for i, s in ipairs(surges) do
        local peak, tOut, tBack, tHold = s[1], s[2], s[3], s[4]
        shake = math.max(shake, 0.5 + i * 0.15)
        playForce()
        --doors give and the player is shoved back
        animate(tOut, function(a)
            local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            doorsPushed(peak * e)
            figDoorPose(e)
            camCF = braced * CFrame.new(0, 0, peak * 0.035 * e) * CFrame.Angles(math.rad(1.6 * e), 0, math.rad(-1.2 * e))
        end)
        tremble = 0.1
        waitPaced(tHold)
        --and shoves it shut again
        animate(tBack, function(a)
            local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            doorsPushed(peak * (1 - e))
            figDoorPose(1 - e * 0.8)
            camCF = braced * CFrame.new(0, 0, peak * 0.035 * (1 - e) - 0.12 * math.sin(e * math.pi)) * CFrame.Angles(math.rad(1.6 * (1 - e)), 0, math.rad(-1.2 * (1 - e)))
        end)
        --only the last shove that gets the doors fully shut slams
        if i == #surges then playSlam() end
        shake = math.max(shake, 0.5)
        waitPaced(0.12)
    end
    tremble = 0.06
end

---------------------------------------------------------------- hands that hold the broom


local function newHand(side)
    local m = Instance.new("Model")
    m.Name = side == 1 and "RightHand" or "LeftHand"
    m.Parent = vm
    local function hp(name, size, col, mat)
        local p = Instance.new("Part")
        p.Name = name p.Size = size p.Color = col p.Material = mat or Enum.Material.SmoothPlastic
        p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
        p.Transparency = 1
        p.Parent = m
        return p
    end
    local h = {side = side, model = m, s = 2.6, grip = 0, open = 0, visible = false}
    h.palm = hp("Palm", Vector3.new(0.3, 0.36, 0.1), skin)
    h.fingers = hp("Fingers", Vector3.new(0.08, 0.34, 0.32), skin)
    h.thumb = hp("Thumb", Vector3.new(0.07, 0.2, 0.12), skin)
    h.wrist = hp("Wrist", Vector3.new(0.22, 0.24, 0.2), skin)
    h.arm = hp("Forearm", Vector3.new(0.26, 0.26, 1), sleeveCol, Enum.Material.Fabric)
    return h
end
local handR = newHand(1)
local handL = newHand(-1)


local function setVisible(h, v)
    h.visible = v
    for _, p in ipairs(h.model:GetChildren()) do p.Transparency = v and 0 or 1 end
end


--grip frame: s is how far up the handle from the head, palm sits on the player's side of the stick
local function placeHand(h)
    if not h.visible then return end
    local cam = camera.CFrame
    local rest = cam * CFrame.new(h.side * 0.75, -1.75, -0.7) * CFrame.Angles(math.rad(55), math.rad(-h.side * 20), 0)
    local G = broom:GetPivot() * CFrame.new(0, h.s, 0)
    local frame = rest:Lerp(G, h.grip)
    --tiny wrist movement so the grip never looks frozen
    local t = os.clock()
    frame = frame * CFrame.Angles(math.noise(t * 1.7, h.side) * 0.04, 0, math.noise(t * 1.3, h.side + 3) * 0.05)
    local o = h.open
    h.palm.CFrame = frame * CFrame.new(0, 0, -0.17)
    h.fingers.CFrame = frame * CFrame.new(0.13 + 0.1 * o, 0, -0.02 - 0.18 * o) * CFrame.Angles(0, 0, math.rad(-70 * o))
    h.thumb.CFrame = frame * CFrame.new(-0.13 - 0.06 * o, 0.05, -0.1 - 0.05 * o)
    h.wrist.CFrame = frame * CFrame.new(0, -0.05, -0.33)
    --forearm runs from the wrist back to an elbow just under the camera
    local W = (frame * CFrame.new(0, -0.08, -0.42)).Position
    local E = cam * Vector3.new(h.side * 0.6, -1.45, 0.3)
    h.arm.Size = Vector3.new(0.26, 0.26, (E - W).Magnitude)
    h.arm.CFrame = CFrame.lookAt((W + E) / 2, E)
end

--broom pose is evaluated after the camera every frame so the hands never lag behind it
local broomFn = nil
RunService:BindToRenderStep("IntroBroom", Enum.RenderPriority.Camera.Value + 6, function()
    if broomFn then broom:PivotTo(broomFn()) end
    placeHand(handR)
    placeHand(handL)
end)


local function sceneBroom()
    --plays at double speed
    setPace(0.5)
    figRattle = true
    figRattleLoop()
    local Y = camCF.Position.Y
    --look for something, anything
    local from = camCF
    local lookBroom = CFrame.lookAt(Vector3.new(-57.4, Y, 15.2), Vector3.new(-58.9, 3.2, 11.2))
    animate(0.5, function(a) camCF = from:Lerp(lookBroom, ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) end)
    --reach out, fingers close as the hand meets the handle
    broomFn = function() return BroomPath.lean end
    handR.s = 2.6 handR.grip = 0 handR.open = 1
    setVisible(handR, true)
    animate(0.45, function(a)
        handR.grip = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        handR.open = 1 - math.clamp((a - 0.6) / 0.4, 0, 1)
    end)
    --the broom rocks slightly in the grip on contact
    animate(0.14, function(a)
        local r = math.sin(a * math.pi) * math.rad(2.5)
        broomFn = function() return BroomPath.lean * CFrame.Angles(0, 0, r) end
    end)
    --lift it while the other hand comes in near the tip
    handL.s = 3.35 handL.grip = 0 handL.open = 1
    setVisible(handL, true)
    animate(0.6, function(a)
        local e = ease(a)
        broomFn = function() return BroomPath.lean:Lerp(BroomPath.held(camera.CFrame), e) end
        handL.grip = ease(math.clamp((a - 0.25) / 0.75, 0, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        handL.open = 1 - math.clamp((a - 0.7) / 0.3, 0, 1)
    end)
    --turn back to the doors carrying it
    broomFn = function() return BroomPath.held(camera.CFrame) end
    from = camCF
    local lookHandles = CFrame.lookAt(Vector3.new(-57.5, Y - 0.2, 16.4), Vector3.new(-59.6, 5.0, 16.4))
    animate(0.55, function(a) camCF = from:Lerp(lookHandles, ease(a)) end)
    --right hand slides down the handle toward the head for a pushing grip
    animate(0.45, function(a) handR.s = 2.6 - 2.0 * ease(a) end)
    --it lets up for a second, just long enough to get the broom through
    figRattle = false
    while not figStill do RunService.RenderStepped:Wait() end
    --guide the tip in from the room side, just above door b's handle
    local camEntry = CFrame.lookAt(Vector3.new(-57.6, Y - 0.1, 16.6), Vector3.new(-59.4, 6.2, 17.2))
    animate(0.65, function(a)
        local e = ease(a)
        camCF = lookHandles:Lerp(camEntry, e)
        broomFn = function() return BroomPath.approach(camera.CFrame, e) end
    end)
    --thread it behind both handles and level it out, left hand lets go before the first handle
    local camSlide = CFrame.lookAt(Vector3.new(-57.6, Y - 0.2, 16.4), Vector3.new(-59.6, 4.9, 15.9))
    local tzStop = 14.05
    local released = false
    animate(1.45, function(a)
        local tz = BroomPath.ENTRY_TZ + (tzStop - BroomPath.ENTRY_TZ) * ease(a)
        broomFn = function() return BroomPath.slidePose(tz) end
        camCF = camEntry:Lerp(camSlide, ease(a))
        if not released and tz < 16.78 then
            released = true
            task.spawn(function()
                animate(0.35, function(b)
                    handL.open = math.clamp(b * 2, 0, 1)
                    handL.grip = 1 - ease(b)
                end)
                setVisible(handL, false)
            end)
        end
    end)
    --one last hard shove home
    animate(0.16, function(a)
        local tz = tzStop + (BroomPath.FINAL_TZ - tzStop) * ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        broomFn = function() return BroomPath.slidePose(tz) end
    end)
    --handle is now fully through both door handles
    playBroomIn()
    shake = 0.45
    --tug it twice to be sure it holds
    for i = 1, 2 do
        animate(0.13, function(a)
            local o = 0.05 * math.sin(a * math.pi)
            broomFn = function() return BroomPath.final * CFrame.new(0, -o, 0) end
        end)
        waitPaced(0.06)
    end
    broomFn = function() return BroomPath.final end
    --let go and pull the hand away
    animate(0.15, function(a) handR.open = a end)
    animate(0.35, function(a) handR.grip = 1 - ease(a) end)
    setVisible(handR, false)
    broomFn = nil
    broom:PivotTo(BroomPath.final)
    setPace(1)
end



--one last shove, the broom holds, it gives up and walks off
local function sceneGiveUp()
    playForce()
    animate(0.16, function(a)
        local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        doorsPushed(1.6 * e)
        figDoorPose(e)
        broom:PivotTo(BroomPath.final * CFrame.new(0, 0, 0) + Vector3.new(0.07 * e, 0, 0))
    end)
    shake = 0.7
    animate(0.25, function(a)
        local e = ease(a)
        doorsPushed(1.6 * (1 - e))
        figDoorPose(1 - e * 0.7)
        broom:PivotTo(BroomPath.final + Vector3.new(0.07 * (1 - e), 0, 0))
    end)
    broom:PivotTo(BroomPath.final)
    waitPaced(0.35)
    --a weaker one, the handle bites the broom again
    playForce()
    animate(0.14, function(a)
        local k = math.sin(a * math.pi)
        doorsPushed(1.1 * k)
        figDoorPose(0.3 + 0.4 * k)
        broom:PivotTo(BroomPath.final + Vector3.new(0.05 * k, 0, 0))
    end)
    broom:PivotTo(BroomPath.final)
    doorsPushed(0)
    --hands slide off the glass, it just stares
    local fromR, fromL = figJ.RightShoulder.C0, figJ.LeftShoulder.C0
    local fromRE, fromLE = figJ.RightElbow.C0, figJ.LeftElbow.C0
    local fromW = figJ.Waist.C0
    local fromRW, fromLW = figJ.RightWrist.C0, figJ.LeftWrist.C0
    animate(0.7, function(a)
        local e = ease(a)
        figJ.RightShoulder.C0 = fromR:Lerp(figBase.RightShoulder * CFrame.Angles(math.rad(8), 0, math.rad(-4)), e)
        figJ.LeftShoulder.C0 = fromL:Lerp(figBase.LeftShoulder * CFrame.Angles(math.rad(14), 0, math.rad(4)), e)
        figJ.RightElbow.C0 = fromRE:Lerp(figBase.RightElbow * CFrame.Angles(math.rad(12), 0, 0), e)
        figJ.LeftElbow.C0 = fromLE:Lerp(figBase.LeftElbow * CFrame.Angles(math.rad(18), 0, 0), e)
        figJ.Waist.C0 = fromW:Lerp(figBase.Waist * CFrame.Angles(math.rad(-6), 0, 0), e)
        figJ.RightWrist.C0 = fromRW:Lerp(figBase.RightWrist, e)
        figJ.LeftWrist.C0 = fromLW:Lerp(figBase.LeftWrist, e)
    end)
    fBreath:Play()
    tremble = 0.08
    animate(1.1, function(a) figLook(camera.CFrame.Position, 6 + 22 * ease(a)) end)
    waitPaced(0.5)
    --turns away to the right and goes
    figLeave()
    waitPaced(0.6)
    tremble = 0.04
end

local function sceneLightsOut()
    --plays at double speed
    setPace(0.5)
    --small step back from the door
    parkCharacter()
    local eye = head.Position
    local from = camCF
    local doorLook = CFrame.lookAt(eye, Vector3.new(-60, eye.Y - 0.5, 16))
    animate(0.9, function(a) camCF = from:Lerp(doorLook, ease(a)) end)
    waitPaced(0.4)
    --outside lights begin to fail, eyes drift out through the glass
    tweenNumber(sHeart, "Volume", 0.9, 2)
    local outside = CFrame.lookAt(eye, Vector3.new(-63, eye.Y - 0.2, 16.4))
    task.spawn(function()
        animate(2.6, function(a) camCF = doorLook:Lerp(outside, ease(a) * 0.7) end)
    end)
    exteriorFailure(2.6 * pace)
    shake = 0.15
    --dark and silent
    waitPaced(0.55)
    waitPaced(0.3)
    --and the world outside is gone
    blackout()
    shake = 0.4
    tremble = 0.03
    waitPaced(2.2)
    setPace(1)
end

local function finish()
    --it has to be properly out of sight before the night starts
    local tw = os.clock()
    while not figGone and os.clock() - tw < 8 do RunService.RenderStepped:Wait() end
    --settle exactly where the player's own camera will be
    parkCharacter()
    local eye = head.Position
    local from = camCF
    local final = CFrame.lookAt(eye, Vector3.new(-60, eye.Y - 0.3, 16))
    tremble = 0
    animate(0.6, function(a) camCF = from:Lerp(final, ease(a)) sway = 0.6 * (1 - a) end)
    RunService:UnbindFromRenderStep("IntroCutscene")
    RunService:UnbindFromRenderStep("IntroBroom")
    camera.CFrame = final
    vm:Destroy()
    if fig then fig:Destroy() end
    hideCharacter = false
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
    end
    --hand everything back to the normal systems
    camera.CameraType = Enum.CameraType.Custom
    camera.CFrame = final
    root.Anchored = false
    setControls(true)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
    pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
    player:SetAttribute("IntroDone", true)
    player:SetAttribute("InCutscene", false)
    TweenService:Create(barTop, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Position = UDim2.fromScale(0, -0.1)}):Play()
    TweenService:Create(barBottom, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Position = UDim2.fromScale(0, 1.1)}):Play()
    tweenNumber(sHeart, "Volume", 0, 10)
    skipGui:Destroy()
    if skipping then
        --back in the room with the sound the intro would have left behind
        introGroup.Volume = 1
        TweenService:Create(skipCover, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    end
    task.delay(15, function()
        gui:Destroy()
        for _, snd in ipairs(allSounds) do snd:Destroy() end
    end)
end

---------------------------------------------------------------- run it
--give assets a moment to load behind the black screen
local content = {}
for _, snd in ipairs(allSounds) do table.insert(content, snd) end
pcall(function() game:GetService("ContentProvider"):PreloadAsync(content) end)
task.wait(1)

player:SetAttribute("IntroStage", "car") sceneCar()
player:SetAttribute("IntroStage", "knock") sceneKnock()
player:SetAttribute("IntroStage", "escape") sceneEscape()
player:SetAttribute("IntroStage", "run") sceneRun()
player:SetAttribute("IntroStage", "door") sceneDoor()
player:SetAttribute("IntroStage", "hold") sceneHold()
player:SetAttribute("IntroStage", "broom") sceneBroom()
player:SetAttribute("IntroStage", "giveup") sceneGiveUp()
player:SetAttribute("IntroStage", "lightsout") sceneLightsOut()
player:SetAttribute("IntroStage", "done") finish()
