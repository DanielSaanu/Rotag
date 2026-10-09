# Ideas inbox

## Where we are (2026-10-09, bootstrap)

- **Design:** `docs/DESIGN.md` is the research-phase design (locked decisions, 36 rules, open questions).
- **Repo:** workflow, pipeline and Rojo scaffold inherited from The Warehouse. Nothing playable yet.
- **Not done, in order (DESIGN §6):** ghost rules, the crate ability list, art direction, match structure,
  monetisation, the name, bots.
- **Next build step, Danzo's call:** the first playable. Suggested: one flat test map, one runner with run, jump,
  double jump and dash on keyboard AND the mobile joystick, the side-on camera, nothing else. Movement first.

## To do

- [ ] Danzo: Play the first playable (handoff H1). The checklist is `docs/qa/first-playable.md` (Studio play-through);
      what to look for is `docs/systems/movement.md` §8. Then pick: BillboardGui or SurfaceGui (`Workspace.SurfaceSprites`),
      and which flip works (`Workspace.FlipBySize`).

- [ ] Danzo: `rokit install`, `rojo plugin install`, connect Studio, Play the scaffold (expect a runner sprite
      top-left once the sheet is uploaded; blank until then). See `docs/ROBLOX_SETUP.md`.
- [ ] Danzo: `npx warehouse roblox build --upload`, then commit `Sprites.lua` + `assets.lock.json`.
- [ ] Decide art direction (DESIGN §6.3) before any real sprite is drawn. The placeholder runner is graphite + one glow.

## Ideas

*(Danzo writes here from the UI's ideas pad; Claude reads it every session.)*
