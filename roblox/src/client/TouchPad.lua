-- Arrow buttons in place of the touch stick (playtest 2026-11-20, Mambo: "perhaps add a settings to use arrows
-- instead of the joystick"; goal 7 in docs/qa/playtest-fixes.md). Touch only. A small STICK / ARROWS switch sits at
-- the top-left of the controls; in ARROWS mode Roblox's own touch stick is hidden (GuiService.TouchControlsEnabled)
-- and two big < > buttons at the bottom-left give moveX -1 / +1 (both held: 0). Our JUMP, DASH, GRAPPLE and ITEM
-- buttons are our own, so they stay. The choice lasts for this server visit (a saved setting would be player data,
-- CLAUDE.md trigger 9: not yet). Drawing and input only: client/Controls reads TouchPad.x().
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local TouchPad = {}

local U = Enum.UserInputType
local ARROW = 88 -- px, the < > buttons
local GAP = 14
local held = { left = false, right = false }
local on = false
local pad: Frame? = nil
local switch: TextButton? = nil

local function style(b: TextButton, size: Vector2)
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.fromRGB(242, 242, 242)
	b.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
	b.BackgroundTransparency = 0.25
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(size.X, size.Y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(125, 249, 255)
	stroke.Thickness = 2
	stroke.Parent = b
end

-- One < or > button: held while a touch that began on it lasts (a thumb that slides off still ends it, as Controls').
local function arrow(parent: Frame, side: string, x: number)
	local b = Instance.new("TextButton")
	b.Name = if side == "left" then "Left" else "Right"
	b.Text = if side == "left" then "<" else ">"
	b.TextSize = 40
	style(b, Vector2.new(ARROW, ARROW))
	b.Position = UDim2.fromOffset(x, 0)
	b.Parent = parent
	local active: InputObject? = nil
	b.InputBegan:Connect(function(input)
		if input.UserInputType == U.Touch or input.UserInputType == U.MouseButton1 then
			active = input
			held[side] = true
		end
	end)
	local function release(input: InputObject)
		if active and input == active then
			active = nil
			held[side] = false
		end
	end
	b.InputEnded:Connect(release)
	UserInputService.InputEnded:Connect(release)
end

local function apply()
	if pad then pad.Visible = on end
	if switch then switch.Text = if on then "STICK" else "ARROWS" end
	held.left, held.right = false, false
	pcall(function() GuiService.TouchControlsEnabled = not on end)
end

-- Built once into the controls' ScreenGui (Controls builds it; it is only Enabled on a touch device).
function TouchPad.build(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "ArrowPad"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 24, 1, -24)
	frame.Size = UDim2.fromOffset(ARROW * 2 + GAP, ARROW)
	frame.Visible = false
	frame.Parent = gui
	arrow(frame, "left", 0)
	arrow(frame, "right", ARROW + GAP)
	pad = frame
	local s = Instance.new("TextButton")
	s.Name = "MoveSwitch"
	s.TextSize = 14
	style(s, Vector2.new(84, 30))
	s.AnchorPoint = Vector2.new(0, 1)
	-- above the pad and the stick's zone, below the top bar's buttons and the callouts (rule 23: not the lower middle)
	s.Position = UDim2.new(0, 24, 1, -(ARROW + 40))
	s.Parent = gui
	-- QA r2 (goal 7): the choice is not saved (trigger 9), so the switch says so instead of seeming to forget it
	local note = Instance.new("TextLabel")
	note.Name = "ThisVisit"
	note.BackgroundTransparency = 1
	note.Text = "this visit"
	note.Font = Enum.Font.Gotham
	note.TextSize = 11
	note.TextColor3 = Color3.fromRGB(190, 190, 205)
	note.Size = UDim2.new(1, 0, 0, 12)
	note.Position = UDim2.new(0, 0, 1, 2)
	note.Parent = s
	s.Activated:Connect(function()
		on = not on
		apply()
	end)
	switch = s
	apply()
end

-- H41: is ARROWS on (the tutorial says "the > button" then, not "the stick")?
function TouchPad.on(): boolean return on end

-- -1..1 while ARROWS is on and one is held; nil means "use the stick" (Controls falls back to it, and so to the keys
-- of a keyboard on a tablet: the hidden stick reads 0).
function TouchPad.x(): number?
	if not on or not (held.left or held.right) then return nil end
	return (if held.right then 1 else 0) - (if held.left then 1 else 0)
end

return TouchPad
