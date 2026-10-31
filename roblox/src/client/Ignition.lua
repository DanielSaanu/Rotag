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

-- One burst at (x, y) on the runner plane: a neon ball that swells and fades, and a ring of sparks. `color`: the
-- ball's colour (H24: the walls' red for a runner the walls took; the ember orange for a burn-out by default).
function Ignition.burst(x: number, y: number, color: Color3?)
	local flash = Instance.new("Part")
	flash.Name = "RotagBurnOut"
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = color or Color3.fromRGB(255, 120, 30)
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
-- H24: a runner gone from `alive` that the last state listed OUTSIDE the walls was taken by them: a red burst there
-- (the holder too). Anyone else gone is the holder's burn-out (orange) or a leave (no body: nothing).
local WALL_RED = Color3.fromRGB(255, 40, 60)
function Ignition.state(s: any, where: (number) -> Vector3?)
	local p = prev
	prev = s
	if not (p and p.round == s.round and not p.over) then return end
	for _, id in p.alive do
		local walled = false
		for _, e in (p.outside or {}) do if e.id == id then walled = true end end
		local at = if table.find(s.alive, id) or not (walled or id == p.it) then nil else where(id)
		-- a holder whose FUSE ran out while it stood outside burned out: orange, not the walls' red (QA round 1)
		if walled and id == p.it and type(p.fuse) == "number" and p.fuse <= 0.2 then walled = false end
		if at then
			Ignition.burst(at.X, at.Y, if walled then WALL_RED else nil)
			if studio then
				print(("[Rotag] %s: %s at (%.1f, %.1f)"):format(if walled then "walled out" else "burn-out", tostring(id), at.X, at.Y))
			end
		end
	end
end

return Ignition
