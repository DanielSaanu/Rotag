# The grapple: hold to hang on marked anchors, release keeps the swing

**Created:** 2026-11-01 by the heavy agent (handoff H25). Design: [`../DESIGN.md`](../DESIGN.md) §2 (the kit:
"Grapple"; "2. Grapple swing releases you with that speed. 3. Dash redirects it"), §3 rules 15-21 (refresh, keep
speed, the grapple rules, easy to start, mistakes cost little, never floaty, juice), 29 (colour-code grapple points),
37 (ghosts never grapple), §4 rows Grapple Dog, Stickman Hook, Parkour Reborn, SpeedRunners. Body, step order and the
other moves: [movement.md](movement.md). Speed trust: [trust.md](trust.md) §11. The wire: [netcode.md](netcode.md) §8.
Keys and the touch button: [controls.md](controls.md). QA goals: [../qa/grapple.md](../qa/grapple.md).

**Status:** BUILT 2026-11-01, QA loop next. Rules tested outside Studio (`grapple.test.luau`,
`move_check_grapple.test.luau`, 20 mutations each caught); seen in solo Play (§8). **The feel is Danzo's call by hand.**
**2026-11-07, H28:** the yoink (§2, [the yoink](#the-yoink-h28-2026-11-07)): built and tested outside Studio, not yet seen in Play.

## 1. Who owns what

| Piece | Where | Side |
|---|---|---|
| The pick (aim assist), hook, swing, release | `shared/Grapple.lua` (pure, tested) | client (and the tests) |
| When a hook starts and ends, inside the step | `shared/Movement.lua` (`step` phases 0, 1, 3, 4, 4b, 4c, 5, 6, 7) | client |
| The numbers | `Config.GRAPPLE_*` (§7) | both |
| The anchors (map data, built parts) | `server/Arena.lua` (`ANCHORS`, `ANCHOR_TAG`) | server |
| Reading anchors, the pick each step, the halo, every rope | `client/Grapple.lua` | client |
| The screen's world rectangle for "never off-screen" | `client/SideCamera.lua` (`view`) | client |
| The rope on other screens | `shared/Snapshot` (14th byte), `client/Others` (`ropes`) | both |
| The GRAPPLE touch button | `client/Controls.lua` (`buttons`: `grapple` lit / `grapple_dim`) | client |

## 2. The design (each choice and why)

- **Anchors** are map data: six on the test map (`Arena.ANCHORS`), over open floor and the gaps, 5-11 tiles up and
  22-48 studs apart so one release reaches the next. Standing under one, it must sit under the HUD banner's inset: over a
  floor at y f that is f + 23.75 at most (QA round 2); `grapple.test.luau` stands under every anchor on the real map. Each is a gold neon ball (1.6 studs) on a dark disc: gold is free
  in the colour code (pads lime, ghost pieces violet, walls red, freeze cyan; rule 29). Not solid and not queried
  (T11: a queried part is a floor to the probes). Each map carries its own list since H27 ([maps.md](maps.md)).
- **Aim assist (rule 17)**, `Grapple.pick`: of the anchors at least `GRAPPLE_MIN_ABOVE` (4) above the runner,
  within `GRAPPLE_RANGE` (28) and inside this screen by `GRAPPLE_INSET` (2), the one with the lowest score: its
  distance, +8 if behind the facing, -2 if it is the last pick (so the pick never flickers between two). The line of
  sight is checked last and only for an anchor that would win (a raycast, so a ghost piece or a platform in the way
  skips it). **Never off-screen** is the data rule in the pure function (S10), against `SideCamera.view()`.
- **Hold to hang**: a press is buffered `GRAPPLE_BUFFER` (0.1 s, x1.25 on touch, like the jump buffer) and hooks the
  first step the input is still held, a pick exists and the cooldown is over. A dash in progress ends.
- **The rope** is as long as the distance at the hook (at least `GRAPPLE_MIN_LEN` 8). Hooked from the floor it reels
  in at `GRAPPLE_REEL` (40/s) until its low point is `GRAPPLE_LIFT` (1) above your feet's height, so a floor hook
  swings instead of dragging. The reel moves the position, not the velocity, so no bounce when it stops.
- **A rope only pulls.** Inside its length the runner flies free under gravity (slack); on the step that would carry
  it past the length it catches (the outward part of the velocity is lost: an inelastic catch); swung up past the
  anchor too slowly to go over, the rope would have to push, so it goes slack and the runner falls inside the circle.
  `MIN_LEN` 8 means no loop round the anchor under the speed cap (a loop needs 5 g L > cap squared: 18 000 > 14 400).
- **The yoink (H28)**: the first step a hook's rope is taut at its length, it whips you `GRAPPLE_YOINK` (20 studs/s)
  x sin(angle) along the swing toward under the anchor: gravity's own direction, so all of it hooked level with the
  anchor, half of it at 30 degrees out, none straight under (a dead hang stays dead). Once a hook (`Rope.bit`): a slack
  spell and a second catch get none. A floor hook's waits until the reel is done. Under the cap like the rest (§4).
  Why this shape and size: [the yoink](#the-yoink-h28-2026-11-07).
- **The pump**: the stick pushes `GRAPPLE_PUMP` (60 studs/s^2) along the swing. From a dead hang, pushing the way
  you swing for 2 s reaches 9.2 studs out on a 12-stud rope (pinned print). Easy to start (rule 18).
- **The speed cap**: the swing never goes faster than `GRAPPLE_MAX_SPEED` = `DASH_SPEED` (120). Why: DESIGN §2's chain
  is run builds, the swing releases, **the dash redirects**; a swing faster than a dash would make the dash a brake.
  And the server's speed check needs no new rate (§4). A 16-stud rope dropped from level reaches the cap; longer ones
  are clipped. Gravity is 450, so a 16-stud swing has a 1.2 s period: never floaty (rule 20).
- **Release (rule 16, rule 17)**: letting go keeps the swing's own velocity (along the rope's tangent, not the step's
  chord) times `GRAPPLE_RELEASE_BOOST` (1.1), then the usual air rules (speed above the run bleeds slowly while you
  hold that way). `GRAPPLE_COOLDOWN` (0.2 s) before the next hook.
- **Other ways off the rope**: **jump** = let go with the boost and at least a full jump up (vy above it is kept but
  not held: the hold only holds `JUMP_SPEED`), the double jump is still in hand; **dash** = let go, the dash sets its
  own speed (no boost: "dash redirects it"); **landing**, **a hold** (trap, freeze, stumble, the tag freeze),
  **a pad's launch** = off, no boost. The tag's hit-stop does not touch the rope.
- **Refresh on the hook (rule 15)**: a hook gives back the dash and double jump, as a wall touch does; the anchor is a
  contact. `GRAPPLE_REFRESH = false` turns it off. This adds a refresh source to rule 15 (DESIGN §3 rule 15 note).
- **Ghosts never grapple (rule 37)**: `client/Place` reads the ghost's grapple press as the rotate first, then
  `client/Grapple.frame` clears the grapple input before Movement sees it: no pick, no halo, no hook (seen, §8).

## 3. The maths: why an angle and leapfrog (measured)

The first build projected the position onto the rope each step and set the velocity to the chord (position-based
dynamics). **It lost 86% of the swing's energy in 4 s at 60 Hz** (`grapple.test.luau` print): each step turns the
chord by half the swing's angle, and the projection eats that. A velocity-level constraint plus a position snap
instead ADDS energy (each snap lifts the runner at the low point without slowing it). So, taut, the rope is a
pendulum in its angle: `w += accel(a) dt/2; a += w dt; w += accel(a1) dt/2` (leapfrog), accel = (-g sin a + pump
cos a) / len, the body given the velocity that carries it exactly to the new point. Measured over 4 s: **0.1% lost**,
the peak set in the first swing and never later; symplectic Euler (one full kick) peaked +110 above the hook's
energy (O(dt)), leapfrog none. The cap clamps `w` to cap / len. Tested: the rope keeps its length within 0.5 stud
over 2 s; energy never grows; a hang never starts swinging by itself.

## 4. Trust: the swing is capped, so nothing new is trusted (trigger 3)

The routine read was a grapple allowance in `MoveCheck`, granted while the stream's grapple bit is set. **Not
built:** a bit the client sets is a lever (a cheat sets it always and gets the higher rate), and bounding it by
anchor distance would be the server re-judging the swing. Instead the swing's own cap is the dash rate, so:
- `MoveCheck.RATE_X = max(DASH_SPEED, GRAPPLE_MAX_SPEED)`: still 120 (the test pins the formula, and that the cap is
  no faster than a dash as tried). **Raising `GRAPPLE_MAX_SPEED` above 120 raises the x rate for everyone, always**:
  the cost is stated where the knob is.
- The release boost (132) and the jump off the rope bleed back inside the burst, like a dash-jump (140) already does.
- **The yoink (H28)** adds at most 20 to the swing, inside the same clamp to the cap, so it adds no rate: re-driven,
  the five chains are still never flagged, fastest swing 120.0, overall 147.5, x budget 1.38 unchanged; up 2.96 → 2.47,
  down 2.21 → 2.77 (re-pinned). `MoveCheck` is untouched.
- **Driven** (`move_check_grapple.test.luau`, five 10 s chains on a long course: dash into every hook, pump the whole
  way, release low / high / at the peak, jump off, dash, double jump; 11-17 hooks each): never flagged. Worst budget
  used, **pinned as measurements (S11): x 1.38 of 24, up 2.41 of 10.5, down 2.67 of 16.** Fastest swing 120.0, fastest
  across 137.8 (the opening dash-jump, not the swing), fastest overall 147.5 studs/s.
- A client claiming a swing it is not on gains nothing: a steady 150 across is caught inside a second, rope or no rope.
- The anchor byte on the wire is drawing only; the server never reads it (`server/Snapshots` ignores it).

## 5. Anchors and the wire

- **No remote.** The server builds the anchors as parts tagged `RotagAnchor` with an `AnchorId` attribute (their place
  in `Arena.ANCHORS`) inside `Workspace.Map.Anchors`, a Model with `ModelStreamingMode = Persistent` (this place has
  `StreamingEnabled`, T11). Clients read them with `CollectionService`, rebuilt on add/remove.
- **The snapshot gains a 14th byte**, `u8 anchor` (0 = not on a rope, 1-255 = the anchor), so another screen draws
  that runner's rope ([netcode.md](netcode.md) §8). The pose rides the sprite byte as before. 4 bytes more per batch.
- **Ghost parts keep clear of anchors**: `Arena.static()` adds a 4-stud box round each (`"anchor"`), so a ghost cannot
  bury one (the HUD says `NO ROOM: anchor`).
- `RemotePose` (the streamless fallback, only the Studio dummies, who never grapple) is unchanged: a stream that
  stops shows no rope.

## 6. On screen

- **The pick's halo**: a pulsing white disc behind the picked anchor, only on your own screen, only while not on a rope.
- **The rope**: a 0.25-stud gold neon part from the runner's raised fist (1.4 up, 0.5 forward of the collider's
  centre) to the anchor, on every screen, just behind the sprite (z 0.9). Hidden, not destroyed, when unused.
- **The pose**: `runner_fall` while on the rope (`Movement.SWING_SPRITE`): its front fist is raised, the nearest thing
  to a hang on the sheet. The art block's hang/swing poses replace it in one line (and an append to
  `Snapshot.SPRITES`). The lean by speed (`Look`) still applies.
