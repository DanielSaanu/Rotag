# INDEX — read this first, then open only what the task needs

One line per doc and per source folder: what it is, and when to read it. For Roblox folders, the service they sync
to (`roblox/default.project.json`).

## Orientation and to-do

- [`CLAUDE.md`](CLAUDE.md): how to work here (the loop, reading and editing rules, Rojo rules, escalation). Every session.
- [`ideas/INBOX.md`](ideas/INBOX.md): Danzo's to-do list, written in the UI. Every session, after `docs/handoffs.md`.
- [`docs/handoffs.md`](docs/handoffs.md): routine → heavy escalations. Check for OPEN entries every session.
- [`docs/worklog.md`](docs/worklog.md): one dated line per block of work. Add to it at the end of each block.
- [`README.md`](README.md): what Rotag is, the quick start, the CLI cheat sheet. First time only.

## Rulebooks

- [`docs/learnings.md`](docs/learnings.md): how to build here, with ID'd rules (A/S/N/T/G/Q). Before a similar task; cite IDs.
- [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md): what makes a good game, portable across projects. Before a design fork.

## Detail

- [`docs/DESIGN.md`](docs/DESIGN.md): the design contract. §2 locked decisions, §3 the 36 adopted rules, §4 reference
  games, §6 open questions in order. Before any gameplay, art or control change.
- [`docs/systems/README.md`](docs/systems/README.md): how the game fits together, server vs client, the remotes list,
  one file per system. Before any game-code task.
- [`docs/systems/sprites-and-animation.md`](docs/systems/sprites-and-animation.md): how 2D elements and animation
  reach the screen (the sheet, `Sprites.lua`, frame naming, the side-on camera over parts). Before drawing or animating.
- [`docs/systems/movement.md`](docs/systems/movement.md): the runner body, the move rules and their numbers, the side-on
  camera, controls, juice, the test map, the two drawing methods. Before any movement, camera or controls change.
- [`docs/systems/art-pipeline.md`](docs/systems/art-pipeline.md): the node pipeline (draw, compose, pack, upload).
- [`docs/ROBLOX_SETUP.md`](docs/ROBLOX_SETUP.md): installing Rojo, connecting Studio, the Open Cloud key, uploading,
  the decal-vs-image gotcha. Setup or toolchain problems.
- [`docs/qa/`](docs/qa/): QA goals files and `*-summary.md` per PR. Read the summary for the area you touch; never `archive/`.

## Game code (Luau, synced by Rojo)

- [`roblox/src/`](roblox/src/README.md): the hub for the three folders below.
- [`roblox/src/shared/`](roblox/src/shared/README.md) → `ReplicatedStorage.Shared`: pure rules, tested by `npm run test:luau`.
- [`roblox/src/server/`](roblox/src/server/README.md) → `ServerScriptService.Server`: the match, the fuse, tags, remotes.
- [`roblox/src/client/`](roblox/src/client/README.md) → `StarterPlayer.StarterPlayerScripts.Client`: input, feel, camera, HUD.
- `roblox/default.project.json`: the Rojo tree, including every RemoteEvent. Read before any file move.
- `roblox/sheet.json`: which scenes go in the sprite sheet (the input to `roblox build`). `roblox/assets.lock.json`: generated. Never hand-edit it.

## The asset pipeline (node, inherited from The Warehouse)

- `bin/warehouse.js`: the CLI entry point (`scenes`, `render`, `ascii`, `search`, `fetch`, `roblox build`).
- `src/`: pipeline code (`render.js`, `pixels.js`, `scene.js`, `sheet.js`, `roblox.js`, `server.js`, `sources/`).
- `ui/`: the browser UI (`npm start`). It polls scene files every 2.5 s.
- `sprites/`: pixel-text sprites (`.txt`, format in `src/pixels.js`). Drawing art.
- `scenes/`: scene JSON (format in `src/scene.js`). The file name is the Roblox sprite name.
- `library/`: borrowed assets and `index.json` licences. Keep CC-BY credits when shipping.
- `test/`: node tests (`core` = renderer and packer, `structure` = line ceiling and shared/ purity) and `test/luau/*.test.luau`.
- `tools/luau-check.js`: Luau lint. `tools/luau/` holds the gitignored binaries. `tools/runner-rig.js`: the runner's poses as
  joints; writes `sprites/runner_*.svg`. Edit it, not the SVGs.
- `.claude/agents/heavy.md`, `.claude/skills/qa-loop/`: the heavy escalation agent and the QA loop skill.
- `exports/`, `cache/`: generated output. Not committed.
