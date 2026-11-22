-- The tutorial course (H41, docs/systems/tutorial.md): every room driven through the real Movement (and Grapple) in
-- the course's own BoxWorld, with the inputs a beginner gives: each lesson is doable with its move and, where the
-- room says so, not without it. Then the lesson rules, the target's flee rule against a plain chaser, the server's
-- tag check, and where the course sits in the world (clear of the lobby and the room, inside the snapshot's range).
local Config = __require("Config")
local Movement = __require("Movement")
local BoxWorld = __require("BoxWorld")
local Grapple = __require("Grapple")
local Lobby = __require("Lobby")
local Tut = __require("Tutorial")

local HH = Config.RUNNER_HEIGHT / 2
local DT = 1 / 60
local X = Tut.X
local REACH = Movement.wallReach()
local world = BoxWorld.fromBlocks(Tut.BLOCKS)
for _, b in world do b[1] += X; b[3] += X end

local function room(id)
	for i, r in Tut.ROOMS do if r.id == id then return r, i end end
	error("no room " .. id)
end
local function inGoal(r, s) local g = r.goal return s.grounded and s.x - X >= g[1] and s.x - X <= g[3] and s.y >= g[2] and s.y <= g[4] end

-- Run a runner from local (x0, floor y0) with `plan(i, s, c, inp, st)` choosing the buttons, until `stop` says.
local function run(x0, y0, plan, stop, maxf)
	local s = Movement.new(X + x0, y0 + HH)
	local c, st = {}, {}
	for i = 1, maxf or 900 do
		BoxWorld.probe(world, s.x, s.y, c)
		local inp = { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
		plan(i, s, c, inp, st)
		local ev = Movement.step(s, inp, c, DT)
		BoxWorld.move(world, s, DT)
		st.ev = ev
		local r = stop(s, ev, i, st)
		if r ~= nil then return r, s end
	end
	return nil, s
end

do -- RUN: holding right gets you to the goal in a couple of seconds
	local r = room("run")
	local ok = run(r.start, 0, function(_, _, _, inp) inp.moveX = 1 end, function(s) if inGoal(r, s) then return true end end, 180)
	assert(ok, "run: holding right reaches the goal within 3 s")
end

do -- JUMP: the hurdle needs a jump; one jump at any distance from 1 to 6 studs before it clears it
	local r = room("jump")
	local blocked = run(r.start, 0, function(_, _, _, inp) inp.moveX = 1 end, function(s, _, i) if inGoal(r, s) then return false end if i > 240 then return true end end, 300)
	assert(blocked, "jump: running alone never clears the hurdle")
	for gap = 1, 6 do
		local ok = run(r.start, 0, function(_, s, _, inp, st)
			inp.moveX, inp.jumpHeld = 1, true
			if not st.j and s.x - X >= 56 - gap - 1 then inp.jumpPressed, st.j = true, true end
		end, function(s) if inGoal(r, s) then return true end end, 300)
		assert(ok, ("jump: a jump %d studs before the hurdle clears it"):format(gap))
	end
end

do -- DOUBLE JUMP: a single jump never lands on the ledge (14.25 < 20); a jump and a second one at most anywhere in
	-- the rise do (the tester: "each time i tried i slid off the platform": the ledge is 8 tiles wide and solid)
	local r = room("double")
	for jx = 80, 99, 1 do
		local on = run(r.start, 0, function(_, s, _, inp, st)
			inp.moveX, inp.jumpHeld = 1, true
			if not st.j and s.grounded and s.x - X >= jx then inp.jumpPressed, st.j = true, true end
		end, function(s, _, i) if inGoal(r, s) then return true end if i > 240 then return false end end, 300)
		assert(not on, ("double: one jump from x %d never lands on the ledge"):format(jx))
	end
	local wins, tries = 0, 0
	for jx = Tut.TAKEOFF[1], Tut.TAKEOFF[2] do -- from the painted line
		for second = 6, 18, 3 do -- frames after the first jump: 0.1 to 0.3 s ("jump, then jump again quickly")
			tries += 1
			local on = run(r.start, 0, function(i, s, _, inp, st)
				inp.moveX, inp.jumpHeld = 1, true
				if not st.j and s.grounded and s.x - X >= jx then inp.jumpPressed, st.j = true, i end
				if st.j and i == st.j + second then inp.jumpPressed = true end
			end, function(s, _, i) if inGoal(r, s) then return true end if i > 300 then return false end end, 360)
			if on then wins += 1 else print(("    double: from x %d, second jump %d frames later, missed"):format(jx, second)) end
		end
	end
	print(("    double: %d of %d jump + double jump timings from the take-off line land on the ledge"):format(wins, tries))
	assert(wins == tries, "double: from the line, a jump and a quick second jump always land on the ledge")
	-- H42: closer than the line, up to the face, the second press rising beside it is the double jump, not a kick off it
	local near, nearTries, kicks = 0, 0, 0
	for jx = Tut.TAKEOFF[2] + 1, 99 do
		for second = 8, 18, 2 do
			nearTries += 1
			local on = run(r.start, 0, function(i, s, _, inp, st)
				inp.moveX, inp.jumpHeld = 1, true
				if not st.j and s.grounded and s.x - X >= jx then inp.jumpPressed, st.j = true, i end
				if st.j and i == st.j + second then inp.jumpPressed = true end
			end, function(s, ev, i) if ev.jump == "wall" then kicks += 1 return false end if inGoal(r, s) then return true end
				if i > 300 then return false end end, 360)
			if on then near += 1 else print(("    double: from x %d (past the line), second jump %d frames later, missed"):format(jx, second)) end
		end
	end
	print(("    double: %d of %d timings from past the line, up to the face, land on the ledge (%d kicks)"):format(near, nearTries, kicks))
	assert(kicks == 0 and near == nearTries, "double: from anywhere up to the face, a jump and a second press land on it")
end

do -- WALL JUMP: the tower is over a double jump; kicking up the shaft gets on it; jumps alone never do
	local r = room("wall")
	for jx = 136, 158, 2 do
		for second = 0, 30, 3 do
			local on = run(r.start, 0, function(i, s, _, inp, st)
				inp.moveX, inp.jumpHeld = 1, true
				if not st.j and s.grounded and s.x - X >= jx then inp.jumpPressed, st.j = true, i end
				if st.j and second > 0 and i == st.j + second then inp.jumpPressed = true end
			end, function(s, ev, i) if ev.jump == "wall" then return false end if inGoal(r, s) then return true end if i > 240 then return false end end, 300)
			assert(not on, ("wall: a jump from %d and a double jump %d frames later never reach the tower"):format(jx, second))
		end
	end
	local function climb(kickBelow)
		return run(r.start, 0, function(_, s, c, inp, st)
			inp.jumpHeld = true
			if not st.up then
				inp.moveX = 1
				if s.x - X >= 150 and s.grounded then inp.jumpPressed, st.up, st.dir = true, true, 1 end
				return
			end
			if s.y > 40 + HH + 1 then inp.moveX = 1 return end
			local wl = c.wallLeft ~= nil and c.wallLeft <= REACH
			local wr = c.wallRight ~= nil and c.wallRight <= REACH
			if not s.grounded and (wl or wr) and s.vy < kickBelow then inp.jumpPressed, st.dir = true, if wl then 1 else -1 end
			inp.moveX = st.dir
			if s.grounded then inp.jumpPressed = true end
		end, function(s) if inGoal(r, s) then return true end end, 600)
	end
	for _, kick in { 53, 20, 0, -8 } do -- pressing jump at a wall while still rising, at the top, or sliding down it (the slide caps the fall at 10)
		assert(climb(kick), ("wall: kicking off each wall (jump at vy < %d) climbs onto the tower"):format(kick))
	end
end

-- From the dash room's start: run right and do `act` (with the frame the runner left the floor); "across" on the
-- far floor, "fell" in the pit.
local function dashTry(act)
	local r = room("dash")
	return run(r.start, 0, function(i, s, _, inp, st)
		inp.moveX, inp.jumpHeld = 1, true
		act(i, s, inp, st)
	end, function(s, _, i)
		if Tut.fell(s.x, s.y) then return "fell" end
		if inGoal(r, s) then return "across" end
		if i > 400 then return "stuck" end
	end, 480)
end

do -- DASH: under the 2-tile roof a jump bonks; a jump at the edge and a dash any time in its first quarter second
	-- crosses; a jump and a double jump at the same timings almost never do (the room cannot need the dash outright:
	-- see tutorial.md §3), and nothing gets on top of the tunnel
	local plain, plainTries = 0, 0
	for jx = 206, 220 do
		for second = 0, 40, 2 do
			plainTries += 1
			local got = dashTry(function(i, s, inp, st)
				if not st.j and s.grounded and s.x - X >= jx then inp.jumpPressed, st.j = true, i end
				if st.j and second > 0 and i == st.j + second then inp.jumpPressed = true end
			end)
			if got == "across" then plain += 1 end
		end
	end
	print(("    dash: %d of %d jump + double jump timings cross the pit without a dash"):format(plain, plainTries))
	assert(plain <= plainTries * 0.06, "dash: jumps alone cross the pit only by luck")
	for f = 2, 16, 2 do
		local got = dashTry(function(i, s, inp, st)
			if not st.j and s.grounded and s.x - X >= 218 then inp.jumpPressed, st.j = true, i end
			if st.j and i == st.j + f then inp.dashPressed = true end
		end)
		assert(got == "across", ("dash: a jump at the edge and a dash %d frames later cross (got %s)"):format(f, tostring(got)))
	end
	assert(Tut.fell(X + 232, -7) and not Tut.fell(X + 232, -5) and not Tut.fell(X + 100, -20), "dash: the pit's fall line")
	local i = Tut.fell(X + 232, -7) :: number
	local sx, sy = Tut.startOf(i)
	assert(sx == X + room("dash").start and math.abs(sy - (HH + 0.05)) < 1e-9, "dash: a fall goes back to the room's start")
end

do -- GRAPPLE: from the dip's near edge the anchor is the aim assist's pick (in reach, above, on a screen centred on
	-- the runner); a jump and a held GRAPPLE hook it at any moment of the jump, and every release lands the runner on
	-- a floor (the dip is safe: a jump gets out of it either side)
	local a = Tut.ANCHORS[1]
	local anchor = { x = X + a.x, y = a.y, id = a.id }
	local view = { x = X + 266, y = HH + Config.CAMERA_Y_OFFSET, halfW = Config.CAMERA_VIEW_HEIGHT * 16 / 9 / 2,
		halfH = Config.CAMERA_VIEW_HEIGHT / 2 }
	local picked = Grapple.pick(X + 266, HH, 1, { anchor }, view, nil, nil, Config.RUN_SPEED)
	assert(picked and picked.id == Tut.ANCHOR_ID, "grapple: standing at the dip's edge, the anchor is the pick")
	local r = room("grapple")
	for delay = 0, 24, 4 do -- frames after the jump the GRAPPLE button goes down (and is held)
		for _, rel in { 0, 10, 20, 30, 45 } do -- frames on the rope before letting go
			local p = Tut.new()
			p.step = table.find(Tut.ROOMS, r) :: number
			local done = false
			local got = run(r.start, 0, function(i, s, _, inp, st)
				inp.moveX = 1
				if not st.j and s.grounded and s.x - X >= 265 then inp.jumpPressed, inp.jumpHeld, st.j = true, true, i end
				if st.j and i >= st.j + delay and not st.let then
					inp.grappleHeld, inp.grapplePressed = true, not st.pressed
					st.pressed = true
					local dx, dy = anchor.x - s.x, anchor.y - s.y
					if dy >= Config.GRAPPLE_MIN_ABOVE and dx * dx + dy * dy <= Config.GRAPPLE_RANGE ^ 2 then inp.anchor = anchor end
				end
				if s.rope then st.on = (st.on or 0) + 1 if st.on > rel then st.let = true inp.grappleHeld = false end end
			end, function(s, ev, i, st)
				local what = Tut.update(p, s.x, s.y, s.grounded, ev, s.rope ~= nil)
				if what == "done" then done = true end
				if done and s.grounded then return "landed" end
				if i > 500 then return "stuck" end
			end, 560)
			assert(got == "landed" and done, ("grapple: a hook %d frames into the jump, let go after %d, is a swing and lands (got %s)"):format(delay, rel, tostring(got)))
		end
	end
end

do -- the lesson rules
	local p = Tut.new()
	local function at(lx, ly, g, ev, rope) return Tut.update(p, X + lx, ly, g, ev, rope or false) end
	assert(at(10, HH, true) == nil and p.step == 1, "rules: nothing at the start")
	local w, id = at(40, HH, true)
	assert(w == "done" and id == "run" and p.step == 2 and p.done.run, "rules: the run's goal finishes it")
	assert(at(60, 10, false) == nil, "rules: over the hurdle is not the goal")
	w, id = at(110, 18 + HH, true)
	assert(w == "passed" and id == "jump" and p.passed.jump and p.step == 3, "rules: the next room reached first passes a lesson")
	w = at(110, 18 + HH, true)
	assert(w == "done" and p.done.double, "rules: standing on the ledge finishes the double jump")
	at(205, HH, true) -- the wall room walked past
	assert(p.passed.wall and p.step == 5, "rules: walking past the tower passes the wall jump")
	at(252, HH, true)
	assert(p.done.dash and p.step == 6, "rules: across the pit finishes the dash")
	assert(at(272, HH, false, { grapple = "attach" }, true) == nil and p.hooked, "rules: a hook is half a swing")
	w = at(274, HH, false, nil, false)
	assert(w == "done" and p.done.grapple and p.step == 7, "rules: letting go finishes the swing")
	assert(at(390, HH, true) == nil and p.step == 7, "rules: the IT lesson is not finished by a place")
	Tut.tagged(p)
	assert(p.done.it and Tut.current(p) == nil and at(390, HH, true) == nil, "rules: the server's tag finishes the course")
	assert(Tut.roomAt(X - 100) == nil and Tut.roomAt(X + 10) == 1 and Tut.roomAt(X + 400) == #Tut.ROOMS, "rules: rooms")
end

do -- the server's tag check: the player's newest position against where the target was in the window
	local hist = { { 1.0, 10, 0 }, { 1.1, 12, 0 }, { 1.2, 14, 0 }, { 1.3, 16, 0 } }
	local reach = Config.TAG_GRACE -- on top of the tag's own reach (Tag.overlaps)
	assert(Tut.caught(12.5, 0, hist, 1.05, reach), "caught: touching where the target was a moment ago")
	assert(not Tut.caught(12.5, 0, hist, 1.25, 0), "caught: not when that moment is out of the window")
	assert(not Tut.caught(30, 0, hist, 0, reach), "caught: never from a gap")
	assert(not Tut.caught(16, 10, hist, 0, reach), "caught: never from above its head")
end

do -- the target: a plain chaser (runs at it, jumps when it is above, as a beginner does) catches it inside 12 s,
	-- never in the first second; it never leaves its room. The chaser runs at "it"'s speed (Config.IT_SPEED, H40)
	local function chase(startX, meets)
		local t = Movement.new(X + Tut.CHASE.home, HH)
		local me = Movement.new(X + startX, HH)
		local ct, cm, m, tin = {}, {}, { turn = 0 }, { moveX = 0 }
		for i = 1, 60 * 20 do
			local now = i * DT
			BoxWorld.probe(world, t.x, t.y, ct)
			Tut.flee(t, me.x, me.y, now, m, DT, tin)
			Movement.step(t, tin, ct, DT)
			BoxWorld.move(world, t, DT)
			assert(t.x >= X + Tut.CHASE.lo - 4 and t.x <= X + Tut.CHASE.hi + 2, "target: stays in its room")
			BoxWorld.probe(world, me.x, me.y, cm)
			local dx = t.x - me.x
			local blocked = (dx > 0 and cm.wallRight ~= nil and cm.wallRight < 1) or (dx < 0 and cm.wallLeft ~= nil and cm.wallLeft < 1)
			local inp = { moveX = if math.abs(dx) < 0.5 then 0 else math.sign(dx),
				jumpPressed = me.grounded and ((meets and t.y > me.y + 3 and math.abs(dx) < 10) or blocked), -- and hops the crate
				jumpHeld = true, dashPressed = false }
			inp.speedMult = Config.IT_SPEED
			Movement.step(me, inp, cm, DT)
			BoxWorld.move(world, me, DT)
			if Tut.touching(me.x, me.y, t.x, t.y, 0) then return now end
		end
		return nil
	end
	for _, from in { 316, 332, 352 } do
		for _, meets in { true, false } do -- jumping to meet its hop, or only running (and hopping the crate)
			local t = chase(from, meets)
			print(("    target: a chaser from x %d%s tags it after %s s"):format(from, if meets then " who jumps to meet it" else " who only runs",
				if t then ("%.1f"):format(t) else "never"))
			assert(t and t > 1 and t < 14, "target: caught in 1..14 s")
		end
	end
	local t, m, inp = Movement.new(X + Tut.CHASE.home - 30, HH), { turn = 0 }, { moveX = 0 }
	Tut.flee(t, nil, nil, 0, m, DT, inp)
	assert(inp.moveX == 1, "target: alone, it walks back to the middle")
end

do -- where the course is: clear of the lobby and the room, inside the snapshot's range, the TUTORIAL door in the lobby
	for _, name in Lobby.NAMES do
		local a = Lobby.AREAS[name]
		assert(not Tut.inCourse(a.x - a.half - 24) and not Tut.inCourse(a.x + a.half + 24), "where: clear of the " .. name)
		assert(Lobby.areaAt(X) == nil and Lobby.areaAt(X + Tut.RIGHT) == nil, "where: the lobby's areas end before it")
	end
	assert(X + Tut.LEFT > -2047 and X + Tut.RIGHT < 2047, "where: inside the snapshot's +-2047 studs")
	local d = Lobby.door("lobby", "tutorial")
	assert(d, "where: the lobby has a TUTORIAL door")
	for _, o in Lobby.AREAS.lobby.doors do
		if o ~= d and o.y0 == d.y0 then assert(o.x1 + 2 <= d.x0 or d.x1 + 2 <= o.x0, "where: TUTORIAL keeps clear of " .. o.id) end
	end
	local k = Lobby.AREAS.lobby.view / 48 -- as server/LobbyMap draws them: the sign over the frame, a plate under a deck
	local signTop = d.y1 + 0.6 + 0.5 + 3 * k
	for _, z in Lobby.AREAS.lobby.zones do
		local plateLow = z[5] - 1.4 - 1.7 * k
		local apart = d.x0 - 0.6 >= z[3] or d.x1 + 0.6 <= z[2] or z[5] == 0 or signTop <= plateLow
		assert(apart, "where: TUTORIAL's sign clears the " .. z[1] .. " plate")
	end
	for _, b in Lobby.AREAS.lobby.blocks do
		if b[3] == 0 and b[5] < 20 and b[1] ~= "Floor" then
			assert(d.x1 <= b[2] or d.x0 >= b[4], "where: TUTORIAL is not inside " .. b[1])
		end
	end
	local sx, sy = Tut.startOf(1)
	assert(Tut.roomAt(sx) == 1 and sy > 0, "where: the course starts in its first room")
end
