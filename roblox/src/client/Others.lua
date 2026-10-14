-- Draws every OTHER runner on this screen (H11, docs/systems/players.md §3; H14, netcode.md §8). Each runner's client
-- draws only its own body (Look is local, never replicated), so without this a second player is an invisible box.
-- Each other runner gets its own Look, placed every render frame from the SNAPSHOT STREAM: the batch the server
-- relays over Remotes.Snapshot, read Config.SNAPSHOT_DELAY behind its newest point (shared/Snapshot). The sprite,
-- facing and juice ride the same snapshots, so nothing is inferred. A runner with no stream (the Studio stand-in,
-- a client that stopped sending) falls back to H13's path: its replicated root through the draw trail, posed by
-- shared/RemotePose. Cosmetic only: nothing here is sent anywhere or decides anything. The Studio dummy (-1000, no
-- stream) is drawn the same way through the fallback path, so solo Play exercises it (Danzo, 2026-10-14).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Movement = require(Shared:WaitForChild("Movement"))
local RemotePose = require(Shared:WaitForChild("RemotePose"))
local Snapshot = require(Shared:WaitForChild("Snapshot"))
local Look = require(script.Parent:WaitForChild("Look"))

local Others = {}

local RUNNER_TAG = "RotagRunner" -- server/Runners.lua Runners.TAG
local HW, HH = Config.RUNNER_WIDTH / 2, Config.RUNNER_HEIGHT / 2
local GROUND_PROBE = 2 -- studs below the feet: enough to tell standing from airborne (fallback path only)
local WALL_PROBE = Movement.wallReach() + 0.1
local INSET = 0.1
local LOG_EVERY = 5 -- Studio only: seconds between one line per other runner about how its stream arrives
local studio = game:GetService("RunService"):IsStudio()

type Drawn = { id: number, root: BasePart, look: any, params: RaycastParams, pose: RemotePose.Pose,
	trail: RemotePose.Trail, prevT: number, at: Vector3, streamed: boolean, logged: number,
	lunge: { x0: number, y0: number, tx: number, ty: number, t0: number }? }
local drawn: { [Model]: Drawn } = {}
local byId: { [number]: Model } = {}
local byRoot: { [BasePart]: Vector3 } = {} -- where each other runner was drawn this frame (the IT marker, the claim)
local streams: { [number]: Snapshot.Stream } = {}
local player: Player? = nil
local me = 0

local function shortest(origins: { Vector3 }, dir: Vector3, half: number, params: RaycastParams): number?
	local best = nil
	for _, origin in origins do
		local hit = workspace:Raycast(origin, dir, params)
		if hit and (best == nil or hit.Distance - half < best) then best = hit.Distance - half end
	end
	return best
end

local function add(model: Instance)
	if not model:IsA("Model") or drawn[model] then return end
	local id = model:GetAttribute("RunnerId")
	if type(id) ~= "number" then return end -- the Studio dummy (-1000) is drawn too: its box is hidden below
	if player and model == player.Character then return end -- our own runner: Client.client.lua draws it
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (root and root:IsA("BasePart") and model.Parent) or drawn[model] then return end
	if id <= -1000 then root.Transparency = 1 end -- the dummy's orange box: the sprite replaces it (client-side only)
	if player and model == player.Character then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	params.CollisionGroup = root.CollisionGroup -- runners pass through runners (players.md §2)
	local p = root.Position
	local now = os.clock()
	drawn[model] = { id = id, root = root, look = Look.new(model, root, true), params = params,
		pose = RemotePose.new(p.X, p.Y), trail = RemotePose.newTrail(now, p.X, p.Y), prevT = now, at = p,
		streamed = false, logged = now, lunge = nil }
	byId[id] = model
end

local function remove(model: Instance)
	local d = drawn[model :: Model]
	if not d then return end
	drawn[model :: Model] = nil
	byRoot[d.root] = nil
	if byId[d.id] == model then byId[d.id] = nil end
	d.look:destroy()
end

-- The fallback (H13): the replicated root through the trail, the pose inferred by RemotePose from probes.
local function fromBody(d: Drawn, now: number, dt: number): (number, number, string, number, boolean, number)
	local p = d.root.Position
	RemotePose.push(d.trail, now, p.X, p.Y, d.prevT)
	d.prevT = now
	local x, y = RemotePose.drawAt(d.trail, now)
	local below = { Vector3.new(x - HW + INSET, y, 0), Vector3.new(x, y, 0), Vector3.new(x + HW - INSET, y, 0) }
	local side = { Vector3.new(x, y - HH + 0.2, 0), Vector3.new(x, y, 0), Vector3.new(x, y + HH - 0.2, 0) }
	local ground = shortest(below, Vector3.new(0, -(HH + GROUND_PROBE), 0), HH, d.params)
	local wall = shortest(side, Vector3.new(-(HW + WALL_PROBE), 0, 0), HW, d.params) ~= nil
		or shortest(side, Vector3.new(HW + WALL_PROBE, 0, 0), HW, d.params) ~= nil
	local sprite, events = RemotePose.step(d.pose, x, y, ground, wall, dt)
	d.look:react(events)
	return x, y, sprite, d.pose.facing, d.pose.dashTime > 0, d.pose.vx
