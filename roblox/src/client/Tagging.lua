-- The client's side of the tag (docs/systems/tag.md). It DECIDES nothing: it holds the server's last MatchState,
-- reports a candidate overlap as a TagClaim (rule 6, "client overlap"), and tells the frame loop when the local
-- runner is frozen (rule 1), in hit-stop (rule 21) or boosted as the chaser (rule 4). A cheating client can fake
-- all three locally; the server never trusts them (tag.md §2). H18: as a ghost holding a hex it reports a touch on the
-- holder as a GhostClaim the same way (docs/systems/ghosts.md); the server judges it and owns every effect.
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
local lastHexAt = -math.huge

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
-- H22, rule 46: the holder's ramp or a ghost's boost grant, never both: Tag.speedMult = max(ramp, grant). H23, rule
-- 51: x END_PHASE_SPEED for the living while the server's MatchState says the end phase is on (endgame.md).
function Tagging.speedMult(granted: boolean?): number
	if not state or state.over then return 1 end
	return Tag.speedMult(state.it == me, state.chaseFor + since(), granted == true,
		state.endPhase and Tagging.isAlive(me))
end
-- H23, rule 50: how far runner `id`'s ignition has grown (0..1): only the holder, from the replicated fuse.
function Tagging.ignition(id: number): number
	if not state or state.over or state.it ~= id then return 0 end
	return Tag.ignition(Tagging.fuseLeft())
end

-- H24: seconds of grace runner `id` has left outside the walls, as the server last said (counted down since), or nil
-- if the server has it inside. The server decides; this only draws.
function Tagging.graceLeft(id: number): number?
	if not state or state.over then return nil end
	for _, e in state.outside do
		if e.id == id then return if e.held then e.left else math.max(0, e.left - since()) end -- held: the server paused it
	end
	return nil
end

-- This runner's entry in MatchState.ghosts ({ id }, H18), or nil if it is not a ghost.
function Tagging.ghost(id: number): any
	if not state or state.over then return nil end
	for _, e in state.ghosts do
		if e.id == id then return e end
	end
	return nil
end
-- Seconds until the shared ward ends (no hex lands before then).
function Tagging.wardLeft(): number
	return if state then math.max(0, state.ward - since()) else 0
end

-- Where another runner is on THIS screen: set by Tagging.start (client/Others.positionOf, H14: the snapshot stream's
-- spot, ~0.1 s old, not the replicated root, ~0.4 s old). The server judges the claim on the same stream.
local positionOf: (BasePart) -> Vector3 = function(root) return root.Position end

-- H38: is another runner drawn mid-dash on this screen (client/Others.dashing)? Set by the client entry point.
Tagging.dodging = function(_root: BasePart): boolean return false end

-- H40, Studio only: one line per close pass of the holder by another runner AS THIS SCREEN DRAWS IT, so "no claim
-- was sent" can be told from "the server refused the claim" (the server logs that side): the closest box gap (studs
-- between the two boxes' edges, x and y), whether a claim fired, and whether the runner was drawn dashing (dodging).
local studio = game:GetService("RunService"):IsStudio()
local NEAR = 3 -- studs of box gap that count as a close pass
local near: { [number]: { gx: number, gy: number, claimed: boolean, dodging: boolean } } = {}
local function watch(id: number, x: number, y: number, p: Vector3, dodging: boolean)
	local gx = math.max(0, math.abs(x - p.X) - Config.RUNNER_WIDTH)
	local gy = math.max(0, math.abs(y - p.Y) - Config.RUNNER_HEIGHT)
	local e = near[id]
	if math.max(gx, gy) <= NEAR then
		if not e then e = { gx = gx, gy = gy, claimed = false, dodging = false } near[id] = e end
		if math.max(gx, gy) < math.max(e.gx, e.gy) then e.gx, e.gy = gx, gy end
		e.dodging = e.dodging or dodging
	elseif e then
		near[id] = nil
		print(("[Rotag] tag: close pass %d: closest box gap %.2f, %.2f studs (reach %.2f), %s%s"):format(id, e.gx, e.gy,
			Config.TAG_REACH, if e.claimed then "claimed" else "NO claim", if e.dodging then ", drawn dashing" else ""))
	end
end

