# QA round 1: maps (H27) — SCORE 6/10

Reviewer: Opus, solo Studio Play on the Yard with 3 dummies, `npm test`, `npm run lint:luau`. Report verbatim.

---

SCORE: 6/10

The data and server side are solid. The format is clean, the tests have teeth, and nothing new reaches the network. The weaker part is the Yard as a level a player moves through. The shafts can't be entered from the floor. The pads don't reach the tier they are meant to reach. Each next tier sits under the HUD banner, so the high route can't be seen from below.

What I ran:
- `npm test`: 13/13 node, 16/16 Luau files ok, including `maps.test.luau` and its mutation line "no keep-clear zones -> ghost orb (-144, 2.5) is not reached".
- `npm run lint:luau`: clean.
- One solo Studio Play on the Yard with 3 dummies, stopped at the end.

What Studio showed:
- Output: `map "yard": 18 parts, 8 grapple anchors, 3 pads, window x -176..176` and `34 static boxes ..., 3 map pads`.
- Server fixtures: `Pad@-112,0.5`, `Pad@108,0.5`, `Pad@-16,24.5`.
- The floor to the mid tier works with one double jump. I went from x -40, drifting left, and landed on `MidLeft2` at (-59.7, 25.75).
- The end phase opened `walls: closing in ... in x -176..176`.
- I took `ghost orb 1: grant` as a ghost, but it rolled BOOST, so I could not test placing a piece.

GOALS:
- 1 The format: met. `shared/Maps.lua:28-54` is pure. `server/Arena.lua:206-219` exposes the same fields. The edit-mode check gave `Maps.get("nope").name == "yard"` and `#static == 34`. No remote was added.
- 2 The Yard: partial. The data matches `maps.md` §3. But `PillarLeft`/`PillarRight` (`MapYard.lua:28,44`) stand on the floor (y 0..10), so a runner on the floor can never enter a shaft. Screenshot 2 shows the pillar flush with the floor.
- 3 Reachable, no dead ends: partial. The weak model passes for every orb and start place. Each shaft, though, is a pit you can only enter by dropping in from the top, so it has one exit. That breaks rule 48's "every area has 2+ exits", and no test checks it.
- 4 No sealing: met. "12 passage tiles fillable, every place still joined both ways", plus the mutation. One caveat: in `exports/map_yard_filled.txt` the floor orb at x -144 stays joined only through a 1-tile (4-stud) chimney beside the pillar, for a runner 3.5 studs wide.
- 5 The window: met. The test drives the real `Walls`, and Studio printed `in x -176..176`.
- 6 Map pads: partial. Built at boot, never doubled, owner 0 is inside the 3-cap (`Placement.place` only caps fixtures), and they are in `syncTo`. But see the pad FIX: they don't do what the map says they do.
- 7 The server decides: met. Pads use the existing placed path, nothing new is trusted, and `WINDOW` is read as before.
- 8 Preserved: met as far as I could check. placement, walls, grapple, move_check and orbs tests all pass, and `grapple.test` covers the anchors of every map. Placing on the Yard itself was not seen.
- 9 Verification: met for tests and lint. I did not diff the rojo sourcemap.
- Test map: met. `MapTest.lua` matches the old `Arena.lua` at 7df4ac3, plus the one documented keep-clear zone.

PRESERVE (done well, must survive future iterations):
- Maps as pure data with `Maps.static`/`Maps.orbs` derived: every system reads a map unchanged, and a new map is one data file.
- `maps.test.luau`'s weak runner, the worst-case fill and the mutation: it already caught a real flaw in the test map (the gap under `PlatformMid`).
- `exports/map_<name>{,_filled}.txt`: you can look at a map without Studio. They showed me the chimney and the shaft problem in seconds.
- Map pads as owner-0 placed things in the same state: no new client code, no remote, safe for late joiners, safe from being covered by ghost parts.
- `Maps.get`'s fallback to the Yard, and the per-map `window` checked against the real `Walls`.

