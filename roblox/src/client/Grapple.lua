-- The grapple on this screen (H25, DESIGN §3 rule 17; docs/systems/grapple.md): the anchors the server built (parts
-- tagged RotagAnchor, read from the workspace, no remote), the aim assist's pick handed to Movement each physics step
-- (shared/Grapple.pick: on screen, in reach, above, in line of sight), the pick's halo, and every runner's rope drawn
-- as a thin neon part from its raised hand to its anchor (our own from Movement, the others from their snapshot
-- stream's anchor byte). Cosmetic and local: the server never reads any of it (trust.md §11).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("Grapple"))

local Grapple = {}

local ANCHOR_TAG = "RotagAnchor" -- server/Arena.lua Arena.ANCHOR_TAG
local ROPE_COLOR = Color3.fromRGB(255, 205, 60) -- the anchors' gold (rule 29: grapple points have their own colour)
local ROPE_WIDTH = 0.25
local ROPE_Z = 0.9 -- just behind the runner's sprite plane (z 1.05), in front of the anchor (z 0)
local HAND_UP, HAND_OUT = 1.4, 0.5 -- the swing pose's raised fist (runner_fall), studs from the collider's centre
local HALO_Z = -0.95 -- behind the anchor's ball, so the halo reads as a ring round it
local HALO_SIZE = 3.6
local HALO_BEAT = 3 -- pulses a second

local anchors: { Rules.Anchor } = {}
local byId: { [number]: Rules.Anchor } = {}
local pick: Rules.Anchor? = nil
local folder: Folder? = nil
local halo: BasePart? = nil
local ropes: { [number]: BasePart } = {}
local seen: { [number]: number } = {}
local frame = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local fromX, fromY = 0, 0
local lastCharacter: Model? = nil -- the filter is rebuilt only when the character changes (QA r1: no per-step table)
local FLOOR_RAY = 64 -- studs down from an anchor the floor under it is looked for, once, at rebuild

local function rebuild()
	table.clear(anchors)
	table.clear(byId)
	for _, part in CollectionService:GetTagged(ANCHOR_TAG) do
		local id = part:GetAttribute("AnchorId")
		if part:IsA("BasePart") and type(id) == "number" then
			-- the floor under it (the map is static): a hook's rope is kept short enough to swing clear of it (QA r1)
			local p = RaycastParams.new()
			p.FilterType = Enum.RaycastFilterType.Exclude
			p.FilterDescendantsInstances = { folder :: any, part.Parent :: any }
			local hit = workspace:Raycast(part.Position, Vector3.new(0, -FLOOR_RAY, 0), p)
			local a = { x = part.Position.X, y = part.Position.Y, id = id, floor = if hit then hit.Position.Y else nil }
			table.insert(anchors, a)
			byId[id] = a
		end
	end
	pick = nil
end

local function part(name: string): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = ROPE_COLOR
	p.Parent = folder
	return p
end

-- The line of sight from the runner to an anchor: nothing solid in between (ghost pieces included; other runners
-- never block, the cast is in the runner's own collision group, T11; anchors and ropes have CanQuery off).
local function clear(a: Rules.Anchor): boolean
	return workspace:Raycast(Vector3.new(fromX, fromY, 0), Vector3.new(a.x - fromX, a.y - fromY, 0), params) == nil
end

function Grapple.start()
	local f = Instance.new("Folder")
	f.Name = "RotagRopes" -- client-only drawing, never replicated
	f.Parent = workspace
	folder = f
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(rebuild)
	CollectionService:GetInstanceRemovedSignal(ANCHOR_TAG):Connect(rebuild)
	rebuild()
end

-- Every physics step, before Movement.step: `input.anchor` = the aim assist's pick (nil on the rope: it is not
-- needed). A ghost never grapples (rule 37): client/Place has already read its grapple press as the rotate, and here
-- the grapple input is cleared before Movement sees it. `view` is SideCamera.view() (nil before the first frame).
function Grapple.frame(input: any, s: any, character: Model, root: BasePart, living: boolean, view: any?)
	if not living then
		input.grappleHeld, input.grapplePressed, input.anchor, pick = false, false, nil, nil
		return
	end
	if s.rope or not view then
		pick = nil
	else
		if lastCharacter ~= character then
			lastCharacter = character
			params.FilterDescendantsInstances = { character }
		end
		params.CollisionGroup = root.CollisionGroup
		fromX, fromY = s.x, s.y
		pick = Rules.pick(s.x, s.y, s.facing, anchors, view, if pick then pick.id else nil, clear, s.vx)
	end
	input.anchor = pick
end

-- For Controls.buttons: the GRAPPLE touch button for the living, lit while an anchor is picked or you hang.
function Grapple.hook(living: boolean, s: any?): string?
	if not living then return nil end
	return if pick or (s and s.rope) then "grapple" else "grapple_dim"
end

local function rope(id: number, x: number, y: number, facing: number, anchor: number?)
	local a = anchor and byId[anchor]
	if not a then return end
	local p = ropes[id]
	if not p then
		p = part("Rope")
		ropes[id] = p
	end
	seen[id] = frame
	local x0, y0 = x + HAND_OUT * (if facing < 0 then -1 else 1), y + HAND_UP
	local len = math.sqrt((a.x - x0) ^ 2 + (a.y - y0) ^ 2)
	p.Size = Vector3.new(ROPE_WIDTH, ROPE_WIDTH, math.max(len, 0.05))
	p.CFrame = CFrame.lookAt(Vector3.new((x0 + a.x) / 2, (y0 + a.y) / 2, ROPE_Z), Vector3.new(a.x, a.y, ROPE_Z),
		Vector3.zAxis)
	p.Transparency = 0
end

-- Every render frame: our rope (`me` on anchor `anchor`, drawn at our body), every other runner's (`eachOther(fn)`
-- calls fn(id, x, y, facing, anchor) for each runner drawn on this screen), and the pick's halo.
function Grapple.draw(me: number, x: number?, y: number?, facing: number, anchor: number?, eachOther: (any) -> ())
	frame += 1
	if x and y then rope(me, x, y, facing, anchor) end
	eachOther(rope)
	for id, p in ropes do
		if seen[id] ~= frame and p.Transparency < 1 then p.Transparency = 1 end
	end
	if pick then
		if not halo then
			halo = part("PickHalo")
			halo.Shape = Enum.PartType.Cylinder
			halo.Color = Color3.fromRGB(255, 255, 255)
			halo.Size = Vector3.new(0.1, HALO_SIZE, HALO_SIZE)
		end
		local h = halo :: BasePart
		h.CFrame = CFrame.new(pick.x, pick.y, HALO_Z) * CFrame.Angles(0, math.pi / 2, 0) -- the disc faces the camera
		h.Transparency = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi * HALO_BEAT))
	elseif halo and halo.Transparency < 1 then
		halo.Transparency = 1
	end
end

return Grapple
