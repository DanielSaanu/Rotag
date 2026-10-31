# The endgame: ignition and end-phase speed (ghosts v2 PR 5)

**Built:** 2026-10-31, handoff H23 (heavy). **Design:** `docs/DESIGN.md` §3 rules 2 (make the fuse readable), 3 (force
an ending), 50 (ignition), 51 (end-phase speed). **Spec:** [ghosts-v2-proposal.md](ghosts-v2-proposal.md) §12 item 5
and §7 (a four-player round minute by minute). The fuse, the round and elimination themselves: [tag.md](tag.md).
QA goals: [`docs/qa/ghosts-v2-endgame.md`](../qa/ghosts-v2-endgame.md).

## 1. Who owns what

| Piece | Where | Decides or draws |
|---|---|---|
| Is the end phase on? | `shared/Tag.endPhase(r, now)` | pure; the **server** calls it on its own clock |
| Its speed | `shared/Tag.speedMult(isIt, chaseTime, granted, endPhase)` | pure; the client's frame loop feeds `Movement` |
| Telling clients | `server/Match.lua`: `MatchState.endPhase` (boolean), sent at once on a flip | server |
| How far the ignition has grown | `shared/Tag.ignition(fuseLeft)` -> 0..1 | pure; every client, from the replicated fuse |
| The ember rim, embers and glow | `client/Look:ignite(level)` | client only, every runner |
| The burn-out burst | `client/Ignition.lua` (new ModuleScript) from the `MatchState` change | client only, every screen |
| The fuse readout's beat, the end-phase line | `client/Hud.lua` | client only |

No new remote. `MatchState` grows one field, `endPhase` ([README.md](README.md) remotes table). Nothing the server
trusts from a client changed.

## 2. The end phase (rule 51)

- **On when:** only two are left alive in a round that BEGAN with three or more, or the round has run
  `END_PHASE_AFTER` seconds (from `Tag.newRound`, `Round.started`). A leave that leaves two counts too (two are left
  either way). **Call:** a round that started with only two runners is a normal fuse until the time cap: rule 51
  says "never during a normal fuse", and a fresh 45 s first fuse is one.
- **Sticky with no stored flag:** the living only ever fall and the clock only runs on, so once true it stays true
  for the round. A round that is over has no end phase (the next round starts normal; seen in Play).
- **Speed:** every LIVING runner's run top speed x `END_PHASE_SPEED`, with max(ramp, grant) on top (rule 46 still
  holds: the ramp and the grant never stack with each other). Top: 45 x 1.15 x 1.1 = **56.925 studs/s** (pinned in
  `tag.test` and `move_check.test`). The dash is never scaled, like the ramp. Ghosts are not living: no end-phase speed.
  The Studio dummies are server-driven boxes and ignore every speed multiplier (as before).
- **The server** sets `MatchState.endPhase = Tag.endPhase(round, now)` and marks the state dirty on a flip, so a
  time-cap flip reaches clients the same frame, not on the 1 s resync; Studio logs `END PHASE: n alive, Ns into the
  round`. Clients only read it (`client/Tagging.speedMult`); an absent or malformed field reads as off.

### The speed check (trust.md §8) — no change, proven by driving

