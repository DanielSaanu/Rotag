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

print("remote_pose ok")
