# QA round 1: the tag — SCORE 7/10

Reviewer: Opus subagent, 2026-10-11, real Studio Play through the MCP (~90 s), `npm test`, `npm run lint:luau`, a Luau
simulation of dash mashing. Goals: `docs/qa/tag.md`. State reviewed: commit add3c07.

## Report (verbatim)

SCORE: 7/10

I ran a real Studio Play through the MCP (about 90 s, no clicks), plus `npm test` (13 node tests and 5 Luau suites, all ok), `npm run lint:luau` (all ok) and a Luau simulation of mashing dash. I did not modify any tracked files. Play is stopped.

What Play showed, from the Output window:
- `round 1: 2 runner(s), 8061215879 is it with 45s`
- `TAG 8061215879 -> -1000, fuse 43.0s`, then `TAG -1000 -> 8061215879, fuse 45.0s`, then two more pairs at `44.1s` and `45.0s`
- `8061215879's fuse ran out, round over, winner -1000`, then `round 2: 2 runner(s), -1000 is it with 45s`
- `PlayerModule controls not found; running from Humanoid.MoveDirection instead: nil`

On screen, 6 s in, the HUD read `YOU'RE IT 45.0 | +2s -> you | you're it: wait for GO | 1.2`. A later capture shows "YOU'RE IT 40.4" in red at the top centre and a red glowing triangle over the runner, with the lower middle of the screen clear. A held D key moved the runner from x 0 to 71 (the wall), so movement works through the fallback even though `PlayerScripts` contains only `RbxCharacterSounds` and `Client`.

GOALS:
- Server-owned "it" and fuse: met - only `Match.lua` changes the round, through `Tag.lua`. `onClaim` (Match.lua:149-162) reads one integer, rate-limits it, runs `canClaim`, and judges against the server's own history with `claimWindow` (capped at 0.5 s). A refused claim gets no reply.
- Fuse rules: met (as amended) - the pass is `min(left+2, freshFuse)` (Tag.lua:389-397), fresh fuses are 45/35/25 with a floor of 15, and the next holder is chosen by rotation. In Play, round 1 ended and round 2 started with the dummy as it.
- No tag-backs and the start wait: met - TAG_FREEZE is 1.5 s and `fuseLeft` does not burn while frozen (Tag.lua:314). START_FREEZE is 1 s with a big count and GO! (Hud.lua:297-311). Seen live: "wait for GO | 1.2".
- Readable: mostly met - fuse at top centre, red "YOU'RE IT", triangle marker and status line all seen in the capture. But the "+2s" pop is not always true (see FIX).
- Chaser ramp and hit-stop: met in code - `chaserBoost` (5 s delay, +15% over 15 s, reset by `pass`) and HIT_STOP 0.08 on both clients involved (Tagging.lua:287). I did not see the hit-stop with my own eyes.
- Playable solo: partial - tag, tag-back and tag again work round after round (seen in Output). But a dash chain is still much faster than a run: simulated at 3 s, holding right averages 44.4 studs/s and mashing Shift averages 64.5 studs/s (+45%). The goal says that must not happen.
- Pure plus tests and tooling: met - `shared/` passes the purity check, 66 asserts in tag.test.luau, all tests and lint ok, and the Rojo tree only gained three RemoteEvents.

