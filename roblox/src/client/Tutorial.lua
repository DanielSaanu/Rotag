-- The tutorial on this screen (H41, docs/systems/tutorial.md): which lesson the local runner is on (shared/Tutorial's
-- rules, fed every physics step), the one line that says what to do in the words of the device in hand
-- (client/Controls.say), a pop when a lesson is done, the IT lesson's fuse, the SKIP button, and the touch on the
-- target sent as a claim. It decides nothing that matters: the server judges the claim on its own record of the
-- target (server/Course) and the win is said only when its answer comes back. Words go through client/Callout,
-- one line at a time, never the lower middle (rule 23).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Tutorial"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Flow = require(script.Parent:WaitForChild("Flow"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Callout = require(script.Parent:WaitForChild("Callout"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Others = require(script.Parent:WaitForChild("Others"))

local Tutorial = {}

local C = Ui.C
local IT_RED = Color3.fromRGB(255, 90, 70)
local CLAIM_GAP = 0.45 -- seconds between two claims (server/Doors drops anything closer than 0.4)
local p = Rules.new()
local here = false -- the runner was last seen on the course (a respawn's body gap does not count as leaving)
local startedAt, fuseFrom = 0, nil :: number?
local claimAt = -math.huge
local lastNote = 0
local won: number? = nil -- seconds the course took, once the server confirmed the tag
local skipped = false
local best: number? = nil -- this visit's best time (session-only, as the rest)
local skip: TextButton? = nil
local pending: { string } = {} -- lessons finished since the last frame (physics runs more often than drawing)

-- What each lesson says. `say` is the device's words for a verb.
local function prompt(id: string): (string, string)
	local say = Controls.say
	if id == "run" then return "RUN", say("run") .. " to the next room" end
	if id == "jump" then return "JUMP", say("jump") .. " to hop the block" end
	if id == "double" then
		return "DOUBLE JUMP", "from the gold line: " .. say("jump") .. ", then again in the air, quickly"
	end
	if id == "wall" then return "WALL JUMP", "jump into the gap, then " .. say("jump") .. " at each wall to kick up it" end
	if id == "dash" then return "DASH", "the roof is low: jump, then " .. say("dash") .. " to fly over the gap" end
	if id == "grapple" then return "GRAPPLE", "jump near the gold ball and " .. say("grapple") .. ". Let go to fly!" end
	return "YOU ARE IT!", "touch the runner to tag them before your fuse runs out"
end
local CHEER = { run = "GOOD!", jump = "NICE JUMP!", double = "DOUBLE JUMP!", wall = "WALL JUMP!", dash = "DASH!",
	grapple = "YOU SWUNG!" }

local function clock(t: number): string return ("%d:%02d"):format(t // 60, math.floor(t % 60)) end

-- Is the local runner in the IT lesson (the course's last room, that lesson current)?
local function inIt(x: number): boolean
	local r = Rules.current(p)
	return r ~= nil and r.id == "it" and Rules.roomAt(x) == #Rules.ROOMS
end

-- Every physics step, after Movement.step (client/Client): the lesson rules, and the touch on the target.
function Tutorial.moved(s: any, ev: any)
	if not Rules.inCourse(s.x) then return end
	local what, id = Rules.update(p, s.x, s.y, s.grounded, ev, s.rope ~= nil)
	if what == "done" and id then table.insert(pending, id) end
	if inIt(s.x) and not won and os.clock() - claimAt >= CLAIM_GAP then
		local at = Others.drawnAt(Rules.BOT_ID) -- where this screen draws it: what the player saw touch
		if at and Rules.touching(s.x, s.y, at.X, at.Y, 0) then
			claimAt = os.clock()
			Flow.op("tut:tag")
		end
	end
end

-- "it" runs a little faster (Config.IT_SPEED, rule 4 as H40 set it): in the IT lesson, so does the player.
function Tutorial.speedMult(x: number, base: number): number
	return if inIt(x) then math.max(base, Config.IT_SPEED) else base
end

local function onSession(new: any)
	local note = new.note
	if type(note) ~= "table" or type(note[2]) ~= "number" or note[2] == lastNote then return end
	lastNote = note[2]
	if note[1] ~= "tuttag" or won then return end
	Rules.tagged(p)
	won = os.clock() - startedAt
	best = if best then math.min(best, won) else won
	Menu.learned()
	Audio.play("tag")
	Audio.play("win")
	Callout.big("TAGGED!", ("now THEY are it  ·  course done in %s%s"):format(clock(won),
		if best and best < won then "  ·  best " .. clock(best) else ""), C.lime, Rules.HOME_AFTER)
end

-- Every render frame. `pos`: where the local runner is (nil: no body).
function Tutorial.frame(pos: Vector3?)
	local now = os.clock()
	local on = pos ~= nil and Rules.inCourse(pos.X)
	if pos and on and not here then -- arrived (the door, or a first join): a fresh run
		p, won, skipped, fuseFrom, startedAt = Rules.new(), nil, false, nil, now
		table.clear(pending)
		Callout.big("TUTORIAL", "one move per room  ·  about a minute  ·  SKIP any time", C.text, 3.5)
		Audio.play("go")
	elseif pos and not on and here then -- back in the lobby
		if won then
			Callout.big("YOU'RE READY!", "stand in QUICK MATCH to play", C.lime, 6)
		elseif skipped then
			Callout.big("TUTORIAL SKIPPED", "the TUTORIAL door is downstairs, right of QUICK MATCH", C.text, 4)
		end
		Callout.pill(nil)
	end
	if pos then here = on end
	if skip then skip.Visible = here and not won end
	if not (here and pos) then return end
	for _, id in pending do
		Audio.play("coin", 1.2)
		local nextRoom = Rules.current(p)
		local title = if nextRoom then (prompt(nextRoom.id)) else nil
		Callout.big(CHEER[id] or "NICE!", if title then "next: " .. title else nil, C.lime, 1.6)
	end
	table.clear(pending)
	local r = Rules.current(p)
	if won or not r then
		Callout.pill("COURSE DONE", C.lime, "taking you to the lobby...")
		return
	end
	local title, line = prompt(r.id)
	local n = table.find(Rules.ROOMS, r) or 1
	if r.id == "it" and inIt(pos.X) then
		fuseFrom = fuseFrom or now
		local left = Rules.FUSE - (now - fuseFrom)
		if left <= 0 then -- nothing burns: it teaches the hurry, then starts again
			fuseFrom = now
			Audio.play("burnout")
			Callout.big("YOUR FUSE RAN OUT!", "in a match you'd be a ghost now: try again", IT_RED, 3)
			left = Rules.FUSE
		end
		Callout.pill(("%s   %d"):format(title, math.ceil(left)), IT_RED, line, "you carry the fuse: a tag passes it on")
	else
		if r.id ~= "it" then fuseFrom = nil end
		Callout.pill(("%d / %d   %s"):format(n, #Rules.ROOMS, title), C.cyan, line)
	end
end

function Tutorial.start(player: Player)
	Flow.onSession(onSession)
	local _, root = Ui.screen(player:WaitForChild("PlayerGui"), "RotagTutorial", 25)
	local b = Ui.button(root, "SKIP TUTORIAL", "ghost", UDim2.fromOffset(170, 38), UDim2.new(1, -12, 0, Ui.topInset() + 72), -- under the wallet AND its
		-- "NOT SAVING" line (seen in Studio: at +50 they overlapped)
		function()
			skipped = true
			Flow.op("tut:skip")
		end, Vector2.new(1, 0))
	Ui.setText(b, nil, 16)
	b.Visible = false
	skip = b
end

-- Studio's smoke test reads the state (docs/systems/tutorial.md §7).
function Tutorial.state(): any return { step = p.step, done = p.done, passed = p.passed, here = here, won = won } end

return Tutorial
