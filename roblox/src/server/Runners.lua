-- Each player's runner body: one invisible box that physics moves, plus a dormant Humanoid kept only so Roblox's
-- player plumbing still works (the default touch joystick, CharacterAdded, network ownership).
-- Why not the stock character: docs/systems/movement.md, "The character". The client drives the box
-- (client/Body.lua); the server only builds it, owns its spawn and hands its physics to the player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Runners = {}

-- No friction against walls and floors (a stored speed must not rub away, and a wall slide must not stick);
-- the high weights make OUR zeros win when two parts' friction is combined.
local FRICTIONLESS = PhysicalProperties.new(1, 0, 0, 100, 100)

local function build(player: Player, spawnAt: Vector3): Model
	local model = Instance.new("Model")
	model.Name = player.Name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(Config.RUNNER_WIDTH, Config.RUNNER_HEIGHT, Config.RUNNER_DEPTH)
	root.CFrame = CFrame.new(spawnAt)
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.CustomPhysicalProperties = FRICTIONLESS
	root.Parent = model

	-- A Humanoid without a Head can die on its own; give it a weightless, non-colliding one.
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.CFrame = root.CFrame * CFrame.new(0, Config.RUNNER_HEIGHT / 2 - 0.5, 0)
	head.Transparency = 1
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0 -- also hides Roblox's own touch jump button; ours replaces it
	humanoid.PlatformStand = true -- the Humanoid applies no forces: Movement owns every speed
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

function Runners.spawn(player: Player, spawnAt: Vector3)
	if not player.Parent then return end
	local old = player.Character
	local model = build(player, spawnAt)
	player.Character = model
	model.Parent = workspace
	if old and old ~= model then old:Destroy() end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- The player's own client simulates its runner (the same as a stock character). pcall: it errors if the part
	-- is anchored or not in Workspace; say so in Output and still finish the spawn.
	local ok, err = pcall(function() root:SetNetworkOwner(player) end)
	if not ok then warn("[Rotag] SetNetworkOwner failed: " .. tostring(err)) end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.wait(1)
		if player.Parent and player.Character == model then Runners.spawn(player, spawnAt) end
	end)
end

-- Call once at boot, before anyone has a character.
function Runners.start(spawnAt: Vector3)
	Players.CharacterAutoLoads = false
	-- Shift is the dash. Roblox's shift-lock would grab it too; the client also sinks Shift (client/Controls.lua).
	pcall(function() StarterPlayer.EnableMouseLockOption = false end)
	local function onPlayer(player: Player)
		pcall(function() player.DevEnableMouseLock = false end)
		Runners.spawn(player, spawnAt)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
end

return Runners
