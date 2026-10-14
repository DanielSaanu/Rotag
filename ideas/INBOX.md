# Ideas inbox

## Where we are (2026-10-10, after the runner pass)

- **Playable:** one runner on a test map with run, jump, double jump, wall jump, dash; side-on camera; SurfaceGui sprite.
  Movement feel is Danzo's and tuned by hand on the controls.
- **Runner art:** smooth 128 px vector figure, 8-frame procedural sprint with lean, jump rise/apex/fall, dash, plus a
  speed-driven tilt on the client. Danzo (2026-10-10): "the poses are a bit strange still but it's fine". A polish pass
  is parked below. Design sheet: https://claude.ai/artifact/JrDw2hzBgJ5o4J9abXcNgb
- **Not done, in order (DESIGN §6):** ghost rules, the crate ability list, art theme, match structure, monetisation,
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
- [ ] **Danzo:** does the tag still feel early on the victim's screen, and does the 0.1 s lunge read as a touch? Say if
      the lunge should be longer, shorter or off.
- [ ] **Next:** commit H13+H14 (27 files, uncommitted); then the H11 proposals and DESIGN §6.1 ghost rules.
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
- [ ] **Runner pass 2 on the canvas (2026-10-14):** https://claude.ai/artifact/PpUVEG3jerX89cjUbpMxgj (model sheet, the
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
