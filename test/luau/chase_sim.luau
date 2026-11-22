-- H40 measurement harness (not a test: run with `node test/luau/sim.js chase_sim.luau`). Two clients and the server,
-- frame by frame at 60 Hz, through the REAL shared code: each client sends Snapshot packets at SNAPSHOT_RATE over its
-- own link (delay + jitter), the server keeps the newest one per runner and samples it every frame (Match.sample),
-- relays to the other client, which draws through Snapshot.Stream; the tagger's client claims on a touch of what it
-- DRAWS (Tagging.claim), the claim crosses the link, and the server judges it with Tag.claimWindow/touchedBetween
-- every frame until the deadline (Match.judgePending). Prints, per scenario and link, how many visible touches the
-- tagger saw, how many it claimed and how many the server confirmed. docs/systems/dash-tag.md §6 has the results.
local Tag = __require("Tag")
local Snapshot = __require("Snapshot")
local Items = __require("Items")
local Config = __require("Config")

for k, v in { TAG_REACH = SIM_TAG_REACH, TAG_GRACE = SIM_TAG_GRACE } do
	if v ~= nil then (Config :: any)[k] = v end -- NAME=value on the command line overrides a Config number
end

local DT = 1 / 60
local SEND_EVERY = math.max(1, math.floor(60 / Config.SNAPSHOT_RATE + 0.5))
local SPRITE_HALF = tonumber(SIM_SPRITE_HALF) or 1.75 -- studs: the drawn runner's half-width (measured on the art, §6)
local PING_IS = SIM_PING_IS or "rtt" -- what Player:GetNetworkPing returns: "rtt" or "half"

local seed = 12345
local function rand() -- deterministic LCG, [0, 1)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

-- A link: one-way delays (seconds) up (client -> server) and down (server -> client), each with uniform jitter.
local LINKS = {
	{ name = "LAN", up = 0.008, down = 0.008, jit = 0 },
	{ name = "wifi", up = 0.030, down = 0.030, jit = 0.015 },
	{ name = "4G", up = 0.055, down = 0.045, jit = 0.030 },
	{ name = "3G", up = 0.180, down = 0.150, jit = 0.090 },
}

local function delay(oneWay, jit) return oneWay + rand() * jit end

-- Scenarios: each returns a function(t) -> x, y, dashing, dashStarted for the tagger (T) and the runner (R).
-- A body moves along a list of segments { until, vx, vy-or-jump }; positions are integrated at 60 Hz below.
local function mover(x, y)
	return { x = x, y = y, vx = 0, vy = 0, dashUntil = -1, dashAt = nil, air = false }
end

local function dash(b, t, dir, floor)
	b.dashUntil = t + Config.DASH_TIME
	b.dashAt = t
	b.dashDir = dir
	b.dashEnd = if floor then Config.DASH_END_SPEED_FLOOR else Config.DASH_END_SPEED
end

local function jump(b, vy)
	b.vy = vy or Config.JUMP_SPEED
	b.air = true
end

local function stepBody(b, t, runVx)
	if t < b.dashUntil then
		b.vx = Config.DASH_SPEED * b.dashDir
		b.vy = 0
	else
		if b.dashEnd then b.vx = b.dashEnd * b.dashDir b.dashEnd = nil else b.vx = runVx end
		if b.air then b.vy -= Config.GRAVITY * DT end
	end
	b.x += b.vx * DT
	b.y += b.vy * DT
	if b.y <= 0 then b.y, b.vy, b.air = 0, 0, false end
end

local SCENARIOS = {}

-- 1. The runner stands (or idles); "it" runs into it at run speed and keeps going (pass-through bodies).
SCENARIOS["run into a standing runner"] = function()
	local T, R = mover(-20 - rand() * 10, 0), mover(0, 0)
	return T, R, function(t) stepBody(T, t, Config.RUN_SPEED) stepBody(R, t, 0) end
