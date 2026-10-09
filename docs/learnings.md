# Learnings

**Created:** 2026-10-09 · **Last updated:** 2026-10-09 (Q5)

Rules that **generalise** — things a session got wrong once and should never get wrong again. One-off typos and
trivia stay in the QA goals file or the commit message; they do not earn a line here.

`docs/PRINCIPLES.md` is the other rulebook: that one is about *what makes a good game*, this one is about *how
to work in this repo*. If a rule tells you what to do at a fork while building, it goes here. If it tells you
what to do at a fork while designing, it goes there.

Each rule has a stable ID so a handoff, a QA report or a commit can cite it (e.g. "→ S2"). Sections:

| ID | Section |
|---|---|
| **A** | Art — sprites, scenes, the renderer, animation |
| **S** | Shared Luau — purity, determinism, the rules modules |
| **N** | Networking and fairness — what the server trusts, remotes |
| **T** | Tooling — node CLI, Rojo, luau, the MCP Studio link |
| **G** | Git and generated files |
| **Q** | QA loop and review |

Behind each rule: the date and the branch or handoff that paid for it. Rules marked *(inherited)* were paid for in
The Warehouse (Lowlands, 2026-09/10) and restated here in this game's terms; the Lowlands-only ones (its save
format, its world sim) were left behind.

---

## A — Art

**A1 — Frame 0 is the rest pose, and an animated thing joins the animation already in progress.** Lowlands'
viewport names every animated tile `<base>_<frame>` and picks the frame from the clock (`floor(now * rate) % n`),
never from "when did this one appear", so two fires on screen flicker together and a tile that scrolls into view
never rewinds the water a frame. Entities drop back to frame 0 a short time after their last move. *(inherited,
`client/Viewport.lua`, `Client.client.lua`.)*

## S — Shared Luau

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

## N — Networking and fairness

**N1 — A mode that must never touch real data is gated where the store is OPENED, and read once at boot.** Returning
early from one load path is not enough; a later code path that calls the store directly would still reach the real
data. Default the mode to the side that cannot lose data, and force it off outside Studio. *(inherited, handoff H4,
Lowlands' `DevMode`.)*

**N2 — Movement and tags are checked by the server against the same pure rules the client predicts with.** Lowlands
put the step rule in `shared/Movement.lua` and ran it on both sides: the client predicts, the server validates, and
the client sets `Predicted*` attributes next to the server's authoritative ones so a Studio pass can compare them.
DESIGN §3 rule 6 asks for exactly this on tags: client overlap, server confirm, catch-up animation. *(inherited.)*

## T — Tooling

**T1 — The line ceiling in `test/structure.test.js` is a design input, not a lint you notice at the end.** The 400
line ceiling and any allow-list entry may only shrink. "Add it to the big file" is not available: new behaviour goes
in a new module. Check headroom **before** planning where code goes. *(inherited, handoff H1.)*

**T2 — Rojo does NOT sync into a Studio session that is already in Play, and a Studio `require` cache is per
DataModel.** Edits made after Play started are invisible until Play stops and starts again, and an `execute_luau`
call that required a module earlier keeps the OLD copy for the life of that DataModel. Stop Play, start Play, then
test. `execute_luau` also gets its own require cache, so it cannot read the running server's state: build a state of
the right shape and bind the module under test instead. *(inherited, rung 3 part 3.)*

**T3 — A cosmetic label is never worth an error.** Anything that might run before its data exists is looked up in a
`pcall`, and the line is worded the plain way if it fails. *(inherited, rung 3 part 3.)*

**T4 — Comments count against the line ceiling too.** `test/structure.test.js` counts every line. Put long
explanations in the folder README, not in a file near its ceiling. *(inherited, `refactor/ai-friendly`.)*

**T5 — A Studio test harness that moves the player is part of the experiment.** Before blaming the code, move the
harness away and see whether the fault goes with it. *(inherited, handoff H8.)*

## G — Git and generated files

**G1 — Generated files are regenerated, never edited, and only Danzo uploads.** `roblox/src/shared/Sprites.lua`
and `roblox/assets.lock.json` come from `node bin/warehouse.js roblox build`. Claude runs the build (it keeps the
old asset id and prints CHANGED); Danzo runs `--upload` and commits the pair. On the PC, if those two are locally
modified, `git checkout -- roblox/src/shared/Sprites.lua roblox/assets.lock.json` before `git pull`. *(inherited.)*

**G2 — The Rojo instance tree is an API: prove it unchanged with a sourcemap diff.** Code finds modules by name
(`Shared:WaitForChild("Config")`) and remotes by name, so any file move, rename or re-nest must leave the tree
identical: the same names, parents and classes (`.server.lua` Script, `.client.lua` LocalScript, `.lua`
ModuleScript). Run `rojo sourcemap roblox/default.project.json` before and after, and compare names, classNames and
nesting. `.md` files in `src/` are ignored by Rojo. Also: Windows paths are case-insensitive, so never create a file
that differs from an existing one only by case. *(inherited, `refactor/ai-friendly`.)*

**G3 — A doc that other files cite by section is an API too: split it behind a hub at the old path.** Keep the old
file as a hub with a table mapping every § and rule ID to its new file, keep the § numbers in the moved headings, and
move by LINE RANGE with a script (never retype). Prove "lose nothing" mechanically: every non-blank line of the old
file must be in the multiset of hub + new files; then a relative-link check over all tracked `.md`. *(inherited,
handoff H2.)*

## Q — QA loop and review

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
