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
