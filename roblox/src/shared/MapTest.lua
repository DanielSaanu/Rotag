--!strict
-- The first-playable test map (H1-H26), kept as a map so any system can be checked against the arena it was built on:
-- set Config.MAP = "test". Pure data in the format of shared/Maps.lua; the reasoning behind each spot is in git at
-- 7df4ac3 (server/Arena.lua) and docs/systems/maps.md §5. Heights are picked against the measured jump (movement.md):
-- a full jump clears 3.5 tiles, a full jump plus the double jump about 7.
local Config = require(script.Parent.Config)

local T = Config.STUDS_PER_TILE
local ORB_UP = Config.ORB_SIZE / 2 + 1.5 -- an orb's centre above the floor it sits on

return {
	name = "test",
	blocks = {
		{ "Floor", -20 * T, -2 * T, 30 * T, 0 },
		{ "EndWallLeft", -21 * T, -2 * T, -20 * T, 20 * T },
		{ "EndWallRight", 30 * T, -2 * T, 31 * T, 20 * T },
		{ "Roof", -21 * T, 20 * T, 31 * T, 22 * T }, -- H39: a lid on the end walls: nobody leaves over the top
		{ "PlatformLow", 3 * T, 2 * T - 1, 7 * T, 2 * T }, -- 2 tiles up: a hop
		{ "PlatformMid", 9 * T, 5 * T - 1, 12 * T, 5 * T }, -- 3 tiles above the low one: a full jump from it
		{ "PlatformHigh", -8 * T, 3 * T - 1, -4 * T, 3 * T }, -- a ledge to walk off (coyote) and dash off
		-- Two walls three tiles apart to wall-jump between; the right one is lower so you can climb out over it.
		{ "WallLeft", 18 * T, 0, 19 * T, 9 * T },
		{ "WallRight", 22 * T, 0, 23 * T, 7 * T },
	},
	spawn = { x = 0, y = 0 },
	window = { lo = -20 * T, hi = 30 * T }, -- the end walls' inner faces (H26)
	ghostOrbs = { -- H18: the left floor, PlatformMid, the floor past the wall-jump walls
		{ x = -10 * T, y = ORB_UP, kind = "ghost" },
		{ x = 10.5 * T, y = 5 * T + ORB_UP, kind = "ghost" },
		{ x = 26 * T, y = ORB_UP, kind = "ghost" },
	},
	livingOrbs = { -- H19: the dummies' patrol lane (x 12-52), PlatformHigh, the far left floor
		{ x = 8 * T, y = ORB_UP, kind = "living" },
		{ x = -6 * T, y = 3 * T + ORB_UP, kind = "living" },
		{ x = -16 * T, y = ORB_UP, kind = "living" },
	},
	-- H22: the one corridor, the wall-jump shaft, from a tile before WallLeft to a tile past WallRight, floor to 3 tiles
	-- above WallLeft's top.
	keepClear = {
		{ 17 * T, 0, 24 * T, 12 * T, "keep-clear" },
		-- H27 (rule 48's worst case, maps.test): the 4-tile gap under PlatformMid, from PlatformLow's end to a tile past
		-- PlatformMid, is a corridor under 5 tiles; filled, it walled in the patrol-lane orb (x 32).
		{ 7 * T, 0, 13 * T, 4 * T, "keep-clear" },
	},
	anchors = { -- H25 (grapple.md §5): 5-11 tiles up, 22-48 studs apart, each under the banner from its stands
		{ x = -14 * T, y = 5 * T },
		{ x = -2 * T, y = 5.5 * T },
		{ x = 8 * T, y = 7.5 * T },
		{ x = 15 * T, y = 5.5 * T },
		{ x = 20.5 * T, y = 11 * T },
		{ x = 26.5 * T, y = 5 * T },
	},
	pads = {},
	top = 20 * T,
}
