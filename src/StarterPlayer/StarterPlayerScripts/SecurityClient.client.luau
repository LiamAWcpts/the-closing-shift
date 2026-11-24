--objective prompt, sitting at the office chair and the security camera monitor
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ev = RS:WaitForChild("SecurityEvent")
local camData = RS:WaitForChild("SecurityCams")
local playerGui = player:WaitForChild("PlayerGui")

local CHIME = "rbxassetid://4612374393"
local BEEP = "rbxassetid://9113938822"
local LATCH = "rbxassetid://9114142431"
--wide angle security lens
local FEED_FOV = 88



local function makeSound(id, volume, speed)
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = volume
    snd.PlaybackSpeed = speed or 1
    --sounds live in soundservice, playergui gets wiped when the picked body is swapped in
    snd.Parent = game:GetService("SoundService")
    return snd
end
local chime = makeSound(CHIME, 0.22, 0.8)
local beep = makeSound(BEEP, 0.12, 0.7)
local latch = makeSound(LATCH, 0.25, 0.9)

local function tween(obj, time, props, style)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
    t:Play()
    return t
end

----------------------------------------------------------------- camera list
local cams = {}
for _, c in ipairs(camData:GetChildren()) do
    table.insert(cams, {id = c:GetAttribute("Id"), label = c:GetAttribute("Label"), pos = c:GetAttribute("Pos"), target = c:GetAttribute("Target")})
end
table.sort(cams, function(a, b) return a.id < b.id end)

--where each button sits on the little map (0 to 1)
local mapSpot = {
    [1] = Vector2.new(0.07, 0.14),
    [2] = Vector2.new(0.52, 0.10),
    [3] = Vector2.new(0.63, 0.33),
    [4] = Vector2.new(0.75, 0.10),
    [5] = Vector2.new(0.55, 0.66),
    [6] = Vector2.new(0.80, 0.62),
    [7] = Vector2.new(0.93, 0.14),
    --pickup window down in the kitchen hallway
    [8] = Vector2.new(0.24, 0.86),
}

----------------------------------------------------------------- objective text


local function showObjective()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ObjectiveGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 5
    gui.Parent = playerGui

    local pill = Instance.new("Frame")
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, -60)
    pill.Size = UDim2.fromOffset(230, 36)
    pill.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    pill.BackgroundTransparency = 1
    pill.Parent = gui
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(1, 0) corner.Parent = pill
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 255, 255) stroke.Transparency = 1 stroke.Thickness = 1 stroke.Parent = pill

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    --clock in first, then the office
    local function objectiveText()
        label.Text = player:GetAttribute("ClockedIn") and "get to the office" or "clock in at the ipad"
    end
    objectiveText()
    player:GetAttributeChangedSignal("ClockedIn"):Connect(objectiveText)
    label.TextSize = 16
    label.TextColor3 = Color3.fromRGB(228, 228, 228)
    label.TextTransparency = 1
    label.Parent = pill

    chime:Play()
    tween(pill, 1.2, {Position = UDim2.new(0.5, 0, 0, 26), BackgroundTransparency = 0.4})
    tween(stroke, 1.2, {Transparency = 0.82})
    tween(label, 1.2, {TextTransparency = 0})

    --slow float so it feels like it is hovering
    local alive = true
    task.spawn(function()
        task.wait(1.3)
        local t0 = os.clock()
        while alive do
            pill.Position = UDim2.new(0.5, 0, 0, 26 + math.sin((os.clock() - t0) * 1.6) * 2.5)
            RunService.RenderStepped:Wait()
        end
    end)

    return function()
        alive = false
        tween(pill, 0.8, {BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, -20)})
        tween(stroke, 0.8, {Transparency = 1})
        tween(label, 0.8, {TextTransparency = 1})
        task.delay(1, function() gui:Destroy() end)
    end
end

local hideObjective = nil
task.spawn(function()
    while not player:GetAttribute("IntroDone") do task.wait(0.5) end
    task.wait(2.5)
    if not player:GetAttribute("Seated") then hideObjective = showObjective() end
end)

----------------------------------------------------------------- fade screen
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "SecFade"
fadeGui.IgnoreGuiInset = true
fadeGui.ResetOnSpawn = false
fadeGui.DisplayOrder = 100
fadeGui.Parent = playerGui
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Parent = fadeGui

local function fadeTo(alpha, time)
    local t = tween(fade, time, {BackgroundTransparency = alpha})
    t.Completed:Wait()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
    if prompt.Name == "ChairPrompt" and not player:GetAttribute("InCutscene") and player:GetAttribute("ClockedIn") then
        tween(fade, 0.12, {BackgroundTransparency = 0})
    end
end)

----------------------------------------------------------------- monitor ui
local mon = Instance.new("ScreenGui")
mon.Name = "SecurityMonitor"
mon.IgnoreGuiInset = true
mon.ResetOnSpawn = false
mon.DisplayOrder = 20
mon.Enabled = false
mon.Parent = playerGui
--text and buttons sit in a second gui inside the safe area, it shows and hides with the monitor
local ctrl = MobileUI.safeGui("SecurityControls", 21, playerGui)
ctrl.Enabled = false
mon:GetPropertyChangedSignal("Enabled"):Connect(function() ctrl.Enabled = mon.Enabled end)


