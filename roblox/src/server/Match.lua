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

local HISTORY = 30 -- server frames of positions kept per runner (~0.5 s): only the transport for Tag.confirm (→ S1)
local INTERP = 0.1 -- seconds added to the claimant's ping for Roblox's replication interpolation
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
	log(("round %d: %d runner(s), %s is it with %ds"):format(roundNo, #ids, tostring(starter), Config.FUSE_START))
	dirty = true
end

-- A confirmed tag, from a client's claim or the dummy's own check. Rules first, then positions.
local function tryTag(claimant: number, target: number, now: number, rewind: number, quiet: boolean?): boolean
	local r = round
	if not r then return false end
	local ok, why = Tag.canClaim(r, claimant, target, now)
	if not ok then
		if not quiet then log(("claim %s -> %s dropped: %s"):format(tostring(claimant), tostring(target), why)) end
		return false
	end
	local ha, hb = history[claimant], history[target]
	if not (ha and hb and Tag.confirm(ha, hb, now, rewind)) then
		if quiet then return false end
		log(("claim %s -> %s dropped: no overlap in the server's last %.2fs"):format(
			tostring(claimant), tostring(target), math.min(rewind, Config.TAG_REWIND_MAX)))
		return false
	end
	local fuse = Tag.pass(r, target, now)
	log(("TAG %s -> %s, fuse %.1fs"):format(tostring(claimant), tostring(target), fuse))
	if verdictRemote then verdictRemote:FireAllClients({ from = claimant, to = target, fuse = fuse }) end
	dirty = true
	return true
end

-- Client -> server. The payload is ONE number, the target's runner id; everything else is the server's own state.
local function onClaim(player: Player, target: any)
	local now = os.clock()
	if now - (lastClaim[player.UserId] or -math.huge) < Config.TAG_CLAIM_GAP then return end
	lastClaim[player.UserId] = now
	if type(target) ~= "number" or target ~= target or target % 1 ~= 0 then return end
	local ok, ping = pcall(function() return player:GetNetworkPing() end)
	tryTag(player.UserId, target, now, (if ok and type(ping) == "number" then ping else 0) + INTERP)
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
		if r.it == Dummy.ID then -- the dummy is the server's own runner: it claims for itself, with no rewind
			for _, id in r.order do
				if id ~= Dummy.ID and r.alive[id] and tryTag(Dummy.ID, id, now, 0, true) then break end
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
		roots[id], history[id], lastClaim[id] = nil, nil, nil
		if round then Tag.leave(round, id, os.clock()) dirty = true end
	end)
	RunService.Heartbeat:Connect(step)
	if useDummy then print("[Rotag] Studio: a dummy runner (orange box) joins the round; Config.STUDIO_DUMMY") end
end

return Match
