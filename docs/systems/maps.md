# Maps: map data, the Yard, the map rule as a test (ghosts v2 PR 6, H27)

**Created:** 2026-11-07 (H27, heavy). The spec is [ghosts-v2-proposal.md](ghosts-v2-proposal.md) §5 (the map rule) and
§6 (the four feels), §12 item 6 (this PR). The rules are `docs/DESIGN.md` §3 25-30 (maps), 17 (anchors), 42 (orbs),
47-48 (placement, keep-clear), 51 (the map shrink), §6.8. The closing walls are [walls.md](walls.md), placement and
pads [placement.md](placement.md), anchors [grapple.md](grapple.md). QA goals: [../qa/maps.md](../qa/maps.md).

## 1. The four decisions (Danzo said "go ahead with whatever is next"; each is a recorded call, say if one is wrong)

| Question | Decision | Why, and what was weighed |
|---|---|---|
| **The map format** | **Pure data in `shared/`**: one module per map (`MapYard`, `MapTest`), `shared/Maps.lua` the format, the registry and what is derived (`orbs`, `static`). `server/Arena` became the loader and builder: it picks `Config.MAP` and exposes the SAME fields as before (`SPAWN`, `WINDOW`, `GHOST_ORBS`, `LIVING_ORBS`, `ORBS`, `KEEP_CLEAR`, `ANCHORS`, `ANCHOR_TAG`, `static`, `build`), plus `MAP` and `PADS` | Server-only map modules would have kept test/luau/run.js lifting Luau literals out of a server file with a regex (what H25 did for `ArenaData`); pure data is required and tested like any shared rule, and the map is no secret (every client sees it). No dependant changed a call: Walls, Match, Placement, Server, client Grapple read what they read before. Trigger 2 is paid once, here |
| **The first map** | **The Yard** (open) | The proposal's lean and the routine's: it is closest to the test arena (every system already tuned there carries over), it shows the most of the kit at once (pads, anchors, fixtures, both orb kinds), and it needs **no new walls maths**: an open map ~2 screens tall is served by the horizontal box (§4). The Tower needs a vertical shrink, the Warren a corridor-heavy keep-clear pass, the Rooftops pits (and the Studio dummies walk a continuous floor): each is a bigger first step |
| **Window bounds and the shrink** | **Per map, horizontal only for now**: each map carries `window = { lo, hi }`, the end walls' inner faces; `shared/Walls` is unchanged | The Yard is kept to 24 tiles tall (96 studs, two screens) on purpose so the 48-stud box still forces the duel: inside a closed box the farthest two runners can be is ~2 screens apart vertically, and every tier is a double jump from the next. A vertical band is the Tower's PR (§4) |
| **How a map is chosen** | **One fixed map**: `Config.MAP = "yard"` (`"test"` brings back the old arena); an unknown name falls back to the Yard | One map exists; a rotation (rule 30's variety) is a list in Match the day a second real map lands. `Maps.get` never leaves the server mapless |

## 2. The map rule as a test (`test/luau/maps.test.luau`, helpers `map_check.luau`)

Every map in `Maps.NAMES` is held to all of this; a new map that fails cannot ship.

- **Well formed:** at least 3 ghost and 3 living orb spots, every orb over a floor and not in a block, every anchor's
  4-stud box clear of blocks, every pad on a floor on a tile line, every keep-clear zone 2 x 2 tiles or more
  (proposal §5: 8 studs > the runner's 3.5).
- **The window (§6.8):** its bounds are the inner faces of two tall end walls, it is wider than the walls' smallest
  opening (2 x `WALL_START_MIN`), every start place is inside it, and the real `shared/Walls` driven for 120 s with a
  pack running end to end never puts a wall past it.
- **Reachable, no dead ends (rules 25-26, 18):** on a tile grid, a deliberately weak model of a runner (rise 6 tiles
  from a floor where the game measures 7, 10 tiles of air drift, a wall kick of 3 tiles only off the wall it did not
  last kick from, so one wall is never climbed and two walls 3 apart are; falling is free; no dash, grapple or pad)
  must reach every start place and orb from the spawn and get back from each. Every anchor must have a stand that is
  both reachable and picks it through the real camera framing (grapple.test's rule).
- **No sealing, however many parts (rule 48):** a *passage* is a free tile in no free 5 x 5 square (the proposal's
  "any passage under 5 tiles across"). Fill EVERY passage tile a part could cover (no map block, keep-clear zone, orb
  box or anchor box on it: `Maps.static`), pads included, then every orb and anchor stand must still be joined to the
  spawn both ways. Rooms (free 5 x 5 squares) stay open in this worst case: the proposal accepts that pieces split a
  room ("that is their point"), the 3-per-ghost cap bounds it, and every part keeps `PLACE_CLEAR` from the living, so
  no runner is walled in where it stands. Start places are not checked here: every part is cleared at round start.
- **The test has teeth:** the Yard with its keep-clear zones removed fails it ("ghost orb (-144, 2.5) is not reached":
  the filled gap over `CoverLeft` and the filled shaft wall in the floor under `MidLeft`). The test map failed it too
  as first written: the 4-tile gap under `PlatformMid` walled in the patrol-lane orb, so it gained a keep-clear zone
  (x 28-52, y 0-16); its placement behaviour changes only there.
- **Pictures:** each run writes `exports/map_<name>.txt` and `map_<name>_filled.txt` (# solid, `.` reached, `k`
  keep-clear, g / o orbs, A anchors, = pads, S start places), the way to LOOK at a map without Studio.

## 3. The Yard (`shared/MapYard.lua`)

**Relaid 2026-11-11 (H29)** for Danzo's brief, "plenty of routes, feels fun, a plethora of options on where to go",
after QA round 1 (6/10: sealed shafts, pads that reached nothing, the next tier under the banner) and the canvas
(`docs/briefs/yard.md`). 88 x 24 tiles inside its end walls (352 x 96 studs; x -176..176), wide not tall (§4). Four
tiers 5 tiles apart, each a double jump above the last and on screen from it under the HUD banner (rule 28; the test
pins it): floor 0, mid 5, high 10, the Mast 15. The two ends are not mirrors.

**Tightened the same day (H30)** after Danzo's first play ("slightly too spaced out", pads with more oomph): the decks
moved 2-3 tiles inward and the end pads to the ends, feeding 9-tile quays.

```
 21 #                         ......................................                         #
 19 #.........                ...................A..................                .........#   A the lantern
 17 #.........                .......A.......................A......                .........#   A the swing-drops
 15 #......................................g.................................................#   the Mast, ghost orb
 14 #....................................####........####....................................#
 13 #..................A...................................................A.................#
 10 #kkkkk........................................................o.....................kkkkk#
  9 #kkk########.............#######..........######............#####..............#######kkk#   high tier
  8 #kkk#k......................A.................................A.....................k#kkk#
  7 #kkk#k......................................................................##......k#kkk#   StepRight
  5 #kkk#k..............o.....................=.........................................k#kkk#
  4 #kkk#k..........#########.......#####...##########.....#####.....#########..........k#kkk#   mid tier
  3 #kkkkk...............................kkkkkkkkkkkkk..................................kkkkk#
  1 #kkkkk.....##........................kkkkkkkkkkkkk..........................##......kkkkk#
  0 #kkkkk.=...##................gS......kkkSkkkkkkkkkS.o.......S.g.............##.....=kkkkk#
```

- **The Dock (left):** the shaft (end wall and `PillarLeft`, hanging from 4 tiles so you walk in) up to the ledge
  `HighLeft`; a floor pad at the end (x -38) that flings you INTO the shaft one way and 17 tiles onto the `MidLeft`
  quay the other; `HighLeft2` the high route's left stand, a double jump up from the quay's end; `MidLeft2` with a
  3-tile hole to the hub. Three ways up from the floor: the shaft, the pad, a double jump.
- **The centre:** the `Hub` over the start line, the `Crown` over the hub (no open centre, rule 26), and the **Mast**:
  two 4-tile perches at 15 over the hub's ends (8 tiles apart), joined by one swing under the lantern anchor (0, 19)
  released at the top of the swing, each with a swing-drop anchor at 17.5 out onto the high deck beyond. The prize
  ghost orb sits on `MastLeft`. A fall from the Mast lands on the crown, the hub or the mid decks: the slower route
  (rule 28). The hub pad (x -3) lands on `HighLeft2`; running right it is a hop under the crown onto the floor.
- **The Stairs (right):** a 5-tile room to `MidRight2`, a 5-tile jump to the `MidRight` quay, then a stair of single
  jumps: `MidRight` 5 → `StepRight` 8 → `HighRight` 10, beside the shaft. The end pad (x 38) lands on `MidRight` one
  way and flings you into the shaft the other. Three ways up: the shaft, the stair (no double jump spent), a double jump.
- **Stacking:** no high deck sits over a mid deck except the crown and the Mast over the hub, because a strip under 5
  tiles between two decks is a corridor parts may fill (rule 48); the worst case (§2) fills 149 tiles and everything
  stays joined. Keep-clear: the two shafts (floor to 13), the start line under the hub with its hole (x -8..5).
- **Orbs (rule 42, 3 + 3):** ghost: the floor at x -64 and x 70 (the Studio dummy ghosts reach only the floor), the
  Mast. Living: the floor at x 30 (the dummies' patrol lane, for solo tests), `MidLeft`, `HighRight2`.
- **Anchors (rule 17), 7, each PROVEN to carry a swing deck to deck by `maps.test` (the real Movement and Grapple, every
  release point, with and without the double jump):** (-26, 13) `HighLeft2` → `HighLeft` (short: `MidLeft`); (-16.5, 8)
  `MidLeft` ↔ `MidLeft2` (and a speed swing along the floor under it); (-12, 17.5) `MastLeft` → `HighLeft2`; (0, 19)
  the lantern, `MastLeft` ↔ `MastRight`; (12, 17.5) `MastRight` → `HighRight2`; (17.5, 8) `MidRight2` ↔ `MidRight`;
  (26, 13) `HighRight2` ↔ `HighRight` (short: `StepRight`).
- **What the simulation taught (the numbers behind the layout):** with H30's launch (115 across ramped and glided,
  120 up) a pad arc with the double jump at its apex is above 5 tiles from 9 to 16 tiles out, peaks 7.3 at 12 and
  lands 17 out, so a fed deck starts 9 tiles from the pad (nearer is a head-bonk at the apex) and reaches past 17.
  (H29's launch, 100 / 105 and the plain bleed, landed 12 out.) A release's air speed decays to the run within ~0.5 s,
  so a swing carries ~10 tiles: an anchor centred over a 5 to 10 tile gap carries both ways; over 12 it drops you
  under the far deck's lip. A low anchor in a 3 or 5 tile hole never lifts a floor runner onto the deck (the pendulum
  returns to its start height and the deck edges break the rope), so the two "swing up onto the hub" anchors of H27
  are gone.
- **Map boost pads (§2 kit), 3, permanent:** built by `server/Placement` as placed pads owned by 0 (no runner) in the
  same state as ghost pads, at boot and after every round start's reset: every client mirrors and launches from them
  exactly like a ghost's pad (no new client code, no remote), a ghost part can never cover one, a late joiner gets
  them in `syncTo`.
- Plain grey parts as before; the Yard's look is the art block's (after this PR in the §12 order).

## 4. The shrink per map (DESIGN §6.8)

`shared/Walls` takes `{ lo, hi }` and is unchanged. Horizontal only is right for the Yard because it is wide and only
two screens tall; the proposal's 150 studs would let a closed box hold two runners three screens apart vertically.
**The Tower** (vertical) needs a floor and a ceiling band: `window` gains `bottom` and `top`, `shared/Walls` a second
axis (its own close, follow and `outside` with hysteresis, → S16), `MatchState.window` two more numbers, `client/Walls`
a band drawn top and bottom. That is the Tower PR's trigger 2, not this one's.

## 5. The test map, kept

`shared/MapTest.lua` is the hand-built arena of H1-H26, data unchanged except the one keep-clear zone of §2. It stays
so a system can be checked against the arena it was tuned on (`Config.MAP = "test"`), and its data feeds grapple.test
and maps.test like any map.

## 6. What the server trusts

Nothing new. No remote; the map is static data both sides could read but only the server builds; pads launch through
the existing placed-pad path (placement.md §3: inside `MoveCheck`'s budget by construction); the walls read
`Arena.WINDOW` as before. The map's keep-clear zones reach clients in the existing `zones` payload.

## 7. Verification (2026-11-07, H27)

- `npm test`: 13 node tests and 16 Luau files pass (`maps.test.luau` new; `grapple.test.luau` stands under every
  anchor of every map); `npm run lint:luau` clean. Rojo: the tree only gained `Shared.Maps`, `Shared.MapYard`,
  `Shared.MapTest` (ModuleScripts); `rojo build` ok.
- **Studio Play (solo, 3 dummies):** the first Play errored (`blocks is not a valid member of Folder "Map"`: a local
  Folder named `map` shadowed the map data inside `Arena.build`; lint cannot see it, → T16); fixed. Then: `map "yard":
  18 parts, 8 grapple anchors, 3 pads, window x -176..176`, `34 static boxes ..., 3 map pads`; rendering 236 frames/s;
  the three pads replicated; running left from the start line the runner hit the floor pad at x -112 (`pad: launched
  off pad 1`; vy 103, vx -99 on the Heartbeat log) and landed on `CoverLeft`; a screenshot showed the left end as
  drawn here (shaft, pillar, `MidLeft` with its orb, `StepLeft`, the lime pad). The end phase came at 83 s with two
  dummies left: `walls: closing in: centre 31.9, half-width 44.0 -> 24 over 20s, in x -176..176` (the Yard's
  window); the round ended by a burn-out and round 2 started. After round 2's reset the server held exactly 3 pads
  (rebuilt, not doubled) and the client launched off the right floor pad (`pad: launched off pad 2`, vy 98), so the
  mirror is refilled after the round's `sync`. Walking into `CoverRight` stopped the runner (a hop, as meant); the
  Studio dummies walk through the covers (server boxes, Studio only). Not seen: a two-client Play, the grapple's high
  route, a ghost placing on the Yard (the QA reviewer drives those).

## 8. Next

The Tower (the vertical shrink, §4), then the Warren and the Rooftops (pits need the dummies off the floor and a
fall-out rule), then a per-round rotation (rule 30). Deferred from placement.md §5: pockets' mouths as keep-clear
zones is now enforced by the filled test for every map.
