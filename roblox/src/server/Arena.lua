-- The first-playable test map: plain Parts in Workspace.Map, built at boot (docs/systems/movement.md, "The map").
-- Workspace.Map is a Folder made HERE, not in default.project.json: nothing in the project file declares it and the
-- client never waits for it by name (it raycasts against everything but its own character).
-- Units are studs; one tile is Config.STUDS_PER_TILE. Every part spans the plane z = 0 with MAP_DEPTH of thickness.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Arena = {}

local MAP_DEPTH = 8
local T = Config.STUDS_PER_TILE

-- {name, left x, bottom y, right x, top y}. The floor's top is y = 0. Heights are picked against the measured jump
-- (movement.md): a full jump clears 3.5 tiles, a full jump plus the double jump about 7.
local BLOCKS = {
	{ "Floor", -20 * T, -2 * T, 30 * T, 0 },
	{ "EndWallLeft", -21 * T, -2 * T, -20 * T, 20 * T },
	{ "EndWallRight", 30 * T, -2 * T, 31 * T, 20 * T },
	{ "PlatformLow", 3 * T, 2 * T - 1, 7 * T, 2 * T }, -- 2 tiles up: a hop
	{ "PlatformMid", 9 * T, 5 * T - 1, 12 * T, 5 * T }, -- 3 tiles above the low one: a full jump from it
	{ "PlatformHigh", -8 * T, 3 * T - 1, -4 * T, 3 * T }, -- a ledge to walk off (coyote) and dash off
	-- Two walls three tiles apart to wall-jump between; the right one is lower so you can climb out over it.
	{ "WallLeft", 18 * T, 0, 19 * T, 9 * T },
	{ "WallRight", 22 * T, 0, 23 * T, 7 * T },
}

Arena.SPAWN = Vector3.new(0, Config.RUNNER_HEIGHT / 2 + 0.05, 0)

-- H18 (DESIGN §3 rule 42): three ghost-orb spots, each orb's centre ORB_SIZE / 2 + 1.5 above a floor: on the left floor,
-- on PlatformMid (a jump from PlatformLow), and on the floor past the wall-jump walls. The Studio dummies stay on the
-- floor, so they only ever reach the two floor ones (server/Bots).
local ORB_UP = Config.ORB_SIZE / 2 + 1.5
Arena.GHOST_ORBS = {
	{ x = -10 * T, y = ORB_UP, kind = "ghost" },
	{ x = 10.5 * T, y = 5 * T + ORB_UP, kind = "ghost" },
	{ x = 26 * T, y = ORB_UP, kind = "ghost" },
}
-- H19 (rules 42, 43): three living-orb spots: on the floor in the dummies' patrol lane (x 12-52, so a solo test sees
-- dummies take and use living items), on PlatformHigh, and on the floor at the far left.
Arena.LIVING_ORBS = {
	{ x = 8 * T, y = ORB_UP, kind = "living" },
	{ x = -6 * T, y = 3 * T + ORB_UP, kind = "living" },
	{ x = -16 * T, y = ORB_UP, kind = "living" },
}
Arena.ORBS = table.clone(Arena.GHOST_ORBS) -- every spot server/Orbs runs: ghost ones first (the indices clients see)
for _, s in Arena.LIVING_ORBS do table.insert(Arena.ORBS, s) end

-- H22 (DESIGN §3 rules 47-48, docs/systems/placement.md §3): what a ghost's part may never cover. The keep-clear zone
-- is the test map's one corridor, the wall-jump shaft: from a tile before WallLeft's face to a tile past WallRight,
-- floor to 3 tiles above WallLeft's top, so no stack of pieces can cap the climb or seal the far side. An orb box over
-- each orb spot (the orb must stay reachable), and every map block. No spawn boxes: every placed part is cleared at
-- round start, so a spawn spot needs no protection mid-round (QA round 1). { x0, y0, x1, y1, why }, studs.
Arena.KEEP_CLEAR = { { 17 * T, 0, 24 * T, 12 * T, "keep-clear" } }

