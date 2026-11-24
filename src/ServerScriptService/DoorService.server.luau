--hold e on any tagged door to open or close it, the swing itself is animated on each client
local CollectionService = game:GetService("CollectionService")

local HOLD_TIME = 0.45
local COOLDOWN = 0.9
--what the prompt says it belongs to
local LABELS = {EntryDoorA = "Front Door", EntryDoorB = "Front Door", BackExitDoor = "Back Door", ExitDoorLeaf = "Exit Door", OfficeDoorModel = "Office Door", EmployeeDoor = "Employee Door", RestroomDoorA = "Restroom", RestroomDoorB = "Restroom", FreezerDoor = "Freezer"}


local function promptPartFor(door)
    if door:IsA("Model") then return door.PrimaryPart end
    return door
end


--Shut only turns true once the swing has really reached the frame, using the same timing the clients animate with
--Open=false just means someone asked it to close
local function trackShut(door)
    local token = 0
    local function refresh()
        token += 1
        local mine = token
        if door:GetAttribute("Open") then
            door:SetAttribute("Shut", false)
            return
        end
        local swing = door:GetAttribute("Slam") == true and 0.38 or 0.95
        task.delay(swing + 0.05, function()
            if token == mine and not door:GetAttribute("Open") then door:SetAttribute("Shut", true) end
        end)
    end
    door:SetAttribute("Shut", not door:GetAttribute("Open"))
    door:GetAttributeChangedSignal("Open"):Connect(refresh)
    --a slam that lands mid close restarts the swing from where it is, same as the clients
    door:GetAttributeChangedSignal("Slam"):Connect(function()
        if door:GetAttribute("Slam") == true and not door:GetAttribute("Open") and not door:GetAttribute("Shut") then refresh() end
    end)
end


local function setup(door)
    --skip the backup copies sitting in serverstorage
    if not door:IsDescendantOf(workspace) then return end
    if door:GetAttribute("Shut") == nil then trackShut(door) end
    local part = promptPartFor(door)
    if not part or part:FindFirstChild("DoorPrompt") then return end
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "DoorPrompt"
    prompt.ActionText = door:GetAttribute("Open") and "Close" or "Open"
    prompt.ObjectText = LABELS[door.Name] or "Door"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    --the office is the panic room, one tap shuts it
    local isOffice = door.Name == "OfficeDoorModel"
    prompt.HoldDuration = isOffice and 0 or HOLD_TIME
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = true
    --the walk-in handle sits in front of the prompt spot, so it would hide the e
    if door.Name == "FreezerDoor" then prompt.RequiresLineOfSight = false end
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt.Parent = part
    --the label follows the door even when the monster opens or shuts it
    door:GetAttributeChangedSignal("Open"):Connect(function()
        prompt.ActionText = door:GetAttribute("Open") and "Close" or "Open"
    end)
    local busy = false
    prompt.Triggered:Connect(function(player)
        if busy then return end
        local open = not door:GetAttribute("Open")
        --the office only opens for someone who has clocked in at the ipad
        if isOffice and open and not player:GetAttribute("ClockedIn") then
            game:GetService("ReplicatedStorage"):WaitForChild("ClockInEvent"):FireClient(player, "needClockIn")
            return
        end
        busy = true
        --shutting it while the monster is loose is a full slam, not the gentle close
        door:SetAttribute("Slam", (not open) and workspace:GetAttribute("Hunting") == true)
        door:SetAttribute("Open", open)
        prompt.ActionText = open and "Close" or "Open"
        task.wait(isOffice and 0.35 or COOLDOWN)
        busy = false
    end)
end

for _, door in ipairs(CollectionService:GetTagged("InteractDoor")) do setup(door) end
CollectionService:GetInstanceAddedSignal("InteractDoor"):Connect(setup)

--the side exit by the restrooms is the way out to the lot, the player can use it from either side
local exitDoor = workspace:WaitForChild("ChipotleMap"):WaitForChild("EntryHallway"):WaitForChild("ExitDoorLeaf", 10)
if exitDoor then setup(exitDoor) end
--the two front doors work from both sides too, opening them pulls the broom out of the handles
for _, n in ipairs({"EntryDoorA", "EntryDoorB"}) do
    local d = workspace.ChipotleMap.EntryHallway:WaitForChild(n, 10)
    if d then
        setup(d)
        --the broom across the handles would otherwise hide the prompt
        local p = promptPartFor(d)
        local prompt = p and p:FindFirstChild("DoorPrompt")
        if prompt then prompt.RequiresLineOfSight = false end
    end
end
