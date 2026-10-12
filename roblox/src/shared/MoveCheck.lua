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
}

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
	s.bx = math.min(cap(MoveCheck.RATE_X), s.bx + MoveCheck.RATE_X * dt - math.abs(dx))
	s.bu = math.min(cap(MoveCheck.RATE_UP), s.bu + MoveCheck.RATE_UP * dt - math.max(dy, 0))
	s.bd = math.min(cap(MoveCheck.RATE_DOWN), s.bd + MoveCheck.RATE_DOWN * dt - math.max(-dy, 0))
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
