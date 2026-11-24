--animates the night monster on this screen: weighted gait, feet planted on the floor, hands that land on real surfaces, fingers and barefoot steps
--the server only moves the body and sets posture, everything here is layered on top through Motor6D.Transform
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AudioIds = require(RS:WaitForChild("AudioIds"))

local rad = math.rad
local sin, cos, clamp, abs = math.sin, math.cos, math.clamp, math.abs
local UP = Vector3.yAxis

--real bare feet slapping a wet surface, cut down to just the first soft contact, only used until the barefoot set is uploaded
local FALLBACK = {"9114521931", "9114521211", "9114520969", "9114522236", "9114522142", "9114522515"}

local GAITS = {
    creep = {stride = 0.85, lift = 0.26, bob = 0.05, crouch = 0.55, arm = 9, sway = 3.5, twist = 5, shift = 0.05, vol = 0.16, curl = 22},
    walk = {stride = 1, lift = 0.4, bob = 0.09, crouch = 0.15, arm = 22, sway = 3.5, twist = 8, shift = 0.07, vol = 0.34, curl = 18},
    run = {stride = 1.35, lift = 0.8, bob = 0.2, crouch = 0.38, arm = 46, sway = 4.5, twist = 12, shift = 0.05, vol = 0.62, curl = 55},
}

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.RespectCanCollide = true


local function ids(list)
    local out = {}
    for _, id in ipairs(list or {}) do
        if id ~= "" then table.insert(out, id) end
    end
    return out
end

----------------------------------------------------------------- math helpers


local function rotBetween(u, v)
    local axis = u:Cross(v)
    local d = clamp(u:Dot(v), -1, 1)
    if axis.Magnitude < 1e-6 then
        if d > 0 then return CFrame.new() end
        local any = abs(u.X) < 0.9 and Vector3.xAxis or Vector3.yAxis
        return CFrame.fromAxisAngle(u:Cross(any).Unit, math.pi)
    end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end


local function fk(parentCF, j, t)
    return parentCF * j.C0 * t * j.C1:Inverse()
end


--swings Part1 about its joint so the bone (a vector in Part1 space) points at goal, returns the Transform and the new Part1 CFrame
local function aim(parentCF, j, bone, goal)
    local frame = parentCF * j.C0
    local rest = frame * j.C1:Inverse()
    local restDir = rest:VectorToWorldSpace(bone).Unit
    local want = goal - frame.Position
    if want.Magnitude < 1e-4 then return CFrame.new(), rest end
    local rw = rotBetween(restDir, want.Unit)
    local rj = frame.Rotation
    local t = rj:Inverse() * rw * rj
    return t, frame * t * j.C1:Inverse()
end




--two bone chain from a toward target, bends toward pole, returns the middle joint position
local function solve(a, target, l1, l2, pole)
    local to = target - a
    local d = clamp(to.Magnitude, 0.05, l1 + l2 - 0.002)
    local dir = to.Magnitude > 1e-4 and to.Unit or -UP
    local c = clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
    local s = math.sqrt(1 - c * c)
    local perp = pole - dir * pole:Dot(dir)
    if perp.Magnitude < 1e-3 then perp = Vector3.zAxis - dir * dir.Z end
    perp = perp.Unit
    return a + dir * (l1 * c) + perp * (l1 * s)
end

local function damp(a, b, rate, dt)
    return a + (b - a) * (1 - math.exp(-rate * dt))
end

----------------------------------------------------------------- footstep sound
local MATERIAL_TONE = {
    [Enum.Material.Wood] = {0.9, 1, 2, -4}, [Enum.Material.WoodPlanks] = {0.9, 1, 2, -4},
    [Enum.Material.Metal] = {1.08, 0.9, -2, 3}, [Enum.Material.DiamondPlate] = {1.1, 0.9, -2, 4}, [Enum.Material.CorrodedMetal] = {1.06, 0.9, -2, 3},
    [Enum.Material.Fabric] = {0.92, 0.45, 0, -14}, [Enum.Material.Carpet] = {0.92, 0.45, 0, -14},
    [Enum.Material.Plastic] = {1.02, 1, 0, 0}, [Enum.Material.SmoothPlastic] = {1.03, 1, 0, 1},
    [Enum.Material.Marble] = {1.04, 1.05, -1, 2}, [Enum.Material.Slate] = {1, 1, 0, 0}, [Enum.Material.Concrete] = {0.98, 1, 0, -1},
    [Enum.Material.CeramicTiles] = {1.05, 1.05, -1, 2}, [Enum.Material.Granite] = {1, 1, 0, 0},
}


