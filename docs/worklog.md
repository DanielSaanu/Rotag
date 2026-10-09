# Worklog

One dated line per block of work, newest last. Say what changed and where, and cite learnings IDs if a rule was
paid for. The detail belongs in commits and the docs; this is the timeline.

- 2026-10-09 · `claude/friendly-hawking-74891i`: repo bootstrapped from The Warehouse. Design notes in
  `docs/DESIGN.md`; the pipeline (`bin/`, `src/`, `ui/`, tests, `tools/luau-check.js`) copied unchanged; `CLAUDE.md`,
  `INDEX.md`, `docs/learnings.md` (inherited rules), `docs/handoffs.md`, the heavy agent and the qa-loop skill
  adapted to this game; a Rojo scaffold (`Config`, two entry stubs, generated `Sprites.lua`) with a placeholder
  runner (idle + two run frames) to prove `roblox build`. `npm test` and `npm run lint:luau` green. Not yet
  uploaded (sheet id 0) and not yet opened in Studio.
- 2026-10-09 · `claude/friendly-hawking-74891i` · heavy, H1: the first playable, built but not yet played.
  `shared/Movement.lua` (run, jump, double jump, wall jump, dash, Celeste forgiveness, refresh on contact, speed
  kept and banked) and `shared/SideCam.lua`, each with a Luau test, each rule mutation-checked (→ S8, new Q5);
  `server/Arena.lua` (test map in `Workspace.Map`) and `server/Runners.lua` (one-box runner, dormant Humanoid);
  `client/Body`, `Controls` (two touch buttons), `Look` (sprite two ways behind `SurfaceSprites`, flip behind
  `FlipBySize`), `SideCamera`. Tree only grew (8 ModuleScripts, sourcemap diffed). `lint:luau` learnt the Roblox
  globals `RaycastParams` and `PhysicalProperties`. Detail: `docs/systems/movement.md`.
- 2026-10-09 · `claude/friendly-hawking-74891i`: H1 played and resolved. Danzo picked the SurfaceGui runner over the
  BillboardGui (the world-face parallax reads nicer) and the negative-rect flip worked; `Look.lua` keeps only that path
  (151 → 126 lines), the `SurfaceSprites` and `FlipBySize` attributes are gone from the server and the docs. Next: tag.
