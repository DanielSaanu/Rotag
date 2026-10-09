-- The server entry point. Owns the match: who is "it", the fuse, eliminations, ghosts (none built yet).
-- Today it resolves the sprite sheet, builds the test map and spawns each player's runner body.
local Players = game:GetService("Players")
-- First, before anything can yield: no stock character for anyone (server/Runners.lua builds the runner body).
Players.CharacterAutoLoads = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Runners = require(script.Parent:WaitForChild("Runners"))

-- Open Cloud uploads give a Decal id; the server turns it into the Image id once (docs/ROBLOX_SETUP.md).
local sheetIds = Sprites.ResolveOnServer()
print(("[Rotag] server up: %d players per match, fuse %ds, %d sprite sheet(s)"):format(
	Config.PLAYERS_PER_MATCH, Config.FUSE_START, #sheetIds))

Arena.build()
Runners.start(Arena.SPAWN)
