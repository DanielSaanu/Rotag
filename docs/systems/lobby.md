# The walk-in lobby, private rooms and practice (H36 design, H37 build)

**Created:** 2026-11-18 (Fable session by Danzo's choice). Danzo: "rather than just buttons you click on the screen it
is a physical location in 2D space; it should be very obvious and clear where to go for what"; then, of the first
build: "too small, not enough space; I intended the lobby to be full of random players; locker and play on the
bottom floor while practice and play with friends are higher up; the labels were off centred; I can't tell the
green and gold apart"; and: "big flashy words to explain what's going on for time-sensitive actions". The design
loop: [../qa/lobby-design-summary.md](../qa/lobby-design-summary.md). The match itself: [session.md](session.md).

## 1. What a player meets

A player lands **in the lobby with a body**, not on a title screen. Every choice is a door; a door is chosen by
**standing in it for one second** (the doorway fills with light). Running past does nothing.

| Door | Where | Colour | What it does |
|---|---|---|---|
| **QUICK MATCH** | downstairs, the biggest | green | queues you for a match with other runners (bots fill empty seats) |
| **LOCKER** | downstairs, left | orange | the locker and the wheel (the queue goes on behind it) |
| **PRACTICE** | upstairs, left deck | ice blue | a match with bots only, 3-2-1 and go; pays nothing |
| **HOST A ROOM** | upstairs, right deck | pink | a private room with a 4-digit code; you are its host |
| **ENTER A CODE** | upstairs, right deck | pink | a number pad; the code of a friend's room takes you there |

Upstairs is two jumps: a step beside QUICK MATCH, then the deck. The lobby is 112 studs of floor on two levels, seen
from further back than a round (64 studs top to bottom, not 48), so the whole of it is on one still screen; a narrow
screen slides with the runner. The pieces: `shared/Lobby` (the data and rules), `server/LobbyMap` (the parts),
`client/Lobby` (the doors and words), `client/Callout` (how the words are drawn), `client/CodePad`.

## 2. Where it is

The lobby and the room are more parts in the same world as the arena, far along x (lobby at x 600, room at x 800;
the arena is within ±176), built at boot on every server. Moving between them is a rebuilt body (`Runners.spawn`),
the one placement a client-owned body cannot undo (tag.md §4). Inside the snapshot stream's ±2047 studs (tested).

## 3. Standing in a door (`shared/Lobby`, pure; `test/luau/lobby.test.luau`)

- `Lobby.dwell`: a door fires after `DOOR_HOLD` 1 s of unbroken time inside it; leaving resets the clock.
- **One choice per visit:** once any door has fired, no door answers until the runner has stood outside every
  door. So nothing fires twice, a queued runner waiting in QUICK MATCH is never asked to leave, and the locker
  does not reopen the moment it is closed.
- **Leaving the queue** is the same door, slower: step out, come back, stay `LEAVE_HOLD` 2 s (a white fill,
  "LEAVING THE QUEUE..."). The pause menu (MENU, M) also has LEAVE THE QUEUE, for anyone who cannot find the door.
- The clock does not run while a menu, the code pad or a teleport is up.

## 4. The requests (`server/Doors`; the Remotes row is in [README.md](README.md))

`Remotes.Menu` still carries ONE string from the client. No new remote.

| Op | Asked by | The server accepts it when |
|---|---|---|
| `play` | QUICK MATCH | the sender is in the lobby area, not queued, not in a room |
| `sit` | QUICK MATCH again, or the pause menu | it is queued (stays where it is) or in a match (back to the lobby / room / hub) |
| `practice`, `host` | those doors | in the lobby, within 8 studs of that door, at most once per 8 s (each may reserve a server) |
| `code:NNNN` | the pad | exactly 4 digits, in the lobby, at most one try per `CODE_GAP` 2 s |
| `start` | the room's START | the sender is the room's HOST, in the room, nothing running; bots on or 2+ players |
| `leave` | the room's LOBBY door | in a room, between matches |
| `set:rounds` / `items` / `bots` | jumping into a block | the sender is the host, between matches |

Trust (→ N4): the sender is the Player; every position is the SERVER's own newest sample of that player, never a
client's word; a lying client only queues, seats or moves itself. Refusals that a player should hear of come back
as a word in that player's `Session` view (`note = { word, n }`: `noroom`, `full`, `failed`, `busy`, `need2`,
`hostonly`); the rest are dropped unread and, in Studio only, logged with the reason.

## 5. Rooms (`server/Room`)

