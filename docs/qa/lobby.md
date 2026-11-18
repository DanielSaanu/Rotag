# QA goals: the walk-in lobby, built (doors, the queue, rooms, practice, the callouts)

Branch: `claude/friendly-hawking-74891i`. Handoff H37 (2026-11-18). System doc: `docs/systems/lobby.md` (read it
first). The design it grew from: `docs/qa/lobby-design-summary.md`. Danzo's asks, in his words:

- "build it then run the /qa-loop on the actual lobby ... the goal is for easy clear playability; kids should
  understand and not get flustered or rushed or confused what's going on"
- "there should also be big flashy words to explain what's going on for time-sensitive actions: say a player has
  queued for a match and is now running around, there should be a clear indication for them that they are still in
  the queue after leaving [the door]; a clear indication when the game is about to start; a clear indication for
  how to leave / unqueue, and a clear indication when that has been achieved. That is just one point of many: you
  should independently verify where and when indications are necessary and make them clear and make them fit the
  game's vibe / style"
- of the first build: "too small, not enough space, you can't stand anywhere; I intended the lobby to be full of
  random players"; "locker and play on the bottom floor while practice and play with friends are higher up"; "the
  labels were off centred" (he likes the asymmetric layout itself); "the colours are too similar, I can't even
  really tell the difference between the green and gold"
- "if the QA agent finds that it is bad or that maybe the map itself is the issue do not hesitate to modify or
  switch things up or try new avenues". So: the reviewer may say the layout itself is wrong.

The question: **does a kid who has never seen the game know where to go, know at every moment what state they are
in and what happens next, and never feel rushed or lost?**

## Goals

1. **Where to go.** From the spawn, QUICK MATCH is the obvious default; LOCKER, PRACTICE, HOST A ROOM and ENTER A
   CODE are each findable and told apart by place, colour and one or two words. Colours are clearly different.
2. **Room to stand.** The lobby has open floor and somewhere to run about; it would hold a crowd of runners.
3. **Layered, centred labels.** PLAY and LOCKER downstairs, PRACTICE and friends upstairs; every sign sits centred on
   its own door; nothing overlaps anything.
4. **Choosing is physical and safe.** A second in a door chooses it; running past never does; nothing fires twice.
5. **Always know your state (the indications, below).** At every listed moment the screen says what is happening,
   in big words in the game's style, without burying the player in lines.
6. **Never rushed.** Nothing starts that the player did not ask for; after a match the player is back where they
   wait and chooses again; a countdown is always announced before the player is moved.
7. **Rooms.** A host gets a code they can read across a room; settings change by jumping into a block and say so;
   START explains itself; a non-host is told who the host is; the room never stalls.
8. **A phone.** The words fit a phone held sideways; nothing important sits under the thumbs; the code pad's keys
   are finger-sized.
9. **Fairness (trigger 3).** Every request is judged on the server (`server/Doors`): position, host, rate.
10. **Nothing broke.** A quick match still runs from the lobby to the podium and back; `npm test` and
    `npm run lint:luau` green; the Rojo tree only grew; the line ceiling holds.

## Indications: the moments the builder decided need words (verify each; say what is missing)

