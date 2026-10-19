-- Off-screen arrows (DESIGN §2, locked: "each player has their own camera, with off-screen arrows pointing to the
-- other players"; H11, docs/systems/players.md §4). One marker per other runner whose sprite is off this screen,
-- on the screen's edge toward it: a round badge with the runner's initial and a pointer turned toward it. The holder's
-- is red; a ghost's is hollow and pale blue (H15, DESIGN §3 rule 41); runners waiting for the next round are dim. The maths is shared/SideCam.edgeArrow
-- (pure, tested); this file only builds and moves the GUI. Placeholder UI, not art.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SideCam = require(Shared:WaitForChild("SideCam"))

local Arrows = {}

local RUNNER_TAG = "RotagRunner" -- server/Runners.lua Runners.TAG
local MARGIN = Config.STUDS_PER_TILE / 2 -- studs past the edge where half the 4-stud sprite still shows: no arrow yet
local INSET = 3.5 -- studs in from the edge (at the 48-stud view, ~50 px on a 700 px tall screen)
local SIZE = 34 -- px, the badge
local RED, WHITE = Color3.fromRGB(255, 50, 40), Color3.fromRGB(245, 245, 245)
local GHOST_BLUE = Color3.fromRGB(170, 215, 255)

local gui: ScreenGui? = nil
local markers: { [Model]: { frame: Frame, pointer: Frame, label: TextLabel } } = {}
local nameOf: (number?) -> string = tostring

local function build(): { frame: Frame, pointer: Frame, label: TextLabel }
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(SIZE, SIZE)
	frame.BackgroundTransparency = 1
	-- The pointer: a square turned 45 degrees, its centre on the badge's rim, inside a holder that rotates.
	local pointer = Instance.new("Frame")
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0.5, 0.5)
	pointer.Size = UDim2.fromScale(1, 1)
	pointer.BackgroundTransparency = 1
	pointer.Parent = frame
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromScale(1, 0.5)
	tip.Size = UDim2.fromOffset(SIZE * 0.45, SIZE * 0.45)
	tip.Rotation = 45
	tip.BorderSizePixel = 0
	tip.Parent = pointer
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.Size = UDim2.fromScale(1, 1)
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 18
	badge.TextColor3 = Color3.new(0, 0, 0)
	badge.ZIndex = 2
	badge.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local ring = Instance.new("UIStroke") -- a ghost's badge is this ring alone (hollow)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = 3
	ring.Color = GHOST_BLUE
	ring.Enabled = false
	ring.Parent = badge
	frame.Parent = gui
	return { frame = frame, pointer = pointer, label = badge }
end

-- Every render frame, after the camera moved. `me` is our runner id; `state` the server's last MatchState (or nil).
function Arrows.update(me: number, state: any)
	if not gui then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local view = camera.ViewportSize
	if view.Y <= 0 then return end
	local cam = camera.CFrame.Position
	local seen: { [Model]: boolean } = {}
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		local id = model:GetAttribute("RunnerId")
		local root = model:FindFirstChild("HumanoidRootPart")
		if model:IsA("Model") and type(id) == "number" and id ~= me and root and root:IsA("BasePart") then
			local p = root.Position
			local arrow = SideCam.edgeArrow(cam.X, cam.Y, view.X / view.Y, p.X, p.Y, MARGIN, INSET)
			if arrow then
				seen[model] = true
				local m = markers[model] or build()
				markers[model] = m
				local holder = state ~= nil and not state.over and state.it == id
				local inPlay = state == nil or table.find(state.alive, id) ~= nil
				local ghost = false
				if state and type(state.ghosts) == "table" then
					for _, e in state.ghosts do if e.id == id then ghost = true end end
				end
				local color = if holder then RED elseif ghost then GHOST_BLUE else WHITE
				m.label.BackgroundColor3 = color
				m.label.Text = string.upper(string.sub(nameOf(id), 1, 1))
				m.label.TextColor3 = if ghost then GHOST_BLUE else Color3.new(0, 0, 0)
				local ring = m.label:FindFirstChildOfClass("UIStroke")
				if ring then ring.Enabled = ghost end
				local tip = m.pointer:FindFirstChildOfClass("Frame")
				if tip then tip.BackgroundColor3 = color end
				local fade = if inPlay or ghost then 0 else 0.6
				m.label.BackgroundTransparency, m.label.TextTransparency = if ghost then 1 else fade, fade
				if tip then tip.BackgroundTransparency = fade end
				m.frame.Position = UDim2.fromScale(arrow.u, arrow.v)
				m.pointer.Rotation = arrow.rotation
				m.frame.ZIndex = if holder then 3 else 1
			end
		end
	end
	for model, m in markers do
		if not seen[model] then
			m.frame:Destroy()
			markers[model] = nil
		end
	end
end

-- names: Hud.nameOf, so the badge's letter matches the HUD's name for that runner.
function Arrows.start(player: Player, names: (number?) -> string)
	nameOf = names
	local g = Instance.new("ScreenGui")
	g.Name = "RotagArrows"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true -- the camera's viewport includes the top bar, so the edge maths does too
	g.DisplayOrder = 1
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
end

return Arrows
