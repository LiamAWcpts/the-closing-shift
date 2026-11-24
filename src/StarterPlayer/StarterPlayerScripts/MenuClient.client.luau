--first screen on joining: the title and one play button, then the difficulty screen takes over
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
if player:GetAttribute("MenuDone") then return end
player:SetAttribute("InCutscene", true)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

local request = RS:WaitForChild("LobbyRequest")
local camera = workspace.CurrentCamera


local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end



local function click()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://9119717286"
    s.Volume = 0.35
    s.Parent = script
    s:Play()
    game:GetService("Debris"):AddItem(s, 2)
end

--one palette for every screen, same family as the character and difficulty screens
local INK = Color3.fromRGB(10, 10, 13)
local PANEL = Color3.fromRGB(20, 20, 26)
local LINE = Color3.fromRGB(255, 255, 255)
local TEXT = Color3.fromRGB(240, 238, 234)
local MUTED = Color3.fromRGB(150, 150, 158)
local WARM = Color3.fromRGB(255, 214, 150)
local GOOD = Color3.fromRGB(110, 200, 130)
local BAD = Color3.fromRGB(235, 95, 85)
----------------------------------------------------------------- backdrop
local gui = Instance.new("ScreenGui")
gui.Name = "MainMenu"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 110
gui.Parent = player:WaitForChild("PlayerGui")
local hud = MobileUI.safeGui("MainMenuHud", 111, player.PlayerGui)

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = INK
--see through: the store shots play behind it, this just darkens them so the cards read
bg.BackgroundTransparency = 0.45
bg.BorderSizePixel = 0
bg.Parent = gui
--a soft pool of light that changes colour with each screen
local glow = {}
for i = 0, 15 do
    local s = 1.25 - i * 0.07
    local c = Instance.new("Frame")
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Position = UDim2.fromScale(0.5, 0.48)
    c.Size = UDim2.fromScale(s, s)
    c.SizeConstraint = Enum.SizeConstraint.RelativeXX
    c.BackgroundColor3 = WARM
    c.BackgroundTransparency = 0.975
    c.BorderSizePixel = 0
    --the coloured pool is not drawn over the store shots, it still tracks colour for the lobby
    c.Visible = false
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(1, 0) cc.Parent = c
    c.Parent = bg
    table.insert(glow, c)
end
for _, rot in ipairs({90, 270}) do
    local v = Instance.new("Frame")
    v.Size = UDim2.fromScale(1, 1)
    v.BackgroundColor3 = Color3.new(0, 0, 0)
    v.BorderSizePixel = 0
    local g = Instance.new("UIGradient")
    g.Rotation = rot
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = v
    v.Parent = bg
end
--slow drifting dust
for i = 1, 22 do
    local s = Instance.new("Frame")
    s.Size = UDim2.fromOffset(2, 2)
    s.Position = UDim2.fromScale(math.random(), math.random())
    s.BackgroundColor3 = Color3.new(1, 1, 1)
    s.BackgroundTransparency = 0.78 + math.random() * 0.18
    s.BorderSizePixel = 0
    s.Parent = bg
    task.spawn(function()
        local speed = 0.0004 + math.random() * 0.0008
        while s.Parent do
            local p = s.Position
            local y = p.Y.Scale - speed
            if y < -0.02 then y = 1.02 end
            s.Position = UDim2.fromScale(p.X.Scale + math.sin(os.clock() * 0.6 + i) * 0.0002, y)
            task.wait(0.05)
        end
    end)
end



local function setGlow(color, time)
    for _, c in ipairs(glow) do tween(c, time or 0.8, {BackgroundColor3 = color}, Enum.EasingStyle.Sine) end
end

--the black fade gets its own gui above the buttons so nothing can ever show on top of the black
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "MainMenuFade"
fadeGui.IgnoreGuiInset = true
fadeGui.ResetOnSpawn = false
fadeGui.DisplayOrder = 112
fadeGui.Parent = player.PlayerGui
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BorderSizePixel = 0
fade.ZIndex = 100
fade.Parent = fadeGui

camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.new(0, 600, 0)