The proposal said `MoveCheck`'s budget should scale by `END_PHASE_SPEED`. Measured, it does not need to: the x rate
is the DASH speed (120), and the end phase scales only the run. Driven in `move_check.test.luau` for 10 s each at the
top multiplier: the fastest dash-jump chain (never flagged; burst used **1.38 of 24 studs, exactly the plain
chain's**, pinned as a measurement → S11), a held run (56.925, clean) and the pad chain (clean). `config.test` asserts
`RUN_SPEED x (1 + max(RAMP_MAX, GRANT_BOOST)) x END_PHASE_SPEED < DASH_SPEED`, so a future tuning that crosses the
dash fails a test before it can flag honest runners. `server/MoveGuard` therefore never needs the phase.

**What a cheat gains:** a client that pretends the end phase is on runs at x1.1 all round. It already could: the
budget is the dash, so any steady run under 120 studs/s passes (trust.md §8, "input replay is the real fix"). Nothing
new is exploitable.

## 3. The ignition and the burn-out (rules 2, 50)

- **Growth:** `Tag.ignition(fuseLeft)` = 0 at `IGNITE_AT` (10 s) or more, rising linearly to 1 at 0. Only the holder
  (`Tagging.ignition(id)`: `state.it == id`), drawn by every client from the replicated fuse.
- **The look** (`Look:ignite`), placeholder art with no sheet upload (Danzo was away; the art pass replaces it):
  - a third rim tint, ember red-orange: priority freeze (cyan) > ignition > grant (orange). It grows from the rim's
    1.08 to 1.25 of the frame and flickers 2 -> 10 times a second as the fuse runs down;
  - embers: a `ParticleEmitter` on an `Attachment` in the sprite plane, rate 0 -> 60 a second, size 1.4;
  - a `PointLight` (ember colour, range 6 -> 16, brightness 1 -> 4) that lights the floor and walls around the
    holder. **Seen in Studio:** without the light, at play zoom the rim read as a faint red tint and 0.6-stud embers
    as one yellow dot; the light is what made it read as "glowing" (capture at 1.0 s left: a red pool on the floor
    and wall, a bright core). Both the size bump and the light came from that capture.
- **The HUD** (every screen): under `IGNITE_AT` the fuse readout reddens (toward hot yellow on the beat), swells up to
  1.35x and beats 2 -> 8 times a second. Seen: 32 px at 10 s, 41-42 px near 0.
- **The burn-out** (`client/Ignition.state`): after each `MatchState`, if the previous holder is gone from `alive`
  in the same round and this screen still draws a body for them, a one-shot burst there: a neon ball swelling to 9
  studs and fading over 0.35 s plus 70 sparks; Debris after 1.2 s. A holder who LEFT has no body: no burst.
  The final burn-out of a round (state `over`) bursts too. Studio prints `burn-out: <id> at (x, y)`.
- **Cost per frame (trigger 6):** one compare per runner when nothing changes; the emitter and light are built once
  per Look on first ignition; only the holder emits. The burst is a few instances per elimination.

## 4. Seen in Studio (2026-10-31, solo Play, 3 dummies)

Round 1: I burned out at 46 s (ember rate 6 -> 54 as the fuse ran 9 -> 1, readout 32 -> 41 px, `burn-out` at my spot);
the dummy burned out next; server `END PHASE: 2 alive, 83s into the round` (the proposal's §7 put the final two at
~1:40 with passes; with none it is 45 + 1 + 1.5 + 35 = 82.5 s); the HUD showed `FINAL TWO: everyone +10% speed`; the
round ended and round 2 started with the line gone. Six `burn-out` lines over the first run's two rounds, each at that runner's spot. With `STUDIO_DUMMY_TAGS =
false` (put back after): the glow capture above, and the burst captured by calling `Ignition.burst` at my spot. No
script errors or warnings (the stock decal line only). NOT seen: the end-phase speed under a hand (the HUD and server
say it is on; Movement's number is pinned by test); the time-cap flip at 120 s (tested in `tag.test`); a second client.

## 5. The numbers (`shared/Config.lua`, trial, tuned by hand)

| Knob | Value | Why |
|---|---|---|
| `IGNITE_AT` | 10 s | DESIGN rule 50's trial; under `FUSE_MIN` (15) so every life ignites, short enough to mean "now" |
| `END_PHASE_SPEED` | 1.1 | DESIGN rule 51's trial; the top end-phase run (56.9) stays well under the dash (120) |
| `END_PHASE_AFTER` | **120 s** | H23's pick (the proposal guessed 150). See below |

**Why 120, not 150.** The pillar is 2-3 minute rounds. The count trigger covers a normal round: with no passes the
final two arrive at ~83 s, with the proposal's pass rate at ~1:40, both under 120, so the cap changes nothing there.
The cap is for the drawn-out round where passes keep three alive. Such a round, at time T, still has about two lives
to burn (the 35 s and 25 s fresh fuses, longer with passes), so it ends near T + 60 s. At 120 it ends near 3:00, inside
the pillar; at 150 it ends near 3:30, outside it. `config.test` also asserts the cap never bites before two whole
unpassed lives (45 + 35 = 80 s) have burnt. If Danzo finds 2:00 rounds feel rushed, 150 is the fallback.

## 6. Left for later

The ignition art (a sprite or sheet particle, behind `Sprites.Has`; ignitions and burn-outs are the first cosmetic
slot, §6.5); rule 3's map shrink with the end phase (PR 6, maps); a HUD countdown to the time cap (not built: the
line appears when it starts).

## QA round 1 (2026-10-31, 8/10)

Fixed: the embers' `LightEmission` 1 → 0.5 and top rate 60 → 35 (the sprite whited out in the last second; the rim
is the signal); the burst at z 4.6, in front of the map's front face (a burst against a wall was cut in half); the
holder's off-screen arrow beats red → hot yellow with `Tagging.ignition`; a dark stroke and brighter orange on the
FINAL TWO line; the flash swell 0.35 → 0.5 s. Deferred: a duel that reaches the time cap is labelled FINAL TWO
(the HUD reads `#alive <= 2`; saying OVERTIME there needs the round's start count in `MatchState`; rounds start with
two only in Studio today). Known race, no harm: a holder who LEAVES can get a burst at its last drawn spot if the
`MatchState` lands before the model removal replicates.
