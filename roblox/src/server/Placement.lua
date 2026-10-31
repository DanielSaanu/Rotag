-- The server's end of ghost parts: fixtures and boost pads (DESIGN §3 rules 15, 47, 48; H22, docs/systems/placement.md).
-- The rules are shared/Placement.lua (pure, tested); this file re-checks every placement on the server's OWN record
-- (the spot is the ghost's newest trusted sample, never a client position), builds the parts, fades and removes them,
-- and tells every client over Remotes.ItemEvent. server/Items routes a Use of a fixture or a pad here.
-- Fixtures are anchored Parts in the Default collision group with CanQuery on: solid to every runner, ghosts included,
-- and a wall and a floor to the client's probes (→ T11). Pads are drawn parts only (no collide, no query): the client
-- that ENTERS one launches its own runner, as every move is the client's (trust.md); the speed check bounds it as is.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local Rules = require(Shared:WaitForChild("Placement"))
local Arena = require(script.Parent:WaitForChild("Arena"))

local Placement = {}

type Context = { round: () -> Tag.Round?, history: { [number]: { Tag.Sample } } }

local T = Config.STUDS_PER_TILE
local DEPTH = 8 -- as deep as the map's parts (server/Arena), across the runner plane z = 0
local FIXTURE_COLOR = Color3.fromRGB(125, 110, 230) -- ghost-made: violet, never the map's grey (rules 12, 29)
local PAD_COLOR = Color3.fromRGB(120, 255, 90) -- boost pads: lime (rule 29: colour-coded)
local FADE_LOOK = 0.55 -- a fading piece's transparency during its 1 s warning (it is still solid)

local state: Rules.State = Rules.new()
local static: { Rules.Box } = {}
local parts: { [number]: { BasePart } } = {}
local folder: Folder? = nil
local event: RemoteEvent? = nil
local ctx: Context? = nil
local buf: { number } = {}
local rows: { { number } } = {}
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] placement:", ...) end end

local function fire(e: any, to: Player?)
	if not event then return end
	if to then event:FireClient(to, e) else event:FireAllClients(e) end
end

-- ItemEvent payloads (docs/systems/README.md), arrays only (→ N13):
--   { kind = "zones", boxes = { { x0, y0, x1, y1, why } } }  to one client on join: what no part may cover (static)
--   { kind = "placed", n, item, owner, shape?, rot, x, y, dir, life? }  x, y its bottom-left; life nil = the round
--   { kind = "fade", n, time }  a fixture's warning before it goes (a ghost's 4th fades its oldest)
--   { kind = "unplaced", n }   gone (faded, run out); a round start's `sync` (server/Orbs) clears them all
local function placedPayload(p: Rules.Placed, now: number)
	return { kind = "placed", n = p.n, item = p.item, owner = p.owner, shape = p.shape, rot = p.rot, x = p.left,
		y = p.bottom, dir = p.dir, life = if p.untilT == math.huge then nil else p.untilT - now }
end

local function part(size: Vector3, at: CFrame, color: Color3, solid: boolean): BasePart
	local b = Instance.new("Part")
	b.Size, b.CFrame, b.Color = size, at, color
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, solid, solid, false, false
	b.Material = if solid then Enum.Material.SmoothPlastic else Enum.Material.Neon
	b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	b.Parent = folder
	return b
end

-- One Part per row run of a fixture (no seam under a runner on its top); a pad's slab and an arrow tilted its way.
local function build(p: Rules.Placed): { BasePart }
	local out = {}
	if p.item == "pad" then
		local cx, cy = p.left + Config.PAD_W / 2, p.bottom + Config.PAD_H / 2
		local slab = part(Vector3.new(Config.PAD_W, Config.PAD_H, DEPTH / 2), CFrame.new(cx, cy, 0), PAD_COLOR, false)
		slab.Name = "Pad"
		local arrow = part(Vector3.new(3, 0.6, 0.2), CFrame.new(cx, cy + 2, Config.RUNNER_DEPTH / 2 + 0.3)
			* CFrame.Angles(0, 0, p.dir * math.rad(40)), PAD_COLOR, false)
		arrow.Name = "PadArrow"
		table.insert(out, slab)
		table.insert(out, arrow)
		return out
	end
	for _, row in Rules.ROT[p.shape :: string][p.rot + 1].rows do
		local x0, y0, x1, y1 = p.left + row[1] * T, p.bottom + row[2] * T, p.left + row[3] * T, p.bottom + row[4] * T
		local b = part(Vector3.new(x1 - x0, y1 - y0, DEPTH), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), FIXTURE_COLOR,
			true)
		b.Name = "Fixture"
		table.insert(out, b)
	end
	return out
