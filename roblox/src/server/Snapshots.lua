-- The server's end of the snapshot stream (H14, docs/systems/netcode.md §8). Each client sends its runner's state
-- over Remotes.Snapshot (an UnreliableRemoteEvent, shared/Snapshot packs it); here each one is rate-limited, size-
-- checked, stamped with the SERVER's clock on arrival (a client's clock is never read), kept as that runner's newest
-- position for Match's tag record and speed check, and relayed to every client in one batch per Heartbeat. Trust is
-- unchanged from H12 (trust.md §2): this is still the client's word about its own position, bounded by MoveCheck;
-- what changed is the carrier, from Roblox's smoothed physics replication (~0.4 s late) to a remote (~a frame).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Snapshot = require(Shared:WaitForChild("Snapshot"))
local ItemRules = require(Shared:WaitForChild("Items"))

local Snapshots = {}

-- After the server builds a runner a new body (join, round start, snap-back), snapshots the client sent about the OLD
-- body may still be in flight: until one lands within ACCEPT studs of the new body (or SPAWN_GRACE passes), they are
-- dropped, and the newest position is cleared so Match reads the body the server placed (trusted, MoveCheck restarts).
local ACCEPT = 8
local SPAWN_GRACE = 1

local remote: UnreliableRemoteEvent? = nil
local latest: { [number]: { x: number, y: number, vx: number, vy: number, t: number } } = {}
local lastSeq: { [number]: number } = {}
local limiters: { [number]: Snapshot.Limiter } = {}
local grace: { [number]: { x: number, y: number, until_: number } } = {}
local batch: { [number]: { t: number, b: buffer } } = {}
local dirty = false
-- H19 (items.md §3): the facing each stream reports (where Use puts a crate or a beam), and when the server saw each
-- runner's last COUNTED dash start (rule 45's i-frames; Items.dashSeen enforces the dash cooldown on the server).
local facing: { [number]: number } = {}
local dashAt: { [number]: number } = {}
local wasDashing: { [number]: boolean } = {}

local function onSnapshot(player: Player, b: any)
	local id = player.UserId
	local now = os.clock()
	local l = limiters[id]
	if not l then
		l = Snapshot.newLimiter(now)
		limiters[id] = l
	end
	if not Snapshot.allow(l, now) then return end
	local s = Snapshot.unpack(b)
	if not s then return end
	local last = lastSeq[id]
	if last ~= nil and not Snapshot.newer(s.seq, last) then return end
	local g = grace[id]
	if g then
		if now < g.until_ and (math.abs(s.x - g.x) > ACCEPT or math.abs(s.y - g.y) > ACCEPT) then return end
		grace[id] = nil
	end
	lastSeq[id] = s.seq
	latest[id] = { x = s.x, y = s.y, vx = s.vx, vy = s.vy, t = now }
	facing[id] = s.facing
	local started = s.dash or (s.dashing and not wasDashing[id]) -- the event, or the flag rising if that packet was lost
	wasDashing[id] = s.dashing
	if started and ItemRules.dashSeen(dashAt[id], now) then dashAt[id] = now end
	batch[id] = { t = now, b = b }
	dirty = true
end

-- The runner's newest snapshot position, or nil when none has arrived for Config.SNAPSHOT_STALE (then Match reads
-- the body, as before H14). `now` is the server clock.
function Snapshots.positionOf(id: number, now: number): (number?, number?)
	local s = latest[id]
	if not s or now - s.t > Config.SNAPSHOT_STALE then return nil, nil end
	return s.x, s.y
end

-- The server just built runner `id` a body at (x, y).
function Snapshots.bodyBuilt(id: number, x: number, y: number, now: number)
	latest[id] = nil
	grace[id] = { x = x, y = y, until_ = now + SPAWN_GRACE }
end

function Snapshots.forget(id: number)
	latest[id], lastSeq[id], limiters[id], grace[id], batch[id] = nil, nil, nil, nil, nil
	facing[id], dashAt[id], wasDashing[id] = nil, nil, nil
end

-- H19: the facing the runner's stream last reported (+1 right, -1 left; 1 with no stream), and whether a dash the
-- server counted is in its i-frames at `now` (rule 45).
function Snapshots.facingOf(id: number): number return facing[id] or 1 end
function Snapshots.iframed(id: number, now: number): boolean return ItemRules.iframed(dashAt[id], now) end

-- One batch to everyone per Heartbeat: { [runner id] = { t = server stamp, b = the client's buffer } }. Each client
-- skips its own id. Four runners are ~150 bytes, well inside the unreliable limit (900).
local function relay()
	if not (dirty and remote) then return end
	remote:FireAllClients(batch)
	batch, dirty = {}, false
end

function Snapshots.start(r: UnreliableRemoteEvent?)
	remote = r
	if not r then
		warn("[Rotag] ReplicatedStorage.Remotes.Snapshot is missing (restart rojo serve to sync default.project.json);"
			.. " other runners draw from the body and tags are judged on it")
		return
	end
	r.OnServerEvent:Connect(onSnapshot)
	Players.PlayerRemoving:Connect(function(player) Snapshots.forget(player.UserId) end)
	RunService.Heartbeat:Connect(relay)
end

return Snapshots
