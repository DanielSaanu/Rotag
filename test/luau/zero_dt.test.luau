-- H43 (docs/systems/bots.md §8): a server frame of zero length. Roblox's Heartbeat can hand a frame dt == 0 (measured
-- in Studio: 9 of 6994 server frames in 30 s). A bot on a taut rope that got one went NaN for good: Grapple.swing
-- set the velocity to (chord / dt) = 0 / 0, Grapple.stopped carried it into the rope's w, Roblox stored the NaN body
-- at (0, -1e6, 0) and BotMind's way-back-in goal (w.x, s.y) handed the NaN y to BoxWorld.field, which threw every frame
-- and stopped Match.step before the judge, the fuse and the walls. A zero (or tiny) step must leave every number finite.
local Config = __require("Config")
local Movement = __require("Movement")
local BoxWorld = __require("BoxWorld")

local function finite(v) return v == v and v > -math.huge and v < math.huge end
local function allFinite(s)
	for k, v in s do
		if type(v) == "number" and not finite(v) then return false, k end
	end
	if s.rope then
		for k, v in s.rope do
			if type(v) == "number" and not finite(v) then return false, "rope." .. k end
		end
	end
	return true, nil
end
local function input(t)
	return { moveX = t.moveX or 0, jumpPressed = false, jumpHeld = t.jumpHeld or false, dashPressed = false,
		grappleHeld = t.hook or false, grapplePressed = false, speedMult = 0.952, hold = t.hold, holdLeft = t.holdLeft,
		holdDir = t.holdDir }
end

do -- the frame Studio caught (Bots' H43 log, 2026-11-22): Ninja King mid-swing on anchor 7, then a dt of 0
	local s = Movement.new(104.8, 36.63)
	s.vx, s.vy, s.grounded, s.holdSpeed = 47.87, 1.923, false, 52.5
	s.rope = { x = 104, y = 52, id = 7, len = 15.39, target = 15.39, rest = 15.39, give = -0.07893, w = 3.121 }
	local world = { { -200, -8, 200, 0 } }
	local c = {}
	BoxWorld.probe(world, s.x, s.y, c)
	Movement.step(s, input({ moveX = 1, jumpHeld = true, hook = true }), c, 0)
	BoxWorld.move(world, s, 0)
	local ok, k = allFinite(s)
	assert(ok, ("a zero-length step on a taut rope leaves %s non-finite"):format(tostring(k)))
	assert(s.rope ~= nil, "a zero-length step does not let go")
	for _ = 1, 30 do -- and the swing carries on as normal afterwards
		BoxWorld.probe(world, s.x, s.y, c)
		Movement.step(s, input({ moveX = 1, jumpHeld = true, hook = true }), c, 1 / 60)
		BoxWorld.move(world, s, 1 / 60)
	end
	ok, k = allFinite(s)
	assert(ok, ("after a zero step the swing goes non-finite in %s"):format(tostring(k)))
end

do -- every other kind of step: the run, the air, a dash, a pad's glide, each hold, a slack rope; dt 0 and dt 1e-9
	local world = { { -200, -8, 200, 0 } }
	local cases = {
		function() return Movement.new(0, Config.RUNNER_HEIGHT / 2), input({ moveX = 1 }) end,
		function() local s = Movement.new(0, 20) s.vy = -10 return s, input({ moveX = -1, jumpHeld = true }) end,
		function() local s = Movement.new(0, 20) s.dashTime, s.dashDir = 0.1, 1 return s, input({}) end,
		function() local s = Movement.new(0, 20) s.padGlide, s.padDir, s.padPeak = 0.3, 1, 90 return s, input({ moveX = 1 }) end,
		function() local s = Movement.new(0, 20) s.vx = 30 return s, input({ hold = "freeze", holdLeft = 0 }) end,
		function() local s = Movement.new(0, 20) return s, input({ hold = "stumble", holdDir = 1, holdLeft = 0.5 }) end,
		function() local s = Movement.new(0, 20) return s, input({ hold = "trap", holdLeft = 0.5 }) end,
		function()
			local s = Movement.new(0, 20)
			s.vx = 20
			s.rope = { x = 0, y = 40, id = 1, len = 25, target = 20 } -- slack: inside its length, no w yet
			return s, input({ hook = true })
		end,
	}
	for i, make in cases do
		for _, dt in { 0, 1e-9 } do
			local s, inp = make()
			local c = {}
			BoxWorld.probe(world, s.x, s.y, c)
			Movement.step(s, inp, c, dt)
			BoxWorld.move(world, s, dt)
			local ok, k = allFinite(s)
			assert(ok, ("case %d, dt %g: %s went non-finite"):format(i, dt, tostring(k)))
		end
	end
end

print("    zero dt: a taut swing, the run, the air, a dash, a glide, every hold and a slack rope stay finite at dt 0")
