# QA round 1: the walk-in lobby, built — SCORE 6/10

Reviewer: Opus subagent, driving Studio (Play, placed bodies, keys, 29 captures). 2026-11-18. Report verbatim.

SCORE: 6/10

How I tested: Studio was already in Play when I arrived. Midway through, Play stopped by itself (the keyboard tool reported "Target is closed"; not my action), so I started it again once. I stopped Play at the end, and it is in Edit now. `npm test`: fail 0. `npm run lint:luau`: no errors. Captures are ScreenCapture_1 to 29, in the session's tool-results folder.

GOALS:
- 1 Where to go: partial. The colours are clearly different (orange, green, ice blue, pink) and QUICK MATCH is the obvious default (Cap_1). But the way upstairs is two thin 6-stud ledges with no "UP" cue.
- 2 Room to stand: partial. The ground floor has open space. Upstairs is two decks crowded with doors, and at a 64-stud view the 3.5-stud runner is about 30 px tall (Cap_1). The lobby feels empty and huge rather than crowded.
- 3 Layered, centred labels: partial. The lobby's signs are centred and nothing overlaps (Cap_1). In the room, "TELL YOUR FRIENDS. THEY USE ENTER A CODE." runs into the START sign, and "A FRIEND WHO JOINS TAKES A BOT'S SEAT" is clipped at the bottom edge (Cap_15). The 3-2-1 count lands on "ROOM CODE" (Cap_21).
- 4 Choosing is physical and safe: NOT MET. Jumping into a room setting block fires twice, so one normal jump toggles BOTS OFF and then back ON (watched on the label: `ON,0.91:OFF,1.33:ON`) and moves ROUNDS on two steps (`5,0.11:1,0.53:3`). Separately, a missed jump toward the step dropped me into QUICK MATCH and I was queued without meaning to be (log: `Stifffchoclate is in the queue` at 605.5, then `match 2 round 1`).
- 5 Always know your state: partial. Rows 1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13 (the refusal), 14 (settings), 15 and 16 all showed on screen. But leaving a match through the menu goes back to the lobby with no words at all (Cap_8). The "to leave" hint is hidden while the big line or the count is up, so in a 12 s queue it is visible for about 3 s. The pad's refusal is small 17 px text, not big words (Cap_27).
- 6 Never rushed: partial. A match goes back to the room with "GOOD GAME!" (Cap_25). But the podium card still says "next match in 5" (Cap_24; Board.lua:191), which is no longer true. The accidental queue above is a 12 s rush.
- 7 Rooms: partial. The code is readable across the room, START was seen working, and the pill reads "YOU ARE THE HOST". The settings blocks are broken (goal 4). Host hand-over and a friend joining were not seen (needs a second person).
- 8 A phone: partial (reasoned from the code and the window, not seen on a phone). Studio's window is 2.73:1; a phone is about 2.16:1, so it shows about 138 studs and the 120-stud lobby still fits. The floor sits about 90% of the way down the screen, so LOCKER (about 23% across) and the room's seat names sit in the joystick and button zones. Pad keys are 96×50 design px, about 37 pt tall at scale 0.75, which is under the 44 pt guideline.
- 9 Fairness: met. Doors.lua checks position, host and rate against the server's own newest sample (Doors.lua:56-131). Cosmetic gaps: `start` and `set:` do not check that the host is at START or at the block.
- 10 Nothing broke: met (Studio and solo only). A quick match runs from the lobby to the round and back, tests and lint are green, and default.project.json is unchanged (the new modules only add to the tree).

PRESERVE:
- The doorway fill plus the "NAME... stay in the door" caption: you read it where you are already looking (Cap_2).
- The one-choice-per-visit dwell (shared/Lobby.lua:179): standing in QUICK MATCH while queued never fires a second time.
- The pill that docks at the bottom over the locker and stays visible (Cap_28), and the countdown closing every menu.
- Every word comes from the server's view; refusals come back as notes and show nothing optimistic.
- The palette, the two-level split and the asymmetric layout Danzo asked for.
- The match hold that waits for a seated bot's body (Match.lua:137).

FIX:
- Setting blocks fire twice per jump: a normal jump passes up through the 4.5-9.5 block and back down into it. Kids cannot turn BOTS or ITEMS off, and it looks broken. -> Make the blocks solid and fire when a runner bonks one from below, Mario-style. Or reset `lastBump` (client/Lobby.lua:271) only once the runner is grounded, and add a server debounce per key of at least 1 s.
- The way upstairs runs through QUICK MATCH: the steps sit on either side of it (Lobby.lua:58-59), so a missed jump lands in the doorway and a kid who pauses there is queued. -> Move the steps to the far ends, by the walls: under PRACTICE on the left, past ENTER A CODE on the right. Make them wider (10 studs or more), give them the neon edge and add a painted "▲ UP" on the wall. Alternatively, make QUICK MATCH fire only from the floor (y below 2).
- The podium says "next match in N": it contradicts H37. -> In Board.lua:191, say "back to the lobby in N" (or "back to the room in N").
- The room's text overlaps START and is clipped at the bottom. -> Shorten CodeHelp to "FRIENDS: ENTER A CODE" at width ≤ 50, or move it. Raise the floor-face texts (SeatName at oy-2.2, SeatHelp at oy-4.8) onto the wall, or lower `viewY`.
- How to leave the queue is nearly invisible. -> Put the leave line into the count ("changed your mind? stand in QUICK MATCH") and keep the hint visible whenever no big line is up. Add a "LEAVE" label in the QUICK MATCH doorway while you are queued (LobbyMap.say "quick").
- No words after LEAVE THE MATCH or leaving practice. -> Send a `note` from Session `sit` ("left") and show `YOU LEFT THE MATCH` "stand in a door to play".
- The solo stand-in mixes groups (Session.lua:227-244; a Studio or VIP server): PRACTICE or a room's START cuts the 3-2-1 short for whoever is quick-queued in the lobby, and seats them in that match, which is then paid. -> Pass a roster to `quickAt`: seat only practice[] or Room.members, and keep the quick queue's own timer.

