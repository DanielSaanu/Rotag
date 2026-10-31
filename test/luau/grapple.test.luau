--!include movement_world.luau
-- The grapple (H25, DESIGN §2 kit, §3 rule 17; docs/systems/grapple.md): the aim assist's pick, the hook, the rope's
-- step, the release. Driven through Movement.step in the box world (Q3), the way the client drives it.
local Grapple = __require("Grapple")

local G = Config.GRAVITY
local OPEN = {} -- open air: no floor, no wall
local VIEW = { x = 0, y = 0, halfW = 42, halfH = 24 } -- a 16:9 screen round the origin

-- An input with the grapple: `hook` held, `press` this frame, `anchor` the pick (as the client hands it in).
local function gin(t)
	local i = input(t)
	i.grappleHeld, i.grapplePressed, i.anchor = t.hook, t.press, t.anchor
	return i
end

local function ropeLen(s) return math.sqrt((s.x - s.rope.x) ^ 2 + (s.y - s.rope.y) ^ 2) end
-- Per unit mass, from the swing's own speed (w x len while taut: the body's velocity is this step's chord).
local function energy(s)
	local r = s.rope
	local v2 = if r and r.w then (r.w * r.len) ^ 2 else s.vx * s.vx + s.vy * s.vy
	return 0.5 * v2 + G * s.y
end

-- A runner in open air at (x, y), hooked to anchor `a` on the first frame.
local function hooked(x, y, a, vx, vy)
	local s = Movement.new(x, y)
	s.vx, s.vy = vx or 0, vy or 0
	local ev = tick(OPEN, s, gin({ hook = true, press = true, anchor = a }))
	assert(ev.grapple == "attach" and s.rope, "the hook takes")
	return s
end

do -- the pick (rule 17): above, in reach, on screen; the nearest, ahead before behind; sticky; line of sight
	local A = { x = 10, y = 12, id = 1 }
	assert(Grapple.pick(0, 0, 1, { A }, VIEW) == A, "an anchor above, in reach and on screen is picked")
	assert(Grapple.pick(0, 0, 1, { { x = 10, y = 2, id = 2 } }, VIEW) == nil, "too little above: not picked")
	assert(Grapple.pick(0, 0, 1, { { x = 0, y = -8, id = 2 } }, VIEW) == nil, "below: never")
	assert(Grapple.pick(0, 0, 1, { { x = 20, y = 20, id = 2 } }, VIEW) == nil, "out of GRAPPLE_RANGE (28.3): not picked")
	local edge = { x = 0, y = 23, id = 3 } -- 23 up: in reach, but 1 stud inside the screen's top (inset 2)
	assert(Grapple.pick(0, 0, 1, { edge }, VIEW) == nil, "never an anchor at or past the screen's edge (rule 17)")
	assert(Grapple.pick(0, 0, 1, { edge }, { x = 0, y = 5, halfW = 42, halfH = 24 }) == edge, "the same one on screen")
	local side = { x = 20, y = 12, id = 7 } -- 23.3 away: in reach, but past the right edge of a screen centred at -21
	assert(Grapple.pick(0, 0, 1, { side }, { x = -21, y = 0, halfW = 42, halfH = 24 }) == nil, "nor past a side edge")
	assert(Grapple.pick(0, 0, 1, { side }, VIEW) == side, "the same one on screen")
	local behind = { x = -8, y = 10, id = 4 } -- 12.8 away, behind
	local ahead = { x = 12, y = 10, id = 5 } -- 15.6 away, ahead
	assert(Grapple.pick(0, 0, 1, { behind, ahead }, VIEW) == ahead, "ahead of the facing beats a little nearer behind")
	assert(Grapple.pick(0, 0, -1, { behind, ahead }, VIEW) == behind, "turn round and the other one is ahead")
	local b = { x = 11, y = 10, id = 6 } -- 14.87 against ahead's 15.62: b is nearer by 0.75
	assert(Grapple.pick(0, 0, 1, { ahead, b }, VIEW) == b, "the nearest wins")
	assert(Grapple.pick(0, 0, 1, { ahead, b }, VIEW, 5) == ahead, "the last pick holds against one under STICKY nearer")
	assert(Grapple.pick(0, 0, 1, { A, ahead }, VIEW, nil, function(a) return a ~= A end) == ahead,
		"a blocked line of sight skips the anchor, the next one is picked")
	-- QA round 1: never one behind the MOTION at speed (the catch would throw the run away); walking, it is fine
	local fast = Config.GRAPPLE_BEHIND_FAST * Config.RUN_SPEED + 1
	assert(Grapple.pick(0, 0, 1, { behind }, VIEW, nil, nil, fast) == nil, "sprinting right: the one behind is skipped")
	assert(Grapple.pick(0, 0, -1, { behind }, VIEW, nil, nil, fast) == nil, "... whichever way you face")
	assert(Grapple.pick(0, 0, 1, { behind }, VIEW, nil, nil, -fast) == behind, "sprinting left: it is ahead of the motion")
	assert(Grapple.pick(0, 0, 1, { behind }, VIEW, nil, nil, fast - 10) == behind, "at a walk, behind is still a pick")
	-- QA round 1: never one under the HUD's banner at the top of the screen (GRAPPLE_INSET_TOP, more than the side inset)
	local top = { x = 0, y = 24 - Config.GRAPPLE_INSET_TOP + 0.5, id = 8 }
	assert(Grapple.pick(0, 0, 1, { top }, VIEW) == nil, "under the banner: not picked")
	assert(Grapple.pick(0, 0, 1, { top }, { x = 0, y = 2, halfW = 42, halfH = 24 }) == top, "the same one lower on screen")
