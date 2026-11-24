--five minute night from 12 to 5 am, the jobs and how many you can miss depend on the difficulty and how many are on shift
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local ev = RS:WaitForChild("NightEvent")
local map = workspace:WaitForChild("ChipotleMap")
local props = map:WaitForChild("NightProps")
local breaker = props:WaitForChild("BreakerBox")
local phone = props:WaitForChild("OfficePhone")
--prompts sit on a PromptPoint attachment so the line of sight check reaches a visible spot
local chairPrompt = map:WaitForChild("BackRooms"):WaitForChild("OfficeChair"):WaitForChild("ChairSeat"):WaitForChild("PromptPoint"):WaitForChild("ChairPrompt")
local hallway = map:WaitForChild("KitchenHallway")

local HOUR_SECONDS = 60
local LAST_HOUR = 5
local NIGHT_LENGTH = HOUR_SECONDS * LAST_HOUR
local MAX_STRIKES = 3

--the jobs a shift is built from, each night uses four of these five
local CORE = {"mess", "line", "window", "vape", "garbage"}
local PER_NIGHT = 4
--the garbage run goes outside to the dumpsters, so it gets longer on the clock
local TASK_TIMES = {garbage = 55}
local difficulty = "Normal"
workspace:SetAttribute("Difficulty", difficulty)
--everyone in the server votes on the difficulty, the vote opens again once a night is over
local vote = {choices = {}, decided = nil, deadline = nil}
local VOTE_TIME = 15

----------------------------------------------------------------- five night runs
--each difficulty is a run of five nights, the next one unlocks when the one before it is won
--saved per player as the night they are on for each difficulty, and whether they beat night 5
local LAST_NIGHT = 5
local DataStoreService = game:GetService("DataStoreService")
local progressStore = nil
pcall(function() progressStore = DataStoreService:GetDataStore("ChipotleNights_v1") end)


local function loadProgress(plr)
    local data = nil
    if progressStore then
        pcall(function() data = progressStore:GetAsync("u" .. plr.UserId) end)
    end
    data = type(data) == "table" and data or {}
    for _, d in ipairs({"Easy", "Normal", "Hard"}) do
        plr:SetAttribute("Night_" .. d, math.clamp(tonumber(data[d]) or 1, 1, LAST_NIGHT))
        plr:SetAttribute("Beat_" .. d, data["beat" .. d] == true)
    end
end

local function saveProgress(plr)
    if not progressStore then return end
    local data = {}
    for _, d in ipairs({"Easy", "Normal", "Hard"}) do
        data[d] = plr:GetAttribute("Night_" .. d) or 1
        data["beat" .. d] = plr:GetAttribute("Beat_" .. d) == true
    end
    task.spawn(function()
        pcall(function() progressStore:SetAsync("u" .. plr.UserId, data) end)
    end)
end

Players.PlayerAdded:Connect(loadProgress)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadProgress, p) end


--a shift plays the earliest night anyone on it is up to, so nobody skips a night
local function shiftNight()
    local n = LAST_NIGHT
    for _, p in ipairs(Players:GetPlayers()) do
        n = math.min(n, p:GetAttribute("Night_" .. difficulty) or 1)
    end
    return n
end




--0 on night 1 up to 1 on night 5
local function nightScale()
    return ((workspace:GetAttribute("NightNumber") or 1) - 1) / (LAST_NIGHT - 1)
end

local CLICK = "rbxassetid://9119717286"
local DING = "rbxassetid://9113938822"

local night = {running = false, id = 0, strikes = 0, objectives = {}, queue = {}, missed = 0, failing = false, current = {}}
local active = {}



--sends tonight's job list to every screen
local function publishObjectives()
    local list = {}
    for _, o in ipairs(night.objectives) do
        table.insert(list, {c = o.cat, s = o.status, r = o.retry and 1 or 0})
    end
    workspace:SetAttribute("Objectives", HttpService:JSONEncode(list))
end




local function countActive()
    local n = 0
    for _ in pairs(active) do n += 1 end
    --the monster reads this so it never starts breaking in while a job is open
    workspace:SetAttribute("TasksActive", n)
end


local function broadcast(...)
    ev:FireAllClients(...)
end

local function playSoundAt(parent, id, volume, speed)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume
    s.PlaybackSpeed = speed or 1
    s.RollOffMaxDistance = 70
    s.Parent = parent
    s:Play()
    game:GetService("Debris"):AddItem(s, 4)
end



local function shuffle(list)
    local copy = {table.unpack(list)}
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

----------------------------------------------------------------- lights
local lightObjs = {}
local neonObjs = {}
for _, d in ipairs(map:GetDescendants()) do
    if not d:IsDescendantOf(map.SecurityCameras) and not d:IsDescendantOf(props) then
        if d:IsA("Light") then
            table.insert(lightObjs, {obj = d, on = d.Enabled})
        elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
            table.insert(neonObjs, {obj = d, color = d.Color})
        end
    end
end
local normalAmbient = Lighting.Ambient
local normalOutdoor = Lighting.OutdoorAmbient

for _, l in ipairs(lightObjs) do l.base = l.obj.Brightness end

--breaker power and the monster hunt both darken the store, lights only come back when neither is going
local powerOn = true




