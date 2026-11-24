--swings doors on this client when their Open attribute flips and draws the soft hold e prompt
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local OPEN_TIME = 1.1
local CLOSE_TIME = 0.95
local DOOR_SOUND = "rbxassetid://9114142431"
--the hit is at the very start of this clip, the old one swelled for half a second before the bang
local SLAM_SOUND = "rbxassetid://101275852749396"

local doors = {}


local function inCutscene()
    return player:GetAttribute("InCutscene") == true
end

---------------------------------------------------------------- door motion


--puts every part of the door at the given swing angle
local function pose(info, angle)
    if info.entry then
        local cf = CFrame.new(info.hinge) * CFrame.Angles(0, math.rad(info.closed + angle), 0) * CFrame.new(1.5, 0, 0)
        info.slab.CFrame = cf
        for _, item in ipairs(info.parts) do item.part.CFrame = cf * item.off end
    else
        local cf = info.hingeCF * CFrame.Angles(0, math.rad(angle), 0)
        for _, item in ipairs(info.parts) do item.part.CFrame = cf * item.base end
    end
end

local function makeSound(parent)
    local snd = Instance.new("Sound")
    snd.Name = "DoorSound"
    snd.SoundId = DOOR_SOUND
    snd.Volume = 0.22
    snd.RollOffMaxDistance = 45
    snd.RollOffMinDistance = 6
    snd.Parent = parent
    return snd
end


local function playSoft(info)
    info.sound.PlaybackSpeed = 0.94 + math.random() * 0.08
    info.sound.TimePosition = 0
    info.sound:Play()
end




--heavy hit for doors that get slammed
local function playSlam(info)
    if not info.slamSound then
        local snd = Instance.new("Sound")
        snd.Name = "DoorSlam"
        snd.SoundId = SLAM_SOUND
        snd.Volume = 1.1
        snd.RollOffMinDistance = 10
        snd.RollOffMaxDistance = 90
        snd.Parent = info.sound.Parent
        info.slamSound = snd
    end
    info.slamSound.PlaybackSpeed = 0.96 + math.random() * 0.06
    info.slamSound.TimePosition = 0
    info.slamSound:Play()
end


--the door goes ghost while it swings so it never shoves the player, then turns solid again
local function setCollide(info, on)
    if not info.collide then
        info.collide = {}
        if info.slab then info.collide[info.slab] = info.slab.CanCollide end
        for _, item in ipairs(info.parts) do info.collide[item.part] = item.part.CanCollide end
    end
    for part, orig in pairs(info.collide) do
        if on then part.CanCollide = orig else part.CanCollide = false end
    end
end




local function animate(info, open)
    info.from = info.angle
    info.to = open and info.openAngle or 0
    info.t0 = os.clock()
    --the monster sets OpenTime for a slow forced open and Slam for a hard close
    local custom = open and info.door:GetAttribute("OpenTime") or nil
    info.duration = custom or (open and OPEN_TIME or CLOSE_TIME)
    info.slow = custom ~= nil
    info.slam = (not open) and info.door:GetAttribute("Slam") == true
    if info.slam then info.duration = 0.38 end
    info.opening = open
    info.latched = false
    setCollide(info, false)
    --the push sound plays as the door starts moving
    if open and not info.slow then playSoft(info) end
end




local function addDoor(door)
    if doors[door] then return end
    local info = {door = door, angle = 0, parts = {}, seed = math.random() * 100}
    if door:GetAttribute("DoorKind") == "Entry" then
        --front doors share the hinge math the intro uses
        local key = string.sub(door.Name, -1)
        info.entry = true
        info.slab = door
        info.hinge = door:GetAttribute("Hinge")
        info.closed = door:GetAttribute("ClosedAngle")
        info.openAngle = -info.closed
        --wait for every streamed piece of the door
        local need = door:GetAttribute("GroupCount") or 0
        local t0 = os.clock()
        repeat
            info.parts = {}
            for _, p in ipairs(door.Parent:GetChildren()) do
                if p:GetAttribute("DoorGroup") == key then table.insert(info.parts, {part = p, off = p:GetAttribute("DoorOffset")}) end
            end
            if #info.parts < need then task.wait(0.2) end
        until #info.parts >= need or os.clock() - t0 > 15
        info.sound = makeSound(door)
    else
        while not door.PrimaryPart do task.wait(0.1) end
        info.hingeCF = CFrame.new(door:GetAttribute("Hinge"))
        info.openAngle = door:GetAttribute("OpenAngle") or 90
        for _, p in ipairs(door:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(info.parts, {part = p, base = info.hingeCF:ToObjectSpace(p.CFrame)}) end
        end
        info.sound = makeSound(door.PrimaryPart)
    end
    doors[door] = info
    --someone may have opened it before this player joined
    if door:GetAttribute("Open") and not (info.entry and inCutscene()) then
        info.angle = info.openAngle
        pose(info, info.angle)
    end
    door:GetAttributeChangedSignal("Open"):Connect(function()
        if info.entry and inCutscene() then return end
        --the broom barricade comes out of the handles the moment a front door is opened
        if info.entry and door:GetAttribute("Open") then
            local broom = workspace:FindFirstChild("ChipotleMap") and workspace.ChipotleMap:FindFirstChild("Broom")
            local ok, path = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("IntroBroomPath"))
            if broom and ok then broom:PivotTo(path.lean) end
        end
        animate(info, door:GetAttribute("Open"))
    end)
    --the slam flag can arrive a frame after the close started, so a closing door is turned into a slam from where it is
    door:GetAttributeChangedSignal("Slam"):Connect(function()
        if door:GetAttribute("Slam") == true and info.t0 and not info.opening and not info.slam and not info.latched then
            info.from = info.angle
            info.t0 = os.clock()
            info.slam = true
            info.duration = 0.38
        end
    end)
