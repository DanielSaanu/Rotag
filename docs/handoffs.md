# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-11-07 (H27 opened: PR 6, maps; H28 opened: the grapple yoink; H26 and H25 signed off by Danzo)

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

### H28 — The grapple yoinks: a hook tugs the runner toward the anchor, adding a little speed — 2026-11-07 16:54 — OPEN
- **Trigger:** 2 (`shared/Grapple.lua` and the hook phases in `shared/Movement.lua`, both pure and tested) and 3
  (any speed added on the hook sits under the server's x rate, `MoveCheck.RATE_X` = max(DASH_SPEED, GRAPPLE_MAX_SPEED)
  = 120; grapple.md §4 says nothing new is trusted because the swing's own cap is the dash rate: keep that true).
- **Doc:** `docs/systems/grapple.md` §2 (the rope, the reel, the pump, the cap, release), §3 (angle + leapfrog), §4
  (trust), §7 (the numbers); `docs/DESIGN.md` §2 (run builds, the swing releases, the dash redirects) and §3 rules 15-21.
- **Observed:** Danzo, 2026-11-07, after signing the grapple off: "can we modify the grapples and have them sort of
  yoink the player a little bit in their direction, increasing their velocity a bit". Today a hook sets the rope to the
  distance at the hook (floor hooks reel in at `GRAPPLE_REEL` 40/s to `GRAPPLE_LIFT`), the rope only pulls, and the
  swing's speed comes from the fall and the pump; a hook at a walk starts a slow swing.
- **Evidence:** `roblox/src/shared/Config.lua` lines 156-175 (the grapple knobs); `test/luau/grapple.test.luau`,
  `test/luau/move_check_grapple.test.luau` (five driven 10 s chains never flagged, budgets pinned); HEAD 7df4ac3.
- **Routine session's read (a guess):** two shapes: (a) a short reel on EVERY hook, not only floor ones, pulling the
  runner toward the anchor for the first ~0.15-0.25 s (a shortening pendulum keeps its angular momentum, so the swing
  speeds up by itself, and the tug toward the anchor is literally the yoink); (b) a one-off tangential impulse on the
  hook, `GRAPPLE_YOINK` studs/s along the swing toward the anchor's side, clamped by the cap. (a) is more physical and
  reads as a pull; (b) is one line and one knob. Either way the cap (120) stays, so the trust story holds; check the
  driven chains and the release boost x1.1 still fit the burst (grapple.md §4, §4's worst budget). "A little bit":
  small enough that a hook at a walk does not become a free dash.
- **Decision needed:** which shape, the size (a knob in Config with Danzo's one-line comment), and that `MoveCheck`
  needs no new allowance. Then build, re-pin tests (mutation-check the new knob: 0 fails a named assertion), update
  grapple.md §2, §7, §9, a `docs/qa/grapple-yoink.md` goals file for a short QA loop, worklog, and if Studio is connected
  see it in Play (a hook at a walk, a hook at a sprint, a floor hook). Say what Danzo should feel for.
- **Blocked routine work:** none. H27 (maps) runs in parallel on the branch; work in a worktree and merge, as H26 did.

### H27 — PR 6, maps: map data instead of the hand-built test arena, the first real map, per-map window bounds — 2026-11-07 16:37 — OPEN
- **Trigger:** 1 (which map first; the shrink's shape per map: DESIGN §6.8, rule 48, rule 51) and 2 (a map format other
  modules depend on: `server/Arena.lua` is read by `server/Walls`, `server/Match`, `server/Placement`, `server/Server`,
  `client/Grapple` via `ANCHOR_TAG`).
- **Doc:** `docs/systems/ghosts-v2-proposal.md` §6 (the four feels) and §12 item 6 (the PR); `docs/DESIGN.md` §3 rules
  25-30 and 48, §6.8; `docs/systems/placement.md` (keep-clear, `Arena.static()`), `docs/systems/walls.md` (`Arena.WINDOW`),
  `docs/systems/grapple.md` (anchors), `docs/systems/orbs.md` if present (spots).
- **Observed:** every system so far runs on one hand-built test arena (`server/Arena.lua`, 148 lines: BLOCKS, SPAWN,
  WINDOW, GHOST_ORBS, LIVING_ORBS, KEEP_CLEAR, ANCHORS, `static()`, `build()`). PRs 1-5b and the grapple are built,
  QA'd and signed off by Danzo (2026-11-07). Nothing else is left before PR 6 in the §12 order.
- **Evidence:** `git log --oneline -8` (b41e10e H26 closed, 90b7b39 the grace to 6 s); `npm test` fail 0 and
  `npm run lint:luau` clean at 90b7b39; line ceiling headroom: `server/Match.lua` 391/400, `client/Client.client.lua`
  314, `client/Hud.lua` 288 (`test/structure.test.js`), so new logic goes in NEW modules.
- **Routine session's read (a guess):** one map module per map under `server/` (data only: blocks, spawn, window,
  orb spots, keep-clear, anchors, pads), `Arena` becomes the loader that picks one and exposes today's fields unchanged,
  so no dependant changes its calls. The window may need a vertical pair for a tall map (walls.md says so); if the
  walls' maths changes for that, it is this PR's trigger 2. First map: Danzo was asked to pick in §12 and today said
  "go ahead with whatever is next", so pick one with a recorded reason and the others follow in later sessions; the
  routine's lean is the Yard (open, closest to the test arena's style, shows pads, anchors and fixtures the most), the
  Tower second (vertical shrink is the new maths). A guess, not a decision.
- **Decision needed:** the map data format (what a map file carries, pure or server-only), which map is built first
  and its size (proposal: ~340 x 150 studs, 6 orb spots, rules 25-29 kept), how the window bounds and the shrink work
  per map (horizontal only, or vertical too), how a map is chosen per round (one fixed map first is fine). Then build
  it, playable, with tests for the map rule (no sealing, keep-clear) and the window inside the bounds, a
  `docs/qa/maps.md` goals file for the QA loop, and `docs/systems/maps.md` (or the right existing doc) with the reasoning.
  Danzo tests in Studio afterwards: say what he should look at.
- **Blocked routine work:** the art block (pieces, pads, the grant, the ignition, the walls, the hang pose) waits
  behind this PR in the §12 order; nothing else.

## Resolved

### H26 — The closing walls loosely follow the runners, irregularly, so the pack is pushed together — 2026-11-02 — RESOLVED
- **Resolved 2026-11-02:** built by the heavy (a lean toward "it" plus a seeded wander on the living mean, inside
  `Arena.WINDOW`; hysteresis at the edge after a flapping dummy in Studio), QA loop 8/10 in round 1 → `docs/systems/walls.md`
  §7.7, `docs/qa/ghosts-v2-walls-2-summary.md`.

### H25 — The living grapple: hold to hang on marked anchors, release keeps the swing — 2026-11-01 02:10 — RESOLVED
- **Resolved 2026-11-02:** built by the heavy, QA loop 7 → 7 → 8/10 (target met in round 3). Anchors, aim assist, the
  leapfrog swing, release/jump/dash off the rope, no new trust → `docs/systems/grapple.md`, `docs/qa/grapple-summary.md`.

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