local function edge(anchor, pos, size, rotation)
    local f = Instance.new("Frame")
    f.AnchorPoint = anchor
    f.Position = pos
    f.Size = size
    f.BackgroundColor3 = Color3.new(0, 0, 0)
    f.BorderSizePixel = 0
    local g = Instance.new("UIGradient")
    g.Rotation = rotation
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = f
    f.Parent = mon
end
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), 90)
edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.2), 270)
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.12, 1), 0)
edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.12, 1), 180)

--scan lines
local lines = Instance.new("Frame")
lines.Size = UDim2.fromScale(1, 1)
lines.BackgroundTransparency = 1
lines.Parent = mon
for i = 0, 89 do
    local l = Instance.new("Frame")
    l.Size = UDim2.new(1, 0, 0, 1)
    l.Position = UDim2.fromScale(0, i / 90)
    l.BackgroundColor3 = Color3.new(0, 0, 0)
    l.BackgroundTransparency = 0.94
    l.BorderSizePixel = 0
    l.Parent = lines
end

--slow rolling bar
local roll = Instance.new("Frame")
roll.Size = UDim2.fromScale(1, 0.12)
roll.BackgroundColor3 = Color3.new(1, 1, 1)
roll.BackgroundTransparency = 0.95
roll.BorderSizePixel = 0
local rg = Instance.new("UIGradient")
rg.Rotation = 90
rg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})
rg.Parent = roll
roll.Parent = mon
--modern digital feed, no rolling bar
roll.Visible = false

--grain
local grain = Instance.new("Frame")
grain.Size = UDim2.fromScale(1, 1)
grain.BackgroundColor3 = Color3.new(1, 1, 1)
grain.BackgroundTransparency = 0.97
grain.BorderSizePixel = 0
grain.Parent = mon

--glitch bars used while switching
local bars = {}
for i = 1, 6 do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(1, 0, 0, 8)
    b.BackgroundColor3 = Color3.new(1, 1, 1)
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Parent = mon
    bars[i] = b
end

local function hudText(text, size, anchor, pos, color)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.AutomaticSize = Enum.AutomaticSize.XY
    t.AnchorPoint = anchor
    t.Position = pos
    t.Font = Enum.Font.Code
    t.TextSize = size
    t.Text = text
    t.TextColor3 = color or Color3.fromRGB(235, 235, 235)
    t.TextStrokeTransparency = 0.6
    t.Parent = ctrl
    return t
end

local camTitle = hudText("CAM 01", 34, Vector2.new(0, 0), UDim2.new(0, 34, 0, 26))
local camName = hudText("", 18, Vector2.new(0, 0), UDim2.new(0, 36, 0, 68), Color3.fromRGB(200, 200, 200))




--thin corner brackets framing the shot
local function bracket(ax, ay)
    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(ax, ay)
    holder.Position = UDim2.new(ax, ax == 0 and 18 or -18, ay, ay == 0 and 16 or -16)
    holder.Size = UDim2.fromOffset(46, 46)
    holder.BackgroundTransparency = 1
    holder.Parent = mon
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, 0, 0, 2)
    h.Position = UDim2.fromScale(0, ay)
    h.AnchorPoint = Vector2.new(0, ay)
    h.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    h.BackgroundTransparency = 0.35
    h.BorderSizePixel = 0
    h.Parent = holder
    local v = Instance.new("Frame")
    v.Size = UDim2.new(0, 2, 1, 0)
    v.Position = UDim2.fromScale(ax, 0)
    v.AnchorPoint = Vector2.new(ax, 0)
    v.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    v.BackgroundTransparency = 0.35
    v.BorderSizePixel = 0
    v.Parent = holder
end
bracket(0, 0) bracket(1, 0) bracket(0, 1) bracket(1, 1)
local lightText = hudText("SPOTLIGHT: ON", 16, Vector2.new(1, 0), UDim2.new(1, -34, 0, 62), Color3.fromRGB(190, 225, 255))
--the flash readout lives at the bottom now so this one stays hidden
lightText.Visible = false
local recText = hudText("REC", 22, Vector2.new(1, 0), UDim2.new(1, -34, 0, 28), Color3.fromRGB(235, 60, 55))
local recDot = Instance.new("Frame")
recDot.AnchorPoint = Vector2.new(1, 0)
recDot.Position = UDim2.new(1, -90, 0, 34)
recDot.Size = UDim2.fromOffset(14, 14)
recDot.BackgroundColor3 = Color3.fromRGB(235, 40, 40)
recDot.BorderSizePixel = 0
local dc = Instance.new("UICorner") dc.CornerRadius = UDim.new(1, 0) dc.Parent = recDot
recDot.Parent = ctrl
local clockText = hudText("12:00 AM", 28, Vector2.new(0, 1), UDim2.new(0, 34, 1, -60))
local dateText = hudText("NOV 12", 16, Vector2.new(0, 1), UDim2.new(0, 36, 1, -34), Color3.fromRGB(200, 200, 200))
local helpText = hudText("[A] [D] switch     [F] flash     [Q] close", 15, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -18), Color3.fromRGB(190, 190, 190))

