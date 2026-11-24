--everyone plays as their own avatar, this only handles someone arriving in the middle of a night
local RS = game:GetService("ReplicatedStorage")
local ev = RS:WaitForChild("CharacterPick")

ev.OnServerEvent:Connect(function(plr)
    --joined in the middle of a night: they watch their teammates until the next night starts
    if workspace:GetAttribute("NightActive") then
        plr:SetAttribute("Waiting", true)
        plr:SetAttribute("Dead", true)
        task.delay(0.5, function()
            local char = plr.Character
            local r = char and char:FindFirstChild("HumanoidRootPart")
            if r and plr:GetAttribute("Waiting") then
                r.Anchored = true
                char:PivotTo(CFrame.new(0, -400, 0))
            end
        end)
    end
end)
