--!strict
-- Items and holds (DESIGN §3 rules 41-45; H19, docs/systems/items.md). Pure Luau over plain tables, every clock passed
-- in as `now`, like shared/Tag and Orbs. The SERVER owns the one State per round and is the only caller that changes
-- it; a victim's client applies the hold it is told about (client/Use) and the server's speed check holds it to it
-- (shared/MoveCheck.hold). The pools (moved here from Orbs, H18), what Use puts in the world, the holds (stumble,
-- freeze, trap), no chains, cast-before-hold, dash i-frames and the per-target ghost ward. Tests: items.test.luau.
local Config = require(script.Parent.Config)

local Items = {}

-- The pools, { item, weight } rows (rules 39, 43, 10; ghosts-v2-proposal.md §3). Runners roll escape items, the holder
-- the ice beam first. The ghost pool has PR 2's share: fixture, boost pad and boost grant (PR 4) join it later, at
-- which point the hex is 8 in 100; until then it is 8 in 40.
Items.POOLS = {
	runner = { { "crate", 40 }, { "trap", 35 }, { "ice", 25 } },
	holder = { { "ice", 50 }, { "crate", 25 }, { "trap", 25 } },
	ghost = { { "crate", 12 }, { "trap", 10 }, { "ice", 10 }, { "hex", 8 } },
} :: { [string]: { { any } } }

-- The pool an orb of `kind` rolls for this taker; nil for a kind with no pool (Orbs never puts such an orb up).
function Items.poolFor(kind: string, holder: boolean?): { { any } }?
	if kind == "ghost" then return Items.POOLS.ghost end
	if kind == "living" then return if holder then Items.POOLS.holder else Items.POOLS.runner end
	return nil
end

-- What each usable item does to the living runner it catches, and how long. The hex is used by touch (GhostClaim).
Items.HOLD = { crate = "stumble", trap = "trap", ice = "freeze" } :: { [string]: string }
Items.HOLD_TIME = { stumble = Config.STUMBLE_TIME, freeze = Config.FREEZE_TIME, trap = Config.TRAP_TIME }
	:: { [string]: number }
-- Aimed (rule 45: a dash's i-frames dodge it; rule 41: a ghost's hit wards its target) versus put down (jump it).
Items.AIMED = { ice = true, hex = true } :: { [string]: boolean }

-- A thing in the world: a crate, a trap or a beam. (x, y) its centre, (hw, hh) its half size; `dir` the user's facing.
export type Thing = {
	n: number, item: string, owner: number, ghost: boolean, x: number, y: number, hw: number, hh: number, dir: number,
	from: number, untilT: number, armed: boolean, hit: { [number]: boolean },
}
export type Hold = { kind: string, from: number, untilT: number, presses: number, over: boolean }
export type State = { things: { Thing }, nextN: number, holds: { [number]: Hold } }
-- A living runner as the server last recorded it: (x, y), the sample before (px, py) if any (the path counts, N14),
-- whether that sample is in a dash's i-frames, and for the holder when its tag freeze ends (a hold too, rule 44).
export type Victim = { id: number, x: number, y: number, px: number?, py: number?, iframe: boolean?, frozenUntil: number? }
-- "hold" { id, hold, time, by } a hold landed; "free" { id } it ended; "gone" { n } a thing broke, caught or expired.
export type Event = { kind: string, id: number?, hold: string?, time: number?, by: number?, n: number? }

function Items.new(): State
	return { things = {}, nextN = 0, holds = {} }
end

-- One axis of the slab test: narrows [t0, t1] to where the moving point a -> b is within h of c; nil if never.
local function slab(a: number, b: number, c: number, h: number, t0: number, t1: number): (number?, number?)
	local d = b - a
	if math.abs(d) < 1e-9 then
		if math.abs(a - c) > h then return nil, nil end
		return t0, t1
	end
	local u, v = (c - h - a) / d, (c + h - a) / d
	if u > v then u, v = v, u end
	t0, t1 = math.max(t0, u), math.min(t1, v)
	if t0 > t1 then return nil, nil end
	return t0, t1
end

