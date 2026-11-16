-- The bots (H31, docs/systems/bots.md): shared/BoxWorld (the box world, the tile grid, the flood fill) and
-- shared/BotBrain (plans tried through the real Movement). Driven on the real maps: a bot must be able to get to
-- every deck a player can, catch a standing runner, and get away from a chaser.
local Config = __require("Config")
local Movement = __require("Movement")
local Maps = __require("Maps")
local BoxWorld = __require("BoxWorld")
local BotBrain = __require("BotBrain")

local T = Config.STUDS_PER_TILE
local HH = Config.RUNNER_HEIGHT / 2
local DT = 1 / 60

local seed = 12345
local function rand() -- a fixed sequence: the test is the same every run
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

do -- the probe and the mover agree with the movement tests' world: a runner dropped on a floor lands and stands
	local world = { { -100, -8, 100, 0 } }
	local s = Movement.new(0, 10)
	local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
	for _ = 1, 120 do
		BoxWorld.probe(world, s.x, s.y, c)
		Movement.step(s, input, c, DT)
		BoxWorld.move(world, s, DT)
	end
	assert(s.grounded and math.abs(s.y - HH) < 0.01, "a dropped runner stands on the floor")
end

do -- a wall stops the runner flush, and the probe reads it as a wall in reach
	local world = { { -100, -8, 100, 0 }, { 10, 0, 14, 20 } }
	local s = Movement.new(0, HH)
	local c, input = {}, { moveX = 1, jumpPressed = false, jumpHeld = false, dashPressed = false }
	for _ = 1, 120 do
		BoxWorld.probe(world, s.x, s.y, c)
		Movement.step(s, input, c, DT)
		BoxWorld.move(world, s, DT)
	end
	assert(math.abs(s.x - (10 - Config.RUNNER_WIDTH / 2)) < 0.01, "flush against the wall")
	BoxWorld.probe(world, s.x, s.y, c)
	assert(c.wallRight ~= nil and c.wallRight <= 0.01 and c.wallLeft == nil, "the wall is on the right, touching")
end

do -- the flood fill goes ROUND a deck: the tile over a deck is further than the straight line says
	local map = Maps.get("yard")
	local g = BoxWorld.grid(map.blocks, map.top)
	local field, queue = {}, {}
	BoxWorld.field(g, 0, 5 * T + HH, field, queue) -- from on top of the Hub (5 tiles up, x 0)
	local under = BoxWorld.far(g, field, 0, HH) -- the floor right under it: 5 tiles away in a straight line
	assert(under > 8 * T and under < BoxWorld.FAR, ("under the hub is a walk round its end, got %g studs"):format(under))
	assert(BoxWorld.far(g, field, 0, 5 * T + HH) == 0, "the source is 0")
	assert(field[BoxWorld.tile(g, 0, 4.5 * T)] >= BoxWorld.FAR, "the deck's own tiles are solid: never filled")
end

-- Run a bot (think every BOT_THINK, as the server does) until `done` or `seconds` pass. Returns the time taken.
local function drive(map, s, goalOf, seconds, done)
	local world = BoxWorld.fromBlocks(map.blocks)
	local g = BoxWorld.grid(map.blocks, map.top)
	local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
	local field, queue = {}, {}
	local plan, mem, planT, nextThink = BotBrain.IDLE, BotBrain.memory(), 0, 0
	local t = 0
	while t < seconds do
		if t >= nextThink and (s.grounded or planT >= 0.7) then
			local goal = goalOf(g, field, queue)
			plan, mem, planT = BotBrain.choose(world, g, s, goal, rand, plan), BotBrain.memory(), 0
			nextThink = t + Config.BOT_THINK
		end
		BoxWorld.probe(world, s.x, s.y, c)
		BotBrain.input(plan, mem, s, c, planT, input)
		input.speedMult = Config.BOT_SPEED
		Movement.step(s, input, c, DT)
		BoxWorld.move(world, s, DT)
		planT += DT
		t += DT
		if done(s) then return t end
	end
	return nil
end

do -- a bot on the Yard's floor reaches a runner standing on every deck a player can stand on, in a few seconds
	local map = Maps.get("yard")
	local slowest, where = 0, ""
	for _, b in map.blocks do
		local name, x0, y0, x1, y1 = b[1], b[2], b[3], b[4], b[5]
		if y1 - y0 <= 1.01 and name ~= "Floor" then -- a deck
			local tx, ty = (x0 + x1) / 2, y1 + HH
			local s = Movement.new(30, HH) -- from the floor near the middle
			local took = drive(map, s, function(g, field, queue)
				return { mode = "seek", x = tx, y = ty, field = BoxWorld.field(g, tx, ty, field, queue) }
			end, 25, function(st)
				return math.abs(st.x - tx) <= Config.RUNNER_WIDTH + 1 and math.abs(st.y - ty) <= Config.RUNNER_HEIGHT + 1
			end)
			assert(took, ("the bot never reached %s at (%g, %g)"):format(name, tx, ty))
			if took > slowest then slowest, where = took, name end
		end
	end
	print(("    bots: every Yard deck reached from the floor; the slowest was %s in %.1f s"):format(where, slowest))
end

