-- The burn-out (DESIGN §3 rule 50, H23, docs/systems/endgame.md §3): when the holder's fuse runs out, every screen
-- plays a one-shot burst where that runner stood. Read from MatchState, never decided here: the server's Tag.tick
-- eliminated them, and the next MatchState (sent at once, it is dirty) shows the holder gone from `alive` in the same
-- round. A holder who LEFT is gone from `alive` too, but has no body to burst at, so nothing plays. The ignition
-- itself (the growing ember rim and the embers) is Look:ignite, fed by Tagging.ignition. Placeholder art: parts and a
-- stock particle, no sheet upload; the art pass replaces it behind Sprites.Has, and it is the first cosmetic slot.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")


local Ignition = {}

local BURST_SPARKS = 70
local BURST_LIFE = 1.2 -- seconds the burst's parts stay before Debris takes them
local FLASH_TIME = 0.5 -- the flash ball grows and fades over this (QA round 1: 0.35 was easy to miss)
local FLASH_SIZE = 9 -- studs across at its widest (about two runners tall)
-- In front of the MAP's front face (server/Arena's parts are 8 deep about z 0), not just the sprite plane: a burst
-- against a wall was cut in half by the wall's face (QA round 1). Side-on, the extra depth is invisible.
local Z = 4.6
local studio = game:GetService("RunService"):IsStudio()

local prev: any = nil

-- One burst at (x, y) on the runner plane: a neon ball that swells and fades, and a ring of sparks.
function Ignition.burst(x: number, y: number)
	local flash = Instance.new("Part")
	flash.Name = "RotagBurnOut"
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 120, 30)
	flash.Size = Vector3.new(1, 1, 1)
	flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch = true, false, false, false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(x, y, Z)
	local at = Instance.new("Attachment")
	at.Parent = flash
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(200, 30, 10))
	e.LightEmission, e.ZOffset = 1, 1
	e.Size = NumberSequence.new(0.8, 0)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime, e.Speed = NumberRange.new(0.4, 0.9), NumberRange.new(12, 26)
	e.SpreadAngle, e.Drag, e.Acceleration = Vector2.new(180, 180), 3, Vector3.new(0, -20, 0)
	e.Parent = at
	flash.Parent = workspace
	e:Emit(BURST_SPARKS)
	TweenService:Create(flash, TweenInfo.new(FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(FLASH_SIZE, FLASH_SIZE, FLASH_SIZE), Transparency = 1 }):Play()
	Debris:AddItem(flash, BURST_LIFE)
end

-- After every MatchState (client/Tagging's onState). `where(id)` is where this screen draws that runner, or nil.
function Ignition.state(s: any, where: (number) -> Vector3?)
	local p = prev
	prev = s
	if not (p and p.it and p.round == s.round and not p.over) then return end
	if table.find(s.alive, p.it) or not table.find(p.alive, p.it) then return end
	local at = where(p.it)
	if not at then return end
	Ignition.burst(at.X, at.Y)
	if studio then print(("[Rotag] burn-out: %s at (%.1f, %.1f)"):format(tostring(p.it), at.X, at.Y)) end
end

return Ignition
