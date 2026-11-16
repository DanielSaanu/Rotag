-- Bots that pass for people (H32, docs/systems/bots.md §7): the grapple (a bot hooks only what a player at its spot
-- could: on its screen, in reach, in line of sight), hazards (a crate or a trap in the way is gone over or round),
-- luck (a sloppier bot picks worse plans) and names (player-like, no two seats alike, the same on every screen).
local Config = __require("Config")
local Movement = __require("Movement")
local Maps = __require("Maps")
local BoxWorld = __require("BoxWorld")
local BotBrain = __require("BotBrain")
local Session = __require("Session")

local T = Config.STUDS_PER_TILE
local HH = Config.RUNNER_HEIGHT / 2
local DT = 1 / 60

local seed = 4242
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

do -- line of sight: a box between two points blocks, a box beside the line does not, touching a corner does not
	local world = { { 0, 0, 10, 10 } }
	assert(not BoxWorld.clear(world, -5, 5, 15, 5), "straight through the box")
	assert(not BoxWorld.clear(world, 5, -5, 5, 15), "straight up through it")
	assert(not BoxWorld.clear(world, -5, -5, 15, 15), "the diagonal through it")
	assert(BoxWorld.clear(world, -5, 12, 15, 12), "over it")
	assert(BoxWorld.clear(world, -5, 5, -1, 5), "stops short of it")
	assert(BoxWorld.clear(world, 12, -5, 12, 15), "beside it")
	assert(BoxWorld.clear({}, 0, 0, 100, 100), "an empty world is clear")
	assert(BoxWorld.floorUnder(world, 5, 30) == 10 and BoxWorld.floorUnder(world, 50, 30) == nil, "the floor under a point")
	-- reach: how far a level line runs before the first box (the ice beam stops at a wall)
	assert(BoxWorld.reach(world, -8, 5, 1, 24) == 8, "8 studs to the box's near face")
	assert(BoxWorld.reach(world, 14, 5, -1, 24) == 4, "and from the other side")
	assert(BoxWorld.reach(world, -8, 5, -1, 24) == 24, "nothing that way: the whole length")
	assert(BoxWorld.reach(world, -8, 15, 1, 24) == 24, "over the box: clear")
	assert(BoxWorld.reach(world, 5, 5, 1, 24) == 0, "from inside a box: nothing")
end

local function hooksOf(map, world)
	local anchors = {}
	for i, a in map.anchors do
		table.insert(anchors, { x = a.x, y = a.y, id = i, floor = BoxWorld.floorUnder(world, a.x, a.y) })
	end
	return { anchors = anchors, world = world }
end

-- Run a bot as the server does; returns the time `done` came true (or nil) and how many frames it spent on a rope.
local function drive(map, s, goalOf, seconds, done, hooks, noise)
	local world = BoxWorld.fromBlocks(map.blocks)
	local g = BoxWorld.grid(map.blocks, map.top)
	local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
	local field, queue = {}, {}
	local plan, mem, planT, nextThink = BotBrain.IDLE, BotBrain.memory(), 0, 0
	local t, roped = 0, 0
	local h = if hooks then hooksOf(map, world) else nil
	while t < seconds do
		if t >= nextThink and (s.grounded or planT >= 0.7) then
			local goal = goalOf(g, field, queue)
			goal.hooks, goal.noise = h, noise
			plan, mem, planT = BotBrain.choose(world, g, s, goal, rand, plan), BotBrain.memory(), 0
			mem.hooked = s.rope ~= nil
			nextThink = t + Config.BOT_THINK
		end
		BoxWorld.probe(world, s.x, s.y, c)
		BotBrain.input(plan, mem, s, c, planT, input, h)
		input.speedMult = Config.BOT_SPEED
		Movement.step(s, input, c, DT)
		BoxWorld.move(world, s, DT)
		if s.rope then
			roped += 1
			-- a rope is only ever on an anchor a player there could hook: in reach when it bit, and in line of sight
			assert(s.rope.len <= Config.GRAPPLE_RANGE + 1e-6, "the rope is never longer than the reach")
		end
		planT += DT
		t += DT
		if done(s) then return t, roped end
	end
	return nil, roped
