-- Use and holds on this client (H19, DESIGN §3 rules 42, 44; docs/systems/items.md §6). It DECIDES nothing: a Use
-- press goes to the server as Remotes.UseItem (one small integer, 0 now: the fixture rotation in PR 4) and the server
-- judges it on its own state and position record; a hold arrives on ItemEvent (client/Items keeps it) and is applied
-- here to the local runner's Movement input. While trapped, every press (any key, click, pad button, a tap anywhere)
-- goes out as a UseItem too, and the server counts the three that pry the trap open (no gap during a trap,
-- Items.acceptPress); this client stays pinned until the server's `free` arrives. A cheating client can ignore a
-- hold; the server's speed check holds it to it (shared/MoveCheck.hold, trust.md §10).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Items = require(script.Parent:WaitForChild("Items"))

local Use = {}

local WAIT = 10
local SEND_GAP = 0.06 -- above the server's USE_GAP, so an honest press is never dropped (→ N4)
local remote: RemoteEvent? = nil
local me = 0
local lastSent = -math.huge
local current: any = nil -- the hold this client last applied, to fix the stumble's direction once
local dir = 1

local function send(): boolean
	local now = os.clock()
	if not remote or now - lastSent < SEND_GAP then return false end
	lastSent = now
	remote:FireServer(0)
	return true
end

-- Every physics frame, after Controls.read: strips Use's fields from `input`, sends a Use or a pry, and writes the
-- local hold into input.hold / holdDir / holdLeft for shared/Movement. `s` is the local Movement state; `frozen`: the
-- tag freeze (no item starts during it either, rule 44).
function Use.frame(input: any, s: any, frozen: boolean)
	local pressed, presses = input.usePressed, input.presses or 0
	input.usePressed, input.presses = nil, nil
	local h = Items.holdOf(me)
	if not h then
		current = nil
		local item = Items.held(me)
		if pressed and not frozen and item and item ~= "hex" then send() end
		return
	end
	if h ~= current then -- a new hold: a stumble carries on the way the runner was going when it landed
		current = h
		dir = if s.vx > 0.5 then 1 elseif s.vx < -0.5 then -1 else s.facing
	end
	-- QA round 1: the client never frees itself. It stays pinned until the server's `free` (a ping after its third
	-- press) or its own timer, so it can never run while the server still holds it (that was a snap-back).
	if h.kind == "trap" and presses > 0 and h.presses < Config.TRAP_PRESSES and send() then
		h.presses += 1
	end
	input.hold, input.holdDir, input.holdLeft = h.kind, dir, h.untilT - os.clock()
end

function Use.start(player: Player)
	me = player.UserId
	task.spawn(function() -- never blocks the client (→ N3); an old rojo serve lacks the remote (→ T6)
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		local r = remotes and remotes:WaitForChild("UseItem", WAIT)
		if r and r:IsA("RemoteEvent") then
			remote = r
		else
			warn("[Rotag] no Remotes.UseItem (restart rojo serve); Use and prying a trap do nothing on this client")
		end
	end)
end

return Use