- **The touch button**: GRAPPLE shows for the living, lit while an anchor is picked or you hang, dimmed otherwise;
  ROTATE for a ghost holding a piece; hidden for other ghosts.
- **The camera is unchanged** (`SideCam` leads by vx, eased at 3/s, so a 1.2 s swing sways it a little). Whether it
  should lead into the swing is a feel call (§10).

## 7. The numbers (trial, Danzo's by hand)

| Name | Value | What |
|---|---|---|
| `GRAPPLE_RANGE` | 28 studs | reach to an anchor; also the longest rope |
| `GRAPPLE_MIN_ABOVE` | 4 | an anchor must be this far above your centre |
| `GRAPPLE_BEHIND_FAST` / `_SLOW` | 0.8 / 0.7 x run | faster than FAST, no anchor behind the motion; one skipped returns only under SLOW (no blink) |
| `GRAPPLE_BEHIND` / `GRAPPLE_STICKY` | 8 / 2 studs | aim assist: behind scores further, the last pick nearer |
| `GRAPPLE_INSET` | 2 studs | inside the screen edge (never off-screen) |
| `GRAPPLE_MIN_LEN` | 8 studs | the shortest rope (no loops) |
| `GRAPPLE_LIFT` / `GRAPPLE_REEL` | 1 stud / 40 studs/s | a floor hook reels you off the floor |
| `GRAPPLE_YOINK` | 20 studs/s | H28: the rope's bite along the swing toward under the anchor, x sin(angle) (0 = off) |
| `GRAPPLE_PUMP` | 60 studs/s^2 | the stick along the swing |
| `GRAPPLE_MAX_SPEED` | 120 (= `DASH_SPEED`) | the swing's cap; above 120 raises the server's x rate (§4) |
| `GRAPPLE_RELEASE_BOOST` | 1.25 (H30; was 1.1) | on letting go or jumping off (1 = off) |
| `GRAPPLE_RELEASE_KICK` / `_MAX` | 25 studs/s / 140 | H30, the haul: added along the swing on letting go (level or rising, none straight down), the release never past 140 |
| `GRAPPLE_GIVE` | 0.05 s | H30: the catch's give, a critically damped stretch of the rope (0 = the one-frame catch) |
| `GRAPPLE_COOLDOWN` | 0.2 s | from a release to the next hook |
| `GRAPPLE_BUFFER` | 0.1 s | a press this early still hooks (x1.25 on touch) |
| `GRAPPLE_REFRESH` | true | a hook gives back dash and double jump |

