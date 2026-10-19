--!include movement_world.luau
-- Snapshot (H14, docs/systems/netcode.md §8): the wire format, the sequence ring, the server's rate limit and the
-- receiving buffer that draws another runner between the snapshots around "now minus the delay". The sender in the
-- buffer tests is a real Movement runner in the box world (Q3), sampled at Config.SNAPSHOT_RATE.
local Snapshot = __require("Snapshot")
local Movement = __require("Movement")

local RATE = Config.SNAPSHOT_RATE
local SEND = 1 / RATE
local DELAY = Config.SNAPSHOT_DELAY

local function snap(seq, s, extra)
	local t = {
		seq = seq, x = s.x, y = s.y, vx = s.vx, vy = s.vy, sprite = Movement.spriteFor(s), facing = s.facing,
		dashing = s.dashTime > 0, dash = false,
	}
	for k, v in extra or {} do t[k] = v end
	return t
end

do -- the wire: every field survives pack/unpack to within the quantisation; bad payloads are nil
	local s = { seq = 65535, x = -123.456, y = 7.89, vx = -119.9, vy = 52.5, sprite = "runner_run_3", facing = -1,
		dashing = true, jump = "wall", dash = true, landed = 61.4 }
	local b = Snapshot.pack(s)
	assert(buffer.len(b) == Snapshot.SIZE, "13 bytes on the wire")
	local u = Snapshot.unpack(b)
	assert(u, "unpacks")
	assert(u.seq == 65535 and math.abs(u.x - s.x) <= 1 / 32 and math.abs(u.y - s.y) <= 1 / 32, "seq and position")
	assert(math.abs(u.vx - s.vx) <= 1 / 16 and math.abs(u.vy - s.vy) <= 1 / 16, "velocity")
	assert(u.sprite == "runner_run_3" and u.facing == -1 and u.dashing and u.jump == "wall" and u.dash, "sprite, flags")
	assert(u.landed == 61, "the landing impact, whole studs/s")
	local plain = Snapshot.unpack(Snapshot.pack({ seq = 1, x = 0, y = 0, vx = 0, vy = 0, sprite = "runner_idle",
		facing = 1, dashing = false, dash = false }))
	assert(plain and plain.jump == nil and plain.landed == nil and not plain.dash and not plain.dashing, "no events")
	assert(Snapshot.unpack("not a buffer") == nil, "a string is refused")
	assert(Snapshot.unpack(buffer.create(12)) == nil and Snapshot.unpack(buffer.create(14)) == nil, "wrong sizes refused")
	local bad = Snapshot.pack(s)
	buffer.writeu8(bad, 10, 200)
	assert(Snapshot.unpack(bad) == nil, "a sprite index off the list is refused")
	-- Every sprite Movement can pick is on the list (the wire carries the index): a new pose must be added here too.
	for _, name in { "runner_idle", "runner_jump_rise", "runner_jump_apex", "runner_fall", "runner_dash" } do
		assert(table.find(Snapshot.SPRITES, name), name .. " is on the wire list")
	end
	for i = 0, Config.RUN_FRAMES - 1 do assert(table.find(Snapshot.SPRITES, "runner_run_" .. i), "run frame " .. i) end
	-- H21: the hold poses ride the wire too, after every older name (their indices never move).
	for _, name in { "runner_trapped_0", "runner_trapped_1", "runner_stumble_0", "runner_stumble_1", "runner_stumble_2",
		"runner_stumble_3", "runner_stumble_4" } do
		local at = table.find(Snapshot.SPRITES, name)
		assert(at and at > 5 + Config.RUN_FRAMES, name .. " is on the wire list, after the motion poses")
		local back = Snapshot.unpack(Snapshot.pack({ seq = 1, x = 0, y = 0, vx = 0, vy = 0, sprite = name, facing = 1,
			dashing = false, dash = false }))
		assert(back and back.sprite == name, name .. " survives the wire")
	end
end

do -- the sequence ring: newer within half a ring, including across the wrap; never equal or older
	assert(Snapshot.newer(2, 1) and Snapshot.newer(0, 65535) and Snapshot.newer(5, 65530), "ahead, and across the wrap")
	assert(not Snapshot.newer(1, 1) and not Snapshot.newer(1, 2) and not Snapshot.newer(65535, 0), "equal or behind")
