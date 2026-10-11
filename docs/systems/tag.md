# The tag, the fuse, elimination

**Created:** 2026-10-11 (handoff H5). Design: [`../DESIGN.md`](../DESIGN.md) §2 "Mode: classic tag with a hot-potato
fuse", §3 rules 1, 2, 4, 5, 6, 21. Remotes: [`README.md`](README.md) (the table and the rules every remote follows).
How a body is owned and moved: [`movement.md`](movement.md) §2.

**Status:** built; the rules tested outside Studio (`test/luau/tag.test.luau`, every rule mutation-checked → Q5);
played solo with the dummy through the remotes in Studio (H6, §7, §9). Feel numbers are Danzo's.

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
3. **Positions are the server's own.** `Match` records every runner's position each server frame (the last ~1 s,
   same timestamps for everyone). Allowance `k` = the claimant's `GetNetworkPing()` + `TAG_VIEW_DELAY` (0.4 s),
   **capped at `TAG_REWIND_MAX` (0.5 s)** so lagging buys no more (`Tag.claimWindow`). `Tag.touchedBetween` accepts
   if some claimant sample and some target sample touch within reach + `TAG_GRACE` (1.5 studs), with the target
   sample **the same age or up to `k` older, never newer**, none before arrival - `k`, and the claimant sample no later
   than arrival + `TAG_CONFIRM_WAIT` (0.35 s). The claim stays open that long and is judged again every frame
   (`judgePending`), because the claimant's own body reaches the server after its claim does. One open claim per
   claimant; a newer one replaces it (the old window up to now was already checked every frame).
4. Confirmed: `Tag.pass`, then `TagVerdict` and `MatchState` to all. Dropped: no reply at all (a Studio log line with
   the closest approach, e.g. `closest: 6.3, 0.0 studs apart`).

**H6 correction (2026-10-11): the H5 check missed real tags.** H5 judged a claim the moment it arrived and paired
only samples of the same server frame. Danzo, solo with the dummy: "i was only able to tag the block once".
Reproduced: `claim <player> -> -1000 dropped: no overlap in the server's last 0.10s` right after a run that touched
the dummy on the client. Measured with a client and a server Heartbeat logger (Studio runs both in one process, so
`os.clock` is shared): **the server's copy of a client-owned body is ~0.18 s behind the client** (the run started 0.08 s
late and settled at 0.18 s), the RemoteEvent arrives almost at once, and the server-anchored dummy reaches the client
within a frame. At the claim the server still had the player ~7 studs short of the dummy. Two consequences, both now
pinned in `tag.test.luau`: (a) a run straight through the target only overlaps on the server AFTER the claim arrives,
hence the wait; (b) a runner trailing its target at a touch never overlaps it in any single server frame, so no wait
helps, hence pairing with older target samples. For two clients the target is two hops old on the tagger's screen
(its upload ~0.18 s plus replication to the tagger), so the allowance is 0.4 s + ping, cap 0.5 s (was 0.3). **What
the tagger gains:** a target up to 0.5 s in the past, ~22 studs at run speed for a very laggy tagger; ~0.4 s for
everyone in Studio. That is the price of Roblox's interpolation on both hops; the cap is the bound, and it is
Danzo's to tighten if two-player Play shows tags that look unfair. The first tag in H5's test worked only because
the dummy walked into a standing player. The dummy's own claims stay same-frame (its position is the truth; it does
tag the player's lagging copy, a small edge for the Studio stand-in only).

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

**Round start:** the first holder waits `START_FREEZE` while everyone scatters, also with the fuse paused. **H6:**
3 s -> **1 s** (Danzo disliked 3 s; 1 s is the proposal, his to tune), and every wait is now counted down big in the
middle of the holder's screen ("1.4", "0.3", then "GO!" for 0.7 s) while everyone else sees "RUN!" (§6). The old cue
was a small "frozen 3.0" line, which read as being stuck. **Checked in Play:** a key pressed during the wait and held
starts the run on the first frame after GO with no re-press (a 6 s test freeze, key down at 3.0, `vx` 25 then 45 at
GO). So the freeze is not what needed "click and release": see movement.md §5, Studio focus. **Open (not built):** the
wait counts from the server's round start, and in Studio the client draws its first frame ~2.5 s later, so round 1's
1 s wait is over before it is seen. Waiting for each client to be ready needs a client -> server "ready" remote
(trigger 3); propose it with the second-player work if round 1 feels unfair.

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
alive player at 30 studs/s (both below the 45 run speed, so it can be caught and escaped). **`CanQuery = false`
(H6):** before, the client's wall probes hit it, so it was a moving wall that stopped a chaser dead behind it (`vx`
sawing 0 to -42 at a 2-stud gap in the log), refreshed the dash on contact and made a run-through impossible. It never plays alone.
Players tag it with a normal claim; as it, the server checks its overlaps itself each frame with no rewind.
**The second path:** Studio's Test tab → Clients and Servers, 2 players: real clients, real claims, ids -1 and -2.

## 5. Decision (e): "the fuse shrinks across the match" — per elimination, 45 → 35 → 25

`Tag.freshFuse(eliminations) = max(FUSE_MIN, FUSE_START - FUSE_SHRINK x eliminations)`: 45, 35, 25 in a 4-player
match (`FUSE_SHRINK = 10`, floor `FUSE_MIN = 15`). It applies to the fresh fuse a new holder gets after an elimination.
**A pass is never touched: always remaining + 5**, exactly as §2 locks it. *Trial (Danzo, 2026-10-11):*
`FUSE_PASS_BONUS` is **2** for now, recorded under DESIGN §2; the rule (remaining + bonus) is unchanged.
**Cap (Danzo, 2026-10-11):** a pass never lifts the fuse above the fuse this life started with: `min(remaining +
bonus, Tag.freshFuse(eliminations))`, so 45 on the first life, then 35, 25. Seen in Play: `fuse 45.0s` after quick passes.

