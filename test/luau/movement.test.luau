local Config = __require("Config")
local Movement = __require("Movement")

-- A tiny box world standing in for Studio's raycasts and physics, so every rule is driven through step() the way
-- the client drives it (learnings Q3): probe contacts, step, move, push out of boxes. Boxes are {x0, y0, x1, y1}.
local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local DT = 1 / 60
local REACH = Movement.wallReach()

local function probe(world, s)
	local c = {}
	local rx = { s.x - HW + 0.1, s.x, s.x + HW - 0.1 }
	local ry = { s.y - HH + 0.2, s.y, s.y + HH - 0.2 }
	for _, b in world do
		local overX = false
		for _, x in rx do if x >= b[1] and x <= b[3] then overX = true end end
		local overY = false
		for _, y in ry do if y >= b[2] and y <= b[4] then overY = true end end
		if overX and b[4] <= s.y then
			local d = (s.y - HH) - b[4]
			if d <= 8 and (c.ground == nil or d < c.ground) then c.ground = d end
		end
		if overX and b[2] >= s.y then
			local d = b[2] - (s.y + HH)
			if d <= 0.5 and (c.ceiling == nil or d < c.ceiling) then c.ceiling = d end
		end
		if overY and b[1] >= s.x then
			local d = b[1] - (s.x + HW)
			if d <= REACH + 0.1 and (c.wallRight == nil or d < c.wallRight) then c.wallRight = d end
		end
		if overY and b[3] <= s.x then
			local d = (s.x - HW) - b[3]
			if d <= REACH + 0.1 and (c.wallLeft == nil or d < c.wallLeft) then c.wallLeft = d end
		end
	end
	return c
end

local function overlaps(world, s)
	for _, b in world do
		if s.x + HW > b[1] and s.x - HW < b[3] and s.y + HH > b[2] and s.y - HH < b[4] then return b end
	end
	return nil
end

-- Physics stand-in: move x then y, and stop flush against whatever was hit.
local function move(world, s)
	s.x += s.vx * DT
	local b = overlaps(world, s)
	if b then s.x = if s.vx > 0 then b[1] - HW else b[3] + HW end
	s.y += s.vy * DT
	b = overlaps(world, s)
	if b then s.y = if s.vy > 0 then b[2] - HH else b[4] + HH end
end

local function input(t)
	t = t or {}
	return { moveX = t.moveX or 0, jumpPressed = t.jump or false, jumpHeld = t.held or t.jump or false,
		dashPressed = t.dash or false, touch = t.touch }
end

local function tick(world, s, inp)
	local ev = Movement.step(s, inp or input(), probe(world, s), DT)
	move(world, s)
	return ev
end

local function frames(world, s, n, inp)
	for _ = 1, n do tick(world, s, inp) end
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
-- A speed carried into the air, after the one frame of over-speed bleed that every airborne frame applies.
local function kept(v) return v - Config.RUN_REDUCE * Config.AIR_MULT * DT end

-- A floor whose top is y = 0 for x <= 0 (a ledge at x = 0) and a deep pit beyond it.
local LEDGE = { { -200, -10, 0, 0 } }
local FLOOR = { { -200, -10, 200, 0 } }
local function standing(world, x)
	local s = Movement.new(x, HH)
	frames(world, s, 2)
	assert(s.grounded, "the fixture runner starts on the floor")
	return s
end

-- Walk off the ledge to the right and return the state on the first frame with no floor under any ray.
local function walkOff(touch)
	local s = standing(LEDGE, -3)
	for _ = 1, 120 do
		tick(LEDGE, s, input({ moveX = 1, touch = touch }))
		if not s.grounded then return s end
	end
	error("never left the ledge")
end

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

-- Fall from height h with the double jump spent; press jump `early` seconds before touching down.
local function dropAndPress(early, keepAirJump)
	local s = Movement.new(0, 30)
	if not keepAirJump then s.airJumps = 0 end
	local pressed, jumped, landedAt = false, nil, nil
	for i = 1, 300 do
		-- predict touchdown from the probe so the press lands `early` seconds before it
		local c = probe(FLOOR, s)
		local ground = c.ground
		local fallSpeed = -s.vy
		local inp = input()
		if not pressed and ground ~= nil and fallSpeed > 0 and ground / fallSpeed <= early then
			inp = input({ jump = true })
			pressed = true
		end
		local ev = Movement.step(s, inp, c, DT)
		move(FLOOR, s)
		if ev.landed and not landedAt then landedAt = i end
		if ev.jump then jumped = { kind = ev.jump, frame = i, airJumps = s.airJumps } return jumped, landedAt end
		if landedAt and i > landedAt + 30 then break end
	end
	return jumped, landedAt
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

-- Jump from the floor holding (or tapping) jump; return the apex height of the feet.
local function apex(holdFrames)
	local s = standing(FLOOR, 0)
	local top = s.y
	for i = 1, 120 do
		tick(FLOOR, s, input({ jump = i == 1, held = i <= holdFrames }))
		top = math.max(top, s.y)
		if s.grounded and i > 2 then break end
	end
	return top - HH
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

print("movement ok")
