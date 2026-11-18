-- The walk-in lobby (H37, docs/systems/lobby.md): shared/Lobby. Where the doors are, standing in one to choose it,
-- what each asks for, the still camera, a room code's shape; and shared/Session's per-match round count.
local Config = __require("Config")
local Lobby = __require("Lobby")
local Session = __require("Session")

local L, R = Lobby.AREAS.lobby, Lobby.AREAS.room
local FEET = Config.RUNNER_HEIGHT / 2 -- a standing runner's centre above the floor

do -- the areas: far from the arena and from each other, inside the snapshot's range
	assert(Lobby.areaAt(0) == nil and Lobby.areaAt(176) == nil and Lobby.areaAt(-176) == nil, "the arena is no lobby")
	assert(Lobby.areaAt(L.x) == "lobby" and Lobby.areaAt(L.x - L.half) == "lobby" and Lobby.areaAt(L.x + L.half + 4) == "lobby", "the lobby")
	assert(Lobby.areaAt(R.x) == "room" and Lobby.areaAt(R.x + 40) == "room", "the room")
	assert(Lobby.areaAt((L.x + R.x) / 2) == nil, "between them: neither")
	assert(R.x + R.half + 24 < 2047, "inside the snapshot stream's +-2047 studs")
	assert(L.x + L.half + 12 < R.x - R.half - 12 and L.x - L.half - 12 > 400, "the areas are apart, and far from the arena")
	local sx, sy = Lobby.spawnAt("lobby", 0)
	assert(Lobby.areaAt(sx) == "lobby" and sy > 0 and sy < 3, "a body spawns on the lobby floor")
	assert(Lobby.doorAt("lobby", sx, sy) == nil, "... and not in a door (nothing is chosen for you)")
	for slot = 0, 11 do
		local x, y = Lobby.spawnAt("room", slot)
		assert(Lobby.doorAt("room", x, y) == nil and Lobby.bumpAt("room", x, y) == nil, "nor in the room")
		x, y = Lobby.spawnAt("lobby", slot)
		assert(Lobby.doorAt("lobby", x, y) == nil, "nobody spawns in a lobby door")
	end
end

