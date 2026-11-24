--phones get a lighter version of the store: no shadows from the small ceiling lights, thinner particles and no depth of field
--the dark, the monster, the office lights and everything the player needs to see stay as they are
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local MobileUI = require(RS:WaitForChild("MobileUI"))

local map = workspace:WaitForChild("ChipotleMap")
local saved = {}
local applied = false


--the office is where the night is spent, its lights keep their shadows
local function important(light)
    local office = map:FindFirstChild("BackRooms")
    return office ~= nil and light:IsDescendantOf(office)
end


local function adjust(d, on)
    if d:IsA("Light") and not important(d) then
        if on and d.Shadows then
            saved[d] = true
            d.Shadows = false
        elseif not on and saved[d] == true then
            d.Shadows = true
        end
    elseif d:IsA("ParticleEmitter") then
        if on then
            if saved[d] == nil then saved[d] = d.Rate end
            d.Rate = saved[d] * 0.5
        elseif saved[d] ~= nil then
            d.Rate = saved[d]
        end
    end
end



local function apply(on)
    if on == applied then return end
    applied = on
    for _, d in ipairs(map:GetDescendants()) do adjust(d, on) end
end

--the store streams in around the player, so lights and particles that arrive later get the same treatment
map.DescendantAdded:Connect(function(d)
    if applied then adjust(d, true) end
end)




--depth of field is one of the heaviest effects, other scripts can switch it back on so it is held off while this is applied
local function watchBlur(e)
    if not e:IsA("DepthOfFieldEffect") then return end
    if applied then e.Enabled = false end
    e:GetPropertyChangedSignal("Enabled"):Connect(function()
        if applied and e.Enabled then e.Enabled = false end
    end)
end
for _, e in ipairs(Lighting:GetChildren()) do watchBlur(e) end
Lighting.ChildAdded:Connect(watchBlur)

MobileUI.watch(function()
    apply(MobileUI.isLowSpec())
    if applied then
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("DepthOfFieldEffect") then e.Enabled = false end
        end
    end
end)
