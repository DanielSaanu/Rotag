# QA summary: the showable game (H31-H34)

Goals: [showable.md](showable.md). Loop run 2026-11-16 on `claude/friendly-hawking-74891i`, one Opus reviewer per
round. The verbatim reports are in `docs/qa/archive/showable-round{1,2,3}.md`.

## Scores

| Round | Score | Rig | Main finding |
|---|---|---|---|
| 1 | 7/10 | PC locked: code, tests, server Output | The flow, the bots and the data rules hold; a phone's text would be 8 points; saves could be overwritten across a server hop |
| 2 | 7/10 | PC locked | Bot names could be real Roblox accounts (a child-safety problem); unlabelled bots dressed in rare prizes |
| 3 | **8/10** | Studio rendering: a whole match played on screen | It plays end to end; the untested hub could flip to solo on one departed player, and a match server could start without its group |

Between rounds 2 and 3 the PC was unlocked and the game was SEEN for the first time (by Danzo, and through Studio
captures). That found more than either blind round: a render-loop crash from a holder's first ignition (Danzo's
"ghost mode not working"), a stage too dark to read and then too bright, a map that streamed in piece by piece.

## Fixed

**Round 1:** the UI's scale floor (0.75) with compact layouts for short screens; name tags a fixed 15 px on any
screen; the HUD in the same scaled space; "PROGRESS IS NOT SAVING RIGHT NOW" in the wallet; a DataStore lock on
load and a revision on save; a bot's tag judged at the target's own ping; one spin at a time; the match track
through the gaps; server-sent round points; "LEVEL n!"; trails cleared on a teleport.

**Round 2:** bot names always hold a space (never a possible username); bots wear common items only;
`Config.BOT_LABEL`; the item readout out from under the scoreboard; a frozen or ghost bot drops its rope; three
`Data` edge cases; safe-area insets; one text size for name tags; a wait for a real viewport before the UI is built.

**The first look (Danzo and captures):** `Look:glow` hidden by `self.glow` (now `Look:aura`; the presentation runs
last in the frame, under pcall); the stage relit and outlined, then dimmed to a middle ground; the map a Persistent
Model; the title's shade; visible ghosts; shorter trails; the walls' red.

**Round 3:** a hub launch drops whoever left and only failed reservations count toward the fall-back; a match
server waits for its group; arrows under the HUD; Enter closes the first-run cards; no black void under the floor;
the ice beam stops at a wall; a failed launch retries in 3 s; unaffordable buttons are quiet; a server's first round
starts with a bot holding the fuse.

**Built during the loop at Danzo's request:** bots that pass for people (H32), the ice beam reworked, trap and
crate marks, the pickup banner (H33), the hub with match servers (H34).

## Preserved (confirmed across rounds)

- The pure `shared/Session`, `Profile`, `Catalog` with tests; the server their only caller.
- Bots run the real `Movement` through rollouts; skill is data, never a cheat; the grapple uses the players' own aim
  assist and line of sight.
- Bots never play alone; a person always takes a bot's seat.
- A failed load is never saved; the revision check refuses stale writes; the player is told.
- Every new client-to-server remote is narrow, rate-gapped, and judged on the server's own state.
- The hub's failure path: a hub that cannot start match servers becomes a playable solo server.
- The fuse HUD; the wheel's printed odds.

## Deferred, and why

- **The bot label is off.** Danzo asked for players to play "with machines unknowingly"; two reviewers advise
  labelling for a kids' audience. One word turns it on (`Config.BOT_LABEL`). His call.
- **Five or more people on the scoreboard:** a match seats four; the hub gives each four their own server.
- **The economy's pace** (a spin every 2-3 matches): judge after the kids play.
- **A UI rebuild on window resize:** the layout is chosen once, at start.
- **A ghost's camera drifting to the holder; the four-line text stack in a ghost's end phase:** camera and HUD rules
  for Danzo's eyes first.
- **`docs/DESIGN.md` at 309 lines:** split §6 when it is next touched (→ G3).

## Still unverified (nobody has done these)

- **The hub's real teleports**, a player leaving mid-launch, and the save across a real server hop: Studio cannot
  teleport. This is the one thing that could stop a live playtest: test it first (below), and `Config.HUB = false`
  is the way back.
- **Sound by ear:** all 41 sounds load and the tracks switch at the right moments; nobody has judged the three
  music picks or the volumes.
- **A phone** (the device emulator), **two people in one match**, **whether a bot is fun to chase and to flee**.

## Danzo's checklist

**Before the Discord link**
1. Game Settings: Max Players **20** (the hub's size); Security: Enable Studio Access to API Services; publish; Public.
2. With two accounts or devices on the PUBLISHED game: both press PLAY: "FINDING A MATCH 2 / 4", within 12 s "MATCH
   FOUND" and a teleport; in the match server "WAITING FOR YOUR GROUP" until both are in, two bots, three rounds, the
   podium; then both back in the hub with their coins. Then one account alone (three bots).
3. If anything in step 2 misbehaves: `Config.HUB = false` in `roblox/src/shared/Config.lua`, Max Players 4, publish.

**Playing it**
- Burn out on purpose: you become a blue ghost with a YOU tag, the fuse keeps counting, ghost orbs are up, your
  item works, the red triangle stays on whoever is it.
- Fire an ice beam while running and jumping: it shoots out from your hand as a cone, travels with you, never
  turns, stops at a wall, freezes whoever it touches. Too strong? `ICE_GROW`, `ICE_LIFE`, `ICE_LENGTH`.
- Take an orb: a ring on you, "YOU GOT: ..." with what it does and the key.
- A trap and a crate: a thin lit line and a soft light, findable without a box round them.
- The arena: walls and decks read by their outlines; not too dark, not too bright (`server/Stage.lua`: the colours
  at the top, `ExposureCompensation`).
- The bots: do they read as people; can you catch one and get away from one (`BOT_SPEED`, `BOT_THINK`)? Do they
  hop too much?
- The music: three tracks picked by description (`roblox/src/client/Audio.lua`, the `MUSIC` table): swap any id.
- The wheel and the locker: spin, buy a trail, see it behind you next round.
- A phone (Studio's device emulator): the title, the cards and the buttons fit; nothing in the lower middle.
- On the title with the keyboard: Enter, Enter, and you are in.
