# QA goals: controls (the full table: two keyboard schemes, mouse, pad, four touch buttons, the pry prompt)

Branch: `claude/friendly-hawking-74891i`. PR 3 of `docs/systems/ghosts-v2-proposal.md` §12, built by the routine session
(no handoff: the proposal says "trigger: none if the table is followed"). The table and every reason behind a binding:
`docs/systems/controls.md` (H17, provisional default: Danzo was "unsure", so the recommended answers stand and he judges
by hand). Bounds: `docs/DESIGN.md` §3 rules 20-24 (never floaty, 4 touch buttons at most, lower-middle clear, over
44 px, read the mobile joystick). Code: `roblox/src/client/Controls.lua` (the whole PR), one line in `client/Hud.lua`
(the trap prompt names the device's pry input), four lines in `client/Client.client.lua` (which optional touch buttons
show). Nothing in `shared/`, no remote, no server change.

The question for this loop: **does every row of the controls table work as written, on keyboard A and B at the same
time, on the mouse, on a pad and on the phone preset; do the touch buttons sit where the table says, big enough and
out of the lower-middle; does the pry still count the right presses and tell the player the right thing to mash; and
did nothing that worked before (Space / Shift / E / click, the old two buttons, the pry) break?**

## Goals

1. **Both keyboard schemes live at once (controls.md §2, §3).** A: Space jump, Left/Right Shift dash, W grapple, E use.
   B: Z jump, X dash, C grapple, ↑ grapple, V use. No key is shared; no menu. All at High priority with Sink, so
   Space never reaches Roblox's jump, Shift never shift-lock, W and ↑ never walk the character into the screen.
   Never bound: Esc, `/`, Tab, F9, the backtick.
2. **Mouse.** Left click = use (passes on, so GUI buttons still see it); right click = grapple (held).
3. **Pad.** A jump; X and B dash; RT (R2) grapple, held; RB (R1) and LT (L2) use. Start and Select untouched.
4. **Grapple input exists, nothing consumes it yet.** `Controls.read` hands out `grapplePressed` / `grappleHeld`;
   the living grapple is its own movement PR, a ghost's rotate is PR 4. Pressing W / C / ↑ / right click / RT does
   nothing visible and raises nothing.
5. **Touch: four buttons in an arc around the right thumb (rules 22-23).** JUMP 96 px in the bottom-right corner, DASH
   76 px up and to its left, GRAPPLE 76 px above JUMP (reads ROTATE for a ghost holding a piece), ITEM 76 px left of
   DASH. All over 44 px, none in the lower-middle, the thumbstick bottom-left untouched. GRAPPLE is hidden until the
   grapple exists; ITEM shows only while the slot holds an item Use can fire (hidden when empty, hidden for a hex,
   which is used by touch), with the item's icon from the sheet when the sheet has one, else its name.
6. **The pry (items.md §6, controls.md §2 pry row).** Three presses still free a trap: any bound action key (Space, E,
   W, Z, X, C, V), any click, any pad face button or trigger, or three taps anywhere on touch (a tap on a button counts
   once, never twice). Shift and the steering keys do not count. The trap line names the device last used: "mash
   Space / click" on keyboard and mouse, "mash A" on a pad, "tap anywhere" on touch. Never Shift (Sticky Keys).
7. **Nothing regressed.** Space / Shift / E / click / the JUMP and DASH buttons behave as before PR 3; presses are still
   latched between frames (a tap shorter than a frame is never lost) and handed out once; a thumb sliding off a touch
   button still releases it; `Config.TRAP_PRESSES` still frees on the third press.
8. **Clean.** `npm test`, `npm run lint:luau` pass; the Rojo tree is unchanged (no new instances); the line ceiling
   holds (`Controls.lua` 254). The bindings are one data table at the top of `Controls.lua`, so a later remap edits
   lists, not code (remapping itself and its saved data are out of scope: trigger 9 when they come).

## Out of scope

The living grapple (its own PR); the ghost's piece and rotate, boost pads, placement (PR 4); ignition and end-phase
speed (PR 5); maps (PR 6); a remap settings panel and saving it (trigger 9); a "move buttons" touch option (after
Danzo's phone test); the art of the buttons (placeholder UI); the alternatives in controls.md §4 (decided, not
rebuilt); Roblox's own keys.

## What Danzo should feel (Studio, keyboard first, then the phone preset, then a pad if one is to hand)

1. Scheme A as before: Space jumps, Shift dashes, E uses. Then without touching a menu: Z jumps, X dashes, V uses.
   Mix them mid-run (Space then X then V): all land.
2. Left click uses the held item. Right click, W, C, ↑ do nothing yet (the grapple is a later PR) and nothing warns.
3. Step on a dummy's trap (`Config.STUDIO_DUMMY_TAGS = false` so you are not tag-frozen): the line says "TRAPPED:
   mash Space / click 0/3"; three Space presses, or three clicks, or Z Z Z, free you early. Mash Shift: it does not
   count (the prompt never asked for it).
4. Phone preset: three buttons at most at any time (JUMP, DASH, and ITEM once you hold a crate, trap or ice), in an arc
   around the right thumb, nothing in the lower-middle, the stick bottom-left. ITEM shows the item's icon and
   disappears once used; holding a hex as a ghost shows no ITEM (touch the holder instead). Tap anywhere three times
   to pry; the line says "tap anywhere".
5. Pad, if you have one: A jump, X or B dash, RB or LT use, RT does nothing yet. Trapped: "mash A".
6. The call this PR is for: do W / ↑ as grapple, mouse binds on, and pry-anywhere feel right (controls.md §5)? Say
   if any key is in the wrong place; a remap is a one-line change in the table at the top of `Controls.lua`.