local function makeVoice(parent)
    local att = Instance.new("Attachment")
    att.Name = "StepVoice"
    att.Parent = parent
    local s = Instance.new("Sound")
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = 5
    s.RollOffMaxDistance = 70
    s.Parent = att
    local eq = Instance.new("EqualizerSoundEffect")
    eq.Parent = s
    return s, eq
end

----------------------------------------------------------------- rig setup
local d = nil


local function setup(model)
    local J = {}
    for _, m in ipairs(model:GetDescendants()) do
        if m:IsA("Motor6D") then J[m.Name] = m end
    end
    for _, n in ipairs({"Root", "Waist", "Neck", "RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist"}) do
        if not J[n] then return nil end
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local o = {model = model, J = J, root = root, phase = 0, vel = Vector3.zero, lastPos = root.Position, move = 0, lastYaw = 0, t = math.random() * 10}
    o.legs = {}
    for _, side in ipairs({"Right", "Left"}) do
        local hip, knee, ankle = J[side .. "Hip"], J[side .. "Knee"], J[side .. "Ankle"]
        local foot = model[side .. "Foot"]
        --bind pose worked out with every Transform at rest
        local lt = fk(CFrame.new(), J.Root, CFrame.new())
        local ul = fk(lt, hip, CFrame.new())
        local ll = fk(ul, knee, CFrame.new())
        local ft = fk(ll, ankle, CFrame.new())
        local leg = {
            side = side, hip = hip, knee = knee, ankle = ankle, foot = foot,
            thighBone = knee.C0.Position - hip.C1.Position,
            shinBone = ankle.C0.Position - knee.C1.Position,
            sole = ft * Vector3.new(0, -foot.Size.Y / 2, 0),
            ankleUp = (ft.Position - (ft * Vector3.new(0, -foot.Size.Y / 2, 0))).Y,
            footRot = ft.Rotation,
            offset = side == "Right" and 0 or 0.5,
            wasStance = true,
            sign = side == "Right" and 1 or -1,
        }
        leg.l1 = leg.thighBone.Magnitude
        leg.l2 = leg.shinBone.Magnitude
        leg.voice, leg.eq = makeVoice(foot)
        table.insert(o.legs, leg)
    end
    o.legLen = o.legs[1].l1 + o.legs[1].l2
    o.k = o.legLen / 2.6
    o.arms = {}
    for _, side in ipairs({"Right", "Left"}) do
        local sh, el, wr = J[side .. "Shoulder"], J[side .. "Elbow"], J[side .. "Wrist"]
        local arm = {
            side = side, sh = sh, el = el, wr = wr, attr = side == "Right" and "HandR" or "HandL",
            upperBone = el.C0.Position - sh.C1.Position,
            foreBone = wr.C0.Position - el.C1.Position,
            handOff = wr.C1.Position.Magnitude,
            sign = side == "Right" and 1 or -1,
            ik = 0, goal = nil,
            offset = side == "Right" and 0.5 or 0,
        }
        arm.l1 = arm.upperBone.Magnitude
        arm.l2 = arm.foreBone.Magnitude + arm.handOff
        table.insert(o.arms, arm)
    end
    o.fingers = {}
    for _, p in ipairs(model:GetChildren()) do
        if p:GetAttribute("Finger") then
            local j = p:FindFirstChildOfClass("Motor6D")
            if j then table.insert(o.fingers, {j = j, sign = p:GetAttribute("CurlSign") or 1, distal = p.Name:sub(-1) == "B", thumb = p.Name:find("Thumb") ~= nil, seed = math.random() * 50, right = p.Name:sub(1, 5) == "Right"}) end
        end
    end
    o.curl = 18
    --filter the body itself and anything that should never block a hand or foot
    local list = {model}
    local map = workspace:FindFirstChild("ChipotleMap")
    if map then
        for _, n in ipairs({"Ambience", "GroundFog", "NightProps"}) do
            local f = map:FindFirstChild(n)
            if f then table.insert(list, f) end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(list, p.Character) end
    end
    o.filter = list
    --sounds: the barefoot set once it is uploaded, otherwise the softened fallback
    local bare = {walk = ids(AudioIds.barefootWalk), run = ids(AudioIds.barefootRun), creep = ids(AudioIds.barefootCreep)}
    o.bare = #bare.walk > 0 and bare or nil
    return o
end

