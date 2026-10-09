-- The adapter between shared/Movement.lua and the runner's Part. The ONLY client file that knows the runner is a
-- physics part: swap the body (stock Humanoid, another rig) by rewriting this file and server/Runners.lua.
-- read(): position and surface distances in, as plain numbers. apply(): velocity out, held to the plane z = 0.
-- Physics does the moving and the colliding; Movement owns every speed, so gravity is cancelled here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Body = {}
Body.__index = Body

local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local GROUND_PROBE = 8 -- how far below the feet to look: the buffer needs to see a floor coming (Movement.landingSoon)
local CEILING_PROBE = 0.5
local WALL_PROBE = Config.WALL_JUMP_REACH_PX * Config.STUDS_PER_TILE / Config.TILE + 0.1
local INSET = 0.1 -- side rays sit just inside the collider so a wall beside us never reads as floor

function Body.new(character: Model, root: BasePart)
	local self = setmetatable({}, Body)
	self.character = character
	self.root = root
	self.params = RaycastParams.new()
	self.params.FilterType = Enum.RaycastFilterType.Exclude
	self.params.FilterDescendantsInstances = { character }
	self.params.IgnoreWater = true
	-- Cancel Roblox gravity on the runner: Movement integrates its own (half gravity at the apex, the dash).
	local attachment = Instance.new("Attachment")
	attachment.Name = "RotagAntiGravity"
	attachment.Parent = root
	local force = Instance.new("VectorForce")
	force.Name = "RotagAntiGravity"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Parent = root
	self.antiGravity = force
	return self
end

-- Shortest hit among rays from `origins` along `dir`, minus the collider's own half-extent `half`. nil: no hit.
function Body:_cast(origins: { Vector3 }, dir: Vector3, half: number): number?
	local best = nil
	for _, origin in origins do
		local hit = workspace:Raycast(origin, dir, self.params)
		if hit then
			local d = hit.Distance - half
			if best == nil or d < best then best = d end
		end
	end
	return best
end

-- The runner's position and what it is touching, in Movement's terms.
function Body:read(): (number, number, { [string]: number? })
	local p = self.root.Position
	local x, y = p.X, p.Y
	local below = {
		Vector3.new(x - HW + INSET, y, 0), Vector3.new(x, y, 0), Vector3.new(x + HW - INSET, y, 0),
	}
	local side = {
		Vector3.new(x, y - HH + 0.2, 0), Vector3.new(x, y, 0), Vector3.new(x, y + HH - 0.2, 0),
	}
	local contacts = {
		ground = self:_cast(below, Vector3.new(0, -(HH + GROUND_PROBE), 0), HH),
		ceiling = self:_cast(below, Vector3.new(0, HH + CEILING_PROBE, 0), HH),
		wallLeft = self:_cast(side, Vector3.new(-(HW + WALL_PROBE), 0, 0), HW),
		wallRight = self:_cast(side, Vector3.new(HW + WALL_PROBE, 0, 0), HW),
	}
	return x, y, contacts
end

-- Put the runner where Movement says (z = 0, upright: the plane lock) and give physics the velocity to move it by.
function Body:apply(x: number, y: number, vx: number, vy: number)
	local root = self.root
	self.antiGravity.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
	root.CFrame = CFrame.new(x, y, 0)
	root.AssemblyLinearVelocity = Vector3.new(vx, vy, 0)
	root.AssemblyAngularVelocity = Vector3.zero
end

function Body:destroy()
	if self.antiGravity then self.antiGravity:Destroy() end
	local attachment = self.root:FindFirstChild("RotagAntiGravity")
	if attachment then attachment:Destroy() end
end

return Body
