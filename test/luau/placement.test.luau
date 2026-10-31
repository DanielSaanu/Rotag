-- Ghost parts: fixtures (tetrominoes) and boost pads, DESIGN §3 rules 15, 47, 48 (H16 spec, built H22),
-- shared/Placement.lua. docs/systems/placement.md has the reasoning; each block names the rule it pins.
local Config = __require("Config")
local Placement = __require("Placement")

local T = Config.STUDS_PER_TILE
local Y = Config.RUNNER_HEIGHT / 2 -- a runner standing on a floor at y = 0
local A, B, C = 101, 202, 303
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local function fixed(v) return function() return v end end
local buf = {}
local runners = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
local function rowsOf(list) -- fill the reused runner rows, return how many are in use
	for i, r in list do runners[i][1], runners[i][2], runners[i][3] = r[1], r[2], r[3] end
	return #list
end
local function fitsAt(st, item, shape, rot, left, bottom, static, list)
	local n = Placement.boxesInto(buf, item, shape, rot, left, bottom)
	return Placement.fits(st, buf, n, static or {}, runners, rowsOf(list or {}))
end

do -- the seven tetrominoes, four cells each in every rotation; rows cover the cells exactly
	assert(#Placement.SHAPES == 7, "seven shapes")
	for _, name in Placement.SHAPES do
		for r = 1, 4 do
			local sh = Placement.ROT[name][r]
			assert(#sh.cells == 8, name .. " has four cells in rotation " .. (r - 1))
			local area, seen = 0, {}
			for _, row in sh.rows do
				assert(row[4] - row[2] == 1, "a row is one tile tall")
				area += row[3] - row[1]
				for x = row[1], row[3] - 1 do
					local k = x .. "," .. row[2]
					assert(not seen[k], "rows never overlap")
					seen[k] = true
				end
			end
			assert(area == 4, name .. ": the rows cover four cells")
			for i = 0, 3 do
				local cx, cy = sh.cells[i * 2 + 1], sh.cells[i * 2 + 2]
				assert(seen[cx .. "," .. cy], "every cell is in a row")
				assert(cx >= 0 and cy >= 0 and cx < sh.w and cy < sh.h, "cells sit in the bounding box from (0, 0)")
			end
		end
	end
	local I = Placement.ROT.I
	assert(I[1].w == 4 and I[1].h == 1 and I[2].w == 1 and I[2].h == 4 and I[3].w == 4 and I[4].h == 4,
		"the I turns from flat to upright and back")
	assert(#I[1].rows == 1 and #I[2].rows == 4, "flat I is one part; upright, four stacked rows")
	local Tt = Placement.ROT.T
	assert(Tt[1].w == 3 and Tt[1].h == 2 and Tt[2].w == 2 and Tt[2].h == 3, "the T turns a quarter each step")
	-- S and Z, J and L are different pieces (no flip side-on): no rotation of one is the other
	local function key(sh) local k = {} for i = 1, #sh.cells do k[i] = sh.cells[i] end return table.concat(k, ",") end
	for _, pair in { { "S", "Z" }, { "J", "L" } } do
		for r = 1, 4 do
			for q = 1, 4 do
				local a, b = Placement.ROT[pair[1]][r], Placement.ROT[pair[2]][q]
				local same = a.w == b.w and a.h == b.h
				if same then
					local ka, kb = {}, {}
					for i = 0, 3 do ka[a.cells[i * 2 + 1] .. "," .. a.cells[i * 2 + 2]] = true end
					for i = 0, 3 do if not ka[b.cells[i * 2 + 1] .. "," .. b.cells[i * 2 + 2]] then same = false end end
				end
				assert(not same, pair[1] .. " never equals a turned " .. pair[2])
			end
		end
	end
	assert(key(Placement.ROT.O[1]) ~= "" and Placement.ROT.O[2].w == 2, "the O is the O every way")
	assert(Placement.rollShape(fixed(0)) == "I" and Placement.rollShape(fixed(0.999)) == "L"
		and Placement.rollShape(fixed(1)) == "L", "the roll covers all seven, a source returning 1 included")
	assert(Placement.valid("T", 3) and not Placement.valid("T", 4) and not Placement.valid("T", 1.5)
		and not Placement.valid("X", 0) and not Placement.valid(nil, 0) and not Placement.valid("T", -1),
		"a network shape and rotation are checked before use")
end

do -- proposal §5: where it goes. A fixture starts a tile past the ghost's front edge on the grid; a pad at its feet
	local left, bottom = Placement.spot("fixture", "I", 0, 10, Y, 1)
	assert(left == 16 and bottom == 0, ("facing right: near edge on the grid past 10 + 1 + 4; saw %g %g"):format(left, bottom))
	assert(left >= 10 + Config.RUNNER_WIDTH / 2 + Config.PLACE_GAP and left % T == 0, "never closer than a tile")
	left, bottom = Placement.spot("fixture", "I", 0, 10, Y, -1)
	assert(left + 4 * T == 4 and bottom == 0, "facing left: the far side, mirrored (right edge 4)")
	left = Placement.spot("fixture", "I", 1, 10, Y, -1)
	assert(left + T == 4, "an upright I is one tile wide: it still ends at the same edge")
	left, bottom = Placement.spot("pad", nil, 0, 10, Y, 1)
	assert(near(left, 10 - Config.PAD_W / 2) and bottom == 0, "a pad is centred where the ghost stands, on its floor")
	local _, hover = Placement.spot("fixture", "O", 0, 0, Y + 7, 1)
	assert(hover == 8, "mid-jump (feet at 7) the piece hovers on the nearest tile line (8): a ghost jumps to place high")
	_, hover = Placement.spot("fixture", "O", 0, 0, Y + 5, 1)
	assert(hover == 4, "feet at 5: the line at 4")
	_, hover = Placement.spot("fixture", "O", 0, 0, Y - 0.15, 1)
	assert(hover == 0, "a runner sunk 0.15 into the floor (the ground snap) still places flush on it")
	local n = Placement.boxesInto(buf, "fixture", "I", 0, 16, 0)
	assert(n == 4 and buf[1] == 16 and buf[3] == 20 and buf[13] == 28 and buf[16] == 4, "four 1-tile cells in a row")
	n = Placement.boxesInto(buf, "pad", nil, 0, 6, 0)
	assert(n == 1 and buf[3] - buf[1] == Config.PAD_W and buf[4] - buf[2] == Config.PAD_H, "a pad is one slab")
end

do -- rule 47: empty space only. Map, pieces, pads, orbs, spawns, keep-clear zones; a tile from every living runner
	local floor = { -100, -8, 100, 0, "map" }
	local st = Placement.new()
	assert(fitsAt(st, "fixture", "O", 0, 16, 0, { floor }), "on the floor: touching is not overlapping")
	local ok, why = fitsAt(st, "fixture", "O", 0, 16, -4, { floor })
	assert(not ok and why == "map", "into the floor: refused, and why: " .. tostring(why))
	ok, why = fitsAt(st, "fixture", "O", 0, 16, 0, { floor, { 20, 0, 28, 8, "keep-clear" } })
	assert(not ok and why == "keep-clear", "one cell in a keep-clear zone is enough to refuse")
	ok, why = fitsAt(st, "fixture", "O", 0, 16, 0, { { 17, 1, 18, 2, "orb" } })
	assert(not ok and why == "orb", "an orb spot under it")
	Placement.place(st, A, "fixture", "O", 0, 16, 0, 1, 0)
	ok, why = fitsAt(st, "fixture", "I", 1, 20, 4)
	assert(not ok and why == "a piece", "over another piece: refused")
	assert(fitsAt(st, "fixture", "I", 1, 24, 0), "beside it (touching): fits, so pieces stack and line up")
	assert(fitsAt(st, "fixture", "I", 0, 16, 8), "on top of it: fits")
	Placement.place(st, B, "pad", nil, 0, 40, 0, 1, 0)
	ok, why = fitsAt(st, "fixture", "O", 0, 44, 0)
	assert(not ok and why == "a pad", "over a pad: refused")
	-- runners: a living one keeps PLACE_CLEAR (a tile); a ghost only its own box (the caller passes margin 0)
	local m = Config.PLACE_CLEAR
	local edge = 160 - Config.RUNNER_WIDTH / 2 - m -- a cell's right edge here is exactly a tile clear of a runner at 160
	assert(fitsAt(st, "fixture", "O", 0, edge - 8 - 0.1, 0, {}, { { 160, Y, m } }), "a tile and a hair clear: fits")
	ok, why = fitsAt(st, "fixture", "O", 0, edge - 8 + 0.2, 0, {}, { { 160, Y, m } })
	assert(not ok and why == "a runner", "inside a tile of a living runner: refused")
	assert(fitsAt(st, "fixture", "O", 0, edge - 8 + 0.2, 0, {}, { { 160, Y, 0 } }), "a ghost there with margin 0: fits")
	ok = fitsAt(st, "fixture", "O", 0, 158, 0, {}, { { 160, Y, 0 } })
	assert(not ok, "but never over a ghost's own box (a solid piece would trap it)")
	ok = fitsAt(st, "fixture", "O", 0, 158, 0, {}, { { 0, 0, 0 }, { 160, Y, 0 } })
	assert(not ok, "every runner row is read, not only the first")
	-- the runner rows past `nr` are ignored: the buffer is reused frame to frame
	rowsOf({ { 160, Y, m } })
	ok = Placement.fits(st, buf, Placement.boxesInto(buf, "fixture", "O", 0, 158, 0), {}, runners, 0)
	assert(ok, "nr = 0 reads no runner row")
end

do -- rule 48, the map rule: nothing overlaps a keep-clear zone, so no stack of pieces from any number of ghosts can
	-- seal the corridor it marks (proposal §5: safe by construction, no path search). Fill a room greedily, every
	-- shape, rotation and grid spot, 30 ghosts; then the zone is still empty.
	local room = { { -40, -8, 40, 0, "map" }, { -44, -8, -40, 40, "map" }, { 40, -8, 44, 40, "map" },
		{ -44, 40, 44, 44, "map" } }
	local zone = { -4, 0, 4, 40, "keep-clear" } -- a 2-tile-wide shaft through the middle, floor to ceiling
	local static = table.clone(room)
	table.insert(static, zone)
	local st = Placement.new()
	local placed = 0
	for _, name in Placement.SHAPES do
		for rot = 0, 3 do
			for gx = -11, 10 do
				for gy = -1, 10 do
					if fitsAt(st, "fixture", name, rot, gx * T, gy * T, static) then
						Placement.place(st, placed // 3 + 1, "fixture", name, rot, gx * T, gy * T, 1, 0) -- a new ghost every 3
						placed += 1
					end
				end
			end
		end
	end
	assert(placed > 20, "the room really filled up: " .. placed)
	for _, p in st.placed do
		for k = 0, p.count - 1 do
			local x0, x1 = p.boxes[k * 4 + 1], p.boxes[k * 4 + 3]
			assert(x1 <= zone[1] + 1e-9 or x0 >= zone[3] - 1e-9, "no cell in the shaft")
		end
	end
	print(("    map rule: %d pieces from %d ghosts filled the room; the keep-clear shaft is still open"):format(placed,
		(placed + 2) // 3))
end

do -- rule 47: at most FIXTURE_CAP live fixtures per ghost; a 4th fades the oldest (solid FIXTURE_FADE more)
	local st = Placement.new()
	local older = Placement.place(st, C, "fixture", "O", 0, 300, 0, 1, -1) -- the oldest piece of all is another ghost's (→ Q5)
	local first = Placement.place(st, A, "fixture", "O", 0, 0, 0, 1, 0)
	Placement.place(st, A, "fixture", "O", 0, 8, 0, 1, 1)
	Placement.place(st, B, "fixture", "O", 0, 100, 0, 1, 1.5)
	local _, faded = Placement.place(st, A, "fixture", "O", 0, 16, 0, 1, 2)
	assert(faded == nil and Placement.live(st, A) == 3, "three live: no fade yet")
	local fourth
	fourth, faded = Placement.place(st, A, "fixture", "O", 0, 24, 0, 1, 3)
	assert(faded == first and first.fadeAt == 3 + Config.FIXTURE_FADE, "the 4th fades A's OLDEST, with the 1 s warning")
	assert(older.fadeAt == nil, "never another ghost's piece, however old")
	assert(Placement.live(st, A) == 3 and Placement.live(st, B) == 1, "three live again; B's are its own")
	assert(#Placement.step(st, 3 + Config.FIXTURE_FADE - 0.01) == 0, "still there (and solid) during the warning")
	local ok = fitsAt(st, "fixture", "O", 0, 0, 0)
	assert(not ok, "a fading piece still blocks placement until it goes")
	local gone = Placement.step(st, 3 + Config.FIXTURE_FADE)
	assert(#gone == 1 and gone[1] == first.n, "then it goes")
	assert(fourth.untilT == math.huge, "a fixture is permanent for the round")
	Placement.place(st, A, "fixture", "O", 0, 32, 0, 1, 5)
	local second
	for _, p in st.placed do if p.owner == A and p.left == 8 then second = p end end -- A's next oldest (C's older piece is index 1)
	assert(second and second.fadeAt == 5 + Config.FIXTURE_FADE, "a 5th fades the next oldest")
	for i = 1, 5 do Placement.place(st, A, "pad", nil, 0, 200 + i * 10, 0, 1, 5) end
	assert(Placement.live(st, A) == 3, "pads are not fixtures: no cap, they never fade a piece")
	gone = Placement.step(st, 5 + Config.PAD_LIFE)
	local pads = 0
	for _, p in st.placed do if p.item == "pad" then pads += 1 end end
	assert(pads == 0 and #gone >= 5, "a pad lasts PAD_LIFE (20 s)")
	assert(Placement.remove(st, fourth.n) and not Placement.remove(st, fourth.n), "remove once")
	-- a client mirror records the server's numbers
	local mirror = Placement.new()
	local p = Placement.record(mirror, 42, A, "fixture", "T", 2, 8, 4, -1, 0)
	assert(p.n == 42 and p.count == 4 and mirror.nextN == 42 and p.dir == -1, "a mirror keeps the server's number")
end

do -- rule 15: a pad launches along its arrow; who touches it (the client launches on ENTERING it)
	local vx, vy = Placement.launch(1)
	assert(vx == Config.PAD_SPEED_X and vy == Config.PAD_SPEED_Y, "right and up")
	vx = Placement.launch(-1)
	assert(vx == -Config.PAD_SPEED_X, "left")
	local st = Placement.new()
	local pad = Placement.place(st, A, "pad", nil, 0, 0, 0, 1, 0)
	assert(Placement.onPad(pad, 4, Y), "a runner standing on it touches it")
	assert(Placement.onPad(pad, 4, Y + Config.PAD_H - 0.1), "feet just inside its top")
	assert(not Placement.onPad(pad, 4, Y + Config.PAD_H + 0.1), "jumping over it: no")
	assert(not Placement.onPad(pad, -Config.RUNNER_WIDTH / 2 - 0.1, Y), "beside it: no")
	assert(Config.PAD_SPEED_Y <= 2 * Config.JUMP_SPEED and Config.PAD_SPEED_X <= Config.DASH_SPEED,
		"the launch stays inside the speed check's rates (move_check.test pins the honest pad chain)")
end

print("placement ok")
