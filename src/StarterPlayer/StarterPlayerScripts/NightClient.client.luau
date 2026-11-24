--night clock, alerts, strikes and the minigames for each event
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ev = RS:WaitForChild("NightEvent")
local playerGui = player:WaitForChild("PlayerGui")


local function makeSound(id, volume, speed)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume
    s.PlaybackSpeed = speed
    --sounds live in soundservice, playergui gets wiped when the picked body is swapped in
    s.Parent = game:GetService("SoundService")
    return s
end
local chime = makeSound("rbxassetid://4612374393", 0.18, 0.8)
local ding = makeSound("rbxassetid://9113938822", 0.12, 1.2)
local click = makeSound("rbxassetid://9119717286", 0.5, 1)
local blip = makeSound("rbxassetid://9113938822", 0.04, 0.4)




local function tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
    t:Play()
    return t
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end


local function newGui(name, order)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = order
    g.Parent = playerGui
    return g
end

----------------------------------------------------------------- hud
local hud = newGui("NightHud", 30)
--everything on the hud stays clear of notches and the roblox buttons
hud.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
--sizes that shrink on a phone, set by layoutHud
local objWidth, rowHeight, rowText = 250, 20, 15
local alertHeight, alertText = 30, 16

local clockLabel = Instance.new("TextLabel")
clockLabel.AnchorPoint = Vector2.new(0.5, 0)
clockLabel.Position = UDim2.new(0.5, 0, 0, 10)
clockLabel.Size = UDim2.fromOffset(240, 46)
clockLabel.BackgroundTransparency = 1
clockLabel.Font = Enum.Font.Code
clockLabel.TextSize = 42
clockLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
clockLabel.TextStrokeTransparency = 0.55
clockLabel.Text = "12 AM"
clockLabel.Visible = false
clockLabel.Parent = hud

local pips = Instance.new("Frame")
pips.AnchorPoint = Vector2.new(0.5, 0)
pips.Position = UDim2.new(0.5, 0, 0, 58)
pips.Size = UDim2.fromOffset(80, 12)
pips.BackgroundTransparency = 1
pips.Visible = false
pips.Parent = hud
local pipLayout = Instance.new("UIListLayout")
pipLayout.FillDirection = Enum.FillDirection.Horizontal
pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
pipLayout.Padding = UDim.new(0, 10)
pipLayout.Parent = pips
local pipFrames = {}
for i = 1, 3 do
    local p = Instance.new("Frame")
    p.Size = UDim2.fromOffset(12, 12)
    p.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    p.BorderSizePixel = 0
    corner(p, 6)
    p.Parent = pips
    pipFrames[i] = p
end

local alertBox = Instance.new("Frame")
alertBox.AnchorPoint = Vector2.new(0.5, 0)
alertBox.Position = UDim2.new(0.5, 0, 0, 82)
alertBox.Size = UDim2.fromOffset(600, 200)
alertBox.BackgroundTransparency = 1
alertBox.Parent = hud
local alertLayout = Instance.new("UIListLayout")
alertLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
alertLayout.Padding = UDim.new(0, 6)
alertLayout.Parent = alertBox

----------------------------------------------------------------- tonight's jobs
local TASK_LABEL = {mess = "clean a mess", line = "help a customer", window = "get the window", vape = "take a vape hit", garbage = "take out the garbage"}
local objPanel = Instance.new("Frame")
objPanel.Position = UDim2.fromOffset(22, 20)
objPanel.Size = UDim2.fromOffset(250, 0)
objPanel.AutomaticSize = Enum.AutomaticSize.Y
objPanel.BackgroundTransparency = 1
objPanel.Visible = false
objPanel.Parent = hud
local objLayout = Instance.new("UIListLayout")
objLayout.SortOrder = Enum.SortOrder.LayoutOrder
objLayout.Padding = UDim.new(0, 5)
objLayout.Parent = objPanel
local objTitle = Instance.new("TextLabel")
objTitle.Size = UDim2.fromOffset(250, 18)
objTitle.BackgroundTransparency = 1
objTitle.Font = Enum.Font.Code
objTitle.TextSize = 14
objTitle.TextXAlignment = Enum.TextXAlignment.Left
objTitle.TextColor3 = Color3.fromRGB(165, 165, 170)
objTitle.TextStrokeTransparency = 0.7
objTitle.LayoutOrder = 0
objTitle.Parent = objPanel
local objRows = {}

local STATUS_LOOK = {
    pending = {dot = Color3.fromRGB(120, 120, 126), text = Color3.fromRGB(175, 175, 180), fill = false},
    active = {dot = Color3.fromRGB(255, 212, 110), text = Color3.fromRGB(245, 232, 205), fill = true},
    done = {dot = Color3.fromRGB(110, 190, 130), text = Color3.fromRGB(125, 135, 128), fill = true, strike = true},
    missed = {dot = Color3.fromRGB(205, 78, 70), text = Color3.fromRGB(190, 110, 100), fill = true, strike = true},
    cancel = {dot = Color3.fromRGB(110, 110, 115), text = Color3.fromRGB(115, 115, 120), fill = false, strike = true},
}


