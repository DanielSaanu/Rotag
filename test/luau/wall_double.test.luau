--!include movement_world.luau
-- H42 (docs/systems/movement.md §3, "Which jump a press beside a wall gives"): a press RISING beside a wall, with the
-- double jump in hand, the stick not pushed away from the wall, and no kick or double jump beside a wall since the
-- floor, is the double jump; falling or sliding beside it, pushing away, or once the wall is used, it is the kick. Rule
-- 15 is unchanged (a touch still gives the double back), so the "used" flag is what stops double jumps climbing a wall
-- forever. Every case through the real step().

local LEDGE_TOP = 20 -- over one jump (14.25), under two (28.5): the tutorial's ledge (18) and a map deck's kind
local face = { { -100, -10, 100, 0 }, { 10, 0, 40, LEDGE_TOP } } -- floor, and a solid ledge whose face is at x = 10
local function onTop(s) return s.grounded and s.x > 10 and math.abs(s.y - HH - LEDGE_TOP) < 0.01 end

-- From standing at x0, hold the stick `stick` and jump; press again `second` frames later. Returns the second press's
-- jump kind and whether the runner ends standing on the ledge.
-- `pressStick`: the stick on the frame of the second press only (default: `stick`).
local function tryLedge(x0, stick, second, runFrames, pressStick)
	local s = standing(face, x0)
	frames(face, s, runFrames or 0, input({ moveX = stick }))
	tick(face, s, input({ moveX = stick, jump = true }))
	local kind
	for i = 1, 150 do
		local ev = tick(face, s, input({ moveX = if i == second then pressStick or stick else stick, jump = i == second,
			held = true }))
		if i == second then kind = ev.jump end
		if s.grounded and i > second then break end
	end
	return kind, onTop(s)
end

do -- the tester's case: flush against a ledge's face, jump, jump again while rising: the double jump, onto the top
	for second = 7, 21, 2 do -- 0.12-0.35 s in: the whole rise that clears 20 studs (earlier is a double too, just low)
		local kind, top = tryLedge(10 - HW, 1, second)
		assert(kind == "double", ("rising beside the face, stick toward it: press %d frames in is the double, got %s")
			:format(second, tostring(kind)))
		assert(top, ("... and lands on the ledge (press %d frames in)"):format(second))
	end
	assert(tryLedge(10 - HW, 0, 6) == "double", "stick let go: still the double jump")
	assert(tryLedge(10 - HW, 1, 9, 0, -1) == "wall", "stick pushed away from the wall on the press: the kick")
	assert(tryLedge(10 - HW, 0, 9, 0, -1) == "wall", "... from a neutral stick too")
end

do -- a run-up into the face: every take-off that meets the face rising and presses again rising lands on top
	local wins, tries, kicksOld = 0, 0, 0
	for back = 4, 20, 2 do -- studs from the face at take-off
		for second = 4, 16, 2 do
			tries += 1
			local kind, top = tryLedge(10 - HW - back - 10, 1, second, 13) -- ~10 studs of run-up first
			if top then wins += 1 end
			assert(top or second < 7, ("from %d studs back, a second press %d frames in lands on top"):format(back, second))
			if kind == "wall" then kicksOld += 1 end
		end
	end
	-- measured: 45 of 63 (every miss a press at 4 or 6 frames: too low); before H42, 29 of 63 with 16 kicks off the face
	print(("    wall double: %d of %d run-up jump + second press timings land on the 20-stud ledge (kicks: %d)")
		:format(wins, tries, kicksOld))
	assert(kicksOld == 0, "no second press made rising beside the face is a kick any more")
end

do -- falling or sliding beside a wall, the press is the kick, as before (the wall-slide climb)
	local wall = { { 10, -100, 12, 200 } }
	local s = Movement.new(10 - HW, 20)
	s.vy = -5
	local ev = tick(wall, s, input({ moveX = 1, jump = true }))
	assert(ev.jump == "wall", "sliding down a wall with the double jump in hand: the kick, got " .. tostring(ev.jump))
	s = Movement.new(10 - HW - REACH * 0.5, 20) -- in reach, not touching: no refresh
	s.vy, s.airJumps = 30, 0
	ev = tick(wall, s, input({ moveX = 1, jump = true }))
	assert(ev.jump == "wall", "rising beside a wall with the double jump spent: the kick")
	s = Movement.new(10 - HW, 20) -- touching, rising: the touch gives the double back (rule 15) but the wall is used
	s.vy, s.wallUsed = 30, true
	ev = tick(wall, s, input({ moveX = 1, jump = true }))
	assert(ev.jump == "wall", "a used wall, the double jump in hand (the touch gave it back): the kick")
