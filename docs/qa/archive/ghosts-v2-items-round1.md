# QA round 1: ghosts v2 items — SCORE 7/10

Reviewer: Opus subagent, 2026-10-19, on the uncommitted H19 working tree over d4f746b. Played solo in Studio with 3
dummies, drove the client with keys, captured the screen, stopped Play. Report verbatim below, then the builder's
decisions.

---

SCORE: 7/10

What I ran:
- `npm test`: all 13 node tests and all 11 Luau suites pass, including items.test.luau (67 asserts), the line ceiling and the purity check.
- `npm run lint:luau`: clean.
- `rojo build` and `rojo sourcemap`: both succeed. The diff shows the tree only gained `Remotes.UseItem` plus three new modules (client/Use, server/Items, shared/Items).
- Studio: started Play, drove the client with keys, captured the screen 3 times, stopped Play.

What I saw in Studio (Output):
- Dummies take living orb 4: `-1000 took living orb 4: crate`, `-1002 took living orb 4: trap`.
- Dummies use items: `-1000 used crate at (17.9, 1.8) facing -1`. Holds land: `-1002 caught: stumble for 0.7s (thing 1)` and `8061215879 caught: trap for 1.0s (thing 2)`, followed at once by `TAG -1000 -> 8061215879`, so a trapped runner can still be tagged.
- My own run: walked into the gold orb and the slot read `ITEM: TRAP`, with an icon block over my head (client part at 40.9, 8.5). Pressed E: `8061215879 used trap at (40.9, 1.8) facing 1`, the slot read `ITEM: none`, then `-1002 caught: trap for 1.0s (thing 6)`.
- Screens: ScreenCapture_1 shows a gold living orb, clearly not the pale ghost orb. ScreenCapture_3 shows a dark-red trap block at the feet.
- No errors, no snap-back lines.

Not exercised in Studio: prying a trap open, the ice beam, the dash dodge, playing as a ghost, the phone preset.

GOALS:
- Living orbs and pools: met. Arena.lua:40-46 has 3 living spots. Items.lua:14-18 has the pools, and Orbs.lua:79 rolls `poolFor(kind, holder)`. Studio rolled crate and trap for runners. Pools and weights are tested.
- Use: met. server/Items.lua:69-86 places items at the newest trusted server sample with the stream's facing. One integer, type-checked and rate-gapped (:105-112). E produced a trap at my feet in Studio.
- Holds: partial. Stumble and trap landed in Studio, and a tag went through a trap. Prying was not seen live, and has a desync risk (see FIX). A pried trap on a ghost or held runner is correctly blocked from starting items (Items.lua:103-110).
- Dash i-frames: met in code and tests, not seen live. Snapshots.lua:56-59 counts dash starts behind the server-side cooldown. Items.lua:168 lets a dash dodge the beam and the trap, never a crate. Ghosts.lua:61 uses `undodged` for the hex, and Tag never reads `iframe`.
- No ganging up: met in code. Items.lua:169,175 and Ghost.lua:54,66 give a per-target ward, shared by the beam and the hex. Victims are only `r.alive` runners (server/Items.lua:125), so ghosts are never hit. Tested.
- Server decides everything: partial. Uses, hits, holds and pries are all server-side. But a freeze is not enforced at all (see FIX), and the client predicts its own pry.
- Readable: partial. Orb, trap and icons are distinct in captures. Ice and stumble were not seen live. The trap status line says "mash any key" on touch too. The ward-end flash and the halo reset are coded (Hud.lua:104,237-241).
- Pure, tested, mutation-checked: met. shared/Items.lua is pure; items.md §8 reports 40 of 41 mutations caught. The hold-budget and teleport-orb tests are in move_check.test.luau:150-229. Match.lua only gains wiring.

