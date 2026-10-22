# QA round 1: controls — SCORE 7/10

Reviewer: Opus subagent, 2026-10-22, tested in Studio through the MCP (Play, key presses, position sampling, Output).

## Report (verbatim)

SCORE: 7/10

I watched it run in Studio for real. Play started and the key presses were sent through the MCP tool. Over 13 s I sampled the root part's position and velocity, and I read the Output window. Play is stopped. `npm test`: 13 pass, 0 fail. `npm run lint:luau`: every file ok. `Controls.lua` is exactly 254 lines. The diff adds no new instances and does not touch `shared/`, the remotes or the server.

**What I saw in Play**
- **Bindings.** `GetAllBoundActionInfo` shows `Rotagjump` / `Rotagdash` / `Rotaggrapple` / `Rotaguse` at priority 3000, with exactly the keys in the table.
- **Jumps.** Z at 5.25 s: vy 52.5, peak y 9.6. Space at 6.85 s: the same jump.
- **Dashes.** X at 8.46 s: vx 120, x moved from -60 to -40.4. LeftShift at 9.76 s: vx 120 again.
- **Grapple keys.** W held for 0.8 s, ↑ held for 0.8 s, and C pressed: the body did not move and nothing appeared in Output.
- **Sinking.** Every key reached `UserInputService.InputBegan` with `gp=true`, so it was sunk.
- **Output.** Nothing new. The `ContentId 203785492` failure does not come from repo code (grep finds nothing).
- **Touch layout.** On the 785x597 viewport, with the touch GUI forced on for a screenshot: Jump 96 at (680,422), Dash 76 at (588,394), Grapple 76 at (690,330), Item 76 at (496,426). "GRAPPLE" fits the button.
- **Item icons.** `Sprites.Has` is true for `crate_0`, `trap_armed` and `ice_icon`.

GOALS:
- 1 Both keyboard schemes: met. Bindings at 3000 (`Controls.lua:20-25`). Z, Space, X and Shift moved the body as expected and were sunk (`gp=true`). Nothing in the table is a Roblox reserved key.
- 2 Mouse: met (code only). MouseButton1 → use, MouseButton2 → grapple, both returning Pass (`:27`, `:74`). I did not click in Play.
- 3 Pad: met (code only). A / X / B / R2 / R1 / L2 are bound; Start and Select are not. No pad was to hand.
- 4 Grapple has no visible effect yet: met. W, ↑ and C were inert and Output stayed clean. `read` hands out `grapplePressed` and `grappleHeld` (`:247-250`).
- 5 Touch arc: partial. Sizes, hiding and icons are right (`:139-190`, Client `:220`). ITEM at `UDim2.new(1,-228,1,-40)` covers x = W-304 to W-228. On a 667-wide phone that is x 363 to 439, past the screen's centre line (333), so it sits in the lower-middle that rule 23 keeps clear.
- 6 Pry: partial. The counting matches the table, and a tap on a button counts once (`:78-80`). Two gaps:
  - Pad Y, L1 and the d-pad are unbound, so they do not count, although the goal says "any face button or trigger".
  - controls.md §2 promises the trap "flashes TAP!", and nothing in `roblox/src` does this.
  - The hint text by device is right (`:220-225`), but I did not get trapped in Play to see it on screen.
- 7 Nothing regressed: met. Space, Shift, E and click behave as before, the presses are still latched and cleared once (`:250`), and a thumb sliding off a button still releases it (`:124`). `Use.frame` still blocks firing an item while held.
- 8 Clean: met. Tests and lint pass, no new instances, the line ceiling holds, and `BINDS` is pure data.

PRESERVE (done well, must survive future iterations):
- The `BINDS` data table and the single loop that binds it (`Controls.lua:20-25`, `:63-76`): a remap is a list edit, as the PR promises.
- Pass for mouse buttons, Sink for keys and pad (`:27`, `:74`): GUI buttons still get clicks, while Space and Shift never reach Roblox's jump or shift-lock.
- Shift does not count toward the pry (`:70`), so mashing it never brings up Sticky Keys. The hint never says Shift.
- Touch counted in one place (`:78-80`), not in the buttons, so a tap on a button cannot count twice.
- `Controls.buttons` only touches the GUI when the values change (`:165-190`), so calling it every frame from Client is cheap.