--redraws the list from the server copy, so it always matches what actually counts
local function refreshObjectives()
    for _, r in ipairs(objRows) do r:Destroy() end
    objRows = {}
    local ok, list = pcall(function() return HttpService:JSONDecode(workspace:GetAttribute("Objectives") or "[]") end)
    if not ok or type(list) ~= "table" then list = {} end
    local done, need = 0, 0
    for _, o in ipairs(list) do
        if o.r ~= 1 then need += 1 end
        if o.s == "done" then done += 1 end
    end
    --a phone only has room for what is happening now and what is next, the rest is counted in one line
    local show = {}
    if MobileUI.isCompact() then
        local MAX = 4
        for _, status in ipairs({"active", "pending"}) do
            for i, o in ipairs(list) do
                if #show < MAX and (o.s or "pending") == status then table.insert(show, i) end
            end
        end
        --nearly finished nights fill the spare rows with the latest finished jobs
        for i = #list, 1, -1 do
            if #show < MAX and not table.find(show, i) then table.insert(show, i) end
        end
    else
        for i = 1, #list do table.insert(show, i) end
    end
    for order, i in ipairs(show) do
        local o = list[i]
        local look = STATUS_LOOK[o.s] or STATUS_LOOK.pending
        local row = Instance.new("Frame")
        row.Size = UDim2.fromOffset(objWidth, rowHeight)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = objPanel
        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0, 0.5)
        dot.Position = UDim2.new(0, 2, 0.5, 0)
        dot.Size = UDim2.fromOffset(9, 9)
        dot.BackgroundColor3 = look.dot
        dot.BackgroundTransparency = look.fill and 0 or 1
        corner(dot, 5)
        local ds = Instance.new("UIStroke")
        ds.Color = look.dot
        ds.Thickness = 1.2
        ds.Parent = dot
        dot.Parent = row
        local l = Instance.new("TextLabel")
        l.Position = UDim2.fromOffset(20, 0)
        l.Size = UDim2.new(1, -20, 1, 0)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = rowText
        l.RichText = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = look.text
        l.TextStrokeTransparency = 0.75
        local txt = (TASK_LABEL[o.c] or o.c) .. (o.r == 1 and "  (again)" or "")
        l.Text = look.strike and ("<s>" .. txt .. "</s>") or txt
        l.Parent = row
        table.insert(objRows, row)
    end
    if #show < #list then
        local more = Instance.new("TextLabel")
        more.Size = UDim2.fromOffset(objWidth, rowHeight)
        more.BackgroundTransparency = 1
        more.LayoutOrder = 99
        more.Font = Enum.Font.Gotham
        more.TextSize = rowText - 1
        more.TextXAlignment = Enum.TextXAlignment.Left
        more.TextColor3 = Color3.fromRGB(140, 140, 146)
        more.TextStrokeTransparency = 0.8
        more.Text = "     +" .. (#list - #show) .. " more"
        more.Parent = objPanel
        table.insert(objRows, more)
    end
    objTitle.Text = string.format("TONIGHT  -  %s  -  %d/%d", string.upper(workspace:GetAttribute("Difficulty") or "normal"), math.min(done, need), need)
end
workspace:GetAttributeChangedSignal("Objectives"):Connect(refreshObjectives)
refreshObjectives()

local alerts = {}


local function addAlert(name, text, color)
    if alerts[name] then alerts[name]:Destroy() end
    local l = Instance.new("TextLabel")
    l.AutomaticSize = Enum.AutomaticSize.X
    l.Size = UDim2.fromOffset(0, alertHeight)
    l.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = alertText
    l.TextColor3 = color or Color3.fromRGB(235, 235, 235)
    l.TextTransparency = 1
    l.Text = text
    l.RichText = true
    l:SetAttribute("BaseText", text)
    l:SetAttribute("Task", name)
    corner(l, 15)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = l
    l.Parent = alertBox
    alerts[name] = l
    tween(l, 0.5, {BackgroundTransparency = 0.35, TextTransparency = 0})
    return l
end



local function removeAlert(name)
    local l = alerts[name]
    if not l then return end
    alerts[name] = nil
    tween(l, 0.5, {BackgroundTransparency = 1, TextTransparency = 1})
    task.delay(0.6, function() l:Destroy() end)
end


--phone layout: a smaller clock, a narrower job list on the left and the alerts down the right under the clock
local function layoutHud()
    local compact = MobileUI.isCompact()
    clockLabel.TextSize = compact and 30 or 42
    clockLabel.Size = UDim2.fromOffset(compact and 150 or 240, compact and 34 or 46)
    clockLabel.Position = UDim2.new(0.5, 0, 0, compact and 2 or 10)
    objWidth = compact and 200 or 250
    rowHeight = compact and 17 or 20
    rowText = compact and 13 or 15
    objPanel.Position = UDim2.fromOffset(compact and 12 or 22, compact and 6 or 20)
    objPanel.Size = UDim2.fromOffset(objWidth, 0)
    objTitle.Size = UDim2.fromOffset(objWidth, compact and 16 or 18)
    objTitle.TextSize = compact and 12 or 14
    objLayout.Padding = UDim.new(0, compact and 3 or 5)
    alertHeight = compact and 28 or 30
    alertText = compact and 14 or 16
    if compact then
        alertBox.AnchorPoint = Vector2.new(1, 0)
        --at the cameras the close button owns the top right corner, so the alerts start under it
        local top = player:GetAttribute("Seated") and 90 or 42
        alertBox.Position = UDim2.new(1, -12, 0, top)
        alertBox.Size = UDim2.new(0.5, -40, 0, 200)
        alertLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    else
        alertBox.AnchorPoint = Vector2.new(0.5, 0)
        alertBox.Position = UDim2.new(0.5, 0, 0, 82)
        alertBox.Size = UDim2.fromOffset(600, 200)
        alertLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    for _, l in pairs(alerts) do
        l.Size = UDim2.fromOffset(0, alertHeight)
        l.TextSize = alertText
    end
    refreshObjectives()
end
MobileUI.watch(layoutHud)
player:GetAttributeChangedSignal("Seated"):Connect(layoutHud)

--shrinks a fixed size panel just enough to fit a small screen with a margin, returns the scale used
local function fitPanel(panel, width, height)
    local vp = camera.ViewportSize
    local s = math.min(1, (vp.X - 110) / width, (vp.Y - 20) / height)
    if s < 1 then
        local sc = Instance.new("UIScale")
        sc.Scale = s
        sc.Parent = panel
        return s
    end
    return 1
end


--screen position of a mouse or finger in the same space as AbsolutePosition
local function pointerPos(input)
    if input and input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
    end
    return UIS:GetMouseLocation()
end

----------------------------------------------------------------- clock

local function nightSeconds()
    local start = workspace:GetAttribute("NightStart")
    if not start then return 0 end
    return math.max(0, workspace:GetServerTimeNow() - start)
end

local lastHour = -1
RunService.RenderStepped:Connect(function()
    local on = workspace:GetAttribute("NightActive") == true
    clockLabel.Visible = on
    --strikes are gone, the job list shows how the night is going instead
    pips.Visible = false
    --the running list of every job is gone, jobs only show as alerts when they come in
    objPanel.Visible = false
    --each task carries its own small countdown, read from the server so it can never be reset
    for name, l in pairs(alerts) do
        local left = workspace:GetAttribute("TaskLeft_" .. name)
        local base = l:GetAttribute("BaseText")
        if left and base then
            local secs = math.ceil(left)
            local color = "#BEBEBE"
            if left <= 8 then
                --warms toward red as it runs out, no flashing
                local k = 1 - left / 8
                color = string.format("#%02X%02X%02X", 235, math.floor(190 - 120 * k), math.floor(170 - 120 * k))
            end
            l.Text = string.format('%s   <font color="%s" face="Code">0:%02d</font>', base, color, secs)
        end
    end
    if on then
        local hour = math.min(5, math.floor(nightSeconds() / 60))
        if hour ~= lastHour then
            lastHour = hour
            clockLabel.Text = hour == 0 and "12 AM" or (hour .. " AM")
        end
    end
end)

----------------------------------------------------------------- freezing the world while a minigame is open
local locked = false
local savedControls = nil
local blockKeys = {
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
    Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1,
}




local function lockWorld(on)
    if on == locked then return end
    locked = on
    if on then
        if not player:GetAttribute("Seated") then
            local saved = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = saved
        end
        CAS:BindActionAtPriority("NightFreeze", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 200, table.unpack(blockKeys))
        local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
        if pm then
            local ok, mod = pcall(require, pm)
            if ok then savedControls = mod:GetControls() savedControls:Disable() end
        end
        RunService:BindToRenderStep("NightMouse", Enum.RenderPriority.Last.Value, function()
            UIS.MouseBehavior = Enum.MouseBehavior.Default
            UIS.MouseIconEnabled = true
        end)
    else
        RunService:UnbindFromRenderStep("NightMouse")
        CAS:UnbindAction("NightFreeze")
        if savedControls then savedControls:Enable() savedControls = nil end
        if not player:GetAttribute("Seated") then
            camera.CameraType = Enum.CameraType.Custom
        end
    end
end


local function shuffle(list)
    local copy = {table.unpack(list)}
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end


local function makePanel(gui, width, height, title)
    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.45
    dim.BorderSizePixel = 0
    dim.Parent = gui
    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(width, height)
    panel.BackgroundColor3 = Color3.fromRGB(22, 24, 27)
    panel.BorderSizePixel = 0
    corner(panel, 10)
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(255, 255, 255)
    st.Transparency = 0.8
    st.Parent = panel
    panel.Parent = gui
    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(24, 16)
    t.Size = UDim2.new(1, -90, 0, 28)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 18
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(235, 235, 235)
    t.Text = title
    t.Parent = panel
    local x = Instance.new("TextButton")
    x.AnchorPoint = Vector2.new(1, 0)
    x.Position = UDim2.new(1, -10, 0, 10)
    --a full size thumb target on phones
    x.Size = MobileUI.isCompact() and UDim2.fromOffset(46, 42) or UDim2.fromOffset(34, 30)
    x.BackgroundColor3 = Color3.fromRGB(50, 52, 56)
    x.BorderSizePixel = 0
    x.Font = Enum.Font.GothamBold
    x.TextSize = 16
    x.TextColor3 = Color3.fromRGB(230, 230, 230)
    x.Text = "X"
    corner(x, 6)
    x.Parent = panel
    return panel, x
end

----------------------------------------------------------------- wire minigame
local wiresGui = nil
local WIRE_COLORS = {Color3.fromRGB(220, 60, 60), Color3.fromRGB(70, 120, 235), Color3.fromRGB(235, 200, 50), Color3.fromRGB(220, 90, 200)}


local function closeWires()
    if not wiresGui then return end
    wiresGui:Destroy()
    wiresGui = nil
    lockWorld(false)
end



local function openWires()
    if wiresGui then return end
    lockWorld(true)
    wiresGui = newGui("WiresGui", 40)
    local panel, x = makePanel(wiresGui, 560, 380, "breaker panel  -  connect the matching wires")
    x.MouseButton1Click:Connect(closeWires)
    local scale = fitPanel(panel, 560, 380)

    local leftOrder = shuffle({1, 2, 3, 4})
    local rightOrder = shuffle({1, 2, 3, 4})
    local leftNodes = {}
    local rightNodes = {}
    local connected = 0
    local dragging = nil
    local dragLine = nil

    local function makeNode(colorIndex, xPos, row)
        local n = Instance.new("Frame")
        n.Size = UDim2.fromOffset(54, 36)
        n.Position = UDim2.fromOffset(xPos, 92 + (row - 1) * 64)
        n.BackgroundColor3 = WIRE_COLORS[colorIndex]
        n.BorderSizePixel = 0
        corner(n, 6)
        n.Parent = panel
        n:SetAttribute("Color", colorIndex)
        return n
    end
    for row, c in ipairs(leftOrder) do leftNodes[row] = makeNode(c, 36, row) end
    for row, c in ipairs(rightOrder) do rightNodes[row] = makeNode(c, 560 - 36 - 54, row) end

    --positions inside the panel before it is scaled down, so lines land on the nodes on any screen
    local function center(node)
        return (node.AbsolutePosition - panel.AbsolutePosition + node.AbsoluteSize / 2) / scale
    end
    local function newLine(color)
        local l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.BackgroundColor3 = color
        l.BorderSizePixel = 0
        l.ZIndex = 5
        corner(l, 4)
        l.Parent = panel
        return l
    end
    local function setLine(l, a, b)
        local d = b - a
        l.Size = UDim2.fromOffset(d.Magnitude, 8)
        l.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
        l.Rotation = math.deg(math.atan2(d.Y, d.X))
    end

    for _, node in ipairs(leftNodes) do
        node.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if node:GetAttribute("Done") then return end
            dragging = node
            dragLine = newLine(node.BackgroundColor3)
            setLine(dragLine, center(node), center(node))
        end)
    end

    local moveConn = UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local m = (pointerPos(input) - panel.AbsolutePosition) / scale
            setLine(dragLine, center(dragging), m)
        end
    end)
    local endConn = UIS.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local m = pointerPos(input)
        local hitNode = nil
        for _, node in ipairs(rightNodes) do
            local p, s = node.AbsolutePosition, node.AbsoluteSize
            if m.X >= p.X - 8 and m.X <= p.X + s.X + 8 and m.Y >= p.Y - 8 and m.Y <= p.Y + s.Y + 8 then hitNode = node end
        end
        if hitNode and hitNode:GetAttribute("Color") == dragging:GetAttribute("Color") and not hitNode:GetAttribute("Done") then
            setLine(dragLine, center(dragging), center(hitNode))
            hitNode:SetAttribute("Done", true)
            dragging:SetAttribute("Done", true)
            click:Play()
            connected += 1
            if connected >= 4 then
                task.delay(0.5, function()
                    if wiresGui then
                        closeWires()
                        ev:FireServer("wiresDone")
                    end
                end)
            end
        else
            dragLine:Destroy()
        end
        dragging = nil
        dragLine = nil
    end)
    wiresGui.Destroying:Connect(function()
        moveConn:Disconnect()
        endConn:Disconnect()
    end)
