-- The tag HUD (DESIGN §3 rule 2, "make the fuse readable"; docs/systems/tag.md §6): the fuse readout at the top
-- centre (rule 23 keeps the lower middle clear), a "+N" pop at every pass, a big red glowing triangle over the
-- holder, one status line (out, round over), and a big countdown to GO while the holder waits (start or pass freeze,
-- H6). H15 (docs/systems/ghosts.md §6): a ghost's own status line, "-N  <ghost>" on every spook, who holds the mark,
-- "<name> is back!" on a comeback, and the IT marker's halo turns pale blue while the shared ward holds.
-- Placeholder UI, not art: the growing, beeping bomb comes with the art pass.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Others = require(script.Parent:WaitForChild("Others")) -- the IT marker sits on the DRAWN runner (H13)

local Hud = {}

local RUNNER_TAG = "RotagRunner"
local DUMMY_NAME = "Dummy"
local POP_TIME = 1.2
local GO_TIME = 0.7 -- seconds "GO!" stays up after the holder's wait ends
local MARKER_PULSE = 1.5 -- glow pulses per second
local MARKER_W, MARKER_H = 3, 2.6 -- studs: the triangle is nearly the runner's width (2) and height (3.5)
local MARKER_UP = Config.RUNNER_HEIGHT / 2 + 0.6 + MARKER_H / 2 -- its centre above the holder's centre
local MARKER_Z = Config.RUNNER_DEPTH / 2 + 0.4 -- in front of the runner's sprite plane, toward the camera
local HIDDEN = CFrame.new(0, -1e4, 0)
local gui, fuseLabel, statusLabel, popLabel, countLabel, markLabel = nil, nil, nil, nil, nil, nil
local halves: { BasePart } = {} -- the solid triangle's two wedges, then the halo's two
local popAt, goAt, wasWaiting = -math.huge, -math.huge, false
local BACK_TIME = 1.6 -- seconds "<name> is back!" stays up
local GHOST_BLUE, POP_GOLD = Color3.fromRGB(170, 215, 255), Color3.fromRGB(255, 210, 90)
local backAt, backText = -math.huge, ""
local seen: { round: number?, alive: { [number]: boolean } } = { round = nil, alive = {} }

local function label(parent: Instance, y: number, h: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(0, 420, 0, h)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Text = ""
	l.Parent = parent
	return l
end

function Hud.nameOf(id: number?): string
	if id == nil then return "nobody" end
	if id < -999 then return if id == -1000 then DUMMY_NAME else (DUMMY_NAME .. tostring(-999 - id)) end
	local p = Players:GetPlayerByUserId(id)
	return if p then p.DisplayName else ("runner " .. tostring(id))
end

local function rootOf(id: number): BasePart?
	for _, model in CollectionService:GetTagged(RUNNER_TAG) do
		if model:GetAttribute("RunnerId") == id then
			local r = model:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then return r end
		end
	end
	return nil
end

-- The IT marker (Danzo 2026-10-11): a big red glowing triangle pointing down at the holder, in the world, not a GUI.
-- H6: a BillboardGui never showed in Studio Play (the old "IT" one was nested in the ScreenGui; moved out, a test one
-- still drew nothing in a capture), while parts and SurfaceGuis do. Two neon wedges make the triangle; two larger,
-- see-through ones behind make the halo. Local to this client: made here, never replicated.
local function wedge(model: Model, w: number, h: number, color: Color3, transparency: number): BasePart
	local p = Instance.new("WedgePart")
	p.Size = Vector3.new(0.1, h, w / 2) -- the triangle is in the wedge's Y-Z plane
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.CFrame = HIDDEN
	p.Parent = model
	return p
end

local function buildMarker(): Model
	local model = Instance.new("Model")
	model.Name = "RotagItMarker"
	local red, halo = Color3.fromRGB(255, 35, 25), Color3.fromRGB(255, 90, 60)
	halves = {
		wedge(model, MARKER_W, MARKER_H, red, 0), wedge(model, MARKER_W, MARKER_H, red, 0),
		wedge(model, MARKER_W * 1.5, MARKER_H * 1.5, halo, 0.7), wedge(model, MARKER_W * 1.5, MARKER_H * 1.5, halo, 0.7),
	}
	model.Parent = workspace
	return model
end

-- Point the triangle down at `at` (a world position), or hide it. Each wedge's right angle goes to the top centre:
-- Ry(+-90) turns the wedge's Y-Z triangle to face the camera, Rz(180) flips it so the point is at the bottom.
local FLIP = CFrame.Angles(0, 0, math.pi)
local function placeMarker(at: Vector3?, pulse: number, warded: boolean?)
	for i, p in halves do
		if not at then
			p.CFrame = HIDDEN
		else
			local scale = if i <= 2 then 1 else 1.5
			local side = if i % 2 == 1 then 1 else -1
			local w = MARKER_W * scale
			local z = MARKER_Z - (if i <= 2 then 0 else 0.1) -- the halo sits just behind
			p.CFrame = CFrame.new(at + Vector3.new(side * w / 4, MARKER_UP, z)) * FLIP
				* CFrame.Angles(0, side * math.pi / 2, 0)
			if i > 2 then
				p.Transparency = 0.55 + 0.3 * pulse
				p.Color = if warded then GHOST_BLUE else Color3.fromRGB(255, 90, 60) -- the ward's shimmer (rule 41)
			end
		end
	end
end

function Hud.start(player: Player)
	gui = Instance.new("ScreenGui")
	gui.Name = "RotagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	fuseLabel = label(gui, 8, 40, 32)
	popLabel = label(gui, 48, 32, 28)
	popLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	statusLabel = label(gui, 82, 24, 18)
	markLabel = label(gui, 106, 22, 16)
	markLabel.TextColor3 = GHOST_BLUE
	-- The holder's wait, counted down big in the middle of the screen, then "GO!" (H6: a small "frozen 3.0" line
	-- read as being stuck).
	countLabel = label(gui, 0, 120, 72)
	countLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countLabel.Position = UDim2.fromScale(0.5, 0.38)
	countLabel.TextStrokeTransparency = 0
	gui.Parent = player:WaitForChild("PlayerGui")
	buildMarker()
