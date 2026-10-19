# Items: living orbs, Use, the holds (crate, bear trap, ice beam)

**Created:** 2026-10-19 by the heavy agent (H19), ghosts v2 PR 2. Design: DESIGN §3 rules 41 (the per-target ward),
42 (orbs), 43 (the living pools), 44 (holds), 45 (dash i-frames); rules 10 and 11 for context. Spec:
[ghosts-v2-proposal.md](ghosts-v2-proposal.md) §12 item 2, §3, §4, §8. Ghosts, ghost orbs and the hex (PR 1):
[ghosts.md](ghosts.md). The speed check this leans on: [trust.md](trust.md) §10. QA goals:
[`../qa/ghosts-v2-items.md`](../qa/ghosts-v2-items.md). Remotes: [README.md](README.md).

**Status:** built; QA round 1 7/10, its two FIXes applied (§3, §5, §8). Rules tested outside Studio
(`items.test.luau` new; additions to `movement`, `move_check`, `orbs`, `ghost`, `config`; mutation-checked, §8). Seen
in Studio by the round 1 reviewer (living orbs taken, Use, a stumble and a trap landing, a trapped runner tagged); not
yet seen live: a pry, the ice beam, the dash dodge, a ghost's items, the phone preset. The round 1 fixes are untested
in Studio.

## 1. The rules and their numbers (Danzo's, 2026-10-19)

- **Living orbs (rules 42, 43).** Their own spots (`Arena.LIVING_ORBS`, three on the test map), for the living only;
  first at 0:05, back after 10 s. The server rolls the taker's pool: a runner crate 40 / trap 35 / ice 25; **the
  holder** ice 50 / crate 25 / trap 25 (rule 10: the chase item first).
- **The ghost pool** gains crate 12 / trap 10 / ice 10 beside hex 8. The hex is now **1 roll in 5** (PR 1: every roll),
  which is Danzo's option (a) for PR 1's hex stream. PR 4 adds fixture 30, boost pad 15 and boost grant 15, which
  brings the hex to the spec's 8 in 100. The pools live in `shared/Items.POOLS` (moved from `Orbs.POOLS`).
