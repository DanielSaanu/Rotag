--!strict
-- The tag and the hot-potato fuse (DESIGN §2 "Mode", §3 rules 1, 4, 5, 6). Pure Luau over plain tables: no
-- Instances, no Roblox APIs, every clock passed in as `now` (seconds). The SERVER owns the one round state and is
-- the only caller that changes it; clients use fuseLeft / frozen / chaserBoost / overlaps to draw and predict.
-- Why each rule is shaped this way: docs/systems/tag.md. Tests: test/luau/tag.test.luau.
local Config = require(script.Parent.Config)

local Tag = {}

-- ids are runner ids: a player's UserId, or a negative id for a server dummy (tag.md §4).
export type Round = {
	order: { number },        -- everyone in the round, in join order (the rotation, rule 5)
	alive: { [number]: boolean },
	it: number?,              -- the holder; nil once the round is over
	fuse: number,             -- seconds left at `since`
	since: number,            -- when `fuse` was last written
	frozenUntil: number,      -- the holder can neither move nor tag before this, and the fuse waits (rule 1)
	chaseFrom: number,        -- when the current chase began (the ramp clock, rule 4) = the end of the freeze
	eliminations: number,
	winner: number?,
	over: boolean,
}

-- The fuse a NEW holder gets after an elimination (not a pass): it shrinks per elimination (tag.md §5, decision e).
function Tag.freshFuse(eliminations: number): number
	return math.max(Config.FUSE_MIN, Config.FUSE_START - Config.FUSE_SHRINK * eliminations)
end

-- Rule 5: rotation, never random. The first id in `order` after `previous` (wrapping) that is in `present`.
function Tag.nextStarter(order: { number }, present: { [number]: boolean }, previous: number?): number?
	local n = #order
	if n == 0 then return nil end
	local start = 0
	if previous ~= nil then
		for i, id in order do
			if id == previous then start = i break end
		end
	end
	for k = 1, n do
		local id = order[(start + k - 1) % n + 1]
		if present[id] then return id end
	end
	return nil
end

function Tag.newRound(order: { number }, starter: number, now: number): Round
	local alive = {}
	for _, id in order do alive[id] = true end
	local frozenUntil = now + Config.START_FREEZE
	return {
		order = table.clone(order), alive = alive, it = starter, fuse = Config.FUSE_START, since = now,
		frozenUntil = frozenUntil, chaseFrom = frozenUntil, eliminations = 0, winner = nil, over = false,
	}
end

-- Seconds left on the fuse at `now`. It does not burn while the holder is frozen (tag.md §3).
function Tag.fuseLeft(r: Round, now: number): number
	local burnFrom = math.max(r.since, r.frozenUntil)
	return math.max(0, r.fuse - math.max(0, now - burnFrom))
end

function Tag.frozen(r: Round, now: number): boolean
	return now < r.frozenUntil
end

function Tag.aliveCount(r: Round): number
	local n = 0
	for _, id in r.order do
		if r.alive[id] then n += 1 end
	end
	return n
end

-- Two runner boxes (centre x, y) touch within `slack` studs of reach on each axis.
function Tag.overlaps(ax: number, ay: number, bx: number, by: number, slack: number): boolean
	local reach = Config.TAG_REACH + slack
	return math.abs(ax - bx) <= Config.RUNNER_WIDTH + reach and math.abs(ay - by) <= Config.RUNNER_HEIGHT + reach
end

-- May `claimant` tag `target` at `now`? Returns ok and, when not ok, the reason (for the Studio log only).
function Tag.canClaim(r: Round, claimant: number, target: number, now: number): (boolean, string?)
	if r.over then return false, "round over" end
	if r.it ~= claimant then return false, "not it" end
	if Tag.frozen(r, now) then return false, "frozen" end
	if target == claimant then return false, "self" end
	if not r.alive[target] then return false, "target not in play" end
	if Tag.fuseLeft(r, now) <= 0 then return false, "fuse out" end
	return true, nil
end

-- Lag-fair confirm (rule 6, tag.md §2). `a` (the claimant) and `b` (the target) are recent positions AS THE SERVER
-- SAW THEM, one sample per server frame: { {t, x, y}, ... } oldest first. True if some claimant sample `sa` and target
-- sample `sb` with from <= sb.t <= sa.t <= to and sa.t - sb.t <= lag touch within TAG_GRACE. `lag` = 0 pairs only
-- samples of the same frame. A target sample NEWER than the claimant's is never paired: no screen shows the future.
-- Why the target may be older (H6, measured in Studio): the server sees the claimant's own body ~0.18 s late, and
-- the claimant saw the target late too, so "touching on the tagger's screen" is the claimant's sample against an
-- older target sample, not the same frame.
export type Sample = { t: number, x: number, y: number }
function Tag.touchedBetween(a: { Sample }, b: { Sample }, from: number, to: number, lag: number): boolean
	for i = #a, 1, -1 do
		local sa = a[i]
		if sa.t < from then break end
		if sa.t <= to then
			for j = #b, 1, -1 do
				local sb = b[j]
				if sb.t < from or sb.t < sa.t - lag then break end
				if sb.t <= sa.t and Tag.overlaps(sa.x, sa.y, sb.x, sb.y, Config.TAG_GRACE) then return true end
			end
		end
	end
	return false