-- Does a point moving from (px, py) to (x, y) come within (hw, hh) of (cx, cy)? Pass the box's half size PLUS the
-- runner's, and this is a runner box swept along the path between two server samples (→ N14). Orbs.touches uses it.
function Items.swept(cx: number, cy: number, hw: number, hh: number, x: number, y: number, px: number?, py: number?)
	: boolean
	local t0, t1 = slab(px or x, x, cx, hw, 0, 1)
	if t0 == nil or t1 == nil then return false end
	return (slab(py or y, y, cy, hh, t0, t1)) ~= nil
end

-- Where Use puts an item for a runner centred at (x, y) facing `facing` (+1 right, -1 left): a crate on the ground
-- line behind it, a trap at its feet, a beam from its front edge ICE_LENGTH ahead at its centre height.
function Items.footprint(item: string, x: number, y: number, facing: number): (number, number, number, number)
	local feet = y - Config.RUNNER_HEIGHT / 2
	if item == "crate" then
		local h = Config.CRATE_SIZE / 2
		return x - facing * (Config.RUNNER_WIDTH / 2 + h + 0.5), feet + h, h, h
	elseif item == "trap" then
		return x, feet + Config.TRAP_H / 2, Config.TRAP_W / 2, Config.TRAP_H / 2
	end
	return x + facing * (Config.RUNNER_WIDTH / 2 + Config.ICE_LENGTH / 2), y, Config.ICE_LENGTH / 2, Config.ICE_HEIGHT / 2
end

-- The hold in force on `id` at `now`, if any.
function Items.holdOf(st: State, id: number, now: number): Hold?
	local h = st.holds[id]
	if h and not h.over and now < h.untilT then return h end
	return nil
end

-- Rule 44 (H20, Danzo 2026-10-19): the holds that stop their victim passing the fuse. Only the ice freeze: a frozen
-- holder's claims are refused until it ends; a trap or a stumble never stops a tag, and no hold shields a victim.
Items.STOPS_TAG = { freeze = true } :: { [string]: boolean }

-- May `id` pass the fuse at `now`, on the server's own hold record (never the client's)? Ok and, when not, why (logs).
function Items.canTag(st: State, id: number, now: number): (boolean, string?)
	local h = Items.holdOf(st, id, now)
	if h and Items.STOPS_TAG[h.kind] then return false, "frozen by ice" end
	return true, nil
end

-- May a new hold land on `id`? Never during one, never in the HOLD_IMMUNITY after one ends (rule 44: no chains). The
-- holder's tag freeze is a hold too: pass its end as `frozenUntil`.
function Items.canHold(st: State, id: number, now: number, frozenUntil: number?): boolean
	local h = st.holds[id]
	if h and now < h.untilT + Config.HOLD_IMMUNITY then return false end
	return not (frozenUntil and now < frozenUntil + Config.HOLD_IMMUNITY)
end

-- May `id` start `item` now (rule 44: never during a hold or the tag freeze)? Returns ok and, when not, why (logs).
function Items.canUse(st: State, id: number, item: string?, now: number, frozenUntil: number?): (boolean, string?)
	if item == nil then return false, "nothing held" end
	if item == "hex" then return false, "the hex is used by touch" end
	if Items.HOLD[item] == nil then return false, "not a usable item" end
	if Items.holdOf(st, id, now) then return false, "in a hold" end
	if frozenUntil and now < frozenUntil then return false, "frozen" end
	return true, nil
end

-- Use (call canUse first): the thing goes into the world at the user's spot as the SERVER recorded it. It outlives any
-- hold its user gets later (rule 44: an item started before a hold goes off in full).
function Items.use(st: State, id: number, item: string, ghost: boolean, x: number, y: number, facing: number,
	now: number): Thing
	local dir = if facing < 0 then -1 else 1
	local cx, cy, hw, hh = Items.footprint(item, x, y, dir)
	st.nextN += 1
	local t: Thing = { n = st.nextN, item = item, owner = id, ghost = ghost, x = cx, y = cy, hw = hw, hh = hh, dir = dir,
		from = now, untilT = now + (if item == "ice" then Config.ICE_LIFE else Config.ITEM_LIFE), armed = false, hit = {} }
	table.insert(st.things, t)
	return t
end

-- A press while trapped (any key, click or tap reaches the server as a UseItem). True when this press frees it.
function Items.pry(st: State, id: number, now: number): boolean
	local h = Items.holdOf(st, id, now)
	if not (h and h.kind == "trap") then return false end
	h.presses += 1
	if h.presses < Config.TRAP_PRESSES then return false end
	h.untilT, h.over = now, true
	return true