| # | Moment | What the screen says |
|---|---|---|
| 1 | arriving | `WELCOME TO ROTAG!` "run to a door and stand in it to choose"; then the pill `STAND IN A DOOR TO CHOOSE` |
| 2 | near a door | the caption: its name and one line |
| 3 | standing in a door | the doorway fills; `QUICK MATCH...` "stay in the door"; rising ticks |
| 4 | first QUICK MATCH ever | the how-to cards; GOT IT queues you |
| 5 | queued | big `YOU'RE IN THE QUEUE!`; the pill `IN THE QUEUE n / 4` stays wherever you run, with "match starts in N · keep moving!" and "to leave: go back to QUICK MATCH and stay 2 seconds"; the door itself shows n / 4 to everyone |
| 6 | someone else joins the queue | `A RUNNER JOINED!` n of 4 |
| 7 | about to start | menus close; `MATCH STARTS IN` 5-4-3-2-1 with ticks |
| 8 | match found (hub) | held `MATCH FOUND!` "taking you there: hang on" until the teleport; `STILL LOOKING...` if it failed |
| 9 | leaving the queue | a white fill, `LEAVING THE QUEUE...`; then big `YOU LEFT THE QUEUE` "stand in QUICK MATCH to play"; the pill returns to the idle hint |
| 10 | the locker while queued | the pill docks at the bottom edge, still showing the queue |
| 11 | practice | `PRACTICE!` "just you and bots · nothing counts"; pill `PRACTICE`; `PRACTICE STARTS IN` 3-2-1 |
| 12 | hosting | `MAKING YOUR ROOM...`; `YOUR ROOM IS OPEN!` "the code is 4827 · tell your friends"; pill `ROOM 4827` "YOU ARE THE HOST" + "stand in START when everyone is here" |
| 13 | joining by code | the pad; `LOOKING FOR ROOM 4827...`; `NO ROOM WITH THAT CODE` / `THAT ROOM IS FULL` on the pad; `YOU'RE IN THE ROOM!` "waiting for NAME to start" |
| 14 | in a room | `NAME JOINED!` / `NAME LEFT`; `ROUNDS: 5` etc.; `ONLY THE HOST CAN CHANGE THIS`; `YOU ARE THE HOST NOW` |
| 15 | START | host: the fill; refused: `YOU NEED 2 PLAYERS` "wait for a friend, or turn BOTS on"; everyone: `HERE WE GO!`, the 3-2-1 |
| 16 | back from a match | `GOOD GAME!` "stand in a door to play again" |
| 17 | anything refused | `NOT RIGHT NOW`, `COULDN'T GET THERE` "nothing is lost: try the door again" |

## How to test (the reviewer drives Studio)

Rojo is syncing. Start Play; wait ~8 s. To put the runner somewhere exactly, from the SERVER datamodel:
`require(game.ServerScriptService.Server.Runners).spawn(player, Vector3.new(x, y, 0))` (a rebuilt body, as the game
itself moves people). To arm a door, be outside every door first, then in it. Lobby origin x 600: QUICK MATCH
(604, 1.8), LOCKER (563, 1.8), PRACTICE (566, 19.9), HOST A ROOM (627.5, 19.9), ENTER A CODE (638.5, 19.9), open floor
(585, 1.8), between the pink doors (633, 19.9), the UP steps (549, 10.8 and 651, 10.8), the decks' ends (558 and 643, 19.8). Room origin x 800: START (832, 1.8), LOBBY (767, 1.8), a block
(783, 6.5 ROUNDS; 800, 6.5 ITEMS; 817, 6.5 BOTS; or stand under one at y 1.8 and press Space). Keys go through the keyboard tool (A/D, Space, Return, digits,
Escape). `screen_capture` after each step and LOOK. The server log prints `[Rotag] session: ...` for accepted and
refused requests. Stop Play when done. The how-to cards appear on the first QUICK MATCH of a session: Return closes them.

## What the builder saw, and did not

Seen on screen in Studio (2026-11-18): rows 1-5, 7, 9, 10 (before it docked), 11, 12, 13 (the refusal), 14 (settings),
15 (the refusal and a start into a round with three bots). `docs/systems/lobby.md` §9.

**Not seen:** rows 6, 8, 14's joins and host hand-over, 16 (needs a whole match), anything with a second person;
any live server (hub queue, room and practice servers, MemoryStore, teleports: Studio cannot); a phone-shaped
screen (Studio's window was 1656 x 606, short and very wide); a hand on the controls (walking into doors was done
by placing the body; one second's FEEL is Danzo's).

**Builder's doubts:** the upstairs doors need two jumps (a step, then the deck): is that obvious to a kid? The
lobby is flat blocks and neon with nobody in it when you are alone. Whether five lines of callout at once is ever
reached. Whether leaving the queue (step out, come back, 2 s) is discoverable without reading the small line.

## Out of scope

The tag itself (Danzo's "tagging is too hard" and his dash-tag rule are in `ideas/INBOX.md`, not built); art for the
lobby beyond blocks and neon; ranked; a 6-digit code; Roblox's "Join friend".
