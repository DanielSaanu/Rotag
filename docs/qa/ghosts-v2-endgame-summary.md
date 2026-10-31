# QA summary: ghosts v2 endgame (PR 5, H23) — 8/10, target met in round 1

Goals: [ghosts-v2-endgame.md](ghosts-v2-endgame.md). Round (verbatim report): `archive/ghosts-v2-endgame-round1.md`.
The reviewer was an Opus subagent with Studio; 2026-10-31.

| Round | Score | Main finding |
|---|---|---|
| 1 | 8/10 | The end phase, its server decision, the speed and the speed check all met and measured; the ignition, readout and burn-out seen on screen; the holder's sprite whited out in the last second and a burst against a wall was cut in half. |

## Fixed (round 1)

- The embers' light emission halved and their top rate 60 → 35 a second, so the ember rim stays the readable signal
  instead of a white-yellow blob.
- The burn-out burst sits in front of the map's front face (z 4.6), so a runner caught against a wall gets a whole burst.
  Seen after the fix: a real burn-out burst at z 4.6 on the player's own runner.
- The holder's off-screen edge arrow beats red → hot yellow as it ignites (`Tagging.ignition` into `Arrows.update`).
- The FINAL TWO line has a dark stroke and a brighter orange; the flash swell is 0.5 s.

## Preserved

- `Tag.endPhase` keeps no flag: it is worked out from the living count and the round's start, so the server and the
  tests cannot drift.
- `MoveCheck` untouched, proven by driving 10 s at the top multiplier (the 1.38-stud burst use pinned as a measurement).
- One `Tag.ignition` curve drives the rim, the embers, the light and the readout.
- The point light is what reads at play zoom.
- Clients normalise `endPhase == true`; an older server or a malformed field reads as off.

## Deferred

- A duel that reaches the time cap is labelled FINAL TWO, not OVERTIME: needs the round's start count in `MatchState`;
  rounds start with two only in Studio today.
- A holder who leaves may get a burst at its last drawn spot if the state lands before the model removal: harmless, rare.
- Sounds for the beat (rule 2's "beeps"); the ignition art on the sheet (the first cosmetic slot).

## Calls Danzo should confirm (made while he was out; recorded in endgame.md and the goals file)

- `END_PHASE_AFTER` = 120 s (the proposal guessed 150): the final two normally come first at about 83-100 s; the cap
  only catches a round that passes keep alive, which then ends near 3:00.
- "The final two" means a round that began with three or more; DESIGN rule 51's wording now says so.
- `MoveCheck` was not scaled by the end-phase speed: the tests drive it and show it is not needed.
- The look is placeholder (ember rim, stock particles, a light, a neon ball for the burn-out).
- Ghosts and the Studio dummies do not get the end-phase speed.

## Danzo's Play checklist (Studio, `STUDIO_DUMMIES = 3`, keyboard)

Set `Config.STUDIO_DUMMY_TAGS = false` first so the dummies cannot tag you back at the cap; put it back to `true`
before committing.

1. Round start, you are it: stand still. At 10.0 the readout turns red and beats; you get a red-orange rim, embers and
   a red glow on the floor and wall, growing and quickening to 0. Can you still see your own figure in the last
   second? Readable without the HUD? Too much or too little?
2. At 0: an orange burst where you stood; you are a ghost. Watch the next holder (a dummy) ignite the same way, and
   watch its edge arrow beat red-yellow when it is off screen.
3. After the second burn-out: the `FINAL TWO: everyone +10% speed` line flashes in.
4. Next round, stay alive to the final two, then run flat out on the long floor, before and after the line: is +10%
   noticeable? As "it" after about 5 s of chase too. Should the end phase also shorten the fuse or shrink the map (PR 6)?
5. Does a 2:00 cap feel right, or leave a long round alone until 2:30 (150)?
6. Two players, if there is a second keyboard: the other screen sees your ignition and your burn-out burst at the
   same spot.
