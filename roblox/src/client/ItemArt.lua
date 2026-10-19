-- The item art on the parts client/Items already draws (H21; the names, canvases and timings are the contract in
-- docs/briefs/items-art.md "Sprite names and sizes"). A sprite goes on a SurfaceGui on the part's camera-facing (+Z,
-- "Back") face, sampled bilinear like the runner (docs/systems/sprites-and-animation.md §4), and the part turns
-- see-through. Every call is guarded by Sprites.Has: while the sheet lacks a name the part stays the coloured
-- placeholder it was, so this ships before Danzo uploads the sheet. It DECIDES nothing; client/Items calls it with
-- what the server said. Frame picks read the clock and index name tables built once: no string is built per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))
local Tagging = require(script.Parent:WaitForChild("Tagging")) -- the shared ward (the hex icon dims while it holds)

local ItemArt = {}

-- The runner's hold art is in the sheet (Danzo has uploaded it): the hold poses, the frozen rim (client/Look) in place
-- of the placeholder ice box. Until then every hold draws exactly as before H21 (motion poses, the cyan box).
ItemArt.HOLD_ART = Sprites.Has("runner_trapped_0") and Sprites.Has("runner_stumble_0")

local PPS = 50 -- SurfaceGui pixels per stud, as client/Look: the label, not the gui, sets the detail
local function names(prefix: string, n: number): { string }
	local t = {}
	for i = 0, n - 1 do t[i + 1] = prefix .. tostring(i) end
	return t
end
local SPIN = { [false] = names("orb_spin_", 4), [true] = names("ghost_orb_spin_", 4) } -- by "is a ghost orb"
local TAKE = { [false] = names("orb_take_", 4), [true] = names("ghost_orb_take_", 4) }
local ORB_FPS = 4 -- the spin: floor(now * 4) % 4, a 1.0 s loop
local TAKE_FRAME = 0.06 -- the take one-shot, per frame; then the faint spot
local FAINT = 0.75 -- ImageTransparency of the faint orb_spin_0 while an orb waits (0.25 opacity)
local CRATE_BREAK = names("crate_break_", 3)
local CRATE_BREAK_ENDS = { 0.05, 0.13, 0.2 } -- 0.05 / 0.08 / 0.07 s, then destroy
local HEX_BEAT = 0.8 -- ready / pulse alternate every 0.8 s while no ward holds
local HEX_SPENT = 0.3
local PUT = { crate = "crate_0", trap = "trap_armed", ice = "ice_beam" }
local ICON = { crate = "crate_0", trap = "trap_armed", ice = "ice_icon" } -- hex: picked by the ward (ItemArt.icon)
local ICE_CHARGE = 0.05 -- the bloom at the hand as the beam comes out
local ICE_FADE = 0.1
local SNAP = 0.06 -- trap_snap_0 as a hold lands, then trap_snap_1
local PRIED = { "trap_pried_1", "trap_pried_2" }
local TRAP_RELEASE = 0.12 -- after the hold: trap_armed this long, then gone

-- Part -> its label and the name and flip on it. Weak keys: a destroyed part takes its entry with it.
local drawn: { [BasePart]: { image: ImageLabel, name: string, mirrored: boolean, alpha: number } } =
	setmetatable({}, { __mode = "k" }) :: any

-- Draw `name` on part `p` (mirrored: flipped left-right by the rect, as client/Look). True when the part shows a
-- sprite; false (part untouched) while the sheet lacks the name and nothing was applied before.
function ItemArt.show(p: BasePart, name: string, mirrored: boolean?): boolean
	local d = drawn[p]
	local flip = mirrored == true
	if d and d.name == name and d.mirrored == flip then return true end
	if not Sprites.Has(name) then return d ~= nil end
	if not d then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "RotagItemSprite"
		gui.Face = Enum.NormalId.Back -- +Z, the face the camera looks at
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PPS
		gui.LightInfluence = 0
		gui.Adornee = p
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = gui
		gui.Parent = p
		if p:IsA("Part") then p.Shape = Enum.PartType.Block end -- a ball's face is its bounding box's face
		p.Transparency = 1
		d = { image = image, name = "", mirrored = false, alpha = 0 }
		drawn[p] = d
	end
	local dd = d :: any
	Sprites.Apply(dd.image, name)
	dd.image.ResampleMode = Enum.ResamplerMode.Default -- vector art, not tile art (client/Look)
	if flip then
		local s = Sprites.Sprites[name]
		dd.image.ImageRectOffset = Vector2.new(s.X + s.W, s.Y)
		dd.image.ImageRectSize = Vector2.new(-s.W, s.H)
	end
	dd.name, dd.mirrored = name, flip
	return true
end

-- How see-through `p` is: the label's when it shows a sprite, else the placeholder part's.
function ItemArt.alpha(p: BasePart, t: number)
	local d = drawn[p]
	if not d then
		p.Transparency = t
	elseif d.alpha ~= t then
		d.alpha = t
		d.image.ImageTransparency = t
	end
