-- The server entry point. Owns the match: who is "it", the fuse, eliminations, ghosts.
-- Nothing is built yet; this stub proves the Rojo tree (default.project.json) syncs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))

-- Open Cloud uploads give a Decal id; the server turns it into the Image id once (docs/ROBLOX_SETUP.md).
local sheetIds = Sprites.ResolveOnServer()
print(("[Rotag] server up: %d players per match, fuse %ds, %d sprite sheet(s)"):format(
	Config.PLAYERS_PER_MATCH, Config.FUSE_START, #sheetIds))