CONSIDER:
- The lobby is seen from too far back for its size: the runner is about 5% of screen height, roughly 20 pt on a phone. Shrink the lobby to about 90 studs at view 52 and put the extra room into one wide floor rather than empty wall. The callouts only need the top third.
- ENTER A CODE's doorway reads "1 2 3 4", which looks like a code; I typed 1234 myself (Cap_27). Use "# CODE".
- The pad's refusal should be big: shake the boxes and show 24 px or larger text.
- In a room, GOOD GAME says "stand in a door to play again"; say "host: stand in START" instead.
- The how-to cards are five paragraphs of small text (Cap_3); for kids, use icons and three words each.
- A practice server on the live game runs the arena's 12 s LOBBY_TIME, not 3-2-1, because `quickAt` is never set there (Session.lua:333-337). The "PRACTICE STARTS IN" callout also only draws in the lobby area.

UNCERTAIN:
- Everything on the live servers: Hub.open, join and keep, the MemoryStore `sid:` read at boot, ReserveServer's second return matching PrivateServerId (it should per the API), TeleportInitFailed requeue. Studio cannot exercise these.
- Rows 6 (A RUNNER JOINED), 8 (MATCH FOUND or STILL LOOKING), 14's joins and host hand-over, and the "room full" refusal: these need two people or a hub.
- The real phone layout: thumb overlap and text sizes are reasoned from the code, not seen.
- Feel, which needs Danzo's hands. Whether one second in a door feels deliberate or sluggish. Whether a kid finds the step-then-deck route. Specifically: from the spawn, go upstairs to PRACTICE without falling into QUICK MATCH, on a keyboard and on a phone, five times each. I only managed it by placing the body first and then jumping (step reached at 592,10.75; deck at 574,19.75).

## Builder decisions

**Fixed (all seven FIX items):**
- **Blocks, one change a jump:** the client holds the block as "the same jump" until the runner is back near the
  floor, and `Room.set` refuses a second change of one setting inside 1 s. Seen in Studio: one held jump, BOTS: OFF
  once. (Not made solid: a solid block over a seat would be a ceiling in a room built for jumping about.)
- **The way up moved to the two ends,** by the walls: a 10-stud step under an UP sign, then the deck. 34 studs from
  QUICK MATCH (tested). The decks were shortened so neither step is under one; the pink doors moved in to fit.
- **The podium** says "back to the lobby in N" / "back to the room in N".
- **The room's wall:** the code moved to the left of the wall (the middle is the callouts'), its help line is
  "FRIENDS USE: ENTER A CODE", the line under the seats is gone, the seat names sit higher.
- **How to leave:** the hint now stays through the count (hidden only for the few seconds a big line is up).
  Not done: a LEAVE label in the doorway (that label is the server's, the same for everybody; a queue count of
  others would vanish for whoever is not queued).
- **YOU LEFT THE MATCH** after the menu's LEAVE THE MATCH or leaving practice (from the view's change; no new note).
- **A private match is its group's:** `setQuick(t, ids)`; only those ids are seated, counted, paid and sent home;
  whoever is quick-queued behind it stays queued, is told "a private match here goes first", and does not see its
  3-2-1.

**Taken from CONSIDER:** the doorway says "# CODE"; the pad's refusal is 22 px heavy and the boxes jump; its keys are
60 px tall on every screen; GOOD GAME in a room says who starts the next one; a practice server counts down from
the arrival (`QUICK_START` + 4 s), not the arena lobby's 12 s. Also: `set:` now needs the host to be in the room.

**Deferred, with why:** shrinking the lobby to 90 studs (Danzo's own words on the first, smaller build were "too
small, not enough space"; the size is his to judge by eye, and the runner's size on a phone is on his checklist);
the how-to cards as icons (an art pass); `start` checked against the START door's position (the host is checked;
the door is the client's way of asking).

**PRESERVE check:** the fill and caption, the one-choice dwell, the docking pill, server-sourced words, the
palette and two levels, the bot hold in `Match` all untouched.

**Also in this commit:** H38 merged (the dash and the tag, `docs/systems/dash-tag.md`): outside this loop's goals.
A practice round was run in Studio with dashes after the merge: no errors; a dash-through tag was not set up.
