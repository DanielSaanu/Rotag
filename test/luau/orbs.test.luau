-- Orbs: DESIGN §3 rules 39 and 42 (H16, built H18), shared/Orbs.lua. Mutation-checked (docs/systems/ghosts.md §8).
local Config = __require("Config")
local Orbs = __require("Orbs")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B = 101, 202
local Y = Config.RUNNER_HEIGHT / 2 -- a runner standing on a floor at y = 0
local function never(): number error("no roll expected") end
local function fixed(v: number) return function() return v end end
local function ghostAt(id, x, y) return { id = id, x = x, y = y, ghost = true } end

do -- rule 42: none before ORB_FIRST; then up
	local o = Orbs.new({ { x = 0, y = Y, kind = "ghost" } }, 100)
	assert(not Orbs.isUp(o, 1, 100 + Config.ORB_FIRST - 0.01, 1), "nothing before 0:05")
	assert(Orbs.isUp(o, 1, 100 + Config.ORB_FIRST, 1), "up at 0:05")
	assert(#Orbs.step(o, 100 + 1, 1, { ghostAt(A, 0, Y) }, never) == 0, "a ghost standing on it early takes nothing")
	assert(o.held[A] == nil, "slot still empty")
end

do -- rule 42: the respawn formulas
	assert(near(Orbs.respawnTime("living", 3), 10), "living orbs: 10 s whatever the ghosts")
	assert(near(Orbs.respawnTime("ghost", 0), 10), "ghost orbs, no ghosts: 10 s")
	assert(near(Orbs.respawnTime("ghost", 1), 10 / 1.5), "one ghost: 6.7 s")
	assert(near(Orbs.respawnTime("ghost", 2), 5), "two ghosts: 5 s")
	assert(near(Orbs.respawnTime("ghost", 3), 4), "three ghosts: 4 s")
end

do -- rule 42: a taken orb is gone for its respawn time, recomputed with the ghost count NOW
	local o = Orbs.new({ { x = 0, y = Y, kind = "ghost" } }, 0)
	local t = Config.ORB_FIRST
	local ev = Orbs.step(o, t, 1, { ghostAt(A, 0, Y) }, fixed(0))
	assert(#ev == 1 and ev[1].by == A and ev[1].item == "hex" and ev[1].up == false, "A takes it: one 'taken' event")
	assert(o.held[A] == "hex", "into A's slot")
	assert(not Orbs.isUp(o, 1, t + 10 / 1.5 - 0.01, 1), "one ghost: still gone just before 6.7 s")
	assert(Orbs.isUp(o, 1, t + 10 / 1.5, 1), "back at 6.7 s")
	assert(Orbs.isUp(o, 1, t + 5, 2), "a second ghost since: back at 5 s")
	local back = Orbs.step(o, t + 5, 2, {}, never)
	assert(#back == 1 and back[1].up == true and back[1].by == nil, "one 'back' event")
	assert(#Orbs.step(o, t + 5.1, 2, {}, never) == 0, "and no repeat while it stays up")
end

do -- rule 42: one slot. A full slot passes through an orb and leaves it up; after use it can take again
	local o = Orbs.new({ { x = 0, y = Y, kind = "ghost" } }, 0)
	local t = Config.ORB_FIRST
	Orbs.step(o, t, 1, {}, never) -- the orb appears
	o.held[A] = "hex"
	assert(#Orbs.step(o, t + 0.1, 1, { ghostAt(A, 0, Y) }, never) == 0, "a full slot takes nothing")
	assert(Orbs.isUp(o, 1, t + 0.1, 1), "the orb stays up for someone else")
	assert(Orbs.use(o, A) == "hex" and o.held[A] == nil, "use empties the slot and says what was in it")
	assert(Orbs.use(o, A) == nil, "using an empty slot gives nothing")
	local ev = Orbs.step(o, t + 0.2, 1, { ghostAt(A, 0, Y) }, fixed(0))
	assert(#ev == 1 and o.held[A] == "hex", "an empty slot takes it")
end

do -- rule 39: ghost orbs are for ghosts only; a kind with no pool yet (living, PR 2) is taken by nobody
	local o = Orbs.new({ { x = 0, y = Y, kind = "ghost" }, { x = 50, y = Y, kind = "living" } }, 0)
	local t = Config.ORB_FIRST
	local living = { id = B, x = 0, y = Y, ghost = false }
	assert(#Orbs.step(o, t, 0, { living }, never) == 1, "the ghost orb appears (one 'back' event), the living one has no pool")
	assert(o.held[B] == nil, "the living cannot take a ghost orb")
	living.x = 50
	Orbs.step(o, t + 0.1, 0, { living }, never)
	assert(o.held[B] == nil, "no living pool before PR 2")
	assert(not Orbs.canTake(o, 2, ghostAt(A, 50, Y), t + 0.1, 0), "and a ghost cannot take a living orb")
end

do -- first come, first served: the earlier taker in the list (the server's join order) gets it
	local o = Orbs.new({ { x = 0, y = Y, kind = "ghost" } }, 0)
	local ev = Orbs.step(o, Config.ORB_FIRST, 2, { ghostAt(B, 0.5, Y), ghostAt(A, 0, Y) }, fixed(0))
	assert(#ev == 1 and ev[1].by == B and o.held[B] == "hex" and o.held[A] == nil, "B was first in the list")
end

do -- the touch: the runner box against the orb's square, edges included, and the path between two samples
	local s = { x = 0, y = Y, kind = "ghost" }
	local reach = Config.RUNNER_WIDTH / 2 + Config.ORB_SIZE / 2
	assert(Orbs.touches(s, reach, Y), "touching at the edge")
	assert(not Orbs.touches(s, reach + 0.01, Y), "a hair away")
	assert(not Orbs.touches(s, 0, Y + Config.RUNNER_HEIGHT / 2 + Config.ORB_SIZE / 2 + 0.01), "just above it")
	assert(Orbs.touches(s, 4, Y, -4, Y), "a dash from -4 to 4 between two samples goes through it")
	assert(not Orbs.touches(s, 4, Y + 10, -4, Y + 10), "the same dash 10 studs higher misses")
	assert(not Orbs.touches(s, 8, Y, 4, Y), "moving away on the far side misses")
	assert(Orbs.touches(s, 4, Y - 4, -4, Y + 4), "a diagonal through the middle hits")
	assert(not Orbs.touches(s, 6, Y + 6, -2, Y + 14), "a diagonal passing above the corner misses")
end

do -- the roll: weighted, from the injected source, deterministic
	local pool = { { "a", 1 }, { "b", 3 } }
	assert(Orbs.roll(pool, fixed(0)) == "a" and Orbs.roll(pool, fixed(0.249)) == "a", "the first quarter is a")
	assert(Orbs.roll(pool, fixed(0.25)) == "b" and Orbs.roll(pool, fixed(0.999)) == "b", "the rest is b")
	local count = { a = 0, b = 0 }
	for k = 0, 999 do count[Orbs.roll(pool, fixed(k / 1000))] += 1 end
	assert(count.a == 250 and count.b == 750, ("weights 1:3 over an even sweep, saw %d:%d"):format(count.a, count.b))
	assert(Orbs.roll(pool, fixed(1)) == "b", "a source that returns 1 still picks a real item")
end

do -- the ghost pool is the hex alone until PRs 2 and 4 (ghosts-v2-proposal.md §12)
	local pool = Orbs.POOLS.ghost
	assert(#pool == 1 and pool[1][1] == "hex", "ghost pool: hex only")
	assert(Orbs.POOLS.living == nil, "no living pool yet")
end

print("orbs ok")