PRESERVE (done well, must survive future iterations):
- The spot always comes from the server (server/Items.lua:77-80). A suspect sample places nothing but still gets hit (:117-129). This is the right asymmetry for rule 6.
- A pure `Items.step` with an event list, swept boxes (`Items.swept`, now shared with Orbs), and per-thing `hit` sets. The beam catches each runner once and crates and traps are used up on a catch. It is easy to test and was tested thoroughly.
- `Items.dashSeen` takes dash starts from the server's record with a cooldown, and also catches the rising `dashing` flag when a packet is lost (Snapshots.lua:56-58).
- Holds never touch Tag. The Studio log proves a trapped runner was tagged.
- Dummies use items through the same `Items.press` path as players (Bots.lua `uses`), so a solo test exercises the real rules.

FIX (done poorly; why it matters; concretely how to fix):
- The pry can desync and wrongly snap an honest player.
  - Why: the client sends at most every 0.06 s (`SEND_GAP`, Use.lua:15), and the server drops UseItems that arrive closer than 0.05 s apart (`USE_GAP`, server/Items.lua:108). A 10 ms jitter that bunches two presses together drops one. The client then frees itself on its own third press (Use.lua:47-51) while the server still pins it (trap rate 0). If you mash a non-Use key, no further UseItem reaches the server, so it waits out the full 1 s. Running ~0.8 s at 45 studs/s is ~36 studs, over the 24-stud burst, so you get snapped back and your samples go untrusted (you cannot tag).
  - How: in `onUse`, don't gap-drop presses during a trap; count them, capped at one per frame. Or let the client stay pinned until the server's `free` arrives (about a ping later). Add a test that bunches presses together.
- A freeze is effectively not enforced.
  - Why: the freeze allowance is DASH_SPEED/2 = 60 studs/s (MoveCheck.lua HOLD_RATES), which is above the 45 studs/s run speed. A client can ignore the whole 1 s freeze and keep running with no flag. The holder rolls ice 50% of the time, so this negates the holder's main tool. trust.md §10 acknowledges this, but the goals summary understates it as "about 16 studs".
  - How: when the hold lands, set the freeze refill from the victim's last server-seen speed. Snapshots `latest[id].vx` is available, so use |vx|/2 plus a small floor, which is ~22 for a runner at run speed. Pin it in move_check with "ignoring a freeze from a run is caught".

CONSIDER (fine but could change; why; how):
- The trap status reads "TRAPPED: mash any key" on a phone (Hud.lua:226). -> Say "tap" when `UserInputService.TouchEnabled`.
- A dummy was caught by its own trap moments after dropping it (`-1001 used trap at (44.8…)` then `-1001 caught: trap … (thing 3)`). This is legal by the spec (it arms once the owner has stepped off it and 0.5 s has passed), but a player who drops a trap and turns back may feel cheated. -> Consider making the owner immune to their own trap and crate entirely.
- Trap and crate are only distinguished by shade (dark red vs brown, both low blocks at Z depth). At phone size they may blur together. -> Give the trap a jaw silhouette (two wedges) when real art comes.
- Only living orb 4 got taken in solo play; the other two spots are out of the dummies' reach. -> Fine for now. Danzo should run to the PlatformHigh orb himself.

UNCERTAIN (could not verify):
- Prying a trap by hand (3 presses or 3 taps), the ice beam's look and slide, the dash dodge, the ghost item pool live, and the phone ITEM button. By the numbers the ITEM button sits at x -104..-40, y -200..-136, size 64, and does not overlap Jump or Dash, but I have not seen it.
- Whether a stumble at half speed and a 1 s freeze feel fair. That needs Danzo's hands on keyboard and phone, especially when an ice beam fired from a dash catches a runner.
- Behaviour with real ping and jitter (the pry desync above is reasoned from the code, not observed).

---

## Builder decisions

By the H19 heavy agent, 2026-10-19. Not committed.

**FIX 1, the pry desync: fixed both ways.**
- **Server:** no rate gap during a trap. The new pure rule is `Items.acceptPress` (shared/Items.lua). While the server
  has the sender trapped, every press counts. Otherwise `USE_GAP` stands. `server/Items.onUse` calls it.
