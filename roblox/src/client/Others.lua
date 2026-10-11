-- Draws every OTHER runner on this screen (H11, docs/systems/players.md §3). Each runner's client draws only its own
-- body (Look is local, never replicated), so without this a second player is an invisible box. Here each other
-- runner gets its own Look, fed every render frame by shared/RemotePose from the position Roblox replicates (option
-- a: no remote, so the pose can never run ahead of or behind the body it is drawn on). Cosmetic only: nothing here
-- is sent anywhere or decides anything. The Studio dummy stays its orange box (Danzo's call, default box).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Movement = require(Shared:WaitForChild("Movement"))
local RemotePose = require(Shared:WaitForChild("RemotePose"))
local Look = require(script.Parent:WaitForChild("Look"))

local Others = {}

local RUNNER_TAG = "RotagRunner" -- server/Runners.lua Runners.TAG
local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local GROUND_PROBE = 2 -- studs below the feet: enough to tell standing from airborne
local WALL_PROBE = Movement.wallReach() + 0.1
local INSET = 0.1

local drawn: { [Model]: { root: BasePart, look: any, pose: RemotePose.Pose, params: RaycastParams } } = {}
local player: Player? = nil

local function shortest(origins: { Vector3 }, dir: Vector3, half: number, params: RaycastParams): number?
	local best = nil
	for _, origin in origins do
		local hit = workspace:Raycast(origin, dir, params)
		if hit and (best == nil or hit.Distance - half < best) then best = hit.Distance - half end
	end
	return best
end

local function add(model: Instance)
	if not model:IsA("Model") or drawn[model] then return end
	local id = model:GetAttribute("RunnerId")
	if type(id) ~= "number" or id < -999 then return end -- the Studio dummy (-1000) keeps its box
	if player and model == player.Character then return end -- our own runner: Client.client.lua draws it
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (root and root:IsA("BasePart") and model.Parent) or drawn[model] then return end
	if player and model == player.Character then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	params.CollisionGroup = root.CollisionGroup -- runners pass through runners (players.md §2)
	local p = root.Position
	drawn[model] = { root = root, look = Look.new(model, root), pose = RemotePose.new(p.X, p.Y), params = params }
end

local function remove(model: Instance)
	local d = drawn[model :: Model]
	if not d then return end
	drawn[model :: Model] = nil
	d.look:destroy()
end

-- Every render frame, after the camera.
function Others.draw(dt: number)
	for model, d in drawn do
		if not d.root.Parent or (player and model == player.Character) then
			remove(model)
			continue
		end
		local p = d.root.Position
		local x, y = p.X, p.Y
		local below = { Vector3.new(x - HW + INSET, y, 0), Vector3.new(x, y, 0), Vector3.new(x + HW - INSET, y, 0) }
		local side = { Vector3.new(x, y - HH + 0.2, 0), Vector3.new(x, y, 0), Vector3.new(x, y + HH - 0.2, 0) }
		local ground = shortest(below, Vector3.new(0, -(HH + GROUND_PROBE), 0), HH, d.params)
		local wall = shortest(side, Vector3.new(-(HW + WALL_PROBE), 0, 0), HW, d.params) ~= nil
			or shortest(side, Vector3.new(HW + WALL_PROBE, 0, 0), HW, d.params) ~= nil
		local sprite, events = RemotePose.step(d.pose, x, y, ground, wall, dt)
		d.look:react(events)
		d.look:draw(sprite, d.pose.facing, d.pose.dashTime > 0, d.pose.vx, dt)
	end
end

-- The sheet ids landed late (Remotes.SheetIds): every other runner re-applies its sprite on the next draw too.
function Others.refresh()
	for _, d in drawn do d.look:refresh() end
end

function Others.start(localPlayer: Player)
	player = localPlayer
	CollectionService:GetInstanceAddedSignal(RUNNER_TAG):Connect(function(m) task.spawn(add, m) end)
	CollectionService:GetInstanceRemovedSignal(RUNNER_TAG):Connect(remove)
	for _, m in CollectionService:GetTagged(RUNNER_TAG) do task.spawn(add, m) end
end

return Others
