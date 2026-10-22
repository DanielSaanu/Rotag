# QA round 2: controls — SCORE 8/10 (target met)

Reviewer: Opus subagent, 2026-10-22, tested in Studio through the MCP (two Play runs, key presses, position sampling,
live GUI, Output).

## Report (verbatim)

SCORE: 8/10

**What I did.** I ran Studio Play through the MCP twice and stopped it both times. I pressed keys, sampled the root part's position, read the live GUI and read Output.

**Tests and files.**
- `npm test`: 13 pass, 0 fail.
- `npm run lint:luau`: all files ok, including Controls, Hud and Client.client.
- `Controls.lua` is 267 lines.
- No change to `default.project.json`, `shared/` or the server.
- The live bindings are `Rotagjump`, `Rotagdash`, `Rotaggrapple` and `Rotaguse`, all at priority 3000.

**What I saw in Play.**
- **Holding W, then ↑, then pressing C:** the body did not move (z stayed 0), and Output showed nothing new.
- **Jumps:** Z at 7241.13 went to y 8.5 and back to 1.8. Space at 7243.74 gave the same jump.
- **Dashes:** X moved x from -60 to -40.4. LeftShift moved it from -40.4 to -20.8.
- **Sinking:** every key reached `UserInputService.InputBegan` with `gp=true`.
- **Items:** in Play 2 I walked onto living orb 6. The HUD showed "ITEM: CRATE". The Item button became visible with no text and an icon from the sheet (rbxassetid://77103575308502, rect 775,259 / 96x96). Pressing V gave "[Rotag] items: 8061215879 used crate at (-73.2, 1.8) facing -1", and the button was hidden again.
- **Live layout on the 785x597 viewport:** Jump 96 at (680,422), Dash 76 at (588,394), Grapple 76 at (690,330, hidden), Item 76 at (596,302).
- **Output:** the only non-[Rotag] lines are `ContentId: rbxassetid://203785492 failed`, and that id is not in the repo.
- **Not tested:** I was never trapped. The dummies placed no trap before my fuse made me a ghost.

GOALS:
- 1 Both keyboard schemes: met - `BINDS` (`Controls.lua:20-25`) is live at priority 3000. Z/Space jumped, X/Shift dashed, W/↑/C were inert, and every key arrived with `gp=true`.
- 2 Mouse: partial - from code only: MouseButton1 is use and MouseButton2 is grapple, both return Pass (`:27`, `:79`). I did not click in Play.
- 3 Pad: partial - from code only: A / X / B / R2 / R1 / L2 are bound, and Start and Select are not. No pad was available.
- 4 Grapple has no effect yet: met - W, ↑ and C did nothing and raised nothing. `read` hands out `grapplePressed`/`grappleHeld` (`:261-262`) and nothing reads them.
- 5 Touch arc: met - the sizes are 96 and 76.
  - Worked out for a 667x375 screen: Item x 463..539, y 135..211; Dash x 455..531; Grapple x 557..633; Jump x 547..643. All of them sit right of the middle third, which ends at 444.
  - Item showing, its icon and hiding after use were all confirmed live.
- 6 Pry: partial - the counting is right in code.
  - Bound keys except Shift count (`:73`). Touch, Y and L1 are counted once in `InputBegan` (`:82-84`). `pryHint` (`:221-225`) feeds Hud `:225`.
  - Not seen on screen: I was never trapped.
- 7 Nothing regressed: met - Space, Shift and E (via V, same `use` row) behaved as before.
  - Presses are latched and cleared once (`:265`), and the release when a thumb slides off a button is unchanged (`:130`).
  - The device switch (`:207-213`) narrows the old blanket `usingTouch = t == Touch`, which helps `TOUCH_WINDOW_SCALE`.
- 8 Clean: met - tests and lint pass, no new instances, the line ceiling holds, and `BINDS` is pure data.

PRESERVE (done well, must survive future iterations):
- **One `BINDS` table and one bind loop (`:20-25`, `:66-80`):** a remap stays a list edit.
- **Pass for mouse, Sink for keys and pad:** clicks still reach GUI buttons, and Space and Shift never reach Roblox's jump or shift-lock.
- **Touch and the extra pad buttons are counted in one `InputBegan` handler, never on the buttons themselves:** a tap on JUMP counts exactly once.
- **The hint never says Shift, and Shift never counts as a pry press:** this is the Sticky Keys guard.
- **`Controls.buttons` only writes to the GUI when its inputs change:** it is cheap to call every frame from Client `:220`.
- **The device only switches on real input types (Touch, Keyboard, Mouse*, Gamepad*):** stray events such as Focus or Gyro no longer flip the touch flag.

FIX (done poorly; why it matters; concretely how to fix):
- **controls.md §2 promises a d-pad that probably does not move you.** Why: §2 says "left stick or d-pad". Roblox's stock gamepad module normally leaves the d-pad to GUI navigation, and nothing in our code moves on the d-pad. Mild confidence: I could not test with a pad. -> Have Danzo press the d-pad on a pad in Play. If the runner doesn't move, either change the doc to "left stick" or add a d-pad term in `moveX`.

CONSIDER (fine but could change; why; how):
- **Shared jump hold:** `jumpHeld` is one flag shared by Space, Z, ButtonA and the JUMP button. Releasing one while another is held cuts the variable jump short. It is rare, but it hits players who mix schemes. -> Count the held inputs (`jumpDown += 1/-1`), or track hold per KeyCode.
- **ITEM's reach:** its centre sits about 202 px up from the bottom, more than half the height of a 375 px landscape phone. It is clear of the lower-middle, but it may be a stretch for the thumb. The gaps between buttons are only 16-18 px, so mis-taps are possible. -> Danzo's phone test decides. A fallback is ITEM at about `(1,-150,1,-150)` with GRAPPLE nudged right.
- **Left click uses the held item anywhere:** a click anywhere fires Use outside a trap, including a misclick on our own HUD (Pass doesn't stop the action from firing). That is fine for now, but watch it once there is clickable UI. -> Ignore MouseButton1 when `GuiService.MenuIsOpen` is true or the click lands on a Rotag GUI (`PlayerGui:GetGuiObjectsAtPosition`).
- **The pry hint flips to keyboard on any mouse move:** a pad player who touches the mouse sees "mash Space / click" (because of `string.sub(name,1,5)=="Mouse"`). -> Switch the device on MouseButton* only, not on MouseMovement or MouseWheel.
- **movement.md is 302 lines (CLAUDE.md caps docs at about 300):** this PR touched it. -> Split it to the `docs/systems/` hub model soon.

UNCERTAIN (could not verify):
- **The trap line on screen:** I never saw it. Danzo should step on a dummy's trap and check four things:
  - Space ×3 frees him, and the line shows "mash Space / click".
  - After a Z press it shows "mash Z / click".
  - A Shift mash adds 0.
  - On the phone preset, 3 taps (one of them on JUMP) free him, and the line shows "tap anywhere".
- **Mouse clicks, real pad input and real touch:** none were exercised. That includes whether a touch tap on a phone also fires a MouseButton1 action through ContextActionService. I believe it does not. If it did, every tap would also Use the held item.
- **Sinking W/↑ against Roblox's own movement script (PlayerModule) in a published game:** this Studio has none ("no PlayerModule controls; reading Humanoid.MoveDirection"). It is moot for the movement maths, which reads only X.
- **The ITEM and GRAPPLE spacing on a real phone, and which hand feels better:**
  - On a phone, check the thumb reach to ITEM.
  - On a keyboard, mix Space with X and V mid-run, then Z with X and V.
  - Check W for grapple while holding D.

## Builder decisions

- **PRESERVE**: all six kept.
- **FIX, the d-pad promise**: controls.md §2 now says "left stick (d-pad untested: Danzo's pad test; a d-pad term in
  `moveX` if he wants it)". No code: nobody has a pad to verify against, and a blind d-pad term could double-steer.
- **CONSIDER, shared jump hold**: done. The jump hold is tracked per source (each key, pad button or the JUMP button);
  `jumpHeld` is true while any source is down, and a press is latched only when the first source goes down. Mixing
  Space and Z no longer cuts a variable jump short.
- **CONSIDER, hint flips on a mouse move**: done. The device switches to "keys" on Keyboard and MouseButton* only;
  MouseMovement and MouseWheel leave it alone.
- **CONSIDER, ITEM's reach**: deferred. Danzo's phone test decides; the fallback position is in the report.
- **CONSIDER, a click anywhere Uses**: deferred. There is no clickable Rotag UI yet; the guard goes in with the first
  one (noted in controls.md §2).
- **CONSIDER, movement.md at 302 lines**: deferred. It is at the limit, not past it; the next session that touches it
  splits it to the hub model (CLAUDE.md, G3).