local function applyLights(fadeTime)
    local on = powerOn and not workspace:GetAttribute("Hunting")
    for _, l in ipairs(lightObjs) do
        if on then
            l.obj.Enabled = l.on
            if fadeTime and fadeTime > 0 then
                l.obj.Brightness = 0
                TweenService:Create(l.obj, TweenInfo.new(fadeTime * (0.7 + math.random() * 0.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = l.base}):Play()
            else
                l.obj.Brightness = l.base
            end
        else
            l.obj.Enabled = false
        end
    end
    for _, n in ipairs(neonObjs) do
        n.obj.Color = on and n.color or n.color:Lerp(Color3.new(0, 0, 0), 0.92)
    end
    --a hunt keeps a little ambient so the room right in front of you still reads
    local dark = workspace:GetAttribute("Hunting") and Color3.fromRGB(14, 14, 19) or Color3.fromRGB(4, 4, 6)
    Lighting.Ambient = on and normalAmbient or dark
    Lighting.OutdoorAmbient = on and normalOutdoor or dark
end

local function setPower(on)
    powerOn = on
    applyLights()
end

workspace:GetAttributeChangedSignal("Hunting"):Connect(function()
    --cut instantly when it gets in, ease back on after it leaves
    applyLights(workspace:GetAttribute("Hunting") and 0 or 3)
end)

----------------------------------------------------------------- strikes and finishing events



local function resetWorld()
    setPower(true)
    phone.Base.Ring:Stop()
    phone.RingLight.RingGlow.Brightness = 0
end


--outcome is "done" when the player finished it, "missed" when the clock ran out, "cancel" when the night stopped
local function endEvent(name, outcome)
    local e = active[name]
    if e then
        outcome = outcome or "done"
        active[name] = nil
        countActive()
        workspace:SetAttribute("TaskLeft_" .. name, nil)
        workspace:SetAttribute("TaskPos_" .. name, nil)
        e.cleanup()
        broadcast("resolved", name)
        --the job it belongs to gets ticked off or marked missed, only once
        if e.objective and e.objective.status == "active" then
            e.objective.status = outcome
            publishObjectives()
            if outcome == "done" then broadcast("taskDone", name) end
        end
    end
end

local function endNight(won)
    night.running = false
    vote.choices = {}
    vote.decided = nil
    vote.deadline = nil
    night.id += 1
    for name in pairs(active) do endEvent(name, "cancel") end
    resetWorld()
    workspace:SetAttribute("NightActive", false)
    workspace:SetAttribute("JobFailed", false)
    workspace:SetAttribute("ForceHunt", false)
    --a win moves everyone on the shift up to the next night of this difficulty
    if won then
        local played = workspace:GetAttribute("NightNumber") or 1
        for _, p in ipairs(Players:GetPlayers()) do
            --someone who joined mid night only watched, they do not move up
            if p:GetAttribute("Waiting") then continue end
            local current = p:GetAttribute("Night_" .. difficulty) or 1
            if played >= LAST_NIGHT then
                p:SetAttribute("Beat_" .. difficulty, true)
            end
            p:SetAttribute("Night_" .. difficulty, math.max(current, math.min(played + 1, LAST_NIGHT)))
            saveProgress(p)
        end
    end
    broadcast(won and "won" or "failed", night.failReason)
    --after a few seconds the night can be started again from the chair
    task.delay(9, function()
        if not night.running then broadcast("reset") end
    end)
end


local function addStrike(reason)
    if not night.running then return end
    night.strikes += 1
    broadcast("strike", night.strikes, MAX_STRIKES, reason)
    if night.strikes >= MAX_STRIKES then
        endNight(false)
    end
end


local function failEvent(name, reason)
    if active[name] then
        endEvent(name, "missed")
        addStrike(reason)
    end
end

--every task gets the same thirty seconds
local TASK_TIME = 30


--a missed shift: the monster is sent for the player wherever they are, the office does not save them from this
local function failNight(reason)
    if not night.running or night.failing then return end
    night.failing = true
    night.failReason = reason
    for name in pairs(active) do endEvent(name, "cancel") end
    broadcast("jobFailed", reason)
    workspace:SetAttribute("ForceHunt", false)
    workspace:SetAttribute("JobFailed", true)
    local id = night.id
    --the kill normally ends the night, this only catches it if something went wrong
    task.delay(14, function()
        if night.id == id and night.running then endNight(false) end
    end)
end



--a missed job comes back once more later in the night if there is still time for it
local function retryLater(cat)
    local now = workspace:GetServerTimeNow() - (workspace:GetAttribute("NightStart") or 0)
    local at = now + 10
    if at + TASK_TIME > NIGHT_LENGTH - 4 then return end
    local o = {cat = cat, status = "pending", retry = true}
    table.insert(night.objectives, o)
    table.insert(night.queue, {at = at, objective = o})
    publishObjectives()
end

--misses a shift can take: what one player gets on this difficulty, times everyone on the shift
--easy never fails on misses, normal allows one each, hard allows none
local function allowedMisses()
    local players = workspace:GetAttribute("ShiftPlayers") or 1
    if difficulty == "Easy" then return math.huge end
    if difficulty == "Hard" then return 0 end
    return players
end

local function onMissed(o)
    night.missed += 1
    workspace:SetAttribute("MissedTasks", night.missed)
    if night.missed > allowedMisses() then
        failNight(difficulty == "Hard" and "you missed a task" or "you missed too many tasks")
        return
    end
    --anything still allowed gets another go later
    retryLater(o.cat)
end

--registers a task with its own countdown, kept here on the server so leaving and coming back never resets it
--the clock keeps running through hunts, hiding in the office never buys time
local function register(name, alertText, cleanup, pos)
    --later nights give a few seconds less, up to 15 percent less on night 5
    local TASK_TIME = math.floor((TASK_TIMES[name] or TASK_TIME) * (1 - 0.15 * nightScale()))
    local e = {cleanup = cleanup, objective = night.current[name]}
    if e.objective then
        e.objective.status = "active"
        publishObjectives()
    end
    active[name] = e
    countActive()
    broadcast("alert", name, alertText, TASK_TIME)
    local id = night.id
    workspace:SetAttribute("TaskLeft_" .. name, TASK_TIME)
    if pos then workspace:SetAttribute("TaskPos_" .. name, pos) end
    task.spawn(function()
        local left = TASK_TIME
        while left > 0 do
            local dt = task.wait(0.1)
            if active[name] ~= e or night.id ~= id then return end
            left -= dt
            workspace:SetAttribute("TaskLeft_" .. name, math.max(0, left))
        end
        if active[name] == e and night.id == id then
            endEvent(name, "missed")
            broadcast("timedOut", name)
            if e.objective then onMissed(e.objective) end
            --running out of time also brings the monster in
            if not night.failing then workspace:SetAttribute("ForceHunt", true) end
        end
    end)
end

----------------------------------------------------------------- blocky customers
local shirts = {Color3.fromRGB(70, 60, 60), Color3.fromRGB(55, 65, 75), Color3.fromRGB(80, 75, 55), Color3.fromRGB(60, 70, 60)}
local pantsColors = {Color3.fromRGB(35, 35, 40), Color3.fromRGB(50, 45, 40), Color3.fromRGB(40, 50, 60)}


--fades every visible piece of a customer to the given transparency
local function fadeCustomer(m, goal, time)
    for _, p in ipairs(m:GetChildren()) do
        if p:IsA("BasePart") then
            TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Sine), {Transparency = goal}):Play()
        end
    end
