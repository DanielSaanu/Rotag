local Config = __require("Config")
local Tag = __require("Tag")
local Movement = __require("Movement")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B, C, D = 101, 202, 303, 404

do -- §2: the first it starts with 45 s; a pass hands over remaining + 5 (the locked example: 20 left -> 25)
	local r = Tag.newRound({ A, B }, A, 0)
	assert(r.it == A and near(r.fuse, Config.FUSE_START), "45 s on the first it")
	local now = Config.START_FREEZE + (Config.FUSE_START - 20) -- 20 s left
	assert(near(Tag.fuseLeft(r, now), 20), "fuse burns after the start freeze")
	local fuse = Tag.pass(r, B, now)
	assert(near(fuse, 25) and r.it == B, "20 s left hands over 25 s")
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
	assert(not Tag.canClaim(r, A, B, 1), "frozen at the start")
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

do -- rule 6: the server confirms from its own position history, with grace and a capped rewind
	local touch = Config.RUNNER_WIDTH + Config.TAG_REACH
	assert(Tag.overlaps(0, 0, touch, 0, 0), "boxes in reach")
	assert(not Tag.overlaps(0, 0, touch + 0.01, 0, 0), "just out of reach")
	assert(Tag.overlaps(0, 0, touch + Config.TAG_GRACE, 0, Config.TAG_GRACE), "the server's grace")
	local function hist(xs) local h = {} for i, x in xs do h[i] = { t = i * 0.1, x = x, y = 0 } end return h end
	local far = touch + Config.TAG_GRACE + 1
	local a = hist({ 0, 0, 0, 0, 0 })
	local b = hist({ far, far, touch, far, far }) -- touched at t = 0.3, apart since
	assert(Tag.confirm(a, b, 0.5, 0.25), "a touch 0.2 s ago is inside a 0.25 s rewind")
	assert(not Tag.confirm(a, b, 0.5, 0.1), "but not inside 0.1 s")
	assert(not Tag.confirm(a, b, 0.5 + Config.TAG_REWIND_MAX, 5), "a huge claimed ping is capped")
	assert(not Tag.confirm(a, hist({ far, far, far, far, far }), 0.5, 0.3), "never touched: dropped")
	local short = hist({ far, far, touch, far, far })
	table.remove(short, 1) -- b respawned and missed the oldest frame: pairs still line up from the newest end
	assert(Tag.confirm(a, short, 0.5, 0.25), "unequal histories pair by frame from the newest end")
	local skew = hist({ far, far, touch, far, far })
	skew[3].t = 0.31
	assert(not Tag.confirm(a, skew, 0.5, 0.3), "samples from different frames are never paired")
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