end

do -- with the anchors, a bot still reaches every deck of the Yard, and it swings on the way to some of them
	local map = Maps.get("yard")
	local slowest, where, swings = 0, "", 0
	for _, b in map.blocks do
		local name, x0, y0, x1, y1 = b[1], b[2], b[3], b[4], b[5]
		if y1 - y0 <= 1.01 and name ~= "Floor" then
			local tx, ty = (x0 + x1) / 2, y1 + HH
			for _, from in { { 30, HH }, { -150, 10 * T + HH } } do -- from the floor, and from the Dock's high ledge
				local s = Movement.new(from[1], from[2])
				local took, roped = drive(map, s, function(g, field, queue)
					return { mode = "seek", x = tx, y = ty, field = BoxWorld.field(g, tx, ty, field, queue) }
				end, 25, function(st)
					return math.abs(st.x - tx) <= Config.RUNNER_WIDTH + 1 and math.abs(st.y - ty) <= Config.RUNNER_HEIGHT + 1
				end, true)
				assert(took, ("with the grapple the bot never reached %s from (%g, %g)"):format(name, from[1], from[2]))
				if took > slowest then slowest, where = took, name end
				if roped > 0 then swings += 1 end
			end
		end
	end
	assert(swings >= 3, ("the bot swings on some routes (%d)"):format(swings))
	print(("    bots: with the grapple every Yard deck reached from two starts; slowest %s in %.1f s; %d routes used a rope"):format(
		where, slowest, swings))
end

do -- a bot never hooks an anchor it cannot see: under a solid roof with the anchor above it, no rope
	local world = { { -100, -8, 100, 0 }, { -100, 8, 100, 9 } } -- a floor and a roof 8 studs up
	local g = BoxWorld.grid({ { "Floor", -100, -8, 100, 0 }, { "Roof", -100, 8, 100, 9 } }, 40)
	local hooks = { anchors = { { x = 10, y = 16, id = 1 } }, world = world }
	local field, queue = {}, {}
	local s = Movement.new(0, HH)
	local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
	for _, p in BotBrain.PLANS do
		if p.hook then
			local st, m = table.clone(s), BotBrain.memory()
			local t = 0
			for _ = 1, 66 do
				BoxWorld.probe(world, st.x, st.y, c)
				BotBrain.input(p, m, st, c, t, input, hooks)
				Movement.step(st, input, c, DT)
				BoxWorld.move(world, st, DT)
				assert(st.rope == nil, "no rope through a roof")
				t += DT
			end
		end
	end
	-- the same anchor with no roof is hooked by a hook plan
	local open = { { -100, -8, 100, 0 } }
	local hooked = false
	for _, p in BotBrain.PLANS do
		if p.hook and p.dir == 1 then
			local st, m = table.clone(s), BotBrain.memory()
			local t = 0
			for _ = 1, 66 do
				BoxWorld.probe(open, st.x, st.y, c)
				BotBrain.input(p, m, st, c, t, input, { anchors = hooks.anchors, world = open })
				Movement.step(st, input, c, DT)
				BoxWorld.move(open, st, DT)
				if st.rope then hooked = true end
				t += DT
			end
		end
	end
	assert(hooked, "in the open the same anchor is hooked")
	local _ = g, field, queue
end

do -- hooks nil (a ghost, rule 37): no plan that grapples is ever picked, and the grapple is never pressed
	local map = Maps.get("yard")
	local world = BoxWorld.fromBlocks(map.blocks)
	local g = BoxWorld.grid(map.blocks, map.top)
	local field, queue = {}, {}
	local s = Movement.new(-100, 10 * T + HH)
	for _ = 1, 40 do
		local goal = { mode = "seek", x = 100, y = 10 * T + HH, field = BoxWorld.field(g, 100, 10 * T + HH, field, queue) }
		assert(not BotBrain.choose(world, g, s, goal, rand, nil).hook, "no hooks given: no hook plan")
	end
	local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
	for _, p in BotBrain.PLANS do
		BotBrain.input(p, BotBrain.memory(), s, c, 0, input, nil)
		assert(not input.grapplePressed and not input.grappleHeld and input.anchor == nil, "never pressed without hooks")
	end
