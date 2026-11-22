-- The door requests (H37, docs/systems/lobby.md §4): what Remotes.Menu carries and how each is judged. ONE string
-- from a client: "play", "sit", "practice", "host", "code:<4 digits>", "start", "leave", "set:<rounds|items|bots>";
-- H41: "tutorial", "tut:skip", "tut:tag" (server/Course judges those).
-- Trust (→ N4): the sender is the Player; a rate gap per player (longer for the two requests that may reserve a
-- server, and for code tries: 4 digits is 10 000 guesses); the SERVER's own position of the player decides whether
-- it is where the request is made (the lobby, the room, near that door); only the room's host starts or changes it.
-- Anything else is dropped unread. A client that lies only queues, seats or moves ITSELF. The state is
-- server/Session's, handed in as `api`; the room is server/Room.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local Room = require(script.Parent:WaitForChild("Room"))
local Course = require(script.Parent:WaitForChild("Course")) -- H41: "tutorial" and "tut:*" (docs/systems/tutorial.md)

local Doors = {}

export type Api = {
	playing: { [number]: boolean },   -- queued or seated
	practice: { [number]: boolean },  -- in through the PRACTICE door
	launching: { [number]: number },  -- being taken to another server, since when
	idle: () -> boolean,              -- the flow is in its lobby and no round is due
	quick: () -> number?,             -- a short countdown is running (PRACTICE, a host's START)
	setQuick: (number, { number }) -> (), -- ... for these players only (nobody else is seated in that match)
	where: (number) -> (number?, number?),
	sit: (Player) -> (),              -- out of the queue or the match
	home: (Player) -> (),             -- a fresh body where this player waits (its room, else the lobby)
	note: (Player, string) -> (),     -- a word for that player's banner
	changed: () -> (),
	log: (string) -> (),
}

local MENU_GAP = 0.4 -- seconds between two requests from one player
local HOST_GAP = 8 -- ... between two HOST A ROOM / PRACTICE requests (each may reserve a server)
local NEAR = 8 -- studs of slack round a door (the server's position is a snapshot old; a run covers 3 in that)
local lastMenu, lastHost, lastCode: { [number]: number } = {}, {}, {}

function Doors.forget(id: number)
	lastMenu[id], lastHost[id], lastCode[id] = nil, nil, nil
end

-- Somebody is being sent to another server: until it happens (or fails) it asks for nothing else.
local function away(api: Api, player: Player): (string) -> ()
	local id = player.UserId
	api.launching[id] = os.clock()
	return function(why: string)
		api.launching[id] = nil
		if player.Parent == Players then api.note(player, why) end
		api.changed()
	end
end

function Doors.ask(api: Api, player: Player, op: any)
	local now = os.clock()
	local id = player.UserId
	if type(op) ~= "string" or #op > 16 or now - (lastMenu[id] or -math.huge) < MENU_GAP then return end
	lastMenu[id] = now
	if api.launching[id] then return end
	if op == "tutorial" or string.sub(op, 1, 4) == "tut:" then
		if Course.ask(api, player, op) then api.changed() end
		return
	end
	local x, y = api.where(id)
	local area = if x then Lobby.areaAt(x) else nil
	local function at(door: string): boolean
		return x ~= nil and y ~= nil and area ~= nil and Lobby.inDoor(area, door, x, y, NEAR)
	end
	local playing, practice = api.playing, api.practice
	-- Studio's log says why a request did nothing (as the tag's "claim dropped" lines do): never sent to the client.
	local function refused()
		api.log(("%s asked %q, refused: at %s (%s, %s), in %s, room %s"):format(player.Name, op, tostring(area),
			tostring(x and math.floor(x)), tostring(y and math.floor(y)), tostring(playing[id] == true), tostring(Room.has(id))))
	end
	local idle = api.idle()
	if op == "play" then
		if playing[id] or Room.has(id) or area ~= "lobby" then refused() return end
		playing[id] = true
		api.log(player.Name .. " is in the queue")
	elseif op == "sit" then
		if not playing[id] then refused() return end
		api.sit(player)
	elseif op == "practice" or op == "host" then
		if Room.has(id) or area ~= "lobby" or not at(op) or now - (lastHost[id] or -math.huge) < HOST_GAP then refused() return end
		lastHost[id] = now
		playing[id], practice[id] = nil, nil -- out of the queue first: one choice at a time
		if Hub.MODE == "hub" then
			Hub.open(if op == "host" then "room" else "practice", player, away(api, player))
		elseif op == "practice" then
			if not idle then
			api.note(player, "busy")
			return
		end
			playing[id], practice[id] = true, true
			api.setQuick(now + Config.QUICK_START, { id })
		elseif Room.create(player) then
			api.home(player)
			api.log(player.Name .. " hosts room " .. tostring(Room.code))
		else
			api.note(player, "busy")
			return
		end
	elseif string.sub(op, 1, 5) == "code:" then
		local code = Lobby.code(string.sub(op, 6))
		if not code or Room.has(id) or area ~= "lobby" or now - (lastCode[id] or -math.huge) < Config.CODE_GAP then refused() return end
		lastCode[id] = now
		if Hub.MODE == "hub" then
			playing[id] = nil
			Hub.join(player, code, away(api, player))
		elseif not (Room.active and Room.code == code) then
			api.note(player, "noroom")
			return
		elseif not Room.add(player) then
			api.note(player, "full")
			return
		else
			playing[id], practice[id] = nil, nil
			api.home(player)
		end
	elseif op == "start" then
		if not (Room.has(id) and area == "room" and idle and api.quick() == nil) then refused() return end
		local why = Room.cannotStart(id)
		if why then
			api.note(player, why)
			return
		end
		for _, m in Room.members do playing[m] = true end
		api.setQuick(now + Config.QUICK_START, Room.members)
		api.log(player.Name .. " started room " .. tostring(Room.code))
	elseif op == "leave" then
		if not (Room.has(id) and idle) then refused() return end
		playing[id] = nil
		Room.remove(id)
		if Hub.KIND == "room" then Hub.home({ player }) else api.home(player) end
	elseif string.sub(op, 1, 4) == "set:" then
		if not (Room.has(id) and area == "room" and idle and api.quick() == nil) then refused() return end
		if not Room.set(id, string.sub(op, 5)) then
			api.note(player, "hostonly")
			return
		end
	else
		return
	end
	api.changed()
end

return Doors
