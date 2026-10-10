# Movement and feel

**Created:** 2026-10-09 (handoff H1, the first playable). Design: [`../DESIGN.md`](../DESIGN.md) §2 (side-on camera
over 3D parts, one plane, the movement kit), §3 rules 14–16 (forgiveness, refresh on contact, keep speed), 20–24
(feel, juice, mobile). Goals: [`../qa/first-playable.md`](../qa/first-playable.md). How the sprite reaches the screen:
[`sprites-and-animation.md`](sprites-and-animation.md) §4.

**Status:** built and tested outside Studio (`npm test`, `npm run lint:luau`, `rojo build`). **Not yet played.**
Danzo's play-through decides whether it feels right and which drawing method stays.

## 1. The frame

```
PreSimulation (before physics), Client.client.lua
  Body:read()        -> x, y, contacts {ground, ceiling, wallLeft, wallRight}   (raycasts)
  Controls.read()    -> {moveX, jumpPressed, jumpHeld, dashPressed, touch}
  Movement.step()    -> new vx, vy (and a snapped y), events {landed, jump, dash}
  Body:apply()       -> CFrame at (x, y, 0) upright + AssemblyLinearVelocity; physics moves and collides
RenderStep (Camera + 1)
  SideCamera.update  -> SideCam.step() (pure) -> camera CFrame
  Look:react/draw    -> squash/stretch, sprite frame (Movement.spriteFor), facing
```

Everything that decides something is pure Luau in `shared/` and has a test; the client files only read the world,
call the rules and apply the answer. The client cannot run outside Studio, so it is kept as thin as that allows.

| Module | Side | What |
|---|---|---|
| `shared/Movement.lua` | both | the move rules: run, jump, double jump, wall jump, dash, coyote, buffer, variable jump, half gravity at the apex, refresh, speed retention, the sprite pick |
| `shared/SideCam.lua` | both | the camera's follow, lead and distance |
| `shared/Config.lua` | both | every number below |
| `client/Body.lua` | client | the ONLY file that knows the runner is a Part: raycast probes, anti-gravity, plane lock |
| `client/Controls.lua` | client | keys, gamepad, the touch joystick (via Roblox's PlayerModule), two touch buttons |
| `client/Look.lua` | client | the sprite, drawn two ways; flip; juice |
| `client/SideCamera.lua` | client | applies `SideCam` to `workspace.CurrentCamera` |
| `server/Runners.lua` | server | builds each player's runner body and spawns it |
| `server/Arena.lua` | server | builds `Workspace.Map` |

No RemoteEvent was added. The sprite sheet id is already resolved in the generated `Sprites.lua` (`Resolved =
true`, from `setid`), so the client needs nothing from the server yet. If a future upload is a Decal again, the
server must hand clients the resolved ids (`Sprites.ApplySheetIds`) through a join remote, declared in
`default.project.json` and listed in [`README.md`](README.md).

## 2. The character: a one-box body with a dormant Humanoid

**Choice:** the server builds each runner as a Model holding one invisible box `HumanoidRootPart` (2 x 3.5 x 2
studs, frictionless), a weightless non-colliding `Head`, and a `Humanoid` with `PlatformStand = true`,
`JumpPower = 0`, `RequiresNeck = false`. It is assigned as `player.Character` and its physics is owned by the
player. The client sets the box's velocity every frame from `Movement`; a client-side `VectorForce` cancels Roblox
gravity because `Movement` integrates its own.

**Why not drive the stock character:**
- The stock Humanoid applies its own forces every physics step (walk speed toward `MoveDirection`, ground friction,
  the hip-height spring, its jump). Overriding `AssemblyLinearVelocity` fights all of them, and the classic result
  is a run that sticks on the ground and drifts in the air: the "underwater" feel rule 20 forbids.
- Celeste's rules need gravity we own (half gravity at the apex, no gravity in a dash, a variable jump that holds
  the take-off speed). Workspace gravity is global; cancelling it on one box is one `VectorForce`.
