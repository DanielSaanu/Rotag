--!strict
-- Ghost parts: fixtures (tetrominoes) and boost pads (DESIGN §3 rules 15, 47, 48; H22, docs/systems/placement.md).
-- Pure Luau over plain tables, every clock passed in as `now`, every roll's random source as `rand`. The SERVER owns
-- the one State per round (server/Placement) and re-checks every placement; a client keeps a mirror of it from
-- ItemEvent to draw its preview and to launch its own runner off a pad. The fit test (`fits`) and the box writers run
-- every frame on a ghost's client, so they take caller-owned buffers and allocate nothing (→ trigger 6).
local Config = require(script.Parent.Config)

local Placement = {}

local T = Config.STUDS_PER_TILE
local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local EPS = 0.05 -- studs: boxes that only touch (a piece on the floor, two pieces side by side) do not overlap

-- The seven tetrominoes as tile cells, y up, before rotation. All seven, equal odds: with rotation only (no flip in a
-- side-on game) S/Z and J/L are four distinct shapes, and seven shapes is the set every player already knows.
Placement.SHAPES = { "I", "O", "T", "S", "Z", "J", "L" }
local BASE: { [string]: { { number } } } = {
	I = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } },
	O = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
	T = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } },
	S = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } },
	Z = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } },
	J = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 2, 1 } },
	L = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 0, 1 } },
}

