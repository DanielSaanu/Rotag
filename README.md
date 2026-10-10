# Rotag

**Rotag** (working title: Parkour Tag) is a 2D side-on parkour tag game for Roblox. Four players, a map bigger
than the screen, a hot-potato fuse, ghosts who want back in. Design: **[docs/DESIGN.md](docs/DESIGN.md)**.
Portable design principles: **[docs/PRINCIPLES.md](docs/PRINCIPLES.md)**.

The asset pipeline, the AI workflow (routine/heavy escalation, QA loop, the docs-as-memory layout) and the Rojo
setup are inherited from [The Warehouse](https://github.com/DanielSaanu/the-warehouse), the pipeline behind
Lowlands. This repo is for Claude and a human to work together: the human works in a browser UI and in Roblox
Studio, Claude works from the terminal, and both edit the same small files.

```
 free asset sources ──┐
 (Kenney, OpenGameArt,│      scenes/*.json        exports/roblox/sheet_0.png
  game-icons, LoSpec) ├──►   sprites/*.txt   ──►  roblox/src/shared/Sprites.lua  ──► Roblox Studio (via Rojo)
 hand-drawn pixels ───┘      ideas/INBOX.md                 ▲
                                    ▲                       │ Open Cloud upload
              browser UI ───────────┤                       │
              Claude (CLI) ─────────┘
```

## Quick start

```bash
npm install
npm start                      # UI at http://localhost:4242
npx warehouse help             # every CLI command
```

Roblox side (Rojo, API key, upload): see **[docs/ROBLOX_SETUP.md](docs/ROBLOX_SETUP.md)**.
How sprites and animation reach the screen: **[docs/systems/sprites-and-animation.md](docs/systems/sprites-and-animation.md)**.

## What is in the box

- **Sources** (`src/sources/`): Kenney CC0 packs, OpenGameArt, game-icons.net, LoSpec palettes, curated free
  fonts, and your own drops. Everything fetched lands in `library/` with its license in `library/index.json`.
- **Scenes** (`scenes/*.json`): a small JSON that says "16x16 canvas, this sprite here, flipped, recolored,
  outlined, this text on top". One file per sprite. Nest scenes inside scenes.
- **Pixel-text sprites** (`sprites/*.txt`): draw sprites as characters, one per pixel. Human-readable,
  diff-able, and something Claude can draw and read.
- **Renderer** (`src/render.js`): one Canvas 2D renderer that runs identically in the browser and in node.
  Effects: crop (slice sprite sheets), scale, rotate, flip, opacity, tint, hue/sat/brightness, recolor map,
  pixel outline, shadow, blend modes, text with real fonts, shapes with gradients.
- **UI** (`ui/`): search sources, drag layers on a zoomable pixel canvas, pixel editor, palette snapping, and an
  **ideas pad** that is literally `ideas/INBOX.md`. The UI reloads a scene when its file changes on disk.
- **Sprite sheets + Lua** (`src/sheet.js`): packs every scene into 1024-max sheets and generates
  `Sprites.lua` with `ImageRectOffset/Size` for each sprite, plus `Sprites.New` / `Sprites.Apply` helpers.
- **Roblox upload** (`src/roblox.js`): Open Cloud Assets API, with a lock file so unchanged sheets are never re-uploaded.
- **Rojo project** (`roblox/`): `shared/` (pure rules, tested outside Studio), `server/` (the match), `client/`
  (feel, camera, HUD). Today it is a scaffold: a `Config`, two entry-point stubs and the generated `Sprites.lua`.

## CLI cheat sheet

```bash
npx warehouse search kenney platformer      # find packs
npx warehouse fetch kenney <slug>           # download a CC0 pack into library/kenney/<slug>/
npx warehouse search gameicons bomb         # icons
npx warehouse search lospec graphite        # palettes
npx warehouse new runner_dash_0 16 16       # empty scene
npx warehouse render runner_run_0 --scale 8 # -> exports/runner_run_0@8x.png
npx warehouse ascii runner_run_0            # print the sprite as pixel-text
npx warehouse totxt library/x.png -o sprites/x.txt   # turn a small PNG into an editable pixel-text sprite
npx warehouse roblox build [--upload]       # sheet + Sprites.lua (+ upload with .env configured)
npm test                                    # renderer/packer/structure tests + Luau tests (needs tools/luau/)
npm run lint:luau                           # luau-analyze over roblox/src with the Roblox-only noise filtered
```

## Layout

```
bin/warehouse.js      CLI entry
src/                  renderer, scene format, sources, packer, roblox, server
ui/                   browser UI (no build step)
scenes/               composed sprites (the sprite name = file name)
sprites/              hand-drawn pixel-text sprites (.txt) and vector sprites (.svg)
ideas/                the shared scratchpad (INBOX.md)
library/              fetched assets + index.json with licenses
exports/              rendered PNGs and the Roblox sheet (ignored by git)
roblox/               Rojo project: default.project.json + src/{shared,client,server}
docs/                 design, systems, setup, rulebooks, QA
.claude/              the heavy agent and the qa-loop skill
```

## Licenses of borrowed things

CC0 (Kenney) needs nothing. CC-BY (game-icons.net, many OpenGameArt entries) needs a credit line in your
game's description. `library/index.json` remembers who to credit. Fonts are OFL/Apache and fine to bake into images.

Code in this repo: MIT.