----------------------------------------------------------------- store shots behind the menu
--slow camera moves around the store, each one dips through black into the next
--they stop when the menu hands over to character select
local V = Vector3.new
local SHOTS = {
    {from = CFrame.lookAt(V(-18, 8, 58), V(-45, 4, 22)), to = CFrame.lookAt(V(-6, 8.5, 60), V(-38, 4, 22)), time = 9},
    {from = CFrame.lookAt(V(-79, 6.2, 37), V(-58, 4.5, 18)), to = CFrame.lookAt(V(-73, 5.6, 31), V(-57, 4.5, 17)), time = 8},
    {from = CFrame.lookAt(V(-51, 6.5, 13), V(-15, 3.5, -8)), to = CFrame.lookAt(V(-55, 6.4, 8), V(-12, 3.5, -12)), time = 8},
    {from = CFrame.lookAt(V(21, 5.2, -8.5), V(35, 4.5, -13)), to = CFrame.lookAt(V(25, 5, -10), V(35, 4.3, -13.5)), time = 8},
}
local DIP = 0.8
--black dip between shots, under the cards and over the world
local dip = Instance.new("Frame")
dip.Size = UDim2.fromScale(1, 1)
dip.BackgroundColor3 = Color3.new(0, 0, 0)
dip.BackgroundTransparency = 0
dip.BorderSizePixel = 0
dip.ZIndex = 0
dip.Parent = gui
bg.ZIndex = 1
local cineOn = true
local shotFrom, shotTo, shotStart, shotTime = nil, nil, 0, 1



--everyone's character is hidden in the shots, the spawn is right in the dining room
--so is the figure the intro uses, it waits outside the front doors until the intro moves it
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




local function hideCharacters()
    for _, c in ipairs(shotHidden()) do
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end
        end
    end
end
RunService:BindToRenderStep("MenuCine", Enum.RenderPriority.Camera.Value + 1, function()
    if not shotFrom then return end
    local a = math.clamp((os.clock() - shotStart) / shotTime, 0, 1)
    local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = shotFrom:Lerp(shotTo, e)
    camera.FieldOfView = 60
    hideCharacters()
end)
task.spawn(function()
    local i = 1
    while cineOn do
        local s = SHOTS[i]
        --far shots need that part of the map streamed in first
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


--character select has its own plain dark stage, so the shots and the hidden characters go back to normal
local function stopCinematic()
    cineOn = false
    RunService:UnbindFromRenderStep("MenuCine")
    for _, c in ipairs(shotHidden()) do
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
        end
    end
    camera.CFrame = CFrame.new(0, 600, 0)
end

----------------------------------------------------------------- building blocks


local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 14)
    c.Parent = o
    return c
end




local function stroke(o, t)
    local s = Instance.new("UIStroke")
    s.Color = LINE
    s.Transparency = t or 0.85
    s.Thickness = 1.2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o
    return s
end

