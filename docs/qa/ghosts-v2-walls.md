# QA goals: ghosts v2 PR 5b, the closing walls (SpeedRunners' shrinking screen, blended with PR 5)

Branch: `claude/friendly-hawking-74891i`. Handoff H24 (the build), after PR 5 (H23, the ignition and the end phase,
QA'd 8/10). Design: `docs/DESIGN.md` §3 rules 3 (force an ending: "shrink the map") and 51 (the end phase, now with
the map shrink as built), §4's SpeedRunners row, §6.8; §2 (each player's own camera, off-screen arrows) unchanged.
System doc: `docs/systems/endgame.md` §7 (the research, the translation table, the rules, the numbers, what was seen).
PR 5's summary: `docs/qa/ghosts-v2-endgame-summary.md` (its PRESERVE list must still hold).

The question for this loop, Danzo's: **is this a harmonious blend of the best elements of SpeedRunners and PR 5's best
elements and core idea?** In practice: when the end phase starts, do two red walls appear just outside the living and
close in where everyone can see them; does a runner past a wall get a short, readable grace to get back (never an
instant kill, never a solid wall), and die like a burn-out if it does not; is every one of those decisions the
server's, on its own record; and does PR 5 (the ignition, the burn-out, the end-phase line and speed) still read as
the same moment rather than a second system bolted on? Solo in Studio the other runners are server-driven boxes
(`Config.STUDIO_DUMMIES = 3`); they walk back in when outside.

## Goals

1. **The walls open with the end phase (rules 3, 51).** On `Tag.endPhase`'s first true frame (the final two of a 3+
   round, or 120 s): centred on the living mean, each `WALL_START_PAD` (8) past the farthest living runner, never
   nearer than `WALL_START_MIN` (44, half a 16:9 screen); nobody starts outside. Studio logs `walls: closing in`.
2. **They close and drift (endgame.md §7.4-7.5).** Linear to `WALL_MIN_HW` (24, a 48-stud box) over 20 s, then held;
   the centre eases toward the living mean (0.5/s) and never moves faster than 8 studs/s; a pack swaying in place
   barely moves them (pinned: under 10 studs end to end for a +-13 sway). A wall never comes at a runner faster than
   half a run.
3. **The grace, not an instant kill (Danzo).** Whole body past a wall: 3 s, counting down; back in: cleared at once;
   out again: a full 3 s. At 0 the runner is eliminated through `Tag.eliminate`, exactly like a burn-out. Paused (not
   reset) during the tag freeze and any item hold. Ghosts are never judged; a leave is not a wall kill.
