-- The stage's look (H31, docs/systems/ui.md §7; DESIGN §6.3 trial: "glowing graphite"): the map's blocks in slate
-- graphite, outlined all round with a brighter lit edge along every top, a dusk backdrop behind the plane with a far skyline and ruled lines (the
-- sketchbook), and night lighting with bloom so the neon (anchors, pads, the walls, embers, trails) glows. Built
-- once at boot from the same map data server/Arena builds: no art upload, nothing a runner collides with or a probe
-- hits. Purely how it looks: the map's rules (shared/Maps, maps.test) never read any of it.
local Lighting = game:GetService("Lighting")

local Stage = {}

-- Seen in Studio and by Danzo (2026-11-16: "a bit difficult to see walls"): near-black blocks on a dark backdrop
-- under a 60% ambient left only the lit top edges; a wall with no top in view was invisible. Now the light is flat
-- and full (a colour here is the colour on screen), a block is clearly LIGHTER than the backdrop, and every block
-- is outlined all the way round, walls included.
local BLOCK = Color3.fromRGB(48, 55, 82) -- a map block: slate, a clear step lighter than the backdrop (Danzo, the
-- same day, of the first relight at (64, 72, 104) and exposure 1.15: "too bright in the arena now")
local EDGE = Color3.fromRGB(120, 200, 255) -- the lit top edge of every block
local FLOOR = Color3.fromRGB(34, 39, 60) -- the floor is a third of the screen: quieter than a deck
local SIDE = Color3.fromRGB(78, 104, 160) -- its sides and underside: an outline, quieter than the top
local FLOOR_EDGE = Color3.fromRGB(90, 130, 220)
local BACK = Color3.fromRGB(22, 25, 38) -- the backdrop: darker than everything that matters
local FAR = { Color3.fromRGB(29, 33, 50), Color3.fromRGB(26, 30, 45), Color3.fromRGB(33, 38, 57) } -- skyline
local RULE = Color3.fromRGB(40, 46, 70) -- the ruled lines
local DEPTH = 8 -- the map's parts are this deep about z 0 (server/Arena)
local FACE = 0.12 -- an edge strip's depth: a line on the block's front face, proud of it (seen in Studio: a strip as
-- deep as the block showed its whole top or underside to the camera, and a deck was one glowing slab)
local FRONT = DEPTH / 2 + FACE / 2

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
	Lighting.Ambient = Color3.new(1, 1, 1) -- flat and full: a part's colour is what the screen shows
	Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	Lighting.FogEnd = 100000
	-- Seen in Studio: under ambient light alone a part draws at under half its colour (a slate block came out navy).
	-- One stop and a bit of exposure brings the screen back to the colours written above.
	Lighting.ExposureCompensation = 0.6 -- (1.15 at first: Danzo found the arena too bright)
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0, 0
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 16, 1.6 -- a glow on the neon, not a smear (seen: 0.9 / 26 smeared)
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
			p.Color, p.Material = if name == "Floor" then FLOOR else BLOCK, Enum.Material.SmoothPlastic
		end
		local by0 = b[3]
		local mx, my, bw, bh = (bx0 + bx1) / 2, (by0 + by1) / 2, bx1 - bx0, by1 - by0
		local wall = string.find(name, "EndWall") ~= nil
		if not wall then
			part(look, name .. "Edge", Vector3.new(bw, 0.24, FACE), CFrame.new(mx, by1 - 0.12, FRONT),
				if name == "Floor" then FLOOR_EDGE else EDGE, Enum.Material.Neon)
		end
		-- The outline: both sides and the underside, proud of the front face like the top (the floor's underside is
		-- never on screen; an end wall is outlined on both faces, its top is off the map).
		for _, side in { -1, 1 } do
			part(look, name .. "Side", Vector3.new(0.18, bh, FACE), CFrame.new(mx + side * (bw / 2 - 0.09), my, FRONT), SIDE,
				Enum.Material.Neon, 0.25)
		end
		if name ~= "Floor" and not wall then
			part(look, name .. "Under", Vector3.new(bw, 0.18, FACE), CFrame.new(mx, by0 + 0.09, FRONT), SIDE,
				Enum.Material.Neon, 0.25)
		end
	end
	-- The backdrop: one big wall behind everything, the ruled lines of a sketchbook on it, and a far skyline between.
	local h = top + 160
	part(look, "Backdrop", Vector3.new(w + 600, h + 200, 2), CFrame.new(cx, top / 2, -60), BACK)
	for y = -8, top + 60, 16 do
		part(look, "Rule", Vector3.new(w + 600, 0.35, 0.5), CFrame.new(cx, y, -58.6), RULE)
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
	part(look, "Under", Vector3.new(w + 600, 80, DEPTH + 2), CFrame.new(cx, -48, 0), Color3.fromRGB(14, 16, 24))
	look.Parent = folder
	print(("[Rotag] stage: dressed %q (%d blocks lit, backdrop %d studs wide)"):format(map.name, #map.blocks, w + 600))
end

return Stage