--camera power, the server drains it while watching and on every flash
local powerText = hudText("POWER 100%", 16, Vector2.new(0, 1), UDim2.new(0, 34, 1, -118), Color3.fromRGB(190, 225, 255))
local powerBack = Instance.new("Frame")
powerBack.AnchorPoint = Vector2.new(0, 1)
powerBack.Position = UDim2.new(0, 36, 1, -100)
powerBack.Size = UDim2.fromOffset(160, 8)
powerBack.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
powerBack.BackgroundTransparency = 0.2
powerBack.BorderSizePixel = 0
powerBack.Parent = ctrl
local powerFill = Instance.new("Frame")
powerFill.Size = UDim2.fromScale(1, 1)
powerFill.BackgroundColor3 = Color3.fromRGB(190, 225, 255)
powerFill.BorderSizePixel = 0
powerFill.Parent = powerBack

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -34, 0, 92)
closeBtn.Size = UDim2.fromOffset(120, 26)
closeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
closeBtn.BackgroundTransparency = 0.2
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = true
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(225, 225, 225)
closeBtn.Text = "close  [Q]"
local closeCorner = Instance.new("UICorner") closeCorner.CornerRadius = UDim.new(0, 6) closeCorner.Parent = closeBtn
closeBtn.Parent = ctrl


--big thumb buttons for switching cameras on a phone
local function camArrow(text)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0, 1)
    b.Size = UDim2.fromOffset(60, 60)
    b.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
    b.BackgroundTransparency = 0.3
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Font = Enum.Font.Code
    b.TextSize = 26
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Text = text
    b.Visible = false
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = b
    local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(235, 235, 235) s.Transparency = 0.6 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = b
    b.Parent = ctrl
    return b
end
local prevBtn = camArrow("<")
local nextBtn = camArrow(">")

--map
local mapFrame = Instance.new("Frame")
mapFrame.AnchorPoint = Vector2.new(1, 1)
mapFrame.Position = UDim2.new(1, -30, 1, -46)
mapFrame.Size = UDim2.fromOffset(400, 200)
mapFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mapFrame.BackgroundTransparency = 0.45
mapFrame.BorderSizePixel = 0
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 255, 255) ms.Transparency = 0.6 ms.Parent = mapFrame
mapFrame.Parent = ctrl


local function room(x1, y1, x2, y2, text)
    local r = Instance.new("Frame")
    r.Position = UDim2.fromScale(x1, y1)
    r.Size = UDim2.fromScale(x2 - x1, y2 - y1)
    r.BackgroundTransparency = 1
    local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(200, 200, 200) st.Transparency = 0.55 st.Parent = r
    if text then
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.fromScale(1, 1)
        tl.BackgroundTransparency = 1
        tl.Font = Enum.Font.Code
        tl.TextSize = 12
        tl.TextColor3 = Color3.fromRGB(150, 150, 150)
        tl.Text = text
        tl.Parent = r
    end
    r.Parent = mapFrame
end
room(0.02, 0.04, 0.44, 0.96, "DINING")
room(0.46, 0.03, 0.82, 0.22, "")
room(0.55, 0.26, 0.74, 0.44, "")
room(0.46, 0.5, 0.9, 0.74, "")
room(0.72, 0.78, 0.9, 0.97, "")
room(0.88, 0.04, 0.98, 0.26, "")
local you = Instance.new("TextLabel")
you.AnchorPoint = Vector2.new(0.5, 0.5)
you.Position = UDim2.fromScale(0.81, 0.9)
you.Size = UDim2.fromOffset(60, 18)
you.BackgroundTransparency = 1
you.Font = Enum.Font.Code
you.TextSize = 14
you.TextColor3 = Color3.fromRGB(235, 235, 235)
you.Text = "YOU"
you.Parent = mapFrame

local buttons = {}
local selected = 1


local function paintButtons()
    for id, b in pairs(buttons) do
        if id == selected then
            b.BackgroundColor3 = Color3.fromRGB(236, 236, 236)
            b.TextColor3 = Color3.fromRGB(10, 10, 10)
        else
            b.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
            b.TextColor3 = Color3.fromRGB(225, 225, 225)
        end
    end
end
for _, c in ipairs(cams) do
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Position = UDim2.fromScale(mapSpot[c.id].X, mapSpot[c.id].Y)
    b.Size = UDim2.fromOffset(46, 22)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.Code
    b.TextSize = 14
    b.Text = "CAM " .. c.id
    local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(235, 235, 235) st.Transparency = 0.35 st.Parent = b
    b.Parent = mapFrame
    buttons[c.id] = b
end

--phone layout: everything pulled into the corners, keyboard hints gone, bigger buttons for thumbs
local camButtonSize = Vector2.new(46, 22)




