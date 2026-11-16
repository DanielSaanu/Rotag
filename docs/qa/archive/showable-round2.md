# QA round 2: the showable game (H31, H32)

**SCORE: 7/10** · reviewer: Opus subagent · 2026-11-16 · goals: [showable.md](showable.md) · the PC was still locked:
reviewed by code, tests and server Output.

## The report (verbatim)

## H31/H32 "showable" review, round 2: 7/10

**Rig:** the PC was locked. The client counted **0** RenderStepped frames in 1 s, so I called no capture or input tools. I reviewed by code, tests and server Output, ran one Play session (PLAY via the hook, about 2.5 minutes), and stopped Play afterwards.

**What I ran:**
- `npm test`: exit 0, fail 0, all 20 Luau files including `bots_human` ("every Yard deck reached from two starts… 12 routes used a rope").
- `npm run lint:luau`: exit 0.
- `rojo build`: succeeds.
- **Studio Output:** bots `fizzy_wolf` (skill 0.73), `LuckyWizard35` (0.29) and `Shadow_Panda9` (0.25) were seated, and the round started after the 5 s Ready timeout with the person as it. Then:
  - Bots took orbs.
  - "fuse ran out, -1000 is it", then "TAG -1000 -> -1001", "TAG -1001 -> -1002", "TAG -1002 -> -1001".
  - Per 20 s each bot made **20–35 jumps**, 0–7 dashes and 0–3 swings.
  - No errors. The only warnings were the expected DataStore 403s.

SCORE: 7/10

GOALS:
- 1 A start: met. Bodies spawn only on "play" (`server/Session.lua:160-163`). A missing profile now counts as new for the how-to cards. Not seen on screen.
- 2 A match: met. Output shows lobby → "match 1 round 1: 1 people, 4 seats" → round. `lastPts` is server-sent (`Board.lua:93`), and the session test pins scoring.
- 3 Never an empty room: partial. Bots chase, tag, take orbs and swing (Output), but whether a bot is beatable by hand is still unverified.
- 4 Fair bots: met (code). Per-target delay at `Bots.lua:287-292`, double overlap check at `:293-294`. Small leak: see FIX (ghost/frozen grapple).
- 5 Earn, not buy: met. The UpdateAsync lock and revision in `Data.lua:84-150`, the "NOT SAVING" chip (`Menu.lua:166,185`), and spins rolled on the server.
- 6 Sound: partial. The music holds through the gaps; no track has been heard.
- 7 Punch: partial. Sound by code; nothing seen.
- 8 Names: partial. A fixed-pixel tag part and "YOU" for self (`Look.lua:301-350`, `Present.lua:118`). Not seen.
- 9 One look: partial. The HUD is now scaled, but the item readout is still a bare unscaled label, and it sits under the scoreboard (FIX).
- 10 A phone: partial. The scale floor of 0.75 and the compact layouts work out on paper: the compact title column ends at about 478 of about 500–520 design px, and the how-to panel is 480. The notch / safe area is not handled. Not seen in the emulator.
- 11 Nothing broke: met. Tests, lint and rojo build are green; `shared/` is still pure (lint covers it).

PRESERVE (done well, must survive future iterations):
- **Bots run the real `Movement`** through rollouts. H32 added skill as data (`BotMind.new`: speed, think time, dash and hook share, noise, reaction), not cheats.
- **The grapple aim assist is shared:** `Grapple.pick` with the same view box and line of sight (`BotBrain.lua:91-93`). The rollout clones the rope (`:143`), so a rollout cannot move the real swing.
- **The server's load/save discipline:** a failed load sets `saved=false` and is never written, the revision check refuses stale writes, and the client is told.
- **Per-target bot tag timing** with a hard cap of 0.4 s, and a bot never tags from out of reach (`here` overlap with grace).
- **Narrow remotes**, Studio-only hooks, and the one-spin lock set on the press (`Locker.lua:168,174`).

FIX (done poorly; why it matters; concretely how to fix):
- **Bot names can be real accounts, a child-safety problem.** `Session.botName` (`shared/Session.lua:43-55`) makes `ShadowKid`, `TurboFox`, `frost_panda`. These are valid Roblox usernames and most certainly exist. A kid who thinks that "player" was fun will search the name and friend-request or message a real stranger, possibly an adult. -> Make the names impossible as usernames: include a space ("Turbo Fox"), or go over 20 characters, or use a character usernames cannot hold. Keep them unmistakably non-account.
- **Hiding that bots are bots from kids.** `bots.md §7`, `Present.lua:161-166`. The game removes Roblox's player list, gives bots no label, and dresses them in random wheel prizes ("the shop's best advert", `Shop.lua:34`). On a monetisation-minded game for children, that is manufactured social proof as well as deception. It also spoils the playtest's purpose: kids can't tell Danzo whether the AI felt good. -> At minimum:
  - add a how-to line ("Empty seats are filled by AI runners") and say it on the game page;
  - add a subtle marker in the strip and cards (a small chip icon), not the name tag;
  - dress bots mostly in common items.
  - Roblox policy is my uncertainty (see UNCERTAIN), but labelling is the low-risk path the doc itself recommends "if the game grows". Do it before posting to a kids' Discord, not after.
