# QA round 3: the grapple — SCORE 8/10

Reviewer: Opus subagent, 2026-11-02, with Studio (one Play, root, rope and halo logged every Heartbeat, keys driven in batched calls). Report verbatim:

SCORE: 8/10

**What I ran**
- `npm test`: all pass, including the new stand-under-every-anchor test. The five swing chains are unflagged: worst x 1.38 of 24, up 2.96 of 10.5, down 2.21 of 16.
- `npm run lint:luau`: clean.
- `rojo build`: ok.
- One Studio Play. I logged root position and velocity, the rope and the halo every Heartbeat, and drove the keys in single batched calls. Play is stopped. I modified no tracked files (`ideas/INBOX.md` was already modified, not by me).
- Output: no `move:` lines, no errors. The only noise is the known `ContentId: rbxassetid://203785492 failed`.

**What I saw in Studio**
- **Floor hook at spawn.** Spawned at (-60, 1.8) and the halo was on anchor 1 (-56, 20) from frame 0. I stepped right to x -54 and held W. It hooked at once (rope on, halo off) and reeled to y 2.8. Off-beat A/D pumping built the swing to vx 59 in about 2 s. Release took the rope; the halo came back at once.
- **Behind-skip.** Sprinting right at 52, the halo sat on anchor 2 (-8, 22) from x -22 to -11.5, then cleared before I passed under it.
- **Halo blink at threshold.** Walking past anchor 1, the halo vanished for one frame at vx 41 (10.66 s) and came back at vx 31. That is the behind-skip crossing 0.8 x run.
- **Floor hook from the side, and a dash off the rope (the first time any round has seen it).** Under anchor 4 (60, 22), standing 11 studs off at x 71.1, I held W. The rope came on and the swing was smooth: vx -45 at the bottom, lowest y 2.8, no yank.
  - Holding A, I pressed Shift mid-swing at vx -15. The log jumped to v(-120, 0) at once and the rope was gone.
  - The dash ran into a dummy at x 47.8, and Output shows `tag: claim 8061215879 -> -1000 received ... TAG 8061215879 -> -1000`. So "dash redirects it" works live and still feeds the tag.
- **Anchors under bloom.** Capture `QA_r3_play` (1656x606): each anchor is a bright yellow ball with a thin dark olive rim. They are clearly unlike the orbs (pale blue rings), the platforms and the runners. The disc reads as a rim, not a disc, but the anchor is unmistakable.
  - Anchor 3 (32, 30) is half cut off at the screen top while standing on the floor. It is not picked, as designed.
  - No halo was shown at x 16.8, which is correct: anchor 2 is about 32 away, past the 28 range.

GOALS:
- Marked anchors: met. Six tagged, Persistent, CanQuery off (Arena.lua:117-139). The capture shows a distinct gold ball and rim.
- Aim assist, readable: met. The halo is live from spawn, the behind-skip works, the halo is off while hanging. One-frame blink at the speed threshold (log 10.66 s).
- Hold to hang, easy to start: met. Floor hooks under anchor 1 and 11 studs off anchor 4 both worked first try; the reel holds y 2.8.
- A rope that swings true: met. The pendulum was clean in the logs: 45 at the bottom from a side hook, turnarounds at the expected heights. Leapfrog tests pass.
- Release keeps the swing: met. The dash off the rope gave -120 in the steered direction (new this round). The 1.1 boost was seen in round 2.
- Refresh on the hook: met in code (Movement.lua refresh behind `GRAPPLE_REFRESH`). Not re-driven.
- Ghosts never grapple: met in code (client/Grapple.lua:95-98). Not re-driven this round; round 1 saw it live.
- The server is never fooled: met. No remote, `RATE_X` unchanged, chains unflagged, no `move:` line during the swing, the side hook or the 120 dash.
- Every screen sees the rope: partial. Only my own rope seen; dummies don't stream.
- The touch button: met (code only).
- Cheap every frame: met. The filter is cached on a character change (client/Grapple.lua:101-104).
- Verification: met. Tests, lint and build pass. The new test fails on the old anchors per the builder's notes.

