-- Ghosts: DESIGN §3 rules 37-41 (H15), shared/Ghost.lua. Each rule below was mutation-checked (docs/systems/ghosts.md).
local Config = __require("Config")
local Tag = __require("Tag")
local Ghost = __require("Ghost")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B, C, D = 101, 202, 303, 404

-- A round where `first` burnt out at `t` and the next holder's freeze has just ended. Returns r, g, t (now).
local function afterFirstOut(order, first)
	local r, g = Tag.newRound(order, first, 0), Ghost.new()
	local t = Config.START_FREEZE + Config.FUSE_START
	local out = Ghost.tick(r, g, t)
	assert(out == first, "the first holder burns out")
	return r, g, t + Config.TAG_FREEZE
end

do -- rule 37: a ghost is a runner eliminated in this round; the living and a late joiner are not
	local r, g, t = afterFirstOut({ A, B, C }, A)
	assert(Ghost.isGhost(r, A), "the eliminated holder is a ghost")
	assert(not Ghost.isGhost(r, B) and not Ghost.isGhost(r, C), "the living are not")
	assert(not Ghost.isGhost(r, D), "a runner not in the round is not")
	assert(not Tag.canClaim(r, r.it :: number, A, t + 0.1), "a ghost cannot be tagged")
end

do -- rule 38: a spook drains SPOOK_DRAIN, and never below 0; the drain is what really came off (→ N7)
	local r, g, t = afterFirstOut({ A, B, C }, A)
	t += Config.SPOOK_COOLDOWN
	local before = Tag.fuseLeft(r, t)
	assert(Ghost.canSpook(r, g, A, r.it :: number, t), "a ready ghost may spook it")
	local fuse, drained = Ghost.spook(r, g, A, t)
	assert(near(drained, Config.SPOOK_DRAIN) and near(fuse, before - Config.SPOOK_DRAIN), "3 s off the fuse")
	assert(near(Tag.fuseLeft(r, t + 1), before - Config.SPOOK_DRAIN - 1), "and it keeps burning from there")
	local r2, g2, t2 = afterFirstOut({ A, B, C }, A)
	t2 += Config.SPOOK_COOLDOWN
	r2.fuse, r2.since = 1, t2
	local fuse2, drained2 = Ghost.spook(r2, g2, A, t2)
	assert(near(fuse2, 0) and near(drained2, 1), "1 s left: drains 1, not 3")
end

do -- rule 38: who may spook whom, and when
	local r, g, t = afterFirstOut({ A, B, C }, A)
	local it = r.it :: number
	assert(not Ghost.canSpook(r, g, A, it, t + 0.1), "a new ghost waits a full cooldown: no instant revenge")
	t += Config.SPOOK_COOLDOWN
	assert(Ghost.canSpook(r, g, A, it, t), "then it may")
	local other = if it == B then C else B
	assert(not Ghost.canSpook(r, g, A, other, t), "only the holder can be spooked")
	assert(not Ghost.canSpook(r, g, other, it, t), "only a ghost can spook")
	Tag.pass(r, other, t)
	assert(not Ghost.canSpook(r, g, A, other, t + Config.TAG_FREEZE / 2), "never while the holder is frozen")
	assert(Ghost.canSpook(r, g, A, other, t + Config.TAG_FREEZE), "and once the freeze ends, yes")
	local r2, g2 = Tag.newRound({ A, B }, A, 0), Ghost.new()
	r2.alive[B] = false -- a ghost at round start, for the start freeze alone
	assert(not Ghost.canSpook(r2, g2, B, A, Config.START_FREEZE / 2), "not in the start freeze either")
end

do -- rule 38: each ghost's cooldown, and the ward shared by every ghost
	local r, g = Tag.newRound({ A, B, C, D }, A, 0), Ghost.new()
	r.alive[B], r.alive[C] = false, false -- two ghosts, both ready
	local t = Config.START_FREEZE + 1
	Ghost.spook(r, g, B, t)
	assert(not Ghost.canSpook(r, g, C, A, t + Config.GHOST_WARD - 0.01), "the ward stops every other ghost")
	assert(Ghost.canSpook(r, g, C, A, t + Config.GHOST_WARD), "until it ends")
	assert(not Ghost.canSpook(r, g, B, A, t + Config.GHOST_WARD), "B's own cooldown is longer than the ward")
	assert(Ghost.canSpook(r, g, B, A, t + Config.SPOOK_COOLDOWN), "and ends after SPOOK_COOLDOWN")
