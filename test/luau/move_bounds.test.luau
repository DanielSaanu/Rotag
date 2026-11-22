-- H44 (docs/systems/trust.md §12): a client owns its body, so it can park it anywhere. Seen in Studio: Roblox turns a
-- NaN CFrame into (0, -1e6, 0) on the client and that is what the server reads; a parked first sample of a fresh body
-- was trusted, and the next snap-back rebuilt the body under the destroy height, which ended the round ("everybody
-- left"). MoveCheck.inBounds decides what may be believed at all; MoveCheck.reject marks a runner suspect without
-- moving its check or its snap-back spot. server/MoveGuard wires both (and starts each check where the server built
-- the body); that half is Studio-tested, this pins the rules.
local Config = __require("Config")
local MoveCheck = __require("MoveCheck")
local Maps = __require("Maps")
local Lobby = __require("Lobby")
local Tutorial = __require("Tutorial")

local nan, inf = 0 / 0, math.huge

do -- what is never believed
	for _, p in { { nan, 1 }, { 1, nan }, { nan, nan }, { inf, 1 }, { -inf, 1 }, { 1, inf }, { 1, -inf },
		{ 0, -1e6 }, -- Roblox's parked NaN part, measured
		{ 1e9, 1 }, { -1e9, 1 }, { 1, 1e9 },
		{ 0, Config.MOVE_BOUND_LOW - 0.01 }, { Config.MOVE_BOUND_X + 0.01, 0 }, { 0, Config.MOVE_BOUND_HIGH + 0.01 } } do
		assert(not MoveCheck.inBounds(p[1], p[2]), ("(%s, %s) must be out of bounds"):format(tostring(p[1]), tostring(p[2])))
	end
	-- the bound sits above Roblox's FallenPartsDestroyHeight (-500 in this place): a snap-back spot is always a place
	-- the server can build a body at
	assert(Config.MOVE_BOUND_LOW > -500, "the low bound is above the destroy height")
end

do -- everything honest is inside: every map's blocks, the lobby and the room, the tutorial course
	for _, name in Maps.NAMES do
		for _, b in Maps.static(Maps.get(name)) do
			assert(MoveCheck.inBounds(b[1], b[2]) and MoveCheck.inBounds(b[3], b[4]), name .. ": a box out of bounds")
		end
	end
	for _, area in Lobby.NAMES do
		for slot = 0, 3 do
			local x, y = Lobby.spawnAt(area, slot)
			assert(MoveCheck.inBounds(x, y), area .. " spawn out of bounds")
			local a = Lobby.AREAS[area]
			assert(MoveCheck.inBounds(a.x - a.half, a.y) and MoveCheck.inBounds(a.x + a.half, a.y + 66), area)
		end
	end
	for _, r in Tutorial.ROOMS do
		assert(MoveCheck.inBounds(Tutorial.X + r.x1, 0), "a tutorial room out of bounds")
	end
	-- the world as Studio measured it (2026-11-22, every collidable part): x -1022..1520, y -126..126
	assert(MoveCheck.inBounds(-1022, -126) and MoveCheck.inBounds(1520, 126), "Studio's measured world")
	-- a fall that leaves the map is still believed long enough to be judged (a runner falling at the cap for 3 s)
	assert(MoveCheck.inBounds(0, -126 - Config.MAX_FALL * 3), "a long fall out of the map")
end

do -- reject: suspect, and the check's position and snap-back spot do not move
	local c = MoveCheck.new(60, 1.8, 0)
	MoveCheck.reject(c, 0.1)
	assert(c.suspect, "suspect after a rejected sample")
	assert(c.x == 60 and c.y == 1.8 and c.trustX == 60 and c.trustY == 1.8, "the check and its spot stay put")
	-- the next believable sample is judged from the last believable one: standing still is clean...
	local ok = MoveCheck.step(c, 60, 1.8, 0.2)
	assert(ok, "standing where it was is no violation")
	assert(c.suspect, "...but still suspect inside MOVE_CLEAR_TIME")
	assert(MoveCheck.step(c, 60, 1.8, 0.1 + Config.MOVE_CLEAR_TIME + 0.01), "clean")
	assert(not c.suspect, "trusted again once MOVE_CLEAR_TIME passes clean")
	-- a later reject never shortens a suspect window already running
	local d = MoveCheck.new(0, 0, 0)
	MoveCheck.step(d, 100, 0, 0.01) -- a teleport: suspect until 1.01
	MoveCheck.reject(d, 0.005)
	assert(d.clearAt >= 0.01 + Config.MOVE_CLEAR_TIME, "reject keeps the longer window")
end

do -- the caught Studio sequence, at the rule's level: a check started where the server built the body (60, 1.8),
	-- then a client that parks every frame at (0, -1e6) for 6 s. Every parked sample is dropped (never stepped), so
	-- the snap-back spot is the build spot the whole time, never the parked one.
	local c = MoveCheck.new(60, 1.8, 0)
	local stored = 0
	for i = 1, 360 do
		local t = i / 60
		if MoveCheck.inBounds(0, -1e6) then
			stored += 1
			MoveCheck.step(c, 0, -1e6, t)
		else
			MoveCheck.reject(c, t)
		end
	end
	assert(stored == 0, "no parked sample stored")
	assert(c.trustX == 60 and c.trustY == 1.8, "the snap-back spot is where the server built the body")
	assert(c.suspect, "suspect while parking")
	-- before H44 the first sample of a fresh body started the check: a parked one became the trusted spot
	local old = MoveCheck.new(0, -1e6, 0)
	assert(old.trustY == -1e6, "the old way trusted the parked spot (why MoveGuard.bodyBuilt exists)")
end

print("move_bounds: ok")
