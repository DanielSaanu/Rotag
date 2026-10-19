-- The server's end of the ghosts (DESIGN §3 rules 37-41, docs/systems/ghosts.md). The rules are shared/Ghost.lua
-- (pure, tested); this file judges a ghost's GhostClaim exactly like a TagClaim (tag.md §2): the sender is the Player
-- Roblox passes, the payload one number (the holder it touched), rate-gapped, and the touch re-checked over the
-- server's OWN position history (Tag.touchedBetween, the same window and caps). Every effect (the drain, the ward,
-- the cooldowns, the mark) is written here or in Match, never on a client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))

local Ghosts = {}

type Pending = { target: number, from: number, deadline: number, lag: number }
type Context = {
	round: () -> Tag.Round?,
	ghosts: () -> Ghost.Ghosts?,
	history: { [number]: { Tag.Sample } },
	changed: () -> (), -- MatchState must go out
}

local pending: { [number]: Pending } = {}
local lastClaim: { [number]: number } = {}
local verdictRemote: RemoteEvent? = nil
local ctx: Context? = nil
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] ghost:", ...) end end

-- A confirmed spook: apply it and tell everyone. For a player's claim and for a Studio dummy's own touch.
-- GhostVerdict { from, to, drained, fuse, mark }: `drained` is what really came off (→ N7), `mark` who holds it now.
function Ghosts.land(r: Tag.Round, g: Ghost.Ghosts, ghost: number, now: number)
	local holder = r.it
	local fuse, drained, marked = Ghost.spook(r, g, ghost, now)
	log(("SPOOK %s -> %s, fuse %.1fs (-%.1fs), %s"):format(tostring(ghost), tostring(holder), fuse, drained,
		if marked then "holds the mark" else "spent: no mark"))
	if verdictRemote then
		verdictRemote:FireAllClients({ from = ghost, to = holder, drained = drained, fuse = fuse,
			mark = Ghost.markOf(r, g) })
	end
	if ctx then ctx.changed() end
end

-- Rules first (the round may have moved on since the claim arrived), then positions. True once decided.
local function judge(ghost: number, p: Pending, to: number, now: number): boolean
	local c = ctx
	local r, g = c and c.round(), c and c.ghosts()
	if not (c and r and g) then return true end
	local ok, why = Ghost.canSpook(r, g, ghost, p.target, now)
	if not ok then
		log(("spook %s -> %s dropped: %s"):format(tostring(ghost), tostring(p.target), tostring(why)))
		return true
	end
	local ha, hb = c.history[ghost], c.history[p.target]
	if not (ha and hb and Tag.touchedBetween(ha, hb, p.from, to, p.lag)) then return false end
	Ghosts.land(r, g, ghost, now)
	return true
end

-- Every server frame, AFTER the tag claims: a tag and a killing spook in one frame, the tag wins.
function Ghosts.judge(now: number)
	for ghost, p in pending do
		if judge(ghost, p, math.min(now, p.deadline), now) then
			pending[ghost] = nil
		elseif now >= p.deadline then
			pending[ghost] = nil
			log(("spook %s -> %s dropped: no overlap in the window (target up to %.2fs older)"):format(
				tostring(ghost), tostring(p.target), p.lag))
		end
	end
end

-- Client -> server, ONE number: the holder's runner id (→ N4). Queued, judged in the next frame after the tags.
local function onClaim(player: Player, target: any)
	local now = os.clock()
	local id = player.UserId
	if now - (lastClaim[id] or -math.huge) < Config.TAG_CLAIM_GAP then return end
	lastClaim[id] = now
	if type(target) ~= "number" or target ~= target or target % 1 ~= 0 then return end
	local ok, ping = pcall(function() return player:GetNetworkPing() end)
	local from, deadline, lag = Tag.claimWindow(now, (if ok and type(ping) == "number" then ping else 0)
		+ Config.TAG_VIEW_DELAY)
	local open = pending[id]
	if not (open and open.target == target) then
		log(("spook %s -> %s received"):format(tostring(id), tostring(target)))
	end
	pending[id] = { target = target, from = from, deadline = deadline, lag = lag }
end

-- What MatchState carries about ghosts: an ARRAY (→ N13) of { id, ready, comebacks } for every present ghost, the
-- shared ward's seconds left, and who holds the mark (nil: nobody would come back).
function Ghosts.state(r: Tag.Round?, g: Ghost.Ghosts?, now: number, present: (number) -> boolean)
	: ({ any }, number, number?)
	local list = {}
	if not (r and g) or r.over then return list, 0, nil end
	for _, id in r.order do
		if Ghost.isGhost(r, id) and present(id) then
			table.insert(list, { id = id, ready = Ghost.readyIn(g, id, now), comebacks = Ghost.comebacksLeft(g, id) })
		end
	end
	return list, Ghost.wardLeft(g, now), Ghost.markOf(r, g)
end

function Ghosts.reset() table.clear(pending) end
function Ghosts.forget(id: number) pending[id], lastClaim[id] = nil, nil end

function Ghosts.start(claim: RemoteEvent?, verdict: RemoteEvent?, context: Context)
	ctx = context
	verdictRemote = verdict
	if claim then claim.OnServerEvent:Connect(onClaim) end
	if verdict then verdict.OnServerEvent:Connect(function() end) end -- server -> client only (→ N3)
	Players.PlayerRemoving:Connect(function(p) Ghosts.forget(p.UserId) end)
end

return Ghosts
