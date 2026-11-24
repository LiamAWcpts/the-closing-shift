--every avatar ends up the same standard size, small ones grow and big ones shrink
local Players = game:GetService("Players")
--the store was built around a standard character at 1.2 times size
local SCALE = 1.2
--never stretch anyone past these, so a strange avatar cannot end up huge or tiny
local MIN_FACTOR = 0.6
local MAX_FACTOR = 1.8


--body height from the bottom of the feet to the top of the head, hats and hair left out
local function bodyHeight(char)
    local low, high = math.huge, -math.huge
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            low = math.min(low, p.Position.Y - p.Size.Y / 2)
            high = math.max(high, p.Position.Y + p.Size.Y / 2)
        end
    end
    return high - low
end

--how tall a plain default character stands at the game's size, measured once
local targetHeight = nil


local function getTarget()
    if targetHeight then return targetHeight end
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
    end)
    if ok and model then
        model:PivotTo(CFrame.new(0, -1000, 0))
        model.Parent = workspace
        targetHeight = bodyHeight(model) * SCALE
        model:Destroy()
    else
        --a plain R15 character is a little over five studs tall
        targetHeight = 5.2 * SCALE
    end
    return targetHeight
end


local function onCharacter(player, char)
    local hum = char:WaitForChild("Humanoid")
    --wait for the avatar to finish loading so the size sticks
    if not player:HasAppearanceLoaded() then
        player.CharacterAppearanceLoaded:Wait()
    end
    if char.Parent == nil then return end
    --put every size slider back to the plain default first
    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if ok and desc then
        desc.HeightScale = 1
        desc.WidthScale = 1
        desc.DepthScale = 1
        desc.HeadScale = 1
        desc.BodyTypeScale = 0
        desc.ProportionScale = 0
        pcall(function() hum:ApplyDescription(desc) end)
    end
    task.wait()
    if char.Parent == nil then return end
    --then scale the whole body so everyone stands the same height
    local height = bodyHeight(char)
    if height <= 0 then return end
    local factor = math.clamp(getTarget() / height, MIN_FACTOR, MAX_FACTOR)
    if math.abs(char:GetScale() - factor) > 0.001 then char:ScaleTo(factor) end
end


local function onPlayer(player)
    player.CharacterAdded:Connect(function(char)
        onCharacter(player, char)
    end)
    if player.Character then
        task.spawn(onCharacter, player, player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayer(p)
end
