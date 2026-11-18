# QA round 1: the walk-in lobby (design) — SCORE 7/10

Reviewer: Opus subagent, pictures only (no Studio, no tests: nothing built). 2026-11-18. Report verbatim.

SCORE: 7/10

This is a clear, good-looking design that fits the game. The zone-by-colour idea works: a kid can read lime as "play now" and pink as "friends" before reading a word. Five things hold it back. Most of the small text on the boards would be unreadable on a phone. The headline contradicts the door rule. Two boost pads sit on the walking route. Waiting in the queue means standing still. Three rules are never said: the room's "who can join", what happens when the host goes AFK, and where the how-to went. Movement feel cannot be judged from a picture (see UNCERTAIN).

GOALS:
- 1 Five-second read: met - lobby.png: three big labelled zones, QUICK MATCH header (~45px) at centre, pink HOST A ROOM / ENTER A CODE right, floor bands PLAY NOW / PLAY WITH FRIENDS repeat them.
- 2 One obvious default: partial - lobby.png: QM is the biggest and brightest, and the nearest door (~100px right of the spawn). But a kid holding right runs straight through it (dwell rule) onto the lime pad at x~1078 and is launched upstairs.
- 3 Friends without confusion: partial - room.png line "Friends type it at ENTER A CODE, or walk into your door upstairs" tells the host both ways in, which is good. But "OPEN" on kai_77/mira's doors and room.png "WHO CAN JOIN: FRIENDS" are undefined: can a non-friend with the code still join? A Discord kid is often not a Roblox friend.
- 4 No accidental choices: partial - gate.png steps 2-3 (1 s hold, walk out cancels) are good, and pass-through (DESIGN §2) means nobody can be shoved into a door. But the pads at x~505 and x~1078 in lobby.png sit on the floor route to WHEEL and HOST A ROOM, so a player walking there gets launched by accident.
- 5 Feels like Rotag: met - real runner art, dark stage, pads and arcs, no red anywhere, seat colours reused in room.png.
- 6 Simple: partial - 8 doors plus a 4-arrow signpost plus 3 setting blocks. Cut candidates are below, but the boards don't name them.
- 7 Phone: not met - text like "Just you and bots. Nothing counts.", the signpost (~13px), "No room. Shows when a friend hosts." (~12px) and room.png's "Host only: jump and bump…" shrink to about 5-7pt on a 390pt-tall landscape phone. In lobby.png the lower-right controls would cover ENTER A CODE's door text, and the joystick covers LOCKER's.
- 8 Honest about the build: partial - goals file and H36 name the categories, but no picture or doc says what each costs on the server. The list is under FIX.

PRESERVE (done well, must survive future iterations):
- Colour = zone, with floor paint repeating the name (lobby.png bottom bands): you can tell where to go before you can read.
- Dwell-to-commit with a filling bar and walk-out-to-cancel (gate.png 2-3): physical, and it can't be triggered by passing or being pushed.
- The QM door showing live "2/4 FINDING A MATCH" with the runners inside it: this reuses the hub's `queued`/`launching` (session.md §8, line 133) and makes the queue visible.
- Bots hold empty seats and "A friend who walks in takes a bot's seat" (room.png): this is rule 31 made visible.
- Room code as huge digits plus the one-line "how friends get in" (room.png top).
- Red reserved for "it"; ranked left out on purpose.
- Brawlhalla mapping (casual matchmaking → QM, custom room → host/code/friends, training → PRACTICE, store → LOCKER/WHEEL) is a fair, honest simplification of its structure.

FIX (done poorly; why it matters; concretely how to fix):
- Headline "RUN INTO A DOOR TO CHOOSE" (lobby.png top): it tells a kid to run in, but gate.png says running past does nothing. -> "STAND IN A DOOR TO CHOOSE".
- Pads on the walking route (lobby.png x~505, x~1078): they launch people who were heading for WHEEL or HOST A ROOM. -> Move each pad off the floor route (e.g. on a small step you must jump onto), or make them stand-and-jump pads.
- Waiting means standing still: walking out of the QM door cancels (gate.png 3). A queue can last LOBBY_TIME (12 s) or longer, so the first pillar (moving on an empty screen) dies in the lobby, and today's hub lets queued players warm up (session.md §8 line 116). -> The 1 s dwell commits you. After that you stay queued anywhere in the lime zone. Leaving the zone, or entering another door, cancels, which is still physical. A HUD pill shows "IN QUEUE 2/4".
- Phone text: these are world signs, so the UI's 0.75 floor (ui.md §1 line 14) does not protect them. -> Signs carry 1-2 words only. Move every description line into a scaled caption that appears when you stand near or in a door. Keep door text out of the bottom ~30% of the frame on the left and right.
- Undefined rules: "OPEN" on friends' doors; WHO CAN JOIN's values; what a non-host sees in START or under a bump-block; the host going AFK or leaving (the room stalls forever: session.md §1 rejects ready-up votes for exactly this reason). -> Write each rule in one line. Suggestion: the code always works and friends' doors always show, so drop WHO CAN JOIN. If the host is idle 60 s or leaves, the longest-seated player becomes host.
- How-to has no home: the first PLAY currently shows the how-to cards (ui.md §2 line 31), and the in-match MENU pill returns to a title that no longer exists. -> Show the cards on a new player's first door commit. Say what the MENU pill and SIT OUT become in a match server.
- Build list for goal 8: what the current server cannot do yet.
  - Rooms need a new server kind with a host-gated start; today a match server counts down by itself (§8 line 117).
  - Settings: MATCH_ROUNDS and BOTS become per-server instead of Config constants.
  - Codes need a MemoryStore map from code to reserved server, with expiry, plus server-side rate limits. 4 digits means 10k codes a client can step through (trigger 3).
  - Friends' doors need, from the hub, each player's friends across servers and each room's live seat count.
  - PRACTICE needs a solo reserved server with no pay-out and no save.
  - BACK TO LOBBY is a teleport taking seconds, not "walk out any time".
  - The lobby needs a lobby map, door zones the server decides, and new `Menu` ops (host, code, friend, practice). A remotes-list change.
  -> Put this in H36 so Danzo picks scope knowingly.

