# QA round 1: the playtest fixes — 7/10

Reviewer: Opus subagent, 2026-11-22. Branch `claude/friendly-hawking-74891i` @ 0c373d0. Studio: one Play session
driven through execute_luau only (Danzo was gaming: no keyboard or mouse input; no 3D drawn out of focus).

## Report (verbatim)

SCORE: 7/10

What I ran:
- `npm test` passes with 0 failures, and `npm run lint:luau` reports ok on every file.
- One Studio Play session on "Rotag (placeId 81535510598835)", driven only through execute_luau on the Server datamodel. I stopped it before finishing.
- `node test/luau/sim.js chase_sim.luau`.
- I rendered `preview_tag_reach@4x.png` and looked at it.

What Studio showed:
- The Output had no errors from new code: `[Rotag] tutorial: the course built at x 1100 (7 rooms)`, `map "yard": ... 7 grapple anchors`, client up, ready sent.
- The only problem lines were expected ones: the DataStore 403 in Studio, and `ContentId rbxassetid://203785492 failed due to: Asset type does not match` three times. That id is not in `roblox/src`, so it looks like it predates this branch.
- The 3D view was not judged, because Studio was out of focus.

GOALS:
- 1 A touch is a tag: partial. The reach change is right and well evidenced, but by the rubric's own line this is below 7: there is no two-client measurement. Evidence:
  - TAG_REACH went 0.5 -> 1.25 across (`Config.lua`). In `preview_tag_reach@4x.png`, the 3.25-stud row clearly overlaps and the 3.6 row shows a gap.
  - `chase_sim` refused 0 claims in every cell.
  - But the 3G/3G "slow catch" cell claims only 5%, and that is a model, not two real clients.
- 2 IT can catch a good runner: partial.
  - IT_SPEED 1.1 and RAMP_DELAY 2 are stated in DESIGN §3 (line 82).
  - `Tag.dodges` (`Tag.lua` ~155) now only gives i-frames for a dash aimed at the tagger.
  - No sim or bot measures a dash-spam runner escaping over a whole round.
- 3 Closing walls can't be gamed: partial.
  - I simulated the refill in Studio. Out 3/in 3 dies at 13.5 s, out 5/in 5 at 12.25 s. Out 1/in 4 and out 2/in 8 never die, but that means spending 80% of the time inside, so the exploit is closed.
  - The screen does NOT show the remaining grace while you are back inside, and stepping out shows 6.0 before the server's real number arrives. Details under FIX.
- 4 Ghosts read as ghosts: partial.
  - The names now read "GHOST <name>" (`Present.lua:183`) and the banner says "LAST 2 RUNNERS" / "OVERTIME: n RUNNERS" (`Hud.lua:225`). Both are right.
  - The look only went to 0.3 / 0.5 transparency (`Look.lua:202`). Whether that reads on a phone at a glance was not seen.
- 5 Grapple explains itself: met (by code). The button reads "GRAPPLE\nno anchor" (`Controls.lua:204`), and a "NO ANCHOR IN REACH" callout fires at most 4 times, 6 s apart (`Grapple.lua:127`). Yard has 7 anchors.
- 6 Tutorial by doing: met (by code and tests).
  - Seven rooms, SKIP, a first-join start, and an IT room whose tag the server confirms.
  - `tutorial.test` shows 35/35 double-jump timings from the line land on the ledge.
  - Nobody has played it by hand yet.
- 7 Arrow buttons option: partial. The switch works per player (`TouchPad.lua:66`, local `TouchControlsEnabled`), but it is session-only (`TouchPad.lua:5`). The rubric asks for it to be remembered.
- 8 Fun, and you come back: partial / unverified. Nothing new for coming back on this branch beyond the tutorial. No one has played a match since.
- 9 Nothing broke: partial. Tests and lint are green, the tree only grew (new files Course, TouchPad, two Tutorial modules), and the boot was clean. A full lobby -> podium -> lobby match was not run.

PRESERVE:
- Measuring before tuning (H40): the close-pass log in `Tagging.lua:92-111`, the chase_sim link matrix, and the drawn-sprite reach preview. These found the real cause: no claim was sent for the last ~1 stud, and the server was not refusing anything.
- `Tag.dodges` keeps the server judging on its own record, and the client still sends claims on runners drawn dashing. Rule 6 is kept, and there is no new remote (tutorial.md §5).
- The wall grace as a refilling pool (`Walls.lua:160-174`) rather than a reset, with tests.
- Tutorial rooms sized by measurement through the real Movement (tutorial.md §3), including the honest note that no room can force the dash or the grapple.
- The grapple hint's rate cap (HINT_MAX 4), so a player who already knows stops being told.

