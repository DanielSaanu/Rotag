# Experimental round: four persona reviewers in one match (playtest fixes)

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

## What each review contains (same shape for all four)

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
