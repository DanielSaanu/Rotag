# QA summary: the walk-in lobby, built (H37)

Goals: [lobby.md](lobby.md). System doc: [../systems/lobby.md](../systems/lobby.md). 2026-11-18. Three rounds, one
fresh Opus reviewer each, each driving Studio (Play, real keys, 25-29 captures a round). **Target 8/10 not met: 6,
7, 7.** Each round's FIX list was fully fixed; each round then found the next layer down. The last round's fixes are
in but have not been re-reviewed. Round reports: `archive/lobby-round*.md`.

| Round | Score | Main finding |
|---|---|---|
| 1 | 6/10 | A room's setting block changed twice per jump; the way upstairs ran past QUICK MATCH (a missed jump queued you); a private match swept in bystanders |
| 2 | 7/10 | The floating UP step was a ceiling under its own sign; landing on a deck landed you IN a door; room arrivals stood under the setting blocks |
| 3 | 7/10 | A full jump still landed inside ENTER A CODE on the right; the big line ran over the upstairs signs; the code pad followed you across the lobby |

## Fixed

**Round 1:** setting blocks change once a jump (client hold + a 1 s server gap); the way up moved to the two ends
under UP signs; a private match seats, counts and pays only its own group; the room's wall re-laid; the podium says
"back to the lobby / room in N"; YOU LEFT THE MATCH; the leave hint stays through the count; "# CODE"; a bigger pad.

**Round 2:** the UP steps are solid blocks on the floor; 8 studs of plain landing on each deck; the room's code
lower and left; arrivals between the blocks; Escape off the pad; a bigger, white leave hint.

**Round 3 (not re-reviewed):** only a door you WALK into counts (a door entered from the air does not answer); a
dark plate under the big line and the count; the pad closes when you leave its door; leaving the queue never takes
longer than the count has left; never five lines at once; **a real bug: bots had no stream in a server's second
match** (each match rebuilds them; the client kept the old stream).

## Preserved (praised, and confirmed in later rounds)

- The doorway that fills with light, and its caption: read where the player is already looking.
- One choice per visit: standing in a door after choosing never fires it again.
- Every word comes from what the server sent back; a refusal shows nothing optimistic.
- The pill that docks under the locker; a countdown closes every menu.
- The four colours, two levels and asymmetric layout Danzo asked for; signs centred on their doors.
- The room: one change per jump, the code off the callouts' rows, GOOD GAME that says who starts next, a match
  that comes back to the room and waits.
- `server/Doors`: position, host and rate judged on the server's own record (goal 9 met in all three rounds).

## Deferred, and why

- **The lobby's size and emptiness.** Reviewers 1 and 3 found the runner small (about 6% of screen height) and the
  lobby empty for one player; reviewers 2 and 3 said keep the size. Danzo asked for the space. His eyes, on a phone.
- **Bots walking the lobby** so it looks lived-in: changes what the lobby is; ask first.
- **A neon outline on the steps, a lip at each deck's inner end:** one-line map changes after he has played it.
- **The how-to cards as icons:** an art pass.

## Never run by anyone

- **Every live-server path:** the hub queue as changed, room and practice servers, the MemoryStore map, every
  teleport. Studio stands in for a room server; the real ones are unrun code.
- **Anything with two people:** a friend joining by code, host hand-over, A RUNNER JOINED!, MATCH FOUND, a queue
  waiting behind a private match.
- **A phone-shaped screen** (Studio's window was 1656 x 606) and **a hand on the controls**.

## Danzo's checklist

In Studio (Play):
1. **Arrive.** Do you know where to go within five seconds? Is the runner too small to enjoy at this zoom?
2. **QUICK MATCH.** Stand in it: the doorway fills, YOU'RE IN THE QUEUE!, the pill follows you. Run about. Go back,
   hold 2 s: YOU LEFT THE QUEUE. Does one second to join feel right? Does leaving feel findable?
3. **Queue, then try to leave at "2".** It should let you out (the hold shrinks to fit).
4. **Upstairs, both sides, five times each:** run to the wall under UP, jump onto the block from beside it, jump to
   the deck. Count the times a door starts filling that you did not walk into (should be none), and the times you
   fall off the deck's inner end.
5. **PRACTICE.** 3-2-1, a match with bots, back to the lobby, GOOD GAME!.
6. **HOST A ROOM.** Read the code. Jump into ROUNDS, ITEMS, BOTS: one change per jump, and it says so. BOTS OFF then
   START: YOU NEED 2 PLAYERS. BOTS ON, START: 3-2-1, the match, "back to the room in N", GOOD GAME.
7. **ENTER A CODE.** Walk in: the pad. A wrong code: NO ROOM WITH THAT CODE. Walk away: it closes.
8. **Play two matches in a row** and watch the bots in the second: they should move smoothly (the stream fix).
9. **On a phone:** can you read the pill and the signs; are your thumbs over anything you need?

On the PUBLISHED game with a friend (nothing here has run): QUICK MATCH from the hub (MATCH FOUND!, the teleport,
back afterwards); HOST A ROOM, your friend's ENTER A CODE, START, back to the room, the LOBBY door home; PRACTICE.
If rooms or practice misbehave live, QUICK MATCH is the H34 path and the fallback; `Config.HUB = false` is still
the switch for the whole hub.
