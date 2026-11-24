--monster effects on the player side: camera flash, feed glitches, chase tension and the kill scenes
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local ev = RS:WaitForChild("MonsterEvent")

local FLASH_COOLDOWN = 3
--same as the server, camera power one flash uses
local FLASH_COST = 7
local OFFICE_EYE = Vector3.new(36.2, 4.45, -20)


local function tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end




local function makeSound(id, volume, speed, looped)
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. id
    snd.Volume = volume
    snd.PlaybackSpeed = speed or 1
    snd.Looped = looped or false
    --sounds live in soundservice, playergui gets wiped when the picked body is swapped in
    snd.Parent = game:GetService("SoundService")
    return snd
end
local staticSound = makeSound("96891705634188", 0.35, 1, true)
local shutter = makeSound("9119717286", 0.6, 1.7)
local scream = makeSound("130285917830946", 1.6, 1)
local heart = makeSound("9043365842", 0, 1, true)
heart:Play()

----------------------------------------------------------------- ui
local gui = Instance.new("ScreenGui")
gui.Name = "MonsterGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Parent = playerGui

--feed static made of random grey bars
local static = Instance.new("Frame")
static.Size = UDim2.fromScale(1, 1)
static.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
static.BorderSizePixel = 0
static.Visible = false
static.Parent = gui
local bars = {}
for i = 1, 54 do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(1, 0, 1 / 54, 1)
    b.Position = UDim2.fromScale(0, (i - 1) / 54)
    b.BorderSizePixel = 0
    b.Parent = static
    bars[i] = b
end

local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.Parent = gui

local flashLabel = Instance.new("TextLabel")
flashLabel.AnchorPoint = Vector2.new(0.5, 1)
flashLabel.Position = UDim2.new(0.5, 0, 1, -58)
flashLabel.Size = UDim2.fromOffset(260, 26)
flashLabel.BackgroundTransparency = 1
flashLabel.Font = Enum.Font.Code
flashLabel.TextSize = 17
flashLabel.TextColor3 = Color3.fromRGB(236, 236, 236)
flashLabel.TextStrokeTransparency = 0.5
flashLabel.Text = "FLASH [F]  READY"
flashLabel.Visible = false
flashLabel.Parent = gui

--buttons and hints live in a gui kept inside the safe area
local touchGui = MobileUI.safeGui("MonsterTouch", 26, playerGui)

--big round flash button for thumbs, only on touch screens while watching the cameras
local flashBtn = Instance.new("TextButton")
flashBtn.Name = "FlashButton"
flashBtn.AnchorPoint = Vector2.new(0, 1)
flashBtn.Position = UDim2.new(0, 20, 1, -20)
flashBtn.Size = UDim2.fromOffset(100, 100)
flashBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 230)
flashBtn.BackgroundTransparency = 0.15
flashBtn.BorderSizePixel = 0
flashBtn.AutoButtonColor = false
flashBtn.Font = Enum.Font.GothamBlack
flashBtn.TextSize = 18
flashBtn.TextColor3 = Color3.fromRGB(14, 14, 16)
flashBtn.Text = "FLASH"
flashBtn.Visible = false
flashBtn.Parent = touchGui
local fbc = Instance.new("UICorner") fbc.CornerRadius = UDim.new(1, 0) fbc.Parent = flashBtn
local fbs = Instance.new("UIStroke") fbs.Color = Color3.fromRGB(255, 255, 255) fbs.Thickness = 3 fbs.Transparency = 0.3 fbs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border fbs.Parent = flashBtn
local fbScale = Instance.new("UIScale") fbScale.Parent = flashBtn

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 150)
hint.Size = UDim2.fromOffset(760, 34)
hint.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 17
hint.TextColor3 = Color3.fromRGB(255, 170, 160)
hint.TextTransparency = 1
hint.Text = ""
hint.TextWrapped = true
hint.Parent = touchGui


