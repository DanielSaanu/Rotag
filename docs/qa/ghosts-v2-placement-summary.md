# QA summary: ghosts v2 placement (PR 4, H22) — 7 → 8/10, target met in round 2

Goals: [ghosts-v2-placement.md](ghosts-v2-placement.md). Rounds (verbatim reports): `archive/ghosts-v2-placement-round1.md`,
`archive/ghosts-v2-placement-round2.md`. Both reviewers were Opus subagents with Studio; 2026-10-31.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | Placement, the map rule, server authority and the tests all met; the preview went red for an invisible reason (a spawn box), the grant glow was illegible, the slot and the ghost line named items differently, and no pad launch was seen. |
| 2 | 8/10 | Preview and placement matched exactly; the rotate press, a ghost's own pad not firing under it, a ghost and a living runner launched off pads; the BOOST line was hidden by other status lines, the preview drew between rounds, Neon washed the colours out. |

## Fixed

**Round 1**
- Spawn boxes dropped from `Arena.static`: placed parts are cleared at round start, so a spawn spot needed no
  protection, and it was the one refusal a player could not see. The server now reports 15 static boxes.
- One name per item (`Items.NAME`: PIECE, BOOST PAD, BOOST) on the slot readout and the ghost line.
- The ghost line says why the preview is red ("NO ROOM: map / keep-clear / orb / a piece / a pad / a runner",
  `Place.refusal`).
- A new piece starts at rotation 0.
- The grant glow at 0.3 transparency and 1.6 studs larger.

**Round 2**
- The BOOST line is appended to whatever status line is showing (tag freeze, a hold, "X is it: run!"), so a grant
  mid-chase is seen.
- No preview between rounds (`placing()` checks `state.over`).
- The preview and the glow are plain parts at (160, 140, 255) and (255, 110, 20); Neon read white and yellow. The
  red refusal and the keep-clear zone keep Neon.
- A pad someone else placed launches on the first frame it is touched; only your own pad needs a real entry.
- trust.md §8 records the pad launch as the client's own move inside the budget, and the server-side knob if abused.

## Preserved (confirmed in both rounds)

- One pure, allocation-free fit test (`shared/Placement.fits`) shared by the server and the client preview, with
  the reason carried to the HUD: preview and placement agree by construction (seen exact in round 2).
- The server's placement inputs: its newest trusted sample, the facing from the stream, the shape it rolled; the
  client sends only a 0-3 integer.
- One Part per row run of a fixture: no seam under a runner.
- `Items.listen`: one ItemEvent connection, so Place never misses an early event.
- The pad chain + grant driven through `MoveCheck` in `move_check.test.luau`: "never flagged" is proven, not argued.
- No launch on the frame your own pad appears under you.
- The map rule as a box test plus the 45-piece room-fill test.

## Deferred

- The preview while the ghost is RUNNING can sit up to a tile ahead of where the server (from its newest sample)
  places the piece; exact when still. Revisit if Danzo feels it (both rounds).
- The open floor of a room is not a corridor: hovering stacks could wall a pocket. For PR 6's map data: mark pockets'
  mouths keep-clear too (round 1).
- A Studio-only knob to make dummy ghosts roll only pads and grants (round 2): `STUDIO_DUMMY_TAGS = false` already
  keeps a tester living; not worth a line until asked.

## Pads for ghosts (a call Danzo may overturn)

Pads launch everyone, ghosts included, as the adopted spec says ("anyone may use it", "pads are map"). Round 1 read
"living only" from an early draft of the doc. If a self-launching ghost feels wrong, the one-line change is in
`client/Place.lua` `Place.frame` (skip the pad loop unless `Tagging.isAlive(me)`).

## Open FIX items from the last round

None: the three round 2 FIX items were all applied.

## Danzo's Play checklist (Studio, `STUDIO_DUMMIES = 3`, keyboard and mouse)

Set `Config.STUDIO_DUMMY_TAGS = false` first (back to `true` before committing) so you can burn out: as "it" at round
start, stand still 45 s and you are a ghost.

1. As a ghost run through the left floor ghost orb (x -40). The slot says PIECE, BOOST PAD or BOOST; the ghost line
   says what to do with it.
2. PIECE: a violet tetromino previews one tile ahead. W (or C, ↑, right click) turns it; a new piece is upright.
   Walk it into a wall, the orb or a dummy: it turns red and the line says NO ROOM: map / orb / a runner. Jump and
   press E: it hovers on the tile line. On the floor press E: the block lands where the preview was; run into it (a
   wall), jump on it (a floor). Place a 4th: the oldest goes half-see-through for a second, then vanishes.
3. Walk into the wall-jump shaft holding a piece: the faint red zone shows, the preview is red everywhere in it.
4. BOOST PAD: press E: a lime slab with an arrow under you, nothing happens. Step off and back on: you are thrown
   along the arrow and up, with dash and double jump back. **The feel calls:** 100 across / 105 up; run onto a pad
   from a standstill, then at full sprint against the arrow (the arrow should win), then double-jump at the top.
5. BOOST: as a ghost, touch a living dummy: an orange glow behind it for 5 s. Living, let a dummy ghost holding BOOST
   touch you: "BOOST +15%  n.ns" on your line and you are faster for 5 s; as the holder late in a chase it changes
   nothing.
6. Left click is Use (the controls table): a stray click while holding a piece places it. Say if that bites.
7. Two players, if there is a second keyboard: a ghost's piece blocks the other player, a pad launches them, the
   preview on the ghost's screen matches where the piece lands on the other screen.
