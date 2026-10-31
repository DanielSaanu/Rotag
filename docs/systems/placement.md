# Placement: fixtures, boost pads and the boost grant (ghosts v2 PR 4, H22)

What a ghost can put in the world and what it can hand a living runner, as built. The spec is
[ghosts-v2-proposal.md](ghosts-v2-proposal.md) §3 (the three rows), §5 (placement and the keep-clear map rule), §8
(trust), §12 item 4. The rules are `docs/DESIGN.md` §3: 15 (a pad refreshes dash and double jump), 46 (the grant never
stacks with the ramp), 47 (placement), 48 (maps and keep-clear zones). Orbs and the slot are in [ghosts.md](ghosts.md);
Use, the holds and the hold budget in [items.md](items.md). QA goals: [../qa/ghosts-v2-placement.md](../qa/ghosts-v2-placement.md).

## 1. The rules and their numbers (trial, 2026-10-31)

| Thing | Who | What | Numbers (`shared/Config.lua`) |
|---|---|---|---|
| **Fixture** | ghosts | one of the seven tetrominoes, 1-tile (4-stud) cells, rotated in 90° steps on the grapple input, placed one tile ahead of the ghost on the tile grid; permanent for the round; solid to EVERYONE, ghosts included; at most 3 live per ghost: a 4th starts the ghost's oldest fading, solid for 1 s more, then gone | `FIXTURE_CAP` 3, `FIXTURE_FADE` 1, `PLACE_GAP` 4, `PLACE_CLEAR` 4 |
| **Boost pad** | ghosts | a 2-tile slab at the ghost's feet, its arrow the ghost's facing; lasts 20 s; anyone who ENTERS it, ghosts included, is launched along the arrow (100 studs/s, speed already carried that way is kept) and up (105 studs/s, 2 x `JUMP_SPEED`), with dash and double jump refreshed (rule 15); not solid, not an obstacle | `PAD_W` 8, `PAD_H` 1, `PAD_LIFE` 20, `PAD_SPEED_X` 100, `PAD_SPEED_Y` 105 |
| **Boost grant** | ghosts | used by touch, like the hex: the ghost's path reaches a living runner's box (a tag's reach) and that runner runs +15% for 5 s; a second grant restarts the 5 s, never stacks. On the holder boost = max(ramp, grant) (rule 46): the grant IS the ramp's top, so a granted holder reaches the top sooner, never above | `GRANT_BOOST` 0.15 (= `RAMP_MAX`), `GRANT_TIME` 5 |
| **The ghost pool** | | fixture 30, pad 15, grant 15, crate 12, trap 10, ice 10, hex 8 (the spec's whole pool; the hex is now 8 in 100) | `Items.POOLS.ghost` |

**Valid only if** (the server checks, the preview shows): every cell is clear of every map part, every live piece and
pad, every orb spot and every keep-clear zone (no spawn boxes: placed parts are cleared at round start, so a spawn spot needs no protection; QA round 1); at least 1 tile (`PLACE_CLEAR`) from every LIVING
runner's box; a solid fixture never over a ghost's own box either (it would trap it). A refused place costs nothing:
the item stays in the slot and Studio prints why.

**The map rule (rule 48, proposal §5).** Nothing placed may overlap a keep-clear zone, so no stack of pieces from any
number of ghosts can seal an exit or a corridor: a box test, no path search. `placement.test.luau` fills a room with
45 pieces from 15 ghosts and the shaft stays open. The test arena's one corridor is the wall-jump shaft between
`WallLeft` and `WallRight`: `Arena.KEEP_CLEAR` is one box from a tile before the left wall's face to a tile past the
right wall, floor to 3 tiles above the left wall's top (x 68-96, y 0-48). Real maps (PR 6) mark theirs in map data.

## 2. Who owns what

| Piece | Where | Side |
|---|---|---|
| The seven shapes in every rotation (`ROT`, cells and row runs), `rollShape`, `valid`, `spot` (where it goes), `boxesInto` (the cells as boxes, no allocation), `fits` (the fit test), `record` / `place` / `remove` / `step` (the state), `live`, `onPad`, `launch` | `shared/Placement.lua` (pure, tested) | both |
| `PLACED` (what Use places), `BY_TOUCH` (hex, grant), `grants` (the touch, the 5 s), `grantLeft` | `shared/Items.lua` | both |
| `Tag.speedMult(isIt, chaseTime, granted)` = max(ramp, grant) | `shared/Tag.lua` | both |
| `launchX` / `launchY` on the input: the pad's launch, refresh, `Events.launch` | `shared/Movement.lua` | client |
| A fixture's shape rolled with it (`piece` per holder), cleared with the slot | `shared/Orbs.lua`, `server/Orbs.lua` (the `orb` and `sync` payloads carry it) | server |
| The static boxes of the test map (`Arena.static`: blocks, keep-clear, orbs) | `server/Arena.lua` | server |
| The one placement state per round, every placement re-checked on the server's own record, the Parts (one per row run, in `Workspace.RotagFixtures`), fades, removals, `ItemEvent` zones / placed / fade / unplaced, the late-join sync | `server/Placement.lua` | server |
| A Use of a fixture or pad routed to `Placement.place` with `UseItem`'s rotation; the grant judged each frame after the things (`Items.grants` on the newest trusted samples) | `server/Items.lua` | server |
| Dummy ghosts place what they roll (a random rotation, a try every 0.5 s) | `server/Bots.lua` | server |
| The client mirror of the placed parts, the preview (red where the server would refuse), the rotate press, the pad launch on ENTERING a pad, the grant glow, `Place.grantLeft` for the frame loop and the HUD, `Place.refusal` (why the preview is red, for the ghost line) | `client/Place.lua` | client |
| `UseItem` carries `Place.rotation()` | `client/Use.lua` | client |
| `Tagging.speedMult(granted)`; the GRAPPLE touch button reads ROTATE while a ghost holds a fixture; `Place.frame` before `Movement.step`, `Place.draw` each render frame | `client/Tagging.lua`, `client/Client.client.lua` | client |
| "GHOST: PIECE / BOOST PAD / BOOST" lines; "BOOST +15% 4.2s" on a granted runner; the three icons and colours | `client/Hud.lua`, `client/Items.lua` | client |

## 3. What the server trusts (DESIGN §3 rule 6, proposal §8)

**`UseItem`'s integer is now read**, for a fixture only: the rotation 0-3 (a pad's arrow is the placer's facing; the
number is ignored for it). Everything else is the server's: the sender is a ghost of this round, the item is the
SERVER's slot, the shape is the one the server rolled with the orb, the spot is the server's newest TRUSTED sample of
the ghost and the facing its stream reports (`Placement.spot` from those), and the fit test runs on the server's own
state and its own record of every runner. A client cannot place from a position the server did not record, place
what it does not hold, choose its shape, place over anything, or place inside a keep-clear zone.

**Pads are not physics.** A pad is a drawn part (no collide, no query); the client that enters one launches its own
runner, as every move is the client's ([trust.md](trust.md)). The launch stays inside `MoveCheck`'s budget by
construction: 100 across is under the dash speed the x budget is built on; a rise from 105 up averages exactly the
check's up rate; `move_check.test.luau` drives a 10 s pad chain with a double jump and a dash on every landing, with
the grant on, and is never flagged. So a cheat launching itself "off a pad" that is not there gains nothing it could
not already claim inside the budget. A pad launching higher than this needs a launch allowance in `MoveCheck` first.

**The grant** is judged on the server like an orb touch (the giver's path between its two newest trusted samples
swept against each living runner's box, → N14); a client cannot grant or be granted by claiming. The server tells
every client (`grant`); the victim's client reads it into `speedMult`; `MoveCheck` needs no change (1.15 x run is
far under the x budget's rate).

**Fixtures are solid to all**, including ghosts (proposal §3: "fixtures and pads are map"): anchored Parts in the
Default collision group with `CanQuery` on, so the runners' probes (cast as `RotagRunners`, → T11) see them as walls and
floors. A fading piece stays solid through its 1 s warning (drawn half-transparent) and goes on the server's clock.

## 4. Payloads (`ItemEvent`, server → all; arrays only, → N13)

From `server/Placement`: `zones` `{ boxes = { { x0, y0, x1, y1, why } } }` (to one client on join: what nothing may
cover; `why` is "map" | "keep-clear" | "orb"; a client also reads "spawn" if a map ever sends it); `placed` `{ n, item, owner, shape?, rot, x, y, dir, life? }`
(x, y its bottom-left in studs; `life` nil = permanent for the round); `fade` `{ n, time }`; `unplaced` `{ n }`.
From `server/Items`: `grant` `{ id, time, by }`. From `server/Orbs`: the `orb` event and `sync`'s held rows gain
`piece` (a fixture's tetromino, "I" | "O" | "T" | "S" | "Z" | "J" | "L"). A round start's `sync` clears every placed
part and grant on the client; a late joiner then gets `zones`, a `placed` per live part, a `fade` per fade in
progress and a `grant` per live grant. `UseItem` (client → server): `number` 0-3, the rotation.

## 5. Decisions taken while building (H22)

- **All seven tetrominoes, equal odds**, rolled on the server with the orb (the same injected source as the pool
  roll), so every screen knows the piece and the ghost previews what it will place. Rotation only, no flip (side-on),
  so S/Z and J/L are four distinct pieces.
- **A fixture goes one tile ahead** of the ghost's front edge, snapped outward to the tile grid, its bottom at the
  ghost's feet rounded to the grid: on a floor flush with it; mid-jump hovering on the nearest tile line, so a ghost
  jumps to place high (proposal §5 "centred one tile ahead ... so it can hover by jumping"). DESIGN rule 47 says
  "where the ghost stands"; the tile ahead is how a 2-wide ghost places a piece without being inside it. A pad is
  centred where the ghost stands.
- **One Part per row run** of a piece, so a runner on a piece's top never crosses a seam (→ learnings on seams).
- **Pads launch on entry only**: a pad that appears under you (the ghost that set it) is not an entry.
- **The pad rise is 11.4 studs**, under a held jump's 14.25: a pad gives speed and the refresh, then the refreshed
  double jump goes higher. Pinned as a measurement in `movement.test.luau`.
- **The grant is help, not a hold**: no ward is read or written (rule 41 is about ganging up), no dash dodges it
  (rule 45 is about what hurts), a held or frozen runner is still granted.
- **Dummy ghosts place at once**, wherever they stand with a random rotation; a refused try logs why (once per
  reason) and is retried in 0.5 s. They head for ghost orbs as before.
- **A pad someone else placed launches on the first frame it is touched**; only your own pad (set under your feet)
  needs a real entry, off then on (QA round 2). The BOOST line is appended to whatever status line is up; no preview
  between rounds; the preview is a plain part (Neon read white). The grant's box became Look's rim in orange (Danzo).
- **Pads launch everyone, ghosts included** (QA round 1 asked): the spec says "anyone may use it" and "pads are map";
  a ghost needs the mobility to reach the holder, and a self-launch spends the pad's 20 s for everyone else.
- **The ghost line says why the preview is red** ("NO ROOM: map / keep-clear / orb / a piece / a pad / a runner",
  `Place.refusal`), and a new piece always starts at rotation 0 (QA round 1).
- **Deferred (QA round 1):** while a ghost RUNS, the server places from its newest received sample, up to a tile
  behind the predicted spot the preview uses; the preview is exact when still. Revisit if it is felt. For PR 6's
  map data: the open floor of a room is not a corridor, so hovering stacks can wall a pocket; mark pockets' mouths
  as keep-clear zones too.

## 6. The knobs (`shared/Config.lua`)

`GRANT_BOOST` 0.15, `GRANT_TIME` 5, `FIXTURE_CAP` 3, `FIXTURE_FADE` 1, `PLACE_GAP` 4, `PLACE_CLEAR` 4, `PAD_W` 8,
`PAD_H` 1, `PAD_LIFE` 20, `PAD_SPEED_X` 100 (keep ≤ `DASH_SPEED`), `PAD_SPEED_Y` 105 (keep ≤ 2 x `JUMP_SPEED`:
`config.test.luau` and `move_check.test.luau` pin both bounds). `Arena.KEEP_CLEAR` for the test map's zone.

## 7. What each screen shows

A ghost holding a piece sees it previewed ahead (pale violet; red when the server would refuse) and the keep-clear
zones faintly red; the GRAPPLE button reads ROTATE; W / C / ↑ / right click / RT turns it. Placed pieces are violet
blocks, pads lime slabs with a tilted arrow; a fading piece goes half-transparent for its last second. A granted runner
has an orange halo (`Look:boost`: the frozen rim's trick, the frame drawn again behind itself, larger and tinted) and,
on its own HUD, "BOOST +15%  n.ns" after whatever else the line says. Danzo (2026-10-31): the earlier box behind the
sprite was ugly, "a glow shouldn't look like that". Over a holder's head: a violet block, a
lime slab or an orange bar. Real art is the next routine block (behind `Sprites.Has`, like H21).

## 8. Verification (2026-10-31, H22)

- `npm test`: 13 Luau files and the node tests pass (`placement.test.luau` new: shapes, spot, fit, the map rule,
  the cap and fade, the pad); `npm run lint:luau` clean.
- Rojo: the tree only gained `Shared.Placement`, `Server.Placement`, `Client.Place` (ModuleScripts); `rojo build` ok.
- Studio Play (solo, `STUDIO_DUMMY_TAGS = false` for the test, four rounds): the server printed 19 static boxes; dummy
  ghosts took ghost orbs and placed fixtures O, Z, L, S, T at every rotation and pads at both floor orbs; a 4th piece
  faded the oldest ("piece 2 fading"); a grant landed on a dummy and on the player ("BOOST" seen in the log); every
  refusal reason printed (a piece, map, spawn, orb, a runner, keep-clear); the player's runner was stopped by a placed
  T piece (solid); the client got the zones (a KeepClear part in `RotagPlace`); no errors, 0 hand-backs. Not yet seen
  live: a player launched by a pad (the QA loop's reviewer drives it).
