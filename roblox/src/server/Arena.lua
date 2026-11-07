-- The map: plain Parts in Workspace.Map, built at boot from the map data Config.MAP names (H27, docs/systems/maps.md).
-- Workspace.Map is a Folder made HERE, not in default.project.json: nothing in the project file declares it and the
-- client never waits for it by name (it raycasts against everything but its own character).
-- Units are studs. Every part spans the plane z = 0 with MAP_DEPTH of thickness.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Maps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Maps"))

-- H27 (PR 6, docs/systems/maps.md): the map is data in shared/ (Maps, MapYard, MapTest), picked by Config.MAP; this
-- file loads it and builds it, and hands every dependant the same fields the hand-built test arena had (SPAWN,
-- WINDOW, the orbs, KEEP_CLEAR, ANCHORS, static), so no caller changed. The rules each map is held to: maps.test.
local Arena = {}

local MAP_DEPTH = 8
local map = Maps.get(Config.MAP)
Arena.MAP = map
Arena.SPAWN = Vector3.new(map.spawn.x, map.spawn.y + Config.RUNNER_HEIGHT / 2 + 0.05, 0)
Arena.WINDOW = map.window -- the closing walls' bounds, world x (H26, DESIGN §6.8): the end walls' inner faces
Arena.GHOST_ORBS = map.ghostOrbs -- H18 (rule 42)
Arena.LIVING_ORBS = map.livingOrbs -- H19 (rules 42, 43)
Arena.ORBS = Maps.orbs(map) -- every spot server/Orbs runs: ghost ones first (the indices clients see)
Arena.KEEP_CLEAR = map.keepClear -- H22 (rules 47-48): every exit and corridor
Arena.PADS = map.pads -- H27: the map's own boost pads (DESIGN §2 kit), built by server/Placement each round
-- H25 (rule 17, grapple.md §5): the anchors, numbered by their place in the list (the snapshot's anchor byte). Built as
-- gold marked balls tagged ANCHOR_TAG; clients read them from the workspace (no remote).
Arena.ANCHOR_TAG = "RotagAnchor"
Arena.ANCHORS = map.anchors
function Arena.static(): { { any } } return Maps.static(map) end

-- The stock Studio template puts a Baseplate and a SpawnLocation at the origin. Seen side-on, the baseplate's top is
-- a grey plane running toward the camera, and the spawn pad sits in the runner's plane. Remove both for this Play
-- only (the place file is not changed) and say so in Output.
local function clearTemplate()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local part = workspace:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part:Destroy()
			print(("[Rotag] map: removed Workspace.%s for this Play (the place file is unchanged)"):format(name))
		end
	end
end

function Arena.build(): Folder
	clearTemplate()
	local old = workspace:FindFirstChild("Map")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	for _, b in map.blocks do
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
		part.Parent = folder
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
	anchors.Parent = folder
	folder.Parent = workspace
	print(("[Rotag] map %q: %d parts, %d grapple anchors, %d pads, window x %g..%g"):format(map.name, #map.blocks,
		#Arena.ANCHORS, #Arena.PADS, Arena.WINDOW.lo, Arena.WINDOW.hi))
	return folder
end

return Arena
