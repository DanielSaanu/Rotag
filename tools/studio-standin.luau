-- A stand-in second runner for solo Play in Studio (docs/systems/players.md §6). Paste into the Studio MCP's
-- execute_luau on the SERVER datamodel while Play is running, or into the command bar with the server focused.
--
-- It is a REAL runner body: unanchored, server-owned, CanCollide = true in the RotagRunners group, tagged
-- RotagRunner with RunnerId -2, so client/Others draws it and runners pass through it. Driven by velocity, not
-- CFrame, so other clients get Roblox's interpolation (an anchored, CFrame-moved part replicates in steps and looks
-- choppy; seen 2026-10-12). It is NOT joined to the match, so it holds no round and cannot be tagged.
-- Remove it with: _G.RotagStandIn.stop()
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
if _G.RotagStandIn then _G.RotagStandIn.stop() end
task.wait(2) -- let Match boot and the player's runner spawn first

local Y0 = 1.8 -- Arena.SPAWN.Y
local model = Instance.new("Model")
model.Name = "StandIn"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(C.RUNNER_WIDTH, C.RUNNER_HEIGHT, C.RUNNER_DEPTH)
root.CFrame = CFrame.new(-6, Y0 + 0.5, 0)
root.Transparency = 1
root.CanCollide = true
root.Anchored = false
root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100) -- frictionless, as Runners.build
root.CollisionGroup = "RotagRunners"
root.Parent = model
local att = Instance.new("Attachment"); att.Parent = root
local ao = Instance.new("AlignOrientation") -- keeps it upright
ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
ao.Attachment0 = att
ao.CFrame = CFrame.new()
ao.RigidityEnabled = true
ao.Parent = root
model.PrimaryPart = root
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
model:SetAttribute("RunnerId", -2)
CS:AddTag(model, "RotagRunner")
model.Parent = workspace
root:SetNetworkOwner(nil) -- the server simulates it

-- Run between XMIN and XMAX at run speed, through the spawn at x = 0; a jump every 2.5 s on the floor.
local XMIN, XMAX = -8, 32
local dir, jumpClock = 1, 0
local conn = RunService.Heartbeat:Connect(function(dt)
	local p = root.Position
	if p.X > XMAX then dir = -1 elseif p.X < XMIN then dir = 1 end
	local v = root.AssemblyLinearVelocity
	local grounded = p.Y <= Y0 + 0.08 and math.abs(v.Y) < 1
	jumpClock += dt
	local vy = v.Y
	if grounded and jumpClock > 2.5 then vy, jumpClock = C.JUMP_SPEED, 0 end
	root.AssemblyLinearVelocity = Vector3.new(dir * C.RUN_SPEED, vy, 0)
	root.AssemblyAngularVelocity = Vector3.zero
	if math.abs(p.Z) > 0.05 then root.CFrame = CFrame.new(p.X, p.Y, 0) end -- stay on the plane
	if p.Y < -20 then root.CFrame = CFrame.new(0, Y0 + 0.5, 0) end -- fell out: reset
end)
_G.RotagStandIn = { model = model, stop = function() conn:Disconnect(); model:Destroy(); _G.RotagStandIn = nil end }
return "stand-in up"