--phones get a narrower hint up near the top and the flash label is replaced by the button
local function layoutHints()
    local compact = MobileUI.isCompact()
    if compact then
        hint.Position = UDim2.new(0.5, 0, 0, 64)
        hint.Size = UDim2.new(0, math.min(560, workspace.CurrentCamera.ViewportSize.X - 300), 0, 46)
        hint.TextSize = 15
    else
        hint.Position = UDim2.new(0.5, 0, 0, 150)
        hint.Size = UDim2.fromOffset(760, 34)
        hint.TextSize = 17
    end
end
MobileUI.watch(layoutHints)
local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 17)
hc.Parent = hint

--red edges that creep in while it is chasing you
local chaseEdge = Instance.new("Frame")
chaseEdge.Size = UDim2.fromScale(1, 1)
chaseEdge.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
chaseEdge.BackgroundTransparency = 1
chaseEdge.BorderSizePixel = 0
chaseEdge.Parent = gui
local edgeGrad = Instance.new("UIGradient")
edgeGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0)})
edgeGrad.Parent = chaseEdge

local topGui = Instance.new("ScreenGui")
topGui.Name = "MonsterKillGui"
topGui.IgnoreGuiInset = true
topGui.ResetOnSpawn = false
topGui.DisplayOrder = 55
topGui.Parent = playerGui
local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 1
black.BorderSizePixel = 0
black.Parent = topGui

local hintToken = 0

local function showHint(text, seconds)
    hintToken += 1
    local mine = hintToken
    hint.Text = text
    tween(hint, 0.4, {TextTransparency = 0, BackgroundTransparency = 0.35})
    task.delay(seconds, function()
        if hintToken ~= mine then return end
        tween(hint, 0.8, {TextTransparency = 1, BackgroundTransparency = 1})
    end)
end

local staticUntil = 0




local function runStatic(seconds)
    staticUntil = math.max(staticUntil, os.clock() + seconds)
end

local killing = false
local chased = false


local function watching()
    return player:GetAttribute("Seated") == true and not killing
end

local nextFlash = 0
local edgeLevel = 0
RunService.RenderStepped:Connect(function(dt)
    local on = os.clock() < staticUntil
    if on ~= static.Visible then
        static.Visible = on
        if on then staticSound:Play() else staticSound:Stop() end
    end
    if on then
        for _, b in ipairs(bars) do
            local g = math.random(10, 150)
            b.BackgroundColor3 = Color3.fromRGB(g, g, g)
            b.BackgroundTransparency = math.random() * 0.5
        end
    end
    local canFlash = watching() and workspace:GetAttribute("NightActive") == true
    local touch = MobileUI.isTouch()
    flashLabel.Visible = canFlash and not touch
    flashBtn.Visible = canFlash and touch
    local powered = (player:GetAttribute("CamPower") or 100) >= FLASH_COST
    local ready = os.clock() >= nextFlash and powered
    if flashLabel.Visible then
        flashLabel.Text = (not powered and "FLASH  NO POWER") or (ready and "FLASH [F]  READY") or "FLASH  CHARGING"
        flashLabel.TextColor3 = ready and Color3.fromRGB(236, 236, 236) or Color3.fromRGB(130, 130, 130)
    end
    if flashBtn.Visible then
        --greys out while it charges so a thumb knows when it will work again
        flashBtn.Text = (not powered and "NO POWER") or (ready and "FLASH") or "..."
        flashBtn.BackgroundTransparency = ready and 0.15 or 0.65
        fbs.Transparency = ready and 0.3 or 0.8
    end

    --heartbeat and red edges get stronger the closer it is to you on foot
    local rig = workspace:FindFirstChild("NightMonster")
    local mroot = rig and rig:FindFirstChild("HumanoidRootPart")
    local char = player.Character
    local proot = char and char:FindFirstChild("HumanoidRootPart")
    local near = 0
    if mroot and proot and mroot.Position.Y > -100 and not player:GetAttribute("Seated") then
        local d = (mroot.Position - proot.Position).Magnitude
        near = math.clamp((45 - d) / 35, 0, 1)
    end
    if chased then near = math.max(near, 0.6) end
    heart.Volume = heart.Volume + (near * 0.9 - heart.Volume) * math.min(1, dt * 3)
    heart.PlaybackSpeed = 1 + near * 0.7
    local want = chased and (0.55 + 0.15 * math.sin(os.clock() * 6)) or 0
    edgeLevel = edgeLevel + (want - edgeLevel) * math.min(1, dt * 4)
    chaseEdge.BackgroundTransparency = 1 - edgeLevel
end)


