# QA goals: ghosts v2 placement (fixtures, boost pads, the boost grant, keep-clear zones)

Branch: `claude/friendly-hawking-74891i`. Handoff H22 (the build), PR 4 of `docs/systems/ghosts-v2-proposal.md` §12,
from H16 (the adopted spec) after PRs 1-3 (built, QA'd 8/10, signed off on keyboard and mouse by Danzo 2026-10-31).
Design: `docs/DESIGN.md` §3 rules 15 (a pad refreshes dash and double jump), 46 (the grant never stacks with the
ramp), 47 (placement), 48 (maps and keep-clear zones); 39 and 42 for the ghost pool. Spec: proposal §3 (the three
rows), §5 (placement and the map rule), §8 (trust). System doc: `docs/systems/placement.md` (new for this PR); orbs
and the slot stay in `ghosts.md`, Use and holds in `items.md`.

The question for this loop: **can a ghost put a tetromino and a boost pad in the world where it stands, see
before placing whether the server will take it, and never seal a corridor; does a pad launch the living fairly and a
grant speed them up without ever stacking on the chaser ramp; and does the server, not any client, decide every
placement, every fade and every grant?** Solo in Studio the other runners are server-driven boxes
(`Config.STUDIO_DUMMIES = 3`); dummy ghosts take the left floor ghost orb and place what they roll where they stand.

## Goals

1. **The ghost pool is the spec's (rules 39, 42; proposal §3).** fixture 30 / pad 15 / grant 15 / crate 12 / trap 10 /
   ice 10 / hex 8, rolled on the server. A fixture's tetromino (one of all seven, equal odds) is rolled with it and
   travels in the `orb` event and `sync`, so every screen knows the piece.
2. **Placement (rule 47, proposal §5).** Use with a fixture or pad held places it: a fixture one tile ahead of the
   ghost's front edge on the tile grid, at its feet (hovering on the nearest tile line mid-jump, so a ghost jumps to
   place high); a pad centred at its feet, its arrow the ghost's facing. The grapple input (W / C / ↑ / right click /
   RT; the GRAPPLE touch button, reading ROTATE) turns the piece in 90° steps; `UseItem` carries the rotation 0-3.
   Valid only in empty space: clear of map, pieces, pads, orb spots, keep-clear zones, and at least 1
   tile from every LIVING runner; never over a ghost's own box (a solid piece would trap it). A refused place costs
   nothing (the item stays) and Studio says why.
3. **The preview tells the truth.** A held piece or pad previews where the server would put it, pale violet when the
   server would take it and red when it would refuse, running the same pure fit test (`shared/Placement.fits`) on
   the client's mirror of the server's state; the keep-clear zones show faintly while a part is held. A refused Use
   should be rare and never surprising.
4. **The map rule (rule 48).** Nothing placed overlaps a keep-clear zone, so no stack of pieces from any number of
   ghosts can seal an exit or corridor (a box test, no path search; `placement.test.luau` fills a room with 45 pieces
   from 15 ghosts and the shaft stays open). The test arena marks its one corridor, the wall-jump shaft between the two
   walls (x 68-96, floor to 3 tiles above the left wall), plus a box over each orb spot (no spawn boxes since round 1).
5. **Fixtures are solid map for everyone**, ghosts included; permanent for the round; at most 3 live per ghost, a 4th
   starts that ghost's OLDEST fading (half-transparent, still solid) for 1 s, then it goes. One Part per row run so a
   runner on top never catches a seam; the runners' probes see them as walls and floors (→ T11).
