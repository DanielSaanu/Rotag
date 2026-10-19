--!include movement_world.luau
-- MoveCheck (H12, docs/systems/trust.md): the server's speed check on a client-owned runner. Honest runs are driven by
-- a real Movement runner in the box world (Q3), so the bound is tested against the rules it is derived from; cheats are
-- fed as the positions a cheating client would replicate.
local MoveCheck = __require("MoveCheck")

local BURST_X = MoveCheck.RATE_X * Config.MOVE_BURST_TIME

-- Feed one sample per frame from a Movement runner; returns the violations seen and the most budget ever spent (x).
local function watched(world, s, n, choose)
	local c = MoveCheck.new(s.x, s.y, 0)
	local bad, deepest, fastest = {}, 0, 0
	for i = 1, n do
		tick(world, s, choose(i, s))
		fastest = math.max(fastest, math.abs(s.vx))
		local ok, axis, over = MoveCheck.step(c, s.x, s.y, i * DT)
		if not ok then table.insert(bad, ("frame %d: %s over by %.2f"):format(i, tostring(axis), over or 0)) end
		deepest = math.max(deepest, BURST_X - c.bx)
	end
	return bad, deepest, fastest
end

-- The fastest chain Movement allows on the flat: dash the moment the cooldown allows, jump out of it on the next
-- frame (a jump keeps the dash speed and adds JUMP_H_BOOST), jump again on every landing; turn at the arena's walls.
local ARENA = { { -400, -10, 400, 0 }, { -410, -10, -400, 100 }, { 400, -10, 410, 100 } }
local function fastestChain()
	local dir, dashedAt = 1, -100
	return function(i, s)
		if s.x > 380 then dir = -1 elseif s.x < -380 then dir = 1 end
		local dash = s.dashes > 0 and s.dashCooldown <= 0
		if dash then dashedAt = i end
		return input({ moveX = dir, dash = dash, jump = i == dashedAt + 1 or s.grounded, held = true })
	end
end

do -- the rates are Movement's own caps (trust.md §2): a new move that is faster must raise them, or honest runs flag
	assert(MoveCheck.RATE_X == Config.DASH_SPEED, "x: the dash speed")
	assert(MoveCheck.RATE_UP == Config.JUMP_SPEED, "up: the jump speed")
	assert(MoveCheck.RATE_DOWN == Config.MAX_FALL, "down: the fall cap")
end

