-- The maps (H27, PR 6; DESIGN §3 rules 25-29, 48, §6.8; docs/systems/maps.md). Every map in shared/Maps is held to:
-- its data is well formed, every place is joined to the spawn both ways (no dead ends), rule 48's map rule (no
-- passage left open to a part can seal anything, however many parts), and the closing walls stay inside its window.
local Config = __require("Config")
local Maps = __require("Maps")
local Grapple = __require("Grapple")
local Tag = __require("Tag")
local Walls = __require("Walls")
local Movement = __require("Movement")
--!include map_check.luau
--!include movement_world.luau

local T = Config.STUDS_PER_TILE

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

	do -- rule 28 (QA round 1): every deck is on screen from a stand under it, below the HUD banner. From feet at y the
		-- view reaches y + CAMERA_Y_OFFSET + half the view; the banner takes GRAPPLE_INSET_TOP of that (grapple.md §5).
		-- A deck is a block wider than tall above the floor; a stand is any block top (the floor included) within the
		-- 4:3 screen's half width of it.
		local clear = Config.CAMERA_Y_OFFSET + Config.CAMERA_VIEW_HEIGHT / 2 - Config.GRAPPLE_INSET_TOP - 1
		local halfW = Config.CAMERA_VIEW_HEIGHT / 2 * 4 / 3
		for _, b in map.blocks do
			if b[4] - b[2] > b[5] - b[3] and b[5] > 0 then
				local seen = false
				for _, c in map.blocks do
					local up = b[5] - c[5]
					if up > 0 and up <= clear and b[2] < c[4] + halfW and c[2] - halfW < b[4] then seen = true break end
				end
				assert(seen, ("%s: %s (top %g) is on screen under the banner from a stand below it"):format(name, b[1], b[5]))
			end
		end
	end

	do -- corridors are entered on foot (QA round 1: the shafts were pits, one exit, rule 48's "2+ exits"): from the
		-- spawn with run and jumps only, some floor tile of every keep-clear zone is reached; and a shaft is a climb:
		-- inside the zone alone, its top row is reached from its floor with wall jumps and not without
		local si, sj = MC.tileOf(map.spawn.x, map.spawn.y)
		local onFoot = MC.reach(g, si, sj, true)
		for _, z in map.keepClear do
			local i0, j0 = MC.tileOf(z[1], z[2])
			local i1, j1 = MC.tileOf(z[3] - 1e-6, z[4] - 1e-6)
			local floor = nil
			for i = i0, i1 do
				if not MC.isSolid(g, i, j0) and MC.isSolid(g, i, j0 - 1) and MC.has(g, onFoot, i, j0) then floor = i break end
			end
			assert(floor, ("%s: the corridor at x %g..%g is walked into from the spawn (no wall jump)"):format(name, z[1], z[3]))
			if j1 - j0 >= 2 * MC.UP then -- tall enough to be a shaft: inside the zone alone, a wall-jump climb, not a jump
				local only = { i0 = g.i0, i1 = g.i1, w = g.w, rows = g.rows, solid = table.clone(g.solid), map = g.map }
				for j = 0, g.rows - 1 do
					for i = g.i0, g.i1 do
						if i < i0 or i > i1 or j < j0 or j > j1 then only.solid[j * g.w + (i - g.i0)] = true end
					end
				end
				local kicks, none = MC.reach(only, floor, j0), MC.reach(only, floor, j0, true)
				local top, topNoKick = false, false
				for i = i0, i1 do
					if MC.has(g, kicks, i, j1) then top = true end
					if MC.has(g, none, i, j1) then topNoKick = true end
				end
				assert(top and not topNoKick, ("%s: the shaft at x %g..%g is climbed from its floor by wall jumps only"):format(name, z[1], z[3]))
			end
		end
	end

	do -- the map pads (§2 kit) earn their place (QA round 1: none reached its deck): driven through the real Movement
		-- in this map's blocks. Entering a pad launches the way you run (PAD_SPEED_X / _Y, placement.md); with the
		-- refreshed double jump pressed at the apex, at least one way lands you a tier up, with the arc uncut (no
		-- ceiling); and the other way, with no jump, the pad's own arc is uncut too (no head bonk on a deck above).
		local world = {}
		for _, b in map.blocks do table.insert(world, { b[2], b[3], b[4], b[5] }) end
		local function fly(p, dir, doubleJump)
			local s = Movement.new(p.x, p.y + HH)
			frames(world, s, 2)
			assert(s.grounded, ("%s: a runner stands on the pad at (%g, %g)"):format(name, p.x, p.y))
			local peak, apexed = p.y, false
			for f = 1, 240 do
				local inp = input({ moveX = dir, held = apexed })
				if f == 1 then inp.launchX, inp.launchY = dir * Config.PAD_SPEED_X, Config.PAD_SPEED_Y end
				if doubleJump and f > 1 and not apexed and s.vy <= 0 then apexed = true inp.jumpPressed, inp.jumpHeld = true, true end
				tick(world, s, inp)
				peak = math.max(peak, s.y - HH)
				if s.grounded and f > 2 then return s.y - HH, peak, s.x end
			end
			error(("%s: the pad at (%g, %g) never lands (dir %d)"):format(name, p.x, p.y, dir))
		end
		for _, p in map.pads do
			local up = false
			for _, dir in { -1, 1 } do
				local _, peak0 = fly(p, dir, false)
				assert(peak0 >= p.y + 11, ("%s: pad (%g, %g) dir %d: its own arc is uncut (peak +%.1f)"):format(name, p.x, p.y, dir, peak0 - p.y))
				local land, peak, x = fly(p, dir, true)
				if land >= p.y + 5 * T - 0.5 then
					assert(peak >= p.y + 25, ("%s: pad (%g, %g) dir %d: the arc to the deck is uncut (peak +%.1f)"):format(name, p.x, p.y, dir, peak - p.y))
					up = true
					print(("    %s: pad (%g, %g) running %s lands %.1f up at x %.1f"):format(name, p.x, p.y, if dir < 0 then "left" else "right", land - p.y, x))
				end
			end
			assert(up, ("%s: the pad at (%g, %g) lands you a tier up one way or the other"):format(name, p.x, p.y))
		end
	end

	do -- the anchors earn their place (H29; QA round 1 could not verify a swing): from some deck edge in reach, running
		-- off it, hooking the anchor and letting go somewhere along the swing (at once, 2 / 4 / 6 tiles past the
		-- anchor, or at the swing's turn; then a double jump or not), the runner lands on ANOTHER deck, never the floor
		-- (a swing-drop onto a lower deck counts: it is aimed at something). Driven through the real Movement and
		-- Grapple in this map's blocks (the pick is grapple.test's). The print names the highest landing found.
		-- Measured on the way: a release's air speed decays to the run within ~0.5 s, so a swing carries ~10 tiles;
		-- an anchor centred over a gap of 6 to 10 tiles carries both ways, one over 12 does not.
		local world = {}
		for _, b in map.blocks do table.insert(world, { b[2], b[3], b[4], b[5] }) end
		local function landing(s)
			for _, b in map.blocks do
				if s.x + 1 > b[2] and s.x - 1 < b[4] and math.abs((s.y - HH) - b[5]) < 0.6 then return b end
			end
			return nil
		end
		local function swing(x0, top, dir, a, past, jump)
			local s = Movement.new(x0, top + HH)
			frames(world, s, 2)
			local hooked, released, jumped = false, false, false
			for f = 1, 600 do
				local inp = input({ moveX = dir })
				if not released and (not s.grounded or hooked) then
					inp.grappleHeld, inp.grapplePressed, inp.anchor = true, not hooked, { x = a.x, y = a.y, id = 1 }
				end
				if hooked and s.rope and ((past and (s.x - a.x) * dir >= past * T) or (not past and s.vx * dir < 0)) then
					inp.grappleHeld, released = false, true
				end
				if released and jump and not jumped and s.vy <= 0 and not s.grounded then
					inp.jumpPressed, inp.jumpHeld, jumped = true, true, true
				end
				local ev = tick(world, s, inp)
				if ev.grapple == "attach" then hooked = true end
				if hooked and not s.rope then released = true end -- a wall or roof broke the rope: that was the release
				if hooked and released and s.grounded and f > 3 then return landing(s) end
			end
			return nil
		end
		-- The test map keeps its H25 anchors as the arena the grapple was tuned on (maps.md §5), stands only: not held.
		for k, a in if name == "test" then {} else map.anchors do
			local carries, top = nil, -1
			for _, b in map.blocks do
				if b[4] - b[2] > b[5] - b[3] and b[5] > 0 then
					for _, e in { { b[2] + 1, -1 }, { b[4] - 1, 1 } } do -- off the left edge running left, and the right one right
						local dx, dy = a.x - e[1], a.y - (b[5] + HH)
						if dx * e[2] > 0 and dy >= Config.GRAPPLE_MIN_ABOVE and dx * dx + dy * dy <= Config.GRAPPLE_RANGE ^ 2 then
							for _, past in { 0, 2, 4, 6, false } do
								for _, jump in { false, true } do
									local on = swing(e[1], b[5], e[2], a, past or nil, jump)
									if on and on ~= b and on[5] > 0 and on[5] > top then
										top, carries = on[5], ("%s -> %s"):format(b[1], on[1])
									end
								end
							end
						end
					end
				end
			end
			assert(carries, ("%s: anchor %d (%g, %g) carries a swing from a deck edge onto another deck"):format(name, k, a.x, a.y))
			print(("    %s: anchor %d: %s"):format(name, k, carries))
		end
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
