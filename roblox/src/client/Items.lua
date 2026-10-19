-- Orbs and held items on this screen (H18, DESIGN §3 rules 39, 41, 42; docs/systems/ghosts.md §6). It DECIDES nothing:
-- it draws what the server says over Remotes.ItemEvent (payloads in server/Orbs.lua and docs/systems/README.md). The
-- ghost orbs are neon balls (bright when up, faint while they wait); the item a runner holds floats over its head on
-- every screen (rule 41); a slot readout shows the local runner's item. Placeholder shapes, not art.
-- H19 (docs/systems/items.md §6): living orbs (gold), the things Use puts in the world (crate, trap, ice beam) and the
-- holds (a trap at a pinned runner's feet, ice around a frozen one), on every screen; client/Use reads the local hold.
-- One palette so orb, hex, crate, trap and ice read apart (rule 12): shape AND colour differ for each.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Others = require(script.Parent:WaitForChild("Others")) -- the item floats over the DRAWN runner (H13)

local Items = {}

local RUNNER_TAG = "RotagRunner"
local WAIT = 10
local Z = Config.RUNNER_DEPTH / 2 + 0.4 -- in front of the sprite plane, like the IT marker (client/Hud)
local ITEM_UP = Config.RUNNER_HEIGHT / 2 + 5 -- above the IT marker and its halo, so a holder's item never hides it
local ORB_COLOR = { ghost = Color3.fromRGB(150, 160, 255), living = Color3.fromRGB(255, 200, 50) } -- balls
local ITEM_COLOR = { -- one colour per item (rule 12); unknown: white
	hex = Color3.fromRGB(235, 60, 200), crate = Color3.fromRGB(160, 100, 45), trap = Color3.fromRGB(190, 45, 35),
	ice = Color3.fromRGB(90, 230, 255),
}
-- The icon over a holder's head: a diamond (hex), a box (crate), a flat jaw (trap), a ball (ice). Unknown: a diamond.
local ICON = { crate = { Vector3.new(1.3, 1.3, 0.2), 0 }, trap = { Vector3.new(1.8, 0.6, 0.2), 0 },
	ice = { Vector3.new(1.1, 1.1, 1.1), 0 } }
local HIDDEN = CFrame.new(0, -1e4, 0)

local orbs: { { part: BasePart, up: boolean, ghost: boolean } } = {}
local held: { [number]: string } = {}
local icons: { [number]: { part: BasePart, item: string } } = {}
local things: { [number]: { part: BasePart, untilT: number } } = {} -- by the server's thing number
local holds: { [number]: { kind: string, untilT: number, presses: number } } = {} -- by runner id
local overlays: { [number]: BasePart } = {}
local folder: Folder? = nil
local slotLabel: TextLabel? = nil

local function part(shape: Enum.PartType, size: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CFrame = HIDDEN
	p.Parent = folder
	return p
end

-- An orb's look is set every frame in Items.draw: a ghost orb reads as a pickup only to a ghost (QA round 2, rule 12).
local function setUp(i: number, up: boolean)
	local o = orbs[i]
	if not o then return end
	o.up = up
end

-- Shape only (→ N3): the server is the only sender, but a malformed table must not break the frame loop.
local function onEvent(e: any)
	if type(e) ~= "table" then return end
	if e.kind == "sync" and type(e.orbs) == "table" and type(e.held) == "table" then
		for _, o in orbs do o.part:Destroy() end
		table.clear(orbs)
		for _, t in things do t.part:Destroy() end -- a sync is a round start or a join: the world starts empty
		table.clear(things)
		table.clear(holds)
		for _, s in e.orbs do
			if type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
				local ghost = s.ghost == true
				local p = part(Enum.PartType.Ball, Vector3.one * Config.ORB_SIZE, ORB_COLOR[if ghost then "ghost" else "living"])
				p.CFrame = CFrame.new(s.x, s.y, 0)
				table.insert(orbs, { part = p, up = false, ghost = ghost })
				setUp(#orbs, s.up == true)
			end
		end
		table.clear(held)
		for _, h in e.held do
			if type(h) == "table" and type(h.id) == "number" and type(h.item) == "string" then held[h.id] = h.item end
		end
	elseif e.kind == "orb" and type(e.spot) == "number" and type(e.up) == "boolean" then
		setUp(e.spot, e.up)
		if type(e.by) == "number" and type(e.item) == "string" then held[e.by] = e.item end
	elseif e.kind == "slot" and type(e.id) == "number" then
		held[e.id] = if type(e.item) == "string" then e.item else nil
	elseif e.kind == "put" and type(e.n) == "number" and type(e.item) == "string" and type(e.x) == "number"
		and type(e.y) == "number" and type(e.w) == "number" and type(e.h) == "number" and type(e.life) == "number" then
		local ice = e.item == "ice"
		local p = part(Enum.PartType.Block, Vector3.new(e.w, e.h, if ice then 1 else Config.RUNNER_DEPTH),
			ITEM_COLOR[e.item] or Color3.new(1, 1, 1))
		p.Material = if ice then Enum.Material.Neon else Enum.Material.SmoothPlastic -- a crate and a trap are objects
		p.Transparency = if ice then 0.25 else 0
		p.CFrame = CFrame.new(e.x, e.y, 0)
		if things[e.n] then things[e.n].part:Destroy() end
		things[e.n] = { part = p, untilT = os.clock() + e.life + 1 } -- the server says "gone"; this is a backstop
	elseif e.kind == "gone" and type(e.n) == "number" then
		local t = things[e.n]
		if t then t.part:Destroy() things[e.n] = nil end
	elseif e.kind == "hold" and type(e.id) == "number" and type(e.hold) == "string" and type(e.time) == "number" then
		holds[e.id] = { kind = e.hold, untilT = os.clock() + e.time, presses = 0 }
	elseif e.kind == "free" and type(e.id) == "number" then
		holds[e.id] = nil
	end
end

-- The hold in force on runner `id` as this screen was told (client/Use applies the local one), or nil.
function Items.holdOf(id: number): { kind: string, untilT: number, presses: number }?
	local h = holds[id]
	if h and os.clock() < h.untilT then return h end
	return nil
end

-- What runner `id` holds, as this screen was last told (nil = an empty slot).
function Items.held(id: number): string?
	return held[id]
end

-- Every render frame, after Others.draw: each held item over its runner's DRAWN spot, and the local slot readout.
-- `ghost`: the local runner is a ghost (its orbs are drawn bright; living orbs bright for the living). `inRound`: it
-- is a living runner of this round. Either shows the readout. `roundOver`: nothing is held between rounds (QA round 1).
function Items.draw(me: number, ghost: boolean, roundOver: boolean, inRound: boolean?)
	local showSlot = ghost or inRound == true
	for _, o in orbs do
		o.part.Transparency = if not o.up then 0.85 elseif o.ghost == ghost then 0.1 else 0.55
	end
	local now = os.clock()
	for n, t in things do
		if now > t.untilT then t.part:Destroy() things[n] = nil end
	end
	local seen, seenHold = {}, {}
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and root and root:IsA("BasePart") then
			local at = if id == me then root.Position else Others.positionOf(root)
			local item = not roundOver and held[id]
			if item then
				seen[id] = true
				local icon = icons[id]
				if icon and icon.item ~= item then icon.part:Destroy() icon = nil end
				if not icon then
					local shape = ICON[item]
					icon = { item = item, part = part(if item == "ice" then Enum.PartType.Ball else Enum.PartType.Block,
						if shape then shape[1] else Vector3.new(1.3, 1.3, 0.2), ITEM_COLOR[item] or Color3.new(1, 1, 1)) }
					icons[id] = icon
				end
				local turn = if ICON[item] then ICON[item][2] else math.pi / 4 -- the hex: a diamond
				icon.part.CFrame = CFrame.new(at.X, at.Y + ITEM_UP, Z) * CFrame.Angles(0, 0, turn)
			end
			local h = not roundOver and Items.holdOf(id)
			if h and h.kind ~= "stumble" then -- a trap at the feet, ice around the body; a stumble shows in the motion
				seenHold[id] = true
				local o = overlays[id]
				if o and o.Name ~= h.kind then o:Destroy() o = nil end
				if not o then
					local trap = h.kind == "trap"
					o = part(Enum.PartType.Block, if trap then Vector3.new(Config.TRAP_W, Config.TRAP_H, 1.2)
						else Vector3.new(Config.RUNNER_WIDTH + 0.6, Config.RUNNER_HEIGHT + 0.6, 1.2),
						ITEM_COLOR[if trap then "trap" else "ice"])
					o.Name, o.Transparency = h.kind, if trap then 0 else 0.55
					overlays[id] = o
				end
				local dy = if h.kind == "trap" then Config.TRAP_H / 2 - Config.RUNNER_HEIGHT / 2 else 0
				o.CFrame = CFrame.new(at.X, at.Y + dy, Z - 0.2)
			end
		end
	end
	for id, icon in icons do
		if not seen[id] then icon.part:Destroy() icons[id] = nil end
	end
	for id, o in overlays do
		if not seenHold[id] then o:Destroy() overlays[id] = nil end
	end
	local label = slotLabel
	if label then
		local mine = if roundOver then nil else held[me]
		label.Text = if mine then ("ITEM: %s"):format(string.upper(mine)) elseif showSlot and not roundOver then "ITEM: none"
			else "" -- the status line (Hud) says what to do about it; the readout only says what is held (QA round 1)
		label.TextColor3 = if mine then (ITEM_COLOR[mine] or Color3.new(1, 1, 1)) else Color3.new(1, 1, 1)
	end
end

function Items.start(player: Player)
	local f = Instance.new("Folder")
	f.Name = "RotagItems"
	f.Parent = workspace
	folder = f
	local gui = Instance.new("ScreenGui")
	gui.Name = "RotagItems"
	gui.ResetOnSpawn = false
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 12, 0, 12) -- top left: the top centre is the fuse's, the lower middle stays clear (rule 23)
	l.Size = UDim2.new(0, 320, 0, 24)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.TextStrokeTransparency = 0.4
	l.Text = ""
	l.Parent = gui
	slotLabel = l
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- never blocks the client (→ N3); an old rojo serve lacks the remote (→ T6)
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		local r = remotes and remotes:WaitForChild("ItemEvent", WAIT)
		if r and r:IsA("RemoteEvent") then
			r.OnClientEvent:Connect(onEvent)
		else
			warn("[Rotag] no Remotes.ItemEvent (restart rojo serve); no orbs or items drawn on this client")
		end
	end)
end

return Items
