-- The walk-in lobby on the client (H37, docs/systems/lobby.md): which door the local runner is in, the bar that
-- fills while it stays, what choosing that door asks the server for, and EVERY word that tells the player what is
-- going on (client/Callout draws them). It decides nothing: a door is a request (Remotes.Menu) the server judges
-- against its own position of us, and what the callouts say comes from what the server sent back (Flow.session), so
-- "YOU'RE IN THE QUEUE!" is never shown for a request that was refused.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Lobby"))
local Course = require(Shared:WaitForChild("Tutorial")) -- H41: the course is off the round's screen too
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Callout = require(script.Parent:WaitForChild("Callout"))
local CodePad = require(script.Parent:WaitForChild("CodePad"))

local Lobby = {}

local C = Ui.C
local PINK, WHITE = Color3.fromRGB(255, 111, 181), Color3.fromRGB(238, 241, 255)
local me = 0
local area: string? = nil
local onCourse = false
local dwell = Rules.newDwell()
local last = os.clock()
local lastBump: string? = nil
local lastThird = 0
local lastNote = 0
local mine: string?, mineAt = nil, 0 -- what we last asked for through a door ("practice" | "host" | "code"), and when
local welcomed = false
local wasHere = false
local SEATS = Config.PLAYERS_PER_MATCH

local function rgb(c: { number }): Color3 return Color3.fromRGB(c[1], c[2], c[3]) end
local function has(list: any, id: number): boolean return type(list) == "table" and table.find(list, id) ~= nil end
local function upper(id: number?): string return string.upper(Flow.nameOf(id)) end

-- Is the local runner in the lobby, a room or the tutorial course (not the arena)?
function Lobby.here(): boolean return area ~= nil or onCourse end

-- The still camera for a runner at (x, y): the point to centre on and the studs of world to show top to bottom, or
-- nil in the arena.
function Lobby.camera(x: number, y: number): (number?, number?, number?)
	local a = Rules.areaAt(x)
	if not a then return nil, nil, nil end
	local cam = workspace.CurrentCamera
	local size = if cam then cam.ViewportSize else Vector2.new(16, 9)
	local cx, cy, view = Rules.camera(a, x, if size.Y > 0 then size.X / size.Y else 16 / 9)
	return cx, cy - Config.CAMERA_Y_OFFSET, view -- shared/SideCam adds the offset back
end

local function room(s: any): any
	local r = s and s.room
	return if type(r) == "table" and has(r.members, me) then r else nil
end

-- A door was chosen (its bar filled).
local function choose(id: string, queued: boolean)
	local ask = Rules.ask(id, queued)
	Audio.play("go", 1.2)
	if ask == "play" then
		Menu.play() -- a first-timer reads the how-to cards, then is queued
	elseif ask == "sit" then
		Flow.sit()
	elseif ask == "locker" then
		Menu.locker()
	elseif ask == "pad" then
		CodePad.open(function(code: string)
			mine, mineAt = "code", os.clock()
			Flow.op("code:" .. code)
			CodePad.status("LOOKING FOR ROOM " .. code .. "...", C.text)
		end)
	else
		if ask == "practice" or ask == "host" then mine, mineAt = ask, os.clock() end
		if ask == "host" then Callout.big("MAKING YOUR ROOM...", "one moment", PINK, 2.5) end
		if ask == "leave" then Callout.big("BACK TO THE LOBBY...", nil, WHITE, 2) end
		Flow.op(ask)
	end
end

local NOTES: { [string]: { string } } = {
	noroom = { "NO ROOM WITH THAT CODE", "check the numbers and try again" },
	full = { "THAT ROOM IS FULL", "four runners are already in it" },
	failed = { "COULDN'T GET THERE", "nothing is lost: try the door again" },
	busy = { "NOT RIGHT NOW", "a match is running here: try again in a moment" },
	need2 = { "YOU NEED 2 PLAYERS", "wait for a friend, or turn BOTS on" },
	hostonly = { "ONLY THE HOST CAN DO THAT", nil :: any },
}

