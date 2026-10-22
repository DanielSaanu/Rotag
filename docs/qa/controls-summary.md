# QA summary: controls (PR 3: two keyboard schemes, mouse, pad, four touch buttons, the pry prompt)

Goals: [controls.md](controls.md). Rounds (verbatim, archived): `archive/controls-round1.md`, `archive/controls-round2.md`.
Both reviewers tested in Studio through the MCP (Play, key presses, position sampling, the live GUI, Output).
Loop closed 2026-10-22 at the target in round 2.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | Every binding right and sunk; ITEM touch button sat in the lower-middle on a 667 px phone (rule 23); pad Y / L1 did not count for the pry; the doc promised a "TAP!" flash nobody built |
| 2 | 8/10 | Layout fixed and ITEM's icon seen live (show, use with V, hide); one shared jump-hold flag could cut a mixed-scheme jump short; d-pad movement promised but untested |

## Fixed

**Round 1**
- ITEM moved above DASH, left of GRAPPLE: the four buttons wrap the bottom-right corner; on a 667-wide screen
  nothing sits left of x 455.
- Pad Y and L1 count as pry presses (`PRY_PAD` in the `InputBegan` handler), not bound as actions.
- The trap hint names Z after a scheme-B key (Z / X / C / V / ↑), Space otherwise.
- The hint's device ("touch" / "pad" / "keys") only switches on Touch, Keyboard, Mouse* and Gamepad* inputs; Focus,
  Gyro and the like leave it alone.
- TextScaled with a max of 18 on every touch button (ROTATE fits later).
- controls.md §2: "the trap flashes TAP!" removed; the ITEM row updated.

**Round 2**
- The jump hold is tracked per source (Space, Z, pad A, the JUMP button): releasing one while another is down keeps
  the variable jump. Seen in Play: Z released under a held Space peaked at 15.4, a full Space hold at 15.5, a 40 ms
  tap at 7.0.
- The device switches to keyboard on a key or a click, never on a mouse move or wheel.
- controls.md §2: the pad moves on the left stick; the d-pad is marked untested (Danzo's pad test); the
  click-anywhere Use is noted for a guard with the first clickable UI.

## Preserved (confirmed in both rounds)

- One `BINDS` data table and one bind loop: a remap is a list edit.
- Pass for mouse buttons, Sink for keys and pad: GUI buttons still get clicks; Space and Shift never reach Roblox's
  jump or shift-lock.
- Shift never counts as a pry press and the hint never names it (Sticky Keys).
- Touch and the extra pad buttons are counted once, in `InputBegan`, never on the buttons.
- `Controls.buttons` only writes to the GUI when its inputs change: cheap every frame.

## Deferred

- ITEM's thumb reach (centre about 202 px up on a 375 px phone, 16-18 px gaps): Danzo's phone test decides; the
  fallback is ITEM at about `(1, -150, 1, -150)` with GRAPPLE nudged right.
- A click anywhere fires Use (even on the HUD): no clickable Rotag UI exists yet; guard it with the first one.
- Joystick touches count as pry taps: harmless, noted in items.md §6.
- No "TAP!" flash on the trap: placeholder UI, the art pass owns it.
- `movement.md` at 302 lines: at the limit, not past it; the next session that touches it splits it (G3).

## Open FIX items from the last round

- None unacted. The d-pad item was answered in the doc; the code waits on a real pad.

## What Danzo should feel (keyboard, then the phone preset, then a pad)

1. Scheme A as before: Space jumps, Shift dashes, E uses. Then Z jumps, X dashes, V uses, no menu. Mix them mid-run
   (Space, X, V): all land. Hold Space, tap Z, release Z while Space is still down: the jump keeps its height.
2. Left click uses the held item. Right click, W, C, ↑ do nothing yet and nothing warns.
3. Step on a dummy's trap (`Config.STUDIO_DUMMY_TAGS = false` first, so you are not tag-frozen): the line says
   "TRAPPED: mash Space / click 0/3". Three Space presses, three clicks, or Z Z Z free you early; after a Z the line
   says "mash Z / click". Mashing Shift adds nothing. Nobody has pried by hand yet.
4. Phone preset: at most three buttons at a time (JUMP, DASH, and ITEM once you hold a crate, trap or ice), wrapping
   the bottom-right corner, nothing in the lower-middle, the stick bottom-left. Is ITEM reachable with the thumb? ITEM
   shows the icon and disappears when used; holding a hex shows no ITEM. Three taps anywhere pry (one of them on
   JUMP counts once); the line says "tap anywhere".
5. Pad, if one is to hand: A jump, X or B dash, RB or LT use, RT nothing yet. Does the d-pad move you? Trapped:
   "mash A"; Y counts.
6. The call this PR is for (controls.md §5): W / ↑ as grapple, mouse binds on, pry anywhere. Any key in the wrong
   place is a one-line change in the `BINDS` table at the top of `Controls.lua`.
