--!strict
-- The side-on camera's follow maths (DESIGN §2: side-on locked camera; §3 rule 21: leads ahead at speed).
-- Pure Luau: client/SideCamera.lua turns the numbers into a CFrame. Tests: test/luau/sidecam.test.luau.
local Config = require(script.Parent.Config)

local SideCam = {}

export type Cam = { x: number, y: number, lead: number }

function SideCam.new(x: number, y: number): Cam
	return { x = x, y = y + Config.CAMERA_Y_OFFSET, lead = 0 }
end

-- How far back along the plane's normal the camera sits so CAMERA_VIEW_HEIGHT studs fill the screen top to bottom.
function SideCam.distance(): number
	return (Config.CAMERA_VIEW_HEIGHT / 2) / math.tan(math.rad(Config.CAMERA_FOV) / 2)
end

-- Frame-rate independent ease: the share of the gap closed in dt at a stiffness of k per second.
local function ease(k: number, dt: number): number
	return 1 - math.exp(-k * dt)
end

-- Chase (targetX, targetY), the runner's position, looking ahead by its horizontal speed vx.
function SideCam.step(cam: Cam, targetX: number, targetY: number, vx: number, dt: number): Cam
	local want = math.clamp(vx * Config.CAMERA_LEAD_TIME, -Config.CAMERA_LEAD_MAX, Config.CAMERA_LEAD_MAX)
	cam.lead += (want - cam.lead) * ease(Config.CAMERA_LEAD_FOLLOW, dt)
	cam.x += (targetX + cam.lead - cam.x) * ease(Config.CAMERA_FOLLOW, dt)
	cam.y += (targetY + Config.CAMERA_Y_OFFSET - cam.y) * ease(Config.CAMERA_FOLLOW_Y, dt)
	return cam
end

return SideCam
