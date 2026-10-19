--!strict
-- The server's speed check on a client-owned runner (H12, docs/systems/trust.md). The client owns its body's physics,
-- so the positions the server sees (and judges tags on) are the client's word. This module bounds that word: over ANY
-- stretch of time T, a runner may travel at most RATE x T + BURST along each axis (a token bucket per axis: the budget
-- refills at the axis's top legal speed, up to BURST, and each step spends the distance it moved). A teleport spends
-- more than BURST at once; a sustained over-speed drains it. Unchanged frames cost nothing and their time still
-- refills, so a position that lands in steps (players.md §2) or catches up after a stall is not punished, up to BURST.
-- Pure Luau; tests: test/luau/move_check.test.luau. Match feeds it the samples it already records (server/MoveGuard).
local Config = require(script.Parent.Config)

local MoveCheck = {}

-- The top legal speed per axis, from Movement's own caps (trust.md §2 has the proof):
-- x: a dash holds DASH_SPEED; a jump out of a dash adds JUMP_H_BOOST, but any speed above the run speed bleeds off
-- (RUN_REDUCE, faster still without the stick), so above DASH_SPEED is only ever a fraction of a second: the burst.
-- up: no move sets vy above JUMP_SPEED. down: MAX_FALL caps every fall.
MoveCheck.RATE_X = Config.DASH_SPEED
MoveCheck.RATE_UP = Config.JUMP_SPEED
MoveCheck.RATE_DOWN = Config.MAX_FALL

export type State = {
	x: number, y: number, t: number,
	bx: number, bu: number, bd: number, -- what is left of each axis's budget, studs
	suspect: boolean, -- a violation since the last clean MOVE_CLEAR_TIME: samples are not trusted for a tag
	clearAt: number, -- when suspect ends if nothing else goes wrong
	trustX: number, trustY: number, -- the last position seen trusted with full budgets: where a snap-back puts it
	hold: { number }?, holdFrom: number?, holdUntil: number?, -- H19: the refill rates while a hold is in force
	holdCap: number?, -- and the x budget's cap for it (QA round 1)
}

-- H19 (DESIGN §3 rule 44, trust.md §10; QA round 1 tightened it): while a hold is in force the budgets REFILL at the
-- hold's allowance { x, up, down }. A trap pins; a stumble runs at half speed (a rise in progress and a fall go on); a
-- freeze slides on the speed `v` the victim had, bleeding to 0, which averages v / 2: its x refill is v / 2 +
-- HOLD_SLACK (the 0 below is replaced). And the x budget DROPS when the hold lands to what lateness can honestly cost:
-- the victim's client hears of it a ping later and runs on at v until then, so v x HOLD_GRACE + HOLD_SLACK, not the
-- free 24-stud burst (with the full burst a client could ignore a whole freeze from a run, QA round 1).
MoveCheck.HOLD_RATES = {
	trap = { 0, 0, Config.MAX_FALL }, -- pinned across and up; a runner caught low in the air drops onto it (QA round 2)
	stumble = { Config.RUN_SPEED * Config.STUMBLE_SPEED, Config.JUMP_SPEED, Config.MAX_FALL },
	freeze = { 0, Config.JUMP_SPEED, Config.MAX_FALL },
} :: { [string]: { number } }

-- Hold this runner to `kind`'s allowance from `from` (the hold's start) to `untilT`. `speed`: its horizontal speed as
-- the SERVER last measured it (MoveCheck.recentSpeed over its own samples; nil = unknown, read as the dash speed, the
-- most lenient). Unknown kinds change nothing.
function MoveCheck.hold(s: State, kind: string, from: number, untilT: number, speed: number?)
	local rates = MoveCheck.HOLD_RATES[kind]
	if not rates then return end
	local v = math.min(math.abs(speed or MoveCheck.RATE_X), MoveCheck.RATE_X)
	local rx = if kind == "freeze" then v / 2 + Config.HOLD_SLACK else rates[1]
	s.hold, s.holdFrom, s.holdUntil = { rx, rates[2], rates[3] }, from, untilT
	s.holdCap = v * Config.HOLD_GRACE + Config.HOLD_SLACK -- the x cap for the whole hold: standing still never refills
	s.bx = math.min(s.bx, s.holdCap :: number) -- past it (else stand 0.35 s, then ignore the rest of a freeze)
end