end

-- A same-frame touch within `rewind` seconds before `now` (capped at TAG_REWIND_MAX). The server's own dummy uses it
-- with rewind 0: its position is the server's truth, so it gets no allowance.
function Tag.confirm(a: { Sample }, b: { Sample }, now: number, rewind: number): boolean
	return Tag.touchedBetween(a, b, now - math.clamp(rewind, 0, Config.TAG_REWIND_MAX), now, 0)
end

-- How a claim that ARRIVED at `at` is judged (H6, tag.md §2): returns from, deadline, lag for touchedBetween.
-- `rewind` is the claimant's ping + TAG_VIEW_DELAY, capped at TAG_REWIND_MAX so lagging buys no more: the target may
-- be up to that much older than the claimant's sample, and no older than `at` minus it. Forward, the claim stays open
-- TAG_CONFIRM_WAIT, because the claimant's body reaches the server after its claim does; the server confirms on the
-- first frame the touch shows up and drops the claim at the deadline.
function Tag.claimWindow(at: number, rewind: number): (number, number, number)
	local k = math.clamp(rewind, 0, Config.TAG_REWIND_MAX)
	return at - k, at + Config.TAG_CONFIRM_WAIT, k
end

-- A confirmed tag: remaining + FUSE_PASS_BONUS goes to `to`, who is frozen for TAG_FREEZE. Call canClaim first.
-- Capped at the fuse this life started with (Danzo 2026-10-11): passes alone never lengthen a round past it.
-- Returns the new fuse and what the pass really added (H7): under the cap that is the whole bonus, at the cap less,
-- so the "+N" every screen pops (rule 2) is never a number the fuse did not get.
function Tag.pass(r: Round, to: number, now: number): (number, number)
	local left = Tag.fuseLeft(r, now)
	local fuse = math.min(left + Config.FUSE_PASS_BONUS, Tag.freshFuse(r.eliminations))
	r.it = to
	r.fuse = fuse
	r.since = now
	r.frozenUntil = now + Config.TAG_FREEZE
	r.chaseFrom = r.frozenUntil
	return fuse, fuse - left
end

-- Advance the round. Returns the id eliminated this call, if the fuse ran out. The next holder is the next alive
-- runner after the eliminated one in join order (rotation, rule 5) with a fresh, shorter fuse; the round ends when
-- one runner is left (or none, in a round that started with one).
function Tag.tick(r: Round, now: number): number?
	local it = r.it
	if r.over or it == nil or Tag.fuseLeft(r, now) > 0 then return nil end
	r.alive[it] = false
	r.eliminations += 1
	local left = Tag.aliveCount(r)
	if left <= 1 then
		r.over = true
		r.it = nil
		r.winner = if left == 1 then Tag.nextStarter(r.order, r.alive, it) else nil
		return it
	end
	r.it = Tag.nextStarter(r.order, r.alive, it)
	r.fuse = Tag.freshFuse(r.eliminations)
	r.since = now
	r.frozenUntil = now + Config.TAG_FREEZE
	r.chaseFrom = r.frozenUntil
	return it
end

-- A runner leaves mid-round: out of the rotation; if they held it, the next alive runner takes over the fuse as is.
-- A round that is already over is left alone (H7): the winner leaving during ROUND_GAP must not rewrite the result.
function Tag.leave(r: Round, id: number, now: number)
	if r.over or not r.alive[id] then return end
	r.alive[id] = false
	if Tag.aliveCount(r) <= 1 and #r.order > 1 then
		r.over = true
		r.winner = Tag.nextStarter(r.order, r.alive, id)
		r.it = nil
		return
	end
	if r.it == id then
		r.fuse = Tag.fuseLeft(r, now)
		r.since = now
		r.it = Tag.nextStarter(r.order, r.alive, id)
		r.frozenUntil = now + Config.TAG_FREEZE
		r.chaseFrom = r.frozenUntil
		if r.it == nil then r.over = true end
	end
end

-- Rule 4: "it" speeds up the longer a chase lasts, and the boost resets on a tag. Multiplier on the run speed.
function Tag.chaserBoost(chaseTime: number): number
	local t = chaseTime - Config.RAMP_DELAY
	if t <= 0 then return 1 end
	return 1 + Config.RAMP_MAX * math.min(1, t / Config.RAMP_TIME)
end

return Tag
