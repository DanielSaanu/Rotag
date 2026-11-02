# QA round 1: the moving walls — SCORE 8/10

Reviewer: Opus subagent, 2026-11-02, with Studio (five rounds, 3 dummies, the runner driven with `Humanoid:Move`, the `Edge` parts sampled every render frame). Report verbatim:

SCORE: 8/10

**What I ran.** I set `END_PHASE_AFTER = 15` and `STUDIO_DUMMY_TAGS = false` in Config, then played five rounds in Play with 3 dummies. I drove my runner with `Humanoid:Move` inside one `execute_luau` per sequence, and read the walls by sampling the `Edge` parts every render frame at 240 fps. Afterwards I restored Config: `git checkout`, `git diff roblox/src/shared/Config.lua` is empty, and it reads 120 / true again. Play is stopped. `npm test`: node 13 pass, 0 fail; 15 Luau suites ok. `walls.test.luau` prints "sways 24.3 studs end to end, fastest 7.82 studs/s" and "a still runner at the edge flips 7 times in 60 s". `npm run lint:luau`: every file ok.

**Studio, seen.** The server log shows five end phases. For example: `walls: closing in: centre 4.9, half-width 72.9 -> 24 over 20s, in x -80..120, seed 3704.580`. Each round has a different seed (3818.087, 3925.095, 4040.277, 4153.441). Over about 8 minutes of walls the whole log has only 2 out/in lines, and both are mine: `8061215879 is outside the walls` at 521.5, then `is back inside` at 522.9. No dummy flapped.