local function layoutMonitor()
    local touch = MobileUI.isTouch()
    --big tablets get the phone layout too, the desktop one puts the readout under the touch buttons
    local compact = MobileUI.isCompact() or touch
    if compact then
        camTitle.TextSize = 26
        camTitle.Position = UDim2.new(0, 16, 0, 6)
        camName.TextSize = 15
        camName.Position = UDim2.new(0, 18, 0, 38)
        clockText.AnchorPoint = Vector2.new(0, 0)
        clockText.TextSize = 18
        clockText.Position = UDim2.new(0, 18, 0, 60)
        dateText.Visible = false
        powerText.AnchorPoint = Vector2.new(0, 0)
        powerText.TextSize = 14
        powerText.Position = UDim2.new(0, 18, 0, 84)
        powerBack.AnchorPoint = Vector2.new(0, 0)
        powerBack.Position = UDim2.new(0, 20, 0, 104)
        powerBack.Size = UDim2.fromOffset(120, 6)
        recText.TextSize = 18
        recText.Position = UDim2.new(1, -16, 0, 8)
        recDot.Size = UDim2.fromOffset(12, 12)
        recDot.Position = UDim2.new(1, -68, 0, 12)
        closeBtn.Position = UDim2.new(1, -14, 0, 40)
        closeBtn.Size = UDim2.fromOffset(112, 42)
        closeBtn.TextSize = 16
        mapFrame.Position = UDim2.new(1, -12, 1, -12)
        --on the shortest phones the map gives up some height so two task alerts fit under the close button
        local mapHeight = math.clamp(math.floor(camera.ViewportSize.Y - 222), 140, 186)
        mapFrame.Size = UDim2.fromOffset(math.min(360, math.floor(camera.ViewportSize.X * 0.44)), mapHeight)
        --finger sized, still clear of each other on the smallest phones
        camButtonSize = Vector2.new(56, 34)
        --left thumb gets the camera arrows above the flash button
        prevBtn.Position = UDim2.new(0, 20, 1, -132)
        nextBtn.Position = UDim2.new(0, 90, 1, -132)
    else
        camTitle.TextSize = 34
        camTitle.Position = UDim2.new(0, 34, 0, 26)
        camName.TextSize = 18
        camName.Position = UDim2.new(0, 36, 0, 68)
        clockText.AnchorPoint = Vector2.new(0, 1)
        clockText.TextSize = 28
        clockText.Position = UDim2.new(0, 34, 1, -60)
        dateText.Visible = true
        powerText.AnchorPoint = Vector2.new(0, 1)
        powerText.TextSize = 16
        powerText.Position = UDim2.new(0, 34, 1, -118)
        powerBack.AnchorPoint = Vector2.new(0, 1)
        powerBack.Position = UDim2.new(0, 36, 1, -100)
        powerBack.Size = UDim2.fromOffset(160, 8)
        recText.TextSize = 22
        recText.Position = UDim2.new(1, -34, 0, 28)
        recDot.Size = UDim2.fromOffset(14, 14)
        recDot.Position = UDim2.new(1, -90, 0, 34)
        closeBtn.Position = UDim2.new(1, -34, 0, 92)
        closeBtn.Size = UDim2.fromOffset(120, 26)
        closeBtn.TextSize = 14
        mapFrame.Position = UDim2.new(1, -30, 1, -46)
        mapFrame.Size = UDim2.fromOffset(400, 200)
        camButtonSize = Vector2.new(46, 22)
    end
    closeBtn.Text = touch and "close" or "close  [Q]"
    helpText.Visible = not touch and not compact
    prevBtn.Visible = touch
    nextBtn.Visible = touch
    for _, b in pairs(buttons) do b.Size = UDim2.fromOffset(camButtonSize.X, camButtonSize.Y) end
end
MobileUI.watch(layoutMonitor)

--red pulsing box on the map where the monster is trying to get in
local alertBox = Instance.new("Frame")
alertBox.AnchorPoint = Vector2.new(0.5, 0.5)
alertBox.Size = UDim2.fromOffset(62, 36)
alertBox.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
alertBox.BackgroundTransparency = 0.3
alertBox.BorderSizePixel = 0
alertBox.ZIndex = 0
alertBox.Visible = false
local abc = Instance.new("UICorner")
abc.CornerRadius = UDim.new(0, 6)
abc.Parent = alertBox
local abs = Instance.new("UIStroke")
abs.Color = Color3.fromRGB(255, 60, 60)
abs.Thickness = 2
abs.Parent = alertBox
alertBox.Parent = mapFrame
game:GetService("RunService").RenderStepped:Connect(function()
    local id = workspace:GetAttribute("MonsterSpot")
    local spot = id and mapSpot[id]
    if spot and workspace:GetAttribute("NightActive") then
        alertBox.Visible = true
        alertBox.Position = UDim2.fromScale(spot.X, spot.Y)
        local pulse = (math.sin(os.clock() * 7) + 1) / 2
        alertBox.BackgroundTransparency = 0.25 + 0.55 * pulse
        abs.Transparency = 0.6 * pulse
        local grow = 8 + 8 * pulse
        alertBox.Size = UDim2.fromOffset(52 + grow, 26 + grow)
    else
        alertBox.Visible = false
    end
    --the camera button itself flashes red too
    for camId, b in pairs(buttons) do
        if spot and camId == id and workspace:GetAttribute("NightActive") then
            local pulse = (math.sin(os.clock() * 7) + 1) / 2
            b.BackgroundColor3 = Color3.fromRGB(120, 10, 10):Lerp(Color3.fromRGB(255, 50, 50), pulse)
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
        elseif camId == selected then
            b.BackgroundColor3 = Color3.fromRGB(236, 236, 236)
            b.TextColor3 = Color3.fromRGB(10, 10, 10)
        else
            b.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
            b.TextColor3 = Color3.fromRGB(225, 225, 225)
        end
    end
end)

----------------------------------------------------------------- viewing state
local viewing = false
local mode = "off"
local zoomCF = CFrame.new()
local zoomFov = 70
local colorGrade = nil
local boost = false
local switching = false
local shownCam = cams[1]



local function camLight(id)
    local m = workspace:FindFirstChild("ChipotleMap")
    m = m and m:FindFirstChild("SecurityCameras")
    m = m and m:FindFirstChild("SecurityCam" .. id)
    local lens = m and m:FindFirstChild("Lens")
    return lens and lens:FindFirstChild("CamLight")
end


