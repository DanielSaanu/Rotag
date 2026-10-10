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
	tick(FLOOR, s, input({ jump = true }))
	frames(FLOOR, s, 10, input({ held = true }))
	assert(not s.grounded, "the fixture is in the air")
	tick(FLOOR, s, input({ dash = true }))
	assert(s.vy == 0 and Movement.spriteFor(s) == "runner_dash", "an air dash shows the dash pose, not the apex")
	tick(FLOOR, s, input({ jump = true }))
	assert(Movement.spriteFor(s) == "runner_jump_rise", "a jump out of the dash rises")
end

print("movement sprites ok")