end

----------------------------------------------------------------- order builder
local orderGui = nil


local function closeOrder()
    if not orderGui then return end
    orderGui:Destroy()
    orderGui = nil
    lockWorld(false)
end

local CATS = {
    {key = "container", label = "container", options = {"bowl", "burrito"}, multi = false},
    {key = "protein", label = "protein", options = {"chicken", "steak", "carnitas", "sofritas"}, multi = false},
    {key = "rice", label = "rice", options = {"white rice", "brown rice", "no rice"}, multi = false},
    {key = "beans", label = "beans", options = {"black beans", "pinto beans", "no beans"}, multi = false},
    {key = "toppings", label = "toppings (pick 2)", options = {"salsa", "cheese", "lettuce", "guac"}, multi = true},
}


local function openOrder(order)
    if orderGui then return end
    lockWorld(true)
    orderGui = newGui("OrderGui", 40)
    --on a phone the panel takes most of the screen with taller buttons, on a computer it keeps its old size
    local compact = MobileUI.isCompact()
    local vp = camera.ViewportSize
    local pw = compact and math.min(760, vp.X - 110) or 760
    local ph = compact and math.min(440, vp.Y - 16) or 440
    local ticketW = compact and 150 or 190
    local top = compact and 52 or 64
    local rowGap = compact and math.floor((ph - top - 60) / 5) or 60
    local labelH = compact and 14 or 18
    local btnH = compact and math.max(32, rowGap - 20) or 30
    local leftX = 24 + ticketW + (compact and 16 or 26)
    local btnW = compact and math.min(118, math.floor((pw - leftX - 24 - 24) / 4)) or 118
    local panel, x = makePanel(orderGui, pw, ph, "make the order")
    x.MouseButton1Click:Connect(closeOrder)

    --ticket on the left
    local ticket = Instance.new("Frame")
    ticket.Position = UDim2.fromOffset(24, top)
    ticket.Size = UDim2.fromOffset(ticketW, ph - top - (compact and 14 or 36))
    ticket.BackgroundColor3 = Color3.fromRGB(236, 232, 220)
    ticket.BorderSizePixel = 0
    ticket.Parent = panel
    local tt = Instance.new("TextLabel")
    tt.Size = UDim2.fromScale(1, 1)
    tt.BackgroundTransparency = 1
    tt.Font = Enum.Font.Code
    tt.TextSize = compact and 15 or 19
    tt.TextColor3 = Color3.fromRGB(30, 30, 30)
    tt.TextXAlignment = Enum.TextXAlignment.Left
    tt.TextYAlignment = Enum.TextYAlignment.Top
    tt.TextWrapped = true
    tt.Text = "ORDER\n------------\n" .. order.container .. "\n" .. order.protein .. "\n" .. order.rice .. "\n" .. order.beans .. "\n" .. order.toppings[1] .. "\n" .. order.toppings[2]
    local tp = Instance.new("UIPadding")
    tp.PaddingLeft = UDim.new(0, 14)
    tp.PaddingTop = UDim.new(0, 14)
    tp.Parent = tt
    tt.Parent = ticket

    local selection = {toppings = {}}
    local buttons = {}
    local function paint()
        for _, c in ipairs(CATS) do
            for opt, b in pairs(buttons[c.key]) do
                local picked
                if c.multi then picked = table.find(selection.toppings, opt) ~= nil else picked = selection[c.key] == opt end
                b.BackgroundColor3 = picked and Color3.fromRGB(110, 200, 140) or Color3.fromRGB(48, 50, 55)
                b.TextColor3 = picked and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(230, 230, 230)
            end
        end
    end

    for row, c in ipairs(CATS) do
        local y = top + (row - 1) * rowGap
        local lab = Instance.new("TextLabel")
        lab.Position = UDim2.fromOffset(leftX, y)
        lab.Size = UDim2.fromOffset(300, labelH)
        lab.BackgroundTransparency = 1
        lab.Font = Enum.Font.Gotham
        lab.TextSize = 13
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.TextColor3 = Color3.fromRGB(160, 160, 165)
        lab.Text = c.label
        lab.Parent = panel
        buttons[c.key] = {}
        for i, opt in ipairs(c.options) do
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(leftX + (i - 1) * (btnW + 8), y + labelH + 2)
            b.Size = UDim2.fromOffset(btnW, btnH)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Font = Enum.Font.Gotham
            b.TextSize = 15
            b.Text = opt
            --long words shrink to fit a narrow phone button instead of spilling out
            if compact then
                b.TextScaled = true
                local lim = Instance.new("UITextSizeConstraint")
                lim.MaxTextSize = 15
                lim.MinTextSize = 9
                lim.Parent = b
                local bp = Instance.new("UIPadding")
                bp.PaddingLeft = UDim.new(0, 4)
                bp.PaddingRight = UDim.new(0, 4)
                bp.Parent = b
            end
            corner(b, 6)
            b.Parent = panel
            buttons[c.key][opt] = b
            b.MouseButton1Click:Connect(function()
                if c.multi then
                    local at = table.find(selection.toppings, opt)
                    if at then
                        table.remove(selection.toppings, at)
                    elseif #selection.toppings < 2 then
                        table.insert(selection.toppings, opt)
                    end
                else
                    selection[c.key] = opt
                end
                ding:Play()
                paint()
            end)
        end
    end
    paint()

    local serve = Instance.new("TextButton")
    serve.AnchorPoint = Vector2.new(1, 1)
    serve.Position = UDim2.new(1, -24, 1, compact and -12 or -20)
    serve.Size = UDim2.fromOffset(150, compact and 42 or 38)
    serve.BackgroundColor3 = Color3.fromRGB(200, 70, 50)
    serve.BorderSizePixel = 0
    serve.Font = Enum.Font.GothamBold
    serve.TextSize = 16
    serve.TextColor3 = Color3.fromRGB(245, 245, 245)
    serve.Text = "serve it"
    corner(serve, 8)
    serve.Parent = panel
    serve.MouseButton1Click:Connect(function()
        ev:FireServer("orderSubmit", selection)
    end)