**Why not per pass:** shrinking anything on a pass would change the locked "remaining + 5 s". **Why not per round**
of a best-of session: §2 says "across the match"; a match is one game to the last runner (2–3 minutes, §1), and
session structure is §6.4, still open. Per elimination also serves rule 3 (force an ending): the final duel starts on
25 s. Worst case with no passes: 45 + 35 + 25 = 105 s, inside the 2–3 minute target.

**Decided (Danzo, 2026-10-11, after H6's Play):** quick passes no longer grow the fuse past the life's fresh fuse
(the cap above). Rule 3's "speed up the fuse" at the final two stays open.

## 6. Feel and readability (rules 2, 4, 21)

- **Rule 4, the chaser ramp** (`Tag.chaserBoost`): no boost for the first 5 s of a chase, then up to +15% run speed
  over 15 s; the chase clock starts when the holder's freeze ends, so every tag resets it. Applied by the holder's
  client through `Movement`'s `speedMult` (the earned-speed bleed uses the boosted top too).
- **Rule 2, readable fuse — partly:** the fuse in seconds at the top centre (red "YOU'RE IT" when yours), "+N -> name"
  on every pass, the IT marker over the holder, the big wait countdown / "GO!" / "RUN!" (§3), out/winner lines. The
  growing, beeping, glowing bomb is art and sound, still to come.
- **The IT marker (Danzo, 2026-10-11): a big red glowing triangle** pointing down at the holder, 3 x 2.6 studs, 0.6
  above the head: two neon wedges, and two larger see-through ones behind as a pulsing halo, local to each client
  (`Hud.lua`). Not a BillboardGui: H5's "IT" one sat inside the ScreenGui and never drew (→ A5). Seen in a capture,
  over the player and then over the dummy.
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

**H6, 2026-10-11 (Studio Play, solo with the dummy, remotes live):** `npm test` 13 node + 5 Luau files ok;
`lint:luau` every file ok; `rojo build` ok; tree unchanged (no file added or moved). Mutations: removing the cap, the
target-not-newer check, the allowance bound, the window start, the deadline, the wait, either cap on the look-back,
or the dash cooldown check (or restoring 0.2) each fails a test. In Play: three runs through the dummy while it and
unfrozen, three tags, each ~0.13 s after the crossing; no `dropped` line; crossings while frozen never tag; the
dummy's tags, the +2, the 45.0 cap, the countdown and "GO!", "RUN!", and the triangle seen. Before the fix the same
run logged `claim 8061215879 -> -1000 dropped: no overlap in the server's last 0.10s`.

## 8. The numbers (`shared/Config.lua`)

| Knob | Value | What |
|---|---|---|
| `FUSE_START` | 45 | the first holder's fuse (§2, locked) |
| `FUSE_PASS_BONUS` | 2 | remaining + this on a tag (§2 says 5; Danzo's trial), capped at the life's fresh fuse |
| `TAG_FREEZE` | 1.5 | new holder frozen, fuse paused (rule 1) |
| `START_FREEZE` | 1 | first holder's wait at round start (H6: was 3) |
| `FUSE_SHRINK`, `FUSE_MIN` | 10, 15 | fresh fuse after each elimination (§5) |
| `TAG_REACH` | 0.5 | studs past touching that count, on the client and the server |
| `TAG_GRACE` | 1.5 | extra studs the server allows |
| `TAG_VIEW_DELAY` | 0.4 | the target may be this much + ping older than the claimant (H6) |
| `TAG_REWIND_MAX` | 0.5 | that allowance at most (H6: was 0.3) |
| `TAG_CONFIRM_WAIT` | 0.35 | a claim stays open this long for the claimant's late samples (H6) |
| `TAG_CLAIM_GAP` | 0.1 | claims closer than this dropped |
| `RAMP_DELAY`, `RAMP_TIME`, `RAMP_MAX` | 5, 15, 0.15 | the chaser ramp (rule 4) |
| `HIT_STOP` | 0.08 | rule 21 |
| `ROUND_GAP` | 4 | seconds between rounds |
| `STUDIO_DUMMY` | true | the dummy, Studio only |

## 9. H6 verdicts (Danzo's first Play with the remotes, 2026-10-11)

1. **"Only able to tag the block once": a bug, two of them.** The server judged claims too early and too strictly
   (§2, H6 correction), and the dummy was a wall to the client's probes (§4). Fixed; three of three run-through tags
   confirm in Play. Readability added too: "RUN!" while the holder waits, the triangle (§6).
2. **"Frozen at the start, have to click and release": the wait was real and unreadable; the re-press was not the
   freeze.** `START_FREEZE` 3 -> 1 s with a countdown to GO (§3). A held key resumes after the freeze (checked). The
   re-press is most likely Studio's game view not having keyboard focus after Play (movement.md §5); unconfirmed.
3. **Dash spam: real**, fixed with a longer cooldown (movement.md §3, `DASH_COOLDOWN` 0.8).

## Expansion: deficits at scale

- **Position trust** is movement trust (§2): the first real fix is the movement event with a server speed check.
- **History cost:** 60 samples per runner, a table each (H6: was 30, to cover the claim window). Four runners: 240
  small tables, trivial. An open claim scans up to 60 x 60 sample pairs a frame for at most 0.35 s. If runner counts
  grow, store x/y in flat ring arrays and walk the target with a moving start index.
- **`MatchState` every second** to every client is a few hundred bytes; fine at 4 players.
- **Claims scan every tagged runner per frame** on the holder's client (4 runners: nothing). Keep it that way.
