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

-- The draw trail (H13, players.md §3): where to DRAW another runner, a fixed Config.OTHERS_DRAW_DELAY behind the
-- positions that arrived, sliding between them. A replicated body can hold for a few frames and then jump; drawn
-- through the trail it moves on every frame. Times are the receiving screen's clock at arrival. Pure, tested.
export type Trail = { points: { { t: number, x: number, y: number } }, delay: number, peak: number }

local KEEP = 1 -- seconds of points kept behind the newest
-- H13 run 4: a fixed 0.1 s hid holds of a few frames but not a sender that steps slowly (a throttled window, a slow
-- phone). The delay now ADAPTS: it tracks the longest recent gap between two arrivals of a MOVING body (a decaying
-- peak) with a margin, between Config.OTHERS_DRAW_DELAY and Config.OTHERS_DRAW_DELAY_MAX, and changes no faster than
-- DELAY_RATE so the drawing slows or speeds a little instead of jumping. A gap over the cap is a rest, not counted.
local PEAK_DECAY = 3 -- seconds per e-fold: a better link brings the delay back down within a few seconds
local MARGIN = 1.25 -- delay = the peak gap times this, so the newest point is usually already there
local DELAY_RATE = 0.25 -- seconds of delay change per second at most

function RemotePose.newTrail(t: number, x: number, y: number): Trail
	return { points = { { t = t, x = x, y = y } }, delay = Config.OTHERS_DRAW_DELAY, peak = 0 }
end

-- The root was read at (x, y) at time t; `prevT` is the previous render frame's time. Call every frame (it also
-- steers the delay); only a change is stored. A change after a hold longer than HOLD (or the delay, if longer: a hold
-- the delay covers is smoothed over) is a start from rest: the old spot is re-stamped at prevT first, so the drawing
-- leaves it now instead of creeping across the whole hold. A teleport restarts the trail.
function RemotePose.push(trail: Trail, t: number, x: number, y: number, prevT: number)
	local dt = math.max(0, t - prevT)
	trail.peak *= math.exp(-dt / PEAK_DECAY)
	local want = math.clamp(trail.peak * MARGIN, Config.OTHERS_DRAW_DELAY, Config.OTHERS_DRAW_DELAY_MAX)
	trail.delay += math.clamp(want - trail.delay, -DELAY_RATE * dt, DELAY_RATE * dt)
	local pts = trail.points
	local last = pts[#pts]
	if x == last.x and y == last.y then return end
	if math.abs(x - last.x) > TELEPORT or math.abs(y - last.y) > TELEPORT then
		trail.points = { { t = t, x = x, y = y } }
		return
	end
	local gap = t - last.t
	if gap <= Config.OTHERS_DRAW_DELAY_MAX then trail.peak = math.max(trail.peak, gap) end
	if gap > math.max(HOLD, trail.delay) and prevT > last.t then table.insert(pts, { t = prevT, x = last.x, y = last.y }) end
	table.insert(pts, { t = t, x = x, y = y })
	while #pts > 2 and pts[2].t < t - KEEP do table.remove(pts, 1) end
end

-- Where to draw at time `now`: the trail at now - trail.delay, between the two points around it; held at the newest
-- point once that is passed (a real stop, or a hold longer than the delay), and at the oldest before it begins.
function RemotePose.drawAt(trail: Trail, now: number): (number, number)
	local pts = trail.points
	local t = now - trail.delay
	local newest = pts[#pts]
	if t >= newest.t then return newest.x, newest.y end
	if t <= pts[1].t then return pts[1].x, pts[1].y end
	for i = #pts - 1, 1, -1 do
		local a = pts[i]
		if a.t <= t then
			local b = pts[i + 1]
			local k = (t - a.t) / (b.t - a.t)
			return a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k
		end
	end
	return pts[1].x, pts[1].y
end

return RemotePose
