--!strict
-- The tutorial course (H41, docs/systems/tutorial.md): a short run that teaches by doing, one move per room, then
-- "you are IT: tag the runner". Pure Luau: the course's blocks and anchor, its rooms and what finishes each lesson,
-- the target runner's flee rule, and the server's check of a tag on it. server/Course builds the parts, runs the
-- target and judges every request; client/Tutorial only draws the words and asks. Units are studs; the course's
-- coordinates are local to Tutorial.X (its floor's top at y 0). Every number was driven through the real Movement
-- in test/luau/tutorial.test.luau: each room is doable with its move and (where it says so) not without it.
local Config = require(script.Parent.Config)
local Tag = require(script.Parent.Tag)

local Tutorial = {}

Tutorial.X = 1100 -- the course's origin in the world: past the room (x 800), inside the snapshot's +-2047
Tutorial.BOT_ID = -900 -- the target runner (Studio's test players are -1, -2, ...; match bots are -1000 and below)
Tutorial.ANCHOR_ID = 201 -- its one anchor (the map's are 1..n; the snapshot's anchor byte goes to 255)
Tutorial.FIRST_JOIN = true -- a player whose saved profile has never finished a match starts here (SKIP is always up)
Tutorial.BOT_SPEED = 0.9 -- the target's run speed x this: "it" (IT_SPEED 1.1) closes on it at ~9 studs/s
Tutorial.BOT_TIRED = 0.6 -- ... and this after BOT_TIRE seconds of being chased: everybody catches it in the end
Tutorial.BOT_TIRE = 8
Tutorial.BOT_FREEZE = 1.5 -- seconds the target stands still after a tag (rule 1's freeze, shown)
Tutorial.FUSE = 20 -- the IT lesson's fuse, seconds: drawn by the client only (it teaches the hurry; nothing burns)
Tutorial.HOME_AFTER = 4 -- seconds from the tag to the lobby (the celebration)

local W, H = Config.RUNNER_WIDTH, Config.RUNNER_HEIGHT
local HH = H / 2
local TOP = 96 -- the end walls' and the tall blocks' height: nothing played reaches it

-- { name, x0, y0, x1, y1 }: solid parts, as a map's blocks.
local blocks: { { any } } = {
	{ "WallStart", -8, -8, -4, TOP },
	{ "Floor", -8, -8, 220, 0 },                 -- RUN, JUMP, DOUBLE JUMP, WALL JUMP, the dash's run-up
	{ "Hurdle", 56, 0, 64, 8 },                  -- JUMP: 2 tiles; one jump clears 14
	-- DOUBLE JUMP: 4.5 tiles (one jump 14.25, two 28.5), 8 wide and solid. A second press BESIDE its face is a wall
	-- kick, not a double jump (Movement: the wall comes first): the take-off line 24-18 studs back says where to
	-- jump from so the second press comes before the face (tutorial.md §3; measured in tutorial.test)
	{ "Ledge", 100, 0, 132, 18 },
	{ "Pillar", 144, 6, 148, 64 },               -- WALL JUMP: walked under; the shaft is 3 tiles (148..160)
	{ "Tower", 160, 0, 188, 40 },                -- ... 10 tiles: over a double jump, so the walls are the way up
	{ "Tunnel", 212, 8, 256, TOP },              -- DASH: a 2-tile roof over the pit (a jump bonks) and up to the
	                                             -- top, so the tower's drop lands before it and nobody walks over
	{ "PitWallL", 216, -44, 220, 0 },
	{ "PitBottom", 220, -44, 248, -40 },         -- ... the pit: a fall here starts the room again (server/Course)
	{ "FloorDash", 248, -44, 268, 0 },
	{ "GrappleDip", 268, -16, 308, -12 },        -- GRAPPLE: a safe dip, 3 tiles deep (a jump gets out either side)
	{ "FloorIt", 308, -16, 416, 0 },             -- IT: the chase room
	{ "Crate", 360, 0, 368, 6 },                 -- ... one hop in the middle
	{ "WallEnd", 416, -16, 420, TOP },
}
Tutorial.TAKEOFF = { 76, 82 } -- the double jump's painted take-off line (local x)

export type Room = {
	id: string,        -- the lesson: "run" | "jump" | "double" | "wall" | "dash" | "grapple" | "it"
	x0: number, x1: number, -- the room's span (local x)
	start: number,     -- where a fall puts you back (local x, on the floor)
	goal: { number }?, -- { x0, y0, x1, y1 }: the runner's centre there, standing, finishes the lesson
	kill: { number }?, -- { x0, x1, below }: a centre under `below` between x0 and x1 is a fall (back to start)
}
local rooms: { Room } = {
	{ id = "run", x0 = -4, x1 = 52, start = 6, goal = { 36, 0, 52, 4 } },
	{ id = "jump", x0 = 52, x1 = 86, start = 46, goal = { 68, 0, 78, 4 } },
	{ id = "double", x0 = 86, x1 = 136, start = 80, goal = { 100, 18, 132, 22 } },
	{ id = "wall", x0 = 136, x1 = 196, start = 136, goal = { 160, 40, 188, 44 } },
	{ id = "dash", x0 = 196, x1 = 266, start = 202, goal = { 249, 0, 266, 4 }, kill = { 220, 248, -6 } },
	{ id = "grapple", x0 = 266, x1 = 312, start = 266 }, -- finished by a swing (Tutorial.update), not a place
	{ id = "it", x0 = 312, x1 = 416, start = 316 },      -- finished by the server's confirmed tag
}
Tutorial.ROOMS = rooms
Tutorial.BLOCKS = blocks
Tutorial.ANCHORS = { { x = 288, y = 16, id = Tutorial.ANCHOR_ID } } -- over the dip; in reach from its near edge
Tutorial.SPAWN = { x = rooms[1].start, y = 0 }
Tutorial.CHASE = { lo = 318, hi = 412, home = 384 } -- the target's room (local x): where it may run, where it waits
Tutorial.LEFT, Tutorial.RIGHT = -8, 420

local function inBox(b: { number }, x: number, y: number): boolean
	return x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4]
end

-- Is world x on the course?
function Tutorial.inCourse(x: number): boolean
	local lx = x - Tutorial.X
	return lx >= Tutorial.LEFT - 4 and lx <= Tutorial.RIGHT + 4
end

-- The room (its index) world x is in, or nil off the course.
function Tutorial.roomAt(x: number): number?
	if not Tutorial.inCourse(x) then return nil end
	local lx = x - Tutorial.X
	for i, r in rooms do
		if lx < r.x1 or i == #rooms then return i end
	end
	return nil
end

-- Where a body is built for room `i` (world, its centre): the course's start for the first.
function Tutorial.startOf(i: number): (number, number)
	return Tutorial.X + rooms[i].start, HH + 0.05
end

-- Has the runner at world (x, y) fallen in a room's pit? Returns that room's index (the server puts it back).
function Tutorial.fell(x: number, y: number): number?
	local i = Tutorial.roomAt(x)
	local k = i and rooms[i].kill
	if not (i and k) then return nil end
	local lx = x - Tutorial.X
	if lx >= k[1] and lx <= k[2] and y < k[3] then return i end
	return nil
end

-- A player's way through (the client's): the lesson it is on, which are done, which were walked past.
export type Progress = { step: number, done: { [string]: boolean }, passed: { [string]: boolean }, hooked: boolean }
function Tutorial.new(): Progress
	return { step = 1, done = {}, passed = {}, hooked = false }
end

-- One physics step of the local runner at world (x, y). `ev`: Movement's events this step; `rope`: on a rope now.
-- Returns "done" and the lesson's id the step it is finished, "passed" and the id of a lesson walked past (the
-- next room reached first: never a loop back, rule 19), else nil. The IT lesson is finished by Tutorial.tagged.
function Tutorial.update(p: Progress, x: number, y: number, grounded: boolean, ev: any?, rope: boolean): (string?, string?)
	local i = Tutorial.roomAt(x)
	if not i or p.step > #rooms then return nil, nil end
	local r = rooms[p.step]
	if i > p.step and r.id ~= "it" then
		p.passed[r.id] = true
		p.step += 1
		p.hooked = false
		return "passed", r.id
	end
	local lx, ly = x - Tutorial.X, y
	if r.id == "grapple" then
		if ev and ev.grapple == "attach" then p.hooked = true end -- the course has one anchor: this room's
		if p.hooked and not rope then
			p.done[r.id], p.step, p.hooked = true, p.step + 1, false
			return "done", r.id
		end
	elseif r.goal and grounded and inBox(r.goal, lx, ly) then
		p.done[r.id], p.step = true, p.step + 1
		return "done", r.id
	end
	return nil, nil
