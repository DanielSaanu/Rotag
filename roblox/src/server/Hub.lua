-- The hub and the match servers (H34; Danzo, 2026-11-16: "hub with match servers"; docs/systems/session.md §8). One
-- place, three kinds of server, decided once at boot:
--   "hub"    a public live server: everybody gathers here. PLAY queues you (and gives you a body to warm up with);
--            when four are queued, or the wait runs out, the group is sent to a match server of its own.
--   "match"  a RESERVED server made by a hub (TeleportService:ReserveServer): it runs today's game for the players
--            it was sent (bots fill the empty seats), one match, then sends everybody back to a hub.
--   "solo"   Studio, a private (VIP) server, or Config.HUB false: the game as it was before the hub: matches run
--            here. Also what a hub falls back to if it cannot reserve servers.
-- Teleports do not work in Studio, so the hub and match paths can only be tested on the published game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hub = {}

local FAILS_TO_SOLO = 2 -- launches that failed in a row before this hub gives up and runs matches itself

local function mode(): string
	if RunService:IsStudio() then
		-- Studio cannot teleport. Workspace attribute RotagHubTest = true makes a Studio server a hub anyway, to test
		-- the queue, a launch that fails, and the fall-back to solo (it will fail twice, then run matches itself).
		return if workspace:GetAttribute("RotagHubTest") == true then "hub" else "solo"
	end
	if not Config.HUB then return "solo" end
	if game.PrivateServerId ~= "" then
		return if game.PrivateServerOwnerId == 0 then "match" else "solo" -- reserved by a hub / a player's own VIP server
	end
	return "hub"
end
Hub.MODE = mode()

local fails = 0
local failed: ((Player) -> ())? = nil

-- Send `players` (a queued group) to a match server of their own. Never yields the caller. A player whose teleport
-- fails is handed to `Hub.onFailed`'s callback (back in the queue); after FAILS_TO_SOLO whole launches that failed
-- in a row this server stops being a hub (Hub.MODE "solo": it runs the matches itself).
function Hub.launch(players: { Player })
	task.spawn(function()
		local ok, res = false, "Studio cannot teleport (the hub test fails every launch on purpose)"
		if RunService:IsStudio() then
			-- Never call TeleportService in Studio: a teleport there restarts the Play session (seen, twice). The
			-- RotagHubTest path stands in a launch that fails after a second, to exercise the requeue and the fall-back.
			task.wait(1)
		else
			ok, res = pcall(function() return TeleportService:ReserveServer(game.PlaceId) end)
		end
		if ok then
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = res
			ok, res = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, players, options) end)
		end
		if ok then
			fails = 0
			print(("[Rotag] hub: sent %d player(s) to a match server"):format(#players))
			return
		end
		fails += 1
		warn(("[Rotag] hub: could not start a match server (%s); try %d of %d"):format(tostring(res), fails, FAILS_TO_SOLO))
		if fails >= FAILS_TO_SOLO then
			Hub.MODE = "solo"
			warn("[Rotag] hub: giving up on match servers: this server runs the matches itself from now on")
		end
		for _, p in players do
			if failed and p.Parent then failed(p) end
		end
	end)
end

-- Send `players` back to a public hub server (the end of a match, or "back to the lobby").
function Hub.home(players: { Player })
	if #players == 0 or RunService:IsStudio() then return end -- (a teleport in Studio restarts the Play session)
	task.spawn(function()
		local ok, err = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, players) end)
		if not ok then warn("[Rotag] hub: could not send players back to the lobby: " .. tostring(err)) end
	end)
end

-- `fn(player)`: this player's teleport did not happen (it is still here): put it back in the queue.
function Hub.onFailed(fn: (Player) -> ())
	failed = fn
end

TeleportService.TeleportInitFailed:Connect(function(player: Player, result, message)
	warn(("[Rotag] hub: teleport failed for %s: %s %s"):format(player.Name, tostring(result), tostring(message)))
	if failed and player.Parent == Players then failed(player) end
end)

print(("[Rotag] hub: this server is a %s server"):format(Hub.MODE))

return Hub
