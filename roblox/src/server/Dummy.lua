-- A bot's body (H31, docs/systems/bots.md; before H31 this was the Studio-only floor dummy of tag.md §4): an anchored,
-- invisible box the SERVER moves, tagged and numbered like a player's runner so every system that finds runners by
-- the tag (Match, the clients' Others, the IT marker) treats it as one. It takes part in a round like a player: it
-- can be "it", be tagged, burn out, play as a ghost. server/Bots.lua decides where it goes; ids are Dummy.ID - k.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Dummy = {}
Dummy.ID = -1000 -- Studio's local-server test players are -1, -2, ...; this never collides with them

function Dummy.new(tagName: string, id: number, name: string, at: Vector3)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(Config.RUNNER_WIDTH, Config.RUNNER_HEIGHT, Config.RUNNER_DEPTH)
	root.Anchored = true
	root.CanCollide = false -- players pass through it, as they pass through each other
	root.CanQuery = false -- and their wall probes ignore it (H6: a queried dummy was a moving wall to a chaser)
	root.CanTouch = false
	root.Transparency = 1 -- every client draws the sprite (client/Others); the box is never seen
	root.CFrame = CFrame.new(at)
	root.Parent = model
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- like every runner (Runners.build, H11)
	model:SetAttribute("RunnerId", id)
	CollectionService:AddTag(model, tagName)
	model.Parent = workspace
	return model, root
end

return Dummy
