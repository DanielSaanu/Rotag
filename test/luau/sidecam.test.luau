local Config = __require("Config")
local SideCam = __require("SideCam")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local DT = 1 / 60

do -- the distance shows CAMERA_VIEW_HEIGHT studs top to bottom
	local d = SideCam.distance()
	assert(near(2 * d * math.tan(math.rad(Config.CAMERA_FOV) / 2), Config.CAMERA_VIEW_HEIGHT, 1e-6), "view height")
end

do -- standing still: settles on the runner, raised by the y offset, no lead
	local cam = SideCam.new(0, 0)
	for _ = 1, 600 do SideCam.step(cam, 10, 5, 0, DT) end
	assert(near(cam.x, 10, 1e-3) and near(cam.y, 5 + Config.CAMERA_Y_OFFSET, 1e-3) and near(cam.lead, 0, 1e-3), "settles")
end

do -- running: the camera looks ahead of the runner, capped, on both sides (rule 21)
	local cam = SideCam.new(0, 0)
	local x = 0
	for _ = 1, 600 do x += Config.RUN_SPEED * DT SideCam.step(cam, x, 0, Config.RUN_SPEED, DT) end
	assert(cam.x > x, "leads to the right when running right")
	assert(cam.lead <= Config.CAMERA_LEAD_MAX + 1e-9, "lead is capped")
	cam = SideCam.new(0, 0)
	x = 0
	for _ = 1, 600 do x -= Config.DASH_SPEED * DT SideCam.step(cam, x, 0, -Config.DASH_SPEED, DT) end
	assert(cam.x < x and near(cam.lead, -Config.CAMERA_LEAD_MAX, 1e-3), "leads left, capped at the dash")
end

do -- frame-rate independent: 30 fps and 60 fps end in the same place
	local a, b = SideCam.new(0, 0), SideCam.new(0, 0)
	for _ = 1, 60 do SideCam.step(a, 20, 0, 0, 1 / 60) end
	for _ = 1, 30 do SideCam.step(b, 20, 0, 0, 1 / 30) end
	assert(near(a.x, b.x, 1e-6), "same place at either frame rate")
end

do -- off-screen arrows (H11, players.md §4): none on screen, at the edge toward the target, rotated to point at it
	local H = Config.CAMERA_VIEW_HEIGHT
	local aspect = 16 / 9
	local W = H * aspect
	assert(SideCam.edgeArrow(0, 0, aspect, W / 2 - 1, H / 2 - 1, 2, 3) == nil, "on screen: no arrow")
	assert(SideCam.edgeArrow(0, 0, aspect, W / 2 + 1.5, 0, 2, 3) == nil, "half the sprite still showing: no arrow")
	local r = SideCam.edgeArrow(0, 0, aspect, 500, 0, 2, 3)
	assert(r and near(r.v, 0.5) and near(r.u, 0.5 + (W / 2 - 3) / W) and near(r.rotation, 0), "right: right edge, points right")
	local l = SideCam.edgeArrow(10, 5, aspect, -500, 5, 2, 3)
	assert(l and near(l.u, 0.5 - (W / 2 - 3) / W) and near(math.abs(l.rotation), 180), "left: left edge, points left")
	local up = SideCam.edgeArrow(0, 0, aspect, 0, 300, 2, 3)
	assert(up and near(up.u, 0.5) and near(up.v, 0.5 - (H / 2 - 3) / H) and near(up.rotation, -90), "above: top, points up")
	local dn = SideCam.edgeArrow(0, 0, aspect, 0, -300, 2, 3)
	assert(dn and near(dn.v, 0.5 + (H / 2 - 3) / H) and near(dn.rotation, 90), "below: bottom (v grows down), points down")
	-- A far corner: on the line from the centre to the target, clamped to whichever edge it meets first, inside the view.
	local c = SideCam.edgeArrow(0, 0, aspect, 400, 100, 2, 3)
	assert(c and c.u > 0.5 and c.u <= 1 and c.v < 0.5 and c.v >= 0, "up-right: inside the view")
	local px, py = (c.u - 0.5) * W, (0.5 - c.v) * H
	assert(near(py / px, 100 / 400, 1e-9), "on the line to the target")
	assert(near(px, W / 2 - 3) or near(py, H / 2 - 3), "on the inset edge")
	assert(near(c.distance, math.sqrt(400 * 400 + 100 * 100)), "distance from the view's centre")
	-- The aspect matters: a tall phone shows less width, so the same target needs an arrow sooner.
	assert(SideCam.edgeArrow(0, 0, 2, 40, 0, 0, 3) == nil and SideCam.edgeArrow(0, 0, 0.5, 40, 0, 0, 3) ~= nil, "aspect")
end

print("sidecam ok")
