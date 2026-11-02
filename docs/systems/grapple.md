# The grapple: hold to hang on marked anchors, release keeps the swing

**Created:** 2026-11-01 by the heavy agent (handoff H25). Design: [`../DESIGN.md`](../DESIGN.md) §2 (the kit:
"Grapple"; "2. Grapple swing releases you with that speed. 3. Dash redirects it"), §3 rules 15-21 (refresh, keep
speed, the grapple rules, easy to start, mistakes cost little, never floaty, juice), 29 (colour-code grapple points),
37 (ghosts never grapple), §4 rows Grapple Dog, Stickman Hook, Parkour Reborn, SpeedRunners. Body, step order and the
other moves: [movement.md](movement.md). Speed trust: [trust.md](trust.md) §11. The wire: [netcode.md](netcode.md) §8.
Keys and the touch button: [controls.md](controls.md). QA goals: [../qa/grapple.md](../qa/grapple.md).

**Status:** BUILT 2026-11-01, QA loop next. Rules tested outside Studio (`grapple.test.luau`,
`move_check_grapple.test.luau`, 20 mutations each caught); seen in solo Play (§8). **The feel is Danzo's call by hand.**

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
  (T11: a queried part is a floor to the probes). PR 6 carries a list per map.
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
| `GRAPPLE_PUMP` | 60 studs/s^2 | the stick along the swing |
| `GRAPPLE_MAX_SPEED` | 120 (= `DASH_SPEED`) | the swing's cap; above 120 raises the server's x rate (§4) |
| `GRAPPLE_RELEASE_BOOST` | 1.1 | on letting go or jumping off (1 = off) |
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
a dash, a landing end it; the buffer (in time, too early, a tap already let go); a floor hook reels and swings; the pose.
`test/luau/move_check_grapple.test.luau`: the rates; five driven chains never flagged; the budgets pinned; a fake
swing caught. `snapshot.test.luau`: 14 bytes, the anchor round-trips. **Mutation-checked (Q5)**: removing the cap,
the taut clamp, the min-above, either screen edge, the behind score, the sticky, the line of sight, the boost, the
cooldown, the floor lift, leapfrog (to Euler), the slack, the catch, the refresh, the hold release, the buffer, the
landing release, the dash release, or spending the double jump on the rope jump: each fails a named assertion.

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
