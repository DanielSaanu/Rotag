# Learnings: S — Shared Luau

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ S1").

**S1 — A capped list can be a memory, but never a ledger.** Anything with an eviction rule (an LRU, a ring, a
"keep the last N") *heals when it evicts*. A number that must be permanent (a session score, a cooldown owed) is
**stored**, and the capped thing is only the transport. Test for it by filling the cap past its limit and asserting
the number did not move. *(inherited, handoff H1.)*

**S2 — Before proposing a data shape, encode it and count the bytes.** Two candidate shapes for one feature came out
216 KB and 22 KB. Measuring took twenty minutes with `test/luau/run.js`'s `bundle()`; guessing would have shipped the
wrong one. Put the number in the doc, then in a test. *(inherited, handoff H1.)*

**S3 — A dedupe set for "has this been applied" is keyed by everything the application is keyed by.** If the write
is per (a, b), the "already done" set is per (a, b) too; a set keyed by less is a bug that only shows up in the second
case. *(inherited, rung 3 part 3.)*

**S7 — Before putting a new kind of thing into an existing list, find every reader that counts or walks it.** Grep the
list's name, read every loop and `#`, and if any reader assumes the old kind, give the new kind its own field.
*(inherited, handoff H7.)*

**S8 — Measure "closer" in the metric the move uses, and test a fallback in the exact shape that triggers it.** A
side-step that could never fire read as working for months because nothing showed it failing. Write the test where
the fallback is the ONLY way out, and watch it fail before the fix. *(inherited, handoff H9.)*

**S9 — A one-shot "do this next" flag is cleared when it is DELIVERED, not when it is attempted.** Anything that can
be silently dropped downstream (a gap, a fade, an open window, nobody on screen) must hand back whether it went out,
and the caller clears on that. *(inherited, handoff H11.)*

**S10 — A constraint that is only true for one case carries that constraint in the data, not in a preference.** A
preference is not a guarantee: mark the rule in the row and let the pure picker skip it, so the rule is tested without
Studio. *(inherited, handoff H11.)*

**S11 — A rate limit cannot cap a per-use gain: test the outcome the limit protects, not the count it allows.** A dash
cooldown passed its "one dash per 0.8 s" test while mashing still ran 45% faster than running, because each use banks
a fixed gain and the cooldown only spaces them. Assert the protected quantity (average speed against run speed, total
gained), and watch that assertion fail on the old rule. *(2026-10-11, handoff H9, `movement.test.luau`.)*
When the right amount is a judgement call, pin the MEASURED value tightly and say in the test that it is a measurement,
so the next tuning change shows as a diff; measure over a whole number of cycles (3 s at a 0.8 s cooldown read x1.350,
five cooldowns x1.325). *(2026-10-11, handoff H10.)*

**S12 — State tied to "the current holder" is keyed by a hand-over counter, never by the holder's id.** The ghost mark
belongs to one hold: A holds, is marked, passes to B, gets the fuse back, and keying by id would revive the stale mark.
Bump one counter on EVERY path that changes hands (pass, elimination, leave) and test each path. *(2026-10-14, H15, `Round.hold`.)*

