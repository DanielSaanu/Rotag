-- The room-code pad (H37, docs/systems/lobby.md §5): the one thing in the lobby that is typed, not walked to. It
-- opens when a runner stands in ENTER A CODE: four big boxes, a number pad (fingers), and the keyboard's digits,
-- Backspace, Enter and Escape. It only collects four digits and hands them over; the server decides if there is such
-- a room (client/Lobby shows its answer here with CodePad.status).
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lobby"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local CodePad = {}

local C = Ui.C
local PINK = Color3.fromRGB(255, 111, 181)
local panel: Frame = nil :: any
local boxes: { TextLabel } = {}
local statusLabel: TextLabel = nil :: any
local typed = ""
local onGo: ((string) -> ())? = nil

function CodePad.isOpen(): boolean return panel ~= nil and panel.Visible end

local function show()
	for i, b in boxes do
		b.Text = if #typed >= i then string.sub(typed, i, i) else ""
	end
end

-- What the server said, or what we are waiting for. A refusal clears the boxes for another try.
function CodePad.status(text: string, color: Color3?, clear: boolean?)
	if not statusLabel then return end
	statusLabel.Text, statusLabel.TextColor3 = text, color or C.text
	if clear then
		typed = ""
		show()
		for _, b in boxes do Ui.pop(b.Parent :: GuiObject, 1.15) end -- the boxes jump: that try is gone
	end
	Ui.pop(statusLabel, 1.4)
end

local function press(key: string)
	if not CodePad.isOpen() then return end
	if key == "del" then
		typed = string.sub(typed, 1, -2)
	elseif key == "go" then
		local code = Rules.code(typed)
		if code and onGo then
			onGo(code)
		else
			CodePad.status(("TYPE ALL %d NUMBERS"):format(Rules.CODE_LEN), C.gold)
		end
		return
	elseif #typed < Rules.CODE_LEN then
		typed ..= key
	end
	statusLabel.Text = ""
	show()
end

function CodePad.open(go: (string) -> ())
	if not panel then return end
	typed, onGo = "", go
	statusLabel.Text = ""
	show()
	panel.Visible = true
	Ui.pop(panel, 0.8)
end

function CodePad.close()
	if panel then panel.Visible = false end
end

local KEYS = { One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	Zero = "0", KeypadOne = "1", KeypadTwo = "2", KeypadThree = "3", KeypadFour = "4", KeypadFive = "5", KeypadSix = "6",
	KeypadSeven = "7", KeypadEight = "8", KeypadNine = "9", KeypadZero = "0", Backspace = "del", Return = "go",
	KeypadEnter = "go" }

function CodePad.start(player: Player)
	local _, root = Ui.screen(player:WaitForChild("PlayerGui"), "RotagCodePad", 28)
	local cmp = Ui.compact()
	local keyH, gap = 60, 8 -- 45 points tall at the smallest scale: a finger's (QA round 1: 50 was 37)
	local h = (if cmp then 160 else 194) + 4 * (keyH + gap) + 12
	panel = Ui.panel(root, UDim2.fromOffset(344, h), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 18)
	panel.Visible = false
	Ui.stroke(panel, PINK, 3, 0.1)
	local title = Ui.label(panel, "YOUR FRIEND'S ROOM CODE", 20, PINK, Ui.HEAD)
	title.Size, title.Position = UDim2.new(1, -70, 0, 30), UDim2.fromOffset(16, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local x = Ui.button(panel, "X", "ghost", UDim2.fromOffset(44, 44), UDim2.new(1, -8, 0, 6), CodePad.close, Vector2.new(1, 0))
	Ui.setText(x, nil, 20)
	local boxH = if cmp then 62 else 78
	for i = 1, Rules.CODE_LEN do
		local f = Ui.frame(panel, UDim2.fromOffset(68, boxH), UDim2.fromOffset(20 + (i - 1) * 78, 52))
		f.BackgroundTransparency, f.BackgroundColor3 = 0, C.ink
		Ui.corner(f, 10)
		Ui.stroke(f, PINK, 3, 0)
		boxes[i] = Ui.label(f, "", if cmp then 44 else 54, C.text, Ui.HEAD)
	end
	statusLabel = Ui.label(panel, "", 22, C.text, Ui.HEAD) -- big enough to be the answer (QA round 1: 17 px)
	statusLabel.Size, statusLabel.Position = UDim2.new(1, -16, 0, 32), UDim2.fromOffset(8, 56 + boxH)
	local y0 = 56 + boxH + 40
	local grid = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "go" }
	for i, key in grid do
		local col, row = (i - 1) % 3, (i - 1) // 3
		local b = Ui.button(panel, if key == "del" then "DEL" elseif key == "go" then "GO" else key,
			if key == "go" then "primary" else "plain", UDim2.fromOffset(96, keyH),
			UDim2.fromOffset(20 + col * 104, y0 + row * (keyH + gap)), function() press(key) end)
		Ui.setText(b, nil, if #key == 1 then 28 else 22)
	end
	UserInputService.InputBegan:Connect(function(input)
		if not CodePad.isOpen() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			CodePad.close()
			return
		end
		local key = KEYS[input.KeyCode.Name]
		if key then press(key) end
	end)
end

return CodePad
