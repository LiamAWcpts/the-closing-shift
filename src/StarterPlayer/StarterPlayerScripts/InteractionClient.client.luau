--a hand reaches for whatever the player holds e on, and rides along with doors as they swing
--it uses whichever hand has a clear way to it, so a wall beside one shoulder never gets an arm pushed through it
--the hand stops on the first solid thing between the shoulder and the target and its flat end is kept just on the surface
--both arms are also kept out of walls and furniture while walking around
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local REACH_RATE = 9
local RELEASE_RATE = 6
local FOLLOW_TIME = 0.75
--how fast the hand slides toward a moving target, high enough to keep up with a swinging door without snapping
local TRACK_RATE = 16
--gap between the hand and whatever it is touching
local SURFACE_GAP = 0.1
--prompts that should not grab anything with the hand
local SKIP = {ChairPrompt = true, MessPrompt = true, VapePrompt = true}

local character = nil
--one reaching arm per side, each with its own ik, target and elbow pole
local arms = {}
local active = nil
local followUntil = 0

local function makeAttachment(name)
    local a = Instance.new("Attachment")
    a.Name = name
    a.Parent = workspace.Terrain
    return a
end


local function setupCharacter(char)
    character = char
    for _, a in pairs(arms) do
        a.ik:Destroy()
        a.holder:Destroy()
        a.pole:Destroy()
    end
    arms = {}
    active = nil
    local hum = char:WaitForChild("Humanoid")
    for _, side in ipairs({"Right", "Left"}) do
        local upper = char:WaitForChild(side .. "UpperArm", 10)
        local lower = char:WaitForChild(side .. "LowerArm", 10)
        local hand = char:WaitForChild(side .. "Hand", 10)
        if upper and lower and hand then
            --the ik moves the middle of the hand onto the target, not the wrist joint
            local center = hand:FindFirstChild("HandCenter") or Instance.new("Attachment")
            center.Name = "HandCenter"
            center.CFrame = CFrame.new()
            center.Parent = hand
            local holder = makeAttachment(side .. "ReachTarget")
            --the elbow aims at this so it bends down and a little out like a real arm
            local pole = makeAttachment(side .. "ReachPole")
            local ik = Instance.new("IKControl")
            ik.Name = side .. "ReachIK"
            --position and turn, the flat end of the hand is always the side that meets the surface so it never rolls a corner into it
            ik.Type = Enum.IKControlType.Transform
            ik.ChainRoot = upper
            ik.EndEffector = center
            ik.Target = holder
            ik.Pole = pole
            ik.Weight = 0
            ik.SmoothTime = 0.06
            ik.Parent = hum
            --the left hand mirrors the right, so its outward side is the other way
            arms[side] = {side = side, parts = {upper, lower, hand}, ik = ik, holder = holder, pole = pole, weight = 0, push = 0, out = side == "Right" and 1 or -1}
        end
    end
end
player.CharacterAdded:Connect(setupCharacter)
if player.Character then task.spawn(setupCharacter, player.Character) end


--closest point on a part to the player at about hand height
local function closestPoint(part, from)
    local cf = part.CFrame
    local half = part.Size / 2
    local l = cf:PointToObjectSpace(from)
    local clamped = Vector3.new(math.clamp(l.X, -half.X, half.X), math.clamp(l.Y, -half.Y, half.Y), math.clamp(l.Z, -half.Z, half.Z))
    return cf:PointToWorldSpace(clamped)
end




--how far the middle of a hand has to sit off a surface so no corner of the block goes in
--worked out from the way the hand is turned right now, so it is right from any angle
local function handClearance(hand, n)
    local cf = hand.CFrame
    local half = hand.Size / 2
    return math.abs(cf.RightVector:Dot(n)) * half.X + math.abs(cf.UpVector:Dot(n)) * half.Y + math.abs(cf.LookVector:Dot(n)) * half.Z + SURFACE_GAP
end



local function handHalfWidth()
    local a = arms.Right or arms.Left
    if not a then return 0.3 end
    local hand = a.parts[3]
    return math.max(hand.Size.X, hand.Size.Z) / 2
end


local function armRadius(a)
    local lower = a.parts[2]
    return math.min(lower.Size.X, lower.Size.Z) / 2 * 0.9
end


local function armLength(a)
    local reach = 0
    for _, p in ipairs(a.parts) do reach += p.Size.Y end
    return reach
end


