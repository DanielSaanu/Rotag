-- The client entry point: the first playable's frame loop (docs/systems/movement.md).
-- Before physics, every frame: read input and the runner's surroundings, step shared/Movement, hand the velocity
-- to the part. Before drawing, every frame: the side-on camera, then the sprite (frame, facing, juice).
-- Nothing here decides anything; the rules are in shared/, the body in Body.lua, the look in Look.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Movement = require(Shared:WaitForChild("Movement"))
local Snapshot = require(Shared:WaitForChild("Snapshot"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Body = require(script.Parent:WaitForChild("Body"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Look = require(script.Parent:WaitForChild("Look"))
local SideCamera = require(script.Parent:WaitForChild("SideCamera"))
local Tagging = require(script.Parent:WaitForChild("Tagging"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Others = require(script.Parent:WaitForChild("Others"))
local Arrows = require(script.Parent:WaitForChild("Arrows"))
local Items = require(script.Parent:WaitForChild("Items"))
local Use = require(script.Parent:WaitForChild("Use")) -- H19: Use, prying, the local hold (docs/systems/items.md)

local player = Players.LocalPlayer
local MAX_DT = 1 / 20 -- a hitch must not turn into one giant step through a wall
local FELL_OUT = -60 -- below the floor by this much: back to where this body spawned
local REMOTES_WAIT = 10 -- seconds to wait for the Remotes folder and Remotes.Ready

local current = nil -- { character, humanoid, root, body, look, state, spawnX, spawnY, pending }

-- H13 run 4, Studio only: this client's own loop rate, the rate its body reaches everyone else. One Studio PC runs
-- every test client as a window, and only one has focus: if an unfocused window's line shows far fewer steps a second
-- than the focused one, its runner steps on every other screen because of the test rig, not the game.
local LOOP_LOG = 5
local loop = { steps = 0, frames = 0, worst = 0, since = os.clock() }
local studio = RunService:IsStudio()

local function teardown()
	if not current then return end
	current.look:destroy()
	current.body:destroy()
	current = nil
end

local function setup(character: Model)
	teardown()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	-- WaitForChild yields: a newer character may have arrived meanwhile. Only the current one gets set up.
	if player.Character ~= character then return end
	if not (root and root:IsA("BasePart") and humanoid and humanoid:IsA("Humanoid")) then
		warn("[Rotag] the runner has no HumanoidRootPart or Humanoid; is server/Runners.lua building it?")
		return
	end
	humanoid.PlatformStand = true
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
	local p = root.Position
	current = {
		character = character,
		humanoid = humanoid,
		root = root,
		body = Body.new(character, root),
		look = Look.new(character, root),
		state = Movement.new(p.X, p.Y),
		spawnX = p.X,
		spawnY = p.Y,
		pending = {},
		toSend = {}, -- juice events since the last snapshot went out (H14)
	}
	Controls.read(humanoid) -- drop any press made before the body existed
	SideCamera.reset(p.X, p.Y)
	print(("[Rotag] client: runner ready at (%.1f, %.1f)"):format(p.X, p.Y))
end

-- Before physics: the move rules.
RunService.PreSimulation:Connect(function(dt: number)
	if studio then loop.steps += 1 end
	local c = current
	if not c or not c.root.Parent then return end
	dt = math.min(dt, MAX_DT)
	local s = c.state
	local x, y, contacts = c.body:read()
	s.x, s.y = x, y
	if y < FELL_OUT then
		s.x, s.y, s.vx, s.vy = c.spawnX, c.spawnY, 0, 0
		contacts = {}
	end
	-- The tag (docs/systems/tag.md): a tag's hit-stop holds everything still and resumes with the same speed (rule
	-- 21); the frozen new holder gets no input and no run speed, but still falls (rule 1); "it" runs faster (rule 4).
	if Tagging.hitStopped() then
		c.body:apply(s.x, s.y, 0, 0)
		return
	end
	local input = Controls.read(c.humanoid)
	Use.frame(input, s, Tagging.frozen()) -- a hold rides on input.hold; a hold never stops the tag claim below
	if Tagging.frozen() then
		input = { moveX = 0, jumpPressed = false, jumpHeld = false, dashPressed = false, touch = input.touch }
		s.vx, s.dashTime = 0, 0 -- a dash in progress ends too
	end
	input.speedMult = Tagging.speedMult()
	local ev = Movement.step(s, input, contacts, dt)
	-- Physics can run more than once between two draws: keep every event until the sprite has reacted to it.
	for _, p in { c.pending, c.toSend } do
		if ev.landed then p.landed = math.max(p.landed or 0, ev.landed) end
		p.jump = ev.jump or p.jump
		p.dash = ev.dash or p.dash
	end
	c.body:apply(s.x, s.y, s.vx, s.vy)
	Tagging.claim(s.x, s.y)
	if Items.held(player.UserId) == "hex" then Tagging.hex(s.x, s.y) end -- H18: a ghost's hex (docs/systems/ghosts.md)
end)

-- The snapshot stream (H14, docs/systems/netcode.md §8): after physics, Config.SNAPSHOT_RATE times a second, our
-- runner's state goes to the server over Remotes.Snapshot (unreliable: a lost one is simply skipped), with the juice
-- events since the last one. The server stamps, bounds and relays it; every other screen draws us from it.
local snapRemote: UnreliableRemoteEvent? = nil
local SEND_GAP = 1 / Config.SNAPSHOT_RATE
local lastSend, seq = -math.huge, 0
RunService.Heartbeat:Connect(function()
	local c = current
	if not (c and c.root.Parent and snapRemote) then return end
	local now = os.clock()
	if now - lastSend < SEND_GAP then return end
	lastSend = now
	seq = (seq + 1) % 65536
	local s, e = c.state, c.toSend
	c.toSend = {}
	snapRemote:FireServer(Snapshot.pack({ seq = seq, x = s.x, y = s.y, vx = s.vx, vy = s.vy,
		sprite = Movement.spriteFor(s), facing = s.facing, dashing = s.dashTime > 0,
		jump = e.jump, dash = e.dash == true, landed = e.landed }))
end)
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", REMOTES_WAIT)
	local r = remotes and remotes:WaitForChild("Snapshot", REMOTES_WAIT)
	if r and r:IsA("UnreliableRemoteEvent") then
		snapRemote = r
		Others.listen(r)
	else
		warn("[Rotag] no Remotes.Snapshot (restart rojo serve); other screens draw this runner from its body")
	end
end)

-- Round-ready (H11, docs/systems/players.md §5): tell the server once, after our runner's first draw, that this
-- client is up and drawing, so round 1 does not start (and count down) before it is seen. No payload.
local readySent = false
local function sendReady()
	readySent = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", REMOTES_WAIT)
		local remote = remotes and remotes:WaitForChild("Ready", REMOTES_WAIT)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer()
			print("[Rotag] client: ready sent")
		else
			warn("[Rotag] no Remotes.Ready (restart rojo serve); the server starts the round after its timeout")
		end
	end)
end

-- How a runner is drawn: nil alive, or a ghost "ready" (holding a hex, H18) / "cooling" (empty-handed) (rules 37, 41).
local function ghostMode(id: number): string?
	if not Tagging.ghost(id) then return nil end
	return if Items.held(id) == "hex" then "ready" else "cooling"
end

-- Before drawing: camera, then our sprite, then everyone else's sprite and the off-screen arrows (H11).
RunService:BindToRenderStep("RotagView", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if studio then
		loop.frames += 1
		loop.worst = math.max(loop.worst, dt)
		local span = os.clock() - loop.since
		if span >= LOOP_LOG then
			print(("[Rotag] client: own loop %.0f physics steps/s, %.0f frames/s, longest frame %.0f ms"):format(
				loop.steps / span, loop.frames / span, loop.worst * 1000))
			loop.steps, loop.frames, loop.worst, loop.since = 0, 0, 0, os.clock()
		end
	end
	local c = current
	if c and c.root.Parent then
		local pos = c.root.Position
		SideCamera.update(pos.X, pos.Y, c.state.vx, dt)
		c.look:react(c.pending)
		c.pending = {}
		c.look:ghost(ghostMode(player.UserId))
		c.look:draw(Movement.spriteFor(c.state), c.state.facing, c.state.dashTime > 0, c.state.vx, dt)
		if not readySent then sendReady() end
	end
	Others.draw(dt, ghostMode)
	local st = Tagging.state()
	Items.draw(player.UserId, Tagging.ghost(player.UserId) ~= nil, st ~= nil and st.over == true, -- held items, slot
		Tagging.isAlive(player.UserId))
	-- After Others.draw: the IT marker sits where this frame drew the holder (H13).
	Hud.update(Tagging.state(), Tagging.me(), Tagging.fuseLeft(), Tagging.frozenLeft())
	Arrows.update(Tagging.me(), Tagging.state())
end)

-- The sheet ids the server resolved (Remotes.SheetIds, docs/systems/README.md). Nothing waits for them: the runner
-- draws with the ids built into Sprites.lua and re-applies when these land. Only the server can fire this event to
-- us, but trust nothing beyond the shape: each key a sheet we have, each value an "rbxassetid://<digits>" string.
local SHEET_IDS_WAIT = 10 -- seconds: the server's decal lookup at boot can take a few in Studio
local function sheetIdCount(ids: any): number
	if type(ids) ~= "table" then return 0 end
	local n = 0
	for i, id in pairs(ids) do
		if type(i) ~= "number" or not Sprites.Sheets[i] then return 0 end
		if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then return 0 end
		n += 1
	end
	return n
end
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", SHEET_IDS_WAIT)
	local remote = remotes and remotes:WaitForChild("SheetIds", SHEET_IDS_WAIT)
	if not (remote and remote:IsA("RemoteEvent")) then
		warn("[Rotag] no Remotes.SheetIds; drawing with the sheet ids built into Sprites.lua")
		return
	end
	local arrived = false
	remote.OnClientEvent:Connect(function(ids: any)
		local n = sheetIdCount(ids)
		if n == 0 then
			warn("[Rotag] ignored a SheetIds payload of the wrong shape")
			return
		end
		Sprites.ApplySheetIds(ids)
		arrived = true
		if current then current.look:refresh() end
		Others.refresh()
		print(("[Rotag] client: %d sheet id(s) from the server, sheet 1 = %s"):format(n, tostring(ids[1])))
	end)
	task.delay(SHEET_IDS_WAIT, function()
		if not arrived then
			warn(("[Rotag] no sheet ids from the server after %ds; drawing with the ids built into Sprites.lua"):format(
				SHEET_IDS_WAIT))
		end
	end)
end)

Controls.start(player)
Hud.start(player)
Arrows.start(player, Hud.nameOf)
Others.start(player)
Items.start(player)
Use.start(player)
-- A verdict: the "+N" pop, and the tagger's drawn sprite catches up to the victim (rule 6, H14). The claim tests
-- where Others draws each runner (the snapshot stream), as the server judges it.
Tagging.start(player, function() end, function(v)
	Hud.pass(v, player.UserId)
	Others.lunge(v.from, v.to)
end, Others.positionOf, function(v)
	Hud.spook(v, player.UserId) -- H18: "-3s HEX  <ghost>" where the "+2s" pops
end)
player.CharacterAdded:Connect(setup)
player.CharacterRemoving:Connect(function(character)
	if current and current.character == character then teardown() end
end)
if player.Character then task.spawn(setup, player.Character) end
print("[Rotag] client up")
