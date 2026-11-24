--there is no jumping in this game, on any device or character
local Players = game:GetService("Players")
local player = Players.LocalPlayer


local function noJump(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.JumpPower = 0
    hum.JumpHeight = 0
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

player.CharacterAdded:Connect(noJump)
if player.Character then noJump(player.Character) end