- **Use.** Crate: dropped behind you, on your feet's line, lasts 20 s; touching it breaks it and **stumbles** you
  0.7 s (half run speed the way you were going, no steer, jump, dash or item). Bear trap: at your feet, 20 s or one
  catch; **pins** you up to 1 s (across; caught in the air you drop onto it and never rise, QA round 2), or 3 presses
  (any key or click; any tap on touch) pry it open. Ice beam: from your
  front edge 24 studs ahead the way you face, 0.5 s, does not turn; **freezes** each runner it touches once, 1 s, with
  no input, sliding on the speed it caught you with, which bleeds linearly to 0. Use with a hex does nothing (the hex
  is used by touch, PR 1's `GhostClaim`).
- **Holds (rule 44).** Never stop a tag (a trapped runner is tagged, a stumbling holder tags), **except the ice
  freeze on the holder (H20, Danzo 2026-10-19): an iced holder cannot pass the fuse** (§5); an iced runner is still a
  free tag. **No chains:** no hold lands during one or in the 0.5 s after it; the holder's tag freeze counts as a hold.
  **No item starts during a hold or the tag freeze; one started before goes off in full** (a beam out stays out).
- **Dash i-frames (rule 45).** The first 0.2 s of a dash the SERVER counted dodges an ice beam and the hex and carries
  you over a trap; never a crate, never a tag.
- **Per-target ward (rule 41).** A runner hit by a ghost's AIMED ability (ice beam, hex) is safe from every ghost's
  aimed abilities for 6 s. A hex wards its holder this way too (beside PR 1's shared ward); a ghost's crate or trap is
  put down, not aimed, and wards nothing. A living runner's beam is not a ghost's: it lands through the ward.
- **Items touch the living only.** The server never passes a ghost as a victim; ghosts' own items hit the living.

## 2. Who owns what

| Piece | Where | Side |
|---|---|---|
| Pools, `poolFor`, footprints, `canUse`, `use`, holds (`holdOf`, `canHold`, `pry`), `step` (hits, holds, the ward), `iframed`, `dashSeen`, `undodged`, `swept` | `shared/Items.lua` (pure, tested) | both |
| The hold input: stumble, freeze, trap | `shared/Movement.lua` (`Input.hold`, `holdDir`, `holdLeft`) | client |
| The hold's speed allowance (`HOLD_RATES`, `hold`, `release`) | `shared/MoveCheck.lua` | server |
| The per-target ward (`Ghosts.wards`, checked by `canHex`, set by `hex`) | `shared/Ghost.lua` | server |
| `UseItem` judged, the things run each frame, holds written, pries, `ItemEvent` put/gone/hold/free | `server/Items.lua` | server |
| Facing and the dash record per runner (i-frames, the server-side cooldown) | `server/Snapshots.lua` | server |
| `iframe` stamped on each history sample | `server/Match.lua` (`sample`), the wiring | server |
| The hold's budget for a player | `server/MoveGuard.lua` (`hold`, `release`) | server |
| Living-orb spots | `server/Arena.lua` (`LIVING_ORBS`, `ORBS`) | server |
| Dummies use what they roll (once a player is within 24 studs, facing it) and stand still while held | `server/Bots.lua`, `server/Dummy.lua` | server |
| Use and pry bindings, the ITEM button | `client/Controls.lua` | client |
| The local hold into Movement, Use and pry presses out as `UseItem` | `client/Use.lua` | client |
| Living orbs, things, beams, hold overlays, icons per item, the slot readout for the living | `client/Items.lua` | client |
| "TRAPPED: mash any key 1/3" / FROZEN / STUMBLE; the ward halo's red flash; halo colour reset on hide | `client/Hud.lua` | client |

## 3. What the server trusts (DESIGN §3 rule 6, proposal §8; → N4, N5, N10)

**`UseItem`: one small integer** (0-3; the fixture rotation in PR 4, ignored now). The sender is the `Player`; rate gap
`USE_GAP` (0.05 s; the client sends no faster than every 0.06 s), **waived while the server has the sender trapped**
(`Items.acceptPress`, QA round 1); a non-integer or out of range is dropped unread.
Everything else is the server's: the round runs and the sender is in it; the item is the SERVER's slot; no hold, no
tag freeze (`Items.canUse` on the server clock); the spot is the server's newest sample of the user and must be
**trusted** (a suspect position places nothing; the item stays in the slot); the facing is the one its own stream
reports (the same word as its position, bounded the same way). A refused Use gets no reply; Studio logs why.

**Hits are the server's reading of its own record**, every frame after the orbs: each thing against each living runner's
newest sample and the path from the one before (→ N14). **An untrusted sample still gets hit**: the speed check may
make a runner's samples unable to tag or collect, never able to dodge.

**Holds.** The server writes the hold, tells every client (`ItemEvent` `hold`), and holds that player's speed check
to it until it ends ([trust.md](trust.md) §10, as tightened by QA round 1): the x budget drops to the victim's speed
(measured on the server's own samples) x `HOLD_GRACE` + `HOLD_SLACK`, and stays capped there; the refill is the
hold's allowance (a freeze's from that same speed). Ignoring a trap is caught 0.34 s in, a freeze 0.76 s in, a
stumble 0.68 s in (all from a run), and snapped back.

**Pries.** While the SERVER has a runner trapped, each `UseItem` from it is a press, with no rate gap (jitter that
bunched two honest presses used to drop one: QA round 1); the third frees it (`free` to all, the check released). The
client counts its presses for the HUD but **stays pinned until the server's `free` arrives**, so it can never run
while the server still holds it. A client cannot pry anything but a trap, nor start an item while held.

**I-frames.** From the snapshot stream's dash event (or the dashing flag rising, if that packet was lost); a start
counts only if `DASH_COOLDOWN - 0.1` s have passed since the last counted one (`Items.dashSeen`), so a client claiming
to dash every packet gets at most 0.2 s of i-frames per 0.7 s. Each history sample carries `iframe`; a hex is judged
only on the holder's samples outside them (`Items.undodged`); a tag never reads it.

**Fairness, stated plainly.** A cheating client can: drift or steer inside a freeze or a stumble within its budget
(at most ~40 studs over a 1 s freeze from a run against an honest ~36; ~31 over a stumble against ~22: trust.md §10);
pry a trap in one frame by sending three presses at once (an honest hand mashing three keys can do the same); claim a
dash at the cooldown's pace for i-frames it did not earn (the same pace an honest
player gets); misreport its facing (a beam or crate the other way). It cannot: place from a position the server did
not record, use an item it does not hold or while held, escape a trap by moving (snapped back), pry anything but a
trap, dodge a crate or a tag, or be hit while a ghost.

## 4. Payloads (`ItemEvent`, server → all; arrays only, → N13)

PR 1's `sync` (now with living orbs: `ghost` false), `orb`, `slot`, plus: `put` `{ n, item, x, y, w, h, dir, life }`
(a thing in the world, centre and size in studs, seconds left); `gone` `{ n }`; `hold` `{ id, hold, time }` (`hold` is
"stumble" | "freeze" | "trap"); `free` `{ id }` (a pry, or run out). A `sync` clears every thing and hold on the client;
a late joiner then gets a `put` per live thing and a `hold` per live hold. `UseItem` (client → server): `number` 0-3.

## 5. Decisions taken while building (H19)

- **Frame order:** players' tags, dummies' tags, hexes, orbs, dummies' uses, the things (hits), then the fuse. A Use
  arriving between frames puts its thing in at once; it is judged from the next frame.
- **A thing is judged against the victim's sample as the server has it** (the victim's own snapshot, ~0.1 s late),
  not rewound: the hazard is the server's, and the victim's own past is what everyone else saw.