-- Every shape in every rotation, built once: `cells` flat { x1, y1, x2, y2, ... } in tiles from the bounding box's
-- bottom-left, `w` / `h` the box in tiles, `rows` the cells merged into one box per row run (server/Placement makes one
-- Part per row, so a runner on a piece's top never crosses a seam).
export type Shaped = { cells: { number }, w: number, h: number, rows: { { number } } }
Placement.ROT = {} :: { [string]: { Shaped } }
for name, cells in BASE do
	local rots: { Shaped } = {}
	local cur: { { number } } = cells
	for _ = 0, 3 do
		local minX: number, minY: number, maxX: number, maxY: number = math.huge, math.huge, -math.huge, -math.huge
		for _, c in cur do
			local cx, cy = c[1] :: number, c[2] :: number
			minX, minY, maxX, maxY = math.min(minX, cx), math.min(minY, cy), math.max(maxX, cx), math.max(maxY, cy)
		end
		local flat: { number }, rows: { { number } } = {}, {}
		for y = minY, maxY do
			local run: { number }? = nil
			for x = minX, maxX do
				local filled = false
				for _, c in cur do if c[1] == x and c[2] == y then filled = true end end
				if filled then
					table.insert(flat, x - minX)
					table.insert(flat, y - minY)
					if run then run[3] = x - minX + 1 else run = { x - minX, y - minY, x - minX + 1, y - minY + 1 } end
				elseif run then
					table.insert(rows, run)
					run = nil
				end
			end
			if run then table.insert(rows, run) end
		end
		table.insert(rots, { cells = flat, w = maxX - minX + 1, h = maxY - minY + 1, rows = rows })
		local nxt: { { number } } = {}
		for _, c in cur do table.insert(nxt, { -c[2], c[1] }) end -- a quarter turn anticlockwise
		cur = nxt
	end
	Placement.ROT[name] = rots
end

-- The shape a ghost's new fixture gets, rolled by the server when the orb gives it (shared/Orbs).
function Placement.rollShape(rand: () -> number): string
	local i = math.floor(rand() * #Placement.SHAPES) + 1
	return Placement.SHAPES[math.clamp(i, 1, #Placement.SHAPES)]
end

-- A valid shape name and rotation 0-3 (a network value is checked with this before it is used).
function Placement.valid(shape: any, rot: any): boolean
	return type(shape) == "string" and BASE[shape] ~= nil and type(rot) == "number" and rot % 1 == 0 and rot >= 0
		and rot <= 3
end

-- Where a placed item's box goes for a ghost at (x, y) facing `facing` (proposal §5): returns its bottom-left, studs.
-- Its bottom is the ghost's feet rounded to the tile grid (on a floor: flush on it; mid-jump: hovering, so a ghost
-- jumps to place high). A fixture's near edge is PLACE_GAP past the ghost's front edge, rounded outward to the grid,
-- so pieces line up and never start inside their ghost. A pad is centred on the ghost ("where you stand").
function Placement.spot(item: string, shape: string?, rot: number, x: number, y: number, facing: number)
	: (number, number)
	local bottom = math.floor((y - HH) / T + 0.5) * T
	if item == "pad" then return x - Config.PAD_W / 2, bottom end
	local w = Placement.ROT[shape :: string][rot + 1].w * T
	if facing >= 0 then return math.ceil((x + HW + Config.PLACE_GAP) / T) * T, bottom end
	return math.floor((x - HW - Config.PLACE_GAP) / T) * T - w, bottom
end

-- Write the item's boxes at (left, bottom) into `buf` as flat { x0, y0, x1, y1, ... } studs; returns how many boxes.
-- A fixture is its four cells, a pad its one slab. `buf` is the caller's and is reused (no allocation).
function Placement.boxesInto(buf: { number }, item: string, shape: string?, rot: number, left: number, bottom: number)
	: number
	if item == "pad" then
		buf[1], buf[2], buf[3], buf[4] = left, bottom, left + Config.PAD_W, bottom + Config.PAD_H
		return 1
	end
	local cells = Placement.ROT[shape :: string][rot + 1].cells
	local n = #cells // 2
	for i = 0, n - 1 do
		local cx, cy = left + cells[i * 2 + 1] * T, bottom + cells[i * 2 + 2] * T
		buf[i * 4 + 1], buf[i * 4 + 2], buf[i * 4 + 3], buf[i * 4 + 4] = cx, cy, cx + T, cy + T
	end
	return n
end

local function hit(ax0: number, ay0: number, ax1: number, ay1: number, bx0: number, by0: number, bx1: number,
	by1: number): boolean
	return ax0 < bx1 - EPS and ax1 > bx0 + EPS and ay0 < by1 - EPS and ay1 > by0 + EPS
end

-- A thing a ghost put in the world. `boxes` flat as above; `untilT` math.huge for a fixture (permanent for the
-- round) until a fourth fades it (`fadeAt`); `dir` the placer's facing when it was put down (kept on the wire; a pad no
-- longer uses it: it throws a runner the way the runner is going).
export type Placed = { n: number, owner: number, item: string, shape: string?, rot: number, left: number,
	bottom: number, dir: number, boxes: { number }, count: number, from: number, untilT: number, fadeAt: number? }
export type State = { placed: { Placed }, nextN: number }
-- A box the map forbids: x0, y0, x1, y1 and why ("map", "keep-clear", "spawn", "orb", "anchor" since H25).
export type Box = { any }

function Placement.new(): State
	return { placed = {}, nextN = 0 }
end

-- The fit test (rules 47, 48; proposal §5), allocation-free: do `count` boxes in `buf` stay clear of every static
-- box, every live placed thing, and every runner in `runners` ({ x, y, margin } rows, the first `nr` used: a living
-- runner with margin PLACE_CLEAR, a ghost with 0 when the item is solid, left out for a pad)? Ok, or why not.
function Placement.fits(st: State, buf: { number }, count: number, static: { Box }, runners: { { number } }, nr: number)
	: (boolean, string?)
	for i = 0, count - 1 do
		local x0, y0, x1, y1 = buf[i * 4 + 1], buf[i * 4 + 2], buf[i * 4 + 3], buf[i * 4 + 4]
		for _, b in static do
			if hit(x0, y0, x1, y1, b[1], b[2], b[3], b[4]) then return false, b[5] or "map" end
		end
		for _, p in st.placed do
			local pb = p.boxes
			for k = 0, p.count - 1 do
				if hit(x0, y0, x1, y1, pb[k * 4 + 1], pb[k * 4 + 2], pb[k * 4 + 3], pb[k * 4 + 4]) then
					return false, if p.item == "pad" then "a pad" else "a piece"
				end
			end
		end
		for j = 1, nr do
			local r = runners[j]
			local m = r[3]
			if hit(x0, y0, x1, y1, r[1] - HW - m, r[2] - HH - m, r[1] + HW + m, r[2] + HH + m) then
				return false, "a runner"
			end
		end
	end
	return true, nil
end

-- Record a thing at (left, bottom) as number `n` (the server numbers them; a client mirror passes the server's).
function Placement.record(st: State, n: number, owner: number, item: string, shape: string?, rot: number, left: number,
	bottom: number, dir: number, now: number, life: number?): Placed
	local boxes = {}
	local count = Placement.boxesInto(boxes, item, shape, rot, left, bottom)
	local p: Placed = { n = n, owner = owner, item = item, shape = shape, rot = rot, left = left, bottom = bottom,
		dir = if dir < 0 then -1 else 1, boxes = boxes, count = count, from = now,
		untilT = if life then now + life else math.huge }
	table.insert(st.placed, p)
	st.nextN = math.max(st.nextN, n)
	return p
end

-- Live (not fading) fixtures of `owner`.
function Placement.live(st: State, owner: number): number
	local k = 0
	for _, p in st.placed do
		if p.owner == owner and p.item == "fixture" and not p.fadeAt then k += 1 end
	end
	return k
end

-- Place (call fits first): a fixture is permanent for the round, a pad lasts PAD_LIFE. A ghost's fixture past the cap
-- starts its OLDEST live one fading (FIXTURE_FADE, solid until it goes): returns the new thing and the faded one.
function Placement.place(st: State, owner: number, item: string, shape: string?, rot: number, left: number,
	bottom: number, dir: number, now: number): (Placed, Placed?)
	local faded: Placed? = nil
	if item == "fixture" and Placement.live(st, owner) >= Config.FIXTURE_CAP then
		for _, p in st.placed do -- oldest first: placed in order
			if p.owner == owner and p.item == "fixture" and not p.fadeAt then
				p.fadeAt = now + Config.FIXTURE_FADE
				faded = p
				break
			end
		end
	end
	local p = Placement.record(st, st.nextN + 1, owner, item, shape, rot, left, bottom, dir, now,
		if item == "pad" then Config.PAD_LIFE else nil)
	return p, faded
end

-- Take thing `n` out (the server said it is gone); true if it was there.
function Placement.remove(st: State, n: number): boolean
	for i, p in st.placed do
		if p.n == n then
			table.remove(st.placed, i)
			return true
		end
	end
	return false
end

-- One server frame: the numbers of things gone now (a faded fixture, a pad run out), removed from the state.
function Placement.step(st: State, now: number): { number }
	local gone = {}
	for i = #st.placed, 1, -1 do
		local p = st.placed[i]
		if now >= p.untilT or (p.fadeAt and now >= p.fadeAt) then
			table.insert(gone, 1, p.n)
			table.remove(st.placed, i)
		end
	end
	return gone
end

-- Does a runner box at (x, y) touch pad `p`? (A client launches its own runner the frame it ENTERS one: standing in
-- a pad, the ghost that set it, is not an entry, so its own pad never fires under it.)
function Placement.onPad(p: Placed, x: number, y: number): boolean
	local b = p.boxes
	return hit(x - HW, y - HH, x + HW, y + HH, b[1], b[2], b[3], b[4])
end

-- A pad's launch (rule 15; the numbers in Config): x the way the runner is already going (`dir` is ITS travel
-- direction, its facing when it stands still; Danzo 2026-10-31: pads throw you onward, they have no arrow), y up.
function Placement.launch(dir: number): (number, number)
	return (if dir < 0 then -1 else 1) * Config.PAD_SPEED_X, Config.PAD_SPEED_Y
end

return Placement
