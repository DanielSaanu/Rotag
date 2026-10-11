-- The tag HUD (DESIGN §3 rule 2, "make the fuse readable"; docs/systems/tag.md §6): the fuse readout at the top
-- centre (rule 23 keeps the lower middle clear), a "+N" pop at every pass, a big red glowing triangle over the
-- holder, one status line (out, round over), and a big countdown to GO while the holder waits (start or pass freeze,
-- H6). Placeholder UI, not art: the growing, beeping bomb comes with the art pass.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
local gui, fuseLabel, statusLabel, popLabel, countLabel = nil, nil, nil, nil, nil
local halves: { BasePart } = {} -- the solid triangle's two wedges, then the halo's two
local popAt, goAt, wasWaiting = -math.huge, -math.huge, false

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
	if id < -999 then return DUMMY_NAME end
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
local function placeMarker(at: Vector3?, pulse: number)
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
			if i > 2 then p.Transparency = 0.55 + 0.3 * pulse end
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
		popLabel.Text = ("+%ds  ->  %s"):format(Config.FUSE_PASS_BONUS, who)
	else
		popLabel.Text = ("+%.1fs, capped  ->  %s"):format(math.max(0, gained), who)
	end
	popAt = os.clock()
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
	elseif waiting then
		countLabel.Text = "RUN!"
		countLabel.TextColor3 = Color3.new(1, 1, 1)
	elseif now - goAt < GO_TIME and state ~= nil and state.it == me then
		countLabel.Text = "GO!"
		countLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
	else
		countLabel.Text = ""
	end
	if not state then
		fuseLabel.Text, statusLabel.Text = "", "waiting for the round"
		placeMarker(nil, 0)
		return
	end
	local inRound = table.find(state.alive, me) ~= nil
	if state.over then
		fuseLabel.Text = ""
		statusLabel.Text = if state.winner == me then "you win the round!"
			elseif state.winner then (Hud.nameOf(state.winner) .. " wins the round") else "round over"
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
	elseif not inRound then
		statusLabel.Text = "out (next round soon)"
	else
		statusLabel.Text = ""
	end
	local holder = if state.it then rootOf(state.it) else nil
	placeMarker(holder and holder.Position, 0.5 + 0.5 * math.sin(now * MARKER_PULSE * 2 * math.pi))
end

return Hud
