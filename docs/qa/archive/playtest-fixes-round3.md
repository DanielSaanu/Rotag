# QA round 3: the playtest fixes — 7/10

Reviewer: Opus subagent, 2026-11-22. Branch `claude/friendly-hawking-74891i` @ d118997, goals file adc6543. Studio:
one Play session through execute_luau only, no captures. Judged blind: goals 3-7.

## Report (verbatim)

SCORE: 7/10

**What I ran:**
- `npm test`: 13 pass, 0 fail. That includes `zero_dt.test.luau` ("a taut swing, the run, the air, a dash, a glide, every hold and a slack rope stay finite at dt 0") and the structure/line-ceiling test. The bots CPU assert passed this time.
- `npm run lint:luau`: ok on every file.
- Studio: one Play session on "Rotag (placeId 81535510598835)", id 280b4489-…2711, driven only by execute_luau. AirGear was not touched. Play is stopped. I took no captures, so every visual goal is judged blind.

**Full match, seen in Studio:**
- I fired `Menu:FireServer("play")` from the Client and hooked Session, MatchState and TagVerdict into Player attributes.
- The phases went: lobby, `match 1 round 1 of 3: 1 people, 4 seats`, round 1, gap, round 2, gap 2, round 3, gap 3, **podium 3** (`"phase":"podium","left":12`), then **lobby** (my body was back at (576, 1.75)).
- Server: `session: Stifffchoclate earned 20 coins`, then `session: match 1 over: winner -1000`.
- The visible GUI at the podium: "GOOD GAME! / stand in a door to play again".
- LogService had 503 lines: 3 errors and 2 warnings. All of them are the Studio DataStore 403 or the stock `ContentId rbxassetid://203785492` line. There was no `bots: … non-finite`, no `errored` and no `H43` line. The H43 freeze did not recur.
- Snapshot streams held 28/s with gaps of about 40-50 ms. The one exception: a 566 ms client frame and a 550 ms gap mid round 2. Most likely Danzo's game loading the PC. I don't count it.

**Tag-back, set up with bots:** my client hook fired 8 `TagClaim`s at the tagger the moment my 1.5 s freeze ended.
- I was tagged by -1001 at a box distance of 0.82. At the end of my freeze it was 66.8 studs away. The server logged `claim 8061215879 -> -1001 dropped: no overlap … (closest: 74.1, 44.5 studs apart)`. That refusal is correct and readable.
- I was tagged by -1002 at 1.08. At freeze end it was 25.9 studs away, and no tag was given.
- Between bots, the swaps came 2.2-6 s apart. No swap came inside 1.5 s.

GOALS:
- 1 A touch is a tag: partial - the refusal log is correct and detailed (above, plus `close pass -1000: closest box gap 1.84, 1.90 studs (reach 1.25), NO claim`). The tag-back swap is safe with bots. There is still no two-client measurement, so the rubric holds it below 7.
- 2 IT can catch a good runner: partial (~7.5) - bots "it" tagged often and every round ended. But the escape sim on yard's real boxes, from round 2, was still not done, and `wall_double` still shows 126.6 studs of climb in 4 s.
- 3 Closing walls can't be gamed: met (blind) - live state shows `outside`/`refill` working. The bots went out and back in a dozen times in round 3, and the round still ended on time.
- 4 Ghosts read as ghosts: partial - by code the name prefix and the RUNNERS banner are there. The look is unchanged and nothing was captured.
- 5 Grapple explains itself: met, blind (cap 8) - `map "yard": 21 parts, 7 grapple anchors`. Bots logged 0-6 swings per 20 s.
- 6 Tutorial by doing: met, blind (cap 8) - `tutorial: the course built at x 1100 (7 rooms)`. `tutorial.test` landed 102/102 timings and tagged the target in 1.1-2.4 s.
- 7 Arrow buttons option: partial - `client/TouchPad.lua:94` now says "this visit". It is honest, but the setting is still not remembered.
- 8 Fun, and you come back: partial - the match ran start to finish with ghost play (hexes, fixtures, pads). Nothing new for retention, and the end-phase duel ran long (CONSIDER).
- 9 Nothing broke: met - tests and lint are green, and I saw a full lobby -> 3 rounds -> podium -> lobby with no Output error.