FIX (done poorly; why it matters; concretely how to fix):
- ITEM sits in the lower-middle on small phones. Why: it breaks DESIGN rule 23, and on a 667-wide screen its centre is about 70 px right of the screen's centre. It is also the farthest reach from the thumb, below DASH, so it reads as a row rather than an arc. -> Move it above DASH and left of GRAPPLE, at about `UDim2.new(1,-128,1,-164)`, so the four buttons wrap the corner. Then check that on the 667x375 preset nothing sits left of x ≈ 445.
- Pad Y (and L1) do not count toward the pry. Why: the goal and the table say "any face button or trigger", and a pad player mashing Y gets 0/3 for no visible reason. -> Count pad buttons the way touch is counted: in the `UserInputService.InputBegan` handler, add a check for `input.UserInputType.Name:sub(1,7) == "Gamepad"` with a KeyCode in {ButtonY, ButtonL1}. Do not bind them as actions.
- The doc promises a flash that does not exist (controls.md §2 pry row: "the trap flashes TAP!"). Why: the doc is the memory, and the next session will believe it is built. -> Delete the words, or build the flash.

CONSIDER (fine but could change; why; how):
- A scheme-B player is told "mash Space / click" even though they use Z. -> Keep the key that last fired a bound action and name that one in the hint (Space for scheme A, Z for scheme B), falling back to "Space / click".
- `usingTouch` flips to false whenever another input type arrives (`:215`). Possibly the phone's Focus or Gyro events count, but that is a guess. If so, the hint on a phone briefly says "mash Space / click". -> Only change `usingTouch` for keyboard, mouse-button and gamepad input types.
- Touch presses include joystick touches and the Roblox top-bar button. This is harmless, but it makes "3 taps" easier than it reads. Leave it, and note it in items.md §6.
- "GRAPPLE" at TextSize 18 just fits 76 px. `TextScaled` with a max size would protect it from the longer "ROTATE"-style labels to come.

UNCERTAIN (could not verify):
- Whether sinking W and ↑ at 3000 beats PlayerModule's move-forward binding in a published game. This Studio has no PlayerModule ("no PlayerModule controls; reading Humanoid.MoveDirection"). It is moot for the move maths, which reads only X.
- Mouse clicks, pad input and real touch, including the trap prompt text on screen. I was not trapped during Play. Danzo should step on a trap and try Space, Z, a click and a Shift mash, then on the phone preset tap three times anywhere and tap the JUMP button.
- The ITEM icon showing and then hiding after use: no item was held during my session.
- Feel. Danzo should mix Space, X and V mid-run, check the W-to-grapple reach while holding D, and judge on a real phone whether ITEM is reachable with the thumb.

## Builder decisions

- **PRESERVE**: all five kept (the `BINDS` table and one bind loop, Pass for mouse / Sink for keys and pad, Shift never a pry press, touch counted once in `InputBegan`, `Controls.buttons` cheap).
- **FIX, ITEM in the lower-middle**: done. ITEM now at `UDim2.new(1, -128, 1, -164)`, above DASH and left of GRAPPLE, so the four buttons wrap the corner (2x2). On a 667-wide screen its left edge is at x 463. controls.md §2 row updated ("above DASH, left of GRAPPLE"; rule 23 outranks the first guess "left of DASH").
- **FIX, pad Y and L1 count for the pry**: done, in the `InputBegan` handler (`PRY_PAD`), not bound as actions. The d-pad is steering and stays out, like A / D.
- **FIX, "the trap flashes TAP!"**: the words are deleted from controls.md §2; the status line already says "tap anywhere" (Hud). No flash built (placeholder UI; the art pass owns it).
- **CONSIDER, hint names the scheme's key**: done. A keyboard press on Z / X / C / V / ↑ marks scheme B; the hint then says "mash Z / click", else "mash Space / click".
- **CONSIDER, `usingTouch` flips on stray input types**: done. The device is only switched on Touch, Keyboard, Mouse* and Gamepad* input types; Focus, Gyro and the rest leave it alone.
- **CONSIDER, joystick touches count as taps**: left as is, noted in items.md §6.
- **CONSIDER, TextScaled**: done, `TextScaled` with a `UITextSizeConstraint` max of 18 on every touch button.
