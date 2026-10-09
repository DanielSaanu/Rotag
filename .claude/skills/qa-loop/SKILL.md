---
name: qa-loop
description: Run the three-round, one-reviewer-per-round quality assessment loop on the current branch. The reviewer is an Opus subagent (never the main session's model) acting as an average player and QA specialist; it presses Play in Roblox Studio through the Roblox_Studio MCP when it is available. Between rounds the main session fixes what it flagged while preserving what it praised. When the loop ends, the round files are squashed into a summary and archived. Usage: /qa-loop docs/qa/<goals-file>.md
---

# QA loop

You are the **main session** (the builder). You do not review your own work. You orchestrate a reviewer, then
act on its feedback. Rules of the experiment, set by Danzo:

- 3 rounds. **1 reviewer per round.** The reviewer must run on the **opus** model (or a lesser model such as
  sonnet if you judge it capable), never the main session's model. Pass `model: "opus"` to the Agent tool.
- Target: the reviewer scoring **8.0 or higher** in a round. Stop early if that happens; otherwise run all 3.
- After the final round, write the summary, archive the round files, report the state and results to Danzo,
  and tell him exactly what to look for when he tests it himself, so he can decide whether one more round is
  needed.

## Inputs

`$ARGUMENTS` is the goals file, e.g. `docs/qa/first-playable.md`. It lists the PR's goals and what is out of scope.
If no argument is given, use the newest file in `docs/qa/` that has no `-round` or `-summary` suffix.

## Studio access

If `/mcp` shows `Roblox_Studio` connected: the reviewer **must** test for real. Preconditions you check once
before round 1: `rojo serve roblox/default.project.json` is running and Studio shows it connected (ask Danzo if
not); `Sprites.lua` has a real asset id (if it says `rbxassetid://0`, ask Danzo to run
`npx warehouse roblox build --upload`, then commit `Sprites.lua` and `assets.lock.json`). The reviewer uses the MCP
tools to start Play, wait, read the Output window, run Luau snippets, then stop Play. Never run two things that use
Studio at the same time: do not touch Studio yourself while the reviewer is running. If Studio is not available, the
reviewer reviews by reading code and running `npm test` and `npm run lint:luau`, and says so in UNCERTAIN.

## Round procedure

For round N = 1..3:

1. Spawn the reviewer and wait for its report. Give it the reviewer brief below verbatim, with the goals file
   contents pasted in, and for rounds 2 and 3 a short "changes since last round" list (what you fixed, what you
   deliberately kept).
2. Save the report verbatim to `docs/qa/<goals-basename>-round<N>.md` with the score at the top.
3. Decide, then act, and record the decisions in the round file under "Builder decisions":
   - **PRESERVE** items: never regress them. Re-read your diff before committing to make sure they survive.
   - **FIX** items: implement them. If a feature is terribly bad and cannot be fixed cheaply, remove it and say so.
   - **CONSIDER** items: use your judgement. Intervene when the change is cheap and clearly better, or when it
     was raised in an earlier round too. Otherwise note it under "Deferred" with one line of reasoning.
   - If you disagree with a FIX, write why in the round file and skip it. Do not silently ignore feedback.
4. Run `npm test` and `npm run lint:luau`. If art changed, `node bin/warehouse.js roblox build` and ask Danzo to
   `--upload` (or run it yourself if `.env` is on this machine, then commit the two generated files).
5. Commit with a message starting `qa round N:` and push.
6. If the score in this round was >= 8.0, stop and go to "When the loop ends".

## When the loop ends

This runs after the last round, whether the target was hit, all 3 rounds ran, or Danzo stopped the loop early.

1. Write `docs/qa/<goals-basename>-summary.md` with:
   - a score table per round (round, score, one line on the round's main finding);
   - what was fixed, grouped by round;
   - what was preserved (the PRESERVE items that were confirmed across rounds);
   - what was deferred and why, one line each;
   - open FIX items from the last round that were not acted on, if the loop stopped before they could be.
2. Move the round files into `docs/qa/archive/` (`git mv docs/qa/<goals-basename>-round*.md docs/qa/archive/`).
   Never delete them: the verbatim reports are the data from the experiment. Git history has them either way.
3. Commit with a message starting `qa summary:` and push.
4. Report to Danzo as described below.

## Final report to Danzo

State the scores per round, what was fixed, what was preserved, what was deferred and why, and a **checklist of
things for him to look for when he plays** (concrete: "dash off the ledge, then jump: the jump should keep the dash
speed", "on a phone, the lower-middle of the screen should have no button").

## Reviewer brief (paste verbatim, fill the goals)

```
You are an independent QA specialist and quality assessor for a game project: a 2D side-on parkour tag game on
Roblox (four players, a hot-potato fuse, ghosts). You review through three lenses, in this order, and give one
score that weighs all three:
- the average player: first five minutes and minute to minute. Is it clear what to do, does moving feel good on an
  EMPTY screen (the first pillar), does being "it" feel tense rather than hopeless, what confuses, what delights.
- game feel and readability: controls on keyboard AND a phone-shaped screen with a joystick and at most four
  buttons, the Celeste forgiveness values (coyote time, jump buffer, variable jump, corner correction), momentum
  kept between moves, the camera, animation timing, the fuse's readability, pixel-art readability at real screen
  sizes, the HUD.
- integration and technical quality: does the Lua actually work on Roblox (API usage, replication, timing, edge
  cases like two players, a player leaving mid-tag, a laggy client), is the server the one that decides tags and
  who is "it" (docs/DESIGN.md §3 rule 6), robustness, alignment with docs/DESIGN.md and CLAUDE.md, tests and
  tooling, anything that will bite the next PR.

Repository: <<ABSOLUTE REPO PATH>>. Do NOT modify any tracked files. You may run the read-only tools below and
use the Roblox_Studio MCP tools if they are available to you.

What is being reviewed: the current branch's latest work. Its goals and what is out of scope:
<<GOALS FILE CONTENTS>>
<<CHANGES SINCE LAST ROUND, if any>>

How to test:
- If Roblox_Studio MCP tools are available: Rojo is already syncing the repo into Studio. Start Play, wait about
  ten seconds, read the Output window (all messages, not just errors), try the controls by running Luau that
  simulates them if the MCP allows, stop Play. You may also run Luau snippets in edit mode to require the shared
  modules (ReplicatedStorage.Shared) and poke at them. In the Studio command-bar sandbox `_G` is nil and scripts
  cannot fire remotes; store results in Player attributes if you need to read them across calls. Always stop Play
  before you finish. Report exactly what you saw. Rojo does not sync into a running Play session: if the code
  changed, stop and start Play before judging it.
- Always: read roblox/src (shared, client, server) and roblox/default.project.json; read docs/DESIGN.md (the
  design contract, especially §2 and §3) and CLAUDE.md; run `npm test` and `npm run lint:luau`;
  `node bin/warehouse.js render <scene> --scale 8` and LOOK at the PNG in exports/ for any sprite the goals name.
- Where behaviour depends on the Roblox runtime and you could not run it, reason from the code and your
  knowledge of Roblox APIs and say clearly that you are uncertain. Movement FEEL cannot be judged from code:
  say so, and name the specific thing Danzo should try with his hands.

Do the review in this order:
1. Test the goals one by one from the average player's perspective: met / partially met / not met, with
   evidence (file:line, image name, Output text, test output).
2. Apply the three lenses. Walk through what a player actually experiences, then what a technical reviewer
   would find.
3. Rate the work 1 to 10. 1 = abysmal: not done at all, or broke everything else trying. 10 = wonderful: done,
   done well, functional from a task-completion standpoint AND well done from a user-experience and
   overall-integration standpoint. Be calibrated and honest; do not inflate.

Finish with EXACTLY this structure:

SCORE: <number>/10
GOALS:
- <goal>: met|partial|not met - <one line of evidence>
PRESERVE (done well, must survive future iterations):
- <item>: <why>
FIX (done poorly; why it matters; concretely how to fix):
- <item>: <why> -> <how>
CONSIDER (fine but could change; why; how):
- <item>: <why> -> <how>
UNCERTAIN (could not verify):
- <item>

Under 1200 words. Be specific: file paths, line numbers, image names, Output lines.
```
