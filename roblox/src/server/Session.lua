-- The match on the server (H31; DESIGN §6.4, rules 31-34; docs/systems/session.md). The rules are shared/Session
-- (pure, tested): lobby -> a match's rounds with a results gap after each -> podium -> lobby. This file owns the
-- one state, who is IN (queued or seated), seats the bots, pays the match's coins and tells every client over
-- Remotes.Session. server/Match asks it when a round may start and with whom, and reports each round's eliminations
-- and end; a round itself is still Match's and shared/Tag's.
-- H37 (docs/systems/lobby.md): everybody has a body from the moment they join, in the walk-in LOBBY; being IN is
-- chosen by standing in a door. Remotes.Menu (client -> server, → N4) carries ONE string, a door's request: "play",
-- "sit", "practice", "host", "code:<4 digits>", "start", "leave", "set:<rounds|items|bots>". The sender is the
-- Player; rate-gapped; each is judged against the SERVER's own position of that player and its own room state;
-- anything else is dropped unread. A client that lies only queues, seats or moves ITSELF.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Rules = require(Shared:WaitForChild("Session"))
local Profile = require(Shared:WaitForChild("Profile"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Runners = require(script.Parent:WaitForChild("Runners"))
local Hub = require(script.Parent:WaitForChild("Hub")) -- H34: is this server a hub, a match server, or both in one
local Room = require(script.Parent:WaitForChild("Room")) -- H37: the private room
local LobbyMap = require(script.Parent:WaitForChild("LobbyMap"))
local Orbs = require(script.Parent:WaitForChild("Orbs"))
local Doors = require(script.Parent:WaitForChild("Doors")) -- H37: the door requests

local Session = {}

type Context = {
	present: (number) -> boolean, -- does runner `id` have a body
	where: (number) -> (number?, number?), -- the server's own position of runner `id` (H37: every door request)
	drop: (number) -> (),         -- runner `id` leaves the round in progress (sat out)
	abort: () -> (),              -- everybody left: end the round in progress
	spawn: Vector3,
}

local RESYNC = 1

local state = Rules.new()
local order: { number } = {} -- people in join order
local playing: { [number]: boolean } = {}
local practice: { [number]: boolean } = {} -- H37: in through the PRACTICE door (a match of only these pays nothing)
local due: { number }? = nil -- the roster of the round that may start now
local quickAt: number? = nil -- H37: PRACTICE, or a room's START: the lobby's countdown ends by then
-- ... and that match is for these players only (QA round 1: on a solo server whoever was quick-queued in the lobby
-- was swept into a stranger's practice or room match, and it paid). nil: a quick match, for everybody queued.
local only: { [number]: boolean }? = nil
local useBots, unpaid = Config.BOTS, false -- this match's (a room's BOTS block; a practice match)
-- H34, a hub only: since when somebody has been queued (the wait's clock), and who has been sent to a match server
-- and when (they are still here for a few seconds: not queued twice; LAUNCH_STALE later the teleport is taken to
-- have failed and they are queued again).
local queueSince: number? = nil
local launching: { [number]: number } = {}
local LAUNCH_STALE = 20
local RETRY = 3 -- seconds a group waits after a failed launch (QA round 3: it restarted the whole LOBBY_TIME)
-- H34, a match server only (QA round 3): how many players the hub sent here, since when the first of them arrived,
-- and how long the lobby's countdown is held for the rest.
local expected, firstAt = 1, nil :: number?
local waitingFor: number? = nil
local GROUP_WAIT = 25
local ctx: Context? = nil
local remote: RemoteEvent? = nil
local lastSent, dirty, noteSeq = -math.huge, true, 0
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
		if playing[id] and not sent and c and c.present(id) and (only == nil or only[id]) then table.insert(out, id) end
	end
	return out
end

local function view(now: number): any
	local v = Rules.view(state, now)
	local ins = {}
	for _, id in order do if playing[id] then table.insert(ins, id) end end
	v.playing = ins
	v.seed = Bots.SEED -- H32: the bots' names (shared/Session.botName) are the same on every screen
	v.mode = Hub.MODE -- H34: "hub" | "match" | "solo": what the queue means on this server
	v.room, v.unpaid = Room.view(), unpaid -- H37
	local o = only
	if o then -- the match running or about to: these players' only
		local group = {}
		for id in o do table.insert(group, id) end
		v.group = group
	end
	if waitingFor then v.waiting = { #people(), waitingFor } end -- a match server holding its lobby for its group
	local sent = {}
	for id in launching do table.insert(sent, id) end
	v.launching = sent -- being taken to another server (a match, a room, practice)
	if Hub.MODE == "hub" then -- a queue, not a countdown to a round here
		v.phase, v.queued = "lobby", #people()
		v.left = if queueSince then math.max(0, Config.LOBBY_TIME - (now - queueSince)) else -1
	elseif state.phase == "lobby" then
		v.queued = #people()
	end
	return v
end

-- To everybody, or to one player; `note` (H37): a word for that player's banner (a refusal, a result), numbered so
-- the client shows each once.
local function send(now: number, to: Player?, note: string?)
	if not remote then return end
	local v = view(now)
	if to then
		if note then
			noteSeq += 1
			v.note = { note, noteSeq }
		end
		remote:FireClient(to, v)
	else
		remote:FireAllClients(v)
		lastSent, dirty = now, false
		local n = v.queued or 0 -- the QUICK MATCH doorway shows the queue to everybody
		LobbyMap.say("quick", if n > 0 and not Room.active and quickAt == nil then ("%d / %d"):format(n, Config.PLAYERS_PER_MATCH) else "PLAY")
	end
end

-- Put `player`'s body where it waits: the room it is in, else the lobby (H37).
local function home(player: Player)
	local id = player.UserId
	local area = if Room.has(id) then "room" else "lobby"
	local slot = (if area == "room" then table.find(Room.members, id) else table.find(order, id)) or 1
	local x, y = Lobby.spawnAt(area, slot - 1)
	Runners.spawn(player, Vector3.new(x, y, 0))
end

-- The podium: everybody who played is paid (DESIGN §6.5), the winner a win. A match shorter than MATCH_ROUNDS (a
-- room's ROUNDS block) pays in proportion; a practice match pays nothing.
local function pay()
	if unpaid then return end
	local share = math.min(1, state.rounds / Config.MATCH_ROUNDS)
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		local coins = math.floor(Rules.reward(state, id) * share)
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

-- The bots that should exist now: the roster's during a match; in a lobby with people queued, none are needed until
-- the round (the warm-up is the walk-in lobby now), but a match server's arena lobby still gets company.
local function seatBots(roster: { number }?)
	if roster then
		Bots.ensure(roster)
	elseif Config.BOTS and Hub.MODE == "match" and #people() > 0 then
		local ids = {}
		for k = 1, math.max(0, Config.PLAYERS_PER_MATCH - #people()) do table.insert(ids, Rules.botId(k)) end
		Bots.ensure(ids)
	else
		Bots.ensure({})
	end
end

-- H34, a hub: no round ever runs here. Whoever stood in QUICK MATCH is queued; the moment the seats are full, or
-- LOBBY_TIME after the first of them queued, the longest-waiting group is sent to a match server of its own.
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

-- The match is over and its podium done: nobody is IN any more. Everybody who played goes back to where they wait
-- (the lobby, or their room) and chooses again: nothing starts by itself (H37: never rushed into a next match).
local function release()
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		if playing[id] and (only == nil or only[id]) then -- (whoever is quick-queued behind a private match stays queued)
			playing[id], practice[id] = nil, nil
			home(player)
		end
	end
	quickAt, only, unpaid, useBots = nil, nil, false, Config.BOTS
	Orbs.ITEMS = true
end

-- Every server frame, before Match decides whether to start a round.
function Session.step(now: number)
	local ins = people()
	local c = ctx
	if c then Room.step(now, c.where, state.phase == "lobby" and quickAt == nil) end
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
	if state.phase == "lobby" then
		if count == 0 then
			quickAt, only = nil, nil
		elseif quickAt and state.until_ > quickAt then
			state.until_, dirty = quickAt, true -- PRACTICE, or a host's START: a short 3-2-1, not the queue's wait
		end
	end
	if what == "start" then
		if state.round == 1 then -- a new match: its settings (a room's blocks), and whether it pays
			local rs = if Room.active then Room.settings else nil
			state.rounds = if rs then rs.rounds else Config.MATCH_ROUNDS
			useBots = if rs then rs.bots else Config.BOTS
			Orbs.ITEMS = if rs then rs.items else true
			unpaid = Hub.KIND == "practice"
			if not unpaid and #ins > 0 then
				unpaid = true
				for _, id in ins do if not practice[id] then unpaid = false end end
			end
			quickAt = nil
		end
		due = Rules.pick(state, ins, useBots)
		seatBots(due)
		log(("match %d round %d of %d: %d people, %d seats%s"):format(state.match, state.round, state.rounds, #ins, #due,
			if unpaid then " (practice: unpaid)" else ""))
	elseif what == "abort" then
		due = nil
		if c then c.abort() end
		seatBots(nil)
		release()
		log("everybody left: back to an idle lobby")
	elseif what == "podium" then
		pay()
		log(("match %d over: winner %s"):format(state.match, tostring(state.winner)))
	elseif what == "lobby" then
		seatBots(nil)
		-- H34: a match server's one match is over: everybody back to the hub. (Should the teleport fail they are still
		-- here in a counting lobby, and simply play another match.) Anywhere else: back to the lobby or the room.
		if Hub.MODE == "match" then Hub.home(Players:GetPlayers()) else release() end
	end
	if what then dirty = true end
	local d = due
	if d and #ins > 0 then -- a round is waiting to start: if none of its people is still in, seat whoever is
		local any = false
		for _, id in d do if table.find(ins, id) then any = true end end
		if not any then
			due = Rules.pick(state, ins, useBots)
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

-- Out: of the queue (the body stays where it is), or of a match in progress (back to the lobby / the room / the hub).
local function sit(player: Player)
	local id = player.UserId
	local c = ctx
	if not (playing[id] and c) then return end
	playing[id], practice[id] = nil, nil
	if state.phase == "lobby" and not due and Hub.MODE ~= "match" then
		log(player.Name .. " left the queue")
		return
	end
	c.drop(id)
	log(player.Name .. " sat out")
	if Hub.MODE == "match" then Hub.home({ player }) else home(player) end
end

-- A door's request (Remotes.Menu): judged in server/Doors against this file's state, handed over as `api`.
local api: Doors.Api = {
	playing = playing, practice = practice, launching = launching,
	idle = function() return state.phase == "lobby" and not due end,
	quick = function() return quickAt end,
	setQuick = function(t: number, ids: { number })
		quickAt, only = t, {}
		for _, id in ids do (only :: any)[id] = true end
	end,
	where = function(id: number) local c = ctx if c then return c.where(id) end return nil, nil end,
	sit = sit, home = home,
	note = function(player: Player, why: string) send(os.clock(), player, why) end,
	changed = function() dirty = true end,
	log = function(text: string) log(text) end,
}

function Session.start(session: RemoteEvent?, menu: RemoteEvent?, context: Context)
	ctx, remote = context, session
	Room.changed = function() dirty = true end
	Room.start()
	if session then session.OnServerEvent:Connect(function() end) end -- server -> client only (→ N3)
	if menu then menu.OnServerEvent:Connect(function(player, op) Doors.ask(api, player, op) end) end
	local function onPlayer(player: Player)
		local id = player.UserId
		if not table.find(order, id) then table.insert(order, id) end
		if Hub.MODE == "match" and not playing[id] then
			-- H34: a match server's players were sent here to play: in at once, in the arena
			playing[id] = true
			-- a practice server: a short count from the arrival, not the arena lobby's LOBBY_TIME (QA round 1)
			if Hub.KIND == "practice" and quickAt == nil then quickAt = os.clock() + Config.QUICK_START + 4 end
			Runners.spawn(player, context.spawn)
			expected = math.max(expected, Hub.groupOf(player))
			firstAt = firstAt or os.clock()
		elseif Hub.MODE ~= "match" then
			-- H37: a body at once, in the lobby (a room server: in the room; a fifth arrival goes back to the hub)
			if Hub.KIND == "room" and not Room.add(player) then
				Hub.home({ player })
				return
			end
			home(player)
		end
		send(os.clock(), player)
		if studio then -- Studio only: a test session asks from a script (the command bar cannot fire a remote)
			player:GetAttributeChangedSignal("RotagMenu"):Connect(function()
				Doors.forget(id)
				Doors.ask(api, player, player:GetAttribute("RotagMenu"))
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Hub.onFailed(function(player: Player) -- its teleport did not happen: still here, and tried again in RETRY s
		local id = player.UserId
		launching[id] = nil
		if playing[id] then queueSince = os.clock() - Config.LOBBY_TIME + RETRY end
		send(os.clock(), player, "failed")
		dirty = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		local id = player.UserId
		local i = table.find(order, id)
		if i then table.remove(order, i) end
		playing[id], practice[id], state.waited[id], launching[id] = nil, nil, nil, nil
		Doors.forget(id)
		Room.remove(id)
		dirty = true
	end)
end

return Session
