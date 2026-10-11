-- The round: who is "it", the fuse clock, confirming tags, eliminations (docs/systems/tag.md). The rules are
-- shared/Tag.lua (pure, tested); this file only feeds them positions and clocks and tells the clients. The server is
-- the ONLY side that changes "it" or the fuse (DESIGN §3 rule 6). Remotes: docs/systems/README.md.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Dummy = require(script.Parent:WaitForChild("Dummy"))

local Match = {}

local HISTORY = 60 -- server frames of positions kept per runner (~1 s at 60 Hz): covers a claim's whole window,
-- TAG_REWIND_MAX before it and TAG_CONFIRM_WAIT after it (0.85 s); only the transport for Tag.touchedBetween (→ S1)
local RESYNC = 1 -- seconds between state messages when nothing changed (late joiners, drift)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function remote(name: string): RemoteEvent?
	local r = remotes and remotes:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	warn(("[Rotag] ReplicatedStorage.Remotes.%s is missing (restart rojo serve to sync default.project.json);"
		.. " the tag runs without it"):format(name))
	return nil
end

local order: { number } = {} -- every runner id in join order: the rotation (rule 5)
local roots: { [number]: BasePart } = {}
local history: { [number]: { Tag.Sample } } = {}
local lastClaim: { [number]: number } = {}
-- Claims the server has not decided yet, one per claimant: { target, from, deadline, lag } (Tag.claimWindow).
local pending: { [number]: { target: number, from: number, deadline: number, lag: number } } = {}
local round: Tag.Round? = nil
local roundNo, nextRoundAt = 0, 0
local lastStarter: number? = nil
local lastSent, dirty = -math.huge, true
local dummy = nil
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] tag:", ...) end end

local function join(id: number)
	if not table.find(order, id) then table.insert(order, id) end
end

local function rootOf(id: number): BasePart?
	local r = roots[id]
	if r and r.Parent then return r end
	return nil
end

local function snapshot(now: number)
	local r = round
	local alive = {}
	if r then
		for _, id in r.order do if r.alive[id] then table.insert(alive, id) end end
	end
	return {
		round = roundNo,
		it = r and r.it,
		fuse = if r then Tag.fuseLeft(r, now) else 0,
		frozenFor = if r then math.max(0, r.frozenUntil - now) else 0,
		chaseFor = if r then now - r.chaseFrom else 0,
		alive = alive,
		over = r == nil or r.over,
		winner = r and r.winner,
	}
end

local stateRemote, verdictRemote, claimRemote

local function sendState(now: number, to: Player?)
	if not stateRemote then return end
	if to then stateRemote:FireClient(to, snapshot(now)) else stateRemote:FireAllClients(snapshot(now)) end
	lastSent, dirty = now, false
end

local function startRound(now: number)
	local present = {}
	for _, id in order do if rootOf(id) then present[id] = true end end
	local ids = {}
	for _, id in order do if present[id] then table.insert(ids, id) end end
	local anyPlayer = false
	for _, id in ids do if id ~= Dummy.ID then anyPlayer = true end end
	local starter = Tag.nextStarter(ids, present, lastStarter)
	if not (starter and anyPlayer) then return end -- the dummy never plays alone
	roundNo += 1
	lastStarter = starter
	round = Tag.newRound(ids, starter, now)
	table.clear(pending)
	log(("round %d: %d runner(s), %s is it with %ds"):format(roundNo, #ids, tostring(starter), Config.FUSE_START))
	dirty = true
end

-- A confirmed tag: hand the fuse over and tell everyone.
local function pass(r: Tag.Round, claimant: number, target: number, now: number)
	local fuse = Tag.pass(r, target, now)
	log(("TAG %s -> %s, fuse %.1fs"):format(tostring(claimant), tostring(target), fuse))
	if verdictRemote then verdictRemote:FireAllClients({ from = claimant, to = target, fuse = fuse }) end
	dirty = true
end

-- Judge one claim over the server's own history (Tag.touchedBetween). Rules first (again: the round may have moved
-- on since the claim arrived), then positions. Returns true once decided (tagged, or refused by the rules).
local function judge(claimant: number, target: number, from: number, to: number, lag: number, now: number): boolean
	local r = round
	if not r then return true end
	local ok, why = Tag.canClaim(r, claimant, target, now)
	if not ok then
		log(("claim %s -> %s dropped: %s"):format(tostring(claimant), tostring(target), tostring(why)))
		return true
	end
	local ha, hb = history[claimant], history[target]
	if not (ha and hb and Tag.touchedBetween(ha, hb, from, to, lag)) then return false end
	pass(r, claimant, target, now)
	return true
end

-- For the Studio log only: the closest the boxes came (x gap, y gap) over the pairs Tag.touchedBetween looks at.
local function closest(a: { Tag.Sample }, b: { Tag.Sample }, from: number, to: number, lag: number): (number, number)
	local bx, by = math.huge, math.huge
	for _, sa in a do
		for _, sb in b do
			if sb.t >= from and sa.t <= to and sb.t <= sa.t and sa.t - sb.t <= lag and math.abs(sa.x - sb.x) < bx then
				bx, by = math.abs(sa.x - sb.x), math.abs(sa.y - sb.y)
			end
		end
	end
	return bx, by
end

-- Every frame: pending claims are judged again as the claimant's late-arriving positions land (H6: in Studio the
-- server sees a client-owned body ~0.15 s after the claim about it arrives, ~7 studs behind at run speed).
local function judgePending(now: number)
	for claimant, p in pending do
		if judge(claimant, p.target, p.from, math.min(now, p.deadline), p.lag, now) then
			pending[claimant] = nil
		elseif now >= p.deadline then
			pending[claimant] = nil
			local gx, gy = closest(history[claimant] or {}, history[p.target] or {}, p.from, p.deadline, p.lag)
			log(("claim %s -> %s dropped: no overlap, target up to %.2fs older, until %.2fs after it (closest: %.1f, %.1f"
				.. " studs apart)"):format(tostring(claimant), tostring(p.target), p.lag, Config.TAG_CONFIRM_WAIT, gx, gy))
		end
	end
