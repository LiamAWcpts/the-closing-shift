--shared math for the broom in the intro, checked against the map so it never clips
local P = {}
local UP = Vector3.new(0, 1, 0)

--distance from the head joint (the pivot) to the handle tip
P.TIP = 3.85
P.ENTRY_TZ = 16.9
P.FINAL_TZ = 13.75




local function lerp(a, b, t)
    return a + (b - a) * t
end

function P.frameFromDir(pos, dir, hint)
    local y = dir.Unit
    local z = hint:Cross(y).Unit
    local x = y:Cross(z).Unit
    return CFrame.fromMatrix(pos, x, y)
end




--broom from its tip position and the direction from tip back to the head
function P.fromLine(tip, d)
    return P.frameFromDir(tip + d * P.TIP, -d, UP)
end

--slope of the broom (sideways, up) per tip position while only the first handle holds it
local keys = {{16.9, 0.35, 1.85}, {16.5, 0.32, 1.55}, {16.0, 0.3, 1.3}, {15.75, 0.2, 1.2}, {15.5, 0.08, 1.1}}




local function firstHandleSlope(tz)
    for i = 1, #keys - 1 do
        local a, b = keys[i], keys[i + 1]
        if tz <= a[1] and tz >= b[1] then
            local t = (a[1] - tz) / (a[1] - b[1])
            return lerp(a[2], b[2], t), lerp(a[3], b[3], t)
        end
    end
    return keys[1][2], keys[1][3]
end


--the broom threads behind door b's handle (z 16.5) then door a's (z 15.5) as the tip moves to tz
function P.slidePose(tz)
    local d, tip
    if tz >= 15.5 then
        local dx, dy = firstHandleSlope(tz)
        d = Vector3.new(dx, dy, 1).Unit
        local B = Vector3.new(-59.485, 5.2, 16.5)
        tip = B - d * ((16.5 - tz) / d.Z)
    else
        local f = (tz - 13.75) / 1.75
        local g = f ^ 0.6
        local dx, dy = 0.08 * g, 1.1 * g
        d = Vector3.new(dx, dy, 1).Unit
        local mid = Vector3.new(lerp(-59.5, -59.525, f), lerp(4.6, 4.65, f), 16)
        local B = mid + Vector3.new(dx / 2, dy / 2, 0.5)
        tip = B - d * ((16.5 - tz) / d.Z)
    end
    return P.fromLine(tip, d)
end

P.lean = P.frameFromDir(Vector3.new(-58.55, 1.46, 10.6), Vector3.new(-math.sin(math.rad(15.5)), math.cos(math.rad(15.5)), 0), Vector3.new(0, 0, 1))
P.entry = P.slidePose(P.ENTRY_TZ)
P.final = P.slidePose(P.FINAL_TZ)

--carried in front of the player, tip forward and to the left
local HELD_TIP = Vector3.new(-0.3, -0.75, -2.1)
local HELD_DIR = Vector3.new(0.35, -0.25, 0.9).Unit

function P.heldLine(camCF)
    return camCF * HELD_TIP, camCF:VectorToWorldSpace(HELD_DIR)
end



function P.held(camCF)
    return P.fromLine(P.heldLine(camCF))
end

--from carried to the entry point: the tip comes in from the room side above door b's handle
local ENTRY_WAY = Vector3.new(-58.85, 6.35, 17.1)

function P.approach(camCF, e)
    local tip0, d0 = P.heldLine(camCF)
    local tipE = P.entry.Position + (-P.entry.UpVector) * 0
    --entry tip is the pivot minus the handle length along the broom axis
    local dE = -P.entry.UpVector
    local tipEntry = P.entry.Position - dE * P.TIP
    local tip
    if e < 0.5 then
        tip = tip0:Lerp(ENTRY_WAY, e * 2)
    else
        tip = ENTRY_WAY:Lerp(tipEntry, (e - 0.5) * 2)
    end
    local d = (d0:Lerp(dE, e)).Unit
    return P.fromLine(tip, d)
end

return P
