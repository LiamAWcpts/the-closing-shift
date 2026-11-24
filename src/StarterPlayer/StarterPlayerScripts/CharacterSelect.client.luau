--difficulty screen shown after play, everyone uses their own avatar so there is no character pick
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MobileUI = require(ReplicatedStorage:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
--runs on joining, and again whenever a won night sends the player back here
if player:GetAttribute("CharacterPicked") then return end
player:SetAttribute("InCutscene", true)
player:SetAttribute("SelectedMonster", "Monster1")

--the main menu comes first
while not player:GetAttribute("MenuDone") do task.wait(0.1) end

--a black cover sits just under the menu's own fade, so nothing shows through while the menu finishes
local earlyCover = Instance.new("ScreenGui")
earlyCover.Name = "DifficultyCover"
earlyCover.IgnoreGuiInset = true
earlyCover.ResetOnSpawn = false
earlyCover.DisplayOrder = 103
local coverFrame = Instance.new("Frame")
coverFrame.Size = UDim2.fromScale(1, 1)
coverFrame.BackgroundColor3 = Color3.new(0, 0, 0)
coverFrame.BorderSizePixel = 0
coverFrame.Parent = earlyCover
earlyCover.Parent = player:WaitForChild("PlayerGui")
--wait for the main menu to finish fading to black and close before this screen starts
local waitStart = os.clock()
while player.PlayerGui:FindFirstChild("MainMenu") and os.clock() - waitStart < 5 do task.wait(0.05) end
task.wait(0.3)

local camera = workspace.CurrentCamera
local WARM = Color3.fromRGB(255, 232, 196)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)


local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

----------------------------------------------------------------- sounds
local soundHolder = Instance.new("Folder")
soundHolder.Name = "DifficultySounds"
soundHolder.Parent = workspace



local function makeSound(id, volume, speed, looped)
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = volume
    snd.PlaybackSpeed = speed
    snd.Looped = looped or false
    snd.Parent = soundHolder
    return snd
end
local clickSound = makeSound("rbxassetid://9119717286", 0.35, 1)
local audioIds = require(ReplicatedStorage:WaitForChild("AudioIds"))
local drone = makeSound(audioIds.selectTheme ~= "" and "rbxassetid://" .. audioIds.selectTheme or "", 0, 1, true)
local muffle = Instance.new("EqualizerSoundEffect")
muffle.LowGain = 2 muffle.MidGain = -3 muffle.HighGain = -12
muffle.Parent = drone
if audioIds.selectTheme ~= "" then drone:Play() end
tween(drone, 3, {Volume = 0.45})

----------------------------------------------------------------- input lock
CAS:BindActionAtPriority("SelectBlock", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 300,
    Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.Thumbstick1, Enum.KeyCode.V)

----------------------------------------------------------------- guis
local gui = Instance.new("ScreenGui")
gui.Name = "CharacterSelectGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")
--text and buttons live in a second gui kept inside the safe area
local hud = MobileUI.safeGui("CharacterSelectHud", 101, player.PlayerGui)
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "CharacterSelectFade"
fadeGui.IgnoreGuiInset = true
fadeGui.ResetOnSpawn = false
fadeGui.DisplayOrder = 102
fadeGui.Parent = player.PlayerGui
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BorderSizePixel = 0
fade.ZIndex = 50
fade.Parent = fadeGui
--this screen's own black is in place now, the early cover can go
earlyCover:Destroy()

----------------------------------------------------------------- store shots behind the screen
--the same slow camera moves as the main menu, each one dips through black into the next
local V = Vector3.new
local SHOTS = {
    {from = CFrame.lookAt(V(-18, 8, 58), V(-45, 4, 22)), to = CFrame.lookAt(V(-6, 8.5, 60), V(-38, 4, 22)), time = 9},
    {from = CFrame.lookAt(V(-79, 6.2, 37), V(-58, 4.5, 18)), to = CFrame.lookAt(V(-73, 5.6, 31), V(-57, 4.5, 17)), time = 8},
    {from = CFrame.lookAt(V(-51, 6.5, 13), V(-15, 3.5, -8)), to = CFrame.lookAt(V(-55, 6.4, 8), V(-12, 3.5, -12)), time = 8},
    {from = CFrame.lookAt(V(21, 5.2, -8.5), V(35, 4.5, -13)), to = CFrame.lookAt(V(25, 5, -10), V(35, 4.3, -13.5)), time = 8},
}
local DIP = 0.8
local dip = Instance.new("Frame")
dip.Size = UDim2.fromScale(1, 1)
dip.BackgroundColor3 = Color3.new(0, 0, 0)
dip.BackgroundTransparency = 0
dip.BorderSizePixel = 0
dip.ZIndex = 1
dip.Parent = gui
local cineOn = true
local shotFrom, shotTo, shotStart, shotTime = nil, nil, 0, 1




