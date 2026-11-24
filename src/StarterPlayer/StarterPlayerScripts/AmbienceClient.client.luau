--hanging things sway a little and the screen edges are darkened
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local swaying = {}


local function addSway(part)
    local pivot = part:GetAttribute("SwayPivot")
    if not pivot then return end
    local pivotCF = CFrame.new(pivot)
    swaying[part] = {
        pivotCF = pivotCF,
        rel = pivotCF:ToObjectSpace(part.CFrame),
        mode = part:GetAttribute("SwayMode"),
        amp = math.rad(part:GetAttribute("SwayAmp") or 1),
        --parts on the same fixture share a phase so they move as one piece
        phase = pivot.X * 0.37 + pivot.Z * 0.61,
    }
end
for _, part in ipairs(CollectionService:GetTagged("Sway")) do addSway(part) end
CollectionService:GetInstanceAddedSignal("Sway"):Connect(addSway)
CollectionService:GetInstanceRemovedSignal("Sway"):Connect(function(part) swaying[part] = nil end)

RunService.Heartbeat:Connect(function()
    local t = os.clock()
    for part, info in pairs(swaying) do
        local ph = info.phase
        --the swing slowly swells and dies down like a draft passing through
        local gust = 1 + 1.6 * math.max(0, math.noise(t * 0.06, ph))
        local a = info.amp * gust
        local ax, az = 0, 0
        if info.mode == "pendant" then
            ax = a * math.sin(t * 1.1 + ph)
            az = a * 0.6 * math.sin(t * 0.83 + ph * 1.7)
        elseif info.mode == "panel" then
            ax = a * math.sin(t * 0.9 + ph)
        else
            ax = a * (math.sin(t * 1.4 + ph * 3) + 0.4 * math.sin(t * 2.3 + ph))
        end
        part.CFrame = info.pivotCF * CFrame.Angles(ax, 0, az) * info.rel
    end
end)

---------------------------------------------------------------- vignette
local gui = Instance.new("ScreenGui")
gui.Name = "Vignette"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -5
gui.Parent = player:WaitForChild("PlayerGui")

local edges = {}


local function edge(pos, size, rotation)
    local f = Instance.new("Frame")
    f.Position = pos f.Size = size f.BackgroundColor3 = Color3.new(0, 0, 0) f.BorderSizePixel = 0 f.Active = false
    f.Parent = gui
    local g = Instance.new("UIGradient")
    g.Rotation = rotation
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = f
    table.insert(edges, g)
end
edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.26, 1), 0)
edge(UDim2.fromScale(0.74, 0), UDim2.fromScale(0.26, 1), 180)
edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90)
edge(UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), 270)

--the dark edges breathe in and out very slightly
RunService.Heartbeat:Connect(function()
    local k = 0.45 + 0.06 * math.sin(os.clock() * 0.9)
    local seq = NumberSequence.new({NumberSequenceKeypoint.new(0, k), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1)})
    for _, g in ipairs(edges) do g.Transparency = seq end
end)
