# Sprites and animation: how 2D elements reach the screen

**Created:** 2026-10-09. This is the method The Warehouse uses for Lowlands, written down as a method, plus the one
change Rotag's locked decision makes (DESIGN §2: side-on camera over 3D parts, not UI-based 2D). Read it before
drawing or animating anything.

## 1. One image, many sprites

Roblox cannot load an image from a file. So every sprite the game shows is **one rectangle of one uploaded sheet**:

1. `node bin/warehouse.js roblox build` renders every scene in `scenes/` (minus `export: false` and the
   `roblox/sheet.json` excludes) with the same renderer the UI uses, shelf-packs them tallest-first into
   power-of-two sheets up to 1024x1024 with 1 px padding (`src/sheet.js`), and writes
   `exports/roblox/sheet_0.png` + `roblox/src/shared/Sprites.lua`.
2. `Sprites.lua` is a table: `Sprites.Sheets[i] = { Id, Width, Height }` and
   `Sprites.Sprites["runner_run_0"] = { Sheet = 1, X, Y, W, H }`, plus `Sprites.Apply(image, name)` (sets `Image`,
   `ImageRectOffset`, `ImageRectSize`, `ResampleMode = Pixelated`, `ScaleType = Stretch`), `Sprites.New(name, parent)`
   and `Sprites.Has(name)`.
3. `--upload` (Danzo only) pushes the PNG through Open Cloud and records the id in `roblox/assets.lock.json`, keyed by
   the sheet's hash, so an unchanged sheet is never re-uploaded. The upload is a **Decal**; the **Image** id inside
   it is what `ImageLabel.Image` wants, and `Sprites.ResolveOnServer()` fetches it at boot
   (`docs/ROBLOX_SETUP.md`, Troubleshooting). The server must hand the resolved ids to clients
   (`Sprites.ApplySheetIds`) before they build any UI.

Consequences worth knowing before you draw:
- **Any art change re-packs everything.** One new sprite can move every rectangle, so the old uploaded image shows
  the WRONG sprites until Danzo re-uploads. Claude runs `roblox build` (it prints CHANGED and keeps the old id);
  Danzo runs `--upload` and commits `Sprites.lua` + `assets.lock.json` together.
- **Sprites can be any size.** 16x16 is the tile unit; a character can be 16x24, a bomb 8x8, a big title 128x32.
  The sheet does not care. Keep each sprite's canvas tight: padding is per sprite.
- **A scene can slice itself** with a `frames` map (`"frames": { "runner_dash_0": {x,y,w,h}, ... }`), which packs each
  rectangle as its own sprite. Use it when a borrowed strip is easier to keep as one image.

## 2. Drawing: pixel text, then scenes