GOALS:
- 1 Target: met. Code: `shared/Walls.lua` `target`/`step` (mean + `WALL_LEAN`·(holder−mean) + drift, `within`-clamped, eased and capped). In Play the closed box tracked the living. In a duel with the "it" dummy standing next to me at x −17, the centre stayed around −29..−8 (about ±11 around us).
- 2 Wander: met. Round 2's closed box moved its left wall 22→44→23 and back over 20 s, never the same way twice. Each round had a new seed. Code: `drift` multiplies by `p`, so it is zero at the open, and the first 1–2 s of the open looked like H24.
- 3 Lean: partial. The tests pin it (walls.test.luau:250–262, including a twin duel). I did not see it in Play: my only "it" round was spent running out of the box.
- 4 Bounds: met. Round 1 pinned the box at the left end while I stood at −60: the lowest left-wall position over 6002 frames was −79.8 (bound −80), and the half-width held at 24.0.
- 5 Fair: met in what I measured. The fastest wall over half-second samples was about 8.2 studs/s (L −60.2→−64.3), well under half a run (22.5). Standing still beside the duel partner, the nearest wall came within 12 studs and never walled me out. I did not reproduce "a still runner far from the pack gets pushed out by the sway": the dummies chase, so I could never get far from them.
- 6 Server decides: met. `holderX` reads only the trusted record and the seed is the server clock (`server/Walls.lua`, `Rules.open(...)` with no seed). The twin test (walls.test.luau:69–75) asserts `w2.x == twin.x and w2.vx == twin.vx`. No remote added.
- 7 Wire: met. `rows` keeps `{x, hw, vx, vhw}`. `client/Walls` is unchanged and extrapolates (client/Walls.lua:94–95). `vx = 0` when there is no mean (shared/Walls.lua step's else-branch). The resend runs while `|vx| > 0.05`.
- 8 H24 preserved: met. The label went `GET BACK IN 3.0` once my centre was 1.46 studs past the wall (my whole body out), counted down 2.8, 2.4, 2.0, and cleared once I was 2.24 studs back inside. It changed exactly twice (on, off) with no flicker. Deaths still go through `Tag.eliminate`; the edges and the open are unchanged.
- 9 Cheap: met. The server adds one `holderX` lookup and two sines per frame; the client adds nothing.
- 10 Verification: met (output above). Sourcemap not re-checked: no module was added (confirmed by `git show --stat`).

PRESERVE (done well, must survive future iterations):
- The hysteresis (`Walls.outside(..., was)`, `WALL_BACK_IN` 2) and the 0.2 s cap on at-once sends (`CHANGE_GAP`): 0 flap lines over 5 rounds in Play, and the label never flickered.
- The bounds come from one clamp, `Walls.within`, used by both open and target. The eased centre therefore stays inside on its own, because each step moves between two clamped points and the allowed range only widens as the box closes.
- The trust argument is pinned against a twin with the same seed, not argued in prose. The wander is a pure function of the server's clock.
- Dummies are kept `BOT_INSET` inside by `Walls.room` (server/Bots.lua:76–82). Without it, Studio testing turns into log spam. Ghost dummies still roam freely, which is correct: they are not living.
- The fade-in (`p` in `drift`) keeps the open reading as "the screen is closing".

FIX (done poorly; why it matters; concretely how to fix):
- The walls step visibly when each MatchState arrives. The largest per-frame jump was 0.290 studs: 67.5 studs/s in a single frame, against about 0.033 studs a frame at the 8 studs/s cap. The goals expected under a quarter of a stud. At about 22 px per stud on a 1080p screen, that is a roughly 6 px hop of a neon line, about 4 times a second. It comes from the wander's acceleration: ½·a·t² with a ≈ 7 studs/s² and t = 0.25 s gives about 0.23. → In `client/Walls.update`, draw the edges from a smoothed x/hw (e.g. close the gap to the extrapolated value at about 15/s instead of snapping). Alternatively, send the drift's acceleration and extrapolate quadratically. Then ask Danzo whether he still sees the step.
- `docs/systems/endgame.md` is 304 lines, past CLAUDE.md's ~300 ceiling (→ G3). → Split §7 (the walls) into its own file now, before the next PR grows it.

CONSIDER (fine but could change; why; how):
- An untrusted holder sample drops the lean entirely (`holderX` returns nil) and also removes the holder from the mean. In a duel the target then jumps to the runner alone, about 20 studs away. Easing hides the jump, but a laggy, legitimately flagged holder makes the box lurch toward the runner every time a sample is flagged. It is not exploitable: cheating only moves the box against the cheater. → Use each runner's last trusted sample, not just the newest one, for both the mean and `holderX`.
- The client's local prediction (client/Walls.lua, `predicted`) has no hysteresis. A runner standing exactly on a swaying line could see the label blink during the ping window before the server's own hysteresis takes over. I did not see it at 0 ping. → Apply `WALL_BACK_IN` to the prediction while the label is showing.
- `Walls.room` clamps a dummy holder's chase inside the box, so a dummy "it" will not follow a runner who steps out. That is Studio-only and harmless, but worth a comment.
- Solo rounds with `STUDIO_DUMMY_TAGS = false` lasted about 95 s with about 60 s of closed box. That is enough to test with; no change needed.

UNCERTAIN (could not verify):
- Feel, Danzo's question: does the sway read as "keep moving" or as random? Does the lean feel like "it"'s weapon? Is lapping harder? He has to try these by hand on keyboard and phone (goal steps 2, 4, 5).
- A still runner far from the pack being pushed out by the sway alone, with the full 3 s grace. The dummies always chased me, so I could only test a deliberate run out.
- The lean while I was "it", seen live.
- Behaviour with real ping and 4 real clients (the prediction blink, the resend load).

## Builder decisions

- **FIX the hop at each MatchState: fixed.** `client/Walls` draws the edges from a smoothed window that closes the gap
  to the extrapolated one at `SMOOTH` 15/s (snaps on first sight). Measured in Studio after the fix: see below.
- **FIX endgame.md over the ceiling: fixed.** §7 (the closing walls and the moving window) is now
  `docs/systems/walls.md` with the same §7.x numbers; endgame.md keeps a §7 stub so every "endgame.md §7.x" citation
  still resolves (G3). INDEX.md lists both.
- **CONSIDER the prediction's hysteresis: fixed** (cheap, client-only): the local GET BACK IN prediction uses the same
  `WALL_BACK_IN` band as the server.
- **CONSIDER the dummy holder's clamped chase: a comment added** in `server/Bots.lua`.
- **CONSIDER the last trusted sample for the mean and the lean: deferred.** It changes what `shared/Walls` reads
  (trigger 2) for a case that is not exploitable and that the easing hides; noted in walls.md §7.8 for the next walls
  handoff.
- Target met (8/10): the loop ends here. Summary: `docs/qa/ghosts-v2-walls-2-summary.md`.
