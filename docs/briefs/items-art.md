# Design brief: items and holds, art and animation

**Written 2026-10-19** from Danzo's /design ask ("item art with animations and the like"). The canvas:
https://claude.ai/artifact/K9dE1GepPSSWB29PKirtyE (five boards: the item set and palette; orbs; bear trap; crate; ice
beam and the frozen slide). As with the runner, the canvas is the reference; shipped frames come from the warehouse
loop (`sprites/`, `scenes/`), one scene per frame, named `<thing>_<state>_<n>`.

## What the canvas settles

- **Style:** the runner's inked graphite with ONE neon edge-light per item. Flat colour, no gradients, no glow: every
  highlight is a straight neon line, 1.5 px shipped (3 px on the 2x boards). Shapes differ first (shard, wire shard,
  kite, cube, blades, lance), colours second.
- **Palette (pass 2, after Danzo's comment "not loving most of these, they don't fit the neon/graphite vibe, sharper"):**
  graphite bodies (ink `#1b1b2f`, facet `#2e3050`) with one thin neon edge-light each, mitred corners, nothing round or
  warm, no soft shine. Living orb = a four-point shard, lime `#b6ff3b`; ghost orb = the same shard as a violet wireframe
  `#9d7bff`; hex = a kite pointing down, magenta `#ff3df2`; crate = a chamfered cube with an orange `#ff8a5b` X brace
  (the rig's alt accent); trap = straight graphite blades, red `#ff3b3b` teeth and plate line; ice = a dead-straight
  cyan `#45e0ff` lance with triangular spikes (bluer and darker than the visor `#7df9ff`). Pass 1 (gold ball, brown
  wood, arcs) is superseded.
- **Pass 3 (Danzo's five canvas notes, same day):** both orbs are ORBS again and shinier: a graphite sphere with a lime
  rim light, a lime equator band that turns on the spin, a hard white specular; the ghost orb the same as a violet
  wireframe with a white specular arc. The hex is the pass 1 diamond (inked inner diamond, rune cross) in magenta.
  The ice beam is softened: still straight, round ends, low rounded crystals, no spike tip. Crate and trap stand from
  pass 2. Danzo on the shard spin: "i like the way these animations are done, keep some of that spirit": the turn
  still reads as one bright line at the half-way frame, the shatter is geometric (quarters + one ring).
- **Timing keys** (frames are holds, no in-betweens unless said):

| Thing | Frames | Timing |
|---|---|---|
| Orb idle | 4, loop: the equator band turns 0°, 45°, edge-on (a line, glint ticks), -45°; the light is fixed | 1.0 s; the ghost orb is wire |
| Orb taken | 4 (white flash in a ring; splits along its seams: the cap lifts with the specular, the band rings out, two curved shell pieces drop; band widens, pieces fade, core bursts into 4 ticks; faint spot) | 0.25 s, ~0.06 s each; spot faint until respawn. Danzo: "use the geometry of the orb to split" |
| Hex | still; a ring breathes out every 0.8 s only while the ward is down; cracks in two on touch | no idle spin |
| Trap | armed open (flat, wide), snap (2 frames, 0.12 s), shut (tall, teeth meshed, dust), pried one notch per press | 1 s timeout ends on frame 0, dust, gone |
| Stuck pose | A yank back / B lurch forward, ping-pong at 8 fps; caught foot is always the FAR leg; release = 2 dash-lean frames | head leads the struggle |
| Crate | intact, hit (skews away, crack, 0.05 s), burst (planks go the runner's way, 0.08 s), settle + fade (0.07 s) | 0.2 s total; jumped = no frame change |
| Stumble | 3 holds: trip 0.2 s (20°), tumble 0.3 s (40°, head below shoulders), recover 0.2 s (10°, crouch) | 0.7 s; hands open; brown dust |
| Beam | charge bloom (0.05 s), fire (0.5 s, spine flickers every 2 frames, never turns), fade to frost + 3 shards (0.1 s) | the only long horizontal line in the game |
| Frozen slide | no new pose: a 3 px cyan rim traces WHATEVER frame the runner was on; speed lines + an ice streak that shorten; 8° tip back from 0.4 s; 1 px shiver in the last 0.15 s; thaw = rim bursts into chips, one shake | 1.0 s, slides on momentum |

## Danzo's rule calls made with the brief (2026-10-19)

1. Ice does NOT freeze you in place: a frozen runner slides on, keeping momentum (rule 44 as written).
2. **A frozen tagger cannot pass the fuse** (new: the holder's claims are refused while frozen). A frozen runner can
   still be tagged (rule 44 as written). → handoff H20.

## What to build from it (not yet scheduled)

Orb idle + shatter and the hex cues are client-only particles/sprites (`client/Items.lua`). Trap, crate and beam
frames are sprites on the placed parts. The three runner holds need rig poses in `tools/runner-rig.js` (trapped A/B,
stumble 1-3) plus the frozen rim as a client effect over the current frame. Each is a sheet change → `roblox build`,
Danzo uploads.
