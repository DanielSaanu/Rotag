# QA summary: the walk-in lobby (a design, nothing built)

Goals: [lobby-design.md](lobby-design.md). Handoff H36. 2026-11-18. Two rounds, one fresh Opus reviewer each,
judging three rendered boards (`exports/lobby_design/lobby.png`, `room.png`, `gate.png`); no Studio, no tests, no
Luau. Boards: https://claude.ai/artifact/9VdirngqxNgVu1MYpVbZPt. Round reports: `archive/lobby-design-round*.md`.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | Zones by colour work; too much small text for a phone, pads on the walking routes, queueing meant standing still, three rules unsaid |
| 2 | 8/10 (target) | Reads at a glance; the queue's "stand in the door again to leave" clashed with the picture and with the LOCKER |

## Fixed

**Round 1:** the headline (STAND IN A DOOR TO CHOOSE); one pad only, at the far-left wall; a queued player keeps
running (HUD pill); signs of one or two words, the detail in a caption near a door; friends' doors cut for v1, the
wheel folded into the LOCKER, the signpost removed; the room's rules written (the code always works, host
hand-over, HOST ONLY flash), two blocks (ROUNDS, ITEMS); the how-to given a home; the build cost list in H36.

**Round 2 (done after the target was met, not re-reviewed):** leaving the queue is walk out, come back, hold two
seconds; the LOCKER never dequeues; the host's START says STAND HERE; the bar reads STAY; stale text in the goals
file and H36 fixed; the build list gained the fixed camera, the caption UI and the "?" card.

## Preserved (confirmed in both rounds)

- Colour = zone, with the zone's name painted on the floor.
- Stand in a door for a second to choose; running past does nothing; nobody can be shoved in.
- The QUICK MATCH door shows the live count (2 / 4).
- Bots hold empty seats; a friend who joins takes a bot's seat.
- The room code in huge digits with one line on how friends use it.
- Red stays reserved for "it"; no ranked door.
- The Brawlhalla mapping: matchmaking, custom room by number, training, store.

## Deferred

- **Phone thumbs over the bottom of the lobby** (door icons, floor paint, the pad in the corner): decided when the
  lobby map and its camera are built.
- **Roblox's "Join friend" lands in the hub, not the room:** a build question (trigger 3), noted in H36.
- **Lime shared by QUICK MATCH and pads, cyan by PRACTICE and "you":** accepted in both rounds.
- **A THIS WEEK door:** waits for round modifiers.

## Not judged by anyone

How any of it feels to move through (one second in a door, stopping inside a door at full speed, reaching a block
with one jump, the pad arc to PRACTICE), real sizes on a phone, teleport waits. All need the build.
