--!strict
-- The closing walls (H24, DESIGN §3 rules 3 and 51; docs/systems/endgame.md §7): SpeedRunners' shrinking screen
-- translated into a window in WORLD space that the server owns, so every player keeps their own camera (DESIGN §2).
-- When the end phase starts, two walls appear just outside the living pack and close in over WALL_CLOSE_TIME to a
-- floor that keeps a duel playable; the window's centre eases (WALL_FOLLOW at most) toward a target that loosely
-- follows the living (H26, endgame.md §7.7): their mean, leaned toward the holder, plus a slow wander that never
-- repeats, inside the map's window bounds. Everything it follows is the server's trusted record or its own clock, so
-- no client can steer it beyond moving its own runner. The walls are not solid:
-- a living runner past one has WALL_GRACE seconds to get back in (reset once its whole body is back), and is eliminated
-- like a burn-out at 0. Pure Luau over plain tables, every clock passed in. The SERVER is the only caller of `open`
-- and `step`, on its own position record; clients draw what MatchState carries. Tests: test/luau/walls.test.luau.
local Config = require(script.Parent.Config)
local Tag = require(script.Parent.Tag)

local Walls = {}

export type State = {
	round: Tag.Round, -- the round these walls belong to: a new round object means no walls yet
	started: number, -- when the walls appeared (the end phase's first server frame)
	x: number, -- the window's centre, world x (studs)
	hw0: number, -- its half-width when it appeared
	vx: number, -- the centre's drift on the last step, studs/s (clients extrapolate with it)
	lo: number?, hi: number?, -- the map's window bounds, world x: no wall ever goes past them (DESIGN §6.8)
	seed: number, -- picks the wander's phases: a new round, a new path (the server's own clock; a test pins it)
	left: { [number]: number }, -- living runners outside the walls: seconds of grace left (absent = inside)
	paused: { [number]: boolean }, -- ... and whether that grace stood still on the last step (a hold or the tag freeze)
}

-- `pos(id)` -> the runner's newest x on the server's record and whether that sample is trusted (MoveCheck, trust.md).
export type Pos = (number) -> (number?, boolean?)

-- The mean x of the living runners with a trusted sample (nil if none): where the walls open, and the base of the
-- target they follow. Not a leader's or the holder's x alone (endgame.md §7.2); the holder only leans it (§7.7).
function Walls.centroid(r: Tag.Round, pos: Pos): number?
	local sum, n = 0, 0
	for _, id in r.order do
		if r.alive[id] then
			local x, trusted = pos(id)
			if x and trusted ~= false then sum, n = sum + x, n + 1 end
		end
	end
	return if n > 0 then sum / n else nil
end

-- A centre moved (as little as possible) so the window [c - hw, c + hw] stays inside the map's bounds; a window wider
-- than the map: the map's middle. hw only shrinks, so the allowed range only widens: a centre inside stays inside.
function Walls.within(w: State, c: number, hw: number): number
	local lo, hi = w.lo, w.hi
	if lo == nil or hi == nil then return c end
	if hi - lo <= 2 * hw then return (lo + hi) / 2 end
	return math.clamp(c, lo + hw, hi - hw)
end

