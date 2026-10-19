-- Items and holds: DESIGN §3 rules 41-45 (H16, built H19), shared/Items.lua. Mutation-checked (docs/systems/items.md §8).
-- Positions are the server's record of each runner; a victim is a living runner (the server never passes a ghost:
-- items touch the living only, rule 37; server/Items builds the list).
local Config = __require("Config")
local Items = __require("Items")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local A, B, C = 101, 202, 303
local Y = Config.RUNNER_HEIGHT / 2 -- a runner standing on a floor at y = 0
local function at(id, x, y, extra)
	local v = { id = id, x = x, y = y or Y }
	for k, val in extra or {} do v[k] = val end
	return v
end
local function kinds(ev)
	local out = {}
	for _, e in ev do table.insert(out, e.kind .. (if e.id then ":" .. e.id else "") .. (if e.hold then ":" .. e.hold else "")) end
	return table.concat(out, " ")
end

do -- rules 43, 39, 10: the pools and weights (ghosts-v2-proposal.md §3), and which pool an orb rolls
	local function rows(p) local s = {} for _, r in p do table.insert(s, r[1] .. "=" .. r[2]) end return table.concat(s, " ") end
	assert(rows(Items.POOLS.runner) == "crate=40 trap=35 ice=25", "runner pool: " .. rows(Items.POOLS.runner))
	assert(rows(Items.POOLS.holder) == "ice=50 crate=25 trap=25", "holder pool, the ice beam first: " .. rows(Items.POOLS.holder))
	assert(rows(Items.POOLS.ghost) == "crate=12 trap=10 ice=10 hex=8", "ghost pool (PR 4 adds fixture, pad, grant): "
		.. rows(Items.POOLS.ghost))
	assert(Items.poolFor("living", true) == Items.POOLS.holder and Items.poolFor("living", false) == Items.POOLS.runner,
		"a living orb rolls the holder pool for the holder, the runner pool for anyone else")
	assert(Items.poolFor("ghost", true) == Items.POOLS.ghost and Items.poolFor("nopool") == nil, "ghost orbs; no pool")
	local hex = 0
	for _, r in Items.POOLS.ghost do if r[1] == "hex" then hex = r[2] end end
	local total = 0
	for _, r in Items.POOLS.ghost do total += r[2] end
	assert(near(hex / total, 0.2), "the hex is 1 ghost roll in 5 until PR 4 (was every roll in PR 1)")
end

do -- where Use puts things: a crate behind you, a trap at your feet, a beam ahead the way you face
	local x, y, hw, hh = Items.footprint("crate", 10, Y, 1)
	assert(x + hw < 10 - Config.RUNNER_WIDTH / 2 and near(y - hh, 0), "facing right, the crate is behind and on the floor")
	x = Items.footprint("crate", 10, Y, -1)
	assert(x - hw > 10 + Config.RUNNER_WIDTH / 2, "facing left, behind is to the right")
	x, y, hw, hh = Items.footprint("trap", 10, Y, 1)
	assert(x == 10 and near(y - hh, 0) and near(hw * 2, Config.TRAP_W), "the trap at your feet")
	x, y, hw = Items.footprint("ice", 10, Y, -1)
	assert(near(x + hw, 10 - Config.RUNNER_WIDTH / 2) and near(hw * 2, Config.ICE_LENGTH) and y == Y,
		"the beam starts at your front edge and reaches 24 studs ahead")
end

