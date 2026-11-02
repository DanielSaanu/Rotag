-- The closing walls on the server (H24, docs/systems/endgame.md §7): opens shared/Walls when the end phase starts,
-- steps it every server frame on the server's OWN position record (Match's history: each runner's newest sample, the
-- speed check's `untrusted` mark included), eliminates through Tag.eliminate, and hands Match what MatchState
-- carries. Nothing is read from a client beyond the snapshot stream every other rule already judges on (trust.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))
local Rules = require(Shared:WaitForChild("Walls"))
local Arena = require(script.Parent:WaitForChild("Arena")) -- H26: the map's window bounds (DESIGN §6.8)

local Walls = {}

local SEND_GAP = 0.25 -- seconds between MatchStates while the walls move (clients extrapolate in between)
local CHANGE_GAP = 0.2 -- H26 follow-up: an out or a back-in is sent at once, but never more than 5 a second in all
-- (a death always goes at once); the HUD predicts its own runner's out locally, so the wait never shows
local BOT_INSET = 4 -- studs inside each wall a dummy keeps to (Walls.room)
local state: Rules.State? = nil
local lastNow, lastSend, pending = 0, -math.huge, false
local studio = RunService:IsStudio()
local function log(...) if studio then print("[Rotag] walls:", ...) end end

-- One frame. `history` is Match's record; `held(id, now)` an item hold (server/Items). True = send MatchState now.
function Walls.step(r: Tag.Round, now: number, history: { [number]: { Tag.Sample } },
	held: (number, number) -> boolean): boolean
	local dt = math.clamp(now - lastNow, 0, 0.1) -- a hitch must not eat a whole grace in one frame
	lastNow = now
	local function pos(id: number): (number?, boolean?)
		local h = history[id]
		local s = h and h[#h]
		if not s then return nil, nil end
		return s.x, not s.untrusted
	end
	if state and state.round ~= r then state = nil end
	if r.over then return false end
	local w = state
	if not w then
		if not Tag.endPhase(r, now) then return false end
		w = Rules.open(r, now, pos, Arena.WINDOW) -- the wander's seed: the server's clock now (a new path every round)
		if not w then return false end
		state, pending = w, false
		log(("closing in: centre %.1f, half-width %.1f -> %g over %gs, in x %g..%g, seed %.3f"):format(w.x, w.hw0,
			Config.WALL_MIN_HW, Config.WALL_CLOSE_TIME, Arena.WINDOW.lo, Arena.WINDOW.hi, w.seed))
		lastSend = now
		return true
	end
	local before = table.clone(w.left)
	local out, changed = Rules.step(w, r, now, dt, pos, function(id) return held(id, now) == true end)
	if studio and changed then
		for id in w.left do if before[id] == nil then log(("%s is outside the walls"):format(tostring(id))) end end
		for id in before do
			if w.left[id] == nil and r.alive[id] then log(("%s is back inside"):format(tostring(id))) end
		end
	end
	for _, id in out do
		log(("%s stayed outside the walls, eliminated; %s"):format(tostring(id),
			if r.over then ("round over, winner " .. tostring(r.winner)) else (tostring(r.it) .. " is it")))
	end
	-- QA round 1: only while the walls still MOVE (closing, or the centre drifting) does the 4-a-second resend run; a
	-- closed, settled box sends on changes only. H26: the wander keeps a closed box moving, so in practice the resend
	-- runs for the whole end phase (4 small MatchStates a second; the client's 0.25 s extrapolation error < 0.25 stud).
	local moving = Rules.closeRate(w, now) > 0 or math.abs(w.vx) > 0.05
	pending = pending or changed
	local gap = now - lastSend
	if #out > 0 or (pending and gap >= CHANGE_GAP) or (moving and gap >= SEND_GAP) then
		lastSend, pending = now, false
		return true
	end
	return false
end

-- For MatchState: the window and the runners outside it, or nil and an empty list when there are no walls.
function Walls.rows(r: Tag.Round?, now: number): (any, { Rules.Row })
	local w = state
	if not (r and w and w.round == r and not r.over) then return nil, {} end
	return Rules.rows(w, now)
end

-- For server/Bots: is living runner `id` outside the walls right now? Then where the window's centre is.
function Walls.backIn(id: number): number?
	local w = state
	if w and not w.round.over and w.left[id] ~= nil then return w.x end
	return nil
end

-- For server/Bots (H26 follow-up): the x range a dummy inside should keep to, BOT_INSET inside each wall (nil, nil
-- with no walls). A dummy that patrolled into a swaying wall flapped out and in every frame (hundreds of log lines).
function Walls.room(now: number): (number?, number?)
	local w = state
	if not w or w.round.over then return nil, nil end
	local hw = Rules.halfWidth(w, now) - BOT_INSET
	return w.x - hw, w.x + hw
end

return Walls