6. **Boost pads (rule 15, 16).** Lime slab with an arrow, lasts 20 s, not solid. Anyone (ghosts included) who ENTERS it is
   launched along the arrow at 100 studs/s (speed already carried that way is kept, never cut) and up at 105
   (2 x the jump speed; the rise measures 11.4 studs, under a held jump's 14.25), with dash and double jump refreshed.
   Not in a hold. The ghost that sets a pad under its own feet is not launched (no entry). The launch stays inside the
   server's speed check by construction: a 10 s pad chain with a double jump and a dash on every landing, with the
   grant on, is never flagged (`move_check.test.luau`).
7. **The boost grant (rule 46).** Used by touch like the hex: the ghost's path reaches a living runner's box (a tag's
   reach, judged on the server's own record, the path swept), the runner gets +15% run speed for 5 s (a second grant
   restarts, never stacks), the ghost's slot empties. On the holder boost = max(ramp, grant): the grant equals the
   ramp's top, so a granted holder reaches the top sooner and never above it. Help, not a hold: no ward, no i-frames,
   a frozen or trapped runner is still granted. The granted runner sees "BOOST +15%  n.ns", everyone sees an orange
   halo behind its sprite.
8. **Server decides everything (rule 6, §8).** The spot is the server's newest TRUSTED sample of the ghost and the
   facing its stream reports; the shape is the one the server rolled; the fit test runs on the server's own state and
   its own record of every runner; fades and pad expiry are on the server clock; the grant is the server's touch.
   The only client words: the rotation (0-3) and the press. A client cannot place from a position the server did not
   record, place what it does not hold, choose its shape, place over anything, or grant by claiming.
9. **Readable (rules 2, 12, 29).** Pieces violet, pads lime with a tilted arrow, the grant an orange bar over the
   holder's head and an orange halo on the granted; the ghost line names what to do with each ("Use places it ahead,
   grapple turns it (red: no room)"). Placeholder parts until the art block (behind `Sprites.Has`, like H21).
10. **Pure where it can be pure, tested.** New `shared/Placement.lua` with `placement.test.luau` (shapes, spot, fit,
    the map rule, the cap and fade, the pad); `Tag.speedMult`, `Items.grants`, `Movement`'s launch, the pad chain in
    `move_check.test.luau`, the pool and piece in `orbs.test.luau`. `npm test`, `npm run lint:luau`, `rojo build` pass;
    the Rojo tree only gained three ModuleScripts; no new remote; the line ceiling holds (`server/Match.lua` untouched).

## Seen by the builder (Studio, 2026-10-31)

Dummy ghosts placed fixtures O, Z, L, S, T (every rotation) and pads; a 4th piece faded the oldest; grants landed on a
dummy and on the player; every refusal reason printed; a placed T piece stopped the player's runner. NOT yet seen: a
player launched by a pad, the preview on a player's screen, the ROTATE press. The reviewer should drive those first.

## Out of scope

Real maps and their keep-clear data, rule 3's map shrink (PR 6); ignition and end-phase speed (PR 5); the living
grapple (its own movement PR); art for pieces, pads and the grant (the next routine block); map boost pads as part
of map data (PR 6: this PR's pad is the ghost's placed one, which is what a map pad will reuse); the vanilla toggle
(rule 49); the phone and pad feel (parked by Danzo 2026-10-31).

## Calls for Danzo (made by the builder, recorded in placement.md §5; say if any feels wrong)

- A fixture goes one tile AHEAD of the ghost (proposal §5), not under it (DESIGN rule 47's "where the ghost stands"
  reads loosely); a pad goes under it. Both are placed at the ghost's feet on the tile grid.
- All seven tetrominoes, equal odds, no flip.
- Pad launch 100 across / 105 up (a rise of 11.4 studs); pad life 20 s; pads are not solid.
- The test arena's keep-clear zone is the wall-jump shaft only; orb spots are also kept clear (spawn boxes dropped in round 1).
- Pads launch ghosts too (the spec's "anyone may use it").

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard and mouse)

Set `Config.STUDIO_DUMMY_TAGS = false` first so you can burn out and become a ghost without being tagged back at the
fuse cap; put it back to `true` before committing. As "it" at round start, stand still 45 s: you are a ghost.

1. As a ghost, run through the ghost orb on the left floor (x -40, a violet ball). Most rolls are now PIECE, BOOST PAD
   or BOOST. The HUD ghost line says what to do with it; an icon floats over your head.
2. PIECE: a pale violet tetromino previews one tile ahead of you. Press W (or C, ↑, right click) to turn it. Walk
   toward a wall, a platform, an orb or a runner: it turns red. Jump and press E mid-air: it hovers on the tile line.
   Press E on the floor: a violet block lands exactly where the preview was. Run into it: it is a wall; jump on it: a
   floor. Place three, then a fourth: the oldest goes half-transparent for a second, then vanishes.
3. Walk into the wall-jump shaft with a piece held: the faint red zone shows and the preview is red everywhere in it.
4. BOOST PAD: press E: a lime slab with an arrow appears under you, nothing happens to you. Come back living (next
   round, or watch a dummy): running onto it throws you along the arrow and up, and your dash and double jump are back.
5. BOOST: as a ghost touch a living dummy: it gets an orange halo for 5 s. As a living runner, get touched by a dummy
   ghost holding one: "BOOST +15%" on your HUD and you are faster for 5 s; as the holder late in a chase it changes
   nothing (the ramp is already there).
6. Two-player, if there is a second keyboard: a ghost's piece blocks the other player; a pad launches them; a grant
   speeds them; the preview on the ghost's screen matches where the piece lands on the other screen.