FIX (done poorly; why it matters; concretely how to fix):
- The shafts are pits sealed at the bottom (`MapYard.lua:28,44`, pillar y 0..10). Danzo's feel item 2 can't start from the floor. The shaft is a one-exit area (rule 48) and a trap for a runner being chased. -> Start each pillar at 3 tiles (`block("PillarLeft", -41, 3, -40, 13)`), so floor runners walk in and the climb becomes a real floor-to-high route. Add a check to `maps.test` that every keep-clear corridor has 2+ reached openings.
- The pads don't land you on the next tier. A pad rises 11.4 studs (`movement.test`) and a tier is 24 studs up.
  - Floor pad at x -112: running left throws you under `MidLeft` (it ends at -120). In the builder's own run you landed on `CoverLeft`, not the mid tier.
  - Floor pad at x 108: it sits under `HighRight2`.
  - Hub pad at x -16..-8: running right throws you straight under the `Crown` (its edge is at -12); running left takes you off the hub, away from the crown.
  - Why it matters: a double jump already reaches every tier, so as placed the pads add only speed and a likely head-bonk.
  - Fix: move each pad so its arc (vx 100, vy 105, plus the refreshed double jump) clears the next deck's edge. Example: the hub pad at the hub's far end facing outward, or the floor pads 2-3 tiles outside a deck's end rather than under it. Then add a `maps.test` case that runs `Movement` from each pad in both directions (no input, and one double jump at the apex) and asserts it lands on a higher tier.
- Each next tier sits in the HUD banner band (rule 28). With `CAMERA_VIEW_HEIGHT` 48 and `CAMERA_Y_OFFSET` 4, a runner on the floor sees up to y ≈ 29.75. The 24-stud mid deck sits in the top 6 studs, under "X is it", as in screenshot 1. The high tier is invisible from the floor. The same is true from mid to high. -> Space the tiers 5 tiles apart (20 studs; the weak model's 6 and the real 7 both still clear it), or raise the camera when grounded under a deck. Add a test that every tier is visible below `GRAPPLE_INSET_TOP` from the tier beneath it.

CONSIDER (fine but could change; why; how):
- The worst-case chimney: once the floor gaps are filled, the x -144 floor orb exits through a 4-stud column beside the pillar (cols 5, rows 0-6 in `map_yard_filled.txt`). It is "joined" in the model, but it is a pixel-precise jump in practice. -> Make the passage width the test requires the runner width plus a tile, or widen the keep-clear to -38 tiles.
- `HighLeft2` and the `Crown` sit almost directly over the deck below (4-stud and ≤1-tile offsets). You have to jump straight up and then drift, or you bonk the underside. My one drive from `MidLeft2` toward `HighLeft2` fell to the floor at (-119.4, 1.8). The fuse ran out during it, so this is inconclusive. -> Offset the high decks by 2+ tiles from the deck below.
- Rule 28 needs a slow route to fall back to, not only to look at. Today the mid tier is mostly separate decks over open floor. -> Fine for now; revisit with the art block.

UNCERTAIN (could not verify):
- A ghost placing on the Yard, including the shaft keep-clear preview going red. My orb rolled BOOST, not a piece.
- The high-route swings: whether each release from anchors 5-8 reaches the next. `grapple.test` checks the stands, not the chain.
- Anchor 2 at y 20, below the hub's top: whether a swing really carries you onto the hub.
- Two clients, a player leaving mid-round on the Yard, and a phone.
- `Config.MAP = "test"` in Play. I verified it only by comparing the data.
- The rojo tree diff. I did not run a before/after sourcemap.
- Movement feel generally. Danzo should try by hand:
  - feel item 4, running both ways over each pad;
  - feel item 2, which with the current data he can only do by dropping in from `HighLeft`;
  - feel item 1, whether he can see the next tier past the banner.

---

## Builder decisions

(filled in below after the fixes)
