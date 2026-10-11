# Ideas inbox

## Where we are (2026-10-10, after the runner pass)

- **Playable:** one runner on a test map with run, jump, double jump, wall jump, dash; side-on camera; SurfaceGui sprite.
  Movement feel is Danzo's and tuned by hand on the controls.
- **Runner art:** smooth 128 px vector figure, 8-frame procedural sprint with lean, jump rise/apex/fall, dash, plus a
  speed-driven tilt on the client. Danzo (2026-10-10): "the poses are a bit strange still but it's fine". A polish pass
  is parked below. Design sheet: https://claude.ai/artifact/JrDw2hzBgJ5o4J9abXcNgb
- **Not done, in order (DESIGN §6):** ghost rules, the crate ability list, art theme, match structure, monetisation,
  the name, bots.
- **Next build step, Danzo's call:** a second player (the tag landed 2026-10-11, H5).

## To do

- [x] **Tag built (H5, 2026-10-11):** `shared/Tag`, `server/Match`, remotes `TagClaim`/`TagVerdict`/`MatchState`, HUD,
      an orange Studio-only dummy to chase. Server side seen in Play; client side needs a `rojo serve` restart first.
      Detail: `docs/systems/tag.md`. Danzo to Play and judge the 1.5 s freeze, the 3 s start wait and the chaser ramp.
- [x] **Tag Play feedback (H6, 2026-10-11):** the once-only tag was a real server bug (claims judged before the body
      arrived), fixed; start wait 1 s with a GO count; dash cooldown 0.8 s. Re-press: likely Studio focus, not code.
- [x] Fuse pass bonus +5 → +2 (Danzo, 2026-10-11, "for now"): `Config.FUSE_PASS_BONUS`, DESIGN §2 note, HUD pop follows.
- [x] Fuse cap: **kept** by Danzo (2026-10-11). Proposed by the H6 agent; DESIGN §2 note now says so.
- [ ] Dash chains: Danzo picked **option 2** (2026-10-11): a ground dash recharges only after landing from the air.
      H9, heavy agent. Test pins mash speed against run speed.
- [x] **QA loop for the tag (2026-10-11): 7 → 8/10,** target met in round 2. Summary and Danzo's Play checklist:
      `docs/qa/tag-summary.md`. H7 (honest pop, leave gap) and H8 (spread round starts, spectating) came out of it.
- [ ] **Next build: second player.** Each screen draws only its own runner; the other player is invisible. Then the
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