end

do -- the rate limit: an honest 30 Hz sender is never refused; a flood at 10 x the rate mostly is
	local l = Snapshot.newLimiter(0)
	local refused = 0
	for i = 1, 300 do if not Snapshot.allow(l, i * SEND) then refused += 1 end end
	assert(refused == 0, "honest sender never refused, got " .. refused)
	l = Snapshot.newLimiter(0)
	local passed = 0
	for i = 1, 300 do if Snapshot.allow(l, i * SEND / 10) then passed += 1 end end
	assert(passed <= 300 * 0.15 + 8 + 1, "a flood is cut to the limit, passed " .. passed)
	-- A stall then the queued burst: a 0.3 s gap and 8 at once go through.
	l = Snapshot.newLimiter(0)
	for i = 1, 30 do Snapshot.allow(l, i * SEND) end
	local burst = 0
	for _ = 1, 8 do if Snapshot.allow(l, 1 + 0.3) then burst += 1 end end
	assert(burst == 8, "a short stall's queue passes, got " .. burst)
end

-- A sender running in the box world, sampled every SEND; snapshots reach the receiver `lag` later with `jitter`.
local function run(n, choose, lag, jitter, hook, startX)
	local s = standing(FLOOR, startX or -50)
	local st = Snapshot.newStream()
	local seq, nextSend, sent, lagged = 0, 0, {}, {}
	local frames = {}
	local pendingJump, pendingDash, pendingLand = nil, false, nil
	for i = 1, n do
		local now = i * DT
		local ev = tick(FLOOR, s, choose(i, s))
		if ev.jump then pendingJump = ev.jump end
		if ev.dash then pendingDash = true end
		if ev.landed then pendingLand = math.max(pendingLand or 0, ev.landed) end
		if now >= nextSend then
			nextSend += SEND
			seq += 1
			local sn = snap(seq, s, { jump = pendingJump, dash = pendingDash, landed = pendingLand })
			pendingJump, pendingDash, pendingLand = nil, false, nil
			local j = if jitter > 0 then (((i * 7919) % 1000) / 1000 - 0.5) * 2 * jitter else 0
			table.insert(sent, { at = now + lag + j, serverT = now + lag / 2, s = Snapshot.unpack(Snapshot.pack(sn)) })
		end
		-- deliver what has arrived (in send order: the server stamps in arrival order, so later seqs stamp later)
		for _, p in sent do
			if not p.done and p.at <= now then
				p.done = true
				Snapshot.push(st, p.serverT, now, p.s)
			end
		end
		local v = Snapshot.at(st, now)
		table.insert(frames, { t = now, truth = { x = s.x, y = s.y, sprite = Movement.spriteFor(s) }, view = v })
		if hook then hook(i, s, st, v) end
	end
	return frames, st
end