--works out where the handle is on a door, on the side the player is standing
--returns the spot on the door face and which way the face points, both in the door's own space
local function doorHandle(door, from)
    local primary = door.PrimaryPart
    local hinge = door:GetAttribute("Hinge")
    if not primary or not hinge then return nil end
    local cf = primary.CFrame
    local size = primary.Size
    local widthAxis, normal, width, thick
    if size.X >= size.Z then
        widthAxis = cf.RightVector normal = cf.LookVector width = size.X thick = size.Z
    else
        widthAxis = cf.LookVector normal = cf.RightVector width = size.Z thick = size.X
    end
    --far enough in from the edge that the whole hand stays clear of the frame
    local inset = math.max(0.4, handHalfWidth() + 0.35)
    local a = cf.Position + widthAxis * (width / 2 - inset)
    local b = cf.Position - widthAxis * (width / 2 - inset)
    --the handle is on the edge away from the hinge
    local edge = a
    if (b - hinge).Magnitude > (a - hinge).Magnitude then edge = b end
    local side = 1
    if (from - cf.Position):Dot(normal) < 0 then side = -1 end
    --the spot on the face of the door, the hand is held off it by its own size every frame
    local point = Vector3.new(edge.X, hinge.Y - 0.4, edge.Z) + normal * side * (thick / 2)
    return primary, cf:PointToObjectSpace(point), cf:VectorToObjectSpace(normal * side)
end

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.RespectCanCollide = true
--only looks at the thing being reached for, to find its real front face
local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Include
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true


local function ignoreList(model)
    local list = {character, workspace.CurrentCamera}
    for _, a in pairs(arms) do
        table.insert(list, a.holder)
        table.insert(list, a.pole)
    end
    if model then table.insert(list, model) end
    return list
end


--first solid thing between the shoulder and the goal, the thing being reached for does not count
local function blockedAt(a, goal, model)
    castParams.FilterDescendantsInstances = ignoreList(model)
    local shoulder = a.parts[1].Position
    local dir = goal - shoulder
    if dir.Magnitude < 0.05 then return nil end
    --a sweep about as thick as the forearm
    local ok, hit = pcall(function() return workspace:Spherecast(shoulder, armRadius(a), dir, castParams) end)
    if not ok then hit = workspace:Raycast(shoulder, dir, castParams) end
    return hit
end

--true when the top of this arm is already pressed into something, a reach with it would only go through
local function shoulderStuck(a, model)
    overlapParams.FilterDescendantsInstances = ignoreList(model)
    return #workspace:GetPartsInPart(a.parts[1], overlapParams) > 0
end


local function start(prompt)
    if not character or not next(arms) then return end
    if SKIP[prompt.Name] then return end
    local part = prompt.Parent
    local point = nil
    if part and part:IsA("Attachment") then
        point = part
        part = part.Parent
    end
    if not part or not part:IsA("BasePart") then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local from = root.Position + Vector3.new(0, 1.2, 0)
    local anchor, offset, normal
    local door = part.Parent
    if prompt.Name == "DoorPrompt" and door and door:IsA("Model") then
        anchor, offset, normal = doorHandle(door, from)
    end
    if not anchor then
        anchor = part
        local p = closestPoint(part, from)
        --an invisible marker part means reach for the marked spot, not empty air around it
        if point and part.Transparency > 0.9 then p = point.WorldPosition end
        local back = from - p
        local n = back.Magnitude > 0.01 and back.Unit or -root.CFrame.LookVector
        offset = part.CFrame:PointToObjectSpace(p)
        normal = part.CFrame:VectorToObjectSpace(n)
    end
    local model = (door and door:IsA("Model")) and door or part
    local contact = anchor.CFrame:PointToWorldSpace(offset)
    --pick the hand: in reach, nothing between it and the spot, shoulder not already in a wall, then the nearer one
    local best, bestScore = nil, math.huge
    for _, a in pairs(arms) do
        local shoulder = a.parts[1].Position
        local d = (contact - shoulder).Magnitude
        if d <= armLength(a) * 1.1 + 0.5 and not shoulderStuck(a, model) then
            local score = d
            if blockedAt(a, contact, model) then score += 50 end
            --the right hand is the usual one
            if a.side == "Right" then score -= 0.35 end
            if score < bestScore then best, bestScore = a, score end
        end
    end
    --too far to touch it with either hand, they stay down instead of grabbing at empty air
    if not best then return end
    --start the reach from where the hand already is so it never jumps
    if not (active and active.arm == best) then
        best.holder.WorldCFrame = best.parts[3].CFrame
        best.push = 0
    end
    active = {prompt = prompt, anchor = anchor, offset = offset, normal = normal, model = model, arm = best}
    followUntil = 0