end

do -- rule 38's cap, as an outcome (→ S11): however many ghosts try every frame, the fuse burns at most 1.5x
	for ghosts = 1, 3 do
		local order = { A, B, C, D }
		local r, g = Tag.newRound(order, A, 0), Ghost.new()
		r.fuse = 1000
		for k = 2, ghosts + 1 do r.alive[order[k]] = false end
		local t0, dt, T = Config.START_FREEZE, 1 / 60, 60
		local t = t0
		while t < t0 + T do
			for k = 2, ghosts + 1 do
				if Ghost.canSpook(r, g, order[k], A, t) then Ghost.spook(r, g, order[k], t) end
			end
			t += dt
		end
		local rate = (1000 - Tag.fuseLeft(r, t)) / (t - t0)
		print(("%d ghost(s) trying every frame for 60 s: the fuse burns %.3fx"):format(ghosts, rate))
		local cap = 1 + Config.SPOOK_DRAIN / math.min(Config.GHOST_WARD, Config.SPOOK_COOLDOWN * ghosts)
		assert(rate <= cap + 0.06, ("%d ghost(s) burn %.3fx, over the cap %.3fx"):format(ghosts, rate, cap))
		assert(rate <= 1.5 + 0.06, ("%d ghost(s): %.3fx is over 1.5x"):format(ghosts, rate))
	end
	assert(Config.SPOOK_DRAIN / Config.GHOST_WARD <= 0.5, "the trial numbers keep the cap at 1.5x")
end

do -- rule 39: the mark is the latest spooker's, on this hold only; a pass clears it
	local r, g = Tag.newRound({ A, B, C, D }, A, 0), Ghost.new()
	r.alive[B], r.alive[C] = false, false
	local t = Config.START_FREEZE + 1
	assert(Ghost.markOf(r, g) == nil, "no mark before any spook")
	Ghost.spook(r, g, B, t)
	assert(Ghost.markOf(r, g) == B, "B spooked: B holds the mark")
	t += Config.GHOST_WARD
	Ghost.spook(r, g, C, t)
	assert(Ghost.markOf(r, g) == C, "the latest spooker takes it")
	Tag.pass(r, D, t + 1)
	assert(Ghost.markOf(r, g) == nil, "a pass clears it")
	Tag.pass(r, A, t + 1 + Config.TAG_FREEZE)
	assert(Ghost.markOf(r, g) == nil, "and the fuse coming back to the same holder does not restore it")
end

do -- rule 39: fuse out with a mark: the marked ghost comes back where it is, never as it; the holder is the ghost
	local r, g = Tag.newRound({ A, B, C }, A, 0), Ghost.new()
	r.alive[B] = false -- order A, B, C: B is a ghost, A holds, C is alive
	Ghost.spook(r, g, B, Config.START_FREEZE + 1)
	local hold, elim = r.hold, r.eliminations
	local out, back = Ghost.tick(r, g, Config.START_FREEZE + Config.FUSE_START)
	assert(out == A and back == B, "A burns out, B comes back")
	assert(r.alive[B] and not r.alive[A] and not r.over, "the round goes on with B alive and A a ghost")
	assert(r.it == C, "the next holder after A in join order, skipping the returner B")
	assert(r.eliminations == elim + 1 and near(r.fuse, Tag.freshFuse(elim + 1)), "the fuse still shrinks")
	assert(r.hold == hold + 1 and Ghost.markOf(r, g) == nil, "a new hold, no mark")
	assert(not Ghost.canSpook(r, g, A, C, r.frozenUntil + 0.1), "the new ghost A waits its full cooldown")
end

do -- rule 39: no mark, no comeback; in the final duel that ends the round as before
	local r, g = Tag.newRound({ A, B, C }, A, 0), Ghost.new()
	r.alive[B] = false
	local out, back = Ghost.tick(r, g, Config.START_FREEZE + Config.FUSE_START)
	assert(out == A and back == nil and r.over and r.winner == C, "nobody marked A: plain elimination, C wins")
end

do -- Tag.tick's `back` only revives a ghost: a living id (a stale mark) is no comeback
	local r = Tag.newRound({ A, B }, A, 0)
	local out = Tag.tick(r, Config.START_FREEZE + Config.FUSE_START, B)
	assert(out == A and r.over and r.winner == B, "B was alive: the duel ends as before")
end