end


local function orderWrong()
    if not orderGui then return end
    local l = Instance.new("TextLabel")
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.Position = UDim2.new(0.5, 0, 0, 90)
    l.Size = UDim2.fromOffset(360, 34)
    l.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.TextColor3 = Color3.fromRGB(245, 245, 245)
    l.Text = "that is not what they ordered"
    corner(l, 8)
    l.Parent = orderGui
    task.delay(1.6, function() l:Destroy() end)
end

----------------------------------------------------------------- phone call
local PHONE_POS = Vector3.new(36.75, 3.7, -21)
local callToken = 0

--opts is only sent for the manager's night 1 call: a different name, slower, and walking away does not hang up
local function playCall(lines, opts)
    opts = opts or {}
    callToken += 1
    local mine = callToken
    local g = newGui("CallGui", 35)
    local compact = MobileUI.isCompact()
    local bar = Instance.new("Frame")
    --on a phone the bottom corners belong to the thumbs, so the caption sits up top under the clock
    if compact then
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.Position = UDim2.new(0.5, 0, 0, 46)
        bar.Size = UDim2.new(0, math.min(560, camera.ViewportSize.X - 280), 0, 84)
    else
        bar.AnchorPoint = Vector2.new(0.5, 1)
        bar.Position = UDim2.new(0.5, 0, 1, -90)
        bar.Size = UDim2.fromOffset(780, 92)
    end
    bar.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    bar.BackgroundTransparency = 0.3
    corner(bar, 10)
    bar.Parent = g
    local who = Instance.new("TextLabel")
    who.Position = UDim2.fromOffset(20, 8)
    who.Size = UDim2.fromOffset(300, 18)
    who.BackgroundTransparency = 1
    who.Font = Enum.Font.Code
    who.TextSize = 14
    who.TextXAlignment = Enum.TextXAlignment.Left
    who.TextColor3 = Color3.fromRGB(220, 170, 70)
    who.Text = opts.caller or "ANGRY CUSTOMER  (on the phone)"
    who.Parent = bar
    local text = Instance.new("TextLabel")
    text.Position = UDim2.fromOffset(20, 30)
    text.Size = UDim2.new(1, -40, 1, -38)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.Gotham
    text.TextSize = compact and 16 or 20
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.TextColor3 = Color3.fromRGB(240, 240, 240)
    text.Text = ""
    text.Parent = bar

    --hanging up by walking away counts as a dropped call
    task.spawn(function()
        while callToken == mine and g.Parent and not opts.tutorial do
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - PHONE_POS).Magnitude > 30 then
                callToken += 1
                g:Destroy()
                ev:FireServer("callDropped")
                return
            end
            task.wait(0.4)
        end
    end)

    for _, line in ipairs(lines) do
        for i = 1, #line do
            if callToken ~= mine then return end
            text.Text = string.sub(line, 1, i)
            if i % 2 == 0 then
                blip.PlaybackSpeed = 0.3 + math.random() * 0.25
                blip:Play()
            end
            task.wait(0.03)
        end
        task.wait(opts.tutorial and 3.6 or 1.5)
    end
    if callToken ~= mine then return end
    callToken += 1
    g:Destroy()
    if not opts.tutorial then ev:FireServer("callDone") end
end

----------------------------------------------------------------- incoming call popup
--sits on the left and works from anywhere, including while watching the cameras
local ringGui = nil



local function hideRing()
    if ringGui then
        ringGui:Destroy()
        ringGui = nil
    end
end


local function ringButton(parent, label, y, color)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = true
    b.Position = UDim2.new(0, 0, 0, y)
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.15
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 16
    b.TextColor3 = Color3.fromRGB(245, 245, 245)
    b.Text = label
    corner(b, 8)
    b.Parent = parent
    return b
end

local function showRing()
    hideRing()
    ding:Play()
    local g = newGui("RingGui", 38)
    g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    ringGui = g
    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0, 0.5)
    box.Position = UDim2.new(0, -200, 0.45, 0)
    box.Size = UDim2.fromOffset(170, 96)
    box.BackgroundTransparency = 1
    box.Parent = g
    local accept = ringButton(box, "Accept call", 0, Color3.fromRGB(46, 120, 70))
    local decline = ringButton(box, "Decline call", 52, Color3.fromRGB(45, 45, 50))
    tween(box, 0.35, {Position = UDim2.new(0, 16, 0.45, 0)})
    accept.MouseButton1Click:Connect(function()
        click:Play()
        hideRing()
        ev:FireServer("acceptCall")
    end)
    decline.MouseButton1Click:Connect(function()
        click:Play()
        hideRing()
        ev:FireServer("declineCall")
    end)
end

----------------------------------------------------------------- vape in the walk in
local inhaleSnd = makeSound("rbxassetid://9113702955", 0.16, 0.6)
local exhaleSnd = makeSound("rbxassetid://9113702967", 0.5, 0.82)
local vapeModel = nil
local vapeRun = 0
local vapeControls = nil
local vapeWallParams = RaycastParams.new()
vapeWallParams.FilterType = Enum.RaycastFilterType.Exclude
local moveKeys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.LeftShift}


