# QA round 2: ghosts v2 items — SCORE 8/10

Reviewer: Opus subagent, 2026-10-19, HEAD 95b352e. Played solo in Studio with 3 dummies via keyboard input, with a
client-side recorder of every HUD text change. Report verbatim below, then the builder's decisions.

---

## QA round 2: ghosts v2 items (HEAD 95b352e)

**Verdict: 8/10.** Both round-1 fixes hold up, the tests pass, and Studio shows items working end to end. The main problem I found live: the TRAPPED / FROZEN / STUMBLE line never appeared on my screen for any of the 3 holds that landed on me. The tag-freeze line was showing instead.

**How I tested.**
- `npm test`: 13 node tests and 11 Luau suites pass. The output includes "ignoring a stumble from a run: caught 0.683 s in".
- `npm run lint:luau`: all files ok.
- `rojo build`: ok.
- Studio Play on 4439bd34 with 3 dummies, driven by `user_keyboard_input`. A client-side recorder wrote every HUD text change into a Player attribute. Play was stopped at the end.
- I could not run the pry by hand. Simulating keys from Luau (`SendKeyEvent`) is blocked: "lacking capability RobloxScript". My Q-mash sequence never overlapped a trap on me, because the dummies' tag ping-pong kept making me "it", and while you are it you cannot be held.

**What Studio showed**
- I took a living orb as holder: `orbs: 8061215879 took living orb 6: ice`. The slot read ITEM: ICE.
- Pressing E fired the beam: `items: 8061215879 used ice at (-67.9, 1.8) facing 1`. ScreenCapture_1 shows a cyan beam ahead of me, and the slot went back to "ITEM: none".
- As a ghost in Play 1, I ran over the living orb at x=-64 and it was not taken.
- Dummies place things and they catch runners:
  - `-1001 used trap at (27.1, 1.8)` then `8061215879 caught: trap for 1.0s (thing 2)`
  - `-1000 caught: stumble for 0.7s (thing 3)`
  - one beam caught three runners: `8061215879 / -1002 / -1000 caught: freeze for 1.0s (thing 8)`
- A hold never stops a tag: right after my freeze landed, the log shows `TAG -1000 -> 8061215879`.
- An honest run into a trap gave no `[Rotag] move:` snap-back line all session, including when I was trapped while running.

SCORE: 8/10

GOALS:
- Living orbs and pools: met. Pools are at shared/Items.lua:14-18. Live: runners rolled trap/crate/ice, and as holder I rolled ice. A ghost could not take the living orb at x=-64.
- Use: met. The server uses its own newest trusted sample and the stream's facing (server/Items.lua:77-80). Live log: "used ice at (-67.9, 1.8) facing 1", beam drawn, slot emptied. The hex is refused (shared/Items.lua:105).
- Holds: partial. Stumble, freeze and trap all landed live, and the round-1 desync is fixed in code (`Items.acceptPress` at shared/Items.lua:139; client/Use.lua:49-51 stays pinned until the server frees it). The 3-press pry was not exercised by hand; it is only covered by items.test.luau:97.
- Dash i-frames: met by code and test. `Snapshots` uses `dashSeen` to enforce the server-side cooldown; `catch` exempts only non-crate items (shared/Items.lua:178); the hex uses `undodged`. Not exercised live.
- No ganging up: met by test (items.test.luau:183). Ghosts are never passed as victims (server/Items.lua:125).
- Server decides everything: met. `MoveCheck.hold` caps for the whole hold using the server's own `recentSpeed`. Untrusted samples are hit but never place (server/Items.lua:79) or collect (server/Orbs.lua:63). No honest snap-backs seen.
- Readable: partial. Beam, trap and ice overlays, the icons and the slot all draw. But the hold status line is hidden whenever a tag freeze is running; my recorder never logged TRAPPED or FROZEN for 3 server-confirmed holds on me.
- Pure, tested, mutation-checked: met. All suites pass, lint is clean, rojo builds, Match only wires (+12 lines). The teleport-bounded orb pickup test is at move_check.test.luau:166.

PRESERVE (done well, must survive future iterations):
- `Items.acceptPress` plus a client that never frees itself: the desync is gone in both directions, and each half is a few lines.
- `MoveCheck.hold` takes its speed from `recentSpeed` over the server's own samples, never the client's vx. A cheat cannot widen its own allowance, and an honest trapped run was not flagged live.
- The beam catches each runner once and catches several at once (thing 8 froze three). The per-target ward is applied only for a ghost's aimed hits.
- Untrusted samples are hit but never place or collect (server/Items.lua:79, server/Orbs.lua:63-64).
- The Studio log lines ("used X at (x,y) facing d", "caught: trap for 1.0s (thing n)"). They made this review possible without any extra tooling.

FIX (done poorly; why it matters; concretely how to fix):
- The hold status line is hidden by the tag-freeze line. Why it matters: client/Hud.lua:222 (`elseif frozenLeft > 0 and inRound` → "X is it: run!") comes before the hold branch at line 224. A tag freeze lasts 1.5 s, which is longer than any hold (≤1 s), and holds cluster around tags. Live, all 3 holds on me (`trap thing 2`, `freeze thing 8`, `freeze thing 10`) each landed next to a tag, and none showed. The trapped player never sees "mash any key 1/3", which is the one instruction the trap needs. -> Move the `Items.holdOf(me)` branch above line 222, just after the `mine and frozenLeft` check (a holder in its tag freeze cannot be held, so the two never clash). Re-check in Studio with the recorder.

