# QA goals: maps (H27, ghosts v2 PR 6: map data, the Yard, per-map window bounds)

Branch: `claude/friendly-hawking-74891i`. Handoff H27 (the build), after PRs 1-5b and the grapple, all signed off by
Danzo (2026-11-07). Design: `docs/DESIGN.md` §3 rules 25-30 (maps), 17 (anchors), 42 (orbs), 47-48 (placement and
keep-clear), 51 (the map shrink), §6.8 (answered for the first map). Spec: `docs/systems/ghosts-v2-proposal.md` §5,
§6, §12 item 6. System doc: `docs/systems/maps.md` (the four decisions, the map rule as a test, the Yard, the shrink,
what was seen). Earlier loops whose PRESERVE lists must still hold on the new map: `ghosts-v2-placement-summary.md`,
`ghosts-v2-walls-2-summary.md`, `grapple-summary.md`.

The question for this loop: **is the Yard a real map to play tag on, built from data every system reads unchanged,
and does nothing that worked on the test arena break on it?** In practice: can a runner reach every orb, anchor and
tier with run and jumps alone, and get back; are the high and low routes visible from each other; do the pads, the
anchors and the shafts each earn their place; can ghosts build cover without ever sealing a route; do the closing
walls stay inside the Yard's end walls; and does flipping `Config.MAP = "test"` bring back the old arena exactly.
Solo in Studio the other runners are server-driven boxes (`Config.STUDIO_DUMMIES = 3`).

## Goals

1. **The format (maps.md §1).** A map is pure data in `shared/` (`MapYard`, `MapTest`); `shared/Maps` is the format,
   the registry (`get` falls back to the Yard), `orbs` (ghost spots first) and `static`. `server/Arena` loads
   `Config.MAP` and exposes the same fields as before; no dependant (Walls, Match, Placement, Server, client Grapple)
   changed a call. `shared/` stays pure; nothing new on the wire.
2. **The Yard (maps.md §3).** 88 x 24 tiles, three tiers (0, 6, 12 tiles), the hub and crown over the start line (no
   open centre), wall-jump shafts at both ends up to corner ledges (one-way drops), 3 ghost + 3 living orb spots, 8
   anchors (mid gaps, beside the hub, the high route in two swings each way), 3 permanent map pads, two cover blocks.
3. **Reachable, no dead ends (rules 18, 25-26).** `maps.test.luau`'s weak runner model (rise 6 of the real 7 tiles,
   10 tiles drift, kicks only between two walls, no dash, grapple or pad) reaches every start place and orb from the
   spawn and back; every anchor has a reachable stand that picks it through the real camera framing.
4. **No sealing (rule 48).** Every passage under 5 tiles that is not keep-clear filled at once (any number of
   ghosts): every orb and anchor stand still joined both ways. Mutation: the Yard without its zones fails. The test
   map gained one zone (the gap under `PlatformMid`) because it failed the same test.
5. **The window (§6.8).** `window = { lo, hi }` per map, the end walls' inner faces (the Yard: x -176..176); the real
   `shared/Walls` driven over a pack running end to end never puts a wall past it. Horizontal only; the vertical shrink
   is the Tower's PR (maps.md §4).
6. **Map pads.** Built by `server/Placement` as permanent placed pads owned by 0, at boot and after every round
   reset, after the round's `sync`: every client mirrors and launches from them like a ghost's pad; no ghost part can
   cover one; a late joiner gets them; never doubled across rounds.
7. **The server decides (trigger 3).** Nothing new is trusted: no remote, pads launch through the existing path
   (inside `MoveCheck`'s budget by construction, placement.md §3), the walls read `Arena.WINDOW` as before.
8. **Preserved.** Placement (the fit test, keep-clear refusal and preview, the 3-cap), the walls (grace, hysteresis,
   the moving box), the grapple (pick, the banner inset: grapple.test now checks every map's anchors), orbs and the
   dummies' floor orbs, the start line spread, PR 5's list.
9. **Verification.** `npm test` (13 node, 16 Luau files; `maps.test.luau` new), `npm run lint:luau` clean, the tree
   only gained `Shared.Maps`, `Shared.MapYard`, `Shared.MapTest`; `rojo build` ok.

## Seen by the builder (Studio, solo, 3 dummies)

The first Play errored (a local Folder shadowed the map data in `Arena.build`, → T16), fixed. Then: `map "yard": 18
parts, 8 grapple anchors, 3 pads, window x -176..176`; rendering at 236 frames/s; a run left hit the floor pad
(`pad: launched off pad 1`, vy 103) and landed on `CoverLeft`; the end phase opened the walls `in x -176..176`; round
2 rebuilt exactly 3 pads and the client launched off the right one (`pad 2`). **Not seen:** two clients, the grapple's
high route, a ghost placing on the Yard, a phone. The reviewer starts with those.

## Out of scope

The Tower, Warren and Rooftops; a vertical shrink; a per-round rotation; the Yard's art (the art block is next in the
§12 order); the dummies climbing (they walk the floor and through the covers, Studio only).

## Calls for Danzo (made by the builder; recorded in maps.md §1; say if any feels wrong)

- **The Yard first**, not the Tower: no new walls maths, closest to what is tuned. Fallback: the Tower next anyway.
- **24 tiles tall, not the proposal's ~37**: two screens, so the horizontal box still forces the duel.
- **3 + 3 orb spots** on a map 1.75x the test arena's width. Fallback: a 4th living spot if orbs feel scarce.
- **Map pads are permanent** (a ghost's lasts 20 s) and lime like ghost pads (rule 29: one colour per meaning).
- **One fixed map** (`Config.MAP`); the test arena stays selectable.

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard, then a phone)

1. Run the whole floor end to end, then the mid tier, then the high tier. Is every tier a double jump from the one
   below, and can you always see the next one up?
2. Climb a shaft at either end (wall-jump between the end wall and the pillar) and drop off the corner ledge.
3. From `HighLeft2`, swing the high route to the crown (two anchors) and on to `HighRight2`. Does each release reach
   the next anchor?
4. Run over the floor pads (x -112, x 108) and the hub's pad. Do they put you on the next tier?
5. As a ghost holding a piece, try to block the shafts (the preview must go red: keep-clear) and build cover on the
   open floor (it should place). Is cover on the Yard useful?
6. Set `Config.END_PHASE_AFTER = 15` and `STUDIO_DUMMY_TAGS = false`: the walls must close inside the end walls and
   the box must keep moving. Put both back (120, `true`).
7. Set `Config.MAP = "test"` once: the old arena must come back as it was. Put it back to `"yard"`.
