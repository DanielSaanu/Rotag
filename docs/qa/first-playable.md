# QA goals: the first playable (side-on camera, one runner, two ways to draw it)

Branch: `claude/friendly-hawking-74891i`. Handoff H1. Design: `docs/DESIGN.md` §2 (platform: side-on locked camera
over 3D parts, one plane), §3 rules 14–16 (forgiveness, refresh on contact, momentum), 20–24 (feel, juice, mobile).
Method: `docs/systems/sprites-and-animation.md` §4.

The question for this loop: **does moving feel good on an empty screen, and which way of drawing the sprite on the
3D world reads best at phone size?** Danzo decides the second from screenshots; the build makes both switchable.

## Goals

1. **Side-on.** `CameraType = Scriptable`, fixed CFrame looking down the plane's normal, follows the runner and
   leads ahead at speed (rule 21). The character is held to one plane: no off-plane drift when the joystick is
   diagonal.
2. **One flat test map**: a floor, three platforms at different heights, two walls to wall-jump between, built as
   Parts in `Workspace.Map` (a Folder; declared in `default.project.json` or built by the server at boot, say which).
3. **The runner moves**: run, jump, double jump, dash. Keyboard (A/D or arrows, Space, Shift) AND the mobile
   joystick with at most two on-screen buttons (jump, dash). Celeste values from `shared/Config.lua`: coyote
   time, jump buffer, variable jump hold, half gravity at the apex. Dash and double jump refresh on landing and on
   a wall touch (rule 15). Dash into jump keeps the speed (rule 16).
4. **Drawn two ways, switchable** by a boolean attribute `SurfaceSprites` on Workspace (false = BillboardGui on
   an invisible Part; true = SurfaceGui on the camera-facing face). Both use `Sprites.Apply`, run cycle
   `runner_run_0/1` advanced per distance travelled, `runner_idle` at rest, flipped to face the move direction.
5. **Juice, the cheap set**: squash on landing, stretch on take-off, a smear or stretch on dash (rule 21). No
   screen shake yet.
6. **Pure where it can be pure**: the forgiveness windows and the move state machine live in
   `shared/Movement.lua` as functions over plain tables, with `test/luau/movement.test.luau` covering coyote
   time, the buffer, refresh on contact and dash-into-jump speed. The client calls them every frame.
7. **Nothing regresses**: `npm test`, `npm run lint:luau`, `rojo build`, the Rojo tree unchanged except for
   additions (new ModuleScripts under Shared, Client, Server; `Workspace.Map` if declared).

## Out of scope

Tag, the fuse, other players, grapple, boost pads, crates, ghosts, HUD beyond the two buttons, art direction (the
placeholder runner is fine), any remote beyond what the camera and map need.

## Studio play-through (Danzo, on the Mac AND on a phone via Studio's device emulator)

1. Play. The camera is side-on and the runner is on the floor. Run left and right: does it feel immediate, not
   floaty (rule 20)?
2. Jump off a platform edge a hair late: did it still jump (coyote)? Press jump just before landing: did it jump
   on landing (buffer)?
3. Dash off a ledge, then jump: did the jump keep the dash speed?
4. Wall-jump between the two walls three times in a row.
5. Flip `Workspace.SurfaceSprites` in Properties, stop and start Play, repeat step 1. Screenshot both at the phone
   preset. Which runner reads better, and does either shimmer when the camera moves?
6. Phone preset: are the two buttons out of the lower-middle, at least 44 px, and does the joystick drive the run?
