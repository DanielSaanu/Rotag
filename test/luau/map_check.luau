-- Helpers for maps.test.luau (inlined by `--!include map_check.luau`): a map on a tile grid, a conservative model of
-- where a runner can get to, and the rule-48 passage finder (docs/systems/maps.md §2).
--
-- The reach model, per tile (a runner's 2 x 3.5 box fits one 4-stud tile), deliberately WEAKER than the real moves so
-- "reachable here" means reachable in the game with run, jump, double jump and wall jumps only (no dash, grapple or
-- pad; rule 18: casual players do fine with run and jump):
--   standing on a solid tile: up to UP tiles of rise (a jump and the double jump measure 7) and AIR tiles of air drift;
--   touching a wall on the side it did not last kick from: KICK more tiles of rise and KICK_H of drift (so one wall is
--   never climbed, two walls 3 apart are, as in the game);
--   rising costs rise, sideways in the air costs drift, falling is free and spends the rise (no jump after a fall).
local MC = {}
MC.UP, MC.AIR, MC.KICK, MC.KICK_H = 6, 10, 3, 4
MC.ROOM = 5 -- rule 48 / proposal §5: a passage under 5 tiles across is a corridor; a free 5 x 5 square is a room

local T = Config.STUDS_PER_TILE

local function overlaps(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
	return ax0 < bx1 - 1e-6 and bx0 < ax1 - 1e-6 and ay0 < by1 - 1e-6 and by0 < ay1 - 1e-6
end
MC.overlaps = overlaps

-- The grid: x tiles i0..i1 (inside the blocks' extent), y tiles 0..top-1 (the floor's top is y 0). Outside is solid.
function MC.grid(map)
	local x0, x1 = math.huge, -math.huge
	for _, b in map.blocks do x0, x1 = math.min(x0, b[2]), math.max(x1, b[4]) end
	local g = { i0 = math.floor(x0 / T), i1 = math.ceil(x1 / T) - 1, rows = math.ceil(map.top / T), solid = {}, map = map }
	g.w = g.i1 - g.i0 + 1
	for j = 0, g.rows - 1 do
		for i = g.i0, g.i1 do
			for _, b in map.blocks do
				if overlaps(i * T, j * T, (i + 1) * T, (j + 1) * T, b[2], b[3], b[4], b[5]) then
					g.solid[j * g.w + (i - g.i0)] = true
					break
				end
			end
		end
	end
	return g
end

function MC.isSolid(g, i, j)
	if i < g.i0 or i > g.i1 or j < 0 or j >= g.rows then return true end
	return g.solid[j * g.w + (i - g.i0)] == true
end

function MC.tileOf(x, y) return math.floor(x / T + 1e-9), math.floor(y / T + 1e-9) end

-- Every tile reachable from tile (si, sj): a set keyed j * w + (i - i0).
function MC.reach(g, si, sj)
	local seen, tiles, queue, head = {}, {}, {}, 1
	local function push(i, j, b, h, w)
		if MC.isSolid(g, i, j) then return end
		if MC.isSolid(g, i, j - 1) then
			b, h, w = MC.UP, MC.AIR, 0
		elseif MC.isSolid(g, i - 1, j) and w ~= -1 then
			b, h, w = math.max(b, MC.KICK), math.max(h, MC.KICK_H), -1
		elseif MC.isSolid(g, i + 1, j) and w ~= 1 then
			b, h, w = math.max(b, MC.KICK), math.max(h, MC.KICK_H), 1
		end
		local key = (((j * g.w + (i - g.i0)) * (MC.UP + 1) + b) * (MC.AIR + 1) + h) * 3 + (w + 1)
		if seen[key] then return end
		seen[key] = true
		tiles[j * g.w + (i - g.i0)] = true
		table.insert(queue, { i, j, b, h, w })
	end
	push(si, sj, 0, 0, 0)
	while head <= #queue do
		local s = queue[head]
		head += 1
		local i, j, b, h, w = s[1], s[2], s[3], s[4], s[5]
		local support = MC.isSolid(g, i, j - 1)
		for _, di in { -1, 1 } do
			if support then push(i + di, j, b, MC.AIR, w) elseif h >= 1 then push(i + di, j, b, h - 1, w) end
		end
		if b >= 1 then push(i, j + 1, b - 1, h, w) end
		if not support then push(i, j - 1, 0, h, w) end
	end
	return tiles
end

function MC.has(g, set, i, j) return set[j * g.w + (i - g.i0)] == true end

-- Rule 48's passages: free tiles in no free ROOM x ROOM square (a corridor, a gap under a deck, a shaft).
function MC.passages(g)
	local room = {}
	for j = 0, g.rows - MC.ROOM do
		for i = g.i0, g.i1 - MC.ROOM + 1 do
			local free = true
			for dj = 0, MC.ROOM - 1 do
				for di = 0, MC.ROOM - 1 do
					if MC.isSolid(g, i + di, j + dj) then free = false break end
				end
				if not free then break end
			end
			if free then
				for dj = 0, MC.ROOM - 1 do
					for di = 0, MC.ROOM - 1 do room[(j + dj) * g.w + (i + di - g.i0)] = true end
				end
			end
		end
	end
	local out = {}
	for j = 0, g.rows - 1 do
		for i = g.i0, g.i1 do
			local k = j * g.w + (i - g.i0)
			if not MC.isSolid(g, i, j) and not room[k] then out[k] = { i, j } end
		end
	end
	return out
end

-- The worst case of rule 48 ("however many ghosts"): every passage tile a part could cover (no static box under it:
-- map, keep-clear, orb, anchor; Maps.static) made solid. Map pads are filled too (conservative: they add no reach).
function MC.filled(g, static)
	local f = { i0 = g.i0, i1 = g.i1, w = g.w, rows = g.rows, solid = table.clone(g.solid), map = g.map }
	local n = 0
	for k, t in MC.passages(g) do
		local i, j = t[1], t[2]
		local clear = true
		for _, z in static do
			if overlaps(i * T, j * T, (i + 1) * T, (j + 1) * T, z[1], z[2], z[3], z[4]) then clear = false break end
		end
		if clear then f.solid[k] = true n += 1 end
	end
	return f, n
end

-- The places a map must join both ways (rule 26: no dead ends): the start line's places, every orb, and one picked
-- stand per anchor (given by the test). { name, i, j }.
function MC.targets(map, startXs, stands)
	local out = {}
	for _, x in startXs do
		local i, j = MC.tileOf(x, map.spawn.y)
		table.insert(out, { ("start x %g"):format(x), i, j })
	end
	for _, s in map.ghostOrbs do table.insert(out, { ("ghost orb (%g, %g)"):format(s.x, s.y), MC.tileOf(s.x, s.y) }) end
	for _, s in map.livingOrbs do table.insert(out, { ("living orb (%g, %g)"):format(s.x, s.y), MC.tileOf(s.x, s.y) }) end
	for _, s in stands do table.insert(out, { s[1], MC.tileOf(s[2], s[3]) }) end
	return out
end

-- The problems with world `g` (the map as built, or filled): a target not reached from the spawn, or the spawn not
-- reached from a target. Empty = every place joined both ways.
function MC.joined(g, targets)
	local problems = {}
	local si, sj = MC.tileOf(g.map.spawn.x, g.map.spawn.y)
	local fromSpawn = MC.reach(g, si, sj)
	for _, t in targets do
		if not MC.has(g, fromSpawn, t[2], t[3]) then
			table.insert(problems, t[1] .. " is not reached from the spawn")
		elseif not MC.has(g, MC.reach(g, t[2], t[3]), si, sj) then
			table.insert(problems, t[1] .. " is a dead end (no way back to the spawn)")
		end
	end
	return problems, fromSpawn
end

-- An ASCII picture for the eye (written to exports/<name>.txt by run.js): # solid, . reached free, blank unreached,
-- k keep-clear, g / o ghost / living orb, A anchor, = pad, S start place. Top row first.
function MC.picture(g, reached, startXs)
	local map, marks = g.map, {}
	local function mark(x, y, c)
		local i, j = MC.tileOf(x, y)
		marks[j * g.w + (i - g.i0)] = c
	end
	for _, x in startXs do mark(x, map.spawn.y, "S") end
	for _, p in map.pads do mark(p.x, p.y, "=") end
	for _, s in map.ghostOrbs do mark(s.x, s.y, "g") end
	for _, s in map.livingOrbs do mark(s.x, s.y, "o") end
	for _, a in map.anchors do mark(a.x, a.y, "A") end
	local lines = {}
	for j = g.rows - 1, 0, -1 do
		local row = {}
		for i = g.i0, g.i1 do
			local k = j * g.w + (i - g.i0)
			local c = if MC.isSolid(g, i, j) then "#" elseif reached[k] then "." else " "
			if c ~= "#" then
				for _, z in map.keepClear do
					if overlaps(i * T, j * T, (i + 1) * T, (j + 1) * T, z[1], z[2], z[3], z[4]) then c = "k" end
				end
			end
			table.insert(row, marks[k] or c)
		end
		table.insert(lines, ("%3d "):format(j) .. table.concat(row))
	end
	return table.concat(lines, "\n")
end