local function stopVape(tellServer)
    if not vapeModel then return end
    vapeRun += 1
    RunService:UnbindFromRenderStep("VapeView")
    vapeModel:Destroy()
    vapeModel = nil
    if tellServer then ev:FireServer("vapeCancel") end
end


local function vapePart(name, size, color, material, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end


--the cloud is left hanging in the room where it was blown, it drifts and thins out on its own
local function exhaleCloud(cf)
    local holder = vapePart("VapeCloud", Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), nil, workspace)
    holder.Transparency = 1
    holder.CFrame = cf
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Color = ColorSequence.new(Color3.fromRGB(232, 234, 238))
    e.LightEmission = 0.05
    e.LightInfluence = 0.8
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.35, 1.8), NumberSequenceKeypoint.new(1, 4.2)})
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.25, 0.62), NumberSequenceKeypoint.new(1, 1)})
    e.Lifetime = NumberRange.new(2.6, 4.2)
    e.Speed = NumberRange.new(2.5, 4.5)
    e.SpreadAngle = Vector2.new(14, 14)
    e.EmissionDirection = Enum.NormalId.Front
    e.Acceleration = Vector3.new(0, 0.4, 0)
    e.Drag = 1.6
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-25, 25)
    e.Rate = 0
    e.Parent = holder
    task.spawn(function()
        --a long breath out, strong at first then trailing off
        for i = 1, 14 do
            e:Emit(i < 5 and 4 or 2)
            task.wait(0.08)
        end
        task.wait(5)
        holder:Destroy()
    end)
end


--a short head rush after the hit: the room swims, colours get richer and a bit brighter, the view breathes in and out
local function headRush()
    local blur = Instance.new("BlurEffect")
    blur.Name = "VapeRushBlur"
    blur.Size = 0
    blur.Parent = camera
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "VapeRushColor"
    cc.Parent = camera
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local fov0 = camera.FieldOfView
    local t0 = os.clock()
    local DUR = 3.2
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local t = os.clock() - t0
        if t >= DUR or not blur.Parent then
            conn:Disconnect()
            blur:Destroy()
            cc:Destroy()
            if hum then hum.CameraOffset = Vector3.zero end
            camera.FieldOfView = fov0
            return
        end
        --comes on fast and fades out slowly
        local k = math.min(1, t / 0.35) * (1 - math.clamp((t - 0.6) / (DUR - 0.6), 0, 1))
        blur.Size = 7 * k
        cc.Saturation = 0.4 * k
        cc.Contrast = 0.06 * k
        cc.Brightness = 0.07 * k
        cc.TintColor = Color3.new(1, 1, 1)
        --a slow swimming sway of the view
        if hum then hum.CameraOffset = Vector3.new(math.sin(t * 1.7) * 0.12 * k, math.sin(t * 2.3) * 0.06 * k, 0) end
        camera.FieldOfView = fov0 + math.sin(t * 2.1) * 3 * k
    end)
end


