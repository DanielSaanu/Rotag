# QA round 2: the playtest fixes — 5/10

Reviewer: Opus subagent, 2026-11-22. Branch `claude/friendly-hawking-74891i` @ c8a05c4, goals file adc6543 (with
"Limits of this loop"). Studio: one Play session through execute_luau only. Judged blind (no 3D drawn): goals 3-7.
The drop from 7 is the BLOCKER: the first live match this loop ran froze before the podium.

## Report (verbatim)

SCORE: 5/10

What I ran:
- `npm test`: 13 pass, 0 fail. `npm run lint:luau` is ok on every file.
- One Play session on "Rotag (placeId 81535510598835)", driven only through execute_luau. I stopped it at the end. Danzo's other Studio window ("AirGear") was not touched.
- New for the builder: from the **Client** datamodel, `ReplicatedStorage.Remotes.Menu:FireServer("play")` works. It queued the player (`[Rotag] session: Stifffchoclate is in the queue`), and a real round with three bots started. I hooked `MatchState` and `TagVerdict` on the Client and stored the payloads in Player attributes.

**BLOCKER, seen in the Output:** late in round 1 the server's `Match.step` throws every frame. The full error is in FIX. The round never reaches the podium.

GOALS:
- 1 A touch is a tag: partial. There is still no two-client measurement, so by the rubric this sits below 7.
  - No `TagVerdict` arrived in my run. I was an AFK "it".
  - The tag-back swap (TAG_FREEZE 1.5 s with the 1.25 reach) was not exercised.
- 2 IT can catch a good runner: partial (about 7.5).
  - `escape_sim.luau` gives 20/20 catches, worst 16 s. But that is on a flat 320-stud floor.
  - `wall_double.test` prints "one wall, a press every 9 frames: feet top out at 126.6 in 4 s". A runner can still go a long way up one wall, and no sim chases on a real map.
- 3 Closing walls can't be gamed: met, by code and live state.
  - A live MatchState showed `"refill":[{"id":-1000,"left":5.98}]` next to `"outside":[{"id":-1001,"left":5.44}]`.
  - `client/Walls.lua:139-149` shows "wall time x / 6" inside, and the GET BACK IN count starts from the pool.
  - Judged blind.
- 4 Ghosts read as ghosts: partial. The "GHOST" name prefix and the RUNNERS banner are there by code. The look is still only 0.3/0.5 transparency, and nothing was captured.
- 5 Grapple explains itself: met, blind (capped at 8). `map "yard": 21 parts, 7 grapple anchors` in the Output, plus the dimmed button and the hint.
- 6 Tutorial by doing: met, blind (capped at 8).
  - The Output shows `tutorial: the course built at x 1100 (7 rooms)`.
  - `tutorial.test` lands 102/102 timings from past the line up to the face (0 kicks), and the target is tagged in 1.1-2.4 s.
  - The first-join start was correctly not offered: the profile load failed with a 403 (`Course.lua:247`).
- 7 Arrow buttons option: partial. It is still session-only, the same as round 1.
- 8 Fun, and you come back: partial. Nothing new for retention. Worse, the stalled match below is the dead time this goal forbids.
- 9 Nothing broke: **not met**. Tests and lint are green, but a live match froze before the podium (FIX 1).

PRESERVE (done well, must survive future iterations):
- H42's rule (`shared/Movement.lua:224-231`): pressing jump while rising beside a wall uses the double jump, unless the stick pushes away or `wallUsed` is set. Why keep it: it closes the testers' "slid off" problem across every map, not just the tutorial, and the chimney test still gets 6 kicks and 0 double jumps.
- `wall_double.test.luau`: mutation-checked, with the climb bounded (at most one double jump beside a wall per flight). Why keep it: it is the guard against an endless wall climb.
- `refill` in MatchState (`server/Walls.lua:74-86`). Why keep it: it is read-only for clients, the server keeps the pool, and DESIGN rule 6 is intact.
- The `Snapshot.unpack` integer decode. Why keep it: a client cannot inject NaN or huge floats, so the NaN below is not a client exploit.

