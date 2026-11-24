--a caught player watches the rest of the shift through a teammate's eyes, tap or click to switch
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "SpectateGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local bar = Instance.new("TextLabel")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -26)
bar.Size = UDim2.fromOffset(220, 40)
bar.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
bar.BackgroundTransparency = 0.35
bar.Font = Enum.Font.GothamMedium
bar.TextSize = 16
bar.TextColor3 = Color3.fromRGB(235, 235, 235)
bar.Text = ""
bar.Parent = gui
local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = bar

local index = 1

local function others()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if p ~= player and hum and hum.Health > 0 and not p:GetAttribute("Dead") then table.insert(list, p) end
    end
    return list
end


local function watching()
    return player:GetAttribute("Dead") == true and workspace:GetAttribute("NightActive") == true
end

RunService.RenderStepped:Connect(function()
    if not watching() then
        if gui.Enabled then
            gui.Enabled = false
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then camera.CameraSubject = hum end
        end
        return
    end
    local list = others()
    gui.Enabled = true
    if #list == 0 then
        bar.Visible = false
        return
    end
    bar.Visible = true
    if index > #list then index = 1 end
    local target = list[index]
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if camera.CameraSubject ~= hum then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = hum
    end
    --just whose eyes you are behind, clicking still switches
    bar.Text = target.DisplayName
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed or not watching() then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
        index += 1
    end
end)
