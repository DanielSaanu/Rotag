# The endgame: ignition, end-phase speed and the closing walls (ghosts v2 PR 5, 5b)

**Built:** 2026-10-31, handoff H23 (heavy); the closing walls 2026-11-01, H24 (heavy), §7. **Design:** `docs/DESIGN.md` §3 rules 2 (make the fuse readable), 3 (force
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
slot, §6.5); rule 3's map shrink (built early as the closing walls, §7, H24); a HUD countdown to the time cap (not built: the
line appears when it starts).

## QA round 1 (2026-10-31, 8/10)

Fixed: the embers' `LightEmission` 1 → 0.5 and top rate 60 → 35 (the sprite whited out in the last second; the rim
is the signal); the burst at z 4.6, in front of the map's front face (a burst against a wall was cut in half); the
holder's off-screen arrow beats red → hot yellow with `Tagging.ignition`; a dark stroke and brighter orange on the
FINAL TWO line; the flash swell 0.35 → 0.5 s. Deferred: a duel that reaches the time cap is labelled FINAL TWO
(the HUD reads `#alive <= 2`; saying OVERTIME there needs the round's start count in `MatchState`; rounds start with
two only in Studio today). Known race, no harm: a holder who LEAVES can get a burst at its last drawn spot if the
`MatchState` lands before the model removal replicates.

## 7. The closing walls (H24, PR 5b, 2026-11-01)

**Asked (Danzo):** "be like SpeedRunners ... with the walls closing. Don't have it kill you instantly and don't make
it solid ... the characters who are off screen are given a short time frame to return to screen before they die",
blended with PR 5. Built by the heavy agent while Danzo was away; every call below is his to confirm.

### 7.1 What SpeedRunners does (research, 2026-11-01; fan sources and reviews, no official numbers)

- **One shared camera follows the leader**; a runner who falls far enough behind its edge is knocked out at once,
  with no grace ("outscreened") (Wikipedia; Steam guides; the SpeedRunners 2 forum).
