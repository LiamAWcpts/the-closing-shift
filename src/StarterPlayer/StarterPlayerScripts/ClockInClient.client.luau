--the wall ipad: type a seven digit employee number to clock in before the office opens
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ev = RS:WaitForChild("ClockInEvent")
local pad = workspace:WaitForChild("ChipotleMap"):WaitForChild("ClockIn")
local screen = pad:WaitForChild("Screen")
local prompt = screen:WaitForChild("PromptPoint"):WaitForChild("ClockInPrompt")

local BLUE = Color3.fromRGB(186, 222, 247)
local GREEN = Color3.fromRGB(120, 206, 140)
local INK = Color3.fromRGB(16, 24, 34)
local LENGTH = 7


local function makeSound(id, vol, speed)
    local s = Instance.new("Sound")
    s.SoundId = id s.Volume = vol s.PlaybackSpeed = speed or 1
    s.Parent = game:GetService("SoundService")
    return s
end
local tapSnd = makeSound("rbxassetid://9119717286", 0.25, 1.6)
local okSnd = makeSound("rbxassetid://9113938822", 0.3, 1.4)
local badSnd = makeSound("rbxassetid://9113938822", 0.25, 0.55)

local function corner(obj, scale)
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(scale or 0.18, 0) c.Parent = obj
end

