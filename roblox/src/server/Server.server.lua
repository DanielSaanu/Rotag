-- The server entry point. Resolves the sprite sheet, builds the map, loads profiles, starts the match (server/Match.lua: "it",
-- the fuse, tag claims, ghosts and orbs) and spawns each player's runner body.
local Players = game:GetService("Players")
-- First, before anything can yield: no stock character for anyone (server/Runners.lua builds the runner body).
Players.CharacterAutoLoads = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Runners = require(script.Parent:WaitForChild("Runners"))
local Match = require(script.Parent:WaitForChild("Match"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Stage = require(script.Parent:WaitForChild("Stage"))
local LobbyMap = require(script.Parent:WaitForChild("LobbyMap")) -- H37: the walk-in lobby and the room, beside the arena
-- Declared in default.project.json, so it is in the place before any script runs; never created here. A rojo serve
-- started before the declaration does not sync it (restart rojo serve): then warn and play on, never hang.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local sheetIdsRemote = remotes and remotes:FindFirstChild("SheetIds")

-- Open Cloud uploads give a Decal id; the server turns it into the Image id once (docs/ROBLOX_SETUP.md).
local sheetIds = Sprites.ResolveOnServer()
print(("[Rotag] server up: %d players per match, fuse %ds, %d sprite sheet(s)"):format(
	Config.PLAYERS_PER_MATCH, Config.FUSE_START, #sheetIds))

-- Hand every client the resolved ids, once, on join (Remotes.SheetIds, docs/systems/README.md). Sent before
-- Runners.start so it leaves ahead of the first body; the client re-applies if it lands later anyway.
if sheetIdsRemote and sheetIdsRemote:IsA("RemoteEvent") then
	local remote: RemoteEvent = sheetIdsRemote
	local function sendSheetIds(player: Player)
		if player.Parent then remote:FireClient(player, sheetIds) end
	end
	-- Server to client only. A client fire is dropped unread, so an exploit cannot fill the event's queue.
	remote.OnServerEvent:Connect(function() end)
	Players.PlayerAdded:Connect(sendSheetIds)
	for _, player in Players:GetPlayers() do sendSheetIds(player) end
else
	warn("[Rotag] ReplicatedStorage.Remotes.SheetIds is missing (restart rojo serve to sync default.project.json);"
		.. " clients draw with the sheet ids built into Sprites.lua")
end

LobbyMap.build()
Stage.dress(Arena.build(), Arena.MAP) -- H31: the look (lit edges, backdrop, night and bloom); no rule reads it
Data.start() -- H31: saved profiles (coins, cosmetics); never blocks a join (docs/systems/session.md §5)
Shop.start(remotes and remotes:FindFirstChild("Shop"), remotes and remotes:FindFirstChild("Profile"),
	remotes and remotes:FindFirstChild("Looks"))
Match.start(Runners.TAG) -- the round, "it", the fuse, tag claims (docs/systems/tag.md); before the first body
Runners.start() -- H37: server/Session gives everybody a body in the lobby the moment they join
