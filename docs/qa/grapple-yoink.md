# QA goals: the grapple yoink (a hook whips the runner along the swing toward the anchor, a little faster)

Branch: `claude/friendly-hawking-74891i` (built in a heavy agent's worktree and merged). Handoff H28, after the grapple
(H25) was signed off by Danzo on 2026-11-07 ("tested and good"). His ask: "have them sort of yoink the player a little
bit in their direction, increasing their velocity a bit". Design: `docs/DESIGN.md` §2 (run builds, the swing releases,
the dash redirects), §3 rules 15-21. System doc: `docs/systems/grapple.md` §2 (the yoink bullet), §4 (trust), §7 (the
knob) and its section "The yoink (H28, 2026-11-07)" (the shapes measured and why this one). Everything in
`docs/qa/grapple-summary.md`'s PRESERVED list must still hold.

The question for this short loop: **does a hook now feel like the rope grabs you and throws you into the swing, a
little faster, without becoming a free dash and without the server trusting anything new?**

## Goals

1. **The whip (the ask).** The first step a hook's rope is taut at its length, the swing gains `GRAPPLE_YOINK` (20
   studs/s) x sin(angle) along the arc toward under the anchor: 14 at 45 degrees out, 10 at 30, none straight under.
   Visible as a snap into the swing the moment the rope bites.
2. **A little faster, not a free dash.** At the swing's fastest: +5 to +7 studs/s in the box world (a walking floor
   hook 10 out 56.9 → 61.8, pinned; a sprinting one 15 out 71.9 → 77.0); +20 at most, never past the 120 cap.
3. **Once a hook.** A slack spell over the top and a second catch get no second yoink (`Rope.bit`).
4. **Floor hooks still swing.** The yoink waits until the floor reel is done (a kick at the bite swept a 45 studs/s
   runner 15 out into the floor and the landing took the rope); the lift-and-swing of H25 is unchanged.
5. **A dead hang stays dead.** Hooked straight under the anchor at rest: no swing appears (x sin(angle) is 0 there).
6. **Nothing new trusted (trigger 3).** `MoveCheck` untouched, `RATE_X` still 120. Five driven 10 s chains re-run:
   never flagged; fastest swing 120.0, overall 147.5, x budget 1.38 of 24 (unchanged); up 2.47 of 10.5, down 2.77 of
   16 (re-pinned from 2.96 and 2.21, S11). A fake swing at 150 is still caught inside a second.
7. **Release, jump and dash off the rope unchanged.** The release keeps the swing x1.1; the dash sets 120 its own way.
8. **Verification.** `npm test` (13 node, 16 Luau suites), `npm run lint:luau` clean; five mutations of the yoink
   (knob 0, the bite before the reel ends, the sign flipped, a second yoink after slack, a flat kick) each fail a
   named assertion. `shared/Grapple.lua` 148 lines, `Config.lua` 200. No remote, no instance-tree change.

## Not seen in Studio by the builder

Another agent held the Studio link while this was built, so the yoink has only been driven in the box world
(`test/luau/grapple.test.luau`, `move_check_grapple.test.luau`). The reviewer's first job is to see it live: a hook at a
walk, a hook at a sprint, a floor hook from the side, a long air chain, and the server Output free of `move:` lines.

## Out of scope

A literal pull toward the anchor (a reel on every hook: measured and dropped, grapple.md "The yoink"); a sound or a
screen shake on the bite; a floor hook at a dash's speed from far to the side losing its rope (found while measuring,
the same with the yoink at 0: the reel cannot lift a runner sweeping that fast along the floor; a later QA round).

## Calls for Danzo (made by the builder; recorded in grapple.md; say if any feels wrong)

- **The shape:** a whip along the swing, not a pull toward the anchor. The "pull" version (reel in every hook) lost
  speed on side hooks: the shorter rope shortens the fall that feeds the swing.
- **The size:** `Config.GRAPPLE_YOINK = 20` studs/s (0 = off). Up for more whip; past ~40 a hook level with the
  anchor (whose whip points straight down) will start to feel like a yank down.
- **A hook behind you at a walk** (only allowed under 0.7 x run) is yanked back toward the anchor a little: the yoink
  points toward the anchor, not "faster whichever way".

## What Danzo should feel (Studio, keyboard, then a phone)

1. Walk under a gold ball and hold **W** from a step or two to the side: after the lift, do you feel the rope
   grab and throw you under the ball? Is it a yoink, or too subtle (raise `GRAPPLE_YOINK`)?
2. Sprint at a ball ahead, jump, hold **W**: the bite should snap you into the swing a little faster than before. Does
   the release fly further? Does it ever feel like a free dash (lower it)?
3. Hook a ball nearly level with you (far out to the side): the whip points down the arc. Natural, or a yank down?
4. Hang still straight under a ball: nothing should move until you push.
5. Chain three anchors with dashes between: does anything feel jerky, or the dash any less of a redirect?
