# QA round 2: the walk-in lobby (design) — SCORE 8/10 (target met)

Reviewer: a fresh Opus subagent, pictures only (no Studio, no tests: nothing built). 2026-11-18. Report verbatim.

SCORE: 8/10

Round 2 fixed nearly everything round 1 raised. The lobby now reads at a glance. It has three coloured zones, signs of one or two words, no pads on any walking route, and one obvious lime default nearest the spawn. The room board is calmer too. What keeps this from 9 is the queue toggle. The rule "stand in the door again to leave" now clashes with lobby.png, which shows queued players doing exactly that. It also clashes with LOCKER being a door that swaps you out of the queue. A few smaller things: the host's own view shows HOST ONLY on START, and two docs still describe the design from before round 1. I judged pictures only and ran nothing.

GOALS:
- 1 Five-second read: met - lobby.png: QUICK MATCH sign (~45px) at centre, pink HOST A ROOM / ENTER A CODE right, gold LOCKER left, floor bands PLAY NOW / PLAY WITH FRIENDS / YOUR STUFF repeat them; the house+ and 1-2-3-4 icons tell the two pink doors apart without reading.
- 2 One obvious default: met - lobby.png: QM is the biggest, brightest and nearest door (~160px right of YOU START HERE); holding right no longer hits a pad (the only pad is at x~8-64, behind every door).
- 3 Friends without confusion: met for v1 - HOST (house) vs CODE (digits) are distinct; room.png "Tell your friends. They use ENTER A CODE." tells the host how friends get in. Goal text lines 55-56 still name FRIENDS' ROOMS and "two ways to join", but that door was cut.
- 4 No accidental choices: partial - gate.png 1-2 (dwell, "Running past does nothing") are solid. But the toggle (goals lines 41-42) makes returning to the QM door an accidental *leave*, and lobby.png draws jaxo and pip_44 standing in the door while queued.
- 5 Feels like Rotag: met - real runner art, dark stage, one pad arc to PRACTICE, seat colours in room.png, no red anywhere. Gate step 3 "KEEP MOVING" puts the first pillar back into the wait.
- 6 Simple: met - 5 doors in the lobby, 2 blocks + START + LOBBY in the room, and 7 one-line rules. Cuts named (friends' doors, WHEEL, signpost, WHO CAN JOIN).
- 7 Phone: partial - signs (~26-28px of 900) hold up at about 11-12pt on a 390pt landscape phone. But the door icons (y~650-700) and the floor bands (y~797) sit in the bottom 30%, under the joystick (LOCKER, the PRACTICE pad) and the buttons (ENTER A CODE). The small text ("FINDING A MATCH", player names, ROUNDS/ITEMS labels, ~15-16px) comes out at about 7pt.
- 8 Honest about the build: partial - H36 lines 38-43 list the costs well. But H36 lines 35-37 still describe FRIENDS' ROOMS and LOCKER / WHEEL. The cost list leaves out a fixed lobby camera, the caption system, and moving the how-to / HOW TO PLAY / SIT OUT off the title (ui.md lines 28-33).

PRESERVE (done well, must survive future iterations):
- Colour = zone with the name repeated as floor paint (lobby.png bottom bands): you can tell where to go before you can read.
- Dwell-to-commit with a filling bar, and "Running past does nothing" (gate.png 2): physical, can't be triggered by bumping, and pass-through (DESIGN §2) means no shoving.
- Queued players stay free to move (gate.png 3, HUD pill IN QUEUE 2 / 4): the wait becomes the warm-up, matching today's hub (session.md §8).
- Icons-only doors plus a proximity caption (gate.png 1): this got the long text off the world signs.
- Room: huge code digits, the one-line "they use ENTER A CODE", bots holding seats with "A friend who joins takes a bot's seat" (rule 31 made visible), ITEMS ON/OFF (rule 13's vanilla toggle).
- One pad, at the far-left wall, off every route.
- The Brawlhalla mapping is a fair, honest simplification: matchmaking -> QM, custom room number -> HOST / CODE, training -> PRACTICE (rule 32), store -> LOCKER, ranked left out.

FIX (done poorly; why it matters; concretely how to fix):
- The queue toggle conflicts with the picture and with instinct: lobby.png shows jaxo and pip_44 waiting *inside* the QM door at 2/4. Under goals lines 41-42, a queued kid who wanders back in, or waits there as drawn, leaves the queue after 1 s without meaning to. It also isn't defined whether staying in the door after committing refills the bar. -> Make re-entering the door while queued do nothing, and leave by the HUD pill (tap IN QUEUE 2 / 4 -> LEAVE) or by committing PRACTICE / HOST / CODE. If leaving must stay physical, require a walk-out first, show a white "LEAVE QUEUE" bar, and use a longer hold (about 2 s). Redraw lobby.png's QM door with 2/4 and no runners standing in it, and draw the HUD pill.
- LOCKER dequeues you ("Another door swaps you over", gate.png 3): browsing cosmetics is the ideal way to spend a 12 s+ wait, and today the locker sits beside a queue. -> LOCKER opens over the queue and does not swap you. Only PRACTICE / HOST / CODE swap. Say so in one line in "The rules".
- START reads HOST ONLY on the host's own screen (room.png right; the title says YOUR ROOM and YOU wears HOST): the host may think they can't start. -> For the host, START's door shows a play arrow or "STAND HERE". HOST ONLY appears only as a flash to non-hosts, as the rule says.
- Stale design text: goals lines 55-56 (FRIENDS' ROOMS, "two ways to join") and H36 lines 35-37 (FRIENDS' ROOMS, WHEEL) contradict the boards. The next build session reads those docs. -> Update both to the round-2 design.
- Build-list gaps (goal 8): -> Add these to H36. (a) The lobby needs a fixed camera, because SideCam follows with lead (players.md line 148: 48 studs tall), and the board assumes one still screen. (b) The proximity caption UI. (c) The title's PLAY / HOW TO PLAY / SIT OUT AND WATCH (ui.md lines 28-33) lose their home: name where a returning player re-reads the how-to (for example a "?" card in LOCKER).

CONSIDER (fine but could change; why; how):
- Bottom-30% content on a phone (lobby.png icons and floor bands, the PRACTICE pad at the lower-left corner under the thumbstick): -> Raise the floor about 60px in the lobby map, or shrink the bands into the door's threshold. Move the pad a step up from the corner.
- Gate step 2 label "HOLD STILL" vs the rule "stay in the door": a kid may think a jump in place resets it. -> Label it "STAY", and let any movement inside the door's zone count.
- Roblox "Join friend" cannot follow a player into a reserved room server: a Discord kid who clicks Join lands in the hub, not the room. -> Room-to-hub presence plus a "your friend is in room 4827" caption at ENTER A CODE. Or a cheap INVITE block in the room (SocialService:PromptGameInvite with the code in the launch data, auto-entering it). This is trigger 3 for the build.
- QM's lime is shared with the pad and PRACTICE's cyan with "you" (ui.md §1): this was accepted last round, and with one pad the clash is small. Leave it.
- Room ROUNDS/ITEMS labels (~16px): bump them to ~22px. The values already read.

UNCERTAIN (could not verify):
- Movement feel: none of it can be judged from a picture. Once it's built, Danzo should try:
  - From the spawn, run full speed right and stop inside the QM door, then hold. Does 1 s feel snappy, and can a phone thumb stop inside the frame without overshooting?
  - Commit, run around, then come back near the door. Is anything surprising?
  - From a seat in the room, jump into ROUNDS. One normal jump should reach it and a tap shouldn't. My estimate: block bottom about 9 studs up, full hold 14.25 (movement.md line 102).
  - Take the pad arc onto the PRACTICE ledge, and see whether a double jump also gets there (the ledge is about 17 studs up).
- The real on-screen scale and point sizes: I assumed 48 studs = 900px. They depend on the final camera and on 19.5:9 framing.
- Teleport timings for BACK TO LOBBY / LOBBY door / MATCH FOUND (nothing runs in Studio).
- The editable boards at the artifact link (not opened; PNGs only).

## Builder decisions

Target met; the loop stops here. The five FIX items were cheap, so they are done anyway (not re-reviewed):

- **Queue leave:** the physical variant, because Danzo asked for places, not buttons: once queued, the door ignores
  you until you have walked out; coming back and holding for TWO seconds (a white LEAVE QUEUE bar) leaves. Nobody is
  drawn standing in the door any more (jaxo and pip_44 run about the lobby).
- **LOCKER never dequeues.** Only PRACTICE, HOST A ROOM and ENTER A CODE swap you. Rule written.
- **START says STAND HERE** on the host's screen; HOST ONLY is only the flash a non-host gets.
- **Stale text** in the goals file and H36 brought up to the boards.
- **Build list** gained the fixed lobby camera, the caption UI, and a home for the how-to (a "?" card in the LOCKER).

**Taken from CONSIDER:** the bar reads STAY (any movement inside the door counts); room block labels 22 px.

**Deferred:** raising the lobby floor for phone thumbs and moving the pad off the corner (a map-build detail: the
real camera decides it); a friend's "Join" landing in the hub, not the room (noted in H36 as a build question,
trigger 3); the lime / cyan colour overlap (accepted twice).
