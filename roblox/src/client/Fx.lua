-- Punch (H31, docs/systems/ui.md §6; DESIGN §3 rule 21): screen shake, a flash on the screen's edge, bursts of sparks
-- in the world, dust under the feet, and the worn cosmetics (a trail and a glow on every runner, the burn-out's
-- style). Local and cosmetic only: built from parts and Roblox's stock particle, no art upload; nothing here is sent
-- or decides anything. A cosmetic never changes a hitbox, a speed or what a runner can see of another (rule 36).
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))

local Fx = {}

local Z = 4.6 -- in front of the map's front face (as client/Ignition): a burst against a wall is not cut in half
local SHAKE_MAX = 1.6 -- studs of camera offset at full trauma
local SHAKE_DECAY = 3.2 -- trauma lost per second (a hit is over in ~0.3 s)
local trauma = 0
local flash: Frame? = nil
local RAINBOW_PERIOD = 2.4
local TELEPORT = 12 -- studs in one frame: no move does this (a dash is 2 a frame), so the runner was re-placed

-- Add `amount` (0..1) of shake. Light on purpose (rule 21: "light screen shake"): a tag 0.45, a burn-out 0.8.
function Fx.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- The camera's offset this frame (client/SideCamera adds it), in studs. Squared: small hits barely move it.
function Fx.offset(dt: number): (number, number)
	if trauma <= 0 then return 0, 0 end
	trauma = math.max(0, trauma - SHAKE_DECAY * dt)
	local k = trauma * trauma * SHAKE_MAX
	local t = os.clock() * 48
	return math.noise(t, 0.3) * 2 * k, math.noise(0.7, t) * 2 * k
end

-- A flash of `color` round the screen's edge (a tag on you, the walls opening).
function Fx.flash(color: Color3, strength: number?)
	local f = flash
	if not f then return end
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - (strength or 0.35)
	TweenService:Create(f, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end

local function sequence(colors: { { number } }): ColorSequence
	if #colors == 1 then return ColorSequence.new(Ui.rgb(colors[1])) end
	local keys = {}
	for i, c in colors do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), Ui.rgb(c))) end
	return ColorSequence.new(keys)
end

-- A one-shot burst of `count` sparks at (x, y). `style`: nil sparks, "confetti" (slow, falling, flat), "ink" (dark
-- blobs), "shards" (fast, sharp), "nova" (a wide slow ring), "coins" (gold, bouncing up), "dust" (a low puff).
function Fx.burst(x: number, y: number, colors: { { number } }, style: string?, count: number?)
	local part = Instance.new("Part")
	part.Name = "RotagFx"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CFrame = CFrame.new(x, y, Z)
	local at = Instance.new("Attachment")
	at.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = sequence(if #colors > 0 then colors else { { 255, 255, 255 } })
	e.LightEmission, e.ZOffset = 0.8, 1
	e.Size = NumberSequence.new(0.9, 0)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime, e.Speed = NumberRange.new(0.3, 0.7), NumberRange.new(14, 30)
	e.SpreadAngle, e.Drag, e.Acceleration = Vector2.new(180, 180), 3, Vector3.new(0, -20, 0)
	local life = 1.2
	if style == "confetti" then
		e.LightEmission, e.Size = 0.2, NumberSequence.new(0.5)
		e.Lifetime, e.Speed, e.Drag = NumberRange.new(1.2, 2.2), NumberRange.new(18, 40), 4
		e.Acceleration, e.RotSpeed, e.Rotation = Vector3.new(0, -26, 0), NumberRange.new(-360, 360), NumberRange.new(0, 360)
		life = 2.6
	elseif style == "ink" then
		e.LightEmission, e.Size = 0, NumberSequence.new(1.6, 0.4)
		e.Lifetime, e.Speed, e.Drag = NumberRange.new(0.6, 1.1), NumberRange.new(8, 22), 5
	elseif style == "shards" then
		e.Size, e.Lifetime, e.Speed = NumberSequence.new(0.5, 0), NumberRange.new(0.25, 0.5), NumberRange.new(40, 70)
		e.Drag = 2
	elseif style == "nova" then
		e.Size, e.Lifetime, e.Speed = NumberSequence.new(1.4, 0), NumberRange.new(0.8, 1.3), NumberRange.new(26, 30)
		e.Drag, e.Acceleration = 1.5, Vector3.zero
		life = 1.6
	elseif style == "coins" then
		e.LightEmission, e.Size = 0.6, NumberSequence.new(0.7)
		e.Lifetime, e.Speed = NumberRange.new(0.9, 1.5), NumberRange.new(20, 42)
		e.SpreadAngle, e.Acceleration = Vector2.new(50, 50), Vector3.new(0, -70, 0)
		at.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- up
		life = 1.8
	elseif style == "dust" then
		e.LightEmission, e.Size, e.Transparency = 0, NumberSequence.new(0.5, 1.3), NumberSequence.new(0.5, 1)
		e.Lifetime, e.Speed, e.Drag = NumberRange.new(0.2, 0.4), NumberRange.new(3, 9), 6
		e.Acceleration = Vector3.new(0, 4, 0)
		life = 0.6
	end
	e.Parent = at
	part.Parent = workspace
	e:Emit(count or 40)
	Debris:AddItem(part, life + 0.2)
end

-- A ring that swells and fades at (x, y): the shape of a hit (a tag) or a pickup.
function Fx.ring(x: number, y: number, color: Color3, size: number?)
	local ring = Instance.new("Part")
	ring.Name = "RotagFxRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Size = Vector3.new(0.15, 1, 1)
	ring.Transparency = 0.2
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.CFrame = CFrame.new(x, y, Z) * CFrame.Angles(0, math.pi / 2, 0) -- the disc faces the camera
	ring.Parent = workspace
	local s = size or 8
	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.15, s, s), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

