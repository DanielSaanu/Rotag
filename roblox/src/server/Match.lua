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
local Runners = require(script.Parent:WaitForChild("Runners"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local MoveGuard = require(script.Parent:WaitForChild("MoveGuard"))
local Snapshots = require(script.Parent:WaitForChild("Snapshots"))

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
local function unreliable(name: string): UnreliableRemoteEvent?
	local r = remotes and remotes:FindFirstChild(name)
	return if r and r:IsA("UnreliableRemoteEvent") then r else nil -- server/Snapshots warns
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
-- Round-ready (H11, players.md §5): players whose client has drawn its runner (Remotes.Ready), and since when the
-- next round has been due but held for them.
local ready: { [number]: boolean } = {}
local dueSince: number? = nil
local BOTS = { [Dummy.ID] = true }
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
	local alive, spectating = {}, {}
	if r then
		for _, id in r.order do if r.alive[id] then table.insert(alive, id) end end
	end
	-- Present but not in this round (joined after it began): "next round soon", not "out" (H8).
	for _, id in order do
		if rootOf(id) and not (r and table.find(r.order, id)) then table.insert(spectating, id) end
	end
	return {
		round = roundNo,
		it = r and r.it,
		fuse = if r then Tag.fuseLeft(r, now) else 0,
		frozenFor = if r then math.max(0, r.frozenUntil - now) else 0,
		chaseFor = if r then now - r.chaseFrom else 0,
		alive = alive,
		spectating = spectating,
		over = r == nil or r.over,
		winner = r and r.winner,
	}
end

local stateRemote, verdictRemote, claimRemote, readyRemote

-- Client -> server, no payload (→ N4): "my client is up and has drawn my runner". Only the sender is read; a second
-- one changes nothing. A client that lies only starts a round it cannot see yet.
local function onReady(player: Player)
	local id = player.UserId
	if ready[id] then return end
	ready[id] = true
	log(("%s ready (client drew its runner)"):format(tostring(id)))
end

local function sendState(now: number, to: Player?)
	if not stateRemote then return end
	if to then stateRemote:FireClient(to, snapshot(now)) else stateRemote:FireAllClients(snapshot(now)) end
	lastSent, dirty = now, false
end

-- Round start (H8, tag.md §4): every runner to its spot from Tag.startPlaces. A player's body is REBUILT there
-- (Runners.spawn): the client owns its physics, and a server CFrame write on a moving owned body is overwritten by
-- the owner's next update (seen in Studio: x -60 for 0.2 s, then the owner's x again). A new part placed before
-- SetNetworkOwner is the one placement the owner cannot undo, and its client starts a fresh Movement state there.
local function place(id: number, x: number)
	history[id] = {}
	if id == Dummy.ID then
		if dummy then Dummy.place(dummy, x) end
		return
	end
	local player = Players:GetPlayerByUserId(id)
	if player then Runners.spawn(player, Vector3.new(x, Arena.SPAWN.Y, 0)) end
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
	local since = dueSince or now
	if not dueSince then
		dueSince = now
		if not Tag.readyToStart(ids, ready, BOTS, 0) then log("round held: waiting for every client to draw") end
	end
	if not Tag.readyToStart(ids, ready, BOTS, now - since) then return end
	dueSince = nil
	for _, id in ids do
		if not (BOTS[id] or ready[id]) then
			log(("%s never sent Ready; started after %ds anyway"):format(tostring(id), Config.READY_TIMEOUT))
		end
	end
	roundNo += 1
	lastStarter = starter
	for id, x in Tag.startPlaces(ids, starter, Arena.SPAWN.X, Config.START_SPREAD) do place(id, x) end
	round = Tag.newRound(ids, starter, now)
	table.clear(pending)
	log(("round %d: %d runner(s), %s is it with %ds"):format(roundNo, #ids, tostring(starter), Config.FUSE_START))
	dirty = true
end

-- A confirmed tag: hand the fuse over and tell everyone.
local function pass(r: Tag.Round, claimant: number, target: number, now: number)
	local fuse, gained = Tag.pass(r, target, now)
	log(("TAG %s -> %s, fuse %.1fs (+%.1fs)"):format(tostring(claimant), tostring(target), fuse, gained))
	if verdictRemote then
		verdictRemote:FireAllClients({ from = claimant, to = target, fuse = fuse, gained = gained })
	end
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

-- For the Studio log only (H13, tag.md §2): the YOUNGEST target age at which the boxes did overlap for this claim,
-- over every target sample in the history, whatever the allowance. The age of a pair is how far the target sample is
-- behind the claimant's sample or the claim's arrival `at`, whichever is more (touchedBetween needs both inside lag).
-- nil: no overlap at any age the history holds (~1 s). Also how many claimant samples in the window were untrusted.
local function neededAge(a: { Tag.Sample }, b: { Tag.Sample }, from: number, to: number, at: number): (number?, number)
	local best, untrusted = nil, 0
	for _, sa in a do
		if sa.t >= from and sa.t <= to then
			if sa.untrusted then
				untrusted += 1
			else
				for _, sb in b do
					if sb.t <= sa.t and Tag.overlaps(sa.x, sa.y, sb.x, sb.y, Config.TAG_GRACE) then
						local age = math.max(sa.t - sb.t, at - sb.t)
						if best == nil or age < best then best = age end
					end
				end
			end
		end
	end
	return best, untrusted
end

-- Every frame: pending claims are judged again as the claimant's late-arriving positions land (H6: in Studio the
-- server sees a client-owned body ~0.15 s after the claim about it arrives, ~7 studs behind at run speed).
local function judgePending(now: number)
	for claimant, p in pending do
		if judge(claimant, p.target, p.from, math.min(now, p.deadline), p.lag, now) then
			pending[claimant] = nil
		elseif now >= p.deadline then
			pending[claimant] = nil
			local ha, hb = history[claimant] or {}, history[p.target] or {}
			local gx, gy = closest(ha, hb, p.from, p.deadline, p.lag)
			local need, bad = neededAge(ha, hb, p.from, p.deadline, p.from + p.lag)
			log(("claim %s -> %s dropped: no overlap, target up to %.2fs older, until %.2fs after it (closest: %.1f, %.1f"
				.. " studs apart); %s; %d claimant sample(s) untrusted"):format(tostring(claimant), tostring(p.target), p.lag,
				Config.TAG_CONFIRM_WAIT, gx, gy, if need then ("overlap WAS there with the target %.2fs old"):format(need)
					else "no overlap at any target age in the history", bad))
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
	-- H13: one line per new claim (a repeat against the same target while one is open is not logged), so a run with
	-- no claim lines at all says the client never saw an overlap, not that the server refused one.
	local open = pending[player.UserId]
	if not (open and open.target == target) then
		log(("claim %s -> %s received, ping %.0f ms, target may be up to %.2fs older"):format(tostring(player.UserId),
			tostring(target), (if ok and type(ping) == "number" then ping else 0) * 1000, lag))
	end
	if judge(player.UserId, target, from, now, lag, now) then
		pending[player.UserId] = nil
	else
		pending[player.UserId] = { target = target, from = from, deadline = deadline, lag = lag }
	end
end

-- H14: a player's position is its newest snapshot (server/Snapshots, netcode.md §8); the body only when none has come
-- for SNAPSHOT_STALE, or the server just rebuilt it. The dummy is the server's own body. Same history, same MoveCheck.
local function sample(now: number)
	for id, root in roots do
		if root.Parent then
			local h = history[id] or {}
			history[id] = h
			local x, y = Snapshots.positionOf(id, now)
			if not (x and y) then
				local p = root.Position
				x, y = p.X, p.Y
			end
			local s: Tag.Sample = { t = now, x = x, y = y }
			MoveGuard.observe(id, root, s) -- the speed check (H12, trust.md): may mark s untrusted for a claim
			table.insert(h, s)
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
	readyRemote = remote("Ready")
	if readyRemote then readyRemote.OnServerEvent:Connect(onReady) end
	Snapshots.start(unreliable("Snapshot"))
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
			local p = root.Position
			Snapshots.bodyBuilt(id, p.X, p.Y, os.clock()) -- in-flight snapshots about the old body are dropped
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
		roots[id], history[id], lastClaim[id], pending[id], ready[id] = nil, nil, nil, nil, nil
		MoveGuard.forget(id)
		local r = round
		if r and not r.over then
			local now = os.clock()
			Tag.leave(r, id, now)
			-- A leave can end the round too (H7): give it the same gap and "wins the round" screen as the tick path,
			-- or the next frame starts a new round at once.
			if r.over then
				nextRoundAt = now + Config.ROUND_GAP
				log(("%s left, round over, winner %s"):format(tostring(id), tostring(r.winner)))
			end
			dirty = true
		end
	end)
	RunService.Heartbeat:Connect(step)
	if useDummy then print("[Rotag] Studio: a dummy runner (orange box) joins the round; Config.STUDIO_DUMMY") end
end

return Match
