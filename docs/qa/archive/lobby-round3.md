# QA round 3: the walk-in lobby, built — SCORE 7/10 (the last round; target 8 not met)

Reviewer: a fresh Opus subagent, driving Studio with real keys and a 20 Hz path recorder (25 captures). 2026-11-18.
Report verbatim.

SCORE: 7/10

How I tested: I started Play from Edit mode, and it never stopped by itself. I stopped it at the end, and Studio is back in Edit. I took 25 captures (ScreenCapture_1 to 25) and recorded the runner's path at 20 Hz with a client script while pressing real keys. `npm test` shows fail 0. `npm run lint:luau` reports every file ok. This commit does not touch default.project.json.

GOALS:
- 1 Where to go: met. The colours are clearly different, QUICK MATCH is the big centre door, and UP signs sit at both ends (Cap_1).
- 2 Room to stand: partial. The floor is wide and open. With one player the runner is about 35 px in a 606 px window, so the lobby looks empty (Cap_1). This was deliberately kept.
- 3 Layered, centred labels: partial, and this is a regression. Moving PRACTICE and HOST A ROOM inward put their signs inside the callout band. The big line's second row is drawn on top of them: "keep moving: we'll grab you when it starts" runs across both the PRACTICE and HOST A sign (Cap_23), and BACK IN THE LOBBY's row sits right against them (Cap_22). The room is now clean: ROOM CODE no longer collides with anything (Cap_9, Cap_12).
- 4 Choosing is physical and safe: partial. On the left it works: from the spawn, holding A into the step and tapping Space put me on it at (545, 9.75), and a held D+Space landed at x 568 (local -32), 2 studs short of PRACTICE. I then ran through it without it firing. On the right it fails: a held A+Space from the step at (655, 9.8) landed at 630.4 (local 30.4), inside ENTER A CODE (27..36). With A released in mid-air the runner stopped at 629.1 and the code pad opened without being chosen (Cap_4). The path shows a full jump from a step carries about 24 studs, so the right deck's 8 studs of plain landing is not enough. Holding on instead runs you off the deck's inner end at x 15 and drops you at 612.6, 0.6 studs from QUICK MATCH's edge (Cap_3). The room blocks work: a jump the moment you arrive changed nothing (Cap_10). One jump turned BOTS OFF once (Cap_11), and ROUNDS went 3 to 5 to 1 one step at a time (Cap_12).
- 5 Always know your state: partial. I saw YOUR ROOM IS OPEN, the pill with its 19 px hint (Cap_10), BOTS: OFF, ROUNDS: 1, the 3-2-1 off the code (Cap_13), GOOD GAME "stand in START to play again" (Cap_21), BACK IN THE LOBBY (Cap_22), YOU'RE IN THE QUEUE plus the pill and the door's 1 / 4 (Cap_23). But the words collide with the signs (goal 3). At count "1", five lines stack in the top middle: the pill, "here it comes!", the leave hint, "LEAVING THE QUEUE... stay in the door" and "MATCH STARTS IN 1" (Cap_24).
- 6 Never rushed: partial. A room match returns you to the room and waits. But I tried to leave the queue during the last 2 s, and the leave fill could not finish, so I was taken into the match anyway (Cap_24 to Cap_25, log `match 2 round 1 of 3: 1 people`). The pad opening without being chosen (goal 4) is the other rush.
- 7 Rooms: met (solo). The code is readable, arrivals stand between the blocks at 791.5, START counted 3-2-1, a 1-round match paid +6 and went back to the room, and the LOBBY door worked. Joins and host hand-over need a second person and were not seen.
- 8 A phone: partial, reasoned only. The pad keys are 60 px. The big line now overlaps the upstairs signs, and on a narrower 2.16:1 screen the text sits in the same place over a narrower world, so the overlap will be at least as bad.
- 9 Fairness: met. This round changed nothing in Doors. Positions are still the server's own sample.
- 10 Nothing broke: met, in Studio and solo. A room match and then a quick match both ran. Tests and lint are green.

