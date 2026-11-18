# QA round 2: the walk-in lobby, built — SCORE 7/10

Reviewer: a fresh Opus subagent, driving Studio with real keys (24 captures). 2026-11-18. Report verbatim.

SCORE: 7/10

How I tested: I started Play from Edit mode and it ran the whole session without stopping by itself. I stopped Play at the end, and Studio is back in Edit. I drove the runner with real keys (A, D, Space, M, digits, Return, Escape) and took 24 captures (ScreenCapture_1 to 24). There were no errors in Output. `npm test`: fail 0. `npm run lint:luau`: every file ok. This commit does not touch `default.project.json`.

GOALS:
- 1 Where to go: met. The four colours are clearly different, QUICK MATCH is the biggest door in the centre, and white UP signs sit at both ends (Cap_1).
- 2 Room to stand: partial. The ground floor is wide and open. The runner is about 35 px tall in a 606 px window (Cap_1), so with one player it feels empty, not crowded.
- 3 Layered, centred labels: partial. The lobby is clean (Cap_1). In the room, the big line's sub-line sits on the same row as "ROOM CODE" and reads as one sentence: "ROOM CODE the code is 0888 · tell your friends" (Cap_10), and again "ROOM CODE wait for a friend, or turn BOTS on" (Cap_13).
- 4 Choosing is physical and safe: partial. Each jump now changes a block exactly once. I watched `botsValue` on the server through a short tap and two full jumps: `ON@0 OFF@0.11 ON@1.72 OFF@3.70`, and ROUNDS went 3 to 5 to 1, one step per jump. Running past QUICK MATCH at full speed never fired. But landing on a deck drops you straight into a door: PRACTICE fired and the 3-2-1 was at "1" before I had chosen anything (Cap_2). ENTER A CODE started filling the moment I landed (Cap_6).
- 5 Always know your state: met. I saw YOU LEFT THE MATCH after leaving a practice match (Cap_5) and after leaving a quick match (Cap_24), BACK IN THE LOBBY (Cap_21), the queue line and pill (Cap_22), and the leave hint still showing during the count (Cap_23). The hint is the smallest text on screen, about 11 px.
- 6 Never rushed: met (seen). The podium said "+6 coins · back to the room in 10" (Cap_19), then GOOD GAME! "stand in START to play again" in the room (Cap_20). The one exception is the accidental PRACTICE in goal 4.
- 7 Rooms: partial. The code is readable and no longer under the 3-2-1 (Cap_15). YOU NEED 2 PLAYERS showed (Cap_13), and a 1-round room match ran to the podium and back to the room. Joins, host hand-over and the queue-behind-a-private-match fix all need a second person and were not seen. Every seat spawns under a block (see FIX).
- 8 A phone: partial. This is reasoned, not seen. Pad keys are about 52 px at this window's scale (Cap_7). The seat names are about 8 px at the very bottom edge (Cap_10). On a phone (about 2.16:1) the room's code moves toward the centre, so the "ROOM CODE" collision gets worse.
- 9 Fairness: met. `set:` now also needs the player to be in the room (`Doors.lua:131`), `Room.set` refuses a second change within 1 s (`Room.lua:99-102`), and positions come from the server's own sample.
- 10 Nothing broke: met (Studio, solo). A quick match ran from the lobby into round 1, a room match ran to the podium and back, and tests and lint are green.

PRESERVE (done well, must survive future iterations):
- The "same jump" hold (`client/Lobby.lua:274-276`) plus the server's 1 s gap: one change per jump, measured live.
- The UP signs and the steps at the far ends: walking up with real keys took two jumps and never went near QUICK MATCH. The test at `lobby.test.luau:72-78` pins that.
- The podium and GOOD GAME text that depends on where you are (`Board.lua:191`, `Lobby.lua:171-173`): the words now match what really happens next.
- The pad's refusal, now 22 px heavy text with the boxes jumping (Cap_7), and "# CODE" in the doorway.
- The `only` roster (`Session.lua:48,78,205`): a private match seats, counts and pays only its own group.
- The hint stays up through the count (`Callout.lua:145-148`).