local function label(parent, text, x, y, w, h, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.fromScale(x, y)
    l.Size = UDim2.fromScale(w, h)
    l.Font = font or Enum.Font.GothamMedium
    l.TextSize = size
    l.TextColor3 = color or INK
    l.Text = text
    l.Parent = parent
    return l
end

----------------------------------------------------------------- the screen itself
--it lives in playergui with the glass as its adornee so taps and clicks reach the buttons
local gui = Instance.new("SurfaceGui")
gui.Name = "ClockInScreen"
gui.ResetOnSpawn = false
gui.Adornee = screen
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 320
gui.LightInfluence = 0
gui.Brightness = 1.2
gui.ZOffset = 1
gui.Active = true
gui.MaxDistance = 60
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = BLUE
bg.BorderSizePixel = 0
bg.Parent = gui

local title = label(bg, "employee clock in", 0.5, 0.05, 0.9, 0.06, 20, Color3.fromRGB(40, 70, 100))

--bar along the top that shows what has been typed
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.fromScale(0.5, 0.1)
bar.Size = UDim2.fromScale(0.88, 0.11)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.BorderSizePixel = 0
bar.Parent = bg
corner(bar, 0.25)
local barStroke = Instance.new("UIStroke") barStroke.Color = Color3.fromRGB(120, 160, 200) barStroke.Thickness = 2 barStroke.Parent = bar
local digitsLabel = label(bar, "", 0.5, 0.5, 0.96, 0.9, 34, INK, Enum.Font.GothamBold)
local hint = label(bg, "enter your 7 digit employee number", 0.5, 0.245, 0.95, 0.05, 15, Color3.fromRGB(60, 90, 120), Enum.Font.Gotham)

--number pad
local keys = {}
local padFrame = Instance.new("Frame")
padFrame.AnchorPoint = Vector2.new(0.5, 0)
padFrame.Position = UDim2.fromScale(0.5, 0.285)
padFrame.Size = UDim2.fromScale(0.88, 0.56)
padFrame.BackgroundTransparency = 1
padFrame.Parent = bg
local layout = {{"1", "2", "3"}, {"4", "5", "6"}, {"7", "8", "9"}, {"CLR", "0", "DEL"}}
for r, row in ipairs(layout) do
    for c, k in ipairs(row) do
        local b = Instance.new("TextButton")
        b.Name = "Key_" .. k
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Position = UDim2.fromScale((c - 0.5) / 3, (r - 0.5) / 4)
        b.Size = UDim2.fromScale(0.29, 0.22)
        b.BackgroundColor3 = Color3.new(1, 1, 1)
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = (#k > 1) and 22 or 40
        b.TextColor3 = Color3.new(0, 0, 0)
        b.Text = k
        b.Parent = padFrame
        corner(b, 0.2)
        keys[k] = b
    end
end

local confirm = Instance.new("TextButton")
confirm.Name = "Confirm"
confirm.AnchorPoint = Vector2.new(0.5, 0)
confirm.Position = UDim2.fromScale(0.5, 0.865)
confirm.Size = UDim2.fromScale(0.88, 0.1)
confirm.BackgroundColor3 = Color3.fromRGB(28, 96, 170)
confirm.AutoButtonColor = false
confirm.BorderSizePixel = 0
confirm.Font = Enum.Font.GothamBold
confirm.TextSize = 26
confirm.TextColor3 = Color3.new(1, 1, 1)
confirm.Text = "CONFIRM"
confirm.Parent = bg
corner(confirm, 0.3)

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(0.97, 0.015)
close.Size = UDim2.fromScale(0.11, 0.07)
close.BackgroundColor3 = Color3.fromRGB(150, 190, 225)
close.AutoButtonColor = false
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 20
close.TextColor3 = INK
close.Text = "X"
close.Visible = false
close.Parent = bg
corner(close, 0.3)

--the green confirmation card covers everything once it goes through
local doneCard = Instance.new("Frame")
doneCard.Size = UDim2.fromScale(1, 1)
doneCard.BackgroundColor3 = GREEN
doneCard.BorderSizePixel = 0
doneCard.Visible = false
doneCard.ZIndex = 5
doneCard.Parent = bg
local check = label(doneCard, "\u{2713}", 0.5, 0.28, 0.5, 0.2, 90, Color3.new(1, 1, 1), Enum.Font.GothamBold)
check.ZIndex = 6
local doneTitle = label(doneCard, "CLOCKED IN", 0.5, 0.47, 0.95, 0.1, 44, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
doneTitle.ZIndex = 6
local doneTime = label(doneCard, "12:00 AM", 0.5, 0.6, 0.9, 0.07, 30, Color3.fromRGB(20, 70, 35), Enum.Font.GothamBold)
doneTime.ZIndex = 6
local doneDate = label(doneCard, "", 0.5, 0.68, 0.9, 0.06, 24, Color3.fromRGB(20, 70, 35), Enum.Font.GothamMedium)
doneDate.ZIndex = 6
local doneNote = label(doneCard, "head to the office", 0.5, 0.82, 0.9, 0.05, 18, Color3.fromRGB(30, 90, 50), Enum.Font.Gotham)
doneNote.ZIndex = 6

----------------------------------------------------------------- state
local code = ""
local using = false
local sending = false

local function render()
    if #code == 0 then
        digitsLabel.Text = string.rep("-  ", LENGTH - 1) .. "-"
        digitsLabel.TextColor3 = Color3.fromRGB(170, 185, 200)
    else
        local shown = {}
        for i = 1, LENGTH do shown[i] = string.sub(code, i, i) ~= "" and string.sub(code, i, i) or "-" end
        digitsLabel.Text = table.concat(shown, " ")
        digitsLabel.TextColor3 = INK
    end
end
render()



local function showHint(text, bad)
    hint.Text = text
    hint.TextColor3 = bad and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(60, 90, 120)
end


local function flash(b)
    b.BackgroundColor3 = Color3.fromRGB(205, 225, 245)
    TweenService:Create(b, TweenInfo.new(0.18), {BackgroundColor3 = (b == confirm) and Color3.fromRGB(28, 96, 170) or Color3.new(1, 1, 1)}):Play()
end




local function press(k)
    if not using or sending then return end
    tapSnd:Play()
    if keys[k] then flash(keys[k]) end
    if k == "DEL" then
        code = string.sub(code, 1, -2)
    elseif k == "CLR" then
        code = ""
    elseif #code < LENGTH then
        code = code .. k
    end
    showHint(#code .. " of " .. LENGTH .. " digits", false)
    render()
end




local function shake()
    local base = UDim2.fromScale(0.5, 0.1)
    task.spawn(function()
        for i = 1, 6 do
            bar.Position = base + UDim2.fromOffset((i % 2 == 0) and 8 or -8, 0)
            task.wait(0.035)
        end
        bar.Position = base
    end)
end


local function submit()
    if not using or sending then return end
    flash(confirm)
    --the pad refuses anything that is not exactly seven digits
    if #code ~= LENGTH then
        badSnd:Play()
        showHint("the number must be exactly 7 digits", true)
        barStroke.Color = Color3.fromRGB(220, 60, 60)
        shake()
        task.delay(0.8, function() barStroke.Color = Color3.fromRGB(120, 160, 200) end)
        return
    end
    sending = true
    ev:FireServer("submit", code)
end

for k, b in pairs(keys) do
    b.Activated:Connect(function() press(k) end)
end
confirm.Activated:Connect(submit)

----------------------------------------------------------------- looking at the pad
local controls = nil

local function getControls()
    local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
    if not pm then return nil end
    local ok, mod = pcall(require, pm)
    if ok then return mod:GetControls() end
end


local function setBody(t)
    local char = player.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = t end
    end
end

local savedFov = 70
local leaving = false

local function stopUsing()
    if not using or leaving then return end
    leaving = true
    using = false
    close.Visible = false
    RunService:UnbindFromRenderStep("ClockInView")
    CAS:UnbindAction("ClockInBlock")
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    camera.CameraType = Enum.CameraType.Custom
    if hum then camera.CameraSubject = hum end
    camera.FieldOfView = savedFov
    if controls then controls:Enable() end
    setBody(0)
    player:SetAttribute("InCutscene", false)
    player:SetAttribute("UsingPad", false)
    leaving = false
end


local function startUsing()
    if using or player:GetAttribute("ClockedIn") then return end
    using = true
    sending = false
    code = ""
    render()
    showHint("enter your 7 digit employee number", false)
    close.Visible = true
    player:SetAttribute("UsingPad", true)
    player:SetAttribute("InCutscene", true)
    controls = getControls()
    if controls then controls:Disable() end
    --movement and jumping keys do nothing while the pad is up
    CAS:BindActionAtPriority("ClockInBlock", function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 120,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
    savedFov = camera.FieldOfView
    local from = camera.CFrame
    --square on to the glass, close enough that the pad fills most of the view
    local goal = CFrame.lookAt(screen.Position + screen.CFrame.LookVector * 1.75, screen.Position)
    camera.CameraType = Enum.CameraType.Scriptable
    local t0 = os.clock()
    RunService:BindToRenderStep("ClockInView", Enum.RenderPriority.Last.Value, function()
        local a = math.clamp((os.clock() - t0) / 0.45, 0, 1)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = from:Lerp(goal, TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
        camera.FieldOfView = 70
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
        setBody(1)
    end)
end

close.Activated:Connect(stopUsing)

local DIGIT_KEYS = {
    [Enum.KeyCode.Zero] = "0", [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3", [Enum.KeyCode.Four] = "4",
    [Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6", [Enum.KeyCode.Seven] = "7", [Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
    [Enum.KeyCode.KeypadZero] = "0", [Enum.KeyCode.KeypadOne] = "1", [Enum.KeyCode.KeypadTwo] = "2", [Enum.KeyCode.KeypadThree] = "3", [Enum.KeyCode.KeypadFour] = "4",
    [Enum.KeyCode.KeypadFive] = "5", [Enum.KeyCode.KeypadSix] = "6", [Enum.KeyCode.KeypadSeven] = "7", [Enum.KeyCode.KeypadEight] = "8", [Enum.KeyCode.KeypadNine] = "9",
}
UIS.InputBegan:Connect(function(input, typing)
    if typing or not using then return end
    local k = input.KeyCode
    if DIGIT_KEYS[k] then press(DIGIT_KEYS[k])
    elseif k == Enum.KeyCode.Backspace then press("DEL")
    elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then submit()
    elseif k == Enum.KeyCode.Escape or k == Enum.KeyCode.Q then stopUsing() end
end)

----------------------------------------------------------------- what the pad shows when nobody is using it

local function idleScreen()
    if player:GetAttribute("ClockedIn") then
        doneCard.Visible = true
        doneCard.BackgroundColor3 = Color3.fromRGB(150, 214, 165)
        doneNote.Text = "see you at 5 am"
        doneDate.Text = player:GetAttribute("ClockInDate") or ""
    else
        doneCard.Visible = false
        code = ""
        render()
        showHint("enter your 7 digit employee number", false)
    end
    prompt.Enabled = not player:GetAttribute("ClockedIn")
end
idleScreen()
player:GetAttributeChangedSignal("ClockedIn"):Connect(function()
    if not using then idleScreen() end
    prompt.Enabled = not player:GetAttribute("ClockedIn")
end)

----------------------------------------------------------------- server replies
--small toast when they try the office first
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "ClockInToast"
toastGui.ResetOnSpawn = false
toastGui.DisplayOrder = 30
toastGui.Parent = player.PlayerGui
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 72)
toast.Size = UDim2.fromOffset(300, 34)
toast.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 15
toast.TextColor3 = Color3.fromRGB(255, 214, 140)
toast.Text = "clock in at the ipad first"
toast.Parent = toastGui
corner(toast, 0.5)
local toastToken = 0

ev.OnClientEvent:Connect(function(kind, a, b)
    if kind == "open" then
        startUsing()
    elseif kind == "bad" then
        sending = false
        badSnd:Play()
        showHint("the number must be exactly 7 digits", true)
        shake()
    elseif kind == "ok" then
        okSnd:Play()
        doneCard.BackgroundColor3 = GREEN
        doneTime.Text = a or "12:00 AM"
        doneDate.Text = b or ""
        doneNote.Text = "head to the office"
        doneCard.Visible = true
        doneCard.BackgroundTransparency = 1
        TweenService:Create(doneCard, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
        task.wait(2.4)
        sending = false
        stopUsing()
        idleScreen()
    elseif kind == "needClockIn" then
        toastToken += 1
        local mine = toastToken
        toast.BackgroundTransparency = 0.35
        toast.TextTransparency = 0
        task.delay(2.5, function()
            if toastToken ~= mine then return end
            TweenService:Create(toast, TweenInfo.new(0.4), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        end)
    end
end)

--dying or being pulled into a cutscene closes the pad
player.CharacterAdded:Connect(function() if using then stopUsing() end end)