end
-- 2. Both run the same way; "it" dashes from 4-9 studs behind (H38's main case: the dash closes the gap).
SCENARIOS["dash into a fleeing runner"] = function()
	local T, R = mover(-8 - rand() * 6, 0), mover(0, 0) -- 8-14 studs behind for real; a dash closes ~11
	local at = 0.5 + rand() * 0.3
	local done = false
	return T, R, function(t)
		if not done and t >= at then dash(T, t, 1, true) done = true end
		stepBody(T, t, Config.RUN_SPEED) stepBody(R, t, Config.RUN_SPEED)
	end
end
-- 3. "It" is 10% faster (end phase / ramp) and closes the gap slowly: a long, easy overlap.
SCENARIOS["slow catch, it 10% faster"] = function()
	local T, R = mover(-12 - rand() * 4, 0), mover(0, 0) -- far enough back that every link draws the runner ahead
	return T, R, function(t) stepBody(T, t, Config.RUN_SPEED * 1.1) stepBody(R, t, Config.RUN_SPEED) end
end
-- 4. Head-on: the runner runs straight at "it" and past it (the side-to-side dodge, XTRA's "jump side to side").
SCENARIOS["head-on pass"] = function()
	local T, R = mover(-25 - rand() * 10, 0), mover(25 + rand() * 10, 0)
	return T, R, function(t) stepBody(T, t, Config.RUN_SPEED) stepBody(R, t, -Config.RUN_SPEED) end
end
-- 5. Head-on, the runner jumps over "it" (a ground jump timed so the apex is near the crossing).
SCENARIOS["head-on, runner jumps over"] = function()
	local T, R = mover(-20, 0), mover(20, 0)
	local cross = 40 / 90
	local at = cross - 0.12 + (rand() - 0.5) * 0.16
	local done = false
	return T, R, function(t)
		if not done and t >= at then jump(R) done = true end
		stepBody(T, t, Config.RUN_SPEED) stepBody(R, t, -Config.RUN_SPEED)
	end
end
-- 6. A runner who stopped dashes away when "it" (running at it) is 2-6 studs off: since H40 a touch before the dash
-- carries it out of reach is a tag (the dash away is no dodge).
SCENARIOS["runner dashes away late"] = function()
	local T, R = mover(-20, 0), mover(0, 0)
	local trigger = 2 + rand() * 4
	local done = false
	return T, R, function(t)
		if not done and R.x - T.x <= Config.RUNNER_WIDTH + trigger then dash(R, t, 1, true) done = true end
		stepBody(T, t, Config.RUN_SPEED) stepBody(R, t, if done then Config.RUN_SPEED else 0)
	end
end

-- One episode: returns visual (the tagger's screen showed the sprites overlapping), claimed, confirmed.
local function episode(make, tl, rl)
	local T, R, step = make()
	local tagger, runner = 1, 2
	local stream = Snapshot.newStream() -- the tagger's view of the runner
	local inflightUp = {} -- { arrive, id, snap } to the server
	local inflightDown = {} -- { arrive, serverT, snap } to the tagger
	local inflightClaim = {} -- { arrive }
	local latest = {} -- server: newest snapshot per id
	local dashAt = {} -- server: counted dash start per id
	local history = { [tagger] = {}, [runner] = {} }
	local seq = { 0, 0 }
	local wasDash = { false, false }
	local pending = nil
	local visual, claimed, confirmed = false, false, false
	local lastClaim = -math.huge
	local rtt = tl.up + tl.down + tl.jit
	local ping = if PING_IS == "rtt" then rtt else rtt / 2
	local prevTx, prevTy
	for f = 1, 150 do
		local t = f * DT
		prevTx, prevTy = T.x, T.y
		step(t)
		-- clients send
		if f % SEND_EVERY == 0 then
			for id, b in { T, R } do
				seq[id] += 1
				local dashing = t < b.dashUntil
				local s = { seq = seq[id], x = b.x, y = b.y, vx = b.vx, vy = b.vy, sprite = "runner_idle", facing = 1,
					dashing = dashing, dash = b.dashAt ~= nil and b.dashAt > t - SEND_EVERY * DT and b.dashAt <= t }
				local link = if id == tagger then tl else rl
				table.insert(inflightUp, { arrive = t + delay(link.up, link.jit), id = id, s = s })
			end
		end
		-- server: arrivals (Snapshots.receive), then sample (Match.sample), then judge (Match.judgePending)
		for i = #inflightUp, 1, -1 do
			local p = inflightUp[i]
			if p.arrive <= t then
				table.remove(inflightUp, i)
				local last = latest[p.id]
				if not last or Snapshot.newer(p.s.seq, last.seq) then
					latest[p.id] = { seq = p.s.seq, x = p.s.x, y = p.s.y }
					local started = p.s.dash or (p.s.dashing and not wasDash[p.id])
					wasDash[p.id] = p.s.dashing
					if started and Items.dashSeen(dashAt[p.id], t) then dashAt[p.id] = t end
					if p.id == runner then
						table.insert(inflightDown, { arrive = t + delay(tl.down, tl.jit), serverT = t, s = p.s })
					end
				end
			end
		end
		for id = 1, 2 do
			local l = latest[id]
			if l then
				local h = history[id]
				table.insert(h, { t = t, x = l.x, y = l.y, iframe = Items.iframed(dashAt[id], t) or nil })
				if #h > 60 then table.remove(h, 1) end
			end
		end
		for i = #inflightClaim, 1, -1 do
			local c = inflightClaim[i]
			if c.arrive <= t then
				table.remove(inflightClaim, i)
				local from, deadline, lag = Tag.claimWindow(t, ping + Config.TAG_VIEW_DELAY)
				pending = { from = from, deadline = deadline, lag = lag }
			end
		end
		if pending and not confirmed then
			if Tag.touchedBetween(history[tagger], history[runner], pending.from, math.min(t, pending.deadline), pending.lag) then
				confirmed = true
			elseif t >= pending.deadline then
				pending = nil
			end
		end
		-- the tagger's client: arrivals, draw, claim (Tagging.claim)
		for i = #inflightDown, 1, -1 do
			local p = inflightDown[i]
			if p.arrive <= t then
				table.remove(inflightDown, i)
				Snapshot.push(stream, p.serverT, t, p.s)
			end
		end
		local v = Snapshot.at(stream, t)
		if v then
			if math.abs(T.x - v.x) <= 2 * SPRITE_HALF and math.abs(T.y - v.y) <= Config.RUNNER_HEIGHT then visual = true end
			local tDashing = t < T.dashUntil
			local hit = Tag.overlaps(T.x, T.y, v.x, v.y, 0)
				or (tDashing and Tag.sweeps(prevTx, prevTy, T.x, T.y, v.x, v.y, Config.TAG_DASH_REACH))
			if hit and t - lastClaim >= 0.15 and not confirmed then -- H40: claimed even when drawn dashing
				lastClaim = t
				claimed = true
				table.insert(inflightClaim, { arrive = t + delay(tl.up, tl.jit) })
			end
		end
	end
	return visual, claimed, confirmed
end

local N = tonumber(SIM_N) or 300
local names = {}
for name in SCENARIOS do table.insert(names, name) end
table.sort(names)
print(("config: TAG_REACH %.2f, TAG_GRACE %.2f, TAG_VIEW_DELAY %.2f, TAG_REWIND_MAX %.2f, sprite half %.2f, ping=%s")
	:format(Config.TAG_REACH, Config.TAG_GRACE, Config.TAG_VIEW_DELAY, Config.TAG_REWIND_MAX, SPRITE_HALF, PING_IS))
print("scenario | tagger link / runner link | seen touching | claimed | confirmed | refused (of claims)")
for _, name in names do
	for _, tl in LINKS do
		for _, rl in { LINKS[2], LINKS[3], tl } do
			local nv, nc, nk = 0, 0, 0
			for _ = 1, N do
				local v, c, k = episode(SCENARIOS[name], tl, rl)
				if v then nv += 1 end
				if c then nc += 1 end
				if k then nk += 1 end
			end
			print(("%-28s | %-4s / %-4s | %3d%% | %3d%% | %3d%% | %d of %d"):format(name, tl.name, rl.name,
				math.floor(nv / N * 100 + 0.5), math.floor(nc / N * 100 + 0.5), math.floor(nk / N * 100 + 0.5), nc - nk, nc))
		end
	end
end
