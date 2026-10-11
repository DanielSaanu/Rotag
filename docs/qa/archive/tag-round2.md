# QA round 2: the tag — SCORE 8/10

Reviewer: Opus subagent, 2026-10-11, real Studio Play through the MCP (~60 s), `npm test`, `npm run lint:luau`,
`rojo build`. Goals: `docs/qa/tag.md`. State reviewed: commit 97c0285 (H7 on top of round 1's fixes).

## Report (verbatim)

SCORE: 8/10

What I ran: a real Studio Play through the MCP (about 60 s, then stopped; Studio is back in Edit), `npm test` (13 node tests and 5 Luau suites, all ok), `npm run lint:luau` (all ok) and `rojo build` (built). I did not modify any tracked files.

Output from Play, verbatim:
- `round 1: 2 runner(s), 8061215879 is it with 45s`
- `TAG 8061215879 -> -1000, fuse 25.9s (+2.0s)`, then `TAG -1000 -> 8061215879, fuse 26.5s (+2.0s)`
- `TAG 8061215879 -> -1000, fuse 7.8s (+2.0s)` (my third tag, done by holding A), then `TAG -1000 -> 8061215879, fuse 8.5s (+2.0s)`
- `8061215879's fuse ran out, round over, winner -1000`, then `round 2: 2 runner(s), -1000 is it with 45s`
- `TAG -1000 -> 8061215879, fuse 45.0s (+0.4s)`: the dummy tagged my idle runner within seconds of round 2 starting (see FIX).
- `no PlayerModule controls; reading Humanoid.MoveDirection`: printed once, no warning.

Screen captures:
- Capture 1: "Dummy is it 25.9", a fading "+2s -> Dummy", "Dummy is it: run!" and a big "RUN!".
- Capture 2: "YOU'RE IT 11.9" in red at the top centre, with the red neon triangle over my runner (marker at x 68.8, runner at x 68.1, read back on the client).
- Capture 3, round 2: "Dummy is it 45.0", "RUN!", and the triangle over the glowing box.

In every capture the lower middle of the screen was clear. The fuse values above also include tool latency, so the clock looks fast; that is not a bug.

GOALS:
- Server-owned "it" and fuse: met. Only Match.lua changes the round, through Tag.lua. `onClaim` (Match.lua:151-164) reads one integer, rate-limits it, gets the ping, and judges with `Tag.claimWindow` (capped at TAG_REWIND_MAX). A refused claim gets no reply.
- Fuse rules (+2, capped): met. `Tag.pass` returns `(fuse, fuse-left)` (Tag.lua:134-143). Elimination and round 2 with the dummy as it at 45 were both seen in Play. The shrink to 35 and the floor of 15 are tested, not played (rounds have 2 runners).
- No tag-backs and the start wait: met. The fuse waits while frozen (Tag.lua:58). "RUN!" and the count to GO are shown during the freeze (Hud.lua:150-164), seen live.
- Readable: met. The pop now uses `gained`: "+2s" and the capped form both appeared in the log, matching the HUD branches at Hud.lua:133-139. Fuse at the top centre, triangle marker and status line all seen.
- Chaser ramp and hit-stop: met in code. `Tag.chaserBoost`, and HIT_STOP set for `from`/`to` at Tagging.lua:96. Not seen or felt by me.
- Playable solo: partial. Tag, tag back and tag again worked three times, then the round ended and round 2 started. The dash-chain speed (+45% in round 1) is unchanged; it is a known fork waiting on Danzo.
- Pure, tests and tooling: met. tag.test.luau:33-41 pins `gained`, :111-113 pins the leave-after-over case. All tests, lint and rojo build pass.

PRESERVE (done well, must survive future iterations):
- The one-number claim judged against the server's own history (Match.lua:151-164, Tag.touchedBetween): rule 6 done properly, and cheap.
- `gained` as the second return of `Tag.pass`, sent in TagVerdict: the HUD can no longer show a number the fuse did not get, and the change is additive.
- `Tag.leave` returns early once `r.over` (Tag.lua:171), and Match sets `nextRoundAt` on the leave path (Match.lua:259-262): one rule, two callers, consistent.
- The fuse waits during a freeze through one `max(since, frozenUntil)`, and the client predicts it the same way (Tagging.lua:31-35).
- The dummy patrols at x 12..52, away from the spawn: round 1 no longer ping-pongs an idle player. Confirmed: no tag happened until I moved.
- The big "RUN!" / count / "GO!" in the centre: it answers "who is it and can I move" within two seconds.

FIX (done poorly; why it matters; concretely how to fix):
- Round start does not reset positions: round 2 began wherever everyone stood, with the dummy as it about 9 studs from me. It tagged me within seconds (`fuse 45.0s (+0.4s)`), so the new round's first beat was a confusing "+0.4s, capped -> you". With four real players, the new it can start right next to someone, and a 1 s START_FREEZE does not cover that. This is the round-1 ping-pong moved to round 2. -> In `startRound` (Match.lua:78), place every runner at spread spawn points (the it at the far end), or respawn the characters, before `Tag.newRound`. Move the dummy to its patrol start too.
- The "+%ds" format is fragile: Hud.lua:136 formats `Config.FUSE_PASS_BONUS` with `%d`. Danzo is trialling this value; set it to 2.5 and Luau's `string.format` throws ("number has no integer representation") inside the TagVerdict handler, so every pop stops showing. It also contradicts tag.md:34 ("pop from gained, never from Config"). -> Print `("+%gs  ->  %s"):format(gained, who)` in the whole-bonus branch, rounded to one decimal place.
- Dash spam (known, pending Danzo): it still beats a run, so goal 6 stays partial. -> Once he chooses (round 1's options a, b or c), add a test that pins mash speed against run speed.

CONSIDER (fine but could change; why; how):
- Unclear status for a late joiner: a player who joins mid-round sees "out (next round soon)" (Hud.lua:185-186), which reads as if they were eliminated. -> Add `spectating` to the snapshot (an id not in `r.order`) and show "next round soon".
- The cap is invisible to the holder: at 45 s nearly every early pass is "+0.xs, capped", which is honest but noisy, and players do not know the cap exists. -> Show it on the fuse readout (for example "44.6 / 45"), or drop the pop's number when gained < 0.1.
- The rewind allowance (0.5 s, about 22 studs at run speed) is still untested with two clients. -> Measure when a second client exists, as already deferred.
- No off-screen pointer yet: the 72-stud map is already wider than the screen. -> Build it with the second player, per DESIGN §2.

UNCERTAIN (could not verify):
- The 80 ms hit-stop and the chaser ramp, by eye or by feel. Danzo should chase the box for more than 10 s and check whether the boost is noticeable, and check whether being caught (1.5 s freeze, then GO) feels fair rather than stuck.
- The leave-ends-round path in Play: there was no second client. Reasoned from Match.lua:248-265 plus the Luau test only.
- The phone preset: the touch thumbstick still has no PlayerModule (the fallback line printed), and marker and HUD legibility at phone size were not checked. This is still the biggest risk for the phone path.
- The "wins the round" status during ROUND_GAP: not captured. The code is at Hud.lua:171-176.
- Whether the shrink to 35 and the 15 s floor feel right; they need 3 or more runners; covered by tests only.
- Movement feel in general: only hands can judge it.

## Builder decisions

- Score 8.0 reached: the loop stops after this round's fixes (skill rule).
- PRESERVE: all six kept; named in the H8 brief.
- FIX round start positions → H8 (heavy): placing runners at round start touches the match loop and bodies whose
  physics the client owns (`SetNetworkOwner`), so the mechanism needs care. Trigger 3.
- FIX fragile "+%d" pop → done (routine, `client/Hud.lua`): the whole-bonus branch prints from `gained` with `%g`
  after rounding to one decimal, never from Config.
- FIX dash spam: still **Danzo's decision**; unchanged. Recorded as an open FIX in the summary.
- CONSIDER late joiner wording → H8 (the agent is in `Match`'s snapshot anyway; a `spectating` list is additive).
- CONSIDER cap visibility: deferred until Danzo rules keep/revert on the cap itself.
- CONSIDER rewind allowance, off-screen pointer: deferred as in round 1 (second player).
- UNCERTAIN: to Danzo's checklist in the summary.