end

local function log(model: Model, d: Drawn, now: number, st: Snapshot.Stream?)
	if not studio or now - d.logged < LOG_EVERY then return end
	d.logged = now
	if st and d.streamed then
		local count, gap, starved, frames = Snapshot.stats(st)
		print(("[Rotag] others: %s stream %.0f snapshots/s, longest gap %.0f ms, starved %d of %d frames"):format(
			model.Name, count / LOG_EVERY, gap * 1000, starved, frames))
	else
		print(("[Rotag] others: %s has no stream: drawn from its body through the trail"):format(model.Name))
	end
end

-- Every render frame, after the camera.
function Others.draw(dt: number)
	local now = os.clock()
	for model, d in drawn do
		if not d.root.Parent or (player and model == player.Character) then
			remove(model)
			continue
		end
		local st = streams[d.id]
		local v = if st and now - st.lastLocal <= Config.SNAPSHOT_STALE then Snapshot.at(st, now) else nil
		local x, y, sprite, facing, dashing, vx
		if v then
			x, y, sprite, facing, dashing, vx = v.x, v.y, v.sprite, v.facing, v.dashing, v.vx
			d.look:react(v.events)
		else
			x, y, sprite, facing, dashing, vx = fromBody(d, now, dt)
		end
		d.streamed = v ~= nil
		log(model, d, now, st)
		-- Rule 6's catch-up (H14): on a verdict the tagger's sprite goes to the victim over TAG_LUNGE_TIME, then eases
		-- back onto its stream over the same time, so the tag reads as a touch on the victim's screen too.
		local L = d.lunge
		if L then
			local k = (now - L.t0) / Config.TAG_LUNGE_TIME
			if k < 1 then
				local e = 1 - (1 - k) ^ 2
				x, y = L.x0 + (L.tx - L.x0) * e, L.y0 + (L.ty - L.y0) * e
			elseif k < 2 then
				x, y = L.tx + (x - L.tx) * (k - 1), L.ty + (y - L.ty) * (k - 1)
			else
				d.lunge = nil
			end
		end
		d.at = Vector3.new(x, y, 0)
		byRoot[d.root] = d.at
		d.look:place(x, y)
		d.look:draw(sprite, facing, dashing, vx, dt)
	end
end

-- Where another runner's sprite is drawn (its stream spot), or the root's own position for our runner and the dummy.
function Others.positionOf(root: BasePart): Vector3
	return byRoot[root] or root.Position
end

-- A tag landed (TagVerdict): `from` lunges to `to`. Our own sprite is welded to our body and we saw the touch
-- ourselves, so only another runner's drawing moves.
function Others.lunge(from: any, to: any)
	if Config.TAG_LUNGE_TIME <= 0 or from == me then return end
	local model = byId[from]
	local d = model and drawn[model]
	if not d then return end
	local tx, ty
	if to == me then
		local ch = player and player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then tx, ty = root.Position.X, root.Position.Y end
	else
		local tm = byId[to]
		local td = tm and drawn[tm]
		if td then tx, ty = td.at.X, td.at.Y end
	end
	if not (tx and ty) then return end
	d.lunge = { x0 = d.at.X, y0 = d.at.Y, tx = tx, ty = ty, t0 = os.clock() }
end

-- The server's relay: { [runner id] = { t = server stamp, b = that client's snapshot } }. Shape-checked, our own id
-- skipped; Snapshot.push drops anything older than what is already here.
function Others.listen(remote: UnreliableRemoteEvent)
	remote.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" then return end
		local now = os.clock()
		for key, e in pairs(batch) do
			-- A dictionary's number keys arrive as STRINGS through a remote (seen in Studio: "key -2 is a string"), → N13.
			local id = tonumber(key)
			if id and id ~= me and type(e) == "table" and type(e.t) == "number" then
				local s = Snapshot.unpack(e.b)
				if s then
					local st = streams[id]
					if not st then
						st = Snapshot.newStream()
						streams[id] = st
					end
					Snapshot.push(st, e.t, now, s)
				end
			end
		end
	end)
end

-- The sheet ids landed late (Remotes.SheetIds): every other runner re-applies its sprite on the next draw too.
function Others.refresh()
	for _, d in drawn do d.look:refresh() end
end

function Others.start(localPlayer: Player)
	player = localPlayer
	me = localPlayer.UserId
	CollectionService:GetInstanceAddedSignal(RUNNER_TAG):Connect(function(m) task.spawn(add, m) end)
	CollectionService:GetInstanceRemovedSignal(RUNNER_TAG):Connect(remove)
	for _, m in CollectionService:GetTagged(RUNNER_TAG) do task.spawn(add, m) end
end

return Others