## 8. Seen in Studio (2026-11-01, solo Play, keyboard injected through the MCP, logged per Heartbeat)

- Rendering checked first (T13): 241 frames/s, viewport 1656 x 606. The client saw all 6 anchors, `CanQuery` off.
  Server: `test map: 8 parts and 6 grapple anchors`, `placement: 21 static boxes` (6 of them anchors).
- **Floor hook** under anchor 1 holding D: hooked, reeled off the floor (y 1.8 to 3.1), swung on a 15.8-stud rope
  about +-6 studs at up to 30 studs/s with D held (holding one way tilts the hang; pumping in time swings higher);
  W up released it onto the floor running.
- **Airborne chain** (run, jump, hook, let go, jump, hook again, let go, dash): hooked in the air, swung through the
  low point at 98, let go and jumped, re-hooked, swung at 110, went up past the anchor's height and **fell slack inside
  the circle** (vx -3, vy -64) until the rope caught again; let go moving left at 86 and **the dash redirected it to
  +120 right**. Fastest body speed on the rope 111. **No `move:` line** on the server through all of it.
- **Seen on screen**: the gold rope from the raised fist of the fall pose to the anchor; anchors read gold against the
  violet orbs; the halo on the pick while running; the GRAPPLE button lit while an anchor was picked (its GUI only
  shows on touch devices).
