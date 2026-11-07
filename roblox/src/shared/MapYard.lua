--!strict
-- The Yard (H27, the first real map; ghosts-v2-proposal.md §6.2, docs/systems/maps.md §3): open, wide floors broken by
-- islands and grapple anchors, map boost pads, a crown over the centre so the middle is never an open field (rule 26),
-- and two wall-jump shafts at the ends up to corner ledges you leave by dropping (one-way drops, rule 26). Three tiers
-- (floor 0, mid 6, high 12 tiles): each is a double jump (7 tiles measured) above the last and on screen from it
-- (rule 28: the high route is seen from the low one). 88 x 24 tiles (352 x 96 studs): wide, not tall, so the closing
-- walls' horizontal box still forces the duel (maps.md §4). Pure data in the format of shared/Maps.lua.
local Config = require(script.Parent.Config)

local T = Config.STUDS_PER_TILE
local ORB_UP = Config.ORB_SIZE / 2 + 1.5 -- an orb's centre above the floor it sits on

-- A one-stud-thick platform with its top at `top` tiles, from x0 to x1 tiles.
local function deck(name: string, x0: number, x1: number, top: number): { any }
	return { name, x0 * T, top * T - 1, x1 * T, top * T }
end
local function block(name: string, x0: number, y0: number, x1: number, y1: number): { any }
	return { name, x0 * T, y0 * T, x1 * T, y1 * T }
end

return {
	name = "yard",
	blocks = {
		block("Floor", -45, -2, 45, 0),
		block("EndWallLeft", -45, -2, -44, 24),
		block("EndWallRight", 44, -2, 45, 24),
		-- the left end: a shaft (the end wall and a pillar 3 tiles apart) up to the corner ledge
		block("PillarLeft", -41, 0, -40, 10),
		deck("HighLeft", -40, -33, 12),
		deck("MidLeft", -38, -30, 6),
		block("CoverLeft", -34, 0, -32, 2), -- a crate-sized block to hop (rule 25: walls in easy reach)
		deck("StepLeft", -26, -22, 3),
		deck("HighLeft2", -27, -21, 12),
		deck("MidLeft2", -20, -11, 6),
		-- the centre: the hub over the start line and the crown above it
		deck("Hub", -5, 5, 6),
		deck("Crown", -3, 3, 12),
		-- the right end
		deck("MidRight2", 11, 20, 6),
		block("CoverRight", 23, 0, 25, 2),
		deck("HighRight2", 21, 28, 12),
		deck("MidRight", 30, 38, 6),
		deck("HighRight", 33, 40, 12),
		block("PillarRight", 40, 0, 41, 10),
	},
	spawn = { x = 0, y = 0 },
	window = { lo = -44 * T, hi = 44 * T }, -- the end walls' inner faces: the box never wanders into them (H26)
	ghostOrbs = { -- two on the floor (the Studio dummy ghosts reach only those), one on the crown (the high route)
		{ x = -36 * T, y = ORB_UP, kind = "ghost" },
		{ x = 0, y = 12 * T + ORB_UP, kind = "ghost" },
		{ x = 36 * T, y = ORB_UP, kind = "ghost" },
	},
	livingOrbs = { -- one in the dummies' patrol lane (x 12-52 studs) for solo tests, one per tier on the sides
		{ x = 10 * T, y = ORB_UP, kind = "living" },
		{ x = -34 * T, y = 6 * T + ORB_UP, kind = "living" },
		{ x = 24.5 * T, y = 12 * T + ORB_UP, kind = "living" },
	},
	-- Rule 48: every corridor (a passage under 5 tiles across) is keep-clear. The Yard's only ones are the two shafts:
	-- from the end wall to a tile past the pillar, floor to 3 tiles over the pillar's top (maps.test proves the rest
	-- of the map stays joined however many parts are placed everywhere else).
	keepClear = {
		{ -44 * T, 0, -39 * T, 13 * T, "keep-clear" },
		{ 39 * T, 0, 44 * T, 13 * T, "keep-clear" },
	},
	anchors = { -- rule 17 (grapple.md §5): each under the HUD banner from a stand in reach (grapple.test)
		{ x = -25 * T, y = 8.75 * T }, -- over the mid gap between MidLeft and MidLeft2 (low enough to show from StepLeft)
		{ x = -8.5 * T, y = 5 * T }, -- off the floor beside the hub: swing up onto it
		{ x = 8 * T, y = 9.5 * T }, -- the mid gap between the hub and MidRight2
		{ x = 25.5 * T, y = 9.5 * T }, -- the mid gap between MidRight2 and MidRight
		{ x = -15 * T, y = 15.5 * T }, -- the high route, HighLeft2 to the crown in two swings
		{ x = -8 * T, y = 15.5 * T },
		{ x = 9 * T, y = 15.5 * T }, -- ... and the crown to HighRight2
		{ x = 15.5 * T, y = 15.5 * T },
	},
	pads = { -- map boost pads (DESIGN §2 kit), permanent: two on the floor up to the mid tier, one on the hub to the crown
		{ x = -28 * T, y = 0 },
		{ x = 27 * T, y = 0 },
		{ x = -4 * T, y = 6 * T },
	},
	top = 24 * T,
}