PRESERVE (done well, must survive future iterations):
- The payload is one number and the server judges against its own history (Match.lua:147-162, Tag.touchedBetween): this is rule 6 done properly, and it is cheap.
- The fuse waits while the holder is frozen, through a single `max(since, frozenUntil)` (Tag.lua:315): simple, tested, and the client predicts it the same way.
- Pending claims are re-judged every frame with `canClaim` checked again (Match.lua:105-145): no stale claim can land after the round has moved on.
- The dummy is Studio only, uses CanQuery=false, and claims for itself at rewind 0: an honest solo test bed.
- The big centred countdown, then GO!, replacing the small "frozen" line (fixes H6's "felt stuck").

FIX (done poorly; why it matters; concretely how to fix):
- Dash spam still beats a run: goal 6 / H6 say it should not. Every dash gains about 14 studs over running ((120-45)x0.15 + the 80-to-45 bleed), so no cooldown alone can make a chain "not faster". At 0.8 s it is +45%, and the test (movement.test.luau:173-179) only counts dashes, never speed. -> Danzo has to pick what is intended. Option a: a grounded dash only recharges after the cooldown and a landing from the air. Option b: cut DASH_END_SPEED to RUN_SPEED on the ground. Option c: accept dashing is faster and write a target ratio (for example at most +15%) into DESIGN. Then add a test that pins mash speed against run speed.
- The pass pop is not always true: `Hud.pass` (Hud.lua:286) always prints `+FUSE_PASS_BONUS`, but the cap can make the real gain smaller (seen live: 44.1 -> 45.0 is +0.9, yet it showed "+2s"). Rule 2's readability depends on that number being honest. -> Have `pass` return or send `gained = fuse - left` in TagVerdict, and print `+%.0fs` from it (or "+0, capped").
- A round that ends because someone leaves restarts instantly: `Tag.leave` can set `r.over`, but Match.lua:213 only sets `nextRoundAt` on the `tick` path. The PlayerRemoving handler (Match.lua:251) leaves `nextRoundAt` stale, so the next frame starts a new round with no gap and no "wins the round" screen. -> In PlayerRemoving, `if round.over then nextRoundAt = os.clock() + Config.ROUND_GAP end`.
- Stale docs: docs/systems/README.md:31 still says "remaining + 5" and "+5". -> Update it to +2 capped, or to the `gained` field above.

CONSIDER (fine but could change; why; how):
- The rewind allowance is generous: with TAG_VIEW_DELAY 0.4 plus ping, capped at 0.5 s, the target sample may be 0.5 s old, which is about 22 studs at run speed, on top of a 4-stud box reach. With two real players the victim may see a tag land from well behind. -> Measure with two clients before trusting 0.4, then lower it toward ping + 0.15. The catch-up animation (rule 6) hides the rest.
- A runner who stands still gets ping-ponged: idle at spawn, I was tagged by and passed to the dummy three times in a few seconds, and the cap keeps refilling the fuse to 45. That is fine for real players, but a first-time player sees confusing "+2s -> you" flashes before touching a key. -> Start the dummy's patrol away from spawn, and maybe give the passer 1 s of immunity (rule 1's other option).
- There is no off-screen pointer to the holder: the map is bigger than the screen, so when the box is off-screen you know who is it but not where. -> An edge arrow on the HUD.
- The PlayerModule warning appears on every Play (documented in movement.md §5, but it is noise in Output). -> Downgrade it to a one-time print once the fallback is confirmed as the path in use.

UNCERTAIN (could not verify):
- The touch joystick on the phone preset: with no PlayerModule in PlayerScripts, I could not confirm a thumbstick appears or drives `MoveDirection`. This is the biggest risk for the phone path.
- Danzo's "click once before moving": MCP key injection bypasses window focus, and my injected D moved the runner at once. Studio game-view focus is still the most likely cause, but that is a guess.
- The 80 ms hit-stop and the chaser ramp felt on real hands. Danzo should try: be caught, and check whether the 1.5 s freeze plus GO feels fair. Chase for over 10 s and check whether the boost is noticeable.
- Two real clients: the measured hop delays, the target being up to 0.5 s older, a laggy client, a player leaving mid-tag. All judged from code only.
- Pixel and marker legibility at phone size.

## Builder decisions

- PRESERVE: all five kept. The H7 brief names them so the heavy agent does not regress them.
- FIX dash spam: **Danzo's decision** (a design fork, trigger 1). Asked with a recommendation for option b (on the
  ground the dash ends at run speed; in the air it keeps 80 and dash-into-jump keeps its speed, rule 16). Deferred
  to his answer; the test that pins mash speed against run speed comes with it.
- FIX honest pass pop → H7 (heavy): `TagVerdict` gains `gained`; the HUD prints it. Trigger 3 (a remote payload).
- FIX leave → instant restart → H7 (heavy): `nextRoundAt` set on the leave path too. Trigger 3 (the tag loop).
- FIX stale README "+5" → H7 (the same table row as `gained`).
- CONSIDER rewind allowance: deferred until two real clients exist; the number is a knob (`TAG_VIEW_DELAY`).
- CONSIDER ping-pong at spawn: dummy patrol moved away from spawn (routine, `server/Dummy.lua`). Passer immunity
  deferred: rule 1 picked the freeze (tag.md §3) and Danzo has not played the freeze yet.
- CONSIDER off-screen pointer: DESIGN §2 locks off-screen arrows; built with the second player, who needs them too.
- CONSIDER PlayerModule warning: downgraded to a one-time print (routine, `client/Controls.lua`).
- UNCERTAIN touch joystick: open; added to Danzo's phone checklist. The rest is for his hands.
