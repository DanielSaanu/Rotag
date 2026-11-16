--!strict
--!native
-- A world of boxes for runners the SERVER simulates (the bots, H31; docs/systems/bots.md): what Studio's raycasts and
-- physics are to a player's client (client/Body), as plain maths, so a bot runs the very same shared/Movement rules a
-- player does. Also a tile grid of the map and a flood-fill distance field over it, which is how a bot knows the way
-- ROUND a deck instead of the straight line through it. Pure Luau; tests: test/luau/bots.test.luau.
local Config = require(script.Parent.Config)
local Movement = require(script.Parent.Movement)

local BoxWorld = {}

export type Box = { number } -- { x0, y0, x1, y1 }
export type Grid = { i0: number, w: number, rows: number, solid: { [number]: boolean } }

local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local T = Config.STUDS_PER_TILE
local GROUND_PROBE = 8 -- as client/Body: the jump buffer needs to see a floor coming
local CEILING_PROBE = 0.5
local WALL_PROBE = Movement.wallReach() + 0.1
BoxWorld.FAR = 1e9 -- a tile the flood fill never reached

-- A map's blocks ({ name, x0, y0, x1, y1 }) as boxes, plus any extra boxes (flat { x0, y0, x1, y1, ... } runs of 4).
function BoxWorld.fromBlocks(blocks: { { any } }): { Box }
	local out = {}
	for _, b in blocks do table.insert(out, { b[2], b[3], b[4], b[5] }) end
	return out
end

-- What the runner at (x, y) is touching, written into `c` (reused: no allocation). The same three rays a side as
-- client/Body casts: just inside the collider's corners and through its centre.
function BoxWorld.probe(world: { Box }, x: number, y: number, c: Movement.Contacts)
	local ground, ceiling, wallLeft, wallRight = nil, nil, nil, nil
	local xa, xb = x - HW + 0.1, x + HW - 0.1
	local ya, yb = y - HH + 0.2, y + HH - 0.2
	for _, b in world do
		local x0, y0, x1, y1 = b[1], b[2], b[3], b[4]
		if xb >= x0 and xa <= x1 then -- some ray below / above crosses this box's span
			if y1 <= y then
				local d = (y - HH) - y1
				if d <= GROUND_PROBE and (ground == nil or d < ground) then ground = d end
			elseif y0 >= y then
				local d = y0 - (y + HH)
				if d <= CEILING_PROBE and (ceiling == nil or d < ceiling) then ceiling = d end
			end
		end
		if yb >= y0 and ya <= y1 then
			if x0 >= x then
				local d = x0 - (x + HW)
				if d <= WALL_PROBE and (wallRight == nil or d < wallRight) then wallRight = d end
			elseif x1 <= x then
				local d = (x - HW) - x1
				if d <= WALL_PROBE and (wallLeft == nil or d < wallLeft) then wallLeft = d end
			end
		end
	end
	c.ground, c.ceiling, c.wallLeft, c.wallRight = ground, ceiling, wallLeft, wallRight
end

local function overlapping(world: { Box }, x: number, y: number): Box?
	for _, b in world do
		if x + HW > b[1] and x - HW < b[3] and y + HH > b[2] and y - HH < b[4] then return b end
	end
	return nil
end

-- Physics' part: move by the velocity, x then y, and stop flush against whatever was hit (the speed into it is lost,
-- as a part's is).
function BoxWorld.move(world: { Box }, s: Movement.State, dt: number)
	s.x += s.vx * dt
	local b = overlapping(world, s.x, s.y)
	if b then
		s.x = if s.vx > 0 then b[1] - HW else b[3] + HW
		s.vx = 0
	end
	s.y += s.vy * dt
	b = overlapping(world, s.x, s.y)
	if b then
		s.y = if s.vy > 0 then b[2] - HH else b[4] + HH
		if s.vy > 0 then s.vy = 0 end
	end
end

