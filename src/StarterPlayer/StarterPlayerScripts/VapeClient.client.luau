--anywhere inside the walk-in the vape prompt sits in the middle of the screen, as many hits as they want
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ev = RS:WaitForChild("NightEvent")

--same box the server checks
local WALKIN_MIN = Vector3.new(3.5, -5, -25.5)
local WALKIN_MAX = Vector3.new(18.5, 20, -13.9)

local gui = Instance.new("ScreenGui")
gui.Name = "VapePromptGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.Position = UDim2.fromScale(0.5, 0.62)
button.Size = UDim2.fromOffset(210, 52)
button.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
button.BackgroundTransparency = 0.25
button.AutoButtonColor = false
button.BorderSizePixel = 0
button.Text = ""
button.Visible = false
button.Parent = gui
local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = button
local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(190, 215, 240) stroke.Transparency = 0.45 stroke.Thickness = 1.5 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border stroke.Parent = button

--key cap on the left, only on a keyboard
local keyCap = Instance.new("TextLabel")
keyCap.AnchorPoint = Vector2.new(0, 0.5)
keyCap.Position = UDim2.new(0, 8, 0.5, 0)
keyCap.Size = UDim2.fromOffset(36, 36)
keyCap.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
keyCap.Font = Enum.Font.GothamBold
keyCap.TextSize = 18
keyCap.TextColor3 = Color3.fromRGB(15, 15, 15)
keyCap.Text = "F"
keyCap.Parent = button
local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(0.25, 0) kc.Parent = keyCap

local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.AnchorPoint = Vector2.new(0, 0.5)
text.Position = UDim2.new(0, 54, 0.5, 0)
text.Size = UDim2.new(1, -60, 1, 0)
text.Font = Enum.Font.GothamBold
text.TextSize = 20
text.TextColor3 = Color3.fromRGB(240, 240, 240)
text.TextXAlignment = Enum.TextXAlignment.Left
text.Text = "take puff"
text.Parent = button


local function layout()
    local touch = MobileUI.isTouch()
    keyCap.Visible = not touch
    if touch then
        --a bigger thumb target, still in the middle of the screen
        button.Size = UDim2.fromOffset(200, 60)
        text.AnchorPoint = Vector2.new(0.5, 0.5)
        text.Position = UDim2.fromScale(0.5, 0.5)
        text.Size = UDim2.fromScale(1, 1)
        text.TextXAlignment = Enum.TextXAlignment.Center
        text.Text = "TAKE PUFF"
        text.TextSize = 24
    else
        button.Size = UDim2.fromOffset(210, 52)
        text.AnchorPoint = Vector2.new(0, 0.5)
        text.Position = UDim2.new(0, 54, 0.5, 0)
        text.Size = UDim2.new(1, -60, 1, 0)
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.Text = "take puff"
        text.TextSize = 20
    end
end
MobileUI.watch(layout)
layout()

local function inside()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end
    local p = root.Position
    return p.X > WALKIN_MIN.X and p.X < WALKIN_MAX.X and p.Z > WALKIN_MIN.Z and p.Z < WALKIN_MAX.Z
end

local function available()
    if player:GetAttribute("InCutscene") or player:GetAttribute("Seated") or player:GetAttribute("Hiding") or player:GetAttribute("ScreenMessage") then return false end
    --hidden while a hit is already playing
    if camera:FindFirstChild("VapeViewmodel") then return false end
    return inside()
end

local lastPress = 0


local function request()
    if os.clock() - lastPress < 0.6 or not available() then return end
    lastPress = os.clock()
    TweenService:Create(button, TweenInfo.new(0.12), {BackgroundTransparency = 0.05}):Play()
    task.delay(0.12, function() TweenService:Create(button, TweenInfo.new(0.2), {BackgroundTransparency = 0.25}):Play() end)
    ev:FireServer("vapeRequest")
end

button.Activated:Connect(request)

local bound = false
RunService.Heartbeat:Connect(function()
    local on = available()
    button.Visible = on
    if on and not bound then
        bound = true
        CAS:BindActionAtPriority("VapeKey", function(_, state)
            if state == Enum.UserInputState.Begin then request() end
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
    elseif not on and bound then
        bound = false
        CAS:UnbindAction("VapeKey")
    end
end)
