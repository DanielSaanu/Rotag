-- The snapshot stream (H14, docs/systems/netcode.md §8): how one runner's motion reaches every other screen, and the
-- server's tag record. The owning client packs its Movement state (position, velocity, sprite, facing, the juice
-- events since the last one) into a 13-byte buffer Config.SNAPSHOT_RATE times a second; the server stamps each on
-- arrival, keeps the newest as that runner's position, and relays the batch; every other client keeps a short buffer
-- and draws Config.SNAPSHOT_DELAY behind the newest, sliding between the two snapshots around that moment. Roblox's own
-- physics replication smooths a CFrame-driven body into ~0.4 s of lag (netcode.md §3); a remote arrives at once (N6).
-- Pure Luau (`buffer` is a language builtin, not a Roblox API); tests: test/luau/snapshot.test.luau.
local Config = require(script.Parent.Config)

local Snapshot = {}

-- Every name Movement.spriteFor can return, in a fixed order: the wire carries the index. Unknown on the wire = idle.
Snapshot.SPRITES = { "runner_idle", "runner_jump_rise", "runner_jump_apex", "runner_fall", "runner_dash" }
for i = 0, Config.RUN_FRAMES - 1 do table.insert(Snapshot.SPRITES, "runner_run_" .. tostring(i)) end
local SPRITE_INDEX = {}
for i, name in Snapshot.SPRITES do SPRITE_INDEX[name] = i end
local JUMPS = { "ground", "double", "wall" }
local JUMP_INDEX = { ground = 1, double = 2, wall = 3 }

Snapshot.SIZE = 13 -- bytes: u16 seq, i16 x, i16 y, i16 vx, i16 vy, u8 sprite, u8 flags, u8 landed
local POS_SCALE = 16 -- 1/16 stud: +-2047 studs (the arena is a few hundred)
local VEL_SCALE = 8 -- 1/8 stud/s: +-4095 studs/s (a dash is 120)
local I16 = 32767
local SEQ_MOD = 65536

export type Snap = {
	seq: number, x: number, y: number, vx: number, vy: number, sprite: string, facing: number, dashing: boolean,
	jump: string?, dash: boolean, landed: number?,
}

local function q(v: number, scale: number): number
	return math.clamp(math.floor(v * scale + 0.5), -I16, I16)
end

function Snapshot.pack(s: Snap): buffer
	local b = buffer.create(Snapshot.SIZE)
	buffer.writeu16(b, 0, s.seq % SEQ_MOD)
	buffer.writei16(b, 2, q(s.x, POS_SCALE))
	buffer.writei16(b, 4, q(s.y, POS_SCALE))
	buffer.writei16(b, 6, q(s.vx, VEL_SCALE))
	buffer.writei16(b, 8, q(s.vy, VEL_SCALE))
	buffer.writeu8(b, 10, SPRITE_INDEX[s.sprite] or 1)
	local flags = (if s.facing < 0 then 1 else 0) + (if s.dashing then 2 else 0)
		+ (if s.jump then (JUMP_INDEX[s.jump] or 0) * 4 else 0) + (if s.dash then 16 else 0)
	buffer.writeu8(b, 11, flags)
	buffer.writeu8(b, 12, math.clamp(math.floor((s.landed or 0) + 0.5), 0, 255))
	return b
end

-- nil for anything that is not exactly one snapshot: the wrong type, the wrong size, a sprite index off the list.
function Snapshot.unpack(b: any): Snap?
	if type(b) ~= "buffer" or buffer.len(b) ~= Snapshot.SIZE then return nil end
	local sprite = Snapshot.SPRITES[buffer.readu8(b, 10)]
	if not sprite then return nil end
	local flags = buffer.readu8(b, 11)
	local landed = buffer.readu8(b, 12)
	return {
		seq = buffer.readu16(b, 0),
		x = buffer.readi16(b, 2) / POS_SCALE, y = buffer.readi16(b, 4) / POS_SCALE,
		vx = buffer.readi16(b, 6) / VEL_SCALE, vy = buffer.readi16(b, 8) / VEL_SCALE,
		sprite = sprite, facing = if flags % 2 == 1 then -1 else 1, dashing = math.floor(flags / 2) % 2 == 1,
		jump = JUMPS[math.floor(flags / 4) % 4], dash = math.floor(flags / 16) % 2 == 1,
		landed = if landed > 0 then landed else nil,
	}
end

-- Sequence numbers wrap at 65536: `seq` is newer than `last` if it is ahead by less than half the ring.
function Snapshot.newer(seq: number, last: number): boolean
	local d = (seq - last) % SEQ_MOD
	return d > 0 and d < SEQ_MOD / 2
end

-- The server's rate limit per sender (like TagClaim's gap): a token bucket at 1.5 x the send rate with a small burst,
-- so a short stall followed by the queued snapshots is let through and a flood is not.
local LIMIT_RATE = Config.SNAPSHOT_RATE * 1.5
local LIMIT_BURST = 8
export type Limiter = { tokens: number, t: number }

function Snapshot.newLimiter(now: number): Limiter
	return { tokens = LIMIT_BURST, t = now }
end