-- A tag landed at (x, y) (the victim): the hit ring, sparks, and a shake for whoever is in it.
function Fx.tag(x: number, y: number, involved: boolean)
	Fx.ring(x, y, Ui.C.ember, 11)
	Fx.burst(x, y, { { 255, 240, 170 }, { 255, 90, 30 } }, nil, 26)
	Fx.shake(if involved then 0.55 else 0.2)
	if involved then Fx.flash(Ui.C.ember, 0.28) end
end

-- Runner `id` burnt out at (x, y): its own burn-out style (the cosmetic slot of rule 50), over client/Ignition's flash.
function Fx.burnout(id: number, x: number, y: number)
	local it = Flow.worn(id, "burst")
	if it then Fx.burst(x, y, it.colors, it.style, 70) end
	Fx.shake(0.8)
end

local function rainbow(colors: { { number } }, shift: number): Color3
	local n = #colors
	local f = (os.clock() / RAINBOW_PERIOD + shift) % 1 * n
	local i = math.floor(f)
	return Ui.rgb(colors[i % n + 1]):Lerp(Ui.rgb(colors[(i + 1) % n + 1]), f - i)
end

-- Every frame, for every runner drawn on this screen: its worn trail and glow on `look` (client/Look). `visible`
-- false hides both (a ghost wears nothing: rule 37's pale runner must read as a ghost). Rebuilt only when the worn
-- item changes; the rainbow and pulse styles recolour in place.
function Fx.wear(look: any, id: number, visible: boolean)
	local holder = look.holder
	if not holder then return end
	local trail = if visible then Flow.worn(id, "trail") else nil
	local glow = if visible then Flow.worn(id, "glow") else nil
	if look.fxHolder ~= holder or look.fxTrail ~= trail or look.fxGlow ~= glow then
		for _, o in look.fxParts or {} do o:Destroy() end
		look.fxParts, look.fxHolder, look.fxTrail, look.fxGlow = {}, holder, trail, glow
		look.fxTrailObj, look.fxLight, look.fxAura = nil, nil, nil
		if trail then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 1.1, 0), Vector3.new(0, -1.3, 0)
			a0.Parent, a1.Parent = holder, holder
			local t = Instance.new("Trail")
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = sequence(trail.colors)
			t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
			t.Lifetime, t.MinLength, t.LightEmission, t.FaceCamera = 0.32, 0.05, 0.7, true
			t.WidthScale = NumberSequence.new(1, 0.2)
			t.Parent = holder
			look.fxTrailObj = t
			table.insert(look.fxParts, a0)
			table.insert(look.fxParts, a1)
			table.insert(look.fxParts, t)
		end
		if glow then
			local at = Instance.new("Attachment")
			at.Position = Vector3.new(0, -0.4, 0)
			at.Parent = holder
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = Ui.rgb(glow.colors[1]), 9, 1.8, false
			light.Parent = at
			local aura = Instance.new("ParticleEmitter")
			aura.Color = sequence(glow.colors)
			aura.LightEmission, aura.ZOffset, aura.Rate = 0.9, -1, 9
			aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0) })
			aura.Transparency = NumberSequence.new(0.2, 1)
			aura.Lifetime, aura.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(1.5, 4)
			aura.SpreadAngle, aura.Acceleration, aura.LockedToPart = Vector2.new(180, 180), Vector3.new(0, 5, 0), false
			aura.Parent = at
			look.fxLight, look.fxAura = light, aura
			table.insert(look.fxParts, at)
		end
	end
	local t = look.fxTrailObj
	if t then -- a runner re-placed (round start, a snap-back, a bot's reset) must not draw a ribbon across the map
		local at = holder.Position
		local was = look.fxAt
		if was and (at - was).Magnitude > TELEPORT then t:Clear() end
		look.fxAt = at
	end
	if trail and look.fxTrailObj and trail.style == "rainbow" then
		look.fxTrailObj.Color = ColorSequence.new(rainbow(trail.colors, 0), rainbow(trail.colors, 0.3))
	end
	if glow and look.fxLight then
		if glow.style == "rainbow" then
			look.fxLight.Color = rainbow(glow.colors, 0)
		elseif glow.style == "pulse" then
			look.fxLight.Brightness = 1.8 + 1.2 * math.sin(os.clock() * 5)
		end
	end
	look:glow(if glow then look.fxLight.Color else nil)
end

function Fx.start(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RotagFx"
	gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = false, true, 2
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel, f.BackgroundTransparency, f.BackgroundColor3 = 0, 1, Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient") -- see-through in the middle, coloured at the left and right edges
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0) })
	g.Parent = f
	f.Parent = gui
	flash = f
	gui.Parent = player:WaitForChild("PlayerGui")
end

return Fx
