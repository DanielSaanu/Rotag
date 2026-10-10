-- Shared helpers for the movement tests: a tiny box world standing in for Studio's raycasts and physics, so every
-- rule is driven through step() the way the client drives it (learnings Q3). Pulled into a test file by a line
-- `--!include movement_world.luau` (test/luau/run.js inlines it, so everything here is a local of that test).
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