end

-- The server confirmed the tag: the last lesson is done.
function Tutorial.tagged(p: Progress)
	p.done.it = true
	p.step = #rooms + 1
end

function Tutorial.current(p: Progress): Room? return rooms[p.step] end

-- Two runner boxes touching: the tag's own shape and reach (shared/Tag, H40), plus `slack` studs.
function Tutorial.touching(ax: number, ay: number, bx: number, by: number, slack: number): boolean
	return Tag.overlaps(ax, ay, bx, by, slack)
end

-- The server's check of a tag on the target: the player's newest position (px, py) against where the target was
-- at any recorded moment from `since` on (`hist`: { t, x, y }, oldest first), within the tag's reach + `reach`. What the player saw
-- is the target a snapshot delay and a ping behind; the window covers that, its cap stops a stale claim.
function Tutorial.caught(px: number, py: number, hist: { { number } }, since: number, reach: number): boolean
	for k = #hist, 1, -1 do
		local h = hist[k]
		if h[1] < since then break end
		if Tutorial.touching(px, py, h[2], h[3], reach) then return true end
	end
	return false
end

-- The target's buttons this frame (the server steps it through shared/Movement in the course's BoxWorld, as a bot).
-- `b`: its Movement state; (cx, cy): the nearest chaser in its room (world), nil for none; `chased`: seconds since a
-- chase began; `m`: its memory ({ turn = seconds left of a turn-and-pass }). It runs away; cornered with the chaser
-- close it turns and hops past (a beginner meets it there) until it tires; with nobody near it walks back to the
-- middle.
function Tutorial.flee(b: any, cx: number?, cy: number?, chased: number, m: any, dt: number, input: any)
	local lo, hi, home = Tutorial.X + Tutorial.CHASE.lo, Tutorial.X + Tutorial.CHASE.hi, Tutorial.X + Tutorial.CHASE.home
	input.jumpPressed, input.jumpHeld, input.dashPressed = false, false, false
	input.speedMult = if chased >= Tutorial.BOT_TIRE then Tutorial.BOT_TIRED else Tutorial.BOT_SPEED
	m.turn = math.max(0, m.turn - dt)
	if not (cx and cy) then
		local dx = home - b.x
		input.moveX = if math.abs(dx) < 2 then 0 else math.sign(dx)
		return
	end
	local away = if b.x >= cx then 1 else -1
	local d = math.abs(b.x - cx)
	local cornered = (away > 0 and b.x > hi - 8) or (away < 0 and b.x < lo + 8)
	if m.turn > 0 then
		input.moveX = -m.dir
		input.jumpHeld = true
		return
	end
	if cornered and d < 16 and chased < Tutorial.BOT_TIRE then -- turn and pass the chaser with one jump (never a
		-- double: it must stay catchable); tired, it stops trying and is caught in its corner
		m.turn, m.dir = 0.6, away
		input.moveX, input.jumpPressed, input.jumpHeld = -away, b.grounded, true
	elseif cornered then
		input.moveX = 0 -- wait in the corner until it is close
	elseif d > 44 then
		input.moveX = 0 -- far enough: catch its breath
	else
		input.moveX = away
	end
	-- the crate: hop it rather than stand against it
	if input.moveX ~= 0 and b.grounded then
		local cx0, cx1 = Tutorial.X + 360, Tutorial.X + 368
		local ahead = if input.moveX > 0 then cx0 - (b.x + W / 2) else (b.x - W / 2) - cx1
		if ahead >= 0 and ahead < 3 then input.jumpPressed, input.jumpHeld = true, true end
	end
end

return Tutorial