local function staticBurst(time)
    local t0 = os.clock()
    while os.clock() - t0 < time do
        grain.BackgroundTransparency = 0.35 + math.random() * 0.35
        for _, b in ipairs(bars) do
            b.BackgroundTransparency = 0.5 + math.random() * 0.5
            b.Position = UDim2.fromScale(0, math.random())
            b.Size = UDim2.new(1, 0, 0, math.random(3, 26))
        end
        task.wait(0.04)
    end
    grain.BackgroundTransparency = 0.97
    for _, b in ipairs(bars) do b.BackgroundTransparency = 1 end
end


local function setBoost(on)
    boost = on
    local l = camLight(shownCam.id)
    if l then l.Brightness = on and 6 or 2 end
    lightText.Text = on and "SPOTLIGHT: BOOST" or "SPOTLIGHT: ON"
end

--the flash is a real burst from the cameras own lamp, and the sensor blows out for a moment
player:GetAttributeChangedSignal("CamFlash"):Connect(function()
    if not viewing then return end
    boost = true
    local mark = player:GetAttribute("CamFlash")
    local l = camLight(shownCam.id)
    if l then
        local baseRange = l:GetAttribute("BaseRange") or l.Range
        l:SetAttribute("BaseRange", baseRange)
        l.Brightness = 45
        l.Range = 60
        TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 2, Range = baseRange}):Play()
        --wide fill so the whole room catches it, not just the cone
        local fill = Instance.new("PointLight")
        fill.Name = "FlashFill"
        fill.Color = Color3.fromRGB(235, 240, 255)
        fill.Brightness = 9
        fill.Range = 30
        fill.Shadows = true
        fill.Parent = l.Parent
        TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0}):Play()
        task.delay(0.45, function() fill:Destroy() end)
    end
    if colorGrade then
        colorGrade.Brightness = 0.32
        TweenService:Create(colorGrade, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0.03}):Play()
    end
    task.delay(0.5, function()
        if player:GetAttribute("CamFlash") == mark then boost = false end
    end)
end)

--the camera picked last stays picked for the whole session
local lastCamId = nil


local function showCam(index)
    if not viewing then return end
    setBoost(false)
    beep:Play()
    local c = cams[index]
    selected = c.id
    lastCamId = c.id
    paintButtons()
    ev:FireServer("focus", c.id)
    --the new feed is up the same frame, the static just plays over it
    shownCam = c
    camTitle.Text = string.format("CAM %02d", c.id)
    camName.Text = c.label
    mode = "feed"
    camera.FieldOfView = FEED_FOV
    camera.Focus = CFrame.new(c.target)
    task.spawn(staticBurst, 0.25)
end


local function cycle(step)
    local index = 1
    for i, c in ipairs(cams) do if c.id == selected then index = i end end
    index = (index - 1 + step) % #cams + 1
    showCam(index)
end

for id, b in pairs(buttons) do
    b.MouseButton1Click:Connect(function()
        for i, c in ipairs(cams) do if c.id == id then showCam(i) end end
    end)
end

local function hideCharacter()
    local char = player.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end
    end
end


local function showCharacter()
    local char = player.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
    end
end

local CAS = game:GetService("ContextActionService")


local function getControls()
    local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
    if not pm then return nil end
    local ok, mod = pcall(require, pm)
    if ok then return mod:GetControls() end
end

--camera each frame while seated
local feedStart = os.clock()
local scareAt = -99
local Lighting = game:GetService("Lighting")


local function step()
    hideCharacter()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    if mode == "zoom" then
        camera.CFrame = zoomCF
        camera.FieldOfView = zoomFov
    elseif mode == "feed" then
        local t = os.clock() - feedStart
        local base = CFrame.lookAt(shownCam.pos, shownCam.target)
        --slow pan like a real security camera
        local yaw = math.sin(t * 0.35 + shownCam.id) * math.rad(9)
        local pitch = math.sin(t * 0.21 + shownCam.id * 2) * math.rad(1.5)
        local shake = Vector3.new(math.noise(t * 9, 1) * 0.02, math.noise(t * 9, 2) * 0.02, 0)
        camera.CFrame = base * CFrame.Angles(pitch, yaw, 0) * CFrame.new(shake)
        camera.FieldOfView = FEED_FOV
        --it got in: the feed snaps onto its face and pushes in
        local s = os.clock() - scareAt
        local m = workspace:FindFirstChild("NightMonster")
        local h = m and m:FindFirstChild("Head")
        if s < 1.6 and h and h.Position.Y > -100 then
            local a = math.clamp(s / 0.25, 0, 1) * (1 - math.clamp((s - 1.1) / 0.5, 0, 1))
            local onFace = CFrame.lookAt(shownCam.pos, h.Position)
            camera.CFrame = camera.CFrame:Lerp(onFace * CFrame.new(math.noise(s * 30, 5) * 0.05, math.noise(s * 30, 6) * 0.05, 0), a)
            camera.FieldOfView = FEED_FOV + (30 - FEED_FOV) * a
        end
    end
end

local clockMinutes = 0


