# Ideas inbox

## Where we are (2026-10-10, after the runner pass)

- **Playable:** one runner on a test map with run, jump, double jump, wall jump, dash; side-on camera; SurfaceGui sprite.
  Movement feel is Danzo's and tuned by hand on the controls.
- **Runner art:** smooth 128 px vector figure, 8-frame procedural sprint with lean, jump rise/apex/fall, dash, plus a
  speed-driven tilt on the client. Danzo (2026-10-10): "the poses are a bit strange still but it's fine". A polish pass
  is parked below. Design sheet: https://claude.ai/artifact/JrDw2hzBgJ5o4J9abXcNgb
- **Not done, in order (DESIGN §6):** the crate ability list, art theme, match structure, monetisation,
  the name, bots.
- **Tag played by Danzo (2026-10-11):** "pretty good": dash good, freeze works. Phone preset still untested.
- **Player 2 built (2026-10-11, H11):** other runners drawn from their replicated position, pass-through collision group,
  off-screen arrows, round waits for every client to draw (5 s cap). Not yet seen with two real clients: Danzo's test
  below. Detail: `docs/systems/players.md`.
- **Two real clients (2026-10-14, H13):** ownership of client-owned bodies was being lost in a multi-client session;
  the server re-asserts it every frame. Other runners now drawn on a 0.1 s trail (`Config.OTHERS_DRAW_DELAY`). Why the
  engine drops ownership is still unknown; the hand-back counts in the Server Output will say how often.
- **Movement trust built (2026-10-12, H12):** no movement remote; the server checks each runner's speed and snaps a
  cheating body back; teleports under ~45 studs still pass. Detail: `docs/systems/trust.md`.
- **Ghosts built (2026-10-14, H15):** eliminated runners spook "it" by touch and can earn one comeback a round (DESIGN §3
  rules 37-41). Waiting on a `rojo serve` restart and Danzo's two-player test below. Detail: `docs/systems/ghosts.md`.
- **Ghosts v2 decided (2026-10-19, H16+H17):** no comeback; orbs for everyone (separate ghost orbs); items crate, trap,
  ice beam, grapple (living kit), boost pad, boost grant, ghost Tetris fixtures, rare hex -3 s; ignition; end-phase speed.
  DESIGN §3 rules 37-51, §6.2 resolved, §6.8 maps. Spec + build order: `docs/systems/ghosts-v2-proposal.md`. Controls
  table (provisional): `docs/systems/controls.md`. Nothing built yet.

## To do

- [x] **Tag built (H5, 2026-10-11):** `shared/Tag`, `server/Match`, remotes `TagClaim`/`TagVerdict`/`MatchState`, HUD,
      an orange Studio-only dummy to chase. Server side seen in Play; client side needs a `rojo serve` restart first.
      Detail: `docs/systems/tag.md`. Danzo to Play and judge the 1.5 s freeze, the 3 s start wait and the chaser ramp.
- [x] **Tag Play feedback (H6, 2026-10-11):** the once-only tag was a real server bug (claims judged before the body
      arrived), fixed; start wait 1 s with a GO count; dash cooldown 0.8 s. Re-press: likely Studio focus, not code.
- [x] Fuse pass bonus +5 → +2 (Danzo, 2026-10-11, "for now"): `Config.FUSE_PASS_BONUS`, DESIGN §2 note, HUD pop follows.
- [x] Fuse cap: **kept** by Danzo (2026-10-11). Proposed by the H6 agent; DESIGN §2 note now says so.
- [x] Dash chains, Danzo's **option 1** (H10, 2026-10-11, replacing H9 the same day): a floor dash ends at run speed
      (`Config.DASH_END_SPEED_FLOOR`); refresh on contact back to normal. Seen in Play. Measured: a floor chain is x1.325
      a run at `DASH_COOLDOWN` 0.8 (about +25% at 1.0, +21% at 1.2). The cooldown is Danzo's knob if he wants it slower.
- [x] Decided by Danzo (2026-10-14): leave the dash as it is. A floor dash that runs off a ledge ends at run speed (the rule reads "started on the floor"). The
      other reading, decide by where it ENDS, would keep 80 off a ledge. Say if the ledge case feels wrong.
- [x] **QA loop for the tag (2026-10-11): 7 → 8/10,** target met in round 2. Summary and Danzo's Play checklist:
      `docs/qa/tag-summary.md`. H7 (honest pop, leave gap) and H8 (spread round starts, spectating) came out of it.
- [x] **Collision between players = pass-through for everyone.** Confirmed by Danzo 2026-10-12 against a solid stand-in
      runner in Play (no stop, shove or wall-kick). DESIGN §2 line updated. Head-bounce (rule 15) parked.
