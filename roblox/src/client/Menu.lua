-- The menu (H31, docs/systems/ui.md §2): the title screen a player lands on, over the live map; PLAY puts them in
-- (Flow.play: the server gives them a body and a seat), and the same screen is one press away in play (the MENU pill,
-- or M / Start). Also the wallet pill (coins, level) and the how-to-play cards. The locker and the wheel are
-- client/Locker. Nothing here decides anything: every button is a request the server judges.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))
local Locker = require(script.Parent:WaitForChild("Locker"))

local Menu = {}

local C = Ui.C
local root: Frame = nil :: any
local title: Frame, how: Frame, pill: TextButton, wallet: Frame = nil :: any, nil :: any, nil :: any, nil :: any
local statusLabel: TextLabel, coinLabel: TextLabel, levelLabel: TextLabel, playButton: TextButton
	= nil :: any, nil :: any, nil :: any, nil :: any
local sitButton: TextButton, unsaved: TextLabel = nil :: any, nil :: any
local screen = "title" -- "title" | "how" | "locker" | "wheel" | "none"
local shownCoins = -1
local taught, playAfterHow = false, false

function Menu.open(): boolean return screen ~= "none" end

local function show(what: string)
	screen = what
	title.Visible = what == "title"
	how.Visible = what == "how"
	Locker.show(if what == "locker" or what == "wheel" then what else nil)
	pill.Visible = what == "none"
end

local function back()
	if playAfterHow then -- "GOT IT" on the first-time cards goes straight into the game
		playAfterHow = false
		Flow.play()
		show("none")
		return
	end
	show("none") -- H37: the game is always behind the menu now (the lobby): closing a screen goes back to it
end

-- H37: the LOCKER door, and "every screen out of the way" when a match is found.
function Menu.locker() show("locker") end
function Menu.close()
	playAfterHow = false
	if screen ~= "none" then show("none") end
end

-- PLAY (H37: asked by standing in QUICK MATCH, client/Lobby). A player who has never finished a match sees the
-- how-to cards first, once (rule 18: easy to start); GOT IT then queues them.
function Menu.play()
	local p = Flow.profile()
	if not taught and not Flow.playing() and (p == nil or p.matches == 0) then
		taught, playAfterHow = true, true
		show("how")
		return
	end
	Flow.play()
	show("none")
end

local function line(parent: Instance, text: string, y: number, size: number, color: Color3?, font: Font?): TextLabel
	local l = Ui.label(parent, text, size, color, font)
	l.Size, l.Position = UDim2.new(1, -40, 0, size + 8), UDim2.fromOffset(20, y)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

local function buildTitle()
	title = Ui.frame(root, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	local shade = Ui.frame(title, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.BackgroundTransparency, shade.BackgroundColor3 = 0, C.ink
	local g = Ui.gradient(shade, C.ink, C.ink, 0)
	-- Seen in Studio (2026-11-16): at 0.08 / 0.35 / 0.82 the live map behind the title was all but gone. Dark only
	-- where the words are; the right two thirds of the screen show the game.
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.55, 0.95), NumberSequenceKeypoint.new(1, 1) })
	-- Laid out top to bottom for the design space this screen has: 720 tall on a desktop, ~520 on a phone held
	-- sideways (Ui.compact; QA round 1: scaled down to fit, the text was 8 points).
	local cmp = Ui.compact()
	local logoSize, y = if cmp then 92 else 132, if cmp then 30 else 96
	local logo = Ui.label(title, "ROTAG", logoSize, Color3.new(1, 1, 1), Ui.HEAD)
	logo.Size, logo.Position, logo.TextXAlignment = UDim2.fromOffset(620, logoSize + 8), UDim2.fromOffset(60, y), Enum.TextXAlignment.Left
	Ui.gradient(logo, Color3.fromRGB(255, 255, 255), C.cyan, 90)
	Ui.outline(logo, 4)
	y += logoSize + (if cmp then 6 else 4)
	local bar = Ui.frame(title, UDim2.fromOffset(if cmp then 290 else 410, if cmp then 6 else 8), UDim2.fromOffset(66, y))
	bar.BackgroundTransparency, bar.BackgroundColor3 = 0, Color3.new(1, 1, 1)
	Ui.gradient(bar, C.ember, C.gold, 0)
	Ui.corner(bar, 4)
	y += if cmp then 12 else 18
	local tag = Ui.label(title, "PARKOUR TAG  ·  DON'T HOLD THE FUSE", if cmp then 18 else 22, C.text, Ui.BODY)
	tag.Size, tag.Position, tag.TextXAlignment = UDim2.fromOffset(620, 30), UDim2.fromOffset(66, y), Enum.TextXAlignment.Left
	Ui.outline(tag, 2)
	y += if cmp then 40 else 66
	local playH, h, gap = if cmp then 62 else 84, if cmp then 44 else 54, if cmp then 8 else 10
	playButton = Ui.button(title, "BACK TO THE GAME", "primary", UDim2.fromOffset(320, playH), UDim2.fromOffset(66, y), back)
	Ui.setText(playButton, nil, 26)
	y += playH + gap
	for _, def in { { "LOCKER", "plain", "locker" }, { "SPIN THE WHEEL", "gold", "wheel" }, { "HOW TO PLAY", "ghost", "how" } } do
		Ui.button(title, def[1], def[2], UDim2.fromOffset(320, h), UDim2.fromOffset(66, y), function() show(def[3]) end)
		y += h + gap
	end
	statusLabel = Ui.label(title, "", 18, C.dim, Ui.BODY)
	statusLabel.Size, statusLabel.Position = UDim2.fromOffset(620, 26), UDim2.fromOffset(66, y)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	Ui.outline(statusLabel, 2)
	y += 32
	sitButton = Ui.button(title, "SIT OUT AND WATCH", "ghost", UDim2.fromOffset(320, 40), UDim2.fromOffset(66, y), function()
		Flow.sit()
	end)
	Ui.setText(sitButton, nil, 16)
	sitButton.Visible = false
