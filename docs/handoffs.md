# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-10-14

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

(none)

## Resolved

### H14 — The snapshot stream: other runners drawn from a 20-30 Hz unreliable remote, not physics replication — 2026-10-14 20:30 — RESOLVED
- **Trigger:** 3 (a new remote; what the server trusts and records for the tag) and 1 (replaces H12's "no movement
  remote" decision in `docs/systems/trust.md` §2; DESIGN §3 rule 6 unchanged).
- **Doc:** `docs/systems/netcode.md` §3-§5 (the research and the recipe), `docs/systems/trust.md` §2, `docs/systems/tag.md`
  §2, `docs/systems/players.md` §3, `docs/systems/README.md` (remotes table).
- **Observed:** two Studio clients on one PC, Studio frame cap 240 (so no rig throttle), H13's adaptive trail on: the other
  runner is smooth but "I press the button to jump or move and it takes a second to register on the other player's
  screen, enough that it's quite jarring" (Danzo, 2026-10-14). Tags also land before contact on the victim's screen.
  There is no network on one PC: the delay is the physics-replication path itself (client-owned body → server ~0.18 s
  (N6), relay, arrival smoothing on the second hop, plus the 0.1-0.3 s trail).
- **Evidence:** H13 runs 1-6 in `docs/handoffs.md`; `docs/systems/netcode.md` §2 confirmed note and §3; the forum and
  Gaffer sources listed there; `client/Body.lua:80-82` (CFrame teleport each frame), `client/Others.lua` and
  `shared/RemotePose.lua` (the current draw path), `server/Match.lua sample()` and `server/MoveGuard.lua` (the server's
  record and speed check read the replicated body today).
- **Routine session's read:** build netcode.md §4 as written: the owning client sends a snapshot (x, y, vx, vy, facing,
  state bits, and a client sequence or time) at a fixed 20-30 Hz on Heartbeat over an `UnreliableRemoteEvent` declared in
  `default.project.json` under `ReplicatedStorage.Remotes`; the server stamps it with its clock, rate-limits it, feeds
  it to the SAME `MoveCheck` budget (so the trust rule and its numbers do not change), records it as the runner's
  sample for `Tag.touchedBetween`, and relays it to the other clients (one relay per tick, or per sender); receivers keep
  a short buffer and draw 2-3 snapshots behind, interpolating between the bracketing pair (linear at 30 Hz; the sent
  velocity is there if Hermite is needed), falling back to the replicated body only until the first snapshot arrives.
  The physics body stays (walls, floors, the server's copy, the ownership guard). `RemotePose`'s pose derivation can
  read the snapshot's velocity and state directly instead of inferring them from position deltas. A guess on numbers:
  30 Hz, buffer 2 snapshots (~67 ms), snap on a jump > 20 studs as the trail does today. Second step, after it works:
  DESIGN rule 6's catch-up: on a verdict, the tagger's drawn sprite lunges to the victim's drawn spot over ~0.1 s
  before the IT swap, no new art needed (a positional lunge of the existing sprite).
- **Decision needed:** build it (Danzo, 2026-10-14: "send a fable agent to make it work whichever way is best"). The
  agent decides the rate, buffer, payload packing and what the server still reads from the physics body, and records
  each in netcode.md with its fairness cost stated plainly. Hard limits: no trust number loosened; the server never
  trusts a client timestamp for the tag record (it stamps on arrival); the new remote is rate-limited and size-checked
  like `TagClaim`; the remotes table in `docs/systems/README.md` and `default.project.json` stay in step; nothing moves
  in the Rojo tree; shared/ stays pure and tested; the line ceiling holds.
- **Blocked routine work:** the two-player test and everything after it in `ideas/INBOX.md`.

Resolution (the Fable session, 2026-10-14):
- **Built 2026-10-14:** `Remotes.Snapshot` (UnreliableRemoteEvent) + `shared/Snapshot` (wire, ring, limiter, buffer; 13 tests,
  mutation-checked) + `server/Snapshots` (limit, stamp, grace after a rebuild, batch relay) + the client sender and
  `Others` drawing 0.08 s behind the stream, the claim testing the drawn spot, rule 6's lunge (`TAG_LUNGE_TIME`). No
  trust number changed. Tree: two new ModuleScripts and the remote, nothing moved. Not yet seen in Studio.
  → `docs/systems/netcode.md` §8, trust.md §2, tag.md §2, players.md §3, README remotes; learnings N12, T12.

Resolution (added by the routine session after Danzo's Play):
- **Resolved 2026-10-14 (run 7, two Studio clients, cap 240):** Danzo: "suddenly there is almost no latency and the
  animations are super smooth". Routine session drove Player2 from the Studio MCP (keyboard input + screen capture of
  Player1's window): 27-29 snapshots/s each way, starved ~0%, tags both ways, 0 hand-backs, 0 move warnings. One fix
  after the build: the relay's number keys arrive as strings (→ N13), `tonumber` on receipt in `client/Others.lua`.
  → `docs/systems/netcode.md` §8, `trust.md` §2, `tag.md` §2, `players.md` §3, README remotes table; learnings N12, N13, T12.

### H13 — Two real clients: positions out of sync, no tag between players, dummy untaggable after a tag — 2026-10-14 15:40 — RESOLVED
- **Tags fixed 2026-10-14:** the cause was client-owned bodies losing their network owner with two real clients (server copy
  stuck at the spawn); `server/MoveGuard` re-asserts ownership every frame (seen: tags land between players and on the
  dummy; why the engine drops it is unknown, the `body:` count will confirm). Choppy other runner: drawn 0.1 s behind
  through a smoothed trail (`Config.OTHERS_DRAW_DELAY`; claim still on the root), feel check is Danzo's.
  → `docs/systems/trust.md` §9, `docs/systems/players.md` §3; learnings N11.
- **Run 4 (2026-10-14):** with the 0.1 s trail, "better slightly but still nowhere near as smooth". Reopened for the
  choppiness only (the tag cause stands). Delay now adapts (0.1 to 0.3 s); sender loop-rate and arrival logs added.
  Suspect: Studio throttles the unfocused test window (unverified). Settled by Danzo's focus experiment plus the
  `client: own loop` and `others:` lines. → `docs/systems/players.md` §3.

Resolution (added by the routine session after Danzo's Play):
- **Resolved 2026-10-14:** three causes, three fixes: (1) client-owned bodies lost their network owner with two real
  clients → `server/MoveGuard` re-asserts ownership every frame (N11); (2) the one-PC rig renders unfocused windows at
  25% of the frame cap → Studio `FramerateCap` 240 (T12); (3) the physics-replication path itself (~0.4 s to another
  screen) → H14's snapshot stream (N12). → `docs/systems/trust.md` §9, `players.md` §3, `netcode.md`.

- **Run 5 (routine, 2026-10-14):** adaptive trail "still choppy"; tagged before touched on the victim's screen. Danzo
  asked for research instead of a fourth patch: `docs/systems/netcode.md`. Policy: the handoff has bounced back
  three times; the Fable question goes to Danzo. Decision pending: test on two real devices / Studio 240 cap first,
  then the snapshot stream (§4) and rule 6's catch-up (§5).
- **Run 6 (routine, 2026-10-14):** Studio cap 240 → "smooth animation"; the rig was the choppiness. Remaining:
  ~1 s input-to-other-screen delay on one PC = the physics replication path (netcode.md §2 confirmed note, §3).
  Decision put to Danzo: build the snapshot stream (§4), on Fable (this session) or the heavy agent.

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