end

do -- QA round 1: an air hook on a long rope never swings into the floor under the anchor: the rope reels to clear it
	local a = { x = 0, y = 20, id = 1, floor = 0 } -- 20 up, the floor's top at y 0
	local s = hooked(-22, 8, a, 40, 0) -- a runner 23.4 away: a rope that long would swing 3.4 below the floor
	assert(s.rope.target <= a.y - a.floor - Config.RUNNER_HEIGHT / 2 - Config.GRAPPLE_LIFT + 1e-6,
		"the target length leaves the low point a LIFT above the floor")
	local lowest = s.y
	for _ = 1, 180 do -- 3 s of swing on a floor at 0 (the world has one here)
		tick(FLOOR, s, gin({ hook = true, moveX = 1 }))
		lowest = math.min(lowest, s.y)
	end
	assert(s.rope ~= nil, "still on the rope: no landing took it")
	assert(lowest - Config.RUNNER_HEIGHT / 2 > 0.3, ("feet never reached the floor; lowest feet %.2f"):format(lowest - 1.75))
	local b = { x = 0, y = 20, id = 2 } -- no floor known (over a gap): the old rule, the distance
	local t = hooked(-22, 8, b, 40, 0)
	assert(math.abs(t.rope.target - math.sqrt(22 * 22 + 12 * 12)) < 1e-6, "no floor: the rope is the distance")
end

do -- QA round 1: W held in the air before an anchor is in reach still hooks when one comes (never from the floor)
	local a = { x = 10, y = 14, id = 1 }
	local s = Movement.new(0, 6)
	tick(OPEN, s, gin({ hook = true, press = true })) -- pressed airborne, no anchor yet
	for _ = 1, 20 do tick(OPEN, s, gin({ hook = true })) end -- 0.33 s: the 0.1 s buffer is long gone
	tick(OPEN, s, gin({ hook = true, anchor = a }))
	assert(s.rope ~= nil, "an airborne press still held hooks the anchor that comes into reach")
	local g = standing(FLOOR, 0)
	tick(FLOOR, g, gin({ hook = true, press = true }))
	for _ = 1, 20 do tick(FLOOR, g, gin({ hook = true })) end
	tick(FLOOR, g, gin({ hook = true, anchor = a }))
	assert(g.rope == nil, "pressed and held on the floor: no hook until a fresh press (standing never auto-hooks)")
	local h = Movement.new(0, 6)
	tick(OPEN, h, gin({ hook = true, press = true }))
	tick(OPEN, h, gin({})) -- let go in the air
	for _ = 1, 5 do tick(OPEN, h, gin({ hook = true })) end
	tick(OPEN, h, gin({ hook = true, anchor = a }))
	assert(h.rope == nil, "let go and re-held without a press: not armed")
end

do -- hook in the air: the rope is the distance; the swing keeps that length (within 0.5 stud over 2 s)
	local a = { x = 0, y = 20, id = 1 }
	local s = hooked(-14, 6, a)
	local len = s.rope.len
	assert(math.abs(len - math.sqrt(14 * 14 + 14 * 14)) < 1e-6, "rope = the distance at the hook")
	local worst, lowest = 0, s.y
	for _ = 1, 120 do
		tick(OPEN, s, gin({ hook = true }))
		assert(s.rope, "still on the rope while held")
		worst = math.max(worst, math.abs(ropeLen(s) - len))
		lowest = math.min(lowest, s.y)
	end
	assert(worst < 0.5, ("the rope keeps its length within 0.5 stud: off by %.3f"):format(worst))
	assert(math.abs(lowest - (a.y - len)) < 0.5, "the swing passes under the anchor at the rope's length")
end