end

-- A pass landed: "+N" pops on every screen (rule 2). N is what the fuse really gained (TagVerdict.gained, H7): the
-- whole bonus, or less when the cap (tag.md §5) cut it, which says so. No number at all if the server sent none.
function Hud.pass(v: any, me: number)
	if not popLabel then return end
	local who = if v.to == me then "you" else Hud.nameOf(v.to)
	local gained = v.gained
	if type(gained) ~= "number" then
		popLabel.Text = ("->  %s"):format(who)
	elseif gained >= Config.FUSE_PASS_BONUS - 0.05 then
		-- From gained, never from Config (tag.md §5, N7): %d on a non-integer bonus would throw inside the handler (QA round 2).
		popLabel.Text = ("+%gs  ->  %s"):format(math.floor(gained * 10 + 0.5) / 10, who)
	else
		popLabel.Text = ("+%.1fs, capped  ->  %s"):format(math.max(0, gained), who)
	end
	popAt = os.clock()
end

-- H15: a spook landed (GhostVerdict): "-3s  <ghost>" pops on every screen, in ghost blue. The number is what really
-- came off (`drained`, → N7), never Config.
function Hud.spook(v: any, me: number)
	if not popLabel then return end
	local who = if v.from == me then "you" else Hud.nameOf(v.from)
	popLabel.Text = ("-%gs  %s%s"):format(math.floor(v.drained * 10 + 0.5) / 10, who, if v.to == me then " spooked you" else "")
	popLabel.TextColor3 = GHOST_BLUE
	popAt = os.clock()
end

-- H15: a ghost coming back shows as a runner newly alive in the same round (no event needed: MatchState carries it).
local function noticeComebacks(state: any, me: number, now: number)
	local alive = {}
	for _, id in state.alive do alive[id] = true end
	if seen.round == state.round then
		for id in alive do
			if not seen.alive[id] then
				backText = if id == me then "YOU'RE BACK!" else (Hud.nameOf(id) .. " is back!")
				backAt = now
			end
		end
	end
	seen.round, seen.alive = state.round, alive
end

