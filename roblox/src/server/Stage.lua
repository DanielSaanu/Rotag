-- The stage's look (H31, docs/systems/ui.md §7; DESIGN §6.3 trial: "glowing graphite"): the map's blocks in near-black
-- graphite with a lit edge along every top, a dusk backdrop behind the plane with a far skyline and ruled lines (the
-- sketchbook), and night lighting with bloom so the neon (anchors, pads, the walls, embers, trails) glows. Built
-- once at boot from the same map data server/Arena builds: no art upload, nothing a runner collides with or a probe
-- hits. Purely how it looks: the map's rules (shared/Maps, maps.test) never read any of it.
local Lighting = game:GetService("Lighting")

local Stage = {}

local BLOCK = Color3.fromRGB(16, 18, 26) -- a map block: darker than the backdrop, so a deck reads by its lit edge
local EDGE = Color3.fromRGB(120, 200, 255) -- the lit top edge of every block
local FLOOR_EDGE = Color3.fromRGB(90, 130, 220)
local BACK = Color3.fromRGB(38, 43, 62) -- the backdrop: the runner (grey, inked) is lighter than it, the blocks darker
local FAR = { Color3.fromRGB(31, 35, 52), Color3.fromRGB(27, 31, 46), Color3.fromRGB(34, 39, 58) } -- skyline
local RULE = Color3.fromRGB(58, 66, 96) -- the ruled lines
local DEPTH = 8 -- the map's parts are this deep about z 0 (server/Arena)

local function part(folder: Instance, name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?,
	transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color = size, at, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- Night, flat and bright enough to read: sprites ignore light (LightInfluence 0), parts take the ambient, neon blooms.
local function light()
	for _, o in Lighting:GetChildren() do
		if o:IsA("Sky") or o:IsA("Atmosphere") or o:IsA("PostEffect") or o:IsA("Clouds") then o:Destroy() end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(150, 156, 176)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 156, 176)
	Lighting.FogEnd = 100000
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0, 0
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.9, 26, 1.1
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast, grade.Saturation, grade.TintColor = 0.08, 0.12, Color3.fromRGB(246, 248, 255)
	grade.Parent = Lighting
end

-- `map` is shared/Maps' data; `folder` Workspace.Map as server/Arena built it.
function Stage.dress(folder: Instance, map: any)
	light()
	local x0, x1, top = math.huge, -math.huge, map.top
	for _, b in map.blocks do x0, x1 = math.min(x0, b[2]), math.max(x1, b[4]) end
	local w, cx = x1 - x0, (x0 + x1) / 2
	local look = Instance.new("Folder")
	look.Name = "Stage"
	-- The blocks' colour and their lit edges (a strip along the top, proud of the front face so it is never z-fought).
	for _, b in map.blocks do
		local name, bx0, by1, bx1 = b[1], b[2], b[5], b[4]
		local p = folder:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color, p.Material = BLOCK, Enum.Material.SmoothPlastic
		end
		local wall = string.find(name, "EndWall") ~= nil
		if not wall then
			part(look, name .. "Edge", Vector3.new(bx1 - bx0, 0.28, DEPTH + 0.2), CFrame.new((bx0 + bx1) / 2, by1 - 0.14, 0),
				if name == "Floor" then FLOOR_EDGE else EDGE, Enum.Material.Neon)
		end
	end
	-- The backdrop: one big wall behind everything, the ruled lines of a sketchbook on it, and a far skyline between.
	local h = top + 160
	part(look, "Backdrop", Vector3.new(w + 600, h + 200, 2), CFrame.new(cx, top / 2, -60), BACK)
	for y = -8, top + 60, 16 do
		part(look, "Rule", Vector3.new(w + 600, 0.35, 0.5), CFrame.new(cx, y, -58.6), RULE, Enum.Material.SmoothPlastic, 0.35)
	end
	local seed = Random.new(7) -- the same skyline on every server
	local x = x0 - 200
	while x < x1 + 200 do
		local bw = seed:NextInteger(10, 34)
		local bh = seed:NextInteger(18, math.floor(top * 0.9))
		local z = -seed:NextInteger(30, 52)
		part(look, "Far", Vector3.new(bw, bh, 2), CFrame.new(x + bw / 2, bh / 2 - 8, z), FAR[seed:NextInteger(1, #FAR)])
		if seed:NextNumber() < 0.5 then -- a lit window strip: a little life far away
			part(look, "FarLight", Vector3.new(bw * 0.5, 0.5, 0.4), CFrame.new(x + bw / 2, bh - 10 - seed:NextInteger(0, 8), z + 1.2),
				Color3.fromRGB(255, 190, 110), Enum.Material.Neon, 0.35)
		end
		x += bw + seed:NextInteger(2, 14)
	end
	-- Below the floor: darkness, so the bottom of the screen is never the backdrop.
	part(look, "Under", Vector3.new(w + 600, 80, DEPTH + 2), CFrame.new(cx, -48, 0), BLOCK)
	look.Parent = folder
	print(("[Rotag] stage: dressed %q (%d blocks lit, backdrop %d studs wide)"):format(map.name, #map.blocks, w + 600))
end

return Stage
