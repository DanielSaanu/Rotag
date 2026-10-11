--!strict
-- Another runner's pose, read from its replicated position alone (docs/systems/players.md §3, H11 option a). The
-- owning client knows its real Movement state; every other screen only sees the body Roblox replicates. This module
-- rebuilds the few fields Movement.spriteFor reads (speed, grounded, dash, slide, facing, the run clock) from the
-- position each frame plus a ground distance and a wall flag the caller probes, so the pose and the position come
-- from the same replicated stream and can never drift apart. Pure Luau; tests: test/luau/remote_pose.test.luau.
local Config = require(script.Parent.Config)
local Movement = require(script.Parent.Movement)

local RemotePose = {}

export type Pose = {
	x: number, y: number, vx: number, vy: number, facing: number, grounded: boolean, airTime: number,
	stillTime: number, runDistance: number, runFrom: number, dashTime: number, sliding: boolean, started: boolean,
	held: number,
}

local VEL_SETTLE = 0.03 -- seconds per e-fold on the measured speed: smooths replication steps, ~2 frames of lag
-- Seen in Studio (H11): a replicated position can land in steps, held for 2-3 render frames and then jumping ahead.
-- A frame with no change is held over (its time joins the next real move) until HOLD has passed, so a step does not
-- read as stop-start (a dash flickering with the run pose); only HOLD with no change at all means standing still.
local HOLD = 0.1
local TELEPORT = 20 -- studs in one step, or faster than TELEPORT_SPEED: a respawn, a reset, a server move; speed
-- restarts at 0 (seen in Studio: a 6-stud server move read as a dash for a moment)
local TELEPORT_SPEED = 2 * Config.DASH_SPEED
local GROUND_TOL = Config.GROUND_SNAP * 2 -- feet within this of a floor (and not rising) = standing
local RISING = 5 -- studs/s up: above this the runner has left the floor, whatever the probe says
-- A dash moves at DASH_SPEED (120) with vy held at 0 and ends at 80 or less; run and jump speeds stay under 70.
local DASH_ABOVE = (Config.DASH_SPEED + Config.DASH_END_SPEED) / 2
local JUMP_SEEN = Config.JUMP_SPEED / 2 -- vy crossing this upward = a jump started
local COYOTE_SEEN = 0.12 -- seconds off the floor within which a jump reads as a ground jump

function RemotePose.new(x: number, y: number): Pose
	return {
		x = x, y = y, vx = 0, vy = 0, facing = 1, grounded = true, airTime = 0,
		stillTime = Config.IDLE_GRACE, runDistance = 0, runFrom = 0, dashTime = 0, sliding = false, started = false, held = 0,
	}
end

-- One render frame: the runner is at (x, y); `ground` is feet-to-floor (nil if no floor in reach), `wall` true when
-- a wall is within the wall-jump reach on either side. Returns the sprite name and the juice events
-- ({ landed, jump, dash } in Movement.Events terms) for client/Look.
function RemotePose.step(p: Pose, x: number, y: number, ground: number?, wall: boolean, dt: number)
	: (string, Movement.Events)
	local ev: Movement.Events = {}
	if dt <= 0 then return Movement.spriteFor(p :: any), ev end
	local dx, dy = x - p.x, y - p.y
	p.held += dt
	if p.started and dx == 0 and dy == 0 and p.held < HOLD then return Movement.spriteFor(p :: any), ev end
	-- From here on, dt is the time this move took: the held frames too, unless it was at rest (a start from rest
	-- moved in this frame alone).
	if math.abs(p.vx) > 0.5 or math.abs(p.vy) > 0.5 then dt = p.held end
	p.held = 0
	local wasGrounded, wasDashing, oldVy = p.grounded, p.dashTime > 0, p.vy
	p.x, p.y = x, y
	local far = math.abs(dx) > TELEPORT or math.abs(dy) > TELEPORT
	if not p.started or far or math.sqrt(dx * dx + dy * dy) > TELEPORT_SPEED * dt then
		p.started, p.vx, p.vy = true, 0, 0
		dx, dy = 0, 0
	else
		local k = 1 - math.exp(-dt / VEL_SETTLE)
		p.vx += (dx / dt - p.vx) * k
		p.vy += (dy / dt - p.vy) * k
	end
	p.grounded = ground ~= nil and ground <= GROUND_TOL and p.vy <= RISING
	p.airTime = if p.grounded then 0 else p.airTime + dt
	p.dashTime = if math.abs(p.vx) > DASH_ABOVE and math.abs(p.vy) < Config.APEX_POSE_BELOW then 1 else 0
	p.sliding = not p.grounded and wall and p.vy < 0 and p.vy >= -(Config.WALL_SLIDE_MAX + RISING)
	if math.abs(p.vx) > 1 then p.facing = if p.vx > 0 then 1 else -1 end
	if math.abs(p.vx) > 0.5 then
		p.stillTime = 0
		if p.grounded then p.runDistance += math.abs(dx) end
	else
		p.stillTime += dt
		if p.stillTime >= Config.IDLE_GRACE then p.runFrom = p.runDistance end
	end
	if p.grounded and not wasGrounded then ev.landed = math.max(0, -oldVy) end
	if p.dashTime > 0 and not wasDashing then ev.dash = true end
	if not p.grounded and p.vy > JUMP_SEEN and oldVy <= JUMP_SEEN then
		ev.jump = if p.airTime - dt <= COYOTE_SEEN then "ground" elseif wall then "wall" else "double"
	end
	return Movement.spriteFor(p :: any), ev
end

return RemotePose