end


local function release()
    active = nil
end

PPS.PromptButtonHoldBegan:Connect(function(prompt)
    start(prompt)
end)
PPS.PromptButtonHoldEnded:Connect(function(prompt)
    if active and active.prompt == prompt and os.clock() > followUntil then release() end
end)
PPS.PromptTriggered:Connect(function(prompt)
    --a one tap prompt like the office door has no hold, so the hand goes out as it fires and rides the door
    if prompt.HoldDuration <= 0 and not (active and active.prompt == prompt) then start(prompt) end
    if active and active.prompt == prompt then
        --keep a grip on the door while it starts to move
        followUntil = os.clock() + FOLLOW_TIME
        task.delay(FOLLOW_TIME, function()
            if active and active.prompt == prompt and os.clock() >= followUntil then release() end
        end)
    end
end)


--places the target for the arm doing the reach, returns false once it should let go
local function aim(a, root, dt)
    local hand = a.parts[3]
    local shoulder = a.parts[1].Position
    local contact = active.anchor.CFrame:PointToWorldSpace(active.offset)
    local normal = active.anchor.CFrame:VectorToWorldSpace(active.normal)
    --let go once the door swings past arms length
    if (contact - shoulder).Magnitude > armLength(a) * 1.3 then return false end
    --the end of the hand faces the surface, knuckles level with the shoulders
    local across = root.CFrame.RightVector
    across = across - normal * across:Dot(normal)
    if across.Magnitude < 0.05 then across = root.CFrame.LookVector - normal * root.CFrame.LookVector:Dot(normal) end
    across = across.Unit
    --panels, plates and handles sitting proud of the door count as its surface too
    --a flat box the size of the hand is pushed in so anything under any part of the hand is found
    probeParams.FilterDescendantsInstances = {active.model}
    local probeFrom = CFrame.fromMatrix(contact + normal * 2, across, normal)
    local footprint = Vector3.new(hand.Size.X, 0.05, hand.Size.Z)
    local ok, probe = pcall(function() return workspace:Blockcast(probeFrom, footprint, -normal * 2.5, probeParams) end)
    if ok and probe then contact = probeFrom.Position - normal * (probe.Distance + 0.025) end
    --a wall or frame in the way: the hand comes to rest against that instead of passing through
    local hit = blockedAt(a, contact + normal * handClearance(hand, normal), active.model)
    if hit then
        contact = hit.Position
        normal = hit.Normal
        across = across - normal * across:Dot(normal)
        if across.Magnitude < 0.05 then across = Vector3.yAxis:Cross(normal) end
        across = across.Unit
    end
    --once the arm is out, any corner of the hand sinking in pushes the target back out, any gap lets it settle in
    if a.weight > 0.85 then
        local gap = (hand.Position - contact):Dot(normal) - handClearance(hand, normal)
        a.push = math.clamp(a.push - gap * math.min(1, dt * 10), 0, 1)
    end
    local flatEnd = hand.Size.Y / 2 + SURFACE_GAP
    local goal = CFrame.fromMatrix(contact + normal * (flatEnd + a.push), across, normal)
    a.holder.WorldCFrame = a.holder.WorldCFrame:Lerp(goal, 1 - math.exp(-TRACK_RATE * dt))
    --elbow points down and slightly out, or straight down when there is a wall on that side
    local rcf = root.CFrame
    local outward = rcf.RightVector * a.out
    local out = outward * 0.9
    castParams.FilterDescendantsInstances = {character}
    if workspace:Raycast(shoulder, outward * 1.4, castParams) then out = Vector3.zero end
    local polePos = shoulder - rcf.UpVector * 1.8 + out + rcf.LookVector * 0.2
    --the elbow swings away from anything it would bend into
    local elbowHit = workspace:Raycast(shoulder, (polePos - shoulder).Unit * 1.3, castParams)
    if elbowHit then polePos += elbowHit.Normal * 1.2 end
    a.pole.WorldPosition = polePos
    return true
end

