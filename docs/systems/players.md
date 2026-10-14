# Players: more than one runner on the map

**Created:** 2026-10-11 by the heavy agent (handoff H11). How a second (third, fourth) real player is seen, passed
through, pointed at and waited for. What the server trusts about a tag is still [tag.md](tag.md) §2; the body and the
move rules are [movement.md](movement.md); how a sprite reaches the screen is
[sprites-and-animation.md](sprites-and-animation.md) §4.

## 1. Who owns what

| Piece | Where | Side |
|---|---|---|
| The runner collision group (`RotagRunners`, does not collide with itself) | `server/Runners.lua` (`Runners.GROUP`, registered in `Runners.start`, set on every root in `build`) | server |
| Probes cast as that group | `client/Body.lua` (`params.CollisionGroup = root.CollisionGroup`), `client/Others.lua` | client |
| Every other runner's sprite | `client/Others.lua` (one `Look` per other runner) fed by `shared/RemotePose.lua` (pure, tested) | client |
| Off-screen arrows | `client/Arrows.lua` (GUI) over `SideCam.edgeArrow` in `shared/SideCam.lua` (pure, tested) | client |
| Round-ready | `Remotes.Ready` (client → server, no payload); `server/Match.lua` holds the due round; `Tag.readyToStart` (pure, tested); `Config.READY_TIMEOUT` | both |
| Runner models never streamed out | `model.ModelStreamingMode = Persistent` in `Runners.build` and `Dummy.new` | server |

## 2. Decision 1: runners pass through each other, "it" included

**Recommended 2026-10-11 by the routine session and built by H11 as the default; pending Danzo's confirmation**
(DESIGN §2 "Players and map" carries the same line). He asked how similar games handle it; the answer given:
- **Chase games pass through.** Gorilla Tag, SpeedRunners and Ultimate Chicken Horse let players overlap, and most
  Roblox tag games put characters in a collision group that ignores itself.
- **One plane.** In a side-on game a blocking body cannot be walked around, only jumped; a runner standing in a
  corridor would be a wall, and two runners would shove each other off ledges. Short hiding spots only (rule 27)
  gets harder to keep when a body can plug a gap.
- **The tag is confirmed by OVERLAP** (rule 6, `Tag.overlaps` on the client, `Tag.touchedBetween` on the server).
  Solid bodies stop at touching, so every tag would sit on the edge of the reach and the chaser would bounce off.
- **H6 already paid for it once:** the solid dummy stopped a chaser dead and refreshed its dash on contact.

