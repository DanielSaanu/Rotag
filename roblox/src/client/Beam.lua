-- The ice beam on screen (H33; Danzo, 2026-11-16: "a big rotating beam ... as large as a player's body, coming out as
-- a cone from the player till it's player sized, then becoming a straight beam; we should see it shoot out and have a
-- shiny rotating pattern on it, not just appear; it should extend ... until it reaches full length ... and stay
-- attached to the front of the player's body"). Cosmetic and local: the box that freezes is shared/Items.beam, judged
-- by the server on its own record; this draws that very box on the shooter as this screen draws the shooter.
-- Built from plain parts (no art upload): a cone of slices at the hand, a straight body, two bright edges, bands
-- that wind round it like a turning spiral, and a bright head at the tip that leads the shot out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemRules = require(Shared:WaitForChild("Items"))

local Beam = {}

local CONE = 5 -- studs from the hand over which the beam widens to its full height
local SLICES = 18 -- the cone is this many slices (side-on they read as one taper; at 10 the steps showed)
local NARROW = 0.5 -- the cone's height at the hand, studs
local BANDS = 9 -- the winding bands
local BAND_GAP = 3.2 -- studs between two bands along the beam
local SPIN = 9 -- radians a second the bands turn about the beam's axis
local RUSH = 26 -- studs a second the bands run out along it
local FADE = 0.12 -- seconds the beam takes to thin away when it ends
local Z = 0.2 -- just in front of the runner plane's middle, behind the sprites (z 1.05)
local CORE = Color3.fromRGB(70, 200, 255)
local EDGE = Color3.fromRGB(215, 248, 255)
local HIDDEN = CFrame.new(0, -1e4, 0)
local HW = Config.RUNNER_WIDTH / 2

local function part(folder: Instance, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = "RotagBeam"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color, p.Transparency = color, transparency
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = HIDDEN
	p.Parent = folder
	return p
end

-- A beam fired the way `dir` (+1 right, -1 left). Parts are made once and moved every frame.
function Beam.new(folder: Instance, dir: number): any
	local b = { dir = if dir < 0 then -1 else 1, slices = {}, bands = {}, parts = {} }
	for i = 1, SLICES do b.slices[i] = part(folder, CORE, 0.3) end
	b.body = part(folder, CORE, 0.3)
	b.top, b.bottom = part(folder, EDGE, 0.05), part(folder, EDGE, 0.05)
	for i = 1, BANDS do b.bands[i] = part(folder, EDGE, 0.25) end
	b.head = part(folder, EDGE, 0)
	b.head.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = CORE, 16, 3, false
	light.Parent = b.head
	local at = Instance.new("Attachment")
	at.Parent = b.head
	local e = Instance.new("ParticleEmitter") -- frost thrown off the head as it travels
	e.Color = ColorSequence.new(EDGE, CORE)
	e.LightEmission, e.Rate = 0.9, 60
	e.Size = NumberSequence.new(0.7, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime, e.Speed = NumberRange.new(0.25, 0.5), NumberRange.new(4, 14)
	e.SpreadAngle, e.Drag = Vector2.new(180, 180), 3
	e.Parent = at
	b.emitter = e
	return b
end

-- Every frame: the beam `age` seconds after the shot, on a shooter now drawn at (ox, oy). `ended`: seconds since the
-- server said it is gone (nil: still out); returns true once it has thinned away and may be destroyed.
function Beam.draw(b: any, ox: number, oy: number, age: number, ended: number?): boolean
	local dir = b.dir
	local _, cy, hw, hh = ItemRules.beam(dir, ox, oy, age)
	local len, h = hw * 2, hh * 2
	if ended then
		if ended >= FADE then return true end
		h *= 1 - ended / FADE
		b.emitter.Enabled = false
	end
	local x0 = ox + dir * HW -- the hand: the shooter's front edge
	local cone = math.min(CONE, len)
	-- The cone: slices from NARROW at the hand up to the full height where the straight body begins.
	for i, s in b.slices do
		local a, c = (i - 1) / SLICES * cone, i / SLICES * cone
		local hi = math.min(h, NARROW + (h - NARROW) * (i / SLICES) * (cone / CONE))
		s.Size = Vector3.new(c - a + 0.02, hi, 1)
		s.CFrame = CFrame.new(x0 + dir * (a + c) / 2, cy, Z)
	end
	-- The straight body and its two bright edges.
	local straight = len - cone
	if straight > 0.05 then
		local mid = x0 + dir * (cone + straight / 2)
		b.body.Size, b.body.CFrame = Vector3.new(straight, h, 1), CFrame.new(mid, cy, Z)
		b.top.Size, b.top.CFrame = Vector3.new(straight, 0.22, 1.1), CFrame.new(mid, cy + h / 2 - 0.11, Z)
		b.bottom.Size, b.bottom.CFrame = Vector3.new(straight, 0.22, 1.1), CFrame.new(mid, cy - h / 2 + 0.11, Z)
	else
		b.body.CFrame, b.top.CFrame, b.bottom.CFrame = HIDDEN, HIDDEN, HIDDEN
	end
	-- The bands: each runs out along the beam and rides a turning circle about its axis, seen side-on: it climbs,
	-- thins to an edge at the rim, and comes back down the far side fainter. Together they read as a spinning spiral.
	local now = os.clock()
	for i, band in b.bands do
		local along = ((i - 1) * BAND_GAP + now * RUSH) % (BANDS * BAND_GAP)
		if along < len - 0.6 and along > 0.8 then
			local turn = now * SPIN + i * 1.3
			local local_h = if along < cone then NARROW + (h - NARROW) * (along / CONE) else h
			band.Size = Vector3.new(0.45, math.max(0.15, local_h * 0.34 * math.abs(math.cos(turn)) + 0.2), 1.2)
			band.CFrame = CFrame.new(x0 + dir * along, cy + math.sin(turn) * local_h * 0.36, Z + 0.05)
				* CFrame.Angles(0, 0, -dir * 0.5)
			band.Transparency = if math.cos(turn) > 0 then 0.15 else 0.6 -- the near side of the turn is brighter
		else
			band.CFrame = HIDDEN
		end
	end
	-- The head: a bright ball that leads the shot out and sits at the tip while the beam stands.
	local d = math.max(0.6, math.min(h, NARROW + (h - NARROW) * (len / CONE)) * 0.95)
	b.head.Size = Vector3.new(d, d, d)
	b.head.CFrame = CFrame.new(x0 + dir * len, cy, Z)
	return false
end

function Beam.destroy(b: any)
	for _, list in { b.slices, b.bands, { b.body, b.top, b.bottom, b.head } } do
		for _, p in list do p:Destroy() end
	end
end

return Beam
