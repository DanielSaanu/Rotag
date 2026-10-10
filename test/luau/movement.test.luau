--!include movement_world.luau
-- The move rules: run, coyote time, jump buffer, variable jump, double jump, refresh, wall jump, dash, ceiling.
-- The sprite pick (run cycle, air poses, dash pose) is in movement_sprites.test.luau.

do -- run: immediate, never floaty (rule 20)
	local s = standing(FLOOR, 0)
	frames(FLOOR, s, 6, input({ moveX = 1 }))
	assert(near(s.vx, Config.RUN_SPEED), "top speed within 0.1 s, got " .. s.vx)
	frames(FLOOR, s, 6)
	assert(s.vx == 0, "stops within 0.1 s of letting go")
	assert(Movement.axis(0.2) == 0 and Movement.axis(0.71) == 1 and Movement.axis(-0.9) == -1,
		"stick past the deadzone is a full run, a diagonal thumb included")
end

do -- coyote time: a jump a hair after leaving the ledge is still a ground jump
	local s = walkOff()
	frames(LEDGE, s, 3, input({ moveX = 1 })) -- the press is the 5th frame off the edge: 0.083 s < 0.1
	local ev = tick(LEDGE, s, input({ jump = true }))
	assert(ev.jump == "ground", "coyote jump, got " .. tostring(ev.jump))
	assert(s.airJumps == Config.AIR_JUMPS, "a coyote jump does not spend the double jump")

	s = walkOff()
	frames(LEDGE, s, 7, input({ moveX = 1 })) -- the 9th frame: 0.15 s > 0.1
	ev = tick(LEDGE, s, input({ jump = true }))
	assert(ev.jump == "double", "past coyote time the press is the double jump, got " .. tostring(ev.jump))

	-- The press frame itself is the 7th frame off the edge: 0.117 s, past 0.1 but inside 0.1 x 1.25 (rule 23).
	s = walkOff()
	frames(LEDGE, s, 5, input({ moveX = 1 }))
	ev = tick(LEDGE, s, input({ jump = true }))
	assert(ev.jump == "double", "0.117 s off the edge is past the keyboard window")
	s = walkOff(true)
	frames(LEDGE, s, 5, input({ moveX = 1, touch = true }))
	ev = tick(LEDGE, s, input({ jump = true, touch = true }))
	assert(ev.jump == "ground", "touch gets a wider coyote window")
end

do -- jump buffer: a press just before landing jumps on landing; too early is dropped
	local j, landedAt = dropAndPress(0.05)
	assert(j and j.kind == "ground", "buffered press jumps on landing")
	assert(landedAt == j.frame, "the buffered jump fires on the landing frame itself")
	j = dropAndPress(0.15)
	assert(j == nil, "a press 0.15 s early (> 0.08 buffer) is not kept")

	-- With the double jump still in hand, a press that the buffer covers waits for the floor instead of spending it.
	j = dropAndPress(0.05, true)
	assert(j and j.kind == "ground" and j.airJumps == Config.AIR_JUMPS, "the buffer beats the double jump near the floor")
end

do -- variable jump hold and half gravity at the apex
	local tap, full = apex(1), apex(120)
	assert(tap > 1, "a tap still hops, got " .. tap)
	assert(full > tap * 2.5, ("holding jumps much higher: tap %.2f, held %.2f"):format(tap, full))
	assert(apex(30) > apex(12), "longer hold, higher jump, up to the window")
	assert(near(apex(30), full, 0.25), "holding past the 0.2 s window adds only the apex float")

	local s = Movement.new(0, 50)
	s.vy = 5
	Movement.step(s, input({ held = true }), {}, DT)
	assert(near(s.vy, 5 - Config.GRAVITY * 0.5 * DT), "half gravity near the apex while jump is held")
	s.vy = 5
	Movement.step(s, input(), {}, DT)
	assert(near(s.vy, 5 - Config.GRAVITY * DT), "full gravity once jump is let go")
end

do -- double jump, and refresh on landing (rule 15)
	local s = standing(FLOOR, 0)
	tick(FLOOR, s, input({ jump = true }))
	frames(FLOOR, s, 20, input({ held = true })) -- a full jump: still rising at 0.35 s
	local ev = tick(FLOOR, s, input({ jump = true }))
	assert(ev.jump == "double" and s.airJumps == 0, "one double jump")
	frames(FLOOR, s, 2)
	ev = tick(FLOOR, s, input({ jump = true }))
	assert(ev.jump == nil, "no triple jump")
	ev = tick(FLOOR, s, input({ dash = true }))
	assert(ev.dash and s.dashes == 0, "air dash spends the charge")
	local landed = false
	for _ = 1, 200 do
		if tick(FLOOR, s).landed then landed = true break end
	end
	assert(landed and s.grounded, "lands")
	frames(FLOOR, s, 12) -- the dash has ended
	assert(s.airJumps == Config.AIR_JUMPS and s.dashes == 1, "landing gives back the double jump and the dash")
end

do -- refresh on a wall touch (rule 15)
	local world = { { 10, -100, 12, 100 } } -- a wall's left face at x = 10, no floor
	local s = Movement.new(10 - HW - 3, 20)
	s.airJumps, s.dashes = 0, 0
	for _ = 1, 30 do tick(world, s, input({ moveX = 1 })) end
	assert(near(s.x + HW, 10, 1e-3), "pressed flush against the wall")
	assert(s.airJumps == Config.AIR_JUMPS and s.dashes == 1, "touching a wall gives back the double jump and the dash")
	assert(s.vy >= -Config.WALL_SLIDE_MAX - 1e-6, "pushing into the wall slides slowly")
