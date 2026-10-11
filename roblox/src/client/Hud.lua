-- The tag HUD (DESIGN §3 rule 2, "make the fuse readable"; docs/systems/tag.md §6): the fuse readout at the top
-- centre (rule 23 keeps the lower middle clear), a "+5" pop at every pass, an IT marker over the holder, and one
-- status line (frozen, out, round over). Placeholder text, not art: the growing, beeping bomb comes with the art pass.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = {}

local RUNNER_TAG = "RotagRunner"
local DUMMY_NAME = "Dummy"
local POP_TIME = 1.2
local gui, fuseLabel, statusLabel, popLabel, marker = nil, nil, nil, nil, nil
local popAt = -math.huge

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

function Hud.start(player: Player)
	gui = Instance.new("ScreenGui")
	gui.Name = "RotagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	fuseLabel = label(gui, 8, 40, 32)
	popLabel = label(gui, 48, 32, 28)
	popLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	statusLabel = label(gui, 82, 24, 18)
	gui.Parent = player:WaitForChild("PlayerGui")
	marker = Instance.new("BillboardGui")
	marker.Name = "RotagItMarker"
	marker.Size = UDim2.new(0, 60, 0, 28)
	marker.StudsOffset = Vector3.new(0, Config.RUNNER_HEIGHT / 2 + 2.5, 0)
	marker.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 80, 60)
	text.TextStrokeTransparency = 0
	text.Text = "IT"
	text.Parent = marker
	marker.Parent = gui -- adornee set per state; a BillboardGui in PlayerGui draws at its Adornee
end

-- A pass landed: "+5" pops on every screen (rule 2).
function Hud.pass(v: any, me: number)
	if not popLabel then return end
	local who = if v.to == me then "you" else Hud.nameOf(v.to)
	popLabel.Text = ("+%ds  ->  %s"):format(Config.FUSE_PASS_BONUS, who)
	popAt = os.clock()
end

-- Every frame, from the client's view of the server's state (client/Tagging.lua).
function Hud.update(state: any, me: number, fuseLeft: number, frozenLeft: number)
	if not fuseLabel then return end
	local pop = os.clock() - popAt
	popLabel.TextTransparency = math.clamp((pop - POP_TIME * 0.6) / (POP_TIME * 0.4), 0, 1)
	if not state then
		fuseLabel.Text, statusLabel.Text = "", "waiting for the round"
		marker.Adornee = nil
		return
	end
	local inRound = table.find(state.alive, me) ~= nil
	if state.over then
		fuseLabel.Text = ""
		statusLabel.Text = if state.winner == me then "you win the round!"
			elseif state.winner then (Hud.nameOf(state.winner) .. " wins the round") else "round over"
		marker.Adornee = nil
		return
	end
	local mine = state.it == me
	fuseLabel.Text = ("%s  %.1f"):format(if mine then "YOU'RE IT" else (Hud.nameOf(state.it) .. " is it"), fuseLeft)
	fuseLabel.TextColor3 = if mine then Color3.fromRGB(255, 90, 70) else Color3.new(1, 1, 1)
	if mine and frozenLeft > 0 then
		statusLabel.Text = ("frozen %.1f"):format(frozenLeft)
	elseif not inRound then
		statusLabel.Text = "out (next round soon)"
	else
		statusLabel.Text = ""
	end
	marker.Adornee = if state.it then rootOf(state.it) else nil
end

return Hud
