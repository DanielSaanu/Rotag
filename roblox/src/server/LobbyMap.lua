-- The lobby and the room as parts (H37, docs/systems/lobby.md): built once at boot from shared/Lobby's data, beside
-- the arena (the same world, far along x). Solid: the floor, the end walls, the ledges. Everything else is paint a
-- runner walks through: each door's dark doorway, its neon frame and its sign, the floor's zone names, the room's
-- code, seats and setting blocks. Words are SurfaceGuis on the camera-facing (+Z, "Back") face, as the sprites are.
-- The few words that change (the queue's count, the room's code, a setting, a seat's name) are set HERE by the
-- server (LobbyMap.say), so every screen reads the same thing. No rule reads any of it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lobby = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lobby"))

local LobbyMap = {}

local HEAD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local INK = Color3.fromRGB(18, 20, 31)
local BACK = Color3.fromRGB(22, 25, 38)
local FAR = { Color3.fromRGB(29, 33, 50), Color3.fromRGB(26, 30, 45), Color3.fromRGB(33, 38, 57) }
local BLOCK, FLOOR = Color3.fromRGB(48, 55, 82), Color3.fromRGB(34, 39, 60)
local EDGE = Color3.fromRGB(120, 200, 255)
local TEXT = Color3.fromRGB(238, 241, 255)
local DEPTH = 8 -- a solid part's depth about z 0, as the arena's
-- Paint sits BEHIND the runners' plane (their sprites are at z ~ +1), in front of the backdrop.
local Z_BACK, Z_DOOR, Z_FRAME, Z_SIGN, Z_FRONT = -3.9, -3.4, -3.2, -3.0, DEPTH / 2 + 0.06

local labels: { [string]: TextLabel } = {}

local function rgb(c: { number }): Color3 return Color3.fromRGB(c[1], c[2], c[3]) end

local function part(parent: Instance, name: string, x: number, y: number, z: number, w: number, h: number, d: number,
	color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color = Vector3.new(w, h, d), CFrame.new(x, y, z), color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Words on a part's camera-facing face, scaled to fit it. `key`: LobbyMap.say can change them later.
local function words(p: Part, text: string, color: Color3, font: Font?, key: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size, l.Position = UDim2.new(1, -8, 1, -4), UDim2.fromOffset(4, 2)
	l.FontFace, l.TextScaled, l.TextColor3, l.Text = font or HEAD, true, color, text
	l.Parent = gui
	if key then labels[key] = l end
	return l
end

-- A sign: a lit plate with dark words.
local function sign(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3, text: string,
	key: string?)
	local p = part(parent, name, x, y, Z_SIGN, w, h, 0.2, color) -- flat, not Neon: under the bloom a glowing plate
	words(p, text, INK, HEAD, key) -- washed its dark words out (seen in Studio)
end

-- Words alone (on an invisible plate): what is painted in a doorway, on the wall, on the floor's face.
local function paint(parent: Instance, name: string, x: number, y: number, z: number, w: number, h: number, text: string,
	color: Color3, font: Font?, key: string?)
	local p = part(parent, name, x, y, z, w, h, 0.1, INK, nil, 1)
	words(p, text, color, font, key)
end

-- `k`: how much further back than a round this area is seen from (its words are that much bigger to match).
local function door(parent: Instance, ox: number, oy: number, d: Lobby.Door, k: number)
	local c = rgb(d.color)
	local w, h = d.x1 - d.x0, d.y1 - d.y0
	local cx, base = ox + (d.x0 + d.x1) / 2, oy + d.y0
	local t = if d.big then 0.9 else 0.6 -- the frame's thickness
	part(parent, d.id .. "Doorway", cx, base + h / 2, Z_DOOR, w, h, 0.2, INK)
	part(parent, d.id .. "Left", ox + d.x0 - t / 2, base + (h + t) / 2, Z_FRAME, t, h + t, 0.3, c, Enum.Material.Neon)
	part(parent, d.id .. "Right", ox + d.x1 + t / 2, base + (h + t) / 2, Z_FRAME, t, h + t, 0.3, c, Enum.Material.Neon)
	part(parent, d.id .. "Top", cx, base + h + t / 2, Z_FRAME, w, t, 0.3, c, Enum.Material.Neon)
	-- The sign: exactly as wide as its door's frame and centred on it (Danzo: "the labels were off centred": the
	-- first signs were wider than their doors and ran into each other).
	local sh = (if d.big then 4.2 else 3) * k
	sign(parent, d.id .. "Sign", cx, base + h + t + 0.5 + sh / 2, w + 2 * t, sh, c, d.name)
	-- In the doorway, over a runner's head: the door's own few characters (QUICK MATCH's become the queue's count).
	local ih = (if d.big then 3.6 else 2.2) * k
	paint(parent, d.id .. "Inside", cx, base + h - 0.6 - ih / 2, Z_FRAME, w - 1.5, ih, d.inside, c, HEAD, d.id)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = c, 14, 0.6
	light.Parent = parent:FindFirstChild(d.id .. "Top")
end

local function area(a: Lobby.Area): Model
	local m = Instance.new("Model")
	m.Name = if a.name == "lobby" then "Lobby" else "Room"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- whole before a client's first frame, as the map is
	local ox, oy = a.x, a.y
	for _, b in a.blocks do
		local w, h = b[4] - b[2], b[5] - b[3]
		local p = part(m, b[1], ox + (b[2] + b[4]) / 2, oy + (b[3] + b[5]) / 2, 0, w, h, DEPTH, if b[1] == "Floor" then FLOOR else BLOCK)
		p.CanCollide, p.CanQuery = true, true -- the only solid things: a runner's probes and physics meet these
		part(m, b[1] .. "Edge", ox + (b[2] + b[4]) / 2, oy + b[5] - 0.15, Z_FRONT, w, 0.3, 0.12, EDGE, Enum.Material.Neon)
	end
	local k = a.view / 48
	local wide = a.half / 40
	-- The backdrop: a dark wall with a few far towers, so the neon reads and the arena's own backdrop is not needed.
	part(m, "Backdrop", ox, oy + a.viewY, -4.6, 2 * a.half + 80, a.view + 28, 0.4, BACK)
	for i, t in { { -52, 26, 34 }, { -24, 16, 46 }, { 2, 30, 30 }, { 30, 18, 42 }, { 54, 22, 36 } } do
		part(m, "Far" .. i, ox + t[1] * wide, oy + t[3] * k / 2, -4.3, t[2] * wide, t[3] * k, 0.2, FAR[i % #FAR + 1])
	end
	-- A group of doors: its colour washed behind them, and its name on a plate exactly as wide as the group, centred
	-- under it: on the floor's face downstairs, hanging under the deck upstairs.
	for _, z in a.zones do
		local w, cx, base = z[3] - z[2], ox + (z[2] + z[3]) / 2, oy + z[5]
		part(m, "Wash" .. z[1], cx, base + 8, Z_BACK, w + 4, 16, 0.2, rgb(z[4]), nil, 0.9)
		local ph = 1.7 * k
		sign(m, "Zone" .. z[1], cx, if z[5] == 0 then base - 0.6 - ph / 2 else base - 1.4 - ph / 2, w, ph, rgb(z[4]), z[1])
		if z[5] == 0 then
			local plate = m:FindFirstChild("Zone" .. z[1]) :: Part
			plate.CFrame = CFrame.new(plate.Position.X, plate.Position.Y, Z_FRONT)
		end
	end
	for _, d in a.doors do door(m, ox, oy, d, k) end
	for _, b in a.blocks do -- the way up says so (QA round 1: two thin ledges with no cue)
		if string.sub(b[1], 1, 4) == "Step" then
			sign(m, b[1] .. "Up", ox + (b[2] + b[4]) / 2, oy + b[5] + 4.6, 7, 3 * k, TEXT, "UP")
		end
	end
	part(m, "SpawnMark", ox + a.spawn.x + 6, oy - 0.2, Z_FRONT, 15, 0.4, 0.12, TEXT, Enum.Material.Neon)
	return m
end

-- The room's own furniture: the code on the wall, the three setting blocks, the four seats.
local function furnish(m: Model, a: Lobby.Area)
	local ox, oy = a.x, a.y
	local pink = rgb(Lobby.COLORS.pink)
	-- Below the top half of the screen (the callouts' place: seen in Studio, the 3-2-1 sat on the code), above the blocks.
	-- On the LEFT of the wall (QA round 1: centred, the 3-2-1 and the big line sat on it, and its help line ran into
	-- START's sign): the middle of the screen is the callouts'.
	local wx = ox - 24
	paint(m, "CodeTitle", wx, oy + 31.6, Z_SIGN, 30, 2.8, "ROOM CODE", pink, HEAD)
	for i = 1, Lobby.CODE_LEN do
		sign(m, "Code" .. i, wx + (i - 2.5) * 8, oy + 25.4, 7, 8.4, pink, "-", "code" .. i)
	end
	paint(m, "CodeHelp", wx, oy + 18.8, Z_SIGN, 34, 2.4, "FRIENDS USE:  ENTER A CODE", TEXT, BODY)
	paint(m, "BumpHelp", ox, oy + 11.6, Z_SIGN, 70, 2.3, "HOST: JUMP INTO A BLOCK TO CHANGE IT", TEXT, HEAD, "bumphelp")
	for _, b in a.bumps do
		local w, h = b[4] - b[2], b[5] - b[3]
		local cx, cy = ox + (b[2] + b[4]) / 2, oy + (b[3] + b[5]) / 2
		part(m, b[1] .. "Rim", cx, cy, Z_DOOR, w + 0.5, h + 0.5, 0.2, TEXT, Enum.Material.Neon)
		part(m, b[1] .. "Block", cx, cy, Z_FRAME, w, h, 0.2, INK)
		paint(m, b[1] .. "Label", cx, cy + h / 4, Z_SIGN, w - 1, h / 2 - 0.3, b[6], Color3.fromRGB(201, 207, 232), BODY)
		paint(m, b[1] .. "Value", cx, cy - h / 4 + 0.1, Z_SIGN, w - 1, h / 2, "-", TEXT, HEAD, b[1])
	end
	local seats = { Lobby.COLORS.cyan, Lobby.COLORS.lime, Lobby.COLORS.pink, Lobby.COLORS.gold }
	for i, sx in Lobby.SEATS_X do
		part(m, "Seat" .. i, ox + sx, oy - 0.2, Z_FRONT, 9, 0.4, 0.12, rgb(seats[i]), Enum.Material.Neon)
		paint(m, "SeatName" .. i, ox + sx, oy - 1.9, Z_FRONT, 11.5, 2.2, "", rgb(seats[i]), HEAD, "seat" .. i)
	end -- (no line under the seats: it was clipped at the screen's bottom edge; BOTS says it when it changes)
end

-- Change one of the keyed words on every screen: "quick" (the queue's count in the QUICK MATCH doorway), "code1".."4",
-- "rounds" / "items" / "bots" (the blocks' values), "seat1".."4", "bumphelp", "seathelp", "start".
function LobbyMap.say(key: string, text: string, color: Color3?)
	local l = labels[key]
	if not l then return end
	if l.Text ~= text then l.Text = text end
	if color and l.TextColor3 ~= color then l.TextColor3 = color end
end

function LobbyMap.build()
	for _, name in Lobby.NAMES do
		local a = Lobby.AREAS[name]
		local old = workspace:FindFirstChild(if name == "lobby" then "Lobby" else "Room")
		if old then old:Destroy() end
		local m = area(a)
		if name == "room" then furnish(m, a) end
		m.Parent = workspace
	end
	print(("[Rotag] lobby: built at x %d (%d doors), the room at x %d"):format(Lobby.AREAS.lobby.x, #Lobby.AREAS.lobby.doors,
		Lobby.AREAS.room.x))
end

return LobbyMap
