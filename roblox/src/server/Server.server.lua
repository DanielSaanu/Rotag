-- The server entry point. Owns the match: who is "it", the fuse, eliminations, ghosts (none built yet).
-- Today it resolves the sprite sheet, builds the test map and spawns each player's runner body.
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

-- The sprite toggles Danzo flips in Properties (docs/systems/movement.md, "Drawn two ways"). Shown in Properties
-- during Play even when the place does not have them yet; set them in Edit mode to keep a choice between Plays.
if workspace:GetAttribute("SurfaceSprites") == nil then workspace:SetAttribute("SurfaceSprites", false) end
if workspace:GetAttribute("FlipBySize") == nil then workspace:SetAttribute("FlipBySize", false) end

Arena.build()
Runners.start(Arena.SPAWN)