--every character and the intro figure are hidden from the shots
local function shotHidden()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(list, p.Character) end
    end
    local map = workspace:FindFirstChild("ChipotleMap")
    local fig = map and map:FindFirstChild("TheFigure")
    if fig then table.insert(list, fig) end
    return list
end


local function setHidden(on)
    for _, c in ipairs(shotHidden()) do
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
        end
    end
end
RunService:BindToRenderStep("SelectView", Enum.RenderPriority.Camera.Value + 1, function()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    if not shotFrom then return end
    local a = math.clamp((os.clock() - shotStart) / shotTime, 0, 1)
    local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = shotFrom:Lerp(shotTo, e)
    camera.FieldOfView = 60
    setHidden(true)
end)
task.spawn(function()
    local i = math.random(1, #SHOTS)
    while cineOn do
        local s = SHOTS[i]
        pcall(function() player:RequestStreamAroundAsync(s.to.Position, 4) end)
        if not cineOn then break end
        shotFrom, shotTo, shotStart, shotTime = s.from, s.to, os.clock(), s.time
        tween(dip, DIP, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
        local t0 = os.clock()
        while cineOn and os.clock() - t0 < s.time - DIP do task.wait(0.1) end
        if not cineOn then break end
        tween(dip, DIP, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine)
        task.wait(DIP)
        i = i % #SHOTS + 1
    end
end)

----------------------------------------------------------------- difficulty
local DIFFS = {
    {name = "Easy", color = Color3.fromRGB(56, 150, 88), deep = Color3.fromRGB(5, 20, 10), text = Color3.fromRGB(190, 240, 200)},
    {name = "Normal", color = Color3.fromRGB(52, 104, 178), deep = Color3.fromRGB(4, 11, 24), text = Color3.fromRGB(190, 214, 250)},
    {name = "Hard", color = Color3.fromRGB(178, 40, 38), deep = Color3.fromRGB(24, 3, 3), text = Color3.fromRGB(250, 190, 185)},
}
local diffIndex = 2
local done = false

--coloured layer over the store shots, see through so they keep playing behind it
local diffLayer = Instance.new("Frame")
diffLayer.Name = "Difficulty"
diffLayer.Size = UDim2.fromScale(1, 1)
diffLayer.BorderSizePixel = 0
diffLayer.BackgroundTransparency = 0.55
diffLayer.ZIndex = 30
diffLayer.Parent = gui
local diffGlow = {}
for i = 0, 17 do
    local s = 1.3 - i * 0.064
    local c = Instance.new("Frame")
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Position = UDim2.fromScale(0.5, 0.46)
    c.Size = UDim2.fromScale(s, s)
    c.SizeConstraint = Enum.SizeConstraint.RelativeXX
    c.BackgroundTransparency = 0.978
    c.BorderSizePixel = 0
    c.ZIndex = 31
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(1, 0) cc.Parent = c
    c.Parent = diffLayer
    table.insert(diffGlow, c)
end
--dark edges top and bottom
for _, rot in ipairs({90, 270}) do
    local v = Instance.new("Frame")
    v.Size = UDim2.fromScale(1, 1)
    v.BackgroundColor3 = Color3.new(0, 0, 0)
    v.BackgroundTransparency = 0
    v.BorderSizePixel = 0
    v.ZIndex = 32
    local g = Instance.new("UIGradient")
    g.Rotation = rot
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = v
    v.Parent = diffLayer
end
--slow drifting specks
for i = 1, 26 do
    local s = Instance.new("Frame")
    s.Size = UDim2.fromOffset(2, 2)
    s.Position = UDim2.fromScale(math.random(), math.random())
    s.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    s.BackgroundTransparency = 0.75 + math.random() * 0.2
    s.BorderSizePixel = 0
    s.ZIndex = 33
    s.Parent = diffLayer
    task.spawn(function()
        local speed = 0.004 + math.random() * 0.01
        while s.Parent do
            local p = s.Position
            local y = p.Y.Scale - speed * 0.05
            if y < -0.02 then y = 1.02 end
            s.Position = UDim2.fromScale(p.X.Scale + math.sin(os.clock() + i) * 0.0002, y)
            task.wait(0.05)
        end
    end)
end


local function textLabel(t, size, font, color)
    local l = Instance.new("TextLabel")
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.BackgroundTransparency = 1
    l.Font = font
    l.TextSize = size
    l.TextColor3 = color
    l.Text = t
    l.ZIndex = 5
    l.Parent = hud
    return l
end
local title = textLabel("choose your difficulty", 17, Enum.Font.GothamMedium, Color3.fromRGB(200, 200, 200))
title.Size = UDim2.fromOffset(700, 29)
local diffName = textLabel("NORMAL", 84, Enum.Font.GothamBlack, Color3.fromRGB(240, 240, 240))
diffName.TextStrokeTransparency = 0.7
local nightLabel = textLabel("night 1 of 5", 20, Enum.Font.GothamMedium, Color3.fromRGB(220, 220, 220))
nightLabel.Size = UDim2.fromOffset(600, 28)


local function hoverable(b, baseStroke)
    local sc = Instance.new("UIScale")
    sc.Parent = b
    local st = b:FindFirstChildOfClass("UIStroke")
    b.MouseEnter:Connect(function()
        tween(sc, 0.18, {Scale = 1.08})
        if st then tween(st, 0.18, {Transparency = 0.1}) end
    end)
    b.MouseLeave:Connect(function()
        tween(sc, 0.18, {Scale = 1})
        if st then tween(st, 0.18, {Transparency = baseStroke}) end
    end)
    b.MouseButton1Down:Connect(function() tween(sc, 0.08, {Scale = 0.94}) end)
    b.MouseButton1Up:Connect(function() tween(sc, 0.15, {Scale = 1.08}) end)
end


local function arrow(t)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    b.BackgroundTransparency = 0.35
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 26
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Text = t
    b.ZIndex = 6
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = b
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(255, 255, 255)
    st.Transparency = 0.75
    st.Thickness = 1.2
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Parent = b
    b.Parent = hud
    hoverable(b, 0.75)
    return b
end
local leftBtn = arrow("<")
local rightBtn = arrow(">")

local playBtn = Instance.new("TextButton")
playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
playBtn.BackgroundColor3 = Color3.fromRGB(240, 238, 234)
playBtn.BorderSizePixel = 0
playBtn.AutoButtonColor = false
playBtn.Font = Enum.Font.GothamBold
playBtn.TextSize = 17
playBtn.TextColor3 = Color3.fromRGB(12, 12, 12)
playBtn.Text = "start"
playBtn.ZIndex = 6
local pcorner = Instance.new("UICorner") pcorner.CornerRadius = UDim.new(1, 0) pcorner.Parent = playBtn
local pstroke = Instance.new("UIStroke")
pstroke.Color = WARM
pstroke.Thickness = 2
pstroke.Transparency = 0.6
pstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pstroke.Parent = playBtn
playBtn.Parent = hud
hoverable(playBtn, 0.6)

--the three choices side by side so the player always sees where they are
local diffTabs = {}
for i, d in ipairs(DIFFS) do
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.Text = string.upper(d.name)
    b.ZIndex = 5
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(1, 0) cc.Parent = b
    b.Parent = hud
    diffTabs[i] = b
end


--positions and sizes for a big screen or a phone
local function layout()
    local compact = MobileUI.isCompact()
    if compact then
        title.AnchorPoint = Vector2.new(0.5, 0)
        title.Position = UDim2.new(0.5, 0, 0, 8)
        title.TextSize = 15
        playBtn.AnchorPoint = Vector2.new(0.5, 1)
        playBtn.Position = UDim2.new(0.5, 0, 1, -14)
        playBtn.Size = UDim2.fromOffset(180, 48)
        leftBtn.Position = UDim2.new(0, 52, 0.5, 0)
        rightBtn.Position = UDim2.new(1, -52, 0.5, 0)
        leftBtn.Size = UDim2.fromOffset(64, 64)
        rightBtn.Size = UDim2.fromOffset(64, 64)
    else
        title.AnchorPoint = Vector2.new(0.5, 0.5)
        title.Position = UDim2.new(0.5, 0, 0.075, 0)
        title.TextSize = 17
        playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
        playBtn.Position = UDim2.fromScale(0.5, 0.91)
        playBtn.Size = UDim2.fromOffset(190, 46)
        leftBtn.Position = UDim2.fromScale(0.37, 0.47)
        rightBtn.Position = UDim2.fromScale(0.63, 0.47)
        leftBtn.Size = UDim2.fromOffset(56, 56)
        rightBtn.Size = UDim2.fromOffset(56, 56)
    end
    diffName.TextSize = compact and 60 or 84
    diffName.Size = UDim2.fromOffset(compact and 560 or 820, compact and 72 or 98)
    diffName.Position = UDim2.fromScale(0.5, compact and 0.36 or 0.4)
    nightLabel.TextSize = compact and 16 or 20
    nightLabel.Position = UDim2.fromScale(0.5, compact and 0.48 or 0.52)
    for i, b in ipairs(diffTabs) do
        b.Size = UDim2.fromOffset(compact and 112 or 130, compact and 44 or 36)
        b.Position = UDim2.new(0.5, (i - 2) * (compact and 124 or 150), compact and 0.62 or 0.7, 0)
        b.TextSize = compact and 14 or 15
    end
end
MobileUI.watch(layout)

local function paintDifficulty(instant)
    local d = DIFFS[diffIndex]
    local time = instant and 0 or 0.5
    tween(diffLayer, time, {BackgroundColor3 = d.deep}, Enum.EasingStyle.Sine)
    for _, g in ipairs(diffGlow) do tween(g, time, {BackgroundColor3 = d.color}, Enum.EasingStyle.Sine) end
    diffName.Text = string.upper(d.name)
    tween(diffName, time, {TextColor3 = d.text}, Enum.EasingStyle.Sine)
    local n = player:GetAttribute("Night_" .. d.name) or 1
    local beat = player:GetAttribute("Beat_" .. d.name) == true
    nightLabel.Text = beat and "all 5 nights beaten  -  replaying night 5" or string.format("night %d of 5", n)
    tween(nightLabel, time, {TextColor3 = d.text}, Enum.EasingStyle.Sine)
    for i, tab in ipairs(diffTabs) do
        local on = i == diffIndex
        tween(tab, 0.25, {BackgroundTransparency = on and 0.1 or 0.85, BackgroundColor3 = on and DIFFS[i].color or Color3.fromRGB(255, 255, 255), TextColor3 = on and Color3.fromRGB(250, 250, 250) or Color3.fromRGB(150, 150, 150)})
    end
end
paintDifficulty(true)




local function step(dir)
    if done then return end
    diffIndex += dir
    if diffIndex < 1 then diffIndex = #DIFFS end
    if diffIndex > #DIFFS then diffIndex = 1 end
    clickSound:Play()
    paintDifficulty(false)
end
for i, b in ipairs(diffTabs) do
    b.MouseButton1Click:Connect(function()
        if done or diffIndex == i then return end
        diffIndex = i
        clickSound:Play()
        paintDifficulty(false)
    end)
end

----------------------------------------------------------------- votes
--everyone's votes show as small dots under the tabs, and a thin bar runs down under start while the vote is open
local voteResult = nil
local voteDots = {}
local voteBar = nil




local function showVotes(counts, left, total)
    for i, b in ipairs(diffTabs) do
        local holder = voteDots[i]
        if not holder then
            holder = Instance.new("Frame")
            holder.AnchorPoint = Vector2.new(0.5, 0)
            holder.Position = UDim2.new(0.5, 0, 1, 8)
            holder.Size = UDim2.fromOffset(100, 8)
            holder.BackgroundTransparency = 1
            holder.ZIndex = 5
            local l = Instance.new("UIListLayout")
            l.FillDirection = Enum.FillDirection.Horizontal
            l.HorizontalAlignment = Enum.HorizontalAlignment.Center
            l.Padding = UDim.new(0, 6)
            l.Parent = holder
            holder.Parent = b
            voteDots[i] = holder
        end
        for _, c in ipairs(holder:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _ = 1, (counts[DIFFS[i].name] or 0) do
            local d = Instance.new("Frame")
            d.Size = UDim2.fromOffset(8, 8)
            d.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            d.BorderSizePixel = 0
            d.ZIndex = 5
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = d
            d.Parent = holder
        end
    end
    if not voteBar then
        voteBar = Instance.new("Frame")
        voteBar.AnchorPoint = Vector2.new(0.5, 0)
        voteBar.Position = UDim2.new(0.5, 0, 1, 10)
        voteBar.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        voteBar.BorderSizePixel = 0
        voteBar.ZIndex = playBtn.ZIndex
        voteBar.Parent = playBtn
    end
    voteBar.Size = UDim2.new(left / total, 0, 0, 3)
    TweenService:Create(voteBar, TweenInfo.new(left, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)}):Play()
end
ReplicatedStorage:WaitForChild("NightEvent").OnClientEvent:Connect(function(kind, a, b, c)
    if kind == "voteState" then
        showVotes(a, b, c)
    elseif kind == "voteResult" then
        voteResult = a
    end
end)

----------------------------------------------------------------- finish


local function cleanup()
    cineOn = false
    RunService:UnbindFromRenderStep("SelectView")
    CAS:UnbindAction("SelectBlock")
    CAS:UnbindAction("SelectSwitch")
    setHidden(false)
    soundHolder:Destroy()
end


local function closeOut()
    tween(drone, 1.4, {Volume = 0})
    task.wait(0.3)
    tween(fade, 1, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
    task.wait(0.3)
    cleanup()
    player:SetAttribute("CharacterPicked", true)
    --the black stays up until the intro has its own screen running, so the store never flashes in between
    local holdStart = os.clock()
    while os.clock() - holdStart < 8 do
        --first time in: the intro's first scene is running
        if not player:GetAttribute("IntroDone") and player:GetAttribute("IntroStage") then break end
        --back after a night: they are standing in the store again
        if player:GetAttribute("IntroDone") and not player:GetAttribute("InCutscene") then break end
        --joined mid night: straight to watching
        if player:GetAttribute("Waiting") then break end
        task.wait(0.05)
    end
    --the other layers go first while the black still covers them, then the black eases off into the intro
    gui:Destroy()
    hud:Destroy()
    task.wait(0.2)
    tween(fade, 0.9, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
    fadeGui:Destroy()
end


--this player's vote goes in, then everyone waits for the server's pick and the game starts
local function confirmDifficulty()
    if done then return end
    done = true
    clickSound:Play()
    ReplicatedStorage:WaitForChild("NightEvent"):FireServer("voteDifficulty", DIFFS[diffIndex].name)
    tween(playBtn, 0.2, {BackgroundTransparency = 0.6})
    while not voteResult do task.wait(0.1) end
    for i, dd in ipairs(DIFFS) do
        if dd.name == voteResult then diffIndex = i end
    end
    paintDifficulty(false)
    task.wait(0.8)
    player:SetAttribute("Difficulty", DIFFS[diffIndex].name)
    closeOut()
end

leftBtn.MouseButton1Click:Connect(function() step(-1) end)
rightBtn.MouseButton1Click:Connect(function() step(1) end)
playBtn.MouseButton1Click:Connect(function() task.spawn(confirmDifficulty) end)

CAS:BindActionAtPriority("SelectSwitch", function(_, state, input)
    if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
    local k = input.KeyCode
    if k == Enum.KeyCode.A or k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then step(-1)
    elseif k == Enum.KeyCode.D or k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then step(1)
    elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then task.spawn(confirmDifficulty) end
    return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 400,
    Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)

--a sideways swipe on a phone flips the difficulty the same as the arrows
UIS.TouchSwipe:Connect(function(direction, touches)
    if done or touches ~= 1 then return end
    if direction == Enum.SwipeDirection.Left then step(1)
    elseif direction == Enum.SwipeDirection.Right then step(-1) end
end)

--slow breathing glow on the start button outline
task.spawn(function()
    while gui.Parent and not done do
        tween(pstroke, 1.4, {Transparency = 0.2}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
        if done then break end
        tween(pstroke, 1.4, {Transparency = 0.7}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
    end
end)

----------------------------------------------------------------- opening
--a night already running has its difficulty, they go straight in to watch
if workspace:GetAttribute("NightActive") then
    done = true
    ReplicatedStorage:WaitForChild("CharacterPick"):FireServer()
    closeOut()
    return
end
--let the first store shot settle behind the black before lifting it
task.wait(0.5)
tween(fade, 1.6, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
