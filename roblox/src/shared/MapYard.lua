--!strict
-- The Yard (H27, the first real map; ghosts-v2-proposal.md §6.2, docs/systems/maps.md §3; relaid H29 for route choice).
-- Danzo's brief (2026-11-11): "plenty of routes, feels fun, a plethora of options on where to go". So every place
-- has three or more ways out, each a different move (a jump, a drop, a swing, a pad, a shaft, a stair), and the two
-- ends are not mirrors: the left end (the Dock) climbs by shaft, pad or double jump; the right end (the Stairs)
-- climbs by shaft, a stair of single jumps or double jump. Four tiers: floor 0, mid 5, high 10, the Mast at 15 over
-- the centre (the sky route: two perches joined by one swing under the lantern, each with a swing-drop out onto a
-- high deck; a fall lands on the crown or the hub, the slower route, rule 28). Every pad arc and every swing was
-- driven through the real Movement (maps.test): a pad lands 12 tiles out and a deck nearer than 8 is a head-bonk;
-- a swing carries ~10 tiles, so anchors sit centred over gaps of 6 to 10 (QA round 1's pads and swings reached
-- nothing). Each tier is a double jump (7 tiles measured) above the last and ON SCREEN from it under the HUD banner
-- (the view reaches 7 tiles up, the banner takes the top 1.5). No high deck sits over a mid deck except the crown
-- over the hub (rule 26: no open centre) and the Mast over the hub's ends: a stacked strip under 5 tiles is a
-- corridor parts could fill (rule 48, maps.test's worst case). 88 x 24 tiles (352 x 96 studs): wide, not tall, so
-- the closing walls' horizontal box still forces the duel (maps.md §4). Pure data in the format of shared/Maps.lua;
-- maps.test holds it to reach, no dead ends, no sealing, the pads' arcs, the swings and the view.
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
		-- THE DOCK (left): a shaft (the end wall and a pillar 3 tiles apart) up to the ledge. The pillar hangs from
		-- 4 tiles, so the shaft is walked into from the floor, and the end pad's hop fits under it into the shaft
		block("PillarLeft", -41, 4, -40, 10),
		deck("HighLeft", -40, -33, 10), -- the shaft's ledge; its far end drops to MidLeft or the floor
		block("CoverLeft", -34, 0, -32, 2), -- a crate-sized block to hop (rule 25: walls in easy reach)
		deck("MidLeft", -29, -20, 5), -- the quay: the end pad's landing (9 to 17 tiles out); not under the ledge
		deck("HighLeft2", -20, -13, 10), -- the high route's left stand; the hub pad's landing
		deck("MidLeft2", -13, -8, 5), -- a 3-tile hole to the hub: a drop
		-- THE CENTRE: the hub over the start line, the crown over the hub, the Mast's two perches over the hub's ends
		deck("Hub", -5, 5, 5),
		deck("Crown", -3, 3, 10),
		deck("MastLeft", -8, -4, 15),
		deck("MastRight", 4, 8, 15),
		-- THE STAIRS (right): a 5-tile room to the hub (never filled), two mid decks a jump apart, then a stair of
		-- single jumps (5 -> 8 -> 10) up to the ledge beside the shaft
		deck("MidRight2", 10, 15, 5),
		deck("HighRight2", 15, 20, 10), -- the high route's right stand
		deck("MidRight", 20, 29, 5), -- the end pad's landing (9 to 17 tiles out)
		deck("StepRight", 31, 33, 8), -- a single jump up from MidRight...
		deck("HighRight", 34, 40, 10), -- ... and another onto the ledge
		block("CoverRight", 31, 0, 33, 2),
		block("PillarRight", 40, 4, 41, 10),
	},
	spawn = { x = 0, y = 0 },
	window = { lo = -44 * T, hi = 44 * T }, -- the end walls' inner faces: the box never wanders into them (H26)
	ghostOrbs = { -- two on the open floor (the Studio dummy ghosts reach only the floor), one on the Mast (the prize)
		{ x = -16 * T, y = ORB_UP, kind = "ghost" },
		{ x = -6 * T, y = 15 * T + ORB_UP, kind = "ghost" },
		{ x = 17.5 * T, y = ORB_UP, kind = "ghost" },
	},
	livingOrbs = { -- one in the dummies' patrol lane (x 12-52 studs) for solo tests, one on each side's mid or high
		{ x = 7.5 * T, y = ORB_UP, kind = "living" },
		{ x = -25 * T, y = 5 * T + ORB_UP, kind = "living" },
		{ x = 17.5 * T, y = 10 * T + ORB_UP, kind = "living" },
	},
	-- Rule 48: every corridor (a passage under 5 tiles across) that must stay open is keep-clear. The two shafts, from
	-- the end wall to a tile past the pillar, floor (the walk-in under the pillar) to 3 tiles over its top; and the
	-- start line under the hub with its hole (the strip under a mid deck is 4 tiles tall, a corridor; filled it would
	-- wall the spawn in). Under the other decks parts may fill the strip: maps.test proves everything stays joined.
	keepClear = {
		{ -44 * T, 0, -39 * T, 13 * T, "keep-clear" },
		{ 39 * T, 0, 44 * T, 13 * T, "keep-clear" },
		{ -8 * T, 0, 5 * T, 4 * T, "keep-clear" },
	},
	anchors = { -- rule 17 (grapple.md §5): each under the HUD banner from a stand in reach (grapple.test)
		{ x = -26 * T, y = 13 * T }, -- the high route: HighLeft <-> HighLeft2, over MidLeft (short: MidLeft)
		{ x = -16.5 * T, y = 8 * T }, -- the mid route: MidLeft <-> MidLeft2, under HighLeft2
		{ x = -12 * T, y = 17.5 * T }, -- off MastLeft: a swing-drop out onto HighLeft2 (out of reach from below, so never hidden under the banner)
		{ x = 0, y = 19 * T }, -- the Mast's lantern: MastLeft <-> MastRight, let go at the top of the swing
		{ x = 12 * T, y = 17.5 * T }, -- off MastRight: a swing-drop out onto HighRight2
		{ x = 17.5 * T, y = 8 * T }, -- the mid route: MidRight2 <-> MidRight, under HighRight2
		{ x = 26 * T, y = 13 * T }, -- the high route: HighRight2 -> HighRight, over MidRight (short: StepRight)
	},
	-- Map boost pads (DESIGN §2 kit), permanent. H30's launch (115 across ramped, 120 up, the glide) with the double
	-- jump at its apex is above 5 tiles from 9 to 16 tiles out, peaks 7.3 at 12, and lands ~17 out (maps.test
	-- measures it), so a deck it feeds starts 9 tiles out (nearer is a head-bonk at the apex) and reaches past 17.
	-- The end pads: inward onto MidLeft / MidRight, outward a hop under the pillar into the shaft. The hub pad feeds
	-- HighLeft2 (left) and is a plain hop under the crown (right).
	pads = {
		{ x = -38 * T, y = 0 },
		{ x = 38 * T, y = 0 },
		{ x = -3 * T, y = 5 * T },
	},
	top = 24 * T,
}
