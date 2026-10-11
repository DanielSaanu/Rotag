-- A server-driven stand-in runner so the tag can be played before a second client exists (docs/systems/tag.md §4).
-- Studio only: Match reads RunService:IsStudio() and Config.STUDIO_DUMMY once at boot and never builds one in a live
-- server (→ learnings N1). It is a visible anchored box the server moves along the floor; it takes part in the round
-- like a player (it can be "it", be tagged, be eliminated) under the id Dummy.ID.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Dummy = {}
Dummy.ID = -1000 -- Studio's local-server test players are -1, -2, ...; this never collides with them

local PATROL_MIN, PATROL_MAX = 12, 52 -- studs; the patrol stays clear of the spawn at x = 0 (QA round 1: an idle
-- runner at spawn was tagged and passed to three times before touching a key)
local PATROL_SPEED = 18 -- slower than a run (45), so a player can catch it
local CHASE_SPEED = 30 -- as "it": slower than a run, so a player can escape it
local Y = Config.RUNNER_HEIGHT / 2 -- standing on the test map's floor (top at y = 0)

function Dummy.new(tagName: string)
	local model = Instance.new("Model")
	model.Name = "Dummy"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(Config.RUNNER_WIDTH, Config.RUNNER_HEIGHT, Config.RUNNER_DEPTH)
	root.Anchored = true
	root.CanCollide = false -- players pass through it, as they pass through each other's sprites
	root.CanQuery = false -- and their wall probes ignore it (H6: it was a moving wall that stopped a chaser dead
	-- behind it, refreshed their dash on contact, and made a run-through impossible)
	root.Color = Color3.fromRGB(255, 170, 60)
	root.Material = Enum.Material.Neon
	root.Transparency = 0.35
	root.CFrame = CFrame.new((PATROL_MIN + PATROL_MAX) / 2, Y, 0)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("RunnerId", Dummy.ID)
	CollectionService:AddTag(model, tagName)
	model.Parent = workspace
	return { model = model, root = root, dir = 1 }
end

-- One server frame. `chaseX` is the nearest alive player's x when the dummy is it and not frozen, else nil.
function Dummy.step(d, dt: number, chaseX: number?, frozen: boolean)
	if frozen then return end
	local x = d.root.Position.X
	if chaseX then
		local dx = chaseX - x
		x += math.sign(dx) * math.min(math.abs(dx), CHASE_SPEED * dt)
	else
		x += d.dir * PATROL_SPEED * dt
		if x > PATROL_MAX then d.dir = -1 elseif x < PATROL_MIN then d.dir = 1 end
	end
	d.root.CFrame = CFrame.new(x, Y, 0)
end

return Dummy
