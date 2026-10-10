# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-10-10

A routine session appends here the moment an escalation trigger fires (CLAUDE.md, "Model policy and
escalation"). The heavy agent reads this file first, works the open entries, records its full reasoning in
the doc the entry names, and marks the entry RESOLVED.

Keep this file small. Once the detail lives in the real doc, trim the resolved entry to its heading plus one
resolved line.

## Entry template

```
### H<n> — <one-line title> — <YYYY-MM-DD HH:MM> — OPEN
- **Trigger:** <which of the numbered triggers>
- **Doc:** <path> §<section>
- **Observed:** <what was seen, plainly — exact error text, failing test, the diff, the Studio Output line>
- **Evidence:** <commands run, file:line, export PNG, branch, commit>
- **Routine session's read:** <best guess, clearly marked as a guess>
- **Decision needed:** <the specific question or action>
- **Blocked routine work:** <what is on hold, if anything>

Resolution (added by the heavy agent under the same entry):
- **Resolved <date>:** <one line> → recorded in <path> §<section>
```

## Open

_None._

## Resolved

### H3 — Sprite pick for the new pose set: 8 run frames, jump rise/apex, fall, dash — 2026-10-10 15:05 — RESOLVED
- **Resolved 2026-10-10:** `RUN_FRAMES = 8`, `RUN_CYCLE` 20; dash → `runner_dash`; air by `vy` (y up) against new
  `Config.APEX_POSE_BELOW = HALF_GRAVITY_BELOW` (20): rise, apex, fall; a wall slide (new `s.sliding`, cap 10 sits
  inside the apex band) shows fall; a run from rest now really opens on frame 0 (new `s.runFrom`; it did not before).
  No move rule changed. Tests mutation-checked; test file at 398/400 lines. → `docs/systems/movement.md` §3, learnings A4.

### H2 — Run cycle: four frames (two strides, two passing poses) instead of two — 2026-10-10 14:40 — RESOLVED
- **Resolved 2026-10-10:** `Config.RUN_FRAMES = 4` (a count, not a name table) and `Config.RUN_CYCLE = 20` studs per full
  cycle replacing the per-frame `RUN_STRIDE`, so frame count and cadence are separate knobs; frames still change every
  5 studs, the legs cycle at half the old rate. Test pins frame order and cycle length (mutation-checked). Feel is
  Danzo's to judge; tune `RUN_CYCLE`. → `docs/systems/sprites-and-animation.md` §3, `docs/systems/movement.md` §3, learnings A3.

### H1 — First playable: side-on camera, one runner, sprites drawn two ways — 2026-10-09 — RESOLVED
- **Resolved 2026-10-09:** built by the heavy agent, played by Danzo the same day ("that worked and I actually quite
  like it"); he chose the SurfaceGui over the BillboardGui, and the negative-rect flip worked unaided. Loser deleted.
  → `docs/systems/movement.md` §2 (the body), §6 (drawing and flip), `docs/systems/sprites-and-animation.md` §4.
