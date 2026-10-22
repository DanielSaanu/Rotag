-- Input, turned into the plain table shared/Movement.lua reads: { moveX, jumpPressed, jumpHeld, dashPressed, touch }
-- plus the fields client/Use strips (usePressed, presses) and the grapple pair the grapple PR will read
-- (grapplePressed, grappleHeld; for a ghost holding a piece the same input is "rotate", PR 4).
-- Run: Roblox's own control module (keys A/D, arrows, gamepad stick, the touch joystick), so the mobile joystick
-- works with no code of ours (DESIGN §3 rule 24). Everything else: the controls table of docs/systems/controls.md §2
-- (PR 3): two keyboard schemes live at once (A: Space / Shift / W / E with the mouse; B: Z / X / C / V with ↑), the
-- pad (A jump, X and B dash, RT grapple, RB and LT use), four touch buttons in an arc around the right thumb, out of
-- the lower-middle and over 44 px (rules 22-23). Presses are latched between frames so a tap shorter than a frame is
-- never lost; read() hands each one out exactly once.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Sprites = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sprites"))

local Controls = {}

-- The table (controls.md §2). One row per verb; a remap (later, trigger 9 when saved) edits these lists only.
-- Never in here: Esc, `/`, Tab, F9, the backtick, Start and Select (Roblox's own).
local K, U = Enum.KeyCode, Enum.UserInputType
local BINDS: { [string]: { any } } = {
	jump = { K.Space, K.Z, K.ButtonA },
	dash = { K.LeftShift, K.RightShift, K.X, K.ButtonX, K.ButtonB },
	grapple = { K.W, K.C, K.Up, K.ButtonR2, U.MouseButton2 }, -- held; ghost: rotate the piece (PR 4)
	use = { K.E, K.V, K.ButtonR1, K.ButtonL2, U.MouseButton1 },
}
-- Mouse clicks pass on (GUI buttons and Roblox's own mouse handling still see them); the keys and pad are ours.
local PASS = { [U.MouseButton1] = true, [U.MouseButton2] = true }
local PRY_PAD = { [K.ButtonY] = true, [K.ButtonL1] = true } -- unbound pad buttons that still count as a pry press (QA r1)
local SCHEME_B = { [K.Z] = true, [K.X] = true, [K.C] = true, [K.V] = true, [K.Up] = true } -- the trap hint names Z then

local jumpHeld, jumpPressed, dashPressed = false, false, false
local grappleHeld, grapplePressed = false, false
-- H19 (docs/systems/items.md §6): Use, and every press of an action input (a bound key, a click, a pad button, a
-- tap anywhere) counted for prying a bear trap open. Steering keys and Shift are not counted: the trap prompt never
-- names Shift (five Shift presses offer Sticky Keys on Windows, controls.md §3).
local usePressed, presses = false, 0
local usingTouch = UserInputService.TouchEnabled
local device = if usingTouch then "touch" else "keys" -- "touch" | "pad" | "keys": the trap hint's audience (QA r1)
local schemeB = false -- the last keyboard action was Z / X / C / V / ↑: the hint says Z, not Space
local playerControls = nil -- Roblox's ControlModule, if it loaded
local buttons: { [string]: TextButton } = {} -- the touch buttons by verb
local itemImage: ImageLabel? = nil -- the ITEM button's icon, when the sheet has one

local function onJump(down: boolean)
	if down and not jumpHeld then jumpPressed = true end
	jumpHeld = down
end

local function onDash(down: boolean)
	if down then dashPressed = true end
end

local function onGrapple(down: boolean)
	if down and not grappleHeld then grapplePressed = true end
	grappleHeld = down
end

local function onUse(down: boolean)
	if down then usePressed = true end
end

local ON = { jump = onJump, dash = onDash, grapple = onGrapple, use = onUse }

-- High priority and Sink: Space must not reach Roblox's own jump, Shift must not reach shift-lock, W and ↑ must not
-- walk the character into the screen. A Shift press is not a pry press (see above); every other action press is.
local function bindKeys()
	local high = Enum.ContextActionPriority.High.Value
	for verb, keys in BINDS do
		local on = ON[verb]
		ContextActionService:BindActionAtPriority("Rotag" .. verb, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				on(true)
				if input.KeyCode ~= K.LeftShift and input.KeyCode ~= K.RightShift then presses += 1 end
				if input.UserInputType == U.Keyboard then schemeB = SCHEME_B[input.KeyCode] == true end
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				on(false)
			end
			return if PASS[input.UserInputType] then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
		end, false, high, table.unpack(keys))
	end
	-- A tap anywhere pries (controls.md §5 Q4): counted here, not on the buttons, so a tap on JUMP counts once. The
	-- pad's unbound Y and L1 count too (any face button or trigger), without becoming actions.
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == U.Touch or PRY_PAD[input.KeyCode] then presses += 1 end
	end)
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
	button.TextScaled = true -- a longer label (ROTATE) shrinks instead of spilling (QA r1); never above 18
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = 18
	textSize.Parent = button
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
		if t == U.Touch or t == U.MouseButton1 then
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
	buttons[name] = button
	return button
end

-- Four buttons wrapping the bottom-right corner (controls.md §2): JUMP the big one in the corner, DASH up and to
-- its left, GRAPPLE (ROTATE for a ghost holding a piece) above JUMP, ITEM above DASH and left of GRAPPLE (QA r1:
-- "left of DASH" reached the lower-middle on a 667 px phone, rule 23). The default thumbstick sits bottom-left.
-- GRAPPLE and ITEM are hidden while they would do nothing (Controls.buttons), so most of the time a phone shows two
-- or three.
local function buildTouchButtons(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RotagControls"
	gui.ResetOnSpawn = false
	gui.Enabled = UserInputService.TouchEnabled
	gui.Parent = playerGui
	touchButton(gui, "Jump", "JUMP", UDim2.new(1, -24, 1, -24), 96, onJump)
	touchButton(gui, "Dash", "DASH", UDim2.new(1, -136, 1, -72), 76, onDash)
	touchButton(gui, "Grapple", "GRAPPLE", UDim2.new(1, -34, 1, -136), 76, onGrapple).Visible = false
	local item = touchButton(gui, "Item", "ITEM", UDim2.new(1, -128, 1, -164), 76, onUse)
	item.Visible = false
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.7, 0.7)
	image.Visible = false
	image.Parent = item
	itemImage = image
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
		gui.Enabled = UserInputService.TouchEnabled
	end)
