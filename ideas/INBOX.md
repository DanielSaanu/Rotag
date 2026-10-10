# Ideas inbox

## Where we are (2026-10-10, after the runner pass)

- **Playable:** one runner on a test map with run, jump, double jump, wall jump, dash; side-on camera; SurfaceGui sprite.
  Movement feel is Danzo's and tuned by hand on the controls.
- **Runner art:** smooth 128 px vector figure, 8-frame procedural sprint with lean, jump rise/apex/fall, dash, plus a
  speed-driven tilt on the client. Danzo (2026-10-10): "the poses are a bit strange still but it's fine". A polish pass
  is parked below. Design sheet: https://claude.ai/artifact/JrDw2hzBgJ5o4J9abXcNgb
- **Not done, in order (DESIGN §6):** ghost rules, the crate ability list, art theme, match structure, monetisation,
  the name, bots.
- **Next build step, Danzo's call:** the tag itself (the fuse, "it", the pass, the +5 s), then a second player.

## To do

- [ ] **Next build: tag.** Server-owned "it", the 45 s fuse, client overlap + server confirm (DESIGN §3 rule 6), the
      +5 s pass, the HUD fuse. Networking and fairness: every piece is escalation trigger 3, so it starts as a handoff.
- [x] Join remote for the sheet id (H4, 2026-10-10): `Remotes.SheetIds`. Uploads no longer need `roblox setid`.
- [x] Movement tests split (2026-10-10): `movement_world.luau` helpers, `movement.test.luau`, `movement_sprites.test.luau`.
- [ ] Danzo: restart `rojo serve roblox/default.project.json` and reconnect in Studio once, so the new RemoteEvent comes
      from the project file (it was added to the open place by hand for the test).
- [ ] Runner polish pass (parked): the poses read "a bit strange" to Danzo. Candidates: longer stride, less knee bend
      in the passing frames, a clearer forward hand. Joints live in `tools/runner-rig.js`; each pass costs an upload.
- [ ] Decide the art theme (DESIGN §6.3: graphite, neon or glowing graphite). Resolution is settled (2026-10-10): smooth
      vector figures, not pixel art. The runner is inked graphite with a neon visor and scarf.
- [ ] Check: with Studio's injected D key the runner ran toward -X (screen-left). Confirm D runs right on a real keyboard.

## Ideas

*(Danzo writes here from the UI's ideas pad; Claude reads it every session.)*