local function doFlash()
    if not watching() or os.clock() < nextFlash then return end
    if (player:GetAttribute("CamPower") or 100) < FLASH_COST then return end
    nextFlash = os.clock() + FLASH_COOLDOWN
    ev:FireServer("flash")
    player:SetAttribute("CamFlash", os.clock())
    shutter:Play()
    --just a little lens bloom, the real light comes from the camera lamp
    flashFrame.BackgroundTransparency = 0.72
    tween(flashFrame, 0.3, {BackgroundTransparency = 1})
end

UIS.InputBegan:Connect(function(input, typing)
    if typing or input.KeyCode ~= Enum.KeyCode.F then return end
    doFlash()
end)
--fires the moment the thumb lands, not when it lifts, so it is as quick as the key
flashBtn.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    fbScale.Scale = 0.9
    tween(fbScale, 0.2, {Scale = 1})
    doFlash()
end)

----------------------------------------------------------------- kill scenes



local function animate(seconds, fn)
    local t = 0
    while t < seconds do
        t += RunService.RenderStepped:Wait()
        fn(math.clamp(t / seconds, 0, 1))
    end
end


local function lockControls(on)
    if on then
        CAS:BindActionAtPriority("MonsterKillLock", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 500,
            Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA)
    else
        CAS:UnbindAction("MonsterKillLock")
    end
    local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
    if pm then
        local ok, mod = pcall(require, pm)
        if ok then
            local controls = mod:GetControls()
            if on then controls:Disable() else controls:Enable() end
        end
    end
end



local function killScene(kind)
    if killing then return end
    killing = true
    chased = false
    local rig = workspace:FindFirstChild("NightMonster")
    local root = rig and rig:FindFirstChild("HumanoidRootPart")
    local head = rig and rig:FindFirstChild("Head")
    local monitor = playerGui:FindFirstChild("SecurityMonitor")
    local monitorWasOn = monitor and monitor.Enabled
    if monitor then monitor.Enabled = false end
    local grade = camera:FindFirstChild("SecurityGrade")
    local gradeWasOn = grade and grade.Enabled
    if grade then grade.Enabled = false end
    lockControls(true)

    local eye, camCF
    if kind == "office" then
        eye = OFFICE_EYE
        camCF = CFrame.lookAt(OFFICE_EYE, OFFICE_EYE + Vector3.new(1, -0.15, 0))
    else
        eye = camera.CFrame.Position
        camCF = camera.CFrame
    end
    local fov = kind == "office" and 62 or camera.FieldOfView
    local shake = 0
    --runs after every other camera script so it wins the camera
    RunService:BindToRenderStep("MonsterKill", Enum.RenderPriority.Last.Value + 5, function()
        local t = os.clock()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.FieldOfView = fov
        camera.CFrame = camCF * CFrame.new(math.noise(t * 30, 1) * shake * 0.35, math.noise(t * 30, 2) * shake * 0.35, 0) * CFrame.Angles(0, 0, math.noise(t * 24, 3) * shake * 0.12)
    end)

    if kind == "office" then
        --the feed dies and the office is quiet
        runStatic(0.4)
        task.wait(1.1)
    else
        task.wait(0.1)
    end
    local doorLook = head and head.Position or eye + camCF.LookVector * 4
    local from = camCF
    local to = CFrame.lookAt(eye, doorLook)
    animate(kind == "office" and 0.9 or 0.35, function(a)
        local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        camCF = from:Lerp(to, e)
    end)
    local light = nil
    if head then
        light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 225, 210)
        light.Brightness = 1.2
        light.Range = 9
        light.Parent = head
    end
    task.wait(kind == "office" and 0.55 or 0.25)

    --lunge straight at the face
    scream:Play()
    shake = 1
    if root and head then
        local start = root.CFrame
        local headUp = head.Position.Y - root.Position.Y
        local flatTo = Vector3.new(start.Position.X - eye.X, 0, start.Position.Z - eye.Z)
        local toward = flatTo.Magnitude > 0.1 and flatTo.Unit or Vector3.new(0, 0, 1)
        local targetPos = Vector3.new(eye.X, eye.Y - headUp + 0.05, eye.Z) + toward * 1.55
        local target = CFrame.lookAt(targetPos, Vector3.new(eye.X, targetPos.Y, eye.Z))
        animate(0.15, function(a)
            root.CFrame = start:Lerp(target, a)
            camCF = CFrame.lookAt(eye, head.Position)
            fov = fov + (44 - fov) * a
        end)
        if light then
            light.Brightness = 3
            light.Range = 14
        end
        local t0 = os.clock()
        while os.clock() - t0 < 0.6 do
            --shaking in the players face
            root.CFrame = target * CFrame.new(math.random(-10, 10) / 100, math.random(-10, 10) / 100, 0) * CFrame.Angles(0, 0, math.rad(math.random(-8, 8)))
            camCF = CFrame.lookAt(eye, head.Position)
            flashFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
            flashFrame.BackgroundTransparency = 0.55 + math.random() * 0.4
            RunService.RenderStepped:Wait()
        end
    else
        task.wait(0.75)
    end
    flashFrame.BackgroundTransparency = 1
    flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    black.BackgroundTransparency = 0
    tween(scream, 0.5, {Volume = 0})
    task.wait(3)
    RunService:UnbindFromRenderStep("MonsterKill")
    scream:Stop()
    scream.Volume = 1.6
    if light then light:Destroy() end
    if monitor then monitor.Enabled = monitorWasOn end
    if grade then grade.Enabled = gradeWasOn end
    if not player:GetAttribute("Seated") then
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = 75
    end
    lockControls(false)
    killing = false
    task.wait(1.2)
    tween(black, 1.2, {BackgroundTransparency = 1})