local function playVape()
    if vapeModel then return end
    vapeRun += 1
    local mine = vapeRun
    --the player keeps walking around while they hit it
    local char = player.Character
    local handSrc = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
    local skin = handSrc and handSrc.Color or Color3.fromRGB(200, 160, 130)
    vapeModel = Instance.new("Model")
    vapeModel.Name = "VapeViewmodel"
    vapeModel.Parent = camera
    --the whole hand is built small and close to the eye, it looks the same size on screen
    --but sits inside the gap between the face and any wall so it can never sink into one
    local S = 0.4
    local function at(x, y, z)
        return CFrame.new(x * S, y * S, z * S)
    end
    local metal = Color3.fromRGB(38, 42, 52)
    --pod vape: flat body, glossy front panel, clear pod with juice, tapered mouthpiece, little led
    local body = vapePart("Body", Vector3.new(0.13, 0.36, 0.06) * S, metal, Enum.Material.Metal, vapeModel)
    body.Reflectance = 0.12
    local panel = vapePart("Panel", Vector3.new(0.11, 0.22, 0.008) * S, Color3.fromRGB(70, 40, 110), Enum.Material.Glass, vapeModel)
    panel.Reflectance = 0.25
    local pod = vapePart("Pod", Vector3.new(0.12, 0.1, 0.055) * S, Color3.fromRGB(150, 200, 230), Enum.Material.Glass, vapeModel)
    pod.Transparency = 0.35
    local juice = vapePart("Juice", Vector3.new(0.1, 0.05, 0.04) * S, Color3.fromRGB(120, 220, 160), nil, vapeModel)
    juice.Transparency = 0.2
    local mouth = vapePart("Mouthpiece", Vector3.new(0.07, 0.07, 0.035) * S, Color3.fromRGB(18, 18, 22), nil, vapeModel)
    local lip = vapePart("Lip", Vector3.new(0.05, 0.025, 0.025) * S, Color3.fromRGB(18, 18, 22), nil, vapeModel)
    local led = vapePart("Led", Vector3.new(0.03, 0.012, 0.004) * S, Color3.fromRGB(30, 34, 40), nil, vapeModel)
    --a hand wrapped round it: palm behind, four finger segments across the front, thumb up the side
    local palm = vapePart("Palm", Vector3.new(0.17, 0.2, 0.1) * S, skin, nil, vapeModel)
    local fingerParts = {}
    for i = 1, 4 do
        fingerParts[i] = vapePart("Finger" .. i, Vector3.new(0.17, 0.045, 0.05) * S, skin, nil, vapeModel)
    end
    local thumb = vapePart("Thumb", Vector3.new(0.05, 0.14, 0.055) * S, skin, nil, vapeModel)
    local wrist = vapePart("Wrist", Vector3.new(0.14, 0.3, 0.12) * S, skin, nil, vapeModel)
    --device poses in camera space, the long axis of the vape is its y
    local K_HIDE = at(0.55, -1.25, -1.1) * CFrame.Angles(math.rad(-15), 0, math.rad(14))
    local K_OUT = at(0.32, -0.62, -1.05) * CFrame.Angles(math.rad(8), math.rad(-10), math.rad(-6))
    --the mouthpiece meets the lips just under the eyes, the device tilted out and down away from the face
    local MOUTH = at(0, -0.34, -0.55)
    local K_MOUTH = MOUTH * CFrame.Angles(math.rad(70), 0, 0) * at(0, -0.37, 0)
    local K_AWAY = at(0.4, -0.7, -1) * CFrame.Angles(math.rad(14), math.rad(-6), math.rad(-10))
    local cur = K_HIDE
    local glow = 0
    RunService:BindToRenderStep("VapeView", Enum.RenderPriority.Camera.Value + 3, function()
        --a wall right in front of the face pulls the hand back toward the body instead of letting it sink into the wall
        vapeWallParams.FilterDescendantsInstances = {player.Character, vapeModel}
        local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1.5 * S, vapeWallParams)
        local pull = 0
        if hit then pull = math.clamp(1.35 * S - hit.Distance, 0, 0.5 * S) end
        --a small bob while walking
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local move = hum and hum.MoveDirection.Magnitude or 0
        local t = os.clock()
        local bob = CFrame.new(math.sin(t * 7) * 0.008 * move, math.abs(math.sin(t * 7)) * 0.01 * move, 0)
        local base = camera.CFrame * CFrame.new(0, -pull * 0.3, pull) * bob * cur
        body.CFrame = base
        panel.CFrame = base * at(0, -0.03, -0.032)
        pod.CFrame = base * at(0, 0.225, 0)
        juice.CFrame = base * at(0, 0.21, 0)
        mouth.CFrame = base * at(0, 0.31, 0)
        lip.CFrame = base * at(0, 0.355, 0)
        led.CFrame = base * at(0, -0.155, -0.031)
        led.Color = Color3.fromRGB(30, 34, 40):Lerp(Color3.fromRGB(150, 110, 255), glow)
        --the hand grips the lower half of the body
        palm.CFrame = base * at(0.02, -0.08, 0.07)
        for i, f in ipairs(fingerParts) do
            f.CFrame = base * at(0.015, -0.005 - i * 0.046, -0.05) * CFrame.Angles(0, 0, math.rad(4))
        end
        thumb.CFrame = base * at(-0.085, -0.02, 0) * CFrame.Angles(0, 0, math.rad(-12))
        wrist.CFrame = base * at(0.04, -0.32, 0.1) * CFrame.Angles(math.rad(-10), 0, 0)
    end)
    local function moveTo(goal, time)
        local from = cur
        local t0 = os.clock()
        while true do
            if vapeRun ~= mine then return false end
            local a = math.clamp((os.clock() - t0) / time, 0, 1)
            cur = from:Lerp(goal, TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
            if a >= 1 then return true end
            RunService.RenderStepped:Wait()
        end
    end
    --out of the pocket, up to the lips
    if not moveTo(K_OUT, 0.4) then return end
    if not moveTo(K_MOUTH, 0.5) then return end
    --the hit: the led lights while they pull on it
    inhaleSnd:Play()
    local t0 = os.clock()
    while os.clock() - t0 < 1.3 do
        if vapeRun ~= mine then return end
        glow = math.clamp((os.clock() - t0) / 0.3, 0, 1)
        RunService.RenderStepped:Wait()
    end
    glow = 0
    --hand comes away and the cloud goes out in front of the face
    exhaleSnd:Play()
    exhaleCloud(camera.CFrame * CFrame.new(0, -0.25, -0.75))
    headRush()
    if not moveTo(K_AWAY, 0.45) then return end
    task.wait(1)
    if vapeRun ~= mine then return end
    if not moveTo(K_HIDE, 0.5) then return end
    stopVape(false)
    ev:FireServer("vapeDone")
end

----------------------------------------------------------------- garbage bag carried in first person
local bagModel = nil
local bagRun = 0
local rustle = makeSound("rbxassetid://9119717286", 0.35, 0.45)
local heave = makeSound("rbxassetid://9126254743", 0.5, 0.8)




local function stopBag()
    bagRun += 1
    RunService:UnbindFromRenderStep("BagView")
    if bagModel then bagModel:Destroy() bagModel = nil end
end

--the hand and bag are built small and close to the eye like the vape, so walls never swallow them
local BAG_S = 0.45


local function bagAt(x, y, z) return CFrame.new(x * BAG_S, y * BAG_S, z * BAG_S) end
local BAG_LOW = bagAt(0.45, -2.3, -1.1)
--held out low in front so the top of the bag stays in view
local BAG_HOLD = bagAt(0.8, -0.6, -1.9) * CFrame.Angles(math.rad(6), math.rad(-10), math.rad(4))
local BAG_BACK = bagAt(0.95, -0.8, -1.5) * CFrame.Angles(math.rad(-25), math.rad(-14), math.rad(10))
local BAG_THROW = bagAt(0.15, 0.25, -1.75) * CFrame.Angles(math.rad(40), math.rad(6), math.rad(-6))
local bagCur = BAG_LOW
local bagFree = nil

local function bagMove(goal, time, style, mine)
    local from = bagCur
    local t0 = os.clock()
    while true do
        if bagRun ~= mine then return false end
        local a = math.clamp((os.clock() - t0) / time, 0, 1)
        bagCur = from:Lerp(goal, TweenService:GetValue(a, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
        if a >= 1 then return true end
        RunService.RenderStepped:Wait()
    end
end


local function startBag()
    stopBag()
    local mine = bagRun
    local char = player.Character
    local handSrc = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
    local skin = handSrc and handSrc.Color or Color3.fromRGB(200, 160, 130)
    bagModel = Instance.new("Model")
    bagModel.Name = "BagViewmodel"
    bagModel.Parent = camera
    local function vp(name, size, color, shape)
        local p = Instance.new("Part")
        p.Name = name p.Size = size * BAG_S p.Color = color p.Material = Enum.Material.Plastic
        p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
        if shape then p.Shape = shape end
        p.Parent = bagModel
        return p
    end
    local bag = vp("Bag", Vector3.new(1.15, 1.35, 1.15), Color3.fromRGB(14, 14, 16), Enum.PartType.Ball)
    bag.Reflectance = 0.06
    local neck = vp("Neck", Vector3.new(0.22, 0.4, 0.22), Color3.fromRGB(14, 14, 16))
    local knot = vp("Knot", Vector3.new(0.32, 0.16, 0.32), Color3.fromRGB(14, 14, 16))
    local fist = vp("Fist", Vector3.new(0.24, 0.22, 0.22), skin)
    local wrist = vp("Wrist", Vector3.new(0.18, 0.5, 0.18), skin)
    bagCur = BAG_LOW
    bagFree = nil
    local t0 = os.clock()
    RunService:BindToRenderStep("BagView", Enum.RenderPriority.Camera.Value + 3, function()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local speed = hum and hum.MoveDirection.Magnitude or 0
        local t = os.clock() - t0
        --swings a little with each step and hangs heavy when standing
        local swing = CFrame.Angles(math.sin(t * 8) * 0.06 * speed, 0, math.sin(t * 4) * 0.08 * speed + math.sin(t * 1.3) * 0.015)
        local fistCF = camera.CFrame * bagCur * swing
        fist.CFrame = fistCF
        wrist.CFrame = fistCF * CFrame.new(0.04 * BAG_S, -0.3 * BAG_S, 0.12 * BAG_S) * CFrame.Angles(math.rad(-30), 0, 0)
        knot.CFrame = fistCF * CFrame.new(0, -0.15 * BAG_S, 0)
        neck.CFrame = fistCF * CFrame.new(0, -0.33 * BAG_S, 0)
        if bagFree then
            bag.CFrame = bagFree
        else
            bag.CFrame = fistCF * CFrame.new(0, -1.08 * BAG_S, 0) * CFrame.Angles(0, 0, math.sin(t * 4) * 0.1 * speed)
        end
    end)
    --hauled up out of the can
    rustle:Play()
    bagMove(BAG_HOLD, 0.6, Enum.EasingStyle.Quad, mine)
end




local function dumpBag()
    if not bagModel then return end
    local mine = bagRun
    task.spawn(function()
        --wind up, then heave it up and over the lip
        if not bagMove(BAG_BACK, 0.22, Enum.EasingStyle.Sine, mine) then return end
        if not bagMove(BAG_THROW, 0.28, Enum.EasingStyle.Quad, mine) then return end
        heave:Play()
        --the bag leaves the hand and carries on into the bin
        local bag = bagModel:FindFirstChild("Bag")
        local from = bag.CFrame
        local dir = camera.CFrame.LookVector
        local t0 = os.clock()
        local neck = bagModel:FindFirstChild("Neck")
        local knot = bagModel:FindFirstChild("Knot")
        if neck then neck.Transparency = 1 end
        if knot then knot.Transparency = 1 end
        while os.clock() - t0 < 0.45 do
            if bagRun ~= mine then return end
            local a = (os.clock() - t0) / 0.45
            bagFree = from + dir * (a * 3.2) + Vector3.new(0, math.sin(a * math.pi) * 0.6 - a * a * 1.6, 0)
            bag.Transparency = math.clamp((a - 0.5) * 2, 0, 1)
            RunService.RenderStepped:Wait()
        end
        bagMove(BAG_LOW, 0.4, Enum.EasingStyle.Sine, mine)
        stopBag()
    end)
end

player.CharacterAdded:Connect(stopBag)

----------------------------------------------------------------- victory
local cheer = makeSound("rbxassetid://132079977802654", 0.7, 1)
local cheer2 = makeSound("rbxassetid://105154404054447", 0.45, 1)
local CONFETTI_COLORS = {Color3.fromRGB(255, 82, 82), Color3.fromRGB(255, 196, 64), Color3.fromRGB(96, 210, 120), Color3.fromRGB(80, 160, 255), Color3.fromRGB(200, 110, 255), Color3.fromRGB(255, 140, 200), Color3.fromRGB(250, 250, 250)}


--paper confetti drawn on screen: two bursts from the bottom corners then a light fall from the top
local function confetti(seconds)
    local g = newGui("ConfettiGui", 72)
    local vp = camera.ViewportSize
    local pieces = {}
    local function spawnPiece(x, y, vx, vy)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Size = UDim2.fromOffset(math.random(6, 11), math.random(10, 17))
        f.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
        f.BorderSizePixel = 0
        f.Parent = g
        table.insert(pieces, {f = f, x = x, y = y, vx = vx, vy = vy, rot = math.random(0, 360), vr = math.random(-420, 420), phase = math.random() * 6, wob = 1 + math.random() * 2})
    end
    for i = 1, 70 do spawnPiece(0, vp.Y, math.random(250, 700), -math.random(750, 1200)) end
    for i = 1, 70 do spawnPiece(vp.X, vp.Y, -math.random(250, 700), -math.random(750, 1200)) end
    local t0 = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        local t = os.clock() - t0
        if t < seconds - 2 then
            for i = 1, 2 do spawnPiece(math.random() * vp.X, -20, math.random(-40, 40), math.random(60, 160)) end
        end
        for i = #pieces, 1, -1 do
            local p = pieces[i]
            p.vy = math.min(p.vy + 620 * dt, 230)
            p.vx *= (1 - 1.3 * dt)
            p.x += (p.vx + math.sin(t * p.wob + p.phase) * 45) * dt
            p.y += p.vy * dt
            p.rot += p.vr * dt
            p.f.Position = UDim2.fromOffset(p.x, p.y)
            p.f.Rotation = p.rot
            if p.y > vp.Y + 40 then
                p.f:Destroy()
                table.remove(pieces, i)
            end
        end
        if t > seconds + 3 then
            conn:Disconnect()
            g:Destroy()
        end
    end)
end




local function victoryCard(diff, done, need)
    local g = newGui("VictoryGui", 66)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.Parent = g
    local function label(text, font, size, y, color)
        local l = Instance.new("TextLabel")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Position = UDim2.fromScale(0.5, y)
        l.Size = UDim2.new(0.94, 0, 0, size + 14)
        l.BackgroundTransparency = 1
        l.Font = font
        l.TextSize = size
        l.TextColor3 = color
        l.TextTransparency = 1
        l.Text = text
        l.Parent = bg
        return l
    end
    local compact = MobileUI.isCompact()
    local t = label("5 AM", Enum.Font.Code, compact and 64 or 96, 0.4, Color3.fromRGB(255, 240, 215))
    --which night of the five this was, and what comes next
    local nightNum = workspace:GetAttribute("NightNumber") or 1
    local sub = nightNum >= 5 and "you survived all five nights" or string.format("you survived night %d.  night %d is next", nightNum, nightNum + 1)
    local s = label(sub, Enum.Font.GothamMedium, compact and 20 or 26, 0.54, Color3.fromRGB(235, 235, 235))
    local d = label(string.format("%s  -  %d / %d tasks done", string.upper(diff), done, need), Enum.Font.Code, compact and 14 or 17, 0.63, Color3.fromRGB(170, 170, 175))
    tween(bg, 0.8, {BackgroundTransparency = 0.35})
    tween(t, 0.8, {TextTransparency = 0})
    task.delay(0.3, function() tween(s, 0.8, {TextTransparency = 0}) end)
    task.delay(0.6, function() tween(d, 0.8, {TextTransparency = 0}) end)
    return g
end

----------------------------------------------------------------- end screens and strikes


--dim is how dark the screen goes behind the text, nil means fully black
local function bigMessage(title, sub, color, holdTime, dim)
    local g = newGui("NightEndGui", 60)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.Parent = g
    local t = Instance.new("TextLabel")
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    local compact = MobileUI.isCompact()
    t.Position = UDim2.fromScale(0.5, 0.45)
    t.Size = UDim2.new(0.94, 0, 0, compact and 64 or 90)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Code
    t.TextSize = compact and 50 or 72
    t.TextColor3 = color
    t.TextTransparency = 1
    t.Text = title
    t.Parent = bg
    local s = Instance.new("TextLabel")
    s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.Position = UDim2.fromScale(0.5, compact and 0.58 or 0.56)
    s.Size = UDim2.new(0.94, 0, 0, compact and 44 or 36)
    s.BackgroundTransparency = 1
    s.Font = Enum.Font.Gotham
    s.TextWrapped = true
    s.TextSize = compact and 16 or 22
    s.TextColor3 = Color3.fromRGB(210, 210, 210)
    s.TextTransparency = 1
    s.Text = sub
    s.Parent = bg
    tween(bg, dim and 0.5 or 1.4, {BackgroundTransparency = dim or 0})
    task.wait(dim and 0.3 or 1.2)
    tween(t, 1, {TextTransparency = 0})
    tween(s, 1, {TextTransparency = 0})
    task.wait(holdTime)
    tween(bg, 1.2, {BackgroundTransparency = 1})
    tween(t, 1, {TextTransparency = 1})
    tween(s, 1, {TextTransparency = 1})
    task.wait(1.3)
    g:Destroy()
end


local function clearUi()
    closeWires()
    closeOrder()
    stopVape(false)
    callToken += 1
    local cg = playerGui:FindFirstChild("CallGui")
    if cg then cg:Destroy() end
    for name in pairs(alerts) do removeAlert(name) end
    for _, p in ipairs(pipFrames) do p.BackgroundColor3 = Color3.fromRGB(60, 60, 64) end
end

local lastReason = ""


local function showObjectiveAgain()
    local g = newGui("ObjectiveGui2", 5)
    local pill = Instance.new("TextLabel")
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, 26)
    pill.Size = UDim2.fromOffset(230, 36)
    pill.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    pill.BackgroundTransparency = 0.4
    pill.Font = Enum.Font.Gotham
    pill.TextSize = 16
    pill.TextColor3 = Color3.fromRGB(228, 228, 228)
    --clock in first, then the office
    local function objectiveText()
        pill.Text = player:GetAttribute("ClockedIn") and "get to the office" or "clock in at the ipad"
    end
    objectiveText()
    player:GetAttributeChangedSignal("ClockedIn"):Connect(objectiveText)
    corner(pill, 18)
    pill.Parent = g
    chime:Play()
    task.spawn(function()
        while not workspace:GetAttribute("NightActive") do task.wait(0.5) end
        g:Destroy()
    end)
end

--true from the win until the player is back in the store after the select screen
local menuReturning = false


--back to the select screen for a fresh run, then into the store with the office as the first stop
--toLobby sends them all the way back to the main menu instead of just the select screen
local function returnToMenu(toLobby)
    menuReturning = true
    local black = newGui("MenuFade", 95)
    local f = Instance.new("Frame")
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = Color3.new(0, 0, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Parent = black
    tween(f, 1.2, {BackgroundTransparency = 0}).Completed:Wait()
    clearUi()
    for _, n in ipairs({"VictoryGui", "ConfettiGui", "NightEndGui", "RingGui"}) do
        local g = playerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    player:SetAttribute("CharacterPicked", false)
    player:SetAttribute("InCutscene", true)
    if toLobby then
        --the objective pill would show through the menu, it comes back once they are in the store
        local og = playerGui:FindFirstChild("ObjectiveGui")
        if og then
            og.Enabled = false
            task.spawn(function()
                repeat task.wait(0.2) until player:GetAttribute("CharacterPicked")
                og.Enabled = true
            end)
        end
        local og2 = playerGui:FindFirstChild("ObjectiveGui2")
        if og2 then og2:Destroy() end
        --the server resets this player, then the start screen runs again right here
        pcall(function() return RS:WaitForChild("LobbyRequest"):InvokeServer("toLobby") end)
        player:SetAttribute("MenuDone", false)
        local menuSrc = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MenuClient")
        if menuSrc then
            local menuCopy = menuSrc:Clone()
            menuCopy.Parent = player:WaitForChild("PlayerScripts")
        end
    end
    local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("CharacterSelect")
    if src then
        local copy = src:Clone()
        copy.Parent = player:WaitForChild("PlayerScripts")
    end
    --the select screen draws over this and fades itself in
    task.wait(1.5)
    black:Destroy()
    repeat task.wait(0.2) until player:GetAttribute("CharacterPicked")
    --give the server a moment to swap in the picked body
    task.wait(0.8)
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    local y = 0.5 + hum.HipHeight + root.Size.Y / 2
    char:PivotTo(CFrame.lookAt(Vector3.new(-55.5, y, 16), Vector3.new(-40, y, 10)))
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = hum
    player:SetAttribute("InCutscene", false)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
    menuReturning = false
    showObjectiveAgain()
end

ev.OnClientEvent:Connect(function(kind, a, b, c)
    if kind == "start" then
        lastHour = -1
        clearUi()
        chime:Play()
        --a light card over the cameras so the feed is still usable straight away
        task.spawn(function() bigMessage("12 AM", string.format("%s shift  -  night %d of 5", string.lower(a or "normal"), b or 1), Color3.fromRGB(240, 240, 240), 1.2, 0.6) end)
    elseif kind == "vape" then
        task.spawn(playVape)
    elseif kind == "garbagePickup" then
        task.spawn(startBag)
    elseif kind == "garbageDump" then
        dumpBag()
    elseif kind == "garbageDrop" then
        stopBag()
    elseif kind == "taskDone" then
        ding:Play()
    elseif kind == "waitTeam" then
        local l = addAlert("waitTeam", "waiting for everyone to clock in", Color3.fromRGB(235, 235, 235))
        task.delay(3, function() if alerts.waitTeam == l then removeAlert("waitTeam") end end)
    elseif kind == "jobFailed" then
        clearUi()
        addAlert("jobfail", (a or "you missed too much") .. ".  it is coming for you", Color3.fromRGB(255, 110, 100))
    elseif kind == "hour" then
        chime:Play()
        tween(clockLabel, 0.3, {TextSize = 54})
        task.delay(0.4, function() tween(clockLabel, 0.4, {TextSize = 42}) end)
    elseif kind == "alert" then
        ding:Play()
        addAlert(a, "!  " .. b, Color3.fromRGB(255, 214, 150))
    elseif kind == "timedOut" then
        local l = addAlert("timeout", "you took too long.  it heard you", Color3.fromRGB(255, 120, 110))
        task.delay(4, function() if alerts.timeout == l then removeAlert("timeout") end end)
    elseif kind == "resolved" then
        removeAlert(a)
        if a == "lights" then closeWires() end
        if a == "line" then closeOrder() end
        if a == "vape" then stopVape(false) end
    elseif kind == "strike" then
        for i = 1, a do pipFrames[i].BackgroundColor3 = Color3.fromRGB(210, 50, 45) end
        lastReason = c or ""
        local l = addAlert("strike", "strike " .. a .. " of " .. b .. ":  " .. (c or ""), Color3.fromRGB(255, 120, 110))
        task.delay(4, function() if alerts.strike == l then removeAlert("strike") end end)
    elseif kind == "wires" then
        openWires()
    elseif kind == "order" then
        openOrder(a)
    elseif kind == "orderWrong" then
        orderWrong()
    elseif kind == "ring" then
        if not workspace:GetAttribute("Hunting") then showRing() end
    elseif kind == "ringStop" then
        hideRing()
    elseif kind == "call" then
        hideRing()
        task.spawn(playCall, a, b)
    elseif kind == "won" then
        clearUi()
        hideRing()
        menuReturning = true
        --phone controls step aside while the end of night card is up
        player:SetAttribute("ScreenMessage", true)
        task.spawn(function()
            --count what was finished before the list is cleared for the next night
            local ok, list = pcall(function() return HttpService:JSONDecode(workspace:GetAttribute("Objectives") or "[]") end)
            local done, need = 0, 0
            if ok and type(list) == "table" then
                for _, o in ipairs(list) do
                    if o.r ~= 1 then need += 1 end
                    if o.s == "done" then done += 1 end
                end
            end
            cheer:Play()
            cheer2:Play()
            chime:Play()
            confetti(6)
            victoryCard(workspace:GetAttribute("Difficulty") or "normal", math.min(done, need), need)
            task.wait(7)
            player:SetAttribute("ScreenMessage", false)
            returnToMenu()
        end)
    elseif kind == "failed" then
        clearUi()
        hideRing()
        --the night only fails on a death once nobody is left alive, so a dead player here has no teammate to watch
        local died = player:GetAttribute("Dead") == true and not player:GetAttribute("Waiting")
        local why = a or lastReason
        player:SetAttribute("ScreenMessage", true)
        task.spawn(function()
            if died then
                menuReturning = true
                bigMessage("You died", "", Color3.fromRGB(210, 60, 55), 4)
                player:SetAttribute("ScreenMessage", false)
                returnToMenu(true)
                return
            end
            menuReturning = true
            bigMessage("you were fired", why, Color3.fromRGB(210, 60, 55), 5)
            player:SetAttribute("ScreenMessage", false)
            --same as a win, back to the select screen to try the night again
            returnToMenu()
        end)
    elseif kind == "reset" then
        if not player:GetAttribute("Seated") and not menuReturning then showObjectiveAgain() end
    end
end)

--caught while a teammate is still alive: just the words, then the spectate camera takes over
player:GetAttributeChangedSignal("Dead"):Connect(function()
    if player:GetAttribute("Dead") ~= true then return end
    task.wait(0.5)
    --someone who joined mid-night is only waiting, they did not die
    if player:GetAttribute("Waiting") then return end
    if player:GetAttribute("Dead") == true and workspace:GetAttribute("NightActive") then
        clearUi()
        hideRing()
        bigMessage("You died", "", Color3.fromRGB(210, 60, 55), 2.5)
    end
end)

--the monster coming in drops whatever task is open, the task itself stays active to finish later
RS:WaitForChild("MonsterEvent").OnClientEvent:Connect(function(kind)
    if kind == "scare" or kind == "hunt" then
        closeWires()
        closeOrder()
        --a hit cut off by the monster can be taken again afterwards
        stopVape(true)
        hideRing()
        callToken += 1
        local cg = playerGui:FindFirstChild("CallGui")
        if cg then cg:Destroy() end
    end
end)

UIS.InputBegan:Connect(function(input, typing)
    if typing then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        closeWires()
        closeOrder()
    end
end)