- [x] Player 2 (H11, 2026-10-11): `shared/RemotePose`, `client/Others`, `client/Arrows`, collision group `RotagRunners`,
      remote `Ready`. Solo-verified in Studio with a server-moved stand-in.
- [x] **Solo stand-in test (2026-10-12):** a server-driven second runner (`tools/studio-standin.luau`, run from the MCP) was
      drawn, animated and smooth, passed through, and had its edge arrow. An ANCHORED stand-in replicated in steps and
      looked choppy; a physics body did not. It is not in the roster, so it cannot be tagged.
- [x] **Real two-player test, first three runs (2026-10-14, H13):** run 1: other runner drawn at its spawn, no tags at
      all. Cause: each client-owned body kept losing its network owner. Server now re-asserts ownership every frame
      (`server/MoveGuard`); run 3: players tag each other. Still choppy → draw trail built (below). `docs/systems/trust.md` §9.
- [x] **Two-player runs 4-6 (2026-10-14):** draw trail "slightly better"; Studio frame cap 240 (unfocused windows run
      at 25% of the cap) → smooth. Remaining: ~1 s delay before a press shows on the other screen, and tags land
      before contact on the victim's screen. Research and the fix (a snapshot stream): `docs/systems/netcode.md`.
- [x] **Snapshot stream built (H14, 2026-10-14, Fable):** each client sends its state 30/s over `Remotes.Snapshot`; the
      server judges tags and the speed check on it; other screens draw 0.08 s behind it; the tagger's sprite lunges to the
      victim on a verdict. Uncommitted, not yet seen in Studio. `docs/systems/netcode.md` §8.
- [x] **Two-player run 7 (2026-10-14, H14):** snapshot stream live. Danzo: "suddenly there is almost no latency and the
      animations are super smooth". Claude drove Player2 from the Studio MCP (it can see the test windows, press keys and
      capture screens). Tags land both ways; 0 hand-backs; 0 move warnings. One post-build fix: remote dictionary keys
      arrive as strings (N13). Knobs if ever needed: `Config.SNAPSHOT_DELAY` 0.08, `SNAPSHOT_RATE` 30, `TAG_LUNGE_TIME` 0.1.
- [x] Danzo (2026-10-19): "the tag speed is great". Lunge stays at 0.1 s.
- [x] **Ghost rules decided and built (H15, 2026-10-14):** Danzo picked "recommended". A ghost spooks "it" by touch (-3 s
      off the fuse; 8 s cooldown each, a shared 6 s ward, never while frozen); the latest spooker holds the mark and comes
      back where it stands if the fuse runs out, once per player per round. DESIGN §3 rules 37-41; `docs/systems/ghosts.md`.
      Dummy ghosts seen spooking and coming back in Studio; a player's own spook is NOT yet seen (needs the remotes below).
- [x] **Two-player ghost test done (2026-10-19), Danzo: "the ghost is good too".** Worry about four players: see
      "Ghosts v2" under Ideas. Original ask kept for the record:
      **Danzo: two-player ghost test.** First stop `rojo serve`, start it again, reconnect Studio (two new remotes,
      → T6): `ReplicatedStorage.Remotes` must list `GhostClaim` and `GhostVerdict`. Then Test → Clients and Servers, 2
      players (cap 240). With the dummy that is 3 runners, so the first player to burn out becomes the ghost. As the
      ghost, chase "it" and touch it. **Feel:** does -3s land as a real hit; is 8 s / 6 s the right rhythm or too slow;
      does being a ghost keep you busy; as "it", can you see the ghost coming (pale blue, brighter when its spook is
      ready, halo turns blue while you are safe); is the comeback fair and readable ("<name> is back!"). Knobs:
      `Config.SPOOK_DRAIN`, `SPOOK_COOLDOWN`, `GHOST_WARD`. **Paste from the Server window:** every `[Rotag] ghost:` line
      (`spook ... received`, `SPOOK ...`, `spook ... dropped: <why>`), every `... is BACK (the mark)` line, and any
      warning naming `GhostClaim` or `GhostVerdict`. Solo alternative: `Config.STUDIO_DUMMIES = 3` gives a 4-runner round.
- [ ] **QA round 1 for PR 1 (2026-10-19): 7/10.** Fixed: dummies default 3, slot readout de-duplicated, held items
      clear between rounds; client half seen in Studio by Claude. Deferred to later PRs: hex rarity (PR 2 fills the ghost
      pool; interim knob `ORB_RESPAWN` if a test feels like a hex stream), off-screen orb arrows (PR 6), item palette (PR 2).
