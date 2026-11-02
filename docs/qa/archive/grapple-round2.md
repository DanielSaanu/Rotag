# QA round 2: the grapple — SCORE 7/10

Reviewer: Opus subagent, 2026-11-02, with Studio (one Play, root and rope/halo logged every Heartbeat, keys driven through the MCP). Report verbatim:

SCORE: 7/10

**What I ran**
- `npm test`: all pass. The five swing chains are unflagged: x 1.38 of 24, up 2.96 of 10.5, down 2.21 of 16.
- `npm run lint:luau`: clean.
- A scratch Luau sim of air hooks, with and without the floor cap.
- One Studio Play. I logged the root and the rope/halo state every Heartbeat and drove the keys through the MCP. Play is stopped.
- Output: no `move:` line and no errors. The only noise is the existing `ContentId: rbxassetid://203785492 failed`.

**What I saw in Studio**
- **Behind-skip works.** Sprinting right from x -60, the halo on anchor 1 (-56,20) disappeared at x -55 once the runner passed it at 52.
- **Armed hook works.** I jumped at x -32 and held W. The hook came about 0.23 s later, past the 0.1 s buffer, at (-17.7, 7.7) on anchor 2.
- **Floor clearance works.** The rope capped at 21.25 and the lowest point was y 2.75–2.8 (feet about 1 stud up). The swing reached 101 at the bottom and held about 75 over 2.5 s. Let go at x -4.7 gave vx 65→72 (the 1.1 boost).
- **NEW REGRESSION: anchors 2 (-4,24) and 4 (60,24) can no longer be hooked from the floor.**
  - Standing at (58.9, 1.8) under anchor 4 with W held (re-pressed once): no halo, no hook.
  - The camera centre is feet + `CAMERA_Y_OFFSET` 4 = 5.8, with halfH 24, so the screen top is 29.75. Minus `GRAPPLE_INSET_TOP` 6, that is 23.75. Both anchors sit at 24.
  - I confirmed it with `Grapple.pick` on the measured view: standing under each anchor, only anchors 1 and 6 (y 20) are picked.
  - Round 1's praised "floor hook under anchor 4", and Danzo's steps 1/7, now only work on two of six balls.
- **Swing hits PlatformLow's side.** On anchor 2's 21-stud rope, the forward swing hit the left edge of PlatformLow (x 12) at (11, 9) on both passes. v went (58,56)→(0,-61) in one frame and the swing reversed. It reads as a bonk.

GOALS:
- Marked anchors: met. Six tagged Persistent, CanQuery off; disc enlarged to 3.4 and darker (Arena.lua:117-118). I did not get a usable capture: the one shot came back blank at the fuse's end.
- Aim assist, readable: partial. Behind-skip and stickiness work live. The top inset hides y-24 anchors from a standing runner (above).
- Hold to hang, easy to start: partial. The armed air hook works (seen live). A floor hook is possible under only two anchors.
- A rope that swings true: met. Leapfrog energy holds; the sim shows the reel adds energy, never loses it (caught E 3961 → 4987).
- Release keeps the swing: met. The floor-cap fix is seen live (low point 2.8, release 72). The dash off the rope is untested this round (a trap/freeze hold interfered).
- Refresh on the hook: met. Movement.lua:259.
- Ghosts never grapple: met in code (client/Grapple.lua:86-88). After burn-out the halo and rope stayed hidden; no active ghost input was tried.
- The server is never fooled: met. No remote, `RATE_X` unchanged, tests unflagged, no `move:` lines.
- Every screen sees the rope: partial. Own rope seen; others' are still untested (dummies don't stream).
- The touch button: met (code only).
- Cheap every frame: met. The filter is rebuilt only on a character change (client/Grapple.lua:93-96).
- Verification: met. Tests and lint pass. Movement.lua is now 362 lines (the goals say 357); the structure test passes.

PRESERVE (done well, must survive future iterations):
- **Floor cap in `Grapple.attach` (shared/Grapple.lua:68-70) plus the once-per-rebuild floor ray.** Live: the air hook that scraped in round 1 now clears by 1 stud and keeps about 100 studs/s.
- **Motion-based behind-skip (`GRAPPLE_BEHIND_FAST`).** The sprint-past case no longer brakes the run, and a walk still allows a hook behind.
- **The armed hook (Movement.lua:247-251).** Hold W early in the air and it hooks when an anchor comes; landing disarms it.
- **Angle leapfrog, the inelastic catch, and no new trust.** These were all praised in round 1 and still hold.