do -- energy: never grows on the rope with no stick; hanging still stays still
	local a = { x = 0, y = 20, id = 1 }
	local s = hooked(-12, 8, a)
	local e0, top, firstTop = energy(s), -math.huge, -math.huge
	for k = 1, 240 do
		tick(OPEN, s, gin({ hook = true }))
		top = math.max(top, energy(s))
		if k == 60 then firstTop = top end
	end
	print(("    swing energy: %.1f at the hook, %.1f after 4 s (%.1f%% of the drop's)"):format(e0, energy(s),
		100 * (e0 - energy(s)) / (G * (a.y - 12 - (a.y - s.rope.len)))))
	print(("    swing energy peak: %.1f in the first second, %.1f over 4 s"):format(firstTop, top))
	assert(top <= e0 + 0.02 * G * 5, ("energy never grows on the rope: %.1f against %.1f at the hook"):format(top, e0))
	assert(top <= firstTop + 1e-6, "and its peak is set in the first swing, never later: no slow pumping by the maths")
	assert(energy(s) > e0 - 0.05 * G * 12, "and the swing does not die out in 4 s (under 5% of its drop lost)")
	local still = hooked(0, 8, a)
	for _ = 1, 120 do tick(OPEN, still, gin({ hook = true })) end
	assert(math.abs(still.x) < 1e-6 and math.abs(still.vx) < 1e-6 and math.abs(still.y - 8) < 0.5,
		"hanging straight down with no stick: no swing appears from nowhere")
	local widest = 0
	for _ = 1, 120 do -- push the way you swing (from rest: right), as a player pumps a swing
		tick(OPEN, still, gin({ hook = true, moveX = if still.vx < 0 then -1 else 1 }))
		widest = math.max(widest, math.abs(still.x))
	end
	print(("    pump from a dead hang, 2 s with the swing: %.1f studs out on a 12-stud rope"):format(widest))
	assert(widest > 4, "the stick's pump gets a hanging runner swinging")
end

do -- a rope only pulls: flying in toward the anchor it is slack (free flight); a rope's length out it catches
	local a = { x = 0, y = 20, id = 1 }
	local s = hooked(-14, 6, a, 40, 40) -- moving up and in, toward the anchor
	assert(s.rope.w == nil, "moving inward: slack")
	local caught = nil
	for k = 1, 60 do
		tick(OPEN, s, gin({ hook = true }))
		assert(ropeLen(s) <= s.rope.len + 0.05, "never past the rope's length")
		if s.rope.w and not caught then caught = k end
	end
	assert(caught and caught > 5, "it falls back out and the rope catches it")
	-- Swung up past the anchor's height too slowly to go over: the rope would have to push, so it goes slack and the
	-- runner falls inside the circle (a rod would carry it round on the circle).
	local up = hooked(0, 8, a, 115, 0)
	local inside, wentSlack = math.huge, false
	for _ = 1, 90 do
		tick(OPEN, up, gin({ hook = true }))
		if up.rope.w == nil then wentSlack = true end
		inside = math.min(inside, ropeLen(up))
	end
	assert(wentSlack and inside < up.rope.len - 0.3, ("over the top too slowly: slack, falls inside (%.1f of %.1f)")
		:format(inside, up.rope.len))
	local hi = hooked(-9, 16, a, 0, 0) -- 4 below, 9 to the side; nearly level, at rest: the rope catches at once
	assert(hi.rope.w ~= nil, "at rest on a taut rope below the anchor: hanging")
end

do -- the speed cap: hooked at a dash's speed on the longest rope, the swing never passes GRAPPLE_MAX_SPEED
	local a = { x = 0, y = 28, id = 1 }
	local s = hooked(-28, 28 - 1e-3, a, Config.DASH_SPEED, 0)
	local fastest = 0
	for _ = 1, 180 do
		tick(OPEN, s, gin({ hook = true, moveX = 1 }))
		fastest = math.max(fastest, math.sqrt(s.vx * s.vx + s.vy * s.vy))
	end
	assert(fastest <= Config.GRAPPLE_MAX_SPEED + 1e-6, "the swing never passes its cap, got " .. fastest)
	assert(fastest > Config.GRAPPLE_MAX_SPEED - 1, "and this swing does reach it")
end