-- H25 (DESIGN §3 rules 17, 29; docs/systems/grapple.md §5): the grapple anchors, { x, y } studs, numbered by their
-- place in this list (the snapshot's anchor byte). Over open floor and the gaps, 3-11 tiles up, 22-36 studs apart so
-- one swing's release reaches the next. Built as gold marked balls tagged ANCHOR_TAG; clients read them from the
-- workspace (no remote). PR 6 carries a list per map.
Arena.ANCHOR_TAG = "RotagAnchor"
Arena.ANCHORS = {
	{ x = -14 * T, y = 5 * T }, -- the open floor left of PlatformHigh
	{ x = -1 * T, y = 6 * T }, -- over the spawn, between PlatformHigh and PlatformLow
	{ x = 8 * T, y = 8 * T }, -- over the gap from PlatformLow up to PlatformMid
	{ x = 15 * T, y = 6 * T }, -- over the floor between PlatformMid and the wall-jump shaft
	{ x = 20.5 * T, y = 11 * T }, -- above the shaft
	{ x = 26.5 * T, y = 5 * T }, -- the floor past the shaft
}
function Arena.static(): { { any } }
	local out = {}
	for _, b in BLOCKS do table.insert(out, { b[2], b[3], b[4], b[5], "map" }) end
	for _, z in Arena.KEEP_CLEAR do table.insert(out, z) end
	local o = Config.ORB_SIZE / 2
	for _, s in Arena.ORBS do table.insert(out, { s.x - o, s.y - o, s.x + o, s.y + o, "orb" }) end
	for _, a in Arena.ANCHORS do table.insert(out, { a.x - 2, a.y - 2, a.x + 2, a.y + 2, "anchor" }) end -- H25
	return out
end

-- The stock Studio template puts a Baseplate and a SpawnLocation at the origin. Seen side-on, the baseplate's top is
-- a grey plane running toward the camera, and the spawn pad sits in the runner's plane. Remove both for this Play
-- only (the place file is not changed) and say so in Output.
local function clearTemplate()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local part = workspace:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part:Destroy()
			print(("[Rotag] test map: removed Workspace.%s for this Play (the place file is unchanged)"):format(name))
		end
	end
end

function Arena.build(): Folder
	clearTemplate()
	local old = workspace:FindFirstChild("Map")
	if old then old:Destroy() end
	local map = Instance.new("Folder")
	map.Name = "Map"
	for _, b in BLOCKS do
		local name, x0, y0, x1, y1 = b[1], b[2], b[3], b[4], b[5]
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = Vector3.new(x1 - x0, y1 - y0, MAP_DEPTH)
		part.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = if name == "Floor" then Color3.fromRGB(70, 72, 84) else Color3.fromRGB(110, 114, 132)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = map
	end
	-- H25: the anchors, in a Persistent model so streaming never drops one from a screen. Not solid and not queried:
	-- they are never a floor or a wall to the probes (T11), nor block a rope's line of sight.
	local anchors = Instance.new("Model")
	anchors.Name = "Anchors"
	anchors.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for i, a in Arena.ANCHORS do
		for _, spec in { { "Anchor", 1.6, Color3.fromRGB(255, 205, 60), 0, Enum.Material.Neon },
			{ "AnchorBack", 3.4, Color3.fromRGB(35, 25, 10), -0.5, Enum.Material.SmoothPlastic } } do -- QA r1: bigger, darker
			local part = Instance.new("Part")
			part.Name = spec[1]
			part.Shape = if spec[1] == "Anchor" then Enum.PartType.Ball else Enum.PartType.Cylinder
			part.Size = if spec[1] == "Anchor" then Vector3.one * spec[2] else Vector3.new(0.2, spec[2], spec[2])
			part.CFrame = CFrame.new(a.x, a.y, spec[4]) * (if spec[1] == "Anchor" then CFrame.identity
				else CFrame.Angles(0, math.pi / 2, 0)) -- the backing disc faces the camera
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
			part.Color, part.Material = spec[3], spec[5]
			if spec[1] == "Anchor" then
				part:SetAttribute("AnchorId", i)
				part:AddTag(Arena.ANCHOR_TAG)
			end
			part.Parent = anchors
		end
	end
	anchors.Parent = map
	map.Parent = workspace
	print(("[Rotag] test map: %d parts and %d grapple anchors in Workspace.Map"):format(#BLOCKS, #Arena.ANCHORS))
	return map
end

return Arena
