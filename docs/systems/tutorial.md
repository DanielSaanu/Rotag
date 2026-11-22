# The tutorial course (H41)

**Created:** 2026-11-22 (heavy agent, H41). From playtest #10775: "the game would benefit a lot from an actual
tutorial to teach the player the movement and what to do as it"; "a step by step tutorial for the wall climbing,
grapple, and other mechanics"; "each time i tried i slid off the platform"; "the grapple button doesn't seem to
work?". Goal 6 of [../qa/playtest-fixes.md](../qa/playtest-fixes.md); research
[../research/movement-tutorials.md](../research/movement-tutorials.md) (on `origin/claude/stoic-euler-231upu`).

## 1. What a player meets

A course of seven rooms in a row, **one move per room**, then the IT lesson. No text cards: one pill at the top
says the lesson and one line says what to press, in the words of the device in hand. A finished lesson pops
("NICE JUMP!  next: DOUBLE JUMP"). **SKIP TUTORIAL** sits at the top right the whole time.

| # | Room | What is there | Finished when |
|---|---|---|---|
| 1 | RUN | flat floor | standing in the goal, 30 studs on |
| 2 | JUMP | a 2-tile block | standing past it (a run alone never gets there) |
| 3 | DOUBLE JUMP | a solid 4.5-tile ledge, 8 tiles wide, a gold take-off line on the floor | standing on the ledge (one jump never does) |
| 4 | WALL JUMP | a pillar you walk under, a 3-tile shaft, a 10-tile tower | standing on the tower (jumps alone never do) |
| 5 | DASH | a 2-tile roof over a pit 7 tiles wide; a fall puts you back at the room's start at once | standing past the pit |
| 6 | GRAPPLE | a safe dip (3 tiles deep) with a gold ball over it | a hook, then letting go |
| 7 | IT | a closed room, one crate, a runner called TARGET; a 20 s fuse on the pill | the SERVER confirms your tag |

The whole run takes about a minute. A lesson whose room you walk past is marked passed, not done, and never asks
you to go back (rule 19). After the tag: "TAGGED! now THEY are it  ·  course done in 0:58", four seconds, then the
lobby and "YOU'RE READY! stand in QUICK MATCH to play". The IT lesson's fuse is drawn by the client only: at 0 it
says "in a match you'd be a ghost now: try again" and starts over. Nothing burns, nothing pays.

## 2. Where it lives and how a player gets there