end

local ICON = { crate = "crate_0", trap = "trap_armed", ice = "ice_icon" } -- the held item on the ITEM button
local shown = { item = "", hook = "" }

-- Every frame from the client: which of the two optional buttons to show. `item`: the held item that Use can fire
-- (nil when the slot is empty or holds a hex, which is used by touch); `hook`: "grapple" for a living runner once
-- the grapple exists, "rotate" for a ghost holding a piece, nil otherwise. Cheap: nothing changes unless the
-- values do.
function Controls.buttons(item: string?, hook: string?)
	local itemKey, hookKey = item or "", hook or ""
	if itemKey ~= shown.item then
		shown.item = itemKey
		local b = buttons.Item
		if b then
			b.Visible = item ~= nil
			local name = item and ICON[item]
			local art = name ~= nil and Sprites.Has(name)
			if art and itemImage then Sprites.Apply(itemImage, name :: string) end
			if itemImage then
				itemImage.ResampleMode = Enum.ResamplerMode.Default -- vector art (client/Look)
				itemImage.Visible = art
			end
			b.Text = if art then "" else string.upper(item or "ITEM")
		end
	end
	if hookKey ~= shown.hook then
		shown.hook = hookKey
		local b = buttons.Grapple
		if b then
			b.Visible = hook ~= nil
			b.Text = if hook == "rotate" then "ROTATE" else "GRAPPLE"
		end
	end
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
		-- Expected in this Studio (no PlayerModule under PlayerScripts, movement.md §5): a note, not a warning (QA round 1).
		print("[Rotag] no PlayerModule controls; reading Humanoid.MoveDirection" .. (if result then ": " .. tostring(result) else ""))
	end
end

function Controls.start(player: Player)
	bindKeys()
	buildTouchButtons(player:WaitForChild("PlayerGui") :: PlayerGui)
	task.spawn(loadPlayerControls, player)
	-- Only a real device switches the audience: Focus, Gyro and the like (phones send them) leave it alone (QA r1).
	UserInputService.LastInputTypeChanged:Connect(function(t)
		local name = t.Name
		if t == U.Touch then device = "touch"
		elseif string.sub(name, 1, 7) == "Gamepad" then device = "pad"
		elseif t == U.Keyboard or string.sub(name, 1, 5) == "Mouse" then device = "keys" end
		usingTouch = device == "touch"
	end)
end

-- What the trap prompt tells this player to mash, by the device last used (controls.md §2, pry row). Never Shift.
function Controls.pryHint(): string
	if device == "touch" then return "tap anywhere" end
	if device == "pad" then return "mash A" end
	return if schemeB then "mash Z / click" else "mash Space / click"
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
		usePressed = usePressed, -- H19: client/Use reads these two and strips them before Movement sees the input
		presses = presses,
		grapplePressed = grapplePressed, -- PR 3: unread until the grapple PR (living) and PR 4 (a ghost's rotate)
		grappleHeld = grappleHeld,
	}
	jumpPressed, dashPressed, usePressed, presses, grapplePressed = false, false, false, 0, false
	return input
end

return Controls
