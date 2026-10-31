--!strict
-- The runner's move rules: run, jump, double jump, wall jump, dash, and Celeste's forgiveness windows
-- (DESIGN §3 rules 14-16, 20). Pure Luau over plain tables: no Instances, no Roblox APIs. The client calls
-- step() once per physics frame and hands the velocity to the part; physics does the moving and the colliding.
-- Why it is shaped this way, and what each number does: docs/systems/movement.md. Tests: test/luau/movement.test.luau.
local Config = require(script.Parent.Config)
local Grapple = require(script.Parent.Grapple) -- H25: the rope (docs/systems/grapple.md)

local Movement = {}

-- moveX is the raw stick or keys (-1..1); the presses are edges (true on the frame the button went down).
-- hold (H19, DESIGN §3 rule 44, docs/systems/items.md): "stumble" carries on at STUMBLE_SPEED x run speed toward
-- holdDir, "freeze" slides with no input as the speed bleeds to 0 over holdLeft seconds, "trap" pins. No steer, jump or
-- dash in any of them; a dash in progress ends.
-- launchX / launchY (H22, rule 15): a boost pad's launch this frame (shared/Placement.launch), ignored in a hold.
export type Input = { moveX: number, jumpPressed: boolean, jumpHeld: boolean, dashPressed: boolean, touch: boolean?,
	speedMult: number?, hold: string?, holdDir: number?, holdLeft: number?, launchX: number?, launchY: number?,
	-- H25: the grapple input (edge and held) and the anchor the aim assist picks this frame (Grapple.pick), nil: none.
	grapplePressed: boolean?, grappleHeld: boolean?, anchor: Grapple.Anchor? }
-- Distances in studs from the runner's collider to the nearest surface on each side, nil if nothing is in reach.
-- ground is feet-to-floor (negative when sunk into it), ceiling head-to-roof, walls side-to-wall.
export type Contacts = { ground: number?, ceiling: number?, wallLeft: number?, wallRight: number? }
-- What happened this step, for juice: landed = impact speed, jump = "ground" | "wall" | "double", dash = started.
export type Events = { landed: number?, jump: string?, dash: boolean?, launch: boolean?, grapple: string? }
export type State = {
	x: number, y: number, vx: number, vy: number, facing: number, grounded: boolean,
	coyote: number, jumpBuffer: number, jumpHold: number, holdSpeed: number,
	airJumps: number, dashes: number, dashTime: number, dashDir: number, dashCooldown: number, dashFloor: boolean,
	wallForce: number, wallForceDir: number, runDistance: number, runFrom: number, stillTime: number,
	sliding: boolean, events: Events,
	-- H21, for the sprite pick only: the hold in force (input.hold as last stepped), seconds since it landed, and the
	-- frame a freeze keeps (the one showing when it landed).
	hold: string?, holdTime: number, holdSprite: string,
	rope: Grapple.Rope?, grappleCooldown: number, grappleBuffer: number, -- H25: on a rope (nil: not), the two clocks
	grappleArmed: boolean, -- H25 QA r1: pressed in the air and still held: hooks the moment an anchor comes in reach
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
		airJumps = Config.AIR_JUMPS, dashes = 1, dashTime = 0, dashDir = 1, dashCooldown = 0, dashFloor = false,
		wallForce = 0, wallForceDir = 0, runDistance = 0, runFrom = 0, stillTime = 0, sliding = false,
		events = {}, hold = nil, holdTime = 0, holdSprite = "runner_idle",
		rope = nil, grappleCooldown = 0, grappleBuffer = 0, grappleArmed = false,
	}
end

