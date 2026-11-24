--keeps the soft light shafts under each ceiling fixture in step with the real light, so they die with the power and fade back with it
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local shafts = {}


local function add(beam)
    local light = beam.Parent and beam.Parent:FindFirstChildWhichIsA("Light")
    if light then shafts[beam] = {light = light, base = beam:GetAttribute("BaseBrightness") or light.Brightness} end
end
for _, b in ipairs(CS:GetTagged("LightShaft")) do add(b) end
CS:GetInstanceAddedSignal("LightShaft"):Connect(add)
CS:GetInstanceRemovedSignal("LightShaft"):Connect(function(b) shafts[b] = nil end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.1 then return end
    acc = 0
    for beam, s in pairs(shafts) do
        local k = s.light.Enabled and math.clamp(s.light.Brightness / math.max(s.base, 0.01), 0, 1.2) or 0
        beam.Enabled = k > 0.03
        beam.Brightness = k
    end
end)
