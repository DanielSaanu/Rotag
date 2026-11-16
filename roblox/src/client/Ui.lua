-- The UI kit (H31, docs/systems/ui.md): one look for the menu, the HUD, the scoreboard and the shop, so nothing on
-- screen is a bare TextLabel. Theme "glowing graphite" (DESIGN §6.3, trial): graphite panels, a thin lit edge, neon
-- accents, heavy italic headlines. Built from Roblox's own UI objects (corners, strokes, gradients): no art upload.
-- Everything is sized in a 720-pixel-tall design space and scaled to the screen (Ui.scale), so a phone and a desktop
-- show the same layout; nothing is placed in the lower middle (rule 23).
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.C = {
	ink = Color3.fromRGB(12, 13, 18),
	panel = Color3.fromRGB(24, 27, 38),
	raised = Color3.fromRGB(36, 41, 58),
	edge = Color3.fromRGB(70, 80, 112),
	text = Color3.fromRGB(238, 241, 250),
	dim = Color3.fromRGB(150, 158, 182),
	cyan = Color3.fromRGB(69, 224, 255),
	ember = Color3.fromRGB(255, 96, 48),
	gold = Color3.fromRGB(255, 208, 84),
	lime = Color3.fromRGB(150, 255, 110),
	ghost = Color3.fromRGB(170, 215, 255),
	red = Color3.fromRGB(255, 60, 50),
}

local HEAD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local LIGHT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
Ui.HEAD, Ui.BODY, Ui.LIGHT = HEAD, BODY, LIGHT

Ui.onClick = nil :: (() -> ())? -- client/Audio sets these: every button clicks and ticks the same way
Ui.onHover = nil :: (() -> ())?

function Ui.rgb(c: { number }): Color3 return Color3.fromRGB(c[1], c[2], c[3]) end

-- The scale from design pixels to this screen. Never under SCALE_MIN: on a 390-point-tall phone a plain height / 720
-- would be 0.54 and 15-pixel text would be 8 points (QA round 1). Under it the design space is simply shorter than
-- 720 (Ui.height, Ui.compact) and each screen lays itself out for that.
local SCALE_MIN, SCALE_MAX = 0.75, 1.6
function Ui.scale(): number
	local cam = workspace.CurrentCamera
	local h = if cam then cam.ViewportSize.Y else 720
	return math.clamp(h / 720, SCALE_MIN, SCALE_MAX)
end

-- The design space this screen has, in design pixels: 720 tall on a desktop, ~520 on a phone held sideways.
function Ui.height(): number
	local cam = workspace.CurrentCamera
	return (if cam then math.max(cam.ViewportSize.Y, 360) else 720) / Ui.scale()
end
function Ui.width(): number
	local cam = workspace.CurrentCamera
	return (if cam then math.max(cam.ViewportSize.X, 480) else 1280) / Ui.scale()
end
function Ui.compact(): boolean return Ui.height() < 640 end