-- The sprite names, built once so a frame pick never builds a string (H21, → trigger 6). The hold poses are the
-- items-art brief's contract (docs/briefs/items-art.md, "Sprite names and sizes"); shared/Snapshot puts them on the wire.
local RUN_NAMES: { string } = {}
for i = 0, Config.RUN_FRAMES - 1 do RUN_NAMES[i + 1] = "runner_run_" .. tostring(i) end
local TRAPPED = { "runner_trapped_0", "runner_trapped_1" }
local STUMBLE = { "runner_stumble_0", "runner_stumble_1", "runner_stumble_2", "runner_stumble_3", "runner_stumble_4" }
Movement.HOLD_SPRITES = { TRAPPED[1], TRAPPED[2], STUMBLE[1], STUMBLE[2], STUMBLE[3], STUMBLE[4], STUMBLE[5] }
Movement.TRAPPED_FPS = 8 -- the stuck pose's yank / lurch, ping-pong (two frames: they alternate)
-- The stumble is a roll (Danzo, 2026-10-19): trip 0.14 s, the tucked pose at 20 / 160 / 290 degrees 0.12 s each, recover
-- 0.2 s; each entry is when that frame ENDS (cumulative). The last one is Config.STUMBLE_TIME, 0.7 s.
Movement.STUMBLE_ENDS = { 0.14, 0.26, 0.38, 0.5, 0.7 }
-- H25: on the rope, until the art block draws a hang pose: the fall frame, whose front fist is raised (grapple.md §6).
Movement.SWING_SPRITE = "runner_fall"

