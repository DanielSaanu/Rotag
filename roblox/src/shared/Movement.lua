--!strict
-- The runner's move rules: run, jump, double jump, wall jump, dash, and Celeste's forgiveness windows
-- (DESIGN §3 rules 14-16, 20). Pure Luau over plain tables: no Instances, no Roblox APIs. The client calls
-- step() once per physics frame and hands the velocity to the part; physics does the moving and the colliding.
-- Why it is shaped this way, and what each number does: docs/systems/movement.md. Tests: test/luau/movement.test.luau.
local Config = require(script.Parent.Config)

local Movement = {}

-- moveX is the raw stick or keys (-1..1); the presses are edges (true on the frame the button went down).
export type Input = { moveX: number, jumpPressed: boolean, jumpHeld: boolean, dashPressed: boolean, touch: boolean? }
-- Distances in studs from the runner's collider to the nearest surface on each side, nil if nothing is in reach.
-- ground is feet-to-floor (negative when sunk into it), ceiling head-to-roof, walls side-to-wall.
export type Contacts = { ground: number?, ceiling: number?, wallLeft: number?, wallRight: number? }
-- What happened this step, for juice: landed = impact speed, jump = "ground" | "wall" | "double", dash = started.
export type Events = { landed: number?, jump: string?, dash: boolean? }
export type State = {
	x: number, y: number, vx: number, vy: number, facing: number, grounded: boolean,
	coyote: number, jumpBuffer: number, jumpHold: number, holdSpeed: number,
	airJumps: number, dashes: number, dashTime: number, dashDir: number, dashCooldown: number,
	wallForce: number, wallForceDir: number, runDistance: number, stillTime: number,
	events: Events,
}

local function approach(v: number, target: number, maxDelta: number): number
	if v < target then return math.min(v + maxDelta, target) end
	return math.max(v - maxDelta, target)
end

local function sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end

-- How close a wall must be to wall-jump off it: Config's pixels in studs (Celeste: 2-3 px).
function Movement.wallReach(): number
	return Config.WALL_JUMP_REACH_PX * Config.STUDS_PER_TILE / Config.TILE
end

-- A stick is read as digital: past the deadzone is a full run, so a diagonal thumb never runs slow (rule 24).
function Movement.axis(x: number): number
	if math.abs(x) < Config.STICK_DEADZONE then return 0 end
	return sign(x)
end

function Movement.new(x: number, y: number): State
	return {
		x = x, y = y, vx = 0, vy = 0, facing = 1, grounded = false,
		coyote = 0, jumpBuffer = 0, jumpHold = 0, holdSpeed = 0,
		airJumps = Config.AIR_JUMPS, dashes = 1, dashTime = 0, dashDir = 1, dashCooldown = 0,
		wallForce = 0, wallForceDir = 0, runDistance = 0, stillTime = 0,
		events = {},
	}
end

-- Rule 15: dash and double jump come back on landing and on a wall touch. A dash in progress keeps its charge spent.
local function refresh(s: State)
	s.airJumps = Config.AIR_JUMPS
	if s.dashTime <= 0 then s.dashes = 1 end
end

-- Falling onto a floor that the remaining buffer will reach: hold the press for the landing instead of spending
-- the double jump a few frames early. This is the buffer doing its job when a double jump is still in hand.
local function landingSoon(s: State, c: Contacts): boolean
	local ground = c.ground
	return s.vy < 0 and ground ~= nil and ground <= -s.vy * s.jumpBuffer
end

local function jump(s: State, kind: string, moveX: number, awayDir: number)
	s.vy = Config.JUMP_SPEED
	s.holdSpeed = Config.JUMP_SPEED
	s.jumpHold = Config.JUMP_HOLD_WINDOW
	s.jumpBuffer = 0
	s.coyote = 0
	s.grounded = false
	s.dashTime = 0 -- a jump ends a dash and KEEPS its speed (rule 16): vx is not touched below except to add
	if kind == "ground" then
		s.vx += moveX * Config.JUMP_H_BOOST
	elseif kind == "wall" then
		-- The kick banks any speed you brought in (DESIGN §2: "wall-kick banks it"), never less than the base kick.
		s.vx = awayDir * math.max(Config.WALL_JUMP_H_SPEED, math.abs(s.vx))
		s.wallForce = Config.WALL_JUMP_FORCE_TIME
		s.wallForceDir = awayDir
		refresh(s)
	else
		s.airJumps -= 1
	end
end

