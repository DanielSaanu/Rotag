--!include movement_world.luau
-- The grapple against the server's speed check (H25, docs/systems/trust.md §11, grapple.md §4). A swing is the
-- client's own move: the server never trusts "I am on an anchor". Instead the swing is capped at
-- GRAPPLE_MAX_SPEED (= DASH_SPEED as tried) and its fast stretches must fit the budgets as they are. Driven here
-- with a real Movement runner in the box world (Q3), the hardest an honest player can push it. Split from
-- move_check.test.luau, which is past ~400 lines.
local MoveCheck = __require("MoveCheck")
local Grapple = __require("Grapple")

local CAP_X = MoveCheck.RATE_X * Config.MOVE_BURST_TIME
local CAP_U = MoveCheck.RATE_UP * Config.MOVE_BURST_TIME
local CAP_D = MoveCheck.RATE_DOWN * Config.MOVE_BURST_TIME

do -- the rates (trust.md §2, §11): x is the larger of the dash and the swing's cap; up and down are unchanged
	assert(MoveCheck.RATE_X == math.max(Config.DASH_SPEED, Config.GRAPPLE_MAX_SPEED), "x: dash or swing cap")
	assert(Config.GRAPPLE_MAX_SPEED <= Config.DASH_SPEED, "as tried, the swing is no faster than a dash (no new rate)")
	assert(MoveCheck.RATE_UP == Config.JUMP_SPEED and MoveCheck.RATE_DOWN == Config.MAX_FALL, "up and down unchanged")
end

-- A long floor with a row of anchors `gap` apart at height `h`, and a view that follows the runner.
local function course(h, gap)
	local anchors = {}
	for i = 0, 60 do table.insert(anchors, { x = i * gap, y = h, id = i % 255 + 1 }) end
	return { { -100, -10, 4000, 0 } }, anchors
end

-- Watch a driven run: one sample per frame into MoveCheck; returns the violations and the deepest use of each budget.
local function watch(world, s, n, choose)
	local c = MoveCheck.new(s.x, s.y, 0)
	local bad, use, fastest, hooks = {}, { x = 0, up = 0, down = 0, fastX = 0, swing = 0 }, 0, 0
	for i = 1, n do
		local ev = tick(world, s, choose(i, s))
		if ev.grapple == "attach" then hooks += 1 end
		fastest = math.max(fastest, math.sqrt(s.vx * s.vx + s.vy * s.vy))
		use.fastX = math.max(use.fastX, math.abs(s.vx))
		if s.rope and s.rope.w then use.swing = math.max(use.swing, math.abs(s.rope.w * s.rope.len)) end
		local ok, axis, over = MoveCheck.step(c, s.x, s.y, i * DT)
		if not ok then table.insert(bad, ("frame %d: %s over by %.2f"):format(i, tostring(axis), over or 0)) end
		use.x, use.up, use.down = math.max(use.x, CAP_X - c.bx), math.max(use.up, CAP_U - c.bu), math.max(use.down, CAP_D - c.bd)
	end
	return bad, use, fastest, hooks
end

-- The hardest honest swing chain: dash into every hook, pump with the swing the whole way, let go once past the low
-- point on the way up (`releaseAt` radians forward of straight down), dash the moment the cooldown allows, double jump
-- off the release, hook the next anchor ahead as soon as one is picked.
local function swinger(anchors, releaseAt, jumpOff)
	local prev = nil
	return function(_, s)
		local i = input({ moveX = 1, held = true })
		if s.rope then
			local r = s.rope
			local a = math.atan2(s.x - r.x, r.y - s.y)
			-- let go past `releaseAt` on the way up, or at the swing's peak if it never gets that far
			i.grappleHeld = not ((a > releaseAt and s.vx > 0) or (a > 0.1 and s.vx < 5))
			i.jumpPressed = jumpOff and not i.grappleHeld
		else
			local view = { x = s.x + 10, y = s.y + 4, halfW = 42, halfH = 24 }
			local a = Grapple.pick(s.x, s.y, s.facing, anchors, view, prev)
			prev = a and a.id
			i.anchor, i.grappleHeld, i.grapplePressed = a, true, a ~= nil
			i.dashPressed = s.dashes > 0 and s.dashCooldown <= 0
			i.jumpPressed = s.grounded or (s.airJumps > 0 and s.vy < 0)
		end
		return i
	end
end

local cases = {
	{ "longest rope, highest anchors, release low", 31, 40, 0.15, false },
	{ "longest rope, release high", 31, 40, 0.9, false },
	{ "jump off the rope", 31, 40, 0.5, true },
	{ "short ropes, close anchors", 14, 22, 0.4, false },
	{ "mid ropes", 22, 30, 0.6, true },
}
local worst = { x = 0, up = 0, down = 0, fastX = 0, swing = 0 }
for _, case in cases do
	local world, anchors = course(case[2], case[3])
	local s = standing(world, -30)
	local bad, use, fastest, hooks = watch(world, s, 600, swinger(anchors, case[4], case[5]))
	print(("    swing chain (%s), 10 s: %d hooks, %.0f studs; fastest swing %.1f, across %.1f, overall %.1f studs/s; budget used x %.2f of %.0f, up %.2f of %.1f, down %.2f of %.0f")
		:format(case[1], hooks, s.x + 30, use.swing, use.fastX, fastest, use.x, CAP_X, use.up, CAP_U, use.down, CAP_D))
	for k in worst do worst[k] = math.max(worst[k], use[k]) end
	assert(hooks >= 5, case[1] .. ": the driver really swings (" .. hooks .. " hooks)")
	assert(#bad == 0, case[1] .. ": an honest swing chain is never flagged: " .. (bad[1] or ""))
	assert(fastest <= Config.GRAPPLE_MAX_SPEED * Config.GRAPPLE_RELEASE_BOOST + Config.JUMP_SPEED + 1e-6,
		case[1] .. ": nothing passes the boosted cap (with a jump's lift), got " .. fastest)
end

-- Pinned as MEASUREMENTS (→ S11, 2026-11-01): the worst of the five chains. A tuning change shows here as a diff.
assert(math.abs(worst.swing - Config.GRAPPLE_MAX_SPEED) < 1e-6, ("the fastest swing reaches the cap: %.2f"):format(worst.swing))
assert(worst.x > 1.2 and worst.x < 1.6, ("x budget used at most (measurement): %.2f of %.0f"):format(worst.x, CAP_X))
-- (QA round 1: 2.41 -> 2.96 once a held W hooks the moment an anchor is in reach; the chains hook earlier and higher.)
assert(worst.up > 2.7 and worst.up < 3.2, ("up budget used at most (measurement): %.2f of %.1f"):format(worst.up, CAP_U))
assert(worst.down > 2.0 and worst.down < 2.5, ("down budget used at most (measurement): %.2f of %.0f"):format(worst.down, CAP_D)) -- 2.67 -> 2.21 (QA r1)

do -- a cheat that claims a swing it is not on gains nothing: no rate is granted by the rope (the server never sees it)
	local c = MoveCheck.new(0, 0, 0)
	local x, caught = 0, nil
	for i = 1, 120 do
		x += Config.GRAPPLE_MAX_SPEED * 1.25 * DT -- a "swing" held at 150 across, forever
		if not MoveCheck.step(c, x, 0, i * DT) and not caught then caught = i end
	end
	assert(caught and caught < 60, "a steady 150 across is caught inside a second, rope or no rope")
end

print("move_check grapple ok")