do -- a run at 30 Hz with a 40 ms link: the other screen moves on EVERY frame, lags by about the delay, never leads
	local frames = run(240, function() return input({ moveX = 1 }) end, 0.04, 0)
	local moved, lagSum, lagN = 0, 0, 0
	for i = 40, #frames do
		local f, g = frames[i], frames[i - 1]
		assert(f.view, "a view once snapshots flow")
		if f.view.x ~= g.view.x then moved += 1 end
		-- how far behind the truth the drawing is, in seconds, at run speed
		local lag = (f.truth.x - f.view.x) / Config.RUN_SPEED
		assert(lag >= -DT, ("frame %d: drawn %.3f s AHEAD of the sender"):format(i, -lag))
		lagSum, lagN = lagSum + lag, lagN + 1
	end
	assert(moved >= (#frames - 40) * 0.95, "moves on nearly every frame, moved on " .. moved)
	local mean = lagSum / lagN
	-- the delay, plus half the link (the server stamps at the midpoint), plus up to one send interval of quantisation
	assert(mean >= DELAY and mean <= DELAY + 0.04 + SEND, ("drawn %.3f s behind; expected about %.3f"):format(mean, DELAY + 0.02))
end

do -- jitter of +-15 ms on arrival: still moves every frame (the delay covers it), still never ahead of the sender
	local frames = run(240, function() return input({ moveX = 1 }) end, 0.04, 0.015)
	local moved, starved = 0, 0
	for i = 40, #frames do
		if frames[i].view.x ~= frames[i - 1].view.x then moved += 1 end
		assert(frames[i].truth.x - frames[i].view.x >= -0.5, "never ahead of the truth")
	end
	assert(moved >= (#frames - 40) * 0.9, "moves on nearly every frame through jitter, moved on " .. moved)
end

-- A sender at 30 Hz losing the packets whose seq is in `lost`; how many frames the drawing held still after frame 40.
local function holdsWhenLost(lost)
	local st = Snapshot.newStream()
	local s = standing(FLOOR, 0)
	local seq, lastX, held = 0, nil, 0
	for i = 1, 120 do
		local now = i * DT
		tick(FLOOR, s, input({ moveX = 1 }))
		if i % 2 == 0 then
			seq += 1
			if not lost[seq] then Snapshot.push(st, now, now, snap(seq, s)) end
		end
		local v = Snapshot.at(st, now)
		if v then
			assert(v.x <= s.x + 1e-6, "never past the sender")
			if lastX and v.x == lastX and i > 40 then held += 1 end
			lastX = v.x
		end
	end
	return held
end

do -- lost packets: one is bridged by the delay (no hold at all); three in a row (a 0.13 s gap, past the delay) hold
	-- at the newest point for the frames the delay does not cover, never extrapolated past it
	assert(holdsWhenLost({ [30] = true }) == 0, "one lost packet is covered by SNAPSHOT_DELAY")
	local held = holdsWhenLost({ [30] = true, [31] = true, [32] = true })
	assert(held >= 1 and held <= 6, "three lost in a row hold a few frames, held " .. held)
end

do -- events ride the snapshot they were sent in and fire once, when the draw clock passes it; the sprite follows
	local jumps, dashes, lands = 0, 0, 0
	local dashSeen, jumpSeen = false, false
	run(300, function(i) return input({ moveX = 1, jump = i == 30, held = i <= 40, dash = i == 150 }) end, 0.04, 0,
		function(_, _, _, v)
			if not v then return end
			if v.events.jump then jumps += 1 end
			if v.events.dash then dashes += 1 end
			if v.events.landed then lands += 1 end
			if v.sprite == "runner_dash" then dashSeen = true end
			if v.sprite == "runner_jump_rise" then jumpSeen = true end
		end, -180)
	assert(jumps == 1, "one jump event delivered, got " .. jumps)
	assert(dashes == 1, "one dash event delivered, got " .. dashes)
	assert(lands == 1, "one landing delivered, got " .. lands)
	assert(dashSeen and jumpSeen, "the dash and the rise pose were drawn")
end

do -- a teleport (a respawn): the drawing snaps, it does not slide across the map
	local st = Snapshot.newStream()
	local s = standing(FLOOR, 0)
	for i = 1, 10 do Snapshot.push(st, i * SEND, i * SEND, snap(i, s)) end
	local far = standing(FLOOR, 150)
	Snapshot.push(st, 11 * SEND, 11 * SEND, snap(11, far))
	local v = Snapshot.at(st, 11 * SEND + DELAY / 2)
	assert(v and v.x == far.x, "drawn at the new spot at once, got " .. tostring(v and v.x))
end

do -- out-of-order and duplicate arrivals are dropped; the drawing never steps backwards
	local st = Snapshot.newStream()
	local s = standing(FLOOR, 0)
	local snaps = {}
	for i = 1, 6 do tick(FLOOR, s, input({ moveX = 1 })) table.insert(snaps, snap(i, s)) end
	assert(Snapshot.push(st, 1, 1, snaps[1]) and Snapshot.push(st, 2, 2, snaps[3]), "in order")
	assert(not Snapshot.push(st, 3, 3, snaps[2]), "an older seq arriving late is dropped")
	assert(not Snapshot.push(st, 3, 3, snaps[3]), "a duplicate is dropped")
	assert(Snapshot.push(st, 3, 3, snaps[4]), "the next newer one lands")
	assert(#st.points == 3, "three points kept, got " .. #st.points)
end

print("snapshot ok")