-- The walls appear: centred on the living pack, each WALL_START_PAD past the farthest living runner (nobody starts
-- outside), never closer than WALL_START_MIN (about half a 16:9 screen: centred on the window, the walls start at the
-- screen's edges, as SpeedRunners' red frame does). nil if no living runner has a trusted sample yet. `bounds` is the
-- map's window (the inner faces of its end walls): a pack against one end gets a box shifted into the map, which still
-- holds everyone (the box only moves toward the pack's own side); a box wider than the map sits on the map's middle.
export type Bounds = { lo: number, hi: number }
function Walls.open(r: Tag.Round, now: number, pos: Pos, bounds: Bounds?, seed: number?): State?
	local c = Walls.centroid(r, pos)
	if not c then return nil end
	local far = 0
	for _, id in r.order do
		local x = if r.alive[id] then pos(id) else nil
		if x then far = math.max(far, math.abs(x - c)) end
	end
	local w: State = { round = r, started = now, x = c, hw0 = math.max(Config.WALL_START_MIN, far + Config.WALL_START_PAD),
		vx = 0, lo = bounds and bounds.lo, hi = bounds and bounds.hi, seed = seed or now, left = {}, paused = {} }
	w.x = Walls.within(w, c, w.hw0)
	return w
end

-- The half-width at `now`: linear from hw0 to WALL_MIN_HW over WALL_CLOSE_TIME, then held there.
function Walls.halfWidth(w: State, now: number): number
	local p = math.clamp((now - w.started) / Config.WALL_CLOSE_TIME, 0, 1)
	return w.hw0 + (Config.WALL_MIN_HW - w.hw0) * p
end

-- How fast each wall moves inward at `now`, studs/s (0 once closed). Clients extrapolate the half-width with it.
function Walls.closeRate(w: State, now: number): number
	if now - w.started >= Config.WALL_CLOSE_TIME then return 0 end
	return (w.hw0 - Config.WALL_MIN_HW) / Config.WALL_CLOSE_TIME
end

-- Is a runner whose centre is at `x` outside? Only once its whole body is past a wall (RUNNER_WIDTH / 2 beyond it).
-- `was`: it was outside on the last step. Then it stays out until it is WALL_BACK_IN further in (the whole body back
-- inside): a hysteresis, so a runner at a swaying wall does not flap out and in every frame (H26 follow-up).
function Walls.outside(w: State, now: number, x: number, was: boolean?): boolean
	local line = Walls.halfWidth(w, now) + Config.RUNNER_WIDTH / 2
	return math.abs(x - w.x) > (if was then line - Config.WALL_BACK_IN else line)
end

-- The wander (H26): a slow sway of the target, studs, a sum of two sines whose periods are WALL_DRIFT_PERIOD and that
-- times the golden ratio (it never repeats, so nobody learns its rhythm), phases picked by the seed. It fades in with
-- the close (0 when the walls appear, full once closed: the opening sweep reads as "the screen is closing"), and is
-- never more than WALL_DRIFT either way. A pure function of the server's clock: nothing a client sends touches it.
local GOLDEN = (1 + math.sqrt(5)) / 2
function Walls.drift(w: State, now: number): number
	local t = now - w.started
	local p = math.clamp(t / Config.WALL_CLOSE_TIME, 0, 1)
	local a = 2 * math.pi * ((w.seed * 0.7548776662) % 1) -- two unrelated phases from one seed
	local b = 2 * math.pi * ((w.seed * 0.5698402910) % 1)
	local P = Config.WALL_DRIFT_PERIOD
	return Config.WALL_DRIFT * p * (0.6 * math.sin(2 * math.pi * t / P + a) + 0.4 * math.sin(2 * math.pi * t / (P * GOLDEN) + b))
end

-- The living holder's x on its own TRUSTED sample (nil: no holder, or no trusted sample: then no lean).
function Walls.holderX(r: Tag.Round, pos: Pos): number?
	local it = r.it
	if it == nil or not r.alive[it] then return nil end
	local x, trusted = pos(it)
	return if x and trusted ~= false then x else nil
end

-- Where the centre is heading at `now`, from the living `mean` (Walls.centroid) and the holder's x (Walls.holderX):
-- the mean, WALL_LEAN of the way toward the holder, plus the wander, kept inside the map's bounds. The lean is what
-- makes the walls press on the chased: in a duel the runner's room away from "it" shrinks (38 studs, not 48), and the
-- wall that comes at the runner is the one on the far side from the holder.
function Walls.target(w: State, now: number, mean: number, holder: number?): number
	local c = if holder then mean + Config.WALL_LEAN * (holder - mean) else mean
	return Walls.within(w, c + Walls.drift(w, now), Walls.halfWidth(w, now))
end

-- One server frame of `dt` seconds. The centre eases toward `Walls.target` (WALL_EASE per second, so a pack that
-- sways about one spot barely moves it; seen in Studio: a hard 8 studs/s follow swung the walls 16 studs with the
-- dummies' patrol) and never faster than WALL_FOLLOW, wander included; each living
-- runner is judged on its newest TRUSTED sample (an untrusted or missing sample changes nothing: a teleport back
-- inside never resets a grace). Outside: the grace starts at WALL_GRACE and runs down, except while the runner is
-- held (the holder's tag freeze, or `held(id)`: an item hold), so no hold plus a wall can kill a runner who could not
-- move; back inside (Walls.outside's hysteresis): it is cleared. Graces that reach 0 are eliminated in order: the one that ran out first, then the
-- holder, then join order; the round may end part-way, and nobody after that dies (Tag.eliminate refuses once over). Returns the ids eliminated, and
-- whether anyone went out or came back in this frame (the server sends MatchState at once on either).
function Walls.step(w: State, r: Tag.Round, now: number, dt: number, pos: Pos, held: ((number) -> boolean)?)
	: ({ number }, boolean)
	local mean = Walls.centroid(r, pos) -- nil: no living runner has a trusted sample, and the box stands still
	if mean then
		local c = Walls.target(w, now, mean, Walls.holderX(r, pos))
		local d = math.clamp((c - w.x) * (1 - math.exp(-Config.WALL_EASE * dt)), -Config.WALL_FOLLOW * dt,
			Config.WALL_FOLLOW * dt)
		w.x += d
		w.vx = if dt > 0 then d / dt else 0
	else
		w.vx = 0 -- nothing to follow: the box stands still, and clients must not extrapolate an old drift (H26)
	end
	local changed = false
	for id in w.left do
		if not r.alive[id] then w.left[id] = nil end -- a leave, or eliminated some other way
	end
	for _, id in r.order do
		if r.alive[id] then
			local x, trusted = pos(id)
			if x and trusted ~= false then
				local out = Walls.outside(w, now, x, w.left[id] ~= nil)
				if out and w.left[id] == nil then
					w.left[id], changed = Config.WALL_GRACE, true
				elseif not out and w.left[id] ~= nil then
					w.left[id], changed = nil, true
				end
			end
			local frozen = r.it == id and Tag.frozen(r, now)
			local still = frozen or (held ~= nil and held(id))
			w.paused[id] = if w.left[id] ~= nil and still then true else nil -- told to clients: no sawtooth (QA round 1)
			if w.left[id] ~= nil and not still then w.left[id] = (w.left[id] :: number) - dt end
		end
	end
	local due = {}
	for id, left in w.left do
		if left <= 0 then table.insert(due, id) end
	end
	table.sort(due, function(a, b)
		if w.left[a] ~= w.left[b] then return w.left[a] < w.left[b] end
		if (r.it == a) ~= (r.it == b) then return r.it == a end
		return (table.find(r.order, a) or 0) < (table.find(r.order, b) or 0)
	end)
	local out = {}
	for _, id in due do
		w.left[id] = nil
		if Tag.eliminate(r, id, now) then table.insert(out, id) end
	end
	return out, changed or #out > 0
end

-- What MatchState carries (arrays and string keys only, → N13): the window, and every living runner outside it with
-- its grace left, in join order. The window's `vx` and `vhw` (the half-width's rate, <= 0) let a client draw the walls
-- moving between two states.
export type Row = { id: number, left: number, held: boolean? }
function Walls.rows(w: State, now: number): ({ x: number, hw: number, vx: number, vhw: number }, { Row })
	local rows = {}
	for _, id in w.round.order do
		local left = w.left[id]
		if left ~= nil and w.round.alive[id] then
			table.insert(rows, { id = id, left = math.max(0, left), held = if w.paused[id] then true else nil })
		end
	end
	return { x = w.x, hw = Walls.halfWidth(w, now), vx = w.vx, vhw = -Walls.closeRate(w, now) }, rows
end

return Walls