- **The owner:** a crate or trap never catches its owner within `OWNER_SAFE` (0.5 s) nor before the owner has been off
  it once (a trap is set at your own feet). A beam never hits its user. (The spec gave the 0.5 s for the crate only.)
- **A runner who cannot be held passes a crate or trap without using it up**; it stays for the next one.
- **The hold's budget (revised by QA round 1, → N15):** the first version kept the 24-stud burst cap and only lowered
  the refill (freeze: a fixed 60), which let a client ignore a whole freeze from a run. Now the x cap drops to the
  victim's server-measured speed x `HOLD_GRACE` + `HOLD_SLACK` for the whole hold, and a freeze refills at half that
  speed + `HOLD_SLACK`. Trap 0/0/0; stumble half run, jump speed up, fall cap down. The speed comes from the server's
  own samples (`MoveCheck.recentSpeed`), not the snapshot's `vx`, so a client cannot widen its own allowance.
- **After a hold (QA round 2):** the x budget is back to the full burst the moment the hold ends, pried or run out
  (`MoveCheck.step`), so a dash-jump straight out of a trap keeps ~22.6 studs to spare instead of 0.49. A trapped
  runner in the air drops (never rises, never moves across); arming a trap only on a grounded sample was the other
  option, but the server does not know "grounded", and Movement stays one line. `Config.STUDIO_DUMMY_TAGS` (false:
  dummies never tag) is the Studio knob for testing items solo.