PRESERVE (done well, must survive future iterations):
- **The real-framing anchor test** (test/luau/grapple.test.luau:67-88, run.js lifting `ArenaData`). The map's anchors are now checked against `CAMERA_Y_OFFSET` and `CAMERA_VIEW_HEIGHT`, so a map edit or a camera tweak cannot silently hide a ball again. PR 6's per-map anchors should run through the same test.
- **The floor cap plus the reel to `GRAPPLE_LIFT`.** Live, every hook this round settled 1 stud above the floor and swung without scraping.
- **Dash off the rope = a plain 120 dash.** It redirects instantly, needs no new trust and still lands tags.
- **No new remote and no allowance, with `RATE_X` = 120.** It held for every move tried this round.
- **Round 1 and 2 PRESERVE items still hold:** leapfrog, the armed hook, the motion behind-skip, the halo off while hanging, ghost gating in `Grapple.frame`.

FIX (done poorly; why it matters; concretely how to fix):
- **`FLOOR_TRIES` can be spent in one burst** (client/Grapple.lua:61-65).
  - Why: `floorTries` is a shared counter, and `rebuild` also runs on every `GetInstanceAddedSignal`. If the six anchors stream in after `Grapple.start`, six rebuilds in the same frame can schedule all five retries at about t+1 s. If the floor arrives later than that, the scrape from round 1 returns. This is low odds on this small map, but it is the exact case the fix was for.
  - How: debounce. Keep one pending flag, so only one `task.delay` is ever in flight and each retry is a second after the last. Or listen to `workspace.Map.ChildAdded` and re-run until every floor is found.
- **The floor ray does not exclude runners or placed pieces** (client/Grapple.lua:46-49).
  - Why: if a retry fires while a runner, a dummy or a ghost piece is under an anchor, `floor` becomes that object's top. The rope is then capped short (a "short" hook) for the whole Play. Anchor 2 is 8 studs from the spawn.
  - How: cast the floor ray with an include filter on `workspace.Map`'s blocks only. The map is static and the anchors live inside it.

CONSIDER (fine but could change; why; how):
- **Halo blink at the behind-skip threshold.** At about 36 studs/s the pick toggles frame to frame while passing a ball. That reads as flicker, against rule 17's "always tell which anchor". → Add hysteresis: skip above 0.8 x run, un-skip below 0.7 x run.
- **The disc reads as a rim under bloom.** It is acceptable now, and the art block can choose. → Leave it, or shrink the ball's neon so more disc shows.
- **Leavers' rope parts** are still hidden, not destroyed. This is harmless and stays deferred.

UNCERTAIN (could not verify):
- Other runners' ropes over the stream; this needs two clients.
- The phone GRAPPLE button: lit and dim states, and holding it while pressing JUMP.
- The ghost path this round (round 1 saw it). The refresh on hook, driven live.
- The 20 mutations; I did not re-run them.
- Feel, for Danzo's hands: whether a dash out of a slow point of the swing (I dashed at vx -15) feels like a launch or a reset; the pump strength (`GRAPPLE_PUMP` 60); whether the side hook from about 11 studs feels like a pull or a snap; the 1.1 release boost; whether the 120 cap feels like a wall.

## Builder decisions

- **FIX the retry burst: fixed.** One floor retry in flight at most (`floorRetryPending`); each is a second after the
  last, five at most.
- **FIX the floor ray's filter: fixed.** The ray includes only `Workspace.Map` (the static blocks; the anchors inside it
  have CanQuery off). No Map yet: no floor, and the retry looks again.
- **CONSIDER the halo blink: fixed** (cheap, and rule 17 says the pick must always be readable). Hysteresis on the
  behind-skip: the anchor picked last frame is kept up to `GRAPPLE_BEHIND_FAST` (0.8 x run); one not picked returns
  only under `GRAPPLE_BEHIND_SLOW` (0.7 x run). Tested at the midpoint both ways.
- **CONSIDER the disc as a rim under bloom: left** for the art block (the anchor is unmistakable as it is).
- **CONSIDER leavers' rope parts: deferred** (hidden, a few parts at most), as in rounds 1 and 2.
- Target met (8/10): the loop ends here. Summary: `docs/qa/grapple-summary.md`.
