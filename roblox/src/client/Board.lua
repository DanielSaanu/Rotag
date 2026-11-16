-- The scoreboard and the match's cards (H31, docs/systems/ui.md §4; DESIGN §3 rules 33-34): the strip of runners and
-- their points in the top-left corner, the lobby countdown, "ROUND n" as a round begins, the results card in the gap
-- after each round, and the podium with the winner and what you earned. Drawn from the server's Session and
-- MatchState only (client/Flow, client/Tagging); nothing here decides anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SessionRules = require(Shared:WaitForChild("Session"))
local SEATS = require(Shared:WaitForChild("Config")).PLAYERS_PER_MATCH
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))

local Board = {}

local C = Ui.C
local ROW = 24
local INTRO = 2.2 -- seconds "ROUND n" stays up as a round begins
local root: Frame = nil :: any
local strip: Frame, stripHead: TextLabel = nil :: any, nil :: any
local rows: { { frame: Frame, dot: Frame, name: TextLabel, pts: TextLabel } } = {}
local big: TextLabel, sub: TextLabel = nil :: any, nil :: any
local card: Frame, cardHead: TextLabel, cardFoot: TextLabel = nil :: any, nil :: any, nil :: any
local cardRows: { { place: TextLabel, name: TextLabel, pts: TextLabel } } = {}
local me = 0
local introAt, introRound = -math.huge, 0
local cardKey = ""
local toastBig: TextLabel, toastSub: TextLabel = nil :: any, nil :: any
local TOAST = 2.2
local toastAt = -math.huge
local earned: number? = nil
local levelled: number? = nil -- the level a match's coins just reached (the podium says so)
Board.onCard = nil :: ((string, boolean) -> ())? -- client/Audio and Fx: "round" | "podium" came up, and did I win it

local function text(parent: Instance, size: number, color: Color3, font: Font, x: number, w: number, align: Enum.TextXAlignment)
	local l = Ui.label(parent, "", size, color, font)
	l.Size, l.Position, l.TextXAlignment = UDim2.new(0, w, 1, 0), UDim2.fromOffset(x, 0), align
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

local topY = 0
local function build(top: number)
	topY = top
	strip = Ui.panel(root, UDim2.fromOffset(214, 34 + 4 * ROW), UDim2.fromOffset(12, top), nil, 12)
	stripHead = Ui.label(strip, "", 15, C.dim, Ui.HEAD)
	stripHead.Size, stripHead.Position, stripHead.TextXAlignment = UDim2.new(1, -20, 0, 26), UDim2.fromOffset(12, 2), Enum.TextXAlignment.Left
	for i = 1, 4 do
		local f = Ui.frame(strip, UDim2.new(1, -12, 0, ROW), UDim2.fromOffset(6, 26 + (i - 1) * ROW))
		local dot = Ui.frame(f, UDim2.fromOffset(8, 8), UDim2.fromOffset(6, ROW / 2 - 4))
		dot.BackgroundTransparency = 0
		Ui.corner(dot, 4)
		rows[i] = { frame = f, dot = dot, name = text(f, 16, C.text, Ui.BODY, 20, 138, Enum.TextXAlignment.Left),
			pts = text(f, 16, C.gold, Ui.HEAD, 158, 40, Enum.TextXAlignment.Right) }
	end
	big = Ui.label(root, "", 54, C.text, Ui.HEAD)
	big.Size, big.Position, big.AnchorPoint = UDim2.fromOffset(900, 70), UDim2.new(0.5, 0, 0, top + 92), Vector2.new(0.5, 0)
	Ui.outline(big, 4)
	sub = Ui.label(root, "", 22, C.gold, Ui.BODY)
	sub.Size, sub.Position, sub.AnchorPoint = UDim2.fromOffset(900, 30), UDim2.new(0.5, 0, 0, top + 162), Vector2.new(0.5, 0)
	Ui.outline(sub, 2.5)
	-- The pickup banner: under the round's intro line, over the play; gone in two seconds.
	toastBig = Ui.label(root, "", 38, C.text, Ui.HEAD)
	toastBig.Size, toastBig.Position, toastBig.AnchorPoint = UDim2.fromOffset(900, 46), UDim2.new(0.5, 0, 0, top + 176), Vector2.new(0.5, 0)
	Ui.outline(toastBig, 3.5)
	toastSub = Ui.label(root, "", 18, C.text, Ui.BODY)
	toastSub.Size, toastSub.Position, toastSub.AnchorPoint = UDim2.fromOffset(900, 26), UDim2.new(0.5, 0, 0, top + 222), Vector2.new(0.5, 0)
	Ui.outline(toastSub, 2.5)
	toastBig.Visible, toastSub.Visible = false, false
	card = Ui.panel(root, UDim2.fromOffset(440, 260), UDim2.new(0.5, 0, 0, top + 78), Vector2.new(0.5, 0), 16)
	card.Visible = false
	cardHead = Ui.label(card, "", 30, C.cyan, Ui.HEAD)
	cardHead.Size, cardHead.Position = UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 10)
	for i = 1, 4 do
		local f = Ui.frame(card, UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 58 + (i - 1) * 36))
		f.BackgroundTransparency, f.BackgroundColor3 = 0.4, C.ink
		Ui.corner(f, 8)
		cardRows[i] = { place = text(f, 20, C.gold, Ui.HEAD, 10, 34, Enum.TextXAlignment.Left),
			name = text(f, 18, C.text, Ui.BODY, 48, 250, Enum.TextXAlignment.Left),
			pts = text(f, 20, C.gold, Ui.HEAD, 300, 90, Enum.TextXAlignment.Right) }
	end
	cardFoot = Ui.label(card, "", 17, C.dim, Ui.BODY)
	cardFoot.Size, cardFoot.Position = UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -40)
