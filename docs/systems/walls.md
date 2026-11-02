# The closing walls (H24) and the moving window (H26)

Split out of [endgame.md](endgame.md) on 2026-11-02 (it had passed the ~300-line ceiling, G3). The section numbers are
kept as they were there, so a citation of "endgame.md §7.x" means this file's §7.x.

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
| the camera follows the leader | the window's centre **eases** (2 s time constant, never faster than 8 studs/s) toward a target that **loosely follows the living** (H26, §7.7): their mean, leaned a quarter of the way toward "it", plus a slow wander that never repeats, inside the map's window bounds | tag has no leader: following the holder alone kills the best escaper, and following a duel's midpoint at speed puts both out at once; a slow, leaning, wandering mean is a zone nobody can drag and nobody can camp in (Danzo, H26: "it always follows the runner but in a sort of irregular manner") |
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
| The map's window bounds (H26) | `server/Arena.WINDOW` `{ lo, hi }` (the end walls' inner faces) | passed to `open`; PR 6 gives each map its own |
| Telling clients | `MatchState.window` `{ x, hw, vx, vhw }` (absent: no walls) and `MatchState.outside` `{ { id, left, held? } }` | server; sent at once when anyone goes out or comes back (at most 5 a second, a death always at once), 4 a second while the walls move |
| A dummy outside walks back in; inside, it keeps 4 studs in from each wall | `server/Bots` via `Walls.backIn`, `Walls.room` | Studio only |
| The walls, the red band, the edge glow, `GET BACK IN  2.1` | `client/Walls.lua` (new) | client only, from `MatchState`; extrapolates the window up to 0.5 s |
| The burst for a wall kill (red; a burn-out stays orange) | `client/Ignition.state` | client, from the state change and the last `outside` list |

No new remote. Nothing new trusted from a client.

### 7.4 The rules (server, `Walls.step`)

- **Outside** = the runner's whole body is past a wall (`|x - centre| > hw + RUNNER_WIDTH / 2`), judged on its newest
  sample in Match's history (the snapshot stream, the record a tag is judged on, netcode.md §8).
- **Back inside** (H26 follow-up, §7.7) = the whole body back in: `|x - centre| <= hw + RUNNER_WIDTH / 2 - WALL_BACK_IN`
  (2 studs, so the centre is `RUNNER_WIDTH / 2` inside the wall). Straddling the wall keeps whatever you were.
