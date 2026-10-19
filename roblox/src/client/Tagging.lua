-- The client's side of the tag (docs/systems/tag.md). It DECIDES nothing: it holds the server's last MatchState,
-- reports a candidate overlap as a TagClaim (rule 6, "client overlap"), and tells the frame loop when the local
-- runner is frozen (rule 1), in hit-stop (rule 21) or boosted as the chaser (rule 4). A cheating client can fake
-- all three locally; the server never trusts them (tag.md §2). H15: as a ghost it reports a touch on the holder as a
-- GhostClaim the same way (docs/systems/ghosts.md); the server judges it and owns every effect.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))

local Tagging = {}

local RUNNER_TAG = "RotagRunner" -- server/Runners.lua Runners.TAG
local CLAIM_EVERY = 0.15 -- seconds between claims; above the server's TAG_CLAIM_GAP so none is dropped as spam
local WAIT = 10

local me = 0
local state = nil -- the server's last snapshot (server/Match.lua), plus `at` = os.clock() on arrival
local hitStopUntil, lastClaimAt = 0, -math.huge
local claimRemote: RemoteEvent? = nil
local ghostRemote: RemoteEvent? = nil
local lastSpookAt = -math.huge

local function since(): number
	return if state then os.clock() - state.at else 0
end

function Tagging.state() return state end
function Tagging.me(): number return me end
function Tagging.isAlive(id: number): boolean
	return state ~= nil and table.find(state.alive, id) ~= nil
end
function Tagging.fuseLeft(): number
	if not state then return 0 end
	local burning = math.max(0, since() - state.frozenFor)
	return math.max(0, state.fuse - (if state.over then 0 else burning))
end
function Tagging.frozenLeft(): number
	return if state then math.max(0, state.frozenFor - since()) else 0
end
-- The local runner holds still: frozen as the new it, or in a tag's hit-stop.
function Tagging.frozen(): boolean
	return state ~= nil and not state.over and state.it == me and Tagging.frozenLeft() > 0
end
function Tagging.hitStopped(): boolean
	return os.clock() < hitStopUntil
end
function Tagging.speedMult(): number
	if not state or state.over or state.it ~= me then return 1 end
	return Tag.chaserBoost(state.chaseFor + since())
end

-- H15: this runner's entry in MatchState.ghosts ({ id, ready, comebacks }), or nil if it is not a ghost.
function Tagging.ghost(id: number): any
	if not state or state.over then return nil end
	for _, e in state.ghosts do
		if e.id == id then return e end
	end
	return nil
end
-- Seconds until `id`'s spook is ready by its own cooldown (0 = ready), and until the shared ward ends.
function Tagging.readyIn(id: number): number
	local e = Tagging.ghost(id)
	return if e then math.max(0, e.ready - since()) else math.huge
end
function Tagging.wardLeft(): number
	return if state then math.max(0, state.ward - since()) else 0
end

-- Where another runner is on THIS screen: set by Tagging.start (client/Others.positionOf, H14: the snapshot stream's
-- spot, ~0.1 s old, not the replicated root, ~0.4 s old). The server judges the claim on the same stream.
local positionOf: (BasePart) -> Vector3 = function(root) return root.Position end

-- Every frame while the local runner is it: tag the first other live runner whose box touches ours on THIS screen.
function Tagging.claim(x: number, y: number)
	if not (claimRemote and state) or state.over or state.it ~= me or Tagging.frozen() then return end
	if os.clock() - lastClaimAt < CLAIM_EVERY then return end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and id ~= me and Tagging.isAlive(id) and root and root:IsA("BasePart") then
			local p = positionOf(root)
			if Tag.overlaps(x, y, p.X, p.Y, 0) then
				lastClaimAt = os.clock()
				claimRemote:FireServer(id)
				return
			end
		end
	end
end

-- Every frame while the local runner is a ghost (H15, DESIGN §3 rule 38): a touch on the holder's DRAWN spot, with
-- this ghost's cooldown and the shared ward over and the holder not frozen as this screen sees them, is a GhostClaim.
-- The server checks all of it again on its own clock and its own position record.
function Tagging.spook(x: number, y: number)
	if not (ghostRemote and state) or state.over or not state.it or not Tagging.ghost(me) then return end
	if Tagging.readyIn(me) > 0 or Tagging.wardLeft() > 0 or Tagging.frozenLeft() > 0 then return end
	if os.clock() - lastSpookAt < CLAIM_EVERY then return end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if model:GetAttribute("RunnerId") == state.it and root and root:IsA("BasePart") then
			local p = positionOf(root)
			if Tag.overlaps(x, y, p.X, p.Y, 0) then
				lastSpookAt = os.clock()
				ghostRemote:FireServer(state.it)
			end
			return
		end
	end
end

-- onState(state) after every MatchState; onVerdict(v) after every TagVerdict {from, to, fuse, gained};
-- where(root) = where that runner is drawn on this screen (H14); onSpook(v) after every GhostVerdict
-- {from, to, drained, fuse, mark} (H15).
function Tagging.start(player: Player, onState: (any) -> (), onVerdict: (any) -> (), where: ((BasePart) -> Vector3)?,
	onSpook: ((any) -> ())?)
	me = player.UserId
	if where then positionOf = where end
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		local function find(name: string): RemoteEvent?
			local r = remotes and remotes:WaitForChild(name, WAIT)
			if r and r:IsA("RemoteEvent") then return r end
			warn(("[Rotag] no Remotes.%s (restart rojo serve); no tag on this client"):format(name))
			return nil
		end
		local stateRemote, verdictRemote = find("MatchState"), find("TagVerdict")
		claimRemote = find("TagClaim")
		if stateRemote then
			stateRemote.OnClientEvent:Connect(function(s: any)
				-- Shape only (→ N3): the server is the only sender, but a malformed table must not break the HUD.
				if type(s) ~= "table" or type(s.fuse) ~= "number" or type(s.alive) ~= "table" then return end
				s.frozenFor = tonumber(s.frozenFor) or 0
				s.chaseFor = tonumber(s.chaseFor) or 0
				s.ward = tonumber(s.ward) or 0 -- H15: absent from an older server, so default to "no ghosts"
				local ghosts = {}
				if type(s.ghosts) == "table" then
					for _, e in s.ghosts do
						if type(e) == "table" and type(e.id) == "number" and type(e.ready) == "number" then
							table.insert(ghosts, { id = e.id, ready = e.ready, comebacks = tonumber(e.comebacks) or 0 })
						end
					end
				end
				s.ghosts = ghosts
				if type(s.mark) ~= "number" then s.mark = nil end
				s.at = os.clock()
				state = s
				onState(s)
			end)
		end
		if verdictRemote then
			verdictRemote.OnClientEvent:Connect(function(v: any)
				if type(v) ~= "table" or type(v.to) ~= "number" or type(v.fuse) ~= "number" then return end
				if v.from == me or v.to == me then hitStopUntil = os.clock() + Config.HIT_STOP end
				onVerdict(v)
			end)
		end
		-- H15, last: an old rojo serve lacks these two (→ T6), and waiting for them must not hold up the tag above.
		ghostRemote = find("GhostClaim")
		local ghostVerdict = find("GhostVerdict")
		if ghostVerdict then
			ghostVerdict.OnClientEvent:Connect(function(v: any)
				if type(v) ~= "table" or type(v.from) ~= "number" or type(v.drained) ~= "number" then return end
				if onSpook then onSpook(v) end
			end)
		end
	end)
end

return Tagging