4. **Not solid.** The wall parts have `CanCollide`, `CanQuery` and `CanTouch` off (T11: a queried part is a wall to the
   runner's probes). Nothing stops a runner or a ghost crossing either way.
5. **Who dies first.** Two graces out on one frame: the one further past 0, then the holder, then join order; the round
   can end part-way and the last living runner is never eliminated with it. The holder's death gives the next runner in
   rotation a fresh, shorter fuse and the tag freeze; a non-holder's death leaves the holder and its fuse alone.
6. **The server decides (rule 6, trigger 3; trust.md §4-5).** `server/Walls` judges the newest sample of Match's own
   history; an untrusted sample changes nothing either way (a teleport back in never resets a grace). `MatchState`
   carries `window` `{ x, hw, vx, vhw }` and `outside` `{ { id, left } }` (arrays, string keys, → N13), sent at once on
   an out or a back-in and 4 a second while the walls move. No new remote; nothing new trusted from a client.
7. **Readable on every screen (rule 2, PRINCIPLES readability).** A neon red edge at each wall beating 1 -> 4 times a
   second as it closes (SpeedRunners' tempo); a red see-through band past it in front of the map; a red glow on the
   screen edge an off-screen wall is coming from; for your own runner outside, `GET BACK IN  2.1` with an arrow home,
   beating faster and hotter as it runs out (shown at once from your own position, the server's count once it lands).
   The end-phase line reads `FINAL TWO: the walls close in  |  +10% speed` (or `OVERTIME: ...`).
8. **The kill reads.** A wall kill bursts red where that runner is drawn (a burn-out stays orange); Studio prints
   `walled out: <id> at (x, y)`.
9. **PR 5 preserved.** `Tag.endPhase` keeps no flag; one `Tag.ignition` curve; the point light; `MoveCheck` untouched;
   `endPhase == true` normalised; the +10% end-phase speed kept (§7.2 says why).
10. **Cheap every frame (trigger 6).** Server: one pass over the round's runners. Client: four parts moved, two frames
    faded, one label. No zoom, so `SideCam` and the camera are unchanged.
11. **Verification.** `npm test` (13 node, 13 Luau suites incl. the new `walls.test.luau`, mutation-checked: each rule
    deleted in turn fails a test), `npm run lint:luau` clean, `rojo build` passes; the sourcemap only gained
    `Shared.Walls`, `Server.Walls`, `Client.Walls` (ModuleScripts); line ceiling holds (`server/Match.lua` 391).

## Seen by the builder (Studio, 2026-11-01)

The viewport did not render this session (1x1, 0 render frames, captures timed out, keys ignored; → T13), so **nothing
was seen on screen**. Seen in Output, with `END_PHASE_AFTER` = 15 for the test (put back to 120): the walls opened with
the end phase (`centre 8.7, half-width 76.7 -> 24 over 20s`); standing still outside I was eliminated 3.00 s after going
out and the fuse passed to the next dummy; a red `walled out` burst on the client; the real `client/Walls` (driven on
Heartbeat in the Client datamodel from the live `MatchState`) put the edges at the server's window, closed them to 48
apart and showed `GET BACK IN  0.3  >>>`; a dummy pushed 48 studs out walked back in 1.9 s; one pushed 117 studs out
died 3.00 s after going out and ended the round. The walls wobbled 16 studs with the dummies' patrol: fixed with
`WALL_EASE` (→ S13). No errors or warnings. **The QA reviewer should capture the look in Play** (step 1 below).

## Out of scope

Per-map window bounds and a vertical shrink (PR 6, maps); sounds (the music's rise is drawn as the beat); wall art on
the sheet; a countdown over other runners outside; a camera zoom (rejected, §7.2).

## Calls for Danzo (made by the builder while he was away; recorded in endgame.md §7; say if any feels wrong)

- **DESIGN §2 is untouched.** No shared camera: the "screen" became a world-space window everyone sees; every player
  keeps their own camera and arrows. Rules 3 and 51 and §6.8 now carry the mechanic as built; §4's row says so.
- **A 3 s grace, reset on return** (not refilled slowly). Fallback: 2 s if it feels toothless; a slow refill if
  in-and-out at the wall feels cheap.
- **The walls start with the end phase**, not at the first burn-out (SpeedRunners starts at the first knockout). One
  moment, one line, and the ghosts keep the middle of the round. Fallback: a slow close from the first burn-out.
- **The window follows the living MEAN, slowly** (eased, 8 studs/s at most), not the holder (it would kill the best
  escaper) and not a duel's midpoint at speed (both would be out at once).
- **It stops at a 48-stud box** instead of closing to nothing: the fuse ends the duel. 20 s to close; it starts at
  least half a screen wide.
- **No camera zoom** (SpeedRunners' developer chose shrink over zoom for readability; zoom throws off distance).
- **+10% end-phase speed kept** alongside the walls.
- **A wall kill is a full elimination:** the next fresh fuse shrinks; the holder's death passes a fresh fuse (not the
  remaining one, as a leave does). A non-holder's wall kill can end the round and the holder then wins.
- **The grace pauses during any hold** (the tag freeze, a trap, the ice, a stumble), so a hold at a wall never kills.
- **Placeholder look:** red neon edges, a red band, a screen-edge glow, a big `GET BACK IN` line; the wall kill's burst
  is red, the burn-out's stays orange.

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard)

To reach the walls quickly, set `Config.END_PHASE_AFTER = 15` and `Config.STUDIO_DUMMY_TAGS = false`; put both back
(120, `true`) before committing.

1. At 0:15 the line `OVERTIME: the walls close in  |  +10% speed` flashes in and two red walls appear near the screen's
   edges (or a red glow on the edge they are off). Do they read at once as "the screen is closing", SpeedRunners-style?
2. Run out past a wall: `GET BACK IN  3.0` with an arrow, counting down and beating faster; you are tinted red. Run
   back in: it vanishes. Out again: a full 3.0. Is 3 s short enough to be scary, long enough to be fair?
3. Stay out: at 0 a red burst where you stand; you are a ghost and can cross the walls freely.
4. Watch the walls close to a box about 12 tiles wide and stop. Do they sway with the pack? Too fast, too slow?
5. Next round, survive to the final two: the walls force you together while the fuse ignites. Does it feel like ONE
   ending (ignition + walls + speed), or two things at once? Is the +10% still worth having?
6. Two players, if there is a second keyboard: both screens show the walls at the same place; a wall kill bursts red
   on both.
