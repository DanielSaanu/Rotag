# Controls: keyboard, mouse, controller and touch (H17)

**Created:** 2026-10-19 by the heavy agent (handoff H17). **Status: PROVISIONAL DEFAULT, adopted 2026-10-19.** Danzo was
"unsure", so the §2 table stands as the default with the recommended answers (W / ↑ = grapple, mouse binds on, pry
with 3 taps anywhere), to be judged by hand once built; every verb is remappable anyway. Build: PR 3 of the order in
[ghosts-v2-proposal.md](ghosts-v2-proposal.md) §12. Nothing is built yet:
`roblox/src/client/Controls.lua` is unchanged (today: Space / ButtonA jump, Shift / ButtonX dash, two touch buttons;
[movement.md](movement.md) §5). Bounds: DESIGN §3 rules 20-24 (never floaty, 4 touch buttons at most, lower-middle
clear, read the mobile joystick). The verb list is H16's, adopted (DESIGN §3 rules 37-51,
[ghosts-v2-proposal.md](ghosts-v2-proposal.md)); if those verbs change, only rows change here.

## 1. The verbs

| Verb | Who | How it is pressed | How often |
|---|---|---|---|
| Move left / right | all | held | always |
| Jump (double and wall jump share it, rule 22) | all | press; held for height (rule 14) | constantly |
| Dash | all | press | every second or two |
| Grapple | living | hold to hang, release to let go (rule 17: release keeps the swing) | often, mid-air, with jump |
| Use item (fire or place) | all | press | every 10 s or so |
| Rotate piece | ghosts, while holding a fixture or pad | press; **on the grapple input** (ghosts have no grapple) | rarely |
| Pry the trap | whoever is trapped | 3 presses of any action input, or clicks / taps | rarely |
| Down | — | unbound, kept for a drop-through or fast-fall later | — |

Five live inputs at most for any one role (move, jump, dash, grapple-or-rotate, use), so rule 22's four touch
buttons hold: the ghost's rotate reuses the living's grapple slot.

## 2. The layout (recommended)

Both keyboard schemes are **live at the same time** (no menu choice): they share no key. Scheme A is "left hand
moves" (WASD, the Roblox habit, mouse optional); scheme B is "right hand moves" (arrows, the classic platformer
habit, ZXCV under the left hand). That pair is also the left/right-hand variant.

| Verb | Keyboard A: WASD (+ mouse) | Keyboard B: arrows + ZXCV | Controller (Xbox / PlayStation) | Touch |
|---|---|---|---|---|
| Move | A / D | ← / → | left stick or d-pad | Roblox's thumbstick, bottom-left |
| Jump | **Space** (kept) | **Z** | **A / Cross** (kept) | JUMP, 96 px, bottom-right corner (kept) |
| Dash | **Left/Right Shift** (kept) | **X** | **X / Square** (kept), B / Circle too | DASH, 76 px, up-left of JUMP (kept) |
| Grapple (ghost: rotate) | **W**, or right mouse button | **C**, or ↑ | **RT / R2** (hold) | GRAPPLE, 76 px, above JUMP; ROTATE for a ghost holding a piece, hidden otherwise |
| Use item | **E**, or left mouse button | **V** | **RB / R1**, LT / L2 too | ITEM, 76 px, left of DASH, shows the held item's icon; hidden when the slot is empty |
| Pry the trap | Space / E / W or clicks, 3 times | Z / X / C / V, 3 times | any face button or trigger, 3 times | 3 taps anywhere (the trap flashes "TAP!") |
| Down (reserved) | S | ↓ | stick down | — |

