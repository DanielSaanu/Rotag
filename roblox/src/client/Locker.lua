-- The locker and the wheel (H31, docs/systems/ui.md §3; DESIGN §6.5, rule 36: cosmetics only). The locker shows
-- every item of a slot as a card: wear what you own, buy what has a price, see what only the wheel gives. The wheel
-- costs coins a spin and lands on one cosmetic by the odds printed beside it; a duplicate pays some coins back.
-- Every press is a request (Flow.shop); the card and the purse only ever change when the server's answer arrives.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))

local Locker = {}

local C = Ui.C
local locker: Frame, wheel: Frame, grid: ScrollingFrame, note: TextLabel = nil :: any, nil :: any, nil :: any, nil :: any
local reel: TextLabel, reelSub: TextLabel, spinButton: TextButton, reelBox: Frame = nil :: any, nil :: any, nil :: any, nil :: any
local tabs: { [string]: TextButton } = {}
local slot = Catalog.SLOTS[1]
local spinning = false -- from the SPIN press until its reel has landed (or the server said no): one spin at a time
local spinAt = -math.huge
local cols = 4 -- the locker grid's columns: as many 208-pixel cards as its panel is wide
Locker.onSpin = nil :: ((string, boolean) -> ())? -- client/Audio: "tick" | a rarity on landing, and whether it is new

