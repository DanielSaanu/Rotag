# QA round 1: ghosts v2 placement — SCORE 7/10

Reviewer: Opus subagent, 2026-10-31, with Studio (about 7 rounds of Play). Report verbatim:

SCORE: 7/10

**What I ran.** `npm test` passes. That includes placement.test.luau ("45 pieces from 15 ghosts… shaft still open") and move_check ("pad chain + grant, 10 s: 12 launches, up budget used at most 2.63 of 10.50"). `npm run lint:luau` is clean. `rojo build` succeeds.

**Studio Play (STUDIO_DUMMIES = 3, about 7 rounds).** As a ghost I picked up ICE, PAD, GRANT ×2, FIXTURE ×4, CRATE and HEX from the ghost orb.
- I placed a pad. The preview sat at x -37.32 and the server logged `placed pad at (-41.3125, 0)`, which puts its centre at -37.31, so they match.
- I placed an O on the floor. The preview covered -32..-24 and the server parts are `Fixture -28,2` and `-28,6`, size 8x4, CanCollide and CanQuery both on.
- Running into it stopped my runner at x -32.95, which is the face of the piece (half-width 1).
- I placed an S mid-jump. It hovered with its bottom at y 12.
- W turned the piece and the preview changed shape. The rotated piece grows away from the ghost.
- A ghost grant landed: `items: 8061215879 granted -1002 the boost for 5s`, and my slot emptied.
- Screenshots ScreenCapture_7, _8 and _9 show the pale-violet preview, the red preview, and readable violet blocks.

**Not seen:** a living runner (me) launched by a pad. Every attempt was cut off by a round ending or by being tagged back.

GOALS:
- Pool (rules 39, 42): met. `Items.POOLS.ghost` matches the spec. The piece travels in the `orb` event and in `sync` (server/Orbs.lua:36, 74). Rolls in Play gave fixture, pad, grant, ice, crate and hex.
- Placement (rule 47): met. Ahead on the grid, hovers mid-air, pad centred, W rotates, and a refusal costs nothing (`use … dropped: no room: map`, item kept).
- Preview tells the truth: partial. It was exact twice while standing still. Of my two red previews, one was a spawn box (-21..-19) and one was the 1-stud platform at y 11. Both were correct, but neither cause is visible on screen. While running, the server places from its newest received sample, so it lags the predicted spot the preview uses (my reasoning, not measured).
- Map rule (rule 48): met. The test passes, the static list is correct (19 boxes, read from Arena.static on the server) and the zone shows at 0.8 transparency while placing.
- Fixtures solid, cap 3, fade: met for solidity in Studio. Cap and fade are covered by tests only (the builder saw them in Play).
- Boost pads: partial. The launch maths is tested and the pad parts look right. The launch was not seen on a player. Also, client/Place.lua:123-135 launches ANY local runner who enters a pad, including ghosts, while placement.md:14 says "anyone living".
- Boost grant: partial. The server touch, slot emptying and max(ramp, grant) all work (Tag.speedMult, client/Tagging.lua). I never saw the orange halo in any capture. It is drawn at 0.7 transparency behind the sprite and was gone when I queried it a few seconds later.
- Server decides: met. Spot from the newest trusted sample (server/Items.lua:91-99), shape from `o.piece`, the fit test re-run on server state (server/Placement.lua:112-133), rotation range-checked (Items.lua:133). The pad launch is client-side but bounded by the speed check, as documented.
- Readable: partial. Pieces and pads read well. The slot says "ITEM: GRANT / FIXTURE / PAD" while the ghost line says "BOOST / PIECE / BOOST PAD". The halo is not legible.
- Pure and tested: met. Three ModuleScripts added, no new remote, Match.lua untouched, tests and lint clean.

PRESERVE (done well, must survive future iterations):
- One pure fit test (`shared/Placement.fits`) shared by the server and the client preview, using caller-owned buffers with no allocation per frame. It is why the preview matched the server exactly.
- Server-side placement inputs: the trusted sample, the facing from the stream and the rolled shape. The client sends only a 0-3 integer.
- One Part per row run for fixtures. No seam was visible, and the runner probes treat them as walls and floors.
- `Items.listen`: a single ItemEvent connection, so Place cannot miss early events.
- The pad-chain plus grant drive in move_check.test.luau. It proves "never flagged" by driving movement rather than arguing it.

