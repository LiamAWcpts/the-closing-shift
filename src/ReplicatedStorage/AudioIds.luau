--asset ids for the music made for this game
--an empty id just means that sound is skipped until it is filled in
return {
    --free creator store sounds, swap any of these for your own uploads later
    --no music on the menu
    selectTheme = "",
    --crickets night 3 (pro sound effects), 64 second loop
    nightAmbience = "9112764573",
    --no way out (distrokid)
    chaseLoop = "131897943146790",
    --the scrolling videos on the phone in the intro, one free creator store sound per video, same order as VIDEO_POOL
    phoneClips = {
        "1839334216", --bloxy cola: sunny pop
        "1836846569", --super bomb simulator: fervour and fury
        "1845137559", --nom nom nom: carnival procession
        "1848294273", --carts carts carts: runaway carousel
        "9043759854", --fight loop: shades of cool rock
        "9125955674", --sk8r vibes: skateboard rolling
        "1836039989", --anime accessories promo: bouncy way
        "9042201681", --bunny scarf ad: christmas pop
        "1836077174", --bricks: triumphant and ceremonial
        "9043359642", --we're watching: dark drone
        "9119383479", --flying cartoon birds: morning birds
        "9119974504", --old retro tv set: tv clicks and static
        "1836846971", --flying colored cubes: off the mark
        "9038880848", --xray critical: electric hum
        "9119677135", --toastin at the beach: surf
        "9114244977", --astronauts in space: airy ambience
        "9119677305", --ocean coastline: surf
        "9040102016", --please wait: calm indie folk
        "4940109913", --clock passing time: ticking
        "9119974615", --tv intermission static: tv static
    },
    --the cartoon pony clip on the phone: cutie pie
    ponyClip = "1837478883",
    --monster barefoot steps, barefoot_walk_1..6, barefoot_run_1..4, barefoot_creep_1..4
    barefootWalk = {"", "", "", "", "", ""},
    barefootRun = {"", "", "", ""},
    barefootCreep = {"", "", "", ""},
}