--runs after the camera so the arm shows up in first person while it reaches
RunService:BindToRenderStep("HandReach", Enum.RenderPriority.Camera.Value + 2, function(dt)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if active and not (active.anchor.Parent and root and arms[active.arm.side] == active.arm) then release() end
    for _, a in pairs(arms) do
        local want = 0
        if active and active.arm == a then
            if aim(a, root, dt) then want = 1 else release() end
        end
        local rate = want > a.weight and REACH_RATE or RELEASE_RATE
        a.weight += (want - a.weight) * (1 - math.exp(-rate * dt))
        if a.weight < 0.01 and want == 0 then a.weight = 0 end
        a.ik.Weight = a.weight
        if a.weight > 0.02 then
            for _, p in ipairs(a.parts) do p.LocalTransparencyModifier = 0 end
        end
    end
end)

----------------------------------------------------------------- arms kept out of walls
--the walk and idle swing can carry a hand into a wall or a counter
--each arm works out its animated pose before ik runs and if it would go into something it is held flat on the surface
local guard = {}
local guardParams = RaycastParams.new()
guardParams.FilterType = Enum.RaycastFilterType.Exclude
guardParams.RespectCanCollide = true
local GUARD_IN = 16
local GUARD_OUT = 7


local function setupGuard(char)
    for _, g in pairs(guard) do
        g.ik:Destroy()
        g.target:Destroy()
        g.pole:Destroy()
    end
    guard = {}
    local hum = char:WaitForChild("Humanoid")
    for _, side in ipairs({"Right", "Left"}) do
        local upper = char:WaitForChild(side .. "UpperArm", 10)
        local lower = char:WaitForChild(side .. "LowerArm", 10)
        local hand = char:WaitForChild(side .. "Hand", 10)
        local sh = upper and upper:WaitForChild(side .. "Shoulder", 5)
        local el = lower and lower:WaitForChild(side .. "Elbow", 5)
        local wr = hand and hand:WaitForChild(side .. "Wrist", 5)
        if sh and el and wr then
            local target = Instance.new("Attachment")
            target.Name = side .. "GuardTarget"
            target.Parent = workspace.Terrain
            local gpole = Instance.new("Attachment")
            gpole.Name = side .. "GuardPole"
            gpole.Parent = workspace.Terrain
            local center = hand:FindFirstChild("HandCenter") or Instance.new("Attachment")
            center.Name = "HandCenter"
            center.CFrame = CFrame.new()
            center.Parent = hand
            local g = Instance.new("IKControl")
            g.Name = side .. "ArmGuard"
            g.Type = Enum.IKControlType.Position
            g.ChainRoot = upper
            g.EndEffector = center
            g.Target = target
            g.Pole = gpole
            g.Weight = 0
            g.SmoothTime = 0.03
            g.Parent = hum
            guard[side] = {ik = g, target = target, pole = gpole, sh = sh, el = el, wr = wr, upper = upper, lower = lower, hand = hand, weight = 0, corr = 0}
        end
    end
end
player.CharacterAdded:Connect(setupGuard)
if player.Character then task.spawn(setupGuard, player.Character) end

--the body collides as a 2 stud box but the shoulders are wider than that, so walking against a wall
--used to sink the arms into it, a rounded invisible bar across the shoulders keeps the body that bit further off
--it is narrower than the thinnest doorway and its round ends slide off frames instead of catching
local BUMPER_WIDTH = 2.7
local bumper = nil


local function syncBumper()
    if not bumper then return end
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local off = player:GetAttribute("Seated") or player:GetAttribute("Hiding") or player:GetAttribute("InCutscene") or (hum and hum.Sit)
    bumper.CanCollide = not off
end


local function setupBumper(char)
    if bumper then bumper:Destroy() bumper = nil end
    local torso = char:WaitForChild("UpperTorso", 10)
    local hum = char:WaitForChild("Humanoid", 10)
    local sh = char:WaitForChild("RightUpperArm", 10) and char.RightUpperArm:WaitForChild("RightShoulder", 5)
    if not torso or not hum then return end
    local height = sh and sh.C0.Position.Y or 0.6
    local p = Instance.new("Part")
    p.Name = "ShoulderBumper"
    p.Shape = Enum.PartType.Cylinder
    p.Size = Vector3.new(BUMPER_WIDTH, 1.1, 1.1)
    p.Transparency = 1
    p.CanQuery = false
    p.CanTouch = false
    p.Massless = true
    p.CastShadow = false
    p.CFrame = torso.CFrame * CFrame.new(0, height, 0)
    local w = Instance.new("WeldConstraint")
    w.Part0 = torso
    w.Part1 = p
    w.Parent = p
    p.Parent = char
    bumper = p
    syncBumper()
    hum:GetPropertyChangedSignal("Sit"):Connect(syncBumper)
