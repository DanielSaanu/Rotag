# QA round 2: ghosts v2 core — SCORE 7/10

Reviewer: Opus subagent, 2026-10-19. This time Studio Play worked for the reviewer (solo, 3 dummies, about 100 s).
Report verbatim below, then the builder's decisions.

---

## Ghosts v2 core, QA round 2

**Bottom line:** the build works in Studio, but the committed branch fails its own tests. The rewritten and new tests exist only in the working tree.

**What I ran**
- `npm test` and `npm run lint:luau` pass on the working tree: all Luau suites ok, and the 1.5x cap holds with 1, 2 and 3 ghosts.
- On a clean `git archive HEAD` export, `test/luau/run.js` exits 1: `FAIL - config.test.luau` and `FAIL - ghost.test.luau` (`attempt to call a nil value` in `afterFirstOut`).
- `rojo build` succeeds. Comparing sourcemaps of HEAD~2 and now shows nothing removed: six ModuleScripts added (Shared.Ghost, Shared.Orbs, Server.Bots, Server.Ghosts, Server.Orbs, Client.Items). `ItemEvent` comes from the project file.
- Studio Play, solo, 3 dummies, about 100 s. I stopped Play at the end. Output:
  - My fuse ran out. Client read: the status line "GHOST: out this round | grab a ghost orb" and the readout "ITEM: none". Three orb balls at (-40, 2.5), (42, 22.5) and (104, 2.5), transparency 0.1. Nothing mentioned coming back.
  - I drove my root through orb 1. Server: `orbs: 8061215879 took ghost orb 1: hex`. Client: that orb went to transparency 0.85, a diamond appeared at (-30, 8.5), the readout said "ITEM: HEX", and the status line said "GHOST: HEX held, touch Dummy for -3s | READY".
  - My driven hex was `dropped: no overlap in the window` after MoveGuard snapped my teleport back. That was my test harness; the slot correctly kept the hex.
  - A dummy ghost hexed three times: `HEX -1000 -> -1001, fuse 19.6s`, then `10.6s`, then `1.6s`, then `-1001's fuse ran out, round over, winner -1002`, then `round 2: 4 runner(s)`.
  - No Rotag errors or warnings. The only noise was CoreGui UIBlox warnings and asset 203785492 failing with "Asset type does not match requested type" (not this PR).

SCORE: 7/10

GOALS:
- No comeback: met. The round ended on the third burn-out with no comeback line in Output, and the next started with all four. ghost.test asserts 45+35+25 and is honest about the retired tests (lines 2-6).
- Ghost orbs: met. Server took my pickup from its own record. orbs.test covers nothing before 0:05, 10 / 6.7 / 5 s respawn recomputed with the ghost count, a full slot passing through, kind gating, and the dash path (line 79).
- The hex: met as specified. Drain, slot empty, shared ward, no hex while frozen (`shared/Ghost.lua:43-55`). In Play the fuse lost 9 s every 6 s, exactly the 1.5x cap. Not rare (see CONSIDER), but that is deferred by the spec.
- Server decides: met. Pickups come only from `history` in `server/Orbs.lua:56-72` and skip untrusted samples. The hex is judged on the server's history and the slot (`server/Ghosts.lua:50-63`). `ItemEvent` and `GhostVerdict` ignore anything clients send.
- Readable: mostly met. Orbs, the diamond, the readout and the status line were seen. I did not see the pop or the ghost brightening myself. The ward halo is only in code (`Hud.lua:110,227`).
- Pure, with tests: partial. The code is pure and the working tree is green, but the committed branch fails 2 of 10 Luau suites, and orbs.test.luau is untracked.

PRESERVE (done well, must survive future iterations):
- Orb pickup judged only from the server's own samples, sweeping the path between two of them (`shared/Orbs.lua:59-66`, tested): no claim remote, and a dash cannot skip an orb.
- The 1.5x cap tested as an outcome with endless hexes for 1 to 3 ghosts (`ghost.test.luau:87-107`). Play confirmed the exact cadence.
- Retired tests named with their rules rather than loosened (`ghost.test.luau:2-6`).
- A clear order inside one server frame: tags, then hexes, then orbs, then the fuse (`server/Match.lua:291-298`). A tag beats a killing hex, and a hex taken this frame is usable next frame.
- Random source and clock injected into `Orbs.roll` and `Orbs.step`. The roll test sweeps evenly, and its edge case `rand() == 1` is handled.

