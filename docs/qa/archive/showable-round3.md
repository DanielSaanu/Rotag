# QA round 3: the showable game (H31-H34)

**SCORE: 8/10** (target met) · reviewer: Opus subagent · 2026-11-16 · goals: [showable.md](showable.md) · Studio was
rendering: the reviewer played a whole solo match on screen with captures.

## The report (verbatim)

## Round 3 review: the showable game (H31–H34), commit 671c1b5

**Rig:** Studio was rendering: the client counted 241 RenderStepped frames in 1 s. Studio was in Edit when I arrived, so I started Play myself. I played one whole solo match (title → how-to → lobby → 3 rounds → podium) with captures throughout, opened the wheel and the locker, wore a trail, and ran the RotagHubTest path once. Play is stopped. RotagHubTest is nil in Edit (checked). The real clicks in the wheel spent the unsaved Studio wallet (200 → 0); nothing was saved.

**Checks:** `npm test` passes (13 node tests and 20 Luau files, 0 fail). `lint:luau` is clean. `rojo build` succeeds. 41/41 Sounds loaded. The only errors in Output were the expected DataStore 403s, plus one warning for an asset id that is not in our code (`rbxassetid://203785492`).

SCORE: 8/10

GOALS:
- 1 A start: met. Captures "title" then "afterplay": ROTAG title over the live map, Return → how-to cards → lobby. No body appears before PLAY.
- 2 A match: met. Saw "ROUND 1 OF 3" card (+4/+2/+1/+0), the strip all match, then the "chill wolf WINS!" card with "+10 coins · next match in 12". The podium is a card, not a stage.
- 3 Never empty: met. 3 bots seated ("match 1 round 1: 1 people, 4 seats"); they took orbs, used crate, trap and hex, swung, and won rounds. Whether they are beatable by hand is untested.
- 4 Fair bots: met (code). The rope drop on freeze or ghost is at `server/Bots.lua:195`. Names hold spaces ("chill wolf", "Pixel Wizard 31").
- 5 Earn, not buy: met. The wheel prints odds and "Cosmetics only"; the spin was server-rolled (Chalk, then Rookie, 100 each). The locker says "nothing here makes you faster". Unsaved status is shown.
- 6 Sound: partial. All 41 sounds load and the "end" track was playing during FINAL TWO (len 303). Nothing was heard.
- 7 Punch: partial. Pickup banner and ice beam seen ("beam" capture). A tag shake or burn-out moment was not caught on capture.
- 8 Names: met. Seat-coloured name tags, "YOU" in cyan, a red ▼ over the holder, lettered off-screen markers.
- 9 One look: partial. HUD, menu and cards share one kit and the runner reads. But the bottom ~20% of every frame below the floor is pure black, and markers overlap the HUD (see FIX).
- 10 Phone: not verified. The emulator was not driven.
- 11 Nothing broke: met. Tests, lint and rojo build are green; the line ceiling holds.

PRESERVE (done well, must survive future iterations):
- **Hub failure path:** Output: "match found for 1 of 1" → "try 1 of 2" → "try 2 of 2" → "giving up… runs the matches itself" → "match 1 round 1". A broken hub degrades to a playable solo server and never strands anyone. The guards also hold: `pcall` around ReserveServer and TeleportAsync, `player.Parent` checks, and LAUNCH_STALE.
- **Data lock across the hop:** a load waits up to 15 s for the old server's leave-save (`Data.lua:107-111`), revision plus lock check on every write, and one release per profile.
- **Presentation runs last, each part under pcall** (the H31 crash fix). The whole match ran with no client error.
- **Readable fuse HUD:** "YOU'RE IT 41.0" with a draining bar, "X is it", HEX and FINAL TWO lines.
- **Wheel honesty:** odds and a "duplicate pays coins back" note on the panel. Bots wear common items only.

FIX (done poorly; why it matters; concretely how to fix):
- **One departed player can count as a failed launch** (`Hub.lua:48-53`). TeleportAsync with a list that holds a player who has already left, or one still mid-teleport after LAUNCH_STALE, very likely throws. Two such launches flip the hub to solo for good, so no live hub survives a busy evening. → Before TeleportAsync, filter `players` to `p.Parent == Players`. Count only ReserveServer failures toward FAILS_TO_SOLO, or reset `fails` after a cooldown.
- **Match server starts without its group** (`Session.lua:234-238`, LOBBY_TIME 12). The countdown starts at the first arrival, and phones load slowly. A friend who arrives after 12 s watches round 1 while a bot takes their seat, on a server made for them. → Send the group size with `TeleportOptions:SetTeleportData({n=#players})`. Hold the lobby until that many have arrived or 25 s have passed.
- **Off-screen markers draw over the HUD and menus.** Captures show "ITE[Z]none" with the Z marker over the item readout, a marker over the strip, and one above the open locker panel. → Clamp markers below the strip and readout rectangles, and give their layer a DisplayOrder under RotagMenu.
- **Enter does not dismiss the first-run cards.** Return opens them from the title (`Menu.lua:226`), but only a mouse click or M closes them. A keyboard kid is stuck on the cards. → On screen "how", let Return, Space or ButtonA call `back()`.
- **Black void below the floor:** about 120 px of pure black under the stage in every capture ("round1", "results2"). → Extend the floor block and backdrop well below Y=0 in `server/Stage.lua`, or clamp the camera's low edge.

