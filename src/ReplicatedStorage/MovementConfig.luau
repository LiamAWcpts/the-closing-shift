--all movement values in one place
local Config = {}

--speed
Config.WalkSpeed = 17
Config.SprintMultiplier = 1.2
Config.SpeedSmoothing = 6

--stamina in seconds
Config.SprintDuration = 5
Config.RechargeDuration = 7
--after running out you need this much back before sprinting again
Config.ResumeThreshold = 0.25

--camera
Config.BaseFOV = 75
Config.SprintFOVBoost = 5
Config.WalkStride = 8.5
Config.SprintStride = 7.7
Config.WalkBobVertical = 0.14
Config.SprintBobVertical = 0.32
Config.WalkBobHorizontal = 0.09
Config.SprintBobHorizontal = 0.18
Config.WalkBobRoll = 0.35
Config.SprintBobRoll = 0.9
Config.BreathAmount = 0.025
Config.ExhaustedBreathAmount = 0.09

--footsteps
Config.WalkStepVolume = 0.3
Config.SprintStepVolume = 0.5
Config.WalkPitch = {0.95, 1.05}
Config.SprintPitch = {0.86, 0.96}
Config.DefaultSurface = "Concrete"

Config.SurfaceMap = {
    Slate = "Tile", Marble = "Tile", Granite = "Tile", Pebble = "Tile", Glass = "Tile",
    Concrete = "Concrete", SmoothPlastic = "Concrete", Plastic = "Concrete", Brick = "Concrete", Cobblestone = "Concrete", Pavement = "Concrete",
    Metal = "Concrete", DiamondPlate = "Concrete", CorrodedMetal = "Concrete", Wood = "Concrete", WoodPlanks = "Concrete",
    Asphalt = "Gritty", Ground = "Gritty", Grass = "Gritty", Sand = "Gritty", Mud = "Gritty", LeafyGrass = "Gritty",
}

Config.FootstepSounds = {
    Concrete = {
        "rbxassetid://108290664490396", "rbxassetid://96955798612091", "rbxassetid://120195545352847",
        "rbxassetid://112000835797556", "rbxassetid://106961831442199",
    },
    Tile = {
        "rbxassetid://112733259097591", "rbxassetid://118048499719068", "rbxassetid://126965755395879",
        "rbxassetid://133063162472741", "rbxassetid://72966441854333", "rbxassetid://139267724392327",
    },
    Gritty = {
        "rbxassetid://75948132493425", "rbxassetid://111154292786687", "rbxassetid://129873522422425",
    },
}

return Config
