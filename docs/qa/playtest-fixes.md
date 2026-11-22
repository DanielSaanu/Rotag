# QA goals: the playtest fixes (QA Central #10775)

Branch: the local session's working branch (`claude/friendly-hawking-74891i` at the time of writing). The triage it
comes from is `docs/qa/playtest-2026-11-20.md` (read it first). Research backing it is in `docs/research/`
(`tag-netcode.md`, `chaser-speed.md`, `movement-tutorials.md`). Items 1-3 change DESIGN §3 or the tag confirm, so
they go through a heavy handoff before the build (triggers 1 and 3). The heavy agent's rulings override this file
where they differ.

Danzo's words (2026-11-22): "u can just get to work autonomously ... qa loop based of those reviews and do some
research to aid yourself then just work together generally to complete the task". The testers' words, which are the
target:

- "a lot of the times that i was it, i touched the other ppl ... but it didnt go through" (XTRA); "I've been it for
  many times and has repeatedly got closed and touched or hit others but they doesn't seem to be the next IT" (Mambo)
- "it's already really easy to avoid the IT ... if they were like 20% faster it would be more fun since i can just
  spam a bunch of moves like jumping from side to side and dashing"
- "the walls ... you could just run into them for a few seconds and run back out and repeat to not get caught"
- "the game said 2 players left, avoid the walls, but i saw a bunch of players running around"
- "the grapple button doesn't seem to work? Or maybe im just not using it properly"
- "an actual tutorial to teach the player the movement and what to do as it"; "bots getting to places that i
  couldnt get to (ex. jumping twice ...) each time i tried i slid off the platform"
- "perhaps add a settings to use arrows instead of the joystick"

The question: **does a new player on a phone or a keyboard tag people when they touch them, feel IT can catch a good
runner, understand the final phase and the ghosts, and learn every move in under two minutes without reading, and want to come back?**

## Goals and rubric (each scored 0-10; pass = average >= 8.0, nothing below 7, no blocker)

| # | Goal | 10 looks like | Below 7 if |
|---|---|---|---|
| 1 | **A touch is a tag.** | Measured on two real clients: every visible touch by IT tags, and no tag fires from a visible gap. A log of refused tags (distance, ping, reason) is in the round file and has none that a player would call a touch. | Any refused tag the video shows as a touch, or no two-client measurement at all. |
| 2 | **IT can catch a good runner.** | A runner who plays well survives about one round as IT's target, not forever. Spamming dashes and hops doesn't make you safe. IT's edge is stated in DESIGN §3 with the number. | A bot or reviewer escapes IT indefinitely with dash spam, or IT catches everyone in seconds. |
| 3 | **The closing walls can't be gamed.** | Stepping out and back in doesn't refill the grace. The time outside adds up over the phase. The screen shows how long you have left. | The in-out loop from the playtest still avoids elimination. |
| 4 | **Ghosts read as ghosts.** | At a glance, on a phone, a living runner and a ghost are told apart (look, not just name). The final-phase banner counts RUNNERS. | A reviewer can't say who is alive within a second, or the banner and the screen disagree. |
| 5 | **The grapple explains itself.** | Anchors look hookable. The GRAPPLE button says why it's dimmed (no anchor in reach) or the anchor in range lights up. Every map has anchors where a player would look for one. | A first-time player presses GRAPPLE, nothing happens, and they can't tell why. |
| 6 | **A tutorial that teaches by doing.** | A short, skippable, guided run (practice room or first join): run, jump, double jump onto a ledge, wall jump, dash, grapple, then "you are IT: tag the bot". One verb at a time, under ~2 minutes, never a wall of text. Phone and keyboard prompts. | It's text cards only, can't be skipped, or leaves out IT or the double jump onto a platform. |
| 7 | **Arrow buttons option.** | A setting swaps the touch stick for left/right arrow buttons. It's remembered and works in a match. | Missing, or it breaks the stick for others. |
| 8 | **Fun, and you come back.** Danzo: "general playability and enjoyment and engagement and returning players" (retention / replayability). | A match is fun start to finish with no dead time. The player always has a goal (catch, escape, survive the walls, a coin or locker unlock in reach). After the podium they want to queue again, and there's a reason to return tomorrow (coins, the wheel, the locker, something new to unlock). The reviewer names what pulled them back. | Dead stretches, a match that feels the same every time, or nothing to want after the podium. |
| 9 | **Nothing broke.** | `npm test` and `npm run lint:luau` are green, the Rojo tree only grew, the line ceiling holds, and a full match runs lobby -> podium -> lobby. | Any regression in a full match. |

**Order (Danzo, 2026-11-22):** the normal `/qa-loop` on this file. The four-persona round is parked (he's gaming
on the PC, which was low on memory): `playtest-fixes-personas.md`.

## Limits of this loop (2026-11-22, Danzo is gaming on the PC)

- **No on-screen visuals unless Studio has focus.** Studio draws no 3D out of focus, and nobody takes focus from
  Danzo's game. The reviewer works from logs, state (`execute_luau`), code and tests, plus captures only when Studio
  happens to have focus. Each round file says which goals were judged blind.
- **Blind scores are provisional.** Goals that need eyes (4 ghosts, 5 anchors, 6 the tutorial rooms, 7 arrows) may
  score at most **8** blind. A 9-10 needs a capture or Danzo's look.
- **Goal 1 is capped at 8** until two real people play a match (H40 measured a model and solo Play with the network
  simulator, not two devices). Also check the tag-back swap: TAG_FREEZE 1.5 s with the wider reach.
- One Play client at a time. No multi-client test unless it's short, and stop it straight away after.

## Evidence the builder supplies each round

- A short video (or screenshot sequence) per goal, Danzo first (`references/review-loop.md`).
- For goal 1: the refused-tag log from a two-client Studio test (Studio's multi-client Test with simulated lag if two
  real devices aren't available; say which).
- Numbers changed in `Config.lua`, each with its reason.

## Out of scope (parked in `ideas/INBOX.md`)

- Map art and layout ("maps feel plain"): the art block and `docs/qa/maps-round1.md`, if Danzo keeps it.
- New abilities (the clone decoy): rolls are built and off (H35). Content, a later design pass.
- The 16+ rating and Max Players 50 -> 20: Danzo's Roblox settings, not code.
