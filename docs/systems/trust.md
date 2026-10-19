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

## 2. Decision 1: no movement remote (H12) — revised by H14: a snapshot stream, the same check

**Revised 2026-10-14 (H14, [netcode.md](netcode.md) §8).** Two real clients showed the cost of reading the replicated
body: Roblox smooths a CFrame-driven body into ~0.4 s of lag on the second hop (netcode.md §3), so a press took most
of a second to show on the other screen and the target the server rewound to was that stale. The check below now reads
`Remotes.Snapshot`, a 30 Hz unreliable stream each client sends of its own state (`shared/Snapshot`,
`server/Snapshots`): the server stamps each on arrival (never a client clock), rate-limits and size-checks it, and feeds
its position into the SAME `MoveCheck` budget and the same tag history. The body is read only when the stream is
stale (0.5 s) or the server just rebuilt it. H12's first bullet still holds: it is the same client's word, and it
arrives ~0.18 s earlier (N6), which is exactly the point. The other two bullets are unchanged. No trust number moved.

The original reasoning (H12), kept for the record. The README had "a movement event (client → server, rate-limited,
with a server speed check)" as planned. **Not built then; the check read the body Roblox already replicates.**
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

## 9. H13: two real clients, the other runner stuck where it spawned (2026-10-14, cause not yet confirmed)

**Seen (Danzo, Test → server + 2 clients):** each window drew the other runner somewhere it was not, no tag landed
between the two, and the player who was "it" could not tag the dummy. Client Output: one `runner ready` line per
client at the round start (P1 at x 60, P2 at x 0), nothing after.

**Read from the screenshot** (4.46 px per stud: 48 studs over a 214 px viewport; both cameras centred on their own
runner, so both stood still when it was taken). Measured against the dummy, which both screens see alike:
- P1's screen: P1 at dummy -15, P2 drawn at dummy -51. P2's screen: P2 at dummy +22, P1 drawn at dummy +11.
- With the dummy near the right end of its 12-52 patrol (~50), **each runner is drawn at its own round-start spot**:
  P2 at ~0, P1 at ~60, within ~2 studs, while its own player had moved on. Standing still rules out plain delay.

**Ranked hypotheses, and the Server Output line that settles each:**
1. **(Leading) the server's copy of each body never followed its player.** If the player does not simulate its own
   body, its moves stay on its own screen only. Everything seen follows: others draw it at its spawn, a claim is judged
   with it at its spawn (the dummy patrols 12-52 and never reaches x 0, so P2 could never tag it), and no `move:` line,
   because a body that never moves never breaks the speed check. **Confirmed by:** `claim ... dropped: no overlap`
   lines whose `closest:` is tens of studs; `body:` lines (below) with one x for seconds; or an `owner:` warning.
