-- Input, turned into the plain table shared/Movement.lua reads: { moveX, jumpPressed, jumpHeld, dashPressed, touch }.
-- Run: Roblox's own control module (keys A/D, arrows, gamepad stick, the touch joystick), so the mobile joystick
-- works with no code of ours (DESIGN §3 rule 24). Jump and dash: our own bindings, and two touch buttons on
-- phones, out of the lower-middle and well over 44 px (rules 22-23). Presses are latched between frames so a tap
-- shorter than a frame is never lost; read() hands each one out exactly once.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Controls = {}

local jumpHeld, jumpPressed, dashPressed = false, false, false
local usingTouch = UserInputService.TouchEnabled
local playerControls = nil -- Roblox's ControlModule, if it loaded

local function onJump(down: boolean)
	if down and not jumpHeld then jumpPressed = true end
	jumpHeld = down
end

local function onDash(down: boolean)
	if down then dashPressed = true end
end

-- High priority and Sink: Space must not reach Roblox's own jump, Shift must not reach shift-lock.
local function bindKeys()
	local high = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority("RotagJump", function(_, state)
		if state == Enum.UserInputState.Begin then onJump(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then onJump(false) end
		return Enum.ContextActionResult.Sink
	end, false, high, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:BindActionAtPriority("RotagDash", function(_, state)
		if state == Enum.UserInputState.Begin then onDash(true) end
		return Enum.ContextActionResult.Sink
	end, false, high, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonX)
end

-- A touch button that reports down and up. The release is also caught on UserInputService, because a thumb that
-- slides off the button ends its touch somewhere else.
local function touchButton(gui: ScreenGui, name: string, label: string, position: UDim2, size: number,
	onChange: (boolean) -> ())
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = label
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(242, 242, 242)
	button.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = true
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(125, 249, 255)
	stroke.Thickness = 2
	stroke.Parent = button
	button.Parent = gui

	local active: InputObject? = nil
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			active = input
			usingTouch = true
			onChange(true)
		end
	end)
	local function release(input: InputObject)
		if active and input == active then
			active = nil
			onChange(false)
		end
	end
	button.InputEnded:Connect(release)
	UserInputService.InputEnded:Connect(release)
	return button
end

-- Two buttons in the bottom-right corner: jump the big one under the thumb, dash up and to its left. The default
-- thumbstick sits bottom-left, so the lower-middle stays clear.
local function buildTouchButtons(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RotagControls"
	gui.ResetOnSpawn = false
	gui.Enabled = UserInputService.TouchEnabled
	gui.Parent = playerGui
	touchButton(gui, "Jump", "JUMP", UDim2.new(1, -24, 1, -24), 96, onJump)
	touchButton(gui, "Dash", "DASH", UDim2.new(1, -136, 1, -72), 76, onDash)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
		gui.Enabled = UserInputService.TouchEnabled
	end)
end

-- Roblox's PlayerModule gives the raw move vector (x = right) for keys, gamepad and the touch joystick alike.
local function loadPlayerControls(player: Player)
	local ok, result = pcall(function()
		local scripts = player:WaitForChild("PlayerScripts", 10)
		if not scripts then return nil end
		local module: any = scripts:WaitForChild("PlayerModule", 10)
		if not module then return nil end
		return require(module):GetControls()
	end)
	if ok and result then
		playerControls = result
	else
		warn("[Rotag] PlayerModule controls not found; running from Humanoid.MoveDirection instead: " .. tostring(result))
	end
end

function Controls.start(player: Player)
	bindKeys()
	buildTouchButtons(player:WaitForChild("PlayerGui") :: PlayerGui)
	task.spawn(loadPlayerControls, player)
	UserInputService.LastInputTypeChanged:Connect(function(t)
		usingTouch = t == Enum.UserInputType.Touch
	end)
end

-- The stick's x, -1..1. Falls back to the Humanoid's move direction (world x is screen right with our camera).
local function moveX(humanoid: Humanoid?): number
	if playerControls then
		local ok, v = pcall(function() return playerControls:GetMoveVector() end)
		if ok and typeof(v) == "Vector3" then return v.X end
	end
	if humanoid then return humanoid.MoveDirection.X end
	return 0
end

-- One frame's input. Clears the latched presses.
function Controls.read(humanoid: Humanoid?)
	local input = {
		moveX = moveX(humanoid),
		jumpPressed = jumpPressed,
		jumpHeld = jumpHeld,
		dashPressed = dashPressed,
		touch = usingTouch,
	}
	jumpPressed, dashPressed = false, false
	return input
end

return Controls