end


local function makeCustomer(cf)
    local m = Instance.new("Model")
    m.Name = "Customer"
    local skin = Color3.fromRGB(176, 168, 160)
    local shirt = shirts[math.random(1, #shirts)]
    local pants = pantsColors[math.random(1, #pantsColors)]
    local function piece(name, size, offset, color)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf * CFrame.new(offset)
        p.Color = color
        p.Material = Enum.Material.SmoothPlastic
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CastShadow = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        --starts invisible and fades in where it stands
        p.Transparency = 1
        p.Parent = m
        return p
    end
    m.PrimaryPart = piece("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), shirt)
    piece("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.7, 0), skin)
    piece("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), shirt)
    piece("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), shirt)
    piece("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), pants)
    piece("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), pants)
    m.Parent = workspace
    fadeCustomer(m, 0, 0.9)
    return m
end

--the line is a queue, the front customer stands at the line spot and the rest wait behind
local QUEUE_GAP = 3.2
local lineQueue = {}


local function queueCF(index)
    local spot = props.LineCustomerSpot.Position + Vector3.new(0, 0, (index - 1) * QUEUE_GAP)
    return CFrame.lookAt(spot, spot + Vector3.new(0, 0, -1))
end


--anyone still waiting moves up a place by fading out and back in one spot closer
local function reflowQueue()
    for i, m in ipairs(lineQueue) do
        if m.Parent and (m:GetPivot().Position - queueCF(i).Position).Magnitude > 0.1 then
            task.spawn(function()
                fadeCustomer(m, 1, 0.35)
                task.wait(0.4)
                if m.Parent then
                    m:PivotTo(queueCF(i))
                    fadeCustomer(m, 0, 0.5)
                end
            end)
        end
    end
end


local function removeCustomer(m)
    if not m or not m.Parent then return end
    fadeCustomer(m, 1, 0.9)
    task.delay(1, function() m:Destroy() end)
    local i = table.find(lineQueue, m)
    if i then
        table.remove(lineQueue, i)
        reflowQueue()
    end
end

----------------------------------------------------------------- event: lights out
local breakerPrompt = breaker.Body.PromptPoint.BreakerPrompt
local breakerLed = breaker.StatusLight




local function startLightsOut()
    local id = night.id
    task.spawn(function()
        for i = 1, 4 do
            setPower(false) task.wait(0.07)
            if night.id ~= id then return end
            setPower(true) task.wait(0.12)
        end
        if night.id == id and active.lights then setPower(false) end
    end)
    playSoundAt(breaker.Body, CLICK, 1, 0.6)
    breakerLed.Color = Color3.fromRGB(220, 40, 40)
    breaker.Body:FindFirstChild("StatusGlow")
    breakerLed.StatusGlow.Color = Color3.fromRGB(220, 40, 40)
    breakerPrompt.Enabled = true
    register("lights", "the power went out. fix the breaker in the back", function()
        breakerPrompt.Enabled = false
        setPower(true)
        breakerLed.Color = Color3.fromRGB(40, 200, 70)
        breakerLed.StatusGlow.Color = Color3.fromRGB(40, 200, 70)
        playSoundAt(breaker.Body, CLICK, 1, 1)
    end)
end

breakerPrompt.Triggered:Connect(function(player)
    if active.lights then ev:FireClient(player, "wires") end
end)

----------------------------------------------------------------- event: mess
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.FilterDescendantsInstances = {props, map.SecurityCameras, map.Ambience, map.GroundFog}
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = {props, map.SecurityCameras, map.Ambience, map.GroundFog}
local zones = {
    {name = "dining room", minX = -50, maxX = 4, minZ = 4.5, maxZ = 17},
    {name = "kitchen", minX = -25, maxX = -8, minZ = -22, maxZ = -8},
}


local function findMessSpot()
    for attempt = 1, 120 do
        local zone = zones[math.random(1, #zones)]
        local x = zone.minX + math.random() * (zone.maxX - zone.minX)
        local z = zone.minZ + math.random() * (zone.maxZ - zone.minZ)
        local cf = CFrame.new(x, 3.6, z)
        local blocked = workspace:GetPartBoundsInBox(cf, Vector3.new(3, 3.2, 3), overlapParams)
        if #blocked == 0 then
            local hit = workspace:Raycast(Vector3.new(x, 6, z), Vector3.new(0, -8, 0), floorParams)
            if hit then return Vector3.new(x, hit.Position.Y, z), zone.name end
        end
    end
end


local function buildMess(pos)
    local m = Instance.new("Model")
    m.Name = "Mess"
    local function blob(name, size, offset, color, shape, mat)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Shape = shape or Enum.PartType.Block
        p.CFrame = CFrame.new(pos + offset)
        p.Color = color
        p.Material = mat or Enum.Material.SmoothPlastic
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Parent = m
        return p
    end
    local flat = CFrame.Angles(0, 0, math.rad(90))
    local main = blob("Puddle", Vector3.new(0.06, 4.2, 4.2), Vector3.new(0, 0.04, 0), Color3.fromRGB(70, 34, 22), Enum.PartType.Cylinder, Enum.Material.Glass)
    main.CFrame = CFrame.new(pos + Vector3.new(0, 0.04, 0)) * flat
    main.Reflectance = 0.15
    local b = blob("Puddle2", Vector3.new(0.05, 2.6, 2.6), Vector3.new(1.6, 0.05, 0.9), Color3.fromRGB(95, 45, 25), Enum.PartType.Cylinder, Enum.Material.Glass)
    b.CFrame = CFrame.new(pos + Vector3.new(1.6, 0.05, 0.9)) * flat
    local c = blob("Puddle3", Vector3.new(0.05, 1.8, 1.8), Vector3.new(-1.5, 0.05, -1.1), Color3.fromRGB(55, 28, 20), Enum.PartType.Cylinder, Enum.Material.Glass)
    c.CFrame = CFrame.new(pos + Vector3.new(-1.5, 0.05, -1.1)) * flat
    for i = 1, 4 do
        local a = math.random() * math.pi * 2
        local r = 0.8 + math.random() * 1.6
        blob("Trash" .. i, Vector3.new(0.7, 0.55, 0.6), Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), Color3.fromRGB(215, 210, 200), Enum.PartType.Ball)
    end
    local cup = blob("Cup", Vector3.new(0.9, 0.6, 0.6), Vector3.new(-0.3, 0.35, 1.4), Color3.fromRGB(170, 40, 35), Enum.PartType.Cylinder)
    cup.CFrame = CFrame.new(pos + Vector3.new(-0.3, 0.35, 1.4)) * CFrame.Angles(0, math.random() * 3, math.rad(80))
    local pr = Instance.new("ProximityPrompt")
    pr.Name = "MessPrompt"
    pr.ActionText = "Clean up"
    pr.ObjectText = "Mess"
    pr.KeyboardKeyCode = Enum.KeyCode.E
    pr.GamepadKeyCode = Enum.KeyCode.ButtonX
    pr.HoldDuration = 5
    pr.MaxActivationDistance = 7
    pr.RequiresLineOfSight = true
    pr.Style = Enum.ProximityPromptStyle.Custom
    pr.Parent = main
    m.PrimaryPart = main
    m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    m.Parent = workspace
    return m, pr
end


local function startMess()
    local pos, zoneName = findMessSpot()
    if not pos then return false end
    local m, pr = buildMess(pos)
    pr.Triggered:Connect(function()
        if active.mess then endEvent("mess") end
    end)
    register("mess", "clean up the mess in the " .. zoneName, function()
        m:Destroy()
    end, pos + Vector3.new(0, 0.8, 0))
    return true
end

----------------------------------------------------------------- event: line customer
local PROTEIN = {"chicken", "steak", "carnitas", "sofritas"}
local RICE = {"white rice", "brown rice", "no rice"}
local BEANS = {"black beans", "pinto beans", "no beans"}
local TOPPINGS = {"salsa", "cheese", "lettuce", "guac"}
local CONTAINER = {"bowl", "burrito"}
local currentOrder = nil
local lineCustomer = nil


local function makeOrder()
    local tops = shuffle(TOPPINGS)
    return {
        container = CONTAINER[math.random(1, #CONTAINER)],
        protein = PROTEIN[math.random(1, #PROTEIN)],
        rice = RICE[math.random(1, #RICE)],
        beans = BEANS[math.random(1, #BEANS)],
        toppings = {tops[1], tops[2]},
    }
end

local function sameOrder(a, b)
    if type(b) ~= "table" or type(b.toppings) ~= "table" then return false end
    if a.container ~= b.container or a.protein ~= b.protein or a.rice ~= b.rice or a.beans ~= b.beans then return false end
    if #b.toppings ~= #a.toppings then return false end
    for _, t in ipairs(a.toppings) do
        if not table.find(b.toppings, t) then return false end
    end
    return true
end

local linePrompt = props:WaitForChild("LineStation"):WaitForChild("PromptPoint"):WaitForChild("LinePrompt")

local function startLine()
    currentOrder = makeOrder()
    --fades in at the next free place in the queue
    lineCustomer = makeCustomer(queueCF(#lineQueue + 1))
    table.insert(lineQueue, lineCustomer)
    local customer = lineCustomer
    linePrompt.Enabled = true
    playSoundAt(props.LineStation, DING, 0.5, 1.4)
    register("line", "help the customer at the line", function()
        linePrompt.Enabled = false
        currentOrder = nil
        removeCustomer(customer)
    end, linePrompt.Parent.WorldPosition)
end

linePrompt.Triggered:Connect(function(player)
    if active.line and currentOrder then
        ev:FireClient(player, "order", currentOrder)
    end
end)

----------------------------------------------------------------- event: dml window
local windowPrompt = hallway:WaitForChild("WindowHandle"):WaitForChild("PromptPoint"):WaitForChild("WindowPrompt")
local paneRight = nil
local paneLeft = nil
local paper = hallway:WaitForChild("WindowPaper")
for _, p in ipairs(hallway:GetChildren()) do
    if p.Name == "WindowGlass" then
        if p.Position.X > -36 then paneRight = p else paneLeft = p end
    end
end
local paneClosed = paneRight.CFrame
local paperClosed = paper.CFrame
local windowCustomer = nil
local windowStage = "closed"
local outsideLight = props:WaitForChild("WindowOutsideLight").Glow


local function slideWindow(open)
    local dx = paneLeft.Position.X - paneRight.Position.X
    local target = open and (paneClosed * CFrame.new(-dx * -1, 0, 0)) or paneClosed
    if open then
        --the right pane slides behind the left one
        target = paneClosed + Vector3.new(paneLeft.Position.X - paneClosed.Position.X, 0, -0.3)
        TweenService:Create(paper, TweenInfo.new(0.9), {CFrame = paperClosed + Vector3.new(paneLeft.Position.X - paneClosed.Position.X, 0, -0.3)}):Play()
    else
        TweenService:Create(paper, TweenInfo.new(0.9), {CFrame = paperClosed}):Play()
    end
    TweenService:Create(paneRight, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {CFrame = target}):Play()
end

--the pickup window is a drive up: a car rolls along the back lane and stops with the driver at the glass
local CAR_SCALE = 0.85
--where the car stops, facing west with the driver side against the window
local CAR_STOP = CFrame.new(-37.3, 3, -43.8) * CFrame.Angles(0, math.rad(90), 0)
--route in from the east end of the lane, and away to the west
local CAR_IN = {Vector3.new(70, 3, -52.5), Vector3.new(-14, 3, -52.5), Vector3.new(-27, 3, -49.5)}
local CAR_OUT = {Vector3.new(-60, 3, -51.5), Vector3.new(-110, 3, -55.5)}



local function makePickupCar()
    local src = map:FindFirstChild("PlayerCar")
    if not src then return nil end
    local car = src:Clone()
    car.Name = "PickupCar"
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false end
    end
    car:ScaleTo(CAR_SCALE)
    car.Parent = workspace
    return car
end



--drives the car through the points, then eases into the final frame, carrying the driver along
local function driveCar(car, driver, points, final, speed)
    local driverOff = CFrame.new(-1.36, 0.7, 1.15) * CFrame.Angles(0, math.rad(90), 0)
    local pos = car:GetPivot()
    local list = {}
    for _, p in ipairs(points) do table.insert(list, p) end
    if final then table.insert(list, final.Position) end
    for i, goal in ipairs(list) do
        local from = pos.Position
        local dist = (goal - from).Magnitude
        local t = dist / speed
        local last = (i == #list and final ~= nil)
        local fromRot = pos.Rotation
        local dir = (goal - from) * Vector3.new(1, 0, 1)
        local toRot = last and final.Rotation or (dir.Magnitude > 0.1 and CFrame.lookAt(Vector3.zero, dir).Rotation or fromRot)
        local t0 = os.clock()
        while true do
            local a = math.clamp((os.clock() - t0) / math.max(t, 0.05), 0, 1)
            local e = last and TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) or a
            local cf = CFrame.new(from:Lerp(goal, e)) * fromRot:Lerp(toRot, math.min(1, a * 2))
            if car.Parent then car:PivotTo(cf) end
            if driver and driver.Parent then driver:PivotTo(cf * driverOff) end
            pos = cf
            if a >= 1 then break end
            task.wait()
        end
    end
end


local function startWindow()
    local car = makePickupCar()
    local startCF = CFrame.new(CAR_IN[1]) * CFrame.Angles(0, math.rad(90), 0)
    if car then car:PivotTo(startCF) end
    windowCustomer = makeCustomer(startCF * CFrame.new(-1.36, 0.7, 1.15) * CFrame.Angles(0, math.rad(90), 0))
    local customer = windowCustomer
    fadeCustomer(customer, 0, 0.1)
    task.spawn(function()
        if car then driveCar(car, customer, {CAR_IN[2], CAR_IN[3]}, CAR_STOP, 22) end
    end)
    windowStage = "closed"
    windowPrompt.ActionText = "Open window"
    windowPrompt.Enabled = true
    outsideLight.Brightness = 1.2
    playSoundAt(hallway.WindowHandle, DING, 0.5, 1.1)
    register("window", "get the dml window", function()
        windowPrompt.Enabled = false
        outsideLight.Brightness = 0
        windowStage = "closed"
        slideWindow(false)
        --pulls away down the lane and is gone
        task.spawn(function()
            if car and car.Parent then
                driveCar(car, customer, CAR_OUT, nil, 24)
                car:Destroy()
            end
            if customer and customer.Parent then customer:Destroy() end
        end)
    end, windowPrompt.Parent.WorldPosition)
end

windowPrompt.Triggered:Connect(function()
    if not active.window then return end
    if windowStage == "closed" then
        windowStage = "open"
        slideWindow(true)
        windowPrompt.ActionText = "Hand over order"
        playSoundAt(hallway.WindowHandle, CLICK, 0.8, 1.3)
    elseif windowStage == "open" then
        windowStage = "done"
        windowPrompt.Enabled = false
        --a paper bag slides out to the customer
        local bag = Instance.new("Part")
        bag.Name = "Bag"
        bag.Size = Vector3.new(1, 1.3, 0.7)
        bag.Color = Color3.fromRGB(150, 115, 75)
        bag.Material = Enum.Material.SmoothPlastic
        bag.Anchored = true
        bag.CanCollide = false
        bag.CFrame = CFrame.new(-35, 4.9, -38.9)
        bag.Parent = workspace
        --into the driver's hand through the car window
        local t = TweenService:Create(bag, TweenInfo.new(1, Enum.EasingStyle.Sine), {Position = Vector3.new(-36, 4.4, -41.1)})
        t:Play()
        t.Completed:Wait()
        bag:Destroy()
        if active.window then endEvent("window") end
    end
end)

----------------------------------------------------------------- event: phone
local phonePrompt = phone.Base.PromptPoint.PhonePrompt
local ringGlow = phone.RingLight.RingGlow
local scripts = {
    {
        "yeah hi. i have been on hold for twenty minutes.",
        "i ordered a burrito. a BURRITO. and you gave me a bowl.",
        "there was no guac either. i paid extra. i always pay extra.",
        "your cashier laughed at me. i heard her through the bag.",
        "i want a manager. i want a refund. i want my evening back.",
        "...hello? are you even listening to me?",
        "whatever. never coming back. enjoy your night.",
    },
    {
        "is this the chipotle on pullman? finally.",
        "my order was wrong. the rice was cold and the chicken was gray.",
        "i drove all the way back and the doors were locked. locked!",
        "the lights were off inside. i saw someone standing in there.",
        "i don't care who it was. i want my money back.",
        "hello? hello?? you're breathing weird. stop that.",
        "fine. i'll see you in the morning. i'll be watching.",
    },
}
local ringToken = 0



local function startPhone()
    ringToken += 1
    local mine = ringToken
    phone.Base.Ring:Play()
    --a steady soft light while it rings, no flashing
    task.spawn(function()
        ringGlow.Brightness = 1
        phone.RingLight.Color = Color3.fromRGB(255, 210, 150)
        while active.phone and ringToken == mine and not phonePrompt:GetAttribute("Answered") do
            task.wait(0.2)
        end
        ringGlow.Brightness = 0
        phone.RingLight.Color = Color3.fromRGB(40, 36, 30)
    end)
    phonePrompt:SetAttribute("Answered", false)
    phonePrompt.Enabled = true
    broadcast("ring")
    register("phone", "the office phone is ringing", function()
        ringToken += 1
        phone.Base.Ring:Stop()
        phonePrompt.Enabled = false
        broadcast("ringStop")
    end)
end

----------------------------------------------------------------- night 1: the manager's call
--not a job, nothing is lost by missing it, it just explains the shift while it plays
local TUTORIAL = {
    "hey, it's your manager. first night? alright, keep me on speaker, i'll talk you through it.",
    "sit back down in the chair. those are the security cameras, you'll be on them most of the night.",
    "flip between cameras with a and d, or tap the cameras on the map.",
    "something walks around out there at night. if you see it on a camera, flash it. press f or hit flash.",
    "the flash only works while it's still outside. once it's in the building, it does nothing.",
    "watch the power bar. watching drains it, flashing drains more. step away from the desk and it charges back.",
    "jobs pop up on your screen. you get about thirty seconds each, so go do them, then get back here.",
    "if it ever gets in, get off the cameras, shut the office door and stay quiet till it leaves.",
    "that's it. make it to 5 am. good luck. i mean it.",
}
local tutorialRinging = false


local function startTutorialCall()
    if active.phone then return end
    tutorialRinging = true
    ringToken += 1
    local mine = ringToken
    phone.Base.Ring:Play()
    phonePrompt:SetAttribute("Answered", false)
    phonePrompt.Enabled = true
    broadcast("ring")
    task.spawn(function()
        local t0 = os.clock()
        ringGlow.Brightness = 1
        phone.RingLight.Color = Color3.fromRGB(255, 210, 150)
        while tutorialRinging and ringToken == mine and os.clock() - t0 < 25 do
            task.wait(0.2)
        end
        --nobody picked up, so it goes to the answering machine and plays anyway
        if tutorialRinging and ringToken == mine then
            tutorialRinging = false
            phone.Base.Ring:Stop()
            phonePrompt.Enabled = false
            broadcast("ringStop")
            if night.running then
                broadcast("call", TUTORIAL, {caller = "MANAGER  (voicemail)", tutorial = true})
            end
        end
        ringGlow.Brightness = 0
        phone.RingLight.Color = Color3.fromRGB(40, 36, 30)
    end)
end


--picking up, either at the phone itself or from the popup on screen
local function answerCall(player)
    if tutorialRinging then
        tutorialRinging = false
        phonePrompt.Enabled = false
        phone.Base.Ring:Stop()
        broadcast("ringStop")
        --on speaker, so everyone on the shift hears it
        broadcast("call", TUTORIAL, {caller = "MANAGER  (on speaker)", tutorial = true})
        return
    end
    if not active.phone or phonePrompt:GetAttribute("Answered") then return end
    phonePrompt:SetAttribute("Answered", true)
    phonePrompt.Enabled = false
    phone.Base.Ring:Stop()
    broadcast("ringStop")
    ev:FireClient(player, "call", scripts[math.random(1, #scripts)])
end
phonePrompt.Triggered:Connect(answerCall)

--turning it down: the manager just hangs up, a customer counts as hung up on
local function declineCall()
    if tutorialRinging then
        tutorialRinging = false
        ringToken += 1
        phonePrompt.Enabled = false
        phone.Base.Ring:Stop()
        broadcast("ringStop")
        return
    end
    if active.phone and not phonePrompt:GetAttribute("Answered") then
        failEvent("phone", "you hung up on a customer")
    end
end

--a hunt cuts the call off, the phone can be picked up again once it is over
workspace:GetAttributeChangedSignal("Hunting"):Connect(function()
    if workspace:GetAttribute("Hunting") and active.phone and phonePrompt:GetAttribute("Answered") then
        phonePrompt:SetAttribute("Answered", false)
        phonePrompt.Enabled = true
    end
    --once it has left, a call that was cut off rings on screen again
    if not workspace:GetAttribute("Hunting") and active.phone and not phonePrompt:GetAttribute("Answered") then
        broadcast("ring")
    end
end)

----------------------------------------------------------------- event: vape in the walk in
local WALKIN_MIN = Vector3.new(3.5, -5, -25.5)
local WALKIN_MAX = Vector3.new(18.5, 20, -13.9)
local vapeSpot = props:WaitForChild("VapeSpot")
local vapePrompt = vapeSpot:WaitForChild("PromptPoint"):WaitForChild("VapePrompt")
--when each player started their hit, so the job only counts once the animation has really played
local vaping = {}



local function inWalkIn(player)
    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    local p = r.Position
    return p.X > WALKIN_MIN.X and p.X < WALKIN_MAX.X and p.Z > WALKIN_MIN.Z and p.Z < WALKIN_MAX.Z
end

--the vape is not a little prompt any more, anywhere inside the walk-in works and it can be hit as often as they like
vapePrompt.Enabled = false


local function startVape()
    register("vape", "take a vape hit in the walk-in", function() end, vapeSpot.PromptPoint.WorldPosition)
end


local function requestVape(player)
    if not inWalkIn(player) then return end
    --one hit at a time, a stuck one frees itself after a few seconds
    if vaping[player] and os.clock() - vaping[player] < 8 then return end
    vaping[player] = os.clock()
    ev:FireClient(player, "vape")
end

----------------------------------------------------------------- difficulty vote


local function voteCounts()
    local counts = {Easy = 0, Normal = 0, Hard = 0}
    for _, d in pairs(vote.choices) do counts[d] += 1 end
    return counts
end

--most votes wins, a tie is picked at random between the tied ones
local function decideVote()
    if vote.decided then return end
    local counts = voteCounts()
    local best = 0
    local top = {}
    for _, name in ipairs({"Easy", "Normal", "Hard"}) do
        if counts[name] > best then
            best = counts[name]
            top = {name}
        elseif counts[name] == best and best > 0 then
            table.insert(top, name)
        end
    end
    if #top == 0 then top = {"Normal"} end
    local pick = top[math.random(1, #top)]
    vote.decided = pick
    vote.deadline = nil
    difficulty = pick
    if not night.running then workspace:SetAttribute("Difficulty", pick) end
    broadcast("voteResult", pick)
end


--shows everyone the votes so far, and ends early once every player in the server has voted
local function voteChanged()
    local left = vote.deadline and math.max(0, vote.deadline - os.clock()) or VOTE_TIME
    broadcast("voteState", voteCounts(), left, VOTE_TIME)
    local all = true
    for _, p in ipairs(Players:GetPlayers()) do
        if not vote.choices[p] then all = false end
    end
    if all then decideVote() end
end

local function castVote(player, choice)
    if choice ~= "Easy" and choice ~= "Normal" and choice ~= "Hard" then return end
    --already settled for this night, this player just goes along with it
    if vote.decided then
        ev:FireClient(player, "voteResult", vote.decided)
        return
    end
    vote.choices[player] = choice
    --the first vote starts the countdown
    if not vote.deadline then
        vote.deadline = os.clock() + VOTE_TIME
        local mine = vote.deadline
        task.delay(VOTE_TIME, function()
            if vote.deadline == mine then decideVote() end
        end)
    end
    voteChanged()
end

Players.PlayerRemoving:Connect(function(p)
    if vote.choices[p] then
        vote.choices[p] = nil
        if not vote.decided then voteChanged() end
    end
end)

----------------------------------------------------------------- client results
ev.OnServerEvent:Connect(function(player, kind, data)
    if kind == "voteDifficulty" then
        castVote(player, data)
    elseif kind == "difficulty" then
        --picked on the select screen, used from the next night on
        if data == "Easy" or data == "Normal" or data == "Hard" then
            difficulty = data
            if not night.running then workspace:SetAttribute("Difficulty", difficulty) end
        end
    elseif kind == "vapeRequest" then
        requestVape(player)
    elseif kind == "vapeDone" then
        --the whole pull and exhale has to have played out
        if active.vape and vaping[player] and os.clock() - vaping[player] >= 3.5 then endEvent("vape") end
        vaping[player] = nil
    elseif kind == "vapeCancel" then
        vaping[player] = nil
    elseif kind == "wiresDone" then
        if active.lights then endEvent("lights") end
    elseif kind == "orderSubmit" then
        if active.line and currentOrder then
            if sameOrder(currentOrder, data) then
                endEvent("line")
            else
                ev:FireClient(player, "orderWrong")
            end
        end
    elseif kind == "acceptCall" then
        if not workspace:GetAttribute("Hunting") then answerCall(player) end
    elseif kind == "declineCall" then
        declineCall()
    elseif kind == "callDone" then
        if active.phone then endEvent("phone") end
    elseif kind == "callDropped" then
        if active.phone and not workspace:GetAttribute("Hunting") then failEvent("phone", "you hung up on a customer") end
    end
end)

----------------------------------------------------------------- the night
----------------------------------------------------------------- event: take out the garbage
local trashBin = props:WaitForChild("TrashBin")
local trashPrompt = trashBin:WaitForChild("Can"):WaitForChild("PromptPoint"):WaitForChild("TrashPrompt")
local fullBag = {trashBin:WaitForChild("FullBag"), trashBin:WaitForChild("BagKnot")}
local dumpsterPrompts = {}
for _, d in ipairs(map:WaitForChild("DumpsterArea"):GetChildren()) do
    if d.Name == "Dumpster" then
        local p = d.PrimaryPart:WaitForChild("PromptPoint"):WaitForChild("DumpsterPrompt")
        table.insert(dumpsterPrompts, p)
    end
end
local DUMPSTER_POS = Vector3.new(124, 5, 77)
local carrying = {}




local function setBagVisible(on)
    for _, p in ipairs(fullBag) do p.Transparency = on and 0 or 1 end
end



local function startGarbage()
    carrying = {}
    setBagVisible(true)
    trashPrompt.Enabled = true
    for _, p in ipairs(dumpsterPrompts) do p.Enabled = false end
    register("garbage", "take out the garbage", function()
        trashPrompt.Enabled = false
        for _, p in ipairs(dumpsterPrompts) do p.Enabled = false end
        for plr in pairs(carrying) do
            if plr.Parent then plr:SetAttribute("CarryingTrash", false) end
            ev:FireClient(plr, "garbageDrop")
        end
        carrying = {}
        setBagVisible(true)
    end, trashPrompt.Parent.WorldPosition)
end

trashPrompt.Triggered:Connect(function(player)
    if not active.garbage or carrying[player] then return end
    carrying[player] = true
    player:SetAttribute("CarryingTrash", true)
    trashPrompt.Enabled = false
    setBagVisible(false)
    ev:FireClient(player, "garbagePickup")
    --the marker moves on to the dumpsters
    workspace:SetAttribute("TaskPos_garbage", DUMPSTER_POS)
    for _, p in ipairs(dumpsterPrompts) do p.Enabled = true end
end)

for _, dp in ipairs(dumpsterPrompts) do
    dp.Triggered:Connect(function(player)
        if not active.garbage or not carrying[player] then return end
        carrying[player] = nil
        for _, p in ipairs(dumpsterPrompts) do p.Enabled = false end
        ev:FireClient(player, "garbageDump")
        playSoundAt(dp.Parent.Parent, "rbxassetid://9126254743", 0.9, 0.7)
        --the job only counts once the bag is over the lip and gone
        task.delay(1.1, function()
            player:SetAttribute("CarryingTrash", false)
            if active.garbage then endEvent("garbage") end
        end)
    end)
end

local starters = {lights = startLightsOut, mess = startMess, line = startLine, window = startWindow, phone = startPhone, vape = startVape, garbage = startGarbage}


--starts the job for one objective, false if it could not be placed yet
local function triggerEvent(o)
    if active[o.cat] then return false end
    night.current[o.cat] = o
    local ok = starters[o.cat]()
    if ok == false then
        o.status = "pending"
        return false
    end
    return true
end


--how many of each job a night holds and when each one comes in
local function buildPlan()
    --every player on the shift brings their own share, anyone can do any of them
    local players = math.clamp(#Players:GetPlayers(), 1, 4)
    workspace:SetAttribute("ShiftPlayers", players)
    local per = (difficulty == "Easy" and 2) or (difficulty == "Hard" and 8) or PER_NIGHT
    --nights 3 and 5 each add one more job
    local nightNum = workspace:GetAttribute("NightNumber") or 1
    if nightNum >= 3 then per += 1 end
    if nightNum >= 5 then per += 1 end
    local total = per * players
    local cats = {}
    --dealt out in shuffled rounds so the same job never comes twice in a row
    while #cats < total do
        local round = shuffle(CORE)
        if #cats > 0 and round[1] == cats[#cats] then round[1], round[#round] = round[#round], round[1] end
        for _, c in ipairs(round) do
            if #cats < total then table.insert(cats, c) end
        end
    end
    --spread from the start of the shift to the last minute, about one a minute for one player on normal
    --night 1 leaves the first minute free for the manager's call
    local first = nightNum == 1 and 55 or 8
    local window = NIGHT_LENGTH - 40 - first
    local gap = window / total
    local times = {}
    for i = 1, total do
        --each one drifts up to almost half a gap either way so they never land on a steady beat
        local drift = (math.random() * 2 - 1) * gap * 0.45
        table.insert(times, math.max(first, first + (i - 1) * gap + gap * 0.3 + drift))
    end
    table.sort(times)
    workspace:SetAttribute("MissedTasks", 0)
    night.objectives = {}
    night.queue = {}
    for i, c in ipairs(cats) do
        local o = {cat = c, status = "pending"}
        table.insert(night.objectives, o)
        table.insert(night.queue, {at = times[i], objective = o})
    end
    publishObjectives()
end


--every job handed out tonight has to have been done once by 5 am, a made up retry counts
local function requirementsMet()
    local done = {}
    local need = {}
    for _, o in ipairs(night.objectives) do
        if o.status == "done" then done[o.cat] = (done[o.cat] or 0) + 1 end
        --a job the clock never got round to handing out is not held against the shift
        if not o.retry and o.status ~= "pending" then need[o.cat] = (need[o.cat] or 0) + 1 end
    end
    for cat, n in pairs(need) do
        if (done[cat] or 0) < n then return false end
    end
    return true
end




local function startNight()
    if night.running then return end
    night.running = true
    night.id += 1
    night.strikes = 0
    night.missed = 0
    night.failing = false
    night.failReason = nil
    night.current = {}
    local id = night.id
    resetWorld()
    workspace:SetAttribute("JobFailed", false)
    workspace:SetAttribute("ForceHunt", false)
    workspace:SetAttribute("TasksActive", 0)
    workspace:SetAttribute("Difficulty", difficulty)
    workspace:SetAttribute("NightNumber", shiftNight())
    buildPlan()
    workspace:SetAttribute("NightStart", workspace:GetServerTimeNow())
    workspace:SetAttribute("NightActive", true)
    broadcast("start", difficulty, workspace:GetAttribute("NightNumber"))
    --night 1: the manager calls a few seconds in and talks them through the shift
    if workspace:GetAttribute("NightNumber") == 1 then
        task.delay(4, function()
            if night.id == id and night.running then startTutorialCall() end
        end)
    end
    task.spawn(function()
        local start = workspace:GetAttribute("NightStart")
        local nextHour = 1
        while true do
            task.wait(0.25)
            if night.id ~= id or not night.running then return end
            local now = workspace:GetServerTimeNow() - start
            if nextHour < LAST_HOUR and now >= nextHour * HOUR_SECONDS then
                broadcast("hour", nextHour)
                nextHour += 1
            end
            if now >= NIGHT_LENGTH then
                if night.failing then return end
                broadcast("hour", LAST_HOUR)
                if requirementsMet() then
                    endNight(true)
                else
                    failNight("you didn't finish your tasks")
                end
                return
            end
            --jobs come in on time, never while it is hunting or breaking in and never two of the same at once
            local monsterState = workspace:GetAttribute("MonsterState")
            local breakingIn = monsterState == "breakin" or monsterState == "forcedEntry"
            if not night.failing and not workspace:GetAttribute("Hunting") and not breakingIn then
                table.sort(night.queue, function(a, b) return a.at < b.at end)
                for i, q in ipairs(night.queue) do
                    if q.at <= now and not active[q.objective.cat] then
                        if triggerEvent(q.objective) then
                            table.remove(night.queue, i)
                        else
                            q.at = now + 2
                        end
                        break
                    end
                end
            end
        end
    end)
end

chairPrompt.Triggered:Connect(function(player)
    --the shift only starts once they have clocked in
    if not player:GetAttribute("ClockedIn") then return end
    --everyone on the shift has to have clocked in first
    for _, p in ipairs(Players:GetPlayers()) do
        if not p:GetAttribute("ClockedIn") then
            ev:FireClient(player, "waitTeam")
            return
        end
    end
    startNight()
end)



--the monster reaching the office ends the night
workspace:GetAttributeChangedSignal("NightForceFail"):Connect(function()
    if workspace:GetAttribute("NightForceFail") and night.running then endNight(false) end
end)
