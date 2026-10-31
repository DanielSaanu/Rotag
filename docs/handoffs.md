# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-11-01 (H25 built, QA loop next)

A routine session appends here the moment an escalation trigger fires (CLAUDE.md, "Model policy and
escalation"). The heavy agent reads this file first, works the open entries, records its full reasoning in
the doc the entry names, and marks the entry RESOLVED.

Keep this file small. Once the detail lives in the real doc, trim the resolved entry to its heading plus one
resolved line.

## Entry template

```
### H<n> — <one-line title> — <YYYY-MM-DD HH:MM> — OPEN
- **Trigger:** <which of the numbered triggers>
- **Doc:** <path> §<section>
- **Observed:** <what was seen, plainly — exact error text, failing test, the diff, the Studio Output line>
- **Evidence:** <commands run, file:line, export PNG, branch, commit>
- **Routine session's read:** <best guess, clearly marked as a guess>
- **Decision needed:** <the specific question or action>
- **Blocked routine work:** <what is on hold, if anything>

Resolution (added by the heavy agent under the same entry):
- **Resolved <date>:** <one line> → recorded in <path> §<section>
```

## Open

### H25 — The living grapple: hold to hang on marked anchors, release keeps the swing — 2026-11-01 02:10 — BUILT, QA loop next
- **Trigger:** 2 (`shared/Movement` gains a move; `shared/MoveCheck`'s rates must cover a swing's speed; `shared/
  Snapshot` and `shared/RemotePose` if the wire carries the rope; `shared/SideCam` if the camera leads into a swing),
  3 (the speed check: a swing can exceed the dash rate the x budget is built on, so the budget needs a grapple
  allowance the server can bound; what the server trusts about "I am on an anchor"), 6 (the aim assist and the
  swing run every physics step; the rope is drawn every frame on every screen), 1 only if DESIGN §2's kit line or
  rule 17 needs wording (say which line).
- **Doc:** `docs/DESIGN.md` §2 (the kit: "Grapple"; "moves should hand speed off to each other: 2. Grapple swing
  releases you with that speed"), §3 rules 16 (momentum kept), 17 (the grapple rules: marked colour-coded anchors,
  aim assist to the nearest, release keeps swing speed with a small optional boost, never target off-screen anchors),
  18-21 (easy to start, mistakes cost little, never floaty, juice), 29 (colour-code anchors), 37 (ghosts never
  grapple), §4 rows Grapple Dog, Stickman Hook, Parkour Reborn, SpeedRunners; `docs/PRINCIPLES.md`;
  `docs/systems/movement.md` (the body, the step order, the numbers, the probes, the camera lead);
  `docs/systems/controls.md` (the Grapple row: W / C / ↑ / right mouse / RT held; the GRAPPLE touch button, 76 px
  above JUMP, hidden until this PR; a ghost's rotate shares the input); `docs/systems/trust.md` §3, §8 ("a new move
  that is faster must raise MoveCheck's rates in the same change"); `docs/systems/netcode.md` §8 (the 13-byte
  snapshot, the state bits); `docs/systems/players.md` §3 (`RemotePose`: the other runner's pose from the stream);
  `docs/systems/sprites-and-animation.md` (frames are sprites; the checklist for a new animated thing);
  `docs/learnings.md` (S-rules: measurements pinned; T11 on probes; the A-rules).
- **Observed:** PRs 1-5b are built, QA'd 8/10 and signed off by Danzo (2026-11-01: "all working nicely"). Danzo:
  "go" on the grapple, the next item in the inbox. He is at the PC and will Play it. The grapple is the one kit move
  (DESIGN §2) not built; the controls, the touch button slot and the input (`Controls.read` gives `grapplePressed`
  and `grappleHeld`, PR 3) are in place and unread for the living.
- **Evidence:** `shared/Movement.lua` (313 lines; `step` in 7 numbered phases: contacts, jump buffer, dash, jumps,
  velocity, surfaces, facing/clock; `Input` has `jumpHeld`, `dashPressed`, `launchX/Y`, `hold`; `State` has x, y, vx,
  vy, facing, grounded, coyote, jumpBuffer, jumpHold, dashes, airJumps, dashTime, wallForce, sliding; `refresh(s)`
  gives dash and double jump back; rule 16's speed retention lives here). `Config`: RUN_SPEED 45, JUMP_SPEED 52.5,
  GRAVITY 450, DASH_SPEED 120, DASH_TIME 0.15, WALL_JUMP_H_SPEED 65, AIR_JUMPS 1, MOVE_BURST_TIME 0.2.
  `MoveCheck.RATE_X = DASH_SPEED` (120), `RATE_UP = JUMP_SPEED`, `RATE_DOWN` (135 lines): a pendulum of rope L under
  g 450 reaches sqrt(2 g L): 20 studs of rope gives 134 studs/s at the bottom, over the x rate; the x budget would
  flag an honest swing unless the rate rises or a swing allowance exists (trust.md §8). `client/Body.lua` (90 lines)
  is the only file that knows the runner is a Part: raycast contacts, anti-gravity, the plane lock, velocity out.
  `shared/Snapshot` packs 13 bytes with state bits (dash, grounded, facing...; `netcode.md` §8 lists them);
  `RemotePose` rebuilds the pose for another screen from the stream. `client/Look` draws the sprite (poses:
  `runner_idle`, `runner_run_0-7`, `runner_jump_rise`, `runner_jump_apex`, `runner_fall`, `runner_dash`, the holds; NO
  hang or swing pose on the sheet: the art block is later, so the swing uses an existing pose for now, say which, and
  a rope drawn as a thin part or beam). `server/Arena.lua` has no anchors (`BLOCKS`: floor, end walls, three
  platforms, two wall-jump walls); anchors are new map data (PR 6 will carry them per map). `server/MoveGuard`
  rebuilds a body at its last trusted spot on a violation. Line counts (ceiling 400): `Client.client.lua` 306,
  `Movement.lua` 313, `Look.lua` 291, `Controls.lua` 272, `movement.test.luau` 397, `move_check.test.luau` 422 (tests
  have no ceiling but split them when they pass ~400: `movement_world.luau` helpers exist).
- **Routine session's read (guess):** (1) Anchors: a list of points in `server/Arena` (`Arena.ANCHORS`, 4-6 over the
  test map: above the platform gaps, above the wall-jump shaft, over open floor at 3-5 tiles up), built as small
  marked parts (colour-coded, rule 29; a ring or a hook shape, placeholder), and sent to clients once (the simplest
  wire: a `sync`-like payload on an existing remote, or the anchor parts themselves tagged with `CollectionService`
  so clients read them from the workspace, no remote at all; the heavy picks). (2) Aim assist, client side, pure:
  `Movement.pickAnchor(s, anchors, view)` → the nearest anchor that is on this screen (rule 17: never off-screen) and
  above the runner within `GRAPPLE_RANGE` (trial 28 studs), favouring the one ahead of the facing. (3) The swing in
  `Movement.step`: on `grapplePressed` with a pick, enter a rope state `{ ax, ay, len }` (len = the distance at
  attach, clamped to `GRAPPLE_MAX_LEN`); while `grappleHeld`, a pendulum constraint each step: integrate velocity under
  gravity, then project the position onto the circle and remove the radial velocity (semi-implicit, stable at 60-240
  Hz; a tiny pump from the stick, `GRAPPLE_PUMP`, so a hanging runner can start swinging); on release, keep the
  tangential velocity (rule 16, DESIGN §2 line 2) plus a small boost `GRAPPLE_RELEASE_BOOST` (trial 1.1, rule 17), refresh
  the double jump and dash (rule 15 lists refresh sources; a release is a natural one: say if you add it), and a short
  `GRAPPLE_COOLDOWN` (0.2 s) before the next attach. Jump while hanging = release with the jump's vertical added. A
  hold (trap, freeze, stumble) breaks the rope. Ghosts never grapple (rule 37): the client does not read the input for
  a ghost beyond the rotate. (4) Speed trust: measure the fastest honest swing (drive it in `move_check.test.luau`: the
  longest rope from the highest anchor, pump, release at the bottom, dash) and set `MoveCheck.RATE_X` (or a swing
  allowance granted while the server sees the grapple bit in the stream, bounded by the same maths) so the chain is
  never flagged; record the new numbers in trust.md §7-8. The server never trusts "I am attached" for anything but
  the allowance; if the allowance is bit-gated, bound the bit's duration like the dash's i-frames. (5) The wire: a
  grapple bit in the snapshot's state bits plus the anchor index (one byte) so other screens draw the rope and the
  pose; `RemotePose` reads it. (6) Client: `Body` unchanged (the plane lock and probes still apply; the rope state
  is Movement's); the rope drawn as a thin neon part from the runner's hand to the anchor on every screen (own and
  others), the anchor highlighted when it is the current pick (aim assist readable: rule 17), the GRAPPLE touch
  button shown for the living (`Controls.buttons`), the camera leading into the swing if `SideCam` needs it.
  (7) Tests: `movement.test.luau` or a new `grapple.test.luau` (attach, the constraint keeps the length within 0.5
  stud over 2 s, energy does not grow when hanging still, release keeps the tangential speed, the boost, jump off the
  rope, a hold breaks it, no attach to an off-screen or out-of-range anchor, cooldown), `move_check.test.luau` (the
  driven fastest swing never flagged; pinned as a measurement), `snapshot.test.luau` (the bit and index round-trip),
  `remote_pose.test.luau`.
- **Decision needed:** design and build the living grapple as DESIGN §2 and rule 17 say, with trial numbers in Config
  and reasons in movement.md (a new section, or `docs/systems/grapple.md` if movement.md would pass ~300 lines).
  Write the QA goals file `docs/qa/grapple.md` in the shape of `docs/qa/ghosts-v2-walls.md` (the loop question: does
  the grapple hand speed off to the other moves, is it easy to start and never floaty, is the aim assist readable, is
  the server never fooled). Verification steps 1-4 (new ModuleScripts fine; a new remote only if the anchors need one:
  then `default.project.json` and the README table). Update movement.md, controls.md (the Grapple row is live, the
  button shows), trust.md §7-8, netcode.md §8 (the bits), the README remotes table if touched, the src READMEs,
  DESIGN only if a line's wording must change (say which). One worklog line. Mark H25 "Built, QA loop next". Do NOT
  commit. Do not touch `sprites/`, `scenes/`, `Sprites.lua` or `assets.lock.json`. Movement FEEL is Danzo's call by
  hand: name in the goals file exactly what he should try.
- **Blocked routine work:** the QA loop on the grapple; PR 6's anchors per map; the art block's hang/swing poses.
- **Built 2026-11-01 (heavy; QA loop next):** `shared/Grapple` (pick, rope, leapfrog swing, release) in Movement phase
  4c, `client/Grapple`, six anchors in `server/Arena`, a 14th snapshot byte; no new remote and no allowance (the swing is
  capped at the dash speed, `RATE_X` unchanged; driven chains never flagged). Calls for Danzo: the cap, a hook behind
  you, refresh on the hook (DESIGN rule 15 note) → `docs/systems/grapple.md`, trust.md §11, goals `docs/qa/grapple.md`.

## Resolved

### H24 — The closing walls: a SpeedRunners-style end phase blended with PR 5 — 2026-11-01 00:40 — RESOLVED
- **Resolved 2026-11-01 (heavy research + build; routine QA loop 8/10 in round 1):** SpeedRunners' shared shrinking
  screen became a server-owned world window (DESIGN §2 untouched): pure `shared/Walls` (open with the end phase at the
  living mean, close to `WALL_MIN_HW` 24 over 20 s, ease toward the mean, a 3 s grace reset on return and paused in
  holds, death order), `server/Walls` (the server's own record, `MatchState.window` / `outside`), `client/Walls` (neon
  edges beating with the close, a red band, screen-edge glow, GET BACK IN), `Tag.eliminate` as the one elimination
  path, a red burst for a wall kill. The reviewer: "reads instantly as the screen closing in", "one moment, not two
  systems". Waiting on Danzo's Play. → `docs/systems/endgame.md` §7, `docs/qa/ghosts-v2-walls-summary.md`, S13, T13.

### H23 — Build ghosts v2 PR 5: ignition and end-phase speed — 2026-10-31 23:30 — RESOLVED
- **Resolved 2026-10-31 (heavy build, finished after one Opus API cut-off; routine QA loop 8/10 in round 1):**
  `Tag.endPhase` (final two of a round that began with 3+, or `END_PHASE_AFTER` 120 s; no stored flag), `Tag.speedMult`
  x `END_PHASE_SPEED` 1.1 for the living, `MatchState.endPhase` (server-decided, sent at once on a flip), `Tag.ignition`
  driving `Look:ignite` (ember rim, embers, a point light), the beating red readout, the holder's arrow beating off
  screen, `client/Ignition` (the burn-out burst from the state change). `MoveCheck` untouched, proven by driving.
  DESIGN rule 51 reworded (final two of a round that began with 3+), §6 item 9 resolved-trial. Waiting on Danzo's Play
  (the +10% feel, the cap). → `docs/systems/endgame.md`, `docs/qa/ghosts-v2-endgame-summary.md`, A7.

### H22 — Build ghosts v2 PR 4: fixtures, boost pads, the boost grant, placement — 2026-10-31 19:00 — RESOLVED
- **Resolved 2026-10-31 (heavy build, finished on Fable after two Opus API cut-offs; routine QA loop 7 → 8/10):** pure
  `shared/Placement` (the seven tetrominoes, the allocation-free fit test shared with the client preview, the 3-cap
  and fade, the pad), `server/Placement` (every placement re-checked on the server's own record, parts in
  `Workspace.RotagFixtures`), `client/Place` (preview with its refusal reason, rotate on the grapple input, the pad
  launch on entry, the grant glow), `Items.grants` and `Tag.speedMult` = max(ramp, grant), `Arena.KEEP_CLEAR`. Pads
  launch ghosts too (the spec). Waiting on Danzo's Play (the pad feel). → `docs/systems/placement.md`,
  `docs/qa/ghosts-v2-placement-summary.md`, trust.md §8.

### H21 — Wire the item and hold art into the client (sprites on parts, hold poses, the frozen edge-light) — 2026-10-19 18:31 — RESOLVED
- **Resolved 2026-10-31 (heavy build 2026-10-19, Danzo's Play 2026-10-31):** `client/ItemArt` (sprites on the item parts
  behind `Sprites.Has`), hold poses in `Movement.spriteFor` (trap, the 5-frame roll, freeze keeps its frame), the
  frozen rim; sheet uploaded 2026-10-19; two post-Play fixes (orbs and crates at full size, dummies show hold poses).
  Danzo: works fine on keyboard and mouse. → `docs/systems/items.md` §9, A6.


### H20 — A frozen tagger cannot pass the fuse (rule 44 changes for the freeze) — 2026-10-19 18:11 — RESOLVED
- Built (heavy, not committed): `Items.canTag` refuses an ice-frozen holder's claims on the server's hold record (Match + Bots), iced runners stay taggable, trap/stumble unchanged (flagged); rule 44 reworded; detail in [items.md](systems/items.md) §5.

### H19 — Build ghosts v2 PR 2: living orbs, Use, the holds (crate, bear trap, ice beam) — 2026-10-19 16:47 — RESOLVED
- **Resolved 2026-10-19 (heavy build, routine QA loop):** PR 2 built: living orbs and the pools (hex now 1 roll in 5),
  `shared/Items` (uses, holds, i-frames, per-target ward), `server/Items`, `client/Use`, remote `UseItem`, the hold
  input in `Movement`, the hold budget in `MoveCheck` (from the server's own speed, whole hold, full burst on release),
  dummies use items. QA loop 7 → 8/10, items seen end to end in Play. Waiting on Danzo's Play (the pry by hand, the
  owner-immunity feel call). → `docs/systems/items.md`, `docs/systems/trust.md` §10, `docs/qa/ghosts-v2-items-summary.md`, N15.

### H18 — Build ghosts v2 PR 1: no comeback, ghost orbs, the hex — 2026-10-19 14:20 — RESOLVED
- **Resolved 2026-10-19 (heavy build, routine QA loop):** PR 1 built: no comeback (H15's mark/comeback code and tests
  retired with rules 39-40), pure `shared/Orbs` (respawn 10/(1+0.5n) live, one slot, swept touch, injected roll),
  `shared/Ghost` = the hex (held hex, -3 s, shared 6 s ward), `server/Orbs`, `client/Items`, remote `ItemEvent`.
  QA loop 7 → 7 → 8/10, everything seen in Studio Play; one open call for Danzo (hex cadence on the hex-only pool).
  → `docs/systems/ghosts.md`, `docs/qa/ghosts-v2-core-summary.md`, N14, G4.

### H17 — Keyboard and controller layout, researched — 2026-10-19 10:19 — RESOLVED
- **Resolved 2026-10-19 (heavy):** Danzo "unsure", so the researched table is the PROVISIONAL default (WASD: Space jump,
  Shift dash, W grapple, E use, mouse on; arrows: Z/X/C/V; pad A/X/RT/RB; 4 touch buttons; pry 3 taps anywhere), judged
  by hand once built, remappable. Build is PR 3. → `docs/systems/controls.md`.

### H16 — Ghosts v2 and the ability list: no comeback, placeable parts, pickups, maps — 2026-10-19 10:19 — RESOLVED
- **Resolved 2026-10-19 (heavy):** Danzo picked "orbs for everyone" with changes (trap 1 s, dash over traps not crates,
  hex -3 s, separate ghost orbs, + ignition and end-phase speed); written into DESIGN §1, §2, §3 rules 37-51, §6.2, §6.8;
  not built: 6-PR build order. → `docs/systems/ghosts-v2-proposal.md` (the spec, §12 build order).

### H15 — Ghost rules: what an eliminated player can do, its cooldowns, and how they earn a respawn — 2026-10-14 23:10 — RESOLVED
- **Resolved 2026-10-14 (heavy):** Danzo picked "recommended": ghosts spook "it" by touch (-3 s, 8 s cooldown, a shared
  6 s ward, 1.5x burn cap), the latest spooker holds the mark and comes back where it stands if the fuse runs out, once
  per player per round. Built (`shared/Ghost`, `server/Ghosts`, `server/Bots`, remotes `GhostClaim`/`GhostVerdict`, HUD,
  pale ghosts, hollow arrows); tests mutation-checked; dummy ghosts seen in Studio. A player's own spook waits on a
  `rojo serve` restart (→ T6) and Danzo's two-player test. → DESIGN §3 rules 37-41, §6.1; `docs/systems/ghosts.md`; S12.

### H14 — The snapshot stream: other runners drawn from a 20-30 Hz unreliable remote, not physics replication — 2026-10-14 20:30 — RESOLVED
- **Resolved 2026-10-14 (Fable build, Danzo's run 7 with two Studio clients):** `Remotes.Snapshot` (UnreliableRemoteEvent),
  `shared/Snapshot` (wire, ring, limiter, buffer), `server/Snapshots` (limit, stamp, grace, batch relay), the client
  sender, `Others` drawing 0.08 s behind the stream, the claim on the drawn spot, rule 6's lunge. No trust number
  changed. Danzo: "suddenly there is almost no latency and the animations are super smooth"; 27-29 snapshots/s each
  way, tags both ways, 0 hand-backs. One post-build fix: relay keys arrive as strings (N13). → `docs/systems/netcode.md`
  §8, `trust.md` §2, `tag.md` §2, `players.md` §3, README remotes; learnings N12, N13, T12. (Trimmed 2026-10-31.)

### H13 — Two real clients: positions out of sync, no tag between players, dummy untaggable after a tag — 2026-10-14 15:40 — RESOLVED
- **Resolved 2026-10-14, three causes, three fixes:** (1) client-owned bodies lost their network owner with two real
  clients → `server/MoveGuard` re-asserts ownership every frame (N11); (2) the one-PC rig renders unfocused windows at
  25% of the frame cap → Studio `FramerateCap` 240 (T12); (3) the physics-replication path itself (~0.4 s to another
  screen) → H14's snapshot stream (N12). Bounced three times (runs 4-6) before the research in `netcode.md` and the
  Fable question went to Danzo. → `docs/systems/trust.md` §9, `players.md` §3, `netcode.md`. (Trimmed 2026-10-31.)

### H12 — Movement trust: the movement remote with a server speed check — 2026-10-12 14:21 — RESOLVED
- **Resolved 2026-10-12:** no movement remote (the server checks the replicated body); `shared/MoveCheck` budgets
  distance per axis at `DASH_SPEED`/`JUMP_SPEED`/`MAX_FALL` with 0.2 s of slack; on a violation `server/MoveGuard` marks
  samples untrusted (`Tag.touchedBetween` skips them for the claimant), warns, and rebuilds the body at its last
  full-budget spot. Seen in Studio: honest runs quiet; a +60 client teleport and a ~150 studs/s push caught and snapped
  back; a 37.5-stud teleport onto the dummy still tagged (the stated limit). → `docs/systems/trust.md`; learnings N10.

### H11 — Player 2: other runners drawn on every screen, pass-through collision, off-screen arrows, round-ready — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** runners pass through each other via the `RotagRunners` collision group, probes cast as it
  (recommended, pending Danzo; DESIGN §2 line); other runners drawn from their replicated position by `shared/RemotePose`
  (option a, no remote; 92% pose agreement measured); off-screen arrows (`SideCam.edgeArrow`, `client/Arrows`); new
  remote `Ready` (no payload), round held up to `READY_TIMEOUT` 5 s. Seen in solo Play with a stand-in runner; the MCP
  cannot run two clients, so the two-player check is Danzo's. → `docs/systems/players.md`; learnings N9, T10, T11.

### H10 — Dash chains, take two: Danzo switched to option 1 (a floor dash ends at run speed); undo option 2 — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** `airSinceDash` removed (refresh as before H9); `State.dashFloor` set at dash start, a floor
  dash ends at `Config.DASH_END_SPEED_FLOOR` (= `RUN_SPEED`), an air dash at 80, a jump out of either keeps 120. Mashing
  from rest over five cooldowns: 59.06 vs 44.58 studs/s, x1.325, pinned as a measurement; `DASH_COOLDOWN` 0.8 left
  for Danzo. Seen in Play. → `docs/systems/movement.md` §3, §9; learnings S11, T9.

### H9 — Dash chains: a ground dash recharges only after landing from the air (Danzo's option 2) — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** `State.airSinceDash` (dash start sets `not grounded`, any airborne frame sets true;
  `refresh` gives the dash back only when true); cooldown 0.8 kept as the second guard. Mashing 3 s on the floor: one
  dash, 45.0 studs/s after the burst (old rule 60.5); confirmed in Play. → `docs/systems/movement.md` §3, §9; S11.
  **Superseded the same day by H10** (Danzo switched to option 1); `airSinceDash` is gone.

### H8 — QA round 2 fixes: spread positions at round start; a spectating list in MatchState — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** round start rebuilds each player's body at its spot (`Runners.spawn`, option (b); a server
  CFrame write, option (a), lost to the owner while running, seen in Studio); spots from `Tag.startPlaces` (even over
  120 studs, starter at the left end); `MatchState.spectating` and "next round soon". Seen holding in Play across four
  rounds, server and client. → `docs/systems/tag.md` §4, §8; `docs/systems/README.md`; `docs/systems/movement.md` §2; N8.

### H7 — QA round 1 fixes: honest "+gained" pop, round gap after a leave, README row — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** `Tag.pass` returns `(fuse, gained)`, `TagVerdict` gains `gained`, the HUD pops `+2s` or
  `+0.4s, capped` (seen in Play); a leave that ends the round now gets `ROUND_GAP`, and `Tag.leave` ignores a finished
  round; README row fixed. → `docs/systems/tag.md` §2, §4, §5; `docs/systems/README.md`; learnings N7.

### H6 — Tag Play feedback: tagged once only, frozen at start until a key is re-pressed, dash spam — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** (1) a bug: the server judged a claim on arrival, same frame only, but sees a client body
  ~0.18 s late (measured), so run-through and trailing tags dropped; now the claim stays open 0.35 s and pairs the
  claimant with target samples up to ping + 0.4 s older (cap 0.5); and the dummy was a wall to the client's probes
  (`CanQuery = false`). (2) `START_FREEZE` 3 -> 1 s with a big countdown to GO and "RUN!"; a held key resumes after a
  freeze (checked); the re-press is most likely Studio's game view lacking focus after Play (unconfirmed). (3)
  `DASH_COOLDOWN` 0.2 -> 0.8 s, tested. Also, from Danzo: pass bonus +2 (trial), fuse capped at the life's fresh fuse,
  the IT marker is a red glowing triangle (neon wedges; the old BillboardGui never drew).
  → `docs/systems/tag.md` §2, §3, §4, §5, §6, §9; `docs/systems/movement.md` §3, §5; learnings N5 (corrected), N6, A5, T9.

### H5 — The tag: server-owned "it", the 45 s fuse, the +5 s pass, lag-fair confirm, HUD fuse — 2026-10-11 — RESOLVED
- **Resolved 2026-10-11:** built `shared/Tag` (tested, mutation-checked), `server/Match`, `server/Dummy`,
  `client/Tagging`, `client/Hud`, remotes `TagClaim` (one number) / `TagVerdict` / `MatchState`. (a) server trusts only
  the claimant's identity and the target id; rate gap 0.1 s, only an unfrozen holder may claim, overlap re-checked on
  the server's own position history with ping rewind capped 0.3 s + 1.5 stud grace; (b) freeze the new holder 1.5 s,
  fuse paused; (c) rotation in join order, solo = always it; (d) Studio-only dummy runner (id -1000) or Studio's
  2-player local server; (e) shrink per elimination 45/35/25, a pass is always remaining + 5. Server round, rotation,
  elimination and the dummy's tag seen in Play; the client side needs `rojo serve` restarted (→ T6).
  → `docs/systems/tag.md`, `docs/systems/README.md` Remotes, learnings N4, N5, T8.

### H4 — A join remote carries the resolved sprite-sheet ids to clients — 2026-10-10 15:40 — RESOLVED
- **Resolved 2026-10-10:** one RemoteEvent `Remotes.SheetIds`, server → one client on join, payload
  `{ [number]: string }` (`rbxassetid://<digits>` per sheet); server never listens (no-op sink) and warns instead of
  hanging if it is missing; client draws at once with built-in ids, re-applies on arrival (`Look:refresh()`), checks
  shape only, warns after 10 s. Not yet seen in Play: restart `rojo serve` first (→ T6). → `docs/systems/README.md`
  Remotes, learnings N3, T6.

### H3 — Sprite pick for the new pose set: 8 run frames, jump rise/apex, fall, dash — 2026-10-10 15:05 — RESOLVED
- **Resolved 2026-10-10:** `RUN_FRAMES = 8`, `RUN_CYCLE` 20; dash → `runner_dash`; air by `vy` (y up) against new
  `Config.APEX_POSE_BELOW = HALF_GRAVITY_BELOW` (20): rise, apex, fall; a wall slide (new `s.sliding`, cap 10 sits
  inside the apex band) shows fall; a run from rest now really opens on frame 0 (new `s.runFrom`; it did not before).
  No move rule changed. Tests mutation-checked; test file at 398/400 lines. → `docs/systems/movement.md` §3, learnings A4.

### H2 — Run cycle: four frames (two strides, two passing poses) instead of two — 2026-10-10 14:40 — RESOLVED
- **Resolved 2026-10-10:** `Config.RUN_FRAMES = 4` (a count, not a name table) and `Config.RUN_CYCLE = 20` studs per full
  cycle replacing the per-frame `RUN_STRIDE`, so frame count and cadence are separate knobs; frames still change every
  5 studs, the legs cycle at half the old rate. Test pins frame order and cycle length (mutation-checked). Feel is
  Danzo's to judge; tune `RUN_CYCLE`. → `docs/systems/sprites-and-animation.md` §3, `docs/systems/movement.md` §3, learnings A3.

### H1 — First playable: side-on camera, one runner, sprites drawn two ways — 2026-10-09 — RESOLVED
- **Resolved 2026-10-09:** built by the heavy agent, played by Danzo the same day ("that worked and I actually quite
  like it"); he chose the SurfaceGui over the BillboardGui, and the negative-rect flip worked unaided. Loser deleted.
  → `docs/systems/movement.md` §2 (the body), §6 (drawing and flip), `docs/systems/sprites-and-animation.md` §4.
