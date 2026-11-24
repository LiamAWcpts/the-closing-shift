# The Closing Shift

A roblox horror game. You close up a burrito restaurant alone at night and something outside keeps trying to get in. You survive 5 nights on easy normal or hard by doing your tasks and watching the cameras.

## How to open it

The game itself lives on roblox so the easiest way is opening The Closing Shift in Roblox Studio.

This repo is just the scripts. The folders are laid out the same way the explorer in studio is so ServerScriptService here is ServerScriptService in the game.

If you want to sync it back into studio you can use rojo with default.project.json (rojo serve) but the map and models arent in here only the code.

## Files

The file endings tell you what kind of script it is.
name.server.luau - Script (runs on the server)
name.client.luau - LocalScript (runs on each player)
name.luau - ModuleScript (shared code)

Server (src/ServerScriptService)

NightService - the night itself. the clock from 12 to 5 am, handing out tasks, strikes, the difficulty vote, winning and losing and saving what night you are on
MonsterService - the monster ai. stalking, testing the doors, breaking in, hunting, the flash, killing the player and getting faster on later nights
SecurityService - sitting in the office chair, camera power draining and charging
DoorService - opening and closing doors and the walk in freezer
ClockInService - the ipad you clock in on at the start of a shift
LobbyService - the play button on the start screen and going back to the menu after a night
CharacterService - someone who joins in the middle of a night watches until the next one
PlayerScale - makes every avatar the same standard size
FriendsOnly - sends strangers to their own server so its only you and your friends
LightFlicker / Ambience / MapAnchor - small map stuff (flickering lights, background sounds, keeping the map from moving)

Player (src/StarterPlayer/StarterPlayerScripts)

MenuClient - the start screen with the play button and the store shots playing behind it
CharacterSelect - the difficulty screen (it used to also be the character picker so the name stayed)
IntroCutscene - the opening scene in the car, the knock, running inside and holding the doors
NightClient - everything on screen during a night (clock, tasks, strikes, the phone calls, winning and the you died screen)
SecurityClient - the camera monitor, switching cameras, the flash button
MonsterClient / MonsterAnimClient / HuntClient - what the player sees and hears from the monster, its animations and hiding during a hunt
MovementController / FirstPersonCamera / NoJump - walking, sprinting, footsteps and the first person camera
InteractionClient / DoorClient / TaskMarkerClient - the e prompts, doors and the markers that point to your task
ClockInClient - the ipad keypad screen
VapeClient - one of the tasks
WatermelonClient - the watermelon by the dumpsters (hold e on it and see what happens)
SpectateClient - watching a teammate after you die
AudioClient - sounds and music
AmbienceClient - hanging things sway a little and the screen edges get darker
AtmosClient - the light shafts under the ceiling lights, they go out with the power
MobileControls / MobilePerformance - phone buttons and turning effects down on phones

Shared (src/ReplicatedStorage)

AudioIds - every sound id in one place
MovementConfig - walk and sprint speeds and stamina
MobileUI - helpers so the screens work on phones and computers
IntroBroomPath - the path the broom takes in the intro

## How a night works

You press play and then everyone in the server votes on the difficulty. After the intro you clock in at the ipad and sit in the office chair and the night starts at 12 am. Every in game hour is a real minute so a night is 5 minutes.

Tasks come in during the night (cleaning, the order line, the window, the trash run and a couple others). Each one has a timer and if you miss too many you lose. Easy lets you miss a lot, normal lets each player miss one and hard doesnt let you miss any.

The monster has a plan for the night and it changes based on the difficulty and which night it is. It stalks outside, tests the doors and tries to break in. You find it on the cameras and flash it to scare it off before it gets inside. If it does get in it hunts and you have to hide.

## Design decisions

Everything important is decided on the server (the clock, tasks, the monster) so two players always see the same night and nobody can cheat by changing their own client.

Later nights get harder in small steps instead of all at once. Task timers get a little shorter, the monster breaks in faster, the camera battery drains faster and nights 3 and 5 add an extra task. Night 1 also has a phone call that explains everything.

Progress saves per difficulty so beating night 3 on normal doesnt skip anything on hard. When a group plays together the night is the lowest one anyone is on so nobody skips a night.

Everyone uses their own avatar but it gets resized to a standard size first because the doors and hiding spots and camera height were all built for one size.

The server only has 4 spots and strangers get moved out because the game is meant to be played with your friends.