- Up to four members in arrival order; the first is host. **The code always works** (no friends-only setting).
- Three blocks the host jumps into: ROUNDS (1 / 3 / 5), ITEMS (off = no orbs at all: rule 13's vanilla toggle),
  BOTS (off needs two players). Seats on the floor name who is in; a friend who joins takes a bot's seat.
- START: a 3-2-1 for everybody in the room, the match, the podium, then **back in the room** (not the hub).
- **A room never stalls:** a host who has not moved for `HOST_IDLE` 60 s between matches, or who leaves, hands
  the room to the next member.
- A match shorter than 3 rounds pays in proportion (`rounds / 3`): a one-round room is not a coin farm.

## 6. Live servers (`server/Hub`) — NOT run: Studio cannot teleport

| Kind of server | How it is told | What happens there |
|---|---|---|
| hub | public | the lobby; QUICK MATCH queues for a match server (H34, unchanged) |
| quick match | reserved, nothing recorded | as H34: one match, then home |
| room | reserved; `sid:<PrivateServerId>` = `{ kind = "room", code, host }` | arrivals land in the ROOM; its matches run there; the LOBBY door goes home |
| practice | reserved; `sid:` = `{ kind = "practice" }` | a match server whose match pays nothing |

A MemoryStore hash map `RotagRooms` holds `sid:<id>` (what a reserved server is: written by the hub that reserved
it, read by that server at boot: server to server, never teleport data) and `code:<4 digits>` → `{ access, sid, n }`
(the access code a hub needs to send a friend there, and how many are in). A room server refreshes both every 240 s
and removes them when it closes; both expire after `ROOM_TTL` 3600 s.

**In Studio and on a solo server the one server stands in for a room server:** HOST A ROOM makes its one room here,
ENTER A CODE walks you into it. The room's rules run the same either way, so they HAVE been run; the reserve, the
MemoryStore calls and the teleports have not.

## 7. The words (`client/Callout`, driven by `client/Lobby`)

Everything said comes from what the SERVER sent back, never from the request ("YOU'RE IN THE QUEUE!" is not shown
for a refused request). Stacked down the top middle, never the lower middle (rule 23), one loud thing at a time:

| Thing | When | Example |
|---|---|---|
| the pill (stays) | whatever you are in | `IN THE QUEUE 2 / 4` + "match starts in 9 · keep moving!" + how to leave |
| the big line (pops, 2-5 s) | something just happened | `YOU'RE IN THE QUEUE!`, `YOU LEFT THE QUEUE`, `A RUNNER JOINED!`, `GOOD GAME!` |
| the held line | being taken somewhere | `MATCH FOUND!` "taking you there: hang on" |
| the count | the last 5 s before a match | `MATCH STARTS IN` 3 |
| the caption | near a door | `QUICK MATCH  Play now with other runners.` |
| the fill (in the world) | standing in a door | the doorway fills, bottom to top |

The full list of moments that get a callout is the goals file, [../qa/lobby.md](../qa/lobby.md) "Indications". Over
a menu or the code pad the pill docks at the bottom edge and the idle hint hides; a countdown closes every menu.

## 8. Numbers (`Config`, trial, Danzo's to tune)

`DOOR_HOLD` 1 · `LEAVE_HOLD` 2 · `QUICK_START` 3 · `HOST_IDLE` 60 · `CODE_GAP` 2 · `ROOM_TTL` 3600; in `server/Doors`:
`MENU_GAP` 0.4, `HOST_GAP` 8, `NEAR` 8 studs.

## 9. What was seen (Studio, 2026-11-18, on screen)

The lobby on one screen; the doorway fill; the how-to cards on a first QUICK MATCH, then the queue (pill, big line,
the door's own 1 / 4); the 5-4-3 count into a real round; the locker over a live queue; leaving with the 2 s hold;
a room made, its code on the wall, ROUNDS 5 and BOTS OFF set by jumping, START refused with YOU NEED 2 PLAYERS,
then started into a round with three bots; the pad's NO ROOM WITH THAT CODE; PRACTICE's 3-2-1 into an unpaid match.

**Not seen:** a second person (a friend joining a room, host hand-over, a full queue); any live server (hub queue,
room and practice servers, the MemoryStore, every teleport); a phone; how one second in a door FEELS by hand.

## Expansion: deficits at scale

- **4-digit codes** are 10 000 guesses at one per 2 s per player. Fine for friends; 6 digits before rooms matter.
- **Roblox's own "Join friend"** lands in the hub, not the friend's room. An INVITE that carries the code would fix it.
- **One room per solo server** (the stand-in). A second host is told NOT RIGHT NOW.
- **The lobby is empty art:** flat blocks and neon, no sprites. Bots do not walk it, so one player alone sees nobody.
