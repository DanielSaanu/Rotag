--!strict
-- The walk-in lobby (H36/H37; docs/systems/lobby.md): the place a player lands in, where every choice is a door you
-- stand in, and the private room behind HOST A ROOM. Pure Luau: the two areas' geometry (blocks, doors, the room's
-- setting blocks), which door a point is in, the stand-still-to-choose rule (the dwell), what a door asks the server
-- for, the still camera, and a room code's shape. server/LobbyMap builds the parts, server/Session and server/Room
-- judge every request against the SERVER's own position of the player; client/Lobby only draws and asks.
-- Units are studs. Each area's coordinates are local to its origin (its floor's top, centre). Tests: lobby.test.luau.
local Config = require(script.Parent.Config)

local Lobby = {}

export type Door = {
	id: string, x0: number, y0: number, x1: number, y1: number,
	name: string,        -- the sign: one or two words
	line: string,        -- the caption a player gets when near
	inside: string,      -- the few characters painted in the doorway
	color: { number },
	big: boolean?,       -- the one obvious default (QUICK MATCH, START)
}
export type Area = {
	name: string, x: number, y: number, -- the origin in the world (the floor's top, centre)
	half: number,                       -- the floor runs -half..half between the end walls
	view: number, viewY: number,        -- the still camera: studs of world top to bottom, and its centre above the floor
	blocks: { { any } },                -- { name, x0, y0, x1, y1 }: solid parts, as a map's blocks
	doors: { Door },
	spawn: { x: number, y: number },
	zones: { { any } },                 -- { label, x0, x1, color, y }: a name plate centred under a group of doors
	bumps: { { any } },                 -- { id, x0, y0, x1, y1, label }: setting blocks a runner jumps into
}

Lobby.SEATS_X = { -18, -6, 6, 18 } -- the room's four seat marks
Lobby.CODE_LEN = 4
Lobby.ROUNDS = { 1, 3, 5 } -- what the room's ROUNDS block steps through

-- Danzo, 2026-11-18, of the first build: "the colors are too similar, I can't even really tell the difference
-- between the green and gold". Under the stage's bloom a neon lime and a neon gold both glow yellow. These five are
-- far apart in hue AND lightness: a deep orange, a pure green, a hot pink, an ice blue, white.
local GOLD, LIME, PINK, CYAN, WHITE = { 255, 120, 20 }, { 40, 235, 90 }, { 255, 80, 200 }, { 60, 190, 255 }, { 238, 241, 255 }
Lobby.COLORS = { gold = GOLD, lime = LIME, pink = PINK, cyan = CYAN, white = WHITE }

local function shell(half: number, top: number): { { any } }
	return {
		{ "Floor", -half - 24, -8, half + 24, 0 },
		{ "WallLeft", -half - 4, 0, -half, top },
		{ "WallRight", half, 0, half + 4, top },
	}
end

-- The lobby (Danzo, the same day: "too small, not enough space, you can't stand anywhere; I intended the lobby to be
-- full of random players"; "locker and play on the bottom floor while practice and play with friends are higher
-- up"; and he likes it asymmetric). 112 studs of floor, two levels, the whole of it on one zoomed-out screen:
--   downstairs  LOCKER (left), the spawn and open floor, QUICK MATCH (the big one), more open floor to the right
--   upstairs    PRACTICE on the left deck, HOST A ROOM and ENTER A CODE on the right deck
-- A step beside QUICK MATCH leads up to each deck: one jump to the step, one to the deck.
local lobbyBlocks = shell(56, 66)
table.insert(lobbyBlocks, { "DeckLeft", -52, 17, -15, 18 })
table.insert(lobbyBlocks, { "DeckRight", 23, 17, 54, 18 })
table.insert(lobbyBlocks, { "StepLeft", -12, 8, -6, 9 })
table.insert(lobbyBlocks, { "StepRight", 14, 8, 20, 9 })

local lobbyBumps: { { any } } = {}
local roomBumps: { { any } } = {
	{ "rounds", -23, 4.5, -11, 9.5, "ROUNDS" },
	{ "items", -6, 4.5, 6, 9.5, "ITEMS" },
	{ "bots", 11, 4.5, 23, 9.5, "BOTS" },
}
local AREAS: { [string]: Area } = {
	lobby = {
		name = "lobby", x = 600, y = 0, half = 56, view = 64, viewY = 26, blocks = lobbyBlocks,
		spawn = { x = -24, y = 0 }, bumps = lobbyBumps,
		-- Only a GROUP gets a name plate (seen in Studio: a plate under PRACTICE's deck ran into the LOCKER's sign, and
		-- a one-door "group" says nothing its sign does not).
		zones = { { "PLAY NOW", -4, 12, LIME, 0 }, { "PLAY WITH FRIENDS", 26, 50, PINK, 17 } },
		doors = {
			{ id = "locker", x0 = -42, y0 = 0, x1 = -32, y1 = 9, name = "LOCKER", inside = "SKINS", color = GOLD,
				line = "Dress your runner. Spin the wheel." },
			{ id = "quick", x0 = -4, y0 = 0, x1 = 12, y1 = 12.5, name = "QUICK MATCH", inside = "PLAY", color = LIME, big = true,
				line = "Play now with other runners." },
			{ id = "practice", x0 = -40, y0 = 18, x1 = -28, y1 = 27, name = "PRACTICE", inside = "SOLO", color = CYAN,
				line = "Just you and bots. Nothing counts." },
			{ id = "host", x0 = 26, y0 = 18, x1 = 36, y1 = 27, name = "HOST A ROOM", inside = "+ ROOM", color = PINK,
				line = "Make a room. Friends join with your code." },
			{ id = "code", x0 = 40, y0 = 18, x1 = 50, y1 = 27, name = "ENTER A CODE", inside = "1 2 3 4", color = PINK,
				line = "Join a friend's room with their code." },
		},
	},
	room = {
		-- Seen from as far back as the lobby (seen in Studio at a round's zoom: the callouts sat on the wall's code).
		name = "room", x = 800, y = 0, half = 40, view = 64, viewY = 26, blocks = shell(40, 66),
		spawn = { x = -18, y = 0 }, zones = {}, bumps = roomBumps,
		doors = {
			{ id = "leave", x0 = -38, y0 = 0, x1 = -28, y1 = 9, name = "LOBBY", inside = "EXIT", color = WHITE,
				line = "Leave the room. Back to the lobby." },
			{ id = "start", x0 = 26, y0 = 0, x1 = 38, y1 = 12.5, name = "START", inside = "GO", color = LIME, big = true,
				line = "The host stands here to start the match." },
		},
	},
}
Lobby.AREAS = AREAS
Lobby.NAMES = { "lobby", "room" }

-- The area the world point x is in ("lobby" | "room"), or nil: the arena, or nowhere.
function Lobby.areaAt(x: number): string?
	for _, name in Lobby.NAMES do
		local a = Lobby.AREAS[name]
		if math.abs(x - a.x) <= a.half + 8 then return name end
	end
	return nil
end

-- Where a body spawns in `area` (its centre, world): on the start mark, `slot` (0-based) steps along it.
function Lobby.spawnAt(area: string, slot: number?): (number, number)
	local a = Lobby.AREAS[area]
	local step = ((slot or 0) % 6) * 2.5
	return a.x + a.spawn.x + step, a.y + a.spawn.y + Config.RUNNER_HEIGHT / 2 + 0.05
end

function Lobby.door(area: string, id: string): Door?
	for _, d in Lobby.AREAS[area].doors do
		if d.id == id then return d end
	end
	return nil
end

-- The door the world point (x, y) is inside (a runner's centre), within `slack` studs; nil between doors.
function Lobby.doorAt(area: string, x: number, y: number, slack: number?): Door?
	local a = Lobby.AREAS[area]
	local s = slack or 0
	local lx, ly = x - a.x, y - a.y
	for _, d in a.doors do
		if lx >= d.x0 - s and lx <= d.x1 + s and ly >= d.y0 - s and ly <= d.y1 + s then return d end
	end
	return nil
end

-- Is the world point within `slack` studs of door `id`? The SERVER's check of a request against its own position of
-- the player (a snapshot is a few studs stale at run speed, so it allows a little).
function Lobby.inDoor(area: string, id: string, x: number, y: number, slack: number): boolean
	local a, d = Lobby.AREAS[area], Lobby.door(area, id)
	if not d then return false end
	local lx, ly = x - a.x, y - a.y
	return lx >= d.x0 - slack and lx <= d.x1 + slack and ly >= d.y0 - slack and ly <= d.y1 + slack
end

-- The nearest door within `reach` studs to the side of (x, y), for the caption; a door you are in wins.
function Lobby.doorNear(area: string, x: number, y: number, reach: number): Door?
	local a = Lobby.AREAS[area]
	local lx, ly = x - a.x, y - a.y
	local best: Door?, gap = nil, reach
	for _, d in a.doors do
		if ly >= d.y0 - 1 and ly <= d.y1 + 1 then
			local g = math.max(0, d.x0 - lx, lx - d.x1)
			if g <= gap then best, gap = d, g end
		end
	end
	return best
end

-- The setting block the point is in (the room's ROUNDS / ITEMS / BOTS), within `slack`; a runner on the floor under
-- one is not in it (its centre is 1.75 up, a block starts at 4.5): a jump reaches, even a tapped one.
function Lobby.bumpAt(area: string, x: number, y: number, slack: number?): string?
	local a = Lobby.AREAS[area]
	local s = slack or 0
	local lx, ly = x - a.x, y - a.y
	for _, b in a.bumps do
		if lx >= b[2] - s and lx <= b[4] + s and ly >= b[3] - s and ly <= b[5] + s then return b[1] end
	end
	return nil
end

-- Standing in a door to choose it. One state per player (the client's): `door` is the door it is in, `t` how long,
-- `armed` whether a door may answer. A door only fires after `need` unbroken seconds inside it; leaving resets the
-- clock (running past does nothing); and once any door has fired, NO door answers until the runner has stood
-- outside every door (so nothing fires twice, and a queued runner standing in QUICK MATCH is never asked to leave).
export type Dwell = { door: string?, t: number, armed: boolean }
function Lobby.newDwell(): Dwell return { door = nil, t = 0, armed = true } end

-- Returns fired (this is the frame the door was chosen) and the bar's fill, 0..1 (0 when no door answers).
function Lobby.dwell(d: Dwell, door: string?, dt: number, need: number): (boolean, number)
	if door ~= d.door then
		d.door, d.t = door, 0
		if door == nil then d.armed = true end
		return false, 0
	end
	if door == nil or not d.armed or need <= 0 then return false, 0 end
	d.t += dt
	if d.t >= need then
		d.armed, d.t = false, 0
		return true, 1
	end
	return false, d.t / need
end

-- How long door `id` must be held: leaving the queue is the one slow door (a deliberate two seconds).
function Lobby.hold(id: string, queued: boolean): number
	return if id == "quick" and queued then Config.LEAVE_HOLD else Config.DOOR_HOLD
end

-- What choosing door `id` asks for: a Remotes.Menu op, or "locker" / "pad" (the client's own screens).
function Lobby.ask(id: string, queued: boolean): string
	if id == "quick" then return if queued then "sit" else "play" end
	if id == "locker" then return "locker" end
	if id == "code" then return "pad" end
	return id -- "practice" | "host" | "leave" | "start"
end

-- The still camera: the whole area on one screen when the screen is wide enough (`aspect` = width / height), else
-- it slides with the runner and stops at the end walls. Returns the world point the camera centres on and how many
-- studs of world it shows top to bottom (the lobby is seen from further back than a round is).
function Lobby.camera(area: string, x: number, aspect: number): (number, number, number)
	local a = Lobby.AREAS[area]
	local slide = math.max(0, a.half + 4 - a.view * aspect / 2)
	return a.x + math.clamp(x - a.x, -slide, slide), a.y + a.viewY, a.view
end

-- A room code as typed: exactly CODE_LEN digits, or nil.
function Lobby.code(s: any): string?
	if type(s) ~= "string" or #s ~= Lobby.CODE_LEN or string.match(s, "^%d+$") == nil then return nil end
	return s
end

-- The ROUNDS block's next value.
function Lobby.nextRounds(n: number): number
	local i = table.find(Lobby.ROUNDS, n) or 0
	return Lobby.ROUNDS[i % #Lobby.ROUNDS + 1]
end

return Lobby