end

do -- no endless climb by double jumps: hold into a tall wall and press every few frames for 4 s. At most one double
	-- jump beside a wall between landings (without the flag, each touch gives the double back, rule 15, and the presses
	-- go straight up the wall). The kick-double-kick climb up one wall is the old rules' own (measured before H42:
	-- 56-120 studs in 4 s by cadence), not this change's.
	local tall = { { -100, -10, 100, 0 }, { 10, 0, 12, 400 } }
	for _, every in { 2, 3, 4, 6, 9 } do
		local s = standing(tall, 10 - HW)
		local run, worst, top = 0, 0, 0
		for i = 1, 240 do
			local c = probe(tall, s)
			local beside = (c.wallRight or math.huge) <= REACH
			local ev = Movement.step(s, input({ moveX = 1, jump = i % every == 1, held = true }), c, DT)
			move(tall, s)
			if ev.jump == "double" and beside then run += 1 elseif s.grounded then run = 0 end
			worst = math.max(worst, run)
			top = math.max(top, s.y - HH)
		end
		print(("    one wall, a press every %d frames: feet top out at %.1f in 4 s"):format(every, top))
		assert(worst <= 1, ("pressing every %d frames: %d double jumps beside the wall in one flight"):format(every, worst))
	end
end

do -- once kicking, presses beside a wall stay kicks: a chimney climbed with ONE press on arriving at each wall
	local world = { { -100, -10, 100, 0 }, { -8, 0, -6, 300 }, { 6, 0, 8, 300 } }
	local s = standing(world, -6 + HW) -- flush against the left wall: jump up it, then kick off it pushing away
	tick(world, s, input({ moveX = -1, jump = true }))
	frames(world, s, 8, input({ moveX = -1, held = true }))
	assert(tick(world, s, input({ moveX = 1, jump = true, held = true })).jump == "wall", "pushing away: the first kick")
	local kicks, doubles, wasNear = 1, 0, false
	for _ = 1, 600 do
		local c = probe(world, s)
		local isNear = ((c.wallLeft and c.wallLeft <= REACH) or (c.wallRight and c.wallRight <= REACH)) == true
		local ev = Movement.step(s, input({ moveX = s.facing, jump = isNear and not wasNear, held = true }), c, DT)
		move(world, s)
		wasNear = isNear
		if ev.jump == "wall" then kicks += 1 elseif ev.jump == "double" then doubles += 1 end
		if kicks >= 6 then break end
	end
	print(("    chimney, one press per arrival: %d kicks, %d double jumps, feet at %.1f"):format(kicks, doubles, s.y - HH))
	assert(kicks >= 6 and doubles == 0, "after the first kick every arrival's press is a kick")
	assert(s.y - HH > 40, "and six kicks climb well over a double jump")

	-- a landing ends the kicking: kick off the ledge's face, land, walk back to it, and the second press rising beside
	-- it is the double once more (the same runner throughout)
	s = standing(face, 10 - HW)
	tick(face, s, input({ moveX = 1, jump = true }))
	frames(face, s, 24, input({ moveX = 1, held = true }))
	assert(tick(face, s, input({ moveX = 1, jump = true })).jump == "wall" and s.wallUsed, "falling: kicked off the face")
	for _ = 1, 240 do tick(face, s, input({ moveX = 1 })) if s.grounded and s.x >= 10 - HW - 1e-3 then break end end
	assert(s.grounded and not s.wallUsed, "back on the floor at the face, the wall unused again")
	tick(face, s, input({ moveX = 1, jump = true }))
	frames(face, s, 8, input({ moveX = 1, held = true }))
	assert(tick(face, s, input({ moveX = 1, jump = true, held = true })).jump == "double",
		"after landing, the second press beside the face is the double again")
end

print("    wall double ok")