FIX (done poorly; why it matters; concretely how to fix):
- **The top inset blocks floor hooks on y-24 anchors.**
  - Why: a beginner standing under the ball over the spawn, or under anchor 4, holds W and nothing happens. That breaks "easy to start" and Danzo's test steps 1 and 7.
  - How (cheapest): lower anchors 2 and 4 to y 22 (5.5 tiles) in Arena.ANCHORS, Arena.lua:62,64.
  - Alternative: apply `GRAPPLE_INSET_TOP` only inside the banner's horizontal span (about ±10 studs of the view centre), or narrow the banner.
  - Add a test that every `Arena.ANCHORS` entry is pickable while standing under it, using the real camera framing (`CAMERA_Y_OFFSET`, `CAMERA_VIEW_HEIGHT`).
- **The test that "fixed" the inset used a view centred on the runner.** grapple.test.luau:62-64 uses VIEW y 0. The real camera sits 4 above the feet, so the test missed the regression. → Build test views from Config's camera numbers, not a hand-made box.

CONSIDER (fine but could change; why; how):
- **The anchor 2 swing bonks PlatformLow's left edge.** A swing that stops dead on a corner reads as a glitch, and the floor ray only looks straight down. → Move anchor 2 left a few studs, or shorten its rope by checking the arc's horizontal reach against static blocks at rebuild.
- **Ghost pieces can sit under an anchor's swing.** The keep-clear box is only 4x4 round the ball, and the floor ray runs once at rebuild, so a placed piece under the arc ends swings. → Widen the "anchor" keep-clear to a column under each anchor, down to its floor.
- **The floor ray depends on streaming order.** StreamingEnabled is true, and the Map blocks are not Persistent. If the anchors' tag events fire before the floor streams in, `floor` stays nil and the old scrape returns. It worked in Studio. → Make Map Persistent too (it is small), or re-run `rebuild` when Map gets children.
- **Rope parts of leavers are still never destroyed.** This was deferred and is harmless.

UNCERTAIN (could not verify):
- The dash off the rope (the 120 redirect): a trap/freeze hold and the missing floor hook interfered.
- Other runners' ropes over the stream, which needs two clients.
- The disc's look under bloom: no usable screen capture (it came back blank at the fuse's end).
- The phone GRAPPLE button: lit and dim states, and thumbing it while pressing JUMP.
- Feel, for Danzo's hands:
  - whether the 1.1 boost feels like a reward
  - whether the cap at 120 feels like a wall at the bottom of a long swing
  - whether the reel on a far-side floor hook feels like a yank
  - the pump strength (`GRAPPLE_PUMP` 60)

## Builder decisions

- **FIX the top inset hiding the y-24 anchors: fixed.** Anchors 2, 3 and 4 lowered half a tile (22, 30, 22); anchor 2 also
  moved to x -8. `server/Arena.lua` records the limit (over a floor at y f an anchor is picked up to f + 23.75).
  Seen in Studio: standing at (-7.9, 1.8) under anchor 2, holding W hooked and hung at y 2.8 (feet a stud up) on a
  17.8-stud rope with a gentle swing, no halo while hanging, no `move:` line. Live `Grapple.pick` through the real
  framing (viewport 1656 x 606): anchors 1, 2, 4 and 6 picked from the floor under them; 3 and 5 are out of reach
  from the floor by design (hooked from PlatformLow and the shaft walls).
- **FIX the test's hand-made view: fixed.** A new test stands under every anchor from every block top in reach, with
  the view built from `CAMERA_Y_OFFSET` and `CAMERA_VIEW_HEIGHT` on a 4:3 screen; `test/luau/run.js` lifts `BLOCKS`
  and `ANCHORS` out of `server/Arena.lua` as an `ArenaData` module (Arena itself is not pure). It failed on the old
  anchors at exactly the reviewer's case ("anchor (-4, 24) ... standing on Floor") before the move. The unit tests'
  box view stays: those test the pick rules, not the camera.
- **CONSIDER the anchor 2 swing bonking PlatformLow: fixed by the move.** At x -8 the longest floor rope (19.25) ends
  0.75 short of the platform's left edge at 12.
- **CONSIDER the floor ray and streaming order: fixed.** The client looks again for a missing floor up to 5 times, a
  second apart (`FLOOR_TRIES`).
- **CONSIDER a keep-clear column under each anchor: deferred.** A piece in the arc is a legitimate ghost play (pieces
  block everyone), and a column would guard only the low point.
- **CONSIDER leavers' rope parts: deferred** (hidden, a few parts at most), as in round 1.
- **Noted for the next reviewer:** driving the runner through the MCP one call at a time burns the 45 s fuse (each call's
  turnaround is seconds); put the walk, the stop and the press in ONE keyboard call and read straight after.
