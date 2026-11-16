-- What a bot WANTS (H31, docs/systems/bots.md §3): its goal this moment and whether to use the item it holds.
-- shared/BotBrain turns the goal into buttons; server/Bots runs the body. Rules of thumb, not a plan:
--   "it":      chase the nearest living runner (sticky, so two runners cannot ping-pong it)
--   a runner:  flee while "it" is within FLEE; else fetch a living orb if the slot is empty; else wander
--   a ghost:   fetch a ghost orb; a hex goes to the holder; anything else goes to the nearest living runner
--   outside the closing walls: back in first
-- Items follow the pools' intent (rule 43): a runner drops a crate or a trap in the chaser's path, the holder and the
-- ghosts aim the ice beam at whoever is in front.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local OrbRules = require(Shared:WaitForChild("Orbs"))
local ItemRules = require(Shared:WaitForChild("Items"))
local Walls = require(script.Parent:WaitForChild("Walls"))

local BotMind = {}

local T = Config.STUDS_PER_TILE
local HH = Config.RUNNER_HEIGHT / 2
local FLEE = 16 * T -- "it" nearer than this: run (a screen is ~21 tiles wide: it is on screen)
local SAFE = 30 * T -- fleeing further than this is no better (stops a bot living in an end shaft)
local STICKY = 0.7 -- a chaser changes target only for one this much nearer
local ROAM = { 3, 6 } -- seconds a wander goal is kept
local PLACE_TRY = 0.6 -- seconds between a ghost bot's tries at placing a part
local AIM_Y = 2.5 -- studs: the ice beam is 2 tall; fire when the target is about level

local stands: { { number } } = {} -- places to wander to: the middle of every deck and stretches of floor

function BotMind.start(map: any)
	stands = {}
	for _, b in map.blocks do
		local x0, y0, x1, y1 = b[2], b[3], b[4], b[5]
		if y1 - y0 <= 1.01 then
			table.insert(stands, { (x0 + x1) / 2, y1 + HH })
		elseif b[1] == "Floor" then
			for k = 1, 6 do table.insert(stands, { x0 + (x1 - x0) * (k / 7), y1 + HH }) end
		end
	end
end

-- A bot is its own player (H32, bots.md §7): `skill` 0..1 sets how fast it runs and thinks, how often it dashes and
-- swings, how sloppy its picks are and how long a change of holder takes to sink in. Rolled once per bot.
function BotMind.new(): any
	local skill = math.random()
	return { target = nil, roamX = 0, roamY = HH, roamUntil = 0, triedAt = -math.huge, skill = skill,
		speed = Config.BOT_SPEED + (skill - 0.5) * 0.1, -- 0.88 .. 0.98 x the run at BOT_SPEED 0.93
		think = Config.BOT_THINK * (1.4 - 0.8 * skill), -- 0.42 s .. 0.18 s between plans
		dash = 0.12 + 0.3 * skill, hook = 0.2 + 0.5 * skill, -- the share of its plans that may dash, may swing
		noise = 9 - 8.4 * skill, -- luck added to each plan's score: 9 (two tiles of misjudgement) .. 0.6
		react = 0.6 - 0.35 * skill, -- seconds before a new holder changes what it is doing
		hold = -1, reactAt = 0, restUntil = 0, last = nil }
end