PRESERVE (done well, must survive future iterations):
- The solid steps against the walls (`shared/Lobby.lua:64-65`): nothing to bonk on, and from the spawn, holding A plus one Space puts you on the step.
- The room arrivals between the blocks (`Lobby.lua:98`) together with the "same jump" hold: a jump the moment you arrive changes nothing.
- The room code at the left, below the callouts (`LobbyMap.lua:143-148`): no collision even with the 3-2-1 up (Cap_13).
- Backspace on an empty entry closes the pad, and Escape no longer does (seen: Escape opened only Roblox's menu, the pad stayed, and Escape again closed the menu).
- The context-aware GOOD GAME, and the one-choice-per-visit dwell: standing in ENTER A CODE after closing the pad never re-fired.

FIX (done poorly; why it matters; concretely how to fix):
- Landing on the right deck lands you in ENTER A CODE: a full jump from a step carries about 24 studs, and only 8 of them are plain deck. The left side clears its door by just 2 studs. The test (`lobby.test.luau:93-100`) checks the geometry, not the jump. -> Robust fix: a door entered while airborne stays unarmed until the runner leaves it, i.e. only a door you walk into counts (in `Lobby.dwell`, pass a grounded flag). Also give each deck 16+ studs of plain landing, or shorten the right deck. Test it with a held jump simulated from each step's outer and inner edge using the shared movement maths.
- The big line overlaps the upstairs signs (Cap_22, Cap_23). This round's door move put PRACTICE and HOST A ROOM's signs into the callout rows, which breaks "nothing overlaps anything". -> Raise the big line about 40 px, or lower and shrink the deck signs, or put a dark backing plate under the big line's two rows. Re-capture with YOU'RE IN THE QUEUE showing.
- The code pad stays open wherever you walk. With the pad open I held A for 1.5 s and ran off the deck and into LOCKER, and the pad still covered the middle of the screen (Cap_8). A kid who opened it by accident (see above) walks away with it stuck there. -> Close the pad when the runner leaves the ENTER A CODE door, or moves more than 3 studs. Also fix the stale header comment (`CodePad.lua:3` still says Escape).

CONSIDER (fine but could change; why; how):
- Leaving at the last second: the 2 s leave hold can't beat a count already at 1 or 2, and you're taken in (Cap_24). -> While the leave fill runs, hold the start, or accept `sit` within the first 3 s of round 1 and send them home with YOU LEFT THE MATCH. Or let the leave fill count from LEAVE_HOLD down to the time left on the count.
- The pad gives no on-screen hint of how to close it (X only). -> Add a small line under the boxes: "BACKSPACE or X to close".
- The steps are the same dark blue as the wall, with only a neon top edge (Cap_1). -> Give them the doorway neon outline, so a kid reads them as "jump here".
- Ease of reaching the room from the right deck: HOST A ROOM sits at 16..25, so a runner overshooting off the inner end drops beside QUICK MATCH (612.6). -> Add a 1-stud lip at each deck's inner end.

UNCERTAIN (could not verify):
- Every live-server path (Hub.open/join/keep, MemoryStore, teleports). On a real practice server, `practiceArmed` (`Session.lua:235`) is never reset. If the only player's body is briefly missing after arming (count drops to 0, which clears `quickAt` at :241), the short count is never re-armed and falls back to LOBBY_TIME. This is a guess from reading the code.
- In match 2 (a quick match straight after the room match), the Output says "others: Ninja Wizard 5 has no stream: drawn from its body through the trail" for all three bots. In match 1 they streamed at 28 snapshots/s. This is outside these goals, but worth checking.
- Anything with two people: joins, host hand-over, A RUNNER JOINED!, MATCH FOUND / STILL LOOKING.
- The how-to cards were not shown, because this profile already has matches (`Menu.lua:55`). That is expected, not a bug.
- A real phone, and feel by hand. Danzo should, from the spawn, go up the RIGHT side to HOST A ROOM five times on keyboard and five on phone, holding the jump the way a kid would. Count how often ENTER A CODE opens by itself, and how often he drops off the deck beside QUICK MATCH.

## Builder decisions (after the last round: done, NOT re-reviewed)

**Fixed (all three FIX items):**
- **Only a door you walk into counts.** `Lobby.dwell` takes `standing`: a door entered from the air does not answer
  on that visit, and a hop inside a door pauses its clock (tested). The caption then says "Step out, then walk in to
  choose." Seen in Studio: a body dropped into ENTER A CODE stood there 3 s and the pad stayed shut. (The landings
  were not widened as well: with this rule where a jump lands no longer matters.)
- **A dark plate under the big line and the count,** so their words read over the world's signs for the few seconds
  they are up. Seen: YOU'RE IN THE QUEUE! over the PRACTICE and HOST A ROOM signs, readable.
- **The pad closes when the runner leaves its door** (3 studs); the stale Escape comment fixed; the pad opens
  saying "X, or walk away, to close".

**Taken from CONSIDER and UNCERTAIN:**
- **Leaving never takes longer than the count has left** (`Lobby.hold(id, queued, left)`: 2 s, down to 0.6 s; tested).
- **Never five lines:** while a doorway fills, its line stands in for the leave hint.
- **Bots "have no stream" in a server's second match: a real bug from H37, fixed.** A bot is rebuilt for every
  match now and its snapshots count from 0 again; the client held the old stream and threw every new snapshot away
  as stale. `client/Others` now drops a runner's stream with the runner. NOT re-seen (needs two matches in a row).
- `practiceArmed` is reset whenever the count drops to nobody.

**Deferred, with why:** a neon outline on the steps and a lip at each deck's inner end (look and feel calls for
Danzo's eyes and hands; both are one-line map changes).