end

do -- wall jump: within reach (not touching), kicks away, and the stick is read as away for a moment
	local world = { { 10, -100, 12, 100 } }
	local s = Movement.new(10 - HW - REACH * 0.5, 20)
	s.airJumps = 0
	local ev = Movement.step(s, input({ jump = true, moveX = 1 }), probe(world, s), DT)
	assert(ev.jump == "wall", "a wall within 3 px is enough to kick off")
	assert(near(s.vx, -kept(Config.WALL_JUMP_H_SPEED)) and s.vy > 0, "kicks away from the wall, upward, got " .. s.vx)
	assert(s.facing == -1, "faces away from the wall")
	assert(s.airJumps == Config.AIR_JUMPS, "a wall jump counts as a wall touch")
	move(world, s)
	frames(world, s, 5, input({ moveX = 1, held = true }))
	assert(s.vx < 0, "holding toward the wall does not cancel the kick inside the force window")

	-- dash into a near wall, then kick: the kick banks the dash speed (DESIGN §2, "wall-kick banks it")
	s = Movement.new(10 - HW - 8, 20)
	tick(world, s, input({ dash = true, moveX = 1 }))
	while (probe(world, s).wallRight or math.huge) > REACH do tick(world, s, input({ moveX = 1 })) end
	ev = tick(world, s, input({ jump = true, moveX = 1 }))
	assert(ev.jump == "wall" and near(s.vx, -kept(Config.DASH_SPEED)), "the kick keeps the dash speed, got " .. s.vx)
end

do -- two walls three tiles apart: wall-jump between them three times in a row and climb
	local world = { { -100, -10, 100, 0 }, { -8, 0, -6, 200 }, { 6, 0, 8, 200 } }
	local s = standing(world, -4)
	tick(world, s, input({ jump = true }))
	local kicks, startY = 0, s.y
	for _ = 1, 400 do
		local c = probe(world, s)
		local near_ = (c.wallLeft and c.wallLeft <= REACH) or (c.wallRight and c.wallRight <= REACH)
		-- a player: stick toward the wall ahead, press jump on arriving (not on the frames still beside the last one)
		local ev = Movement.step(s, input({ moveX = s.facing, jump = near_ and s.wallForce <= 0, held = true }), c, DT)
		move(world, s)
		if ev.jump == "wall" then kicks += 1 end
		if kicks >= 3 then break end
	end
	assert(kicks >= 3, "three wall jumps in a row, got " .. kicks)
	assert(s.y > startY, "and gained height")
end

do -- dash: fast, flat, then eases to the end speed; dash into jump keeps the speed (rule 16)
	local s = standing(FLOOR, 0)
	local ev = tick(FLOOR, s, input({ dash = true }))
	assert(ev.dash and near(s.vx, Config.DASH_SPEED), "dash speed, facing right by default")
	frames(FLOOR, s, 3)
	ev = tick(FLOOR, s, input({ jump = true, moveX = 1 }))
	assert(ev.jump == "ground", "jump out of a ground dash")
	assert(near(s.vx, kept(Config.DASH_SPEED + Config.JUMP_H_BOOST)), "the jump keeps the dash speed (plus the boost), got " .. s.vx)
	frames(FLOOR, s, 10, input({ moveX = 1, held = true }))
	assert(s.vx > Config.RUN_SPEED * 1.5, "held that way, the earned speed carries through the air, got " .. s.vx)

	-- air dash, then the double jump: same rule
	s = Movement.new(0, 40)
	tick(FLOOR, s, input({ dash = true, moveX = -1 }))
	frames(FLOOR, s, 2)
	ev = tick(FLOOR, s, input({ jump = true, moveX = -1 }))
	assert(ev.jump == "double" and near(s.vx, -kept(Config.DASH_SPEED)), "double jump out of an air dash keeps the speed")

	-- a dash with no jump ends at the end speed and the cooldown stops spamming
	s = standing(FLOOR, 0)
	tick(FLOOR, s, input({ dash = true }))
	ev = tick(FLOOR, s, input({ dash = true }))
	assert(not ev.dash, "dash cooldown")
	frames(FLOOR, s, 8)
	assert(s.vx < Config.DASH_SPEED and s.vx > 0, "eases off after the dash")
end

do -- the ceiling ends the rise
	local world = { { -100, -10, 100, 0 }, { -100, HH * 2 + 3, 100, 20 } }
	local s = standing(world, 0)
	local bonked = false
	for i = 1, 30 do
		local c = probe(world, s)
		Movement.step(s, input({ jump = i == 1, held = true }), c, DT)
		if c.ceiling and c.ceiling <= Config.TOUCH_DIST and not bonked then
			bonked = true
			assert(s.vy <= 0, "the bonk frame drops at once instead of hanging under the roof, vy " .. s.vy)
		end
		move(world, s)
	end
	assert(bonked, "the fixture reached the roof")
	assert(s.y + HH <= HH * 2 + 3 + 1e-6, "never through the roof")
	assert(s.jumpHold == 0, "a bonk ends the variable jump")
end

print("movement ok")