**Never bound by us:** Esc (Roblox menu), `/` (chat), Tab (player list), F9 (console), the backtick (backpack);
Start and Select on a pad (Roblox's menus; not verified against a Roblox page, check when building).

**Remappable (when built):** every game verb on keyboard and pad, in a small settings panel, saved per player (a
saved-data change: trigger 9 at that point). Roblox's own keys above are not ours to move. Touch buttons: a later
"move buttons" option (Danzo's phone test first).

## 3. Why each binding (the reasons, so a later session does not move one without a new one)

- **Space jump, Shift dash stay.** Space is jump in every Roblox game (a beginner's guide lists it with WASD as the
  defaults) and Dead Cells uses Space jump with Shift for its roll, the same split. Moving them would fight habit
  for no gain. They are already bound at High priority with Sink so Roblox's jump and shift-lock never fire.
- **W for grapple in scheme A.** With A and D under the ring and index fingers, the middle finger rests on W, and W
  does nothing in a side-on game. Grapple anchors sit above you, so "up hooks up"; one SpeedRunners player's default-
  style setup used Up for grapple. Thumb jumps, pinky dashes, middle grapples: four verbs on four fingers, none of
  them the fingers that steer. E (use item) is the middle finger's next key and Roblox's own "interact" key (its
  proximity prompts use E). The mouse is a second home: left click uses, right click grapples, for players who rest
  a hand on it.
- **Scheme B is Z jump, X dash.** Z jump is Silksong's and SpeedRunners 2's default; X dash is Celeste's. C and V
  continue the row (SpeedRunners 2 puts grapple and item on X and C; we keep X for the dash, the more frequent verb,
  and slide grapple and item one key right). ↑ also grapples, matching W.
- **Not Space with the arrows.** Cheap membrane keyboards jam some three-key combinations; Phaser's maintainers
  confirmed "Space plus left and up failed" on one board while Space plus WASD worked. Scheme B keeps its actions on
  Z-V, away from that combination; scheme A's Space sits with WASD, the combination that worked.
- **Never mash Shift.** Windows offers Sticky Keys after five Shift presses and minimises the game, so the trap prompt
  names Space / click, never Shift.
- **Pad: A jump, X dash stay;** Celeste's defaults are A jump and X dash (B also dashes there, so B dashes here too).
  Roblox's own guidance: A for jumping, B for "dodge, roll or sprint", triggers for primary actions. **RT grapple**
  because the grapple is held while the thumb jumps: only a trigger lets you hold one and press A at the same time
  (Celeste puts its held grab on a trigger or shoulder; Silksong its harpoon on a trigger). **RB use item** for the
  same reason (fire while jumping), with LT as a twin so either hand can.
- **Touch: four buttons in an arc around the right thumb,** JUMP biggest in the corner (the verb pressed most),
  everything over 44 px, the lower-middle empty (rules 22-23). ITEM and the ghost's ROTATE are hidden when they would
  do nothing, so most of the time a phone shows three buttons.
- **Remapping is a basic accessibility rule** (Game Accessibility Guidelines, basic tier: "easy to implement, wide
  reaching"), and Can I Play That warns against games that remap but still hard-lock some keys: hence "every game
  verb" above.

## 4. Alternatives considered

1. **Scheme B as Celeste exactly (C jump, X dash, Z grab):** no gain over Z jump, and Z-jump is the more common
   default in the sources; rejected.
2. **Q for dash** (Roblox fighting games use Q to dodge: Slayers 2, Hunters, Archived): it would need the ring
   finger that holds A; added nowhere, but a remap away.
3. **Up / W as a second jump:** many platformer players press it; it takes the grapple's best key. Rejected for now;
   question 2 below.
4. **A contextual grapple** (auto-hook near an anchor, rule 22 allows it): saves a touch button, but a missed or
   unwanted swing is the top grapple complaint (rule 17); kept explicit.

## 5. Questions for Danzo (answered 2026-10-19: "unsure", so the recommended answer to each is the provisional default)

1. Accept the table as is?
2. W / ↑: grapple (recommended) or a second jump?
3. Mouse: left click use, right click grapple (recommended), or no mouse binds at all?
4. Touch trap pry: any 3 taps anywhere (recommended, bigger target), or taps on the trap itself as you said?

## Sources

- SpeedRunners 2 keyboard defaults (Z jump, X grapple, C pickup, Space boost): https://www.magicgameworld.com/speedrunners-2-king-of-speed-controls-keybinds/
- SpeedRunners players' layouts (Up for grapple; Z/X/C): https://steamcommunity.com/app/207140/discussions/2/598198356176779321
- SpeedRunners pickups (crate, freeze ray, golden hook): https://speedrunners.wiki.gg/wiki/Pickups
- Celeste defaults (C jump, X dash, Z grab; pad A jump, X dash): https://www.magicgameworld.com/?p=147653
- Celeste grab on trigger or shoulder (community): https://steamcommunity.com/app/504230/discussions/0/1777135944136908423
- Hollow Knight Silksong defaults (Z jump, X attack, C sprint; pad RT sprint, LT harpoon): https://www.destructoid.com/all-hollow-knight-silksong-pc-and-controller-key-bindings/
- Hollow Knight players' layouts: https://steamcommunity.com/app/367520/discussions/0/135514402722966465
- Dead Cells defaults (WASD, Space jump, Shift roll): https://www.magicgameworld.com/dead-cells-the-bad-seed-pc-keyboard-controls-guide/
- Roblox gamepad conventions: https://create.roblox.com/docs/input/gamepad
- Roblox keyboard defaults (Space jump, `/` chat, Tab, Esc, F9): https://htg-george.com/beginner-roblox-tutorials/roblox-keyboard-mouse-controls-pc/
- Roblox fighting games' Q dash, F block: https://allthings.how/bug-fixes-controls-guide-for-roblox-duels-every-keybind/
- Key jamming with arrows + Space: https://github.com/photonstorm/phaser/issues/949
- Sticky Keys after five Shift presses: https://www.digitalcitizen.life/problem-sticky-keys-takes-me-out-of-games/
- Remapping as a basic guideline ("Motor (Basic)"): https://gameaccessibilityguidelines.com/allow-controls-to-be-remapped-reconfigured/ ; hard-locked keys: https://caniplaythat.com/?p=8886
