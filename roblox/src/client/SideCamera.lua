-- The side-on camera (DESIGN §2): Scriptable, looking straight down -Z at the plane z = 0 from SideCam.distance(),
-- narrow field of view so it reads near-orthographic, world +X to the screen's right. The follow and the lead are
-- the pure maths in shared/SideCam.lua; this file only turns them into a CFrame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SideCam = require(Shared:WaitForChild("SideCam"))

local SideCamera = {}

local cam = nil
local DISTANCE = SideCam.distance()

-- Jump straight to (x, y): on spawn, so the camera does not swoop in from the old body.
function SideCamera.reset(x: number, y: number)
	cam = SideCam.new(x, y)
end

function SideCamera.update(x: number, y: number, vx: number, dt: number)
	local camera = workspace.CurrentCamera
	if not camera then return end
	if not cam then cam = SideCam.new(x, y) end
	SideCam.step(cam, x, y, vx, dt)
	-- Re-asserted every frame: Roblox's camera scripts may set Custom again when a character spawns.
	if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
	if camera.FieldOfView ~= Config.CAMERA_FOV then camera.FieldOfView = Config.CAMERA_FOV end
	camera.CFrame = CFrame.lookAt(Vector3.new(cam.x, cam.y, DISTANCE), Vector3.new(cam.x, cam.y, 0))
end

return SideCamera
