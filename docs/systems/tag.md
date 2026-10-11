# The tag, the fuse, elimination

**Created:** 2026-10-11 (handoff H5). Design: [`../DESIGN.md`](../DESIGN.md) §2 "Mode: classic tag with a hot-potato
fuse", §3 rules 1, 2, 4, 5, 6, 21. Remotes: [`README.md`](README.md) (the table and the rules every remote follows).
How a body is owned and moved: [`movement.md`](movement.md) §2.

**Status:** built; the rules tested outside Studio (`test/luau/tag.test.luau`, every rule mutation-checked → Q5); the
server round, rotation, elimination and the dummy's tag seen in Studio Play (§7). **Not yet played with the remotes**: `rojo serve` must be restarted
first (→ T6). Feel numbers are Danzo's.

## 1. Who owns what

| Module | Side | What |
|---|---|---|
| `shared/Tag.lua` | both | the pure rules: the round state, the fuse clock, who may claim, the lag-fair confirm, the pass, elimination, rotation, the chaser ramp |
| `shared/Config.lua` | both | every number (§8) |
| `server/Match.lua` | server | the ONE round state; samples every runner's position each frame; confirms claims; ticks the fuse; tells clients |
| `server/Dummy.lua` | server | the Studio-only stand-in runner (§4) |
| `server/Runners.lua` | server | marks each body: CollectionService tag `RotagRunner`, attribute `RunnerId` = UserId |
| `client/Tagging.lua` | client | holds the server's last state; sends claims; tells the frame loop "frozen", "hit-stop", "speed x" |
| `client/Hud.lua` | client | fuse readout, the +5 pop, the IT marker, one status line |
| `shared/Movement.lua` | both | one new optional input, `speedMult`, multiplies the run speed (the ramp) |

The server is the only thing that writes "it" or the fuse (DESIGN §3 rule 6). The client never decides a tag: it can
only ask.

## 2. Decision (a): the remotes, and what the server trusts

Three RemoteEvents, declared in `default.project.json` and listed in [`README.md`](README.md):

- **`TagClaim`**, client → server, payload **one number**: the target's runner id. Fired by the holder's client
  when, on ITS screen, its box touches another live runner's box (`Tag.overlaps`, reach 0.5 studs). At most one per
  0.15 s from the client.
- **`TagVerdict`**, server → all, `{ from, to, fuse }`: a tag counted. Clients pop "+5", hit-stop if involved.
- **`MatchState`**, server → all (and to one player on join), a snapshot: `{ round, it, fuse, frozenFor, chaseFor,
  alive, over, winner }`. Durations, not timestamps, so no clock sync is needed: the client counts down from the
  moment it arrives and is corrected by the next one. Sent on every change and at least once a second.

**What the server trusts from a claim: the claimant's identity (the `Player` Roblox passes, never the payload) and
which target it names. Nothing else.** In order:
1. **Rate:** a claim within `TAG_CLAIM_GAP` (0.1 s) of that player's last one is dropped unread. A payload that is not
   an integer is dropped.
2. **Who may claim** (`Tag.canClaim`): the round is running; the claimant IS the holder; the claimant is not frozen;
   the target is alive in this round and is not the claimant; the fuse is not out.
3. **Positions are the server's own.** `Match` records every runner's position each server frame (the last ~0.5 s,
   same timestamps for everyone). `Tag.confirm` accepts if, at any frame within the **rewind** window, the two boxes
   touch within reach + `TAG_GRACE` (1.5 studs). Rewind = the claimant's `GetNetworkPing()` + 0.1 s interpolation,
   **capped at `TAG_REWIND_MAX` (0.3 s)** so a client cannot buy a longer look-back by lagging. A frame where one
   runner has no sample is never paired with another frame.
4. Confirmed: `Tag.pass`, then `TagVerdict` and `MatchState` to all. Dropped: no reply at all (a log line in Studio).

