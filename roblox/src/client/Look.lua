-- Draws the runner on its part, two ways, switched live by the Workspace attribute SurfaceSprites
-- (docs/systems/sprites-and-animation.md §4; the comparison is handoff H1):
--   false: a BillboardGui adorned to the collider (always faces the camera)
--   true:  a SurfaceGui on the camera-facing (+Z, "Back") face of a thin see-through part welded to the collider
-- Both hold one ImageLabel set by Sprites.Apply. Flip, frame and juice are the same code for both.
-- Flip: FlipBySize = false mirrors with a negative ImageRectSize; true with a negative Size.X.Scale. Which one
-- Roblox honours is the first Studio check (movement.md, "Open questions").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))

local Look = {}
Look.__index = Look

local SPRITE = Config.STUDS_PER_TILE -- the runner sprite is one 16 px tile: 4 studs square
local CANVAS = SPRITE * 1.5 -- room around the sprite so the biggest stretch (1.5 x) stays inside the gui
local BASE = SPRITE / CANVAS -- the label's size as a share of the canvas
-- The label hangs from the feet: its bottom edge is the sprite's bottom edge, SPRITE / 2 below the collider centre.
local FEET = 0.5 + (SPRITE / 2) / CANVAS
local SURFACE_PPS = 50 -- SurfaceGui pixels per stud: well above screen density so the Pixelated sampler decides

-- Juice targets as {x scale, y scale}; each eases back to {1, 1} (DESIGN §3 rule 21). Feet stay planted.
local JUICE = {
	land = { 1.35, 0.7 },
	ground = { 0.75, 1.3 },
	double = { 0.8, 1.25 },
	wall = { 0.75, 1.3 },
	dash = { 1.5, 0.75 },
}
local JUICE_SETTLE = 0.035 -- seconds per e-fold: back to within 5% in ~100 ms

function Look.new(character: Model, root: BasePart)
	local self = setmetatable({}, Look)
	self.character = character
	self.root = root
	self.sx, self.sy = 1, 1
	self.sprite, self.facing, self.flipBySize = nil, 1, nil
	self:_build()
	self.conns = {
		workspace:GetAttributeChangedSignal("SurfaceSprites"):Connect(function() self:_build() end),
		workspace:GetAttributeChangedSignal("FlipBySize"):Connect(function() self.sprite = nil end),
	}
	return self
end

function Look:_clear()
	if self.holder then self.holder:Destroy() end
	self.holder, self.image = nil, nil
end

function Look:_build()
	self:_clear()
	local surface = workspace:GetAttribute("SurfaceSprites") == true
	local gui
	if surface then
		local plane = Instance.new("Part")
		plane.Name = "RotagSpritePlane"
		plane.Size = Vector3.new(CANVAS, CANVAS, 0.05)
		plane.Transparency = 1
		plane.CanCollide = false
		plane.CanQuery = false
		plane.CanTouch = false
		plane.Massless = true
		plane.CastShadow = false
		plane.CFrame = self.root.CFrame * CFrame.new(0, 0, Config.RUNNER_DEPTH / 2 + 0.05)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = self.root
		weld.Part1 = plane
		weld.Parent = plane
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- +Z, the face the camera looks at
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = SURFACE_PPS
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Adornee = plane
		gui.Parent = plane
		plane.Parent = self.character
		self.holder = plane
	else
		gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(CANVAS, 0, CANVAS, 0) -- Scale is studs on a BillboardGui
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Adornee = self.root
		gui.Parent = self.root
		self.holder = gui
	end
	gui.Name = "RotagRunnerSprite"
	local image = Sprites.New("runner_idle", gui)
	image.AnchorPoint = Vector2.new(0.5, 1)
	image.Position = UDim2.fromScale(0.5, FEET)
	self.image = image
	self.sprite = nil -- force the next draw to apply frame, flip and size
	print(("[Rotag] runner drawn with %s (Workspace.SurfaceSprites = %s)"):format(
		if surface then "a SurfaceGui on a part" else "a BillboardGui", tostring(surface)))
end

-- What Movement reported this frame (or since the last draw): start the matching squash or stretch.
function Look:react(events)
	local kind = nil
	if events.dash then kind = "dash"
	elseif events.jump then kind = events.jump
	elseif events.landed and events.landed > 5 then kind = "land" end
	if not kind then return end
	local target = JUICE[kind]
	local amount = 1
	if kind == "land" then amount = math.clamp(events.landed / Config.MAX_FALL, 0.3, 1) end
	self.sx = 1 + (target[1] - 1) * amount
	self.sy = 1 + (target[2] - 1) * amount
end

local function setSprite(image: ImageLabel, name: string, mirrored: boolean)
	Sprites.Apply(image, name)
	if mirrored then
		local s = Sprites.Sprites[name]
		if s then
			-- The rect runs from its right edge back to its left: the same pixels, mirrored.
			image.ImageRectOffset = Vector2.new(s.X + s.W, s.Y)
			image.ImageRectSize = Vector2.new(-s.W, s.H)
		end
	end
end

-- Every render frame: frame, facing and juice. dashing holds the dash stretch while the dash lasts.
function Look:draw(spriteName: string, facing: number, dashing: boolean, dt: number)
	local image = self.image
	if not image then return end
	local flipBySize = workspace:GetAttribute("FlipBySize") == true
	if spriteName ~= self.sprite or facing ~= self.facing or flipBySize ~= self.flipBySize then
		self.sprite, self.facing, self.flipBySize = spriteName, facing, flipBySize
		setSprite(image, spriteName, facing < 0 and not flipBySize)
	end
	if dashing then
		self.sx, self.sy = JUICE.dash[1], JUICE.dash[2]
	else
		local k = math.exp(-dt / JUICE_SETTLE)
		self.sx = 1 + (self.sx - 1) * k
		self.sy = 1 + (self.sy - 1) * k
	end
	local xSign = if flipBySize and facing < 0 then -1 else 1
	image.Size = UDim2.fromScale(BASE * self.sx * xSign, BASE * self.sy)
end

function Look:destroy()
	for _, c in self.conns do c:Disconnect() end
	self:_clear()
end

return Look
