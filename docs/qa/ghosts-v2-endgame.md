# QA goals: ghosts v2 endgame (the ignition, the burn-out, end-phase speed)

Branch: `claude/friendly-hawking-74891i`. Handoff H23 (the build), PR 5 of `docs/systems/ghosts-v2-proposal.md` §12,
after PRs 1-4 (built, QA'd to 8/10). Design: `docs/DESIGN.md` §3 rules 2 (make the fuse readable), 3 (force an ending),
50 (ignition), 51 (end-phase speed); 46 (max(ramp, grant)) which the end phase stacks on. System doc:
`docs/systems/endgame.md` (new for this PR); the fuse and the round stay in `tag.md` (its new §10 points here).

The question for this loop: **can every player see the holder's fuse running out (a growing ember glow on the holder,
a reddening, beating readout) and see the burn-out where it happened; does the end phase come on at the final two (or
past 2:00) and speed every living runner by 10% on top of the ramp and the grant, decided by the server alone, without
the speed check ever flagging an honest runner?** Solo in Studio the other runners are server-driven boxes
(`Config.STUDIO_DUMMIES = 3`); they ignore speed multipliers, so the end-phase speed is felt only on the player.

## Goals

1. **The end phase (rule 51).** `Tag.endPhase`: on once two are left alive in a round that began with 3+ (a leave
   counts), or once the round has run `END_PHASE_AFTER` (120 s); sticky; off in a round that is over. A round that
   started with two is normal until the time cap. Tested in `tag.test.luau` (count, time, sticky, a leave, a duel).
2. **The server decides it (rule 6, trigger 3).** `MatchState.endPhase` is set from `Tag.endPhase` on the server's
   clock, sent at once on a flip; Studio logs `END PHASE: n alive, Ns into the round`. Clients only read it; an absent
   or malformed field reads as off. No new remote; nothing new trusted from a client.
3. **The speed (rule 51 + 46).** Every living runner's run top x 1.1, with max(ramp, grant) on top, never the two
   stacked; ghosts unaffected; the dash unscaled. Top: 56.925 studs/s (pinned).
4. **The speed check never flags it (trust.md §8).** `MoveCheck` unchanged, proven by driving at the top multiplier for
   10 s: the fastest dash-jump chain (burst 1.38 of 24 studs, the plain chain's, pinned as a measurement), a held run,
   the pad chain. `config.test` asserts the fastest end-phase run stays under the dash rate.
5. **The ignition (rules 2, 50).** From 10 s left, the holder (on every screen) gets an ember rim that grows (1.08 ->
   1.25) and flickers faster, embers (0 -> 60 a second) and a glow light on the floor and walls (range 6 -> 16).
   Rim priority: freeze cyan > ember > grant orange. `Tag.ignition` (0..1, linear) is pure and tested.
6. **The readout (rule 2).** Under 10 s, on every screen, the fuse readout reddens toward hot yellow on the beat,
   swells up to 1.35x and beats 2 -> 8 times a second.
7. **The burn-out (rule 50).** When the holder's fuse runs out, every screen plays a burst (a swelling orange ball and
   sparks) where that runner stood, including the round's last burn-out; a holder who leaves gets none.
8. **Readable end phase.** A line under the status line, `FINAL TWO: everyone +10% speed` (or `OVERTIME: ...` at the
   time cap with 3+ alive), flashing for its first 2.5 s, gone when the round ends.
9. **Cheap every frame (trigger 6).** One compare per runner when nothing changes; emitter and light built once per
   Look; one emitter live at a time (the holder).
10. **Verification.** `npm test`, `npm run lint:luau`, `rojo build` pass; the Rojo tree only gained
    `StarterPlayerScripts.Client.Ignition` (ModuleScript); no new remote; line ceiling holds (`server/Match.lua` 387).

## Seen by the builder (Studio, 2026-10-31)

Ember rate 6 -> 54 as my fuse ran 9 -> 1; readout 32 -> 41 px; `burn-out` lines at each runner's spot (6 in two rounds);
`END PHASE: 2 alive, 83s into the round`; the FINAL TWO line on, then gone in the next round. A capture at 1.0 s left
showed a red glow pool and a bright core on the holder (the first capture, before the light and bigger embers, showed
almost nothing at play zoom: fixed in the build). The burst seen by calling `Ignition.burst` at my spot. No errors.
NOT seen: the end-phase speed under a hand, the 120 s time-cap flip in Play, a second client's view, an ignition on a
dummy captured on screen (its emitter rate was logged rising to 52).

## Out of scope

Rule 3's map shrink (PR 6, maps); the ignition art on the sheet (a later routine block, behind `Sprites.Has`;
ignitions are the first cosmetic slot, §6.5); bots speeding up; a countdown to the time cap; sounds (the "beeps" of
rule 2 are drawn as the readout's beat for now).

## Calls for Danzo (made by the builder while he was away; recorded in endgame.md; say if any feels wrong)

- **`END_PHASE_AFTER` = 120 s** (the proposal guessed 150). The final two normally come first (~83-100 s); the cap
  only catches a round passes keep alive, which then ends near 3:00 instead of 3:30. Fallback: 150.
- **"The final two" means a round that began with 3+.** A round that starts with two runners is a normal fuse until
  the time cap (rule 51: "never during a normal fuse"). DESIGN rule 51's line now says so.
- **`MoveCheck` was NOT scaled** by `END_PHASE_SPEED` (the proposal said it would be): its x rate is the dash, which
  the end phase never touches; the tests drive it. A cheat faking the end phase gains nothing it could not already.
- **The look is placeholder:** ember rim + stock particle embers + a light that glows on the map; a neon ball and
  sparks for the burn-out. The light was added after the first capture read as nothing.
- **The HUD's end-phase line** says FINAL TWO or OVERTIME and "+10% speed".
- **Ghosts and the Studio dummies** do not get the end-phase speed (rule 51: "living"; dummies ignore multipliers).

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard)

Set `Config.STUDIO_DUMMY_TAGS = false` first so the dummies cannot tag you back at the cap; put it back to `true`
before committing.

1. Round start, you are it: stand still. At 10.0 the readout turns red and starts to beat; you get a red-orange rim,
   embers and a red glow on the floor and wall; all of it grows and quickens to 0. Is it readable without the HUD?
   Too much? Too little?
2. At 0: an orange burst where you stood; you are a ghost. Watch the next holder (a dummy) ignite the same way at 10.
3. After the second burn-out: the `FINAL TWO: everyone +10% speed` line flashes in. (As a ghost you are not faster.)
4. Next round, run instead of standing: get to the final two still alive (dummies burn out on their own). Then run
   flat out, with and without the ramp (as it, after ~5 s of chase): you should feel faster than before the line came
   on. Is +10% noticeable? Should the end phase also shorten the fuse or shrink the map sooner (PR 6)?
5. Does a 2:00 cap feel right, or should a long round be left alone until 2:30 (150)?
6. Two-player, if there is a second keyboard: the other screen sees your ignition and your burn-out burst at the
   same spot.
