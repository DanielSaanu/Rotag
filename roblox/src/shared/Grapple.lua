--!strict
-- The grapple (H25, DESIGN §2 kit and "2. Grapple swing releases you with that speed"; §3 rule 17): hook a marked
-- anchor that is on this screen and in reach (aim assist: the nearest, favouring the one ahead), hang and swing while
-- the input is held, let go and keep the swing's speed with a small boost. Pure Luau over Movement's state table; the
-- move rules call it from Movement.step (shared/Movement). Why each choice: docs/systems/grapple.md. Tests:
-- test/luau/grapple.test.luau.
local Config = require(script.Parent.Config)

local Grapple = {}

-- An anchor: its centre and the map's number for it (the wire carries the number, shared/Snapshot). `floor`: the top
-- of the floor under it, if the client found one (a ray down, once): a hook's rope is kept short enough that the
-- swing's low point clears it (QA round 1: an air hook on a long rope scraped the floor and lost the swing).
export type Anchor = { x: number, y: number, id: number, floor: number? }
-- The visible world: centre and half extents, studs (client/SideCamera.view).
export type View = { x: number, y: number, halfW: number, halfH: number }
-- The rope: the anchor's centre and id, its length now and the length it reels in to.
-- `w`: the swing's angular speed while taut (radians/s, counter-clockwise), nil while slack.
export type Rope = { x: number, y: number, id: number, len: number, target: number, w: number? }

-- Aim assist (rule 17): of the anchors at least GRAPPLE_MIN_ABOVE above (x, y), within GRAPPLE_RANGE, and inside the
-- view by GRAPPLE_INSET (never off-screen), the one with the lowest score: its distance, + GRAPPLE_BEHIND if it is
-- behind the facing, - GRAPPLE_STICKY if it is `prev` (the last pick's id). `clear(a)`, if given, is the line of sight
-- (the client's raycast); it is asked only of an anchor that would win, so at most a few rays a frame. nil: none.
-- QA round 1: never one under the screen's top GRAPPLE_INSET_TOP (the HUD banner sits there), and never one behind
-- the MOTION while moving faster than GRAPPLE_BEHIND_FAST x run (`vx`): the catch would throw the run away. QA round
-- 3: with hysteresis, so the pick never blinks at the threshold: the anchor picked last frame (`prev`) is kept up to
-- BEHIND_FAST; one not picked is taken only under BEHIND_SLOW.
function Grapple.pick(x: number, y: number, facing: number, anchors: { Anchor }, view: View, prev: number?,
	clear: ((Anchor) -> boolean)?, vx: number?): Anchor?
	local best, bestScore = nil, math.huge
	local inset = Config.GRAPPLE_INSET
	local speed = if vx ~= nil then math.abs(vx) / Config.RUN_SPEED else 0
	for _, a in anchors do
		local dx, dy = a.x - x, a.y - y
		local fast = speed > (if a.id == prev then Config.GRAPPLE_BEHIND_FAST else Config.GRAPPLE_BEHIND_SLOW)
		if dy >= Config.GRAPPLE_MIN_ABOVE and math.abs(a.x - view.x) <= view.halfW - inset
			and a.y - view.y >= -(view.halfH - inset) and a.y - view.y <= view.halfH - Config.GRAPPLE_INSET_TOP
			and not (fast and dx * (vx :: number) < 0) then
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= Config.GRAPPLE_RANGE then
				local score = d
				if dx * facing < 0 then score += Config.GRAPPLE_BEHIND end
				if a.id == prev then score -= Config.GRAPPLE_STICKY end
				if score < bestScore and (clear == nil or clear(a)) then best, bestScore = a, score end
			end
		end
	end
	return best
end

-- The rope's angle: 0 straight down from the anchor, positive to the right (radians), and the unit tangent there.
local function angle(r: Rope, x: number, y: number): number
	return math.atan2(x - r.x, r.y - y)
end

-- The swing's true velocity (along the rope's tangent, w x len) at the runner's position: what a release keeps.
local function tangential(s: any, r: Rope)
	local a = angle(r, s.x, s.y)
	local v = (r.w :: number) * r.len
	s.vx, s.vy = v * math.cos(a), v * math.sin(a)
end

-- Hook anchor `a`. The rope is as long as the distance (GRAPPLE_MIN_LEN at least); hooked from the floor it reels
-- in until your height is GRAPPLE_LIFT above where your feet were, so the swing's low point clears that floor.
function Grapple.attach(s: any, a: Anchor)
	local dx, dy = s.x - a.x, s.y - a.y
	local d = math.sqrt(dx * dx + dy * dy)
	local target = d
	if s.grounded then target = math.min(d, a.y - s.y - Config.GRAPPLE_LIFT) end
	if a.floor then -- the swing's low point (straight below the anchor) must clear the floor under it (QA round 1)
		target = math.min(target, a.y - a.floor - Config.RUNNER_HEIGHT / 2 - Config.GRAPPLE_LIFT)
	end
	local lo, hi = Config.GRAPPLE_MIN_LEN, Config.GRAPPLE_RANGE
	s.rope = { x = a.x, y = a.y, id = a.id, len = math.clamp(d, lo, hi), target = math.clamp(target, lo, hi) }
end

-- Let go. `boost`: the swing's velocity x GRAPPLE_RELEASE_BOOST (rule 17: a let-go or a jump off the rope; a dash,
-- a landing, a hold or a pad take the rope away without one). The next hook waits GRAPPLE_COOLDOWN.
function Grapple.release(s: any, boost: boolean)
	if not s.rope then return end
	if s.rope.w then tangential(s, s.rope) end -- the swing's own velocity, not this step's chord
	if boost then
		s.vx *= Config.GRAPPLE_RELEASE_BOOST
		s.vy *= Config.GRAPPLE_RELEASE_BOOST
	end
	s.rope = nil
	s.grappleCooldown = Config.GRAPPLE_COOLDOWN
