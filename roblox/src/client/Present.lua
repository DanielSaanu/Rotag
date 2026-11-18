-- The presentation glue (H31, docs/systems/ui.md): one place where the game's events meet its sound, its punch and its
-- screens, so client/Client.client.lua's frame loop stays the move rules. It starts the menu, the scoreboard, the
-- audio and the effects, and each frame: picks the music, beeps the fuse, ticks the countdown, puts every runner's
-- name, trail and glow on its sprite, and updates the menu and the cards. Cosmetic and local only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Locker = require(script.Parent:WaitForChild("Locker"))
local Board = require(script.Parent:WaitForChild("Board"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Others = require(script.Parent:WaitForChild("Others"))
local Items = require(script.Parent:WaitForChild("Items"))
local Lobby = require(script.Parent:WaitForChild("Lobby")) -- H37: the doors and the callouts
local Callout = require(script.Parent:WaitForChild("Callout"))

local Present = {}

-- A seat's colour (the roster's order): the name over each runner, so four identical figures are four people.
local SEATS = { Ui.C.cyan, Ui.C.lime, Color3.fromRGB(255, 120, 230), Ui.C.gold }
local HH = Config.RUNNER_HEIGHT / 2
local me = 0
local lastTick, wasPhase, wasEnd = -1, "", false
local ghostOf: (number) -> string? = function() return nil end
local myAt: Vector3? = nil -- where the local runner was last drawn (a pickup's ring)

local warned: { [string]: boolean } = {}
local function guard(what: string, fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok and not warned[what] then
		warned[what] = true
		warn(("[Rotag] present: %s failed (shown once): %s"):format(what, tostring(err)))
	end
end

local function seat(id: number): Color3
	local s = Flow.session()
	local i = s and table.find(s.roster, id)
	return if i then SEATS[(i - 1) % #SEATS + 1] else Ui.C.text
end

-- What the local runner's Movement reported since the last draw, at its feet (x, y the body's centre).
function Present.moves(events: any, x: number, y: number)
	myAt = Vector3.new(x, y, 0)
	Audio.moves(events)
	if events.landed and events.landed > 30 then
		Fx.burst(x, y - HH, { { 200, 205, 225 } }, "dust", 10)
		if events.landed > 70 then Fx.shake(0.18) end
	end
	if events.jump == "ground" or events.dash then Fx.burst(x, y - HH, { { 200, 205, 225 } }, "dust", 6) end
	if events.jump == "double" then Fx.ring(x, y - HH, Ui.C.cyan, 4) end
end

-- A confirmed tag (TagVerdict): where this screen draws the victim.
function Present.verdict(v: any, at: Vector3?)
	local involved = v.from == me or v.to == me
	if at then Fx.tag(at.X, at.Y, involved) end
	Audio.play(if v.to == me then "tagged" else "tag")
end

-- A runner burnt out or was walled out (client/Ignition found it in the state).
function Present.burst(id: number, at: Vector3, walled: boolean)
	if not walled then Fx.burnout(id, at.X, at.Y) else Fx.shake(0.6) end
	Audio.play("burnout")
	if id == me then Fx.flash(Ui.C.ember, 0.5) end
end

-- H38: we dashed through the holder: its tag cannot land. Big, quick, ours only.
function Present.dodged(x: number, y: number)
	Fx.ring(x, y, Ui.C.cyan, 7)
	Audio.play("go", 1.6)
	Callout.big("DODGED!", nil, Ui.C.cyan, 0.9)
end

function Present.spook(v: any)
	Audio.play("hex")
	if v.to == me then Fx.flash(Ui.C.ghost, 0.3) end
end

-- The spectator camera's focus (no body: in the menu before Play, or sat out): the holder, else the pack, else the
-- start line.
function Present.focus(match: any): (number, number)
	local at = (match and match.it and Others.drawnAt(match.it)) or Others.middle()
	if at then return at.X, at.Y end
	return 0, 10
end

-- What each item is called, its colour, and what it does in a few words (the pickup banner).
local ITEMS: { [string]: { any } } = {
	crate = { "CRATE", { 255, 170, 70 }, "drops behind you: whoever hits it stumbles" },
	trap = { "BEAR TRAP", { 255, 70, 50 }, "set at your feet: whoever steps in is stuck" },
	ice = { "ICE BEAM", { 90, 225, 255 }, "a beam ahead of you: freezes whoever it touches" },
	hex = { "HEX", { 235, 80, 210 }, "touch the holder: 3 seconds off its fuse" },
	fixture = { "PIECE", { 150, 130, 255 }, "a block you place in the map" },
	pad = { "BOOST PAD", { 130, 255, 100 }, "a launch pad you place" },
	grant = { "BOOST", { 255, 160, 60 }, "touch a runner: a burst of speed for them" },
}
local function useHint(item: string): string
	if item == "hex" or item == "grant" then return "" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "tap ITEM" end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return "press RB" end
	return "press E"
end

local function onItem(e: any)
	if e.kind == "orb" and type(e.by) == "number" and type(e.item) == "string" then
		-- Danzo, 2026-11-16: "make the item acquisition flashier for both the sprite everyone sees and for the player
		-- so they clearly know what they got". Every screen: a ring and sparks on whoever took it, in the item's
		-- colour. The taker's own: a banner naming it and what it does, a flash, a louder sound.
		local def = ITEMS[e.item]
		local at = if e.by == me then myAt else Others.drawnAt(e.by)
		if def and at then
			Fx.ring(at.X, at.Y, Ui.rgb(def[2]), 9)
			Fx.burst(at.X, at.Y + 1, { def[2], { 255, 255, 255 } }, "nova", 18)
		end
		if e.by == me then
			Audio.play("orb")
			if def then
				local hint = useHint(e.item)
				Board.toast("YOU GOT: " .. def[1], def[3] .. (if hint ~= "" then "  ·  " .. hint else ""), Ui.rgb(def[2]))
				Fx.flash(Ui.rgb(def[2]), 0.22)
				Audio.play("prize", 1.25)
			end
		end
	elseif e.kind == "put" then
		Audio.play(if e.item == "ice" then "ice" elseif e.item == "trap" then "place" else "crate")
	elseif e.kind == "hold" then
		Audio.play(if e.hold == "trap" then "trap" elseif e.hold == "freeze" then "ice" else "crate")
		if e.id == me then Fx.shake(0.35) end
	elseif e.kind == "placed" and e.owner ~= 0 then
		Audio.play("place")
	elseif e.kind == "grant" and e.id == me then
		Audio.play("coin", 0.7)
	end
end

-- Every render frame. `look`: the local runner's Look (nil: no body); `match`: the last MatchState; `fuse`: seconds
-- left on it; `ghostMode(id)`: nil for the living.
function Present.frame(look: any, match: any, fuse: number, ghostMode: (number) -> string?)
	ghostOf = ghostMode
	local phase, left = Flow.phase(), Flow.left()
	local running = match ~= nil and not match.over
	-- Music follows the match: the menu's track in the lobby and on the podium, the chase in a round, the pressure
	-- track once the end phase is on (rule 51).
	-- QA round 1: the match track holds through the 6 s gaps between rounds (it flipped to the menu's and back).
	local inMatch = phase == "round" or phase == "gap"
	Audio.music(if not inMatch or (not Flow.playing() and Menu.open()) then "menu"
		elseif running and match.endPhase then "end" else "match")
	if running then Audio.fuse(fuse, Config.IGNITE_AT, match.it == me) end
	if running and match.endPhase and not wasEnd then
		Audio.play("walls")
		Fx.flash(Ui.C.red, 0.3)
	end
	wasEnd = running and match.endPhase == true
	if phase == "lobby" and left and left <= 3 then
		local n = math.ceil(left)
		if n ~= lastTick then
			lastTick = n
			Audio.play("tick", 1)
		end
	else
		lastTick = -1
	end
	if phase ~= wasPhase then
		if phase == "round" then Audio.play("go") end
		wasPhase = phase
	end
	-- Each part on its own (pcall): a slip in a cosmetic must never stop the menu or the cards, or the rest of the
	-- frame behind this call (it did: Look.glow, 2026-11-16). The first error of each kind is printed once.
	guard("names and cosmetics", function()
		if look then
			look:name("YOU", if ghostOf(me) then Ui.C.ghost else seat(me))
			Fx.wear(look, me, ghostOf(me) == nil)
		end
		Others.each(function(id, other)
			local ghost = ghostOf(id) ~= nil
			other:name(Flow.nameOf(id), if ghost then Ui.C.ghost else seat(id))
			Fx.wear(other, id, not ghost)
		end)
	end)
	guard("menu", Menu.update)
	guard("lobby", Lobby.frame, if look then myAt else nil) -- H37: the doors, the bar, every word about the queue
	-- In the lobby a round that is not ours (a solo server) is not on our screen: its cards stay off it too.
	guard("board", Board.update, match, Menu.open() or (Lobby.here() and not Flow.playing()))
end

function Present.start(player: Player)
	me = player.UserId
	Flow.start(player)
	Audio.start()
	Fx.start(player)
	Menu.start(player)
	Board.start(player)
	Lobby.start(player)
	Ui.onClick = function() Audio.play("click") end
	Ui.onHover = function() Audio.play("hover") end
	Items.listen(onItem)
	Locker.onSpin = function(what: string, new: boolean)
		if what == "tick" then
			Audio.play("tick", 1.4)
		else
			Audio.play(if what == "common" then "coin" else "prize", if what == "legendary" then 1.2 else 1)
		end
	end
	Board.onCard = function(what: string, won: boolean)
		Audio.play(if what == "podium" or won then "win" else "card")
		if won then
			local cam = workspace.CurrentCamera
			local x, y = if cam then cam.CFrame.X else 0, if cam then cam.CFrame.Y else 10
			Fx.burst(x, y + 6, { { 255, 90, 90 }, { 255, 220, 70 }, { 90, 220, 255 }, { 150, 255, 110 } }, "confetti",
				if what == "podium" then 120 else 50)
		end
	end
	Flow.onProfile(function(p)
		if type(p.earned) == "number" and p.earned > 0 then Audio.play("coin") end
	end)
	-- H32: client/Board's strip is this game's player list (it seats the bots beside the people, bots.md §7); Roblox's
	-- own would sit over the wallet. SetCoreGuiEnabled can throw before the CoreGui is ready: try a few times.
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end) then break end
			task.wait(1)
		end
	end)
end

return Present