- **As a ghost** (the round's fuse ran out on me twice, T9): no halo, no hook, running and dashing as normal (rule 37).
- **Noticed**: running right past anchor 1 with no anchor ahead in reach, the hook took the one behind and swung the
  runner back left. That is the aim assist doing what rule 17 says (the nearest); whether a hook behind you at speed
  should be allowed is §10's first call.
- No errors in either Output; the only warning is the stock place decal (`203785492`).

## 9. Tests

`test/luau/grapple.test.luau`: the pick (above, range, both screen edges, ahead before behind, the nearest, sticky,
line of sight); the hook's rope length; the length held within 0.5 stud over 2 s; energy never grows and the swing
does not die; no swing from a dead hang; the pump starts one; slack inward, the catch, slack over the top; the cap;
the release keeps the swing x the boost; the cooldown; the jump off (not the double jump); refresh on the hook; a hold,
a dash, a landing end it; the buffer (in time, too early, a tap already let go); a floor hook reels and swings; the pose;
H28's yoink (the bite adds `YOINK` x sin 45 at 45 degrees out, toward under the anchor, mirrored; none again after a
slack spell; none while a floor reel runs, and a fast floor hook from the side keeps its rope; a walking floor hook
+4.9, pinned).
`test/luau/move_check_grapple.test.luau`: the rates; five driven chains never flagged; the budgets pinned; a fake
swing caught. `snapshot.test.luau`: 14 bytes, the anchor round-trips. **Mutation-checked (Q5)**: removing the cap,
the taut clamp, the min-above, either screen edge, the behind score, the sticky, the line of sight, the boost, the
cooldown, the floor lift, leapfrog (to Euler), the slack, the catch, the refresh, the hold release, the buffer, the
landing release, the dash release, or spending the double jump on the rope jump: each fails a named assertion. H28's
five: `GRAPPLE_YOINK` 0, the bite before the reel ends, the sign flipped, a second yoink after slack, a flat kick in
place of x sin: each fails a named assertion.

## 10. Calls for Danzo, and what is not built

- **A hook behind you** (§8): allowed now (nearest wins, ahead preferred by 8 studs). Option: no anchor behind the
  facing while running faster than the run speed. Say if the reversal feels wrong.