**Why this shape.** Rule 6 says client overlap, server confirm. The holder sees the target where it was a moment ago
(replication delay), so a server check on "now" alone would reject tags the player clearly landed; the short rewind
over the server's OWN history is the fair version of "trust what the tagger saw", and the cap bounds how much a
laggy tagger gains (Gorilla Tag's complaint: "lag favours the tagger"). The grace covers interpolation between frames.
Why the server does not just detect overlaps itself and drop the claim: it could, but then a tag the player saw land
could be missed; the claim is what tells the server WHEN to look back. The dummy, which is the server's own runner,
does exactly that (rewind 0).

**The honest limit.** Runner bodies are client-owned physics (`SetNetworkOwner(player)`, [movement.md](movement.md) §2),
so the positions the server checks come from each player's own client. A cheating client that teleports onto a target
passes any position check. That is a movement-trust problem, not a tag problem: the planned movement event (README
"Planned") with a server speed check closes it. The tag check is no weaker than movement trust, and every other gate
(who, when, frozen, rate, rewind cap) is server-side today. The freeze, the hit-stop and the chaser boost are applied
by the client to its own body, so a cheat can ignore them; the server still refuses a frozen holder's claims.

## 3. Decision (b): rule 1, no tag-backs — freeze the new holder 1.5 s

`Config.TAG_FREEZE = 1.5` (already in Config, pinned 1–2 s by `config.test.luau`). The new holder gets no input and no
run speed (a dash in progress ends) but still falls; the server refuses its claims until the freeze ends; **the fuse
does not burn while frozen**, so the holder really gets remaining + 5 s of chase.

**Why freeze, not passer immunity.** After a tag the two runners are touching. Immunity for the passer only delays the
tag-back by its own length: the new holder follows at the same speed and tags the moment it ends. A freeze turns the
same 1.5 s into a head start (about 67 studs at run speed), which is what actually ends tag-backs (Gorilla Tag's model).
Rule 11's "no stun over ~1 s" is about crate items; rule 1 sets 1–2 s for this freeze. **Danzo's call in Play:** 1.5 s
may feel long on a phone; 1.0 is the other end of rule 1's range.

**Why the fuse pauses in the freeze.** §2 says the new holder gets remaining + 5. If it burned while they could not
move, the pass would really be +3.5. The HUD shows the number standing still while "frozen 1.2" counts down.

**Round start:** the first holder waits `START_FREEZE` (3 s) while everyone scatters, also with the fuse paused.

## 4. Decisions (c) and (d): who is first "it", and testing without a second player

**(c) Rule 5, rotation in join order, never random** (`Tag.nextStarter`). `Match` keeps every runner id in join order.
Round 1: the first to join. Each later round: the next present runner after the last round's starter, wrapping.
- **One player:** they are it. The fuse runs, they are eliminated at 0, the round ends with no winner, a new one starts
  after `ROUND_GAP` (4 s). This is the solo fuse test.
- **N players:** as above; joiners mid-round wait for the next round (they run, but are not in play).
- **After an elimination:** the next ALIVE runner after the eliminated one in join order becomes it, frozen
  `TAG_FREEZE`, with a fresh fuse (§5). Not "the last one who tagged them", which would punish good play.
- **The holder leaves:** the next alive runner takes the fuse as it stands, frozen. Down to one runner: round over.
- "The previous round's leader" (rule 5's other option) needs scoring, which is DESIGN §6.4 (open). Swap it in then.

**(d) Testable before a second client: a server-driven dummy** (`server/Dummy.lua`). In Studio only
(`RunService:IsStudio()` and `Config.STUDIO_DUMMY`, read once at boot, → N1), an orange neon box joins the round after
the first player, under runner id **-1000** (Studio's local-server test players are -1, -2, ...; this never collides).
It is anchored and moved by the server along the floor: patrols ±40 studs at 18 studs/s; as it, chases the nearest
alive player at 30 studs/s (both below the 45 run speed, so it can be caught and escaped). It never plays alone.
Players tag it with a normal claim; as it, the server checks its overlaps itself each frame with no rewind.
**The second path:** Studio's Test tab → Clients and Servers, 2 players: real clients, real claims, ids -1 and -2.

## 5. Decision (e): "the fuse shrinks across the match" — per elimination, 45 → 35 → 25

`Tag.freshFuse(eliminations) = max(FUSE_MIN, FUSE_START - FUSE_SHRINK x eliminations)`: 45, 35, 25 in a 4-player
match (`FUSE_SHRINK = 10`, floor `FUSE_MIN = 15`). It applies to the fresh fuse a new holder gets after an elimination.
**A pass is never touched: always remaining + 5**, exactly as §2 locks it.

**Why not per pass:** shrinking anything on a pass would change the locked "remaining + 5 s". **Why not per round**
of a best-of session: §2 says "across the match"; a match is one game to the last runner (2–3 minutes, §1), and
session structure is §6.4, still open. Per elimination also serves rule 3 (force an ending): the final duel starts on
25 s. Worst case with no passes: 45 + 35 + 25 = 105 s, inside the 2–3 minute target.

**Not decided (Danzo):** a chain of quick passes grows the fuse +5 each time (minus the chase time). No cap is set,
because a cap would reinterpret §2's "+5". If Play shows rounds dragging, the options are a cap at the life's fresh
fuse, or rule 3's "speed up the fuse" at the final two.

## 6. Feel and readability (rules 2, 4, 21)

- **Rule 4, the chaser ramp** (`Tag.chaserBoost`): no boost for the first 5 s of a chase, then up to +15% run speed
  over 15 s; the chase clock starts when the holder's freeze ends, so every tag resets it. Applied by the holder's
  client through `Movement`'s `speedMult` (the earned-speed bleed uses the boosted top too).
- **Rule 2, readable fuse — partly:** the fuse in seconds at the top centre (red "YOU'RE IT" when yours), "+5 -> name"
  on every pass, an IT marker over the holder, frozen/out/winner lines. The growing, beeping, glowing bomb is art and
  sound, still to come.
- **Rule 21, hit-stop:** 80 ms (`HIT_STOP`) on both involved clients when the verdict lands; the body holds still and
  resumes with the same speed. Screen shake: not yet.
- **Rule 6's catch-up animation: not built.** Today the verdict only moves the marker and pops "+5". It needs the art
  pass (a reach/lunge frame toward the target); recorded here so it is not forgotten (→ Q1).
- **Eliminated runners keep running** but are out of play (untaggable, HUD says "out") until ghosts exist (DESIGN §6.1).
- **Gap for "then a second player":** each client draws only its own runner's sprite (`Look` is built for the local
  character). Other players' bodies are invisible on your screen; the dummy is visible only because it is a neon part.

## 7. Verification (2026-10-11)

- `npm test`: 13 node tests pass; Luau: config, movement, movement_sprites, sidecam, **tag** all ok.
  `npm run lint:luau`: every file ok. `rojo build`: ok. Sourcemap before/after: nothing removed or renamed; added
  `Shared.Tag`, `Server.Match`, `Server.Dummy`, `Client.Tagging`, `Client.Hud` (RemoteEvents are not in a sourcemap;
  the build includes them).
- Mutation check: ten rules deleted one at a time (the +5, the fuse pause, the frozen claim, only-it, the rewind cap,
  same-frame pairing, the shrink, the rotation wrap, the ramp delay, the pass freeze): `tag.test.luau` failed each time.
- **Studio Play (solo; the running `rojo serve` predates the new remotes, → T6):** the scripts synced, the three
  RemoteEvents did not; the server warned once for each and played on (no hang, → N3), the client warned after 10 s.
  Output, in order: `round 1: 2 runner(s), <player> is it with 45s` (the dummy joined after the player);
  `<player>'s fuse ran out, round over, winner -1000` (no claims possible without `TagClaim`); `round 2: 2 runner(s),
  -1000 is it with 45s` (rotation); `TAG -1000 -> <player>, fuse 48.8s` (the dummy chased; the server's own confirm
  passed: 43.8 left + 5). **Not seen:** a client claim, the HUD, the freeze and the hit-stop on a client; all need the
  remotes. Unrelated line seen: `PlayerModule controls not found; running from Humanoid.MoveDirection instead: nil`
  from `Controls.lua` (unchanged by H5).

## 8. The numbers (`shared/Config.lua`)

| Knob | Value | What |
|---|---|---|
| `FUSE_START` | 45 | the first holder's fuse (§2, locked) |
| `FUSE_PASS_BONUS` | 5 | remaining + this on a tag (§2, locked) |
| `TAG_FREEZE` | 1.5 | new holder frozen, fuse paused (rule 1) |
| `START_FREEZE` | 3 | first holder's wait at round start |
| `FUSE_SHRINK`, `FUSE_MIN` | 10, 15 | fresh fuse after each elimination (§5) |
| `TAG_REACH` | 0.5 | studs past touching that count, on the client and the server |
| `TAG_GRACE` | 1.5 | extra studs the server allows |
| `TAG_REWIND_MAX` | 0.3 | the server's look-back cap, seconds |
| `TAG_CLAIM_GAP` | 0.1 | claims closer than this dropped |
| `RAMP_DELAY`, `RAMP_TIME`, `RAMP_MAX` | 5, 15, 0.15 | the chaser ramp (rule 4) |
| `HIT_STOP` | 0.08 | rule 21 |
| `ROUND_GAP` | 4 | seconds between rounds |
| `STUDIO_DUMMY` | true | the dummy, Studio only |

## Expansion: deficits at scale

- **Position trust** is movement trust (§2): the first real fix is the movement event with a server speed check.
- **History cost:** 30 samples per runner per server frame, a table each. Four runners: 120 small tables, trivial. If
  runner counts grow, store x/y in flat ring arrays instead of tables.
- **`MatchState` every second** to every client is a few hundred bytes; fine at 4 players.
- **Claims scan every tagged runner per frame** on the holder's client (4 runners: nothing). Keep it that way.
