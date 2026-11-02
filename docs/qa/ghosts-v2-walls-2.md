# QA goals: the moving walls (H26, the closing walls loosely follow the runners)

Branch: `claude/friendly-hawking-74891i`. Handoff H26 (the build), after PR 5b (H24, the closing walls, QA'd 8/10 and
signed off by Danzo 2026-11-01). Design: `docs/DESIGN.md` §3 rules 3 and 51 (the map shrink, now "loosely following
the living"), §6.8 (maps carry window bounds); §2 unchanged. System doc: `docs/systems/endgame.md` §7.7 (the options
weighed, the rule, the numbers, the fairness and trust argument), §7.2's translation table row. The walls' first loop:
`docs/qa/ghosts-v2-walls-summary.md` (its PRESERVE list must still hold).

The question for this loop, Danzo's: **does the moving box force the chase without ever feeling like it killed you by
itself?** In practice: once the walls have closed, does the box keep moving (loosely after the living, a little toward
"it", swaying irregularly) so the chased runner cannot settle and run laps in a still arena; is the motion smooth on
every screen, never faster than a slow walk next to a run, and never past the map's end walls; and does a runner who
stays in play (with the others) never get walled out by the sway alone? Solo in Studio the other runners are
server-driven boxes (`Config.STUDIO_DUMMIES = 3`).

## Goals

1. **The target (endgame.md §7.7).** The centre eases (`WALL_EASE` 0.5/s, capped at `WALL_FOLLOW` 8 studs/s) toward
   the living mean, `WALL_LEAN` (0.25) of the way toward the holder, plus the wander, inside `Arena.WINDOW`. Nothing
   else steers it.
2. **The wander.** Two sines (8 s and 12.9 s), reach `WALL_DRIFT` (20) in the target, phases from a seed (the server's
   clock at the open: each round a new path). Zero when the walls appear, full once closed, so the opening sweep still
   reads as "the screen is closing". Measured: a closed box over a still duel sways ~24 studs end to end, fastest
   7.8 studs/s.
3. **The lean.** On the holder's own trusted sample only; a pass moves it to the new holder (eased, never a jump). In a
   duel 40 studs apart the box sits 5 studs toward "it": the chased runner has 38 studs of room from "it", not 48.
4. **The map's bounds.** No wall ever past `Arena.WINDOW` (x -80..120, the end walls' inner faces). A pack at one end
   gets a box shifted inward with everyone still inside; a box wider than the map sits on its middle.
5. **Fair.** A wall never comes at a runner faster than half a run (cap + close rate). Runners who stay together are
   never walled out by the wander (`WALL_DRIFT` < `WALL_MIN_HW`); a runner who stands still away from the pack is
   pushed out eventually (the intended pressure), with H24's full 3 s grace.
6. **The server decides (rule 6, trigger 3; trust.md §4-5).** The wander is the server's clock; the lean reads a
   trusted sample; an untrusted sample changes nothing, to the last bit (pinned against a twin). No new remote.
7. **The wire.** `MatchState.window` keeps `{ x, hw, vx, vhw }`; `client/Walls` unchanged. The 4-a-second resend now
   runs for the whole end phase (the box never settles). `vx` is 0 when there is nothing to follow.
8. **H24 preserved.** The grace, its pauses (tag freeze, item holds), the death order, `Tag.eliminate` as the one path,
   the neon edges, the open at the screen's edges, `GET BACK IN`, PR 5's list. **Changed on purpose (H26 follow-up,
   endgame.md §7.4):** back inside now means the whole body back in (`WALL_BACK_IN` hysteresis), so a runner at a
   swaying wall never flaps; out/in sends at most 5 a second, a death at once; dummies keep 4 studs inside.
9. **Cheap every frame (trigger 6).** Server: one more pass for the holder's sample, two sines. Client: nothing new.
10. **Verification.** `npm test` (13 node, 15 Luau suites; `walls.test.luau` +4 blocks, two H24 checks re-pinned
    against a twin; mutation-checked 16 mutants, 15 caught, the survivor equivalent for the property),
    `npm run lint:luau` clean. No module added or moved: the sourcemap is unchanged.

## Seen by the builder

**Nothing in Studio**: the main tree was busy with another QA reviewer, so this was built and tested in a worktree
without the Studio MCP. Seen: the Luau tests' output (the sway and speed above), the lint, the mutation run.
**The reviewer must look in Play first:** the walls' motion once closed (smooth or stepping at each MatchState, ~4 a
second, expected under a quarter of a stud), the Studio line `walls: closing in: centre .., half-width .. -> 24 over
20s, in x -80..120, seed ..`, and a wall never past the end walls.

## Out of scope

Per-map bounds beyond the test map (PR 6); a vertical shrink; sounds; wall art; a camera zoom.

## Calls for Danzo (made by the builder while he was away; recorded in endgame.md §7.7; say if any feels wrong)

- **(a) a wander + (b) a lean toward "it"**, both on the living mean. Not a patrol (it ignores the players), not a lean
  toward the runners (it frees the escaper, the opposite of "run from the chaser"). Your words "it always follows the
  runner" read as "the runners" (everyone living); if you meant the chased runner, set `WALL_LEAN` negative (-0.25).
- **`WALL_LEAN` 0.25**: a quarter-lean, not a follow (§7.2's "following the holder kills the best escaper").
  Fallback: 0 (the plain mean, wander only) if the box feels like "it"'s weapon.
- **`WALL_DRIFT` 20, period 8 s**: a sway about half the closed box. Fallback 12 if it feels random or cheap; 23 is
  the most the "the pack is never walled out" rule allows.
- **The wander fades in with the close** (none at the start). Fallback: full from the start if the close feels static.
- **The bounds are the test map's end walls** (`Arena.WINDOW`); every new map brings its own pair.

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard)

Set `Config.END_PHASE_AFTER = 15` and `Config.STUDIO_DUMMY_TAGS = false` to reach the walls fast; put both back (120,
`true`) before committing.

1. At 0:15 the walls sweep in from the screen's edges as before: the first seconds should look like H24 (no sway yet).
2. After ~20 s the box is closed (12 tiles). **Stand still in the middle of it for 20 s.** The box should drift side to
   side, never the same way twice, and at some point one wall should come at you slowly enough to walk away from.
   Does it read as "the screen is moving, keep going" or as random?
3. **Stand still near one wall.** You should get pushed out within a few seconds of the sway turning toward you
   (`GET BACK IN 3.0`); one full step in (the whole body past the wall) fixes it, and the label must not flicker. Does it ever feel like the wall killed you with no warning?
4. **Run laps inside the box.** Is lapping harder than in H24 (the far wall is not where you left it)?
5. **When you are "it", chase a dummy.** The box should sit a little toward you: the dummy's escape room shrinks. When a
   dummy is "it" (`STUDIO_DUMMY_TAGS = true`), the box leans its way and you feel the far wall at your back.
6. **Run to the far left end wall during the close.** The box should stop at the end wall, never past it.
7. Watch the walls' edges while you stand still: smooth glide, or a tiny step 4 times a second? (Expected tiny.)