-- One frame. Mutates s, returns (and stores in s.events) what happened. dt in seconds.
function Movement.step(s: State, input: Input, c: Contacts, dt: number): Events
	local ev: Events = {}
	s.events = ev
	local scale = if input.touch then Config.TOUCH_WINDOW_SCALE else 1
	local moveX = Movement.axis(input.moveX)
	s.dashCooldown = math.max(0, s.dashCooldown - dt)
	s.wallForce = math.max(0, s.wallForce - dt)
	if s.wallForce > 0 then moveX = s.wallForceDir end

	-- 1. What are we touching? Standing = a floor within GROUND_SNAP while not rising; snap the feet onto it.
	local wasGrounded = s.grounded
	local ground = c.ground
	if ground ~= nil and ground <= Config.GROUND_SNAP and s.vy <= 0 then
		s.grounded = true
		s.y -= ground
		if not wasGrounded then ev.landed = -s.vy end
		s.vy = 0
		s.coyote = Config.COYOTE_TIME * scale
		refresh(s)
	else
		s.grounded = false
		s.coyote = math.max(0, s.coyote - dt)
	end
	local wl, wr = c.wallLeft, c.wallRight
	local touchL = wl ~= nil and wl <= Config.TOUCH_DIST
	local touchR = wr ~= nil and wr <= Config.TOUCH_DIST
	if (touchL or touchR) and not s.grounded then refresh(s) end

	-- 2. Buffer the jump press: it stays live for JUMP_BUFFER and fires the first frame a jump is possible.
	if input.jumpPressed then
		s.jumpBuffer = Config.JUMP_BUFFER * scale
	else
		s.jumpBuffer = math.max(0, s.jumpBuffer - dt)
	end

	-- 3. Dash: horizontal, toward the stick or else the way we face. Gravity is off while it lasts.
	if input.dashPressed and s.dashes > 0 and s.dashCooldown <= 0 then
		local dir = if moveX ~= 0 then moveX else s.facing
		s.dashes -= 1
		s.dashTime = Config.DASH_TIME
		s.dashDir = dir
		s.dashCooldown = Config.DASH_COOLDOWN
		s.vx = dir * Config.DASH_SPEED
		s.vy = 0
		s.jumpHold = 0
		s.wallForce = 0
		ev.dash = true
	end

	-- 4. Jump, in priority order: ground (or coyote), wall, double.
	if s.jumpBuffer > 0 then
		local reach = Movement.wallReach()
		local nearL = wl ~= nil and wl <= reach
		local nearR = wr ~= nil and wr <= reach
		if s.grounded or s.coyote > 0 then
			jump(s, "ground", moveX, 0)
			ev.jump = "ground"
		elseif nearL or nearR then
			local away = if nearL and (not nearR or (wl :: number) <= (wr :: number)) then 1 else -1
			jump(s, "wall", moveX, away)
			ev.jump = "wall"
		elseif s.airJumps > 0 and not landingSoon(s, c) then
			jump(s, "double", moveX, 0)
			ev.jump = "double"
		end
	end

	-- 5. Velocity. A wall jump this frame forces the stick away from the wall from this frame on.
	if s.wallForce > 0 then moveX = s.wallForceDir end
	if s.dashTime > 0 then
		s.dashTime -= dt
		s.vx = s.dashDir * Config.DASH_SPEED
		s.vy = 0
		if s.dashTime <= 0 then s.vx = s.dashDir * Config.DASH_END_SPEED end
	else
		local mult = if s.grounded then 1 else Config.AIR_MULT
		local target = moveX * Config.RUN_SPEED
		if math.abs(s.vx) > Config.RUN_SPEED and sign(s.vx) == moveX then
			s.vx = approach(s.vx, target, Config.RUN_REDUCE * mult * dt) -- earned speed bleeds off slowly
		else
			s.vx = approach(s.vx, target, Config.RUN_ACCEL * mult * dt)
		end
		if not s.grounded then
			local g = Config.GRAVITY
			if input.jumpHeld and math.abs(s.vy) < Config.HALF_GRAVITY_BELOW then g *= 0.5 end
			local pushing = (touchL and moveX < 0) or (touchR and moveX > 0)
			local maxFall = if pushing and s.vy <= 0 then Config.WALL_SLIDE_MAX else Config.MAX_FALL
			s.vy = approach(s.vy, -maxFall, g * dt)
			if s.jumpHold > 0 then
				if input.jumpHeld then s.vy = math.max(s.vy, s.holdSpeed) else s.jumpHold = 0 end
				s.jumpHold = math.max(0, s.jumpHold - dt)
			end
		end
	end

	-- 6. Surfaces stop what pushes into them, so a stored speed never drives the part into a wall or a roof.
	local ceiling = c.ceiling
	if ceiling ~= nil and ceiling <= Config.TOUCH_DIST and s.vy > 0 then
		s.vy = 0
		s.jumpHold = 0
	end
	if touchL and s.vx < 0 then s.vx = 0 end
	if touchR and s.vx > 0 then s.vx = 0 end

	-- 7. Facing and the animation clock (the run cycle advances by distance, not time).
	if s.dashTime > 0 then
		s.facing = s.dashDir
	elseif s.wallForce > 0 then
		s.facing = s.wallForceDir
	elseif moveX ~= 0 then
		s.facing = moveX
	end
	if math.abs(s.vx) > 0.5 then
		s.stillTime = 0
		if s.grounded then s.runDistance += math.abs(s.vx) * dt end
	else
		s.stillTime += dt
	end
	return ev
end

-- Move by the velocity. The client never calls this (physics moves the part); tests and a future server check do.
function Movement.integrate(s: State, dt: number)
	s.x += s.vx * dt
	s.y += s.vy * dt
end

-- Which sprite to show (docs/systems/sprites-and-animation.md §3): idle at rest after a short grace, the run
-- frames by distance travelled, frame 0 of the run in the air and while dashing.
function Movement.spriteFor(s: State): string
	if s.dashTime > 0 or not s.grounded then return "runner_run_0" end
	if s.stillTime >= Config.IDLE_GRACE then return "runner_idle" end
	return "runner_run_" .. tostring(math.floor(s.runDistance / Config.RUN_STRIDE) % 2)
end

return Movement
