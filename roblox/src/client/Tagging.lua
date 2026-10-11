-- The client's side of the tag (docs/systems/tag.md). It DECIDES nothing: it holds the server's last MatchState,
-- reports a candidate overlap as a TagClaim (rule 6, "client overlap"), and tells the frame loop when the local
-- runner is frozen (rule 1), in hit-stop (rule 21) or boosted as the chaser (rule 4). A cheating client can fake
-- all three locally; the server never trusts them (tag.md §2).
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

-- Every frame while the local runner is it: tag the first other live runner whose box touches ours on THIS screen.
function Tagging.claim(x: number, y: number)
	if not (claimRemote and state) or state.over or state.it ~= me or Tagging.frozen() then return end
	if os.clock() - lastClaimAt < CLAIM_EVERY then return end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and id ~= me and Tagging.isAlive(id) and root and root:IsA("BasePart") then
			local p = root.Position
			if Tag.overlaps(x, y, p.X, p.Y, 0) then
				lastClaimAt = os.clock()
				claimRemote:FireServer(id)
				return
			end
		end
	end
end

-- onState(state) after every MatchState; onVerdict(v) after every TagVerdict {from, to, fuse}.
function Tagging.start(player: Player, onState: (any) -> (), onVerdict: (any) -> ())
	me = player.UserId
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
	end)
end

return Tagging
