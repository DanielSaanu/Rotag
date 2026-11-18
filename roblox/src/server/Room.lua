-- A private room (H37, docs/systems/lobby.md §5): the place behind HOST A ROOM. Who is in it (up to four, in the
-- order they arrived), who its host is, its code and its three settings. On the live game a room is a reserved server
-- of its own (server/Hub: Hub.KIND "room"); in Studio and on a solo server, which cannot teleport, the ONE server
-- stands in: HOST A ROOM makes its room here and ENTER A CODE walks you into it. The rules are the same either way,
-- so what Studio shows is what a room server does. server/Session calls in; nothing here trusts a client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local LobbyMap = require(script.Parent:WaitForChild("LobbyMap"))

local Room = {}

Room.active = false
Room.code = nil :: string?
Room.host = nil :: number?
Room.members = {} :: { number }
Room.settings = { rounds = Config.MATCH_ROUNDS, items = true, bots = true }
Room.changed = function() end -- server/Session: something every screen shows has changed

local wantHost: number? = nil -- a room server: who asked for it (it is host once it arrives)
local hostAt: { x: number, y: number, since: number }? = nil
local KEEP = 240 -- seconds between a room server's refreshes of its code
local lastKeep = 0

function Room.has(id: number): boolean return Room.active and table.find(Room.members, id) ~= nil end

local function nameOf(id: number): string
	local p = Players:GetPlayerByUserId(id)
	return if p then string.upper(p.DisplayName) else "RUNNER"
end

-- The words on the room's walls and floor, for every screen.
local function paint()
	local code = Room.code or ""
	for i = 1, Lobby.CODE_LEN do
		LobbyMap.say("code" .. i, if #code >= i then string.sub(code, i, i) else "-")
	end
	local s = Room.settings
	LobbyMap.say("rounds", tostring(s.rounds))
	LobbyMap.say("items", if s.items then "ON" else "OFF", if s.items then Color3.fromRGB(166, 240, 74) else Color3.fromRGB(255, 96, 48))
	LobbyMap.say("bots", if s.bots then "ON" else "OFF", if s.bots then Color3.fromRGB(166, 240, 74) else Color3.fromRGB(255, 96, 48))
	for i = 1, Config.PLAYERS_PER_MATCH do
		local id = Room.members[i]
		LobbyMap.say("seat" .. i, if id then nameOf(id) .. (if id == Room.host then "  (HOST)" else "")
			elseif s.bots then "BOT" else "EMPTY")
	end
	LobbyMap.say("seathelp", if s.bots then "A FRIEND WHO JOINS TAKES A BOT'S SEAT" else "BOTS ARE OFF: YOU NEED TWO PLAYERS")
end

local function touch()
	paint()
	if Hub.KIND == "room" then
		Hub.keep(#Room.members)
		lastKeep = os.clock()
	end
	Room.changed()
end

-- The stand-in (Studio, a solo server): `player` makes this server's one room. False if there is one already.
function Room.create(player: Player): boolean
	if Room.active then return false end
	Room.active, Room.code = true, ("%04d"):format(math.random(0, 9999))
	Room.host, Room.members = player.UserId, { player.UserId }
	Room.settings = { rounds = Config.MATCH_ROUNDS, items = true, bots = true }
	hostAt = nil
	touch()
	return true
end

-- `player` walks in (a code that matched, or an arrival on a room server). False: the room is full.
function Room.add(player: Player): boolean
	local id = player.UserId
	if not Room.active then return false end
	if table.find(Room.members, id) then return true end
	if #Room.members >= Config.PLAYERS_PER_MATCH then return false end
	table.insert(Room.members, id)
	if Room.host == nil or id == wantHost then Room.host, hostAt = id, nil end
	touch()
	return true
end

-- `id` is gone (the LOBBY door, or it left the game). The next in line hosts; an empty stand-in room closes.
function Room.remove(id: number)
	local i = table.find(Room.members, id)
	if not i then return end
	table.remove(Room.members, i)
	if Room.host == id then Room.host, hostAt = Room.members[1], nil end
	if #Room.members == 0 and Hub.KIND ~= "room" then Room.active, Room.code = false, nil end
	touch()
end

-- The host jumped into a setting block. Returns the new value as words for the banner, or nil (not the host).
function Room.set(id: number, key: string): string?
	if not (Room.active and Room.host == id) then return nil end
	local s = Room.settings
	if key == "rounds" then
		s.rounds = Lobby.nextRounds(s.rounds)
	elseif key == "items" then
		s.items = not s.items
	elseif key == "bots" then
		s.bots = not s.bots
	else
		return nil
	end
	touch()
	return key
end

-- May the host start now? nil, or the word for why not.
function Room.cannotStart(id: number): string?
	if not (Room.active and Room.host == id) then return "hostonly" end
	if not Room.settings.bots and #Room.members < 2 then return "need2" end
	return nil
end

-- What every client in the room is told (inside Remotes.Session's view): arrays and plain values only.
function Room.view(): any
	if not Room.active then return nil end
	local s = Room.settings
	return { code = Room.code, host = Room.host, members = table.clone(Room.members), rounds = s.rounds, items = s.items, bots = s.bots }
end

-- Every server frame. A host who has not moved for HOST_IDLE seconds while the room waits hands the room to the next
-- player (a room must never stall on one AFK kid: session.md §1 turned down ready-up votes for the same reason).
-- `where(id)` is the server's own position of a runner; `waiting`: the room is between matches.
function Room.step(now: number, where: (number) -> (number?, number?), waiting: boolean)
	if not Room.active then return end
	if Hub.KIND == "room" and now - lastKeep > KEEP then
		lastKeep = now
		Hub.keep(#Room.members)
	end
	local host = Room.host
	if not (host and waiting and #Room.members > 1) then
		hostAt = nil
		return
	end
	local x, y = where(host)
	if not (x and y) then return end
	local h = hostAt
	if not h or math.abs(h.x - x) > 0.5 or math.abs(h.y - y) > 0.5 then
		hostAt = { x = x, y = y, since = now }
	elseif now - h.since >= Config.HOST_IDLE then
		local i = table.find(Room.members, host) or 1
		Room.host, hostAt = Room.members[i % #Room.members + 1], nil
		print(("[Rotag] room: host %d stood still for %ds; %s is host"):format(host, Config.HOST_IDLE, tostring(Room.host)))
		touch()
	end
end

function Room.start()
	if Hub.KIND == "room" then -- a room server: the room is this server, from its first frame
		local rec = Hub.RECORD
		Room.active, Room.code = true, if rec and type(rec.code) == "string" then rec.code else nil
		wantHost = if rec and type(rec.host) == "number" then rec.host else nil
		game:BindToClose(function() Hub.keep(nil) end)
	end
	paint()
end

return Room
