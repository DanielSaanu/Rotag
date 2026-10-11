# QA summary: the tag

Goals: [`tag.md`](tag.md). Two rounds, 2026-10-11, one Opus reviewer per round, each a real Studio Play through the
MCP plus `npm test` and `npm run lint:luau`. Target 8.0 reached in round 2. Verbatim round reports: `archive/tag-round1.md`,
`archive/tag-round2.md`. Fixes that touched the match loop or a remote went through handoffs H7 and H8 (`docs/handoffs.md`).

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | Tag, tag-back and tag again work round after round and the server decides everything; but a dash chain is still +45% over a run, the "+2s" pop lied under the cap, and a leave could restart a round with no gap. |
| 2 | 8/10 | Pop honest, leave gap fixed, dummy off spawn; but a new round started with everyone where they stood, so the new "it" could tag an idle player within seconds. |

## Fixed

**Round 1**
- The "+2s" pop prints the real gain: `Tag.pass` returns `gained`, `TagVerdict` carries it, the HUD prints "+2s" or
  "+0.4s, capped" (H7, seen in Play).
- A leave that ends the round schedules `ROUND_GAP` and logs the winner; `Tag.leave` no longer rewrites the winner
  once the round is over (H7, Luau-tested; not played, solo Studio has no second client).
- The `TagVerdict` row in `docs/systems/README.md` no longer says +5 (H7).
- The dummy patrols x 12..52, clear of the spawn, so an idle first-time player is not ping-ponged (confirmed round 2).
- The PlayerModule warning is a one-time print.

**Round 2**
- Round start rebuilds every body at its own spot: `Tag.startPlaces` spreads runners over 120 studs, starter at the
  left end, the rest in rotation order, at least 20 studs apart in a full match. A server `CFrame` write on a
  client-owned body does not hold while it runs (measured), so bodies are respawned instead (H8, learnings N8; seen
  holding across four rounds, including one where the runner was mid-sprint).
- `MatchState.spectating`: a late joiner reads "next round soon", not "out" (H8).
- The whole-bonus pop formats from `gained` with `%g`, never from Config with `%d`, so a non-integer bonus cannot
  throw inside the verdict handler.

## Preserved (confirmed in both rounds)

- One-number `TagClaim`, judged against the server's own position history, looking back by ping plus a capped margin.
- The fuse waits while the holder is frozen through one `max(since, frozenUntil)`; the client predicts it the same way.
- Pending claims are re-judged every frame with `canClaim`, so no stale claim lands after the round moves on.
- The Studio-only dummy with `CanQuery = false`, claiming for itself at rewind 0.
- The big centred RUN! / count / GO!, which answers "who is it and can I move" within two seconds.
- `gained` as the second return of `Tag.pass`, sent additively in `TagVerdict` (round 2).
- `Tag.leave` early-return once over, with `nextRoundAt` set on the leave path (round 2).

## Deferred, one line each

- **Rewind allowance** (`TAG_VIEW_DELAY` 0.4 s, cap 0.5 s, about 22 studs): measure with two real clients first.
- **Passer immunity** as an alternative to the freeze: rule 1 chose the freeze (tag.md §3); Danzo has not judged it yet.
- **Off-screen pointer to the holder**: DESIGN §2 locks off-screen arrows; built with the second player, who needs them.
- **Cap visibility** ("+0.xs, capped" is honest but noisy): waits on Danzo's keep/revert on the cap itself.
- **Late joiner still sees the RUN! countdown** (H8 agent's note): hide it for anyone not in the round; cheap, next pass.
- **Round 1 rebuilds the body once more** right after first spawn (H8): harmless; fix if Danzo notices it.

## Open FIX items the loop did not act on

- **Dash chains beat a run by about 45%** even at the 0.8 s cooldown; each dash gains about 14 studs over running no
  matter the cooldown. A design fork, Danzo's to pick: (1) a ground dash ends at run speed, air keeps 80 and dash into
  jump keeps its speed (recommended); (2) a ground dash only recharges after landing from the air; (3) accept it and
  write a ceiling such as +15% into DESIGN. Then a test pins mash speed against run speed. Goal 6 stays partial.
- **The fuse cap** was added by the H6 agent without Danzo's say-so and labelled as his. Keep or revert is his call;
  DESIGN §2 carries the note either way.

## Danzo's checklist (keyboard, then the phone preset)

1. Play. Within two seconds: red "YOU'RE IT 45.0" at the top, the red triangle over you, a 1 s count to GO. Hold D
   through the count: you should move the instant GO shows, with no re-press. If you still need a click, click once in
   the game view after Play and tell me whether that was it.
2. Catch the orange box: "+2s -> Dummy", the triangle jumps to the box, a blink of hit-stop. Let it catch you: a 1.5 s
   count, the fuse number must not drop while it counts. Catch it again, and a third time.
3. Chase it for more than 10 s without catching it: do you feel yourself speed up (the ramp, up to +15%)?
4. Mash Shift on the floor: a chain is still faster than running. This is the open decision above; feel it and pick 1, 2 or 3.
5. Let your fuse run out: "Dummy wins the round", a few seconds' gap, then round 2 with the box as "it" at 45 and
   everyone rebuilt at opposite ends of the floor. Nobody should get tagged before they have moved.
6. Stand still inside x 12..52 while you are "it": the box will walk into you and you will ping-pong. That is the
   Studio dummy's patrol, not a bug; say if it bothers you and the patrol moves again.
7. Phone preset: fuse readout visible at the top, the lower middle clear, the triangle legible. Does the thumbstick
   drive the run at all? That is the biggest unverified risk (no PlayerModule under PlayerScripts in this Studio).