end
player.CharacterAdded:Connect(setupBumper)
if player.Character then task.spawn(setupBumper, player.Character) end
for _, a in ipairs({"Seated", "Hiding", "InCutscene"}) do player:GetAttributeChangedSignal(a):Connect(syncBumper) end


--a sweep as thick as the arm itself, these blocky arms are about a stud across
local function sweep(a, b, radius)
    local dir = b - a
    if dir.Magnitude < 0.05 then return nil end
    local ok, hit = pcall(function() return workspace:Spherecast(a, radius, dir, guardParams) end)
    if not ok then hit = workspace:Raycast(a, dir, guardParams) end
    return hit
end

--the motors still hold the plain animation here, the ik is applied after this point in the frame
RunService.PreSimulation:Connect(function(dt)
    if not character then return end
    local off = player:GetAttribute("Hiding") or player:GetAttribute("Seated") or player:GetAttribute("InCutscene")
    guardParams.FilterDescendantsInstances = ignoreList()
    for side, g in pairs(guard) do
        local want = 0
        --in first person the arms are hidden unless reaching, nothing to fix there
        local seen = g.hand.Parent and g.hand.LocalTransparencyModifier < 0.5
        local reaching = arms[side] ~= nil and arms[side].weight > 0.01
        if reaching then g.weight = 0 end
        if not off and seen and not reaching and g.sh.Part0 then
            local shoulderCF = g.sh.Part0.CFrame * g.sh.C0
            local upperCF = shoulderCF * g.sh.Transform * g.sh.C1:Inverse()
            local elbowCF = upperCF * g.el.C0
            local lowerCF = elbowCF * g.el.Transform * g.el.C1:Inverse()
            local handCF = lowerCF * g.wr.C0 * g.wr.Transform * g.wr.C1:Inverse()
            local tip = (handCF * CFrame.new(0, -g.hand.Size.Y / 2, 0)).Position
            --checked from the middle of the chest, which is never inside anything, so a post the whole arm already sits in still counts
            local chest = g.sh.Part0.Position
            local upperR = math.min(g.upper.Size.X, g.upper.Size.Z) / 2 * 0.9
            local lowerR = math.min(g.lower.Size.X, g.lower.Size.Z) / 2 * 0.9
            local hit = sweep(chest, elbowCF.Position, upperR) or sweep(chest, handCF.Position, lowerR) or sweep(elbowCF.Position, tip, lowerR)
            if hit then
                want = 1
                local n = hit.Normal
                local radius = math.max(lowerR, math.min(g.hand.Size.X, g.hand.Size.Z) / 2) + 0.08
                --the hand stays where the animation had it, just pushed back out onto the surface
                local depth = (handCF.Position - hit.Position):Dot(n)
                local safe = handCF.Position + n * math.max(0, radius - depth)
                --pushed in that far it would land inside the chest, so it comes round in front of the body instead
                local torso = g.sh.Part0
                local l = torso.CFrame:PointToObjectSpace(safe)
                local halfW = torso.Size.X / 2 + radius * 0.6
                local halfD = torso.Size.Z / 2 + radius
                if math.abs(l.X) < halfW and math.abs(l.Z) < halfD then
                    safe = torso.CFrame:PointToWorldSpace(Vector3.new(l.X, l.Y, -halfD))
                end
                if g.weight < 0.02 then
                    g.target.WorldPosition = g.hand.Position
                    g.corr = 0
                end
                --same sink in correction as the reach, only ever along the wall normal
                if g.weight > 0.85 then
                    local gap = (g.hand.Position - hit.Position):Dot(n) - radius
                    g.corr = math.clamp(g.corr - gap * math.min(1, dt * 10), 0, 1)
                end
                g.target.WorldPosition = g.target.WorldPosition:Lerp(safe + n * g.corr, 1 - math.exp(-20 * dt))
                --and the elbow bends away from the wall instead of into it
                g.pole.WorldPosition = elbowCF.Position + n * 1.2 - Vector3.yAxis * 0.4
            end
        end
        local rate = want > g.weight and GUARD_IN or GUARD_OUT
        g.weight += (want - g.weight) * (1 - math.exp(-rate * dt))
        if g.weight < 0.01 and want == 0 then g.weight = 0 end
        g.ik.Weight = g.weight
    end
end)