local function last(history: { [number]: { Tag.Sample } }, id: number): Tag.Sample?
	local h = history[id]
	return h and h[#h]
end

local function dist(s: any, p: Tag.Sample): number
	return math.sqrt((s.x - p.x) ^ 2 + (s.y - p.y) ^ 2)
end

-- The nearest living runner to `s` other than `id` (and, with `notIt`, other than the holder): its id and sample.
local function nearest(r: Tag.Round, id: number, s: any, history: { [number]: { Tag.Sample } }, notIt: boolean?)
	: (number?, Tag.Sample?, number)
	local best, bestP, bestD = nil, nil, math.huge
	for _, other in r.order do
		if other ~= id and r.alive[other] and not (notIt and other == r.it) then
			local p = last(history, other)
			if p then
				local d = dist(s, p)
				if d < bestD then best, bestP, bestD = other, p, d end
			end
		end
	end
	return best, bestP, bestD
end

local function nearestOrb(o: OrbRules.State, kind: string, s: any): (number?, number?)
	local bx, by, bd = nil, nil, math.huge
	for i, spot in o.spots do
		if spot.kind == kind then
			local d = math.abs(spot.x - s.x) + math.abs(spot.y - s.y) + (if o.up[i] then 0 else 1e4)
			if d < bd then bx, by, bd = spot.x, spot.y, d end
		end
	end
	if bd >= 1e4 then return nil, nil end -- none is up: do something else meanwhile
	return bx, by
end

local function roam(m: any, s: any, now: number): (string?, number?, number?, number?)
	if #stands == 0 or now < m.restUntil then return nil end
	if now >= m.roamUntil or (math.abs(s.x - m.roamX) < 6 and math.abs(s.y - m.roamY) < 6) then
		local spot = stands[math.random(1, #stands)]
		m.roamX, m.roamY = spot[1], spot[2]
		m.roamUntil = now + ROAM[1] + (ROAM[2] - ROAM[1]) * math.random()
		if math.random() < 0.4 then -- H32: nobody runs without a breath: stand a moment before the next place
			m.restUntil = now + 0.3 + 1.2 * math.random()
			return nil
		end
	end
	return "seek", m.roamX, m.roamY, nil
end

-- The goal: mode ("seek" | "flee"), the point, and for a flee the distance that is far enough. nil: stand still.
local function want(m: any, id: number, s: any, r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } },
	o: OrbRules.State?): (string?, number?, number?, number?)
	if not (r and not r.over and r.alive[id] ~= nil) then return roam(m, s, now) end -- the lobby, a gap, sitting out
	local back = Walls.backIn(id)
	if back then return "seek", back, s.y, nil end
	if r.alive[id] then
		if r.it == id then
			if Tag.frozen(r, now) then return nil end
			local cand, p, d = nearest(r, id, s, history)
			local held = m.target and r.alive[m.target] and last(history, m.target)
			if held and cand ~= m.target and d > dist(s, held) * STICKY then p = held else m.target = cand end
			if p then return "seek", p.x, p.y, nil end
			return nil
		end
		local it = r.it and last(history, r.it)
		if it and dist(s, it) < FLEE then return "flee", it.x, it.y, SAFE end
		if o and o.held[id] == nil then
			local ox, oy = nearestOrb(o, "living", s)
			if ox then return "seek", ox, oy, nil end
		end
		return roam(m, s, now)
	end
	-- a ghost (rules 37-41)
	local item = o and o.held[id]
	if o and item == nil then
		local ox, oy = nearestOrb(o, "ghost", s)
		if ox then return "seek", ox, oy, nil end
		return roam(m, s, now)
	end
	local it = r.it and last(history, r.it)
	if item == "hex" and it then return "seek", it.x, it.y, nil end
	local _, p = nearest(r, id, s, history, item == "grant") -- the grant is a gift: give it to a runner, not the chaser
	if p then return "seek", p.x, p.y, nil end
	return roam(m, s, now)
end

-- H32: the fuse changing hands takes a moment to sink in, as it does for a person: for `react` seconds after it the
-- bot carries on with what it was doing (a runner does not turn on the frame "it" changes; a new "it" was frozen
-- anyway). Otherwise the goal is what it wants now.
function BotMind.goal(m: any, id: number, s: any, r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } },
	o: OrbRules.State?): (string?, number?, number?, number?)
	local hold = if r and not r.over then r.hold else -1
	if hold ~= m.hold then
		m.hold = hold
		if hold >= 0 then m.reactAt = now + m.react end
	end
	local last = m.last
	if now < m.reactAt and last then return last[1], last[2], last[3], last[4] end
	local mode, x, y, safe = want(m, id, s, r, now, history, o)
	m.last = if mode then { mode, x, y, safe } else nil
	return mode, x, y, safe
end

-- Should the bot use `item` now? Returns use, the facing to aim it (nil: as it faces), and a fixture's rotation.
function BotMind.use(m: any, id: number, s: any, item: string, r: Tag.Round, now: number,
	history: { [number]: { Tag.Sample } }): (boolean, number?, number?)
	if item == "hex" or item == "grant" then return false, nil, nil end -- by touch (Bots.hexes, Items.grants)
	local ghost = r.alive[id] == false
	if ItemRules.PLACED[item] then -- a fixture or a pad: near the action, tried now and then (a refusal costs nothing)
		if now - m.triedAt < PLACE_TRY then return false, nil, nil end
		local _, _, d = nearest(r, id, s, history)
		if d > 14 * T then return false, nil, nil end
		m.triedAt = now
		return true, nil, math.random(0, 3)
	end
	if item == "ice" then -- aimed: whoever is in front, about level, in the beam's reach (rule 43: the holder's tool)
		local _, p, _ = nearest(r, id, s, history, ghost == false and r.it ~= id)
		if r.it ~= id and not ghost then p = r.it and last(history, r.it) end -- a runner freezes the chaser
		if p and math.abs(p.x - s.x) <= Config.ICE_LENGTH and math.abs(p.x - s.x) > 3 and math.abs(p.y - s.y) <= AIM_Y then
			return true, if p.x >= s.x then 1 else -1, nil
		end
		return false, nil, nil
	end
	-- a crate (dropped behind you) or a trap (at your feet): in the path of whoever is coming
	local p
	if ghost then
		local _, q = nearest(r, id, s, history)
		p = q
	elseif r.it ~= id then
		p = r.it and last(history, r.it)
	end
	if p and math.abs(p.x - s.x) <= 7 * T and math.abs(p.x - s.x) >= 5 and math.abs(p.y - s.y) <= 5 and s.grounded then
		return true, if p.x >= s.x then -1 else 1, nil -- face away: a crate lands between us
	end
	if r.it == id and now - m.triedAt > 6 then -- the holder rolled a crate or trap it has no use for: drop it, free the slot
		m.triedAt = now
		return s.grounded, nil, nil
	end
	return false, nil, nil
end

return BotMind
