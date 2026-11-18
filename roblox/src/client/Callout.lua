-- The callouts (H37, docs/systems/lobby.md §7): the big words that say what is happening and what to do, so nobody
-- has to guess. Stacked down the top-middle of the screen (never the lower middle, rule 23; never over the doors'
-- signs), over every other screen (the locker included: a queued player dressing its runner still sees its queue):
--   the PILL     what you are in right now, for as long as you are in it ("IN THE QUEUE 2 / 4"), with a line under
--                it for what happens next and a quieter one for how to get out;
--   the CAPTION  the door you are at: its name and one line about it;
--   the BIG line something just happened ("YOU'RE IN THE QUEUE!", "YOU LEFT THE QUEUE", "MATCH FOUND!"): it pops,
--                stays a few seconds and fades; a held one stays until released;
--   the COUNT    a giant 3-2-1 when a match is about to start (in the big line's place);
--   the FILL     in the world, not on the glass: the doorway you stand in fills with light, bottom to top, until the
--                door is chosen. The bar is the door itself, where the player is already looking.
-- Drawing only: client/Lobby decides what each says.
local Ui = require(script.Parent:WaitForChild("Ui"))

local Callout = {}

local C = Ui.C
local pill: Frame, pillText: TextLabel, pillSub: TextLabel, pillHint: TextLabel, pillStroke: UIStroke
	= nil :: any, nil :: any, nil :: any, nil :: any, nil :: any
local big: TextLabel, sub: TextLabel, count: TextLabel, countLabel: TextLabel = nil :: any, nil :: any, nil :: any, nil :: any
local caption: TextLabel = nil :: any
local fill: Part? = nil
local bigUntil, bigHeld = 0, false
local shownCount: number? = nil
local pillKey, bigKey = "", ""
local wantHint, wantCaption, captionStrong = false, false, false
local captionSize = 21
local low = false -- docked at the bottom, one line: a menu is open over the game (Callout.dock)
local topY, pillH = 0, 46
local FILL_Z = -3.27 -- between a doorway's dark back and its frame (server/LobbyMap), behind the runners

-- What you are in: `text` nil hides it. `hint`: the quiet third line (how to leave).
function Callout.pill(text: string?, color: Color3?, line: string?, hint: string?)
	if not pill then return end
	pill.Visible = text ~= nil
	pillSub.Visible = text ~= nil and line ~= nil and not low
	wantHint = text ~= nil and hint ~= nil
	if not text then
		pillKey = ""
		return
	end
	local c = color or C.text
	pillText.Text, pillText.TextColor3, pillStroke.Color = text, c, c
	pillSub.Text, pillHint.Text = line or "", hint or ""
	if text ~= pillKey then -- it changed: a pop, so the eye goes to it
		pillKey = text
		Ui.pop(pill, 1.18)
	end
	-- A slow beat on the edge: alive, not flashing.
	pillStroke.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 4))
end

-- A menu is open over the game (the locker, the how-to cards): the pill alone moves to the bottom edge, out of the
-- menu's way, so "IN THE QUEUE" is still on screen while a runner is being dressed.
function Callout.dock(down: boolean)
	if not pill or down == low then return end
	low = down
	pill.AnchorPoint = Vector2.new(0.5, if down then 1 else 0)
	pill.Position = if down then UDim2.new(0.5, 0, 1, -8) else UDim2.new(0.5, 0, 0, topY)
end

-- Something happened: pops, stays `seconds` (default 3.2), fades.
function Callout.big(text: string, line: string?, color: Color3?, seconds: number?)
	if not big then return end
	big.Text, big.TextColor3, sub.Text = text, color or C.text, line or ""
	big.TextTransparency, sub.TextTransparency = 0, 0
	bigUntil, bigHeld, bigKey = os.clock() + (seconds or 3.2), false, text
	Ui.pop(big, 1.5)
end

-- The same, but it stays until Callout.release (being taken to a match: nothing else matters until it happens).
function Callout.hold(text: string, line: string?, color: Color3?)
	if not big then return end
	if bigHeld and bigKey == text then
		sub.Text = line or ""
		return
	end
	Callout.big(text, line, color)
	bigHeld = true
end
function Callout.release()
	if bigHeld then bigHeld, bigUntil = false, os.clock() end
end

-- The 3-2-1: `n` nil hides it. Returns true on the frame the number changes (the caller ticks).
function Callout.count(n: number?, label: string?): boolean
	if not count then return false end
	count.Visible, countLabel.Visible = n ~= nil, n ~= nil
	if n == shownCount then return false end
	shownCount = n
	if n then
		count.Text, countLabel.Text = tostring(n), label or ""
		Ui.pop(count, 1.7)
	end
	return n ~= nil
end

