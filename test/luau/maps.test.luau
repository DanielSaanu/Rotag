-- The maps (H27, PR 6; DESIGN §3 rules 25-29, 48, §6.8; docs/systems/maps.md). Every map in shared/Maps is held to:
-- its data is well formed, every place is joined to the spawn both ways (no dead ends), rule 48's map rule (no
-- passage left open to a part can seal anything, however many parts), and the closing walls stay inside its window.
local Config = __require("Config")
local Maps = __require("Maps")
local Grapple = __require("Grapple")
local Tag = __require("Tag")
local Walls = __require("Walls")
--!include map_check.luau

local T = Config.STUDS_PER_TILE
local HH = Config.RUNNER_HEIGHT / 2

-- The start line as Match lays it: Tag.startPlaces for a full match round the spawn.
local function startXs(map)
	local ids = {}
	for k = 1, Config.PLAYERS_PER_MATCH do ids[k] = k end
	local xs = {}
	for _, x in Tag.startPlaces(ids, 1, map.spawn.x, Config.START_SPREAD) do table.insert(xs, x) end
	table.sort(xs)
	return xs
end

-- Every stand (a block top) an anchor is PICKED from through the real camera framing on a 4:3 screen (grapple.test's
-- rule): { name, x, y feet }.
local function stands(map)
	local out, halfH = {}, Config.CAMERA_VIEW_HEIGHT / 2
	for k, a in map.anchors do
		local anchor = { x = a.x, y = a.y, id = 1 }
		for _, b in map.blocks do
			local sx, sy = math.clamp(a.x, b[2] + 1, b[4] - 1), b[5] + HH
			local dx, dy = a.x - sx, a.y - sy
			local view = { x = sx, y = sy + Config.CAMERA_Y_OFFSET, halfW = halfH * 4 / 3, halfH = halfH }
			if dy >= Config.GRAPPLE_MIN_ABOVE and dx * dx + dy * dy <= Config.GRAPPLE_RANGE ^ 2
				and Grapple.pick(sx, sy, 1, { anchor }, view) == anchor then
				table.insert(out, { k = k, name = ("anchor %d's stand on %s"):format(k, b[1]), x = sx, y = b[5] })
			end
		end
	end
	return out
end

