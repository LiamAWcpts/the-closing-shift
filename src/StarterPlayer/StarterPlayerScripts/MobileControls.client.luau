--the phone thumbstick and jump button only show while the player is on their feet and free to walk
--menus, cutscenes, the camera chair, hiding and the death scene all have their own buttons or none
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer

local function walkingFree()
    if not player:GetAttribute("CharacterPicked") then return false end
    if player:GetAttribute("InCutscene") then return false end
    if player:GetAttribute("Seated") then return false end
    if player:GetAttribute("Hiding") then return false end
    --the end of night card or the you died screen
    if player:GetAttribute("ScreenMessage") then return false end
    if workspace:GetAttribute("MonsterKill") and workspace:GetAttribute("NightActive") then return false end
    return true
end


local function sync()
    GuiService.TouchControlsEnabled = walkingFree()
end

for _, name in ipairs({"CharacterPicked", "InCutscene", "Seated", "Hiding", "ScreenMessage"}) do
    player:GetAttributeChangedSignal(name):Connect(sync)
end
workspace:GetAttributeChangedSignal("MonsterKill"):Connect(sync)
workspace:GetAttributeChangedSignal("NightActive"):Connect(sync)
sync()
