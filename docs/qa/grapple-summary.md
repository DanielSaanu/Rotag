# QA summary: the living grapple (H25)

Goals: `docs/qa/grapple.md`. Three rounds of one Opus reviewer in Studio, 2026-11-01 to 2026-11-02. The verbatim
round reports are in `docs/qa/archive/grapple-round{1,2,3}.md` (do not re-read them in a build session).

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | An air hook on a long rope swung into the floor and lost the swing; a hook behind a sprinter braked the run; anchors sat under the HUD banner. |
| 2 | 7/10 | The round 1 banner inset hid the two y-24 anchors from a runner standing under them (the camera sits 4 above the runner; round 1's test had centred the view on it). |
| 3 | 8/10 | Target met. Every hook seen live settled a stud above the floor; the first dash off the rope: -15 to -120 the way it steered, and it landed a tag. |

## Fixed

- **Round 1:** each anchor learns the floor under it and `Grapple.attach` caps the rope so the low point clears it
  (air hooks too); `pick` skips anchors behind the MOTION above 0.8 x run; `GRAPPLE_INSET_TOP` 6 below the screen top;
  a press held in the air ARMS the hook for the next anchor in reach; a bigger, darker disc; the line-of-sight filter
  rebuilt only on a character change; a jump off the rope reports "double" (the mid-air puff on other screens);
  the anchor byte noted in trust.md §11.
- **Round 2:** anchors 2, 3 and 4 lowered half a tile (22, 30, 22) and anchor 2 moved to x -8 (its arc bonked
  PlatformLow's edge); a test stands under every anchor on the real map from every block top in reach, through the
  real framing (`test/luau/run.js` lifts `BLOCKS` and `ANCHORS` out of `server/Arena.lua` as `ArenaData`); the client
  retries a missing floor ray while the map streams in.
- **Round 3:** the floor ray includes only `Workspace.Map` (a runner or a ghost piece can never become an anchor's
  floor); one retry in flight at most; hysteresis on the behind-skip (`GRAPPLE_BEHIND_SLOW` 0.7) so the halo never
  blinks while slowing past a ball.

## Preserved (confirmed across rounds)

- The angle-space leapfrog with the inelastic catch and slack over the top (`shared/Grapple.lua`): the swing keeps its
  energy; grapple.md §3 says why the position projection was dropped.
- Nothing new for the server to trust: the swing is capped at the dash speed, `RATE_X` stays 120, no remote, the
  anchor byte is drawing only. Held for every move tried in three rounds; never a `move:` line.
- The floor cap plus the reel to `GRAPPLE_LIFT`: every hook seen live settled 1 stud above the floor.
- Dash off the rope = a plain 120 dash: instant redirect, still lands tags.
- The motion-based behind-skip, the armed hook, the halo off while hanging, ghost gating in one place (`Grapple.frame`).
- The real-framing anchor test: PR 6's per-map anchors must run through it.
- `move_check_grapple.test.luau`'s driven chains with budget printouts (x 1.38 of 24, up 2.96 of 10.5, down 2.21 of 16).

## Deferred

- Leavers' rope parts stay hidden, never destroyed: a few parts at most.
- A keep-clear column under each anchor: a piece in the arc is a legitimate ghost play, and a column would only guard
  the low point.
- The disc reads as a rim under neon bloom: the anchor is unmistakable as it is; the art block chooses the look.

## Open from the last round

None: every FIX was acted on. UNCERTAIN across all rounds, for a two-client test later: other runners' ropes over the
stream; the phone GRAPPLE button (lit and dim, thumbing it while pressing JUMP).

## Danzo's checklist (keyboard, then a phone)

Play as the living (`Config.STUDIO_DUMMY_TAGS = false` keeps the dummies off you; put it back before committing).

1. Stand under the far-left gold ball, hold **W**: you lift a stud and hang. Push **D** and **A** with the swing. Does
   it get going easily? Too slow or too wild (`GRAPPLE_PUMP` 60)?
2. Stand 10 studs to the side of a ball and hold W: the rope pulls you up and across. A pull, or a snap?
3. Run right, jump, hold W toward the ball over the spawn (x -8): let go past the low point. Fast and far? Does the
   1.1 boost read as a reward (`GRAPPLE_RELEASE_BOOST`)?
4. Swing, let go, **Shift**: the dash takes your swing into a 120 dash the way you steer. One move? Also try the dash
   from a SLOW point of the swing: a launch, or a reset?
5. Swing and press **Space** instead of letting go: a jump off the rope, then a double jump.
6. Chain balls left to right without touching the floor. Is the halo always on the ball W will take? Ever one behind
   you while sprinting (it should not be), ever a blink?
7. Swing hard on the longest rope. Does the bottom feel capped (120 = the dash)? Ever floaty?
8. As a ghost: W turns your piece and never hooks.
9. On a phone: the GRAPPLE button above JUMP, lit when a ball is in reach. Hold it with the thumb while jumping?

The builder's calls to confirm or overturn (grapple.md §10): the 120 cap, a hook behind you allowed at a walk, the
refresh on the hook, no boost on a dash off the rope, hold-to-hang, the placeholder look.