-- Make `gui`'s one child `root`: the design space, scaled to the screen (kept right as the window resizes).
function Ui.scaled(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local k = Ui.scale()
		scale.Scale = k
		root.Size = UDim2.fromScale(1 / k, 1 / k) -- so scale-relative children still fill the screen
	end
	fit()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	return root
end

-- A ScreenGui over the whole screen (the top bar's inset included: Ui.topInset) with its scaled design-space root.
function Ui.screen(parent: Instance, name: string, order: number): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Ui.scaled(gui)
	gui.Parent = parent
	return gui, root
end

-- The top inset (the Roblox top bar, a phone's notch) in design pixels: HUD rows start below it.
function Ui.topInset(): number
	return GuiService:GetGuiInset().Y / Ui.scale()
end

function Ui.corner(o: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

function Ui.stroke(o: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.Transparency = color, thickness or 1.5, transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

function Ui.gradient(o: Instance, a: Color3, b: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = o
	return g
end

function Ui.frame(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size, f.Position, f.AnchorPoint = size, pos, anchor or Vector2.zero
	f.Parent = parent
	return f
end

-- A graphite panel with a lit edge.
function Ui.panel(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?, radius: number?): Frame
	local f = Ui.frame(parent, size, pos, anchor)
	f.BackgroundTransparency = 0.08
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	Ui.gradient(f, Ui.C.raised, Ui.C.panel)
	Ui.corner(f, radius or 14)
	Ui.stroke(f, Ui.C.edge, 1.5, 0.25)
	return f
end

function Ui.label(parent: Instance, text: string, size: number, color: Color3?, font: Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or BODY
	l.TextSize = size
	l.TextColor3 = color or Ui.C.text
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	l.TextWrapped = false
	l.Parent = parent
	return l
end

-- A dark outline, for text that sits on the world and not on a panel.
function Ui.outline(l: TextLabel | TextButton, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.Transparency = Ui.C.ink, thickness or 2.5, 0.15
	s.Parent = l
end

function Ui.tween(o: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(o, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- A button: `kind` "primary" (cyan, the one thing to press), "gold" (spend coins), "ghost" (quiet) or "plain".
-- It grows a little under the pointer and dips on a press; `fn` runs on activation (mouse, touch and gamepad).
-- The words are a child label (Ui.setText): a UIGradient on the button itself would tint its own text too.
function Ui.button(parent: Instance, text: string, kind: string, size: UDim2, pos: UDim2, fn: () -> (), anchor: Vector2?)
	: TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Size, b.Position, b.AnchorPoint = size, pos, anchor or Vector2.zero
	b.Text = ""
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	local top, bottom, ink, edge = Ui.C.raised, Ui.C.panel, Ui.C.text, Ui.C.edge
	if kind == "primary" then
		top, bottom, ink, edge = Color3.fromRGB(120, 240, 255), Color3.fromRGB(30, 170, 230), Ui.C.ink, Color3.fromRGB(190, 250, 255)
	elseif kind == "gold" then
		top, bottom, ink, edge = Color3.fromRGB(255, 226, 120), Color3.fromRGB(240, 160, 30), Ui.C.ink, Color3.fromRGB(255, 240, 180)
	elseif kind == "ghost" then
		b.BackgroundTransparency = 0.45
	end
	Ui.gradient(b, top, bottom)
	Ui.corner(b, 12)
	Ui.stroke(b, edge, 1.5, 0.1)
	local l = Ui.label(b, text, 22, ink, HEAD)
	l.Name = "Label"
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		Ui.tween(scale, 0.08, { Scale = 1.05 })
		if Ui.onHover then Ui.onHover() end
	end)
	b.MouseLeave:Connect(function() Ui.tween(scale, 0.1, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() Ui.tween(scale, 0.05, { Scale = 0.95 }) end)
	b.MouseButton1Up:Connect(function() Ui.tween(scale, 0.1, { Scale = 1 }) end)
	b.Activated:Connect(function()
		if Ui.onClick then Ui.onClick() end
		fn()
	end)
	b.Parent = parent
	return b
end

-- A button's words and, optionally, their size.
function Ui.setText(b: TextButton, text: string?, size: number?)
	local l = b:FindFirstChild("Label")
	if l and l:IsA("TextLabel") then
		if text and l.Text ~= text then l.Text = text end
		if size and l.TextSize ~= size then l.TextSize = size end
	end
end

-- A coin: a small gold disc with a lit rim (no art upload).
function Ui.coin(parent: Instance, size: number, pos: UDim2, anchor: Vector2?): Frame
	local f = Ui.frame(parent, UDim2.fromOffset(size, size), pos, anchor)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	Ui.gradient(f, Color3.fromRGB(255, 236, 140), Color3.fromRGB(235, 150, 20), 60)
	Ui.corner(f, size)
	Ui.stroke(f, Color3.fromRGB(255, 246, 200), math.max(1, size / 12), 0)
	return f
end

-- Pop a thing: from `from` x its size back to 1, with a little overshoot (a number that just changed, a card landing).
function Ui.pop(o: GuiObject, from: number?)
	local scale = o:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = o
	scale.Scale = from or 1.35
	Ui.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Ui
