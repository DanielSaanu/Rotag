-- The closing walls on every screen (H24, DESIGN §3 rules 3, 51; docs/systems/endgame.md §7). It DECIDES nothing: the
-- server's MatchState carries the window ({ x, hw, vx, vhw }) and who is outside with how much grace; this draws it.
-- SpeedRunners' red frame, in world space: past each wall the world is tinted red (a see-through band in front of the
-- map), the wall itself is a bright neon line that beats faster as it closes (the music's tempo, drawn), and while
-- a wall is off this screen a red glow on that screen edge grows as it nears. The local runner outside gets a big
-- "GET BACK IN" line with the grace counting down and an arrow home. Not solid: nothing here collides or is queried.
-- Placeholder look, no sheet art. Cost per frame: four parts moved, two frames faded, one label.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Walls = {}

local Z = 4.7 -- in front of the map's front face (Arena parts are 8 deep about z 0), as the burn-out burst (H23)
local TALL, BAND = 600, 400 -- studs: taller than any map, and the tint reaches far past the wall
local EDGE_W = 0.8
local RED, TINT = Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 30, 30) -- QA round 1: (190, 15, 30) read mauve
local hw0: number? = nil -- the half-width when this client first saw the walls: the beat's tempo runs on the progress
local HOT = Color3.fromRGB(255, 225, 100)
local HIDDEN = CFrame.new(0, -1e4, 0)
local EXTRAPOLATE = 0.5 -- seconds a MatchState's window is carried forward at most (they come 4 a second)
local SMOOTH = 15 -- 1/s: the drawn window closes the gap to the extrapolated one at this rate (QA H26 r1: the wander's
-- acceleration made each MatchState land ~0.29 studs off the extrapolation, a visible hop 4 times a second)
local drawX: number? = nil -- the window as drawn last frame (nil: not shown)
local drawHw = 0
local lastFrame = 0
local predictedWas = false -- the local GET BACK IN prediction, with the server's hysteresis (WALL_BACK_IN)
local NEAR = 40 -- studs: an off-screen wall's edge glow starts this far beyond the screen's edge

local parts: { { edge: BasePart, band: BasePart } } = {}
local glows: { Frame } = {}
local label: TextLabel? = nil

local function part(name: string, w: number, color: Color3, material: Enum.Material, folder: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(w, TALL, 0.2)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false -- never a wall
	p.Material, p.Color = material, color -- to the runner's probes (T11: a ray hits anything with CanQuery)
	p.CFrame = HIDDEN
	p.Parent = folder
	return p
end

function Walls.start(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "RotagWalls" -- local to this client, never replicated; nothing finds it by name
	for _ = 1, 2 do
		table.insert(parts, { edge = part("Edge", EDGE_W, RED, Enum.Material.Neon, folder),
			band = part("Outside", BAND, TINT, Enum.Material.SmoothPlastic, folder) })
	end
	folder.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "RotagWallsHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	for i = 1, 2 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = RED
		f.Size = UDim2.fromScale(0.06, 1)
		f.Position = UDim2.fromScale(if i == 1 then 0 else 0.94, 0)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new(if i == 1 then 0 else 1, if i == 1 then 1 else 0)
		g.Parent = f
		f.BackgroundTransparency = 1
		f.Parent = gui
		glows[i] = f
	end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, 0, 0, 228) -- QA round 1: a fixed row UNDER the Hud's end-phase line (which ends at y 188)
	l.Size = UDim2.new(0.9, 0, 0, 70)
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 44
	l.TextStrokeTransparency = 0
	l.Text = ""
	l.Parent = gui
	label = l
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function hide()
	for _, p in parts do p.edge.CFrame, p.band.CFrame = HIDDEN, HIDDEN end
	for _, g in glows do g.BackgroundTransparency = 1 end
	if label then label.Text = "" end
end

-- Every render frame. `state` is the client's last MatchState (client/Tagging), `myX` our runner's x (nil if none),
-- `grace` = Tagging.graceLeft(me): the server's count for us, or nil while it has us inside.
function Walls.update(state: any, myX: number?, grace: number?)
	local w = state and not state.over and state.window
	if not w then
		hide()
		hw0, drawX, predictedWas = nil, nil, false
		return
	end
	local now = os.clock()
	local age = math.clamp(now - (state.at or now), 0, EXTRAPOLATE)
	local x = w.x + w.vx * age
	local hw = math.max(Config.WALL_MIN_HW, w.hw + w.vhw * age)
	if drawX == nil then
		drawX, drawHw = x, hw -- first sight: snap
	else
		local k = 1 - math.exp(-SMOOTH * math.clamp(now - lastFrame, 0, 0.1))
		drawX += (x - (drawX :: number)) * k
		drawHw += (hw - drawHw) * k
	end
	lastFrame = now
	x, hw = drawX :: number, drawHw
	hw0 = math.max(hw0 or hw, hw)
	local span = (hw0 :: number) - Config.WALL_MIN_HW
	local closed = if span < 1 then 1 else math.clamp(((hw0 :: number) - hw) / span, 0, 1) -- progress, whatever the start width
	local beat = 0.5 + 0.5 * math.sin(now * 2 * math.pi * (1 + 3 * closed)) -- 1 -> 4 beats a second as it closes
	for i, p in parts do
		local side = if i == 1 then -1 else 1
		p.edge.CFrame = CFrame.new(x + side * hw, 0, Z + 0.05)
		p.band.CFrame = CFrame.new(x + side * (hw + BAND / 2), 0, Z)
		p.edge.Transparency = 0.35 * beat
		p.band.Transparency = 0.6 - 0.08 * beat
	end
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 0 then -- an off-screen wall glows on the edge it is coming from
		local half = Config.CAMERA_VIEW_HEIGHT * camera.ViewportSize.X / camera.ViewportSize.Y / 2
		local cx = camera.CFrame.Position.X
		for i, g in glows do
			local side = if i == 1 then -1 else 1
			local beyond = side * (x + side * hw - cx) - half -- studs past this screen's edge (< 0: on screen)
			g.BackgroundTransparency = if beyond <= 0 or beyond > NEAR then 1 else 0.35 + 0.65 * beyond / NEAR
		end
	end
	if not label then return end
	-- the server hears a ping later; the same hysteresis as its own (shared/Walls.outside): out past the wall, back in
	-- only WALL_BACK_IN further in, so a runner on a swaying line never sees the label blink
	local predicted = myX ~= nil and math.abs(myX - x) > hw + Config.RUNNER_WIDTH / 2 - (if predictedWas then Config.WALL_BACK_IN else 0)
	predictedWas = predicted
	if grace == nil and not predicted then
		label.Text = ""
		return
	end
	local left = grace or Config.WALL_GRACE
	local home = if myX and myX > x then "<<<" else ">>>"
	label.Text = if home == "<<<" then ("<<<  GET BACK IN  %.1f"):format(left) else ("GET BACK IN  %.1f  >>>"):format(left)
	local urgency = 1 - math.clamp(left / Config.WALL_GRACE, 0, 1)
	local b = 0.5 + 0.5 * math.sin(now * 2 * math.pi * (2 + 6 * urgency))
	label.TextColor3 = RED:Lerp(HOT, b * (0.3 + 0.7 * urgency))
	label.TextSize = 44 * (1 + 0.25 * urgency * b)
end

return Walls