end

local function fillCard(s: any, podium: boolean)
	local ids, n = {}, 0
	if podium then
		for _, row in s.scores do table.insert(ids, row.id) end
	else
		ids = s.last
	end
	n = #ids
	cardHead.Text = if podium then (if s.winner == me then "YOU WIN THE MATCH!" else (Flow.nameOf(s.winner) .. " WINS!"))
		else ("ROUND %d OF %d"):format(s.round, s.rounds)
	cardHead.TextColor3 = if podium then C.gold else C.cyan
	for i, r in cardRows do
		local id = ids[i]
		r.place.Parent.Visible = id ~= nil
		if id then
			local total = 0
			for _, row in s.scores do if row.id == id then total = row.pts end end
			r.place.Text = tostring(i)
			r.name.Text = Flow.listName(id)
			r.name.TextColor3 = if id == me then C.cyan else C.text
			-- what the SERVER scored for the place (a round nobody won pays no win bonus); an older server: the rule
			local gained = if type(s.lastPts) == "table" and type(s.lastPts[i]) == "number" then s.lastPts[i]
				else SessionRules.points(i, n)
			r.pts.Text = if podium then tostring(total) else ("+%d"):format(gained)
		end
	end
	card.Size = UDim2.fromOffset(440, 58 + math.max(1, n) * 36 + 50)
end

-- A banner for the local player alone (a pickup): `text` big in `color`, `detail` under it, for TOAST seconds.
function Board.toast(text: string, detail: string, color: Color3)
	if not toastBig then return end
	toastBig.Text, toastBig.TextColor3, toastSub.Text = text, color, detail
	toastAt = os.clock()
	Ui.pop(toastBig, 1.5)
end

