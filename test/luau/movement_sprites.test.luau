--!include movement_world.luau
-- The sprite pick (Movement.spriteFor): the run cycle by distance, the rest pose, the air poses by vy, the dash pose.
-- The move rules themselves are in movement.test.luau.

do -- the run cycle advances by distance, the rest pose after a short grace (A1)
	local s = standing(FLOOR, 0)
	frames(FLOOR, s, 10)
	assert(Movement.spriteFor(s) == "runner_idle", "idle at rest")
	-- The sheet has eight run frames (contact, down, pass, up, twice: H3). Change this with the art, never to pass.
	assert(Config.RUN_FRAMES == 8, "eight run frames in the sheet")
	local order, cycleStarts = {}, {}
	for _ = 1, 100 do -- 75 studs at top speed: over three cycles
		tick(FLOOR, s, input({ moveX = 1 }))
		local name = Movement.spriteFor(s)
		if name ~= order[#order] then
			table.insert(order, name)
			if name == "runner_run_0" then table.insert(cycleStarts, s.runDistance) end
		end
	end
	for i, name in order do
		local want = "runner_run_" .. tostring((i - 1) % Config.RUN_FRAMES)
		assert(name == want, "frame " .. i .. " of the cycle is " .. want .. ", got " .. name)
	end
	assert(#order >= 2 * Config.RUN_FRAMES, "at least two full cycles seen, got " .. #order .. " frames")
	-- Cadence is set by the cycle length alone: more frames make it smoother, never faster or slower.
	local perTick = Config.RUN_SPEED * DT
	for i = 2, #cycleStarts do
		local len = cycleStarts[i] - cycleStarts[i - 1]
		assert(math.abs(len - Config.RUN_CYCLE) <= perTick + 1e-6, "one cycle covers RUN_CYCLE studs, got " .. len)
	end
	assert(#cycleStarts >= 3, "three cycle starts measured")
	local before = s.runDistance
	tick(FLOOR, s)
	assert(Movement.spriteFor(s) ~= "runner_idle", "no snap to idle inside the grace")
	frames(FLOOR, s, 12)
	assert(Movement.spriteFor(s) == "runner_idle", "rest pose after the grace")
	assert(s.runDistance >= before, "distance never runs backwards")
	tick(FLOOR, s, input({ moveX = 1 }))
	assert(Movement.spriteFor(s) == "runner_run_0", "a run from rest starts on frame 0, got " .. Movement.spriteFor(s))
end

do -- the air poses follow vy (rise, apex, fall), a wall slide is a fall, a dash is the dash pose (H3)
	local A = Config.APEX_POSE_BELOW
	local function airPoses(world, s, inp) -- every airborne frame until the landing, after the first tick
		local seen = {}
		for _ = 1, 200 do
			tick(world, s, inp)
			if s.grounded then break end
			local name = Movement.spriteFor(s)
			local want = if s.vy > A then "runner_jump_rise" elseif s.vy < -A then "runner_fall" else "runner_jump_apex"
			assert(name == want, "vy " .. s.vy .. " shows " .. want .. ", got " .. name)
			if name ~= seen[#seen] then table.insert(seen, name) end
		end
		assert(s.grounded, "the fixture lands")
		return table.concat(seen, " ")
	end
	local arc = "runner_jump_rise runner_jump_apex runner_fall"
	local s = standing(FLOOR, 0)
	tick(FLOOR, s, input({ jump = true }))
	assert(Movement.spriteFor(s) == "runner_jump_rise", "the take-off frame rises")
	assert(airPoses(FLOOR, s, input({ held = true })) == arc, "a held jump: rise, apex, fall, once each")
	assert(string.sub(Movement.spriteFor(s), 1, 11) == "runner_run_" or Movement.spriteFor(s) == "runner_idle",
		"landed: back to a ground pose")
	frames(FLOOR, s, 12)
	tick(FLOOR, s, input({ jump = true }))
	assert(airPoses(FLOOR, s, input()) == arc, "a tap hop: the same arc")
	-- Walking off a ledge starts at vy 0, the top of the arc: a short apex, then the fall. Never a rise.
	local step = { LEDGE[1], { 0, -30, 200, -20 } } -- the ledge, and a floor 20 studs below it
	s = standing(step, -3)
	for _ = 1, 30 do tick(step, s, input({ moveX = 1 })) if not s.grounded then break end end
	assert(Movement.spriteFor(s) == "runner_jump_apex", "the first frame off the ledge is the top of the arc")
	local off = airPoses(step, s, input({ moveX = 1 }))
	assert(off == "runner_jump_apex runner_fall", "walked off: apex, then fall, got " .. off)
	-- A wall slide is capped at WALL_SLIDE_MAX, inside the apex band, so it is picked by the slide, not by vy.
	assert(Config.WALL_SLIDE_MAX < A, "the fixture needs the slide cap inside the apex band")
	local wall = { { 10, -100, 12, 100 } }
	s = Movement.new(10 - HW - 3, 20)
	for _ = 1, 30 do tick(wall, s, input({ moveX = 1 })) end
	assert(s.sliding and s.vy < 0 and s.vy >= -Config.WALL_SLIDE_MAX - 1e-6, "sliding down the wall")
	assert(Movement.spriteFor(s) == "runner_fall", "a wall slide shows the fall pose")
	-- The dash pose, on the ground and in the air (where vy 0 would otherwise read as the apex).
	s = standing(FLOOR, 0)
	tick(FLOOR, s, input({ dash = true }))
	assert(Movement.spriteFor(s) == "runner_dash", "a ground dash shows the dash pose")
	frames(FLOOR, s, math.ceil(Config.DASH_TIME / DT) + 1, input({ moveX = 1 }))
	assert(s.dashTime <= 0 and string.sub(Movement.spriteFor(s), 1, 11) == "runner_run_", "dash over: running again")
	s = Movement.new(0, 40) -- a fresh runner in the air: the ground dash above is still cooling down (H6)
	frames(FLOOR, s, 10)
	assert(not s.grounded and s.vy < 0, "the fixture is in the air")
	tick(FLOOR, s, input({ dash = true }))
	assert(s.vy == 0 and Movement.spriteFor(s) == "runner_dash", "an air dash shows the dash pose, not the apex")
	tick(FLOOR, s, input({ jump = true }))
	assert(Movement.spriteFor(s) == "runner_jump_rise", "a jump out of the dash rises")
end

do -- H21: the hold poses (docs/briefs/items-art.md "Sprite names and sizes"): trapped ping-pong at 8 fps, the stumble's
	-- roll (trip 0.14 s, three tucked frames 0.12 s each, recover 0.2 s), a freeze keeps the frame it landed on;
	-- motionSprite is the fallback
	local function held(kind, left, moveX)
		local i = input({ moveX = moveX or 0 })
		i.hold, i.holdDir, i.holdLeft = kind, 1, left or 1
		return i
	end
	local names = table.concat(Movement.HOLD_SPRITES, " ")
	assert(names == "runner_trapped_0 runner_trapped_1 runner_stumble_0 runner_stumble_1 runner_stumble_2"
		.. " runner_stumble_3 runner_stumble_4",
		"the brief's hold pose names, got " .. names)

	-- Trapped: frame 0 on the frame it lands, then a swap every 1/8 s (two frames ping-pong), whatever the motion does.
	local s = standing(FLOOR, 0)
	frames(FLOOR, s, 10, input({ moveX = 1 }))
	local runs, last, start = {}, nil, 0
	for k = 1, 60 do -- one second
		tick(FLOOR, s, held("trap"))
		local name = Movement.spriteFor(s)
		assert(name == "runner_trapped_0" or name == "runner_trapped_1", "trapped shows a trapped frame, got " .. name)
		if k == 1 then assert(name == "runner_trapped_0", "the trap lands on frame 0, got " .. name) end
		if name ~= last then
			if last then table.insert(runs, (k - start) * DT) end
			last, start = name, k
		end
	end
	assert(#runs >= 7, "eight holds a second: at least seven swaps in one second, got " .. #runs)
	for i, len in runs do assert(math.abs(len - 1 / 8) <= DT + 1e-6, "swap " .. i .. " after 1/8 s, got " .. len) end
	assert(Movement.motionSprite(s) == "runner_idle", "the fallback under the trap is the motion pose: pinned, idle")
	tick(FLOOR, s, input())
	assert(Movement.spriteFor(s) == "runner_idle", "freed: back to the motion pose")
	tick(FLOOR, s, held("trap"))
	assert(Movement.spriteFor(s) == "runner_trapped_0", "a second trap starts its clock again on frame 0")

	-- Stumble: the roll, each frame once, for 0.14 / 0.12 / 0.12 / 0.12 / 0.2 s (Config.STUMBLE_TIME), from a full run.
	local ends = Movement.STUMBLE_ENDS
	assert(math.abs(ends[#ends] - Config.STUMBLE_TIME) < 1e-9, "the roll fills the stumble exactly")
	local function at(t)
		local r = Movement.new(0, 0)
		r.hold, r.holdTime = "stumble", t
		return Movement.spriteFor(r)
	end
	assert(at(0) == "runner_stumble_0", "frame 0 at t = 0, got " .. at(0))
	assert(at(0.45) == "runner_stumble_3", "frame 3 at t = 0.45, got " .. at(0.45))
	assert(at(0.6) == "runner_stumble_4", "frame 4 at t = 0.6, got " .. at(0.6))
	assert(at(5) == "runner_stumble_4", "held on recover past the table, got " .. at(5))
	s = standing(FLOOR, 0)
	frames(FLOOR, s, 30, input({ moveX = 1 }))
	local seen, lens = {}, {}
	for _ = 1, math.floor(Config.STUMBLE_TIME / DT + 0.5) do
		tick(FLOOR, s, held("stumble"))
		local name = Movement.spriteFor(s)
		if name ~= seen[#seen] then table.insert(seen, name) table.insert(lens, 0) end
		lens[#lens] += DT
	end
	local order = table.concat(seen, " ")
	assert(order == "runner_stumble_0 runner_stumble_1 runner_stumble_2 runner_stumble_3 runner_stumble_4",
		"trip, the roll, recover: got " .. order)
	for i, want in { 0.14, 0.12, 0.12, 0.12, 0.2 } do
		assert(math.abs(lens[i] - want) <= DT + 1e-6, "stumble frame " .. (i - 1) .. " holds " .. want .. " s, got " .. lens[i])
	end
	assert(string.sub(Movement.motionSprite(s), 1, 11) == "runner_run_", "the fallback under a stumble runs (it carries on)")

	-- Freeze: the frame showing when it lands stays for the whole hold, though the slide moves the run clock on.
	s = standing(FLOOR, 0)
	frames(FLOOR, s, 17, input({ moveX = 1 }))
	local before = Movement.spriteFor(s)
	assert(string.sub(before, 1, 11) == "runner_run_", "the fixture is mid-run")
	local motionMoved = false
	for k = 1, 60 do
		tick(FLOOR, s, held("freeze", 1 - (k - 1) * DT))
		assert(Movement.spriteFor(s) == before, "frozen on " .. before .. ", got " .. Movement.spriteFor(s))
		if Movement.motionSprite(s) ~= before then motionMoved = true end
	end
	assert(motionMoved, "the fixture slides far enough that the motion pose would have changed")
	tick(FLOOR, s, input())
	assert(Movement.spriteFor(s) == Movement.motionSprite(s), "thawed: the motion pose again")
	-- In the air: frozen on the rise, it keeps the rise while it falls.
	s = standing(FLOOR, 0)
	frames(FLOOR, s, 12)
	tick(FLOOR, s, input({ jump = true }))
	tick(FLOOR, s, input({ held = true }))
	assert(Movement.spriteFor(s) == "runner_jump_rise", "the fixture is rising")
	for _ = 1, 50 do tick(FLOOR, s, held("freeze", 1)) end
	assert(s.vy <= 0 or s.grounded, "the fixture has come down")
	assert(Movement.spriteFor(s) == "runner_jump_rise", "frozen mid-rise keeps the rise, got " .. Movement.spriteFor(s))
end

print("movement sprites ok")
