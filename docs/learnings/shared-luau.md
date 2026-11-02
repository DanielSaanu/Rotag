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