FIX (done poorly; why it matters; concretely how to fix):
- Ghosts are launched by pads: Place.frame has no alive check, unlike the doc ("anyone living") and goal 6. A ghost can also step off its own pad and back on to self-launch as a mobility tool. -> Add `if not Tagging.isAlive(me) then return end` before the pad loop (keep the rotate line above it), or record "ghosts too" as a decision in placement.md §5.
- Spawn boxes in `Arena.static` restrict placement mid-round for no gain. Every placed part is cleared at round start (`Placement.reset`), so a spawn box protects nothing, and it is invisible. I hit it on my first fixture and saw a red preview with no visible cause. -> Drop the spawn boxes, or keep them only for map pads in PR 6. If any other invisible box stays, draw it faintly as the keep-clear zone is drawn.
- Grant halo not legible (client/Place.lua:209-212): 0.7 transparency, behind the sprite, at Others' drawn position. -> Lower the transparency to about 0.35, use a rim or outline instead of a box, or tint the sprite. Then check it on a capture.
- Item naming is inconsistent between the slot readout and the ghost line. -> Use one name per item (PIECE, BOOST PAD, BOOST) in client/Items' slot readout.

CONSIDER (fine but could change; why; how):
- Preview against the server spot while running: the server places from its newest received sample, which can be one tile behind the predicted spot at 44 studs/s plus ping. -> Compute the preview from the last snapshot the client sent (what the server will see), or snap the preview while the ghost is moving.
- `rot` persists across pieces (Place.lua:30). My second piece started at rotation 1. -> Reset `rot = 0` on an `orb` event with `by == me`.
- The open floor of the test arena is not a keep-clear corridor. Hover placement lets three ghosts stack pieces tall enough to wall the left pocket, which could pen a holder in. Out of scope for real maps, but worth a line in placement.md for PR 6.
- The red preview gives no reason. -> Show the `fits` reason ("spawn", "orb", "map", "a runner") in the ghost line while the preview is red.

UNCERTAIN (could not verify):
- A living runner launched by a pad in Play: the rise, the carried speed and the refreshed dash and double jump. Danzo should run onto a dummy ghost's pad with his own hands and judge the 100/105 feel.
- The orange halo and "BOOST +15%" on my own HUD while granted. I was never granted.
- The 4th-piece fade in Play (tested only), and pad expiry at 20 s.
- Two unexplained events: a Use and a placement (`placed fixture T at (-8, 0) rot 1`) that I never pressed E for, plus a 22-stud move right during a 60 ms A press. My guess is that the MCP input tool clicked the viewport to focus it (MouseButton1 is bound to Use), but I could not confirm it. Danzo should watch for stray Uses on left-click.
- Behaviour under real latency and with two real clients (goal 6 of the feel list).

## Builder decisions

- **FIX ghosts launched by pads: kept as "everyone, ghosts included", recorded.** The adopted spec (proposal §3) says of the
  pad "Anyone may use it" and "fixtures and pads are map, solid or usable for everyone"; the goals file and
  placement.md §1 had narrowed it to "living" by mistake. A ghost needs mobility to reach the holder (hex, grant), and a
  self-launch costs it the pad's 20 s for everyone else. Docs corrected; placement.md §5 records the call.
- **FIX spawn boxes: dropped from `Arena.static`.** Placed parts are cleared at round start, so the box protected nothing
  and was the one invisible refusal. Orb spots stay (the orb is visible; it must stay reachable).
- **FIX grant halo: transparency 0.7 → 0.3 and 1.6 studs larger than the runner, still behind the sprite** (a glow, not a rim: one part).
- **FIX item names: one name per item.** `Items.NAME` in `client/Items`: fixture → PIECE, pad → BOOST PAD, grant → BOOST;
  the slot readout and the ghost line share it.
- **CONSIDER rotation persists across pieces: fixed** (cheap): `rot` resets to 0 whenever a new placeable item arrives
  in the slot.
- **CONSIDER red preview without a reason: fixed** (cheap, clearly better): `Place.refusal()` gives the fit test's reason
  and the ghost line appends "no room: <why>" while the preview is red.
- **CONSIDER preview vs the server's lagging sample while running: deferred.** The preview is exact when still; while
  running the server may land the piece up to a tile behind. Noted in placement.md §5; revisit if Danzo sees it.
- **CONSIDER the open floor walled by hovering stacks: deferred to PR 6,** one line in placement.md for the map data.
- **UNCERTAIN stray Use on left click:** left click IS bound to Use by the controls table (PR 3); the MCP input tool
  clicks the viewport to focus. Not a bug; noted for Danzo.
