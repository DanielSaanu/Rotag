# Design brief: the Yard, layout and look

**Written 2026-11-09** from Danzo's /design ask ("I figured we would have used /design for this"). The Yard (H27) was
laid out from the written spec and never drawn; QA round 1 scored it 6/10, mostly on things a drawing shows at once. As
with the runner and the items, the canvas is the reference. What ships is map data in `roblox/src/shared/MapYard.lua`,
built by the heavy (trigger 2) and held to `test/luau/maps.test.luau`.

**The two questions for the canvas:** (1) what is the Yard's layout; (2) what does the world look like (DESIGN §6.3:
graphite, neon or glowing graphite).

## What has to stay true

The layout is free inside these. Every number is from `Config.lua` or `docs/systems/maps.md`.

| What | Number | Why |
|---|---|---|
| Size | 88 x 24 tiles inside tall end walls (1 tile = 4 studs) | Wide, not tall, so the closing walls' 12-tile box still forces the duel |
| Screen | 12 tiles tall, about 21 wide at 16:9; the camera sits 1 tile above the runner | Each player's own view |
| HUD banner | hides the top 1.5 tiles | From a tier you can really see about 6 tiles up (rule 28: the high route is seen from the low one) |
| Double jump | rises 7 tiles (the test's weak runner: 6) | A tier gap of 5 or 6 is one double jump |
| Wall kick | two walls 3 tiles apart can be climbed; one wall cannot | Shafts |
| Runner | 2 x 3.5 studs, so under one tile wide | Keep every gap at least 2 tiles |
| Grapple | reach 7 tiles; only on-screen anchors, below the banner | Rule 17; gold, always |
| Boost pad | launch 100 across, 105 up; with the double jump it clears the next tier 7 to 11.5 tiles out | A pad sits about 8 tiles from the deck it feeds |
| Blocks | axis-aligned rectangles only (name, x0, y0, x1, y1); a deck is one stud thick | The data format |
| Counts | 3 ghost orbs, 3 living orbs (two of the ghost orbs on the floor for the Studio dummies, one living orb at x 40 in their patrol lane), 4 start places on the floor, 3 map pads or so, 6 to 10 anchors | Rule 42, maps.md §2 |

**The rules the layout is judged by (DESIGN §3):** vertical loops with 2-3 exits (25); no open centre, no dead ends,
one-way drops break infinite loops (26); no camping spots (27); visible high and low routes, a mistake drops you to the
slower one (28); colour-coded anchors, pads and hazards (29); every exit and corridor is keep-clear, every area has 2+
exits (48).

## What QA found (fix these on paper first)

- **Shafts were sealed pits** at the floor. Enter them on foot.
- **Pads aimed at nothing:** they launched you under the next deck. A pad needs open air above its landing path.
- **The next tier hid under the banner** at 6-tile spacing.
- **The stacking trap (the failing test today):** a deck sits on one row, so decks 5 tiles apart leave a 4-tile strip
  between them, which counts as a corridor (under 5 across). Ghosts may fill a corridor unless it is keep-clear. Where a
  high deck sits right over a mid deck, filling that strip walls in whatever is on the mid deck
  (`exports/map_yard_filled.txt`, both ends). Either stagger stacked decks, or mark the strip keep-clear.
- **Consider:** high decks almost directly over the deck below make you bonk; offset by 2+ tiles.

## What exists to match

Runner and items: inked graphite (ink `#1b1b2f`, facet `#2e3050`), one thin neon edge-light each, flat colour, straight
lines, mitred corners (`docs/briefs/items-art.md`). Accents already spoken for: visor `#7df9ff`, living orb lime
`#b6ff3b`, ghost orb violet `#9d7bff`, hex magenta `#ff3df2`, crate orange `#ff8a5b`, trap red `#ff3b3b`, ice cyan
`#45e0ff`, grapple anchors gold, the closing walls red. The world must sit behind all of that and never compete.

## What to draw

1. The current Yard to scale, with what is wrong marked.
2. A proposed layout (or two) to scale, routes drawn on it, every number above kept.
3. One screen as a player sees it (runner, HUD banner, next tier visible), in each of the three themes.
4. The chosen direction's kit of parts: deck, wall, pillar, cover, the background.

## Status

**Canvas:** https://claude.ai/artifact/5y52CKT5B2hhTmv5mJuymk (three boards: the Yard today, a proposed staggered
layout, one screen in each theme; the kit board waits for the theme). The staggered layout passed all 16 Luau test files
in a scratch copy on 2026-11-09; `MapYard.lua` itself is unchanged by this brief.

**2026-11-11 (H29):** Danzo asked for "plenty of routes, feels fun, a plethora of options on where to go". The layout
was built (not the staggered board: a fourth tier, the Mast, asymmetric ends, end pads into the shafts) and is in
`MapYard.lua`, held by `maps.test` including every pad arc and every swing: `docs/systems/maps.md` §3, goals
`docs/qa/yard-routes.md`. The theme (question 2) is still Danzo's to pick on the canvas.