end

do -- hazards: a crate in the way on an open floor is jumped (or a plan that misses it is picked); none: plain running
	local world = { { -400, -8, 400, 0 } }
	local g = BoxWorld.grid({ { "Floor", -400, -8, 400, 0 } }, 40)
	local field, queue = {}, {}
	local s = Movement.new(0, HH)
	local crate = { 14, 0, 17, 3 } -- a 3-stud crate on the floor, 14 studs ahead
	local into, clear = 0, 0
	for _ = 1, 40 do
		local goal = { mode = "seek", x = 200, y = HH, noDash = true, field = BoxWorld.field(g, 200, HH, field, queue) }
		goal.hazards = { crate }
		local p = BotBrain.choose(world, g, s, goal, rand, nil)
		-- replay the pick: does it touch the crate?
		local st, m = table.clone(s), BotBrain.memory()
		local c, input = {}, { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }
		local t, touched = 0, false
		for _ = 1, 66 do
			BoxWorld.probe(world, st.x, st.y, c)
			BotBrain.input(p, m, st, c, t, input, nil)
			Movement.step(st, input, c, DT)
			BoxWorld.move(world, st, DT)
			if st.x + 1 > crate[1] and st.x - 1 < crate[3] and st.y - HH < crate[4] then touched = true end
			t += DT
		end
		if touched then into += 1 else clear += 1 end
	end
	assert(into == 0, ("with the crate known, no pick runs into it (%d of 40 did)"):format(into))
	assert(clear == 40, "every pick clears it")
end

do -- luck: a sloppy bot's picks are worse on average than a sharp one's, by the plan's own rating
	local map = Maps.get("yard")
	local world = BoxWorld.fromBlocks(map.blocks)
	local g = BoxWorld.grid(map.blocks, map.top)
	local field, queue = {}, {}
	local s = Movement.new(30, HH)
	local function mean(noise)
		local sum, n = 0, 60
		for _ = 1, n do
			local goal = { mode = "seek", x = 0, y = 5 * T + HH, noise = noise, field = BoxWorld.field(g, 0, 5 * T + HH, field, queue) }
			local p = BotBrain.choose(world, g, s, goal, rand, nil)
			sum += BotBrain.rate(world, g, s, p, goal)
		end
		return sum / n
	end
	local sharp, sloppy = mean(0.6), mean(60)
	assert(sloppy < sharp - 0.5, ("a sloppy bot picks worse plans (sharp %.1f, sloppy %.1f)"):format(sharp, sloppy))
end

do -- names: player-like, the same for the same seat and seed, different between seats, different between servers
	local a, b, c = Session.botName(Session.botId(1), 77), Session.botName(Session.botId(2), 77), Session.botName(Session.botId(3), 77)
	assert(type(a) == "string" and #a >= 5 and #a <= 20, "a name of a sensible length: " .. tostring(a))
	assert(a ~= b and b ~= c and a ~= c, "no two seats share a name")
	assert(Session.botName(Session.botId(1), 77) == a, "the same seat and seed: the same name (every screen agrees)")
	local differ = 0
	for sd = 1, 50 do
		if Session.botName(Session.botId(1), sd) ~= a then differ += 1 end
		local x, y, z = Session.botName(Session.botId(1), sd), Session.botName(Session.botId(2), sd), Session.botName(Session.botId(3), sd)
		assert(x ~= y and y ~= z and x ~= z, "seats differ on every server")
		for _, name in { x, y, z } do
			assert(not string.find(string.lower(name), "bot"), "no name says bot: " .. name)
			assert(string.match(name, "^[%w ]+$"), "letters, digits and spaces only: " .. name)
			assert(string.find(name, " ", 1, true), "always a space: never a possible Roblox username (QA round 2): " .. name)
		end
	end
	assert(differ >= 40, "another server, other names")
end

print("    bots_human ok")