- The stock rig is many parts, with accessories, an Animate script and limbs whose `CanCollide` the Humanoid
  manages. A side-on sprite game needs one collider whose size is the sprite's figure (8 x 14 px).

**Why keep a Humanoid at all:** Roblox's player plumbing keys on it. The default touch joystick only shows when the
character has a Humanoid; `CharacterAdded`, the camera scripts, and automatic network ownership of the character
all expect one. With `PlatformStand` on, it applies no forces, and `JumpPower = 0` hides Roblox's own touch jump
button (ours replaces it).

**Swapping it:** the body lives in two files. `server/Runners.lua` builds it; `client/Body.lua` reads its position and
surroundings and applies a velocity. `Movement` never sees an Instance. To try the stock character, rewrite those
two files; nothing else changes.

**Contacts are raycasts, not `Touched`.** Three rays down (ground, 8 studs of look-ahead so the buffer can see a
floor coming), three up (ceiling), three each side (walls, out to the wall-jump reach). Each returns a distance
from the collider's face. The rays exclude the runner's own model, so `Workspace.Map` is never looked up by name.

**The plane lock:** every frame the box is set to `CFrame.new(x, y, 0)` with no rotation and zero angular
velocity, and its velocity has no Z. A diagonal stick cannot drift it off the plane: only `moveVector.X` is read.

## 3. The rules (shared/Movement.lua)

Celeste's numbers, mapped at **0.5 studs per Celeste pixel** (its 8 px tile = our 4-stud tile). Studs, seconds, y up.

| Rule | Value | Note |
|---|---|---|
| Run | 45 studs/s, accel 500/s² | top speed in 0.09 s, stops as fast (rule 20) |
| Over-speed bleed | 200/s² while holding that way | earned speed lasts (rule 16); let go and it stops at 500/s² |
| Air control | 0.65 x ground | |
| Gravity, max fall | 450/s², 80 studs/s | |
| Jump | 52.5 studs/s, +20 in the stick's direction on a ground jump | |
| Variable jump hold | 0.2 s: while held, the take-off speed is held | rule 14 |
| Half gravity at the apex | when \|vy\| < 20 and jump is held | rule 14 |
| Coyote time | 0.1 s (x 1.25 on touch) | rule 14, rule 23 |
| Jump buffer | 0.08 s (x 1.25 on touch) | rule 14, rule 23 |
| Double jump | 1, same speed and hold | |
| Wall jump | within 3 px (0.75 studs), kicks 65 studs/s away; the stick reads "away" for 0.16 s | |
| Wall slide | fall capped at 10 studs/s while pushing into a wall | |
| Dash | horizontal, 120 studs/s for 0.15 s (18 studs), no gravity, ends at 80; 0.2 s cooldown | |
| Stick | digital past a 0.3 deadzone | a diagonal thumb runs full speed (rule 24) |

**Measured** (the pure rules, 60 fps): a tap hops 3.5 studs (0.9 tiles); a full hold 14.25 studs (3.6 tiles), apex
at 0.35 s, 0.68 s in the air; a full jump then a full double jump about 28 studs (7 tiles). The test map's heights
are set against these.

**Jump priority:** ground (or coyote) > wall (either wall within reach, the nearer one) > double.

**Refresh on contact (rule 15):** landing and touching a wall give back the double jump and the dash. A wall jump
counts as a wall touch. A dash in progress keeps its charge spent.

**Keep speed (rule 16):** a jump ends a dash and does not touch `vx`, so dash-into-jump carries 120 (plus the jump
boost) into the air, bleeding only at the over-speed rate while held. A double jump does the same. A wall kick
**banks** the speed brought into it: `max(65, |vx|)` away from the wall (DESIGN §2: "wall-run or wall-kick banks it").

**Two decisions beyond the goals file, both small and both tested:**
- **Landing-aware buffer.** If a press comes while falling with the double jump in hand, and the floor is close
  enough that the remaining buffer will reach it, the press waits for the landing instead of spending the double
  jump a few frames early. Without this, "press just before landing" (play-through step 2) would fire the double
  jump in the air whenever the player still had it.
