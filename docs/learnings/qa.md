# Learnings: Q — QA loop and review

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ Q1").

**Q1 — A pure test suite cannot see a missing side effect.** Every rule passed `test:luau` while the player was never
TOLD. For anything the player is meant to notice, the checklist item is not "the value changed" but "the line
appeared and the HUD refreshed", and that item belongs in the Studio pass. *(inherited, rung 3 part 3.)*

**Q2 — Build a test's fixture the way production builds the object, or the test hides the bug.** Trace the real call
order and seed the fixture to match before asserting a migration or a merge. *(inherited, handoff H3.)*

**Q3 — A test that calls the inner function directly can pin the bug in place.** Drive the rule through the caller
that fires it in production, or set the fixture to the exact state that caller is in. *(inherited, handoff H5.)*

**Q4 — A per-cycle counter resets on the cycle's own signal, not on one of the paths that ends it.** Find the state
that defines the cycle and reset on its change, so every path that ends a cycle resets it; then test the path the
repro did NOT use. *(inherited, handoff H10.)*

**Q5 — A rule whose fixture already enforces it needs an assertion only the rule can produce.** A test world that
stops the runner at a roof passed with the ceiling rule deleted: the stand-in did the rule's job. Assert the thing
only the rule changes (the velocity on the bonk frame, not the position after it), and mutation-check every new rule
suite: delete each rule in turn and watch its test fail (→ S8). *(2026-10-09, handoff H1, `movement.test.luau`.)*
