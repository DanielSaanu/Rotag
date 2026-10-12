# Movement trust: the server's speed check

**Created:** 2026-10-12 by the heavy agent (handoff H12). What the server believes about where a runner is. The tag
check that uses these positions is [tag.md](tag.md) §2; the body and the move rules are [movement.md](movement.md)
§1-§3; how other screens draw a runner from the same replicated stream is [players.md](players.md) §3. DESIGN §3
rule 6 (client overlap, server confirm) is unchanged: this makes the positions the server confirms on harder to fake.

**Status:** built; the rule tested outside Studio (`test/luau/move_check.test.luau`, every rule mutation-checked → Q5);
seen in solo Play catching a client teleport and a client speed push, and quiet through honest runs (§6).

## 1. Who owns what

| Piece | Where | Side |
|---|---|---|
| The rule: a per-axis budget of distance (`MoveCheck.new`, `MoveCheck.step`) | `shared/MoveCheck.lua` (pure, tested) | server |
| Feeding it, marking samples, the warning, the snap-back | `server/MoveGuard.lua` (`observe`, `forget`) | server |
| Where samples come from | `server/Match.lua` `sample()`: each Heartbeat, every runner's `root.Position` | server |
| Claims ignore untrusted claimant samples | `Tag.touchedBetween` (`Sample.untrusted`) | server |
| The numbers | `Config.MOVE_BURST_TIME`, `MOVE_CLEAR_TIME`, `MOVE_SNAP_BACK`, `MOVE_SNAP_GAP` (§7) | both |

## 2. Decision 1: no movement remote

The README had "a movement event (client → server, rate-limited, with a server speed check)" as planned. **Not built;
the check reads the body Roblox already replicates, and the remotes list is unchanged.**
- **A position remote adds nothing.** It is the same client's word as the replicated body, and it arrives ~0.18 s
  ahead of that body (N6), so the server would hold two disagreeing streams and the tag would still be judged on one.
- **An input remote only helps if the server re-simulates.** Replaying inputs through `Movement` on the server needs
  server-side probes, and then reconciling the client's prediction against server corrections: a large change that
  touches feel Danzo has tuned. It is the next step if cheating becomes a real problem in a live game (§8), not now.
- **The two named threats are visible without it.** A teleport and a speed push both show in the server's own copy of
  the body. Fewer remotes is less to rate-limit and less to fake (N4).

## 3. Decision 2: the rule

Over any stretch of time T, a runner may travel at most `RATE x T + BURST` along each axis. Per axis a budget refills
at `RATE` per second up to `BURST`, and each server sample spends the distance moved since the last one (refill and
spend together, then cap, so a step from a full budget may move `BURST` plus what its own time earned). Below zero is a
violation. Three axes, each with its own budget: x (either way), up, down.

**The rates are Movement's own caps** (`MoveCheck.RATE_*`, pinned equal to the Config names by the test):
- **x = `DASH_SPEED` (120).** A dash holds 120. A jump out of a dash adds `JUMP_H_BOOST` (140 at most, pinned), but
  speed above the run speed bleeds at `RUN_REDUCE` while the stick holds that way, and faster otherwise, so above 120
  is only ever a fraction of a second. Ground jumps cannot stack it: each adds 20 and the shortest hop bleeds ~30.
  A wall kick keeps the speed it brought in, never more. The chaser ramp (+15%) only touches the run speed (51.75).
- **up = `JUMP_SPEED` (52.5):** no move sets `vy` higher. **down = `MAX_FALL` (80):** every fall is capped.

**The burst is `MOVE_BURST_TIME` (0.2 s) of each axis's rate:** 24 studs across, 10.5 up, 16 down. Measured:
- The fastest honest chain in the test world (dash the moment the cooldown allows, jump out of it, jump on every
  landing, 10 s) uses 1.38 studs of the x budget (pinned as a measurement → S11).
