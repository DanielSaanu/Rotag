--!strict
-- The maps (H27, PR 6; DESIGN §3 rules 25-30 and 48, §6.8; docs/systems/maps.md). Pure Luau: each map is a data
-- module (shared/MapYard.lua, shared/MapTest.lua) and this file is the format, the registry and what is derived from
-- a map (the orb list, the static boxes nothing may be placed over). server/Arena picks `Config.MAP` and builds it;
-- test/luau/maps.test.luau holds every map to the map rule (reachable, no dead ends, no sealing, the window inside).
-- Units are studs; one tile is Config.STUDS_PER_TILE. The floor's top is y = 0 (the Studio dummies walk on it).
local Config = require(script.Parent.Config)
local MapYard = require(script.Parent.MapYard)
local MapTest = require(script.Parent.MapTest)

local Maps = {}

export type Block = { any } -- { name, x0, y0, x1, y1 }: a solid map part
export type Spot = { x: number, y: number, kind: string } -- an orb's centre; kind "ghost" | "living"
export type Map = {
	name: string,
	blocks: { Block },
	spawn: { x: number, y: number }, -- the start line's centre (feet on the floor); runners spread START_SPREAD round it
	window: { lo: number, hi: number }, -- the closing walls' bounds, world x (the end walls' inner faces; H26)
	ghostOrbs: { Spot },
	livingOrbs: { Spot },
	keepClear: { { any } }, -- { x0, y0, x1, y1, "keep-clear" }: every exit and corridor (rule 48)
	anchors: { { x: number, y: number } }, -- the grapple anchors (rule 17), numbered by their place in the list
	pads: { { x: number, y: number } }, -- map boost pads (§2 kit): x the centre, y the floor top they sit on
	top: number, -- the highest y a runner can matter at (the map checks' grid stops here)
}

Maps.ALL = { yard = MapYard :: Map, test = MapTest :: Map }
Maps.NAMES = { "yard", "test" } -- a fixed order for tests and logs

-- The map `name`, or the Yard if there is none by that name (a typo in Config must not leave the server mapless).
function Maps.get(name: string?): Map
	return Maps.ALL[name or ""] or Maps.ALL.yard
end

-- Every orb spot the server runs: ghost ones first (the indices clients see), then the living ones.
function Maps.orbs(m: Map): { Spot }
	local out = table.clone(m.ghostOrbs)
	for _, s in m.livingOrbs do table.insert(out, s) end
	return out
end

-- What no ghost part may cover (DESIGN §3 rules 47-48, placement.md §1): every map block, every keep-clear zone, an
-- orb box over each orb spot (the orb must stay reachable) and a 4-stud box over each anchor (H25). Map pads are not
-- here: they are placed things in server/Placement's state, which the fit test already reads.
function Maps.static(m: Map): { { any } }
	local out = {}
	for _, b in m.blocks do table.insert(out, { b[2], b[3], b[4], b[5], "map" }) end
	for _, z in m.keepClear do table.insert(out, z) end
	local o = Config.ORB_SIZE / 2
	for _, s in Maps.orbs(m) do table.insert(out, { s.x - o, s.y - o, s.x + o, s.y + o, "orb" }) end
	for _, a in m.anchors do table.insert(out, { a.x - 2, a.y - 2, a.x + 2, a.y + 2, "anchor" }) end
	return out
end

return Maps