2. **Snap-back loop** (the routine session's first guess): **killed by the client Output.** Every rebuild prints a new
   `runner ready`, and none came after the round start. If it were live, the server log would show `[Rotag] move:`.
3. **Claim window too short for a two-hop target** (`TAG_REWIND_MAX` 0.5 s): it cannot explain runners drawn at their
   spawn while standing still. **Shown by:** drops whose `closest:` is only a few studs (just past the 4-stud reach).

**What was changed (the guard, not the root cause):** `server/MoveGuard.lua`, once a second per player, reads the
body's network owner. If it is not the player, it hands ownership back with `SetNetworkOwner`, warns
`[Rotag] owner: <name>'s runner was simulated by <who> at (x, y); handed back to <name>` (or `hand-back failed: <error>`),
and restarts that runner's speed check, so the server's own repair jump is not punished as a teleport. In Studio it
also prints `[Rotag] body: <name> at (x, y), simulated by <who>` every 5 s per player.
- **Trust:** nothing loosened. The client owning its body has been the design since H1. A client cannot cause the
  hand-back (only the server's ownership decides it), so the restarted check is not something a cheat can trigger.
- **Not yet known:** why ownership would be wrong only with two real clients (solo Play has owned and replicated since
  H6). The next run's `body:` and `owner:` lines say whether it is ownership. If `body:` shows the right owner and the
  x still does not change, the fault is elsewhere in replication, and this guard does not fix it.

**Re-test 1 (Danzo, 2026-10-14, with the once-a-second hand-back):** "both able to move and tag the dummy; they still
cannot tag one another; the movement is very choppy/laggy". So the stuck server copy was real and the hand-back
repaired it. The Server Output was not captured, so we still don't know whether ownership was lost once or keeps
being lost. Two symptoms are left.

**Second change (diagnostics, plus a tighter guard; nothing about trust changed):**
- `MoveGuard` now checks the owner on **every** sample, not once a second, so a wrong owner lasts at most a frame. The
  `owner:` warning is rate-limited to one a second, and the Studio `body:` line counts hand-backs since the last line.
- `Match` logs `claim <a> -> <b> received, ping <n> ms, ...` for each new claim. When a claim is dropped it now adds
  `overlap WAS there with the target <age>s old` (the youngest target age at which the boxes really overlapped, at any
  allowance) or `no overlap at any target age`, plus how many of the claimant's samples were untrusted.
- `client/Others` (Studio only) prints `others: <name> moved on <m> of <n> frames, longest hold <h> frames, biggest
  step <s> studs` every 5 s for each other runner.

**Symptom 2, no tag between players, ranked (the dummy is taggable, so the claim path itself works):**
1. **The window is too short for a client-owned target.** On the tagger's screen the target is two hops old: its
   owner → server, then server → tagger, **plus the tagger's interpolation buffer**. Roblox smooths unanchored bodies on
   arrival; an anchored part like the dummy is not smoothed (players.md §3: the anchored stand-in stepped, the
   unanchored one was smooth), so the dummy shows up younger. If the gap passes `TAG_REWIND_MAX` (0.5 s), a moving
   target can never be confirmed, while a still one should be. **Confirmed by** `overlap WAS there with the target 0.6s
   old` (or any age above the allowance), and by a tag that lands when the target stands still.
2. **Ownership still being lost** (samples taken at a stale spot). Shown by `body:` lines with a hand-back count above 0.
3. **The client never claims.** Shown by no `claim <player> -> <player> received` line at all while they overlap on screen.
4. **Untrusted samples.** Shown by `move:` lines or `N claimant sample(s) untrusted` above 0.
If (1) holds, the fix is a fairness decision for Danzo (trigger 3): how much older the target may be, stated in
seconds. Raising the cap for everyone also raises what a laggy or lying client gets. Not changed until the number is
measured.

**Symptom 3, the other runner drawn choppy, ranked:**
1. **Ownership flapping:** each hand-back makes the body jump. Shown by big `biggest step` values with hand-backs
   counted. The per-frame check now limits this to one-frame glitches.
2. **Arrival cadence:** three Studio processes on one PC (the server and two clients) means a jittery link. Shown by a
   long `longest hold` with small steps and `moved on` well under the frame count. A real server and real phones may
   behave differently; that is worth one look before building for it.
- **The drawing-side fix, if (2):** in `Others`/`RemotePose`, draw the other runner a fixed ~0.1 s behind and
  interpolate between the positions that arrived. This is cosmetic only, with no trust change. But the claim must
  then test what is drawn, not the raw root, so the needed target age grows by the same amount. This decision is
  coupled to symptom 2's number, so it should be made after the measurement, not before.

**Danzo's suggestion: a server-side body "like the dummy".** Weighed honestly, it is not a fix for what is left:
- **An anchored server body moved from client reports** needs a movement remote: the same client's word, so no trust
  gain (§2). And anchored CFrame writes reach other screens in steps (the stand-in was "very choppy"), so it would make
  symptom 3 worse.
- **An unanchored server-owned body driven by velocity** would be smooth on other screens (that stand-in was smooth).
  But the owner's own runner would then have to be a separate local body predicted on the client and reconciled with
  the server's. That is the input-replay rework in §8: big, and it touches feel Danzo has tuned. It only buys trust if
  the server re-runs `Movement` on the inputs, and it adds a remote hop between the owner and the copy everyone tags
  against.
- **Rule 6 is unchanged either way:** the tagger's screen proposes, the server confirms on its own history. What
  decides symptom 2 is how old the target may be when the server pairs the samples. A server-owned body shortens that
  gap only a little.
- **Verdict:** not now. Measure first (the lines above). Reconsider only if, with ownership stable, the relayed body is
  still choppy on real devices, or if input replay is wanted for cheating anyway (§8).

**Re-test 2 (Danzo, 2026-10-14, with the per-frame owner check): "the players can tag each other now, but it's still
very choppy". The cause of the missing tags is settled by elimination:** the only change in behaviour between re-tests
1 and 2 was the owner check going from once a second to every frame. Everything else added was log lines that only
read state. So ownership was still being lost **repeatedly** in re-test 1, not once. Each lapse, up to a second
long, left the server's copy wrong (stuck, or simulated by someone else) and threw the claim pairs off. Run-to-run
luck can't be ruled out, one run each; the `body:` hand-back counts from the next run will confirm it. **Why the engine
drops ownership with two real clients is still unknown.** The guard repairs it within a frame; it does not explain it.
Rule → learnings N11. Hypothesis (1) for symptom 2 (the window) was therefore not the cause, and no trust number
changed. **Fairness cost of the fix: none.** A cheat cannot trigger a hand-back. After one, that runner's speed check
restarts from where the server's copy now is (one unchecked jump of whatever the lapse built up). If hand-backs turn
out to be constant, that weakens the speed check, and the counts would show it.

**The choppiness:** handled on the drawing side, players.md §3 "The draw trail" (`Config.OTHERS_DRAW_DELAY`, cosmetic,
no trust change; the claim still tests the replicated root).

## 10. Holds: the budget shrinks to the hold (H19, 2026-10-19; tightened by QA round 1)

A crate, a trap or an ice beam puts its victim in a hold ([items.md](items.md)); the victim's client applies it. When
the server writes the hold, `MoveGuard.hold` calls `MoveCheck.hold` with the victim's horizontal speed `v` measured from
the SERVER's own samples (`MoveCheck.recentSpeed`, the last 0.1 s; never the client's reported velocity, which a cheat
would raise to widen its own allowance; unknown = the dash speed, the lenient side). For the whole hold:

- **The x cap drops to what lateness can honestly cost:** `v x HOLD_GRACE + HOLD_SLACK` (45 x 0.3 + 2 = 15.5 studs for a
  runner at run speed), instead of the free 24-stud burst. The victim's client hears of the hold a ping later and runs
  on at `v` until then; that is all the cap forgives. It stays the cap for the whole hold, so standing still never
  banks budget for later in it.
- **The x refill is the hold's allowance:** trap 0; stumble half the run speed (22.5); freeze `v / 2 + HOLD_SLACK`
  (a slide from `v` bleeding linearly to 0 averages `v / 2`; 24.5 from a run). Up and down keep their H19 rates
  (trap 0 / 0; stumble and freeze the jump speed and the fall cap) and their caps.
- A pry ends it early (`MoveCheck.release`).

**Measured** (`move_check.test.luau`, all from a run at 45): an honest client that obeys a trap, a freeze or a stumble
0.3 s late is never flagged, nor an honest freeze slide from 140 heard at once. Ignoring a trap is caught **0.34 s**
in; ignoring a freeze **0.76 s** in (inside the 1 s freeze); standing 0.4 s inside a freeze and then dashing 0.2 s is
caught; ignoring a stumble is caught **0.68 s** in, on the last frames of its 0.7 s.

**What it still cannot catch, in numbers.** Inside a freeze from a run a client may cover at most the cap plus the
refill, ~15.5 + 24.5 = **40 studs** over the second, where an honest late client covers about 36 (13.5 before it hears,
~22.5 sliding): it can drift or steer within that, not run free. Inside a stumble, ~15.5 + 22.5 x 0.7 = 31 studs against
an honest ~22. **The honest edge:** a victim whose client hears of a hold more than `HOLD_GRACE` (0.3 s) late while
running is flagged and snapped back; at today's Studio delays that is far off, but a live server with very high ping
would need `HOLD_GRACE` from the victim's measured ping (items.md, expansion). The first H19 version kept the full burst
and a fixed freeze refill of 60, so a whole freeze from a run went unflagged (QA round 1); learnings N15 records why.