- **Ceiling bonk.** A rise into a roof zeroes the upward speed and ends the jump hold, so the runner drops at once
  instead of hanging under it for 0.1 s.

**Sprite pick (`Movement.spriteFor`, decided H3, 2026-10-10).** First match wins:

| State | Sprite |
|---|---|
| dashing (`dashTime > 0`), ground or air | `runner_dash` |
| airborne and wall-sliding (`s.sliding`), or `vy < -APEX_POSE_BELOW` | `runner_fall` |
| airborne, `vy > APEX_POSE_BELOW` | `runner_jump_rise` |
| airborne, `|vy| <= APEX_POSE_BELOW` | `runner_jump_apex` |
| grounded, stopped 0.08 s | `runner_idle` (the rest pose, → A1) |
| grounded, otherwise | `runner_run_<floor((runDistance - runFrom) * RUN_FRAMES / RUN_CYCLE) % RUN_FRAMES>` |

- **Run: `RUN_FRAMES = 8`, `RUN_CYCLE` stays 20 studs.** Contact, down, pass, up, twice. The cadence is unchanged by
  the frame count (→ A3): a full cycle 2.25 times a second at top speed, a step 4.5 times, but a new frame every
  2.5 studs, 18 a second, so the legs are smoother at the same speed.
- **A run from rest opens on frame 0 (a contact pose).** Before H3 this held only for the very first run: `runDistance`
  never resets, so a second run from rest opened wherever the last one stopped (the new test saw `runner_run_6`).
  `runFrom` now marks the odometer once the runner has been still for `IDLE_GRACE`, and the frame is taken from
  `runDistance - runFrom`; `runDistance` itself still never runs backwards (its test is unchanged). Landing mid-run
  and a quick turn (under the grace) carry on from the frame they were on, which is A1's "join in progress".
- **y is up** (`Config`: "y is up"; `JUMP_SPEED` is positive, gravity pulls `vy` toward `-MAX_FALL`), so rise is
  `vy > 0` and fall `vy < 0`.
