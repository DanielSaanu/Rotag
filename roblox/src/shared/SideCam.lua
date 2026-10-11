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

-- Off-screen arrows (DESIGN §2: each player has their own camera, with arrows to the other players; players.md §4).
-- The camera looks straight down the plane's normal, so on the plane z = 0 the screen is linear in x and y: the view
-- is CAMERA_VIEW_HEIGHT studs tall and that times `aspect` (width / height) wide, centred on (camX, camY). A target
-- whose centre is within `margin` studs past the view's edge still shows part of its sprite: no arrow (nil).
-- Otherwise: where the arrow sits, as screen fractions (u right, v DOWN, 0..1), `inset` studs in from the edge on the
-- line from the view's centre to the target; its rotation in GUI degrees (clockwise, 0 = pointing right); and the
-- distance in studs from the view's centre.
export type Arrow = { u: number, v: number, rotation: number, distance: number }
function SideCam.edgeArrow(camX: number, camY: number, aspect: number, tx: number, ty: number, margin: number,
	inset: number): Arrow?
	local h = Config.CAMERA_VIEW_HEIGHT
	local w = h * aspect
	local dx, dy = tx - camX, ty - camY
	if math.abs(dx) <= w / 2 + margin and math.abs(dy) <= h / 2 + margin then return nil end
	local hx, hy = math.max(0, w / 2 - inset), math.max(0, h / 2 - inset)
	local scale = math.min(if dx ~= 0 then hx / math.abs(dx) else math.huge, if dy ~= 0 then hy / math.abs(dy) else math.huge)
	return {
		u = 0.5 + dx * scale / w,
		v = 0.5 - dy * scale / h,
		rotation = -math.deg(math.atan2(dy, dx)),
		distance = math.sqrt(dx * dx + dy * dy),
	}
end

return SideCam
