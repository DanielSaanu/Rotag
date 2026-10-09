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
	map.Parent = workspace
	print(("[Rotag] test map: %d parts in Workspace.Map"):format(#BLOCKS))
	return map
end

return Arena