- **Apex band: `Config.APEX_POSE_BELOW`, defined as `= Config.HALF_GRAVITY_BELOW` (20).** The half-gravity window is
  where the jump actually hangs, so the hang pose shows exactly while the hang is felt. It is its own constant
  because it is an art knob and half gravity is a feel knob (→ A3's "one knob per concern"): today they are linked by
  the definition; replace it with a number to tune the pose without touching the jump. Symmetric (`|vy|`), so the
  apex shows on the way up and the way down. **Measured** at 60 fps (no wall, no stick): a full held jump is rise
  17 frames (0.28 s), apex 10 (0.17 s), fall 13 (0.22 s); a tap hop 5 / 5 / 5; walking off a ledge 2 frames (33 ms)
  of apex and then fall, because leaving a ledge starts at `vy = 0`, which is the top of a ballistic arc. Never a
  rise. If those 33 ms read as a hiccup in play, the fix is a minimum rise before apex is allowed, which needs one
  more state field; not built, nobody has seen it yet.
- **A wall slide is a fall.** The slide caps the fall at `WALL_SLIDE_MAX` = 10, which is INSIDE the apex band, so a
  speed-only pick would show the hang pose for the whole slide. `step()` now records `s.sliding` (the slide cap is
  in force this frame: airborne, pushing into a touched wall, `vy <= 0`), and the pick checks it before the bands
  (→ A4). It reuses `runner_fall` until there is a wall-slide pose; when one exists, it is one line here. The fall
  pose faces the way the runner faces, which during a slide is INTO the wall (the stick); a dedicated slide pose would
  want to face away. `sliding` is animation state only, like `runDistance` and `stillTime`: no move rule reads it.
- **The dash pose wins over the air poses**, because an air dash zeroes `vy` and would otherwise read as the apex. A
  jump out of a dash ends the dash, so the next frame is already `runner_jump_rise`. `Look:draw` still applies its
  dash stretch (1.5 x 0.75) on top of the dash sprite; whether the drawn pose wants the stretch too is Danzo's call in
  play (Look.lua, not shared/).
- **Tests** (`test/luau/movement.test.luau`, mutation-checked → S8): eight frames in order and one cycle per
  `RUN_CYCLE`; on every airborne frame of a held jump, a tap hop and a walk-off, the pose matches the `vy` band and
  the arcs read rise-apex-fall, rise-apex-fall and apex-fall; a run from rest opens on frame 0; a wall slide shows fall; a ground dash and an air dash
  show the dash pose, a run frame after it ends, and a jump out of the dash rises. Removing the slide check, the dash
  line, swapping rise and fall, or setting the apex band to 0 each fails a named assertion.

Why the run is cut by cycle and not per frame: [sprites-and-animation.md](sprites-and-animation.md) §3 (H2).

**Not built:** corner correction (Config has the 4 px; the goals did not ask for it), an 8-way dash, wall-run,
grapple, boost pads (out of scope).

## 4. The camera (shared/SideCam.lua, client/SideCamera.lua)

`Scriptable`, looking down -Z at the plane from 136 studs, `FieldOfView` 20 so 48 studs (12 tiles) fill the screen
top to bottom: near-orthographic, and world +X is screen right. It eases toward the runner (10/s across, 6/s up and
down, 4 studs above the feet) and **leads** by `vx x 0.35 s`, capped at 16 studs, eased at 3/s (rule 21). The easing
is frame-rate independent (tested). `CameraType` and `FieldOfView` are re-asserted every frame in case Roblox's
camera scripts reset them on spawn.

## 5. Controls

- **Run:** Roblox's `PlayerModule` `GetMoveVector().X`: A/D, arrows, WASD, a gamepad stick and the touch joystick all
  arrive the same way. Fallback if the module is missing: `Humanoid.MoveDirection.X` (warned in Output).
- **Jump:** Space, gamepad A, the touch JUMP button. **Dash:** Left or Right Shift, gamepad X, the touch DASH button.
  Bound at High priority with `Sink`, so Space never reaches Roblox's jump and Shift never toggles shift-lock (the
  server also turns `EnableMouseLockOption` off).
- **Touch buttons:** a `ScreenGui` shown only when `TouchEnabled`. JUMP is 96 px in the bottom-right corner, DASH 76 px
  up and to its left; the default joystick is bottom-left, so the lower-middle is clear (rules 22–23). Presses are
  latched between frames so a quick tap is never lost; a thumb sliding off a button still releases it.

## 6. How the runner is drawn (decided, H1)

A **`SurfaceGui`** on the `Back` (+Z, camera-facing) face of a 6 x 6 stud see-through part welded 1 stud in front of
the collider, 50 px per stud, `LightInfluence = 0`. It is a real face in the world, so it shifts against the map with
the camera the way the map's own faces do. Danzo compared it in Studio (2026-10-09) against a `BillboardGui` adorned
to the collider, which always faces the camera and sat flat on the scene, and picked the SurfaceGui: "the one where
the background moves a little bit is much nicer". The BillboardGui path and the `SurfaceSprites` attribute are gone.

One `ImageLabel` from `Sprites.New`, 4 x 4 studs, hung from the feet (anchor bottom-centre) so a squash keeps the
feet planted. The canvas is 1.5 x the sprite so the widest stretch (the dash, 1.5 x) is not clipped.

**Resolution (2026-10-10):** the runner art is 128 x 128 vector (SVG via `tools/runner-rig.js`, feet on y = 120 so the
collider and the feet line up exactly as with the 16 px placeholder), and `Look.lua` sets `ResampleMode = Default`
after every `Sprites.Apply` so it is sampled bilinear. Danzo asked for a smooth, higher-resolution figure that sits in
the 3D stage rather than pixel art ([sprites-and-animation.md](sprites-and-animation.md) §2).

