-- The server's end of Use, items and holds (DESIGN §3 rules 41-45; H19, docs/systems/items.md). The rules are
-- shared/Items.lua (pure, tested); this file judges each UseItem on the server's own state and position record (the
-- spot is never a client's), runs the things in the world against the living each frame, writes every hold, pries a
-- trap, holds the victim's speed check to the hold (server/MoveGuard) and tells every client over Remotes.ItemEvent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local OrbRules = require(Shared:WaitForChild("Orbs"))
local Rules = require(Shared:WaitForChild("Items"))
local MoveCheck = require(Shared:WaitForChild("MoveCheck"))
local Orbs = require(script.Parent:WaitForChild("Orbs"))
local MoveGuard = require(script.Parent:WaitForChild("MoveGuard"))

local Items = {}

type Context = {
	round: () -> Tag.Round?,
	ghosts: () -> Ghost.Ghosts?,
	history: { [number]: { Tag.Sample } },
	facing: (number) -> number, -- the user's facing: its stream's (server/Snapshots) or a dummy's
}

local state: Rules.State = Rules.new()
local ctx: Context? = nil
local event: RemoteEvent? = nil
local lastUse: { [number]: number } = {}
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] items:", ...) end end

local function fire(e: any, to: Player?)
	if not event then return end
	if to then event:FireClient(to, e) else event:FireAllClients(e) end
end

-- ItemEvent payloads (docs/systems/README.md), on top of server/Orbs' sync / orb / slot:
--   { kind = "put", n, item, x, y, w, h, dir, life }  a thing in the world (life: seconds left)
--   { kind = "gone", n }                             it broke, caught someone, or expired
--   { kind = "hold", id, hold, time }                 a hold landed on runner id ("stumble" | "freeze" | "trap")
--   { kind = "free", id }                            it ended early (a pry) or ran out
local function put(t: Rules.Thing, now: number)
	return { kind = "put", n = t.n, item = t.item, x = t.x, y = t.y, w = t.hw * 2, h = t.hh * 2, dir = t.dir,
		life = t.untilT - now }
end

-- A late joiner: every live thing and hold (after server/Orbs' sync, which clears the client's).
function Items.syncTo(player: Player)
	local now = os.clock()
	for _, t in state.things do fire(put(t, now), player) end
	for id, h in state.holds do
		if Rules.holdOf(state, id, now) then fire({ kind = "hold", id = id, hold = h.kind, time = h.untilT - now }, player) end
	end
end

-- Round start: nothing in the world, nobody held (server/Orbs.reset's sync already cleared every client).
function Items.reset()
	state = Rules.new()
end

-- The hold in force on `id` (server/Bots stops a held dummy).
function Items.held(id: number, now: number): boolean
	return Rules.holdOf(state, id, now) ~= nil
end

-- Rule 44 (H20): may `id` pass the fuse now? Not while the ice beam has it frozen (Rules.canTag, the server's record).
function Items.canTag(id: number, now: number): (boolean, string?)
	return Rules.canTag(state, id, now)
end

-- A Use, judged on the server's own state: in the round, holding a usable item, not held or frozen (rule 44), at the
-- server's newest TRUSTED sample of the user (a suspect position places nothing) and the facing its stream reports.
local function use(id: number, now: number): (boolean, string?)
	local c = ctx
	local r, o = c and c.round(), Orbs.current()
	if not (c and r and o) or r.over then return false, "no round" end
	if not table.find(r.order, id) then return false, "not in this round" end
	local item = o.held[id]
	local ok, why = Rules.canUse(state, id, item, now, if r.it == id then r.frozenUntil else nil)
	if not ok then return false, why end
	local h = c.history[id]
	local s = h and h[#h]
	if not s or s.untrusted then return false, "position untrusted" end
	local t = Rules.use(state, id, item :: string, Ghost.isGhost(r, id), s.x, s.y, c.facing(id), now)
	OrbRules.use(o, id)
	Orbs.emptied(id)
	fire(put(t, now))
	log(("%s used %s at (%.1f, %.1f) facing %d"):format(tostring(id), t.item, s.x, s.y, t.dir))
	return true, nil
end

-- One press: a pry while trapped (any key, click or tap the client sends during a trap), else a Use. Also the dummies'.
function Items.press(id: number, now: number)
	local h = Rules.holdOf(state, id, now)
	if h then
		if h.kind == "trap" and Rules.pry(state, id, now) then
			MoveGuard.release(id, now)
			fire({ kind = "free", id = id })
			log(("%s pried the trap open"):format(tostring(id)))
		end
		return -- no item starts during a hold (rule 44); a press during a stumble or freeze does nothing
	end
	local ok, why = use(id, now)
	if not ok then log(("use %s dropped: %s"):format(tostring(id), tostring(why))) end
end

-- Client -> server, ONE small integer (0-3: the fixture rotation in PR 4, ignored now; → N4). Rate-gapped, typed, and
-- everything else read from the server's own state.
local function onUse(player: Player, n: any)
	local now = os.clock()
	local id = player.UserId
	if not Rules.acceptPress(state, id, now, lastUse[id]) then return end -- no gap during a trap (QA round 1)
	lastUse[id] = now
	if type(n) ~= "number" or n ~= n or n % 1 ~= 0 or n < 0 or n > 3 then return end
	Items.press(id, now)
end

-- Every server frame while the round runs, after the orbs: each thing against each living runner's newest sample and
-- the path from the one before (→ N14). An untrusted sample still gets hit: a cheat never escapes a hazard by being
-- suspect. Ghosts are never victims (items touch the living only, rule 37).
function Items.step(r: Tag.Round, now: number, present: (number) -> boolean)
	local c = ctx
	if not c then return end
	local g = c.ghosts()
	local victims: { Rules.Victim } = {}
	for _, id in r.order do
		local h = c.history[id]
		local s, p = h and h[#h], h and h[#h - 1]
		if r.alive[id] and present(id) and s then
			table.insert(victims, { id = id, x = s.x, y = s.y, px = p and p.x, py = p and p.y, iframe = s.iframe,
				frozenUntil = if r.it == id then r.frozenUntil else nil })
		end
	end
	for _, e in Rules.step(state, now, victims, if g then g.wards else {}) do
		if e.kind == "hold" then
			-- its speed from the server's own samples, never the client's word (QA round 1: the freeze's allowance)
			local speed = MoveCheck.recentSpeed(c.history[e.id :: number] or {})
			MoveGuard.hold(e.id :: number, e.hold :: string, now, now + (e.time :: number), speed)
			log(("%s caught: %s for %.1fs (thing %d)"):format(tostring(e.id), tostring(e.hold), e.time or 0, e.by or 0))
		end
		fire(e)
	end
end

function Items.start(use: RemoteEvent?, items: RemoteEvent?, context: Context)
	ctx = context
	event = items
	if use then use.OnServerEvent:Connect(onUse) end
	Players.PlayerRemoving:Connect(function(p) lastUse[p.UserId] = nil end)
end

return Items