- **The cap at the dash speed** (§4). If swings feel capped, raising it loosens the speed check for everyone.
- **Refresh on the hook** (rule 15's new source). Off with `GRAPPLE_REFRESH = false` if chains get too free.
- **Holding the stick**: one way tilts the hang; the swing grows when you push with it. Is that easy enough?
- **Not built**: a rope that wraps round corners (a rope through a platform is only prevented at the hook, by the line
  of sight); a hang/swing pose (the art block); the camera leading into the swing; a sound; rope physics (sag, wobble).

## Expansion: deficits at scale

Per physics step the pick walks every anchor (6 here; a map of 30 is still nothing) and casts at most a few rays;
per render frame one part per runner on a rope (4 at most) and the halo. The wire grew by 1 byte per snapshot.
Nothing grows with the match's length.

## QA round 1 (2026-11-01, 7/10)

Fixed: each anchor learns the floor under it (a ray down at rebuild; `Anchor.floor`) and `attach` caps the rope so
the swing's low point clears it by `GRAPPLE_LIFT` for air hooks too (an air hook on a long rope scraped the floor,
the landing took the rope and the ground ate the swing); `pick` skips any anchor behind the MOTION while faster than
`GRAPPLE_BEHIND_FAST` (0.8) x run (a hook behind a sprinter threw the run away); `GRAPPLE_INSET_TOP` 6 keeps a pick
out from under the HUD banner; a press made in the air and still held ARMS the hook for the next anchor in reach
(`State.grappleArmed`; landing, letting go or a hold disarms it; standing never auto-hooks); the anchor's disc is
bigger and darker; the line-of-sight filter is rebuilt only when the character changes; a jump off the rope reports
"double" so other screens play the mid-air puff. Measurements re-pinned: up budget 2.41 → 2.96 of 10.5, down 2.67 →
2.21 of 16 (the chains hook earlier and higher). Deferred: leavers' hidden rope parts.

## QA round 2 (2026-11-02, 7/10)

The round 1 fixes held live (floor clearance, the behind-skip, the armed hook). One regression: `GRAPPLE_INSET_TOP` 6
hid anchors 2 and 4 (y 24) from a runner standing under them, because the camera's centre sits `CAMERA_Y_OFFSET` 4
above the runner (screen top 29.75, usable 23.75); round 1's test had centred the view on the runner. Fixed: anchors 2,
3 and 4 lowered by half a tile (22, 30, 22) and anchor 2 moved to x -8 so its longest floor rope (19.25) stops short of
PlatformLow's left edge (the swing bonked it at x -4); a test stands under every anchor from every block top in reach
through the real framing (`test/luau/run.js` lifts `BLOCKS` and `ANCHORS` out of `server/Arena.lua` as `ArenaData`);
the client looks for a missing floor again up to 5 times a second apart (Persistent anchors can arrive before the
streamed map). Deferred: a keep-clear column under each anchor (a piece in the arc is a legitimate ghost play, and a
column would only guard the low point); leavers' hidden rope parts.

## QA round 3 (2026-11-02, 8/10: target met)

Seen live by the reviewer: a floor hook at spawn, a side hook 11 studs off anchor 4 (smooth, no yank), and the first
dash off the rope (-15 → -120 the way it steered, which then landed a tag). Fixed after it: the floor ray counts only
`Workspace.Map`'s blocks (a runner or a ghost piece under an anchor could have become its floor on a retry), one
floor retry in flight at most (six tag signals in a frame could spend all five at once), and hysteresis on the
behind-skip (`GRAPPLE_BEHIND_SLOW` 0.7: the halo blinked for a frame while slowing past a ball at the 0.8 threshold).
Left as is: the disc reads as a rim under bloom (the art block's call); leavers' hidden rope parts.

## The yoink (H28, 2026-11-07)

Danzo, after signing the grapple off: "have them sort of yoink the player a little bit in their direction, increasing
their velocity a bit". Two shapes were on the table (handoff H28); both were built and measured in the box world.

- **(a) A short reel on every hook, keeping angular momentum** (a pulled-in pendulum spins up): built first, with
  `GRAPPLE_YOINK` as a share of the rope (0.15). **Dropped on the numbers:** its gain is a share of the speed you bring,
  so a hook at a walk gains nearly nothing, and a side hook LOST speed (69.3 → 60.1 at the swing's fastest, air hook 10
  out at 30): the shorter rope raises the low point, so the fall that feeds the swing is shorter. It also changed every
  floor hook's reel, which was signed off.
- **(b) A kick along the swing, chosen.** On the rope's first taut step at its length, `w -= YOINK sin(a) / len`: the
  direction gravity pulls along the arc, toward under the anchor. It is felt the moment the rope bites (the whip),
  adds a little to the swing's top speed (a walking floor hook 10 out: 56.9 → 61.8; a sprinting one 15 out: 71.9 →
  77.0), and cannot make a free dash (+20 at most, never past the cap). x sin(a), not a flat kick: smooth through
  straight under (a flat kick would flip at a = 0 and swing a dead hang by itself).
