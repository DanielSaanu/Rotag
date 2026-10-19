# QA goals: ghosts v2 items (living orbs, Use, the holds: crate, bear trap, ice beam)

Branch: `claude/friendly-hawking-74891i`. Handoff H19 (the build), from H16 (the adopted spec) and H18 (PR 1, built and
QA'd 7/7/8). Design: `docs/DESIGN.md` §3 rules 41 (the per-target ward), 42 (orbs), 43 (the living pools), 44 (holds),
45 (dash i-frames); rules 10 and 11 for context. Spec: `docs/systems/ghosts-v2-proposal.md` §12 item 2 (this PR), §3
(the abilities), §4 (holds, casting, the dash), §8 (trust). System doc: `docs/systems/items.md` (new for this PR);
ghosts stay in `docs/systems/ghosts.md`.

The question for this loop: **does the living half now play with items (grab an orb, Use it, see it land), are the
holds short, fair and never chained, does the dash dodge what it should and nothing else, and does the server, not any
client, decide every use, every hit, every hold and every pry?** Solo in Studio the other runners are server-driven
boxes (`Config.STUDIO_DUMMIES = 3`); they take living and ghost orbs on the floor and use what they roll.

## Goals

1. **Living orbs and pools (rules 42, 43, 10).** Living-orb spots on the test arena, their own kind (ghosts cannot take
   one; the living cannot take a ghost orb). First at 0:05, back after 10 s. The server rolls the taker's pool with an
   injected random source: a runner rolls crate 40 / trap 35 / ice 25; the holder ice 50 / crate 25 / trap 25. The
   ghost pool gains crate 12 / trap 10 / ice 10 beside the hex 8, so the hex is now 1 roll in 5 (it was every roll):
   the PR 1 "hex stream" is diluted, as Danzo chose (option a). The pools live in the new pure `shared/Items.lua`.
2. **Use (rule 42, proposal §8).** New remote `UseItem`, client → server, one small integer (0-3; the fixture rotation
   later, ignored now). The spot is always the server's own record of the user (newest trusted sample and facing),
   never a client position. Bound minimally: E, V, RB / R1, left click, an ITEM touch button. A crate drops behind
   you, a trap at your feet, an ice beam goes 24 studs ahead the way you face for 0.5 s and does not turn. A hex is
   still used by touch (PR 1's `GhostClaim`); Use with a hex does nothing.
3. **Holds (rule 44, rule 11).** Crate: stumble 0.7 s (carry on at half run speed, no steer, jump, dash or item);
   the crate breaks. Ice: freeze 1 s, sliding on your momentum, which bleeds to 0. Bear trap: pinned up to 1 s, or
   3 presses (any key or click; 3 taps anywhere on touch) pry it open sooner. After any hold (and after the tag
   freeze) 0.5 s in which no new hold lands. No item can be started during a hold (or the tag freeze); one started
   before goes off in full (a beam out stays out). **A hold never stops a tag** (a trapped runner can still be tagged).
4. **Dash i-frames (rule 45).** The first 0.2 s of a dash dodges an ice beam and the hex and carries you over a bear
   trap; never through a crate (jump it), never a tag. Judged from the dash seen in the server's snapshot record, with
   the 0.8 s dash cooldown enforced on the server, so a client cannot claim to dash for ever.
5. **No ganging up (rule 41).** A runner hit by a ghost's aimed ability (ice beam, hex) is warded from every ghost's
   aimed abilities for 6 s. Ghosts pass through crates, traps and beams (items touch the living only).
6. **Server decides everything (rule 6, §8).** Uses, hits, holds and pries are all judged by the server on its own
   clock and position record. The victim's client applies the hold it is told about; the server's speed check
   (`shared/MoveCheck`) shrinks that runner's budget to the hold's allowance for its length, so a client that ignores a
   trap is snapped back and its samples go untrusted (cannot tag). An untrusted sample still gets hit (a cheat never
   escapes a hazard by being suspect) but never places or collects.
7. **Readable (rules 2, 12, 41).** Orb, hex, crate, trap and ice read apart at a glance (one palette, distinct shapes);
   placed things and beams drawn on every screen; the held item over every head; a slot readout for the local runner
   (living too now); a hold shows on the victim (a status line, e.g. "TRAPPED: mash to break 1/3"). Carried from PR 1's
   QA: the ward halo flashes red ~0.3 s as the ward ends, and the halo colour resets when the marker hides.
8. **Pure where it can be pure, tested, mutation-checked.** New `shared/Items.lua` with `items.test.luau`; movement and
   move_check additions (the hold input; the hold budget; an orb pickup on a tolerated teleport bounded by the same
   ~45 studs as a tag, carried from PR 1's QA). `npm test`, `npm run lint:luau`, `rojo build` pass; the Rojo tree only
   gained instances (`Remotes.UseItem`, new ModuleScripts); the line ceiling holds (`server/Match.lua` only wires).

## Out of scope

Fixtures, boost pads, boost grant, placement, keep-clear zones (PR 4); the full controls table, both keyboard schemes
and the grapple input (PR 3); ignition and end-phase speed (PR 5); real maps and off-screen orb pointers (PR 6); the
vanilla toggle (rule 49); real art for orbs and items (placeholder neon shapes); scoring (§6.4); the tag freeze as a
speed-check hold (trust.md §8 names it, not this PR).

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard, then the phone preset)

1. Run through a living orb (gold ball) at 0:05: your slot reads CRATE, TRAP or ICE, an icon floats over your head.
   As "it" you mostly get ICE.
2. Press E (or V, left click, RB): a crate drops behind you / a trap at your feet / a cyan beam shoots ahead. The
   slot empties.
3. Run into a dummy's crate: you stumble forward at half speed for under a second, it breaks. Jump it instead: nothing.
4. Step on a trap: you stop dead; mash any key three times and you are out in well under a second; do nothing and it
   lets go after 1 s. Dash over a trap: nothing. Dash into a crate: you still stumble.
5. Get frozen by an ice beam: you slide to a stop over a second, no input. Dash through a beam as it fires: no freeze.
6. Straight after any hold you cannot be held again for half a second (nothing chains), and while held, Use does nothing.
7. While trapped or stumbling as a runner, the holder can still tag you. As the holder, a trapped you can still tag.
8. As a ghost: grab ghost orbs; most rolls are now crate, trap or ice, the hex is about 1 in 5. Your items never
   touch other ghosts, and the dummies' hexes no longer stream.
9. Phone preset: the ITEM button is reachable, out of the lower-middle, over 44 px; 3 taps anywhere break a trap.
