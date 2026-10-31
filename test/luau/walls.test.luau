local Config = __require("Config")
local Tag = __require("Tag")
local Walls = __require("Walls")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local A, B, C, D = 101, 202, 303, 404
local DT = 1 / 60

-- A position record the way server/Walls builds it from Match's history: newest x and whether it is trusted.
local function record(xs, bad)
	return function(id)
		local x = xs[id]
		if x == nil then return nil, nil end
		return x, not (bad and bad[id])
	end
end

-- Step the walls at 60 Hz from t0 for `secs`; returns every id eliminated, in order, and the time it stopped.
local function run(w, r, t0, secs, pos, held)
	local out, t = {}, t0
	for _ = 1, math.floor(secs / DT + 0.5) do
		t += DT
		local gone = Walls.step(w, r, t, DT, pos, held)
		for _, id in gone do table.insert(out, id) end
	end
	return out, t
end

do -- opening: centred on the living, every living runner inside, WALL_START_PAD past the farthest
	local r = Tag.newRound({ A, B, C, D }, A, 0)
	r.alive[D] = false -- a ghost far away counts for nothing
	local xs = { [A] = -30, [B] = 0, [C] = 90, [D] = 400 }
	local w = Walls.open(r, 100, record(xs)) :: any
	assert(w and near(w.x, 20), "the centre is the living mean (-30 + 0 + 90) / 3 = 20, the ghost ignored")
	assert(near(w.hw0, 70 + Config.WALL_START_PAD), "half-width: the farthest living (90, 70 from the centre) + the pad")
	for _, id in { A, B, C } do assert(not Walls.outside(w, 100, xs[id]), "nobody starts outside") end
	local tight = Walls.open(r, 0, record({ [A] = 0, [B] = 2, [C] = 4 })) :: any
	assert(near(tight.hw0, Config.WALL_START_MIN), "a tight pack: the walls start at WALL_START_MIN, not on top of it")
	assert(Walls.open(r, 0, record({})) == nil, "no sample yet: no walls")
	assert(Walls.open(r, 0, record(xs, { [A] = true, [B] = true, [C] = true })) == nil, "only untrusted samples: none")
end

