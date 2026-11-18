-- The bots (H31; DESIGN §3 rules 31-32, §6.7; docs/systems/bots.md). A bot is a runner the SERVER simulates with the
-- very rules a player has: shared/Movement stepped every server frame in shared/BoxWorld (the map's blocks plus the
-- ghosts' fixtures), its buttons picked by shared/BotBrain. It fills an empty seat in a round (server/Session picks
-- the roster) and plays every role: runs, chases as "it", takes orbs, uses items, haunts as a ghost. Its position is
-- the server's own truth: its tags get no lag allowance and are judged where a PERSON sees it (BOT_SEEN behind), its
-- state rides the snapshot relay (Snapshots.inject) so every screen draws it like a person. server/BotMind picks the
-- goal; this file owns the bodies and the frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local OrbRules = require(Shared:WaitForChild("Orbs"))
local ItemRules = require(Shared:WaitForChild("Items"))
local PlaceRules = require(Shared:WaitForChild("Placement"))
local Movement = require(Shared:WaitForChild("Movement"))
local BoxWorld = require(Shared:WaitForChild("BoxWorld"))
local BotBrain = require(Shared:WaitForChild("BotBrain"))
local SessionRules = require(Shared:WaitForChild("Session"))
local Dummy = require(script.Parent:WaitForChild("Dummy"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Items = require(script.Parent:WaitForChild("Items"))
local Placement = require(script.Parent:WaitForChild("Placement"))
local Snapshots = require(script.Parent:WaitForChild("Snapshots"))
local Walls = require(script.Parent:WaitForChild("Walls"))
local BotMind = require(script.Parent:WaitForChild("BotMind"))

local Bots = {}
Bots.ids = {} :: { [number]: boolean } -- for Tag.readyToStart: never waited for

local MAX_DT = 1 / 20 -- a server hitch must not become one giant step through a deck
local AIR_COMMIT = 0.7 -- seconds an airborne bot keeps its plan before it may think again (a jump is a commitment)
local WORLD_EVERY = 0.5 -- seconds between rebuilds of the box world (the ghosts' fixtures come and go)
local SEND_GAP = 1 / Config.SNAPSHOT_RATE
local BOT_SEEN = 0.04 -- seconds on top of SNAPSHOT_DELAY and the target's own ping: how far behind the server a
-- person sees a bot (half the round trip GetNetworkPing reports). A bot's tag is judged on where the bot WAS then, so it lands when it looks like
-- a touch on THEIR screen (QA round 1: a fixed 0.12 s was 4 studs short for a 200 ms phone). At most BOT_SEEN_MAX.
local BOT_SEEN_MAX = 0.4
local FELL_OUT = -60
local DID_EVERY = 20 -- Studio only: seconds between one line per bot about what it did
local studio = game:GetService("RunService"):IsStudio()

local list: { [number]: any } = {}
local count = 0
local tagName = ""
local mapBoxes: { BoxWorld.Box } = {}
local world: { BoxWorld.Box } = {}
local grid: BoxWorld.Grid = nil :: any
local worldAt = -math.huge
local thoughtAt = -math.huge -- at most one bot plans per frame (a plan is ~33 rollouts)
-- H32: what a bot needs to grapple as a player does (the anchors, the boxes a rope cannot pass), and the crates and
-- traps lying in the world (a plan that runs into one is rated down: BotBrain's hazards).
local hooks: BotBrain.Hooks = { anchors = {}, world = {} }
local hazards: { BoxWorld.Box } = {}
-- The seed of this server's bot names (shared/Session.botName): every client gets it in Remotes.Session.
Bots.SEED = math.random(1, 1000000)

function Bots.any(): boolean return count > 0 end
function Bots.isBot(id: number): boolean return list[id] ~= nil end

local function rebuildWorld(now: number)
	worldAt = now
	world = table.clone(mapBoxes)
	for _, p in Placement.placed() do
		if p.item == "fixture" then
			local b = p.boxes
			for i = 0, p.count - 1 do table.insert(world, { b[i * 4 + 1], b[i * 4 + 2], b[i * 4 + 3], b[i * 4 + 4] }) end
		end
	end
	hooks.world = world
	hazards = {}
	for _, t in Items.things() do
		if t.item ~= "ice" then table.insert(hazards, { t.x - t.hw, t.y - t.hh, t.x + t.hw, t.y + t.hh }) end
	end
end

local function reset(b: any, x: number, y: number)
	b.s = Movement.new(x, y)
	b.plan, b.mem, b.planT, b.nextThink = BotBrain.IDLE, BotBrain.memory(), 0, 0
	b.pending = {}
	table.clear(b.pads)
	b.root.CFrame = CFrame.new(x, y, 0)
end

-- Call once at boot, after the map exists.
function Bots.start(tag: string)
	tagName = tag
	mapBoxes = BoxWorld.fromBlocks(Arena.MAP.blocks)
	grid = BoxWorld.grid(Arena.MAP.blocks, Arena.MAP.top)
	BotMind.start(Arena.MAP)
	hooks.anchors = {}
	for i, a in Arena.ANCHORS do -- numbered as the clients number them (the snapshot's anchor byte)
		table.insert(hooks.anchors, { x = a.x, y = a.y, id = i, floor = BoxWorld.floorUnder(mapBoxes, a.x, a.y) })
	end
	rebuildWorld(os.clock())
end

-- Make the bots in `ids` exist and every other bot go (server/Session: the roster's bots, or none in an empty server).
function Bots.ensure(ids: { number })
	local want: { [number]: boolean } = {}
	for _, id in ids do
		if SessionRules.isBot(id) then want[id] = true end
	end
	for id, b in list do
		if not want[id] then
			b.model:Destroy()
			list[id], Bots.ids[id] = nil, nil
			Snapshots.forget(id)
			count -= 1
		end
	end
	for id in want do
		if not list[id] then
			local at = Vector3.new(Arena.SPAWN.X + (SessionRules.BOT_ID - id + 1) * 8, Arena.SPAWN.Y, 0)
			local model, root = Dummy.new(tagName, id, SessionRules.botName(id, Bots.SEED), at)
			local b = { id = id, model = model, root = root, input = { moveX = 0, jumpPressed = false, jumpHeld = false,
				dashPressed = false }, c = {}, field = {}, queue = {}, pads = {}, seq = 0, sendAt = 0, mind = BotMind.new(),
				did = { jumps = 0, air = 0, dashes = 0, swings = 0, since = os.clock() } }
			reset(b, at.X, at.Y)
			list[id], Bots.ids[id] = b, true
			count += 1
		end
	end
end

-- Round start: stand at `x` on the start line, a fresh Movement state.
function Bots.place(id: number, x: number)
	local b = list[id]
	if b then reset(b, x, Arena.SPAWN.Y) end
end

-- Where a bot's crate or beam goes (server/Items): the way BotMind aimed it this frame, else the way it faces.
function Bots.facing(id: number): number?
	local b = list[id]
	return b and (b.aim or b.s.facing)
end

local goal: BotBrain.Goal = { mode = "seek", field = {}, x = 0, y = 0 }

local function think(b: any, r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } }, o: OrbRules.State?)
	local mode, gx, gy, safe = BotMind.goal(b.mind, b.id, b.s, r, now, history, o)
	if mode and gx and gy then
		goal.mode, goal.x, goal.y, goal.safe = mode, gx, gy, safe
		goal.field = BoxWorld.field(grid, gx, gy, b.field, b.queue)
		goal.speedMult = b.input.speedMult
		-- H32: each bot is its own player (BotMind.new): how often it dashes and swings, how sloppy its picks are.
		local mind = b.mind
		goal.noDash = math.random() > mind.dash
		local ghost = r ~= nil and not r.over and r.alive[b.id] == false
		goal.hooks = if not ghost and math.random() < mind.hook then hooks else nil -- a ghost never grapples (rule 37)
		goal.hazards = if #hazards > 0 then hazards else nil
		goal.noise = mind.noise
		goal.lo, goal.hi = nil, nil
		if r and r.alive[b.id] then goal.lo, goal.hi = Walls.room(now) end
		if Walls.backIn(b.id) then goal.lo, goal.hi = nil, nil end -- outside already: any way back in is a good plan
		b.plan = BotBrain.choose(world, grid, b.s, goal, math.random, b.plan)
	else
		b.plan = BotBrain.IDLE
	end
	b.mem, b.planT = BotBrain.memory(), 0
	b.mem.hooked = b.s.rope ~= nil -- on a rope already: a hook plan keeps holding, any other lets go
	b.nextThink = now + b.mind.think * (0.8 + 0.4 * math.random())
end

local function stepBot(b: any, r: Tag.Round?, dt: number, now: number, history: { [number]: { Tag.Sample } },
	o: OrbRules.State?)
	local s, id, input = b.s, b.id, b.input
	local inRound = r ~= nil and not r.over and r.alive[id] ~= nil
	local isIt = inRound and (r :: Tag.Round).it == id
	local frozen = isIt and Tag.frozen(r :: Tag.Round, now)
	input.speedMult = b.mind.speed * (if inRound and r then Tag.speedMult(isIt, now - r.chaseFrom, false,
		r.alive[id] == true and Tag.endPhase(r, now)) else 1)
	if now >= b.nextThink and (s.grounded or b.planT >= AIR_COMMIT) and thoughtAt ~= now then
		thoughtAt = now
		think(b, r, now, history, o)
	end
	BoxWorld.probe(world, s.x, s.y, b.c)
	BotBrain.input(b.plan, b.mem, s, b.c, b.planT, input, hooks)
	-- A hold (rule 44), exactly as a player's client applies it (client/Use): the stumble carries on the way it went.
	local h = Items.holdOf(id, now)
	if h then
		if h ~= b.hold then b.hold, b.holdDir = h, if s.vx > 0.5 then 1 elseif s.vx < -0.5 then -1 else s.facing end
		input.hold, input.holdDir, input.holdLeft = h.kind, b.holdDir, h.untilT - now
	else
		b.hold, input.hold, input.holdDir, input.holdLeft = nil, nil, nil, nil
	end
	if frozen then -- the tag freeze (rule 1): no input, no run speed, still falls (as client/Client does)
		input.moveX, input.jumpPressed, input.jumpHeld, input.dashPressed = 0, false, false, false
		s.vx, s.dashTime = 0, 0
	end
	-- QA round 2: a bot tagged or burnt out mid-swing kept its rope until its plan ran out. A frozen holder has no
	-- input and a ghost never grapples (rule 37), exactly as client/Grapple.frame drops a player's.
	if frozen or (r ~= nil and not r.over and r.alive[id] == false) then
		input.grappleHeld, input.grapplePressed, input.anchor = false, false, nil
	end
	-- A pad launches a bot on ENTERING it, as a player's client launches itself (client/Place.frame).
	input.launchX, input.launchY = nil, nil
	for _, p in Placement.placed() do
		if p.item == "pad" then
			local touching = PlaceRules.onPad(p, s.x, s.y)
			local was = b.pads[p.n]
			b.pads[p.n] = touching
			if touching and (was == false or (was == nil and p.owner ~= id)) and not h then
				input.launchX, input.launchY = PlaceRules.launch(if s.vx > 0.5 then 1 elseif s.vx < -0.5 then -1 else s.facing)
			end
		end
	end
	local ev = Movement.step(s, input, b.c, dt)
	BoxWorld.move(world, s, dt)
	if s.y < FELL_OUT then reset(b, Arena.SPAWN.X, Arena.SPAWN.Y) end
	b.planT += dt
	local e = b.pending
	if studio then -- Studio only: what each bot did, so a tester can see it plays like a person (bots.md §7)
		local n = b.did
		if ev.jump == "ground" then n.jumps += 1 elseif ev.jump then n.air += 1 end
		if ev.dash then n.dashes += 1 end
		if ev.grapple == "attach" then n.swings += 1 end
		if now - n.since >= DID_EVERY then
			print(("[Rotag] bots: %s (%d, skill %.2f) in %ds: %d ground jumps, %d double or wall jumps, %d dashes, %d swings"):format(
				b.model.Name, id, b.mind.skill, DID_EVERY, n.jumps, n.air, n.dashes, n.swings))
			n.jumps, n.air, n.dashes, n.swings, n.since = 0, 0, 0, 0, now
		end
	end
	if ev.landed then e.landed = math.max(e.landed or 0, ev.landed) end
	e.jump = ev.jump or e.jump
	e.dash = ev.dash or e.dash
	b.root.CFrame = CFrame.new(s.x, s.y, 0)
	if now - b.sendAt >= SEND_GAP then
		b.sendAt = now
		b.seq = (b.seq + 1) % 65536
		b.pending = {}
		Snapshots.inject(id, { seq = b.seq, x = s.x, y = s.y, vx = s.vx, vy = s.vy, sprite = Movement.spriteFor(s),
			facing = s.facing, dashing = s.dashTime > 0, jump = e.jump, dash = e.dash == true, landed = e.landed,
			anchor = if s.rope then s.rope.id else nil }, now) -- the rope every screen draws (H25's anchor byte)
	end
end

-- Before the server samples positions: every bot thinks (one a frame) and moves one frame.
function Bots.move(r: Tag.Round?, dt: number, now: number, history: { [number]: { Tag.Sample } }, o: OrbRules.State?)
	if count == 0 then return end
	if now - worldAt >= WORLD_EVERY then rebuildWorld(now) end
	dt = math.min(dt, MAX_DT)
	for _, b in list do
		b.aim = nil
		if dt > 1 / 45 then -- a slow frame: two half steps, so a fall never skips a deck
			stepBot(b, r, dt / 2, now - dt / 2, history, o)
			stepBot(b, r, dt / 2, now, history, o)
		else
			stepBot(b, r, dt, now, history, o)
		end
	end
end

-- After the orbs: a bot uses what it holds when BotMind says the moment is right, through server/Items.press: the
-- same rules as a player's Use.
function Bots.uses(r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } }, o: OrbRules.State?)
	if not (r and o) or r.over then return end
	for id, b in list do
		local item = o.held[id]
		if item and not (r.it == id and Tag.frozen(r, now)) and not Items.holdOf(id, now) then
			local use, aim, rot = BotMind.use(b.mind, id, b.s, item, r, now, history)
			if use then
				b.aim = aim
				Items.press(id, now, rot, true)
			end
		end
	end
end

local function sampleAt(h: { Tag.Sample }, t: number): Tag.Sample?
	for i = #h, 1, -1 do
		if h[i].t <= t then return h[i] end
	end
	return h[1]
end

-- After the server judged the players' tags: a bot holder tags the first living runner it touches, where a person
-- SEES the bot (BOT_SEEN ago) against where that runner is now, with no grace: a bot never tags from out of reach.
function Bots.tags(r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } },
	pass: (Tag.Round, number, number, number) -> ())
	local it = r and not r.over and r.it
	if not (r and it and list[it]) or not Config.BOT_TAGS then return end -- off: solo item testing (H19)
	local ha = history[it]
	local here = ha and ha[#ha]
	if not (ha and here) then return end
	for _, id in r.order do
		if id ~= it and r.alive[id] and Tag.canClaim(r, it, id, now) and Items.canTag(it, now) then
			local hb = history[id]
			local sb = hb and hb[#hb]
			local behind = 0 -- another bot is the server's own too: judged on this frame
			local player = Players:GetPlayerByUserId(id)
			if player then
				local ok, ping = pcall(function() return player:GetNetworkPing() end)
				-- GetNetworkPing is the round trip; what the target SEES is one way behind (plus the draw delay)
				behind = math.min(BOT_SEEN_MAX, Config.SNAPSHOT_DELAY + BOT_SEEN + (if ok and type(ping) == "number" then ping / 2 else 0))
			end
			local seen = sampleAt(ha, now - behind)
			if sb and seen and not sb.iframe -- H38: a dash dodges a bot's tag as it does a person's
				and Tag.overlaps(seen.x, seen.y, sb.x, sb.y, 0)
				and Tag.overlaps(here.x, here.y, sb.x, sb.y, Config.TAG_GRACE) then
				pass(r, it, id, now)
				return
			end
		end
	end
end

-- After the players' hexes: a bot ghost holding a hex hexes the holder it touches.
function Bots.hexes(r: Tag.Round?, g: Ghost.Ghosts?, o: OrbRules.State?, now: number,
	history: { [number]: { Tag.Sample } }, land: (Tag.Round, Ghost.Ghosts, OrbRules.State, number, number) -> ())
	local it = r and not r.over and r.it
	if not (r and g and o and it) then return end
	for id in list do
		if Ghost.canHex(r, g, o, id, it, now) then
			local ha, hb = history[id], history[it]
			if ha and hb and Tag.confirm(ha, ItemRules.undodged(hb), now, 0) then land(r, g, o, id, now) return end
		end
	end
end

return Bots
