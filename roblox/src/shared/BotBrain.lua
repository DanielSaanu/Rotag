--!strict
--!native
-- How a bot decides where to run (H31; DESIGN §3 rules 31-32, §6.7; docs/systems/bots.md). A bot is a runner the
-- SERVER moves with the same shared/Movement rules a player has, in shared/BoxWorld. It has no map of routes: every
-- BOT_THINK it tries each of a small set of PLANS (run, jump, double jump, turn back over a ledge, dash, kick up a
-- shaft) for HORIZON seconds in its head, through the real move rules, and takes the one that ends best: nearest its
-- goal along the flood-fill distance (BoxWorld.field) when it chases or fetches, farthest when it flees. So whatever
-- a player can do with run, jump, dash and the grapple, a bot finds, and it can never do what a player cannot.
-- Pure Luau; `rand` is injected. Tests: test/luau/bots.test.luau.
local Config = require(script.Parent.Config)
local Movement = require(script.Parent.Movement)
local BoxWorld = require(script.Parent.BoxWorld)
local Grapple = require(script.Parent.Grapple)

local BotBrain = {}

export type Plan = {
	dir: number,        -- the stick: -1, 0, 1
	jumpAt: number?,    -- seconds into the plan the jump is pressed (nil: no jump)
	double: boolean,    -- press again at the top of the jump
	flipAt: number?,    -- seconds in, the stick turns round (out past a ledge, then back over it)
	dash: boolean,      -- dash at the start
	climb: boolean,     -- kick off every wall in reach (a shaft)
	stopAt: number?,    -- seconds in, the stick is let go (a short step: the last few studs to a goal)
	goAt: number?,      -- seconds in, the stick is first pushed (rise beside a deck's end, then drift over it)
	hook: number?,      -- seconds the grapple is held from the start (rule 17: the anchor the aim assist would pick)
}
-- A plan's memory while it runs: what has been pressed, and the anchor last picked (the aim assist is sticky).
export type Memory = { jumped: boolean, jumpT: number, dashed: boolean, hooked: boolean, pick: number? }
-- What a bot needs to grapple as a player does: the map's anchors and the boxes a rope cannot pass through.
export type Hooks = { anchors: { Grapple.Anchor }, world: { BoxWorld.Box } }

local function plan(dir: number, jumpAt: number?, double: boolean?, flipAt: number?, dash: boolean?, climb: boolean?,
	stopAt: number?, goAt: number?, hook: number?): Plan
	return { dir = dir, jumpAt = jumpAt, double = double == true, flipAt = flipAt, dash = dash == true,
		climb = climb == true, stopAt = stopAt, goAt = goAt, hook = hook }
end

BotBrain.IDLE = plan(0)
BotBrain.PLANS = { BotBrain.IDLE } :: { Plan }
for _, dir in { -1, 1 } do
	for _, p in {
		plan(dir),                               -- run
		plan(dir, nil, false, nil, false, false, 0.07), -- a step ...
		plan(dir, nil, false, nil, false, false, 0.2),  -- ... and a longer one (the last studs to an orb or a runner)
		plan(dir, 0),                            -- jump
		plan(dir, 0, true),                      -- jump, double jump at the top
		plan(dir, 0.25, true),                   -- a late jump (off the end of a deck), double
		plan(dir, 0, true, 0.3),                 -- out, up and back: onto the deck overhead
		plan(dir, 0, true, 0.55),                -- the same, wider
		plan(dir, 0, true, nil, false, false, nil, 0.3),  -- straight up beside a deck's end, then over it
		plan(dir, 0, true, nil, false, false, nil, 0.55), -- the same, higher first
		plan(dir, nil, false, nil, true),        -- dash
		plan(dir, 0.1, true, nil, true),         -- dash into a jump (rule 16: the jump keeps the speed)
		plan(dir, 0, false, nil, false, true),   -- kick up a shaft
		plan(dir, nil, false, nil, false, false, nil, nil, 0.45), -- hook the anchor ahead, a short swing, let go
		plan(dir, nil, false, nil, false, false, nil, nil, 0.8),  -- ... a long swing
		plan(dir, 0, false, nil, false, false, nil, nil, 0.7),    -- jump, then hook (an anchor out of reach from the floor)
	} do table.insert(BotBrain.PLANS, p) end
end

BotBrain.HORIZON = 1.1 -- seconds a plan is tried for
BotBrain.STEP = 1 / 60 -- the rollout's step: the server frame's, so a plan plays out as it was tried (at 1 / 30 a jump
-- under a deck's lip landed in the head and missed on the floor: the bot hopped under the Hub for 3 s)
local REACH = Movement.wallReach()
local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local NEAR = 2 * Config.STUDS_PER_TILE -- studs of flood-fill way inside which the straight line to the goal is used

function BotBrain.memory(): Memory
	return { jumped = false, jumpT = 0, dashed = false, hooked = false, pick = nil }
end

-- What a bot's "screen" shows: the aim assist never picks an anchor a player at that spot could not see (rule 17).
local view: Grapple.View = { x = 0, y = 0, halfW = Config.CAMERA_VIEW_HEIGHT / 2 * 16 / 9,
	halfH = Config.CAMERA_VIEW_HEIGHT / 2 }

-- The plan's buttons at `t` seconds in, written into `input` (reused). `s` and `c` are the runner now. `hooks`: the
-- anchors, for a plan that grapples (nil: the grapple is never pressed).
function BotBrain.input(p: Plan, m: Memory, s: Movement.State, c: Movement.Contacts, t: number, input: Movement.Input,
	hooks: Hooks?)
	local hook = p.hook
	if hook and hooks and t < hook then
		-- Held from the start, as a player holds it: pressed once, and armed in the air until an anchor comes in reach.
		input.grappleHeld, input.grapplePressed = true, not m.hooked
		m.hooked = true
		if s.rope then
			input.anchor = nil
		else
			view.x, view.y = s.x, s.y + Config.CAMERA_Y_OFFSET
			local world = hooks.world
			local a = Grapple.pick(s.x, s.y, s.facing, hooks.anchors, view, m.pick, function(an)
				return BoxWorld.clear(world, s.x, s.y, an.x, an.y)
			end, s.vx)
			m.pick = if a then a.id else nil
			input.anchor = a
		end
	else
		input.grappleHeld, input.grapplePressed, input.anchor = false, false, nil
	end
	local flip = p.flipAt
	local stop, go = p.stopAt, p.goAt
	input.moveX = if (stop and t >= stop) or (go and t < go) then 0 elseif flip and t >= flip then -p.dir else p.dir
	local press = false
	local jumpAt = p.jumpAt
	if jumpAt and not m.jumped and t >= jumpAt then
		press, m.jumped, m.jumpT = true, true, t
	elseif p.double and m.jumped and not s.grounded and s.airJumps > 0 and s.vy <= 2 and t >= m.jumpT + 0.12 then
		press = true
	elseif p.climb and m.jumped and not s.grounded and s.vy < 25 then
		local wl, wr = c.wallLeft, c.wallRight
		press = (wl ~= nil and wl <= REACH) or (wr ~= nil and wr <= REACH)
	end
	input.jumpPressed = press
	input.jumpHeld = s.vy > 0 or press -- always the full jump
	input.dashPressed = p.dash and not m.dashed
	if p.dash then m.dashed = true end
end

export type Goal = {
	mode: string,            -- "seek": get near the field's source; "flee": get away from it
	field: { number },       -- BoxWorld.field from the goal (seek) or from the chaser (flee)
	x: number, y: number,    -- that source point: the last tile is closed on the straight line (the field is in tiles)
	safe: number?,           -- flee: studs of way beyond which further is no better (stops a bot hugging an end wall)
	lo: number?, hi: number?, -- the closing walls' room, world x: ending outside is the worst plan
	speedMult: number?,
	noDash: boolean?,        -- this think, no plan with a dash is tried (a bot that dashed at every chance averaged
	                         -- 70 studs/s in Studio, a run is 45: nobody could catch or escape it)
	hooks: Hooks?,           -- the anchors: plans that grapple are tried (nil: none; a ghost never grapples, rule 37)
	hazards: { BoxWorld.Box }?, -- crates and traps in the world: a plan that runs into one loses HAZARD
	noise: number?,          -- how much luck is added to each plan's score (default NOISE): a sloppier bot, worse picks
}
local NOISE = 0.6
local EFFORT = 2 -- what a jump must be worth: about half a tile of way
local HAZARD = 25 -- about six tiles of way: a bot goes over or round a crate unless that costs more than this

local scratch: Movement.Contacts = {}
local rolloutInput: Movement.Input = { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false }

-- How good plan `p` is from state `s` (higher is better): play it for HORIZON in a copy of `s`.
function BotBrain.rate(world: { BoxWorld.Box }, g: BoxWorld.Grid, s: Movement.State, p: Plan, goal: Goal): number
	local sim = table.clone(s) :: any -- (any: the analyzer cannot follow Movement's type through the clone, → T15)
	local rope = s.rope
	if rope then sim.rope = table.clone(rope :: any) end -- a swing in progress is tried on its own copy of the rope
	local m = BotBrain.memory()
	m.hooked = s.rope ~= nil -- already on a rope: a hook plan keeps holding, it does not press again
	local hooks, hazards = goal.hooks, goal.hazards
	local hit = false
	local dt = BotBrain.STEP
	local field = goal.field
	local seek = goal.mode ~= "flee"
	local gx, gy = goal.x, goal.y
	local nearest, touch, touchT, t = math.huge, math.huge, 0, 0
	local lo, hi = goal.lo, goal.hi
	local out = 0 -- steps spent outside the closing walls' room
	rolloutInput.speedMult = goal.speedMult
	rolloutInput.hold, rolloutInput.launchX, rolloutInput.launchY = nil, nil, nil
	for _ = 1, math.floor(BotBrain.HORIZON / dt + 0.5) do
		BoxWorld.probe(world, sim.x, sim.y, scratch)
		BotBrain.input(p, m, sim, scratch, t, rolloutInput, hooks)
		Movement.step(sim, rolloutInput, scratch, dt)
		BoxWorld.move(world, sim, dt)
		t += dt
		if hazards and not hit then
			for _, h in hazards do
				if sim.x + HW > h[1] and sim.x - HW < h[3] and sim.y + HH > h[2] and sim.y - HH < h[4] then hit = true end
			end
		end
		local d = BoxWorld.far(g, field, sim.x, sim.y)
		if d < nearest then nearest = d end
		if lo and hi and (sim.x < lo or sim.x > hi) then out += 1 end
		if seek and d <= NEAR then -- inside the last tiles the straight line decides (the field is in whole tiles)
			local e = math.sqrt((sim.x - gx) ^ 2 + (sim.y - gy) ^ 2)
			if e < touch - 0.5 then touch, touchT = e, t end
		end
	end
	local final = BoxWorld.far(g, field, sim.x, sim.y)
	local score
	if seek then
		-- The closest the plan comes is what counts (a tag or an orb is a touch, not a stop), then how soon, and only
		-- a little where it ends: a chaser runs THROUGH its goal. (Rating the end alone made a bot stall under a
		-- platform on purpose, to arrive exactly: seen in the test.)
		score = -(0.85 * nearest + 0.15 * final) - math.min(touch, NEAR) - 4 * touchT
	else
		local safe = goal.safe or math.huge
		score = math.min(final, safe) + 0.5 * math.min(nearest, safe) -- far at the end, and never close on the way
		if sim.grounded then score += 2 end -- end on your feet: the next plan has every move
	end
	-- The closing walls: ending outside is the worst plan, and every step outside on the way costs (in Studio a bot
	-- that only minded where it ENDED stepped out and back a dozen times in one end phase).
	if lo and hi and (sim.x < lo + 2 or sim.x > hi - 2) then score -= 1000 end
	-- A jump costs a little: a ground jump adds speed (JUMP_H_BOOST), so on open floor a jump always rated a hair
	-- above a run and a bot hopped 1.5 times a second in Studio. People run when running will do.
	return score - 4 * out - (if hit then HAZARD else 0) - (if p.jumpAt then EFFORT else 0)
end

-- The best plan from `s` toward `goal`. `rand` in [0, 1): a little noise so two bots (and two tries) differ, and
-- `keep` (the plan in hand) gets a small bonus so a bot does not dither between two equal ways.
function BotBrain.choose(world: { BoxWorld.Box }, g: BoxWorld.Grid, s: Movement.State, goal: Goal, rand: () -> number,
	keep: Plan?): Plan
	local best, bestScore = BotBrain.IDLE, -math.huge
	for _, p in BotBrain.PLANS do
		if (p.dash and goal.noDash) or (p.hook and not goal.hooks) then continue end
		local score = BotBrain.rate(world, g, s, p, goal) + rand() * (goal.noise or NOISE) + (if p == keep then 0.3 else 0)
		if score > bestScore then best, bestScore = p, score end
	end
	return best
end

return BotBrain