- A sprite is a text file, one character per pixel (`sprites/runner_run_0.txt`, format in `src/pixels.js`):
  ```
  # name: runner_run_0
  # palette: . = transparent, k = #1b1b2f, g = #5b5f73, n = #7df9ff
  ..kkkk..
  ```
  Claude can draw it, read it (`warehouse ascii <scene>`), and diff it. Palettes stay small (5 to 8 colours) so a
  recolor layer can re-skin a whole character (Lowlands' bandit is the player body with four colours swapped).
- **Vector sprites** for things that must read as smooth drawings, not pixel art (the runner, Danzo 2026-10-10): an
  SVG in `sprites/<name>.svg` used as an image layer of a scene with `"pixelated": false` and the SVG's own size
  (the runner is 128 x 128, eight times the tile, feet on y = 120). `src/render.js` loads SVG as it loads PNG, in
  node and in the UI. The runner's poses are joints in `tools/runner-rig.js`, which writes the SVGs: add a pose
  there, run it, add the scene. The label must then sample bilinear (`ResampleMode = Default`, set in
  `client/Look.lua` after `Sprites.Apply`, which sets `Pixelated` for tile art).
- A scene (`scenes/<name>.json`, format in `src/scene.js`) composes layers: images (a `.txt` sprite, a PNG from
  `library/`, with `crop` to slice a sheet), pixel grids, text in real fonts, shapes, or other scenes. Per-layer
  effects: flip, rotate, scale, opacity, tint, hue/sat/brightness, recolor map, outline, shadow.
- **Render and LOOK** after every change: `node bin/warehouse.js render <scene> --scale 8`, then Read the PNG.
  Mockups that are only for eyeballing get `"export": false` and a `preview_` name (`preview_runner_strip`).
- Borrow with `warehouse search` / `fetch` (Kenney CC0, OpenGameArt, game-icons, LoSpec palettes). The licence lands
  in `library/index.json`. `warehouse totxt` turns a small PNG into an editable pixel-text sprite.

## 3. Animation: frames are sprites, the clock picks the frame

There is no animation runtime. An animation is **a set of sprites with a naming convention and a rule that picks
one**:

- Frames are separate scenes named `<thing>_<state>_<n>`: `runner_run_0`, `runner_run_1`. Facing variants in a
  top-down game were `<thing>_<facing>_<n>`; a side-on game needs one facing and `flipX` on the ImageLabel, or
  a mirrored scene layer, for the other.
- **Frame 0 is the rest pose** (→ learnings A1). A thing that stops moving drops back to frame 0 after a short grace
  (Lowlands: 0.08 s after its last step for the player, two step times for others).
- **Looping things take the frame from the clock**, not from when they appeared:
  `frame = math.floor(now * rate) % frames`, then `Sprites.Apply(img, base .. "_" .. frame)` only when the frame
  changed. Everything flickers in step and nothing rewinds when it scrolls into view.
- **Step-driven things advance a frame per step**: Lowlands flips `frame = 1 - frame` each tile step, so the walk
  cycle is tied to distance, not time. A runner's run cycle should do the same against distance travelled, so speed
  reads in the legs.
- **A run cycle needs its in-betweens, and its speed is set per cycle, not per frame** (decided, H2, 2026-10-10).
  The first runner had two contact poses flipped every 5 studs: at 45 studs/s that was 9 flips a second between two
  far-apart poses, which Danzo read as "too fast", flicker rather than legs. It is now four frames, stride, pass,
  stride, pass (`runner_run_0..3`; frame 0 doubles as the air and dash pose), picked as
  `floor(runDistance * Config.RUN_FRAMES / Config.RUN_CYCLE) % Config.RUN_FRAMES`.
  - *Constant, not a table of names.* The frames already follow `<thing>_<state>_<n>`, so a count is all the picker
    needs; a name table would only be worth it for uneven holds (a contact held two slots), and nothing asks for
    that. If it ever does, a table of names replaces the count without touching the cycle length.
  - *Cycle length, not a per-frame stride.* With "studs per frame" as the knob, adding frames silently slows the legs
    (four frames at 5 studs halves the step rate) and dropping frames speeds them up, so two separate things,
    smoothness and cadence, move together. `RUN_CYCLE` is studs per full cycle (two steps) and is the only cadence
    knob; `RUN_FRAMES` only says how finely that cycle is cut. The Luau test pins both: the frames come in order, and
    one cycle covers `RUN_CYCLE` studs.
  - *20 studs.* Frames still change every 5 studs (9 a second at top speed, no more flicker cost than before), but a
    full cycle comes 2.25 times a second and a step 4.5 times a second: half the old leg rate, and about a real
    sprinter's cadence (4 to 5 steps a second). A 10-stud step is ~3 body heights, far longer than life, but
    45 studs/s is ~13 body heights a second, so either the cadence or the step has to exaggerate, and a long step
    with a believable cadence reads as speed instead of a blur. **Tuning:** if the legs still look too busy, raise
    `RUN_CYCLE` (24 to 28); if they look like they skate, lower it (16). That is Danzo's call on a phone and a
    keyboard, not a test's.
- One-shot effects (a smear on dash, dust on landing, the tag hit-stop flash) are a short frame list played once by
  the client, then destroyed. Keep each one a scene so the UI can preview it.
- **Juice is cheap on an ImageLabel**: squash and stretch is `Size` tweened for 50–100 ms, a smear is one extra
  wide frame, hit-stop is the client freezing its own animation clock for 50–100 ms. DESIGN §3 rule 21 lists the
  set; each one is a few lines against the ImageLabel, not a new system.

## 4. Where the ImageLabel lives: Lowlands' way, and Rotag's

**Lowlands (top-down, UI-based 2D).** The whole world is a `ScreenGui`: a `World` frame that scrolls, a ring buffer
of tile ImageLabels per layer that repaints off screen, entities as ImageLabels positioned in the same frame, snapped
to integer pixels so scrolling never judders, and `ZIndex` by y for depth. Nothing is a Part. It works, and it is
what `Viewport.lua` in The Warehouse does in 430 lines.

**Rotag (DESIGN §2, locked): a side-on locked camera over 3D parts.** Physics, collisions, wall detection and
replication come from Roblox parts; the sprites are drawn ON them. The same `Sprites.lua` serves, the ImageLabel just
has a different parent:

- **Characters and moving things** (decided, H1, 2026-10-09): an ImageLabel inside a `SurfaceGui` on the
  camera-facing face of a thin see-through Part welded to the collider, `AlwaysOnTop = false`, `LightInfluence = 0`,
  sized in studs so the sprite scales with the world, `Config.STUDS_PER_TILE` studs per 16 px. A `BillboardGui` was
  built beside it and lost: it always faces the camera, so it sits flat on the scene, while the SurfaceGui is a face
  in the world and shifts against the map as the camera moves, which Danzo preferred by a wide margin. **Flip:** a
  negative `ImageRectSize.X` with the offset moved to the rect's right edge, under `ScaleType.Stretch`; confirmed in
  Studio. (A mirrored second scene also works but doubles the frames in the sheet.) Detail: [movement.md](movement.md) §6.
- **Tiles, platforms, walls**: a `SurfaceGui` on the camera-facing face of the collision Part, one ImageLabel per
  tile or a `ScaleType = Tile` label over a repeating sprite. The Part is the collider; the GUI is the look. Grapple
  anchors, boost pads and hazards are the same with their colour-coded sprite (DESIGN §3 rule 29).
- **Camera**: `CameraType = Scriptable`, a fixed `CFrame` looking down the plane's normal, orthographic feel from a
  narrow `FieldOfView` at distance; lead ahead at speed (rule 21). The character stays on one plane by zeroing the
  off-plane velocity each frame or a `BodyPosition`/constraint on that axis.
- **HUD** (the fuse, the +5 s, off-screen arrows, four mobile buttons): a plain `ScreenGui`, Lowlands' `Hud.lua`
  pattern, with `Sprites.New` for every icon.

The open question from the first draft of this doc (BillboardGui vs SurfaceGui vs a UI world frame with parts only for
physics) was settled by handoff H1: SurfaceGui, above. The UI-world-frame option was never built (DESIGN §2 locks "3D
parts") and is no longer on the table.

## 5. The checklist for a new animated thing

1. Draw `<thing>_<state>_0..n` in `sprites/`, one scene each in `scenes/` (or one scene with `frames`).
2. `render` and LOOK; `preview_<thing>_strip` with every frame side by side is cheap and worth it.
3. `node bin/warehouse.js roblox build`; it prints CHANGED. Ask Danzo to `--upload`.
4. In Luau, one `Sprites.Apply` per frame change, picked by the clock or the step count, frame 0 at rest.
5. Studio: stop Play, start Play (Rojo does not sync into a running Play), look at it at phone size.
