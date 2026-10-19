# Worklog

One dated line per block of work, newest last. Say what changed and where, and cite learnings IDs if a rule was
paid for. The detail belongs in commits and the docs; this is the timeline.

- 2026-10-09 · `claude/friendly-hawking-74891i`: repo bootstrapped from The Warehouse. Design notes in
  `docs/DESIGN.md`; the pipeline (`bin/`, `src/`, `ui/`, tests, `tools/luau-check.js`) copied unchanged; `CLAUDE.md`,
  `INDEX.md`, `docs/learnings.md` (inherited rules), `docs/handoffs.md`, the heavy agent and the qa-loop skill
  adapted to this game; a Rojo scaffold (`Config`, two entry stubs, generated `Sprites.lua`) with a placeholder
  runner (idle + two run frames) to prove `roblox build`. `npm test` and `npm run lint:luau` green. Not yet
  uploaded (sheet id 0) and not yet opened in Studio.
- 2026-10-09 · `claude/friendly-hawking-74891i` · heavy, H1: the first playable, built but not yet played.
  `shared/Movement.lua` (run, jump, double jump, wall jump, dash, Celeste forgiveness, refresh on contact, speed
  kept and banked) and `shared/SideCam.lua`, each with a Luau test, each rule mutation-checked (→ S8, new Q5);
  `server/Arena.lua` (test map in `Workspace.Map`) and `server/Runners.lua` (one-box runner, dormant Humanoid);
  `client/Body`, `Controls` (two touch buttons), `Look` (sprite two ways behind `SurfaceSprites`, flip behind
  `FlipBySize`), `SideCamera`. Tree only grew (8 ModuleScripts, sourcemap diffed). `lint:luau` learnt the Roblox
  globals `RaycastParams` and `PhysicalProperties`. Detail: `docs/systems/movement.md`.
- 2026-10-09 · `claude/friendly-hawking-74891i`: H1 played and resolved. Danzo picked the SurfaceGui runner over the
  BillboardGui (the world-face parallax reads nicer) and the negative-rect flip worked; `Look.lua` keeps only that path
  (151 → 126 lines), the `SurfaceSprites` and `FlipBySize` attributes are gone from the server and the docs. Next: tag.