-- Is the straight line from (x0, y0) to (x1, y1) clear of every box? (A rope's line of sight: client/Grapple asks
-- Studio's raycast the same question.)
function BoxWorld.clear(world: { Box }, x0: number, y0: number, x1: number, y1: number): boolean
	local dx, dy = x1 - x0, y1 - y0
	for _, b in world do
		local t0, t1, inside = 0, 1, true
		if math.abs(dx) < 1e-9 then
			inside = x0 > b[1] and x0 < b[3]
		else
			local a, c = (b[1] - x0) / dx, (b[3] - x0) / dx
			if a > c then a, c = c, a end
			t0, t1 = math.max(t0, a), math.min(t1, c)
		end
		if inside then
			if math.abs(dy) < 1e-9 then
				inside = y0 > b[2] and y0 < b[4]
			else
				local a, c = (b[2] - y0) / dy, (b[4] - y0) / dy
				if a > c then a, c = c, a end
				t0, t1 = math.max(t0, a), math.min(t1, c)
			end
		end
		if inside and t0 < t1 then return false end
	end
	return true
end

-- The top of the highest box under the point (x, y), or nil (an anchor's `floor`, shared/Grapple.attach).
function BoxWorld.floorUnder(world: { Box }, x: number, y: number): number?
	local best = nil
	for _, b in world do
		if x >= b[1] and x <= b[3] and b[4] <= y and (best == nil or b[4] > best) then best = b[4] end
	end
	return best
end

-- The map as tiles: x tiles i0.. (the blocks' extent), y tiles 0..rows-1 from the floor's top. A tile any block
-- overlaps is solid; outside the grid is solid.
function BoxWorld.grid(blocks: { { any } }, top: number): Grid
	local x0, x1 = math.huge, -math.huge
	for _, b in blocks do x0, x1 = math.min(x0, b[2]), math.max(x1, b[4]) end
	local i0, i1 = math.floor(x0 / T), math.ceil(x1 / T) - 1
	local g: Grid = { i0 = i0, w = i1 - i0 + 1, rows = math.ceil(top / T), solid = {} }
	for j = 0, g.rows - 1 do
		for i = i0, i1 do
			for _, b in blocks do
				if i * T < b[4] - 1e-6 and b[2] < (i + 1) * T - 1e-6 and j * T < b[5] - 1e-6 and b[3] < (j + 1) * T - 1e-6 then
					g.solid[j * g.w + (i - i0)] = true
					break
				end
			end
		end
	end
	return g
end

-- The tile index of a world point, clamped into the grid.
function BoxWorld.tile(g: Grid, x: number, y: number): number
	local i = math.clamp(math.floor(x / T) - g.i0, 0, g.w - 1)
	local j = math.clamp(math.floor(y / T), 0, g.rows - 1)
	return j * g.w + i
end

-- Flood fill from the tile at (x, y) through the free tiles, 4 ways: `out[tile]` = steps from there, BoxWorld.FAR
-- where it never got. `out` and `queue` are reused by the caller (no allocation after the first call). A start
-- inside a solid tile (a runner brushing a deck) starts from the tile above it.
function BoxWorld.field(g: Grid, x: number, y: number, out: { number }, queue: { number }): { number }
	local n = g.w * g.rows
	for k = 0, n - 1 do out[k] = BoxWorld.FAR end
	local start = BoxWorld.tile(g, x, y)
	while g.solid[start] and start + g.w < n do start += g.w end
	if g.solid[start] then return out end
	local w, solid = g.w, g.solid
	out[start] = 0
	queue[1] = start
	local head, tail = 1, 1
	while head <= tail do
		local k = queue[head]
		head += 1
		local d = out[k] + 1
		local i = k % w
		if i > 0 and not solid[k - 1] and out[k - 1] > d then out[k - 1] = d tail += 1 queue[tail] = k - 1 end
		if i < w - 1 and not solid[k + 1] and out[k + 1] > d then out[k + 1] = d tail += 1 queue[tail] = k + 1 end
		if k >= w and not solid[k - w] and out[k - w] > d then out[k - w] = d tail += 1 queue[tail] = k - w end
		if k + w < n and not solid[k + w] and out[k + w] > d then out[k + w] = d tail += 1 queue[tail] = k + w end
	end
	return out
end

-- The way from (x, y) to the field's source, in studs: tiles of flood fill, FAR if there is none. A runner whose
-- centre is in a solid tile (its head under a deck: a deck's tile is solid whole) counts as the free tile below it.
function BoxWorld.far(g: Grid, field: { number }, x: number, y: number): number
	local k = BoxWorld.tile(g, x, y)
	while g.solid[k] and k >= g.w do k -= g.w end
	local d = field[k]
	return if d >= BoxWorld.FAR then BoxWorld.FAR else d * T
end

return BoxWorld
