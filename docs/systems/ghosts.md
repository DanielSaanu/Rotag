# Ghosts: what an eliminated player does, and how it comes back

**Created:** 2026-10-14 by the heavy agent (handoff H15). Design: [`../DESIGN.md`](../DESIGN.md) §2 "Elimination:
ghosts", §3 rules 7-9 and **37-41** (adopted by Danzo 2026-10-14: "recommended", all six questions answered as
proposed). The tag this builds on: [tag.md](tag.md). Remotes: [README.md](README.md).

**SUPERSEDED IN DESIGN 2026-10-19 (H16).** Danzo adopted "ghosts v2": no mark, no comeback, ghost orbs, placed parts
and a rare hex (DESIGN §3 rules 37-51). The spec and build order: [ghosts-v2-proposal.md](ghosts-v2-proposal.md). This
doc still describes the CODE as built until PR 1 of that build order lands; superseded parts: §1 the mark and the
comeback, the spook's 8 s cooldown (the hex replaces it), `GHOST_COMEBACKS`; still valid: the trust path (§3), the
ward, the drawing (§6).

**Status:** built. Rules tested outside Studio (`test/luau/ghost.test.luau`, every rule mutation-checked, §8). Seen in
Studio solo Play with three dummies: dummy ghosts spook, the mark, comebacks, the spent ghost, the round end, and the
client's drawing (§8). **Not yet seen: a PLAYER's spook** (`GhostClaim`): the running `rojo serve` predates the two
new remotes (→ T6). Restart it, then the two-player test in `ideas/INBOX.md`.

## 1. The rules (DESIGN §3 rules 37-41) and their numbers

- **A ghost** is a runner eliminated in this round: its own body, in place, with the whole movement kit. It passes
  through runners, collides with the map, cannot tag, be tagged or hold the fuse, and sees what everyone sees.
- **Spook:** a ghost whose box touches "it" takes `SPOOK_DRAIN` **3 s** off the fuse. On contact: no button. No stun,
  no slow: the holder's movement is never touched.
- **Cooldowns:** each ghost waits `SPOOK_COOLDOWN` **8 s** after its spook; a NEW ghost starts on a full 8 s (no instant
  revenge on the next holder). After any spook, **no ghost** may spook for `GHOST_WARD` **6 s** (the shared ward), and
  none while the holder is frozen (start or pass freeze). So the fuse burns at most `1 + 3/6 = 1.5x` however many
  ghosts there are; one ghost alone `1 + 3/8 = 1.375x`. Measured in the test (60 s, every ghost trying every frame):
  1 ghost 1.400x, 2 ghosts 1.500x, 3 ghosts 1.500x. (1.400 not 1.375: the spook at t = 0 counts in a 60 s window.)
- **The mark:** the latest ghost to spook the CURRENT holder holds it; every screen shows who. Any change of hands (a
  pass, an elimination, the holder leaving) clears it: it lives on one *hold* (`Round.hold`, +1 on each change).
- **Comeback:** when the fuse runs out, the marked ghost comes back to life **where it stands** and is **never** the
  new holder; the eliminated holder becomes a ghost; the next holder is the next alive after the eliminated one in join
  order, skipping the returner. The elimination still counts, so the fresh fuse still shrinks. No mark, no comeback.
- **One comeback per player per round** (`GHOST_COMEBACKS` 1). A spent ghost still spooks (and drains) but never takes
  the mark: its spook leaves an earlier mark where it was.
- **The round still ends** (rule 3): a 4-player round with no passes has at most 7 lives, 45 + 35 + 25 + 15 x 4 = 165 s
  (was 105 s); the test pins "7 lives at most, and it ends". 2 players never have a ghost; 3 players have one.

**Rule 8 reading (Danzo, 2026-10-14):** every ghost presses the holder, which is a role that moves with every tag, and
the shared ward caps the total pressure whatever the ghost count; that is the meaning of "no ganging up". Rule 8's
"no information leaks" holds by construction: nothing in this game is hidden (the arrows already show every runner).
Rule 9 (the living free ghosts) is not adopted: the comeback is earned by the ghost; pods invite camping.

## 2. Who owns what