- **An iced holder cannot pass the fuse (H20, Danzo 2026-10-19).** `Items.canTag` (shared, pure) refuses the holder
  while `holdOf` says freeze; `Items.STOPS_TAG = { freeze = true }` is the one switch. The server asks it in
  `Match.judge` right after `Tag.canClaim`, and `Bots.tags` asks it for a dummy holder, both on the SERVER's hold
  record. Like the tag freeze it is judged **when the claim is decided**, not when the touch happened: a claim still
  pending when the ice lands is dropped. The ice ends on its own clock (`now >= untilT`), so the next frame's claim
  passes even though the frame judges tags before `Items.step` marks the hold over. The holder's client skips claims
  while iced (it would only be refused) and its HUD says "FROZEN: can't tag". **Trap and stumble are unchanged**: Danzo
  named only the freeze, so this is my reading, not his ruling; extending it is one line in `STOPS_TAG`. A cheat that
  ignores the freeze on its own screen still cannot tag: the refusal reads the hold record, not the motion. Test:
  `items.test.luau` (rule 44, H20 block); mutation-checked 6/6 (no hold stops it, trap or stumble stops it, the freeze
  never ends, ends one tick late, an iced victim shielded).
- **The trap press path (QA round 1):** no rate gap during a trap (`Items.acceptPress`), and the client stays pinned
  until the server's `free`. Both, not one: the first removes the desync, the second makes any future one harmless.
- **A press during a trap is any `UseItem`**: no second remote; the integer is not read for it.
- **The stumble's direction** is fixed by the client from its own speed when the hold lands (or its facing at rest).
- **Dummies** stand still for any hold (they are stand-ins), use an item once a living player is within 24 studs and
  turn to face that player; a ghost dummy with any item heads to the holder. Solo Play therefore shows holds landing
  on the player.
