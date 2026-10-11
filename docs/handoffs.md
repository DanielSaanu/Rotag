# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-10-11

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

### H11 — Player 2: other runners drawn on every screen, pass-through collision, off-screen arrows, round-ready — 2026-10-11 — OPEN
- **Trigger:** 1 (collision between players: a §2/§3 addition; the arrows are already locked in §2), 2 (`shared/` helpers
  for the arrows and remote sprite pick), 3 (any new remote; what the server trusts about another client's pose).
- **Doc:** `docs/DESIGN.md` §2 "Players and map" (off-screen arrows), §3 rules 6, 15 ("bouncing off a player"), 27;
  `docs/systems/sprites-and-animation.md` §4 (how the local runner is drawn); `docs/systems/movement.md` §2 (the body,
  `SetNetworkOwner(player)`), §3 (sprite pick `Movement.sprite`); `docs/systems/tag.md` §2 (the stated anti-cheat
  limit), §4 (round start, H8 "ready" note); `docs/systems/README.md` Remotes.
- **Observed:** Danzo played the tag solo on 2026-10-11 and is happy ("dash is good, freeze works"); he said "go on
  player 2". Today each client draws only its own runner (`client/Look.lua` is built for the local character), so a
  second real player is an invisible body. The map is wider than the screen and nothing points at other players.
  Runner bodies collide with each other and block each other's wall probes (the H6 dummy showed it: a solid runner
  stopped a chaser dead and refreshed its dash on contact). In Studio the client draws its first frame ~2.5 s after the
  server starts round 1, so the start wait is over before it is seen (H6 note). Danzo asked how similar games handle
  collision between players who are not "it".
- **Evidence:** `roblox/src/client/{Look.lua,Body.lua,Client.client.lua,SideCamera.lua,Hud.lua}`,
  `roblox/src/server/{Runners.lua,Match.lua,Dummy.lua}` (`CanCollide`/`CanQuery` on the dummy root; `Runners.TAG`
  and the `RunnerId` attribute every runner model carries), `roblox/src/shared/{Movement.lua,SideCam.lua,Sprites.lua}`,
  `roblox/default.project.json` Remotes. HEAD 767e10b.
- **Routine session's read (guesses, in scope order):**
  1. **Collision: pass-through for everyone, "it" included.** Routine session's recommendation, given to Danzo with the
     reasons (chase games pass through: Gorilla Tag, SpeedRunners, UCH, most Roblox tag games via a collision group;
     one plane means a blocker cannot be walked around, rule 27; the tag is confirmed by OVERLAP, which blocking
     prevents; the dummy already had to go pass-through in H6). Danzo has NOT yet confirmed; build pass-through as the
     default and record it in DESIGN §2 as "recommended, pending Danzo" unless the routine session relays his word.
     Mechanism guess: one collision group for runner roots that does not collide with itself; wall probes
     (`Movement`'s wall/ground raycasts via the client) must ignore other runners (RaycastParams filter or `CanQuery`
     off on the root, as the dummy does). Rule 15's "bouncing off a player" is a later optional head-bounce; note it,
     don't build it.
  2. **Draw other runners.** Each client needs a `Look` per other runner, fed by the replicated body position. The
     sprite pick (`Movement.sprite`) needs pose state the server does not have (vx, vy, grounded, dash, facing). Options:
     (a) derive it client-side from the replicated root's velocity and a ground probe (no remote, approximate);
     (b) the owning client sends a small pose packet (frame/facing) through a remote the server relays (cosmetic only:
     never trusted for rules, rate-limited, shape-checked → N3/N4). Prefer whichever reads well at run speed; say which.
     The dummy can get a sprite too (it is an orange box today) or stay a box: Danzo's call, default box.
  3. **Off-screen arrows** (§2, locked): HUD edge markers pointing at each other runner, the holder's in red. Pure maths
     in `shared/SideCam.lua` or a new shared helper (tested): world x/y → screen edge point and direction.
  4. **Round-ready:** round 1 should not start until each present client has drawn (H6/H8 note). Guess: a client → server
     `Ready` remote (no payload; the server reads only the sender) and `Match.startRound` waits for all present players
     or a timeout (`Config.READY_TIMEOUT` ~5 s) so one stalled client cannot hold the round.
  5. **Not in this entry (next, H12):** the movement remote with a server speed check (tag.md §2's stated limit) and the
     two-client measurement of `TAG_VIEW_DELAY`. Do not start it; note anything you learn that it needs.
  6. **Testing:** Studio's Test → Clients and Servers with 2 players if the MCP can drive it; otherwise the dummy plus a
     hand-check in Play, and a precise ask for Danzo (two-player local test on his PC, what to look for).
- **PRESERVE (QA rounds 1–2):** one-number `TagClaim` judged on the server's history; `gained` in `TagVerdict`; the
  fuse waiting while frozen; pending claims re-judged every frame; the Studio-only dummy; RUN!/count/GO!; H8's
  spread round start by respawn (a server CFrame write does not hold on a client-owned body, N8).
- **Decision needed:** (1) collision (recommended pass-through; confirm with Danzo through the routine session if a
  question arises, do not decide alone); (2) remote-pose mechanism a or b; (3) the ready timeout. Record each in a new
  `docs/systems/players.md` (≤300 lines) plus a line in `docs/systems/README.md`, the Remotes table for any new remote,
  and the DESIGN §2 collision line.
- **Blocked routine work:** none. INBOX: the phone preset is still untested by Danzo (his note).

## Resolved

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
