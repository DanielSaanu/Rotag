-- Ghost parts and the boost grant on this client (H22, DESIGN §3 rules 15, 46-48; docs/systems/placement.md). It
-- DECIDES nothing the server needs: it mirrors the server's placed parts and grants from ItemEvent (client/Items hands
-- it every event), previews a held fixture or pad one tile ahead of the local ghost (red where the server would refuse
-- it), turns the piece on the grapple input (the number goes up with Use, client/Use), launches the local runner the
-- frame it ENTERS a pad (every move is the client's; the speed check bounds it, trust.md), and tells the frame loop
-- the local run-speed boost. The fit test runs every render frame: shared/Placement's, on reused buffers (trigger 6).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Placement"))
local Items = require(script.Parent:WaitForChild("Items"))
local Tagging = require(script.Parent:WaitForChild("Tagging"))
local Others = require(script.Parent:WaitForChild("Others"))

local Place = {}

local RUNNER_TAG = "RotagRunner"
local HIDDEN = CFrame.new(0, -1e4, 0)
local Z = Config.RUNNER_DEPTH / 2 + 0.5 -- in front of the runner sprites, like the item icons
-- Plain (SmoothPlastic) for the violet preview: Neon washed it out to white (QA round 2); Neon stays for the red
-- refusal and the keep-clear zone, which are meant to shout. The grant's halo is client/Look's rim (Look:boost).
local OK_COLOR, NO_COLOR = Color3.fromRGB(160, 140, 255), Color3.fromRGB(255, 60, 60)

local mirror: Rules.State = Rules.new() -- the server's placed parts, by its numbers
local static: { Rules.Box } = {}
local pieces: { [number]: string } = {} -- runner id -> the tetromino it holds (from the orb that gave it)
local grants: { [number]: number } = {} -- runner id -> os.clock() its grant ends
local inside: { [number]: boolean } = {} -- pad n -> the local runner touched it last frame (launch on entry only)
local rot = 0
local folder: Folder? = nil
local cells: { BasePart } = {} -- the preview: four cells (a pad uses the first)
local zoneParts: { BasePart } = {}
local runnerModels: { [Model]: boolean } = {}
local buf: { number } = {}
local rows: { { number } } = {}
local shownOk: boolean? = nil
local refusal: string? = nil -- why the preview is red this frame (the fit test's reason), nil when it is not
local lastPlacing: string? = nil -- the placeable item held last frame: a new one starts at rotation 0 (QA round 1)
local studio = RunService:IsStudio()

local function part(size: Vector3, color: Color3, transparency: number, neon: boolean?): BasePart
	local p = Instance.new("Part")
	p.Size, p.Color, p.Transparency, p.CFrame = size, color, transparency, HIDDEN
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Parent = folder
	return p
end

local function onEvent(e: any)
	local k = e.kind
	if k == "sync" then -- a round start or a join: no parts, no grants (the server rebuilds its own)
		mirror = Rules.new()
		table.clear(grants)
		table.clear(inside)
		table.clear(pieces)
		if type(e.held) == "table" then
			for _, h in e.held do
				if type(h) == "table" and type(h.id) == "number" and type(h.piece) == "string" then pieces[h.id] = h.piece end
			end
		end
	elseif k == "orb" and type(e.by) == "number" then
		pieces[e.by] = if type(e.piece) == "string" then e.piece else nil
	elseif k == "slot" and type(e.id) == "number" then
		pieces[e.id] = nil
	elseif k == "zones" and type(e.boxes) == "table" then
		static = {}
		for _, z in zoneParts do z:Destroy() end
		table.clear(zoneParts)
		for _, b in e.boxes do
			if type(b) == "table" and type(b[1]) == "number" and type(b[2]) == "number" and type(b[3]) == "number"
				and type(b[4]) == "number" then
				table.insert(static, { b[1], b[2], b[3], b[4], if type(b[5]) == "string" then b[5] else "map" })
				if b[5] == "keep-clear" then
					local z = part(Vector3.new(b[3] - b[1], b[4] - b[2], 0.2), NO_COLOR, 1, true)
					z.Name = "KeepClear"
					z:SetAttribute("At", Vector3.new((b[1] + b[3]) / 2, (b[2] + b[4]) / 2, Z - 0.3))
					table.insert(zoneParts, z)
				end
			end
		end
	elseif k == "placed" and type(e.n) == "number" and (e.item == "fixture" or e.item == "pad")
		and type(e.x) == "number" and type(e.y) == "number" and type(e.owner) == "number" then
		local rotation = if type(e.rot) == "number" then e.rot else 0
		if e.item == "fixture" and not Rules.valid(e.shape, rotation) then return end
		Rules.remove(mirror, e.n) -- a resend (a late join's sync) replaces, never doubles
		Rules.record(mirror, e.n, e.owner, e.item, if e.item == "fixture" then e.shape else nil, rotation, e.x, e.y,
			if e.dir == -1 then -1 else 1, os.clock(), if type(e.life) == "number" then e.life else nil)
	elseif k == "unplaced" and type(e.n) == "number" then
		Rules.remove(mirror, e.n)
		inside[e.n] = nil
	elseif k == "grant" and type(e.id) == "number" and type(e.time) == "number" then
		grants[e.id] = os.clock() + e.time
	end
end

-- Runner `id`'s grant, seconds left: the HUD line, the run-speed multiplier input (with Tag's ramp: rule 46), and
-- each runner's halo (Look:boost).
function Place.grantLeft(id: number): number
	return math.max(0, (grants[id] or 0) - os.clock())
end

-- What the local runner holds that it places, if any: "fixture" or "pad" (a ghost only, while the round runs: no
-- preview between rounds, QA round 2).
local function placing(me: number): string?
	local item = Items.held(me)
	local st = Tagging.state()
	if (item == "fixture" or item == "pad") and Tagging.ghost(me) and st ~= nil and not st.over then return item end
	return nil
end

-- For Controls.buttons: the GRAPPLE touch button reads ROTATE while the local ghost holds a fixture.
function Place.hook(me: number): string?
	return if placing(me) == "fixture" then "rotate" else nil
end

-- The rotation UseItem carries (client/Use): 0-3 for a fixture, 0 otherwise (the server ignores it for a pad).
function Place.rotation(): number
	return rot
end

-- Why the preview is red right now ("map", "keep-clear", "orb", "a piece", "a pad", "a runner"), nil when it is not.
function Place.refusal(): string?
	return refusal
end

-- Every physics step, after the freeze and the ramp: the rotate press, and a pad's launch when the local runner
-- ENTERS one. Your OWN pad appears under your feet, so it needs a real entry (off, then on); someone else's pad that
-- lands on you launches at once, so a fast runner never slips under a fresh pad (QA round 2). Pads launch everyone,
-- ghosts included (proposal §3: "anyone may use it"; placement.md §5).
function Place.frame(input: any, s: any, me: number)
	local held = placing(me)
	if held ~= lastPlacing then
		lastPlacing = held
		if held then rot = 0 end -- a new piece starts upright, whatever the last one was turned to
	end
	if input.grapplePressed and held == "fixture" then rot = (rot + 1) % 4 end
	for _, p in mirror.placed do
		if p.item == "pad" then
			local touching = Rules.onPad(p, s.x, s.y)
			local was = inside[p.n]
			inside[p.n] = touching
			if touching and (was == false or (was == nil and p.owner ~= me)) and not input.hold then
				input.launchX, input.launchY = Rules.launch(p.dir)
				if studio then print(("[Rotag] pad: launched off pad %d"):format(p.n)) end
			end
		end
	end
end

-- The rows for Rules.fits from this screen, as server/Placement builds them: every living runner a tile clear, a ghost
-- by its own box for a fixture only. The local runner where it is, everyone else where it is drawn.
local nrows = 0
local function addRow(id: number, rx: number, ry: number, item: string)
	local living = Tagging.isAlive(id)
	if not (living or (item == "fixture" and Tagging.ghost(id) ~= nil)) then return end
	nrows += 1
	local row = rows[nrows]
	if not row then
		row = { 0, 0, 0 }
		rows[nrows] = row
	end
	row[1], row[2], row[3] = rx, ry, if living then Config.PLACE_CLEAR else 0
end
local function runnersFor(me: number, x: number, y: number, item: string): number
	nrows = 0
	addRow(me, x, y, item)
	for model in runnerModels do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and id ~= me and root and root:IsA("BasePart") then
			local p = Others.positionOf(root)
			addRow(id, p.X, p.Y, item)
		end
	end
	return nrows
end

-- Every render frame: the preview (where the server would put it, red where it would refuse) and the keep-clear
-- zones while a part is held. (The grant's halo is drawn by each runner's Look, from Place.grantLeft.)
function Place.draw(me: number, x: number?, y: number?, facing: number)
	local item = if x and y then placing(me) else nil
	if item and x and y then
		local shape = pieces[me]
		local count = 0
		if item == "pad" or Rules.valid(shape, rot) then
			local r = if item == "pad" then 0 else rot
			local left, bottom = Rules.spot(item, shape, r, x, y, facing)
			count = Rules.boxesInto(buf, item, shape, r, left, bottom)
		end
		local ok, why = false, nil
		if count > 0 then ok, why = Rules.fits(mirror, buf, count, static, rows, runnersFor(me, x, y, item)) end
		refusal = if ok then nil else (why or "no shape")
		for i = 1, 4 do
			local c = cells[i]
			if i <= count then
				local x0, y0, x1, y1 = buf[i * 4 - 3], buf[i * 4 - 2], buf[i * 4 - 1], buf[i * 4]
				if c.Size.X ~= x1 - x0 or c.Size.Y ~= y1 - y0 then c.Size = Vector3.new(x1 - x0, y1 - y0, 0.4) end
				c.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, Z)
			elseif c.CFrame ~= HIDDEN then
				c.CFrame = HIDDEN
			end
		end
		if ok ~= shownOk then
			shownOk = ok
			for _, c in cells do
				c.Color = if ok then OK_COLOR else NO_COLOR
				c.Material = if ok then Enum.Material.SmoothPlastic else Enum.Material.Neon
			end
		end
	elseif cells[1] and cells[1].CFrame ~= HIDDEN then
		for _, c in cells do c.CFrame = HIDDEN end
		shownOk = nil
		refusal = nil
	end
	for _, z in zoneParts do -- the map rule made visible to the ghost who is placing
		local want = if item then 0.8 else 1
		if z.Transparency ~= want then
			z.Transparency = want
			z.CFrame = if item then CFrame.new(z:GetAttribute("At") :: Vector3) else HIDDEN
		end
	end
end

function Place.start()
	local f = Instance.new("Folder")
	f.Name = "RotagPlace"
	f.Parent = workspace
	folder = f
	for i = 1, 4 do cells[i] = part(Vector3.new(4, 4, 0.4), OK_COLOR, 0.45) end
	for _, m in CollectionService:GetTagged(RUNNER_TAG) do if m:IsA("Model") then runnerModels[m] = true end end
	CollectionService:GetInstanceAddedSignal(RUNNER_TAG):Connect(function(m)
		if m:IsA("Model") then runnerModels[m] = true end
	end)
	CollectionService:GetInstanceRemovedSignal(RUNNER_TAG):Connect(function(m)
		runnerModels[m :: Model] = nil
	end)
	Items.listen(onEvent)
end

return Place
