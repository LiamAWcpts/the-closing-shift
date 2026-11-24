--the watermelon by the dumpsters, hold e on it for 5 seconds and it covers your screen for 5 seconds
local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local DURATION = 5
local active = false

--the watermelon photo shrunk down to 48 by 27 blocks, each letter is one colour from the palette
local W, H = 48, 27
local PALETTE = {"ffffff", "fffffe", "fdfefd", "f6f8f5", "eaefe8", "d4e2ca", "c1d5b6", "8ebe6f", "81b262", "75a754", "719c59", "a2c492", "639944", "4a7b31", "557f3d", "5c8f41", "5a8a41", "a4d089", "45732e", "366329", "456c33", "305722", "21461d", "3f6126"}
local ROWS = {
    "AAAAAAAAAAAAAAAAAAAAABBAAAAAAAAAAAAAAAAAAAAAAAAA",
    "AAAAAAAAAAAAAAAACDEFFFFFFFEDCAAAAAAAAAAAAAAAAAAA",
    "AAAAAAAAAAAAABDFGHIJKKKKJIHLGFDCAAAAAAAAAAAAAAAA",
    "AAAAAAAAAAAADFLHHIJJJJJJMNNOPJLFECAAAAAAAAAAAAAA",
    "AAAAAAAAAABEGHHHIJMQQQPMJMMMPOQKHFDBAAAAAAAAAAAA",
    "AAAAAAAAAAERRRRHKMMMQSTSSSTNMJMMMJRFCAAAAAAAAAAA",
    "AAAAAAAAADLILLLLHHHIJJMMNSSSUUOPJIMJLDAAAAAAAAAA",
    "AAAAAAAACGILLLLRRRHIJMMMMMMMMKIIKKMQOLDAAAAAAAAA",
    "AAAAAAAAEHHLLLLLHHHKOUSSSSPPPIHRRHIMOQGCAAAAAAAA",
    "AAAAAAAAGIHGRRRLHRHKQUTVTTUNOKKIHLHHIOQEAAAAAAAA",
    "AAAAAAACRHHRRRRRRRRKMQPOSTTUUOQKKILLHIOLCAAAAAAA",
    "AAAAAAADHHRRHRRRRRHMJMMMMNSNOQQQKKKIIJMKDAAAAAAA",
    "AAAAAAAEKKRHIKKIIHIJJMPPPPNQPPMMKKKKKOSQEAAAAAAA",
    "AAAAAAAFJIHHHIKPQQMMMOTSNNNNNQQPMJIJKQVUFAAAAAAA",
    "AAAAAAAFJHHIHHIJOTTTTVWTSSXSSNNOOPPMJMNUFAAAAAAA",
    "AAAAAAAEMJIHHHJMPTVVWWWWWWWVVXTNQOPPPPQPEAAAAAAA",
    "AAAAAAACINOIHIJMQQNUVWWWWWWWWWWVTUNSSNSPEAAAAAAA",
    "AAAAAAAAGNSMJJJMMPPPSTTVTTVVWWWWWWWWWWWKCAAAAAAA",
    "AAAAAAAADHPOOPMMPPPPOSTUNSSSVWWWWWVVVVXGBAAAAAAA",
    "AAAAAAAAAFHQNSOQNPPOONXXSSNSTTVXXSNOQOKEAAAAAAAA",
    "AAAAAAAAACFIMNUUTNSUOONNNNSSNNNNNNNOOOGCAAAAAAAA",
    "AAAAAAAAAACFIMMSUTVVVTSSSSVXSNNNSTTUOGCAAAAAAAAA",
    "AAAAAAAAAAACELKMPNXTVVWVVVVVVVTVVXUKGCAAAAAAAAAA",
    "AAAAAAAAAAABCDFHPOSSSXVVVVVVVXXXUKLECBAAAAAAAAAA",
    "AAAAAAACCCDDDDEEGHQUXXXXXXXXVXOKLFEEDDDCCCCAAAAA",
    "AAAAAAACCDDEEEEFFGLLKQOOUOOQKHLGGFFEEEDDCCCAAAAA",
    "AAAAAAAACCCDDDDEEEEEFFFFFFFFFFEEEEDDDDCCCCAAAAAA",
}


--every block is its own frame so it stays crunchy and stretches over the whole screen
local function buildMelon()
    local gui = Instance.new("ScreenGui")
    gui.Name = "WatermelonGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 500
    gui.Parent = player.PlayerGui

    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.Size = UDim2.fromScale(1, 1)
    holder.BackgroundColor3 = Color3.new(1, 1, 1)
    holder.BorderSizePixel = 0
    holder.Parent = gui

    for y = 1, H do
        local row = ROWS[y]
        for x = 1, W do
            local index = row:byte(x) - 64
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.BackgroundColor3 = Color3.fromHex(PALETTE[index])
            --one extra pixel each way so no seams show between blocks
            f.Position = UDim2.fromScale((x - 1) / W, (y - 1) / H)
            f.Size = UDim2.new(1 / W, 1, 1 / H, 1)
            f.Parent = holder
        end
    end
    return gui
end


local function trigger()
    if active then return end
    active = true
    local gui = buildMelon()
    task.wait(DURATION)
    gui:Destroy()
    active = false
end

PPS.PromptTriggered:Connect(function(prompt)
    if prompt.Name == "WatermelonPrompt" then task.spawn(trigger) end
end)