- **When:** at the first taut step at the rope's length, not at the hook. A kick at the bite of a floor hook, before
  the reel had lifted the runner, swept a 45 studs/s runner 15 out into the floor and the landing took the rope
  (measured at 20 and 25; fine at 15). Once a hook: a slack spell over the top and a second catch get none.
- **A hook behind you at a walk** (allowed under `GRAPPLE_BEHIND_SLOW`) is yanked back toward the anchor a little: the
  yoink is toward the anchor, not "faster whatever way". Under 0.7 x run only.
- **The size, 20:** 15 / 20 / 25 measured; at 20 a 45-degree bite adds 14 at once and +5 to +7 at the swing's
  fastest. The knob is `Config.GRAPPLE_YOINK` (studs/s, 0 = off). Up for more whip; past ~40 a level hook's downward
  kick will start to feel like a yank down.
- **Tests changed:** the energy test's "peak set in the first swing" tolerance went from 1e-6 absolute to 1e-5 of the
  energy: the yoink's wider arc makes leapfrog's bounded error envelope settle +0.0045 over the first 4 s (then flat
  to 1e-8 over 100 s, measured), which is noise; Euler's growth was +110. The chains' up and down budgets re-pinned
  (S11). Nothing else loosened.
- **Found, not caused:** a floor hook at a dash's speed from 15 out loses its rope at once with or without the yoink
  (the reel is too slow to lift a runner sweeping that fast along the floor). Left for a later QA round.
- **Not seen in Studio** (another agent held the Studio link). What to feel for: [../qa/grapple-yoink.md](../qa/grapple-yoink.md).

## The haul and the give (H30, 2026-11-11)

Danzo, after the first play of the relaid Yard: the grapple "should yoink you, the arc you swing on feels forced and
sudden", then: "yoink as in when you release, going towards one: on the release it should almost feel like the
character is pulling on the string to launch himself off". Two changes, both in `shared/Grapple`, both knobs.

- **The haul (the release).** `Grapple.release` with the boost now sets the speed to `v x GRAPPLE_RELEASE_BOOST +
  GRAPPLE_RELEASE_KICK x rising`, along the swing's velocity, where `rising` is 1 level or going up and fades to 0
  straight down (you let go to fly, never to be thrown at the floor); then `min(…, GRAPPLE_RELEASE_MAX)`. 1.25, 25
  and 140: a slow swing (60) leaves at 100, a capped one (120) at 140. **Why the cap:** at 150 the hardest honest
  chain (`move_check_grapple.test`) spent 6.66 of the server's 24-stud x burst and 5.30 of the 10.5 up; at 140 it
  spends 1.81 and 2.21 (was 1.38 and 2.47), re-pinned. The server's rates are unchanged (§4 still holds).
- **The give (the catch).** The catch used to drop the outward part of the velocity in one frame. Now that part
  becomes a stretch: the rope's length grows at that speed and a critically damped spring (time constant
  `GRAPPLE_GIVE` 0.05 s, settled in ~0.15 s) brings it back to the length it caught at; the stretch's speed is
  clamped so the body never passes the swing's cap, and the taut step's chord is clamped at the cap too (the catch's
  step came from inside the circle). The reel and the yoink wait for the give to settle. 0 restores H25's catch.
  The energy test is unchanged (it hooks at rest: no give); the rope-length test holds because the length itself
  carries the stretch.
- **Not changed:** the bite's yoink (H28, 20) and the pump. If the arc still feels forced, `GRAPPLE_YOINK` 0 is the
  next thing to try by hand, then `GRAPPLE_GIVE` up to 0.08.
- **Seen:** tests and the box world only (the Yard's seven anchors still carry both ways in `maps.test`). The feel is
  Danzo's: `docs/qa/yard-routes.md`, the H30 items.