-- Every frame while the local runner is it: tag the first other live runner whose box touches ours on THIS screen.
-- H38: while we DASH (`dashing`, from (px, py) last frame to here) the whole of that step counts, with a little more
-- reach: a dash into or through a runner is a tag. H40: a runner drawn mid-dash is claimed too (below).
function Tagging.claim(x: number, y: number, px: number?, py: number?, dashing: boolean?)
	if not (claimRemote and state) or state.over or state.it ~= me or Tagging.frozen() then return end
	local ready = os.clock() - lastClaimAt >= CLAIM_EVERY
	if not (ready or studio) then return end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and id ~= me and Tagging.isAlive(id) and root and root:IsA("BasePart") then
			local p = positionOf(root)
			local dodging = Tagging.dodging(root)
			if studio then watch(id, x, y, p, dodging) end
			local hit = Tag.overlaps(x, y, p.X, p.Y, 0)
				or (dashing == true and px ~= nil and py ~= nil and Tag.sweeps(px, py, x, y, p.X, p.Y, Config.TAG_DASH_REACH))
			-- H40: claimed even when the runner is drawn dashing: whether its dash dodges (at or through us, or both
			-- dashing) is the server's call on its own record (Tag.dodges); this screen cannot see where a dash began
			if ready and hit then
				lastClaimAt = os.clock()
				if near[id] then near[id].claimed = true end
				claimRemote:FireServer(id)
				return
			end
		end
	end
end

-- H38: are we, dashing, passing through the holder right now (its tag cannot land)? True at most once a second: the
-- "DODGED!" pop. What this screen sees only; the server's own record decides whether a tag lands.
-- H40: only a dash aimed at the holder (it lies ahead of where our dash began) or one while it dashes too is a dodge
-- (Tag.dodges on the server); a dash away from a touch is a tag, so it pops nothing.
local lastDodge = -math.huge
local dashFrom: number? = nil
function Tagging.dodge(x: number, y: number, dashing: boolean): boolean
	if not dashing then dashFrom = nil elseif dashFrom == nil then dashFrom = x end
	if not (dashing and state) or state.over or state.it == nil or state.it == me or not Tagging.isAlive(me) then return false end
	if os.clock() - lastDodge < 1 then return false end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if model:GetAttribute("RunnerId") == state.it and root and root:IsA("BasePart") then
			local p = positionOf(root)
			local from = dashFrom or x
			local aimed = (p.X - from) * (x - from) > 0 or Tagging.dodging(root)
			if aimed and Tag.overlaps(x, y, p.X, p.Y, 0.5) then
				lastDodge = os.clock()
				return true
			end
			return false
		end
	end
	return false
end

-- Every frame while the local runner is a ghost holding a hex (the caller checks the slot; H18, DESIGN §3 rule 40):
-- a touch on the holder's DRAWN spot, with the shared ward over and the holder not frozen as this screen sees them, is
-- a GhostClaim. The server checks all of it again (the hex too) on its own clock and its own position record.
function Tagging.hex(x: number, y: number)
	if not (ghostRemote and state) or state.over or not state.it or not Tagging.ghost(me) then return end
	if Tagging.wardLeft() > 0 or Tagging.frozenLeft() > 0 then return end
	if os.clock() - lastHexAt < CLAIM_EVERY then return end
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if model:GetAttribute("RunnerId") == state.it and root and root:IsA("BasePart") then
			local p = positionOf(root)
			if Tag.overlaps(x, y, p.X, p.Y, 0) then
				lastHexAt = os.clock()
				ghostRemote:FireServer(state.it)
			end
			return
		end
	end
end

-- onState(state) after every MatchState; onVerdict(v) after every TagVerdict {from, to, fuse, gained};
-- where(root) = where that runner is drawn on this screen (H14); onSpook(v) after every GhostVerdict
-- {from, to, drained, fuse} (a hex, H18).
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
				s.endPhase = s.endPhase == true -- H23: absent or malformed reads as a normal fuse
				local ghosts = {}
				if type(s.ghosts) == "table" then
					for _, e in s.ghosts do
						if type(e) == "table" and type(e.id) == "number" then table.insert(ghosts, { id = e.id }) end
					end
				end
				s.ghosts = ghosts
				local w = s.window -- H24: the closing walls (endgame.md §7); absent or malformed reads as none
				s.window = if type(w) == "table" and type(w.x) == "number" and type(w.hw) == "number" then
					{ x = w.x, hw = w.hw, vx = tonumber(w.vx) or 0, vhw = math.min(0, tonumber(w.vhw) or 0) } else nil
				local outside = {}
				for _, e in (if type(s.outside) == "table" then s.outside else {}) do
					if type(e) == "table" and type(e.id) == "number" and type(e.left) == "number" then
						table.insert(outside, { id = e.id, left = e.left, held = e.held == true })
					end
				end
				s.outside = outside
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
