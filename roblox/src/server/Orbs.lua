-- The server's end of the orbs (DESIGN §3 rules 39, 42; H18, docs/systems/ghosts.md §3). The rules are shared/Orbs.lua
-- (pure, tested); this file feeds them the server's OWN position record every frame (no claim remote: a client never
-- says it touched an orb), rolls with the server's math.random, and tells every client over Remotes.ItemEvent (server ->
-- all; the server never listens, → N3). A sample the speed check marked untrusted collects nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local Rules = require(Shared:WaitForChild("Orbs"))

local Orbs = {}

local spots: { Rules.Spot } = {}
local state: Rules.State? = nil
local remote: RemoteEvent? = nil
local function rand(): number return math.random() end -- [0, 1), seeded by Roblox per server
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] orbs:", ...) end end

function Orbs.current(): Rules.State? return state end

-- ItemEvent payloads (docs/systems/README.md), arrays only (→ N13):
--   { kind = "sync", orbs = { { x, y, ghost, up } }, held = { { id, item } } }  on join, and to all at round start
--   { kind = "orb", spot, up, by?, item? }  an orb came back (up), or `by` took it and now holds `item`
--   { kind = "slot", id, item? }            a runner's slot changed outside an orb (a hex used, a leave): item nil = empty
local function syncPayload()
	local orbs, held = {}, {}
	local o = state
	for i, s in spots do
		table.insert(orbs, { x = s.x, y = s.y, ghost = s.kind == "ghost", up = o ~= nil and o.up[i] == true })
	end
	if o then
		for id, item in o.held do table.insert(held, { id = id, item = item }) end
	end
	return { kind = "sync", orbs = orbs, held = held }
end

function Orbs.syncTo(player: Player)
	if remote then remote:FireClient(player, syncPayload()) end
end

-- Round start: every orb down until ORB_FIRST, every slot empty.
function Orbs.reset(now: number)
	state = Rules.new(spots, now)
	if remote then remote:FireAllClients(syncPayload()) end
end

-- A runner's slot emptied outside an orb (a hex used; server/Ghosts calls this).
function Orbs.emptied(id: number)
	if remote then remote:FireAllClients({ kind = "slot", id = id }) end
end

-- Every server frame while the round runs, after the tags and hexes. `present(id)`: that runner is still in the game.
function Orbs.step(r: Tag.Round, now: number, history: { [number]: { Tag.Sample } }, present: (number) -> boolean)
	local o = state
	if not o then return end
	local takers: { Rules.Taker } = {}
	for _, id in r.order do
		local h = history[id]
		local s, p = h and h[#h], h and h[#h - 1]
		if s and not s.untrusted and present(id) then
			local path = p ~= nil and not p.untrusted
			table.insert(takers, { id = id, x = s.x, y = s.y, px = if path then p.x else nil, py = if path then p.y else nil,
				ghost = Ghost.isGhost(r, id) })
		end
	end
	for _, e in Rules.step(o, now, Ghost.count(r, present), takers, rand) do
		if e.by then
			log(("%s took ghost orb %d: %s"):format(tostring(e.by), e.spot, tostring(e.item)))
		end
		if remote then remote:FireAllClients({ kind = "orb", spot = e.spot, up = e.up, by = e.by, item = e.item }) end
	end
end

-- A runner left: its slot empties (and everyone is told).
function Orbs.forget(id: number)
	local o = state
	if o and Rules.use(o, id) ~= nil then Orbs.emptied(id) end
end

-- At boot: the map's orb spots (server/Arena) and the remote (nil if an old rojo serve lacks it: Match warned; the
-- orbs are still judged, no client sees them).
function Orbs.start(r: RemoteEvent?, mapSpots: { Rules.Spot })
	spots = mapSpots
	remote = r
	if r then r.OnServerEvent:Connect(function() end) end -- server -> client only (→ N3)
	Players.PlayerRemoving:Connect(function(p) Orbs.forget(p.UserId) end)
end

return Orbs