- 2026-10-10 · `claude/friendly-hawking-74891i`: high-resolution runner. Danzo asked for a smooth, non-pixel figure that
  sits in the 3D stage. Three 128 px vector poses from `tools/runner-rig.js` (idle, run_0, run_1), scenes
  `pixelated: false`, `Look.lua` samples bilinear. Sheet rebuilt (CHANGED, awaiting Danzo's `--upload`). Play boots
  clean. DESIGN §6.3 partly answered, learnings A2.
  Danzo: the back-swung arm bent the wrong way (elbow low, hand high); fixed in the rig: elbow high and behind, hand low. Then the scarf knot showed over the back
  shoulder: knot moved under the chin and drawn before the near limbs, scarf routed above the elbow.
  Danzo uploaded (decal 95377152540627); the client showed nothing because it had the decal id and no remote carries
  the resolved id yet, so the image id (135988781031637) is hard-coded via `roblox setid`, as on 2026-10-09. Seen in Play.
- 2026-10-10 · `claude/friendly-hawking-74891i` · heavy, H2: the run cycle is four frames (stride, pass, stride, pass).
  `Config.RUN_FRAMES = 4` + `Config.RUN_CYCLE = 20` studs per cycle replace the per-frame `RUN_STRIDE` in
  `Movement.spriteFor`; test pins frame order and cycle length, mutation-checked (Q5). Not yet played. Learnings A3.
- 2026-10-10 · `claude/friendly-hawking-74891i`: Danzo: the legs are too fast, needs in-betweens. Two passing poses drawn in
  `tools/runner-rig.js` (run_1, run_3; old run_1 is now run_2), five sprites in the sheet (CHANGED, awaiting upload).
  The picker change in shared/ went through H2 (heavy agent): RUN_FRAMES + RUN_CYCLE replace RUN_STRIDE. Uploaded (decal 94711766510242 → image
  98566906497928 via `roblox setid`); seen in Play. Feel is Danzo's call: RUN_CYCLE 20, up to 24–28 if still busy.
- 2026-10-10 · `claude/friendly-hawking-74891i`: Danzo: "emulate SpeedRunners, the runner doesn't give speed".
  Researched run-cycle practice (contact/down/pass/up, forward lean and head-down sell speed, 1-3 air poses, no jump
  wind-up). `tools/runner-rig.js` rebuilt: procedural 8-frame run with IK and a 24-degree lean, plus jump_rise,
  jump_apex, fall and dash. 13 sprites in the sheet (CHANGED, awaiting upload). The picker for the new poses is H3.
  Design artifact "Runner Animation Style" holds the reference sheet and the rules applied.
- 2026-10-10 · `claude/friendly-hawking-74891i` · H3 (heavy): `spriteFor` picks dash, rise/apex/fall by vy
  (`APEX_POSE_BELOW` = 20), wall slide = fall (`s.sliding`, → A4), 8 run frames; a run from rest now opens on frame 0
  (`s.runFrom`). Tests mutation-checked. Next: routine rebuilds the sheet, Danzo uploads and plays.
- 2026-10-10 · `claude/friendly-hawking-74891i`: 13-sprite sheet uploaded by Danzo (decal 105903060352937 → image
  78839933770143 via `roblox setid`); label loads it in Play, air pose seen mid-jump. Feel is Danzo's call next.
- 2026-10-10 · `claude/friendly-hawking-74891i`: Danzo: "give him some lean while he runs". Speed-driven lean in
  `Look.lua` (14° at run speed, 22° in a dash, feet pivot), client-only, no upload. Seen in Play at full speed: rot -14
  while moving at -45. Open question: an injected D key ran him towards -X (screen-left); confirm with Danzo's keyboard.
- 2026-10-10 · `claude/friendly-hawking-74891i`: H4 (heavy): first remote, `Remotes.SheetIds` (server → client on
  join, the resolved sheet ids); client draws at once and re-applies on arrival. Not yet seen in Play: `rojo serve`
  must be restarted to sync it (→ T6). Rules → N3. Detail: `docs/systems/README.md` Remotes.
- 2026-10-10 · `claude/friendly-hawking-74891i`: H4 seen working in Play. The RemoteEvent was added to the Edit tree by
  hand (the running `rojo serve` predates it, → T6); normal path: client prints 1 sheet id from the server. Remote path:
  `Sprites.lua` set to the decal id with no Resolved, the label still loaded image 78839933770143, runner visible.
  Reverted. `roblox setid` after an upload is now optional. Also: movement tests split (world, rules, sprites).
- 2026-10-11 · `claude/friendly-hawking-74891i`: H5 opened (trigger 3): the tag — server-owned "it", 45 s fuse,
  +5 s pass, lag-fair confirm (DESIGN §3 rule 6), HUD fuse. Heavy agent spawned with the entry; detail will land in
  `docs/systems/tag.md`.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H5 (heavy): the tag. `shared/Tag` + 10 test blocks (10 mutations
  caught), `server/Match` + `server/Dummy`, `client/Tagging` + `client/Hud`, `Movement` input `speedMult` (rule 4),
  remotes `TagClaim`/`TagVerdict`/`MatchState`. Play (old `rojo serve`, remotes missing, warned): round, elimination,
  rotation and the dummy's tag (`TAG -1000 -> player, fuse 48.8s`) seen; client side not yet. → `docs/systems/tag.md`,
  N4, N5, T8.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H6 (heavy): Danzo's first tag Play. Tag once = bug: server saw the
  player's body ~0.18 s late (measured) and judged claims on arrival, same frame; now a 0.35 s open window pairing the
  claimant with target samples up to ping + 0.4 s older (cap 0.5), and the dummy is `CanQuery = false` (was a wall).
  `START_FREEZE` 3 -> 1 with a GO countdown; `DASH_COOLDOWN` 0.2 -> 0.8; from Danzo: `FUSE_PASS_BONUS` 5 -> 2 (trial),
  fuse capped at the life's fresh fuse, IT marker = red glowing triangle (neon wedges). Play: 3/3 run-through tags.
  → `docs/systems/tag.md`, `docs/systems/movement.md`, N5 corrected, N6, A5, T9.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H7 (heavy): QA round 1 fixes. `Tag.pass` returns `gained`,
  `TagVerdict` carries it, HUD pops `+2s` / `+0.4s, capped` (Studio Play: `fuse 45.0s (+0.4s)`); leave that ends a
  round now gets `ROUND_GAP`; `Tag.leave` ignores a finished round; README `TagVerdict` row. → `docs/systems/tag.md`, N7.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H8 (heavy): QA round 2 fixes. Round start spreads everyone
  (`Tag.startPlaces`, `Config.START_SPREAD` 120, starter at the left end) by rebuilding each player's body there
  (`Runners.spawn`; a server CFrame write lost to the owner while running, seen in Studio); `MatchState.spectating`
  and "next round soon" for late joiners. Play: four rounds, bodies at -60/60 on server and client, held while running.
  → `docs/systems/tag.md` §4, N8.
- 2026-10-11 · `claude/friendly-hawking-74891i`: QA loop on the tag: round 1 7/10, round 2 8/10 (target). Routine fixes:
  dummy patrol off spawn, PlayerModule note, pop from `gained` with `%g`. H7 and H8 came out of the rounds. Summary and
  Danzo's checklist in `docs/qa/tag-summary.md`; round files archived. Open for Danzo: dash chains, the fuse cap.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H9 (heavy): a floor dash recharges only after air (`Movement` `airSinceDash`), mash speed pinned against run speed in `movement.test.luau` (45.0 vs old 60.5), seen in Play; movement.md §3/§9, learnings S11.
- 2026-10-11 · `claude/friendly-hawking-74891i`: Danzo's calls after the QA loop: fuse cap kept (DESIGN §2 note corrected: proposed
  by the H6 agent), dash chains option 2 (H9, heavy). DESIGN §3 rule 15 carries the H9 exception. `movement.md` sits at 302
  lines: split it on the next edit (→ G3).
