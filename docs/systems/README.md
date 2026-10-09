# How the game fits together

**Created:** 2026-10-09. This is the short overview. What the game is meant to *be* is in
[`../DESIGN.md`](../DESIGN.md). Today the game is a scaffold; this file grows one row per system as each lands,
and every system file ends with **Expansion: deficits at scale** once there is something to measure.

## Server vs client

- **The server owns the match** (`roblox/src/server`, which syncs to `ServerScriptService.Server`): who is "it",
  the fuse, when a tag counts (DESIGN §3 rule 6: the client reports overlap, the server confirms), eliminations,
  ghosts, the round timer, crates. It is the only side that can change a player's state.
- **The client owns feel** (`roblox/src/client`, which syncs to `StarterPlayerScripts.Client`): input on keyboard
  and the mobile joystick, the Celeste forgiveness windows, momentum between moves, the side-on camera, juice, the
  HUD. It predicts its own movement with the same pure rules the server checks (→ learnings N2) and holds nothing
  durable.
- **`shared/` is pure Luau** (`ReplicatedStorage.Shared`): rules over plain tables, with no Instances and no Roblox
  APIs. That's why `npm run test:luau` can run it outside Studio and why `test/structure.test.js` polices it. The
  fuse maths, the tag rule, the movement constants and the crate table belong here. The one exception is the
  generated `Sprites.lua`.

## Remotes

RemoteEvents live in `ReplicatedStorage.Remotes` and are declared in `roblox/default.project.json`, never created in
code. Add a row here in the same commit as the declaration. Never rename one: both sides look them up with
`WaitForChild`.

| Name | Direction | Payload | Used by |
|---|---|---|---|
| *(none yet)* | | | |

The first playable (H1) added none: the sprite sheet id is already resolved in `Sprites.lua`, and movement is
client-owned physics on the player's own character ([movement.md](movement.md) §1).

Planned by the design, to be named when built: a join/init event (sends the resolved sprite sheet ids, the map,
the match state), a movement event (client → server, rate-limited), a tag claim (client → server) and a tag verdict
(server → all, with the fuse handed over), a match state event (fuse ticks, eliminations, ghosts), a notice event.

## Systems

One file each. Read only the one your task touches.

| System | File | Main modules |
|---|---|---|
| Sprites and animation (how 2D reaches the screen) | [sprites-and-animation.md](sprites-and-animation.md) | `Sprites` (generated) |
| The art pipeline (node) | [art-pipeline.md](art-pipeline.md) | `bin/warehouse.js`, `src/*.js` |
| Movement and feel (the body, the rules, camera, controls, juice) | [movement.md](movement.md) | `shared/Movement`, `shared/SideCam`, `client/Body`, `client/Controls`, `client/Look`, `client/SideCamera`, `server/Runners` |
| Tag, the fuse, elimination | *(not built)* | `shared/Fuse`, `server/Match` |
| Ghosts | *(not built; DESIGN §6.1 is open)* | |
| Crates and abilities | *(not built; DESIGN §6.2 is open)* | |
| Maps | the first-playable test map only: [movement.md](movement.md) §7 | `server/Arena` |
| HUD and mobile controls | the two touch buttons only: [movement.md](movement.md) §5; no HUD yet | `client/Controls`, later `client/Hud` |

The per-module "who owns what" tables are the folder READMEs under [`roblox/src/`](../../roblox/src/README.md).
