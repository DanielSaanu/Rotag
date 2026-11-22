-- H42 measurement harness (not a test: run with `node test/luau/sim.js escape_sim.luau [ARENA=320] [RUNS=20]`).
-- QA round 1 of docs/qa/playtest-fixes.md asked: can a runner who spams dashes and hops escape "it" (H40's speeds:
-- x1.1, ramping to x1.265 from 2 s to 17 s into a chase) for a whole round? Both bodies run the REAL shared/Movement
-- in a BoxWorld at 60 Hz: a flat floor between two end walls ARENA studs apart (the Yard's floor is about 320; 48 is
-- the closing walls' final box). A tag is Tag.overlaps or Tag.sweeps with no slack (what the tagger's screen claims at
-- zero lag; the server adds TAG_GRACE on top, so this is the runner's best case). Prints, per runner and chaser policy,
-- how many of RUNS chases end in a tag inside 60 s, and the median and worst time. docs/systems/movement.md §3 (H42).
local Config = __require("Config")
local Movement = __require("Movement")
local BoxWorld = __require("BoxWorld")
local Tag = __require("Tag")

local DT = 1 / 60
local ARENA = tonumber(SIM_ARENA) or 320
local RUNS = tonumber(SIM_RUNS) or 20
local LIMIT = 60
local HH = Config.RUNNER_HEIGHT / 2
local L, R = -ARENA / 2, ARENA / 2
local world = { { L - 10, -10, R + 10, 0 }, { L - 4, 0, L, 200 }, { R, 0, R + 4, 200 } }

local seed = 4242
local function rand() -- deterministic LCG, [0, 1)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function sign(v) return if v > 0 then 1 elseif v < 0 then -1 else 0 end

local function blank()
	return { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false, speedMult = 1 }
end

-- The dash-hop chain: dash whenever it is back, jump out of the dash just before it ends (rule 16: the jump keeps
-- the 120), and hop again on every landing.
local function chain(s, inp, dir)
	inp.moveX = dir
	if s.dashes > 0 and s.dashCooldown <= 0 and s.dashTime <= 0 then inp.dashPressed = true end
	if s.dashTime > 0 and s.dashTime <= 2 * DT then inp.jumpPressed = true end
	if s.grounded and s.dashTime <= 0 and not inp.dashPressed then inp.jumpPressed = true end
	inp.jumpHeld = s.vy > 0 or inp.jumpPressed
end

-- RUNNERS: return the input for the runner `r` fleeing `t` (m: the policy's memory).
local RUNNERS = {
	-- runs away; at an end wall it turns and runs back past "it" (no tricks)
	["runs"] = function(r, t, inp, m)
		local d = sign(r.x - t.x)
		if d == 0 then d = 1 end
		if (d > 0 and R - r.x < 6) or (d < 0 and r.x - L < 6) then d = -d end
		inp.moveX = d
	end,
	-- the QA case: dash on cooldown and hop away; cornered, turn, hop over "it" and dash on past ("side to side")
	["dash-hops, jukes over"] = function(r, t, inp, m)
		local away = sign(r.x - t.x)
		if away == 0 then away = 1 end
		local room = if away > 0 then R - r.x else r.x - L
		if not m.juke and room < 30 and math.abs(r.x - t.x) < 40 then m.juke = -away end
		if m.juke then
			local dir = m.juke
			local gap = (t.x - r.x) * dir -- > 0 while "it" is still ahead
			inp.moveX = dir
			if r.grounded and gap > 0 and gap < 16 then inp.jumpPressed = true end -- the hop over, apex near the crossing
			if not r.grounded and r.vy < 8 and gap < 4 and r.dashes > 0 and r.dashCooldown <= 0 then
				inp.dashPressed = true -- flat over its head
			end
			inp.jumpHeld = r.vy > 0 or inp.jumpPressed
			if gap < -12 then m.juke = nil end
			return
		end
		chain(r, inp, away)
	end,
}

-- CHASERS: the input for "it" `t` chasing `r`.
local CHASERS = {
	["runs at it"] = function(t, r, inp, m)
		inp.moveX = sign(r.x - t.x)
	end,
	-- a player who also chains dashes and hops toward the runner, and jumps to meet a hop coming over
	["dash-hops too, jumps to meet"] = function(t, r, inp, m)
		local dir = sign(r.x - t.x)
		local dx = math.abs(r.x - t.x)
		if dx < 18 and not r.grounded and r.vx * dir < 0 then -- the runner is coming over: meet it in the air
			inp.moveX = dir
			if t.grounded then inp.jumpPressed = true end
			inp.jumpHeld = t.vy > 0 or inp.jumpPressed
			return
		end
		chain(t, inp, dir)
	end,
}

local function episode(runner, chaser)
	local gap = math.min(15 + rand() * 25, ARENA * 0.5) -- 15-40 studs apart, both inside the walls
	local cx = (rand() - 0.5) * math.max(0, ARENA - gap - 8)
	local t, r = Movement.new(cx - gap / 2, HH), Movement.new(cx + gap / 2, HH)
	if rand() < 0.5 then t.x, r.x = r.x, t.x end
	local ct, cr = {}, {}
	local mt, mr = {}, {}
	for i = 1, LIMIT * 60 do
		local now = i * DT
		local it, ir = blank(), blank()
		it.speedMult = Tag.speedMult(true, now, false, false) -- the ramp (rule 4, H40)
		CHASERS[chaser](t, r, it, mt)
		RUNNERS[runner](r, t, ir, mr)
		local tx0, ty0 = t.x, t.y
		BoxWorld.probe(world, t.x, t.y, ct)
		BoxWorld.probe(world, r.x, r.y, cr)
		Movement.step(t, it, ct, DT)
		Movement.step(r, ir, cr, DT)
		BoxWorld.move(world, t, DT)
		BoxWorld.move(world, r, DT)
		if Tag.overlaps(t.x, t.y, r.x, r.y, 0) or Tag.sweeps(tx0, ty0, t.x, t.y, r.x, r.y, 0) then return now end
	end
	return nil
end

-- Top speeds on an open floor (no "it"): the chain against a run, 10 s from rest, for the record.
do
	local open = { { -1e5, -10, 1e5, 0 } }
	local function speed(mult, chained)
		local s, c = Movement.new(0, HH), {}
		for _ = 1, 600 do
			local inp = blank()
			inp.speedMult = mult
			if chained then chain(s, inp, 1) else inp.moveX = 1 end
			BoxWorld.probe(open, s.x, s.y, c)
			Movement.step(s, inp, c, DT)
			BoxWorld.move(open, s, DT)
		end
		return s.x / 10
	end
	print(("open floor, 10 s: run %.1f, dash-hop chain %.1f studs/s; it at x1.1 runs %.1f, chains %.1f; at x1.265 runs %.1f, chains %.1f")
		:format(speed(1, false), speed(1, true), speed(1.1, false), speed(1.1, true), speed(1.265, false), speed(1.265, true)))
end

print(("arena %d studs, %d chases each, 60 s cap, a touch with no slack (the runner's best case)"):format(ARENA, RUNS))
for _, runner in { "runs", "dash-hops, jukes over" } do
	for _, chaser in { "runs at it", "dash-hops too, jumps to meet" } do
		local times, escaped = {}, 0
		for _ = 1, RUNS do
			local at = episode(runner, chaser)
			if at then table.insert(times, at) else escaped += 1 end
		end
		table.sort(times)
		local med = if #times > 0 then times[math.floor((#times + 1) / 2)] else 0
		local worst = if #times > 0 then times[#times] else 0
		print(("  runner %-22s vs it %-28s: tagged %2d/%d, median %5.1f s, worst %5.1f s, escaped 60 s: %d")
			:format(runner, chaser, #times, RUNS, med, worst, escaped))
	end
end