- **The grace** starts at `WALL_GRACE` (3 s) on the first frame outside, runs down (straddling the wall included), and is
  cleared the frame the runner is back inside; going out again starts a full grace. A dip of half a body resets nothing. At 0: `Tag.eliminate`, exactly like a burn-out (a ghost; the next
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
| `WALL_FOLLOW` | 8 studs/s | under a fifth of a run: a zone, never a camera you can drag; the cap holds with the wander in (H26) |
| `WALL_EASE` | 0.5 /s | seen in Studio (§7.6): a hard 8 studs/s chase swung the walls 16 studs with the dummies' patrol |
| `WALL_LEAN` | 0.25 | H26, §7.7: a quarter of the way from the living mean to "it"; a duel's runner may be 38 studs from "it", not 48 |
| `WALL_DRIFT` | 20 studs | H26: the wander's reach in the target; after the ease a closed box sways ~24 studs end to end at up to 7.8 studs/s |
| `WALL_DRIFT_PERIOD` | 8 s | H26: the main sway; the second sine 1.618x slower, so the sum never repeats (12.9 s) |
| `WALL_BACK_IN` | 2 studs | H26 follow-up: back inside = the whole body in (`RUNNER_WIDTH`); the out/in hysteresis |

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
- **Not seen:** the look on screen, anything under a hand, a second client. (The red burst sat at the dummy's last
  DRAWN spot, stale only because nothing was drawn.)

### 7.7 The moving window (H26, 2026-11-02, heavy)

**Asked (Danzo):** the walls should "sort of track around the map and force players to interact/run away from each
other ... it always follows the runner but in a sort of irregular manner forcing the runner to be careful while also
forcing him to run from the chaser ... it 'loosely' follows the runners". **The problem:** H24's box closes and then
sits still (the pack's mean barely moves in a duel), so a chased runner can run laps in a static arena.

**Weighed:** (a) a **wander** on the target; (b) a **lean toward "it"**; (c) a **patrol** sweeping between the map's
bounds; (d) a lean toward the runners (the literal "follows the runner"). (c) ignores the players (a conveyor at 8
studs/s, 25 s a sweep): rejected. (d) frees the escaper: in a duel the box can only press on one of the two, and
leaning toward the runner presses on "it", who already wants to close in. (b) presses on the chased, which is the ask
("run from the chaser"); alone it is §7.2's "following the holder kills the best escaper", so it is a quarter-lean on
top of the mean, not a follow. (a) is the "irregular": a box that keeps moving is one nobody can camp in.

**Built: (a) + (b) on the mean.** `Walls.step` eases the centre (as H24: `WALL_EASE`, capped at `WALL_FOLLOW`) toward
`Walls.target = within(mean + WALL_LEAN x (holder - mean) + drift(t))`:
- `mean` = `Walls.centroid` (living, trusted, as H24); `holder` = `Walls.holderX`, the living holder's TRUSTED sample
  (none: no lean). A duel 40 apart: the target sits 5 studs toward "it"; the runner's room from "it" is 38, not 48.
- `drift(t) = WALL_DRIFT x p x (0.6 sin(2 pi t / P + a) + 0.4 sin(2 pi t / (1.618 P) + b))`, `t` since the walls
  appeared, `p` the close's progress (0 at the start, so the opening sweep still reads as a close; full once closed),
  phases `a`, `b` from a seed (the server's clock at the open: a new path each round; tests pin it). Never repeats.
- `within`: the window never goes past the map's bounds (`Arena.WINDOW`, the end walls' inner faces, §6.8); a pack
  against one end gets a box shifted inward that still holds everyone; a box wider than the map sits on its middle.
- Measured (`walls.test`, a still duel +-12, closed): the box sways 24.3 studs end to end, fastest 7.82 studs/s.

**Fair:** a wall still never comes at a runner faster than 8 + the close rate (under half a run). A runner who stays
with the pack is never walled out by the wander (|drift| <= 20 < 24, pinned); a runner who stands still away from it is
pushed out at some point (pinned: that is the pressure). The grace, its pauses and the death order are H24's,
untouched. **Trust:** the wander is a function of the server's clock and seed; the lean reads only the holder's
trusted sample; an untrusted sample changes nothing (pinned against a twin that never had it, to the last bit).

**Wire:** `MatchState.window` keeps its shape `{ x, hw, vx, vhw }`; `client/Walls` is unchanged. A closed box now keeps
moving, so the 4-a-second resend runs the whole end phase (H24 stopped it once settled). Extrapolating 0.25 s with
`vx` misses by under 0.22 studs (simulated; ~5 px at 1080p): a small step at each MatchState, to be looked at in Play.
`vx` is now 0 when nothing can be followed (it used to keep the last frame's value).

**Tests:** `walls.test` +4 blocks (the wander, the lean, the moving box, the bounds); two H24 checks re-pinned against
a twin (the untrusted drag, the +-13 sway) because the box now moves on its own clock. Mutation-checked: 16 mutants,
15 caught (the wider-than-map one by `math.clamp` erroring); the survivor (one of the two phases ignoring the seed)
still gives each round a new path, which is the property.

**Follow-up (2026-11-02, heavy, Studio):** runners at the swaying box's edge FLAPPED out/in every frame (~1650
`walls:` lines in 48 s, each an at-once MatchState): one threshold, a moving wall, and `Bots` patrolling into it. Fixed
(→ S16): hysteresis in `Walls.outside` (`WALL_BACK_IN`, §7.4: the grace resets only with the whole body back in);
out/in sends at most 5 a second (a death at once); a dummy keeps 4 studs inside each wall (`Walls.room`). Pinned: a
runner dancing +-0.9 on the swaying line flips once and dies at 0; a still one at the edge flips 7 times in 60 s; 5/5
mutants caught. **After, in Studio:** 0 flap lines over two closes and 40 s closed; 81 MatchStates in 20 s (the 4 Hz
resend); a still player swept over went out and in once; dummy -1001 pinned out was eliminated 3.00 s later.

**Calls for Danzo (by hand):** `WALL_LEAN` 0.25 (0: the plain mean; negative leans toward the runners, reading (d));
`WALL_DRIFT` 20 (12 if it feels like the box kills you; it must stay under `WALL_MIN_HW`, the pack rule, pinned);
the wander off while closing (fades in). **Not seen in Studio** (the main tree was busy): see the goals file
[ghosts-v2-walls-2.md](../qa/ghosts-v2-walls-2.md).

### 7.8 Left for later

The mean and the lean read each runner's NEWEST sample, so an untrusted one drops that runner for a frame and in a
duel the target jumps to the other (hidden by the easing; not exploitable, it only moves the box against the cheater):
read the last TRUSTED sample instead (QA H26 round 1, deferred). Per-map window bounds (one pair, `Arena.WINDOW`, built in H26) and a vertical shrink (PR 6's map data: a tall map may want a floor and ceiling band too); a
countdown over OTHER runners outside (a world label needs a SurfaceGui, A5); sounds; art for the walls (sheet,
behind `Sprites.Has`). A wall-kill burst on a runner that LEFT in the same frame can play at its last drawn spot (the
same harmless race as §6).

### QA round 1 on the moving window (2026-11-02, 8/10: target met)

Five rounds in Play: a new seed each round, the box never past -80, the fastest wall 8.2 studs/s, 0 flap lines over 8
minutes, GET BACK IN on and off once with no flicker. Fixed after it: `client/Walls` draws from a smoothed window
(`SMOOTH` 15/s; the wander's acceleration put each MatchState ~0.29 studs off the extrapolation: the largest per-frame
jump fell 0.290 → 0.037 studs over 2882 frames), the local prediction got the server's hysteresis band, and this
section left endgame.md (G3). Summary: `docs/qa/ghosts-v2-walls-2-summary.md`.

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
