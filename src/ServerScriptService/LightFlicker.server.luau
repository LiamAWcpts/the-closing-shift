--a few chosen lights fail on the same slow rhythm, everything else stays steady
local root = workspace:WaitForChild("ChipotleMap")

local CYCLE = 11
local groups = {}
local order = {}
for _, p in ipairs(root:GetDescendants()) do
    if p:IsA("BasePart") and p:GetAttribute("Flicker") and not p:GetAttribute("Exterior") then
        local key = p:GetAttribute("FlickerGroup") or p
        if not groups[key] then groups[key] = {} table.insert(order, key) end
        table.insert(groups[key], p)
    end
end

local function collect(parts)
    local lights, neons = {}, {}
    for _, p in ipairs(parts) do
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Light") then table.insert(lights, {obj = c, base = c.Brightness}) end
        end
        if p.Material == Enum.Material.Neon then table.insert(neons, p) end
    end
    return lights, neons
end


local function setLevel(lights, neons, level)
    for _, l in ipairs(lights) do l.obj.Brightness = l.base * level end
    for _, n in ipairs(neons) do n.Material = level > 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic end
end



--same short buzz every time so it reads as one broken ballast
local function stutter(lights, neons, count)
    for i = 1, count do
        setLevel(lights, neons, 0.15)
        task.wait(0.07)
        setLevel(lights, neons, 1)
        task.wait(0.11)
    end
end

for i, key in ipairs(order) do
    local lights, neons = collect(groups[key])
    task.spawn(function()
        --groups are spread evenly across the cycle so they never fail together
        task.wait((i - 1) * CYCLE / #order)
        while true do
            task.wait(CYCLE - 4.2)
            stutter(lights, neons, 3)
            setLevel(lights, neons, 0)
            task.wait(2.4)
            stutter(lights, neons, 4)
            setLevel(lights, neons, 1)
        end
    end)
end