-- What changed between two of the server's views: said once, big.
local function onSession(new: any, old: any)
	local note = new.note
	if type(note) == "table" and type(note[2]) == "number" and note[2] ~= lastNote then
		lastNote = note[2]
		local words = NOTES[tostring(note[1])]
		if words then
			mine = nil
			Audio.play("card", 0.7)
			if CodePad.isOpen() and (note[1] == "noroom" or note[1] == "full" or note[1] == "failed") then
				CodePad.status(words[1], C.ember, true)
			else
				Callout.big(words[1], words[2], C.ember, 4)
			end
		end
	end
	if not old then return end
	local wasIn, isIn = has(old.playing, me), has(new.playing, me)
	local wasQ, isQ = wasIn and old.phase == "lobby", isIn and new.phase == "lobby"
	local wasL, isL = has(old.launching, me), has(new.launching, me)
	local was, is = room(old), room(new)
	if isL and not wasL then -- being taken somewhere: every other screen out of the way
		Menu.close()
		CodePad.close()
		Audio.play("prize")
	end
	if is and not was then
		CodePad.close()
		Audio.play("prize")
		if is.host == me then
			Callout.big("YOUR ROOM IS OPEN!", ("the code is %s  ·  tell your friends"):format(tostring(is.code)), PINK, 5)
		else
			Callout.big("YOU'RE IN THE ROOM!", ("waiting for %s to start"):format(upper(is.host)), PINK, 4)
		end
	elseif was and not is then
		Callout.big("BACK IN THE LOBBY", "stand in a door to choose", WHITE)
	elseif was and is then
		for _, id in is.members do
			if not has(was.members, id) then
				Callout.big(upper(id) .. " JOINED!", ("%d of %d in the room"):format(#is.members, SEATS), PINK)
				Audio.play("coin")
			end
		end
		for _, id in was.members do
			if not has(is.members, id) then Callout.big(upper(id) .. " LEFT", ("%d of %d in the room"):format(#is.members, SEATS), C.dim) end
		end
		if is.host ~= was.host and has(is.members, was.host) then -- handed over (not: the old host walked out)
			Callout.big(if is.host == me then "YOU ARE THE HOST NOW" else upper(is.host) .. " IS THE HOST NOW",
				if is.host == me then "stand in START when everyone is ready" else nil, C.gold, 4)
			Audio.play("prize")
		elseif is.host ~= was.host and is.host == me then
			Callout.big("YOU ARE THE HOST NOW", "stand in START when everyone is ready", C.gold, 4)
		end
		if is.rounds ~= was.rounds then
			Callout.big(("ROUNDS: %d"):format(is.rounds), if is.rounds == 1 then "one round decides it" else "most points wins", WHITE, 2.2)
			Audio.play("click")
		elseif is.items ~= was.items then
			Callout.big(if is.items then "ITEMS: ON" else "ITEMS: OFF", if is.items then "orbs, crates, traps, ice" else "no orbs: just running", WHITE, 2.2)
			Audio.play("click")
		elseif is.bots ~= was.bots then
			Callout.big(if is.bots then "BOTS: ON" else "BOTS: OFF", if is.bots then "bots fill the empty seats" else "only people: you need two", WHITE, 2.2)
			Audio.play("click")
		end
		if isIn and not wasIn then Callout.big("HERE WE GO!", nil, C.lime, 2) end
	end
	if isQ and not wasQ and not is then
		Audio.play("go")
		if mine == "practice" then
			Callout.big("PRACTICE!", "just you and bots  ·  nothing counts", C.cyan, 3)
		else
			Callout.big("YOU'RE IN THE QUEUE!", "keep moving: we'll grab you when it starts", C.lime, 4)
		end
	elseif wasQ and not isQ and not isL and not is and new.phase == "lobby" then
		Audio.play("card")
		Callout.big("YOU LEFT THE QUEUE", "stand in QUICK MATCH to play", WHITE, 4)
	elseif isQ and wasQ and (tonumber(new.queued) or 0) > (tonumber(old.queued) or 0) then
		Audio.play("coin", 0.8)
		Callout.big("A RUNNER JOINED!", ("%d of %d"):format(tonumber(new.queued) or 1, SEATS), C.lime, 1.8)
	end
	if wasL and not isL and type(note) ~= "table" and new.mode == "hub" and isQ then
		Callout.big("STILL LOOKING...", "that match didn't start: you're still in the queue", C.gold, 4)
	end
	if old.phase == "podium" and new.phase == "lobby" and wasIn then
		Callout.big("GOOD GAME!", if is then (if is.host == me then "stand in START to play again" else "the host can start another")
			else "stand in a door to play again", C.gold, 5)
	elseif wasIn and not isIn and (old.phase == "round" or old.phase == "gap") then
		Audio.play("card") -- out through the menu's LEAVE THE MATCH (QA round 1: back in the lobby with no words)
		Callout.big("YOU LEFT THE MATCH", if is then "you are back in the room" else "stand in a door to play", WHITE, 4)
	end
end

-- The pill, the count and the held line: what the local player is in right now.
local function status(s: any, queued: boolean, r: any)
	local left = Flow.left()
	local launching = s ~= nil and has(s.launching, me)
	local started = r ~= nil and Flow.playing()
	if launching then
		Callout.pill(nil)
		Callout.count(nil)
		if mine == "host" then
			Callout.hold("ROOM READY!", "taking you there...", PINK)
		elseif mine == "code" then
			Callout.hold("ROOM FOUND!", "taking you there...", PINK)
		elseif mine == "practice" then
			Callout.hold("PRACTICE!", "taking you there...", C.cyan)
		else
			Callout.hold("MATCH FOUND!", "taking you there: hang on", C.gold)
		end
		return
	end
	Callout.release()
	-- a private match (practice, a room) on this server is its group's: its count is not ours to see
	local outside = s ~= nil and type(s.group) == "table" and not has(s.group, me)
	local counting = (queued or started) and left ~= nil and left <= 5 and not outside
	if counting and (Menu.open() or CodePad.isOpen()) then -- the match is about to start: every screen out of the way
		Menu.close()
		CodePad.close()
	end
	Callout.dock(Menu.open() or CodePad.isOpen())
	if Callout.count(if counting and left then math.max(1, math.ceil(left)) else nil,
		if mine == "practice" then "PRACTICE STARTS IN" else "MATCH STARTS IN") then
		Audio.play("tick", 1)
	end
	if r then
		local code = "ROOM  " .. tostring(r.code)
		if started then
			Callout.pill(code, PINK, "starting!")
		elseif r.host == me then
			Callout.pill(code, PINK, "YOU ARE THE HOST", "stand in START when everyone is here  ·  the LOBBY door leaves")
		else
			Callout.pill(code, PINK, ("waiting for %s to start"):format(upper(r.host)), "jump around while you wait  ·  the LOBBY door leaves")
		end
	elseif queued and mine == "practice" then
		Callout.pill("PRACTICE", C.cyan, "starting: nothing counts")
	elseif Flow.playing() and outside then
		Callout.pill("IN THE QUEUE", C.lime, "a private match here goes first  ·  keep moving!",
			"to leave: go back to QUICK MATCH and stay 2 seconds")
	elseif queued then
		local n = if s then tonumber(s.queued) or 1 else 1
		Callout.pill(("IN THE QUEUE   %d / %d"):format(n, SEATS), C.lime,
			if left and left > 5 then ("match starts in %d  ·  keep moving!"):format(math.ceil(left))
				elseif left then "here it comes!" else "finding runners  ·  keep moving!",
			"to leave: go back to QUICK MATCH and stay 2 seconds")
	elseif Flow.playing() then -- a solo server, mid-match: in from the next round
		Callout.pill("YOU'RE IN NEXT ROUND", C.lime, "this round is finishing")
	elseif Menu.open() or CodePad.isOpen() then
		Callout.pill(nil) -- nothing to say over the menu or the how-to cards
	else
		Callout.pill("STAND IN A DOOR TO CHOOSE", WHITE, "QUICK MATCH is the big green door")
	end
end

-- Every render frame. `pos`: where the local runner is (nil: no body).
function Lobby.frame(pos: Vector3?)
	local now = os.clock()
	local dt = math.min(now - last, 0.1)
	last = now
	Callout.update()
	area = if pos then Rules.areaAt(pos.X) else nil
	onCourse = pos ~= nil and Course.inCourse(pos.X)
	if mine and now - mineAt > 20 then mine = nil end
	local a = area
	if not (a and pos) then -- the arena: the round's own HUD speaks
		Rules.dwell(dwell, nil, dt, 1) -- no body, or elsewhere: outside every door (a fresh body may choose again)
		if wasHere and pos then Menu.close() end -- taken into a match with the locker open: the round, not the shop
		wasHere = false
		Callout.dock(false)
		if not onCourse then Callout.pill(nil) end -- the course's pill is client/Tutorial's (H41)
		Callout.caption(nil)
		Callout.fill(nil)
		Callout.count(nil)
		Callout.release()
		if CodePad.isOpen() then CodePad.close() end
		return
	end
	wasHere = true
	local s = Flow.session()
	local r = if a == "room" then room(s) else nil
	local queued = Flow.playing() and Flow.phase() == "lobby" and r == nil
	status(s, queued, r)
	if not welcomed then
		welcomed = true
		Callout.big("WELCOME TO ROTAG!", "run to a door and stand in it to choose", WHITE, 5)
	end
	-- The room's setting blocks: jumping into one asks for the change (only the host's is granted).
	local bump = Rules.bumpAt(a, pos.X, pos.Y)
	if bump == nil and lastBump ~= nil and pos.Y - Rules.AREAS[a].y > 3 then
		bump = lastBump -- still in the air above or below it: the same jump (QA round 1: one jump changed it twice)
	end
	if bump and bump ~= lastBump and r and not Flow.playing() then
		if r.host == me then
			Flow.op("set:" .. bump)
		else
			Callout.big("ONLY THE HOST CAN CHANGE THIS", ("%s is the host"):format(upper(r.host)), C.gold, 2.5)
		end
	end
	lastBump = bump
	-- The doors. Nothing answers while another screen is up, while we are being taken somewhere, or once a room's
	-- match has been started; and the clock does not run then either (so nothing fires the moment a screen closes).
	-- The pad belongs to its door: walk away and it closes (QA round 3: it stayed up across the whole lobby).
	if CodePad.isOpen() and not Rules.inDoor(a, "code", pos.X, pos.Y, 3) then CodePad.close() end
	local busy = Menu.open() or CodePad.isOpen() or (s ~= nil and has(s.launching, me)) or (r ~= nil and Flow.playing())
	if busy then
		Callout.caption(nil)
		Callout.fill(nil)
		return
	end
	local d = Rules.doorAt(a, pos.X, pos.Y)
	local near = d or Rules.doorNear(a, pos.X, pos.Y, 5)
	local hostOnly = d ~= nil and d.id == "start" and r ~= nil and r.host ~= me
	local id = if d and not hostOnly then d.id else nil
	local standing = d == nil or Rules.standing(a, d, pos.Y)
	local fired, frac = Rules.dwell(dwell, id, dt, if id then Rules.hold(id, queued, Flow.left()) else 1, standing)
	if fired and id then
		lastThird = 0
		Callout.caption(nil)
		Callout.fill(nil)
		choose(id, queued)
		return
	end
	if id and d and frac > 0 then
		local leaving = id == "quick" and queued
		local color = if leaving then WHITE else rgb(d.color)
		local o = Rules.AREAS[a]
		Callout.fill(o.x + d.x0, o.y + d.y0, o.x + d.x1, o.y + d.y1, frac, color) -- the doorway fills with light
		Callout.caption(if leaving then "LEAVING THE QUEUE..." else d.name .. "...", color, "stay in the door", true)
		local third = math.floor(frac * 3)
		if third ~= lastThird then
			lastThird = third
			Audio.play("tick", 1 + third * 0.2)
		end
	elseif near then
		lastThird = 0
		local line: string? = near.line
		if d and id and not dwell.armed and not (near.id == "quick" and queued) then
			line = "Step out, then walk in to choose." -- landed in it from a jump, or already chose it this visit
		elseif near.id == "quick" and queued then
			line = nil -- the pill already says it all
		elseif near.id == "start" and r then
			line = if r.host == me then "Stay here to start the match for everyone." else ("Only the host (%s) can start."):format(upper(r.host))
		end
		Callout.fill(nil)
		if line then Callout.caption(near.name, rgb(near.color), line) else Callout.caption(nil) end
	else
		lastThird = 0
		Callout.fill(nil)
		Callout.caption(nil)
	end
end

function Lobby.start(player: Player)
	me = player.UserId
	Callout.start(player)
	CodePad.start(player)
	Flow.onSession(onSession)
end

return Lobby