local function updateHud(dt)
    if not viewing then return end
    --blinking rec dot
    local on = (os.clock() % 1.2) < 0.7
    recDot.BackgroundTransparency = on and 0 or 1
    --moving roll bar
    roll.Position = UDim2.fromScale(0, ((os.clock() * 0.12) % 1.3) - 0.15)
    if not switching then
        grain.BackgroundTransparency = 0.95 + math.random() * 0.04
    end
    if workspace:GetAttribute("NightActive") then
        local start = workspace:GetAttribute("NightStart") or 0
        clockMinutes = math.max(0, workspace:GetServerTimeNow() - start)
    else
        clockMinutes = clockMinutes + dt / 3
    end
    local power = player:GetAttribute("CamPower") or 100
    powerText.Text = string.format("POWER %d%%", math.floor(power + 0.5))
    powerFill.Size = UDim2.fromScale(power / 100, 1)
    --goes amber under a third and red under a tenth
    local col = power < 10 and Color3.fromRGB(235, 70, 60) or (power < 33 and Color3.fromRGB(240, 180, 70) or Color3.fromRGB(190, 225, 255))
    powerFill.BackgroundColor3 = col
    powerText.TextColor3 = col
    local m = math.floor(clockMinutes)
    local h = (12 + math.floor(m / 60)) % 12
    if h == 0 then h = 12 end
    clockText.Text = string.format("%d:%02d AM", h, m % 60)
end

local savedFx = {}


local function dimEffects(on)
    if on then
        savedFx = {}
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") then savedFx[e] = {Intensity = e.Intensity} e.Intensity = e.Intensity * 0.25
            elseif e:IsA("DepthOfFieldEffect") then savedFx[e] = {Enabled = e.Enabled} e.Enabled = false end
        end
    else
        for e, v in pairs(savedFx) do
            for k, val in pairs(v) do e[k] = val end
        end
        savedFx = {}
    end
end

--low light sensor: while looking through the cameras the dark is lifted to a grey picture, no colour cast
--the server can still change the real lighting (lights out, hunts), those values are tracked and put back on close
local IR_AMBIENT = Color3.fromRGB(58, 60, 66)
local irOn = false
local settingIr = false
local realAmbient = Lighting.Ambient
local realOutdoor = Lighting.OutdoorAmbient


local function applyIr()
    settingIr = true
    Lighting.Ambient = irOn and IR_AMBIENT or realAmbient
    Lighting.OutdoorAmbient = irOn and IR_AMBIENT or realOutdoor
    settingIr = false
end
Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
    if settingIr then return end
    realAmbient = Lighting.Ambient
    if irOn then applyIr() end
end)
Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
    if settingIr then return end
    realOutdoor = Lighting.OutdoorAmbient
    if irOn then applyIr() end
end)
--the store air and the warm grade are for your own eyes, the camera sensor sees clean and neutral
local savedAir = {}




local function sensorLook(on)
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if on then
        savedAir = {density = atmo and atmo.Density, tint = grade and grade.TintColor}
        if atmo then atmo.Density = math.min(atmo.Density, 0.14) end
        if grade then grade.TintColor = Color3.new(1, 1, 1) end
    else
        if atmo and savedAir.density then atmo.Density = savedAir.density end
        if grade and savedAir.tint then grade.TintColor = savedAir.tint end
        savedAir = {}
    end
end
local savedExposure = nil


local function openMonitor()
    dimEffects(true)
    savedExposure = Lighting.ExposureCompensation
    Lighting.ExposureCompensation = savedExposure + 0.35
    irOn = true
    applyIr()
    sensorLook(true)
    viewing = true
    mon.Enabled = true
    mode = "feed"
    feedStart = os.clock()
    colorGrade = Instance.new("ColorCorrectionEffect")
    colorGrade.Name = "SecurityGrade"
    --neutral modern cctv, slightly washed out, no tint
    colorGrade.Saturation = -0.35
    colorGrade.TintColor = Color3.new(1, 1, 1)
    colorGrade.Brightness = 0.03
    colorGrade.Contrast = 0.12
    colorGrade.Parent = camera
    --back on whatever camera was being watched last time
    shownCam = cams[1]
    for _, c in ipairs(cams) do
        if c.id == lastCamId then shownCam = c end
    end
    selected = shownCam.id
    lastCamId = shownCam.id
    paintButtons()
    setBoost(false)
    camTitle.Text = string.format("CAM %02d", shownCam.id)
    camName.Text = shownCam.label
    ev:FireServer("focus", shownCam.id)
    camera.FieldOfView = FEED_FOV
    camera.Focus = CFrame.new(shownCam.target)
    task.spawn(staticBurst, 0.5)
end

local controls = nil
local sequenceRunning = false


local function closeMonitor()
    if not viewing or sequenceRunning then return end
    sequenceRunning = true
    fadeTo(0, 0.35)
    viewing = false
    mon.Enabled = false
    mode = "off"
    if colorGrade then colorGrade:Destroy() colorGrade = nil end
    dimEffects(false)
    if savedExposure then
        Lighting.ExposureCompensation = savedExposure
        savedExposure = nil
    end
    irOn = false
    applyIr()
    sensorLook(false)
    setBoost(false)
    ev:FireServer("leave")
end

--it broke in while they were watching: jump to the camera it is on and push in on its face
RS:WaitForChild("MonsterEvent").OnClientEvent:Connect(function(kind, a)
    if kind ~= "scareCam" or not viewing then return end
    task.spawn(function()
        local id = tonumber(a) or 0
        if id > 0 and shownCam.id ~= id then
            for i, c in ipairs(cams) do
                if c.id == id then
                    switching = false
                    showCam(i)
                end
            end
        end
        scareAt = os.clock()
        beep:Play()
        staticBurst(0.12)
    end)
end)


