--!include movement_world.luau
-- RemotePose (H11, docs/systems/players.md §3): another runner's sprite from its replicated position alone. Driven by
-- a real Movement runner in the box world (Q3): its positions are what Roblox would replicate to the other screens.
local RemotePose = __require("RemotePose")

local function family(name)
	if string.sub(name, 1, 11) == "runner_run_" then return "run" end
	return name
end

-- Feed one Movement frame's position to a pose, probing the same world the way client/Others.lua probes Studio.
local function watch(world, p, s, dt)
	local c = probe(world, s)
	return RemotePose.step(p, s.x, s.y, c.ground, c.wallLeft ~= nil or c.wallRight ~= nil, dt or DT)
end

do -- standing still reads as the rest pose; running reads as the run cycle, in order, facing the way it runs
	local s = standing(FLOOR, 0)
	local p = RemotePose.new(s.x, s.y)
	local name
	for _ = 1, 20 do tick(FLOOR, s) name = watch(FLOOR, p, s) end
	assert(name == "runner_idle", "idle at rest, got " .. tostring(name))
	local order = {}
	for _ = 1, 80 do
		tick(FLOOR, s, input({ moveX = -1 }))
		name = watch(FLOOR, p, s)
		if name ~= order[#order] then table.insert(order, name) end
	end
	assert(p.facing == -1, "faces left running left")
	local runs = 0
	for i, n in order do
		if family(n) == "run" then
			runs += 1
			local want = "runner_run_" .. tostring((runs - 1) % Config.RUN_FRAMES)
			assert(n == want, "run frame " .. i .. " is " .. want .. ", got " .. n)
		end
	end
	assert(runs >= Config.RUN_FRAMES, "a whole run cycle seen, got " .. runs)
end

do -- a jump: a "ground" jump event, rise -> apex -> fall, then a landing with its impact speed
	local s = standing(FLOOR, 0)
	local p = RemotePose.new(s.x, s.y)
	for _ = 1, 10 do tick(FLOOR, s) watch(FLOOR, p, s) end
	local seen, jumped, landed = {}, nil, nil
	for i = 1, 120 do
		tick(FLOOR, s, input({ jump = i == 1, held = i <= 12 }))
		local name, ev = watch(FLOOR, p, s)
		if name ~= seen[#seen] then table.insert(seen, name) end
		jumped = jumped or ev.jump
		if ev.landed then landed = ev.landed break end
	end
	assert(jumped == "ground", "a ground jump event, got " .. tostring(jumped))
	local want = { "runner_jump_rise", "runner_jump_apex", "runner_fall" }
	for i, n in want do assert(seen[i] == n, "pose " .. i .. " is " .. n .. ", got " .. tostring(seen[i])) end
	assert(landed and landed > 5, "a landing with impact (Look squashes above 5), got " .. tostring(landed))
end

do -- a dash shows the dash pose and a dash event; the dash's end speed does not (it is a run speed)
	local s = standing(FLOOR, -100)
	local p = RemotePose.new(s.x, s.y)
	for _ = 1, 5 do tick(FLOOR, s, input({ moveX = 1 })) watch(FLOOR, p, s) end
	local dashFrames, events = 0, 0
	for i = 1, 40 do
		tick(FLOOR, s, input({ moveX = 1, dash = i == 1 }))
		local name, ev = watch(FLOOR, p, s)
		if name == "runner_dash" then dashFrames += 1 end
		if ev.dash then events += 1 end
	end
	local real = math.floor(Config.DASH_TIME / DT + 0.5)
	assert(events == 1, "one dash event, got " .. events)
	assert(math.abs(dashFrames - real) <= 3, "the dash pose lasts about the dash (" .. real .. " frames), got " .. dashFrames)
end

do -- A4: a wall slide's capped fall speed sits inside the apex band; the wall flag makes it read as a fall
	local p, q = RemotePose.new(0, 20), RemotePose.new(0, 20)
	local y = 20
	local a, b
	for _ = 1, 30 do
		y -= Config.WALL_SLIDE_MAX * DT
		a = RemotePose.step(p, 0, y, nil, true, DT)
		b = RemotePose.step(q, 0, y, nil, false, DT)
	end
	assert(a == "runner_fall", "sliding down a wall reads as the fall pose, got " .. a)
	assert(b == "runner_jump_apex", "the same speed with no wall is the apex band (why the flag exists), got " .. b)
end

do -- a teleport (a respawn, a fall-out reset) is not a move: no dash pose, no speed
	local p = RemotePose.new(0, HH)
	RemotePose.step(p, 0, HH, 0, false, DT)
	local name, ev = RemotePose.step(p, 120, HH, 0, false, DT)
	assert(name ~= "runner_dash" and not ev.dash and p.vx == 0, "a 120-stud jump in one frame is a teleport")
	-- Seen in Studio: a short server move (6 studs in one frame, 360 studs/s) is no runner's speed either.
	name, ev = RemotePose.step(p, 126, HH, 0, false, DT)
	assert(name ~= "runner_dash" and not ev.dash and p.vx == 0, "6 studs in one frame from rest is a teleport")
end

do -- replication that lands in steps (20 Hz, held for 2 frames between; seen in Studio, H11): a run reads as a run
	-- (never a dash, never idle) and a dash reads as one unbroken dash, not dash and run flickering
	local s = standing(FLOOR, -100)
	local p = RemotePose.new(s.x, s.y)
	local shownX, shownY = s.x, s.y
	local dashSeen = {}
	for i = 1, 120 do
		tick(FLOOR, s, input({ moveX = 1, dash = i == 61 }))
		if i % 3 == 0 then shownX, shownY = s.x, s.y end
		local c = probe(FLOOR, { x = shownX, y = shownY })
		local name = RemotePose.step(p, shownX, shownY, c.ground, false, DT)
		if i > 10 and i <= 60 then assert(family(name) == "run", "frame " .. i .. " reads as a run, got " .. name) end
		if name == "runner_dash" then table.insert(dashSeen, i) end
	end
	assert(#dashSeen >= 6, "the dash shows at 20 Hz, got " .. #dashSeen .. " frames")
	assert(dashSeen[#dashSeen] - dashSeen[1] + 1 == #dashSeen, "one unbroken dash pose, no flicker")
end

do -- standing still after a run: the rest pose within HOLD + IDLE_GRACE (+ a frame or two of smoothing)
	local s = standing(FLOOR, 0)
	local p = RemotePose.new(s.x, s.y)
	for _ = 1, 30 do tick(FLOOR, s, input({ moveX = 1 })) watch(FLOOR, p, s) end
	local frames = 0
	repeat
		tick(FLOOR, s)
		frames += 1
	until watch(FLOOR, p, s) == "runner_idle" or frames > 60
	assert(frames * DT <= 0.1 + Config.IDLE_GRACE + 0.1, "idle after stopping, took " .. frames .. " frames")
end

do -- against the truth: a scripted run, jump, dash and wall slide; how often the other screen shows the same pose
	-- family as the owner. A MEASUREMENT (S11): the remote pose trails by ~2 frames of smoothing, so the edges of each
	-- pose differ; this pins the value so a tuning change shows as a diff.
	local WORLD = { { -200, -10, 200, 0 }, { 40, 0, 44, 80 } }
	local s = standing(WORLD, -60)
	local p = RemotePose.new(s.x, s.y)
	local script = {}
	local function add(n, inp) for i = 1, n do table.insert(script, inp(i)) end end
	add(20, function() return input() end)
	add(40, function() return input({ moveX = 1 }) end)
	add(50, function(i) return input({ moveX = 1, jump = i == 1, held = i <= 12 }) end)
	add(10, function() return input({ moveX = 1 }) end)
	add(30, function(i) return input({ moveX = 1, dash = i == 1 }) end)
	add(40, function() return input({ moveX = 1 }) end)
	add(60, function(i) return input({ moveX = 1, jump = i == 1, held = i <= 12 }) end)
	add(30, function() return input() end)
	local same = 0
	for _, inp in script do
		tick(WORLD, s, inp)
		local name = watch(WORLD, p, s)
		if family(name) == family(Movement.spriteFor(s)) then same += 1 end
	end
	local share = same / #script
	print(("remote pose: same family as the owner on %d of %d frames (%.0f%%)"):format(same, #script, share * 100))
	assert(share >= 0.92, "measured 258 of 280 (92%) on 2026-10-11; at least 92% of frames, got " .. share)
end

do -- the draw trail (H13): a body that lands in steps is drawn moving on every frame, a stop ends on the spot,
	-- a start from rest does not creep, a teleport snaps
	local F = 1 / 60
	assert(Config.OTHERS_DRAW_DELAY > 0 and Config.OTHERS_DRAW_DELAY <= 0.25, "draw delay is a small positive knob")
	-- 60 studs/s arriving every third frame as a 3-stud jump (the stepped replication seen in Studio)
	local tr = RemotePose.newTrail(0, 0, 0)
	local x, prevT, lastDrawn = 0, 0, 0
	local still, minStep, maxStep = 0, math.huge, 0
	for i = 1, 120 do
		local t = i * F
		if i % 3 == 0 then x += 3 end
		RemotePose.push(tr, t, x, 0, prevT)
		prevT = t
		local dx = RemotePose.drawAt(tr, t)
		if t > Config.OTHERS_DRAW_DELAY + 0.1 and i <= 117 then
			local step = dx - lastDrawn
			if step == 0 then still += 1 end
			minStep, maxStep = math.min(minStep, step), math.max(maxStep, step)
		end
		lastDrawn = dx
	end
	assert(still == 0, "drawn moves on every frame through the steps, held " .. still)
	assert(minStep > 0.5 and maxStep < 1.5, ("drawn steps near 1 stud a frame, got %.2f-%.2f"):format(minStep, maxStep))
	-- a stop: the drawing ends exactly where the body stopped
	local ex = RemotePose.drawAt(tr, 10)
	assert(ex == x, "a stop ends on the last spot, got " .. ex)
	-- a start after a long rest: no creep across the rest, then full speed
	local rest = RemotePose.newTrail(0, 0, 0)
	local t0 = 2
	RemotePose.push(rest, t0, 1, 0, t0 - F)
	assert(RemotePose.drawAt(rest, t0 - F + Config.OTHERS_DRAW_DELAY - 0.001) == 0, "still at rest until the start")
	assert(RemotePose.drawAt(rest, t0 + Config.OTHERS_DRAW_DELAY) == 1, "the first step is drawn in one frame, not 2 s")
	-- a teleport (respawn, round start) snaps at once
	local tp = RemotePose.newTrail(0, 0, 0)
	RemotePose.push(tp, 0.5, 50, 0, 0.5 - F)
	assert(RemotePose.drawAt(tp, 0.5) == 50, "a teleport is drawn at once")
end

do -- the adaptive delay (H13 run 4): a sender that steps slowly (8 arrivals a second, a throttled window) is still
	-- drawn moving on every frame once the delay has grown; a good link brings it back to the floor; a rest never
	-- raises it; it never passes the cap
	local F = 1 / 60
	local base, cap = Config.OTHERS_DRAW_DELAY, Config.OTHERS_DRAW_DELAY_MAX
	assert(cap > base and cap <= 0.5, "the cap sits above the floor and stays small")
	local tr = RemotePose.newTrail(0, 0, 0)
	local x, prevT, lastDrawn, still, maxStep = 0, 0, 0, 0, 0
	for i = 1, 6 * 60 do -- 6 s at 45 studs/s, arriving every 7.5 frames (0.125 s)
		local t = i * F
		local due = math.floor(t * 8) / 8
		x = due * 45
		RemotePose.push(tr, t, x, 0, prevT)
		prevT = t
		local dx = RemotePose.drawAt(tr, t)
		if t > 3 then
			if dx == lastDrawn then still += 1 end
			maxStep = math.max(maxStep, dx - lastDrawn)
		end
		lastDrawn = dx
	end
	assert(tr.delay > 0.125 and tr.delay <= cap, ("the delay grew past the 0.125 s gap: %.3f"):format(tr.delay))
	assert(still == 0, "a slow sender is drawn moving on every frame once adapted, held " .. still)
	assert(maxStep < 45 * F * 1.6, ("no jumps once adapted, biggest %.2f studs"):format(maxStep))
	-- the link improves: arrivals on every frame for 10 s
	for i = 1, 10 * 60 do
		local t = prevT + F
		x += 45 * F
		RemotePose.push(tr, t, x, 0, prevT)
		prevT = t
	end
	assert(math.abs(tr.delay - base) < 0.01, ("back to the floor on a good link: %.3f"):format(tr.delay))
	-- a rest of 2 s and then a start: not counted as a gap
	local t = prevT + 2
	RemotePose.push(tr, t, x + 1, 0, t - F)
	for i = 1, 60 do RemotePose.push(tr, t + i * F, x + 1, 0, t + (i - 1) * F) end
	assert(math.abs(tr.delay - base) < 0.01, "a rest does not raise the delay")
	-- a sender stepping every 0.28 s: the delay stops at the cap
	local slow = RemotePose.newTrail(0, 0, 0)
	prevT = 0
	for i = 1, 10 * 60 do
		local tt = i * F
		RemotePose.push(slow, tt, math.floor(tt / 0.28) * 2.8, 0, prevT) -- gaps under the cap, x 1.25 over it
		prevT = tt
	end
	assert(slow.delay <= cap + 1e-9, ("never past the cap: %.3f"):format(slow.delay))
end

print("remote_pose ok")