CONSIDER (fine but could change; why; how):
- A dash or dash-jump straight out of a pried trap from a standstill. `MoveCheck.hold` sets the x budget to 0×0.3+2 = 2 studs. After release it refills at 120/s, but a jump out of a dash goes past 120 for a moment. With real ping the refill window is usually enough; with near-zero ping it is tight. -> Add a move_check test: trapped from a stand, pried at 0.3 s, dash-jump 1 frame after release must not be flagged. If it fails, restore the cap to the full burst on `release`.
- A trap pins vy = 0 (shared/Movement.lua:206), so a runner caught low over a trap hangs in mid-air until freed. -> Let gravity apply to a trapped runner that is not grounded, or only arm a trap's catch on a grounded sample.
- The solo test bed buries the item feel. With me standing still, the dummies tagged me back and forth every ~1.5 s for over a minute, with the fuse capped at 45 s. You are almost always "it" or in a tag freeze, so you rarely get held. -> For item testing, have the dummies keep away from a still player, or add a Studio knob that turns dummy tagging off.

UNCERTAIN (could not verify):
- The 3-press pry by hand: the HUD count going 1/3 to 3/3, the server's "pried the trap open" line, and no snap-back afterwards. Danzo should step on a dummy's trap and mash; then do nothing and check it lets go after 1 s.
- Dashing through a live beam or over a trap, and dashing into a crate (should still stumble). Not exercised live; code and tests only.
- The ghost pool at about 1 hex in 5, and that ghosts' items never touch other ghosts. Test-only; I never held a ghost orb live.
- The phone preset. By the numbers the ITEM button is 64 px at W-104..W-40, H-200..H-136, 16 px above JUMP and out of the lower middle. Thumb reach and "tap anywhere" are for Danzo's phone.
- Feel of the stumble at half speed, the freeze slide bleeding to 0, and the 0.5 s no-chain window. These can only be judged by hand.
- A runner who becomes a ghost mid-hold probably stays pinned up to 1 s, because client/Use applies the hold regardless of ghost state. Reasoned from code, not seen.

---

## Builder decisions

Target met (8.0): the loop stops after this round's actions.

**FIX, hold line hidden by the tag-freeze line → done by the routine session** (client HUD only): the hold branch now
sits right after the holder's own "wait for GO" check and above "X is it: run!". A holder in its tag freeze cannot be
held, so the two never clash.

**CONSIDER ×3 → the heavy agent (shared code, triggers 2 and 6):** (1) the move_check test for a dash-jump one frame
after a pry from a standstill, with the release cap restored to the full burst if it fails; (2) gravity for a trapped
runner that is not grounded (or arm the trap only on a grounded sample); (3) a Studio knob that turns dummy tagging
off so item feel can be tested solo. Outcome recorded below by the agent.

**PRESERVE:** all five kept.

**Danzo's checklist** (in the summary): the pry by hand, dash through a beam / over a trap / into a crate, the ghost
pool live, the phone ITEM button, the feel of the stumble and the freeze slide, and the owner-immunity feel call.

**Outcome (the H19 heavy agent, 2026-10-19; not committed).**
- **(1) Dash-jump out of a pried trap:** the test did NOT fail, but it passed by only 0.49 studs of budget at a
  138 studs/s peak. trust.md §3 measured 8.6 studs of catch-up jitter on an honest stream, so I restored the burst
  anyway. When a hold ends, by pry or by running out, `MoveCheck.step` resets the x budget to the full burst. The
  test now drives a real Movement runner: trapped standing, pried at 0.3 s or left to run out, dash, then jump. It
  asserts no flag, a peak above the dash speed, and a budget never under half the burst (measured: 22.6 studs). A
  client that ignored the hold was already caught during it, so the reset gives a cheat nothing.
- **(2) The trap hang:** fixed in `shared/Movement.lua` with one line. A trapped runner keeps x at 0, and in the air
  its vy is `min(vy, 0)`: it drops onto the trap and never rises. I chose this over "arm only on a grounded sample"
  because the server does not know grounded and Movement stays pure.
  - H19's "pinned in the air" assertion was retired with that behaviour. The new test is a rising runner caught low:
    it never rises, never moves across, and lands.
  - The trap's down allowance in `MoveCheck.HOLD_RATES` is now the fall cap. A trap set in mid-air can catch a runner
    high up, and its 40-stud fall is legal. A mutation found this; it has a test now.
- **(3) Solo item testing:** `Config.STUDIO_DUMMY_TAGS` (default true; false: a dummy holder chases but never tags),
  checked in `Bots.tags`. It is documented in ghosts.md's knob table and in the "What Danzo should feel" preamble of
  `ghosts-v2-items.md`: false for items 1-6, true again for item 7 and before committing.
- **PRESERVE:** all five untouched.
- **Re-run:**
  - `npm test`: 13 node tests pass; all 11 Luau suites ok.
  - `npm run lint:luau`: 33 files ok.
  - `rojo build`: ok; the tree is unchanged since round 1 (41 instances).
  - Mutation: 54 mutations, 51 caught. The 3 misses are the equivalent ones recorded in items.md §8.
- **Not played:** none of these three changes has been run in Studio.