- 2026-10-11 · `claude/friendly-hawking-74891i`: H10 (heavy): H9 undone; a floor dash ends at run speed (`Movement` `dashFloor`, `Config.DASH_END_SPEED_FLOOR = RUN_SPEED`), refresh back to pre-H9; mash/run measured and pinned at x1.325 (cooldown 0.8, Danzo's knob); seen in Play; movement.md §3/§9 rewritten (300 lines, no split), learnings S11/T9 extended.
- 2026-10-11 · `claude/friendly-hawking-74891i`: Danzo reversed to dash option 1 (H10, heavy): floor dash ends at run speed,
  H9's recharge gate removed, chain measured x1.325 a run and pinned. DESIGN rule 15 amendment and INBOX updated; pushed.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H11 (heavy): player 2. Pass-through collision group + probes cast as it (pending Danzo, DESIGN §2), other runners drawn via `shared/RemotePose` (option a), off-screen arrows, `Remotes.Ready` + `READY_TIMEOUT` 5 s, runner models streaming-Persistent. Tested and mutation-checked; seen in solo Play with a stand-in runner; two-client check is Danzo's. → `docs/systems/players.md`, learnings N9, T10, T11.
- 2026-10-11 · `claude/friendly-hawking-74891i`: H11 (heavy) player 2 landed: remote pose from replicated position (no
  remote), pass-through collision group, edge arrows, `Ready` round hold. Verified solo; two-client test is Danzo's.
  Pass-through still "pending Danzo" in DESIGN §2. Pushed.
- 2026-10-12 · `claude/friendly-hawking-74891i`: solo player-2 test with a stand-in runner driven from the Studio MCP. Danzo: pass-through confirmed (DESIGN §2 line flipped to confirmed), drawn + arrow fine. An anchored stand-in replicated in steps ("very choppy"); an unanchored server-owned body moved every render frame. Script saved to `tools/studio-standin.luau`; players.md §2/§6 and INBOX updated.
- 2026-10-12 · `claude/friendly-hawking-74891i`: H12 (heavy): movement trust. No movement remote (decided); `shared/MoveCheck` (per-axis distance budget at DASH_SPEED / JUMP_SPEED / MAX_FALL, burst 0.2 s) + `server/MoveGuard` (untrusted samples, server warning, snap-back to the last full-budget spot); `Tag.touchedBetween` skips untrusted claimant samples; 4 Config numbers. Tested, 10 of 10 rules mutation-checked. Studio: honest runs quiet, client +60 teleport and ~150 studs/s push caught and snapped back; a 37.5-stud teleport onto the dummy still tagged (the stated limit). → `docs/systems/trust.md`, learnings N10.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H13 (heavy), first pass: two-client screenshot read; each runner drawn at its own round-start spot (stuck server copy, leading hypothesis); snap-back loop ruled out by the client Output. `server/MoveGuard` now checks each body's network owner once a second, hands it back and warns, plus a Studio `body:` line every 5 s. Lint and tests clean; not run in Studio. Waiting on the Server Output and a re-test. → `docs/systems/trust.md` §9.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H13 (heavy), second pass after re-test 1 (owner hand-back fixed the stuck bodies; still no player-to-player tag, choppy other runner). Owner checked every frame; Studio diagnostics for claims (received, the youngest target age that overlapped, untrusted count) and the other-runner cadence; the server-body suggestion weighed. Lint and tests clean; not run in Studio. → `docs/systems/trust.md` §9.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H13 resolved (heavy). Re-test 2: tags land between players once the owner is re-asserted every frame, so the cause (by elimination) was ownership lapsing repeatedly with two real clients; why is unknown (learnings N11). Choppy other runner: `RemotePose` draw trail (`Config.OTHERS_DRAW_DELAY` 0.1 s, tested, 3 mutations caught), `Look` free mode, IT marker on the drawn spot; the claim still tests the root. Lint and tests clean; not seen in Studio. → trust.md §9, players.md §3.
- 2026-10-14 · `claude/friendly-hawking-74891i`: routine: Danzo's first two-client test failed three ways; H13 opened and run by the heavy agent across three re-tests (owner hand-back → per-frame owner check → draw trail). Verified npm test, test:luau, lint:luau, rojo build; INBOX updated. Uncommitted until Danzo judges run 4.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H13 run 4 (heavy): still choppy at 0.1 s. Trail delay now adapts to arrival gaps (floor `OTHERS_DRAW_DELAY` 0.1, cap new `OTHERS_DRAW_DELAY_MAX` 0.3; tested, 4 mutations caught); extrapolation weighed and set aside (overshoot on every stop); Studio logs for each client's own loop rate and the arrival cadence, to test the unfocused-window throttle suspect. Lint and tests clean; not seen in Studio. → players.md §3.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H13 run 5 still choppy + early tags; researched instead of patching: `docs/systems/netcode.md` (rig throttle at 25% fps, physics-replication smoother vs CFrame body, snapshot interpolation over UnreliableRemoteEvent, lag compensation). Recommendation to Danzo; no code change.
- 2026-10-14 · `claude/friendly-hawking-74891i`: run 6: Studio FramerateCap 240 (settings XML, Studio closed) made the other runner smooth: the one-PC rig was the choppiness. Remaining ~1 s press-to-other-screen delay is the physics replication path; snapshot-stream decision put to Danzo. netcode.md, handoffs H13, INBOX updated.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H14 (Fable): the snapshot stream. `Remotes.Snapshot` (UnreliableRemoteEvent), `shared/Snapshot` (13-byte wire, seq ring, limiter, interpolation buffer; tests mutation-checked), `server/Snapshots` (limit, server stamp, rebuild grace, batch relay), client sender on Heartbeat at 30 Hz, `Others` drawing 0.08 s behind with the snapshot's sprite and juice, claim on the drawn spot, rule 6's lunge. Trust numbers unchanged. lint, npm test, test:luau, rojo build clean; sourcemap: +2 ModuleScripts, nothing moved. Docs: netcode.md §8, trust §2, tag §2, players §3, README remotes, N12, T12. Pending Danzo's two-client Play; uncommitted.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H14 (Fable fork) snapshot stream + rule-6 lunge built; routine session found the relay dropped whole (number keys arrive as strings, N13) by probing the live test clients through the Studio MCP, fixed `client/Others.lua`, drove Player2 by keyboard. Run 7, Danzo: "almost no latency ... super smooth". H13 + H14 RESOLVED.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H11 proposals done: `MatchState.held` + HUD "waiting for players"; the Studio dummy wears the runner sprite (drawn by `Others` through the fallback path, box hidden client-side). Ledge dash left as is (Danzo). `docs/briefs/runner-v2.md`: the design-command brief for the runner pass 2.
- 2026-10-14 · `claude/friendly-hawking-74891i`: /design on docs/briefs/runner-v2.md → canvas "Rotag runner, pass 2" (3 boards). Rig proposal `tools/runner-rig-pass2.mjs`: smaller head + hood point, tapered torso, fists, sole lines, sprint cycle after Danzo's live notes (arms, trailing foot, "punchy and fast": heel kick 36 px, knee drive, straight-leg heel strike, flight). Not ported to runner-rig.js yet.
- 2026-10-14 · `claude/friendly-hawking-74891i`: runner pass 2 ported into `tools/runner-rig.js` after four rounds of Danzo's notes on the canvas (arm swing, trailing foot, sprint cycle, jump arms, flared wild scarf, dive dash). 13 sprites regenerated, strip rendered and checked, `roblox build` CHANGED, npm test clean. Upload is Danzo's.
- 2026-10-14 · `claude/friendly-hawking-74891i`: scarf rebuilt on cloth follow-through (Danzo: "too stiff", "flowy"): `ribbon()` in `tools/runner-rig.js`, a travelling S-wave growing toward a flared, forked tail, the run bounce arriving late down the ribbon; bounce fixed to one per step. Sprites + sheet rebuilt (CHANGED), tests clean; Danzo re-uploads.
- 2026-10-14 · `claude/friendly-hawking-74891i`: runner pass 2 accepted by Danzo in Play ("okay im satisfied") after the flowing-scarf upload (decal 93514398826893). Block closed; next is ghost rules (DESIGN §6.1).
- 2026-10-14 · `claude/friendly-hawking-74891i`: H15 ghost rules, design pass (heavy): proposal written under H15 in `docs/handoffs.md` (recommended: ghosts "spook" the holder by touch, -3 s fuse, 8 s cooldown + shared 6 s ward, the latest spooker holds the mark and swaps back in on a fuse-out, once per player per round; two ranked alternatives; DESIGN §3 rules 37-41 drafted). Waiting on Danzo; nothing built, DESIGN.md untouched.
- 2026-10-14 · `claude/friendly-hawking-74891i`: H15 built after Danzo picked "recommended": `shared/Ghost` (+ `Tag.hold`, `Tag.tick` back), `server/Ghosts`, `server/Bots` (dummies out of Match, N of them, ghosts too), remotes `GhostClaim`/`GhostVerdict`, MatchState ghosts/ward/mark, client claim, pale ghosts, hollow arrows, HUD; DESIGN §3 rules 37-41, §6.1 resolved; `docs/systems/ghosts.md`; learnings S12. 21 mutations caught; tests, lint, build, sourcemap clean; dummy ghosts seen in Studio; player spook waits on a `rojo serve` restart (T6).
- 2026-10-14 · `claude/friendly-hawking-74891i`: routine: H15 verified (npm test 9 Luau files ok, lint clean, rojo build with GhostClaim/GhostVerdict). `docs/learnings.md` passed 300 lines → split into `docs/learnings/` (one file per section, the old path is the hub, G3). Two-player ghost test next.
- 2026-10-19 · `claude/friendly-hawking-74891i`: Danzo play-tested the snapshot tag ("speed is great") and the two-player ghosts ("good too"). His four-player worry and the ghosts-v2 direction (no comeback, rare drain, placeable traps/boosts, maps) written into `ideas/INBOX.md` under Ideas. Nothing built; waits on his decision before an H16 design pass.
- 2026-10-19 · `claude/friendly-hawking-74891i`: H16 + H17 design passes (heavy): `docs/systems/ghosts-v2-proposal.md` (recommended "orbs for everyone": no comeback, one orb system with runner/holder/ghost pools, rare -5 s hex, holds that never chain, dash i-frames for aimed things only, tetromino fixtures with a keep-clear map rule, 4 map feels, draft §3 rules 37-49 and a §6.2 answer; 3 ranked alternatives) and `docs/systems/controls.md` (researched layout: WASD+Space/Shift/W/E and arrows+ZXCV live together, pad A/X/RT/RB, 4 touch buttons; sources cited). DESIGN.md and Lua untouched; both entries OPEN waiting on Danzo.
- 2026-10-19 · `claude/friendly-hawking-74891i`: H16 + H17 RESOLVED on Danzo's answers (heavy): DESIGN §1/§2 ("the next round is their way back", orbs), §3 rules 37-51 (ghosts v2: no comeback, ghost orbs, hex -3 s, living orbs and pools, holds with a 1 s trap, dash over traps not through crates, boost grant, placement and keep-clear map rule, vanilla toggle, ignition, end-phase speed), §6.2 resolved, §6.8 maps. `ghosts-v2-proposal.md` is the spec with a 6-PR build order (§12); `controls.md` the provisional layout; ghosts.md marked superseded; README, INDEX updated. No Lua, no build.
- 2026-10-19 · `claude/friendly-hawking-74891i`: routine: H16/H17 answers relayed to the heavy agent and recorded; INBOX "Where we are" and "Next" updated to ghosts v2 and the PR order. Next word from Danzo: commit, then build PR 1.
- 2026-10-19 · `claude/friendly-hawking-74891i`: H18 built (heavy), ghosts v2 PR 1: no comeback (`Tag.tick`'s `back`, the mark, `SPOOK_COOLDOWN`, `GHOST_COMEBACKS` gone, their tests retired with the rules), new pure `shared/Orbs` (spots, respawn 10/(1+0.5n), one slot, swept touch, injected roll) + `server/Orbs` + `client/Items`, `shared/Ghost` rewritten for the hex (held hex, -3 s, shared 6 s ward), remote `ItemEvent`, 3 ghost-orb spots, dummies run to orbs then hex. Tests + lint + rojo build ok, sourcemap only gained; 20/21 mutations caught (1 equivalent). Studio solo Play: server path seen (orbs taken, hexes, no comeback); client side waits on a `rojo serve` restart (T6). Not committed; QA goals `docs/qa/ghosts-v2-core.md`. New rule N14.
- 2026-10-19 · `claude/friendly-hawking-74891i`: QA round 1 on `docs/qa/ghosts-v2-core.md`: 7/10 (Opus; its Play was denied). Builder Play via the MCP with ItemEvent present: orbs, hex, pop, ward all seen, no errors. Fixes: STUDIO_DUMMIES 3, slot readout, held items clear on round over. Hex rarity deferred to PR 2 by spec.
- 2026-10-19 · `claude/friendly-hawking-74891i`: QA round 2 on ghosts v2 core: 7/10. Reviewer Played for real. Slip: round 1 commit staged by path list and missed test/ (→ G4, new). Fixed + committed; ghost orbs half-bright for the living; clean-export Luau run all ok. Teleport-pickup question answered from trust.md (45-stud tolerance, same as a tag).
- 2026-10-19 · `claude/friendly-hawking-74891i`: QA round 3 on ghosts v2 core: 8/10, target met, loop closed. Summary `docs/qa/ghosts-v2-core-summary.md`, rounds archived, H18 RESOLVED. Open for Danzo: the hex cadence on the hex-only pool (a/b/c in INBOX) and the Play checklist.
- 2026-10-19 · `claude/friendly-hawking-74891i`: H19 built (heavy, not committed): ghosts v2 PR 2, living orbs and pools (`shared/Items`), Use (`UseItem`), holds (crate stumble, bear trap, ice freeze) with no chains, i-frames, per-target ward; server holds the speed check to each hold (→ N15, new). QA goals `docs/qa/ghosts-v2-items.md`; detail `docs/systems/items.md`. Tests/lint/build green, mutation 40/41. Studio: `UseItem` missing until `rojo serve` restarts (→ T6).
- 2026-10-19 · `claude/friendly-hawking-74891i`: H19 QA round 1 fixes (heavy, not committed): pry presses never gap-dropped during a trap and the client stays pinned until the server frees it; a hold now drops the x budget to speed x HOLD_GRACE + slack for its whole length and a freeze refills from the server-measured speed (ignoring a freeze from a run caught 0.76 s in). N15 rewritten (its first version was wrong). Trap line says "tap" on touch. Tests/lint/build green, mutation 47/50 (3 equivalent).
- 2026-10-19 · `claude/friendly-hawking-74891i`: H19 QA round 2 CONSIDERs (heavy, not committed): full burst back when a hold ends (a dash-jump out of a trap had 0.49 studs to spare, now 22.6); a trapped runner in the air drops instead of hanging (and its fall is legal); `Config.STUDIO_DUMMY_TAGS` for solo item tests. Tests/lint/build green, mutation 51/54 (3 equivalent).
- 2026-10-19 · `claude/friendly-hawking-74891i`: QA loop for PR 2 (ghosts v2 items) closed at 7 → 8/10. Summary `docs/qa/ghosts-v2-items-summary.md`, rounds archived, H19 RESOLVED. Waiting on Danzo's Play (pry by hand, own-trap feel). Next: PR 3 controls.