FIX (done poorly; why it matters; concretely how to fix):
- **Tests not committed:** HEAD fails `npm test` (config and ghost suites), and `test/luau/orbs.test.luau` is untracked. Anyone who pulls or checks out this branch gets red tests and no orb tests, which breaks CLAUDE.md verification step 3 and goal 6. -> Commit `test/luau/config.test.luau`, `test/luau/ghost.test.luau`, the new `test/luau/orbs.test.luau` and the `INDEX.md` change. Then re-run `npm test` on a clean checkout.

CONSIDER (fine but could change; why; how):
- **Hex cadence on the test arena:**
  - Why: one dummy ghost alone kept the holder at the full 1.5x burn for about 18 s, hexing every ward window. That is the "stream" Danzo's feel check 4 says should not happen. The cap makes it safe to merge, but on this small arena every ghost will hex as often as the ward allows.
  - How: accept the PR 2 deferral, but put it in the INBOX as a known feel issue. If it bothers Danzo before PR 2, a Studio-only Config knob (e.g. a longer ghost-orb respawn for a solo test) is cheap and needs no rule change.
- **Living players see bright ghost orbs they cannot take:**
  - Why: they read as pickups, which is a rule 12 readability risk. In round 2, alive, all three orbs were drawn at transparency 0.1.
  - How: draw ghost orbs dimmer, or with a ghost-only shimmer, on a living player's screen. Full brightness only for ghosts.
- **The pickup during my harness teleport passed MoveGuard:**
  - Why: my first move ran at about 180 studs/s, yet the pickup counted. Only the second leg was flagged ("over the x speed limit by 0.5 studs").
  - How: confirm that MoveGuard's allowance is per sample, and that a sustained fast glide cannot collect orbs across the map. A test via `MoveCheck` would pin it.
- **Slot readout at fixed top-left, TextSize 18 (`Items.lua` start):**
  - Why: on a phone the Roblox top bar and chat button sit nearby.
  - How: check it with the phone preset. Consider `IgnoreGuiInset` false plus a y offset, or anchoring next to the fuse.

UNCERTAIN (could not verify):
- Ghost brightening with a held hex, the pale-blue ward halo, and the "-3s HEX" pop on my own screen. I read the code but saw no frame: screen_capture is edit-time only, and a dummy's hex landed on another dummy.
- A real player's hex end to end. My scripted approach was snapped back by MoveGuard, and the movement state cannot be driven from the MCP. The builder's round-1 run reported it working.
- Phone preset legibility of the readout and the over-head diamond. Movement feel as a ghost needs Danzo's hands, keyboard then phone: run through an orb at dash speed, then chase and touch the holder.
- Two real clients, a ghost leaving while holding a hex, and lag effects: read in code (`Orbs.forget`, `Ghosts.forget`), not run.

---

## Builder decisions

**FIX, tests not committed → done, and it was the builder's slip.** The round 1 commit staged `docs ideas roblox` by
path and left `test/` and `INDEX.md` behind. Committed in this round; `npm test` re-run on a clean `git archive`
export. New rule G4 in `docs/learnings/git.md`: stage from `git status`, never from a path list.

**PRESERVE:** all five kept, untouched.

**CONSIDER, living players see bright ghost orbs → done.** On a living player's screen an up ghost orb is drawn at
half brightness (transparency 0.55); full brightness (0.1) only for ghosts; waiting orbs 0.85 for all. The
brightness is set in `Items.draw` every frame from the local runner's ghost state, so it changes the moment the
player burns out.

**CONSIDER, hex cadence → already in INBOX from round 1 (deferred to PR 2 by spec); the reviewer's observation (one
dummy alone holds the 1.5x burn for 18 s on this arena) added to that line.**

**CONSIDER, pickup during a harness teleport → explained, no change.** The first leg passed because the speed check
tolerates one jump under about 45 studs (H12, `docs/systems/trust.md`: "teleports under ~45 studs still pass"), and
the orb slab test ran on that trusted sample. A sustained glide is flagged from the second sample on, and untrusted
samples never collect (`server/Orbs.lua`, skip on untrusted). So the worst a cheat gets is one orb within 45 studs,
the same tolerance a tag already has. Pinning that with a `MoveCheck` test belongs to PR 2, which changes the budget.

**CONSIDER, slot readout on a phone → Danzo's checklist.** It needs his eyes on the phone preset; moved to the
final checklist, not changed blind.
