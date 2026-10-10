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
- 2026-10-10 · `claude/friendly-hawking-74891i`: high-resolution runner. Danzo asked for a smooth, non-pixel figure that
  sits in the 3D stage. Three 128 px vector poses from `tools/runner-rig.js` (idle, run_0, run_1), scenes
  `pixelated: false`, `Look.lua` samples bilinear. Sheet rebuilt (CHANGED, awaiting Danzo's `--upload`). Play boots
  clean. DESIGN §6.3 partly answered, learnings A2.
  Danzo: the back-swung arm bent the wrong way (elbow low, hand high); fixed in the rig: elbow high and behind, hand low. Then the scarf knot showed over the back
  shoulder: knot moved under the chin and drawn before the near limbs, scarf routed above the elbow.
  Danzo uploaded (decal 95377152540627); the client showed nothing because it had the decal id and no remote carries
  the resolved id yet, so the image id (135988781031637) is hard-coded via `roblox setid`, as on 2026-10-09. Seen in Play.
- 2026-10-10 · `claude/friendly-hawking-74891i` · heavy, H2: the run cycle is four frames (stride, pass, stride, pass).
  `Config.RUN_FRAMES = 4` + `Config.RUN_CYCLE = 20` studs per cycle replace the per-frame `RUN_STRIDE` in
  `Movement.spriteFor`; test pins frame order and cycle length, mutation-checked (Q5). Not yet played. Learnings A3.
- 2026-10-10 · `claude/friendly-hawking-74891i`: Danzo: the legs are too fast, needs in-betweens. Two passing poses drawn in
  `tools/runner-rig.js` (run_1, run_3; old run_1 is now run_2), five sprites in the sheet (CHANGED, awaiting upload).
  The picker change in shared/ went through H2 (heavy agent): RUN_FRAMES + RUN_CYCLE replace RUN_STRIDE. Uploaded (decal 94711766510242 → image
  98566906497928 via `roblox setid`); seen in Play. Feel is Danzo's call: RUN_CYCLE 20, up to 24–28 if still busy.
- 2026-10-10 · `claude/friendly-hawking-74891i`: Danzo: "emulate SpeedRunners, the runner doesn't give speed".
  Researched run-cycle practice (contact/down/pass/up, forward lean and head-down sell speed, 1-3 air poses, no jump
  wind-up). `tools/runner-rig.js` rebuilt: procedural 8-frame run with IK and a 24-degree lean, plus jump_rise,
  jump_apex, fall and dash. 13 sprites in the sheet (CHANGED, awaiting upload). The picker for the new poses is H3.
  Design artifact "Runner Animation Style" holds the reference sheet and the rules applied.
- 2026-10-10 · `claude/friendly-hawking-74891i` · H3 (heavy): `spriteFor` picks dash, rise/apex/fall by vy
  (`APEX_POSE_BELOW` = 20), wall slide = fall (`s.sliding`, → A4), 8 run frames; a run from rest now opens on frame 0
  (`s.runFrom`). Tests mutation-checked. Next: routine rebuilds the sheet, Danzo uploads and plays.