do -- the fastest honest chain, 10 s: never flagged; the burst it uses is pinned as a MEASUREMENT (→ S11)
	local s = standing(ARENA, 0)
	local bad, deepest, fastest = watched(ARENA, s, 600, fastestChain())
	assert(#bad == 0, "an honest dash-jump chain is never flagged: " .. (bad[1] or ""))
	assert(fastest <= Config.DASH_SPEED + Config.JUMP_H_BOOST + 1e-6, "no move goes past dash + jump boost, got " .. fastest)
	assert(fastest > Config.DASH_SPEED, "the chain really goes past the dash speed (the case the burst is for)")
	-- Measured 2026-10-12: 1.38 studs of the 24 (a jump out of a dash runs above DASH_SPEED until the bleed brings it back).
	assert(deepest > 1.2 and deepest < 1.6, ("burst used by the fastest chain (measurement): %.2f studs"):format(deepest))
end

do -- a wall-kick climb between two walls and a long fall: never flagged
	local WELL = { { -50, -10, 50, 0 }, { -6, 0, -5, 200 }, { 5, 0, 6, 200 } }
	local s = standing(WELL, 0)
	local bad = watched(WELL, s, 600, function(i, st)
		local dir = if st.vx >= 0 then 1 else -1
		return input({ moveX = dir, jump = i % 12 == 0, held = true, dash = i % 50 == 0 })
	end)
	assert(#bad == 0, "a wall-kick climb is never flagged: " .. (bad[1] or ""))
	local high = Movement.new(0, 150)
	bad = watched(FLOOR, high, 200, function() return input() end)
	assert(#bad == 0, "a fall at the fall cap is never flagged: " .. (bad[1] or ""))
end

do -- positions that land in steps (held 3 frames, then the whole move at once) are not punished: the held time refills
	local s = standing(ARENA, 0)
	local c = MoveCheck.new(s.x, s.y, 0)
	local choose, bad = fastestChain(), 0
	for i = 1, 600 do
		tick(ARENA, s, choose(i, s))
		if i % 3 == 0 and not MoveCheck.step(c, s.x, s.y, i * DT) then bad += 1 end
		if i % 3 ~= 0 and not MoveCheck.step(c, c.x, c.y, i * DT) then bad += 1 end
	end
	assert(bad == 0, "a stepped feed of the fastest chain is never flagged, got " .. bad)
end

do -- the server's copy catching up after a stop (seen in Studio: ~250 studs/s for 5 frames after the client stood still)
	local c = MoveCheck.new(0, 0, 0)
	local x, t = 0, 0
	for _ = 1, 30 do t += DT x += 120 * DT assert(MoveCheck.step(c, x, 0, t), "a dash is legal") end
	for _ = 1, 6 do t += DT assert(MoveCheck.step(c, x, 0, t), "the copy stalls") end
	for _ = 1, 5 do t += DT x += 250 * DT assert(MoveCheck.step(c, x, 0, t), "the catch-up (~21 studs) fits the burst") end
end

do -- a teleport past the burst is caught on the frame it lands; the trusted spot is where the runner was before it
	local c = MoveCheck.new(0, 2, 0)
	assert(MoveCheck.step(c, 1, 2, DT), "a short step is fine")
	local ok, axis, over = MoveCheck.step(c, 1 + BURST_X + 6, 2, 2 * DT)
	assert(not ok and axis == "x", "a teleport is an x violation")
	assert(over and near(over, 6 - MoveCheck.RATE_X * DT, 1e-6), "over by what the budget lacked, got " .. tostring(over))
	assert(c.suspect and c.trustX == 1 and c.trustY == 2, "suspect, and the snap-back spot is the last trusted one")
	assert(c.bx == 0, "the budget is emptied, not left negative")
	assert(MoveCheck.step(c, c.x + 0.5, 2, 3 * DT), "the next ordinary step is judged fresh (one teleport, one violation)")
	assert(c.suspect and c.trustX == 1, "but the runner stays suspect, and the trusted spot does not follow it")
	-- Clean for MOVE_CLEAR_TIME: trusted again, and the trusted spot follows it from then on.
	local t = 3 * DT
	while t < 3 * DT + Config.MOVE_CLEAR_TIME / 2 do t += DT MoveCheck.step(c, c.x, 2, t) end
	assert(c.suspect and c.trustX == 1 and near(c.bx, BURST_X), "budgets full again, but still suspect: spot unchanged")
	while t < 2 * DT + Config.MOVE_CLEAR_TIME do t += DT MoveCheck.step(c, c.x, 2, t) end
	assert(not c.suspect and c.trustX == c.x, "trusted again after a clean MOVE_CLEAR_TIME")
end

do -- the honest limit, pinned: a teleport inside the burst passes (trust.md §2: the price of not replaying inputs)
	local c = MoveCheck.new(0, 2, 0)
	assert(MoveCheck.step(c, BURST_X - 0.5, 2, DT), "a jump of just under the burst from rest is not caught")
	assert(not MoveCheck.step(c, BURST_X * 2 + 1, 2, 2 * DT), "a second one straight after is")
end

do -- sustained over-speed: 3 x RUN_SPEED is caught within a few seconds; 2 x is not (the bound is the dash speed)
	local function runAt(v, seconds)
		local c = MoveCheck.new(0, 2, 0)
		for i = 1, math.floor(seconds / DT) do
			if not MoveCheck.step(c, v * i * DT, 2, i * DT) then return i * DT end
		end
		return nil
	end
	local caught = runAt(3 * Config.RUN_SPEED, 10)
	local expect = BURST_X / (3 * Config.RUN_SPEED - MoveCheck.RATE_X)
	assert(caught and math.abs(caught - expect) < 0.05, ("3x run speed caught after %s s, expected ~%.2f"):format(
		tostring(caught), expect))
	assert(runAt(2 * Config.RUN_SPEED, 10) == nil, "2x run speed is under the dash speed: not caught (the limit)")
	assert(runAt(MoveCheck.RATE_X, 10) == nil, "exactly the dash speed forever: not caught")
end

do -- vertical: flying up faster than a jump, or falling faster than the cap, is caught; each axis on its own budget
	local function climb(vy, seconds)
		local c = MoveCheck.new(0, 0, 0)
		for i = 1, math.floor(seconds / DT) do
			local ok, axis = MoveCheck.step(c, 0, vy * i * DT, i * DT)
			if not ok then return axis end
		end
		return nil
	end
	assert(climb(Config.JUMP_SPEED + 10, 5) == "up", "flying up at jump speed + 10 is an up violation")
	assert(climb(Config.JUMP_SPEED, 5) == nil, "rising at the jump speed is not")
	assert(climb(-(Config.MAX_FALL + 20), 5) == "down", "falling past the cap is a down violation")
	assert(climb(-Config.MAX_FALL, 5) == nil, "falling at the cap is not")
	local c = MoveCheck.new(0, 0, 0)
	for i = 1, 60 do assert(MoveCheck.step(c, 100 * i * DT, -70 * i * DT, i * DT), "a fast diagonal under both caps is legal") end
end

do -- standing still costs nothing and never flags, however long
	local c = MoveCheck.new(5, 2, 0)
	for i = 1, 600 do assert(MoveCheck.step(c, 5, 2, i * DT), "standing is legal") end
	assert(near(c.bx, BURST_X) and not c.suspect, "the budget stays full")
end

do -- a teleport as the SERVER sees it (Studio 2026-10-12, a +60 client CFrame write): smoothed into 12 fast steps.
	-- Caught on the last of them, and the snap-back spot is where the runner stood before the ramp, not part-way up it.
	local xs = { 14.56, 15.21, 16.28, 17.64, 19.69, 22.73, 26.57, 30.97, 35.49, 40.65, 46.57, 51.96, 57.61, 62.56 }
	local c = MoveCheck.new(14.56, 1.7, 0)
	for _ = 1, 30 do MoveCheck.step(c, 14.56, 1.7, c.t + DT) end
	local caughtAt = nil
	for i = 2, #xs do
		if not MoveCheck.step(c, xs[i], 1.7, c.t + DT) and not caughtAt then caughtAt = xs[i] end
	end
	assert(caughtAt == 62.56, "the smoothed 60-stud teleport is caught at its last step, got " .. tostring(caughtAt))
	assert(c.trustX <= 17.7, "snap back to the last step still at a legal speed (17.64), not part-way up, got " .. c.trustX)
	-- The honest limit: the same ramp stopped after 32 studs is not caught (a +40 write in Studio was not either).
	local d = MoveCheck.new(14.56, 1.7, 0)
	local any = false
	for i = 2, 11 do if not MoveCheck.step(d, xs[i], 1.7, d.t + DT) then any = true end end
	assert(not any, "a smoothed teleport of 32 studs passes (trust.md §3)")
end

do -- carried from PR 1's QA: an orb pickup on a tolerated teleport is bounded like a tag, ~45 studs (trust.md §3).
	-- The server's Orbs.step skips an untrusted sample as either end of the path (server/Orbs), as here.
	local Orbs = __require("Orbs")
	local xs = { 14.56, 15.21, 16.28, 17.64, 19.69, 22.73, 26.57, 30.97, 35.49, 40.65, 46.57, 51.96, 57.61, 62.56 }
	local function taken(orbX)
		local spot = { x = orbX, y = 1.7, kind = "ghost" }
		local c = MoveCheck.new(xs[1], 1.7, 0)
		for _ = 1, 30 do MoveCheck.step(c, xs[1], 1.7, c.t + DT) end
		local px: number? = xs[1]
		for i = 2, #xs do
			MoveCheck.step(c, xs[i], 1.7, c.t + DT)
			if c.suspect then
				px = nil
			else
				if Orbs.touches(spot, xs[i], 1.7, px, if px then 1.7 else nil) then return true end
				px = xs[i]
			end
		end
		return false
	end
	assert(taken(xs[1] + 44), "an orb 44 studs away is taken by the tolerated part of the teleport")
	assert(not taken(xs[1] + 47.5) and not taken(xs[1] + 50), "one 47.5 or 50 studs away is not: the step that reaches it is caught")
end

do -- H19, rule 44, tightened by QA round 1: when a hold lands the x budget DROPS to what lateness can honestly cost
	-- (speed x HOLD_GRACE + HOLD_SLACK) and the refill becomes the hold's allowance (a freeze: half the speed it caught,
	-- + HOLD_SLACK). Round 1 found the old rule (full 24-stud burst, freeze refill 60) let a client ignore a whole freeze.
	local Y, G = 2, Config.HOLD_GRACE
	-- 1 s at run speed, then a hold of `kind` lands (t = 1, measured speed `speed`, default the run speed); `vel(d)` is
	-- this client's speed d seconds after it landed. `kind` nil: no hold (the control). Returns when flagged, or nil.
	local function ride(kind: string?, len: number, vel: (number) -> number, speed: number?, pryAt: number?): number?
		local c = MoveCheck.new(0, Y, 0)
		local x, t, held = 0, 0, false
		while t < 3 do
			t += DT
			if kind and not held and t >= 1 then
				MoveCheck.hold(c, kind, t, t + len, speed or Config.RUN_SPEED)
				held = true
			end
			if pryAt and t >= 1 + pryAt then MoveCheck.release(c, 1 + pryAt) end
			x += (if t < 1 then Config.RUN_SPEED else vel(t - 1)) * DT
			if not MoveCheck.step(c, x, Y, t) then return t - 1 end
		end
		return nil
	end
	local R = Config.RUN_SPEED
	local function run() return R end
	-- An honest client hears of the hold G late (running on at full speed till then), then obeys it for `len` of its own.
	local function honest(len: number, during: (number) -> number)
		return function(d) return if d < G then R elseif d < G + len then during(d - G) else R end
	end
	local cap = R * G + Config.HOLD_SLACK

	-- The trap: pinned.
	assert(ride("trap", Config.TRAP_TIME, honest(Config.TRAP_TIME, function() return 0 end)) == nil,
		"an honest client that hears of the trap a grace late: never flagged")
	local caught = ride("trap", Config.TRAP_TIME, run)
	assert(caught and near(caught, cap / R, 2 * DT),
		("ignoring a trap is caught %.2f s in (expected ~%.2f)"):format(caught or -1, cap / R))
	assert(ride(nil, 0, run) == nil, "control (Q5): with no hold the same run is legal")
	assert(ride("trap", Config.TRAP_TIME, function(d) return if d < 0.1 or d >= 0.4 then R else 0 end, nil, 0.4) == nil,
		"pinned at 0.1, pried open at 0.4: running again is legal")

	-- The freeze: sliding from the speed it caught, bleeding to 0 over FREEZE_TIME.
	local function slide(v: number) return function(d) return v * (1 - d / Config.FREEZE_TIME) end end
	assert(ride("freeze", Config.FREEZE_TIME, honest(Config.FREEZE_TIME, slide(R))) == nil,
		"an honest freeze from a run, heard a grace late: never flagged")
	local fast = Config.DASH_SPEED + Config.JUMP_H_BOOST
	assert(ride("freeze", Config.FREEZE_TIME, slide(fast), fast) == nil,
		"an honest freeze slide from a jump out of a dash (140), heard at once: never flagged")
	local iced = ride("freeze", Config.FREEZE_TIME, run)
	local iceExpect = cap / (R - (R / 2 + Config.HOLD_SLACK))
	assert(iced and iced < Config.FREEZE_TIME and near(iced, iceExpect, 2 * DT),
		("ignoring a freeze from a run is caught %.2f s in, before it ends (expected ~%.2f)"):format(iced or -1, iceExpect))

	-- Standing still does not bank budget for later in the hold: the dropped cap holds for the whole of it. Without it,
	-- a client could stand through part of a freeze, let the budget refill to the full burst, then dash.
	local banked = ride("freeze", Config.FREEZE_TIME, function(d)
		return if d >= 0.4 and d < 0.6 then Config.DASH_SPEED else 0 end)
	assert(banked and banked < 0.6, "stand 0.4 s inside a freeze, then dash 0.2 s: caught")

	-- The stumble: half run speed, the way it was going. The allowance itself, over a hold far longer than a stumble.
	assert(ride("stumble", 5, honest(5, function() return R * Config.STUMBLE_SPEED end)) == nil,
		"an honest stumble at half speed (held 5 s): never flagged")
	-- The limit, pinned as a measurement (trust.md §10): ignoring a 0.7 s stumble at full run speed spends the dropped
	-- cap at 22.5 studs/s, 0.69 s: caught on the stumble's last frame, about the same moment it would have ended anyway.
	local tripped = ride("stumble", Config.STUMBLE_TIME, run)
	print(("    ignoring a stumble from a run: caught %s s in (the stumble is %.1f s)"):format(
		if tripped then ("%.3f"):format(tripped) else "never", Config.STUMBLE_TIME))
	assert(tripped == nil or tripped >= Config.STUMBLE_TIME - 2 * DT,
		"a stumble ignored is caught no sooner than its end: the measured edge")
end

do -- the speed a hold is judged from comes from the SERVER's own samples, over the last 0.1 s
	local h = {}
	for i = 0, 30 do table.insert(h, { t = i * DT, x = Config.RUN_SPEED * i * DT }) end
	assert(near(MoveCheck.recentSpeed(h) :: number, Config.RUN_SPEED, 1e-6), "running: the run speed")
	for i = 31, 40 do table.insert(h, { t = i * DT, x = h[31].x }) end
	assert((MoveCheck.recentSpeed(h) :: number) < 1, "stopped for the last 0.1 s: about 0, not the run before")
	assert(MoveCheck.recentSpeed({ { t = 0, x = 0 } }) == nil and MoveCheck.recentSpeed({}) == nil, "too few samples: nil")
	local c = MoveCheck.new(0, 2, 0)
	MoveCheck.hold(c, "trap", 0, 1, nil)
	assert(near(c.holdCap :: number, MoveCheck.RATE_X * Config.HOLD_GRACE + Config.HOLD_SLACK),
		"an unknown speed is read as the dash speed (the most lenient cap)")
end

print("move_check: ok")