-- Every frame. `hidden`: a menu screen is up (the cards step aside; the strip stays).
function Board.update(match: any, hidden: boolean)
	local now = os.clock()
	local fade = math.clamp((now - toastAt - TOAST + 0.35) / 0.35, 0, 1)
	toastBig.TextTransparency, toastSub.TextTransparency = fade, fade
	toastBig.Visible, toastSub.Visible = fade < 1 and not hidden, fade < 1 and not hidden
	local s = Flow.session()
	if not s then
		strip.Visible, big.Text, sub.Text, card.Visible = false, "", "", false
		return
	end
	local phase, left = s.phase, Flow.left()
	-- The strip: this match's standings; before any round, the roster.
	local ids = {}
	for _, row in s.scores do table.insert(ids, row.id) end
	for _, id in s.roster do if not table.find(ids, id) then table.insert(ids, id) end end
	strip.Visible = phase ~= "lobby" and #ids > 0
	if strip.Visible then
		stripHead.Text = if phase == "podium" then "FINAL" else ("ROUND %d / %d"):format(s.round, s.rounds)
		for i, r in rows do
			local id = ids[i]
			r.frame.Visible = id ~= nil
			if id then
				local pts = 0
				for _, row in s.scores do if row.id == id then pts = row.pts end end
				local inRound = match and not match.over
				local alive = inRound and table.find(match.alive, id) ~= nil
				local isIt = inRound and match.it == id
				r.name.Text = Flow.listName(id)
				r.name.TextColor3 = if id == me then C.cyan elseif inRound and not alive then C.dim else C.text
				r.name.TextTransparency = if inRound and not alive then 0.35 else 0
				r.dot.BackgroundColor3 = if isIt then C.ember elseif inRound and not alive then C.ghost else C.lime
				r.dot.BackgroundTransparency = if inRound then 0 else 0.6
				r.pts.Text = tostring(pts)
			end
		end
		strip.Size = UDim2.fromOffset(214, 34 + math.min(4, #ids) * ROW)
	end
	-- "ROUND n" as it begins.
	if phase == "round" and match and not match.over and introRound ~= s.round * 1000 + s.match then
		introRound, introAt = s.round * 1000 + s.match, now
	end
	local key = ""
	big.Text, sub.Text = "", ""
	if hidden then
		key = "hidden"
	elseif phase == "lobby" then
		big.TextSize, big.Position = 54, UDim2.new(0.5, 0, 0, topY + 92)
		if type(s.waiting) == "table" then -- a match server holding its lobby until the group has arrived
			big.Text, big.TextColor3 = "WAITING FOR YOUR GROUP", C.text
			sub.Text = ("%d of %d here  ·  warm up!"):format(tonumber(s.waiting[1]) or 1, tonumber(s.waiting[2]) or 1)
		elseif s.mode == "hub" then -- H34: a queue for a match server, not a countdown to a round here
			if type(s.launching) == "table" and table.find(s.launching, me) then
				big.Text, big.TextColor3, sub.Text = "MATCH FOUND!", C.gold, "taking you there..."
			elseif Flow.playing() then
				big.Text, big.TextColor3 = "FINDING A MATCH", C.text
				sub.Text = ("%d / %d runners%s  ·  warm up!"):format(tonumber(s.queued) or 1, SEATS,
					if left then ("  ·  starting in %d"):format(math.ceil(left)) else "")
			end
		elseif left then
			big.Text = if left > 3.5 then "GET READY" else tostring(math.max(1, math.ceil(left)))
			big.TextColor3 = if left > 3.5 then C.text else C.gold
			sub.Text = if left > 3.5 then ("match starts in %d  ·  warm up!"):format(math.ceil(left)) else ""
		end
	elseif phase == "round" and now - introAt < INTRO then
		-- Just the round's name: the HUD under it already says who is it and counts the holder down (QA round 1: the
		-- two overlapped on a small screen and said the same thing twice).
		big.Text = if s.round == s.rounds then "FINAL ROUND" else ("ROUND %d"):format(s.round)
		big.TextColor3, big.TextSize = C.cyan, 46
		big.Position = UDim2.new(0.5, 0, 0, topY + 122) -- under the HUD's status lines, over the holder's count
		big.TextTransparency = math.clamp((now - introAt - INTRO + 0.4) / 0.4, 0, 1)
	elseif phase == "gap" then
		key = "gap" .. tostring(s.match) .. "." .. tostring(s.round)
		cardFoot.Text = if left then (if s.round < s.rounds then ("next round in %d"):format(math.ceil(left)) else "the podium is next") else ""
	elseif phase == "podium" then
		key = "podium" .. tostring(s.match)
		cardFoot.Text = (if earned then ("+%d coins   ·   "):format(earned) else "")
			.. (if levelled then ("LEVEL %d!   ·   "):format(levelled) else "")
			.. (if left then ("next match in %d"):format(math.ceil(left)) else "")
		cardFoot.TextColor3 = C.gold
	end
	if big.Text ~= "" and phase ~= "round" then big.TextTransparency, sub.TextTransparency = 0, 0 end
	local show = string.sub(key, 1, 3) == "gap" or string.sub(key, 1, 6) == "podium"
	if key ~= cardKey then
		cardKey = key
		if show then
			local podium = phase == "podium"
			if not podium then
				earned, levelled = nil, nil
				cardFoot.TextColor3 = C.dim
			end
			fillCard(s, podium)
			Ui.pop(card, 0.7)
			if Board.onCard then Board.onCard(if podium then "podium" else "round", (if podium then s.winner else s.last[1]) == me) end
		end
	end
	card.Visible = show
end

function Board.start(player: Player)
	me = player.UserId
	local _, r = Ui.screen(player:WaitForChild("PlayerGui"), "RotagBoard", 5)
	root = r
	build(Ui.topInset() + 6)
	Flow.onProfile(function(p)
		if type(p.earned) == "number" then earned = p.earned end
		if type(p.levels) == "number" and p.levels > 0 and type(p.level) == "number" then levelled = p.level end
	end)
end

return Board
