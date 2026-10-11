local Config = __require("Config")
local Tag = __require("Tag")
local Movement = __require("Movement")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B, C, D = 101, 202, 303, 404

do -- §2: the first it starts with 45 s; a pass hands over remaining + the bonus (§2's example: 20 left -> 25 at +5)
	local r = Tag.newRound({ A, B }, A, 0)
	assert(r.it == A and near(r.fuse, Config.FUSE_START), "45 s on the first it")
	local now = Config.START_FREEZE + (Config.FUSE_START - 20) -- 20 s left
	assert(near(Tag.fuseLeft(r, now), 20), "fuse burns after the start freeze")
	local fuse = Tag.pass(r, B, now)
	assert(near(fuse, 20 + Config.FUSE_PASS_BONUS) and r.it == B, "20 s left hands over 20 + the bonus")
end

do -- the cap (Danzo 2026-10-11): a pass never lifts the fuse above the fuse this life started with
	local r = Tag.newRound({ A, B, C }, A, 0)
	local t = Config.START_FREEZE + 0.5 -- 0.5 s burnt: 44.5 left, + the bonus would pass 45
	assert(Config.FUSE_PASS_BONUS > 0.5, "the case needs a bonus bigger than the burn")
	assert(near(Tag.pass(r, B, t), Config.FUSE_START), "capped at 45 on the first life")
	r.fuse, r.since, r.frozenUntil = 1, t, t -- B burns out: C's fresh life is 35
	assert(Tag.tick(r, t + 1) == B and near(r.fuse, Tag.freshFuse(1)), "C starts on 35")
	local t2 = t + 1 + Config.TAG_FREEZE + 0.5
	assert(near(Tag.pass(r, A, t2), Tag.freshFuse(1)), "after an elimination the cap is that life's fresh fuse")
	local t3 = t2 + Config.TAG_FREEZE + 20 -- 20 s burnt: well under the cap, the bonus is added in full
	assert(near(Tag.pass(r, C, t3), Tag.freshFuse(1) - 20 + Config.FUSE_PASS_BONUS), "under the cap: remaining + bonus")
end

do -- the fuse waits while the holder is frozen (start freeze, and the freeze after a pass)
	local r = Tag.newRound({ A, B }, A, 10)
	assert(near(Tag.fuseLeft(r, 10 + Config.START_FREEZE), Config.FUSE_START), "no burn in the start freeze")
	assert(near(Tag.fuseLeft(r, 10 + Config.START_FREEZE + 1), Config.FUSE_START - 1), "burns once it ends")
	local t = 20
	Tag.pass(r, B, t)
	local after = Tag.fuseLeft(r, t)
	assert(near(Tag.fuseLeft(r, t + Config.TAG_FREEZE), after), "no burn in the pass freeze")
	assert(near(Tag.fuseLeft(r, t + Config.TAG_FREEZE + 2), after - 2), "burns after the pass freeze")
end

do -- rule 1, no tag-backs: the new holder cannot claim while frozen; only it may claim; never self or the out
	local r = Tag.newRound({ A, B, C }, A, 0)
	assert(not Tag.canClaim(r, A, B, Config.START_FREEZE / 2), "frozen at the start")
	local t = Config.START_FREEZE + 0.01
	assert(Tag.canClaim(r, A, B, t), "it may tag once the freeze ends")
	assert(not Tag.canClaim(r, B, A, t), "only it may claim")
	assert(not Tag.canClaim(r, A, A, t), "not yourself")
	Tag.pass(r, B, t)
	local ok, why = Tag.canClaim(r, B, A, t + Config.TAG_FREEZE - 0.01)
	assert(not ok and why == "frozen", "no tag-back inside the freeze")
	assert(Tag.canClaim(r, B, A, t + Config.TAG_FREEZE + 0.01), "the freeze ends")
	r.alive[C] = false
	assert(not Tag.canClaim(r, B, C, t + 5), "an eliminated runner cannot be tagged")
end

do -- rule 5: rotation in join order, skipping the absent, wrapping; never random
	local order = { A, B, C }
	local all = { [A] = true, [B] = true, [C] = true }
	assert(Tag.nextStarter(order, all, nil) == A, "first round: first to join")
	assert(Tag.nextStarter(order, all, A) == B and Tag.nextStarter(order, all, C) == A, "rotates and wraps")
	assert(Tag.nextStarter(order, { [A] = true, [C] = true }, A) == C, "skips the absent")
	assert(Tag.nextStarter(order, all, 999) == A, "an unknown previous starts at the top")
	assert(Tag.nextStarter({ A }, { [A] = true }, A) == A, "one player is always it")
	assert(Tag.nextStarter(order, {}, A) == nil, "nobody present")
end

do -- §2 decision e: the fresh fuse after each elimination shrinks 45, 35, 25, floored at FUSE_MIN
	assert(Tag.freshFuse(0) == 45 and Tag.freshFuse(1) == 35 and Tag.freshFuse(2) == 25, "45, 35, 25")
	assert(Tag.freshFuse(10) == Config.FUSE_MIN, "floored")
end

do -- elimination: holder out, next alive after them is it with the shrunk fuse, frozen; last one standing wins
	local r = Tag.newRound({ A, B, C, D }, B, 0)
	local burnout = Config.START_FREEZE + Config.FUSE_START
	assert(Tag.tick(r, burnout - 0.01) == nil, "not yet")
	assert(Tag.tick(r, burnout) == B, "B's fuse ran out")
	assert(not r.alive[B] and r.it == C and near(r.fuse, 35) and Tag.frozen(r, burnout), "C takes a 35 s fuse")
	local t2 = burnout + Config.TAG_FREEZE + 35
	assert(Tag.tick(r, t2) == C and r.it == D and near(r.fuse, 25), "then D with 25")
	assert(Tag.tick(r, t2 + Config.TAG_FREEZE + 25) == D, "D out")
	assert(r.over and r.winner == A and r.it == nil, "A wins")
	assert(Tag.tick(r, 1e6) == nil, "nothing after the end")
end

do -- one player: they are it, the fuse runs, they are out, the round ends with no winner (the solo test)
	local r = Tag.newRound({ A }, A, 0)
	assert(Tag.tick(r, Config.START_FREEZE + Config.FUSE_START) == A and r.over and r.winner == nil, "solo round")
end

do -- leaving: a holder who leaves hands the fuse as is to the next; down to one, the round ends
	local r = Tag.newRound({ A, B, C }, A, 0)
	local t = Config.START_FREEZE + 10
	Tag.leave(r, A, t)
	assert(r.it == B and near(r.fuse, Config.FUSE_START - 10) and not r.over, "B carries A's fuse")
	Tag.leave(r, C, t + 1)
	assert(r.over and r.winner == B, "B is the last one in")
end

do -- rule 6: the server confirms from its own position history, with grace and a capped allowance
	local touch = Config.RUNNER_WIDTH + Config.TAG_REACH
	assert(Tag.overlaps(0, 0, touch, 0, 0), "boxes in reach")
	assert(not Tag.overlaps(0, 0, touch + 0.01, 0, 0), "just out of reach")
	assert(Tag.overlaps(0, 0, touch + Config.TAG_GRACE, 0, Config.TAG_GRACE), "the server's grace")
	local function hist(xs) local h = {} for i, x in xs do h[i] = { t = i * 0.1, x = x, y = 0 } end return h end
	local far = touch + Config.TAG_GRACE + 1
	local a = hist({ 0, 0, 0, 0, 0 })
	local b = hist({ far, far, touch, far, far }) -- touched at t = 0.3, apart since
	assert(Tag.confirm(a, b, 0.5, 0.25), "a same-frame touch 0.2 s ago is inside a 0.25 s rewind")
	assert(not Tag.confirm(a, b, 0.5, 0.1), "but not inside 0.1 s")
	assert(not Tag.confirm(a, b, 0.5 + Config.TAG_REWIND_MAX, 5), "a huge claimed ping is capped")
	assert(not Tag.confirm(a, hist({ far, far, far, far, far }), 0.5, 0.3), "never touched: dropped")
	local short = hist({ far, far, touch, far, far })
	table.remove(short, 1) -- b respawned and missed the oldest frame: samples still pair by their time
	assert(Tag.confirm(a, short, 0.5, 0.25), "unequal histories pair by time")
	assert(not Tag.touchedBetween(a, hist({ far, far, far, far, far }), 0, 0.5, Config.TAG_REWIND_MAX),
		"never touched: dropped, whatever the allowance")
end

-- H6 (measured in Studio, tag.md §2): the server sees a client-owned body ~0.18 s after the client moved it, and a
-- claim arrives before the body does. Histories at 60 Hz, built from where each runner truly was.
local HZ = 60
local function track(fromT, toT, xAt)
	local h = {}
	for i = math.floor(fromT * HZ + 0.5), math.floor(toT * HZ + 0.5) do
		local t = i / HZ
		table.insert(h, { t = t, x = xAt(t), y = 0 })
	end
	return h
end
local LAG = 0.18

do -- the claim window: back by the capped allowance, forward by the wait
	local from, deadline, lag = Tag.claimWindow(1, 0.3)
	assert(near(from, 0.7) and near(deadline, 1 + Config.TAG_CONFIRM_WAIT) and near(lag, 0.3), "the window")
	local f2, _, l2 = Tag.claimWindow(1, 5)
	assert(near(l2, Config.TAG_REWIND_MAX) and near(f2, 1 - Config.TAG_REWIND_MAX), "a huge ping is capped")
	assert(Config.TAG_CONFIRM_WAIT > LAG, "the wait outlasts the claimant's measured body lag")
	assert(Config.TAG_VIEW_DELAY >= 2 * LAG and Config.TAG_REWIND_MAX >= Config.TAG_VIEW_DELAY,
		"the allowance covers two measured hops (a client tagging a client)")
end

do -- a run straight through the dummy (Danzo: "only able to tag the block once"): it touches on the tagger's screen
	-- for ~0.08 s; the server sees that touch only after the claim has arrived
	local touchAt = 1.0 -- the true moment the boxes cross: claimant from the left at 45, dummy from the right at 18
	local function claimant(t) return 45 * (t - LAG - touchAt) end -- the server's copy, LAG late
	local function dummy(t) return -18 * (t - touchAt) end -- the server's own runner: its truth
	local a, b = track(0.5, 1.6, claimant), track(0.5, 1.6, dummy)
	local at = touchAt + 0.02 -- the claim lands a frame after the touch on the tagger's screen
	local from, deadline, lag = Tag.claimWindow(at, 0 + Config.TAG_VIEW_DELAY)
	assert(not Tag.touchedBetween(a, b, from, at, 0), "judged on arrival, same frame only: missed (the H6 bug)")
	assert(Tag.touchedBetween(a, b, from, deadline, lag), "judged until the deadline: confirmed")
	assert(not Tag.touchedBetween(a, b, from, at + 0.03, lag), "nor a frame before the claimant's body shows the touch")
end

do -- a chase in step: the tagger trails the dummy at a touch on its screen; on the server it never touches in any
	-- one frame, so waiting alone can never confirm it; pairing with the target's older samples does
	local function dummy(t) return 30 * t end
	local function claimant(t) return 30 * (t - LAG) - Config.RUNNER_WIDTH end -- touching, LAG late on the server
	local a, b = track(0, 2, claimant), track(0, 2, dummy)
	local from, deadline, lag = Tag.claimWindow(1, Config.TAG_VIEW_DELAY)
	assert(not Tag.touchedBetween(a, b, from, deadline, 0), "no same-frame touch anywhere in the window")
	assert(Tag.touchedBetween(a, b, from, deadline, lag), "the target's older sample confirms it")
	assert(not Tag.touchedBetween(a, b, from, deadline, 0.1), "an allowance shorter than the lag does not")
end

do -- what the allowance never pairs: a target NEWER than the claimant, or older than the allowance or the window
	local a = { { t = 1.0, x = 0, y = 0 } }
	assert(not Tag.touchedBetween(a, { { t = 1.1, x = 0, y = 0 } }, 0, 2, 0.5), "never the future")
	assert(Tag.touchedBetween(a, { { t = 0.6, x = 0, y = 0 } }, 0, 2, 0.5), "0.4 s older is inside 0.5")
	assert(not Tag.touchedBetween(a, { { t = 0.4, x = 0, y = 0 } }, 0, 2, 0.5), "0.6 s older is not")
	assert(not Tag.touchedBetween(a, { { t = 0.6, x = 0, y = 0 } }, 0.7, 2, 0.5), "nor before the window opens")
	assert(not Tag.touchedBetween({ { t = 2.1, x = 0, y = 0 } }, { { t = 2.0, x = 0, y = 0 } }, 0, 2, 0.5),
		"nor a claimant sample after the deadline")
end

do -- rule 4: the chaser ramp starts after RAMP_DELAY, reaches RAMP_MAX after RAMP_TIME, and Movement uses it
	assert(Tag.chaserBoost(0) == 1 and Tag.chaserBoost(Config.RAMP_DELAY) == 1, "no boost early")
	assert(near(Tag.chaserBoost(Config.RAMP_DELAY + Config.RAMP_TIME / 2), 1 + Config.RAMP_MAX / 2), "halfway")
	assert(near(Tag.chaserBoost(1e6), 1 + Config.RAMP_MAX), "capped")
	local s = Movement.new(0, 0)
	local floor = { ground = 0 }
	local boost = 1 + Config.RAMP_MAX
	for _ = 1, 120 do
		Movement.step(s, { moveX = 1, jumpPressed = false, jumpHeld = false, dashPressed = false, speedMult = boost },
			floor, 1 / 60)
	end
	assert(near(s.vx, Config.RUN_SPEED * boost, 1e-6), "the boosted top speed is reached and held")
	for _ = 1, 120 do
		Movement.step(s, { moveX = 1, jumpPressed = false, jumpHeld = false, dashPressed = false }, floor, 1 / 60)
	end
	assert(near(s.vx, Config.RUN_SPEED, 1e-6), "no multiplier: back to the plain top speed")
end

print("tag ok")