end

local function fadeLook(n: number)
	for _, b in parts[n] or {} do b.Transparency = FADE_LOOK end
end

-- The runners a part must keep clear of, from the server's newest samples: every living runner by PLACE_CLEAR (rule
-- 47); a ghost by its own box for a solid fixture (a piece over a ghost would trap it), not at all for a pad.
local function runnersFor(r: Tag.Round, item: string): number
	local c = ctx :: Context
	local nr = 0
	for _, id in r.order do
		local h = c.history[id]
		local s = h and h[#h]
		local ghost = Ghost.isGhost(r, id)
		if s and (r.alive[id] or (ghost and item == "fixture")) then
			nr += 1
			rows[nr] = rows[nr] or { 0, 0, 0 }
			rows[nr][1], rows[nr][2], rows[nr][3] = s.x, s.y, if ghost then 0 else Config.PLACE_CLEAR
		end
	end
	return nr
end

-- A Use of a fixture or a pad by ghost `id` (server/Items has checked the round, the slot and the hold; the sample is
-- its newest TRUSTED one). `shape` the fixture's tetromino from the orb (shared/Orbs.piece), `rot` UseItem's 0-3.
-- Re-checked here on the server's own record: a refused place costs nothing (the item stays) and says why.
function Placement.place(r: Tag.Round, id: number, item: string, shape: string?, rot: number, x: number, y: number,
	facing: number, now: number): (boolean, string?)
	if not ctx then return false, "not started" end
	if not Ghost.isGhost(r, id) then return false, "only a ghost places parts" end
	if item == "fixture" and not Rules.valid(shape, rot) then return false, "no shape for this fixture" end
	if item == "pad" then rot = 0 end -- a pad's arrow is its placer's facing; the rotation is not read for it
	local left, bottom = Rules.spot(item, shape, rot, x, y, facing)
	local count = Rules.boxesInto(buf, item, shape, rot, left, bottom)
	local ok, why = Rules.fits(state, buf, count, static, rows, runnersFor(r, item))
	if not ok then return false, "no room: " .. tostring(why) end
	local p, faded = Rules.place(state, id, item, shape, rot, left, bottom, facing, now)
	parts[p.n] = build(p)
	fire(placedPayload(p, now))
	if faded then
		fadeLook(faded.n)
		fire({ kind = "fade", n = faded.n, time = Config.FIXTURE_FADE })
	end
	log(("%s placed %s%s at (%g, %g) rot %d facing %d%s"):format(tostring(id), item,
		if shape and item == "fixture" then " " .. shape else "", left, bottom, rot, p.dir,
		if faded then (", piece %d fading"):format(faded.n) else ""))
	return true, nil
end

-- Every server frame while the round runs (from server/Items.step): faded pieces and run-out pads go.
function Placement.step(now: number)
	for _, n in Rules.step(state, now) do
		for _, b in parts[n] or {} do b:Destroy() end
		parts[n] = nil
		fire({ kind = "unplaced", n = n })
	end
end

-- Round start: every part gone (the round's `sync` from server/Orbs has already cleared each client's).
function Placement.reset()
	for _, list in parts do
		for _, b in list do b:Destroy() end
	end
	table.clear(parts)
	state = Rules.new()
end

-- A late joiner: the static boxes, then every live part (and any fade in progress).
function Placement.syncTo(player: Player)
	local now = os.clock()
	fire({ kind = "zones", boxes = static }, player)
	for _, p in state.placed do
		fire(placedPayload(p, now), player)
		if p.fadeAt then fire({ kind = "fade", n = p.n, time = math.max(0, p.fadeAt - now) }, player) end
	end
end

function Placement.start(items: RemoteEvent?, context: Context)
	ctx = context
	event = items
	static = Arena.static()
	local old = workspace:FindFirstChild("RotagFixtures")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "RotagFixtures" -- made here; nothing waits for it by name (clients use ItemEvent, probes hit its parts)
	f.Parent = workspace
	folder = f
	log(("%d static boxes (map, keep-clear, orbs)"):format(#static))
end

return Placement