for _, name in Maps.NAMES do
	local map = Maps.ALL[name]
	local g = MC.grid(map)
	local xs = startXs(map)

	do -- the data: well formed, inside the map, nothing buried in a block
		assert(map.name == name and Maps.get(name) == map, name .. ": registered under its own name")
		assert(#map.ghostOrbs >= 3 and #map.livingOrbs >= 3, name .. ": at least 3 ghost and 3 living orb spots")
		local function inBlock(x, y)
			for _, b in map.blocks do
				if x > b[2] and x < b[4] and y > b[3] and y < b[5] then return b[1] end
			end
			return nil
		end
		for _, s in Maps.orbs(map) do
			assert(not inBlock(s.x, s.y), ("%s: orb (%g, %g) is not inside %s"):format(name, s.x, s.y, tostring(inBlock(s.x, s.y))))
			local i, j = MC.tileOf(s.x, s.y)
			assert(MC.isSolid(g, i, j - 1), ("%s: orb (%g, %g) sits over a floor (ORB_UP above it)"):format(name, s.x, s.y))
		end
		for _, a in map.anchors do
			for _, b in map.blocks do
				assert(not MC.overlaps(a.x - 2, a.y - 2, a.x + 2, a.y + 2, b[2], b[3], b[4], b[5]),
					("%s: anchor (%g, %g) clear of %s by its 4-stud box"):format(name, a.x, a.y, b[1]))
			end
		end
		for _, p in map.pads do
			local i, j = MC.tileOf(p.x, p.y)
			assert(MC.isSolid(g, i, j - 1) and not MC.isSolid(g, i, j), ("%s: pad at (%g, %g) lies on a floor"):format(name, p.x, p.y))
			assert(math.abs(p.y / T - math.floor(p.y / T + 0.5)) < 1e-9, name .. ": a pad sits on a tile line")
		end
		for _, z in map.keepClear do -- proposal §5: an exit at least 2 x 2 tiles (8 studs > the runner's 3.5)
			assert(z[3] - z[1] >= 2 * T and z[4] - z[2] >= 2 * T and z[5] == "keep-clear", name .. ": keep-clear zones are 2 x 2 tiles or more")
		end
	end

	do -- the window (§6.8, H26): the end walls' inner faces, wide enough to open, the whole start line inside it
		local lo, hi = map.window.lo, map.window.hi
		local left, right = false, false
		for _, b in map.blocks do
			if b[4] == lo and b[5] - b[3] >= 16 * T then left = true end
			if b[2] == hi and b[5] - b[3] >= 16 * T then right = true end
		end
		assert(left and right, name .. ": the window's bounds are the inner faces of two tall end walls")
		assert(hi - lo >= 2 * Config.WALL_START_MIN, name .. ": the window is wider than the walls' smallest opening")
		for _, x in xs do assert(x - 1 > lo and x + 1 < hi, name .. ": every start place inside the window") end
		-- the walls driven on this map's window: a pack that runs end to end for two minutes never sees a wall past it
		local A, B = 101, 202
		local r = Tag.newRound({ A, B }, A, 0)
		local pos = { [A] = lo + 3, [B] = lo + 10 }
		local w = Walls.open(r, 0, function(id) return pos[id], true end, map.window, 1.5) :: any
		assert(w, name .. ": the walls open on this map")
		local t = 0
		for k = 1, 60 * 120 do
			t += 1 / 60
			local x = lo + (hi - lo) * (0.5 - 0.5 * math.cos(k / 60 * 0.2))
			pos[A], pos[B] = x, x + 4
			Walls.step(w, r, t, 1 / 60, function(id) return pos[id], true end, function() return true end)
			local hw = Walls.halfWidth(w, t)
			assert(w.x - hw >= lo - 1e-9 and w.x + hw <= hi + 1e-9, name .. ": no wall ever past the window")
		end
	end

	local st = stands(map)
	local pickedBy = {}
	for _, s in st do pickedBy[s.k] = pickedBy[s.k] or s end
	local reachStands = {}
	for k = 1, #map.anchors do
		assert(pickedBy[k], ("%s: anchor %d is picked from some stand"):format(name, k))
	end

	do -- as built: every start place, orb and anchor stand joined to the spawn both ways (rules 25-26)
		local problems, reached = MC.joined(g, MC.targets(map, xs, {}))
		assert(#problems == 0, name .. ": " .. table.concat(problems, "; "))
		for k = 1, #map.anchors do -- some stand that picks the anchor is reachable
			local ok = false
			for _, s in st do
				local i, j = MC.tileOf(s.x, s.y)
				if s.k == k and MC.has(g, reached, i, j) then ok = true reachStands[k] = s break end
			end
			assert(ok, ("%s: anchor %d has a reachable stand that picks it"):format(name, k))
		end
		print(("MAPFILE map_%s\n%s\nENDMAP"):format(name, MC.picture(g, reached, xs)))
	end

	do -- rule 48, however many parts: fill every passage a part may cover; every orb and anchor stand stays joined.
		-- Not the start places: every placed part is cleared at round start (placement.md §1), and mid-round a part
		-- keeps PLACE_CLEAR from every living runner, so nobody is ever walled in where they stand.
		local list = {}
		for k = 1, #map.anchors do
			local s = reachStands[k]
			table.insert(list, { s.name, s.x, s.y })
		end
		local f, n = MC.filled(g, Maps.static(map))
		local problems, reached = MC.joined(f, MC.targets(map, {}, list))
		print(("MAPFILE map_%s_filled\n%s\nENDMAP"):format(name, MC.picture(f, reached, xs)))
		assert(#problems == 0, name .. " (every open passage filled): " .. table.concat(problems, "; "))
		print(("    %s: %d passage tiles fillable, every place still joined both ways"):format(name, n))
	end
end

do -- the map rule's test has teeth: drop the Yard's keep-clear zones and a filled shaft seals a corner ledge's orb
	local map = table.clone(Maps.ALL.yard)
	map.keepClear = {}
	local g = MC.grid(map)
	local f = MC.filled(g, Maps.static(map))
	local problems = MC.joined(f, MC.targets(map, startXs(map), {}))
	assert(#problems > 0, "without its keep-clear zones the Yard can be sealed (the check is not vacuous)")
	print("    mutation: no keep-clear zones -> " .. problems[1])
end

do -- Maps.get falls back to the Yard (a typo in Config must not leave the server mapless); orbs: ghost ones first
	assert(Maps.get("nope") == Maps.ALL.yard and Maps.get(nil) == Maps.ALL.yard, "unknown map: the Yard")
	local o = Maps.orbs(Maps.ALL.yard)
	assert(#o == 6 and o[1].kind == "ghost" and o[4].kind == "living", "ghost spots first, then living")
	assert(Maps.get(Config.MAP) == Maps.ALL[Config.MAP], "Config.MAP names a real map")
end
