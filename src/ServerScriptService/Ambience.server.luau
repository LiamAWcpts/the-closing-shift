--starts every looping room sound placed in the map
local amb = workspace:WaitForChild("ChipotleMap"):WaitForChild("Ambience")
for _, d in ipairs(amb:GetDescendants()) do
    if d:IsA("Sound") then
        d.TimePosition = math.random() * 3
        d:Play()
    end
end
