--the game is first person only, on every device
local Players = game:GetService("Players")
local player = Players.LocalPlayer

player.CameraMode = Enum.CameraMode.LockFirstPerson

--the camera follows whatever body the player ends up in after picking a character
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then workspace.CurrentCamera.CameraSubject = hum end
end)
