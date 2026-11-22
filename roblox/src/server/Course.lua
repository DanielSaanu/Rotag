-- The tutorial course on the server (H41, docs/systems/tutorial.md): its parts (built once at boot from
-- shared/Tutorial's data, beside the lobby and the room), who goes in and out, the pit's fall, and the target runner
-- the IT lesson is played against. Everything a player can ask arrives as a door request (server/Doors hands every
-- "tutorial" / "tut:*" op here, Remotes.Menu, no new remote) and is judged against the SERVER's own position of
-- that player (→ N4). The lessons themselves are the client's (nothing is at stake in them); the one thing that is
-- confirmed like a tag is the IT lesson's tag (rule 6: the client sees the touch, this file confirms it on its own
-- record of the target, then plays the win). Session-only memory: who finished this visit; nothing is saved.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Tut = require(Shared:WaitForChild("Tutorial"))
local Movement = require(Shared:WaitForChild("Movement"))
local BoxWorld = require(Shared:WaitForChild("BoxWorld"))
local Runners = require(script.Parent:WaitForChild("Runners"))
local Snapshots = require(script.Parent:WaitForChild("Snapshots"))
local Dummy = require(script.Parent:WaitForChild("Dummy"))
local Data = require(script.Parent:WaitForChild("Data"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local Room = require(script.Parent:WaitForChild("Room"))

local Course = {}

local NEAR = 8 -- studs of slack round the door (as server/Doors)
local FELL_GAP = 1 -- seconds between two rebuilt bodies for one fall
local HIST = 1 -- seconds of the target's positions kept for the tag check
local WINDOW = 0.5 -- ... and how far back a claim may reach (Config.TAG_REWIND_MAX's size: lagging buys no more)
local EMPTY_FOR = 5 -- seconds with nobody on the course before the target goes
local SEND_GAP = 1 / Config.SNAPSHOT_RATE
local MAX_DT = 1 / 20

local done: { [number]: boolean } = {} -- finished it this server visit (session-only: saved data is trigger 9)
local offered: { [number]: boolean } = {} -- the first-join start was used (once a visit)
local fellAt: { [number]: number } = {}
local won: { [number]: boolean } = {} -- tagged the target: on the way home
local enteredAt: { [number]: number } = {}
local ENTER_GAP = 3 -- seconds: a repeated door request is not a second fresh body (seen in Studio: two in one frame)
local world: { BoxWorld.Box } = {}
local target: any = nil
local emptySince: number? = nil
local tagName = ""
local studio = RunService:IsStudio()
local log = function(...) if studio then print("[Rotag] tutorial:", ...) end end

-- The server's newest position of a player (its snapshot, else its body), or nil.
local function where(player: Player, now: number): (number?, number?)
	local x, y = Snapshots.positionOf(player.UserId, now)
	if x and y then return x, y end
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root.Position.X, root.Position.Y end
	return nil, nil
end

-- May this server run the course for anyone? Not a match server (its players came to play), not a room's or a
-- practice server (H37): a hub or a solo server, where the lobby is.
local function open(): boolean return Hub.MODE ~= "match" and Hub.KIND == "match" end

-- A fresh body at room `i`'s start (the one placement a client-owned body cannot undo, tag.md §4).
local function put(player: Player, i: number)
	local x, y = Tut.startOf(i)
	Runners.spawn(player, Vector3.new(x, y, 0))
end

function Course.enter(player: Player)
	won[player.UserId], fellAt[player.UserId], enteredAt[player.UserId] = nil, nil, os.clock()
	put(player, 1)
	log(player.Name .. " started the tutorial")
end

-- The parts: the blocks (solid), the anchor (gold, tagged as the map's are), the take-off line, the pit's dark,
-- a backdrop. Built like server/LobbyMap's: solid parts collide and are queried, paint is neither.
local function part(parent: Instance, name: string, x0: number, y0: number, x1: number, y1: number, z: number, d: number,
	color: Color3, material: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CastShadow = true, false
	p.CanCollide, p.CanQuery, p.CanTouch = solid == true, solid == true, false
	p.Size, p.CFrame = Vector3.new(x1 - x0, y1 - y0, d), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, z)
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Course.build()
	local old = workspace:FindFirstChild("Course")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "Course"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- whole before a client's first frame, as the map is
	local X = Tut.X
	local floor, block = Color3.fromRGB(34, 39, 60), Color3.fromRGB(48, 55, 82)
	for _, b in Tut.BLOCKS do
		local p = part(m, b[1], X + b[2], b[3], X + b[4], b[5], 0, 8, if string.sub(b[1], 1, 5) == "Floor" then floor else block,
			nil, true)
		p.Name = b[1]
		part(m, b[1] .. "Edge", X + b[2], b[5] - 0.3, X + b[4], b[5], 4.06, 0.12, Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	end
	part(m, "Backdrop", X + Tut.LEFT - 40, -48, X + Tut.RIGHT + 40, 100, -4.6, 0.4, Color3.fromRGB(22, 25, 38))
	part(m, "TakeOff", X + Tut.TAKEOFF[1], -0.2, X + Tut.TAKEOFF[2], 0.05, 4.06, 0.12, Color3.fromRGB(255, 208, 84), Enum.Material.Neon)
	local k = Tut.ROOMS[5].kill :: { number }
	part(m, "PitGlow", X + k[1], -40, X + k[2], -38, 0, 6, Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
	for _, a in Tut.ANCHORS do -- as server/Arena's: a gold ball on a dark disc, never solid or queried (T11)
		local ball = part(m, "Anchor", X + a.x - 0.8, a.y - 0.8, X + a.x + 0.8, a.y + 0.8, 0, 1.6, Color3.fromRGB(255, 205, 60),
			Enum.Material.Neon)
		ball.Shape = Enum.PartType.Ball
		ball:SetAttribute("AnchorId", a.id)
		ball:SetAttribute("NoFloor", true) -- client/Grapple: the course has no floor to cap its rope by (the dip is low)
		ball:AddTag("RotagAnchor")
		local disc = part(m, "AnchorBack", X + a.x - 0.1, a.y - 1.7, X + a.x + 0.1, a.y + 1.7, -0.5, 3.4, Color3.fromRGB(35, 25, 10))
		disc.CFrame = CFrame.new(X + a.x, a.y, -0.5) * CFrame.Angles(0, math.pi / 2, 0)
	end
	m.Parent = workspace
	world = BoxWorld.fromBlocks(Tut.BLOCKS)
	for _, b in world do b[1] += X; b[3] += X end
	print(("[Rotag] tutorial: the course built at x %d (%d rooms)"):format(X, #Tut.ROOMS))
end

-- The target runner: made when somebody is on the course, gone a few seconds after the last leaves.
local function makeTarget(now: number)
	local x = Tut.X + Tut.CHASE.home
	local model, root = Dummy.new(tagName, Tut.BOT_ID, "TARGET", Vector3.new(x, Config.RUNNER_HEIGHT / 2, 0))
	model:SetAttribute("Coach", true) -- client/Arrows: no off-screen arrow to it from the lobby
	target = { model = model, root = root, s = Movement.new(x, Config.RUNNER_HEIGHT / 2), c = {}, input = { moveX = 0 },
		mem = { turn = 0 }, hist = {}, seq = 0, sendAt = 0, chaseFrom = nil, frozenUntil = 0, pending = {} }
	log("the target is up")
end

local function dropTarget()
	if not target then return end
	target.model:Destroy()
	Snapshots.forget(Tut.BOT_ID)
	target = nil
end

local function stepTarget(now: number, dt: number, chasers: { { number } })
	local t = target
	local s = t.s
	-- the nearest player in the chase room
	local cx, cy, best = nil, nil, math.huge
	for _, p in chasers do
		local d = math.abs(p[1] - s.x)
		if p[1] >= Tut.X + Tut.ROOMS[#Tut.ROOMS].x0 and d < best then cx, cy, best = p[1], p[2], d end
	end
	if cx and not t.chaseFrom then t.chaseFrom = now elseif not cx then t.chaseFrom = nil end
	Tut.flee(s, cx, cy, if t.chaseFrom then now - t.chaseFrom else 0, t.mem, dt, t.input)
	if now < t.frozenUntil then t.input.moveX, t.input.jumpPressed, t.input.jumpHeld = 0, false, false end
	BoxWorld.probe(world, s.x, s.y, t.c)
	local ev = Movement.step(s, t.input, t.c, dt)
	BoxWorld.move(world, s, dt)
	t.root.CFrame = CFrame.new(s.x, s.y, 0)
	table.insert(t.hist, { now, s.x, s.y })
	while #t.hist > 0 and t.hist[1][1] < now - HIST do table.remove(t.hist, 1) end
	local e = t.pending
	if ev.landed then e.landed = math.max(e.landed or 0, ev.landed) end
	e.jump = ev.jump or e.jump
	if now - t.sendAt >= SEND_GAP then -- drawn on every screen as a runner (Snapshots.inject, as server/Bots)
		t.sendAt, t.seq, t.pending = now, (t.seq + 1) % 65536, {}
		Snapshots.inject(Tut.BOT_ID, { seq = t.seq, x = s.x, y = s.y, vx = s.vx, vy = s.vy, sprite = Movement.spriteFor(s),
			facing = s.facing, dashing = false, jump = e.jump, dash = false, landed = e.landed, anchor = nil }, now)
	end
end

local function frame(dt: number)
	local now = os.clock()
	dt = math.min(dt, MAX_DT)
	local chasers = {}
	for _, player in Players:GetPlayers() do
		local x, y = where(player, now)
		if x and y and Tut.inCourse(x) then
			table.insert(chasers, { x, y })
			local id = player.UserId
			local i = Tut.fell(x, y) -- the dash's pit: back to the room's start, at once (the research's "instant respawn")
			if i and now - (fellAt[id] or -math.huge) >= FELL_GAP then
				fellAt[id] = now
				put(player, i)
			end
		end
	end
	if #chasers > 0 then
		emptySince = nil
		if not target then makeTarget(now) end
	elseif target then
		emptySince = emptySince or now
		if now - emptySince >= EMPTY_FOR then dropTarget() end
	end
	if target then stepTarget(now, dt, chasers) end
end

-- A door request ("tutorial", "tut:skip", "tut:tag"): Doors has already rate-gapped it and checked the sender is
-- not being taken somewhere. `api` is server/Session's (server/Doors.Api). Returns true when something changed.
function Course.ask(api: any, player: Player, op: string): boolean
	local id = player.UserId
	local now = os.clock()
	local x, y = where(player, now)
	if not (x and y) then return false end
	if op == "tutorial" then
		if not open() or Room.has(id) or Lobby.areaAt(x) ~= "lobby" or not Lobby.inDoor("lobby", "tutorial", x, y, NEAR)
			or now - (enteredAt[id] or -math.huge) < ENTER_GAP then
			return false
		end
		api.playing[id], api.practice[id] = nil, nil -- out of the queue first: one choice at a time
		Course.enter(player)
		return true
	elseif op == "tut:skip" then
		if not Tut.inCourse(x) then return false end
		log(player.Name .. " skipped the tutorial")
		api.home(player)
		return true
	elseif op == "tut:tag" then
		local t = target
		if not (t and Tut.inCourse(x) and not won[id] and now >= t.frozenUntil) then return false end
		if not Tut.caught(x, y, t.hist, now - WINDOW, Config.TAG_GRACE) then
			log(("%s's tag refused: (%.1f, %.1f), the target at (%.1f, %.1f)"):format(player.Name, x, y, t.s.x, t.s.y))
			return false
		end
		won[id], done[id] = true, true
		t.frozenUntil = now + Tut.BOT_FREEZE
		api.note(player, "tuttag") -- the client's win: "TAGGED!" and the time
		log(player.Name .. " tagged the target: tutorial done")
		task.delay(Tut.HOME_AFTER, function()
			if player.Parent == Players and won[id] then
				won[id] = nil
				local px = where(player, os.clock())
				if px and Tut.inCourse(px) then api.home(player) end
				api.changed()
			end
		end)
		return true
	end
	return false
end

-- Has this player finished the course this visit? (Nothing reads it yet: a funnel event or a saved flag would.)
function Course.done(id: number): boolean return done[id] == true end

-- Call once at boot (server/Session.start), after the lobby exists. `api`: server/Session's door api.
function Course.start(api: any, tag: string)
	tagName = tag
	Course.build()
	-- The first join (H41): a player whose SAVED profile has never finished a match starts on the course, once a
	-- visit, with SKIP on screen. A profile that did not load (Studio without API access, an outage) is not a first
	-- join: nothing is known. Studio: workspace attribute RotagTutorialFirst = true makes every join a first join.
	local function onPlayer(player: Player)
		Data.whenLoaded(player, function(p)
			local id = player.UserId
			local first = (Data.saves(player) and p.matches == 0) or (studio and workspace:GetAttribute("RotagTutorialFirst") == true)
			if not (Tut.FIRST_JOIN and first and open()) or offered[id] or api.playing[id] or Room.has(id) then return end
			offered[id] = true
			local x = where(player, os.clock())
			for _ = 1, 30 do -- the profile can land before the lobby body does (server/Session builds it on join)
				if x or player.Parent ~= Players then break end
				task.wait(0.1)
				x = where(player, os.clock())
			end
			if x and Lobby.areaAt(x) == "lobby" then Course.enter(player) end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do task.spawn(onPlayer, player) end
	Players.PlayerRemoving:Connect(function(player)
		local id = player.UserId
		done[id], offered[id], fellAt[id], won[id], enteredAt[id] = nil, nil, nil, nil, nil
	end)
	RunService.Heartbeat:Connect(frame)
end

return Course
