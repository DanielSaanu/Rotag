-- Orbs and held items on this screen (H18, DESIGN §3 rules 39, 41, 42; docs/systems/ghosts.md §6). It DECIDES nothing:
-- it draws what the server says over Remotes.ItemEvent (payloads in server/Orbs.lua and docs/systems/README.md). The
-- ghost orbs are neon balls (bright when up, faint while they wait); the item a runner holds floats over its head on
-- every screen (rule 41); a slot readout shows the local runner's item. Placeholder shapes, not art.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Others = require(script.Parent:WaitForChild("Others")) -- the item floats over the DRAWN runner (H13)

local Items = {}

local RUNNER_TAG = "RotagRunner"
local WAIT = 10
local Z = Config.RUNNER_DEPTH / 2 + 0.4 -- in front of the sprite plane, like the IT marker (client/Hud)
local ITEM_UP = Config.RUNNER_HEIGHT / 2 + 5 -- above the IT marker and its halo, so a holder's item never hides it
local ORB_COLOR = Color3.fromRGB(175, 120, 255)
local ITEM_COLOR = { hex = Color3.fromRGB(225, 70, 255) } -- one colour per item (rule 12); unknown: white
local HIDDEN = CFrame.new(0, -1e4, 0)

local orbs: { { part: BasePart, up: boolean } } = {}
local held: { [number]: string } = {}
local icons: { [number]: BasePart } = {}
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
		for _, s in e.orbs do
			if type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
				local p = part(Enum.PartType.Ball, Vector3.one * Config.ORB_SIZE, ORB_COLOR)
				p.CFrame = CFrame.new(s.x, s.y, 0)
				table.insert(orbs, { part = p, up = false })
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
	end
end

-- What runner `id` holds, as this screen was last told (nil = an empty slot).
function Items.held(id: number): string?
	return held[id]
end

-- Every render frame, after Others.draw: each held item over its runner's DRAWN spot, and the local slot readout.
-- `showSlot`: the local runner has a slot worth showing (it is a ghost; the living get items in PR 2).
-- `roundOver`: nothing is held between rounds (QA round 1): icons and the readout clear until the next sync.
function Items.draw(me: number, showSlot: boolean, roundOver: boolean)
	-- `showSlot` doubles as "the local runner is a ghost": only then is an up ghost orb drawn at full brightness.
	for _, o in orbs do
		o.part.Transparency = if not o.up then 0.85 elseif showSlot then 0.1 else 0.55
	end
	local seen = {}
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		local item = not roundOver and type(id) == "number" and held[id]
		if item and root and root:IsA("BasePart") then
			seen[id] = true
			local icon = icons[id] or part(Enum.PartType.Block, Vector3.new(1.3, 1.3, 0.2), ITEM_COLOR[item] or Color3.new(1, 1, 1))
			icons[id] = icon
			icon.Color = ITEM_COLOR[item] or Color3.new(1, 1, 1)
			local at = if id == me then root.Position else Others.positionOf(root)
			icon.CFrame = CFrame.new(at.X, at.Y + ITEM_UP, Z) * CFrame.Angles(0, 0, math.pi / 4) -- a diamond
		end
	end
	for id, icon in icons do
		if not seen[id] then icon:Destroy() icons[id] = nil end
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
