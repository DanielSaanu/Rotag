-- The client entry point: the first playable's frame loop (docs/systems/movement.md).
-- Before physics, every frame: read input and the runner's surroundings, step shared/Movement, hand the velocity
-- to the part. Before drawing, every frame: the side-on camera, then the sprite (frame, facing, juice).
-- Nothing here decides anything; the rules are in shared/, the body in Body.lua, the look in Look.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = require(Shared:WaitForChild("Movement"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Body = require(script.Parent:WaitForChild("Body"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Look = require(script.Parent:WaitForChild("Look"))
local SideCamera = require(script.Parent:WaitForChild("SideCamera"))

local player = Players.LocalPlayer
local MAX_DT = 1 / 20 -- a hitch must not turn into one giant step through a wall
local FELL_OUT = -60 -- below the floor by this much: back to where this body spawned

local current = nil -- { character, humanoid, root, body, look, state, spawnX, spawnY, pending }

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
	}
	Controls.read(humanoid) -- drop any press made before the body existed
	SideCamera.reset(p.X, p.Y)
	print(("[Rotag] client: runner ready at (%.1f, %.1f)"):format(p.X, p.Y))
end

-- Before physics: the move rules.
RunService.PreSimulation:Connect(function(dt: number)
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
	local ev = Movement.step(s, Controls.read(c.humanoid), contacts, dt)
	-- Physics can run more than once between two draws: keep every event until the sprite has reacted to it.
	local p = c.pending
	if ev.landed then p.landed = math.max(p.landed or 0, ev.landed) end
	p.jump = ev.jump or p.jump
	p.dash = ev.dash or p.dash
	c.body:apply(s.x, s.y, s.vx, s.vy)
end)

-- Before drawing: camera, then the sprite.
RunService:BindToRenderStep("RotagView", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local c = current
	if not c or not c.root.Parent then return end
	local pos = c.root.Position
	SideCamera.update(pos.X, pos.Y, c.state.vx, dt)
	c.look:react(c.pending)
	c.pending = {}
	c.look:draw(Movement.spriteFor(c.state), c.state.facing, c.state.dashTime > 0, c.state.vx, dt)
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
player.CharacterAdded:Connect(setup)
player.CharacterRemoving:Connect(function(character)
	if current and current.character == character then teardown() end
end)
if player.Character then task.spawn(setup, player.Character) end
print("[Rotag] client up")