- **Client:** it never frees itself. `client/Use.lua` keeps applying the trap until the server's `free` arrives (about
  a ping after the third press) or its own timer runs out. It stops sending after three presses. `Items.free` is
  deleted.
- **Why both:** the first removes the desync. The second makes any future desync cost a ping of standing still
  instead of a snap-back.
- **Not taken:** the reviewer's "capped at one per frame". Two honest presses bunched into one server frame would still
  lose one under that cap.
- **What a cheat gains:** it can now pry in one frame instead of ~0.12 s. An honest hand mashing three keys at once
  does the same, so the trade is worth it.
- **Test:** `items.test.luau` "presses bunched by network jitter during a trap all count". Three presses arrive 0.07 s
  and then 0.01 s apart: all are counted and the third frees the trap. Outside a trap a 0.01 s press is dropped, and
  one `USE_GAP` later it is taken. A stumble keeps the gap.

**FIX 2, the freeze not enforced: fixed, and the hole was wider than reported.**
- **The wider hole:** lowering the freeze refill to |vx|/2 + floor is not enough. The full 24-stud burst survived the
  hold, and a 1 s freeze at (45 - 24.5) studs/s never empties it. Worse, the cap was only applied once, so a client
  could stand still part of a hold, let the budget refill to 24, and then sprint. The first re-test showed it: the trap
  catch came 2 frames late.
- **`MoveCheck.hold` now does three things:**
  - the x cap drops to `v x HOLD_GRACE + HOLD_SLACK` (15.5 studs from a run) and **stays the cap for the whole hold**;
  - a freeze refills at `v / 2 + HOLD_SLACK` (24.5 from a run);
  - `v` is the victim's speed from the **server's own samples** (`MoveCheck.recentSpeed`, last 0.1 s), not the
    snapshot's `vx`. A cheat would report a high `vx` to widen its own allowance. An unknown speed is read as the dash
    speed, the lenient side.
- **The grace changed form:** `HOLD_GRACE` is now forgiveness in the budget, not a delay before the hold starts. New
  knob `Config.HOLD_SLACK` = 2.
- **Measured from a run, in `move_check.test.luau`:**
  - ignoring a freeze is caught 0.76 s in ("ignoring a freeze from a run is caught", before the 1 s ends);
  - ignoring a trap is caught 0.34 s in (it was 0.83 s);
  - ignoring a stumble is caught 0.68 s in (it was never caught);
  - standing 0.4 s inside a freeze and then dashing 0.2 s is caught;
  - an honest client obeying 0.3 s late is never flagged for any hold, and neither is an honest freeze slide from 140.
- **The residual, in studs, now in trust.md §10:** inside a freeze from a run a cheat covers at most ~40 studs against
  an honest ~36. In a stumble it is ~31 against ~22. It can drift, not run free.
- **The new honest edge:** a victim whose client hears of a hold more than 0.3 s late while running is snapped back.
- **Rule N15 rewritten:** the first version said "keep the cap", which was wrong.

**CONSIDER, the trap line on a phone: done.** `Hud.lua` says "TRAPPED: tap anywhere 1/3" when
`UserInputService.TouchEnabled`, and "mash any key" otherwise.

**Kept, as the coordinator directed (Danzo's feel test):** owner immunity to their own trap and crate (0.5 s plus
stepped off, per spec); the trap's silhouette (real art later); dummies reaching only living orb 4. **Every PRESERVE
item is untouched.** The server-chosen spot, hitting suspect samples, the pure `Items.step`, `dashSeen` and holds never
touching Tag are all unchanged. The dummies still go through `Items.press`.

**Re-run:**
- `npm test`: 13 node tests pass; all 11 Luau suites ok.
- `npm run lint:luau`: 33 files ok. It caught one new warning on the way, `Config` unused in `server/Items.lua`; the
  import is removed.
- `rojo build`: ok. Sourcemap still only adds the three modules.
- Mutation: 50 mutations, 47 caught. The 3 misses are equivalent; the reasons are in items.md §8.
- **Not played:** the fixes have not been run in Studio.