| Piece | Where | Side |
|---|---|---|
| The rules: who is a ghost, `canSpook`, `spook` (drain, cooldown, ward, mark), `markOf`, `tick` (the comeback), `leave` | `shared/Ghost.lua` (pure, tested) | both |
| `Round.hold`; `Tag.tick(r, now, back)` revives `back` after picking the next holder | `shared/Tag.lua` | both |
| The ghost state beside the round; the frame order (§5); `MatchState.ghosts / ward / mark` | `server/Match.lua` | server |
| `GhostClaim` judged like `TagClaim`; `GhostVerdict`; the state rows | `server/Ghosts.lua` | server |
| The Studio dummies (`Config.STUDIO_DUMMIES`, ids -1000, -1001, ...): as a ghost each chases the holder and spooks on the server's own same-frame check | `server/Bots.lua`, `server/Dummy.lua` | server |
| The claim on overlap with the holder's DRAWN spot; the ghost fields of `MatchState` | `client/Tagging.lua` (`Tagging.spook`, `ghost`, `readyIn`, `wardLeft`) | client |
| Pale see-through ghosts, brighter when ready | `client/Look.lua` (`Look:ghost`), `client/Others.lua`, `client/Client.client.lua` | client |
| Status line, "-3s" pop, mark line, "is back!", the ward's halo | `client/Hud.lua` | client |
| Hollow ghost arrows | `client/Arrows.lua` | client |

## 3. What the server trusts (DESIGN §3 rule 6, → N4, N5)

`GhostClaim` (client → server) carries **one number: the holder's runner id**. Exactly the `TagClaim` path
([tag.md](tag.md) §2):
1. **Rate:** a claim within `TAG_CLAIM_GAP` (0.1 s) of that player's last is dropped unread; the client sends at most
   every 0.15 s. A non-integer payload is dropped.
2. **Who may spook** (`Ghost.canSpook`, on the SERVER's clock): the round runs; the claimant is a ghost of this round;
   the target IS the holder; the holder is not frozen; the shared ward is over; the claimant's own cooldown is over;
   the fuse is above 0. The client's view of the cooldowns is only used to avoid useless claims.
3. **Positions are the server's own record** (`Tag.touchedBetween` over the snapshot-fed history, same allowance:
   ping + `TAG_VIEW_DELAY`, capped at `TAG_REWIND_MAX`, open `TAG_CONFIRM_WAIT`). A ghost's samples go through the same
   `MoveCheck`: a ghost moving too fast has its samples marked untrusted and is snapped back, like any runner.
4. Confirmed: `Ghost.spook`, then `GhostVerdict { from, to, drained, fuse, mark }` to all and a `MatchState`.
   Refused: no reply; a Studio log line says why (`spook <id> -> <id> dropped: warded`).

**Fairness, stated plainly.** A cheating ghost can: report a touch it did not make (the server checks its own
history, as for tags, so only a ghost whose stream really put it there passes); teleport onto the holder within
`MoveCheck`'s burst (~45 studs, the same honest limit as a tag, [trust.md](trust.md) §3). It cannot: spook faster
than its cooldown or through the ward or a freeze (server clock), spook anyone but the holder, drain more than 3 s,
take the mark while spent, or choose who comes back. A cheating holder cannot dodge a spook by ignoring anything: the
drain is on the server's fuse, never applied by the victim's client (which is why the spook was chosen over a slick
floor, H15 proposal). The comeback is decided in `Ghost.tick` on the server only.

## 4. `MatchState` additions (H15)

`ghosts`: an ARRAY (→ N13) of `{ id, ready, comebacks }` for every present ghost, `ready` = seconds until its spook is
off cooldown. `ward`: seconds before any ghost may spook. `mark`: the id that comes back if the fuse runs out now, or
nil. Durations, not timestamps, like every other field. A client of an older server sees none of them and draws no
ghosts.

## 5. Decisions taken while building

- **The comeback does NOT rebuild the body.** The coordinator's brief suggested `Runners.spawn`; the rule says "where it
  stands", so nothing moves (N8 is about moving a client-owned body), and a rebuild would zero the returner's speed
  mid-run (a fresh `Movement` state) and drop its snapshots for up to `SPAWN_GRACE` while the server reads the body.
  Ghost and living runner are one body; only server state flips. The ownership guard and the stream carry on untouched.
- **Frame order:** players' tag claims, the dummies' tags, then players' spooks, then dummies' spooks, then the fuse.
  A tag and a killing spook in one frame: the tag wins. A spook claim is queued on arrival and judged in the next
  frame (≤ 1 frame later), so it can never jump ahead of a tag claim.
- **The claim window can reach back past the ward's end** by up to `TAG_REWIND_MAX`: a touch made in the last 0.5 s of
  the ward can land just after it ends (the same looseness the tag has around the freeze). Accepted.
- **Dummies tag only players** (seen in Play: with three dummies sharing one patrol lane, they passed the fuse among
  themselves for ever, so no dummy could burn out and become a ghost). With one dummy this is no change.
- **Comebacks are seen on the client as a runner newly alive in the same round** (no extra event): `MatchState` is
  resent every second, so a lost message cannot lose a comeback.

## 6. What each screen shows (rule 41)