**S13 — Anything that follows a moving average (a zone, a camera target, a crowd marker) eases toward it; a speed cap
alone turns normal sway into a constant wobble.** The closing walls' centre first chased the living mean at its 8
studs/s cap, so three patrolling dummies swung both walls 16 studs back and forth every few seconds (Studio). Ease
proportionally (a time constant longer than the sway's period) and keep the cap only for the big moves; pin the
outcome with a driven sway (a sine of the measured amplitude and period) and watch the old rule fail it.
*(2026-11-01, handoff H24, `shared/Walls.step`.)*

**S14 — A constraint solved by projecting positions bleeds energy at a game's frame rate: step a pendulum in its
angle with leapfrog, and pin "energy never grows, and does not die" over several periods.** The grapple's first swing
projected the next position onto the rope and set the velocity to the chord: it lost 86% of its energy in 4 s at
60 Hz. The obvious repair (a velocity constraint plus a position snap) ADDS energy instead. In the angle,
`w += a(th) dt/2; th += w dt; w += a(th1) dt/2` lost 0.1% over 4 s, and plain symplectic Euler overshot the start
energy by 3%. Measure the energy per swing before trusting any constraint solver, and mutation-check that the test
fails for Euler. *(2026-11-01, handoff H25, `shared/Grapple.swing`.)*

**S15 — When a rule gains a motion of its own, re-pin "X changes nothing" against a twin, never by loosening the
constant.** H24 pinned "an untrusted sample drags nothing" as `x == 0` after a step; H26's wander moves the box on its
own clock, so that check failed although the property held. Widening the tolerance would have hidden a real drag of the
same size. Step a twin with the same seed and clock but WITHOUT the input, and assert exact equality (`==`, every
frame or at the end); measure a response the same way (difference from the twin). Mutation-check that a clock- or
input-dependent mutant now fails the twin check. *(2026-11-02, handoff H26, `walls.test.luau`.)*

**S16 — A yes/no judged against a MOVING line needs hysteresis, and a bot must aim inside the line, never at it.** H24's
walls judged "outside" with one threshold; H26 made the wall sway, and a Studio dummy patrolling into it (whose
`backIn` aimed only until it was in by a hair) flipped out/in every frame: ~1650 `walls:` lines in 48 s, each an at-once
MatchState. Give the state two thresholds (enter at the line, leave only a body-width past it, a Config knob), say in
the doc which event the reset belongs to, rate-limit the at-once send it drives (never a death), and keep a bot's goal
a margin inside the zone. Pin it with a runner dancing ON the moving line (one flip, then it dies) and mutation-check
"no hysteresis". *(2026-11-02, handoff H26 follow-up, `shared/Walls.outside`, `server/Bots`.)*

**S17 — "Nothing can ever be sealed" is tested in its worst case, with a reach model WEAKER than the real moves.** A
box rule (parts never overlap keep-clear zones) is only as good as the zones a map author drew. H27's test fills EVERY
tile the rule lets a part cover, then demands every orb and anchor stand is still joined to the spawn both ways, on a
tile-grid runner that jumps lower and drifts less than the game's (no dash, grapple or pad), so "reachable" in the
test is reachable in Play. Mutation-check it: remove the zones and watch it fail (the Yard: a floor orb walled in), and
let it judge old content too (the test map failed it and gained a zone). *(2026-11-07, handoff H27, `test/luau/maps.test.luau`.)*

**S18 — A test window or tolerance fitted to one start is a hidden assumption: state it in the system's own terms.**
The grapple's energy test asked "the peak is set in the first 60 frames, to 1e-6 absolute". That held for a swing
starting at rest at the arc's end; H28's yoink starts the swing mid-arc, and leapfrog's bounded error envelope (flat
to 1e-8 over 100 s, measured) settled 0.0045 above its first-second value, failing a test whose real question (does
the maths pump energy? Euler's +110 does) was untouched. Before changing such a test, measure over a long run that
the property still holds, then write the window as the system's own scale (a period, a close time) and the tolerance
relative to the quantity, with the measured number beside it. Never just widen it until it passes. *(2026-11-07,
handoff H28, `test/luau/grapple.test.luau`.)*

**S19 — A layout is laid out by driving its routes through the real movement, not by reading the numbers.** The
Yard's first pads and anchors were placed from the measured figures ("a pad rises 11 studs", "a rope reaches 7 tiles")
and QA found every pad landed under the next deck and no swing could be verified. A scratch probe that ran the real
`Movement` and `Grapple` from every deck edge (hook, hold, let go at several points, double jump or not) settled it in
minutes: a pad arc with the jump at its apex lands 12 tiles out and bonks a deck nearer than 8; a release's air speed
decays to the run in ~0.5 s so a swing carries ~10 tiles; a low anchor in a hole never lifts a floor runner. Three of
eight anchors were useless. Put the probe in the map test (`maps.test`: every pad lands a tier up, every anchor
carries deck to deck) so the next map is held to it, and keep the probe script's shape for the next kit piece.
*(2026-11-11, handoff H29, `test/luau/maps.test.luau`, `shared/MapYard.lua`.)*

**S20 — A feel change is sized by the speed check's burst, not by what feels right alone: drive the hardest chain
and read the budget before picking the number.** The release haul at 150 studs/s felt like the right size and spent
6.66 of the server's 24-stud x burst and 5.30 of its 10.5 up in the driven swing chain (from 1.38 and 2.47); at 140 it
spent 1.81 and 2.21. A pad up-launch above 2 x `JUMP_SPEED` likewise spends the up burst on every launch (4.50 of
10.5 at 120). Honest players must never get near a budget: two such moves back to back (a release onto a pad) add
up. So: make the knob, run `move_check*.test`, pin the measured use with a ceiling (under a fifth, under 60%), and
write the number's reason beside the knob. *(2026-11-11, handoff H30, `shared/Grapple.release`, `Config.PAD_SPEED_Y`.)*

**S21 — A plan tried in the head must be stepped exactly as it will be played: the same step, the same rules.** The
bots rate each plan by rolling it out through the real `Movement.step`. At a 1/30 rollout step a jump under a deck's
lip landed in the rollout and missed on the server's 1/60 frames: the bot hopped under the Hub for three seconds,
sure each time. Rolling out at the frame's step fixed it at once. A cheaper, coarser model of your own rules is a
different game. *(2026-11-16, handoff H31, `shared/BotBrain.STEP`, `test/luau/bots.test.luau`.)*

**S22 — A score rewards exactly what it measures, so read what the winner of it actually does.** Rating a seeking
plan by where it ENDS made a bot bonk its head under a platform on purpose (0.35 s lost, then it arrived exactly on
the orb) rather than run through the orb and overshoot; rating a fleeing plan by distance alone loved ending inside a
solid tile (distance: "unreachable"); minding the walls only at the plan's end let a bot step out and back a dozen
times. Each was found by printing every plan's score at one bad decision, not by staring at the formula. Score the
thing the game counts (a touch, soonest), and trace one decision before trusting a tuning.
*(2026-11-16, handoff H31, `BotBrain.rate`, `BoxWorld.far`.)*

**S23 — Before a room is built to NEED a move, measure what every other move already reaches.** In this kit one jump
peaks at 14.25 studs and carries 31 across, two carry 55, two and a dash 76, a swing about 40: no pit can need the
grapple, and none can need the dash outright. And Movement resolves a second jump press beside a wall as a wall
kick, so a tall solid ledge throws a beginner off it unless they take off far enough back. Drive the room through
the real Movement with a sweep of beginner timings (jump spot x second press), count the ways through without the
move, and when geometry cannot force a move, check the move itself (a hook and a let-go), not a crossing.
*(2026-11-22, handoff H41, `test/luau/tutorial.test.luau`, docs/systems/tutorial.md §3.)*

**S24 — A new way to spend a resource at a contact that refunds it is a loop: guard the new choice, not the
refund.** Rule 15 gives the double jump back on a wall touch; H42 made a press rising beside a wall a double jump.
Together, a held stick and a mashed button went straight up any wall (the chimney test: 0 kicks). Gating the refund
(no double back while rising) also stopped it, but changed an adopted rule and quietly took a route the bots used.
A "used since the floor" flag on the new choice closed the loop and left every old measurement identical. When a
rule spends something at a contact, drive the mashed-button case through the real step(), and compare the
neighbours' numbers (bots, routes) per case, not one summary line: a shared random sequence moves them all.
*(2026-11-22, handoff H42, `test/luau/wall_double.test.luau`, docs/systems/movement.md §3.)*

**S25 — Every step function must survive dt == 0: Heartbeat really sends it.** Roblox's Heartbeat handed the server
`dt == 0` 9 times in 30 s of Studio Play. Any `x / dt` (a velocity from a chord) is then 0 / 0 = NaN, and a NaN in
carried state (a rope's `w`) never leaves. Roblox hides it: a part given a NaN CFrame sits at (0, -1e6, 0), so the
body looks finite while the state is not; the error surfaces frames later somewhere innocent (a table index). Guard
the division at its source (`if dt <= 0 then return end`), test every step at dt 0, and have the server check a
simulated body's state is finite after each step (log once, reset) and isolate per-entity steps with `pcall`, so one
bad entity cannot stop the frame for everyone.
*(2026-11-22, handoff H43, `test/luau/zero_dt.test.luau`, docs/systems/bots.md §8.)*