**The mechanism.** One collision group, `RotagRunners`, registered on the server at boot and set as not collidable
with itself; every runner root is put in it before it is parented. Walls and floors stay in `Default`, which still
collides with it. Registration and the part's group replicate: seen on the client in Play, `root.CollisionGroup =
RotagRunners`, the group registered, `CollisionGroupsAreCollidable(RotagRunners, RotagRunners) = false`.
- **Probes too.** A raycast hits anything with `CanQuery`, collidable or not, so the group alone would leave another
  runner as a wall to kick off and a floor to land on. `client/Body.lua` sets `RaycastParams.CollisionGroup` to its
  root's group, so a ray only hits what the runner itself would collide with. Why not `CanQuery = false` like the
  dummy: Roblox allows `CanQuery = false` only when `CanCollide` is false, and a runner root must collide with walls.
- **Seen in Studio (2026-10-11, solo Play):** a static block in `RotagRunners` (CanCollide, CanQuery on, like a
  runner root) in the runner's path: holding right, x ran -55.67 → -40.67 at a steady vx 45.0 straight through it.
  The control, the same block switched to `Default`: the runner stopped flush at x 63.00 (block face 62.05 + half
  width). So the group, not some other effect, is what lets the runner through.
- **"Bouncing off a player" (rule 15)** is a later, optional head-bounce (land on a runner's head for a refresh). It
  is NOT built: with pass-through it would be an explicit check (a falling runner's feet crossing another's head),
  not physics. Note for later; a design question for Danzo when it comes up.

## 3. Decision 2: other runners are drawn from their replicated position (option a, no remote) — superseded by H14

**Since 2026-10-14 (H14, [netcode.md](netcode.md) §8) other runners are drawn from the snapshot stream:** each client
sends its own state 30 times a second over `Remotes.Snapshot`, the server relays it, and `client/Others` draws each
runner `Config.SNAPSHOT_DELAY` behind its newest snapshot, sliding between the two around that moment, with the sprite
and juice carried in the snapshot (nothing inferred). Option (b) below was rejected in H11 because a pose packet would
run ahead of the replicated body; H14 sends position AND pose in one packet, so they cannot drift. Everything below is
now the FALLBACK for a runner with no stream (the Studio stand-in `tools/studio-standin.luau`, a client that stopped
sending): the replicated root through the trail, posed by `RemotePose`. The trail knobs (`OTHERS_DRAW_DELAY*`) only
apply to that path.

Each client builds `Look` only for its own character, and `Look` is client-made (never replicated), so another
player was an invisible box. `client/Others.lua` gives every other runner model (tag `RotagRunner`, `RunnerId` ≥
-999) its own `Look`, and each render frame feeds it a pose from `shared/RemotePose`.

**Why (a), deriving the pose, and not (b), a relayed pose packet.** Measured in H6 (→ N6): a RemoteEvent arrives
almost at once, while a client-owned body reaches the server ~0.18 s late (and another client later still). A pose
packet would therefore run AHEAD of the body it is drawn on: the jump pose would show while the body still stood, the
landing squash before it landed. Deriving the pose from the same replicated stream keeps pose and position in step by
construction. It also adds no remote and no trust surface (nothing a cheat could spam or fake), and costs a few rays per
runner per frame. The price is that it is approximate; measured below.

**What `RemotePose` reads.** `Movement.spriteFor` needs speed, grounded, dash, slide, facing and the run clock.
- Speed: the position change over the time it took, smoothed (0.03 s e-fold, ~2 frames of lag).
- Grounded: a floor within 0.4 studs under the feet (three short rays, as `Body` casts them) and not rising.
- Dash: horizontal speed above 100 (midway between `DASH_SPEED` 120 and `DASH_END_SPEED` 80; runs and jumps stay
  under ~70) with vertical speed inside the apex band (a dash holds `vy` at 0). A wall kick banking a dash can read as a
  dash for a moment; accepted.
- Slide: airborne, a wall within the wall-jump reach, falling no faster than the slide cap (+5). Needed for the same
  reason as `s.sliding` in H3 (→ A4): the capped slide speed sits inside the apex band.
- Facing from the sign of the speed (kept when nearly still); the run clock from ground distance, reset after the
  idle grace, exactly as `Movement` does (→ A1).
- Juice events for `Look:react`: a landing (with its impact speed), a jump start (`ground` within 0.12 s of leaving
  the floor, else `wall` beside a wall, else `double`), a dash start.

**Two fixes from what Studio showed.** A server-moved stand-in runner (anchored, `RunnerId` -2, run, jump and dash on a
script) was drawn by `Others` on the client and its sprite logged every frame:
- **Replication can land in steps**: the position held for 2-3 render frames, then jumped ahead. The first version
  read each hold as a stop, so a dash flickered dash / run / dash and a jump rise / apex / rise. Now a frame with no
  change is held over for up to 0.1 s (`HOLD`) and its time joins the next real move; only 0.1 s with no change at
  all means standing still. A move out of rest uses that frame's time alone, or a jump from standing read as the apex.
  After the fix the dash showed as one unbroken pose in the log, the run cycle came in order both ways. One-frame
  slips remain at some pose edges with the stepped stand-in. **Confirmed 2026-10-12:** the steps were the ANCHORED
  stand-in (a server CFrame write replicates with no smoothing: Danzo saw it "very choppy"). The same stand-in as an
  unanchored, server-owned body driven by velocity moved on every render frame (180 of 180 over 3 s, median 0.78
  studs) and Danzo judged it as smooth as his own runner. A real client-owned runner is interpolated the same way.
  Script: `tools/studio-standin.luau`.
- **The draw trail (H13, 2026-10-14).** With two real clients, the other runner was drawn "very choppy": a client-owned
  body reaches the other screen through two hops (owner → server → this client), and it lands in steps. Now `Others`
  draws each other runner `Config.OTHERS_DRAW_DELAY` (0.1 s) behind its replicated root, sliding between the positions
  that arrived (`RemotePose.newTrail` / `push` / `drawAt`, pure, tested and mutation-checked). A hold the delay covers
  is smoothed over. A change after a longer hold is a start from rest and leaves the old spot at once (no creep). A jump
  over 20 studs snaps. The sprite plane of another runner is anchored and placed by `Look:place` (`Look.new(..., true)`)
  instead of welded, and the pose, the probes and the IT marker (`Others.positionOf`) all use the drawn spot.
  **The tag claim still tests the replicated root**, not the drawing, so the server's window and every trust number
  are unchanged. **The cost:** at speed the sprite trails the root by the delay (4.5 studs at run speed, 12 in a dash).
  So a tagger closing from behind touches the sprite a little before the claim fires, and a runner moving away can be
  tagged a moment before its sprite looks touched. Making the claim test the drawn spot instead would add the delay to
  the target's age, which means raising `TAG_VIEW_DELAY`/`TAG_REWIND_MAX` by it. That is a fairness decision for Danzo,
  not made. Arrows still point at the raw root (off-screen, the difference does not show). Not yet seen in Studio.
  Diagnose with the client line `others: <name> moved on <m> of <n> frames, longest hold <h> frames, biggest step <s>`.
  A longest hold of more than ~6 frames at 60 fps is more than the 0.1 s delay hides: raise the knob, or suspect the link.
- **Run 4 (2026-10-14): "better slightly but still nowhere near as smooth as my own runner".** Two changes:
  - **The delay adapts.** The trail tracks the longest recent gap between two arrivals of a moving body (a peak that
    decays with a 3 s e-fold) and draws `x 1.25` that far behind. The floor is `OTHERS_DRAW_DELAY` (0.1), the cap is
    `OTHERS_DRAW_DELAY_MAX` (0.3). It changes by at most 0.25 s per second, so the sprite slows or speeds a little
    rather than jumping. A gap over the cap is a rest and is not counted. Tested: a sender arriving 8 times a second is
    drawn moving on every frame once adapted, a good link brings it back to the floor, a rest doesn't raise it, it never
    passes the cap; each rule mutation-checked. On a real device with frame-paced arrivals it stays at 0.1.
  - **Why not extrapolate (dead reckoning):** drawing ahead along the last speed overshoots on every stop and turn
    (4.5 studs at run speed for 0.1 s), then snaps back. The sprite would slide past and return each time it stopped.
    A delay never shows a place the runner wasn't. Extrapolation is the fallback only if the cap's 0.3 s behind feels
    too far.
  - **Suspect: Studio's unfocused window.** One PC runs both test clients and only one window has focus. The runner's
    loop is `RunService.PreSimulation` (`Client.client.lua`), one step per frame, and its body reaches everyone else at
    that rate. If Studio throttles the unfocused window, that runner steps on every other screen: a test-rig artefact
    two real devices would not have. Whether Studio throttles it is **not verified**; the logs settle it. Each client now
    prints `client: own loop <p> physics steps/s, <r> frames/s, longest frame <ms> ms` every 5 s. The `others:` line adds
    arrivals/s, the mean hold and how far behind the drawing is. Sender stepping: arrivals/s close to the sender's own
    loop rate, mean hold close to the longest. Link jitter: arrivals close to this screen's frame rate, small mean hold.
    Also: below 20 frames/s the sender's `MAX_DT` clamp slows its runner in game time too.
- **A short server move read as a dash** (a 6-stud jump in one frame). Any step faster than 2 x `DASH_SPEED` is now a
  teleport: speed restarts at 0. Same for a jump over 20 studs (a respawn or a fall-out reset).

**Measured** (`remote_pose.test.luau`, pinned as a measurement → S11): a scripted run, jump, dash and wall slide by a
real `Movement` runner in the test world; the remote pose shows the owner's pose family (idle, run, rise, apex, fall,
dash) on 258 of 280 frames (92%). The misses are the 1-2 frame edges of each pose. Every rule in `RemotePose` was
mutation-checked: deleting it fails a named test (slide flag, teleport by distance and by speed, dash band, landing,
the run clock, the hold, the start-from-rest time).

**The Studio dummy stays an orange box** (Danzo's call, default box): `Others` skips ids below -999. Giving it a
sprite is one line there.

**Streaming.** The place has `StreamingEnabled`. A far runner could be streamed out on a phone, and then neither the
tag claim (`Tagging.claim` walks the tagged models) nor its arrow would see it. Runner models are now
`ModelStreamingMode = Persistent` (seen on the client in Play): four small models, always present.

## 4. Off-screen arrows (DESIGN §2, locked)

`SideCam.edgeArrow(camX, camY, aspect, tx, ty, margin, inset)`: the camera looks straight down the plane's normal,
so on the plane the screen is linear: `CAMERA_VIEW_HEIGHT` (48) studs tall, that x the viewport aspect wide. A target
whose centre is within `margin` (2 studs, half the sprite) past an edge gets no arrow; otherwise the arrow sits
`inset` (3.5 studs, ~45 px) in from the edge on the line from the view's centre to the target, rotated to point at
it. Tested: no arrow on screen or with half the sprite showing; right, left, up, down; a far corner on the line and on
the inset edge; the aspect (a tall phone needs an arrow sooner).

`client/Arrows.lua`: a ScreenGui with `IgnoreGuiInset = true` (the camera's viewport includes the top bar, so the
maths does too). One marker per other runner off screen: a round badge with the runner's initial (from `Hud.nameOf`,
so "D" for the dummy) and a turned square as the pointer. **The holder's is red**, others white, runners not in play
(out, or waiting for the next round) dimmed. Seen in Play: with the dummy 120 studs right, a white "D" badge at the
right edge (u 0.957, v 0.533, pointing right). Placeholder UI, not art.

## 5. Decision 3: round-ready, with a 5 s timeout

In Studio the client drew its first frame ~2.5 s after the server started round 1, so the start wait (RUN!/count/GO!)
was over before it was seen (H6, H8). Now:
- **`Remotes.Ready`**, client → server, **no payload**. Fired once per client session, after its runner's first draw
  (`Client.client.lua`). The server reads only the sender (→ N4): `ready[UserId] = true`, a repeat changes nothing,
  cleared when the player leaves.
- **`Match.startRound` holds a due round** until `Tag.readyToStart`: every present player is ready, or the round has
  waited `Config.READY_TIMEOUT` (5 s) since it fell due. The dummy (no client) is never waited for. One stalled client
  cannot hold everyone; the log names who never sent Ready.
- **Trust:** a client that lies can only start a round it cannot see yet. No rate limit is needed beyond the flag
  (a repeat is one table read).
- **Why 5 s:** twice the slowest first draw seen in Studio (~2.5 s); a stalled client delays round 1 by at most 5 s
  for everyone. Danzo's knob.
- Later rounds do not wait: everyone is already ready, and round start rebuilds each body (H8) on a client that is
  already running. A late joiner is waited for (up to 5 s) at the next round.
- **Seen in Play:** `round held: waiting for every client to draw`, then `client: ready sent`, `<id> ready (client
  drew its runner)`, then `round 1: 2 runner(s) ...`. Rounds 2 and 3 started without a hold.

## 6. Testing, and what is still Danzo's

- **Studio MCP cannot drive Test → Clients and Servers.** The MCP's Play is one client. Setting
  `TestService.NumberOfPlayers = 2` and starting Play still gave one player (set back to 0). So no two-client run yet.
- **What ran:** `npm test`, `lint:luau`, the new tests; solo Play with the dummy; the stand-in runner (`RunnerId` -2,
  server-moved) drawn and logged on the client; the collision-group block and its `Default` control; the arrows.
- **Checked by Danzo solo (2026-10-12)** against the physics stand-in: 1 (drawn, animated, smooth), 2 (pass-through,
  no stop or wall-kick) and 3 (the edge arrow). The stand-in is not in the match roster, so it cannot be tagged.
- **Danzo's two-player test** (Studio, Test tab → Clients and Servers → 2 players → Start), still to see: 4 and 5.
  1. Each window shows the other runner as the drawn character (not invisible), running, jumping, dashing and facing
     the right way, with no flicker between poses.
  2. Run through each other: no stop, no shove, no wall-kick off the other body; "it" too.
  3. Run apart: an arrow at the screen edge points at the other one; red on the holder's.
  4. Round 1: the RUN!/count/GO! is seen in both windows from the start.
  **First run, 2026-10-14 (H13):** each window drew the other runner at its round-start spot and no tag landed; see
  [trust.md](trust.md) §9 for the read and the ownership guard.
  5. Tags between the two feel fair at run speed (that is H12's measurement of `TAG_VIEW_DELAY`; note any that look
     too far or that missed).

## 7. Notes for H12 (the movement remote and the two-client delay)

- **Done (H12, 2026-10-12):** no movement remote; the server's speed check is a per-axis distance budget over its own
  samples, so held frames refill and stepped positions pass ([trust.md](trust.md)). `RemotePose`'s per-step speed
  would not do on the server: its copy catches up at ~2x dash speed after a stop (trust.md §3).
- With two real clients the target on the tagger's screen is two hops old; measure it with the same Heartbeat logger
  as H6 (both clients and the server in one Studio process share `os.clock`).

## 8. The numbers

| Name | Value | Where |
|---|---|---|
| `Config.READY_TIMEOUT` | 5 s | how long a due round waits for every client's Ready |
| `RemotePose` `VEL_SETTLE` / `HOLD` | 0.03 s / 0.1 s | speed smoothing / longest replication hold before "standing" |
| `RemotePose` dash band | 100 studs/s | midway between `DASH_SPEED` and `DASH_END_SPEED` |
| `RemotePose` teleport | 20 studs, or 2 x `DASH_SPEED` | a respawn or server move, not a run |
| `Config.OTHERS_DRAW_DELAY` | 0.1 s | the least another runner is drawn behind its replicated root (H13); the trail adapts upward |
| `Config.OTHERS_DRAW_DELAY_MAX` | 0.3 s | the most; a sender stepping slower than this still shows |
| `Arrows` margin / inset | 2 / 3.5 studs | no arrow while half the sprite shows / arrow distance from the edge |

## Expansion: deficits at scale

- `Others` casts 9 rays per other runner per frame (3 down, 3 each side): 27 a frame at 4 players. Cheap; if ghosts
  or bots multiply runners, cast the side rays only when airborne.
- `Arrows` walks `GetTagged` every frame and rebuilds a marker when one leaves and comes back; fine at 4 runners.
- `Ready` is per session; if a client can lose its scripts mid-match (a teleport between places), it needs a reset.