do -- the doors: on the floor, inside the walls, apart from each other; QUICK MATCH the biggest and nearest the spawn
	for _, name in Lobby.NAMES do
		local a = Lobby.AREAS[name]
		for i, d in a.doors do
			assert(d.x0 > -a.half and d.x1 < a.half, d.id .. " is between the walls")
			local stands = false -- on the floor or a deck: a solid top right under the whole doorway
			for _, b in a.blocks do
				if b[5] == d.y0 and b[2] <= d.x0 and b[4] >= d.x1 then stands = true end
			end
			assert(stands, d.id .. " stands on something solid")
			assert(d.x1 - d.x0 >= 4 * Config.RUNNER_WIDTH, d.id .. " is wide enough to stop in")
			assert(#d.name <= 14 and select(2, string.gsub(d.name, "%S+", "")) <= 3, d.id .. "'s sign is a few words")
			for j, e in a.doors do
				if i < j then assert(d.x1 + 1 < e.x0 or e.x1 + 1 < d.x0 or d.y1 < e.y0 or e.y1 < d.y0, d.id .. " and " .. e.id .. " overlap") end
			end
			local mid, feet = a.x + (d.x0 + d.x1) / 2, a.y + d.y0 + FEET
			assert(Lobby.doorAt(name, mid, feet) == d, "standing in " .. d.id .. " is being in it")
			assert(Lobby.doorAt(name, a.x + d.x0 - 0.5, feet) == nil, "just outside is not")
			assert(Lobby.inDoor(name, d.id, a.x + d.x0 - 3, feet, 4), "... but is, for the server's check with its slack")
			assert(not Lobby.inDoor(name, d.id, a.x + d.x0 - 12, feet, 4), "a door away is not")
			assert(Lobby.doorNear(name, a.x + d.x0 - 0.9, feet, 5) == d, "the caption comes from just outside")
			-- the name plate under a group of doors is centred on doors (Danzo: "the labels were off centred")
			for _, z in a.zones do
				if z[2] <= d.x0 and z[3] >= d.x1 and z[5] <= d.y0 then
					local firstX, lastX = math.huge, -math.huge
					for _, e in a.doors do
						if e.y0 == d.y0 and e.x0 >= z[2] and e.x1 <= z[3] then firstX, lastX = math.min(firstX, e.x0), math.max(lastX, e.x1) end
					end
					assert(firstX == z[2] and lastX == z[3], z[1] .. " spans exactly its doors")
				end
			end
		end
	end
	local quick = Lobby.door("lobby", "quick") :: any
	for _, d in L.doors do
		if d.id ~= "quick" then
			assert(quick.x1 - quick.x0 > d.x1 - d.x0 and quick.y1 - quick.y0 > d.y1 - d.y0, "QUICK MATCH is the biggest door")
		end
	end
	assert(quick.y0 == 0 and (Lobby.door("lobby", "locker") :: any).y0 == 0, "PLAY and the LOCKER are downstairs")
	for _, id in { "practice", "host", "code" } do assert((Lobby.door("lobby", id) :: any).y0 > 12, id .. " is upstairs") end
	-- upstairs is not downstairs: a runner under a deck is not in the door on it, nor the other way round
	assert(Lobby.doorAt("lobby", L.x - 34, L.y + FEET) == Lobby.door("lobby", "locker"), "under PRACTICE: the LOCKER")
	assert(Lobby.doorAt("lobby", L.x + 28, L.y + FEET) == nil, "under HOST A ROOM: open floor")
	-- the way up is nowhere near QUICK MATCH (QA round 1: a missed jump beside it queued the reviewer)
	for _, b in L.blocks do
		if string.sub(b[1], 1, 4) == "Step" then
			assert(b[2] >= quick.x1 + 20 or b[4] <= quick.x0 - 20, b[1] .. " is far from QUICK MATCH")
			assert(b[4] - b[2] >= 10, b[1] .. " is wide enough to land on")
		end
	end
	-- open floor to stand on (Danzo: "you can't stand anywhere"): downstairs, outside every door
	local free = 2 * L.half
	for _, d in L.doors do if d.y0 == 0 then free -= d.x1 - d.x0 end end
	assert(free >= 80, "at least 80 studs of the lobby's floor is not a door")
	-- the way up: a step one full jump high, then the deck one more; neither step is under a deck (no head bump)
	local full = Config.JUMP_SPEED ^ 2 / (2 * Config.GRAVITY) -- a tapped jump; a held one is far more (movement.md)
	assert(full > 0, "jump")
	for _, b in L.blocks do
		if string.sub(b[1], 1, 4) == "Step" then
			assert(b[5] <= 14 and 18 - b[5] <= 14, b[1] .. " is a held jump from the floor and from the deck")
			for _, k in L.blocks do
				if string.sub(k[1], 1, 4) == "Deck" then assert(b[4] <= k[2] or b[2] >= k[4], b[1] .. " is not under " .. k[1]) end
			end
		end
	end
end

do -- the room's blocks: only a jump reaches one
	for _, b in R.bumps do
		local mid = R.x + (b[2] + b[4]) / 2
		assert(Lobby.bumpAt("room", mid, R.y + FEET) == nil, "standing under " .. b[1] .. " does nothing")
		assert(Lobby.bumpAt("room", mid, R.y + 5) == b[1], "jumping into it does")
		assert(Lobby.doorAt("room", mid, R.y + FEET) == nil, "no door under a block")
	end
	-- even a tapped jump lifts the centre JUMP_SPEED^2 / (2 g) (a held one far more): the block is in reach
	local rise = Config.JUMP_SPEED ^ 2 / (2 * Config.GRAVITY)
	assert(FEET + rise > 4.5, "one tapped jump reaches a block")
end

do -- standing in a door: a full, unbroken hold; running past does nothing; one choice per visit
	local d = Lobby.newDwell()
	local fired, frac = Lobby.dwell(d, nil, 0.1, 1)
	assert(not fired and frac == 0, "outside: nothing")
	fired, frac = Lobby.dwell(d, "quick", 0.1, 1) -- the frame it enters
	assert(not fired and frac == 0, "entering starts the clock at zero")
	for _ = 1, 5 do fired, frac = Lobby.dwell(d, "quick", 0.1, 1) end
	assert(not fired and math.abs(frac - 0.5) < 1e-6, "half a second in: half the bar")
	fired = Lobby.dwell(d, nil, 0.1, 1) -- ran out
	fired, frac = Lobby.dwell(d, "quick", 0.1, 1)
	for _ = 1, 8 do fired, frac = Lobby.dwell(d, "quick", 0.1, 1) end
	assert(not fired and frac < 0.9, "leaving reset the clock: 0.8 s after coming back is not a choice")
	local more = 0
	repeat
		fired = Lobby.dwell(d, "quick", 0.1, 1)
		more += 1
	until fired or more > 5
	assert(fired and more <= 3, "a whole second: chosen (0.1 ten times is a hair under 1)")
	for _ = 1, 50 do
		local again, f = Lobby.dwell(d, "quick", 0.1, 1)
		assert(not again and f == 0, "staying in the door never chooses twice, and shows no bar")
	end
	-- straight from one door into the next without standing outside: still not armed
	for _ = 1, 30 do assert(not Lobby.dwell(d, "locker", 0.1, 1), "a neighbour door does not fire either") end
	Lobby.dwell(d, nil, 0.1, 1)
	Lobby.dwell(d, "quick", 0.1, 2)
	local n = 0
	repeat
		fired = Lobby.dwell(d, "quick", 0.1, 2)
		n += 1
	until fired or n > 100
	assert(fired and n >= 20, "after stepping out, the door answers again; leaving the queue takes its two seconds")
	-- a run through at full speed (the door is 14 studs: 0.31 s at 45, 0.12 s in a dash) never chooses
	local q = Lobby.door("lobby", "quick") :: any
	local across = (q.x1 - q.x0) / Config.RUN_SPEED
	assert(across < Config.DOOR_HOLD * 0.5, "running through QUICK MATCH takes under half the hold")
end

do -- what each door asks for
	assert(Lobby.hold("quick", false) == Config.DOOR_HOLD and Lobby.hold("quick", true) == Config.LEAVE_HOLD, "the holds")
	assert(Config.LEAVE_HOLD > Config.DOOR_HOLD, "leaving the queue is the slow one")
	assert(Lobby.hold("host", true) == Config.DOOR_HOLD, "every other door is the quick one, queued or not")
	assert(Lobby.ask("quick", false) == "play" and Lobby.ask("quick", true) == "sit", "QUICK MATCH: in, then out")
	assert(Lobby.ask("locker", true) == "locker" and Lobby.ask("code", false) == "pad", "the client's own screens")
	for _, id in { "practice", "host", "leave", "start" } do assert(Lobby.ask(id, false) == id, id) end
end

do -- the still camera
	local x, y, view = Lobby.camera("lobby", L.x - 30, 16 / 9)
	assert(math.abs(x - (L.x - (L.half + 4 - L.view * 16 / 18))) < 1e-6, "16:9: it slides a little")
	assert(math.abs(x - L.x) < 4 and y == L.y + L.viewY and view == L.view, "... a few studs: nearly the whole lobby, still")
	x = Lobby.camera("lobby", L.x - 30, 19.5 / 9)
	assert(x == L.x, "a phone held sideways: the whole lobby on one screen, still")
	x = Lobby.camera("lobby", L.x - 50, 4 / 3)
	assert(x == L.x - (L.half + 4 - L.view * 4 / 6), "a narrow screen slides with the runner and stops at the wall")
	x = Lobby.camera("lobby", L.x + 3, 4 / 3)
	assert(x == L.x + 3, "... following in between")
	assert(L.view > Config.CAMERA_VIEW_HEIGHT, "the lobby is seen from further back than a round")
	assert(L.viewY + L.view / 2 > 27 + 6 and L.viewY - L.view / 2 < 0, "the upstairs signs and the floor are on screen")
	-- at the spawn, on a 16:9 screen, every door is on screen (nothing to scroll to find)
	local sx = Lobby.spawnAt("lobby", 0)
	local cx = Lobby.camera("lobby", sx, 16 / 9)
	for _, d in L.doors do
		assert(L.x + d.x0 > cx - L.view * 16 / 18 and L.x + d.x1 < cx + L.view * 16 / 18, d.id .. " is on screen from the spawn")
	end
	local rx, _, rv = Lobby.camera("room", R.x + 20, 16 / 9)
	assert(rx == R.x + math.clamp(20, 0, math.max(0, R.half + 4 - R.view * 16 / 18)) and rv == R.view, "the room's camera")
end

do -- a room code
	assert(Lobby.code("4827") == "4827" and Lobby.code("0000") == "0000", "four digits")
	for _, bad in { "482", "48270", "48a7", "", " 482", "4 27", 4827, {}, true } do
		assert(Lobby.code(bad) == nil, "not a code: " .. tostring(bad))
	end
	assert(Lobby.nextRounds(1) == 3 and Lobby.nextRounds(3) == 5 and Lobby.nextRounds(5) == 1, "ROUNDS steps 1, 3, 5")
	assert(Lobby.nextRounds(7) == 1, "an odd value falls back into the list")
end

do -- a match's round count is the state's (a room host's setting), not the constant
	local s = Session.new()
	assert(s.rounds == Config.MATCH_ROUNDS and Session.view(s, 0).rounds == Config.MATCH_ROUNDS, "the default")
	s.rounds = 1
	Session.tick(s, 0, 1)
	assert(Session.tick(s, Config.LOBBY_TIME, 1) == "start", "round 1")
	Session.begin(s, { 1, 2 })
	Session.finish(s, 1, 100)
	assert(Session.tick(s, 100 + Config.ROUND_GAP, 1) == "podium", "a one-round match goes straight to the podium")
	assert(Session.view(s, 0).rounds == 1, "and the view says so")
end

print("lobby: ok")