CONSIDER (fine but could change; why; how):
- **Out-of-walls red wash is very heavy.** A ghost left outside the walls sees an all-red screen ("results", "late"), and the final duel happened under the scoreboard ("r3"). → Halve the wash's opacity outside the walls, and let a ghost's camera drift toward the holder.
- **Failed launch restarts the full 12 s wait** (215.4 → 227.4 in Output). Playing begins 38 s after PLAY on a broken hub, and the countdown jumping back says nothing. → Requeue with `queueSince` set back by LOBBY_TIME, and show "retrying…".
- **The ice beam passes through blocks.** `Items.step` has no line-of-sight check. The "beam" capture shows it coming out from behind a crate. → Clip the beam's length at the first solid box along it.
- **Unaffordable buttons look affordable.** At 0 coins, BUY 200 and SPIN 100 stay bright gold. → Dim them when coins < price. Also highlight the active locker tab.
- **Top-centre text stack** gets to four lines (fuse, HEX, GHOST, FINAL TWO). → Drop the GHOST hint after the first few seconds.
- **Bot label is off** by the owner's choice. Names are now safe; the AI-disclosure advice from round 2 still stands for a kids' Discord.
- **New player is IT in the first second** of their first match (rounds 1 and 3). → Never start a person's first-ever round holding the fuse.
- **Bots still hop a lot:** about 13 ground jumps plus 15 double or wall jumps per 20 s each (Output). Judge by eye.
- DESIGN.md is 308 lines (deferred).

UNCERTAIN (could not verify):
- Real ReserveServer and TeleportAsync behaviour, a player leaving mid-launch, TeleportInitFailed timing, and the DataStore lock under a real hop. All of this is reasoned from code only.
- The phone layout (device emulator not used), and the safe-insets result on a notched phone.
- Sound and music by ear, and their volumes.
- The tag shake, flash and burn-out sparks on screen. I was AFK and missed both moments; only the beam and the pickup banner were seen.
- Whether a person can catch or escape a bot. Danzo: run clean against "Zippy Panda" (skill 0.87) for a full round on keyboard and on a phone.
- Two people in one match, and a friend joining mid-match.
- Whether the wheel has a reveal animation. The result showed within 0.9 s.

## Builder decisions

**FIX, all five done:**
- A departed player counting as a failed launch: the group is filtered to who is still here before the teleport;
  only a server that could not be RESERVED counts toward giving up; a teleport that fails just requeues the group.
- A match server starting without its group: the group's size rides the teleport (`SetTeleportData`,
  `Hub.groupOf`); the match server's lobby idles ("WAITING FOR YOUR GROUP 2 of 3") until that many have arrived or
  25 s. The number is only ever used to wait, never to seat (it passes through the client).
- Markers over the HUD: the arrows' layer is under the HUD (2), the readout (3), the scoreboard (5), the menu (20).
- Enter on the first-run cards: Return, Space or gamepad A is GOT IT. Seen in Studio: Return, Return, in.
- The black void: the ground under the floor is the floor's colour. Seen in Studio.

**CONSIDER:**
- The walls' red wash: lighter (0.86). A ghost's camera drifting to the holder: deferred (a camera rule, Danzo's).
- A failed launch: the group is retried in 3 s, not after the whole wait.
- The beam through blocks: done. `BoxWorld.reach`, `Items.beam`'s `reach`: the server cuts the beam at the first
  block or ghost fixture ahead of the hand; the client draws the same cut from a ray. Tested (a runner behind a
  wall is not hit, one in front is).
- Unaffordable buttons: a price you cannot pay is quiet, the spin button dims under 100 coins. (The active tab was
  already the solid one.)
- First round's holder: on a server's very first round a bot holds the fuse first when there is one. Seen in Studio
  ("-1000 is it"). After that the rotation (rule 5) is untouched.
- Deferred: the top-centre stack (four lines only in a ghost's end phase with a hex landing); the bot label
  (Danzo's ask stands, the advice is in INBOX); bots' hop rate (his eyes); DESIGN.md's length.

**PRESERVE:** all five intact.