- [ ] **Next (2026-10-19):** commit the H15 ghost work as tested; then build ghosts v2 in the PR order of
      `docs/systems/ghosts-v2-proposal.md` §12 (1 core: no comeback, ghost orbs, hex; 2 living orbs + holds; 3 controls;
      4 fixtures + placement; 5 ignition + end-phase speed; 6 maps). Phone test still pending. Open number: `END_PHASE_AFTER`
      (heavy guess 150 s, not in DESIGN).
- [x] Danzo: two-player run 4 (restart `rojo serve` first). Feel: the other runner should glide ~0.1 s behind
      instead of stuttering, red marker on its sprite, tags still land. Paste from the Server window any `[Rotag] body:`
      and `[Rotag] owner:` lines (hand-back counts confirm the cause) and from each client `[Rotag] others:`. If still
      choppy: a longest hold above ~6 frames → raise `Config.OTHERS_DRAW_DELAY`; a few huge steps → ownership still flapping.
- [ ] Danzo's call (H13): the tag still tests the REAL position, so at speed the drawn sprite trails it by 4.5 studs
      (run) to 12 (dash); a chaser can touch the sprite a moment before the tag fires. Testing the drawn spot instead
      means +0.1 s on `TAG_VIEW_DELAY`/`TAG_REWIND_MAX` (looser fairness). Say if tags feel early or late.
- [x] H11 proposals, done 2026-10-14: HUD says "waiting for players" while a round is held (`MatchState.held`); the Studio
      dummy wears the runner sprite through the fallback drawing path (`client/Others`).
- [x] Movement trust (H12, 2026-10-12): server speed check, snap-back, untrusted samples for the tag; no remote.
      `docs/systems/trust.md`.
- [x] Join remote for the sheet id (H4, 2026-10-10): `Remotes.SheetIds`. Uploads no longer need `roblox setid`.
- [x] Movement tests split (2026-10-10): `movement_world.luau` helpers, `movement.test.luau`, `movement_sprites.test.luau`.
- [x] Danzo (2026-10-11): `rojo serve` restarted and Studio reconnected; `Remotes.SheetIds` now comes from the project file.
- [x] **Runner pass 2 shipped (2026-10-14), Danzo: "okay im satisfied".** Scarf rebuilt on cloth follow-through after
      "too stiff". Knobs if ever needed: the run `ribbon()` call in `tools/runner-rig.js` (amp 16, lag 0.07).
- [x] Runner pass 2 on the canvas (2026-10-14): https://claude.ai/artifact/PpUVEG3jerX89cjUbpMxgj (model sheet, the
      13 poses over pass 1, palette). Danzo's live notes already in: arm swing fixed, trailing foot angle fixed, cycle
      remade as a sprint (heel kick, knee drive, flight). Proposal rig: `tools/runner-rig-pass2.mjs`. Next: Danzo judges
      the strip; then port into `tools/runner-rig.js`, render, `roblox build`, Danzo uploads.
      **Ported 2026-10-14** (Danzo: "upload so i can test"): `tools/runner-rig.js` IS pass 2 now, 13 SVGs regenerated, sheet
      built (CHANGED). Danzo: `node bin/warehouse.js roblox build --upload`, then commit `Sprites.lua` + `assets.lock.json`,
      then Play and judge the sprint, the scarf and the dash in motion.
- [x] Runner polish pass (superseded by pass 2 above): the poses read "a bit strange" to Danzo. Candidates: longer stride, less knee bend
      in the passing frames, a clearer forward hand. Joints live in `tools/runner-rig.js`; each pass costs an upload.
- [ ] Decide the art theme (DESIGN §6.3: graphite, neon or glowing graphite). Resolution is settled (2026-10-10): smooth
      vector figures, not pixel art. The runner is inked graphite with a neon visor and scarf.
- [x] Checked by Danzo (2026-10-11): D runs right on a real keyboard. The -X run was Studio's injected key only.

## Ideas

