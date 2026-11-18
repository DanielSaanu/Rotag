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
local MemoryStoreService = game:GetService("MemoryStoreService")
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

-- H37 (docs/systems/lobby.md §6): a reserved server is a quick match's (nothing recorded), a private ROOM's or a
-- PRACTICE server's. What it is was written by the hub that reserved it, server to server, under its PrivateServerId
-- in a MemoryStore map (teleport data passes through the client: it is never what decides this). A room's code is a
-- second key in the same map: code -> the access code that lets a hub send a friend there.
--   "sid:<PrivateServerId>" = { kind = "room" | "practice", code = "4827"?, host = userId }
--   "code:<4 digits>"       = { access = <reserved server access code>, sid = <PrivateServerId>, n = players there }
Hub.KIND = "match" -- "match" | "room" | "practice": only read on a reserved server
Hub.RECORD = nil :: any
local map: any = nil
local function store(): any
	if map == nil then
		local ok, m = pcall(function() return MemoryStoreService:GetHashMap("RotagRooms") end)
		map = if ok then m else false
	end
	return map or nil
end
if Hub.MODE == "match" then
	local ok, rec = pcall(function()
		local m = store()
		return m and m:GetAsync("sid:" .. game.PrivateServerId)
	end)
	if ok and type(rec) == "table" and (rec.kind == "room" or rec.kind == "practice") then
		Hub.KIND, Hub.RECORD = rec.kind, rec
	elseif not ok then
		warn("[Rotag] hub: could not read what this reserved server is for (" .. tostring(rec) .. "); running a quick match")
	end
	-- A room runs its matches itself, when its host says so, and keeps its players between them: the solo flow.
	if Hub.KIND == "room" then Hub.MODE = "solo" end
end

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
		local reserved = ok
		if ok then
			-- QA round 3: whoever left while the server was being reserved is dropped from the group first (a
			-- teleport of a list holding a player who is gone throws, and that must not count against the hub).
			local here = {}
			for _, p in players do
				if p.Parent == Players then table.insert(here, p) end
			end
			if #here == 0 then return end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = res
			options:SetTeleportData({ n = #here }) -- the match server waits for this many before it counts down
			ok, res = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, here, options) end)
		end
		if ok then
			fails = 0
			print(("[Rotag] hub: sent %d player(s) to a match server"):format(#players))
			return
		end
		-- Only a server that could not be RESERVED counts toward giving up: a teleport that failed for a group
		-- (somebody left, a slow phone) just puts that group back in the queue.
		if not reserved then fails += 1 end
		warn(("[Rotag] hub: could not start a match (%s); %d of %d failed reservations"):format(tostring(res), fails, FAILS_TO_SOLO))
		if fails >= FAILS_TO_SOLO then
			Hub.MODE = "solo"
			warn("[Rotag] hub: giving up on match servers: this server runs the matches itself from now on")
		end
		for _, p in players do
			if failed and p.Parent == Players then failed(p) end
		end
	end)
end

-- How many players the hub sent to this match server with `player` (1..PLAYERS_PER_MATCH), or 1 when unknown.
-- Teleport data passes through the client, so it is only ever used to WAIT a little longer, never to seat anyone.
function Hub.groupOf(player: Player): number
	local ok, data = pcall(function() return player:GetJoinData() end)
	local n = if ok and type(data) == "table" and type(data.TeleportData) == "table" then data.TeleportData.n else nil
	if type(n) ~= "number" or n ~= n then return 1 end
	return math.clamp(math.floor(n), 1, Config.PLAYERS_PER_MATCH)
end

-- Send `players` back to a public hub server (the end of a match, or "back to the lobby").
function Hub.home(players: { Player })
	if #players == 0 or RunService:IsStudio() then return end -- (a teleport in Studio restarts the Play session)
	task.spawn(function()
		local ok, err = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, players) end)
		if not ok then warn("[Rotag] hub: could not send players back to the lobby: " .. tostring(err)) end
	end)
end

-- H37: reserve a server of `kind` ("room" | "practice") for `player`, record what it is, and send the player there.
-- Never yields the caller. `done(why)` runs only when it did NOT happen (the player is still here), with a word for
-- the banner. A room gets a fresh 4-digit code (a few tries to find a free one).
function Hub.open(kind: string, player: Player, done: (string) -> ())
	task.spawn(function()
		local m = store()
		if RunService:IsStudio() or not m then
			task.wait(1)
			done("failed")
			return
		end
		local ok, access, sid = pcall(function() return TeleportService:ReserveServer(game.PlaceId) end)
		if not (ok and type(access) == "string" and type(sid) == "string") then
			warn("[Rotag] hub: could not reserve a " .. kind .. " server: " .. tostring(access))
			done("failed")
			return
		end
		local code: string? = nil
		local wrote = pcall(function()
			if kind == "room" then
				for _ = 1, 6 do
					local try = ("%04d"):format(math.random(0, 9999))
					if m:GetAsync("code:" .. try) == nil then
						code = try
						break
					end
				end
				if not code then error("no free room code") end
				m:SetAsync("code:" .. code, { access = access, sid = sid, n = 0 }, Config.ROOM_TTL)
			end
			m:SetAsync("sid:" .. sid, { kind = kind, code = code, host = player.UserId }, Config.ROOM_TTL)
		end)
		if not wrote or player.Parent ~= Players then
			if wrote and code then pcall(function() m:RemoveAsync("code:" .. code) end) end
			done("failed")
			return
		end
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = access
		local sent, err = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
		if not sent then
			warn("[Rotag] hub: could not send " .. player.Name .. " to its " .. kind .. " server: " .. tostring(err))
			done("failed")
		end
	end)
end

-- H37: send `player` to the room with `code`. `done(why)` only when it did not happen: "noroom" | "full" | "failed".
function Hub.join(player: Player, code: string, done: (string) -> ())
	task.spawn(function()
		local m = store()
		if RunService:IsStudio() or not m then
			done("noroom")
			return
		end
		local ok, rec = pcall(function() return m:GetAsync("code:" .. code) end)
		if not ok then
			done("failed")
		elseif type(rec) ~= "table" or type(rec.access) ~= "string" then
			done("noroom")
		elseif type(rec.n) == "number" and rec.n >= Config.PLAYERS_PER_MATCH then
			done("full")
		elseif player.Parent == Players then
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = rec.access
			local sent = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
			if not sent then done("failed") end
		end
	end)
end

-- H37, a room server: keep its code alive and say how many are in it (`n`); `n` nil closes the room (its code is
-- free again). Never yields the caller.
function Hub.keep(n: number?)
	local rec = Hub.RECORD
	local m = store()
	if not (m and rec and type(rec.code) == "string") or RunService:IsStudio() then return end
	task.spawn(function()
		pcall(function()
			local key = "code:" .. rec.code
			if n == nil then
				m:RemoveAsync(key)
				m:RemoveAsync("sid:" .. game.PrivateServerId)
				return
			end
			local cur = m:GetAsync(key)
			if type(cur) == "table" then
				cur.n = n
				m:SetAsync(key, cur, Config.ROOM_TTL)
			end
			m:SetAsync("sid:" .. game.PrivateServerId, rec, Config.ROOM_TTL)
		end)
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

print(("[Rotag] hub: this server is a %s server%s"):format(Hub.MODE, if Hub.KIND ~= "match" then " (" .. Hub.KIND .. ")" else ""))

return Hub
