--every script in the game uses fixed world positions, so the map has to sit exactly where it was built
--the map is locked in studio so a stray click and drag cant move it, this is the backup if it ever gets moved anyway
local map = workspace:WaitForChild("ChipotleMap")
local home = map:GetAttribute("HomePivot")
if typeof(home) == "CFrame" then
    local off = (map:GetPivot().Position - home.Position).Magnitude
    if off > 0.01 then
        warn(string.format("ChipotleMap was moved %.1f studs from where it was built, putting it back. Undo the move in studio and keep the map locked", off))
        map:PivotTo(home)
    end
end