- **Sudden death** starts after the first knockout, or after a set time with none (one review: about a minute, with a
  timer shown): a **red frame appears at the screen's edge and grows inward**; the area outside "glows red"; the
  **music speeds up**; it shrinks until one runner is left; the screen is restored next round (PC Gamer, GamingCypher,
  a GameSpot user review, TV Tropes' "Advancing Wall of Doom").
- **The developer chose shrinking over zooming** on purpose: "It's really obvious what's going on when it's shrinking";
  players added that zooming would "throw off timing" and that the narrowing "feels like tunnel vision" (Steam thread
  "Screen narrowing VS zooming in", 2013).
- **What players complained about:** the screen gets very small with four players (same thread; CGMagazine called the
  screen-minimising its one real complaint); it is not obvious what makes the screen close in (Cubed3); online,
  lag killed players at the edge, which the developer answered by not letting high-ping clients decide their own
  off-screen state (Steam "camera glitch" threads, unverified). The game is 16:9 only because the edge kills.
- Numbers (rate, timer, any grace) are not published anywhere found. Ours are trial numbers (§7.5).

### 7.2 The translation: a world-space window the server owns (DESIGN §2 untouched)

A shared camera is out: DESIGN §2 locks "each player has their own camera, with off-screen arrows", and the map is
bigger than the screen by design. So the **screen** becomes a **window in world space**, drawn as two walls everyone
sees at the same place. What carries over, and what changes:

| SpeedRunners | Rotag | Why |
|---|---|---|
| the screen's edge kills | the walls' edge starts a **3 s grace**, reset the moment you are back in | Danzo: no instant kill; also the lag lesson (an instant edge kill is where latency kills) |
| the red frame grows in from the screen's edge | the walls appear just outside the living pack (each `WALL_START_PAD` past the farthest, never nearer than `WALL_START_MIN`, half a 16:9 screen) and close over 20 s | nobody starts outside; on a centred screen they appear at its edges, as the frame does |
| shrinks until one is left | stops at `WALL_MIN_HW` (a 48-stud box, both walls on one screen) | the "too small" complaint; the fuse, not the box, ends the duel |
| shrinking, not zooming | **no camera zoom**; `SideCam` unchanged | the developer's own reason (readable), and zoom throws off distance and timing |
| out of bounds glows red | a red see-through band past each wall, in front of the map | the same read, on every screen |
| the music speeds up | the walls' neon edge beats 1 -> 4 times a second as they close | rule 2's beat, no sound yet |
| the camera follows the leader | the window's centre **eases** toward the living mean (2 s time constant), never faster than 8 studs/s | tag has no leader: following the holder kills the best escaper, and following a duel's midpoint puts both out at once; a slow mean is a zone nobody can drag |
| it starts after a knockout or a timer | it starts **with PR 5's end phase**: the final two of a 3+ round, or `END_PHASE_AFTER` (120 s) | one moment, one line (`FINAL TWO` / `OVERTIME: the walls close in  \|  +10% speed`); a close from the first burn-out would make most rounds a shrinking zone and shorten the ghosts' part |
| (the edge is not a wall) | **not solid**: nothing collides or is queried; runners and ghosts cross freely | Danzo |

**Kept from PR 5 (its reviewer's PRESERVE list):** `Tag.endPhase` still has no stored flag (the walls open on its
first true frame); the +10% end-phase speed stays (the walls force the meeting, the speed makes it quick; together they
are SpeedRunners' rising tempo); the ignition, the burn-out, the beating readout and the end-phase line stay; clients
still normalise `endPhase == true`. `MoveCheck` untouched: nothing physical changed.

### 7.3 Who owns what

| Piece | Where | Decides or draws |
|---|---|---|
| The window, the follow, the grace, the order of deaths | `shared/Walls.lua` (new, pure) | the server calls `open` / `step`; tested in `walls.test.luau` |
| An elimination (burn-out or walls) | `shared/Tag.eliminate` (new; `Tag.tick` calls it) | one path: a ghost, the next fuse shrinks; the holder's death passes a fresh fuse |
| Stepping it on the server's record | `server/Walls.lua` (new) | server, every frame after `Tag.tick`; Studio log `walls: ...` |
| Telling clients | `MatchState.window` `{ x, hw, vx, vhw }` (absent: no walls) and `MatchState.outside` `{ { id, left, held? } }` | server; sent at once when anyone goes out or comes back, 4 a second while the walls move |
| A dummy outside walks back in | `server/Bots` via `Walls.backIn` | Studio only |
| The walls, the red band, the edge glow, `GET BACK IN  2.1` | `client/Walls.lua` (new) | client only, from `MatchState`; extrapolates the window up to 0.5 s |
| The burst for a wall kill (red; a burn-out stays orange) | `client/Ignition.state` | client, from the state change and the last `outside` list |

No new remote. Nothing new trusted from a client.

### 7.4 The rules (server, `Walls.step`)

- **Outside** = the runner's whole body is past a wall (`|x - centre| > hw + RUNNER_WIDTH / 2`), judged on its newest
  sample in Match's history (the snapshot stream, the record a tag is judged on, netcode.md §8).
- **The grace** starts at `WALL_GRACE` (3 s) on the first frame outside, runs down, and is cleared the frame the runner
  is back in; going out again starts a full grace. At 0: `Tag.eliminate`, exactly like a burn-out (a ghost; the next
  fresh fuse shrinks; the holder's death gives the next runner in rotation a fresh fuse and the tag freeze).
- **Paused, never reset, while held:** the holder's tag freeze, and any item hold (trap, freeze, stumble). A hold
  next to a wall must not kill a runner who could not move (rule 11).
- **Trust (trust.md §4-5):** a sample marked `untrusted` by the speed check changes nothing, either way: a teleport
  back inside never resets a grace, and an untrusted "outside" starts none. No sample at all: no change.
- **Ghosts** are never judged; a **leave** clears the row and is not a wall kill.
- **Two graces out on one frame:** the one further past 0 dies first; a tie, the holder first; then join order. Each
  goes through `Tag.eliminate`, which refuses once the round is over: in a final two the second never dies.
- **Lateness:** the server sees a runner one link hop after it moved, both going out and coming back, so the grace is
  the same length, shifted by the link. The HUD counts the server's number down from its arrival, and shows
  `GET BACK IN` at once from the local position (a prediction) before the server's row lands.

### 7.5 The numbers (`shared/Config.lua`, trial, tuned by hand)

| Knob | Value | Why |
|---|---|---|
| `WALL_GRACE` | 3 s | Danzo's "short time frame"; at a run (45) that is 135 studs back, far more than the pad |
| `WALL_START_PAD` | 8 studs | two tiles: nobody starts outside, and the walls appear near the pack |
| `WALL_START_MIN` | 44 studs | half a 16:9 screen (85.3 wide): centred, the walls appear at the screen's edges |
| `WALL_MIN_HW` | 24 studs | a 48-stud box (12 tiles): both walls on one 16:9 screen, still room for a duel |
| `WALL_CLOSE_TIME` | 20 s | the last fresh fuse of a 4-runner round is 25 s: the final duel spends its end in the box |
| `WALL_FOLLOW` | 8 studs/s | under a fifth of a run: a zone, never a camera you can drag |
| `WALL_EASE` | 0.5 /s | seen in Studio (§7.6): a hard 8 studs/s chase swung the walls 16 studs with the dummies' patrol |

`walls.test` pins the shape: the start is at least half a screen, the closed box fits a screen and is 10+ tiles, a
wall never comes at a runner faster than half a run, the grace is longer than a short way back and no more than 3 s.

### 7.6 Seen in Studio (2026-11-01, solo Play, 3 dummies, `END_PHASE_AFTER` = 15 for the test, put back to 120)

The viewport did not render in this session (`ViewportSize` 1x1, 0 `RenderStepped` frames, captures timed out, keys
did not reach the runner), so there is **no screen capture**; what follows is the server's and the client's Output, and
the real client modules run in the Client datamodel on Heartbeat (→ T13).

- `walls: closing in: centre 8.7, half-width 76.7 -> 24 over 20s` on the same frame as `END PHASE: 4 alive, 15s`.
- I stood at x -60: `... is outside the walls` 2.6 s later, `... stayed outside the walls, eliminated; -1000 is it`
  **3.00 s** after that (timestamps); the client printed `walled out: ... at (-60.0, 1.8)` (the red burst).
- `client/Walls.update` fed by `client/Tagging` from the live `MatchState`: the edges at the server's window, closing to
  48 apart; the label `GET BACK IN  0.3  >>>` (the arrow toward the centre) while I was out; empty once I was a ghost.
  The edges swung 16 studs back and forth with the dummies' patrol: hence `WALL_EASE` (test: a +-13-stud sway now moves
  them under 10; the old rule moved them 17.5).
- Dummies moved out by hand from the Server datamodel: one 48 studs out was `back inside` 1.9 s later (walked back by
  `Bots`); one 117 studs out was eliminated 3.00 s after going out, which ended the round (`winner -1001`); round 2
  started with no walls. An orange `burn-out` between them. No errors or warnings.
- **Not seen:** the look on screen (the walls, the band, the edge glow, the label's beat), anything under a hand, a
  second client. The second run's red burst was placed at the dummy's last DRAWN spot, stale because nothing was
  being drawn; with a live viewport `Others.drawnAt` is current.

### 7.7 Left for later

Per-map window bounds and a vertical shrink (PR 6's map data: a tall map may want a floor and ceiling band too); a
countdown over OTHER runners outside (a world label needs a SurfaceGui, A5); sounds; art for the walls (sheet,
behind `Sprites.Has`). A wall-kill burst on a runner that LEFT in the same frame can play at its last drawn spot (the
same harmless race as §6).

### Sources (H24)

- https://en.wikipedia.org/wiki/SpeedRunners
- https://www.pcgamer.com/speedrunners-review-early-access/
- https://steamcommunity.com/app/207140/discussions/2/666826069005560656/ (narrowing vs zooming; the developer's reply)
- https://steamcommunity.com/app/207140/discussions/2/537405286644253320/ (the camera and lag at the edge)
- https://steamcommunity.com/app/3183760/discussions/0/614286180499908010/ (outscreen = kill)
- https://www.gamingcypher.com/speedrunners-review-xbox-one/ (red out of bounds, the music)
- https://www.gamespot.com/speedrunners/user-reviews/2200-12729647/ (the music speeds up)
- https://www.cgmagonline.com/review/game/speedrunners-pc-review/ · https://cubed3.com/review/2825/1/speedrunners-pc.html
- https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/SpeedRunners (403 to the fetcher; cited by the routine session)