FIX:
- Wall grace is invisible inside and wrong for a moment on stepping out. This matters because the goal says "the screen shows how long you have left", and a runner with 1.5 s left who sees "6.0" will die believing they had time. How to fix:
  - Carry `w.pool[id]` in MatchState (for example `state.pool` or a `grace` field per living runner).
  - Seed the client prediction in `client/Walls.lua:141` with that value instead of `Config.WALL_GRACE`.
  - Show a small grace meter while it refills.
- The double-jump "slid off" problem is only worked around inside the tutorial. tutorial.md §3/§8 says a second press next to a wall is a wall kick, not a double jump. That is the testers' real complaint, and it still happens on every map ledge in a match: a gold line exists only in the tutorial. How to fix: open the Movement handoff tutorial.md §8 proposes (prefer the double jump while rising, unless the stick points away from the wall). Danzo should try it by hand first: jump at a 4-tile ledge from close and press jump again.
- Goal 1 has no real two-client evidence. How to fix: once Danzo is free, run Studio's Test > Clients 2 with the network simulator on 4G, play 3 minutes as IT, and paste the `[Rotag] tag: close pass` lines and the server's refusals into the round file.
- The arrows setting is not remembered. How to fix: store it as a profile field. That is trigger 9 (saved data), so hand it to Danzo. Or say clearly in the UI that it resets per visit.

CONSIDER:
- A dash-spam escape test. Goal 2's "below 7" case (escaping forever with dash spam) has no measurement. Add a chase_sim scenario: a runner dashing on cooldown and hopping, IT at 1.1 -> 1.265, time to catch over 60 s.
- Ghost contrast. 0.3 transparency on a ready ghost may still read as alive at phone size. Try an outline colour or a desaturated sprite, not transparency alone, and judge it on a real phone screenshot.
- The tutorial's "finished" flag. A player who skips and never finishes a match gets the course again every visit. Saving the flag is cheap, but it is Danzo's trigger 9 call.
- Funnel analytics per tutorial room (tutorial.md §8), to see where new players quit.

UNCERTAIN:
- Anything visual: the 3D was not drawn (Studio out of focus). Ghost readability, anchor look, the tutorial rooms, the TouchPad layout on a phone.
- A real two-client tag test, or real 3G.
- Movement feel at IT_SPEED 1.1. Danzo should play IT against a friend who spams dash plus side-to-side hops, and see whether a catch comes within about 20 s.
- A full match from lobby to podium and back, and the first-join start with a saved profile.
- Whether hiding `TouchControlsEnabled` has side effects on some devices (for example the Roblox menu button). Check on a real phone.

## Builder decisions

- **FIX wall grace on screen: done.** `server/Walls.rows` returns `refill` ({ id, left } for each living runner back
  inside with a refilling pool); MatchState carries it (`docs/systems/README.md`); `Tagging.poolLeft(id)` extrapolates
  it at WALL_REFILL; `client/Walls.update` seeds the GET BACK IN count with it on stepping out and shows a quiet
  "wall time 3.2 / 6" line while it refills inside. No shared/ change.
- **FIX double jump beside a wall: escalated as H42** (`shared/Movement`, trigger 2), with the CONSIDER dash-spam
  chase_sim scenario in the same handoff.
- **FIX two-client evidence: deferred to Danzo.** He is gaming on the PC and cancelled the multi-client run; the
  MCP cannot start one. Goal 1 is capped until he plays a real two-device match with the Studio log open.
- **FIX arrows remembered: deferred to Danzo (trigger 9, saved data).** Kept session-only, as the TouchPad header says.
- **PRESERVE** all five kept: no change touches the close-pass log, Tag.dodges, the pool rule, the course sizes or
  HINT_MAX.

## Deferred

- Ghost contrast beyond 0.3 / 0.5: needs a real phone screenshot first; Studio draws nothing out of focus today.
- Tutorial finished flag, funnel events: Danzo's calls (tutorial.md §8), trigger 9 for the flag.
