# Ghosts: what an eliminated player does (ghosts v2, PR 1: no comeback, ghost orbs, the hex)

**Created:** 2026-10-14 (H15). **Rewritten 2026-10-19 by the heavy agent (H18)** for ghosts v2 PR 1. Design: DESIGN
§2 "Elimination: ghosts", §3 rules 37-42 (rule 49, the vanilla toggle, is later). The spec and the remaining five PRs:
[ghosts-v2-proposal.md](ghosts-v2-proposal.md) §12. The tag this builds on: [tag.md](tag.md). Remotes: [README.md](README.md).
QA goals: [`../qa/ghosts-v2-core.md`](../qa/ghosts-v2-core.md). H15's spook, mark and comeback (built 2026-10-14, removed
here) are in git at `df94334`; DESIGN §6.1 keeps their one-line summary.

**Status:** built, not yet QA'd. Rules tested outside Studio (`ghost.test.luau`, `orbs.test.luau`, mutation-checked, §8).
Server path seen in Studio solo Play with three dummies (§8). **Not yet seen: anything on a client** (orbs, the item
over heads, the slot readout, a player's own hex): the running `rojo serve` predates `Remotes.ItemEvent` (→ T6).

## 1. The rules (DESIGN §3 rules 37-42) and their numbers

- **A ghost** is a runner eliminated in this round: its own body, in place, with the whole movement kit (no grapple
  once it exists). It passes through runners, collides with the map, cannot tag, be tagged or hold the fuse.
- **No comeback (rule 38).** A ghost stays out until the next round. `Tag.tick` has no `back` any more; every
  elimination still shrinks the next fuse, so a 4-runner round with no passes is at most 45 + 35 + 25 = 105 s.
- **Ghost orbs (rules 39, 42).** Fixed spots of their own (`Arena.GHOST_ORBS`, three on the test map). Only a ghost may
  take one. None before `ORB_FIRST` (5 s) into the round. A taken orb is back after `ORB_RESPAWN / (1 + GHOST_ORB_RAMP x
  ghosts)` = 10 / (1 + 0.5 n) s: 10, 6.7, 5, 4 for 0-3 ghosts, **recomputed every frame with the ghost count now**
  (a new ghost brings a waiting orb back sooner; the spec says only "respawn 10 s / (1 + 0.5 x ghosts)").
- **One slot (rule 42).** Touch an orb that is up with an empty slot and the server rolls the orb's pool into it; a
  full slot passes through and leaves the orb up. Ghost pool today: **the hex alone** (PRs 2 and 4 add crate, trap,
  ice, fixture, boost pad, boost grant at the §3 weights, where the hex is 8 in 100).
- **The hex (rule 40).** A ghost holding a hex that touches the holder takes `SPOOK_DRAIN` **3 s** off the fuse (never
  below 0) and its slot empties. No per-ghost cooldown (H15's `SPOOK_COOLDOWN` is gone): holding a hex is the limit.
  After any hex, **no ghost** may hex for `GHOST_WARD` **6 s** (the shared ward), and none while the holder is frozen.
  A refused hex keeps the hex. Cap, measured with every ghost handed a fresh hex every frame for 60 s: 1.500x for 1, 2
  and 3 ghosts = 1 + 3/6.

**Why the respawn is recomputed and not fixed at the take:** ghosts only ever increase inside a round (no comeback),
so recomputing can only bring an orb back sooner, which is the ramp's whole intent (the end phase gets busier). A
ghost leaving lowers the count and delays a waiting orb slightly. Pinned in `orbs.test.luau`.

## 2. Who owns what

| Piece | Where | Side |
|---|---|---|
| Who is a ghost, `count`, `canHex`, `hex` (drain, shared ward, empties the slot), `wardLeft` | `shared/Ghost.lua` (pure, tested) | both |
| Orb spots, `isUp`, the respawn formula, one slot, `touches` (the path between two samples), `roll` (injected random source), `step`, `use`, `POOLS` | `shared/Orbs.lua` (pure, tested) | both |
| The orb state per round; touches judged on the server's own record each frame; rolls with `math.random`; `ItemEvent` out | `server/Orbs.lua` | server |
| `GhostClaim` judged like `TagClaim` (now the hex's claim); `GhostVerdict`; the `MatchState` ghost rows | `server/Ghosts.lua` | server |
| Wiring and the frame order (§5); `MatchState.ghosts / ward` | `server/Match.lua` | server |
| Three ghost-orb spots | `server/Arena.lua` (`Arena.GHOST_ORBS`) | server |
| Studio dummies as ghosts: run to the nearest floor ghost orb, then with a hex chase the holder; their hexes judged same-frame | `server/Bots.lua` | server |
| Ghost orbs drawn, the held item over every runner's drawn head, the local slot readout | `client/Items.lua` | client |
| The hex claim on overlap with the holder's DRAWN spot (sent only while the local slot holds a hex) | `client/Tagging.lua` (`Tagging.hex`), `client/Client.client.lua` | client |
| Ghost line, "-3s HEX" pop, the ward's halo | `client/Hud.lua` | client |
| Pale ghosts (brighter while holding a hex), hollow ghost arrows | `client/Look.lua`, `client/Others.lua`, `client/Arrows.lua` | client |

## 3. What the server trusts (DESIGN §3 rule 6, proposal §8; → N4, N5)

**Orbs: no claim remote.** A client never says it touched an orb. Every frame (while the round runs) `server/Orbs`
takes each present runner's newest sample in the server's history (the snapshot stream, H14, bounded by the speed
check, H12) and the sample before it, and asks `Orbs.step` whether the box crossed an orb on that path. A sample
marked untrusted collects nothing, and an untrusted previous sample is not used as a path start. Ties in one frame go
to the earlier runner in join order. Rolls happen on the server only.

**The hex: `GhostClaim`, one number** (the holder's runner id), exactly the `TagClaim` path ([tag.md](tag.md) §2): rate
gap `TAG_CLAIM_GAP`; non-integers dropped; `Ghost.canHex` on the server's clock and the server's own slots (round runs,
claimant is a ghost of this round, it holds a hex, the target is the holder, not frozen, ward over, fuse above 0); the
touch re-checked with `Tag.touchedBetween` over the server's history (ping + `TAG_VIEW_DELAY`, capped
`TAG_REWIND_MAX`, open `TAG_CONFIRM_WAIT`). Confirmed: `Ghost.hex`, `GhostVerdict` to all, an `ItemEvent` slot
emptied, a `MatchState`. Refused: no reply; a Studio log line says why (`hex <id> -> <id> dropped: no hex held`).

**Fairness, stated plainly.** A cheating client can: send `GhostClaim` without a hex (refused: the server reads its own
slot); report a touch it did not make (refused unless the server's own history shows it); move within `MoveCheck`'s
burst (~45 studs) to reach an orb or the holder, the same honest limit as a tag ([trust.md](trust.md) §3). It cannot:
take an orb it never reached on the server's record, choose its roll, hold two items, drain more than 3 s, hex through
the ward or a freeze, or hex anyone but the holder. The drain is on the server's fuse; no victim client applies it.

## 4. Payloads

`MatchState.ghosts`: an ARRAY (→ N13) of `{ id }` for every present ghost (H15's `ready` and `comebacks` are gone);
`ward`: seconds before any ghost may hex. `mark` is gone. `GhostVerdict`: `{ from, to, drained, fuse }` (`mark` gone).
`ItemEvent` (server → all): `sync` (join, and to all at round start), `orb` (an orb back, or taken with the roll),
`slot` (a slot emptied outside an orb: a hex used, a leave). Field lists: [README.md](README.md) remotes table.
What each runner holds travels only on `ItemEvent`, not in `MatchState`: reliable events plus a full `sync` on join and
at every round start keep a client exact without a once-a-second resend.

## 5. Decisions taken while building (H18)

- **Frame order:** players' tags, dummies' tags, players' hexes, dummies' hexes, orbs, then the fuse. A tag and a
  killing hex in one frame: the tag wins. An orb taken this frame is a hex usable next frame.
- **The path between two samples counts** (`Orbs.touches`, a slab test of the runner box swept against the orb's
  square). The snapshot stream is 30 Hz; a dash moves 4 studs a snapshot, the touch window is 4 studs wide, so a point
  test could miss a dash straight through an orb.
- **An orb kind with no pool is never up.** Living orbs are PR 2; until then a `living` spot (none exist yet) would
  otherwise be reported up and drawn, an orb nobody could take. Caught by the first run of `orbs.test.luau`.
- **`Round.hold` stays** in `shared/Tag.lua` (+1 on every change of hands) though the mark that used it is gone: it is
  the S12 key for anything tied to one holder, and PR 2's per-target rules may need it. Its test stays, unchanged, as the
  ghost test's last block.
- **`SPOOK_DRAIN` kept its name** (the proposal's decision), now the hex's drain. `GhostClaim`/`GhostVerdict` kept theirs.
- **The ghost pool lives in `shared/Orbs.POOLS`** for now; PR 2's `shared/Items.lua` takes the pools and weights.
- **The server rolls with `math.random`** (seeded by Roblox per server), not `Random.new()`: same quality for a pick,
  and the Luau lint knows it (`Random` is a Roblox global it flags).
- **The held item floats at 5 studs over the runner's centre**, above the IT marker's halo, so a living holder's item
  (PR 2) never hides the triangle. A hex is a magenta diamond; an orb a violet ball (rule 12: distinct shapes).
- **Dummies reach only floor orbs** (they are floor-bound boxes); the platform orb is for players.

## 6. What each screen shows (rule 41)

| Who | What |
|---|---|
| A ghost | Status line `GHOST: out this round  \|  grab a ghost orb`, or with a hex `GHOST: HEX held, touch <holder> for -3s  \|  READY / ward 3.1`; slot readout top left (`ITEM: HEX` / `ITEM: none (grab a ghost orb)`); its own sprite pale blue, 0.3 see-through holding a hex, 0.65 empty-handed |
| Everyone | Ghost orbs as violet balls (bright when up, faint while they wait); each held item as a diamond over its holder's drawn head; ghosts pale, brighter while armed; `-3s HEX  <ghost>` on every hex (`... hexed you` on the holder's screen); hollow ghost arrows; the IT halo pale blue while the ward holds |

## 7. The knobs (`shared/Config.lua`)

| Knob | Value | What |
|---|---|---|
| `SPOOK_DRAIN` | 3 | seconds off the fuse per hex (rule 40, trial) |
| `GHOST_WARD` | 6 | no hex from any ghost for this long after one; cap = 1 + DRAIN / WARD |
| `ORB_FIRST` | 5 | seconds into a round before any orb is up (rule 42) |
| `ORB_RESPAWN` | 10 | seconds a taken orb is gone; ghost orbs divide by (1 + `GHOST_ORB_RAMP` x ghosts) |
| `GHOST_ORB_RAMP` | 0.5 | the ghost orbs' respawn ramp (rule 42) |
| `ORB_SIZE` | 2 | studs across an orb's touch square |
| `STUDIO_DUMMIES` | 3 | Studio dummies; 3 gives a solo 4-runner round where dummy ghosts take orbs and hex |

`config.test.luau` pins 3 / 6 / 5 / 10 / 0.5 and that `SPOOK_COOLDOWN` and `GHOST_COMEBACKS` no longer exist.

## 8. Verification (2026-10-19, H18)

- **Tests retired WITH their rules** (H15's rules 39-40, removed by Danzo in H16): the mark (latest spooker, cleared by
  a pass), the comeback (revive where it stands, never as it, one per player, the spent ghost, the killing spook,
  `Tag.tick`'s `back`, the marked ghost leaving), the 7-lives bound, and the spook cooldown. The behaviour they pinned
  no longer exists in DESIGN or in code; nothing was loosened to make anything pass. In their place: no comeback (a
  4-runner round is three burn-outs and 105 s of fuse, nobody revives), the hex's conditions, the cap with endless hexes.
- `npm test`: 13 node tests pass (line ceiling, purity); Luau: config, ghost, movement, movement_sprites, move_check,
  **orbs** (new), remote_pose, sidecam, snapshot, tag all ok. `npm run lint:luau`: every file ok. `rojo build`: ok.
- **Sourcemap before/after:** nothing removed or renamed; added `Shared.Orbs`, `Server.Orbs`, `Client.Items`
  (ModuleScripts); the build also holds `Remotes.ItemEvent` (RemoteEvent).
- **Mutation check (21 mutations, 20 caught):** hex needed, hex used up, ward set, ward checked, frozen holder, only the
  holder, only ghosts, the drain floor, count skips leavers, the ghost ramp, first at 0:05, no pool not up, one slot,
  ghost orbs for ghosts, the path counts, the roll boundary, the back event and its once-only, use empties, the round
  ends at one alive. Not caught: removing the `break` after a take, an equivalent mutant (the next taker's `canTake`
  re-checks `isUp`, already false; the "first in the list" test asserts the outcome).
- **Studio solo Play** (Config temporarily `STUDIO_DUMMIES` 3, flat 14 s fuse; restored before the tests). Server
  Output, in order: `round 1: 4 runner(s), <player> is it with 14s` · `<player>'s fuse ran out, -1000 is it` ·
  `-1000's fuse ran out, -1001 is it` · `orbs: -1000 took ghost orb 1: hex` · `ghost: HEX -1000 -> -1001, fuse 7.7s
  (-3.0s), ward 6s` · `orbs: -1000 took ghost orb 3: hex` · `ghost: HEX -1000 -> -1001, fuse 0.0s (-1.7s), ward 6s` ·
  `-1001's fuse ran out, round over, winner -1002` · `round 2: 4 runner(s), -1000 is it`. No comeback, three burn-outs,
  the real drain on the last hex (N7). No script errors. Both sides warned `Remotes.ItemEvent is missing (restart rojo
  serve ...)` and played on (N3), so nothing client-side was seen. **Next: restart `rojo serve`, reconnect, check
  `ReplicatedStorage.Remotes.ItemEvent` exists, then the play-through in the QA goals file.**

## Expansion: deficits at scale

- **Bots** (DESIGN §6.7): reuse `Bots.hexes`' shape (the server's own runner, rewind 0) and `orbX`'s goal pick, with a
  real path to platform orbs.
- **More orbs** cost one slab test per runner per orb per frame (4 x 6 = 24 at the planned map size): negligible.
- **Scoring (§6.4)** may count hexes; `GhostVerdict` and the `orbs:` log line carry the ids.
