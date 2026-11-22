# QA summary: the playtest fixes (QA Central #10775) — 7 -> 5 -> 7 (target 8 not met)

Goals: [`playtest-fixes.md`](playtest-fixes.md). Triage: [`playtest-2026-11-20.md`](playtest-2026-11-20.md). Rounds
are archived in `[archive/](archive/) (playtest-fixes-round1-3)`. Built 2026-11-22 by the local session (two-session team with
the cloud session, which wrote the triage, the goals, the research and read each round adversarially). Every round ran
**blind**: Danzo was gaming on the PC, so Studio drew no 3D and nobody sent keys or mouse. Goals 4-7 were capped at 8,
and goal 1 below 7 until two real people play.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7 | The fixes are right; the wall grace was invisible once back inside; the double jump beside a wall was still a kick in matches |
| 2 | 5 | BLOCKER: the first live match of the loop froze on a NaN in the bot planner |
| 3 | 7 | A full match ran lobby -> 3 rounds -> podium -> lobby with no error; what's left needs Danzo's hands or calls |

## What was fixed

**Before round 1** (the build):
- H40, the chase (`docs/systems/dash-tag.md` §6-7). Measured first: the server refused no claims. The real causes were
  that the hand stopped short of the sprite and that a dash away dodged. TAG_REACH 0.5 -> 1.25 across; the dodge only
  applies to a dash at or through "it" (or when both dash); "it" x1.1 always, the ramp from 2 s; the wall grace refills
  at 0.25 s/s instead of resetting; a Studio-only close-pass log.
- Ghosts: a GHOST name tag, paler sprites, the banner counts RUNNERS. Grapple: "no anchor" on the button, plus a hint.
  Touch: a STICK/ARROWS switch. H41: a seven-room tutorial, a TUTORIAL door, a first-join start, SKIP.

**Round 1:** the wall grace shows inside ("wall time x / 6") and seeds GET BACK IN (MatchState `refill`). H42: a press
while rising beside a wall is the double jump (tutorial ledge 24/102 -> 102/102); a dash-hop spammer was caught 20/20.

**Round 2:** H43: Heartbeat's dt == 0 on a taut rope gave a NaN bot that froze the match. It's fixed in shared
Grapple and Movement, plus finite guards and a pcall per bot (S25). The arrows switch says "this visit".

## Preserved (confirmed across rounds)

- Measure before tuning: the close-pass log, chase_sim, the reach preview (R1-R3).
- `Tag.dodges` judged on the server's own record; no new remote (R1-R3).
- The wall grace pool and `refill` (R1-R3). H42's rule and `wall_double.test` (R2-R3). The dt == 0 guards and
  `zero_dt.test` (R3). The Snapshot integer decode (R2-R3).

## Deferred, and why

- Ghost contrast beyond 0.3/0.5: needs one phone screenshot first.
- An escape sim on yard's real boxes: a real two-person chase answers it better.
- The bot reset to the spawn in the end phase: a last resort that never fired; the spawn is known clear.
- Funnel events per tutorial room: Danzo's call.

## Open: needs Danzo (not actionable by the loop)

1. **Two real clients** (goal 1's cap). Test > 2 Clients with the 4G simulator, 3 minutes as IT, with one deliberate
   tag-back. Paste the `close pass` and `claim … dropped` lines into a round file.
2. **Save the arrows setting and a "tutorial done" flag** (trigger 9: one bool each on the profile)?
3. **The end-phase ping-pong** (round 3: two bots swapped "it" 18 times in 75 s; +2 s per pass kept the fuse alive).
   Halve FUSE_PASS_BONUS in the end phase? A §3 change.
4. **A three-way points tie** goes to the first-seen player. Break ties by the last round, or show TIE?
5. Roblox settings: Max Players 50 -> 20 (my Open Cloud attempt was blocked), the 16+ questionnaire.

## Open: a follow-up for the routine session

- **H44 (trigger 3):** a client that sets its root to a NaN CFrame, which Roblox parks at (0, -1e6, 0). Does the
  server's move check snap it back, or can a cheater freeze a match the way H43's bot did? (Raised by the cloud session.)