**Flip: a negative `ImageRectSize.X` with `ImageRectOffset.X` moved to the rect's right edge**, under the
`ScaleType.Stretch` that `Sprites.Apply` sets. Confirmed in Studio 2026-10-09 (the runner faced left on its own with
the default). The negative `Size.X.Scale` alternative and its `FlipBySize` switch are deleted.

**Juice (rule 21), eased per frame rather than with `TweenService`** so the flip and the stretch never fight over
`Size`: landing squash `1.35 x 0.7` (scaled by impact), take-off stretch `0.75 x 1.3`, double jump `0.8 x 1.25`,
dash `1.5 x 0.75` held while the dash lasts. Each eases back to `1 x 1` with a 35 ms time constant (about 100 ms to
settle). No screen shake yet.

**Lean (2026-10-10, Danzo: "give him some lean while he runs"):** on top of the lean drawn into the run frames, the
label's `Rotation` follows the signed horizontal speed: 14° at `RUN_SPEED`, rising to 22° at `DASH_SPEED`, eased with
a 60 ms time constant so it never snaps. `Rotation` turns about the label's centre, so `Position` is shifted each
frame to keep the feet on the floor. Client-only, in `Look.lua`; `Client.client.lua` passes `state.vx` to `draw`.

## 7. The map (server/Arena.lua)

Built at boot into **`Workspace.Map`, a Folder created in code**. It is not declared in `default.project.json`
because nothing finds it by name: the client's rays exclude the runner's own model rather than include the map.
Plain grey Parts, 8 studs deep, all on the plane z = 0. Floor top at y = 0 from x = -80 to 120 with end walls; a
low platform (2 tiles up), a mid one (3 tiles above the low one), a high ledge to walk and dash off (3 tiles up),
and two walls 3 tiles apart (9 and 7 tiles tall) to wall-jump between and climb out over the lower one. The stock
`Baseplate` and `SpawnLocation` are removed for the Play only (said in Output); the place file is not changed.

## 8. Open questions only Studio can answer

1. ~~Flip~~ answered 2026-10-09: the negative rect mirrors.
2. ~~Drawing~~ answered 2026-10-09: SurfaceGui (§6). Still to check at the phone preset: crispness and shimmer.
3. **The body:** does the runner stand, stop at walls and ride the floor without jitter? A Humanoid on a one-box
   model with `PlatformStand` is the least-proven piece. If the Humanoid dies at spawn, Output shows a second
   "runner ready" a second later.
4. **Touch:** does the default joystick show (it needs a Humanoid in the character) and drive the run, and is
   Roblox's own jump button hidden (it should be, with `JumpPower = 0`)?
5. **Depth:** map faces are at z = +4 and the sprite at z = 0 to +1, so a stretch that pokes past the collider
   beside a wall is hidden by the wall's face. Expected to be invisible; say if it is not.

## 9. Tests

`test/luau/movement.test.luau` drives every rule through `Movement.step()` with a small box world standing in for
the raycasts and physics (learnings Q3). The world and its helpers live once in `test/luau/movement_world.luau`,
pulled in by a `--!include movement_world.luau` first line that `test/luau/run.js` inlines; the sprite pick has its
own file, `movement_sprites.test.luau`, on the same helpers (split 2026-10-10). Covered: run and stop times, the digital stick, coyote (keyboard and the wider touch
window), the buffer (on time, too early, landing-aware), variable jump and half gravity, double jump and its limit,
refresh on landing and on a wall touch, wall jump reach, the force window and the bank, three wall jumps up a
chimney, dash, cooldown, dash-into-jump and dash-into-double-jump speed, the ceiling bonk, and the sprite pick (the
eight run frames in order, one cycle per `RUN_CYCLE` studs whatever the frame count, the air poses by `vy`, the wall
slide, the dash: §3).
`test/luau/sidecam.test.luau` pins the view height, settling, the lead and its cap, and frame-rate independence.
**Each rule was mutation-checked:** removing it makes its test fail (→ S8). The ceiling test did not, at first,
because the box stand-in stops at the roof by itself (→ Q5).