- **Palette (rule 12, PR 1's QA):** ghost orb pale blue-violet ball, living orb gold ball; over heads a magenta diamond
  (hex), a brown box (crate), a flat red jaw (trap), a cyan ball (ice); in the world a brown crate and a dark-red trap
  (plastic: objects) and a see-through neon cyan beam; a trapped runner gets a red jaw at its feet, a frozen one a
  cyan box.

## 6. What each screen shows, and the controls

| Who | What |
|---|---|
| Everyone | Gold living orbs (bright to the living), pale ghost orbs (bright to ghosts); crates, traps and beams where the server put them; each held item's icon over its holder's drawn head; a jaw at a trapped runner's feet, ice around a frozen one |
| The local runner | `ITEM: CRATE` etc. top left (living too, now); while held, the status line says `TRAPPED: mash any key 1/3`, `FROZEN` or `STUMBLE`; the IT halo flashes red 0.3 s as a ghost ward ends |

Use: **E, V, RB / R1, left click**, and an **ITEM** touch button (64 px, above JUMP, out of the lower middle). Pry:
any key, click, pad button or tap. The full table is PR 3 ([controls.md](controls.md)).

## 7. The knobs (`shared/Config.lua`)

`ITEM_LIFE` 20 · `CRATE_SIZE` 3 · `TRAP_W` 3 / `TRAP_H` 1 · `ICE_LENGTH` 24 / `ICE_HEIGHT` 2 / `ICE_LIFE` 0.5 ·
`STUMBLE_TIME` 0.7 / `STUMBLE_SPEED` 0.5 · `FREEZE_TIME` 1 · `TRAP_TIME` 1 / `TRAP_PRESSES` 3 · `HOLD_IMMUNITY` 0.5 ·
`OWNER_SAFE` 0.5 · `DASH_IFRAMES` 0.2 · `HOLD_GRACE` 0.3 · `HOLD_SLACK` 2 · `USE_GAP` 0.05. `config.test.luau` pins Danzo's numbers and
rule 11 (no hold over ~1 s).

## 8. Verification (2026-10-19, H19)

- **Tests changed WITH their rules** (spec §12: PR 2 fills the pools): `orbs.test.luau`'s "a living orb has no pool,
  taken by nobody" and "the ghost pool is the hex alone" are retired with those interim rules; "a kind with no pool
  is never up" is kept with a made-up kind; three hex-taking tests now feed the hex's share of the roll (`HEX`)
  instead of 0, with every assertion unchanged.
- `npm test`: 13 node tests pass (line ceiling, purity); Luau: config, ghost, **items** (new), movement,
  movement_sprites, move_check, orbs, remote_pose, sidecam, snapshot, tag all ok. `npm run lint:luau`: all 33 files ok.
  `rojo build`: ok, with `Remotes.UseItem`.
- **Sourcemap before/after:** nothing removed or renamed; added `Shared.Items`, `Server.Items`, `Client.Use`
  (ModuleScripts); the build also holds `Remotes.UseItem` (RemoteEvent).
- **Mutation check (41 mutations, 40 caught):** pools and `poolFor`, the crate behind, immunity after a hold, the tag
  freeze as a hold, no use in a hold or freeze, the hex not by Use, 3 presses, only a trap pries, the i-frame length,
  the server dash cooldown, the hex dodged in i-frames, the owner's 0.5 s and step-off, never through a crate, over a
  trap, a beam catches once, its life, crates and traps used up, the ward (ghosts only, aimed only, set, checked, and
  in `canHex` / `hex`), `free` once, the trap pins in the air, the hold blocks jump and dash and ends a dash, a buffered
  press dropped, the stumble's speed, the freeze's bleed, the hold's refill and allowances, release, the holder's pool,
  no pool never up. The first run missed four: a fixture was doing the rule's job each time (→ Q5); each got an
  assertion only the rule can produce. **Not caught:** "a beam never hits its user", an equivalent mutant while
  `OWNER_SAFE` (0.5) >= `ICE_LIFE` (0.5): the owner rule covers it. Kept explicit for when either number changes.
- **QA round 1 (7/10, [`../qa/ghosts-v2-items-round1.md`](../qa/ghosts-v2-items-round1.md)), fixes re-checked:** 50
  mutations, 47 caught. New and caught: no gap during a trap, only a trap waives it, the gap outside one (a bunched-
  presses test), the freeze refill from the measured speed, the cap from the speed, the dropped cap kept for the whole
  hold (a stand-then-dash test, added because the first re-run missed it), `recentSpeed`'s window, an unknown speed read
  leniently. Not caught, both equivalent in the server: "the budget drops when the hold lands" (the in-hold cap clamps
  it on the next sample anyway) and "the hold starts at its first sample" (`>=` vs `>`: the server applies a hold after
  that frame's sample, so no sample sits on the start). Plus the beam-user one above.
- **QA round 2 (8/10, target met, [`../qa/ghosts-v2-items-round2.md`](../qa/ghosts-v2-items-round2.md)):** 54
  mutations, 51 caught (the same 3 equivalents). New and caught: the full burst after a hold (a dash-jump-out-of-a-trap
  test that asserts the margin, since it first passed by 0.49 studs without the rule), a trapped runner never rises,
  drops rather than hangs, stays pinned across, and its fall is legal (a trap set in mid-air, 40 studs: the first
  re-run missed this one, so the test was added).
- **Studio:** connected (Edit mode). The running `rojo serve` had synced `Shared.Items`, `Server.Items` and `Client.Use`
  but not `Remotes.UseItem` (→ T6), so the builder did not start Play. The round 1 reviewer then played it with the
  remote present (its Output is in the round file); the round 1 fixes have not been played.

## 9. The art on the parts (H21, 2026-10-19)

The contract is [the brief](../briefs/items-art.md) "Sprite names and sizes"; this is how the client meets it.

- **Where:** `client/ItemArt.lua` (new ModuleScript; `client/Items` calls it). `ItemArt.show(part, name, mirrored)` puts a
  SurfaceGui (+Z face, 50 px per stud, bilinear) on the part `client/Items` already made and turns the part see-through
  (a ball becomes a block: a face is the bounding box's). **Guard:** while `Sprites.Has(name)` is false the part is
  untouched and stays the coloured placeholder, so the code ships before the sheet (checked in Studio: a missing name
  leaves the Ball as it was). `ItemArt.alpha` fades the label once art is on, the part otherwise.
- **Frame pickers** (all from the clock and name tables built once; no string is built per frame):
  orb: `floor(now * 4) % 4` while up; the take one-shot (0.06 s a frame) from the "orb" event's up=false, then the faint
  `orb_spin_0` (ImageTransparency 0.75); ghost orbs the `ghost_orb_` set at the old half-bright rule. Crate: `crate_0`;
  on a "gone" for a crate that **caught someone**, `crate_break_0..2` (0.05 / 0.08 / 0.07 s) then destroy. Trap thing:
  `trap_armed`; the trap at a pinned runner's feet: `trap_snap_0` 0.06 s, then `trap_snap_1`, `trap_pried_1/2` by the
  local runner's presses, `trap_armed` for 0.12 s after the hold, then gone. Beam: `ice_beam` (mirrored when `dir` is
  -1), `ice_charge` at the hand for 0.05 s, `ice_fade` 0.1 s after "gone". Held icons: `crate_0`, `trap_armed` (1.8
  wide), `ice_icon`; the hex `hex_dim` while the shared ward holds, else `hex_ready` / `hex_pulse` every 0.8 s, and
  `hex_spent` 0.3 s when it leaves the slot mid-round.
- **"Caught" without a new field:** `server/Items` fires each `hold` (with `by` = the thing's number) just before that
  thing's `gone`, in the same frame, in order. The client marks the thing caught on the hold, so a gone after it is a
  catch and any other gone is an expiry. No payload changed; `by` is now written into the remotes table.
- **Runner holds:** `Movement.spriteFor` picks a hold first, from `s.hold` / `s.holdTime` / `s.holdSprite`, which `step`
  records from the input it already had: trapped `floor(t * 8) % 2`, the stumble ROLL by `STUMBLE_ENDS` (0.14, 0.26,
  0.38, 0.5, 0.7: trip, the tucked pose at 20 / 160 / 290 degrees, recover; Danzo's change on the canvas), a freeze the
  frame showing when it landed. The old pick is now `Movement.motionSprite`. The five hold names are appended to
  `Snapshot.SPRITES`, so older wire indices keep their meaning. Tests: `movement_sprites` (trap, roll, freeze on the
  ground and mid-rise, the fallback) and `snapshot` (the names ride the wire). Mutation check: 11 mutants, 10 caught; the
  miss (capturing `holdSprite` on every hold change, not only a freeze) is equivalent, since only a freeze reads it.
- **One switch for the runner:** `ItemArt.HOLD_ART` (`runner_trapped_0` and `runner_stumble_0` in the sheet). Off: the
  client draws and sends `motionSprite` and the frozen runner keeps the cyan box, exactly as before H21. On: hold poses,
  and `Look:frozen` draws the brief's rim (the current frame again behind itself, tint `#45e0ff`, 1.08 x) plus a cyan
  feet line instead of the box, on every screen (`Others.draw`'s new `iced` callback). **Risk for Danzo's Play:**
  ImageColor3 multiplies, so the rim is cyan only where the art is light; on the dark graphite it may read weakly. If
  it does, the fix is a white-filled silhouette per frame in the sheet (an art change), not more code.
- **Left out on purpose:** other screens see no pry presses (the server does not send them), so a trap on another runner
  stays on `trap_snap_1` until free; crate planks do not follow the runner's direction (one set of frames); the dummies
  (no snapshot stream) show motion poses only.
- **The trap in the guard:** `Sprites.Has` only knows the generated `Sprites.lua`. After `roblox build` and BEFORE the
  upload, the names are there but the sheet id is still the old image, so every sprite (the runner's too) draws the wrong
  rect. Seen in Studio on 2026-10-19: the runner and items were fragments. The guard covers a missing name, not a missing
  upload (→ A6).

## Expansion: deficits at scale

- Things cost one slab test per living runner per thing per frame: 4 runners x a few dozen things is negligible.
- PR 4's fixtures and pads are a different kind (solid map parts, placement rules) and belong in `shared/Placement`,
  not here; the boost grant joins the pools here.
- A live game with real ping may want `HOLD_GRACE` from the victim's measured ping instead of a constant.