local function label(parent, text, size, font, color, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or TEXT
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    return l
end


--hover grows it a touch, press squashes it, like the select screens
local function pressable(b, baseStroke)
    local sc = Instance.new("UIScale")
    sc.Parent = b
    local st = b:FindFirstChildOfClass("UIStroke")
    b.MouseEnter:Connect(function()
        tween(sc, 0.18, {Scale = 1.04})
        if st then tween(st, 0.18, {Transparency = 0.35}) end
    end)
    b.MouseLeave:Connect(function()
        tween(sc, 0.18, {Scale = 1})
        if st then tween(st, 0.18, {Transparency = baseStroke or 0.85}) end
    end)
    b.MouseButton1Down:Connect(function() tween(sc, 0.08, {Scale = 0.96}) end)
    b.MouseButton1Up:Connect(function() tween(sc, 0.15, {Scale = 1.04}) end)
end

local function pill(parent, text, light)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.BackgroundColor3 = light and Color3.fromRGB(240, 238, 234) or PANEL
    b.BackgroundTransparency = light and 0 or 0.25
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = light and Color3.fromRGB(12, 12, 12) or TEXT
    b.Text = text
    b.Size = UDim2.fromOffset(180, 46)
    corner(b, UDim.new(1, 0))
    stroke(b, light and 0.6 or 0.8).Color = light and WARM or LINE
    b.Parent = parent
    pressable(b, light and 0.6 or 0.8)
    return b
end
--the usual account picture person: round head and round shoulders cut off flat at the bottom
--a thin outline in the card colour keeps people apart where they overlap
----------------------------------------------------------------- screens
--each screen is a canvas group so it fades and slides in one piece
local screens = {}
local current = nil



local function screen(name)
    local s = Instance.new("CanvasGroup")
    s.Name = name
    s.Size = UDim2.fromScale(1, 1)
    s.BackgroundTransparency = 1
    s.GroupTransparency = 1
    s.Visible = false
    s.Parent = hud
    screens[name] = s
    return s
end


local function show(name, dir)
    local nxt = screens[name]
    if current == nxt then return end
    local old = current
    current = nxt
    dir = dir or 1
    --the old screen fully fades out before the new one comes in so they never overlap
    if old then
        tween(old, 0.16, {GroupTransparency = 1})
    end
    nxt.Position = UDim2.fromOffset(40 * dir, 0)
    nxt.GroupTransparency = 1
    task.delay(old and 0.17 or 0, function()
        if current ~= nxt then return end
        for _, other in pairs(screens) do
            if other ~= nxt then
                other.Visible = false
                other.GroupTransparency = 1
            end
        end
        nxt.Visible = true
        tween(nxt, 0.4, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
    end)
end


local function statusLine(parent, y)
    return label(parent, "", 15, Enum.Font.GothamMedium, BAD, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(640, 24), TextTransparency = 1})
end


local function flashStatus(l, text, color)
    l.Text = text
    l.TextColor3 = color or BAD
    l.TextTransparency = 0
    local mine = text
    task.delay(3.5, function() if l.Text == mine then tween(l, 0.6, {TextTransparency = 1}) end end)
end

----------------------------------------------------------------- mode select
local modeScreen = screen("mode")
label(modeScreen, "SURVIVE THE CLOSING SHIFT", 44, Enum.Font.GothamBlack, TEXT, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromOffset(900, 56)})
local playBtn = pill(modeScreen, "PLAY", true)
playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
playBtn.Position = UDim2.fromScale(0.5, 0.56)
playBtn.Size = UDim2.fromOffset(330, 88)
playBtn.TextSize = 34
--black with white text
playBtn.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
playBtn.BackgroundTransparency = 0
playBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
local modeStatus = statusLine(modeScreen, 0.86)

----------------------------------------------------------------- requests
local busy = false


local function ask(statusLabel, kind, arg)
    if busy then return false end
    busy = true
    local ok, a, b = pcall(function() return request:InvokeServer(kind, arg) end)
    busy = false
    if not ok then
        flashStatus(statusLabel, "could not reach the server")
        return false
    end
    if a == false then
        if b then flashStatus(statusLabel, b) end
        return false
    end
    return true, b
end

playBtn.MouseButton1Click:Connect(function()
    click()
    ask(modeStatus, "play")
end)

RunService:BindToRenderStep("MenuMouse", Enum.RenderPriority.Last.Value, function()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
end)

--every word on the menu in one rounder typeface, swapped in as anything is added
local WEIGHTS = {[Enum.Font.GothamBlack] = Enum.FontWeight.Heavy, [Enum.Font.GothamBold] = Enum.FontWeight.Bold, [Enum.Font.GothamMedium] = Enum.FontWeight.Medium, [Enum.Font.Gotham] = Enum.FontWeight.Regular}


local function refont(o)
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        local w = WEIGHTS[o.Font] or Enum.FontWeight.Bold
        o.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", w)
        --everything centered
        o.TextXAlignment = Enum.TextXAlignment.Center
    end
end
for _, o in ipairs(hud:GetDescendants()) do refont(o) end
hud.DescendantAdded:Connect(refont)

----------------------------------------------------------------- done
local finished = false


local function finish()
    if finished then return end
    finished = true
    --buttons stop taking clicks the moment the fade starts
    for _, sc in pairs(screens) do
        sc.Interactable = false
    end
    --the buttons fade on the same curve as the black that covers them
    for _, sc in pairs(screens) do
        if sc.Visible then
            tween(sc, 0.9, {GroupTransparency = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        end
    end
    tween(fade, 0.9, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
    for _, sc in pairs(screens) do
        sc.Visible = false
    end
    stopCinematic()
    task.wait(0.2)
    RunService:UnbindFromRenderStep("MenuMouse")
    hud:Destroy()
    gui:Destroy()
    fadeGui:Destroy()
end
player:GetAttributeChangedSignal("MenuDone"):Connect(function()
    if player:GetAttribute("MenuDone") then finish() end
end)

----------------------------------------------------------------- opening
show("mode", 1)
setGlow(WARM, 0)
tween(fade, 1.4, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