PRESERVE (done well, must survive future iterations):
- The dt <= 0 early return in `shared/Grapple.lua:114-116` and the 1e-6 floor in `Movement.lua:343`: they fix the cause where it lives, in shared code. That covers the player's own client too, not just bots.
- `zero_dt.test.luau`: it replays the caught frame across every movement state. It is the guard against S25 coming back.
- The pcall around each bot in `server/Bots.lua:292-307`, plus the finite checks at 162 and 247: one bot can no longer freeze the judge, the fuse and the walls for everyone.
- The refused-claim log line, with distance, target age and the reason: it is exactly the evidence goal 1 needs from the two-client run.
- Round 2's PRESERVE items: H42's rule, `refill` and the Snapshot integer decode. All are untouched.

FIX (done poorly; why it matters; concretely how to fix):
- **No two-client tag log yet.** Why: goal 1 sits below 7 by the rubric, which blocks a pass on its own. How: when Danzo is free, Test > 2 Clients with the 4G simulator for 3 minutes. Paste the `claim … received/dropped` and `close pass` lines into the round file, and include one deliberate tag-back where both players stand still when the freeze ends.
- **Arrows still session-only.** Why: goal 7's "10" asks for it to be remembered. How: Danzo makes the trigger 9 call to add one bool to the profile. The profile already saves coins and level (`data: … loaded`).

CONSIDER (fine but could change; why; how):
- **The end-phase ping-pong is long.**
  - What I saw: in round 1, two bots swapped "it" 18 times in about 75 s (TagVerdicts at 7398.7 … 7461.4). With +2.0 per pass the fuse fell only from about 22 s to 12-16 s. The window parked at `hw 24, vhw 0`.
  - Why it matters: for the two ghosts that is a long watch.
  - How: drop or halve `FUSE_PASS_BONUS` once `endPhase` is true, or let the fuse burn faster there. A heavy call, because it touches §3.
- **A three-way tie on points** (7/7/7, one win each) gave "winner -1000" through the first-seen tie-break (`Session.lua:19`). Why: to a player the podium may look arbitrary. How: break ties by the last round's placing, or show "tie" on the card.
- **The bot reset in `server/Bots.lua:255` sends the bot to `Arena.SPAWN` even in the end phase.** Why: the spawn may be outside the closing walls, so the bot burns outside time for a bug that wasn't its fault. How: reset to the window centre when `r.endPhase`.
- **The yard escape sim with wall climbs is still owed** from round 2.

UNCERTAIN (could not verify):
- Everything visual: the podium card as drawn, ghost contrast, anchors, the tutorial rooms, the arrow buttons. Studio was unfocused and I made no captures.
- Real-lag tags between two humans, and a human tag-back with a person standing still.
- How rare zero-dt frames are on a live server. The guard never fired in my run, which fits the shared fix but proves nothing about live frequency.
- Movement feel. Danzo should try, on a phone and on a keyboard: a run-up double jump onto a 4-tile ledge from close in, and a swing held through a hitch, to check that it never jerks or stops dead.

## Builder decisions

- **FIX two-client log / arrows remembered:** both need Danzo (his hands on two devices; trigger 9 for saved data).
  Carried to the summary as open items, with the exact test to run.
- **CONSIDER end-phase ping-pong:** a §3 change (trigger 1). Proposed to Danzo in the summary, not built.
- **CONSIDER three-way tie:** deferred: a scoring rule (trigger 1), a design call for Danzo.
- **CONSIDER bot reset in the end phase:** deferred. The guard is a last resort that never fired in round 3, and an
  arbitrary x inside the window can sit inside a deck block; the spawn is known clear.
- **CONSIDER yard escape sim:** deferred, the third time it was raised. The flat floor is the runner's best case, and a
  real chase between two people (the open FIX above) answers it better than a sim.
- **PRESERVE:** all kept; nothing changed after this round.
