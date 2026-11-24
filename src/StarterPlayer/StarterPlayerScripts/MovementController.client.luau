local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("MovementConfig"))
local MobileUI = require(game:GetService("ReplicatedStorage"):WaitForChild("MobileUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local character = nil
local humanoid = nil
local root = nil

local stamina = 1
local sprintHeld = false
local sprinting = false
local exhausted = false
local fullTime = 0

local phase = 0
local lastStep = 0
local bobAmount = 0
local sprintBlend = 0
local footsteps = {}
local lastClip = {}


local function lerp(a, b, t)
    return a + (b - a) * t
end


--smooth toward a target no matter the frame rate
local function approach(current, target, rate, dt)
    return current + (target - current) * (1 - math.exp(-rate * dt))
end

--stamina bar ui
local gui = Instance.new("ScreenGui")
gui.Name = "StaminaGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("CanvasGroup")
bar.Name = "StaminaBar"
bar.AnchorPoint = Vector2.new(1, 1)
bar.Position = UDim2.new(1, -15, 1, -24)
bar.Size = UDim2.fromOffset(170, 6)
bar.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
bar.BackgroundTransparency = 0.35
bar.BorderSizePixel = 0
bar.GroupTransparency = 1
bar.Parent = gui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(205, 205, 200)
fill.BorderSizePixel = 0
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

--on a phone the bottom corners belong to the thumbstick and the jump button, so the bar sits bottom middle
MobileUI.watch(function()
    if MobileUI.isCompact() then
        bar.AnchorPoint = Vector2.new(0.5, 1)
        bar.Position = UDim2.new(0.5, 0, 1, -10)
        bar.Size = UDim2.fromOffset(150, 6)
    else
        bar.AnchorPoint = Vector2.new(1, 1)
        bar.Position = UDim2.new(1, -15, 1, -24)
        bar.Size = UDim2.fromOffset(170, 6)
    end
end)

--sprint input, hold to run
local function onSprint(_, state)
    if state == Enum.UserInputState.Begin then
        sprintHeld = true
    elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
        sprintHeld = false
    end
    return Enum.ContextActionResult.Pass
end
--only bound while the player is on their feet, so the phone run button is not left on screen in menus, cutscenes or the camera chair
local sprintBound = false


local function syncSprint()
    local want = not player:GetAttribute("InCutscene") and not player:GetAttribute("Seated") and not player:GetAttribute("Hiding") and not player:GetAttribute("ScreenMessage")
    if want and not sprintBound then
        sprintBound = true
        CAS:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
        CAS:SetTitle("Sprint", "RUN")
        --just up and left of the jump button where the right thumb already is
        CAS:SetPosition("Sprint", UDim2.new(1, -170, 1, -160))
        --bigger than the default button so a thumb finds it without looking
        local b = CAS:GetButton("Sprint")
        if b then b.Size = UDim2.fromOffset(64, 64) end
    elseif not want and sprintBound then
        sprintBound = false
        sprintHeld = false
        CAS:UnbindAction("Sprint")
    end
end
player:GetAttributeChangedSignal("InCutscene"):Connect(syncSprint)
player:GetAttributeChangedSignal("Seated"):Connect(syncSprint)
player:GetAttributeChangedSignal("Hiding"):Connect(syncSprint)
player:GetAttributeChangedSignal("ScreenMessage"):Connect(syncSprint)
syncSprint()


local function playFootstep()
    local surface = Config.SurfaceMap[humanoid.FloorMaterial.Name] or Config.DefaultSurface
    local clips = footsteps[surface]
    if not clips or #clips == 0 then return end
    --never the same clip twice in a row
    local index = math.random(1, #clips)
    if #clips > 1 and index == lastClip[surface] then
        index = index % #clips + 1
    end
    lastClip[surface] = index
    local sound = clips[index]
    local walkPitch = lerp(Config.WalkPitch[1], Config.WalkPitch[2], math.random())
    local sprintPitch = lerp(Config.SprintPitch[1], Config.SprintPitch[2], math.random())
    sound.PlaybackSpeed = lerp(walkPitch, sprintPitch, sprintBlend)
    sound.Volume = lerp(Config.WalkStepVolume, Config.SprintStepVolume, sprintBlend)
    sound.TimePosition = 0
    sound:Play()
end


local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
    humanoid.WalkSpeed = Config.WalkSpeed
    stamina = 1
    exhausted = false
    phase = 0
    lastStep = 0
    bobAmount = 0
    sprintBlend = 0

    --silence the default roblox running sound
    task.spawn(function()
        local running = root:WaitForChild("Running", 10)
        if running then
            running.Volume = 0
            running:GetPropertyChangedSignal("Volume"):Connect(function()
                if running.Volume ~= 0 then running.Volume = 0 end
            end)
        end
    end)

    footsteps = {}
    for surface, ids in pairs(Config.FootstepSounds) do
        footsteps[surface] = {}
        for i, id in ipairs(ids) do
            local s = Instance.new("Sound")
            s.Name = "Footstep" .. surface .. i
            s.SoundId = id
            s.RollOffMinDistance = 5
            s.RollOffMaxDistance = 60
            s.Parent = root
            table.insert(footsteps[surface], s)
        end
    end
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
    task.spawn(setupCharacter, player.Character)
end


local function update(dt)
    if not humanoid or not root or humanoid.Health <= 0 then return end
    --the intro cutscene owns the camera and controls while it plays
    if player:GetAttribute("InCutscene") then
        sprinting = false
        bar.GroupTransparency = 1
        return
    end
    local t = os.clock()

    local vel = root.AssemblyLinearVelocity
    local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local moving = humanoid.MoveDirection.Magnitude > 0.1 and flatSpeed > 1

    --stamina drains only while actually running, refills otherwise
    if exhausted and stamina >= Config.ResumeThreshold then
        exhausted = false
    end
    sprinting = sprintHeld and moving and grounded and not exhausted and stamina > 0
    if sprinting then
        stamina = math.max(0, stamina - dt / Config.SprintDuration)
        if stamina <= 0 then
            exhausted = true
            sprinting = false
        end
    else
        stamina = math.min(1, stamina + dt / Config.RechargeDuration)
    end

    --speed eases between walk and sprint
    local targetSpeed = Config.WalkSpeed
    if sprinting then
        targetSpeed = Config.WalkSpeed * Config.SprintMultiplier
    end
    humanoid.WalkSpeed = approach(humanoid.WalkSpeed, targetSpeed, Config.SpeedSmoothing, dt)
    sprintBlend = approach(sprintBlend, sprinting and 1 or 0, 5, dt)

    --head bob follows the distance actually walked so it always matches speed
    local bobTarget = 0
    if moving and grounded then bobTarget = 1 end
    if bobTarget > bobAmount then
        bobAmount = approach(bobAmount, bobTarget, 7, dt)
    else
        bobAmount = approach(bobAmount, bobTarget, 5, dt)
    end
    if moving and grounded then
        local stride = lerp(Config.WalkStride, Config.SprintStride, sprintBlend)
        phase = phase + flatSpeed / stride * math.pi * dt
        --one footstep every half cycle
        local stepCount = math.floor(phase / math.pi)
        if stepCount ~= lastStep then
            lastStep = stepCount
            playFootstep()
        end
    end

    --small noise so no two steps look identical
    local variation = 1 + math.noise(t * 0.7, 1.3) * 0.3
    local vAmp = lerp(Config.WalkBobVertical, Config.SprintBobVertical, sprintBlend) * bobAmount * variation
    local hAmp = lerp(Config.WalkBobHorizontal, Config.SprintBobHorizontal, sprintBlend) * bobAmount * variation
    local rAmp = lerp(Config.WalkBobRoll, Config.SprintBobRoll, sprintBlend) * bobAmount

    local y = (math.abs(math.sin(phase)) - 0.5) * vAmp * 2
    local x = math.sin(phase) * hAmp
    local roll = math.sin(phase + 0.4) * rAmp

    --breathing sway, heavier when low on stamina
    local tired = math.clamp(1 - stamina / 0.4, 0, 1)
    if exhausted then tired = 1 end
    local breathAmp = lerp(Config.BreathAmount, Config.ExhaustedBreathAmount, tired)
    local breathRate = lerp(1.6, 3.4, tired)
    y = y + math.sin(t * breathRate) * breathAmp

    humanoid.CameraOffset = Vector3.new(x, y, 0)
    camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(roll))
    camera.FieldOfView = approach(camera.FieldOfView, Config.BaseFOV + Config.SprintFOVBoost * sprintBlend, 6, dt)

    --stamina bar
    fill.Size = UDim2.fromScale(stamina, 1)
    if exhausted then
        fill.BackgroundColor3 = Color3.fromRGB(150, 48, 42)
    else
        fill.BackgroundColor3 = Color3.fromRGB(205, 205, 200)
    end
    if stamina >= 1 and not sprinting then
        fullTime = fullTime + dt
    else
        fullTime = 0
    end
    local barTarget = 0
    if fullTime > 1.5 then barTarget = 1 end
    bar.GroupTransparency = approach(bar.GroupTransparency, barTarget, 4, dt)
end

--runs right after the default camera so the bob sits on top of it
RunService:BindToRenderStep("MovementController", Enum.RenderPriority.Camera.Value + 1, update)