do -- rule 44: a crate stumbles who runs into it for 0.7 s and breaks; jumping over it is nothing
	local st = Items.new()
	local t = Items.use(st, A, "crate", false, 10, Y, 1, 0)
	assert(#Items.step(st, 0.1, { at(B, t.x, Y + 8, { px = t.x - 6, py = Y + 8 }) }, {}) == 0, "a jump over it: nothing")
	local ev = Items.step(st, 0.2, { at(B, t.x + 1, Y, { px = t.x - 6, py = Y }) }, {})
	assert(kinds(ev) == "hold:202:stumble gone", "caught on the path, then the crate breaks: " .. kinds(ev))
	assert(ev[1].time == Config.STUMBLE_TIME and ev[1].by == t.n, "0.7 s, and the event says which thing")
	assert(Items.holdOf(st, B, 0.2 + 0.69) ~= nil and Items.holdOf(st, B, 0.2 + 0.7) == nil, "it lasts 0.7 s")
	assert(kinds(Items.step(st, 0.9, {}, {})) == "free:202", "a 'free' when it runs out, once")
	assert(#Items.step(st, 1.0, {}, {}) == 0, "not twice")
end

do -- rule 45: the dash's i-frames carry you over a trap and through a beam, never through a crate
	local st = Items.new()
	local crate = Items.use(st, A, "crate", false, 0, Y, 1, 0)
	local trap = Items.use(st, A, "trap", false, 50, Y, 1, 0)
	local ice = Items.use(st, C, "ice", false, 100, Y, 1, 0)
	local ev = Items.step(st, 0.1, { at(B, trap.x, Y, { iframe = true }) }, {})
	assert(#ev == 0, "dashing over the trap: nothing, and the trap stays")
	ev = Items.step(st, 0.1, { at(B, ice.x, Y, { iframe = true }) }, {})
	assert(#ev == 0, "dashing through the beam: nothing")
	ev = Items.step(st, 0.2, { at(B, crate.x, Y, { iframe = true }) }, {})
	assert(kinds(ev) == "hold:202:stumble gone", "dashing into a crate still stumbles: " .. kinds(ev))
	assert(near(st.things[1].x, trap.x), "the trap is still set")
end

do -- rule 44: the bear trap pins up to 1 s, or 3 presses pry it open; only a trap is pried
	local st = Items.new()
	local trap = Items.use(st, A, "trap", false, 50, Y, 1, 0)
	local ev = Items.step(st, 1, { at(B, trap.x, Y) }, {})
	assert(kinds(ev) == "hold:202:trap gone", "one catch and the trap is gone: " .. kinds(ev))
	assert(ev[1].time == Config.TRAP_TIME and Config.TRAP_TIME == 1, "1 s at most (Danzo)")
	assert(not Items.pry(st, B, 1.1) and not Items.pry(st, B, 1.2), "two presses: still pinned")
	assert(Items.holdOf(st, B, 1.25) ~= nil, "still held after two")
	assert(Items.pry(st, B, 1.3), "the third press frees it")
	assert(Items.holdOf(st, B, 1.3) == nil, "free at once")
	assert(#Items.step(st, 1.4, {}, {}) == 0, "the server sent 'free' with the pry: no second one from step")
	local s2 = Items.new()
	Items.use(s2, A, "crate", false, 10, Y, 1, 0)
	Items.step(s2, 0.1, { at(B, s2.things[1].x, Y) }, {})
	assert(not Items.pry(s2, B, 0.2) and not Items.pry(s2, B, 0.3) and not Items.pry(s2, B, 0.4)
		and Items.holdOf(s2, B, 0.4) ~= nil, "presses do not end a stumble")
	local s3 = Items.new()
	local t3 = Items.use(s3, A, "trap", false, 50, Y, 1, 0)
	Items.step(s3, 1, { at(B, t3.x, Y) }, {})
	assert(Items.holdOf(s3, B, 1.99) ~= nil and Items.holdOf(s3, B, 2) == nil, "no presses: it lets go at 1 s")
end

do -- QA round 1, FIX 1: presses bunched by network jitter during a trap all count; outside a trap the gap stands
	local st = Items.new()
	local trap = Items.use(st, A, "trap", false, 50, Y, 1, 0)
	Items.step(st, 1, { at(B, trap.x, Y) }, {})
	-- The client sent three presses 0.06 s apart; jitter delivers the last two 0.01 s apart (closer than USE_GAP).
	local last, freed = nil, false
	for _, arrive in { 1.10, 1.17, 1.18 } do
		if Items.acceptPress(st, B, arrive, last) then
			last = arrive
			freed = Items.pry(st, B, arrive) or freed
		end
	end
	assert(freed and Items.holdOf(st, B, 1.18) == nil, "all three counted: freed on the third, as the client counted")
	assert(not Items.acceptPress(st, B, 1.19, 1.18), "free again: a press 0.01 s after the last is gap-dropped")
	assert(Items.acceptPress(st, B, 1.18 + Config.USE_GAP, 1.18), "and one USE_GAP later is taken")
	local s2 = Items.new()
	Items.use(s2, A, "crate", false, 10, Y, 1, 0)
	Items.step(s2, 0.1, { at(B, s2.things[1].x, Y) }, {})
	assert(not Items.acceptPress(s2, B, 0.21, 0.2), "a stumble is not a trap: the gap stands")
end

do -- rule 44: no chains. After a hold, HOLD_IMMUNITY in which a crate does not catch (and is not used up)
	local st = Items.new()
	local c1 = Items.use(st, A, "crate", false, 0, Y, 1, 0)
	Items.step(st, 1, { at(B, c1.x, Y) }, {})
	local c2 = Items.use(st, A, "crate", false, 40, Y, 1, 1)
	local free = 1 + Config.STUMBLE_TIME
	assert(#Items.step(st, 1.3, { at(B, c2.x, Y) }, {}) == 0, "during the stumble another crate does nothing")
	local ev = Items.step(st, free + 0.4, { at(B, c2.x, Y) }, {})
	assert(kinds(ev) == "free:202", "in the immunity: only the 'free'; the crate stays: " .. kinds(ev))
	ev = Items.step(st, free + 0.5, { at(B, c2.x, Y) }, {})
	assert(kinds(ev) == "hold:202:stumble gone", "after 0.5 s it catches again: " .. kinds(ev))
end

do -- rule 44: the holder's tag freeze is a hold too: nothing lands during it or for 0.5 s after it
	local st = Items.new()
	local trap = Items.use(st, A, "trap", false, 50, Y, 1, 0)
	local frozen = { frozenUntil = 2 }
	assert(#Items.step(st, 1, { at(B, trap.x, Y, frozen) }, {}) == 0, "frozen: no trap")
	assert(#Items.step(st, 2.4, { at(B, trap.x, Y, frozen) }, {}) == 0, "0.4 s after the freeze: no trap")
	assert(#Items.step(st, 2.5, { at(B, trap.x, Y, frozen) }, {}) == 2, "0.5 s after: trapped")
end

do -- rule 44: no item starts during a hold or the tag freeze; one started before goes off in full
	local st = Items.new()
	assert(not Items.canUse(st, A, nil, 0), "nothing held")
	local ok, why = Items.canUse(st, A, "hex", 0)
	assert(not ok and why == "the hex is used by touch", "the hex is not Use's")
	assert(Items.canUse(st, A, "ice", 0) and not Items.canUse(st, A, "ice", 0.5, 1), "the tag freeze blocks a use")
	local beam = Items.use(st, A, "ice", false, 0, Y, 1, 0) -- A fires at 0, then steps into C's trap at 0.05
	Items.use(st, C, "trap", false, -30, Y, 1, 0)
	assert(kinds(Items.step(st, 0.05, { at(A, -30, Y) }, {})) == "hold:101:trap gone", "A is trapped")
	assert(not Items.canUse(st, A, "crate", 0.1), "trapped: no new item")
	local ev = Items.step(st, 0.1, { at(B, beam.x, Y) }, {})
	assert(kinds(ev) == "hold:202:freeze", "the beam fired before A's hold still freezes B: " .. kinds(ev))
end

do -- the owner: a crate or trap never catches its owner within OWNER_SAFE, nor before it has stepped off it
	local st = Items.new()
	local trap = Items.use(st, A, "trap", false, 20, Y, 1, 0)
	assert(#Items.step(st, 1, { at(A, 20, Y) }, {}) == 0, "standing on your own trap past 0.5 s: never stepped off")
	assert(#Items.step(st, 1.05, { at(A, 20, Y) }, {}) == 0, "still standing on it a frame later: still safe")
	assert(#Items.step(st, 1.1, { at(A, 30, Y) }, {}) == 0, "stepping off arms it")
	assert(#Items.step(st, 1.2, { at(A, trap.x, Y) }, {}) == 2, "back onto it: caught")
	local s2 = Items.new()
	local crate = Items.use(s2, A, "crate", false, 20, Y, 1, 0)
	assert(#Items.step(s2, 0.1, { at(A, 30, Y) }, {}) == 0 and #Items.step(s2, 0.3, { at(A, crate.x, Y) }, {}) == 0,
		"turning straight back into your own crate inside 0.5 s: safe")
	assert(#Items.step(s2, 0.6, { at(A, 30, Y) }, {}) == 0 and #Items.step(s2, 0.7, { at(A, crate.x, Y) }, {}) == 2,
		"after 0.5 s and off it: your own crate catches you")
end

do -- the ice beam: 0.5 s, catches each runner once, never its user, does not turn with you
	local st = Items.new()
	local beam = Items.use(st, A, "ice", false, 0, Y, 1, 0)
	assert(beam.x > 0 and beam.dir == 1, "ahead, to the right")
	assert(#Items.step(st, 0.1, { at(A, beam.x, Y) }, {}) == 0, "never its user")
	local ev = Items.step(st, 0.1, { at(B, beam.x, Y), at(C, beam.x + 5, Y) }, {})
	assert(kinds(ev) == "hold:202:freeze hold:303:freeze", "one beam, two runners: " .. kinds(ev))
	assert(ev[1].time == Config.FREEZE_TIME, "frozen 1 s")
	st.holds[B].untilT, st.holds[B].over = -10, true -- as if B were long free and past its immunity
	assert(#Items.step(st, 0.2, { at(B, beam.x, Y) }, {}) == 0, "the same beam never catches B twice")
	assert(kinds(Items.step(st, 0.5, {}, {})) == "gone", "gone after 0.5 s")
	assert(#Items.step(st, 0.5, { at(B, 13, Y) }, {}) == 0, "and catches nobody after")
end

do -- rule 41: a ghost's AIMED hit wards its target 6 s from every ghost's aimed abilities; a living beam still lands
	local st, wards = Items.new(), {}
	local g1 = Items.use(st, A, "ice", true, 0, Y, 1, 0)
	Items.step(st, 0.1, { at(B, g1.x, Y) }, wards)
	assert(near(wards[B], 0.1 + Config.GHOST_WARD), "a ghost's beam wards its target")
	st.holds[B].untilT, st.holds[B].over = -10, true
	local g2 = Items.use(st, C, "ice", true, 0, Y, 1, 1)
	local ev = Items.step(st, 1.1, { at(B, g2.x, Y) }, wards)
	assert(kinds(ev) == "gone", "another ghost's beam inside the ward: nothing (the first beam expires): " .. kinds(ev))
	local l = Items.use(st, C, "ice", false, 0, Y, 1, 2)
	ev = Items.step(st, 2.1, { at(B, l.x, Y) }, wards)
	assert(kinds(ev) == "gone hold:202:freeze", "a living runner's beam is not a ghost's: it lands: " .. kinds(ev))
	assert(near(wards[B], 0.1 + Config.GHOST_WARD), "and does not ward")
	local s2, w2 = Items.new(), {}
	local gtrap = Items.use(s2, A, "trap", true, 0, Y, 1, 0)
	Items.step(s2, 1, { at(B, gtrap.x, Y) }, w2)
	assert(w2[B] == nil, "a ghost's trap is put down, not aimed: no ward")
end

do -- rule 45, the server's dash record: i-frames for 0.2 s from a counted start; starts closer than the cooldown don't count
	assert(Items.iframed(1, 1) and Items.iframed(1, 1.19) and not Items.iframed(1, 1.2), "0.2 s from the start")
	assert(not Items.iframed(nil, 1) and not Items.iframed(1, 0.9), "no dash, or before it")
	assert(Items.dashSeen(nil, 0) and Items.dashSeen(0, Config.DASH_COOLDOWN), "the first one, and one a cooldown later")
	assert(not Items.dashSeen(0, 0.3), "a claimed dash 0.3 s after the last is not counted (no endless i-frames)")
	local kept = Items.undodged({ { t = 1 }, { t = 2, iframe = true }, { t = 3 } })
	assert(#kept == 2 and kept[1].t == 1 and kept[2].t == 3, "a hex never lands on a sample in i-frames")
end

do -- the swept touch is the slab test (→ N14): a fast path through a thin box counts, a path past it does not
	assert(Items.swept(0, 0, 1, 1, 5, 0, -5, 0), "through")
	assert(not Items.swept(0, 0, 1, 1, 5, 3, -5, 3), "above")
	assert(Items.swept(0, 0, 1, 1, 1, 1) and not Items.swept(0, 0, 1, 1, 1.01, 0), "a point: edges in, a hair out")
end

do -- rule 44 (H20, Danzo 2026-10-19): an iced holder cannot pass the fuse; an iced runner can be tagged; nothing else stops a tag
	local Tag = __require("Tag")
	local r = Tag.newRound({ A, B, C }, A, 0) -- A is it; its start freeze is long over by t = 5
	local st = Items.new()
	-- What server/Match.judge does: the round's rules, then the claimant's hold, then a same-frame touch.
	local function passes(claimant, target, now)
		local ok = Tag.canClaim(r, claimant, target, now)
		if ok then ok = Items.canTag(st, claimant, now) end
		return ok and Tag.confirm({ { t = now, x = 0, y = Y } }, { { t = now, x = 1, y = Y } }, now, 0)
	end
	assert(passes(A, B, 5), "no hold: the holder's touch passes")
	local beam = Items.use(st, B, "ice", false, 10, Y, -1, 4.9) -- B ices the holder
	assert(kinds(Items.step(st, 5, { at(A, beam.x), at(B, 10) }, {})) == "hold:101:freeze", "the beam freezes A")
	local ok, why = Items.canTag(st, A, 5.1)
	assert(not ok and why == "frozen by ice", "an iced holder may not tag: " .. tostring(why))
	assert(not passes(A, B, 5.1) and not passes(A, C, 5 + Config.FREEZE_TIME - 0.01), "nor pass the fuse, the whole freeze")
	assert(passes(A, B, 5 + Config.FREEZE_TIME), "the freeze ends on its own clock: the next frame's claim passes, even"
		.. " before Items.step marks it over (Match judges tags first)")
	st.holds[A] = nil
	st.holds[B] = { kind = "freeze", from = 5, untilT = 6, presses = 0, over = false }
	assert(passes(A, B, 5.5), "an iced runner is still a free tag (rule 44 as written)")
	for _, kind in { "trap", "stumble" } do
		st.holds[A] = { kind = kind, from = 5, untilT = 6, presses = 0, over = false }
		assert(Items.canTag(st, A, 5.5) and passes(A, C, 5.5), "a " .. kind .. " never stops the holder's tag")
	end
end

print("items ok")