--battery ran flat, or they tried to sit down before it charged back
local function powerToast()
    local g = player.PlayerGui:FindFirstChild("PowerToast")
    if not g then
        g = Instance.new("ScreenGui")
        g.Name = "PowerToast"
        g.ResetOnSpawn = false
        g.DisplayOrder = 36
        g.Parent = player.PlayerGui
    end
    g:ClearAllChildren()
    local l = Instance.new("TextLabel")
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.Position = UDim2.new(0.5, 0, 0, 120)
    l.Size = UDim2.fromOffset(420, 36)
    l.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    l.BackgroundTransparency = 0.3
    l.Font = Enum.Font.GothamBold
    l.TextSize = 17
    l.TextColor3 = Color3.fromRGB(240, 180, 70)
    l.Text = "camera power is out.  step away to let it charge"
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = l
    l.Parent = g
    task.delay(3, function() if l.Parent then l:Destroy() end end)
end

ev.OnClientEvent:Connect(function(kind)
    if kind == "noPower" then
        powerToast()
        if viewing then closeMonitor() end
        return
    end
    if kind == "seated" then
        task.spawn(function()
            sequenceRunning = true
            player:SetAttribute("Seated", true)
            player:SetAttribute("InCutscene", true)
            if hideObjective then hideObjective() hideObjective = nil end
            controls = getControls()
            if controls then controls:Disable() end
            --stop jumping out of the chair
            CAS:BindActionAtPriority("SecurityBlock", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
            --straight onto the feed, no lean in animation to sit through
            camera.CameraType = Enum.CameraType.Scriptable
            RunService:UnbindFromRenderStep("SecurityFeed")
            RunService:BindToRenderStep("SecurityFeed", Enum.RenderPriority.Last.Value, step)
            latch:Play()
            openMonitor()
            sequenceRunning = false
            fadeTo(1, 0.2)
        end)
    elseif kind == "stood" then
        --the server can stand them up when the night ends, so the feed has to close here too
        if viewing then closeMonitor() end
        --back in the room
        RunService:UnbindFromRenderStep("SecurityFeed")
        showCharacter()
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = 70
        if controls then controls:Enable() end
        CAS:UnbindAction("SecurityBlock")
        player:SetAttribute("Seated", false)
        player:SetAttribute("InCutscene", false)
        sequenceRunning = false
        task.wait(0.2)
        fadeTo(1, 0.5)
    end
end)

UIS.InputBegan:Connect(function(input, typing)
    if typing or not viewing then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.Q or k == Enum.KeyCode.Escape then
        closeMonitor()
    elseif k == Enum.KeyCode.D or k == Enum.KeyCode.Right then
        cycle(1)
    elseif k == Enum.KeyCode.A or k == Enum.KeyCode.Left then
        cycle(-1)
    else
        local names = {One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8}
        local n = names[k.Name]
        if n then
            for i, c in ipairs(cams) do if c.id == n then showCam(i) end end
        end
    end
end)

RunService.RenderStepped:Connect(updateHud)

closeBtn.MouseButton1Click:Connect(function() closeMonitor() end)
prevBtn.Activated:Connect(function() cycle(-1) end)
nextBtn.Activated:Connect(function() cycle(1) end)

----------------------------------------------------------------- desk monitor
--the physical screen on the desk shows a live picture of the selected camera
--the store is copied once into a viewport, and the monster, players, doors and the window are mirrored into it every tick
task.spawn(function()
    local map = workspace:WaitForChild("ChipotleMap")
    local monitor = map:WaitForChild("BackRooms"):WaitForChild("OfficeMonitor"):WaitForChild("Monitor")
    local face = monitor:WaitForChild("ScreenFace")
    for _, c in ipairs(face:GetChildren()) do
        if c:IsA("GuiObject") then c.Visible = false end
    end
    local screen = Instance.new("Frame")
    screen.Name = "LiveFeed"
    screen.Size = UDim2.fromScale(1, 1)
    screen.BackgroundColor3 = Color3.fromRGB(6, 6, 7)
    screen.BorderSizePixel = 0
    screen.Parent = face
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.fromScale(1, 1)
    vp.BackgroundColor3 = Color3.fromRGB(4, 4, 5)
    vp.Ambient = Color3.fromRGB(118, 118, 122)
    vp.LightColor = Color3.fromRGB(205, 205, 212)
    vp.LightDirection = Vector3.new(-0.35, -1, -0.25)
    vp.Parent = screen
    local world = Instance.new("WorldModel")
    world.Parent = vp
    local vcam = Instance.new("Camera")
    vcam.FieldOfView = 74
    vcam.Parent = vp
    vp.CurrentCamera = vcam
    local function label(text, size, anchor, pos, color)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.AnchorPoint = anchor
        t.Position = pos
        t.Size = UDim2.fromOffset(0, size + 4)
        t.AutomaticSize = Enum.AutomaticSize.X
        t.Font = Enum.Font.Code
        t.TextSize = size
        t.Text = text
        t.TextColor3 = color or Color3.fromRGB(230, 230, 230)
        t.TextStrokeTransparency = 0.5
        t.ZIndex = 3
        t.Parent = screen
        return t
    end
    local title = label("CAM 01", 13, Vector2.new(0, 0), UDim2.fromOffset(6, 4))
    local rec = label("● REC", 11, Vector2.new(1, 0), UDim2.new(1, -6, 0, 5), Color3.fromRGB(230, 60, 55))
    local clock = label("12:00 AM", 11, Vector2.new(0, 1), UDim2.new(0, 6, 1, -4))
    local live = label("LIVE", 10, Vector2.new(1, 1), UDim2.new(1, -6, 1, -4), Color3.fromRGB(190, 190, 190))
    local grain = Instance.new("Frame")
    grain.Size = UDim2.fromScale(1, 1)
    grain.BackgroundColor3 = Color3.new(1, 1, 1)
    grain.BackgroundTransparency = 0.97
    grain.BorderSizePixel = 0
    grain.ZIndex = 2
    grain.Parent = screen

    --copy the inside of the store once, a few folders at a time so nothing hitches
    while not player:GetAttribute("IntroDone") do task.wait(1) end
    --a second copy of the whole store is too heavy for a phone, the screen keeps its labels and grain without the picture
    local lowSpec = MobileUI.isLowSpec()
    local KEEP = {"Floors", "Walls", "InteriorWalls", "LobbyCeiling", "BackCeilings", "DiningRoom", "ServingLine", "EntryHallway", "Facade", "PickupShelf", "RestroomHall", "Restrooms", "Kitchen", "KitchenHallway", "BackHallway", "BackRooms", "DrinkAlcove", "NightProps", "LightRigs"}
    local mirror = {}
    local moving = {}
    for _, d in ipairs(game:GetService("CollectionService"):GetTagged("InteractDoor")) do moving[d] = true end
    for _, d in ipairs(game:GetService("CollectionService"):GetTagged("MonsterDoor")) do moving[d] = true end
    local function dynamic(p)
        for d in pairs(moving) do
            if p == d or p:IsDescendantOf(d) then return true end
            if d:GetAttribute("DoorKind") == "Entry" and p:GetAttribute("DoorGroup") == string.sub(d.Name, -1) then return true end
        end
        return p.Name == "WindowGlass" or p.Name == "WindowPaper"
    end
    local count = 0
    for _, name in ipairs(KEEP) do
        local f = map:FindFirstChild(name)
        if f and not lowSpec then
            for _, p in ipairs(f:GetDescendants()) do
                if p:IsA("BasePart") and p.Transparency < 0.98 and p ~= monitor then
                    local ok, c = pcall(function() return p:Clone() end)
                    if ok and c then
                        for _, x in ipairs(c:GetChildren()) do
                            if not (x:IsA("Decal") or x:IsA("Texture") or x:IsA("SpecialMesh") or x:IsA("SurfaceAppearance")) then x:Destroy() end
                        end
                        c.Anchored = true
                        c.Parent = world
                        if dynamic(p) then table.insert(mirror, {src = p, dst = c}) end
                        count += 1
                        if count % 150 == 0 then task.wait() end
                    end
                end
            end
        end
    end

    --live bodies: the monster and every player, rebuilt when they change
    local bodies = {}
    local function bodyFor(model)
        local b = bodies[model]
        if b and b.clone.Parent then return b end
        if b then b.clone:Destroy() end
        model.Archivable = true
        local ok, c = pcall(function() return model:Clone() end)
        if not ok or not c then return nil end
        local pairsList = {}
        local srcParts = {}
        for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then table.insert(srcParts, p) end end
        local dstParts = {}
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(dstParts, p) p.Anchored = true
            elseif p:IsA("LuaSourceContainer") or p:IsA("Sound") or p:IsA("Light") or p:IsA("JointInstance") or p:IsA("Constraint") or p:IsA("Highlight") then p:Destroy() end
        end
        for i, p in ipairs(srcParts) do if dstParts[i] then table.insert(pairsList, {src = p, dst = dstParts[i]}) end end
        c.Parent = world
        b = {clone = c, list = pairsList}
        bodies[model] = b
        return b
    end

    local camIndex = 1
    local lastSwitch = os.clock()
    while true do
        task.wait(1 / 15)
        --follows whatever the player picked while seated, otherwise cycles on its own
        local c
        if viewing then
            c = shownCam
        else
            if os.clock() - lastSwitch > 6 then
                lastSwitch = os.clock()
                camIndex = camIndex % #cams + 1
            end
            c = cams[camIndex]
        end
        local t = os.clock()
        local yaw = math.sin(t * 0.35 + c.id) * math.rad(9)
        vcam.CFrame = CFrame.lookAt(c.pos, c.target) * CFrame.Angles(0, yaw, 0)
        title.Text = string.format("CAM %02d  %s", c.id, c.label or "")
        rec.TextTransparency = (t % 1.2) < 0.7 and 0 or 1
        local start = workspace:GetAttribute("NightStart")
        local m = start and workspace:GetAttribute("NightActive") and math.floor(math.max(0, workspace:GetServerTimeNow() - start)) or 0
        local h = (12 + math.floor(m / 60)) % 12
        if h == 0 then h = 12 end
        clock.Text = string.format("%d:%02d AM", h, m % 60)
        grain.BackgroundTransparency = 0.95 + math.random() * 0.04
        --doors swing and the pickup window slides
        for _, e in ipairs(mirror) do
            if e.src.Parent then e.dst.CFrame = e.src.CFrame end
        end
        --monster and players
        local live = {}
        local monster = workspace:FindFirstChild("NightMonster")
        if monster then live[monster] = true end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then live[p.Character] = true end
        end
        if lowSpec then live = {} end
        for model in pairs(live) do
            local b = bodyFor(model)
            if b then
                for _, e in ipairs(b.list) do
                    if e.src.Parent then e.dst.CFrame = e.src.CFrame end
                end
            end
        end
        for model, b in pairs(bodies) do
            if not live[model] then
                b.clone:Destroy()
                bodies[model] = nil
            end
        end
    end
end)