| Who | What |
|---|---|
| The ghost itself | Status line `GHOST: touch <holder> for -3s  \|  READY / ready in 4.2 / ward 3.1  \|  comeback left / you hold the mark / no comeback left`; its own sprite pale blue (0.3 see-through when ready, 0.65 when cooling) |
| Everyone | Other ghosts drawn the same pale blue, brighter when their spook is ready; ghost arrows hollow pale-blue rings; every spook pops `-3s  <ghost>` (`-3s  <ghost> spooked you` on the holder's screen); `marked by <name>: back if the fuse runs out` under the status line; `<name> is back!` (or `YOU'RE BACK!`) big for 1.6 s on a comeback |
| Around the holder | The IT triangle's halo turns pale blue while the ward holds (no spook can land), red otherwise |
| A ghost during a freeze | No "RUN!" (it has nothing to run from) |

## 7. The knobs (`shared/Config.lua`)

| Knob | Value | What |
|---|---|---|
| `SPOOK_DRAIN` | 3 | seconds off the fuse per spook (rule 38, trial) |
| `SPOOK_COOLDOWN` | 8 | one ghost's wait between spooks; a new ghost starts on it |
| `GHOST_WARD` | 6 | no spook from any ghost for this long after one; cap = 1 + DRAIN / WARD |
| `GHOST_COMEBACKS` | 1 | per player per round (rule 40) |
| `STUDIO_DUMMIES` | 1 | Studio dummies; 3 gives a solo 4-runner round where dummy ghosts play |

`config.test.luau` pins 3 / 8 / 6 / 1 as the adopted trial: change DESIGN §3 rules 38/40 and the test together.

## 8. Verification (2026-10-14)

- `npm test`: 13 node tests pass (line ceiling, purity); Luau: config, **ghost**, movement, movement_sprites,
  move_check, remote_pose, sidecam, snapshot, tag all ok. `npm run lint:luau`: every file ok. `rojo build`: ok.
- **Sourcemap before/after:** nothing removed or renamed; added `Shared.Ghost`, `Server.Ghosts`, `Server.Bots`
  (ModuleScripts). The build also holds the two new RemoteEvents `Remotes.GhostClaim`, `Remotes.GhostVerdict`.
- **Mutation check (21 mutations, each caught):** the drain and its floor at 0, the ward set and checked, the
  cooldown set and checked, the frozen holder, only ghosts, only the holder, the new ghost's wait, the spent ghost's
  mark, the mark's hold, the comeback count, leave clears the mark, `back` only revives a ghost, the returner never
  it, the comeback keeps the round going, the revive itself, `hold` on pass / leave / tick.
- **Studio solo Play** (Config temporarily: `STUDIO_DUMMIES` 3, flat 14 s fuse; restored after). Server Output, in order:
  `8061215879's fuse ran out, -1000 is it` · `-1000's fuse ran out, -1001 is it` · `ghost: SPOOK -1000 -> -1001, fuse
  4.5s (-3.0s), holds the mark` · `-1001's fuse ran out, -1000 is BACK (the mark), -1002 is it` · (two more of the
  same) · `SPOOK -1000 -> -1001, fuse 4.5s (-3.0s), spent: no mark` · `-1001's fuse ran out, round over, winner -1002`.
  Six lives. Client, sampled every 0.5 s: the ghost line (`READY`, then `ward 6.0` counting down), the fuse dropping
  7.9 → 4.4 on a spook, `marked by Dummy3: back if the fuse runs out`, `Dummy3 is back!`, ghost dummies at 0.65 see-
  through and the player-ghost at 0.30 tinted (0.67, 0.84, 1.0), the hollow ring on the ghost's arrow only, the halo
  pale blue in every ward and red outside it. First run showed "RUN!" to a ghost and the dummies' endless passing:
  both fixed (§5, §6).
- **Not seen:** the player's own `GhostClaim` and the `-3s` pop (`GhostVerdict`): both remotes were missing in Play
  (`ReplicatedStorage.Remotes.GhostClaim is missing (restart rojo serve ...)`); the server and client warned and
  played on, as N3 requires.

## 9. The proposal this came from (H15, kept for the record)

Ranked alternatives Danzo did not pick: (1) the same rules with ghosts that FLY through walls at ~30 studs/s (easier
for weaker players, loses the movement pillar for ghosts, needs a new movement mode); (2) ink-splat traps (a ghost
button, new art, a slip applied by the victim's client that a cheat can ignore, comeback timing by luck).

## Expansion: deficits at scale

- **Bots.** A real bot (DESIGN §6.7) should reuse `Bots.spooks`' shape: the server's own runner, rewind 0.
- **More than 4 players** raises the ghost count, not the pressure (the ward caps it); the comeback bound grows by
  one life per player.
- **Scoring (§6.4)** may want spooks and comebacks as points; `GhostVerdict` and the comeback log line carry the ids.