CONSIDER (fine but could change; why; how):
- Five pink things against one lime (builder's doubt): -> For v1, cut FRIENDS' ROOMS, since ENTER A CODE covers joining and the friends' doors are the costliest piece (cross-server friend lookup). Fold WHEEL into LOCKER, which is the same screen today.
- Narrow friends' doors (~130px wide, upstairs): stopping inside one after a pad arc with momentum may be fiddly. -> Widen them, or let the dwell count when you land on the door's ledge segment.
- Bump-from-below blocks (room.png): they sit ~210px above the floor (a double jump?) and are a rule a player has to learn. -> Lower them to single-jump height and add a pop or sound on change. Show non-hosts a "HOST ONLY" flash.
- Swap BOTS FILL SEATS for an ITEMS ON/OFF toggle: that toggle is rule 13's vanilla option, which session.md "Expansion" (line 149) lists as missing for private servers.
- Colour meanings: ui.md §1 says cyan = "you/go" and lime = "pads/alive", but PRACTICE is cyan and QM shares lime with the pads. -> Accept this, or make PRACTICE the pale ghost-blue.
- A future "THIS WEEK" door slot (Brawlhalla's rotating mode), for rules 30/35 when modifiers arrive.
- The signpost (lobby.png x 545-725) is four stacked small arrows hard against the spawn. -> One arrow per zone, painted on the floor.

UNCERTAIN (could not verify):
- Movement feel. Danzo should try three things by hand once it's built:
  - Run full speed at QUICK MATCH and stop inside its ~290px frame, then hold 1 s. Does 1 s feel snappy or sticky?
  - Take a pad arc and land in a 130px friend's door.
  - Reach a bump-block in the room with a single jump.
- The real on-screen scale. A fixed one-screen camera vs the game's follow camera, and its zoom on a 19.5:9 phone, decide every readability number above. My phone point sizes are estimates.
- Whether hub/room teleports feel acceptable for "walk out any time" (nothing here runs in Studio).
- The editable boards at the artifact link (not opened; the PNGs only).

## Builder decisions

**Fixed (all seven FIX items):**
- Headline is now STAND IN A DOOR TO CHOOSE.
- One pad left, at the far-left wall past every door (it only serves PRACTICE). No walking route crosses a pad.
- The queue no longer pins you: one second in the door commits; you stay queued anywhere in the lobby (a HUD pill
  IN QUEUE 2 / 4); standing in QUICK MATCH again leaves it; another door swaps you. **Differs from the reviewer's
  "stay in the lime zone"**: that zone is ~300 px wide, too small to run about in; a toggle keeps the whole lobby
  as the warm-up.
- Signs carry one or two words; every description left the doors (icons only) and became a caption that appears
  near a door (gate board, step 1). Room text enlarged, cut to three lines.
- Rules written (goals file, "The rules"): the code always works; WHO CAN JOIN dropped; non-host sees HOST ONLY;
  host idle 60 s or gone → the longest-seated player hosts.
- How-to: the cards show on a new player's first door commit; in a match the MENU pill reads BACK TO LOBBY.
- The build list is in H36.

**Taken from CONSIDER:** FRIENDS' ROOMS cut for v1 (the costliest piece; ENTER A CODE covers it); WHEEL folded into
LOCKER; blocks lowered, two of them (ROUNDS, ITEMS: rule 13's toggle replaces BOTS FILL SEATS); the signpost
removed (three zones on one screen do its job).

**Deferred:** PRACTICE stays cyan (pale ghost-blue reads as "dead" here); a THIS WEEK door waits for round
modifiers; floor arrows not added (nothing to point at that is not already on screen).

**PRESERVE check:** zone colours and floor paint, the dwell bar, the live 2 / 4 door, bots holding seats, the huge
code, no red, the Brawlhalla mapping all survive. "Walk out to cancel" changed on purpose (see the queue fix).
