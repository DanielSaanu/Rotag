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
	hold: number,             -- +1 every time the fuse changes hands (pass, elimination, leave): key anything tied to
	                          -- one holder by this, never by the holder's id (→ S12; H15's mark used it)
	winner: number?,
	over: boolean,
	started: number,          -- when the round began: the end phase's clock (rule 51, H23)
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

-- Where each runner starts a round (H8, tag.md §4): evenly along `spread` studs of floor centred on `centre`, the
-- starter at the left end and the rest in rotation order after it, so the new "it" never starts beside anyone. One
-- runner stands at the left end. Returns { [id] = x }. The server places the bodies; this only picks the spots.
function Tag.startPlaces(order: { number }, starter: number, centre: number, spread: number): { [number]: number }
	local ids, start = {}, table.find(order, starter) or 1
	for k = 0, #order - 1 do table.insert(ids, order[(start + k - 1) % #order + 1]) end
	local left, gap = centre - spread / 2, if #ids > 1 then spread / (#ids - 1) else 0
	local places = {}
	for i, id in ids do places[id] = left + (i - 1) * gap end
	return places
end

function Tag.newRound(order: { number }, starter: number, now: number): Round
	local alive = {}
	for _, id in order do alive[id] = true end
	local frozenUntil = now + Config.START_FREEZE
	return {
		order = table.clone(order), alive = alive, it = starter, fuse = Config.FUSE_START, since = now,
		frozenUntil = frozenUntil, chaseFrom = frozenUntil, eliminations = 0, hold = 0, winner = nil, over = false,
		started = now,
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

-- Two runner boxes (centre x, y) touch within the reach (TAG_REACH across, TAG_REACH_Y up and down; H40: the hand
-- reaches across, as far as the drawn sprite does) plus `slack` studs on each axis.
function Tag.overlaps(ax: number, ay: number, bx: number, by: number, slack: number): boolean
	return math.abs(ax - bx) <= Config.RUNNER_WIDTH + Config.TAG_REACH + slack
		and math.abs(ay - by) <= Config.RUNNER_HEIGHT + Config.TAG_REACH_Y + slack
end

-- H38: does a runner box moving in a straight line from (ax0, ay0) to (ax1, ay1) touch the box at (bx, by) at any
-- point on the way, within `slack` studs of reach? (Tag.overlaps at every point of the segment: a segment against a
-- box, the slab test.) A dash covers 2-4 studs between two frames and a body is 2 wide: without this a dash straight
-- through a runner could land on no frame at all.
function Tag.sweeps(ax0: number, ay0: number, ax1: number, ay1: number, bx: number, by: number, slack: number): boolean
	local hx, hy = Config.RUNNER_WIDTH + Config.TAG_REACH + slack, Config.RUNNER_HEIGHT + Config.TAG_REACH_Y + slack
	local t0, t1 = 0, 1
	for _, axis in { { ax0 - bx, ax1 - ax0, hx }, { ay0 - by, ay1 - ay0, hy } } do
		local p, d, h = axis[1], axis[2], axis[3]
		if d == 0 then
			if math.abs(p) > h then return false end
		else
			local u, v = (-h - p) / d, (h - p) / d
			if u > v then u, v = v, u end
			t0, t1 = math.max(t0, u), math.min(t1, v)
			if t0 > t1 then return false end
		end
	end
	return true
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
-- older target sample, not the same frame. A claimant sample marked `untrusted` (H12: recorded while the server's speed
-- check, shared/MoveCheck, held that runner suspect) is never used; a target's is (the tagger did nothing wrong).
-- `iframe` (H19): recorded inside a dash's i-frames (rule 45: DASH_IFRAMES from a dash the SERVER saw start, at most
-- one per dash cooldown, so nobody is "dashing" for ever).
-- H38 (rule 45 as Danzo rewrote it, 2026-11-18: "as tagger, dashing into or through you should count as a tag,
-- unless you are also dashing or are the one dashing through the tagger"):
--   a DASHING TAGGER sweeps: the whole path between two of its samples counts (Tag.sweeps), with TAG_DASH_REACH more
--   reach, so a dash through a runner tags even when no single frame has the two boxes touching;
--   a DASHING TARGET cannot be tagged by a dashing tagger, nor while its own dash goes at or through the tagger (H40:
--   Tag.dodges; a dash AWAY is taggable).
-- The target's dash is judged at the moment the tagger SAW it (the older target sample), like everything else here.
-- H40 (dash-tag.md §7) narrows the dodge to Danzo's own words: a target inside its i-frames dodges only when the
-- tagger is dashing too, or when its dash is aimed AT the tagger (through it). A runner dashing AWAY from a tagger
-- that touches it is tagged: the dash buys distance, never invulnerability (QA Central: "I can just spam ... dashing").
export type Sample = { t: number, x: number, y: number, untrusted: boolean?, iframe: boolean? }
local SWEEP_GAP = 0.1 -- two claimant samples further apart than this are not one motion (a stall, a rebuilt body)

-- Does target sample b[j] dodge a touch by claimant sample `sa` (rule 45 as H38 and H40 shaped it)? Only inside the
-- target's i-frames, and then: the claimant dashing too, or the claimant lying ahead along the target's dash from the
-- spot the dash left (the last sample before its i-frames). A dash the history cannot place (no motion yet) dodges,
-- as before H40.
function Tag.dodges(b: { Sample }, j: number, sa: Sample): boolean
	local sb = b[j]
	if not sb.iframe then return false end
	if sa.iframe then return true end
	local k = j
	while k > 1 and b[k].iframe and sb.t - b[k - 1].t <= Config.DASH_IFRAMES + SWEEP_GAP do k -= 1 end
	local dir = sb.x - b[k].x
	if dir == 0 then return true end
	return (sa.x - b[k].x) * dir > 0
end

function Tag.touchedBetween(a: { Sample }, b: { Sample }, from: number, to: number, lag: number): boolean
	for i = #a, 1, -1 do
		local sa = a[i]
		if sa.t < from then break end
		if sa.t <= to and not sa.untrusted then
			local prev = a[i - 1]
			local dash = sa.iframe == true and prev ~= nil and not prev.untrusted and sa.t - prev.t <= SWEEP_GAP
			for j = #b, 1, -1 do
				local sb = b[j]
				if sb.t < from or sb.t < sa.t - lag then break end
				if sb.t <= sa.t and not Tag.dodges(b, j, sa) then
					if Tag.overlaps(sa.x, sa.y, sb.x, sb.y, Config.TAG_GRACE) then return true end
					if dash and prev and Tag.sweeps(prev.x, prev.y, sa.x, sa.y, sb.x, sb.y, Config.TAG_GRACE + Config.TAG_DASH_REACH) then
						return true
					end
				end
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
	r.hold += 1
	r.fuse = fuse
	r.since = now
	r.frozenUntil = now + Config.TAG_FREEZE
	r.chaseFrom = r.frozenUntil
	return fuse, fuse - left
end

-- Eliminate living runner `id` (H24: the one path for a burn-out and the closing walls' grace running out). It is a
-- ghost for the rest of the round: no comeback (DESIGN §3 rule 38, H16). Every elimination shrinks the next fresh fuse.
-- If it held the fuse, the next alive runner after it in join order (rotation, rule 5) takes over with a fresh, shorter
-- fuse and the tag freeze; a non-holder's death leaves the holder and its fuse alone. The round ends when one runner is
-- left (or none, in a round that started with one). Returns whether anything changed.
function Tag.eliminate(r: Round, id: number, now: number): boolean
	if r.over or not r.alive[id] then return false end
	local wasIt = r.it == id
	r.alive[id] = false
	r.eliminations += 1
	local left = Tag.aliveCount(r)
	if left <= 1 then
		r.over = true
		r.it = nil
		r.hold += 1
		r.winner = if left == 1 then Tag.nextStarter(r.order, r.alive, id) else nil
		return true
	end
	if wasIt then
		r.hold += 1
		r.it = Tag.nextStarter(r.order, r.alive, id)
		r.fuse = Tag.freshFuse(r.eliminations)
		r.since = now
		r.frozenUntil = now + Config.TAG_FREEZE
		r.chaseFrom = r.frozenUntil
	end
	return true
end

-- Advance the round. Returns the id eliminated this call, if the holder's fuse ran out (Tag.eliminate does the rest).
function Tag.tick(r: Round, now: number): number?
	local it = r.it
	if r.over or it == nil or Tag.fuseLeft(r, now) > 0 then return nil end
	Tag.eliminate(r, it, now)
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
		r.hold += 1
		r.frozenUntil = now + Config.TAG_FREEZE
		r.chaseFrom = r.frozenUntil
		if r.it == nil then r.over = true end
	end
end

-- Rule 4: "it" runs IT_SPEED x faster from the first step (H40), and speeds up further the longer a chase lasts; the
-- ramp resets on a tag. Multiplier on the run speed.
function Tag.chaserBoost(chaseTime: number): number
	local t = chaseTime - Config.RAMP_DELAY
	if t <= 0 then return Config.IT_SPEED end
	return Config.IT_SPEED * (1 + Config.RAMP_MAX * math.min(1, t / Config.RAMP_TIME))
end

-- The fastest run-speed multiplier any runner can have (the holder at the top of its ramp, or a grant, in the end
-- phase): the speed check's x rate must stay above RUN_SPEED x this (config.test, move_check.test).
function Tag.topSpeedMult(): number
	return math.max(Config.IT_SPEED * (1 + Config.RAMP_MAX), 1 + Config.GRANT_BOOST) * Config.END_PHASE_SPEED
end

-- A runner's run-speed multiplier (rules 4, 46; H22): the holder's ramp, a ghost's boost grant, never both stacked:
-- boost = max(ramp, grant). The grant equals the ramp's bonus (+15%); since H40 "it" starts at IT_SPEED, so a granted
-- holder gains only while its ramp is under the grant, and is never above the ramp's top.
-- H23, rule 51: in the end phase every LIVING runner's multiplier is that x END_PHASE_SPEED (the caller passes
-- endPhase only for the living); the dash is never scaled (Movement), so the speed check's budget still holds.
function Tag.speedMult(isIt: boolean, chaseTime: number, granted: boolean, endPhase: boolean?): number
	local ramp = if isIt then Tag.chaserBoost(chaseTime) else 1
	local m = math.max(ramp, if granted then 1 + Config.GRANT_BOOST else 1)
	return if endPhase then m * Config.END_PHASE_SPEED else m
end

-- Rule 51 (H23, docs/systems/endgame.md): the end phase is on once only two are left alive in a round that began with
-- three or more (a round that STARTED with two is a normal fuse until END_PHASE_AFTER), or once the round has run
-- END_PHASE_AFTER. Sticky with no stored flag: the living only ever fall and the clock only runs on. The server
-- decides it on its own clock and sends it in MatchState; clients only read it.
function Tag.endPhase(r: Round, now: number): boolean
	if r.over then return false end
	return (#r.order > 2 and Tag.aliveCount(r) <= 2) or now - r.started >= Config.END_PHASE_AFTER
end

-- Rule 50 (H23): how far the holder's ignition has grown, 0 above IGNITE_AT seconds left, rising linearly to 1 at 0.
-- Every client draws it from the replicated fuse; nothing decides on it.
function Tag.ignition(fuseLeft: number): number
	if fuseLeft >= Config.IGNITE_AT then return 0 end
	return math.clamp(1 - fuseLeft / Config.IGNITE_AT, 0, 1)
end

-- Round-ready (H11, players.md §5): a round may start once every present PLAYER has told the server it is drawing
-- (Remotes.Ready), or once the round has waited `waited` >= Config.READY_TIMEOUT for them, so one stalled client
-- cannot hold everyone. `bots` are runners with no client (the Studio dummy): never waited for.
function Tag.readyToStart(ids: { number }, ready: { [number]: boolean }, bots: { [number]: boolean }, waited: number)
	: boolean
	if waited >= Config.READY_TIMEOUT then return true end
	for _, id in ids do
		if not bots[id] and not ready[id] then return false end
	end
	return true
end

return Tag
