--!strict
-- The closing walls (H24, DESIGN §3 rules 3 and 51; docs/systems/endgame.md §7): SpeedRunners' shrinking screen
-- translated into a window in WORLD space that the server owns, so every player keeps their own camera (DESIGN §2).
-- When the end phase starts, two walls appear just outside the living pack and close in over WALL_CLOSE_TIME to a
-- floor that keeps a duel playable; the window's centre drifts slowly after the living. The walls are not solid:
-- a living runner past one has WALL_GRACE seconds to get back in (reset the moment it is back), and is eliminated
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
	left: { [number]: number }, -- living runners outside the walls: seconds of grace left (absent = inside)
	paused: { [number]: boolean }, -- ... and whether that grace stood still on the last step (a hold or the tag freeze)
}

-- `pos(id)` -> the runner's newest x on the server's record and whether that sample is trusted (MoveCheck, trust.md).
export type Pos = (number) -> (number?, boolean?)

-- The centre the walls drift toward: the mean x of the living runners with a trusted sample (nil if none). The mean,
-- not the holder or a leader: no runner's position counts more than another's (endgame.md §7).
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

-- The walls appear: centred on the living pack, each WALL_START_PAD past the farthest living runner (nobody starts
-- outside), never closer than WALL_START_MIN (about half a 16:9 screen: centred on the window, the walls start at the
-- screen's edges, as SpeedRunners' red frame does). nil if no living runner has a trusted sample yet.
function Walls.open(r: Tag.Round, now: number, pos: Pos): State?
	local c = Walls.centroid(r, pos)
	if not c then return nil end
	local far = 0
	for _, id in r.order do
		local x = if r.alive[id] then pos(id) else nil
		if x then far = math.max(far, math.abs(x - c)) end
	end
	return { round = r, started = now, x = c, hw0 = math.max(Config.WALL_START_MIN, far + Config.WALL_START_PAD), vx = 0,
		left = {}, paused = {} }
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
function Walls.outside(w: State, now: number, x: number): boolean
	return math.abs(x - w.x) > Walls.halfWidth(w, now) + Config.RUNNER_WIDTH / 2
end

-- One server frame of `dt` seconds. The centre eases toward the living centroid (WALL_EASE per second, so a pack that
-- sways about one spot barely moves it; seen in Studio: a hard 8 studs/s follow swung the walls 16 studs with the
-- dummies' patrol) and never faster than WALL_FOLLOW; each living
-- runner is judged on its newest TRUSTED sample (an untrusted or missing sample changes nothing: a teleport back
-- inside never resets a grace). Outside: the grace starts at WALL_GRACE and runs down, except while the runner is
-- held (the holder's tag freeze, or `held(id)`: an item hold), so no hold plus a wall can kill a runner who could not
-- move; inside: it is cleared. Graces that reach 0 are eliminated in order: the one that ran out first, then the
-- holder, then join order; the round may end part-way, and nobody after that dies (Tag.eliminate refuses once over). Returns the ids eliminated, and
-- whether anyone went out or came back in this frame (the server sends MatchState at once on either).
function Walls.step(w: State, r: Tag.Round, now: number, dt: number, pos: Pos, held: ((number) -> boolean)?)
	: ({ number }, boolean)
	local c = Walls.centroid(r, pos)
	if c then
		local d = math.clamp((c - w.x) * (1 - math.exp(-Config.WALL_EASE * dt)), -Config.WALL_FOLLOW * dt,
			Config.WALL_FOLLOW * dt)
		w.x += d
		w.vx = if dt > 0 then d / dt else 0
	end
	local changed = false
	for id in w.left do
		if not r.alive[id] then w.left[id] = nil end -- a leave, or eliminated some other way
	end
	for _, id in r.order do
		if r.alive[id] then
			local x, trusted = pos(id)
			if x and trusted ~= false then
				local out = Walls.outside(w, now, x)
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