do -- release (rule 16, rule 17): the swing's velocity is kept, times the boost; the cooldown, then a new hook
	local a = { x = 0, y = 20, id = 1 }
	local s = hooked(-14, 6, a)
	for _ = 1, 120 do -- to the bottom of the swing
		if s.y < 20 - s.rope.len + 0.3 and s.vx > 0 then break end
		tick(OPEN, s, gin({ hook = true }))
	end
	local r = s.rope
	local vx = r.w * r.len * math.cos(math.atan2(s.x - r.x, r.y - s.y)) -- the swing's own speed across, here
	tick(OPEN, s, gin({ moveX = 1 })) -- let go, holding the way we swing
	assert(s.rope == nil, "let go: off the rope")
	assert(near(s.vx, kept(vx * Config.GRAPPLE_RELEASE_BOOST), 1e-6),
		("the release keeps the swing x the boost: %.2f from %.2f"):format(s.vx, vx))
	tick(OPEN, s, gin({ hook = true, press = true, anchor = a }))
	assert(s.rope == nil, "no new hook inside GRAPPLE_COOLDOWN")
	frames(OPEN, s, math.ceil(Config.GRAPPLE_COOLDOWN * 60), gin({ hook = true }))
	tick(OPEN, s, gin({ hook = true, press = true, anchor = a }))
	assert(s.rope, "after the cooldown a press hooks again")
end

do -- jump off the rope: let go with the boost and at least a full jump up; the double jump is still in hand
	local a = { x = 0, y = 20, id = 1 }
	local s = hooked(0, 8, a)
	local ev = tick(OPEN, s, gin({ hook = true, jump = true }))
	assert(s.rope == nil and ev.jump and ev.grapple == "jump", "a jump lets go")
	assert(s.vy > Config.JUMP_SPEED - G / 60 - 1e-6, "at least a full jump up")
	assert(s.airJumps == Config.AIR_JUMPS, "the rope's jump is not the double jump")
end

do -- a hook gives back the dash and double jump (rule 15: a contact); a hold, a dash, a landing take the rope away
	local a = { x = 0, y = 20, id = 1 }
	local s = Movement.new(0, 8)
	s.airJumps, s.dashes = 0, 0
	tick(OPEN, s, gin({ hook = true, press = true, anchor = a }))
	assert(s.airJumps == Config.AIR_JUMPS and s.dashes == 1, "dash and double jump back on the hook")
	local i = gin({ hook = true })
	i.hold = "trap"
	tick(OPEN, s, i)
	assert(s.rope == nil, "a hold breaks the rope")
	local d = hooked(0, 8, a)
	tick(OPEN, d, gin({ hook = true, dash = true, moveX = -1 }))
	assert(d.rope == nil and d.vx == -Config.DASH_SPEED, "a dash lets go and sets its own speed")
	local LOW = { { -50, -10, 50, 0 } } -- a floor 6 studs under the swing's low point: a long rope reaches it
	local l = Movement.new(-20, 10)
	tick(LOW, l, gin({ hook = true, press = true, anchor = { x = 0, y = 26, id = 1 } }))
	assert(l.rope, "hooked over the floor")
	for _ = 1, 120 do
		tick(LOW, l, gin({ hook = true }))
		if l.grounded then break end
	end
	assert(l.grounded and l.rope == nil, "landing ends the swing")
end

do -- the buffer: a press just before an anchor comes into reach still hooks; one too early does not, UNLESS it was
	-- made in the air and is still held (QA round 1: a beginner holding W before the ball is armed; the floor case is
	-- in its own block below)
	local a = { x = 0, y = 20, id = 1 }
	local s = Movement.new(0, 8)
	tick(OPEN, s, gin({ hook = true, press = true })) -- nothing picked yet
	frames(OPEN, s, 3, gin({ hook = true }))
	tick(OPEN, s, gin({ hook = true, anchor = a }))
	assert(s.rope, "a press 4 frames early hooks when the anchor is picked")
	local late = standing(FLOOR, 0)
	tick(FLOOR, late, gin({ hook = true, press = true }))
	frames(FLOOR, late, 8, gin({ hook = true }))
	tick(FLOOR, late, gin({ hook = true, anchor = a }))
	assert(late.rope == nil, "a press 9 frames early on the floor has run out (standing never arms)")
	local let = Movement.new(0, 8)
	tick(OPEN, let, gin({ press = true, hook = false, anchor = a }))
	assert(let.rope == nil, "a tap already let go does not hook")
end

do -- from the floor the rope reels in so the runner swings clear of it; it never drags along the floor
	local a = { x = 10, y = 16, id = 1 }
	local s = standing(FLOOR, 0)
	tick(FLOOR, s, gin({ hook = true, press = true, anchor = a }))
	assert(s.rope and not s.grounded, "hooked from the floor")
	local feet = HH
	for _ = 1, 60 do tick(FLOOR, s, gin({ hook = true })) end
	assert(s.rope, "still swinging after 1 s: the low point clears the floor")
	assert(math.abs(s.rope.len - (a.y - feet - Config.GRAPPLE_LIFT)) < 1e-6, "reeled to the lift")
end

do -- the pose: on the rope, the swing sprite
	local s = hooked(0, 8, { x = 0, y = 20, id = 1 })
	assert(Movement.spriteFor(s) == Movement.SWING_SPRITE, "the swing pose on the rope")
end

print("grapple ok")