end

function ItemArt.has(p: BasePart): boolean
	return drawn[p] ~= nil
end

-- An orb, every frame: spinning while up; the take one-shot from `takenAt`; then the faint spot. `bright`: an up
-- orb's transparency on this screen (a ghost orb is half-bright to the living). False: no art, the caller fades.
function ItemArt.orb(p: BasePart, ghost: boolean, up: boolean, takenAt: number?, now: number, bright: number): boolean
	local frame, t = 1, FAINT
	local set = SPIN[ghost]
	if up then
		frame, t = math.floor(now * ORB_FPS) % 4 + 1, bright
	elseif takenAt and now - takenAt < 4 * TAKE_FRAME then
		set, frame, t = TAKE[ghost], math.floor((now - takenAt) / TAKE_FRAME) + 1, bright
	end
	if not ItemArt.show(p, set[frame]) then return false end
	ItemArt.alpha(p, t)
	return true
end

-- A thing put in the world: crate_0, trap_armed or the beam (mirrored when it points left). The beam also gets
-- ice_charge at the hand for ICE_CHARGE (a small part of its own, destroyed by ItemArt.thing). Returns the record's
-- art fields for client/Items: `art` (a sprite is on), `charge`.
function ItemArt.put(p: BasePart, item: string, dir: number): (boolean, BasePart?)
	local name = PUT[item]
	if not (name and ItemArt.show(p, name, dir < 0)) then return false, nil end
	if item ~= "ice" or not Sprites.Has("ice_charge") then return true, nil end
	local c = Instance.new("Part")
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
	c.Size = Vector3.new(2, 2, 0.2) -- 64 x 64 at 32 px per stud
	c.CFrame = p.CFrame * CFrame.new(-dir * p.Size.X / 2, 0, p.Size.Z / 2 + 0.1)
	c.Parent = p.Parent
	ItemArt.show(c, "ice_charge")
	return true, c
end

-- Every frame for a thing with art. `t` = { part, item, born, endedAt?, caught?, charge? } (client/Items' record).
-- True when it is finished and may be destroyed: a crate that caught someone breaks (0.2 s), a beam fades (0.1 s).
function ItemArt.thing(t: any, now: number): boolean
	local c = t.charge
	if c and now - t.born >= ICE_CHARGE then c:Destroy() t.charge = nil end
	local e = t.endedAt
	if not e then return false end
	local dt = now - e
	if t.item == "crate" and t.caught then
		for i, last in CRATE_BREAK_ENDS do
			if dt < last then ItemArt.show(t.part, CRATE_BREAK[i]) return false end
		end
		return true
	elseif t.item == "ice" and dt < ICE_FADE and ItemArt.show(t.part, "ice_fade", ItemArt.mirrored(t.part)) then
		return false
	end
	return true
end

function ItemArt.mirrored(p: BasePart): boolean
	local d = drawn[p]
	return d ~= nil and d.mirrored
end

-- The trap at a pinned runner's feet (`h`: client/Items' hold, `from` when it landed, `presses` counted by client/Use
-- for the local runner; other screens see none, so theirs stay shut until free). `released`: when the hold ended,
-- for trap_armed over TRAP_RELEASE. False: no art (the caller keeps the placeholder). Second: finished.
function ItemArt.trap(p: BasePart, from: number, presses: number, released: number?, now: number): (boolean, boolean)
	local name
	if released then
		if now - released >= TRAP_RELEASE then return ItemArt.has(p), true end
		name = "trap_armed"
	elseif now - from < SNAP then
		name = "trap_snap_0"
	elseif presses > 0 then
		name = PRIED[math.min(presses, 2)]
	else
		name = "trap_snap_1"
	end
	return ItemArt.show(p, name), false
end

-- The held item over a runner's head. Hex: dim while the shared ward holds, else ready / pulse every HEX_BEAT;
-- `spentAt` (the hex left the slot): hex_spent for HEX_SPENT. False: no art. Second: the spent flash is over.
function ItemArt.icon(p: BasePart, item: string, spentAt: number?, now: number): (boolean, boolean)
	local name = ICON[item]
	if item == "hex" then
		if spentAt then
			if now - spentAt >= HEX_SPENT then return ItemArt.has(p), true end
			name = "hex_spent"
		elseif Tagging.wardLeft() > 0 then
			name = "hex_dim"
		else
			name = if math.floor(now / HEX_BEAT) % 2 == 0 then "hex_ready" else "hex_pulse"
		end
	end
	if not name then return false, spentAt ~= nil end
	if not ItemArt.has(p) and Sprites.Has(name) then
		local s = Sprites.Sprites[name] -- the brief: 1.3 studs over the head; a wide one (the trap) 1.8 across, its aspect
		p.Size = if s.W > s.H then Vector3.new(1.8, 1.8 * s.H / s.W, 0.2) else Vector3.new(1.3, 1.3 * s.H / s.W, 0.2)
	end
	return ItemArt.show(p, name), false
end

return ItemArt