- **The course** is more parts in the same world: local x -8..420 from `Tutorial.X` = 1100 (the lobby is at 600,
  the room at 800, both inside the snapshot's ±2047). Built at boot on every server (`server/Course.build`), solo,
  on the same server: no reserved server.
- **The TUTORIAL door** in the lobby: downstairs, right of QUICK MATCH, white (the one lobby colour no door used),
  8 studs wide. To fit it, the LOCKER went from 10 to 8 studs wide, so 80 of the floor's 112 studs stay outside
  every door (lobby.test's rule).
- **The first join:** a player whose **saved** profile has never finished a match (`matches == 0`) starts on the
  course, once a server visit (`Tutorial.FIRST_JOIN`). A profile that did not load (Studio without API access, an
  outage) is not a first join. In Studio, workspace attribute `RotagTutorialFirst = true` makes every join one.
- **Not on** a match server, a room's server or a practice server (the players there came to play).

## 3. Why the rooms are the size they are (measured, `test/luau/tutorial.test.luau`)

Every number was driven through the real `Movement` (and `Grapple`) in the course's own `BoxWorld`:

- One jump peaks at 14.25 studs, two at 28.5; at a run, one jump carries 31 studs across, two 55, two and a dash 76.
  A swing carries about 40.
- **Double jump.** A second jump pressed BESIDE a wall is a wall kick away from it, never a double jump (Movement
  checks the wall first). A beginner who jumps close to a tall ledge and presses again is thrown off it: this is
  very likely the playtester's "each time i tried i slid off the platform". The ledge is solid (a thin deck was
  worse: a jump from under it bonks) and a gold line 18-24 studs back marks where to take off: from the line, a
  jump and a second press 0.1-0.3 s later land on top 35 times out of 35. **H42 changed Movement:** a press rising
  beside a wall is now the double jump (unless pushed away, or the wall was used: movement.md §3), so from past the
  line up to the face it lands 102 of 102 (was 24, with 78 kicks). The line stays as the easy spot.
- **Wall jump.** The tower (40) is over a double jump; kicking up the 12-stud shaft gets on it whether the press
  comes while rising, at the top, or sliding down. No jump and double jump timing reaches it.
- **Dash.** No room can NEED the dash outright: under a 2-tile roof a jump bonks, but a jump and a double jump
  timed well still cross a 28-stud pit 18 times in 315 (6%). A jump at the edge and a dash any time in the next
  quarter second always crosses. The pit is a fall (back to the room's start, server-side, at once).
- **Grapple.** No pit can need the grapple: a double jump crosses 55 studs and a swing about 40, and a swing
  ACROSS a pit only lands for a narrow window of release (measured: under a third of hook and release timings).
  So the room checks the move, not a crossing: a hook and a let-go finish it, over a safe dip, whatever happens
  after. From the dip's edge the ball is the aim assist's pick, and a jump plus a held GRAPPLE hooks it at any
  moment of the jump. The prompt says to press in the air: a press held from the floor runs out its 0.1 s buffer
  and never hooks (Movement's `grappleArmed` is set only by a press in the air).
- **IT.** The target runs at 0.9 x run speed (0.6 after 8 s of being chased), turns and hops past you when
  cornered, and stops trying once tired. You run at `IT_SPEED` (1.1, H40) in this lesson. A chaser that runs at it
  tags it in 1.5-2.5 s, one that also jumps to meet the hop sooner: never in the first second.

## 4. The pieces

| Piece | What it does |
|---|---|
| `shared/Tutorial` (pure, tested) | the blocks, the anchor, the rooms and their goals, `update` (the lesson rules), `fell`, `flee` (the target), `caught` (the server's tag check), `touching` (= `Tag.overlaps`) |
| `server/Course` | builds the parts, the first-join start, the pit's fall, the target (a `Dummy` stepped through `Movement` in `BoxWorld`, drawn everywhere through `Snapshots.inject`), judges `tutorial` / `tut:skip` / `tut:tag` |
| `server/Doors` | hands `tutorial` and `tut:*` to `Course.ask` (same rate gap, same launching check) |
| `client/Tutorial` | the lesson rules every physics step, the pill and the pops, the fuse, SKIP, the claim |
| `client/Controls.say` | "press SPACE" / "press Z" / "press A" / "tap JUMP", by the device last used (and "hold the > button" with ARROWS on) |
| `client/Lobby` | `here()` is true on the course too (a round's HUD stays off it); it leaves the course's pill alone |
| `client/Grapple` | an anchor with `NoFloor` (the course's) is not waited for |
| `client/Arrows` | no off-screen arrow to the target (`Coach` attribute) |

## 5. What the server trusts (→ N4, DESIGN §3 rule 6)

No new remote: `Remotes.Menu` carries three more strings.

| Op | Accepted when (the server's own newest position of the sender) |
|---|---|
| `tutorial` | a hub or solo server; in the lobby, within 8 studs of the TUTORIAL door; not in a room; once per 3 s. It takes the sender out of the queue first |
| `tut:skip` | on the course. Back to the lobby (or its room) |
| `tut:tag` | on the course; not already won; the target not frozen; the sender's newest position touches where the target WAS at any moment in the last 0.5 s, within the tag's reach + `TAG_GRACE` |

The lessons are the client's: nothing rides on them. The tag is the one thing confirmed like a tag: the client
claims on the overlap it draws (`Others.drawnAt` of the target), the server checks its own record of the target
(the server simulates it, so its history is the truth) against its own newest sample of the player, and only
then sends `note = "tuttag"` to that player. A lying client wins its own tutorial and nothing else. The pit's fall is
judged by the server alone, on its own position of the player.

## 6. Memory: session-only (trigger 9 not crossed)

Nothing new is saved. "Finished" lives in `server/Course` for the server visit, and the first-join start keys on
the profile's existing `matches` count. The cost: a player who never finishes a match is started on the course
again on their next visit (one SKIP press). A saved `tutorial` flag would fix that; it is Danzo's call (§8).

## 7. What was seen (Studio, 2026-11-22, one Play, no keyboard or mouse: Danzo was gaming)

- Output: `tutorial: the course built at x 1100 (7 rooms)`, no errors from any new file.
- The TUTORIAL door request from in the doorway put a new body at the course's start; the target came up and
  streamed at 28 snapshots a second to the client. On screen: the pill `1 / 7  RUN` with "hold D or the right arrow
  to the next room", SKIP TUTORIAL top right (it sat on the wallet's "NOT SAVING" line: moved down).
- With the body moved into the IT room by a script: the client claimed, the server logged `tagged the target:
  tutorial done`, four seconds later the body was back in the lobby, and the target was gone five seconds after.
- Found and fixed: two `tutorial` requests in one frame each built a body (now once per 3 s).
- **Not seen:** the course itself on screen (Studio drew no 3D while out of focus: the lobby was as dark),
  a hand on the controls in any room, a phone, the first-join start with a saved profile, two players on the
  course at once.

## 8. Open, for Danzo

- **Feel, by hand:** each room on a keyboard and a phone, and whether a minute is right.
- **The double jump beside a wall** (§3): done in H42 (movement.md §3). Feel it by hand: the ledge from close up, and
  the tower's shaft (the first press rising beside the tower is now a double jump; kicks follow).
- **Save "finished"** (a `tutorial` field in the profile: trigger 9) so a returning player who skipped is never
  started on it again. Today: session-only.
- **Funnel events** (research rec. 5): `AnalyticsService` onboarding steps per room would show where new players
  quit. Not built.
- **A ghost demo per room** (research rec. 3) and contextual hints in real matches: not built.
