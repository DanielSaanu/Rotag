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

88 x 24 tiles inside its end walls (352 x 96 studs; x -176..176). The proposal's ~340 wide is kept; its ~150 tall is
not (§4). Three tiers, each a double jump above the last and on screen from it (rule 28: from the floor the view
reaches ~7 tiles up, from the mid tier the high one):

```
 15 #.............................A......A................A.....A............................#
 12 #kkkkk.......................................g.......................o..............kkkkk#
 11 #kkkk#######......######..................######..................#######.....#######kkkk#
  9 #kkk#k...............................................A................A.............k#kkk#
  8 #kkk#k..............A...............................................................k#kkk#
  6 #kkk#k.....o.............................=..........................................k#kkk#
  5 #kkk#k.########..........#########..A...##########......#########..........########.k#kkk#
  2 #kkk#k.............####.............................................................k#kkk#
  1 #kkk#k.....##.......................................................##..............k#kkk#
  0 #kkk#k...g.##....=............S.........S.........S....o....S.......##..=........g..k#kkk#
```

- **Floor** at y 0, end to end (the start line, the Studio dummies' lane). **Mid tier** at 6 tiles: `MidLeft`,
  `MidLeft2`, the `Hub` over the start line, `MidRight2`, `MidRight`. **High tier** at 12: `HighLeft`, `HighLeft2`,
  the `Crown` over the hub, `HighRight2`, `HighRight`. One `StepLeft` at 3 and two crate-sized `Cover` blocks.
- **No open centre (rule 26):** the hub and the crown stack over the start line; the middle is a climb, not a field.
- **Wall-jump shafts at both ends:** the end wall and a 10-tile pillar 3 tiles apart, up to the corner ledges, which
  you leave by dropping (one-way drops, rule 26). Keep-clear: the shaft and a tile past the pillar, floor to 13 tiles.
  They are the Yard's only corridors; the filled test proves nothing else needs a zone.
- **Orbs (rule 42, 3 + 3):** ghost: the floor under `MidLeft` (x -144), the crown (the high route's prize), the floor
  at x 144; the two floor ones are the Studio dummy ghosts' (they only reach the floor). Living: the floor at x 40 (the
  dummies' patrol lane, for solo tests), `MidLeft`, `HighRight2`.
- **Anchors (rule 17), 8:** four over the mid gaps and beside the hub (one off the floor: swing up onto the hub), four
  at 15.5 tiles carrying the high route from `HighLeft2` to the crown and on to `HighRight2` in two swings each. The
  one over `StepLeft` sits at 8.75 tiles: at 9.5 it was under the HUD banner from the step (grapple.test caught it).
- **Map boost pads (§2 kit), 3, permanent:** the floor at x -112 and x 108 (up to the mid tier), and the hub's left
  end (up beside the crown). Built by `server/Placement` as placed pads owned by 0 (no runner) in the same state as
  ghost pads, at boot and after every round start's reset: every client mirrors and launches from them exactly like a
  ghost's pad (no new client code, no remote), a ghost part can never cover one, a late joiner gets them in `syncTo`.
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
