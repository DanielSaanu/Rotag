-- The server's end of the ghosts (DESIGN §3 rules 37-42, H18, docs/systems/ghosts.md). The rules are shared/Ghost.lua
-- (pure, tested); this file judges a ghost's GhostClaim (now the hex's claim) exactly like a TagClaim (tag.md §2): the
-- sender is the Player Roblox passes, the payload one number (the holder it touched), rate-gapped, the held hex read
-- from the server's own slots (shared/Orbs), and the touch re-checked over the server's OWN position history
-- (Tag.touchedBetween, the same window and caps). Every effect (the drain, the ward, the emptied slot) is written here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local OrbRules = require(Shared:WaitForChild("Orbs"))
local ItemRules = require(Shared:WaitForChild("Items"))
local Orbs = require(script.Parent:WaitForChild("Orbs"))

local Ghosts = {}

type Pending = { target: number, from: number, deadline: number, lag: number }
type Context = {
	round: () -> Tag.Round?,
	ghosts: () -> Ghost.Ghosts?,
	orbs: () -> OrbRules.State?,
	history: { [number]: { Tag.Sample } },
	changed: () -> (), -- MatchState must go out
}

local pending: { [number]: Pending } = {}
local lastClaim: { [number]: number } = {}
local verdictRemote: RemoteEvent? = nil
local ctx: Context? = nil
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] ghost:", ...) end end

-- A confirmed hex: apply it and tell everyone. For a player's claim and for a Studio dummy's own touch.
-- GhostVerdict { from, to, drained, fuse }: `drained` is what really came off (→ N7). Then ItemEvent: the slot is empty.
function Ghosts.land(r: Tag.Round, g: Ghost.Ghosts, o: OrbRules.State, ghost: number, now: number)
	local holder = r.it
	local fuse, drained = Ghost.hex(r, g, o, ghost, now)
	log(("HEX %s -> %s, fuse %.1fs (-%.1fs), ward %ds"):format(tostring(ghost), tostring(holder), fuse, drained,
		Config.GHOST_WARD))
	if verdictRemote then
		verdictRemote:FireAllClients({ from = ghost, to = holder, drained = drained, fuse = fuse })
	end
	Orbs.emptied(ghost)
	if ctx then ctx.changed() end
end

-- Rules first (the round may have moved on since the claim arrived), then positions. True once decided.
local function judge(ghost: number, p: Pending, to: number, now: number): boolean
	local c = ctx
	local r, g, o = c and c.round(), c and c.ghosts(), c and c.orbs()
	if not (c and r and g and o) then return true end
	local ok, why = Ghost.canHex(r, g, o, ghost, p.target, now)
	if not ok then
		log(("hex %s -> %s dropped: %s"):format(tostring(ghost), tostring(p.target), tostring(why)))
		return true
	end
	local ha, hb = c.history[ghost], c.history[p.target]
	-- H19, rule 45: a holder in its dash's i-frames dodges the hex (only samples outside them count)
	if not (ha and hb and Tag.touchedBetween(ha, ItemRules.undodged(hb), p.from, to, p.lag)) then return false end
	Ghosts.land(r, g, o, ghost, now)
	return true
end

-- Every server frame, AFTER the tag claims: a tag and a killing hex in one frame, the tag wins.
function Ghosts.judge(now: number)
	for ghost, p in pending do
		if judge(ghost, p, math.min(now, p.deadline), now) then
			pending[ghost] = nil
		elseif now >= p.deadline then
			pending[ghost] = nil
			log(("hex %s -> %s dropped: no overlap in the window (target up to %.2fs older)"):format(
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
		log(("hex %s -> %s received"):format(tostring(id), tostring(target)))
	end
	pending[id] = { target = target, from = from, deadline = deadline, lag = lag }
end

-- What MatchState carries about ghosts: an ARRAY (→ N13) of { id } for every present ghost, and the shared ward's
-- seconds left. What each ghost holds travels on ItemEvent (server/Orbs).
function Ghosts.state(r: Tag.Round?, g: Ghost.Ghosts?, now: number, present: (number) -> boolean): ({ any }, number)
	local list = {}
	if not (r and g) or r.over then return list, 0 end
	for _, id in r.order do
		if Ghost.isGhost(r, id) and present(id) then table.insert(list, { id = id }) end
	end
	return list, Ghost.wardLeft(g, now)
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
