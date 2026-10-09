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

print("sidecam ok")