*(Danzo writes here from the UI's ideas pad; Claude reads it every session.)*

### Ghosts v2 (Danzo, 2026-10-19, thinking aloud in chat, "all rough ideas and im still mulling over most of it")

Worry: with four players the ghost loop collapses. Every ghost spooks once, the fuse loses ~6 s in total, and that is
the whole ghost interaction. The touch-for-the-mark comeback (rules 39-40) is the part that feels thin.

- **Drop the comeback.** Ghosts do not get back into the game. Rules 39-40 go.
- **Keep the fuse drain, but make it rare** and aimed only at the tagger: a specific "tagger-harming" ability.
- **Ghosts place things.** One or two abilities that drop real parts into the map, as they please, to hinder OR help the
  tagger and the runners: traps, walls, slows; or boosts and helpful walls. Both ways.
- **How often, three candidates:** (a) a timer; (b) once per round; (c) more often as the end phase builds (screen
  shrinking etc.) to pressure two good survivors; or (d) ghosts must pick up lucky blocks too.
- **Living players get abilities as well**, but only from lucky blocks / orbs (= DESIGN §6.2, the crate list). Ghosts
  keep a few specific ones (1-2) aimed at the tagger / runners: the drain as the rare harm, a boost grant as the help.
- **Maps.** Always planned: 3-4 maps from the start, each with its own feel (more maze-like, more open, lots of places to
  jump to or move between). Ghost-placed parts are a map thing, so this comes with it.

Touches DESIGN §3 rules 37-41 and §6.2 (and adds a maps question to §6): escalation trigger 1 once Danzo says go.

#### Abilities (Danzo, 2026-10-19, same chat, still rough)

Most of these are "same as in SpeedRunners". Who gets what: **crates, traps and ice: players AND ghosts. Grapple:
players only. Permanent fixtures: ghosts only.** Living players earn theirs from lucky blocks / orbs.

- **Bear trap.** Whoever steps in it is pinned in place, max 2 s (first said 3, dropped to 2). The trapped player taps the
  trap on screen 3 times to pry free, which should be very quick: a minor inconvenience. A slow tapper is freed by the
  timer anyway.
- **Crate.** A non-permanent part. Run into it and you stumble / roll / skid in the direction you were moving, then
  carry on. Point: for a second you are slower, so you do not catch the player right in front of you. During the
  stumble: no direction change, no jump, no dash. An ability started BEFORE the stumble still goes off; you cannot
  start one until you are back to normal.
- **Ice / freeze beam.** Shoots out in front, SpeedRunners mechanics.
- **Grappling hook.** SpeedRunners. Players only.
- **Boost pads.** SpeedRunners.
- **Boost grant** (ghost help ability). Danzo: "cant be given to the tagger, actually u decide on the fairness" of
  whether the tagger may receive it. Claude's lean, accepted by Danzo (2026-10-19): anyone may take it, but it never
  stacks on the chaser ramp (a boosted tagger reaches the ramp top sooner, never faster than it). H16 checks the numbers.
- **Dash i-frames.** The dash dodges ABILITIES, never a tag. Elden Ring style: a short active window, so a mistimed dash
  dodges the first half of an ice beam and still gets hit by the rest.
- **Ghost fixtures.** Permanent parts that add to the map: a wall or a block. Could literally be Tetris pieces, placed
  anywhere there is space, hovering allowed. Guard: a piece big enough to block an entrance entirely is too big to fit
  in a hallway or a one-entrance area. (Stacking: Danzo chose a MAP rule, 2026-10-19, "flexible, whatever u think is best"; H16 picks it.)
- **Later mode:** a pure knock-out race, like SpeedRunners.
- **Trap release on keyboard:** key mash or mouse clicks, same count as the 3 touch taps (Danzo, 2026-10-19).
- **Controls layout (Danzo, 2026-10-19):** Claude decides the optimal keyboard and controller layout, after research on
  what QWERTY keys and pad buttons these games usually use. Handoff H17.

Danzo said **propose** (2026-10-19): H16 (ghosts v2 + abilities + maps) and H17 (controls) opened in `docs/handoffs.md`.

**Danzo's answers so far (2026-10-19), on the H16 proposal (`docs/systems/ghosts-v2-proposal.md`):**
- Ruleset **1, "orbs for everyone"**: picked.
- Dash i-frames (Q5): the dash goes OVER bear traps, never THROUGH crates. So the dodge covers aimed abilities and traps,
  not crates.
- Q2 drop the "way back in" lines in §1/§2: **yes**. Q3 grapple: **living only**, a kit move. Q4 trap: **1 s cap** ("I want
  it to be fast paced"), 3 presses still free you sooner. Q6 Hex: **-3 s**. Q7 orbs: **separate ghost orbs**.
- Ignition: **in**, drawn by every client from the replicated fuse (everyone sees it). End-phase speed: **end phase
  only** (the final two or a long round, with the map shrink).
- H17 controls: Danzo "unsure". Provisional default = the table as proposed (W / ↑ grapple, mouse binds on, pry with 3 taps
  anywhere), to be judged by hand once built. Remappable anyway.

**New ideas (Danzo, 2026-10-19, thinking aloud, "tell me if im bugging or onto something"):**
- **Ignition.** As the fuse gets low, "it" is visibly ignited: a cool animation change before the explosion / fade-away
  when the holder burns out. Later a paid or spin-for slot: death animations, skins, ignitions (feeds DESIGN §6.5).
- **End-phase speed.** As the timer nears 0, max speed goes up for a high-octane finish. Or only for rounds that run
  long, together with the map shrink (DESIGN §3 rule 3). "idk". Note: rule 4 already ramps "it" (+15% after 5 s, over
  15 s, `Config.RAMP_*`); this would be a raise for everyone, not just the holder.