function Snapshot.allow(l: Limiter, now: number): boolean
	l.tokens = math.min(LIMIT_BURST, l.tokens + math.max(0, now - l.t) * LIMIT_RATE)
	l.t = now
	if l.tokens < 1 then return false end
	l.tokens -= 1
	return true
end

-- The receiving client's buffer. Points carry the SERVER's arrival stamp; `offset` maps that clock onto this screen's
-- (an average of local arrival minus stamp, so the draw clock runs smoothly through jitter), and the drawing reads the
-- buffer at local now - offset - Config.SNAPSHOT_DELAY. A snapshot that jumps TELEPORT studs (a respawn, a round start,
-- a snap-back) empties the buffer so the sprite snaps instead of sliding across the map.
export type Point = { t: number, s: Snap }
export type Stream = {
	points: { Point }, offset: number?, lastSeq: number?, lastLocal: number, eventT: number?,
	count: number, longestGap: number, lastT: number?, starved: number, frames: number, -- Studio log counters
}
local OFFSET_K = 0.1 -- how much of each arrival's offset is taken: ~10 snapshots to settle, ~0.3 s at 30 Hz
local OFFSET_RESET = 1 -- seconds off the running offset: a clock jump (a long stall), start over
local KEEP = 1 -- seconds of points kept behind the newest (a claim's whole window is shorter)
local TELEPORT = 20 -- studs between two snapshots: not a move

function Snapshot.newStream(): Stream
	return { points = {}, offset = nil, lastSeq = nil, lastLocal = -math.huge, eventT = nil,
		count = 0, longestGap = 0, lastT = nil, starved = 0, frames = 0 }
end

-- A snapshot stamped `serverT` arrived at local time `localT`. False if it is older than one already here.
function Snapshot.push(st: Stream, serverT: number, localT: number, s: Snap): boolean
	if st.lastSeq ~= nil and not Snapshot.newer(s.seq, st.lastSeq) then return false end
	st.lastSeq = s.seq
	local off = localT - serverT
	if st.offset == nil or math.abs(off - st.offset) > OFFSET_RESET then st.offset = off
	else st.offset += (off - st.offset) * OFFSET_K end
	local pts = st.points
	local last = pts[#pts]
	if last and (math.abs(s.x - last.s.x) > TELEPORT or math.abs(s.y - last.s.y) > TELEPORT) then
		st.points = { { t = serverT, s = s } }
		st.eventT = serverT
	else
		if last and serverT <= last.t then serverT = last.t + 1e-6 end -- two in one server frame: keep the order
		table.insert(pts, { t = serverT, s = s })
		while #pts > 2 and pts[2].t < serverT - KEEP do table.remove(pts, 1) end
	end
	if st.lastT then st.longestGap = math.max(st.longestGap, serverT - st.lastT) end
	st.lastT, st.count, st.lastLocal = serverT, st.count + 1, localT
	return true
end

-- What to draw at local time `now`: position, velocity, sprite, facing, dashing, and the juice events of every
-- snapshot the draw clock passed since the last call (each once). Nil until the first snapshot. Past the newest point
-- (a lost packet, a sender pause, a stop) it holds there: never ahead of what was sent (netcode.md §4).
export type View = { x: number, y: number, vx: number, vy: number, sprite: string, facing: number, dashing: boolean,
	events: { jump: string?, dash: boolean?, landed: number? }, behind: number }
function Snapshot.at(st: Stream, now: number): View?
	local pts = st.points
	local n = #pts
	if n == 0 or st.offset == nil then return nil end
	local t = now - st.offset - Config.SNAPSHOT_DELAY
	st.frames += 1
	local events = {}
	local from = st.eventT or t
	for _, p in pts do
		if p.t > from and p.t <= t then
			local s = p.s
			if s.jump then events.jump = s.jump end
			if s.dash then events.dash = true end
			if s.landed then events.landed = math.max(events.landed or 0, s.landed) end
		end
	end
	st.eventT = math.max(from, t)
	local a, b, k = pts[n], pts[n], 0
	if t >= pts[n].t then
		st.starved += 1
	elseif t <= pts[1].t then
		a, b = pts[1], pts[1]
	else
		for i = n - 1, 1, -1 do
			if pts[i].t <= t then
				a, b = pts[i], pts[i + 1]
				k = (t - a.t) / (b.t - a.t)
				break
			end
		end
	end
	local sa, sb = a.s, b.s
	return {
		x = sa.x + (sb.x - sa.x) * k, y = sa.y + (sb.y - sa.y) * k,
		vx = sa.vx + (sb.vx - sa.vx) * k, vy = sa.vy + (sb.vy - sa.vy) * k,
		sprite = sa.sprite, facing = sa.facing, dashing = sa.dashing, events = events,
		behind = pts[n].t - t,
	}
end

-- Studio log helper: the stream's counters since the last call, reset.
function Snapshot.stats(st: Stream): (number, number, number, number)
	local count, gap, starved, frames = st.count, st.longestGap, st.starved, st.frames
	st.count, st.longestGap, st.starved, st.frames = 0, 0, 0, 0
	return count, gap, starved, frames
end

return Snapshot