local function clearTransforms(o)
    for _, j in pairs(o.J) do j.Transform = CFrame.new() end
    for _, f in ipairs(o.fingers) do f.j.Transform = CFrame.new() end
end




local function playStep(o, leg, mode, hit, weight)
    local g = GAITS[mode] or GAITS.walk
    local s, eq = leg.voice, leg.eq
    local tone = hit and MATERIAL_TONE[hit.Material] or {1, 1, 0, 0}
    local id
    local bare = o.bare
    if bare then
        local list = (#bare[mode] > 0 and bare[mode]) or bare.walk
        id = list[math.random(1, #list)]
        s.PlaybackSpeed = (0.94 + math.random() * 0.12) * tone[1]
        eq.LowGain = tone[3]
        eq.MidGain = 0
        eq.HighGain = tone[4]
    else
        id = FALLBACK[math.random(1, #FALLBACK)]
        --a touch lower and duller so the tub ring goes and only skin on floor is left
        s.PlaybackSpeed = (mode == "run" and 0.95 or 0.86) * tone[1] + math.random() * 0.06
        eq.LowGain = 1 + tone[3]
        eq.MidGain = -3
        eq.HighGain = -11 + tone[4]
    end
    s.SoundId = "rbxassetid://" .. id
    local vol = g.vol * tone[2] * clamp(weight, 0.4, 1) * (bare and 1 or 0.6)
    s.Volume = vol
    s.TimePosition = 0
    s:Play()
    if not bare then
        --only the first contact of the clip is kept, the splash after it is faded out
        leg.stepToken = (leg.stepToken or 0) + 1
        local mine = leg.stepToken
        local gate = mode == "run" and 0.16 or 0.24
        task.delay(gate, function()
            if leg.stepToken ~= mine then return end
            local tw = TweenService:Create(s, TweenInfo.new(0.09), {Volume = 0})
            tw:Play()
            tw.Completed:Wait()
            if leg.stepToken == mine then s:Stop() end
        end)
    end
end

----------------------------------------------------------------- per frame


local function update(o, dt)
    local model, J, root = o.model, o.J, o.root
    if not model.Parent or not root.Parent then return false end
    local real = root.CFrame
    if real.Position.Y < -100 then
        --parked out of the world, nothing to animate
        clearTransforms(o)
        o.lastPos = real.Position
        o.smooth = nil
        o.vel = Vector3.zero
        return true
    end
    --the server position arrives in steps over the network, the body is drawn gliding after it instead
    --a big jump like appearing somewhere new snaps straight there
    if not o.smooth or (o.smooth.Position - real.Position).Magnitude > 8 then
        o.smooth = real
        o.lastPos = real.Position
    else
        o.smooth = o.smooth:Lerp(real, 1 - math.exp(-dt * 14))
    end
    local rcf = o.smooth
    local pos = rcf.Position
    o.t += dt
    rp.FilterDescendantsInstances = o.filter

    --how fast and which way the body is really moving, ignoring jumps from teleports
    local raw = (pos - o.lastPos) / math.max(dt, 1e-3)
    raw = Vector3.new(raw.X, 0, raw.Z)
    if raw.Magnitude > 45 then raw = Vector3.zero end
    o.lastPos = pos
    o.vel = o.vel:Lerp(raw, 1 - math.exp(-dt * 9))
    local look = Vector3.new(rcf.LookVector.X, 0, rcf.LookVector.Z)
    local yaw = math.atan2(-look.X, -look.Z)
    local yawRate = ((yaw - o.lastYaw + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1e-3)
    o.lastYaw = yaw
    local speed = o.vel.Magnitude
    local turnSpeed = abs(yawRate) * o.legLen * 0.35
    local eff = math.max(speed, turnSpeed)
    local mode = model:GetAttribute("Mode") or "walk"
    local g = GAITS[mode] or GAITS.walk
    o.move = damp(o.move, clamp(eff / 1.6, 0, 1), 6, dt)
    local w = o.move
    local k = o.k

    --stride grows with speed, cadence follows from it so planted feet do not slide
    local S = clamp((0.6 + 0.12 * eff) * k * g.stride, 0.6 * k, 3.6 * k)
    local rate = eff / (2 * S)
    if w < 0.05 then rate = 0 end
    o.phase = (o.phase + rate * dt) % 1
    local ph = o.phase
    local dirLocal = Vector3.new(0, 0, -1)
    if speed > 0.4 then
        local v = rcf:VectorToObjectSpace(o.vel)
        v = Vector3.new(v.X, 0, v.Z)
        if v.Magnitude > 1e-3 then dirLocal = v.Unit end
    end

    --pelvis drops into a crouch and bobs twice per cycle
    local breath = sin(o.t * 1.3)
    local bob = g.bob * k * (0.5 - 0.5 * cos(ph * 4 * math.pi)) * w
    local drop = g.crouch * k * clamp(w * 1.5, 0, 1) + bob
    --leans into turns like a real body would
    o.bank = damp(o.bank or 0, clamp(-yawRate * 0.05, -0.14, 0.14) * w, 5, dt)
    local roll = rad(g.sway) * sin(ph * 2 * math.pi) * w + o.bank
    local twist = rad(g.twist) * sin(ph * 2 * math.pi) * w
    --weight shifts over the planted foot each step
    local shift = g.shift * k * sin(ph * 2 * math.pi) * w
    local tRoot = CFrame.new(shift, -drop, 0) * CFrame.Angles(0, twist, roll)
    --the joint carries the gap between where the server has the body and where it is drawn
    local c0 = J.Root.C0
    J.Root.Transform = c0:Inverse() * real:Inverse() * rcf * c0 * tRoot
    local lt = fk(rcf, J.Root, tRoot)

    --legs
    for _, leg in ipairs(o.legs) do
        local p = (ph + leg.offset) % 1
        local fx, lift, stance
        if p < 0.5 then
            local u = p / 0.5
            fx = S / 2 * (1 - 2 * u)
            lift = 0
            stance = true
        else
            local u = (p - 0.5) / 0.5
            fx = -S / 2 * cos(math.pi * u)
            lift = g.lift * k * sin(math.pi * u)
            stance = false
        end
        local localSole = leg.sole + dirLocal * fx * w
        local soleW = rcf * localSole
        local hit = workspace:Raycast(soleW + UP * 2.4, -UP * 6, rp)
        local groundY = hit and hit.Position.Y or (rcf * leg.sole).Y
        local target = Vector3.new(soleW.X, groundY + lift * w + leg.ankleUp, soleW.Z)
        local hipPos = (lt * leg.hip.C0).Position
        --knees splay outward the deeper it crouches, and swing aside if they would go through a door or wall
        local bend = clamp(1 - (target - hipPos).Magnitude / (leg.l1 + leg.l2), 0, 1)
        local pole = rcf.LookVector + rcf.RightVector * (0.12 + 1.6 * bend) * leg.sign
        local kneePos = solve(hipPos, target, leg.l1, leg.l2, pole)
        local function blocked(k)
            local a = k - hipPos
            local b = target - k
            return workspace:Raycast(hipPos, a * 1.15, rp) or workspace:Raycast(k, b, rp)
        end
        if bend > 0.05 and blocked(kneePos) then
            for _, alt in ipairs({rcf.RightVector * leg.sign, rcf.RightVector * leg.sign - rcf.LookVector * 0.5, -rcf.LookVector}) do
                local k2 = solve(hipPos, target, leg.l1, leg.l2, alt)
                if not blocked(k2) then
                    kneePos = k2
                    break
                end
            end
        end
        local t1, ul = aim(lt, leg.hip, leg.thighBone, kneePos)
        leg.hip.Transform = t1
        local t2, ll = aim(ul, leg.knee, leg.shinBone, target)
        leg.knee.Transform = t2
        --foot stays level with the floor, toes dip a little while it swings
        local frame = ll * leg.ankle.C0
        local want = rcf.Rotation * leg.footRot * CFrame.Angles(stance and 0 or rad(-14) * sin(math.pi * ((p - 0.5) / 0.5)), 0, 0)
        leg.ankle.Transform = frame.Rotation:Inverse() * want * leg.ankle.C1.Rotation
        --heel strike
        if stance and not leg.wasStance and w > 0.3 then playStep(o, leg, mode, hit, w) end
        leg.wasStance = stance
    end

    --spine counters the hips, chest rises with breathing
    local tWaist = CFrame.Angles(rad(1.4) * breath, -twist * 0.8, -roll * 0.6)
    J.Waist.Transform = tWaist
    local ut = fk(lt, J.Waist, tWaist)
    --head stays steady while the body bobs
    local tNeck = CFrame.Angles(rad(-0.8) * breath + rad(2) * sin(o.t * 0.37) * 0.3, 0, -roll * 0.5)
    J.Neck.Transform = tNeck

    --arms
    local anyContact = false
    for _, arm in ipairs(o.arms) do
        local swing = rad(g.arm) * sin((ph + arm.offset) * 2 * math.pi) * w
        local tS = CFrame.Angles(swing, 0, 0)
        local tE = CFrame.Angles(rad(g.arm * 0.35) * (0.5 + 0.5 * sin((ph + arm.offset) * 2 * math.pi)) * w, 0, 0)
        local ua = fk(ut, arm.sh, tS)
        local la = fk(ua, arm.el, tE)
        local shoulderPos = (ut * arm.sh.C0).Position
        local handPos = (la * arm.wr.C0).Position + (la * arm.wr.C0).UpVector * -arm.handOff
        --a surface the server wants this hand on
        local goal = model:GetAttribute(arm.attr)
        local want = 0
        if typeof(goal) == "Vector3" then
            want = 1
            anyContact = true
        else
            --free arm: if it would go through something, stop the hand on the surface instead
            local reach = handPos - shoulderPos
            local hit = reach.Magnitude > 0.05 and workspace:Raycast(shoulderPos, reach.Unit * (reach.Magnitude + 0.45), rp)
            --a hanging hand can still slide into a door or wall in front of the body, so check straight ahead of it too
            if not hit then
                local fwd = Vector3.new(rcf.LookVector.X, 0, rcf.LookVector.Z).Unit
                local front = workspace:Raycast(handPos - fwd * 0.9, fwd * 1.5, rp)
                if front and front.Normal:Dot(fwd) < -0.3 then hit = front end
            end
            if hit then
                goal = hit.Position + hit.Normal * 0.55
                want = 1
            else
                goal = nil
            end
        end
        if goal then arm.goal = goal end
        arm.ik = damp(arm.ik, want, want > 0 and 9 or 5, dt)
        local foreCF = nil
        if arm.ik > 0.01 and arm.goal then
            local pole = -UP * 0.9 - rcf.LookVector * 0.45 + rcf.RightVector * 0.7 * arm.sign
            local elbowPos = solve(shoulderPos, arm.goal, arm.l1, arm.l2, pole)
            local ik1, ua2 = aim(ut, arm.sh, arm.upperBone, elbowPos)
            local ik2, la2 = aim(ua2, arm.el, arm.foreBone, arm.goal)
            arm.sh.Transform = tS:Lerp(ik1, arm.ik)
            arm.el.Transform = tE:Lerp(ik2, arm.ik)
            foreCF = la2
        else
            arm.sh.Transform = tS
            arm.el.Transform = tE
        end
        --palm turned flat onto a surface the server asked for, fingers pointing up along it
        arm.press = damp(arm.press or 0, typeof(model:GetAttribute(arm.attr)) == "Vector3" and 1 or 0, 8, dt)
        local rest = CFrame.Angles(rad(-18) * arm.ik, 0, 0)
        if foreCF and arm.press > 0.01 then
            local push = Vector3.new(arm.goal.X - shoulderPos.X, 0, arm.goal.Z - shoulderPos.Z)
            if push.Magnitude > 0.05 then
                push = push.Unit
                --the palm is the hand's -x side on the right hand and +x on the left
                local x = arm.side == "Right" and -push or push
                local want = CFrame.fromMatrix(Vector3.zero, x, -UP)
                local frame = foreCF * arm.wr.C0
                local flat = frame.Rotation:Inverse() * want * arm.wr.C1.Rotation
                arm.wr.Transform = rest:Lerp(flat, arm.press * arm.ik)
            else
                arm.wr.Transform = rest
            end
        else
            arm.wr.Transform = rest
        end
    end

    --fingers splay flat on contact, claw when running, never fully still
    --flat and straight against a surface so nothing pokes through it
    local wantCurl = anyContact and 0 or g.curl
    o.curl = damp(o.curl, wantCurl, 6, dt)
    for _, f in ipairs(o.fingers) do
        local twitch = math.noise(o.t * 0.9, f.seed) * (anyContact and 2 or 14)
        local c = o.curl + twitch
        if f.distal then c *= 1.25 end
        if f.thumb then c *= 0.5 end
        f.j.Transform = CFrame.Angles(0, 0, rad(c) * f.sign)
    end
    return true
end

----------------------------------------------------------------- hook up
RunService:BindToRenderStep("MonsterAnim", Enum.RenderPriority.Character.Value + 5, function(dt)
    if not d then
        local m = workspace:FindFirstChild("NightMonster")
        if m then d = setup(m) end
        if not d then return end
    end
    local ok, alive = pcall(update, d, dt)
    if not ok then
        warn("monster anim: " .. tostring(alive))
        d = nil
    elseif not alive then
        d = nil
    end
end)