end

local function controlsText(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Stick: run   ·   JUMP: jump, double jump, wall jump   ·   DASH   ·   GRAPPLE: hold near a gold anchor   ·   ITEM"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Stick: run   ·   A: jump   ·   X: dash   ·   RT: grapple (hold)   ·   RB: use item"
	end
	return "A / D: run   ·   SPACE: jump, double jump, wall jump   ·   SHIFT: dash   ·   W: grapple (hold)   ·   E: use item"
end

local HOW = {
	{ "THE FUSE", C.ember, "One runner is IT and carries a burning fuse. Touch another runner to pass it on. Whoever holds it at zero burns out." },
	{ "RUN", C.cyan, "Run, jump, double jump, kick off walls, dash, swing from the gold anchors, hit the green pads. Moves chain: keep your speed." },
	{ "ORBS", C.gold, "Grab a glowing orb for an item: a crate, a bear trap or an ice beam. One at a time. Use it to slow whoever is after you." },
	{ "GHOSTS", C.ghost, "Burnt out? You are a ghost until the round ends. Grab ghost orbs, drop blocks and pads, and hex the holder to burn its fuse faster." },
	{ "THE MATCH", C.lime, ("%d rounds. Outlast the others to score. The last two get closing walls. Earn coins, spin the wheel, dress your runner.%s"):format(
		Config.MATCH_ROUNDS, if Config.BOT_LABEL then " Empty seats are filled by AI runners." else "") },
}

local function buildHow()
	how = Ui.frame(root, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	how.Visible = false
	local shade = Ui.frame(how, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.BackgroundTransparency, shade.BackgroundColor3 = 0.3, C.ink
	local cmp = Ui.compact()
	local step, rowH = if cmp then 66 else 78, if cmp then 60 else 70
	local p = Ui.panel(how, UDim2.fromOffset(math.min(900, Ui.width() - 24), if cmp then 480 else 560),
		UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 18)
	local head = line(p, "HOW TO PLAY", if cmp then 10 else 18, if cmp then 28 else 34, C.text, Ui.HEAD)
	head.TextColor3 = C.cyan
	for i, card in HOW do
		local row = Ui.frame(p, UDim2.new(1, -40, 0, rowH), UDim2.fromOffset(20, (if cmp then 54 else 72) + (i - 1) * step))
		row.BackgroundTransparency, row.BackgroundColor3 = 0.35, C.ink
		Ui.corner(row, 10)
		local stripe = Ui.frame(row, UDim2.new(0, 6, 1, -16), UDim2.fromOffset(8, 8))
		stripe.BackgroundTransparency, stripe.BackgroundColor3 = 0, card[2]
		Ui.corner(stripe, 3)
		local name = Ui.label(row, card[1], 20, card[2], Ui.HEAD)
		name.Size, name.Position, name.TextXAlignment = UDim2.new(0, 150, 1, 0), UDim2.fromOffset(24, 0), Enum.TextXAlignment.Left
		local body = Ui.label(row, card[3], 17, C.text, Ui.LIGHT)
		body.Size, body.Position = UDim2.new(1, -196, 1, -6), UDim2.fromOffset(180, 3)
		body.TextWrapped, body.TextXAlignment = true, Enum.TextXAlignment.Left
	end
	local keys = Ui.label(p, controlsText(), 16, C.gold, Ui.BODY)
	keys.Size, keys.Position, keys.TextWrapped = UDim2.new(1, -220, 0, 44), UDim2.new(0, 20, 1, -54), true
	keys.TextXAlignment = Enum.TextXAlignment.Left
	Ui.button(p, "GOT IT", "primary", UDim2.fromOffset(160, 44), UDim2.new(1, -20, 1, -10), back, Vector2.new(1, 1))
end

local function buildWallet(top: number)
	wallet = Ui.panel(root, UDim2.fromOffset(232, 40), UDim2.new(1, -12, 0, top), Vector2.new(1, 0), 20)
	Ui.coin(wallet, 24, UDim2.fromOffset(10, 8))
	coinLabel = Ui.label(wallet, "0", 20, C.gold, Ui.HEAD)
	coinLabel.Size, coinLabel.Position, coinLabel.TextXAlignment = UDim2.fromOffset(92, 40), UDim2.fromOffset(42, 0), Enum.TextXAlignment.Left
	levelLabel = Ui.label(wallet, "LVL 1", 16, C.cyan, Ui.HEAD)
	levelLabel.Size, levelLabel.Position, levelLabel.TextXAlignment = UDim2.fromOffset(84, 40), UDim2.new(1, -96, 0, 0), Enum.TextXAlignment.Right
	unsaved = Ui.label(root, "PROGRESS IS NOT SAVING RIGHT NOW", 14, C.ember, Ui.BODY)
	unsaved.Size, unsaved.Position, unsaved.AnchorPoint = UDim2.fromOffset(360, 20), UDim2.new(1, -14, 0, top + 44), Vector2.new(1, 0)
	unsaved.TextXAlignment, unsaved.Visible = Enum.TextXAlignment.Right, false
	Ui.outline(unsaved, 2)
	pill = Ui.button(root, "MENU", "ghost", UDim2.fromOffset(92, 36), UDim2.new(1, -252, 0, top + 2), function() show("title") end,
		Vector2.new(1, 0))
	Ui.setText(pill, nil, 16)
	pill.Visible = false
end

-- Every frame (cheap: text only when it changes).
function Menu.update()
	local p = Flow.profile()
	if p and p.coins ~= shownCoins then
		if shownCoins >= 0 and p.coins > shownCoins then Ui.pop(coinLabel) end
		shownCoins = p.coins
		coinLabel.Text = tostring(p.coins)
		levelLabel.Text = "LVL " .. tostring(p.level)
	end
	unsaved.Visible = p ~= nil and p.saved == false -- a DataStore outage: say so before a kid spends coins that vanish
	if screen ~= "title" then return end
	-- H37: the title is the pause menu now (the MENU pill, M): the game goes on behind it. Its one way OUT of
	-- whatever you are in is this button, for anyone who cannot find the door.
	local s = Flow.session()
	local phase = Flow.phase()
	local queued = Flow.playing() and phase == "lobby" and not (s and s.mode == "match")
	sitButton.Visible = Flow.playing()
	Ui.setText(sitButton, if queued then "LEAVE THE QUEUE" else "LEAVE THE MATCH")
	statusLabel.Text = if not s then "connecting..."
		elseif type(s.waiting) == "table" then ("Waiting for your group  ·  %d of %d here"):format(tonumber(s.waiting[1]) or 1, tonumber(s.waiting[2]) or 1)
		elseif queued then "You are in the queue  ·  the game goes on behind this menu"
		elseif Flow.playing() and phase ~= "podium" then ("You are in a match  ·  round %d of %d"):format(s.round, s.rounds)
		elseif phase == "podium" then "Match over"
		else "Stand in a door in the lobby to choose what to play"
end

function Menu.start(player: Player)
	local _, r = Ui.screen(player:WaitForChild("PlayerGui"), "RotagMenu", 20)
	root = r
	buildTitle()
	buildHow()
	buildWallet(Ui.topInset() + 6)
	Locker.start(root, back)
	show("none") -- H37: a player lands IN the lobby, not on a title screen
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonStart then
			if screen == "none" then show("title") else back() end
		elseif screen == "title" and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA) then
			back() -- Enter / A on the title is BACK TO THE GAME
		elseif screen == "how" and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA) then
			back() -- ... and GOT IT on the cards (QA round 3: only a click closed them)
		end
	end)
end

return Menu