do -- the close: linear from hw0 to WALL_MIN_HW over WALL_CLOSE_TIME, then held; the rate clients extrapolate with
	local r = Tag.newRound({ A, B }, A, 0)
	local w = Walls.open(r, 10, record({ [A] = -50, [B] = 50 })) :: any
	local hw0 = 50 + Config.WALL_START_PAD
	assert(near(Walls.halfWidth(w, 10), hw0), "starts at hw0")
	assert(near(Walls.halfWidth(w, 10 + Config.WALL_CLOSE_TIME / 2), (hw0 + Config.WALL_MIN_HW) / 2), "halfway")
	assert(near(Walls.halfWidth(w, 10 + Config.WALL_CLOSE_TIME), Config.WALL_MIN_HW), "closed")
	assert(near(Walls.halfWidth(w, 10 + 1000), Config.WALL_MIN_HW), "never below WALL_MIN_HW")
	local rate = Walls.closeRate(w, 11)
	assert(near(rate, (hw0 - Config.WALL_MIN_HW) / Config.WALL_CLOSE_TIME), "the inward rate")
	assert(near(Walls.halfWidth(w, 11) - rate * 1, Walls.halfWidth(w, 12)), "extrapolating with it is exact")
	assert(Walls.closeRate(w, 10 + Config.WALL_CLOSE_TIME) == 0, "no rate once closed")
	local _, rows = Walls.rows(w, 11)
	local win = Walls.rows(w, 11)
	assert(#rows == 0 and win.vhw < 0 and near(win.hw, Walls.halfWidth(w, 11)), "rows: the window, nobody out")
end

do -- the follow: toward the living mean at WALL_FOLLOW at most, never a snap; an untrusted sample is not followed
	local r = Tag.newRound({ A, B }, A, 0)
	local xs = { [A] = 0, [B] = 0 }
	local w = Walls.open(r, 0, record(xs)) :: any
	xs[A], xs[B] = 200, 200 -- the pack is suddenly far right (a teleport, or two quick dashes)
	Walls.step(w, r, DT, DT, record(xs))
	assert(near(w.x, Config.WALL_FOLLOW * DT) and near(w.vx, Config.WALL_FOLLOW), "one frame: WALL_FOLLOW x dt")
	run(w, r, DT, 1, record(xs))
	assert(near(w.x, Config.WALL_FOLLOW * (1 + DT), 1e-3), "after 1 s it has moved WALL_FOLLOW studs, no more")
	local w2 = Walls.open(r, 0, record({ [A] = 0, [B] = 0 })) :: any
	Walls.step(w2, r, DT, DT, record({ [A] = 0, [B] = 900 }, { [B] = true }))
	assert(near(w2.x, 0), "an untrusted sample drags nothing")
	assert(Config.WALL_FOLLOW < Config.RUN_SPEED / 2, "a zone, not a camera: far slower than a run")
	-- a pack swaying about one spot (Studio: three dummies patrolling) barely moves it: eased, not chased at the cap
	local w3 = Walls.open(r, 0, record({ [A] = 0, [B] = 0 })) :: any
	local swing, lo, hi = { [A] = 0, [B] = 0 }, math.huge, -math.huge
	for k = 1, 60 * 20 do
		local m = 13 * math.sin(k / 60 * 2 * math.pi / 4.4) -- the patrol mean: +-13 studs, a 4.4 s period
		swing[A], swing[B] = m, m
		Walls.step(w3, r, k / 60, DT, record(swing))
		if k > 60 * 10 then lo, hi = math.min(lo, w3.x), math.max(hi, w3.x) end
	end
	assert(hi - lo < 10, ("a +-13 stud sway moves the walls %.1f studs end to end, under 10"):format(hi - lo))
end

do -- the grace: starts full when the whole body is past a wall, runs down, resets the moment the runner is back in
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0 }
	local w = Walls.open(r, 0, record(xs)) :: any
	local edge = Walls.halfWidth(w, DT) + Config.RUNNER_WIDTH / 2
	xs[C] = edge - 0.01 -- straddling the wall: still in
	local _, ch = Walls.step(w, r, DT, DT, record(xs))
	assert(w.left[C] == nil and not ch, "half a body past the wall is still in")
	xs[C] = edge + 500 -- far enough that the drift toward the mean cannot reach it in the test
	_, ch = Walls.step(w, r, 2 * DT, DT, record(xs))
	assert(ch and near(w.left[C], Config.WALL_GRACE - DT), "out: the grace starts, and the send is due at once")
	run(w, r, 2 * DT, 1, record(xs))
	assert(near(w.left[C], Config.WALL_GRACE - 1 - DT, 1e-3), "1 s outside: a second gone")
	xs[C] = 0
	_, ch = Walls.step(w, r, 1.1, DT, record(xs))
	assert(ch and w.left[C] == nil, "back in: cleared at once")
	xs[C] = 500
	Walls.step(w, r, 1.2, DT, record(xs))
	assert(near(w.left[C], Config.WALL_GRACE - DT), "out again: a FULL grace, not what was left")
	local _, rows = Walls.rows(w, 1.2)
	assert(#rows == 1 and rows[1].id == C and rows[1].left > 0, "the row MatchState carries")
end

do -- expiry: alive just before WALL_GRACE outside, eliminated at it; a non-holder's death leaves the fuse alone
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0 }
	local w = Walls.open(r, 0, record(xs)) :: any
	xs[C] = 1000
	local fuse, hold = Tag.fuseLeft(r, 2), r.hold
	local gone, t = run(w, r, 0, Config.WALL_GRACE - 0.05, record(xs))
	assert(#gone == 0 and r.alive[C], "not yet")
	gone, t = run(w, r, t, 0.1, record(xs))
	assert(#gone == 1 and gone[1] == C and not r.alive[C], "out of the walls for WALL_GRACE: eliminated")
	assert(r.it == A and r.hold == hold and r.eliminations == 1, "the holder keeps the fuse; no change of hands")
	assert(near(Tag.fuseLeft(r, 2), fuse), "the holder's fuse is untouched")
	assert(near(Tag.freshFuse(r.eliminations), Config.FUSE_START - Config.FUSE_SHRINK), "it still shrinks the next fuse")
	gone = run(w, r, t, 5, record(xs))
	assert(#gone == 0 and w.left[C] == nil, "a ghost is never judged again (rule 38)")
	local _, rows = Walls.rows(w, t + 5)
	assert(#rows == 0, "and never listed")
end

do -- the holder outside: eliminated like a burn-out; the next it in rotation gets a fresh fuse and the tag freeze
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0 }
	local w = Walls.open(r, 5, record(xs)) :: any
	xs[A] = -1000
	local hold = r.hold
	local gone, t = run(w, r, 5, Config.WALL_GRACE + 0.05, record(xs))
	assert(#gone == 1 and gone[1] == A and r.it == B, "the holder dies; B is next in rotation")
	assert(near(r.fuse, Tag.freshFuse(1)) and r.hold == hold + 1, "a fresh, shorter fuse, a new hold")
	assert(Tag.frozen(r, t) and r.frozenUntil - t > Config.TAG_FREEZE - 0.1 and r.frozenUntil - t <= Config.TAG_FREEZE,
		"and the tag freeze, from the frame it died (the run stopped 0.05 s later)")
end

do -- held runners: the tag freeze and an item hold pause the grace (no hold plus a wall kills); a hold never resets it
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0 }
	local w = Walls.open(r, 2, record(xs)) :: any
	xs[B] = 1000
	local _, t = run(w, r, 2, 1, record(xs))
	Tag.pass(r, B, t) -- B is tagged outside the walls: frozen TAG_FREEZE, cannot move
	local before = w.left[B]
	_, t = run(w, r, t, Config.TAG_FREEZE - 0.05, record(xs))
	assert(near(w.left[B], before), "frozen as the new it: the grace waits")
	local gone
	gone, t = run(w, r, t, 0.2, record(xs))
	assert(#gone == 0 and w.left[B] < before, "the freeze over: it runs again")
	xs[C] = -1000
	local trapped = true
	local function held(id) return trapped and id == C end
	_, t = run(w, r, t, 5, record(xs), held)
	assert(r.alive[C] and near(w.left[C], Config.WALL_GRACE), "trapped outside for 5 s: still alive, the grace untouched")
end

do -- trust (trust.md §4-5): an untrusted sample never changes inside/outside; a missing one neither
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 1000 }
	local w = Walls.open(r, 0, record({ [A] = 0, [B] = 0, [C] = 0 })) :: any
	Walls.step(w, r, DT, DT, record(xs))
	assert(w.left[C] ~= nil, "C is out")
	xs[C] = 0 -- a teleport back inside, flagged by the speed check
	local gone = run(w, r, DT, Config.WALL_GRACE, record(xs, { [C] = true }))
	assert(#gone == 1 and gone[1] == C, "an untrusted 'I am back in' never resets the grace")
	local r2 = Tag.newRound({ A, B, C }, A, 0)
	local w2 = Walls.open(r2, 0, record({ [A] = 0, [B] = 0, [C] = 0 })) :: any
	gone = run(w2, r2, 0, 5, record({ [A] = 0, [B] = 0, [C] = 1000 }, { [C] = true }))
	assert(#gone == 0 and w2.left[C] == nil, "an untrusted 'I am outside' starts nothing either")
	gone = run(w2, r2, 5, 5, record({ [A] = 0, [B] = 0 }))
	assert(#gone == 0, "no sample at all (C stalled): nothing changes")
end

do -- a leave while outside: out of the round, never eliminated by the walls, its row gone
	local r = Tag.newRound({ A, B, C }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0 }
	local w = Walls.open(r, 0, record(xs)) :: any
	xs[C] = 1000
	local _, t = run(w, r, 0, 1, record(xs))
	Tag.leave(r, C, t)
	local gone = run(w, r, t, 5, record(xs))
	assert(#gone == 0 and w.left[C] == nil and r.eliminations == 0, "a leaver is not a wall kill")
end

do -- two graces out on the same frame: the one that ran out first goes first; a tie, the holder; then join order.
	-- The round may end part-way: the last living runner is never eliminated with it.
	local r = Tag.newRound({ A, B, C, D }, A, 0)
	local xs = { [A] = 0, [B] = 0, [C] = 0, [D] = 0 }
	local w = Walls.open(r, 0, record(xs)) :: any
	w.left[C], w.left[D] = 0.01, 0.005 -- D ran out first
	local gone = Walls.step(w, r, 10, DT, function(id) return nil, nil end) -- past the start freeze
	assert(#gone == 2 and gone[1] == D and gone[2] == C, "the one further past 0 first")
	assert(r.it == A and Tag.aliveCount(r) == 2, "two ghosts, the holder still it")
	-- the final two, both out, both run out on the same frame: the holder goes, the runner wins
	w.left[A], w.left[B] = 0.01, 0.01
	gone = Walls.step(w, r, 10, DT, function(id) return nil, nil end) -- past the start freeze
	assert(#gone == 1 and gone[1] == A, "a tie: the holder first, and only the holder")
	assert(r.over and r.winner == B and r.alive[B], "the round ends with B the winner, alive")
	-- the same tie with the holder LATER in join order (C is it, B before it): still the holder first (→ Q5)
	local r3 = Tag.newRound({ A, B, C }, C, 0)
	Tag.eliminate(r3, A, 1)
	local w3 = Walls.open(r3, 0, record(xs)) :: any
	w3.left[B], w3.left[C] = 0.01, 0.01
	gone = Walls.step(w3, r3, 10, DT, function(id) return nil, nil end)
	assert(#gone == 1 and gone[1] == C and r3.winner == B, "the holder goes first even when later in join order")
	-- join order breaks a tie between two non-holders
	local r2 = Tag.newRound({ A, B, C, D }, A, 0)
	local w2 = Walls.open(r2, 0, record(xs)) :: any
	w2.left[D], w2.left[B] = 0.01, 0.01
	gone = Walls.step(w2, r2, 10, DT, function(id) return nil, nil end)
	assert(#gone == 2 and gone[1] == B and gone[2] == D, "a tie between runners: join order")
end

do -- the numbers' shape (endgame.md §7)
	local screen = Config.CAMERA_VIEW_HEIGHT * 16 / 9 -- studs across a 16:9 screen
	assert(Config.WALL_START_MIN >= screen / 2, "the walls start at least at a 16:9 screen's edges")
	assert(2 * Config.WALL_MIN_HW <= screen, "closed, both walls fit on one 16:9 screen")
	assert(2 * Config.WALL_MIN_HW >= 10 * Config.STUDS_PER_TILE, "closed, still 10+ tiles: a duel stays playable")
	-- the fastest a wall can come at you: a start as wide as a 250-stud map, plus the drift; under half a run
	assert((125 - Config.WALL_MIN_HW) / Config.WALL_CLOSE_TIME + Config.WALL_FOLLOW < Config.RUN_SPEED / 2,
		"a running runner always outruns a wall")
	assert(Config.WALL_GRACE * Config.RUN_SPEED > 2 * Config.WALL_START_PAD, "the grace is longer than a short way back")
	assert(Config.WALL_GRACE <= 3, "a SHORT time frame (Danzo, H24)")
end

print("walls ok")