-- A runner's horizontal speed from the server's OWN samples ({ t, x } oldest first): the distance over the last
-- `window` seconds (default 0.1) divided by the time. Never the client's reported velocity (a cheat would report a
-- high one to widen its own allowance). nil with fewer than two samples.
function MoveCheck.recentSpeed(samples: { { t: number, x: number } }, window: number?): number?
	local last = samples[#samples]
	if not last then return nil end
	local w = window or 0.1
	local first = nil
	for i = #samples - 1, 1, -1 do
		first = samples[i]
		if last.t - samples[i].t >= w then break end
	end
	if not first or last.t <= first.t then return nil end
	return math.abs(last.x - first.x) / (last.t - first.t)
end

-- The hold ended early (a trap pried open at `t`).
function MoveCheck.release(s: State, t: number)
	if s.holdUntil then s.holdUntil = math.min(s.holdUntil, t) end
end

local FULL = 0.01 -- studs: a budget this close to its cap counts as full (float dust)

local function cap(rate: number): number
	return rate * Config.MOVE_BURST_TIME
end

-- A fresh check at a position the server put the body at (spawn, round start, snap-back): trusted, budgets full.
function MoveCheck.new(x: number, y: number, t: number): State
	return {
		x = x, y = y, t = t,
		bx = cap(MoveCheck.RATE_X), bu = cap(MoveCheck.RATE_UP), bd = cap(MoveCheck.RATE_DOWN),
		suspect = false, clearAt = t, trustX = x, trustY = y,
	}
end

-- One server sample. Returns ok, and on a violation the axis ("x", "up", "down") and how many studs over budget it
-- went (the worst axis). After a violation the spent budget is set to 0, not left negative, so one teleport does not
-- poison every later step; the runner stays suspect until MOVE_CLEAR_TIME passes with no further violation.
function MoveCheck.step(s: State, x: number, y: number, t: number): (boolean, string?, number?)
	local dt = math.max(0, t - s.t)
	local dx, dy = x - s.x, y - s.y
	s.x, s.y, s.t = x, y, t
	-- Refill and spend together, then cap: a step from a full budget may move BURST plus what its own time earned.
	local rx, ru, rd = MoveCheck.RATE_X, MoveCheck.RATE_UP, MoveCheck.RATE_DOWN
	local h = s.hold
	local capX = cap(MoveCheck.RATE_X)
	if h and t > (s.holdUntil :: number) then
		-- QA round 2: the hold is over (pried or run out). The x budget is back to a resting runner's full burst: a pinned
		-- runner left at the hold's 2-stud floor had 0.49 studs to spare on a dash-jump out of a trap, under the stream's
		-- own catch-up jitter (trust.md §3). A client that ignored the hold was already caught during it.
		s.bx, s.hold, h = capX, nil, nil
	end
	if h and t >= (s.holdFrom :: number) and t <= (s.holdUntil :: number) then
		rx, ru, rd = h[1], h[2], h[3]
		capX = math.min(capX, s.holdCap :: number)
	end
	s.bx = math.min(capX, s.bx + rx * dt - math.abs(dx))
	s.bu = math.min(cap(MoveCheck.RATE_UP), s.bu + ru * dt - math.max(dy, 0))
	s.bd = math.min(cap(MoveCheck.RATE_DOWN), s.bd + rd * dt - math.max(-dy, 0))
	local axis, over = nil, 0
	if s.bx < -over then axis, over = "x", -s.bx end
	if s.bu < -over then axis, over = "up", -s.bu end
	if s.bd < -over then axis, over = "down", -s.bd end
	if axis then
		s.bx, s.bu, s.bd = math.max(s.bx, 0), math.max(s.bu, 0), math.max(s.bd, 0)
		s.suspect, s.clearAt = true, t + Config.MOVE_CLEAR_TIME
		return false, axis, over
	end
	if s.suspect and t >= s.clearAt then s.suspect = false end
	-- The snap-back spot moves only while every budget is full. Seen in Studio: the server's copy of a client-owned body
	-- smooths a teleport into ~0.2 s of fast steps, so "the last sample before the violation" is already most of the way
	-- there; the last full-budget sample is where the runner was before the jump began.
	local full = s.bx >= cap(MoveCheck.RATE_X) - FULL and s.bu >= cap(MoveCheck.RATE_UP) - FULL
		and s.bd >= cap(MoveCheck.RATE_DOWN) - FULL
	if not s.suspect and full then s.trustX, s.trustY = x, y end
	return true, nil, nil
end

return MoveCheck