- **The item readout is hidden under the scoreboard.** `client/Items.lua:240-252` puts "ITEM: …" in a plain ScreenGui at screen (12, inset+12), DisplayOrder 0. `Board.lua:39,188` puts the near-opaque strip at (12, inset+6·k), DisplayOrder 5. During every round the strip covers the item line. -> Move the readout onto `Ui.scaled` under the strip (y = strip bottom + 6), or into the strip's header, in the Ui kit's fonts.
- **A ghost or frozen bot can keep swinging.** `Bots.lua:179` calls `BotBrain.input(..., hooks)` with the module's `hooks`, whatever `goal.hooks` is. The frozen branch (`:188-191`) clears move, jump and dash but not `grappleHeld`. A bot that burns out or is tagged mid-swing holds its rope for up to the plan's 0.8 s. A player's client drops it (`Client.client.lua:125-132`, `Grapple.frame` with a ghost flag). This breaks "a bot can do nothing a player cannot" and rule 37. -> In `stepBot`, after `BotBrain.input`, when `frozen` or `r.alive[id]==false`, set `input.grappleHeld, input.grapplePressed, input.anchor = false, false, nil`.

CONSIDER (fine but could change; why; how):
- **Hopping wasn't cured by `EFFORT`.** This round's Output shows 20–35 jumps per 20 s per bot, about the "before EFFORT" 24–35 in `bots.md:117`, so the doc's claim isn't supported. It may be double jumps and wall kicks on the Yard; a person may hop that much too. -> Count only ground jumps in the Studio line, then judge by eye.
- **Data.lua edge cases:**
  - `PlayerRemoving` clears `profiles[id]` *after* the yielding save (`:159-160`), so a fast rejoin to the same server can have its fresh profile wiped. -> Clear only if `profiles[id]` is still the same table.
  - `BindToClose` plus `PlayerRemoving` both save, so the second is refused and logs a false "another server" warning. -> Skip ids already released.
  - The last-try forced takeover after about 9 s makes `LOCK_TTL` moot. A slow leave-save on the old server is then refused, and that match's coins are lost. -> On the forced take, load with `saved=false` for the session, or wait longer.
- **No safe-area handling.** `IgnoreGuiInset = true` everywhere, and the strip, logo and buttons sit 9–50 pt from the left edge, under an iPhone's landscape notch. -> Set `ScreenInsets = DeviceSafeInsets` on the menu and board roots, or pad by `GuiService:GetSafeZoneOffsets`.
- **Layouts are fixed at build time.** `Ui.compact()` and `Ui.width()` are read once. A 1×1 viewport at start (as on this rig) makes a desktop compact for good. -> Rebuild on a large `ViewportSize` change, or after the first non-1×1 size.
- **Uneven name-tag text.** It is TextScaled in an 8h-wide part, so 13+ character names shrink. -> Widen to 11h, or fix `TextSize` with `TextScaled` off.
- **`GetNetworkPing` is a round trip** (per my reading of the docs). The display delay is about half of it, so the 0.4 s cap is reached early on phones. It is conservative, not unfair: note it.

UNCERTAIN (could not verify):
- Everything on screen (Studio rendered 0 frames): the title, cards, locker, wheel, compact phone layouts, name tags, the item/strip overlap as it actually draws, the bloom, trails, shake.
- Music and SFX ids and their volumes.
- Whether a person can catch and escape a bot, and whether the bots *read as people*. Danzo: play three solo matches on keyboard and in the phone emulator, and watch one bot for 30 s for hop rate and rests.
- Real DataStore lock and revision behaviour under a fast server hop (Studio API access is off, so it loaded "NOT saved this session").
- Whether Roblox's Community Standards or experience guidelines restrict unlabelled AI "players" aimed at under-13s. I believe NPCs are allowed, but deceptive representation to minors is a gray area. Check before publishing more widely.
- Two people in one match, and a player leaving mid-tag (not exercised this session).

## Builder decisions

**FIX:**
- Bot names can be real accounts: **done.** Every name now holds a space (`Turbo Fox 12`): never a possible username.
  The test asserts it for 50 seeds.
- Hiding that bots are bots: **partly done, partly Danzo's call, and said so to him.** Done: bots wear common items
  only (no rare prize on a non-person); `Config.BOT_LABEL` exists (true marks bots "[AI]" in the scoreboard and
  the cards and adds "Empty seats are filled by AI runners" to the how-to cards). NOT done by default: the label is
  OFF, because Danzo asked in so many words for players to play "with machines unknowingly"; that is his product
  decision, the reviewer's advice is recorded in bots.md §7 and INBOX, and the switch is one word. Roblox's player
  list stays off (the scoreboard is the list).
- The item readout under the scoreboard: **done** (on the scaled root, under the strip). Seen in Studio.
- A ghost or frozen bot keeps swinging: **done** (the grapple input is cleared for both).

**CONSIDER:**
- Hopping: the Studio line now counts ground jumps apart from double and wall jumps; the doc's claim removed.
- Data edge cases: all three done (clear only the same profile table; one release per profile; 15 s of waiting
  before a lock is taken over, and the stale-writer check still protects the newer save).
- Safe area: `ScreenInsets = DeviceSafeInsets` set on every kit screen (under pcall).
- Layout fixed at build time: the client waits up to 2 s for a real viewport before building; a rebuild on resize
  is deferred (ui.md deficits).
- Name-tag text: one text size, `TextScaled` off, a wider part.
- `GetNetworkPing`: half of it is used now (what the target sees is one way behind).

**PRESERVE:** all five intact.

**Then the PC was unlocked, and the game was looked at for the first time** (by Danzo and through captures). What
that found and changed is not from this report: ui.md §8 (a render-loop crash from the first ignition, the dark
stage, the map streaming in, ghosts, trails, the walls' red), and H33 (the ice beam, traps, pickups).
