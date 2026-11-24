--small yellow circle that shows through walls wherever the player needs to go next
--the office door before the night starts, then every job that is open
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local OFFICE_DOOR = Vector3.new(35, 4.4, -14.4)
local CLOCK_PAD = Vector3.new(-39.4, 4.6, -2.1)
local YELLOW = Color3.fromRGB(255, 208, 92)


--billboards only draw from a plain folder in playergui, and it gets remade if the gui is wiped
local function folder()
    local f = playerGui:FindFirstChild("TaskMarkers")
    if not f then
        f = Instance.new("Folder")
        f.Name = "TaskMarkers"
        f.Parent = playerGui
    end
    return f
end

local markers = {}


local function circle(parent, size, transparency, filled)
    local c = Instance.new("Frame")
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Position = UDim2.fromScale(0.5, 0.5)
    c.Size = UDim2.fromOffset(size, size)
    c.BackgroundColor3 = YELLOW
    c.BackgroundTransparency = filled and transparency or 1
    c.BorderSizePixel = 0
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = c
    if not filled then
        local s = Instance.new("UIStroke")
        s.Color = YELLOW
        s.Thickness = 2
        s.Transparency = transparency
        s.Parent = c
    end
    c.Parent = parent
    return c
end




local function makeMarker(key)
    --an attachment on the terrain gives the billboard a point in the world without a part
    local att = Instance.new("Attachment")
    att.Name = "TaskMarker_" .. key
    att.Parent = workspace.Terrain
    local bb = Instance.new("BillboardGui")
    bb.Name = key
    --drawn on top of everything so walls never hide it
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Size = UDim2.fromOffset(40, 40)
    bb.MaxDistance = 1000
    bb.Adornee = att
    bb.Parent = folder()
    local glow = circle(bb, 38, 0.86, true)
    local ring = circle(bb, 18, 0.3, false)
    local dot = circle(bb, 6, 0.12, true)
    local m = {att = att, bb = bb, glow = glow, ring = ring, dot = dot, seed = math.random() * 6}
    markers[key] = m
    return m
end


local function clearMarker(key)
    local m = markers[key]
    if not m then return end
    markers[key] = nil
    m.bb:Destroy()
    m.att:Destroy()
end


--where the player should be heading right now, empty when nothing needs them
local function wantedTargets()
    local list = {}
    if player:GetAttribute("InCutscene") or player:GetAttribute("Seated") or player:GetAttribute("Hiding") or player:GetAttribute("UsingPad") then return list end
    if not player:GetAttribute("IntroDone") or not player:GetAttribute("CharacterPicked") then return list end
    if workspace:GetAttribute("NightActive") then
        for name, value in pairs(workspace:GetAttributes()) do
            if string.sub(name, 1, 8) == "TaskPos_" and typeof(value) == "Vector3" then
                list[string.sub(name, 9)] = value
            end
        end
    else
        --before the shift: clock in at the ipad first, then the office
        if player:GetAttribute("ClockedIn") then
            list.office = OFFICE_DOOR
        else
            list.clockin = CLOCK_PAD
        end
    end
    return list
end

local t = 0
RunService.RenderStepped:Connect(function(dt)
    t += dt
    local want = wantedTargets()
    for key in pairs(markers) do
        if not want[key] then clearMarker(key) end
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    for key, pos in pairs(want) do
        --a wiped gui destroys the billboard for good, so the marker is built again
        if markers[key] and markers[key].bb.Parent == nil then clearMarker(key) end
        local m = markers[key] or makeMarker(key)
        m.att.WorldPosition = pos
        --a slow breathing pulse, and it fades back when the player is standing right on it
        local pulse = 0.5 + 0.5 * math.sin(t * 2.2 + m.seed)
        local near = 1
        if root then
            local d = (root.Position - pos).Magnitude
            near = math.clamp((d - 4) / 8, 0.25, 1)
        end
        m.glow.Size = UDim2.fromOffset(30 + 10 * pulse, 30 + 10 * pulse)
        m.glow.BackgroundTransparency = 1 - (0.1 + 0.06 * pulse) * near
        m.ring.UIStroke.Transparency = 1 - 0.7 * near
        m.dot.BackgroundTransparency = 1 - 0.88 * near
    end
end)