end

-- Does the server take a press from `id` arriving at `now` (its last taken press at `last`)? Outside a trap, Use presses
-- closer than USE_GAP are dropped (→ N4). DURING a trap every press counts (QA round 1): a gap there let network
-- jitter drop one of three honest presses, the client freed itself while the server still pinned it, and the speed
-- check snapped an honest runner back. A cheat gains nothing here: three presses free it either way.
function Items.acceptPress(st: State, id: number, now: number, last: number?): boolean
	local h = Items.holdOf(st, id, now)
	if h and h.kind == "trap" then return true end
	return last == nil or now - last >= Config.USE_GAP
end

-- Rule 45: is a dash that the server saw start at `dashAt` still in its i-frames at `now`?
function Items.iframed(dashAt: number?, now: number): boolean
	return dashAt ~= nil and now >= dashAt and now < dashAt + Config.DASH_IFRAMES
end

-- The server's record of dash starts: a new one counts only once the dash cooldown has passed since the last one that
-- counted (less arrival jitter), so a client cannot claim to be dashing for ever (proposal §8).
local DASH_JITTER = 0.1
function Items.dashSeen(last: number?, now: number): boolean
	return last == nil or now - last >= Config.DASH_COOLDOWN - DASH_JITTER
end

-- The samples a hex may land on: none inside a dash's i-frames (rule 45). A tag never asks this.
function Items.undodged<S>(samples: { S }): { S }
	local out = {}
	for _, s in samples do
		if not (s :: any).iframe then table.insert(out, s) end
	end
	return out
end

-- Does thing `t` catch victim `v` now? Writes the hold and the ward when it does.
local function catch(st: State, t: Thing, v: Victim, now: number, wards: { [number]: number }, ev: { Event }): boolean
	local touching = Items.swept(t.x, t.y, t.hw + Config.RUNNER_WIDTH / 2, t.hh + Config.RUNNER_HEIGHT / 2, v.x, v.y,
		v.px, v.py)
	if v.id == t.owner then
		if t.item == "ice" then return false end -- a beam never hits its own user
		if not t.armed then
			t.armed = not touching and now >= t.from + Config.OWNER_SAFE -- safe until it has stepped off, and 0.5 s
			return false
		end
	end
	if not touching then return false end
	if t.item ~= "crate" and v.iframe then return false end -- rule 45: dash through the beam, over the trap; never a crate
	if t.item == "ice" and (t.hit[v.id] or (t.ghost and now < (wards[v.id] or -math.huge))) then return false end
	if not Items.canHold(st, v.id, now, v.frozenUntil) then return false end
	local kind = Items.HOLD[t.item]
	local time = Items.HOLD_TIME[kind]
	st.holds[v.id] = { kind = kind, from = now, untilT = now + time, presses = 0, over = false }
	t.hit[v.id] = true
	if t.ghost and Items.AIMED[t.item] then wards[v.id] = now + Config.GHOST_WARD end -- rule 41, per target
	table.insert(ev, { kind = "hold", id = v.id, hold = kind, time = time, by = t.n })
	return true
end

-- One server frame: holds that ran out, then each thing (oldest first) against each living victim (`victims` in join
-- order: a tie goes to the first). A crate or trap that catches someone is gone; a beam stays out its 0.5 s and catches
-- each runner once. `wards` is the ghosts' per-target ward table (Ghost.Ghosts.wards), read and written.
function Items.step(st: State, now: number, victims: { Victim }, wards: { [number]: number }): { Event }
	local ev: { Event } = {}
	for id, h in st.holds do
		if not h.over and now >= h.untilT then
			h.over = true
			table.insert(ev, { kind = "free", id = id })
		end
	end
	local keep: { Thing } = {}
	for _, t in st.things do
		local gone = now >= t.untilT
		if not gone then
			for _, v in victims do
				if catch(st, t, v, now, wards, ev) and t.item ~= "ice" then
					gone = true
					break
				end
			end
		end
		if gone then table.insert(ev, { kind = "gone", n = t.n }) else table.insert(keep, t) end
	end
	st.things = keep
	return ev
end

return Items
