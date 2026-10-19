--!strict
-- Orbs (DESIGN §3 rules 39, 42; H18, docs/systems/ghosts.md §1). Pure Luau over plain tables: every clock comes in as
-- `now` and every roll's random source as `rand` (a function returning [0, 1)), so the tests are deterministic. The
-- SERVER owns the one State per round and is the only caller that changes it; clients draw what ItemEvent says.
-- An orb sits at a fixed spot; its kind says who may take it: "ghost" orbs are for ghosts only (rule 39). Touch one
-- that is up with an empty slot and the server rolls the pool of the orb's kind into your slot. One slot per runner.
-- "living" orbs are for the living (H19); the pools (runner, holder, ghost) are shared/Items.POOLS.
local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

local Orbs = {}

export type Spot = { x: number, y: number, kind: string }
export type State = {
	spots: { Spot },
	takenAt: { [number]: number }, -- per spot index: when it was last taken this round (absent: not yet)
	up: { [number]: boolean },     -- per spot index: up as last reported by Orbs.step (a change is an event)
	firstAt: number,               -- no orb is up before this: round start + ORB_FIRST
	held: { [number]: string },    -- per runner id: the one item in its slot
}
-- One runner as the server last recorded it: (x, y) now, (px, py) the sample before, if any (the path counts).
export type Taker = { id: number, x: number, y: number, px: number?, py: number?, ghost: boolean,
	holder: boolean? }
-- What changed: an orb came back (up = true), or `by` took it and rolled `item` (up = false).
export type Event = { spot: number, up: boolean, by: number?, item: string? }

function Orbs.new(spots: { Spot }, now: number): State
	return { spots = spots, takenAt = {}, up = {}, firstAt = now + Config.ORB_FIRST, held = {} }
end

-- Rule 42: a living orb is back after ORB_RESPAWN; a ghost orb sooner the more ghosts there are, 10 / (1 + 0.5 x n).
function Orbs.respawnTime(kind: string, ghosts: number): number
	if kind == "ghost" then return Config.ORB_RESPAWN / (1 + Config.GHOST_ORB_RAMP * ghosts) end
	return Config.ORB_RESPAWN
end

-- Up at `now`, with `ghosts` ghosts in the round NOW: the respawn is recomputed every frame, so a new ghost brings a
-- waiting ghost orb back sooner. An orb whose kind has no pool yet is never up (nobody could take it).
function Orbs.isUp(o: State, i: number, now: number, ghosts: number): boolean
	if now < o.firstAt or Items.poolFor(o.spots[i].kind) == nil then return false end
	local t = o.takenAt[i]
	return t == nil or now >= t + Orbs.respawnTime(o.spots[i].kind, ghosts)
end

-- Does a runner box moving from (px, py) to (x, y) touch the orb's square on the way? The whole path between two of
-- the server's samples counts, so a dash (4 studs a snapshot) cannot skip over an orb (Items.swept, → N14).
function Orbs.touches(spot: Spot, x: number, y: number, px: number?, py: number?): boolean
	return Items.swept(spot.x, spot.y, Config.RUNNER_WIDTH / 2 + Config.ORB_SIZE / 2,
		Config.RUNNER_HEIGHT / 2 + Config.ORB_SIZE / 2, x, y, px, py)
end

-- A weighted pick from a pool with an injected random source (rand() in [0, 1)).
function Orbs.roll(pool: { { any } }, rand: () -> number): string
	local total = 0
	for _, row in pool do total += row[2] end
	local r = rand() * total
	for _, row in pool do
		r -= row[2]
		if r < 0 then return row[1] end
	end
	return pool[#pool][1]
end

-- May this taker take orb i now? Up (so its kind has a pool), its kind (a ghost orb only for a ghost), an empty slot.
function Orbs.canTake(o: State, i: number, who: Taker, now: number, ghosts: number): boolean
	if o.held[who.id] ~= nil or (o.spots[i].kind == "ghost") ~= who.ghost then return false end
	return Orbs.isUp(o, i, now, ghosts)
end

-- One server frame: every orb that came back, then the first taker in `takers` order (the server passes join order)
-- touching it takes it. Returns what changed, in spot order, for ItemEvent.
function Orbs.step(o: State, now: number, ghosts: number, takers: { Taker }, rand: () -> number): { Event }
	local events: { Event } = {}
	for i, spot in o.spots do
		local up = Orbs.isUp(o, i, now, ghosts)
		if up then
			for _, who in takers do
				if Orbs.canTake(o, i, who, now, ghosts) and Orbs.touches(spot, who.x, who.y, who.px, who.py) then
					local item = Orbs.roll(Items.poolFor(spot.kind, who.holder) :: { { any } }, rand) -- rules 39, 43
					o.takenAt[i], o.held[who.id], up = now, item, false
					table.insert(events, { spot = i, up = false, by = who.id, item = item })
					break
				end
			end
		end
		if up and not o.up[i] then table.insert(events, { spot = i, up = true }) end
		o.up[i] = up
	end
	return events
end

-- Empty a runner's slot (an item used, or the runner left). Returns what was in it.
function Orbs.use(o: State, id: number): string?
	local item = o.held[id]
	o.held[id] = nil
	return item
end

return Orbs
