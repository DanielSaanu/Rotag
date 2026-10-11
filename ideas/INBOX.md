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
  below. Detail: `docs/systems/players.md`. Next: H12, the movement remote with a server speed check.

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
- [ ] Danzo, optional: a floor dash that runs off a ledge ends at run speed (the rule reads "started on the floor"). The
      other reading, decide by where it ENDS, would keep 80 off a ledge. Say if the ledge case feels wrong.
- [x] **QA loop for the tag (2026-10-11): 7 → 8/10,** target met in round 2. Summary and Danzo's Play checklist:
      `docs/qa/tag-summary.md`. H7 (honest pop, leave gap) and H8 (spread round starts, spectating) came out of it.
- [ ] **Danzo confirms: collision between players = pass-through for everyone** (recommended 2026-10-11; chase games do it,
      one plane cannot be walked around, the tag needs overlap). Head-bounce (rule 15) parked as an optional later mechanic.
- [x] Player 2 (H11, 2026-10-11): `shared/RemotePose`, `client/Others`, `client/Arrows`, collision group `RotagRunners`,
      remote `Ready`. Solo-verified in Studio with a server-moved stand-in.
- [ ] **Danzo: two-player test.** Restart `rojo serve` and reconnect (the `Ready` remote was hand-added for the test), then
      Test tab → Clients and Servers → 2 players → Start. Look for: the other runner drawn and animated the right way with
      no pose flicker; running through each other with no stop, shove or wall-kick; an edge arrow (red on the holder) when
      apart; RUN!/count/GO! in both windows; whether tags at run speed look fair (H12's input).
- [ ] Proposals from the H11 agent, Danzo's call: HUD "waiting for players" while round 1 is held (it reads "round over"
      today); give the dummy the runner sprite so solo Play exercises the remote-drawing path (one line in `client/Others`). Each screen draws only its own runner; the other player is invisible. Then the
      movement remote with a server speed check (the stated limit of the tag check, `docs/systems/tag.md` §2).
- [x] Join remote for the sheet id (H4, 2026-10-10): `Remotes.SheetIds`. Uploads no longer need `roblox setid`.
- [x] Movement tests split (2026-10-10): `movement_world.luau` helpers, `movement.test.luau`, `movement_sprites.test.luau`.
- [x] Danzo (2026-10-11): `rojo serve` restarted and Studio reconnected; `Remotes.SheetIds` now comes from the project file.
- [ ] Runner polish pass (parked): the poses read "a bit strange" to Danzo. Candidates: longer stride, less knee bend
      in the passing frames, a clearer forward hand. Joints live in `tools/runner-rig.js`; each pass costs an upload.
- [ ] Decide the art theme (DESIGN §6.3: graphite, neon or glowing graphite). Resolution is settled (2026-10-10): smooth
      vector figures, not pixel art. The runner is inked graphite with a neon visor and scarf.
- [x] Checked by Danzo (2026-10-11): D runs right on a real keyboard. The -X run was Studio's injected key only.

## Ideas

*(Danzo writes here from the UI's ideas pad; Claude reads it every session.)*