- **Studio, solo Play, the server's copy of a client-owned body while dash-jumping:** steps up to 257 studs/s, about
  twice the dash speed, for ~5 frames. That is the copy catching up after the client stopped (a tag's hit-stop): the
  copy runs ~0.2 s behind and speeds up to close the gap. Over the run it used 8.6 studs of the x budget, 1.2 up,
  0.1 down. This is why a per-step speed limit would not work and why the burst is ~3 times what was seen: Studio has
  no real network jitter; a phone does.
- Unchanged frames cost nothing and their time still refills, so a position that lands in steps (players.md §2) or
  catches up after a short stall is fine, up to the burst.

**What it does not catch (the honest limit).** Seen in Studio: **the server's copy smooths a client teleport too**,
into ~0.2 s of fast steps (a +60 stud jump arrived as 12 steps of up to ~350 studs/s). So a one-shot teleport passes
when it is under the burst plus what 0.2 s earns, about 45 studs across: a +40 write passed, a +60 write was caught on
its last step, and **a 37.5-stud teleport onto the Studio dummy counted as a tag**. A steady speed under 120 is never
caught (2 x `RUN_SPEED` = 90 passes; 3 x, 135, is caught after ~1.6 s, pinned). Tightening either needs the server to
know the inputs (§8), or a smaller burst once Danzo's two-client test shows real jitter (§7).

## 4. Decision 3: on a violation

All three, in `server/MoveGuard.lua`:
1. **Untrusted.** The violating sample and every sample after it are marked `untrusted` until `MOVE_CLEAR_TIME` (1 s)
   passes with no further violation. The budget that went negative is set to 0, not left owing, so one teleport is one
   violation, not a string of them.
2. **A warning in the server log**, in live servers too (a violation should be rare), at most one per runner per
   second: `[Rotag] move: <name> (<id>) over the x speed limit by 0.5 studs at (-56.4, 1.8); snapped back to (64.0, 1.7)`.
3. **Snap-back:** the body is rebuilt at its last trusted spot with `Runners.spawn` (a CFrame write on an owned body
   is overwritten, N8), at most once per `MOVE_SNAP_GAP` (0.5 s), deferred out of Match's sample loop. The new body
   starts a fresh, trusted check (`MoveGuard` notices the new root).

**The snap-back spot is the last sample with every budget full**, not the last sample before the violation. Seen in
Studio: with "last before" the +60 teleport snapped back to x 57.6, 43 studs into the jump, because the smoothed
steps before the caught one were each still within budget. Honest motion keeps the budget full or refills it within a
fraction of a second, so the spot is recent for an honest runner and before the jump for a teleport (pinned by a test
that replays the recorded steps: the spot is 17.64, the last step at a legal speed, from a start of 14.56).

**Why snap back at all, when untrusted already stops the tag:** a speed push used to ESCAPE is not a claim, so
"untrusted" does nothing against it. **The cost** is that a false positive rubber-bands an honest player; the burst is
set to make that rare. `Config.MOVE_SNAP_BACK = false` keeps only the untrusted marking and the warning, if Danzo's
two-client test shows snaps he did not earn.

## 5. Decision 4: what the tag does with it

`Tag.touchedBetween` skips any claimant sample marked `untrusted`; the target's samples are used as they are (being
chased by someone who teleported is not the target's fault, and a target that warped is still where the server saw
it). Pinned in `tag.test.luau`: a trusted control confirms, the same touch from an untrusted sample does not, the
claimant's earlier trusted samples still count, an untrusted target can still be tagged. The Studio dummy is the
server's own runner and is not checked (nor is any body with no player, like the stand-in).

## 6. Seen in Studio (2026-10-12, solo Play, one client, the dummy in the round)

- **Honest runs:** two dash-jump key scripts across the map, ~25 tags back and forth with the dummy, a round start
  (rebuild at -60) and a snap-back's own rebuild: no `move:` line.
- **Client teleport +60** (a CFrame write from the client), first version: `over the x speed limit by 0.9 studs at
  (62.6, 1.7); snapped back to (57.6, 1.7)`: caught, but snapped back most of the way into the jump. This is what
  moved the snap-back spot to "budgets full" (§4). **After the change**, the same +60 from x -60: `over the x speed
  limit by 0.1 studs at (-14.4, 1.8); snapped back to (-56.5, 1.8)`, a new body 3.5 studs from where it started.
  Note the 0.1: a 60-stud teleport is only just caught, 45 studs into its smoothed ramp.
- **Client speed push** (CFrame moved on every PostSimulation, ~152 studs/s seen on the server): caught after ~1 s,
  `over the x speed limit by 0.5 studs at (-56.4, 1.8); snapped back to (64.0, 1.7)`: back to where it started.
- **Client teleport of 37.5 studs onto the dummy while "it"**: not caught, and the tag counted (§3, the limit).
- **Not seen in Studio:** a claim refused for untrusted samples (the dummy and runner ended up overlapping and tagging
  back and forth, so no clean case). It is covered by the pure test. The two-client run is Danzo's (players.md §6).

## 7. The numbers

| Name | Value | What |
|---|---|---|
| `MoveCheck.RATE_X` / `RATE_UP` / `RATE_DOWN` | 120 / 52.5 / 80 | `DASH_SPEED` / `JUMP_SPEED` / `MAX_FALL` (§3) |
| `Config.MOVE_BURST_TIME` | 0.2 s | each axis's slack: 24 / 10.5 / 16 studs. Lower once real jitter is known; raise if honest players are snapped |
| `Config.MOVE_CLEAR_TIME` | 1 s | clean time after a violation before claims use that runner's samples again |
| `Config.MOVE_SNAP_BACK` | true | false: untrusted and warning only |
| `Config.MOVE_SNAP_GAP` | 0.5 s | between two snap-backs of one runner |
| `MoveGuard` warning gap | 1 s | between two log lines about one runner |

## 8. What would change it

- **A new move that is faster** (grapple release, boost pads, DESIGN §2's kit) must raise `MoveCheck`'s rates in
  the same change, or honest players get snapped. The test pins the rates to Config names, so a new fastest move needs
  a new line there and in the fastest-chain test.
- **The frozen holder:** the freeze is applied by the client, and a cheat can ignore it (tag.md §2); the server still
  refuses a frozen holder's claims. A "no horizontal travel while frozen" budget would be a small addition.
- **Input replay** (a client → server input remote, the server running `Movement` over its own probes) is the real
  fix for short teleports and steady over-speed under 120. A trigger-3 decision for a live game, not built.
