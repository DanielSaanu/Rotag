# QA round 1: the grapple — SCORE 7/10

Reviewer: Opus subagent, 2026-11-01, with Studio (two sessions, the runner's position and velocity logged every step). Report verbatim:

SCORE: 7/10

What I ran: `npm test` (13 node and 15 Luau suites, all pass, including grapple and move_check_grapple; the five swing chains are never flagged, worst x budget 1.38 of 24), `npm run lint:luau` (clean), `rojo build` (passes). I played two Studio sessions through the MCP, logging the runner's root position and velocity every Heartbeat or every physics step from the Client datamodel. In the first session my fuse burned out, which left me as a ghost for part of it. The server Output has 169 lines, with no `move:` line, no warnings and no errors.

**What I saw in Studio (in brief)**
- **Floor hook under anchor 4 (60,24):** smooth and not a glitch. Feet at y 1.75, the reel lifts the runner to 3.6, and the low point settles at 2.75, 1 stud above the floor. The drawn rope went 21.6 → 19.8.
- **Hang and pump under anchor 1:** off-beat D/A input still built the swing from ±19 to ±66 studs/s in about 3 s. No halo shows while hanging.
- **Running past a ball, then an air hook on the ball behind (rule 17's nearest pick):**
  - I ran right from -60, jumped, and held W. The halo sat on anchor 1 (-56,20), behind me, for the whole run.
  - The hook at (-41.9, 9.9) took v(49,17) to (2,3) within 0.07 s, then swung me back left.
  - At 6.85 to 6.88 the arc grazed the floor (y 2.1 → 1.8). The landing took the rope while W was still held, and the -74 swing died on the ground in 0.15 s.
- **Floor hook on anchor 2 while running at 50:** the swing kept the run (59 to 60). Jump off the rope gave vy 52, and the double jump fired 0.45 s later (vy 52). Both work.
- **As a ghost:** W never hooked and no halo appeared, over about 20 s of input.
- **Capture `QA_hang`:** the picked anchor and its halo overlap the "YOU'RE IT 45.0" banner. The anchor at top-left also touches "ITEM: none".
- **Close crop of the anchors:** the "dark disc" does not read. Neon bloom turns it into a pale-yellow ring, so each anchor is one yellow blob. The white halo ring is clear.

GOALS:
- Marked anchors: partial. 6 tagged and Persistent, CanCollide and CanQuery false (checked live), "anchor" keep-clear boxes in place (Arena.lua:74). The dark disc is invisible under bloom.
- Aim assist, readable: partial. The halo is clear and pulses. It picks the ball behind a full-speed runner, and anchors near the top edge sit under the HUD banner (`QA_hang`).
- Hold to hang, easy to start: met. Floor reel measured 1.75 → 2.75; the pump builds the swing quickly. A W already held when a ball comes into range never hooks (it needs a fresh press, Movement.lua:244-252).
- A rope that swings true: met. Leapfrog plus the catch and slack logic (shared/Grapple.lua:87-118); tests pass; the swing looked like a clean pendulum in the logs.
- Release keeps the swing: partial. Jump off and double jump confirmed. An air hook on a long rope scrapes the floor and silently drops the rope, losing the swing.
- Refresh on the hook: met. Movement.lua:252 calls `refresh(s)`, behind `GRAPPLE_REFRESH`.
- Ghosts never grapple: met. Seen live (no halo, no hook); Grapple.frame clears the input for ghosts (client/Grapple.lua:83-86).
- The server is never fooled: met. No new remote; `RATE_X = max(...)` = 120; the server relays the raw buffer and never reads byte 13 (Snapshots.lua:45-63); no `move:` lines in my sessions.
- Every screen sees the rope: partial. I saw my own Rope part (Transparency 0, length logged). Others' ropes are untested: the dummies have no stream.
- The touch button: met (code only). Controls.lua:203-204 dims it, and the hook selection is chained in Client.client.lua:231.
- Cheap every frame: met, with one small allocation each physics step (see CONSIDER).
- Verification: met. 13 node and 15 Luau suites, lint clean, build ok, Movement 357 and Client 314 lines. I did not re-run the 20 mutations.

PRESERVE (done well, must survive future iterations):
- Angle-space leapfrog with an inelastic catch and slack over the top (shared/Grapple.lua): the swing kept its energy in play, and grapple.md §3 explains why the position projection was dropped.
- The grapple adds nothing the server trusts: the cap equals the dash speed, so `RATE_X` is unchanged, there is no remote, and the anchor byte is only for drawing. This kept trigger 3 closed.
- The floor-hook reel to GRAPPLE_LIFT: it swings instead of dragging, as measured.
- The ghost gating in one place (Grapple.frame), and the halo hidden while hanging.
- move_check_grapple.test.luau's driven chains with budget printouts: this is the kind of evidence a later tuning PR needs.

FIX (done poorly; why it matters; concretely how to fix):
- Air hooks swing into the floor and drop the rope: anchors 1, 2, 4 and 6 sit 18 to 22 studs above standing height, and the range is 28. Any air hook from more than about 18 studs away gives a low point at or below GROUND_SNAP. Movement.lua:163 then releases with no boost, and the ground eats the speed (seen: -74 → 0 in 0.15 s with W held). That breaks "run feeds a swing" and reads as a glitch. → Give each anchor a `floor` once, in client/Grapple.rebuild (a ray down from the anchor; the map is static). In Grapple.attach, cap `target` at `a.y - floor - RUNNER_HALF_HEIGHT - GRAPPLE_LIFT` for air hooks too, so the reel lifts the arc clear. Add a test: an air hook from 25 studs on a 20-stud-high anchor never lands mid-swing.
- A hook behind a fast runner kills its momentum: v(49,17) → (2,3), because the velocity is almost all radial, so the catch discards it. With no ball ahead in range, the halo sits behind you all the way, so the most natural first try (run, jump, W) feels like a brake. → Take the grapple.md §10 option: skip anchors behind the facing while `|vx| > RUN_SPEED * 0.8`, or skip any anchor with `dx * vx < 0` and `|vx|` high. Add a pick test for it.
- The HUD banner covers top-of-screen anchors: GRAPPLE_INSET is 2 studs, so a picked anchor can sit under "YOU'RE IT 45.0" (`QA_hang`) or touch "ITEM: none". → Add a separate top inset of about the banner's height in studs (around 6), or move the banner. The anchor W will take must never be under text.

CONSIDER (fine but could change; why; how):
- Hook while held: a beginner who holds W before reaching a ball gets nothing, because the 0.1 s buffer has expired. → After the buffer, still hook if W was pressed while airborne and is still held. A landing would clear that flag, so standing on the floor never auto-hooks.
- The dark disc behind the gold ball does not show under Neon bloom. → Darken it more, make it larger (3.2), or switch the ball to SmoothPlastic with a separate small glow. Rule 29 wants anchors to be unmistakable.
- client/Grapple.lua:92 reads `params.FilterDescendantsInstances` each physics step (about 240 Hz in Studio). The getter allocates a table every time. → Cache the last character in a local and compare against that.
- A jump off the rope sends `ev.jump = "ground"` (Movement.lua:210), so other screens play a ground-jump puff in mid-air. → Send "double" or a new effect.
- The anchor byte is unvalidated cosmetics: a modified client could draw a fake rope, ghosts included. Harmless now. Note it in trust.md §11.
- Rope parts for players who leave are hidden, never destroyed. Clean them up when Others forgets the player.

UNCERTAIN (could not verify):
- Other runners' ropes over the snapshot stream: the dummies don't stream or grapple, so this needs a 2-client test.
- The touch GRAPPLE button: lit and dim states, and holding it while pressing JUMP on a phone.
- An airborne dash off the rope: my dash came after a floor scrape. The builder saw +120.
- One early floor hook at (53,1.8) did not fire. It coincided with the round's "GO!" reset, which I believe applied a hold. It did not reproduce.
- The 20 mutations: I did not re-run them.
- Feel, which needs Danzo's hands: whether a floor hook on a far-side ball feels like a yank (it measured smooth), whether the swing feels capped at 120, the pump strength, and the 1.1 release boost.

## Builder decisions

- **FIX air hooks swinging into the floor: fixed.** Each anchor learns the floor under it once (a ray down at
  rebuild); `Grapple.attach` caps the rope so the swing's low point stays a LIFT above that floor, for air hooks too.
  Test: an air hook from 23 studs on a 20-high anchor over a floor swings 3 s without touching it.
- **FIX a hook behind a sprinting runner: fixed.** `Grapple.pick` skips any anchor behind the MOTION while faster than
  `GRAPPLE_BEHIND_FAST` (0.8) x run; at a walk, or facing the other way, it is still a pick. Tested.
- **FIX anchors under the HUD banner: fixed.** `GRAPPLE_INSET_TOP` 6 studs below the screen's top. Tested.
- **CONSIDER hook while held: fixed** (cheap, the beginner case): a press made in the air and still held arms the hook
  for the next anchor in reach; landing, letting go or a hold disarms it; standing on the floor never auto-hooks. Tested.
- **CONSIDER the disc: fixed** (bigger, 3.4, and darker).
- **CONSIDER the per-step allocation: fixed** (the filter is rebuilt only when the character changes).
- **CONSIDER the mid-air "ground" puff: fixed** (a jump off the rope reports "double").
- **CONSIDER the anchor byte note: done** (trust.md §11).
- **CONSIDER rope parts of leavers: deferred** (hidden, a few parts at most).