end

-- One physics step on the rope, in place of the run and the fall (Movement.step phase 5). A rope only pulls. SLACK
-- (`w` nil): free flight under gravity, until this step would carry it past the rope's length; then it CATCHES:
-- the outward part of the velocity is lost (an inelastic catch), the rest becomes the swing. TAUT: a pendulum in its
-- angle, stepped with leapfrog (half a kick of (-g sin a + pump cos a) / len, a += w dt, the other half), which keeps
-- the swing's energy over many periods; measured in docs/systems/grapple.md §3: a position projection lost 86% of it in
-- 4 s at 60 Hz. The body gets the velocity that carries it from where it is to the new point on the rope this step.
-- It goes slack again when the rope would have to push (len w^2 + g cos a < 0: too slow above the anchor's side).
-- The rope reels in at GRAPPLE_REEL while longer than its target. The swing never passes GRAPPLE_MAX_SPEED.
function Grapple.swing(s: any, moveX: number, dt: number)
	local r: Rope = s.rope
	if r.len > r.target then r.len = math.max(r.target, r.len - Config.GRAPPLE_REEL * dt) end
	local g, cap = Config.GRAVITY, Config.GRAPPLE_MAX_SPEED
	-- Slack: catch on the step that would carry the runner past the rope's length (never a frame beyond it).
	local dx, dy = s.x + s.vx * dt - r.x, s.y + (s.vy - g * dt) * dt - r.y
	if r.w == nil and dx * dx + dy * dy >= r.len * r.len then
		local a0 = angle(r, s.x, s.y)
		r.w = (s.vx * math.cos(a0) + s.vy * math.sin(a0)) / r.len
	end
	local w = r.w
	if w ~= nil then
		local a, len = angle(r, s.x, s.y), r.len
		local pump = moveX * Config.GRAPPLE_PUMP
		local function accel(at: number): number return (-g * math.sin(at) + pump * math.cos(at)) / len end
		w += accel(a) * dt / 2 -- leapfrog: half a kick, the drift, half a kick (energy error O(dt^2), §3)
		local a1 = a + w * dt
		w = math.clamp(w + accel(a1) * dt / 2, -cap / len, cap / len)
		r.w = w
		if len * w * w + g * math.cos(a) < 0 then
			tangential(s, r)
			r.w = nil -- slack: the rope would have to push; fly free from here (below)
		else
			s.vx = (r.x + len * math.sin(a1) - s.x) / dt
			s.vy = (r.y - len * math.cos(a1) - s.y) / dt
			return
		end
	end
	s.vy -= g * dt
	local v = math.sqrt(s.vx * s.vx + s.vy * s.vy)
	if v > cap then s.vx, s.vy = s.vx * cap / v, s.vy * cap / v end
end

-- Something solid stopped part of the step's velocity (Movement.step phase 6): the swing keeps only what is left.
function Grapple.stopped(s: any)
	local r = s.rope
	if not (r and r.w) then return end
	local a = angle(r, s.x, s.y)
	r.w = (s.vx * math.cos(a) + s.vy * math.sin(a)) / r.len
end

return Grapple