end

-- Client -> server. The payload is ONE number, the target's runner id; everything else is the server's own state.
-- A newer claim replaces the claimant's pending one: the old window up to now has already been checked every frame.
local function onClaim(player: Player, target: any)
	local now = os.clock()
	if now - (lastClaim[player.UserId] or -math.huge) < Config.TAG_CLAIM_GAP then return end
	lastClaim[player.UserId] = now
	if type(target) ~= "number" or target ~= target or target % 1 ~= 0 then return end
	local ok, ping = pcall(function() return player:GetNetworkPing() end)
	local from, deadline, lag = Tag.claimWindow(now, (if ok and type(ping) == "number" then ping else 0)
		+ Config.TAG_VIEW_DELAY)
	if judge(player.UserId, target, from, now, lag, now) then
		pending[player.UserId] = nil
	else
		pending[player.UserId] = { target = target, from = from, deadline = deadline, lag = lag }
	end
end

local function sample(now: number)
	for id, root in roots do
		if root.Parent then
			local h = history[id] or {}
			history[id] = h
			local p = root.Position
			table.insert(h, { t = now, x = p.X, y = p.Y })
			if #h > HISTORY then table.remove(h, 1) end
		end
	end
end

local function nearestAlivePlayerX(r: Tag.Round, x: number): number?
	local best, bestD = nil, math.huge
	for _, id in r.order do
		local root = rootOf(id)
		if id ~= Dummy.ID and r.alive[id] and root then
			local d = math.abs(root.Position.X - x)
			if d < bestD then best, bestD = root.Position.X, d end
		end
	end
	return best
end

local function step(dt: number)
	local now = os.clock()
	local r = round
	if dummy then
		local chase = r and not r.over and r.it == Dummy.ID and not Tag.frozen(r, now)
		Dummy.step(dummy, dt, if chase and r then nearestAlivePlayerX(r, dummy.root.Position.X) else nil,
			r ~= nil and r.it == Dummy.ID and Tag.frozen(r, now))
	end
	sample(now)
	if r and not r.over then
		judgePending(now)
		if r.it == Dummy.ID then -- the dummy is the server's own runner: it claims for itself, this frame only
			for _, id in r.order do
				if id ~= Dummy.ID and r.alive[id] and Tag.canClaim(r, Dummy.ID, id, now) then
					local ha, hb = history[Dummy.ID], history[id]
					if ha and hb and Tag.confirm(ha, hb, now, 0) then pass(r, Dummy.ID, id, now) break end
				end
			end
		end
		local out = Tag.tick(r, now)
		if out then
			log(("%s's fuse ran out%s"):format(tostring(out), if r.over then
				(", round over, winner " .. tostring(r.winner)) else (", " .. tostring(r.it) .. " is it")))
			dirty = true
		end
		if r.over then nextRoundAt = now + Config.ROUND_GAP end
	elseif now >= nextRoundAt then
		startRound(now)
	end
	if dirty or now - lastSent >= RESYNC then sendState(now) end
end

-- Call once at boot, after the map exists and before Runners.start.
function Match.start(tagName: string)
	stateRemote, verdictRemote, claimRemote = remote("MatchState"), remote("TagVerdict"), remote("TagClaim")
	-- Server -> client events: the server never listens (→ N3).
	if stateRemote then stateRemote.OnServerEvent:Connect(function() end) end
	if verdictRemote then verdictRemote.OnServerEvent:Connect(function() end) end
	if claimRemote then claimRemote.OnServerEvent:Connect(onClaim) end
	local useDummy = studio and Config.STUDIO_DUMMY -- read once (→ N1); never in a live server
	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(model)
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(id) == "number" and root and root:IsA("BasePart") then
			roots[id] = root
			history[id] = {}
		end
	end)
	local function onPlayer(player: Player)
		join(player.UserId)
		if useDummy and not dummy then
			dummy = Dummy.new(tagName) -- after the first player, so round 1 starts with a person as it
			join(Dummy.ID)
		end
		sendState(os.clock(), player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		local id = player.UserId
		local i = table.find(order, id)
		if i then table.remove(order, i) end
		roots[id], history[id], lastClaim[id], pending[id] = nil, nil, nil, nil
		if round then Tag.leave(round, id, os.clock()) dirty = true end
	end)
	RunService.Heartbeat:Connect(step)
	if useDummy then print("[Rotag] Studio: a dummy runner (orange box) joins the round; Config.STUDIO_DUMMY") end
end

return Match