-- The pose from motion alone (docs/systems/movement.md §3, H3): the dash pose while dashing; in the air rise, apex or
-- fall by vertical speed (a wall slide is a fall: its capped speed sits inside the apex band); on the ground idle at
-- rest after a short grace, else the RUN_FRAMES run frames by distance travelled. Also the client's fallback when the
-- sheet lacks a hold pose (H21: the game looks as it did before the art until Danzo uploads).
function Movement.motionSprite(s: State): string
	if s.rope then return Movement.SWING_SPRITE end
	if s.dashTime > 0 then return "runner_dash" end
	if not s.grounded then
		if s.sliding or s.vy < -Config.APEX_POSE_BELOW then return "runner_fall" end
		if s.vy > Config.APEX_POSE_BELOW then return "runner_jump_rise" end
		return "runner_jump_apex"
	end
	if s.stillTime >= Config.IDLE_GRACE then return "runner_idle" end
	local n = Config.RUN_FRAMES -- frame = which nth of the cycle; RUN_CYCLE alone sets the cadence
	return RUN_NAMES[math.floor((s.runDistance - s.runFrom) * n / Config.RUN_CYCLE) % n + 1]
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
	local hold = input.hold
	if hold ~= s.hold then -- a hold landed (or ended): its clock restarts; a freeze keeps the frame showing now (H21)
		if hold == "freeze" then s.holdSprite = Movement.motionSprite(s) end
		s.hold, s.holdTime = hold, 0
	elseif hold then
		s.holdTime += dt
	end
	local jumpPressed, jumpHeld, dashPressed = input.jumpPressed, input.jumpHeld, input.dashPressed
	if hold then
		moveX, jumpPressed, jumpHeld, dashPressed = 0, false, false, false
		s.dashTime, s.jumpHold, s.wallForce = 0, 0, 0
	end
	-- H25: a hold breaks the rope; letting go of the input releases it with the boost (rule 17).
	if s.rope and (hold or not input.grappleHeld) then Grapple.release(s, not hold) end
	s.grappleCooldown = math.max(0, s.grappleCooldown - dt)
	local vx0 = s.vx -- the speed a freeze slides on (H19)
	s.dashCooldown = math.max(0, s.dashCooldown - dt)
	s.wallForce = math.max(0, s.wallForce - dt)
	if s.wallForce > 0 then moveX = s.wallForceDir end

	-- 1. What are we touching? Standing = a floor within GROUND_SNAP while not rising; snap the feet onto it.
	local wasGrounded = s.grounded
	local ground = c.ground
	if ground ~= nil and ground <= Config.GROUND_SNAP and s.vy <= 0 then
		Grapple.release(s, false) -- H25: landing ends a swing
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
	if jumpPressed then
		s.jumpBuffer = Config.JUMP_BUFFER * scale
	elseif hold then
		s.jumpBuffer = 0 -- a press made before the hold does not fire when it ends
	else
		s.jumpBuffer = math.max(0, s.jumpBuffer - dt)
	end

	-- 3. Dash: horizontal, toward the stick or else the way we face. Gravity is off while it lasts.
	if dashPressed and s.dashes > 0 and s.dashCooldown <= 0 then
		Grapple.release(s, false) -- H25: a dash off the rope sets its own speed (DESIGN §2: "dash redirects it")
		local dir = if moveX ~= 0 then moveX else s.facing
		s.dashes -= 1
		s.dashTime = Config.DASH_TIME
		s.dashDir = dir
		s.dashCooldown = Config.DASH_COOLDOWN
		s.dashFloor = s.grounded -- H10: a dash started on the floor ends at run speed, not the air dash's end speed
		s.vx = dir * Config.DASH_SPEED
		s.vy = 0
		s.jumpHold = 0
		s.wallForce = 0
		ev.dash = true
	end

	-- 4. Jump, in priority order: ground (or coyote), wall, double.
	if s.rope then
		-- H25: on the rope a jump lets go with the boost and at least a full jump up (vy above it is kept, not held).
		if s.jumpBuffer > 0 then
			Grapple.release(s, true)
			s.vy = math.max(s.vy, Config.JUMP_SPEED)
			s.holdSpeed, s.jumpHold, s.jumpBuffer = Config.JUMP_SPEED, Config.JUMP_HOLD_WINDOW, 0
			ev.jump, ev.grapple = "double", "jump" -- "double": the mid-air puff on other screens, not a ground one (QA r1)
		end
	elseif s.jumpBuffer > 0 then
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

	-- 4b. A boost pad (H22, rule 15): launch along its arrow, keeping any speed you already carry that way (rule 16, as
	-- the wall kick banks it), up at the launch speed; a dash or a jump hold in progress ends; dash and double jump back.
	local lx, ly = input.launchX, input.launchY
	if lx and ly and not hold then
		Grapple.release(s, false)
		if lx ~= 0 then s.vx = sign(lx) * math.max(math.abs(lx), s.vx * sign(lx)) end
		s.vy = math.max(s.vy, ly)
		s.grounded, s.coyote, s.jumpBuffer, s.jumpHold, s.dashTime, s.wallForce = false, 0, 0, 0, 0, 0
		refresh(s)
		ev.launch = true
	end

	-- 4c. The grapple (H25, rule 17): a press is buffered GRAPPLE_BUFFER and hooks the first frame the input is still
	-- held, the aim assist has an anchor and the cooldown is over. A dash in progress ends; dash and double jump back.
	if input.grapplePressed and not hold then
		s.grappleBuffer = Config.GRAPPLE_BUFFER * scale
		if not s.grounded then s.grappleArmed = true end -- held in the air: the hook waits for an anchor (QA round 1)
	else
		s.grappleBuffer = math.max(0, s.grappleBuffer - dt)
	end
	if s.grounded or not input.grappleHeld or hold then s.grappleArmed = false end -- standing on the floor never auto-hooks
	local anchor = input.anchor
	if not s.rope and anchor and (s.grappleBuffer > 0 or s.grappleArmed) and input.grappleHeld and s.grappleCooldown <= 0
		and not hold then
		s.grappleArmed = false
		Grapple.attach(s, anchor)
		s.grappleBuffer, s.jumpBuffer, s.jumpHold, s.dashTime, s.wallForce, s.coyote = 0, 0, 0, 0, 0, 0
		s.grounded = false
		if Config.GRAPPLE_REFRESH then refresh(s) end
		ev.grapple = "attach"
	end

	-- 5. Velocity. A wall jump this frame forces the stick away from the wall from this frame on.
	if s.wallForce > 0 then moveX = s.wallForceDir end
	s.sliding = false -- for the sprite pick only: the wall-slide fall cap is in force this frame
	if s.rope then
		Grapple.swing(s, moveX, dt) -- H25: the rope's own step replaces the run and the fall
	elseif s.dashTime > 0 then
		s.dashTime -= dt
		s.vx = s.dashDir * Config.DASH_SPEED
		s.vy = 0
		if s.dashTime <= 0 then
			-- H10: a floor chain gains only the bursts; an air dash keeps 80 (a jump out of either keeps 120, rule 16)
			s.vx = s.dashDir * (if s.dashFloor then Config.DASH_END_SPEED_FLOOR else Config.DASH_END_SPEED)
		end
	else
		local mult = if s.grounded then 1 else Config.AIR_MULT
		local top = Config.RUN_SPEED * (input.speedMult or 1) -- the chaser ramp (Tag.chaserBoost, rule 4)
		local target = moveX * top
		if math.abs(s.vx) > top and sign(s.vx) == moveX then
			s.vx = approach(s.vx, target, Config.RUN_REDUCE * mult * dt) -- earned speed bleeds off slowly
		else
			s.vx = approach(s.vx, target, Config.RUN_ACCEL * mult * dt)
		end
		if not s.grounded then
			local g = Config.GRAVITY
			if jumpHeld and math.abs(s.vy) < Config.HALF_GRAVITY_BELOW then g *= 0.5 end
			local pushing = (touchL and moveX < 0) or (touchR and moveX > 0)
			s.sliding = pushing and s.vy <= 0
			local maxFall = if s.sliding then Config.WALL_SLIDE_MAX else Config.MAX_FALL
			s.vy = approach(s.vy, -maxFall, g * dt)
			if s.jumpHold > 0 then
				if jumpHeld then s.vy = math.max(s.vy, s.holdSpeed) else s.jumpHold = 0 end
				s.jumpHold = math.max(0, s.jumpHold - dt)
			end
		end
	end
	-- 5b. A hold (H19) overrides the run: gravity above still applies. A trap pins x; caught low in the air you drop
	-- onto it (never rise: a jump in progress is cut), so nobody hangs in mid-air until freed (QA round 2).
	if hold == "trap" then
		s.vx, s.vy = 0, if s.grounded then 0 else math.min(s.vy, 0)
	elseif hold == "stumble" then
		s.vx = (if (input.holdDir or 0) ~= 0 then sign(input.holdDir :: number) else s.facing)
			* Config.RUN_SPEED * Config.STUMBLE_SPEED
	elseif hold == "freeze" then
		s.vx = approach(vx0, 0, math.abs(vx0) * dt / math.max(input.holdLeft or dt, dt))
	end

	-- 6. Surfaces stop what pushes into them, so a stored speed never drives the part into a wall or a roof.
	local vx6, vy6 = s.vx, s.vy
	local ceiling = c.ceiling
	if ceiling ~= nil and ceiling <= Config.TOUCH_DIST and s.vy > 0 then
		s.vy = 0
		s.jumpHold = 0
	end
	if touchL and s.vx < 0 then s.vx = 0 end
	if touchR and s.vx > 0 then s.vx = 0 end
	if s.rope and (s.vx ~= vx6 or s.vy ~= vy6) then Grapple.stopped(s) end -- H25: a wall or roof checks the swing

	-- 7. Facing and the animation clock (the run cycle advances by distance, not time).
	if s.dashTime > 0 then
		s.facing = s.dashDir
	elseif s.wallForce > 0 then
		s.facing = s.wallForceDir
	elseif s.rope then
		if math.abs(s.vx) > 1 then s.facing = sign(s.vx) end -- on the rope you face the way you swing
	elseif moveX ~= 0 then
		s.facing = moveX
	end
	if math.abs(s.vx) > 0.5 then
		s.stillTime = 0
		if s.grounded then s.runDistance += math.abs(s.vx) * dt end
	else
		s.stillTime += dt -- at rest the cycle restarts, so a run from rest opens on frame 0 (A1)
		if s.stillTime >= Config.IDLE_GRACE then s.runFrom = s.runDistance end
	end
	return ev
end

-- Move by the velocity. The client never calls this (physics moves the part); tests and a future server check do.
function Movement.integrate(s: State, dt: number)
	s.x += s.vx * dt
	s.y += s.vy * dt
end

-- Which sprite to show (docs/systems/movement.md §3): a hold first (H21: trapped yank / lurch at TRAPPED_FPS, the
-- stumble's roll by time since it landed (STUMBLE_ENDS), a freeze the frame it landed on), else motionSprite.
function Movement.spriteFor(s: State): string
	local hold, t = s.hold, s.holdTime
	if hold == "trap" then return TRAPPED[math.floor(t * Movement.TRAPPED_FPS) % 2 + 1] end
	if hold == "stumble" then
		local ends = Movement.STUMBLE_ENDS
		for i = 1, #ends - 1 do
			if t < ends[i] then return STUMBLE[i] end
		end
		return STUMBLE[#ends] -- recover, and held there should the hold outlast the table
	end
	if hold == "freeze" then return s.holdSprite end
	return Movement.motionSprite(s)
end

return Movement