FIX (done poorly; why it matters; concretely how to fix):
- **Match stalls on a NaN in the bot planner.** The Server Output repeats every frame:
  ```
  ReplicatedStorage.Shared.BoxWorld:170: table index is NaN
  ... Bots:145 think <- Bots:176 stepBot <- Bots:252/249 move <- Match:279 step
  ```
  - Why it matters: `Bots.move` runs before `sample`, `judgePending`, the fuse and `Walls.step` (`Match.lua:275-285`). So one bad goal freezes tags, the fuse, the walls and MatchState for everyone.
  - The client log shows "longest gap 13128 ms" before `burn-out: -1002`. MatchState then stopped for good, at round 1: endPhase true, it -1000, ghosts 2, and -1001 outside the walls.
  - The NaN is the goal (gx, gy) passed into `BoxWorld.field` (`BoxWorld.lua:170`, `out[start] = 0`). The bot bodies' positions were finite.
  - Candidates, unconfirmed: `Walls.backIn` (w.x) for the bot outside; a history sample of the stashed ghost (Fizzy Panda 40 at y -1000000); the replayed `m.last`.
  - How to fix:
    1. In `Bots.think`, reject non-finite `gx`/`gy` (`gx ~= gx`), fall back to `BotBrain.IDLE`, and log the bot id, mode, goal, `s.x`/`s.y` and `Walls.backIn` once.
    2. Isolate `Bots.move` from the rest of `step`: guard each bot with pcall, or move the call after the judge and fuse, so a bot bug can never freeze the match.
    3. Add a Luau test that drives BotMind with a runner outside the walls plus a ghost bot.
    4. Re-run the lobby -> podium -> lobby loop with the Client `Menu:FireServer("play")` trick.
- **Goal 1 still has no two-client log.** Why it matters: the rubric holds it below 7 without one. How to fix: Danzo runs Test > 2 Clients with the 4G simulator for 3 minutes and pastes the close-pass lines and refusals into the round file. Include a deliberate tag-back: both stand still when the freeze ends.
- **Arrows not remembered.** Why it matters: goal 7 asks for it. How to fix: hand it to Danzo as trigger 9, or label it "this visit only" in the setting.

CONSIDER (fine but could change; why; how):
- An escape sim on yard's real boxes. Why: the flat-floor sim misses walls and decks, where a single-wall climb (up to 126 studs in 4 s) or anchor chains may keep a runner safe for good. How: run `escape_sim` on yard with a runner that mixes wall climbs and hops.
- Ghost look. Why: 0.3 transparency alone may not read at phone size. How: desaturate or outline the ghost sprite, then judge it on one phone screenshot.
- The `ContentId rbxassetid://203785492 ... Asset type does not match` warning (3x per boot). Why: it is noise in every boot log. How: find it in the place file (it is not in `roblox/src`).

UNCERTAIN (could not verify):
- The root cause of the NaN: module state can't be read from the command bar, because `require` gives a fresh copy (`Bots.ids` was empty). I also can't say whether this branch introduced it. H31's full match ran clean on 2026-11-16, and nothing in H42 or the refill change does NaN-prone maths that I could find.
- Everything visual: ghosts, anchors, the tutorial rooms, the arrow buttons, the wall-time line. Studio was out of focus and I made no captures.
- The tag-back swap at 1.5 s with the 1.25 reach, and real-lag tags.
- Feel of the H42 double jump. Danzo should run at a 4-tile map ledge from close, press jump twice, and check that it lands. He should also check that kicking up a two-wall chimney still feels like kicks.

## Builder decisions

- **FIX the NaN freeze: escalated as H43** (trigger 4: the routine session read shared/Walls and BotMind and could not
  find it in one attempt). The brief carries all four of the reviewer's steps (guard, isolate, test, re-run).
- **FIX two-client evidence: deferred to Danzo** (same as round 1: he is gaming, the MCP cannot start a multi-client test).
- **FIX arrows remembered: label it.** The cheap half of the reviewer's fix: the switch says the choice lasts this
  visit. Saving it stays Danzo's trigger 9 call.
- **CONSIDER yard escape sim:** folded into round 3's ask if H43 leaves time; the flat result is the strong case for
  the runner, the map's end walls and the closing walls only help "it".
- **CONSIDER ghost look:** deferred again until a phone screenshot exists.
- **CONSIDER 203785492:** not ours. The routine session scanned every service's descendants in the Edit place across
  17 content properties and the repo: no match. Earlier QA rounds logged the same line as stock (CoreGui).
- **PRESERVE:** H42's rule and its test, `refill`, the Snapshot decode: untouched by this round's work.