FIX (done poorly; why it matters; concretely how to fix):
- The step is a ceiling under its own UP sign. Spawned at (549, 1.8), a full Space jump peaked at y 6.34 and bonked on the underside of `StepLeft` (y 8). The natural move is to run to the wall under UP and jump, and that fails; you can only get on from beside it. -> Make the steps one-way platforms (pass through from below). Or leave a 3-4 stud gap between each step and the wall so the step can be reached from both sides, and point an arrow at the side to jump from.
- Landing on a deck lands you in a door. The left deck starts at x 556, and PRACTICE starts at 560. I landed at 569, inside the door, and PRACTICE fired (Cap_2). On the right I landed in ENTER A CODE (Cap_6). A kid stopping to look is in a 3-2-1 they did not choose. -> Leave at least 8 studs of plain deck between where you land and each door. Or don't start the door clock until the runner has been on the ground for 0.3 s and has just moved toward the door.
- The room's "ROOM CODE" title collides with the big line's sub-line on the same row (Cap_10, Cap_13). -> Move the code block down by about 3 studs (title at oy+28, digits at oy+22) or further left. Or make the room's big line one line only, with nothing under it.
- Every room seat is under a setting block. `SEATS_X` -18 / -6 / 6 / 18 sit under ROUNDS, ITEMS and BOTS (`Lobby.lua:31,65-67`), and arrivals spawn at the seats. A host's first happy jump changes a setting, and a friend's first jump shows "ONLY THE HOST CAN CHANGE THIS". -> Spawn arrivals between the blocks (about x -8.5 and 8.5) or near the LOBBY door, and keep the seats as floor marks only.
- Escape on the pad also opens Roblox's own menu. After Escape, `GuiService.MenuIsOpen` was true and A/D did nothing (Cap_8, Cap_9). Escape is reserved by Roblox. -> Close the pad with Backspace on an empty entry, or with its X, and remove Escape from the on-screen help.

CONSIDER (fine but could change; why; how):
- Lobby size: keep it. Danzo asked for space, and the floor does give room. The real problem is that the runner is only about 6% of the screen's height. -> Keep 112 studs, but on a narrow screen follow the runner at about a 48-stud view instead of showing the whole lobby. Add a few idle bot runners walking the floor so it looks lived-in.
- The leave hint is about 11 px. -> During the queue, put "LEAVE: STAND IN QUICK MATCH" on the pill's second line, which is larger.
- Two jumps within 1 s on one block: the second is silently ignored (`Room.lua:101` returns `key`). -> Fine for now; shorten `SET_GAP` to 0.6 s if hosts complain.
- A practice server's `quickAt` is cleared whenever `count == 0` (`Session.lua:234-235`). If the arriving body is not yet `present` on the first step, the server falls back to the arena lobby's 12 s timer. -> Set `quickAt` once `count > 0`, not at PlayerAdded.

UNCERTAIN (could not verify):
- Everything on live servers: Hub.open, join and keep, the MemoryStore reads and writes, the teleports, and the practice server's count from arrival.
- Anything that needs two players: a friend joining, host hand-over, A RUNNER JOINED!, and a quick-queued player waiting behind a private match ("a private match here goes first").
- The how-to cards did not appear on this session's QUICK MATCH, probably because they had already been seen; not checked.
- A real phone: thumb zones and text sizes are reasoned from a 1656 x 606 window.
- Feel: Danzo should, by hand, run from the spawn to PRACTICE and to HOST A ROOM five times each on keyboard and on phone. Count the bonks under UP and the times he lands inside a door he did not mean to choose.

## Builder decisions

**Fixed (all five FIX items):**
- **The steps are solid blocks standing on the floor** against each wall (x ±49..56, top 8): there is no "under" to
  bonk on; you jump onto one from beside it. Seen in Studio with real keys: Space + A from the floor landed on the
  step (545, 9.75); Space + D from there landed on the deck.
- **8+ studs of plain deck at each landing** before the first door (tested): PRACTICE moved to x -30..-18, HOST A
  ROOM 16..25, ENTER A CODE 27..36, the right deck now 15..44. Seen: the landing above came down beside PRACTICE,
  not in it.
- **The room's code** is lower and further left (title y 28.2, digits 18.2-26.2, x -26), off the big line's rows.
- **Room arrivals stand between the blocks** (x -8.5, 8.5, -25.5, 24.5; tested: never under one). The seats are
  floor marks only.
- **Escape no longer closes the pad** (it is Roblox's menu key): Backspace on an empty entry, the X, or gamepad B.

**Taken from CONSIDER:** the leave hint is 19 px and white (was 16, dim); a practice server's short count is armed
once its player is counted, not at PlayerAdded.

**Deferred, with why:** following the runner at a 48-stud view on narrow screens, and idle bots walking the lobby
(both change what the lobby IS; Danzo has not seen this size on a phone yet: his call first); `SET_GAP` 1 s stays.

**PRESERVE check:** the same-jump hold, the far-end steps and their test (the test now also holds them to the
floor), the podium / GOOD GAME text, the pad's refusal, the `only` roster, the hint through the count: untouched.