end

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for _, info in pairs(doors) do
        if info.t0 then
            local a = math.clamp((now - info.t0) / info.duration, 0, 1)
            local e
            if info.opening and info.slow then
                e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            elseif info.opening then
                e = TweenService:GetValue(a, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            elseif info.slam then
                --speeds up right into the frame
                e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            else
                e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            end
            info.angle = info.from + (info.to - info.from) * e
            pose(info, info.angle)
            --the click or slam plays on the exact frame the door is drawn against the jamb, never while it is still swinging
            if not info.opening and not info.latched and a >= 1 then
                info.latched = true
                if info.slam then
                    playSlam(info)
                    info.shudder = now
                else
                    playSoft(info)
                end
            end
            if a >= 1 then
                info.t0 = nil
                setCollide(info, true)
            end
        end
        --a slammed door bounces off the jamb and shudders shut
        if info.shudder and not info.t0 then
            local s = now - info.shudder
            if s < 0.5 then
                local dir = info.openAngle >= 0 and 1 or -1
                pose(info, info.angle + dir * math.abs(math.sin(s * 34)) * 3.2 * math.exp(-s * 9))
            else
                info.shudder = nil
                pose(info, info.angle)
            end
        end
        --something forcing it: the door shakes in its frame, harder as Rattle goes up
        local r = info.door:GetAttribute("Rattle") or 0
        if not info.t0 and not info.shudder and not (info.entry and inCutscene()) then
            if r > 0 then
                info.rattling = true
                local j = (math.noise(now * 23, info.seed) * 2.6 + math.sin(now * 38 + info.seed) * 0.7) * r
                pose(info, info.angle + j)
            elseif info.rattling then
                info.rattling = false
                pose(info, info.angle)
            end
        end
    end
end)

for _, door in ipairs(CollectionService:GetTagged("InteractDoor")) do
    if door:IsDescendantOf(workspace) then task.spawn(addDoor, door) end
end
CollectionService:GetInstanceAddedSignal("InteractDoor"):Connect(addDoor)
--locked outside doors only the monster can open
for _, door in ipairs(CollectionService:GetTagged("MonsterDoor")) do task.spawn(addDoor, door) end
CollectionService:GetInstanceAddedSignal("MonsterDoor"):Connect(addDoor)

---------------------------------------------------------------- front door prompts stay off during the intro


local function refreshEntryPrompts()
    for door, info in pairs(doors) do
        if info.entry then
            local prompt = door:FindFirstChild("DoorPrompt")
            if prompt then prompt.Enabled = not inCutscene() end
        end
    end
end
player:GetAttributeChangedSignal("InCutscene"):Connect(function()
    refreshEntryPrompts()
    --snap the front doors to their real state once the intro lets go
    if not inCutscene() then
        for door, info in pairs(doors) do
            if info.entry then
                info.angle = door:GetAttribute("Open") and info.openAngle or 0
                pose(info, info.angle)
            end
        end
    end
end)
task.spawn(function()
    while true do refreshEntryPrompts() task.wait(1) end
end)

---------------------------------------------------------------- soft custom prompt

--billboards only draw from a plain folder in playergui, not inside a screengui
--playergui gets wiped when the character is swapped, so the folder is remade whenever it is missing
local function promptFolder()
    local pg = player:WaitForChild("PlayerGui")
    local f = pg:FindFirstChild("DoorPrompts")
    if not f then
        f = Instance.new("Folder")
        f.Name = "DoorPrompts"
        f.Parent = pg
    end
    return f