end

----------------------------------------------------------------- server messages
ev.OnClientEvent:Connect(function(kind, a, b)
    if kind == "moved" then
        --no sound when it moves somewhere
    elseif kind == "seen" then
        if watching() then
            runStatic(0.14)
        end
    elseif kind == "stare" then
        if watching() then
            runStatic(0.08)
        end
    elseif kind == "scared" then
        chased = false
        if watching() then runStatic(0.15) end
        showHint("it ran off... for now", 3)
    elseif kind == "hunt" then
        if a == player.UserId then
            chased = true
            if player:GetAttribute("Seated") then
                showHint("it got inside.  leave the cameras" .. MobileUI.key(" [Q]") .. " and shut the office door", 5)
            else
                showHint("it got inside.  get to the office and shut the door", 4)
            end
        end
    elseif kind == "huntEnd" then
        if a == player.UserId and chased then
            chased = false
            showHint("it's leaving", 3)
        end
    elseif kind == "doorOpening" then
        showHint("the office door is opening", 3)
    elseif kind == "kill" then
        if b == player.UserId or (a == "office" and b == nil) then
            task.spawn(killScene, a)
        end
    end
end)




--the intro figure leaves once the real night starts
local function hideIntroFigure()
    local fig = workspace:FindFirstChild("ChipotleMap") and workspace.ChipotleMap:FindFirstChild("TheFigure")
    if not fig then return end
    for _, p in ipairs(fig:GetDescendants()) do
        if p:IsA("BasePart") then p.CFrame = CFrame.new(0, -200, 0) end
    end
end

workspace:GetAttributeChangedSignal("NightActive"):Connect(function()
    if workspace:GetAttribute("NightActive") then
        chased = false
        hideIntroFigure()
        task.delay(5, function()
            showHint("something is trying to get in.  find it on the cameras and flash it" .. MobileUI.key("  [F]"), 8)
        end)
    else
        chased = false
    end
end)
