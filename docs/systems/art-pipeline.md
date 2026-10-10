# The art pipeline (node, inherited from The Warehouse)

**What it does.** Draw sprites as pixel text, compose them into scenes, pack a sheet, and ship it to Roblox as
`shared/Sprites.lua` plus an uploaded image. The browser UI (`npm start`) and the CLI edit the same files. The
Roblox-side half (where the ImageLabel lives, how frames animate) is [`sprites-and-animation.md`](sprites-and-animation.md).

**Key files**
- `bin/warehouse.js` is the CLI (`scenes`, `new`, `render`, `ascii`, `totxt`, `search`, `fetch`, `roblox build`,
  `roblox setid`, `roblox resolve`). `npx warehouse help` lists them all.
- `src/pixels.js` defines the sprite text format, `src/scene.js` the scene format, and `src/render.js` the
  renderer (the same code in the browser and in node, via `src/node-env.js`).
- `src/build.js` is `roblox build`; `src/sheet.js` packs and writes the Lua; `src/roblox.js` uploads through Open
  Cloud. `src/library.js` and `src/sources/` borrow CC0 and CC-BY assets. `src/server.js` + `ui/` are the UI.
- `sprites/*.txt` (pixel text) and `sprites/*.svg` (vector, see `tools/runner-rig.js`), `scenes/*.json`,
  `library/index.json` hold the art itself and licences. `roblox/sheet.json` says
  which scenes go in the sheet (`preview_*` and `mockup_*` are excluded).

**Gotchas**
- `roblox/src/shared/Sprites.lua` and `roblox/assets.lock.json` are generated and committed. Never hand-edit them.
  Only Danzo uploads (`roblox build --upload`).
- After any art change, render it and LOOK at it (`render <scene> --scale 8`, then Read the PNG).
- Changing `render.js`, `pixels.js` or `scene.js` is escalation trigger 2. `test/core.test.js` covers them.
- The sheet is not capped at 256: it grows by powers of two to 1024x1024, then spills into more sheets. Shelf
  packing is global, so one new sprite can move every cell and change the sheet's hash (Danzo re-uploads). If the
  sheet count ever matters, stable placement is the fix; measure first.
- The UI polls scene files every 2.5 s, so Claude's edits show up live for Danzo.