end


--no prompts at all while a cutscene or the camera monitor has the screen
local function refreshPromptService()
    ProximityPromptService.Enabled = not inCutscene()
end
player:GetAttributeChangedSignal("InCutscene"):Connect(refreshPromptService)
refreshPromptService()


local function keyLabel(prompt, inputType)
    if inputType == Enum.ProximityPromptInputType.Gamepad then
        return string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
    elseif inputType == Enum.ProximityPromptInputType.Touch then
        return "TAP"
    end
    return prompt.KeyboardKeyCode.Name
end


local function round(obj, r)
    local c = Instance.new("UICorner") c.CornerRadius = r c.Parent = obj
end


local function buildPrompt(prompt, inputType)
    local bb = Instance.new("BillboardGui")
    bb.Name = "Prompt"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(206, 62)
    bb.LightInfluence = 0
    bb.Active = true
    bb.Adornee = prompt.Parent
    bb.Parent = promptFolder()

    local scale = Instance.new("UIScale") scale.Scale = 0.86 scale.Parent = bb

    --the pill is a button so touch and mouse can hold it too
    local pill = Instance.new("TextButton")
    pill.Text = "" pill.AutoButtonColor = false
    pill.AnchorPoint = Vector2.new(0.5, 0.5) pill.Position = UDim2.fromScale(0.5, 0.5) pill.Size = UDim2.fromOffset(182, 48)
    pill.BackgroundColor3 = Color3.fromRGB(24, 23, 22) pill.BackgroundTransparency = 1
    pill.Parent = bb
    round(pill, UDim.new(1, 0))
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 244, 228) stroke.Thickness = 1 stroke.Transparency = 1 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border stroke.Parent = pill
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 165, 158))
    grad.Rotation = 90 grad.Parent = pill

    --soft glow behind the pill
    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5) glow.Position = UDim2.fromScale(0.5, 0.5) glow.Size = UDim2.fromOffset(198, 62)
    glow.BackgroundColor3 = Color3.fromRGB(255, 236, 210) glow.BackgroundTransparency = 1 glow.ZIndex = 0
    glow.Parent = bb
    round(glow, UDim.new(1, 0))

    local key = Instance.new("Frame")
    key.AnchorPoint = Vector2.new(0, 0.5) key.Position = UDim2.new(0, 6, 0.5, 0) key.Size = UDim2.fromOffset(32, 32)
    key.BackgroundColor3 = Color3.fromRGB(250, 246, 240) key.BackgroundTransparency = 1
    key.Parent = pill
    round(key, UDim.new(1, 0))
    local keyText = Instance.new("TextLabel")
    keyText.BackgroundTransparency = 1 keyText.Size = UDim2.fromScale(1, 1)
    keyText.Font = Enum.Font.GothamBold keyText.TextSize = 15 keyText.TextColor3 = Color3.fromRGB(40, 36, 32) keyText.TextTransparency = 1
    keyText.Text = keyLabel(prompt, inputType)
    keyText.Parent = key

    --small line naming the thing, then the action under it
    local object = Instance.new("TextLabel")
    object.BackgroundTransparency = 1 object.Position = UDim2.fromOffset(48, 7) object.Size = UDim2.new(1, -58, 0, 13)
    object.Font = Enum.Font.GothamBold object.TextSize = 11 object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextColor3 = Color3.fromRGB(210, 202, 190) object.TextTransparency = 1
    object.Text = string.upper(prompt.ObjectText)
    object.Parent = pill
    local action = Instance.new("TextLabel")
    action.BackgroundTransparency = 1 action.Size = UDim2.new(1, -58, 0, 18)
    action.Font = Enum.Font.GothamMedium action.TextSize = 16 action.TextXAlignment = Enum.TextXAlignment.Left
    action.TextColor3 = Color3.fromRGB(246, 240, 232) action.TextTransparency = 1
    --one tap prompts like the office door just say what they do
    local function actionText()
        if prompt.HoldDuration <= 0 then return prompt.ActionText end
        return "Hold to " .. string.lower(prompt.ActionText)
    end
    action.Text = actionText()
    action.Parent = pill
    --without an object name the action sits in the middle
    local function layoutText()
        object.Text = string.upper(prompt.ObjectText)
        if prompt.ObjectText == "" then
            action.Position = UDim2.new(0, 48, 0.5, -11)
        else
            action.Position = UDim2.fromOffset(48, 19)
        end
    end
    layoutText()

    --thin fill line that grows while the key is held
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0, 1) track.Position = UDim2.new(0, 48, 1, -8) track.Size = UDim2.new(1, -66, 0, 3)
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255) track.BackgroundTransparency = 1
    track.Parent = pill
    round(track, UDim.new(1, 0))
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1) fill.BackgroundColor3 = Color3.fromRGB(255, 226, 190) fill.BackgroundTransparency = 1
    fill.Parent = track
    round(fill, UDim.new(1, 0))

    --some prompts only show the key itself, no words
    if prompt:GetAttribute("KeyOnly") then
        pill.Size = UDim2.fromOffset(46, 46)
        key.AnchorPoint = Vector2.new(0.5, 0.5)
        key.Position = UDim2.fromScale(0.5, 0.5)
        object.Visible = false
        action.Visible = false
        track.AnchorPoint = Vector2.new(0.5, 1)
        track.Position = UDim2.new(0.5, 0, 1, -3)
        track.Size = UDim2.fromOffset(28, 3)
        glow.Size = UDim2.fromOffset(58, 58)
    end

    local fadeInfo = TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local function fade(show)
        TweenService:Create(scale, fadeInfo, {Scale = show and 1 or 0.86}):Play()
        TweenService:Create(pill, fadeInfo, {BackgroundTransparency = show and 0.32 or 1}):Play()
        TweenService:Create(stroke, fadeInfo, {Transparency = show and 0.82 or 1}):Play()
        TweenService:Create(glow, fadeInfo, {BackgroundTransparency = show and 0.93 or 1}):Play()
        TweenService:Create(key, fadeInfo, {BackgroundTransparency = show and 0.05 or 1}):Play()
        TweenService:Create(keyText, fadeInfo, {TextTransparency = show and 0 or 1}):Play()
        TweenService:Create(action, fadeInfo, {TextTransparency = show and 0.05 or 1}):Play()
        TweenService:Create(object, fadeInfo, {TextTransparency = show and 0.25 or 1}):Play()
        TweenService:Create(track, fadeInfo, {BackgroundTransparency = show and 0.82 or 1}):Play()
        TweenService:Create(fill, fadeInfo, {BackgroundTransparency = show and 0 or 1}):Play()
    end
    fade(true)

    local conns = {}
    local fillTween
    table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
        if fillTween then fillTween:Cancel() end
        fillTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1)})
        fillTween:Play()
        TweenService:Create(key, TweenInfo.new(0.15), {Size = UDim2.fromOffset(28, 28)}):Play()
    end))
    table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
        if fillTween then fillTween:Cancel() end
        fillTween = TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Size = UDim2.fromScale(0, 1)})
        fillTween:Play()
        TweenService:Create(key, TweenInfo.new(0.15), {Size = UDim2.fromOffset(32, 32)}):Play()
    end))
    table.insert(conns, prompt.Triggered:Connect(function()
        glow.BackgroundTransparency = 0.75
        TweenService:Create(glow, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.93}):Play()
    end))
    table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
        action.Text = actionText()
    end))
    table.insert(conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(layoutText))
    --mouse and touch holding
    table.insert(conns, pill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
    end))
    table.insert(conns, pill.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
    end))

    return function()
        for _, c in ipairs(conns) do c:Disconnect() end
        fade(false)
        task.delay(0.25, function() bb:Destroy() end)
    end
end

--the walk-in door gets a soft outline when you are close and it is shut, so it reads as something you can open
task.spawn(function()
    local freezer = workspace:WaitForChild("ChipotleMap"):WaitForChild("BackHallway"):WaitForChild("NorthSide"):WaitForChild("FreezerDoor", 20)
    if not freezer then return end
    local hl = Instance.new("Highlight")
    hl.Name = "FreezerHint"
    hl.FillColor = Color3.fromRGB(255, 236, 200)
    hl.FillTransparency = 1
    hl.OutlineColor = Color3.fromRGB(255, 236, 200)
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Adornee = freezer
    hl.Parent = freezer
    local shown = false
    while freezer.Parent do
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local near = false
        if root and not freezer:GetAttribute("Open") then
            near = (root.Position - freezer:GetPivot().Position).Magnitude < 14
        end
        if near ~= shown then
            shown = near
            TweenService:Create(hl, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {OutlineTransparency = near and 0.55 or 1, FillTransparency = near and 0.93 or 1}):Play()
        end
        task.wait(0.2)
    end
end)

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
    local cleanup = buildPrompt(prompt, inputType)
    prompt.PromptHidden:Wait()
    cleanup()
end)
