# QA goals: the walk-in lobby (a DESIGN, nothing built)

Branch: `claude/friendly-hawking-74891i`. Handoff H36 (2026-11-18). Danzo's ask: "change the lobby ... a lobby area
[where] you should be able to choose what type of game you want to play; take Brawlhalla's system as a base, but
rather than just buttons you click on the screen it is a physical location in 2D space; it should be very obvious
and clear where to go for what; this way players who wish to play with their friends can start their own private
rooms or simple random match etc." Then: "start a /qa-loop to verify the feel and simplicity and clarity of it all".

**This loop reviews pictures, not a build.** No Luau changed; there is nothing to Play. Do not start or stop Play in
Studio (Danzo may be in it). The reviewer looks at three renders and judges them as a player would:

- `exports/lobby_design/lobby.png`: the lobby a player lands in (one screen, no scrolling).
- `exports/lobby_design/room.png`: inside a private room, as its host.
- `exports/lobby_design/gate.png`: how every door works, in four steps.

The same boards, editable: https://claude.ai/artifact/9VdirngqxNgVu1MYpVbZPt (private to Danzo). What exists today,
for comparison: the title screen with a PLAY button and the hub queue, `docs/systems/session.md` §1, §8,
`docs/systems/ui.md`.

The question: **would a kid who has never seen the game know, within five seconds of landing and without reading a
how-to, where to go to (a) play with strangers now, (b) make a room for friends, (c) get into a friend's room? And
does choosing by running feel like the game, not like a menu with extra steps?**

## The design in words (after QA round 2)

- **One screen, three colour zones, the spawn in the middle.** Gold left = your stuff (LOCKER: the shop and the wheel
  behind one door). Lime centre = play now (QUICK MATCH, the biggest door, nearest the spawn). Pink right = friends
  (HOST A ROOM, ENTER A CODE). Cyan upstairs left = PRACTICE (you and bots, nothing counts), reached by the one
  boost pad, at the far-left wall where no walking route crosses it. Floor paint under each zone repeats its name.
- **Brawlhalla's structure, mapped:** matchmaking -> QUICK MATCH; custom game room (a room number, the host sets it
  up and starts) -> HOST A ROOM / ENTER A CODE; training -> PRACTICE; store -> LOCKER. Ranked is deliberately absent.
  Cut for v1: one door per hosting friend (the costliest piece; a code does the job).
- **Signs are one or two words.** A caption with the detail appears only when you are near a door.
- **A door is chosen by standing in it for one second** (a bar fills). Running past does nothing.
- **A private room is a place too:** the code on the wall in huge digits, four coloured seats (bots hold the empty
  ones), two settings as blocks the host jumps into (ROUNDS, ITEMS on/off), a START door, a LOBBY door.
- **The only on-screen input left** is typing a room code at ENTER A CODE (a number pad; not drawn yet).

## The rules (one line each)

- **Queue:** one second in QUICK MATCH puts you in the queue; you stay in it wherever you run in the lobby (a HUD
  pill: IN QUEUE 2 / 4), the LOCKER included. To leave: walk out, come back and hold the door for two seconds (a
  white LEAVE QUEUE bar). Committing to PRACTICE, HOST A ROOM or ENTER A CODE swaps you; the LOCKER never does.
- **Who can join a room:** anyone with the code. No friends-only setting.
- **Host only:** START (STAND HERE on the host's screen) and the blocks answer only to the host; anyone else gets
  a HOST ONLY flash.
- **Host idle 60 s, or gone:** the longest-seated player becomes host. A room never stalls.
- **A friend who joins** takes a bot's seat; with four people there are no bots.
- **Leaving a room** is the LOBBY door (a teleport: a few seconds, not instant).
- **The how-to cards** show on a new player's first door commit and live on as a "?" card in the LOCKER. In a
  match, the MENU pill reads BACK TO LOBBY.

## Goals

1. **Five-second read.** From the spawn, each of the three main choices (random match, host for friends, join a
   friend) is findable at a glance by size, colour and one or two words. Nothing needs the HUD hint to be found.
2. **One obvious default.** A player who does nothing clever ends up in a random match: QUICK MATCH is the biggest,
   brightest and nearest thing.
3. **Friends without confusion.** The difference between HOST A ROOM and ENTER A CODE is clear from the lobby
   alone; a host knows how friends get in (the code); a friend knows where to type it.
4. **No accidental choices.** Passing a door, or being bumped into one, never commits you; leaving is as physical as
   entering.
5. **It feels like Rotag.** Getting to a door uses the game's own moves (run, jump, pads); the lobby is a small
   playground, not a corridor of menus. It looks like the game (the runner, the dark stage, the seat colours; red
   stays reserved for "it").
6. **Simple.** No more doors, words or rules than a first-time player can hold. Anything that could be cut without
   losing a choice should be named.
7. **A phone.** Signs and door text would still read on a phone-shaped screen; touch controls have room (the lower
   corners and lower middle, DESIGN rule 23).
8. **Honest about the build.** Anything in the pictures that the current server cannot do (private rooms, codes,
   friends' doors, practice, room settings) is called out so Danzo knows what he is choosing to build.

## Out of scope

The build itself, the networking of rooms and codes (trigger 3, a later handoff), the number pad's look, the art
finish of the lobby (these are flat mock-ups, not sprites), ranked play.

## What the builder saw, and did not

- Rendered all three boards locally and looked at each PNG. Fixed two overlaps on the lobby board (the signpost over
  the QUICK MATCH door; runners drawn over door text) and one wrong line on the room board.
- **Not seen:** any of it moving, any of it at phone size, any of it in Studio. Whether one second in a door feels
  right is a hand-on-the-controls call.
- **Builder's own doubts (after round 1):** PRACTICE is the only thing upstairs and needs the pad, which may hide
  it; the queue toggle (stand in the door again to leave) is a rule to learn; the room's blocks are another.
