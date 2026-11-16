-- The match on the server (H31; DESIGN §6.4, rules 31-34; docs/systems/session.md). The rules are shared/Session
-- (pure, tested): lobby -> MATCH_ROUNDS rounds with a results gap after each -> podium -> lobby. This file owns the
-- one state, who is IN (pressed Play in the menu: only they get a runner body and a seat), seats the bots, pays the
-- match's coins and tells every client over Remotes.Session. server/Match asks it when a round may start and with
-- whom, and reports each round's eliminations and end; a round itself is still Match's and shared/Tag's.
-- Remotes.Menu (client -> server, → N4): ONE string, "play" or "sit"; the sender is the Player; rate-gapped; anything
-- else is dropped unread. A client that lies only puts ITSELF in or out of the next round.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Rules = require(Shared:WaitForChild("Session"))
local Profile = require(Shared:WaitForChild("Profile"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Runners = require(script.Parent:WaitForChild("Runners"))
local Hub = require(script.Parent:WaitForChild("Hub")) -- H34: is this server a hub, a match server, or both in one

local Session = {}

type Context = {
	present: (number) -> boolean, -- does runner `id` have a body
	drop: (number) -> (),         -- runner `id` leaves the round in progress (sat out)
	abort: () -> (),              -- everybody left: end the round in progress
	spawn: Vector3,
}

local MENU_GAP = 0.4 -- seconds between two Menu requests from one player
local RESYNC = 1

local state = Rules.new()
local order: { number } = {} -- people in join order
local playing: { [number]: boolean } = {}
local due: { number }? = nil -- the roster of the round that may start now
-- H34, a hub only: since when somebody has been queued (the wait's clock), and who has been sent to a match server
-- and when (they are still here for a few seconds: not queued twice; LAUNCH_STALE later the teleport is taken to
-- have failed and they are queued again).
local queueSince: number? = nil
local launching: { [number]: number } = {}
local LAUNCH_STALE = 20
local RETRY = 3 -- seconds a group waits after a failed launch (QA round 3: it restarted the whole LOBBY_TIME)
-- H34, a match server only (QA round 3): how many players the hub sent here, since when the first of them arrived,
-- and how long the lobby's countdown is held for the rest (a phone can take 20 s to load: without this a friend
-- arrived to watch round 1 with a bot in their seat).
local expected, firstAt = 1, nil :: number?
local waitingFor: number? = nil
local GROUP_WAIT = 25
local ctx: Context? = nil
local remote: RemoteEvent? = nil
local lastMenu: { [number]: number } = {}
local lastSent, dirty = -math.huge, true
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] session:", ...) end end

-- The people who are in and have a body, in join order.
local function people(): { number }
	local out = {}
	local c = ctx
	local now = os.clock()
	for _, id in order do
		local sent = launching[id]
		if sent and now - sent > LAUNCH_STALE then launching[id], sent = nil, nil end
		if playing[id] and not sent and c and c.present(id) then table.insert(out, id) end
	end
	return out
end

local function view(now: number): any
	local v = Rules.view(state, now)
	local ins = {}
	for _, id in order do if playing[id] then table.insert(ins, id) end end
	v.playing = ins
	v.seed = Bots.SEED -- H32: the bots' names (shared/Session.botName) are the same on every screen
	v.mode = Hub.MODE -- H34: "hub" | "match" | "solo": what PLAY means on this server, and what the lobby line says
	if waitingFor then v.waiting = { #people(), waitingFor } end -- a match server holding its lobby for its group
	if Hub.MODE == "hub" then -- a queue, not a countdown to a round here
		local sent = {}
		for id in launching do table.insert(sent, id) end
		v.phase, v.queued, v.launching = "lobby", #people(), sent
		v.left = if queueSince then math.max(0, Config.LOBBY_TIME - (now - queueSince)) else -1
	end
	return v
end

local function send(now: number, to: Player?)
	if not remote then return end
	if to then remote:FireClient(to, view(now)) else remote:FireAllClients(view(now)) end
	if not to then lastSent, dirty = now, false end
end

-- The podium: everybody who played is paid (DESIGN §6.5), the winner a win.
local function pay()
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		local coins = Rules.reward(state, id)
		if coins > 0 then
			local levels = 0
			Data.update(player, function(p: Profile.Profile)
				levels = Profile.earn(p, coins)
				p.matches += 1
				if state.winner == id then p.wins += 1 end
			end)
			Shop.push(player, { earned = coins, levels = levels })
			log(("%s earned %d coins"):format(player.Name, coins))
		end
	end
end

-- The bots that should exist now: the roster's during a match; in a lobby with people in it, company to warm up with.
local function seatBots(roster: { number }?)
	if roster then
		Bots.ensure(roster)
	elseif Config.BOTS and #people() > 0 then
		local ids = {}
		for k = 1, math.max(0, Config.PLAYERS_PER_MATCH - #people()) do table.insert(ids, Rules.botId(k)) end
		Bots.ensure(ids)
	else
		Bots.ensure({})
	end
end

-- H34, a hub: no round ever runs here. Whoever pressed PLAY is queued (with a body, to warm up); the moment the
-- seats are full, or LOBBY_TIME after the first of them queued, the longest-waiting group is sent to a match server
-- of its own (Hub.launch; the bots that fill its empty seats are seated there).
local function stepHub(now: number, ins: { number })
	if #ins == 0 then
		queueSince = nil
	else
		queueSince = queueSince or now
		if #ins >= Config.PLAYERS_PER_MATCH or now - queueSince >= Config.LOBBY_TIME then
			local group = {}
			for _, id in Rules.pick(state, ins, false) do
				local p = Players:GetPlayerByUserId(id)
				if p then
					table.insert(group, p)
					launching[id] = now
				end
			end
			if #group > 0 then
				Hub.launch(group)
				print(("[Rotag] session: match found for %d of %d queued"):format(#group, #ins))
			end
			queueSince = if #ins > #group then now else nil -- whoever is left starts a new wait
			dirty = true
		end
	end
	if dirty or now - lastSent >= RESYNC then send(now) end
end

-- Every server frame, before Match decides whether to start a round.
function Session.step(now: number)
	local ins = people()
	if Hub.MODE == "hub" then
		stepHub(now, ins)
		return
	end
	local count = #ins
	if Hub.MODE == "match" and state.phase == "lobby" and state.match == 0 and count > 0 and count < expected
		and now - (firstAt or now) < GROUP_WAIT then
		count = 0 -- the lobby idles (no countdown) until the group is here, or GROUP_WAIT is up
		waitingFor = expected
	elseif waitingFor then
		waitingFor = nil
		dirty = true
	end
	local what = Rules.tick(state, now, count)
	if what == "start" then
		due = Rules.pick(state, ins, Config.BOTS)
		seatBots(due)
		log(("match %d round %d: %d people, %d seats"):format(state.match, state.round, #ins, #due))
	elseif what == "abort" then
		due = nil
		if ctx then ctx.abort() end
		seatBots(nil)
		log("everybody left: back to an idle lobby")
	elseif what == "podium" then
		pay()
		log(("match %d over: winner %s"):format(state.match, tostring(state.winner)))
	elseif what == "lobby" then
		seatBots(nil)
		-- H34: a match server's one match is over: everybody back to the hub. (Should the teleport fail they are still
		-- here in a counting lobby, and simply play another match.)
		if Hub.MODE == "match" then Hub.home(Players:GetPlayers()) end
	elseif state.phase == "lobby" and (state.until_ == math.huge) ~= (not Bots.any()) and Config.BOTS then
		seatBots(nil) -- the first person in (or the last one out) of an idle lobby
	end
	if what then dirty = true end
	local d = due
	if d and #ins > 0 then -- a round is waiting to start: if none of its people is still in, seat whoever is
		local any = false
		for _, id in d do if table.find(ins, id) then any = true end end
		if not any then
			due = Rules.pick(state, ins, Config.BOTS)
			seatBots(due)
		end
	end
	if dirty or now - lastSent >= RESYNC then send(now) end
end

-- The roster of the round that may start now, or nil. Match starts it (once every client is drawing) and calls began.
function Session.due(): { number }? return due end

function Session.began(ids: { number })
	due = nil
	Rules.begin(state, ids)
	dirty = true
end

-- Every frame of a running round, and once when it ends.
function Session.note(r: Tag.Round) Rules.note(state, r.alive) end

function Session.finish(r: Tag.Round, now: number)
	Rules.note(state, r.alive)
	local placing = Rules.finish(state, r.winner, now)
	log(("round %d over: %s"):format(state.round, table.concat(placing, " > ")))
	dirty = true
end

local function onMenu(player: Player, op: any)
	local now = os.clock()
	local id = player.UserId
	if now - (lastMenu[id] or -math.huge) < MENU_GAP then return end
	lastMenu[id] = now
	local c = ctx
	if not c then return end
	if op == "play" and not playing[id] then
		playing[id] = true
		if not c.present(id) then Runners.spawn(player, c.spawn) end
		log(player.Name .. " is in")
	elseif op == "sit" and playing[id] then
		playing[id] = nil
		c.drop(id)
		Runners.despawn(player)
		log(player.Name .. " sat out")
		if Hub.MODE == "match" then Hub.home({ player }) end -- H34: out of a match server is back to the lobby
	else
		return
	end
	dirty = true
end

function Session.start(session: RemoteEvent?, menu: RemoteEvent?, context: Context)
	ctx, remote = context, session
	if session then session.OnServerEvent:Connect(function() end) end -- server -> client only (→ N3)
	if menu then menu.OnServerEvent:Connect(onMenu) end
	local function onPlayer(player: Player)
		if not table.find(order, player.UserId) then table.insert(order, player.UserId) end
		if Hub.MODE == "match" and not playing[player.UserId] then
			-- H34: a match server's players were sent here to play: in at once, no title screen to click through
			playing[player.UserId] = true
			Runners.spawn(player, context.spawn)
			expected = math.max(expected, Hub.groupOf(player))
			firstAt = firstAt or os.clock()
		end
		send(os.clock(), player)
		if studio then -- Studio only: a test session presses Play from a script (the command bar cannot fire a remote)
			player:GetAttributeChangedSignal("RotagMenu"):Connect(function()
				lastMenu[player.UserId] = nil
				onMenu(player, player:GetAttribute("RotagMenu"))
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Hub.onFailed(function(player: Player) -- its teleport did not happen: queued again, and tried again in RETRY s
		launching[player.UserId] = nil
		queueSince = os.clock() - Config.LOBBY_TIME + RETRY
		dirty = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		local id = player.UserId
		local i = table.find(order, id)
		if i then table.remove(order, i) end
		playing[id], lastMenu[id], state.waited[id], launching[id] = nil, nil, nil, nil
		dirty = true
	end)
end

return Session
