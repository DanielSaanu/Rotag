# Movement trust: a parked or NaN position (H44)

**Created:** 2026-11-22 by the heavy agent (handoff H44). The detail behind [trust.md](trust.md) §12, split out
because trust.md is at its ~300-line limit (→ G3). The speed check it extends is trust.md §3-§4; H43's bot NaN,
which raised the question, is [bots.md](bots.md) §8. DESIGN §3 rule 6 is unchanged: the server still decides.

**Status:** built and seen in Studio (solo Play, one client, three bots); the rule pinned in
`test/luau/move_bounds.test.luau` (mutation-checked → Q5).

## 1. The question

A client owns its body (network ownership), so a cheat can write its root CFrame to NaN, or to any finite far value.
H43 showed a NaN reaching `BoxWorld` froze `Match.step` for everyone. Can a client do that, or anything like it?

## 2. What Studio showed, before the fix (2026-11-22, d118997 + no change)

All from the Client datamodel's command bar, a round running (`Menu:FireServer("play")`, three bots), a probe on the
server printing the server's copy of the body.

| Test | What the server saw and did |
|---|---|
| **A.** NaN root, every Heartbeat and RenderStep, 3 s, **snapshot stream live** | Nothing. The client's own copy read `(0, -1000000, 0)` (Roblox parks a NaN CFrame there on the CLIENT, before it replicates). The server samples the stream while it is fresh (trust.md §2), so it never read the body. |
| **B.** the same, **stream cut** (the client's `Remotes.Snapshot` unparented) | The server's copy read `0, -1000000, 0` (never a NaN: the parking happens before replication). `[Rotag] move: Stifffchoclate (8061215879) over the down speed limit by 999985.4 studs at (0.0, -1000000.0); snapped back to (60.0, 1.8)`. The round ran on. |
| **C.** `(0, -1e6, 0)` held on **every** body (each new one too), stream cut, 6 s | First sample caught and snapped back as in B. **The next body was parked before the server's first sample of it, and no warning followed for ~4 s**: the fresh check had started at -1e6 and trusted it. Then the body's own step to (60, 1.8) was flagged: `over the up speed limit by 999991.0 studs at (60.0, 1.8); snapped back to (0.0, -1000000.0)`. The snap-back built a body at y -1e6, under `FallenPartsDestroyHeight` (-500); the part was destroyed, the runner had no body, and Session ended the match: `[Rotag] session: everybody left: back to an idle lobby`. |

**Verdict.** No freeze: no NaN can reach the server (the snapshot is an int16 decode, ±2047; the body is parked
before it replicates), and the server's step never threw. But a cheat could **end the match**, and for a moment the
server stored a -1e6 sample in the tag history every bot and the walls read. The routine read ("the speed check snaps
it back") was right for one write and wrong for a cheat that keeps writing, because of one assumption:
`MoveGuard.observe` started each new body's check at its **first sample**, "where the server put it is trusted". In
Studio (ping 0) the client's write reached the server before that first sample; on a live server it is a race the
cheat can win whenever its half-ping is under a server frame.

## 3. The fix

- **`MoveCheck.inBounds(x, y)`** (pure, `shared/MoveCheck`): finite, `|x| <= MOVE_BOUND_X` (2047, the snapshot's own
  range; the world measured in Studio is x -1022..1520), `MOVE_BOUND_LOW <= y <= MOVE_BOUND_HIGH` (-400, above the
  destroy height, so a snap-back spot is always somewhere a body can exist; 2047). The world is y -126..126; a fall
  out of the map at the cap is still believed for 3 s.
- **`MoveCheck.reject(s, t)`**: the runner is suspect (`MOVE_CLEAR_TIME`, never shortening a window already running);
  the check's position and its snap-back spot do not move.
- **`MoveGuard.observe` returns whether to keep the sample.** Out of bounds: marked untrusted, rejected, a warning
  (rate-limited), a snap-back to the last trusted spot (rate-limited by `MOVE_SNAP_GAP`), and **`Match.sample` does
  not store it**. So the tag history, the walls, the bots, the doors' `where` only ever see the last believable
  sample. A bot's out-of-bounds sample is dropped the same way (bots have their own guard, H43).
- **`MoveGuard.bodyBuilt`**, called from Match's tag signal (the instant the server builds the body, before
  `SetNetworkOwner`): the fresh check starts at the SERVER's spot. The first-sample start stays only as the fallback
  for a body that signal missed.

## 4. Seen after the fix (Studio, 2026-11-22)

One client, every body held at NaN for 3 s, then `(0, -1e6)` for 4 s, then `(5000, 50)` for 3 s, stream cut:
20 bodies built in 10 s (one per `MOVE_SNAP_GAP`), every one at the build spot:
`[Rotag] move: Stifffchoclate (8061215879) out of bounds at (0, -1000000), sample dropped; snapped back to (60.0, 1.8)`,
then `... out of bounds at (4999.99853515625, 50.000022888183594), sample dropped; untrusted for tags` (the warning
is once a second, the snap twice: the line says whether THIS sample snapped). The Studio `body:` line, which prints the
stored sample, read `(60.0, 1.8)` throughout. The round ran on: orbs, crates and traps, a close pass, then
`8061215879's fuse ran out, -1000 is it`; no error, no "everybody left".

## 5. What it still cannot catch

- **A cheat parked in bounds** is the plain teleport case (trust.md §3): caught by the budget, snapped back.
- **A cheat parking forever** costs it the game (it is frozen in the history at its last believable spot, taggable
  there, and its body is rebuilt twice a second) and costs the server one body build per 0.5 s per such client, the
  same price as the speed check's loop (`MOVE_SNAP_GAP`). Kicking a repeat offender is not built; it is the next step
  if a live server ever logs one.
- **Bounds are a box, not the map.** If a map or area is ever built past |x| 2047 or y 2047, `move_bounds.test.luau`
  fails on its blocks: raise the bound and the snapshot's `POS_SCALE` together.