-- A ghost's own line (rule 38): what to do, whether the spook is ready, and the comeback.
local function ghostLine(state: any, e: any, me: number): string
	local since = os.clock() - (state.at or os.clock())
	local ready, ward = math.max(0, e.ready - since), math.max(0, (state.ward or 0) - since)
	local now = if ready > 0 then ("ready in %.1f"):format(ready) elseif ward > 0 then ("ward %.1f"):format(ward)
		else "READY"
	local back = if state.mark == me then "you hold the mark" elseif e.comebacks > 0 then "comeback left"
		else "no comeback left"
	return ("GHOST: touch %s for -%gs  |  %s  |  %s"):format(Hud.nameOf(state.it), Config.SPOOK_DRAIN, now, back)
end

-- Every frame, from the client's view of the server's state (client/Tagging.lua).
function Hud.update(state: any, me: number, fuseLeft: number, frozenLeft: number)
	if not fuseLabel then return end
	local now = os.clock()
	local pop = now - popAt
	popLabel.TextTransparency = math.clamp((pop - POP_TIME * 0.6) / (POP_TIME * 0.4), 0, 1)
	-- The holder's wait: a big count to GO on their screen; everyone else is told to run.
	local waiting = state ~= nil and not state.over and frozenLeft > 0
	if wasWaiting and not waiting then goAt = now end
	wasWaiting = waiting
	if waiting and state.it == me then
		countLabel.Text = ("%.1f"):format(frozenLeft)
		countLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	elseif waiting and table.find(state.alive, me) then -- a ghost or a spectator has nothing to run from
		countLabel.Text = "RUN!"
		countLabel.TextColor3 = Color3.new(1, 1, 1)
	elseif now - goAt < GO_TIME and state ~= nil and state.it == me then
		countLabel.Text = "GO!"
		countLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
	else
		countLabel.Text = ""
	end
	if now - popAt > POP_TIME then popLabel.TextColor3 = POP_GOLD end
	markLabel.Text = ""
	if not state then
		fuseLabel.Text, statusLabel.Text = "", "waiting for the round"
		placeMarker(nil, 0)
		return
	end
	noticeComebacks(state, me, now)
	if now - backAt < BACK_TIME and not (waiting and state.it == me) then -- over "RUN!", not over your own count
		countLabel.Text = backText
		countLabel.TextColor3 = GHOST_BLUE
	end
	local inRound = table.find(state.alive, me) ~= nil
	local myGhost = nil
	if type(state.ghosts) == "table" then
		for _, e in state.ghosts do if e.id == me then myGhost = e end end
	end
	if state.over then
		fuseLabel.Text = ""
		statusLabel.Text = if state.winner == me then "you win the round!"
			elseif state.winner then (Hud.nameOf(state.winner) .. " wins the round")
			elseif state.held then "waiting for players" else "round over"
		placeMarker(nil, 0)
		return
	end
	local mine = state.it == me
	fuseLabel.Text = ("%s  %.1f"):format(if mine then "YOU'RE IT" else (Hud.nameOf(state.it) .. " is it"), fuseLeft)
	fuseLabel.TextColor3 = if mine then Color3.fromRGB(255, 90, 70) else Color3.new(1, 1, 1)
	if mine and frozenLeft > 0 then
		statusLabel.Text = "you're it: wait for GO"
	elseif frozenLeft > 0 and inRound then
		statusLabel.Text = ("%s is it: run!"):format(Hud.nameOf(state.it))
	elseif myGhost then
		statusLabel.Text = ghostLine(state, myGhost, me)
	elseif not inRound and type(state.spectating) == "table" and table.find(state.spectating, me) then
		statusLabel.Text = "next round soon" -- joined after this round began (H8): waiting, not eliminated
	elseif not inRound then
		statusLabel.Text = "out (next round soon)"
	else
		statusLabel.Text = ""
	end
	if state.mark then -- rule 39: everyone sees who comes back if the fuse runs out now
		markLabel.Text = if state.mark == me then "you hold the mark: if the fuse runs out, you're back"
			else ("marked by %s: back if the fuse runs out"):format(Hud.nameOf(state.mark))
	end
	local warded = (state.ward or 0) - (now - (state.at or now)) > 0 and #state.ghosts > 0
	local holder = if state.it then rootOf(state.it) else nil
	placeMarker(holder and Others.positionOf(holder), 0.5 + 0.5 * math.sin(now * MARKER_PULSE * 2 * math.pi), warded)
end

return Hud