local function swatch(parent: Instance, it: Catalog.Item, size: UDim2, pos: UDim2)
	local f = Ui.frame(parent, size, pos)
	f.BackgroundTransparency, f.BackgroundColor3 = 0, Color3.new(1, 1, 1)
	Ui.corner(f, 8)
	if #it.colors == 0 then
		f.BackgroundColor3 = C.ink
		local l = Ui.label(f, "NONE", 14, C.dim, Ui.BODY)
		l.Size = UDim2.fromScale(1, 1)
	else
		local keys = {}
		for i, c in it.colors do
			table.insert(keys, ColorSequenceKeypoint.new(if #it.colors == 1 then 0 else (i - 1) / (#it.colors - 1), Ui.rgb(c)))
		end
		if #keys == 1 then table.insert(keys, ColorSequenceKeypoint.new(1, Ui.rgb(it.colors[1]))) end
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(keys)
		g.Parent = f
		if it.slot == "title" then
			f.BackgroundColor3 = C.ink
			g:Destroy()
			local l = Ui.label(f, string.upper(it.name), 16, Ui.rgb(it.colors[1]), Ui.HEAD)
			l.Size = UDim2.fromScale(1, 1)
		end
	end
end

local function fill()
	for _, ch in grid:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local p = Flow.profile()
	local owned, worn = {}, {}
	if p then
		for _, id in p.owned do owned[id] = true end
		for _, id in p.worn do worn[id] = true end
	end
	for name, tab in tabs do tab.BackgroundTransparency = if name == slot then 0 else 0.55 end
	for i, it in Catalog.inSlot(slot) do
		local card = Ui.panel(grid, UDim2.fromOffset(196, 168), UDim2.fromOffset(((i - 1) % cols) * 208, ((i - 1) // cols) * 180), nil, 12)
		local rarity = Ui.rgb(Catalog.RARITY_COLORS[it.rarity])
		local st = card:FindFirstChildOfClass("UIStroke")
		if st then st.Color, st.Transparency = rarity, if worn[it.id] then 0 else 0.45 end
		swatch(card, it, UDim2.new(1, -20, 0, 54), UDim2.fromOffset(10, 10))
		local name = Ui.label(card, it.name, 17, C.text, Ui.HEAD)
		name.Size, name.Position = UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 68)
		local rare = Ui.label(card, string.upper(it.rarity), 14, rarity, Ui.BODY)
		rare.Size, rare.Position = UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 92)
		local text, kind, op = "WHEEL ONLY", "ghost", nil
		if worn[it.id] then text, kind = "WEARING", "ghost"
		elseif owned[it.id] then text, kind, op = "WEAR", "primary", "equip"
		elseif it.price then
			-- a price you cannot pay yet is quiet, not gold (QA round 3): it still says what to save for
			local can = p ~= nil and p.coins >= it.price
			text, kind, op = ("BUY  %d"):format(it.price), if can then "gold" else "ghost", if can then "buy" else nil
		end
		local b = Ui.button(card, text, kind, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -48), function()
			if op then Flow.shop(op, it.id) end
		end)
		Ui.setText(b, nil, 16)
		b.Active = op ~= nil
	end
	grid.CanvasSize = UDim2.fromOffset(0, ((#Catalog.inSlot(slot) - 1) // cols + 1) * 180)
end

local function oddsText(): string
	local parts = {}
	for _, r in Catalog.RARITIES do table.insert(parts, ("%s %d%%"):format(r, Catalog.ODDS[r])) end
	return "Odds:  " .. table.concat(parts, "  ·  ")
end

-- The reel: names flick past, slowing, then the one the SERVER rolled lands (the result was decided before the
-- first flick; the animation only shows it).
local function land(id: string, back: number)
	local it = Catalog.get(id)
	if not it then return end
	spinning = true
	task.spawn(function()
		local pool = Catalog.ITEMS
		local gap = 0.05
		for _ = 1, 22 do
			local show = pool[math.random(1, #pool)]
			if show.price ~= 0 then
				reel.Text, reel.TextColor3 = show.name, Ui.rgb(Catalog.RARITY_COLORS[show.rarity])
				reelSub.Text = ""
				if Locker.onSpin then Locker.onSpin("tick", false) end
			end
			task.wait(gap)
			gap *= 1.09
		end
		local color = Ui.rgb(Catalog.RARITY_COLORS[it.rarity])
		reel.Text, reel.TextColor3 = it.name, color
		reelSub.Text = if back > 0 then ("%s %s  ·  already yours: +%d coins back"):format(string.upper(it.rarity),
			Catalog.SLOT_NAMES[it.slot], back) else ("NEW %s %s!  ·  it is in your locker"):format(string.upper(it.rarity),
			Catalog.SLOT_NAMES[it.slot])
		reelSub.TextColor3 = color
		local st = reelBox:FindFirstChildOfClass("UIStroke")
		if st then st.Color = color end
		Ui.pop(reel, 1.6)
		if Locker.onSpin then Locker.onSpin(it.rarity, back == 0) end
		spinning = false
	end)
end

local function buildLocker(root: Frame, back: () -> ())
	locker = Ui.frame(root, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	locker.Visible = false
	local shade = Ui.frame(locker, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.BackgroundTransparency, shade.BackgroundColor3 = 0.3, C.ink
	local w = math.min(880, Ui.width() - 16)
	cols = math.max(2, (w - 44) // 208)
	local p = Ui.panel(locker, UDim2.fromOffset(w, math.min(560, Ui.height() - 24)), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 18)
	local head = Ui.label(p, "LOCKER", 34, C.cyan, Ui.HEAD)
	head.Size, head.Position, head.TextXAlignment = UDim2.fromOffset(240, 48), UDim2.fromOffset(24, 12), Enum.TextXAlignment.Left
	for i, name in Catalog.SLOTS do
		local tab = Ui.button(p, string.upper(Catalog.SLOT_NAMES[name]), "plain", UDim2.fromOffset(136, 40),
			UDim2.fromOffset(190 + (i - 1) * 146, 18), function()
				slot = name
				fill()
			end)
		Ui.setText(tab, nil, 16)
		tabs[name] = tab
	end
	Ui.button(p, "X", "ghost", UDim2.fromOffset(44, 40), UDim2.new(1, -16, 0, 18), back, Vector2.new(1, 0))
	grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency, grid.BorderSizePixel = 1, 0
	grid.Size, grid.Position = UDim2.new(1, -44, 1, -132), UDim2.fromOffset(24, 76)
	grid.ScrollBarThickness, grid.ScrollBarImageColor3 = 6, C.edge
	grid.Parent = p
	note = Ui.label(p, "Cosmetics only: nothing here makes you faster.", 15, C.dim, Ui.LIGHT)
	note.Size, note.Position, note.TextXAlignment = UDim2.new(1, -48, 0, 30), UDim2.new(0, 24, 1, -44), Enum.TextXAlignment.Left
end

local function buildWheel(root: Frame, back: () -> ())
	wheel = Ui.frame(root, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	wheel.Visible = false
	local shade = Ui.frame(wheel, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	shade.BackgroundTransparency, shade.BackgroundColor3 = 0.3, C.ink
	local p = Ui.panel(wheel, UDim2.fromOffset(620, 420), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 18)
	local head = Ui.label(p, "THE WHEEL", 34, C.gold, Ui.HEAD)
	head.Size, head.Position, head.TextXAlignment = UDim2.fromOffset(400, 48), UDim2.fromOffset(24, 12), Enum.TextXAlignment.Left
	Ui.button(p, "X", "ghost", UDim2.fromOffset(44, 40), UDim2.new(1, -16, 0, 18), back, Vector2.new(1, 0))
	reelBox = Ui.panel(p, UDim2.new(1, -48, 0, 150), UDim2.fromOffset(24, 76), nil, 14)
	reel = Ui.label(reelBox, "?  ?  ?", 46, C.text, Ui.HEAD)
	reel.Size, reel.Position = UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 16)
	reelSub = Ui.label(reelBox, "Trails, glows, burn-outs and titles", 16, C.dim, Ui.BODY)
	reelSub.Size, reelSub.Position = UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 106)
	spinButton = Ui.button(p, ("SPIN  ·  %d"):format(Config.SPIN_COST), "gold", UDim2.fromOffset(300, 70),
		UDim2.new(0.5, 0, 0, 250), function()
			if spinning and os.clock() - spinAt < 6 then return end
			local pr = Flow.profile()
			if pr and pr.coins < Config.SPIN_COST then
				reelSub.Text, reelSub.TextColor3 = ("Not enough coins: a spin is %d. Play a match to earn more."):format(Config.SPIN_COST), C.ember
				return
			end
			spinning, spinAt = true, os.clock() -- QA round 1: two taps sent two spins and the reels overlapped
			Flow.shop("spin")
		end, Vector2.new(0.5, 0))
	Ui.setText(spinButton, nil, 30)
	if Config.ABILITY_ROLLS and #Catalog.ABILITIES > 0 then -- H35: off and empty for now (shared/Config, Catalog)
		spinButton.Position = UDim2.new(0.5, -160, 0, 250)
		local roll = Ui.button(p, ("ABILITY ROLL  ·  %d"):format(Config.ABILITY_ROLL_COST), "primary", UDim2.fromOffset(300, 70),
			UDim2.new(0.5, 160, 0, 250), function()
				if spinning and os.clock() - spinAt < 6 then return end
				Flow.shop("roll")
			end, Vector2.new(0.5, 0))
		Ui.setText(roll, nil, 22)
		p.Size = UDim2.fromOffset(700, 420)
	end
	local odds = Ui.label(p, oddsText(), 15, C.dim, Ui.LIGHT)
	odds.Size, odds.Position = UDim2.new(1, -48, 0, 22), UDim2.new(0, 24, 1, -70)
	local fine = Ui.label(p, "Cosmetics only. Coins come from playing. A duplicate pays coins back.", 15, C.dim, Ui.LIGHT)
	fine.Size, fine.Position = UDim2.new(1, -48, 0, 22), UDim2.new(0, 24, 1, -46)
end

-- "locker" | "wheel" | nil (both hidden).
function Locker.show(what: string?)
	locker.Visible = what == "locker"
	wheel.Visible = what == "wheel"
	if what == "locker" then fill() end
end

function Locker.start(root: Frame, back: () -> ())
	buildLocker(root, back)
	buildWheel(root, back)
	Flow.onProfile(function(p)
		if locker.Visible then fill() end
		spinButton.BackgroundTransparency = if p.coins >= Config.SPIN_COST then 0 else 0.55
		if type(p.spin) == "table" and type(p.spin.id) == "string" then land(p.spin.id, tonumber(p.spin.back) or 0) end
		if type(p.roll) == "table" then -- H35: an ability roll landed: say what it unlocked
			local a = Catalog.ability(p.roll.id)
			if a then
				reel.Text, reel.TextColor3 = a.name, Ui.rgb(Catalog.RARITY_COLORS[a.rarity])
				reelSub.Text, reelSub.TextColor3 = "NEW ABILITY  ·  " .. a.about, Ui.rgb(Catalog.RARITY_COLORS[a.rarity])
				Ui.pop(reel, 1.6)
				if Locker.onSpin then Locker.onSpin(a.rarity, true) end
			end
		end
		if type(p.note) == "string" and wheel.Visible and type(p.spin) ~= "table" then -- the spin was refused
			spinning = false
			reelSub.Text, reelSub.TextColor3 = "Could not spin: " .. p.note, C.ember
		end
		if type(p.note) == "string" and locker.Visible then
			note.Text = if p.note == "bought" then "Bought and on. Cosmetics only: nothing here makes you faster." else ("Could not do that: " .. p.note)
		end
	end)
end

return Locker
