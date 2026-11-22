# Experimental round: four persona reviewers in one match (playtest fixes)

**PARKED, not run (Danzo, 2026-11-22 14:55): "skip it, I'm playing Apex while you work, just do it like you normally
would".** The Roblox Player had crashed from low memory on the shared PC (local session, Player log), and four
clients plus a server would squeeze it more. Kept for a time the PC is free.

**Danzo (2026-11-22):** "have some qa reviewers play and each one should act like a player who was most frustrated
by one of those points there should be 4 reviewers they should all play together in one match by spinning up
multiple sessions in roblox and after the match they should then write a review this is an experimental method try
it for just one round of testing i want to see how effective it is"

**One round only**, run after the fix pass for `docs/qa/playtest-fixes.md` is built. It doesn't replace the
`/qa-loop` rounds. It's an experiment we compare against them.

## Setup

- Studio **Test → Clients and Servers, 4 players**, one match, no bots in the seats (the four reviewers are the
  four runners). Record each client (video or screenshot sequence) and the Server Output.
- Each reviewer is an **Opus subagent** (not Fable) that drives one client and sees only that client's screen and
  Output. It knows its persona and the game as a player would (HOW TO PLAY, the screen). It does **not** see the
  source, the triage or the other reviewers' notes.
- **Honesty rule:** if a reviewer couldn't really control its client (inputs scripted for it, turns taken, lag from
  the harness), it says so at the top of its review. A review written from a recording it watched rather than
  played is labelled "watched, not played".
- After the podium, each writes its review independently. The builder then saves them verbatim as
  `docs/qa/playtest-fixes-personas-<n>.md`.

## What the harness can and can't do (local session, 2026-11-22; seen with 2 clients on 2026-10-14)

- **Can:** each Test client is its own Studio instance (`list_roblox_studios`). Per client, an agent sends real
  inputs (`user_keyboard_input`: D/A, Space, Shift, W), captures the screen or video, runs `execute_luau`
  (`LocalPlayer.Name` tells clients apart) and reads that client's console. So four agents each own one client.
- **Can't:** play in real time. Each action is a tool call holding keys for a set time, seconds apart, so a chase is
  bursts, not twitch play. **Reviewers don't score feel, reaction-speed dodging or touch=tag at full speed.** They
  judge what's on screen: whether a tag registers when two runners overlap, the wall in-out trick, ghost readability,
  the grapple hint, the tutorial's steps.
- **Frame rate:** unfocused Studio windows are throttled to 25% of the cap, and 4 clients + server share one PC. Below
  60 fps is expected. Don't count it as a game bug.
- **Hard evidence for goal 1 is the server's refused-tag log** (distance, reason), not the agents' impressions.
- Starting a 4-player Test may need Danzo's one click. Whether a Test client can use the phone Device Simulator is
  still unknown. Persona 4 says which it got.

## The four personas

| # | Who | Most frustrated by | How they play | Main goals checked |
|---|---|---|---|---|
| 1 | **"My touches don't tag"**: played IT a lot last time, kept touching people and nothing happened | goal 1 | Chases hard as IT, goes for close touches, body-on-body, mid-dash, through jumps. Counts every touch that didn't tag. | 1, 2 |
| 2 | **"IT is too easy to escape"**: a good, smug runner who spams side hops and dashes | goal 2 | As a runner, tries the dash-spam escape and times how long it lasts. As IT, tries to catch someone doing it. | 2, 1 |
| 3 | **"The end of the round made no sense"**: confused by "2 players left" while ghosts ran about, and dodged the walls by stepping in and out | goals 3, 4 | Tries the in-out wall trick in the final phase. Says at each moment who it thinks is alive and whether the banner agrees. | 3, 4 |
| 4 | **"First time here, the grapple did nothing"**: a new player who skips reading, on a phone-sized screen | goals 5, 6, 7 | Starts with the tutorial (or skips it and comes back). Presses GRAPPLE without an anchor. Tries the double jump onto a ledge. Uses the arrow-buttons option if it can. | 5, 6, 7 |

## The match is planned ahead (Danzo, 2026-11-22)

"have them plan a match ahead of time maybe set one of the reviewers to orchestrate it such that each player would
encounter their problem staggered with multiple chances for it so they can reflect on the experience"

- **Reviewer 2 doubles as director.** Before Play, it writes the run sheet below into
  `docs/qa/playtest-fixes-personas-plan.md` and sends it to the other three. During the match it calls each scene
  ("scene 3 starts: P1 is IT, P2 runs the dash spam").
- **The director may set the stage, never the outcome.** It may use the SERVER window's `execute_luau` only to put
  players in place: who is IT, a respawn point, skip to the end phase, give an item. It never forces a tag, a miss or
  an elimination. Every setup call is logged in the plan file, with the time it was made.
- **Staggered, with repeats.** Each persona's problem comes up **2-3 times**, spread through the match, never twice
  in a row. That way a reviewer meets it again after it has reflected, not in one burst.
- **A one-line note after every scene.** Each reviewer writes "what I tried, what happened, how it felt as my
  persona" into its own notes before the next scene starts. The final review is built from those notes.

Example run sheet (the director adapts it to the build and the maps):

| Scene | Round | Set-up | Spotlight | Others |
|---|---|---|---|---|
| 1 | warm-up | P4 runs the tutorial from the practice door | P4: tutorial, grapple, double jump | P1-P3 wait in the lobby, note the lobby |
| 2 | 1 | P1 is IT | P1: close touches, body-on-body, mid-dash | P2-P4 run normally |
| 3 | 1 | P1 still IT, P2 starts the dash spam | P2: dash-spam escape, timed | P1 chases P2 only |
| 4 | 1 end | let the end phase come | P3: wall in-out, the banner vs who's alive | others play it straight |
| 5 | 2 | P2 is IT | P2: catch a dash-spammer (P1 runs it) | P4: GRAPPLE with and without an anchor |
| 6 | 2 | P1 tagged early, becomes IT again | P1: touches, second chance | P3 watches the ghosts |
| 7 | 2 end | end phase | P3: wall trick again; P4: arrow-buttons option | |
| 8 | 3 | P3 is IT | P1: as a runner, does a tag on ME register when it should? | P2: dash spam, third time |
| 9 | 3 end | end phase, to the podium | P3: third wall check; everyone: "queue again?" | |

## What each review contains (same shape for all four)

0. The scene notes, verbatim (one line per scene).
1. Score 0-10 from this persona's point of view, and one line: "would I play again with friends?"
2. **Was my frustration fixed?** Yes / partly / no, with the moments (timestamp or round) that show it.
3. What else bothered me (anything, not just my point).
4. What I liked.
5. Control honesty: how I drove the client, and anything that may have skewed what I saw.

## How we judge the experiment (cloud session, afterwards)

- **Agreement:** did the four reviews agree on the shared facts (who tagged whom, when the walls closed)? Check
  against the Server Output.
- **New findings:** what did they find that the normal one-reviewer round didn't, and the reverse?
- **Cost:** agents spawned, wall-clock time, anything the harness couldn't do.
- **Verdict for Danzo:** keep, change or drop the method, in three lines.