-- The door you are at: its name in its colour, then a line about it. `title` nil hides it. `strong`: you are IN it
-- and its doorway is filling: bigger, and not hidden by a big line (it is the thing happening now).
function Callout.caption(title: string?, color: Color3?, line: string?, strong: boolean?)
	if not caption then return end
	wantCaption, captionStrong = title ~= nil, strong == true
	if not title then return end
	caption.TextSize = if strong then captionSize * 1.35 else captionSize
	local c = color or C.text
	caption.Text = ('<font color="#%s">%s</font>%s'):format(c:ToHex(), title, if line then "   " .. line else "")
end

-- The doorway (world studs: x0, y0, x1, y1) filling with light to `frac` (0..1) in `color`; nil hides it.
function Callout.fill(x0: number?, y0: number?, x1: number?, y1: number?, frac: number?, color: Color3?)
	if not (x0 and y0 and x1 and y1 and frac and frac > 0) then
		if fill then fill.Parent = nil end
		return
	end
	local p = fill
	if not p then
		p = Instance.new("Part")
		p.Name = "RotagDoorFill"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material, p.Transparency = Enum.Material.Neon, 0.6 -- (0.35: the runner vanished in a white door's light)
		fill = p
	end
	local h = math.max(0.05, (y1 - y0) * math.clamp(frac, 0, 1))
	p.Size = Vector3.new(x1 - x0, h, 0.05)
	p.CFrame = CFrame.new((x0 + x1) / 2, y0 + h / 2, FILL_Z)
	p.Color = color or C.text
	if p.Parent ~= workspace then p.Parent = workspace end
end

-- Every frame: the big line's fade.
function Callout.update()
	if not big then return end
	if not bigHeld then
		local t = math.clamp((os.clock() - bigUntil) / 0.5, 0, 1)
		big.TextTransparency, sub.TextTransparency = t, t
		local s = big:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = 0.15 + 0.85 * t end
		local s2 = sub:FindFirstChildOfClass("UIStroke")
		if s2 then s2.Transparency = 0.15 + 0.85 * t end
	end
	-- the count takes the big line's place while it runs
	big.Visible, sub.Visible = shownCount == nil and not low, shownCount == nil and not low
	-- One thing at a time (seen in Studio: six lines at once the moment a runner queued): while the big line or the
	-- count is up, the quiet lines wait.
	local loud = bigHeld or os.clock() < bigUntil or shownCount ~= nil
	pillHint.Visible = wantHint and not loud and not low
	caption.Visible = wantCaption and (captionStrong or not loud) and not low
end

local function line(root: Frame, y: number, size: number, color: Color3, font: Font, h: number?): TextLabel
	local l = Ui.label(root, "", size, color, font)
	l.Size, l.Position, l.AnchorPoint = UDim2.new(1, -24, 0, h or size + 10), UDim2.new(0.5, 0, 0, y), Vector2.new(0.5, 0)
	Ui.outline(l, math.max(2, size / 14))
	return l
end

function Callout.start(player: Player)
	local _, root = Ui.screen(player:WaitForChild("PlayerGui"), "RotagCallout", 30)
	local cmp = Ui.compact()
	local top = Ui.topInset() + 6
	topY, pillH = top, if cmp then 40 else 46
	pill = Ui.panel(root, UDim2.fromOffset(if cmp then 380 else 440, pillH), UDim2.new(0.5, 0, 0, top), Vector2.new(0.5, 0), 23)
	pillStroke = Ui.stroke(pill, C.text, 3, 0.2)
	pillText = Ui.label(pill, "", if cmp then 21 else 25, C.text, Ui.HEAD)
	local y = top + (if cmp then 44 else 52)
	pillSub = line(root, y, if cmp then 18 else 21, C.text, Ui.BODY)
	y += if cmp then 24 else 28
	pillHint = line(root, y, if cmp then 15 else 16, C.dim, Ui.BODY)
	y += if cmp then 24 else 30
	captionSize = if cmp then 18 else 21
	caption = line(root, y, captionSize, C.text, Ui.BODY, captionSize * 1.35 + 10)
	caption.RichText = true
	y += if cmp then 28 else 36
	big = line(root, y, if cmp then 44 else 58, C.text, Ui.HEAD)
	big.TextTransparency = 1
	countLabel = line(root, y, if cmp then 20 else 24, C.text, Ui.HEAD)
	count = line(root, y + (if cmp then 20 else 24), if cmp then 84 else 110, C.gold, Ui.HEAD, if cmp then 88 else 114)
	count.Visible, countLabel.Visible = false, false
	y += if cmp then 52 else 68
	sub = line(root, y, if cmp then 19 else 23, C.text, Ui.BODY)
	sub.TextTransparency = 1
	Callout.pill(nil)
	Callout.caption(nil)
end

return Callout
