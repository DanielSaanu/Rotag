# QA summary: ghosts v2 closing walls (PR 5b, H24) — 8/10, target met in round 1

Goals: [ghosts-v2-walls.md](ghosts-v2-walls.md). Round (verbatim report): `archive/ghosts-v2-walls-round1.md`.
The reviewer was an Opus subagent with Studio; 2026-11-01. Danzo's loop question: a harmonious blend of the best of
SpeedRunners and PR 5's best elements and core idea.

| Round | Score | Main finding |
|---|---|---|
| 1 | 8/10 | The walls, seen on screen for the first time, "read instantly as the screen closing in" and arrive on the same frame as the burn-out and the end-phase line, "one moment, not two systems"; the GET BACK IN label covered the end-phase line and the red band read mauve. |

## Fixed (round 1)

- The GET BACK IN label sits in a fixed row under the end-phase line (screen y 193-263 against the line's 164-188)
  and is 90% of the screen wide instead of a fixed 600 px.
- The band past each wall is a warm red at 0.6 transparency instead of a mauve haze.
- The grace count no longer saw-tooths during a hold: the server marks the row `held` and the client stops counting.
- A holder whose fuse ran out while standing outside gets the orange burn-out burst, not the walls' red.
- The walls' beat runs on the real close progress (from the width they opened at), not a fixed start width.
- The 4-a-second state resend runs only while the walls move; a settled box sends on changes only.

## Preserved

- `Tag.eliminate` as the one elimination path for burn-outs and wall kills.
- The server judges its own trusted record; an untrusted sample changes nothing either way.
- The neon edges: the SpeedRunners element done right.
- The grace pauses for any hold and the tag freeze.
- `WALL_START_MIN`: the walls open at the screen's edge and visibly sweep in.
- PR 5's preserve list still holds (no stored flag, one ignition curve, the point light, `MoveCheck` untouched).

## Deferred

- A leaver who was outside may get a red burst at its last drawn spot on other screens (rare, harmless; needs the
  round's order in `MatchState` to tell a leave from a kill).
- The phone layout of the GET BACK IN line (44 px text in a 90%-wide row) is untested; phone feel is parked.
- A wall kill and the real GET BACK IN count were not seen live by the reviewer (no dummy stayed outside; the builder
  saw both in Output with a short time cap).

## Calls Danzo should confirm (made while he was out; recorded in endgame.md §7 and the goals file)

- DESIGN §2 untouched: a world window everyone sees, not a shared camera; every player keeps their own camera.
- A 3 s grace that resets fully on return; the walls start with the end phase (not at the first burn-out); the
  window follows the living mean slowly; it stops at a 48-stud box after 20 s and opens at least half a screen wide.
- No camera zoom; the +10% end-phase speed kept alongside the walls.
- A wall kill is a full elimination; the grace pauses during any hold; placeholder look.

## Danzo's Play checklist (Studio, `STUDIO_DUMMIES = 3`, keyboard)

Set `Config.END_PHASE_AFTER = 15` and `Config.STUDIO_DUMMY_TAGS = false` to reach the walls fast; put both back (120,
`true`) before committing.

1. At 0:15: `OVERTIME: the walls close in  |  +10% speed`, and two red walls near the screen's edges sweep in, beating
   faster as they close. Do they read at once as "the screen is closing", SpeedRunners-style?
2. Run out past a wall: `GET BACK IN  3.0` with an arrow home, under the end-phase line, counting down and beating
   faster. Back in: gone. Out again: a full 3.0. Is 3 s scary enough and fair enough?
3. Stay out: at 0 a red burst where you stood; you are a ghost and cross the walls freely.
4. Watch the walls close to a box about 12 tiles wide and stop. Do they sway with the pack? Too fast, too slow?
5. Next round survive to the final two: the walls push you together while the fuse ignites. One ending, or two things
   at once? Is the +10% still worth having with the walls?
6. Two players, if there is a second keyboard: both screens show the walls at the same place; a wall kill bursts red
   on both.
