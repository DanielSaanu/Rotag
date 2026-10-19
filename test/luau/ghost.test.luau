-- Ghosts v2: DESIGN §3 rules 37, 38, 40 (H16, built H18), shared/Ghost.lua. Mutation-checked (docs/systems/ghosts.md §8).
-- RETIRED WITH THEIR RULES (H15's rules 39-40, the mark and the comeback, removed by Danzo 2026-10-19, H16): the mark's
-- tests (latest spooker, cleared by a pass), the comeback's (revive where it stands, never as it, one per player, a
-- spent ghost takes no mark, the killing spook, `Tag.tick`'s `back`, the marked ghost leaving) and the 7-lives bound.
-- They were not loosened to make anything pass: the behaviour they pinned no longer exists in DESIGN or in code.
-- H15's per-ghost SPOOK_COOLDOWN went with the spook; the hex is limited by holding one and by the shared ward.
local Config = __require("Config")
local Tag = __require("Tag")
local Ghost = __require("Ghost")
local Orbs = __require("Orbs")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B, C, D = 101, 202, 303, 404

-- A round where `first` burnt out and the next holder's freeze has just ended. Returns r, g, o, t (now).
local function afterFirstOut(order, first)
	local r, g, o = Tag.newRound(order, first, 0), Ghost.new(), Orbs.new({}, 0)
	local t = Config.START_FREEZE + Config.FUSE_START
	assert(Tag.tick(r, t) == first, "the first holder burns out")
	return r, g, o, t + Config.TAG_FREEZE
end

do -- rule 37: a ghost is a runner eliminated in this round; the living and a late joiner are not
	local r, _, _, t = afterFirstOut({ A, B, C }, A)
	assert(Ghost.isGhost(r, A), "the eliminated holder is a ghost")
	assert(not Ghost.isGhost(r, B) and not Ghost.isGhost(r, C), "the living are not")
	assert(not Ghost.isGhost(r, D), "a runner not in the round is not")
	assert(not Tag.canClaim(r, r.it :: number, A, t + 0.1), "a ghost cannot be tagged")
	assert(Ghost.count(r) == 1, "one ghost")
	assert(Ghost.count(r, function(id) return id ~= A end) == 0, "a ghost that left the game is not counted")
end

do -- rule 40: a held hex drains SPOOK_DRAIN and empties the slot; never below 0; the drain is what came off (→ N7)
	local r, g, o, t = afterFirstOut({ A, B, C }, A)
	o.held[A] = "hex"
	local before = Tag.fuseLeft(r, t)
	assert(Ghost.canHex(r, g, o, A, r.it :: number, t), "a ghost holding a hex may hex it at once (no cooldown)")
	local fuse, drained = Ghost.hex(r, g, o, A, t)
	assert(near(drained, Config.SPOOK_DRAIN) and near(fuse, before - Config.SPOOK_DRAIN), "3 s off the fuse")
	assert(near(Tag.fuseLeft(r, t + 1), before - Config.SPOOK_DRAIN - 1), "and it keeps burning from there")
	assert(o.held[A] == nil, "the hex is used up")
	assert(not Ghost.canHex(r, g, o, A, r.it :: number, t + Config.GHOST_WARD), "no second hex without a new orb")
	local r2, g2, o2, t2 = afterFirstOut({ A, B, C }, A)
	o2.held[A] = "hex"
	r2.fuse, r2.since = 1, t2
	local fuse2, drained2 = Ghost.hex(r2, g2, o2, A, t2)
	assert(near(fuse2, 0) and near(drained2, 1), "1 s left: drains 1, not 3")
end

do -- rule 40: who may hex whom, and when
	local r, g, o, t = afterFirstOut({ A, B, C }, A)
	local it = r.it :: number
	local other = if it == B then C else B
	assert(not Ghost.canHex(r, g, o, A, it, t), "a ghost with an empty slot cannot drain")
	o.held[A], o.held[other] = "hex", "hex"
	assert(Ghost.canHex(r, g, o, A, it, t), "with a hex it may")
	o.held[A] = "crate"
	assert(not Ghost.canHex(r, g, o, A, it, t), "any other item is not a hex")
	o.held[A] = "hex"
	assert(not Ghost.canHex(r, g, o, A, other, t), "only the holder can be hexed")
	assert(not Ghost.canHex(r, g, o, other, it, t), "only a ghost can hex, whatever it holds")
	Tag.pass(r, other, t)
	assert(not Ghost.canHex(r, g, o, A, other, t + Config.TAG_FREEZE / 2), "never while the holder is frozen")
	assert(Ghost.canHex(r, g, o, A, other, t + Config.TAG_FREEZE), "and once the freeze ends, yes")
	r.fuse, r.since = 0, t + Config.TAG_FREEZE
	assert(not Ghost.canHex(r, g, o, A, other, t + Config.TAG_FREEZE), "not on an empty fuse")
	local r2, g2, o2 = Tag.newRound({ A, B }, A, 0), Ghost.new(), Orbs.new({}, 0)
	r2.alive[B], o2.held[B] = false, "hex" -- a ghost at round start, for the start freeze alone
	assert(not Ghost.canHex(r2, g2, o2, B, A, Config.START_FREEZE / 2), "not in the start freeze either")
	r2.over = true
	assert(not Ghost.canHex(r2, g2, o2, B, A, Config.START_FREEZE + 1), "not after the round")
end

do -- rule 40: the ward is shared by every ghost and lasts GHOST_WARD
	local r, g, o = Tag.newRound({ A, B, C, D }, A, 0), Ghost.new(), Orbs.new({}, 0)
	r.alive[B], r.alive[C] = false, false
	o.held[B], o.held[C] = "hex", "hex"
	local t = Config.START_FREEZE + 1
	Ghost.hex(r, g, o, B, t)
	assert(near(Ghost.wardLeft(g, t), Config.GHOST_WARD), "the ward starts")
	assert(not Ghost.canHex(r, g, o, C, A, t + Config.GHOST_WARD - 0.01), "the ward stops every other ghost")
	assert(o.held[C] == "hex", "a refused hex keeps the hex")
	assert(Ghost.canHex(r, g, o, C, A, t + Config.GHOST_WARD), "until it ends")
end

do -- rule 40's cap, as an outcome (→ S11): however many ghosts, each handed a fresh hex EVERY frame, the fuse burns
	-- at most 1 + SPOOK_DRAIN / GHOST_WARD = 1.5x
	for ghosts = 1, 3 do
		local order = { A, B, C, D }
		local r, g, o = Tag.newRound(order, A, 0), Ghost.new(), Orbs.new({}, 0)
		r.fuse = 1000
		for k = 2, ghosts + 1 do r.alive[order[k]] = false end
		local t0, dt, T = Config.START_FREEZE, 1 / 60, 60
		local t = t0
		while t < t0 + T do
			for k = 2, ghosts + 1 do
				o.held[order[k]] = "hex"
				if Ghost.canHex(r, g, o, order[k], A, t) then Ghost.hex(r, g, o, order[k], t) end
			end
			t += dt
		end
		local rate = (1000 - Tag.fuseLeft(r, t)) / (t - t0)
		print(("%d ghost(s) with endless hexes for 60 s: the fuse burns %.3fx"):format(ghosts, rate))
		assert(rate <= 1 + Config.SPOOK_DRAIN / Config.GHOST_WARD + 0.06, ("%d ghost(s) burn %.3fx"):format(ghosts, rate))
		assert(rate <= 1.5 + 0.06, ("%d ghost(s): %.3fx is over 1.5x"):format(ghosts, rate))
	end
	assert(Config.SPOOK_DRAIN / Config.GHOST_WARD <= 0.5, "the trial numbers keep the cap at 1.5x")
end

do -- rule 38: no comeback. Ghosts holding hexes do not change who is out: a 4-runner round with no passes is three
	-- burn-outs, 45 + 35 + 25 = 105 s of fuse at most (rule 3), and every ghost stays a ghost to the end
	local order = { A, B, C, D }
	local r, g, o = Tag.newRound(order, A, 0), Ghost.new(), Orbs.new({}, 0)
	local total, lives, outs = 0, 0, {}
	while not r.over and lives < 50 do
		total += Tag.fuseLeft(r, r.frozenUntil)
		lives += 1
		for _, id in order do
			if Ghost.isGhost(r, id) then o.held[id] = "hex" end
		end
		local out = Tag.tick(r, r.frozenUntil + Tag.fuseLeft(r, r.frozenUntil))
		assert(out ~= nil, "the holder burns out")
		table.insert(outs, out)
		for _, id in outs do assert(r.alive[id] == false, "nobody comes back") end
	end
	assert(r.over and lives == 3, ("three burn-outs end it, saw %d"):format(lives))
	assert(near(total, 45 + 35 + 25), ("105 s of fuse at most, saw %.1f"):format(total))
	assert(r.winner ~= nil and r.alive[r.winner :: number], "the last one alive wins")
end

do -- Tag: every change of hands is a new hold (kept with Round.hold, → S12, though the mark that used it is gone)
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

do -- rule 41 (H19): the per-target ward. A holder a ghost's ice beam hit is safe from the hex; a hex wards its target
	local r, g, o, t = afterFirstOut({ A, B, C }, A)
	local it = r.it :: number
	o.held[A] = "hex"
	g.wards[it] = t + 2 -- what Items.step writes when a ghost's beam freezes it
	local ok, why = Ghost.canHex(r, g, o, A, it, t + 1)
	assert(not ok and why ~= nil and string.find(why, "target warded", 1, true) ~= nil, "warded by a ghost's ice hit")
	assert(Ghost.canHex(r, g, o, A, it, t + 2), "and free again when that ward ends")
	Ghost.hex(r, g, o, A, t + 2)
	assert(near(g.wards[it], t + 2 + Config.GHOST_WARD), "a hex wards its target from every ghost's aimed abilities")
end

print("ghost ok")
