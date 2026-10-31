# QA goals: the living grapple (hold to hang on marked anchors, release keeps the swing)

Branch: `claude/friendly-hawking-74891i`. Handoff H25 (the build), after PRs 1-5b (signed off by Danzo 2026-11-01:
"all working nicely"). Design: `docs/DESIGN.md` §2 (the kit: "Grapple"; "2. Grapple swing releases you with that
speed. 3. Dash redirects it"), §3 rules 15-21, 29, 37 (notes under rules 15 and 17 say what was built), §4 rows
Grapple Dog, Stickman Hook, Parkour Reborn, SpeedRunners. System doc: `docs/systems/grapple.md` (the design, the maths
and why, trust, the wire, what was seen). Trust: `docs/systems/trust.md` §11. Earlier summaries' PRESERVE lists
(`docs/qa/*-summary.md`) must still hold; the speed check's numbers are unchanged.

The question for this loop: **does the grapple hand speed off to the other moves, is it easy to start and never
floaty, is the aim assist readable, and is the server never fooled?** In practice: does a run feed a swing, the swing
release you fast, and a dash redirect that speed without a loss; does a beginner hook and swing on the first try
(hold W near a gold ball); can you always tell which anchor W will take; and does nothing about the grapple widen
what the server believes (no new rate, no new remote, no client-claimed state the server acts on)? Solo in Studio the
other runners are server-driven dummies (`Config.STUDIO_DUMMIES = 3`); they never grapple.

## Goals

1. **Marked anchors (rules 17, 29).** Six gold neon balls on dark discs on the test map (`Arena.ANCHORS`), distinct
   from every other colour in the game; not solid, not queried (never a floor or wall to the probes, T11), in a
   Persistent model (streaming never drops one); ghost parts can never cover one (`"anchor"` keep-clear boxes).
2. **Aim assist, readable (rule 17).** `Grapple.pick`: at least 4 above you, within 28, inside the screen by 2 (never
   off-screen, both axes), in line of sight; nearest wins, an anchor behind the facing scores +8, the last pick -2 (no
   flicker). A pulsing white halo shows the pick on your screen; none while you hang.
3. **Hold to hang, easy to start (rules 18, 22).** A press buffered 0.1 s (x1.25 on touch) hooks while held; from the
   floor the rope reels you 1 stud clear so you swing, not drag; the stick pumps the swing (from a dead hang, pushing
   with it for 2 s swings 9 studs out on a 12-stud rope).
4. **A rope that swings true (rule 20).** A rope only pulls: slack inside its length, an inelastic catch at it, slack
   again over the top when too slow; the swing keeps its energy (leapfrog in the angle: 0.1% lost over 4 s; the first
   build's position projection lost 86%, grapple.md §3); never faster than 120 (= the dash); no loops (min rope 8).
5. **Release keeps the swing (rules 16, 17; DESIGN §2).** Letting go keeps the swing's own velocity x1.1; a jump off
   the rope gives at least a full jump up and keeps the double jump; a dash off it sets the dash's 120 the way you
   steer ("dash redirects it"); a landing, a hold (trap, ice, crate, tag freeze) or a pad takes the rope with no boost;
   0.2 s cooldown to the next hook.
6. **Refresh on the hook (rule 15, proposed).** A hook gives back dash and double jump (`GRAPPLE_REFRESH`).
7. **Ghosts never grapple (rule 37).** A ghost's grapple input stays its rotate (PR 4); no pick, no halo, no hook.
8. **The server is never fooled (rule 6's spirit, trigger 3).** No new remote; no allowance; `MoveCheck.RATE_X =
   max(DASH_SPEED, GRAPPLE_MAX_SPEED)` = 120 as before. Five driven 10 s swing chains are never flagged (worst budget
   x 1.38 of 24, up 2.41 of 10.5, down 2.67 of 16, pinned); a fake swing at 150 is caught in under a second. The
   anchor byte is drawing only; the server never reads it.
9. **Every screen sees the rope (rule 21).** The snapshot's 14th byte carries the anchor (0 = none); `Others.ropes`
   draws each other runner's rope from its drawn spot; your own from your body. A gold 0.25-stud line from the swing
   pose's raised fist (`runner_fall`, until the art block's hang pose) to the anchor.
10. **The touch button (controls.md).** GRAPPLE shows for the living, lit while an anchor is picked or you hang,
    dimmed otherwise; ROTATE for a ghost holding a piece; hidden for other ghosts.
11. **Cheap every frame (trigger 6).** Per physics step one walk over the anchors and a few rays at most; per render
    frame one part per runner on a rope and the halo. The wire grew by 1 byte.
12. **Verification.** `npm test` (13 node, 15 Luau suites incl. the new `grapple.test.luau` and
    `move_check_grapple.test.luau`; 20 mutations of the grapple rules each caught), `npm run lint:luau` clean, `rojo
    build` passes; the sourcemap only gained `Shared.Grapple` and `Client.Grapple` (ModuleScripts); line ceiling holds
    (`shared/Movement.lua` 357, `client/Client.client.lua` 314).

## Seen by the builder (Studio, 2026-11-01)

Rendering checked first (241 frames/s, viewport 1656 x 606). A floor hook under anchor 1 lifted the runner off the
floor and swung it on a 15.8-stud rope; an airborne chain (run, jump, hook, let go, jump, hook, let go, dash) swung
at up to 110, fell slack inside the circle when it went over the anchor's height, and the dash turned a leftward
release at 86 into +120 right. No `move:` line on the server. On screen: the gold rope from the raised fist to the
anchor, the halo on the pick, the GRAPPLE button lit. As a ghost (the round's fuse ran out on me): no halo, no hook.
No errors. **Noticed:** running past an anchor with none ahead, the hook takes the one behind and swings you back.

## Out of scope

A rope that wraps round corners; the hang/swing pose (the art block); the camera leading into the swing; sounds; rope
sag; anchors per map (PR 6); a grapple remap panel.

## Calls for Danzo (made by the builder; recorded in grapple.md §10; say if any feels wrong)

- **The swing is capped at the dash speed (120)**, so the dash still redirects it and the server's speed check is
  unchanged. Raising it raises the x rate for everyone.
- **A hook behind you is allowed** (nearest wins, ahead preferred by 8 studs). Option: no anchor behind while faster
  than a run.
- **A hook refreshes dash and double jump** (a new rule 15 source). `GRAPPLE_REFRESH = false` turns it off.
- **Jump off the rope** keeps the double jump; **dash off it** gets no release boost.
- **Hold to hang**, not tap: letting go is the release (rule 17, controls.md).
- **Placeholder look**: gold balls, a gold line, a white halo, the fall pose with its raised fist.

## What Danzo should feel (Studio, keyboard, then a phone)

Play a round as a living runner (you start as "it" with 45 s; `Config.STUDIO_DUMMY_TAGS = false` keeps dummies from
tagging you; put it back to `true` before committing).

1. Stand under the far-left gold ball, hold **W**: you lift a stud and hang. Push **D** and **A** in time with the
   swing. Does it get going easily? Too slow, too wild (`GRAPPLE_PUMP`)?
2. Run right, jump, hold **W** as you rise toward the ball over the spawn: let go past the low point. Do you fly out
   fast and far? Does the 1.1 boost feel like a reward (`GRAPPLE_RELEASE_BOOST`)?
3. Swing, let go, **Shift**: the dash turns your swing speed into a dash the way you steer. Does the chain read as
   one move (DESIGN §2)?
4. Swing and press **Space** instead of letting go: a jump off the rope, then a double jump. Natural?
5. Chain anchors left to right across the map without touching the floor. Is the halo always on the ball W will
   take? Ever surprised by which one (or by one behind you)?
6. Swing hard on the longest rope. Does it feel capped at the bottom (`GRAPPLE_MAX_SPEED`)? Ever floaty?
7. Hook from the floor with a ball far to the side: does the reel feel like a yank or a glitch?
8. As a ghost: W turns your piece and never hooks.
9. On a phone: the GRAPPLE button above JUMP, lit when a ball is in reach. Hold it with the thumb while jumping?