do -- and the test map's too
	local map = Maps.get("test")
	for _, o in map.livingOrbs do
		local s = Movement.new(map.spawn.x, map.spawn.y + HH)
		local took = drive(map, s, function(g, field, queue)
			return { mode = "seek", x = o.x, y = o.y, field = BoxWorld.field(g, o.x, o.y, field, queue) }
		end, 25, function(st) return math.abs(st.x - o.x) <= 3 and math.abs(st.y - o.y) <= 4 end)
		assert(took, ("the bot never reached the test map's orb at (%g, %g)"):format(o.x, o.y))
	end
end

do -- fleeing: from 6 tiles off a still chaser, the bot is far away within 3 s and never ends at an end wall
	local map = Maps.get("yard")
	local cx, cy = 0, HH
	local s = Movement.new(6 * T, HH)
	drive(map, s, function(g, field, queue)
		return { mode = "flee", x = cx, y = cy, field = BoxWorld.field(g, cx, cy, field, queue), safe = 30 * T }
	end, 3, function() return false end)
	local away = math.sqrt((s.x - cx) ^ 2 + (s.y - cy) ^ 2)
	assert(away >= 15 * T, ("3 s of fleeing got only %g studs away"):format(away))
end

do -- the closing walls: a plan that ends outside the room is never the pick
	local map = Maps.get("yard")
	local s = Movement.new(20, HH)
	drive(map, s, function(g, field, queue)
		return { mode = "flee", x = 0, y = HH, field = BoxWorld.field(g, 0, HH, field, queue), safe = 30 * T, lo = -24, hi = 24 }
	end, 4, function() return false end)
	assert(s.x > -24 and s.x < 24, ("the bot fled out of the walls to x %g"):format(s.x))
end

do -- noDash: a think that may not dash never picks a dash plan, however good one is (a long open floor)
	local world = { { -400, -8, 400, 0 } }
	local g = BoxWorld.grid({ { "Floor", -400, -8, 400, 0 } }, 40)
	local field, queue = {}, {}
	local s = Movement.new(-150, HH)
	local dashes = 0
	for _ = 1, 30 do
		local goal = { mode = "seek", x = 150, y = HH, field = BoxWorld.field(g, 150, HH, field, queue) }
		if BotBrain.choose(world, g, s, goal, rand, nil).dash then dashes += 1 end
		goal.noDash = true
		assert(not BotBrain.choose(world, g, s, goal, rand, nil).dash, "noDash: no dash plan is picked")
	end
	assert(dashes > 20, ("free to dash down an open floor, the bot dashes (%d of 30)"):format(dashes))
end

do -- the closing walls cost on the way too: a plan that leaves the room and comes back rates under one that stays in
	local world = { { -400, -8, 400, 0 } }
	local g = BoxWorld.grid({ { "Floor", -400, -8, 400, 0 } }, 40)
	local field, queue = {}, {}
	local s = Movement.new(20, HH)
	local out = nil -- "run right for 1.1 s": leaves a room that ends at x 24 at once and ends well outside
	for _, p in BotBrain.PLANS do
		if p.dir == 1 and not p.jumpAt and not p.dash and not p.stopAt and not p.climb then out = p end
	end
	assert(out, "the plain run plan exists")
	local goal = { mode = "flee", x = -100, y = HH, safe = 400, field = BoxWorld.field(g, -100, HH, field, queue) }
	local free = BotBrain.rate(world, g, s, out, goal)
	goal.lo, goal.hi = -24, 24
	local walled = BotBrain.rate(world, g, s, out, goal)
	assert(walled < free - 1000, "ending outside the walls is the worst plan")
	goal.lo, goal.hi = -24, 60 -- now it ends inside (x ~66 is past 60: still out)... a room it ends INSIDE of:
	goal.lo, goal.hi = -24, 80
	local inside = BotBrain.rate(world, g, s, out, goal)
	assert(inside == free, "a plan that never leaves the room costs nothing")
	-- a room whose wall the plan crosses and re-crosses: start outside at x 20 with the room at x 30..200
	goal.lo, goal.hi = 30, 200
	local crossing = BotBrain.rate(world, g, s, out, goal)
	assert(crossing < free and crossing > free - 1000, "steps spent outside on the way cost, less than ending outside")
end

do -- cost: one decision is PLANS x HORIZON / STEP move steps; say what that is so a change is seen
	local map = Maps.get("yard")
	local world = BoxWorld.fromBlocks(map.blocks)
	local g = BoxWorld.grid(map.blocks, map.top)
	local field, queue = {}, {}
	local s = Movement.new(0, HH)
	local t0 = os.clock()
	local n = 50
	for _ = 1, n do
		BotBrain.choose(world, g, s, { mode = "seek", x = 100, y = 40, field = BoxWorld.field(g, 100, 40, field, queue) }, rand, nil)
	end
	local each = (os.clock() - t0) / n
	print(("    bots: one decision = %d plans x %d steps, %.2f ms here; 3 bots thinking every %.1f s = %.1f%% of a core"):format(
		#BotBrain.PLANS, math.floor(BotBrain.HORIZON / BotBrain.STEP + 0.5), each * 1000, Config.BOT_THINK,
		each * 3 / Config.BOT_THINK * 100))
	assert(each < 0.02, "a decision must stay well under a frame")
end

print("    bots ok")
