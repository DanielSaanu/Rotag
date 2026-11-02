# QA summary: the moving walls (H26)

Goals: `docs/qa/ghosts-v2-walls-2.md`. One round of one Opus reviewer in Studio, 2026-11-02. The verbatim round report
is `docs/qa/archive/ghosts-v2-walls-2-round1.md` (do not re-read it in a build session).

| Round | Score | Main finding |
|---|---|---|
| 1 | 8/10 | Target met. Five rounds in Play: a new seed each round, the box never past -80, the fastest wall 8.2 studs/s, 0 flap lines over 8 minutes of walls, GET BACK IN on and off exactly once with no flicker. The edges hopped 0.29 studs at each MatchState. |

## Fixed

- **Before the loop (the heavy's follow-up, seen by the routine session):** a runner at the edge flapped outside/inside
  many times a second once the box swayed (about 1650 `walls:` lines in 48 s). Hysteresis: back inside only when the
  whole body is in (`WALL_BACK_IN` 2); out/in sends capped at 5 a second, a death at once; dummies keep 4 studs inside
  (`server/Bots` through `Walls.room`). After: 0 flap lines, a held-out dummy still dies at 3.00 s.
- **Round 1:** the client draws the walls from a smoothed window that closes the gap to the extrapolated one at 15/s
  (the wander's acceleration put each MatchState ~0.29 studs off the extrapolation). Measured after: the largest
  per-frame jump of a closed box's wall fell from 0.290 to 0.037 studs over 2882 frames, none over 0.1. The local
  GET BACK IN prediction got the same hysteresis band as the server. `docs/systems/endgame.md` §7 (304 lines, over the
  ceiling) became `docs/systems/walls.md` with the same §7.x numbers and a stub at the old place (G3).

## Preserved (the reviewer's list)

- The hysteresis and the 0.2 s cap on at-once sends.
- One clamp (`Walls.within`) bounds both the open and the target, so the eased centre stays inside the map on its own.
- The trust argument pinned against a twin with the same seed; the wander a pure function of the server's clock.
- Dummies kept inside by `Walls.room`; ghost dummies roam freely.
- The fade-in of the wander, so the open still reads as "the screen is closing".
- H24's list still holds: the grace and its pauses, the death order, `Tag.eliminate` as the one path, the edges, the
  open at the screen's edges, GET BACK IN.

## Deferred

- The mean and the lean read each runner's newest sample; an untrusted one drops that runner (the box lurches toward
  the other in a duel, hidden by the easing; not exploitable, it only moves the box against the cheater). Using the
  last TRUSTED sample instead is a `shared/Walls` change for the next walls handoff (walls.md §7.8).

## Open from the last round

None. UNCERTAIN, for Danzo and a four-client test: the feel (below); the lean seen live as "it"; a still runner far
from the pack pushed out by the sway alone; real ping (the prediction, the resend load).

## Danzo's checklist (Studio, keyboard; `STUDIO_DUMMIES` 3)

Set `Config.END_PHASE_AFTER = 15` and `Config.STUDIO_DUMMY_TAGS = false` to reach the walls fast; put both back (120,
`true`) before committing.

1. At 0:15 the walls sweep in from the screen's edges as before; the first seconds look like the old close, no sway.
2. After ~20 s the box is closed. **Stand still in the middle for 20 s.** It should drift side to side, never the same
   way twice, slowly enough to walk away from. Does it read as "the screen is moving, keep going" or as random?
   Knobs: `WALL_DRIFT` 20 (12 if it feels random or cheap), `WALL_DRIFT_PERIOD` 8 s.
3. **Stand still near one wall.** You should get pushed out within a few seconds of the sway turning toward you
   (`GET BACK IN 3.0`); one full step in clears it, and the label must never flicker. Did the wall ever feel like it
   killed you with no warning?
4. **Run laps inside the box.** Harder than before, because the far wall is not where you left it?
5. **As "it", chase a dummy:** the box should sit a little toward you (`WALL_LEAN` 0.25; 0 turns it off; -0.25 leans
   toward the chased runner instead, if that is what you meant by "follows the runner").
6. **Run to the far left end wall during the close.** The box stops at the end wall, never past it.
7. Watch a wall's edge while you stand still: it should glide, with no visible step 4 times a second.

The builder's calls to confirm or overturn (walls.md §7.7): a wander plus a quarter-lean toward "it" on the living
mean (not a patrol, not a lean toward the runners); the wander fading in with the close; the test map's end walls as
the bounds.