do -- rule 39: a spook that empties the fuse is the kill: that ghost comes back
	local r, g = Tag.newRound({ A, B, C }, A, 0), Ghost.new()
	r.alive[B] = false
	local t = Config.START_FREEZE + Config.FUSE_START - 2 -- 2 s left
	Ghost.spook(r, g, B, t)
	local out, back = Ghost.tick(r, g, t)
	assert(out == A and back == B and not r.over, "the killing spook brings B back in the same frame")
end

do -- rule 40: one comeback per player per round; a spent ghost still spooks but never takes the mark
	local r, g = Tag.newRound({ A, B, C, D }, A, 0), Ghost.new()
	r.alive[B] = false
	local t = Config.START_FREEZE + 1
	Ghost.spook(r, g, B, t)
	local _, back = Ghost.tick(r, g, Config.START_FREEZE + Config.FUSE_START)
	assert(back == B and Ghost.comebacksLeft(g, B) == 0, "B used its one comeback")
	r.alive[B] = false -- B is out again (say, burnt out later): a spent ghost; A is a ghost with its comeback
	assert(r.it == C and Ghost.isGhost(r, A), "C holds, A is the ghost from the comeback")
	t = r.frozenUntil + 1
	g.readyAt[A], g.readyAt[B] = nil, nil
	Ghost.spook(r, g, A, t)
	t += Config.GHOST_WARD
	local _, drained, marked = Ghost.spook(r, g, B, t)
	assert(near(drained, Config.SPOOK_DRAIN) and not marked, "the spent ghost still drains, takes no mark")
	assert(Ghost.markOf(r, g) == A, "and leaves A's mark where it was")
	r.fuse, r.since = 0, t
	local out2, back2 = Ghost.tick(r, g, t)
	assert(out2 == C and back2 == A, "A comes back, not B")
end

do -- edge: the marked ghost leaves the game: no comeback
	local r, g = Tag.newRound({ A, B, C }, A, 0), Ghost.new()
	r.alive[B] = false
	Ghost.spook(r, g, B, Config.START_FREEZE + 1)
	Ghost.leave(g, B)
	local _, back = Ghost.tick(r, g, Config.START_FREEZE + Config.FUSE_START)
	assert(back == nil and r.over, "B left: A's elimination ends the duel")
end

do -- edge: the holder leaves: not an elimination, a new hold, the mark is cleared
	local r, g = Tag.newRound({ A, B, C, D }, A, 0), Ghost.new()
	r.alive[B] = false
	Ghost.spook(r, g, B, Config.START_FREEZE + 1)
	Tag.leave(r, A, Config.START_FREEZE + 2)
	assert(r.it == C and Ghost.markOf(r, g) == nil, "C holds now, unmarked")
end

do -- rule 3 still holds: a 4-player round where every elimination that can be a comeback is one, with no passes,
	-- sees at most 7 fresh fuses (45+35+25+15x4 = 165 s) and ends
	local order = { A, B, C, D }
	local r, g = Tag.newRound(order, A, 0), Ghost.new()
	local t, total, lives = 0, 0, 0
	while not r.over and lives < 50 do
		local burn = Tag.fuseLeft(r, r.frozenUntil)
		total += burn
		lives += 1
		local spookAt = r.frozenUntil + 0.5
		for _, id in order do -- the first ghost with a comeback left marks the holder
			if Ghost.isGhost(r, id) and Ghost.comebacksLeft(g, id) > 0 then
				g.readyAt[id] = nil
				Ghost.spook(r, g, id, spookAt)
				total -= Config.SPOOK_DRAIN -- the drain shortened this life
				break
			end
		end
		t = r.frozenUntil + burn
		Ghost.tick(r, g, t)
	end
	assert(r.over, "the round ends")
	assert(lives == 7, ("7 lives at most, saw %d"):format(lives))
end

do -- Tag: every change of hands is a new hold (the mark depends on it)
	local r = Tag.newRound({ A, B, C }, A, 0)
	assert(r.hold == 0, "hold 0 at round start")
	Tag.pass(r, B, Config.START_FREEZE + 1)
	assert(r.hold == 1, "a pass")
	Tag.tick(r, 1000)
	assert(r.hold == 2, "an elimination")
	local r2 = Tag.newRound({ A, B, C, D }, A, 0)
	Tag.leave(r2, A, 1)
	assert(r2.hold == 1 and r2.it == B, "the holder leaving")
end

print("ghost ok")
