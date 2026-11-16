# QA round 1: the showable game (H31)

**SCORE: 7/10** · reviewer: Opus subagent · 2026-11-16 · goals: [showable.md](showable.md) · the PC was locked (Studio
rendered 0 frames): reviewed by code, tests and server Output.

## The report (verbatim)

## H31 "showable" review: 7/10

The PC was still locked. Client `RenderStepped` counted 0 frames in 1 s, so I called no capture or input tools. I reviewed by code, tests and server Output.

**What I ran:**
- `npm test`: exit 0, "fail 0". `session`, `profile` and `bots` tests pass, and so do all the older ones (the move, grapple and walls numbers are unchanged).
- `npm run lint:luau`: exit 0.
- `rojo build`: succeeds. The project diff only adds 5 RemoteEvents under `Remotes`.
- Studio Play:
  - PLAY through the hook gave Bolt, Dash and Pixel seats ("match 1 round 1: 1 people, 4 seats"). The round started after the Ready timeout and the person was it with 45 s. Bots took orbs ("-1002 took living orb 4: crate").
  - "sit" in the middle of the round logged "sat out", then "everybody left: back to an idle lobby". "play" again respawned the body. No errors.
  - Profile: "loaded (NOT saved this session): 200 coins" (150 start + 50 daily).
  - The server's Heartbeat averaged 4.2 ms (worst 6.4 ms) with three bots.
  - One `BotBrain.choose` on the Yard (20 boxes) took 3.5 ms in the command context. That is roughly 10 thinks a second, at most one per frame: affordable.
  - Play is stopped.

SCORE: 7/10

GOALS:
- 1 A start: met. `Runners.start()` no longer spawns a body; `Session.onMenu` spawns one only on "play". The how-to cards show once when `p.matches == 0` (`Menu.lua:47-57`). Caveat: if the profile has not arrived yet, `p` is nil and the cards are skipped.
- 2 A match: met. `shared/Session.tick` runs lobby, 3 rounds with gaps, podium, lobby. `points()` gives 4/2/1/0 (tested). The strip `Board.lua:36` is up all match. Studio Output confirms the lobby and round steps; the full match end-to-end is the builder's observation.
- 3 Never an empty room: partial. Seats fill and bots use the real `Movement` in `BoxWorld`, chase, flee, take orbs, use items, haunt and mind the walls. Whether a bot is "beatable by a clean runner" needs hands: nobody has played one.
- 4 Fair bots: partial. A bot never plays alone (`Match.lua:146`, plus the abort I saw). Seats go to people first (`Session.pick`). But `BOT_SEEN = 0.12` is fixed for every target (`Bots.lua:35`, `249`), so on a 200 ms phone a bot tag lands about 4 studs short of a touch on that player's screen.
- 5 Earn, not buy: met. The catalogue is cosmetic only, odds are printed (`Locker.lua:82`), spins are rolled on the server (`Profile.spin` with `math.random`), and a failed load sets `saved=false` and never writes. Two caveats: `saved` is never shown to the player, and saves use `SetAsync` with no session lock.
- 6 Sound: partial. Every move, hit, pickup and button has an effect, and the fuse beep speeds up and rises (`Audio.lua:94`). The music ids are unheard and unverified, and the track flips menu→match→menu around every 6 s gap.
- 7 Punch: met (by code). Shake is squared trauma, at most 1.6 studs; a tag gives about 0.48 studs. The edge flash is transparent in the middle 50% (`Fx.lua:210`), so it cannot hide the figure. Nothing seen.
- 8 Four figures, four people: partial. The tag is 0.095 of a 6-stud canvas, about 0.57 studs, in a 48-stud view (`Look.lua:301`). That is about 13 px at 1080p but about 4.6 pt on a 390-pt phone: unreadable there.
- 9 One look: partial. Menu, Board and Locker share the `Ui` kit, but the HUD still uses unscaled `Enum.Font` labels with TextStroke at pixel offsets. Stage colours look sensible on paper; nothing was looked at.
- 10 A phone: partial. Everything fits (720-tall design, `UIScale` k≈0.54), but the text does not read (see FIX). The cards are top-centre, so the lower middle stays clear.
- 11 Nothing broke: met. Tests and lint are green, the tree only grew, `rojo build` succeeds, and `shared/` stays pure. `docs/DESIGN.md` is 308 lines, slightly over the ~300 soft limit.

PRESERVE (done well, must survive future iterations):
- **The pure `shared/Session` / `Profile` / `Catalog` with tests:** the flow, scoring, queue and purse rules are testable without Studio, and the server is their only caller.
- **Bots run the real `Movement` through `BotBrain` rollouts:** a bot cannot do what a player cannot, and its tuning is the `noDash` share, not cheats.
- **Bots are stopped from playing alone in two places:** `startRound` needs a person, and `Session.tick` aborts when nobody is in. The abort path was confirmed in Studio.
- **A failed load is never saved:** `saved[id]=false` blocks the write, and `Profile.sanitize` cleans whatever was stored.
- **Every new client→server remote is narrow:** one string, or op plus id, rate-gapped, with prices, odds and ownership read only on the server.
- **Mid-round joiners don't affect the round:** `Orbs.step` and `BotMind` iterate `r.order`, so a person waiting for the next round cannot take orbs or be chased.

FIX (done poorly; why it matters; concretely how to fix):
- **Text unreadable on a phone (goal 10):** `Ui.screen` scales by height/720, so on a 390-pt landscape phone k≈0.54. Rarity text (12) comes out at 6.5 pt, odds and fine print (14) at 7.5 pt, how-to body (16) at 8.6 pt, and scoreboard names (15) at 8 pt. -> Floor k at about 0.75 for small viewports and give the locker grid 3 columns there. Or raise every body size to 20 or more in design pixels. Check in the device emulator.
- **Name tags about 4.6 pt on a phone (goal 8):** `Look.lua:301` ties the tag's size to the world. -> Use a BillboardGui with a fixed pixel size (14-16 px) adorned to the holder, offset above the head. Or scale the tag up as the viewport shrinks.
- **HUD and Board overlap at round start on small screens:** HUD labels are unscaled pixels (`countLabel` y 0-120 at 72 px, `statusLabel` y 82, `phaseLabel` y 106). Board's "ROUND n" and its sub-line are scaled (top+92, top+162). At k≈0.54 they land at inset+53..103 and collide with the holder's "3, 2, 1" and the status line. -> Move the HUD onto `Ui.screen` (the same design space), or put Board's intro lower (around 200) while the holder's count is up.
- **The saved flag is never shown:** `Profile.view.saved` is sent but no client code reads it (`Data.lua:51` says "the menu says so"). In a DataStore outage a kid spends coins that vanish. -> Show a "progress not saving right now" chip in the wallet when `saved == false`.
- **DataStore overwrites across servers:** `SetAsync` with no session lock (`Data.lua:93`). A fast server hop can load before the old server's leave-save lands, then overwrite it with stale data. -> Use `UpdateAsync` with a session token or version stamp: refuse to write when the stored version is newer, and retry the load once when a foreign lock is fresh.
- **Fixed `BOT_SEEN` ignores the target's ping (`Bots.lua:242`):** goal 4's "a touch a person can see" fails for laggy players. -> Use `seen = now - (target:GetNetworkPing() + SNAPSHOT_DELAY)`, clamped to the history, so the bot is judged where that person's screen showed it.
- **Double spin:** `spinning` is set only when the reply lands (`Locker.lua:93`). Two taps more than 0.25 s apart send two spins and the reel animations overlap. -> Set `spinning = true` on the press and clear it on the reply or a note.

CONSIDER (fine but could change; why; how):
- **Music in the gaps:** a track change every ~100 s round, with a 6 s menu track between rounds, may grate. -> Keep "match" through the gaps and use "menu" only in the lobby, the podium and the title.
- **Results card points:** the "+N" is recomputed on the client with `points(i, n)` (`Board.lua:89`), which disagrees with the server when a round ends with no winner. -> Send the per-round points in `Session.view`.
- **Five or more people:** the strip and the podium show only 4 rows, so the person waiting a round can vanish from the board. -> Add a "waiting: name" line.
- **Level-ups are invisible:** `levels` is sent but never celebrated. -> Pop "LEVEL n" on the podium card.
- **Economy pace:** about 35-60 coins a match against 100 a spin is roughly one spin per 2-3 matches. Danzo should judge after the kids play.
- **Doc length:** `docs/DESIGN.md` at 308 lines is over the soft limit; split §6 when it is next touched.

UNCERTAIN (could not verify):
- Everything on screen: the title, cards, locker, wheel, stage, bloom, trails, glows, shake and name tags. Studio rendered 0 frames.
- Whether the three APM music ids load and suit the game, and whether the volumes balance.
- Whether a person can catch a bot at 0.93 speed, and escape one. Danzo should try three solo matches on keyboard and on the phone emulator.
- Whether a `Trail` (`FaceCamera`) streaks across the screen when a runner teleports to the start line or a bot resets after falling out.
- Real DataStore save and load, BindToClose timing, and two people in one match.
- The full podium and coin payout this session. I only saw lobby, round 1, sit and rejoin; the full match is from the builder's log.

## Builder decisions

**FIX, all seven done:**
- Text on a phone: `Ui.scale` never under 0.75; on a short screen the design space is shorter (`Ui.height`,
  `Ui.compact`) and the title, the how-to cards and the locker lay out for it (smaller logo, tighter buttons, the
  grid's columns from its width); small text raised (rarity 12 -> 14, odds 14 -> 15, how-to body 16 -> 17, names 15 -> 16).
- Name tags: their own part above the head, 15 px tall on any screen (`Look.nameHeight`); the IT marker lifted by
  the same height. A SurfaceGui, not the BillboardGui suggested: a BillboardGui never drew in Studio (H6).
- HUD and Board overlap: the HUD is on a scaled root (`Ui.scaled`); the holder's count sits lower on a compact
  screen; the Board's intro is only "ROUND n", placed between the HUD's status lines and the count.
- The saved flag: the wallet shows "PROGRESS IS NOT SAVING RIGHT NOW" when `saved == false`.
- DataStore: a lock taken in the load's `UpdateAsync` (a fresh foreign lock is waited out), a revision on every
  save (a newer one in the store, or another server's lock, refuses the write and stops this session saving).
- `BOT_SEEN`: per target, `SNAPSHOT_DELAY + that player's ping + 0.04`, at most 0.4 s; a bot target is this frame.
- Double spin: `spinning` set on the press, cleared when the reel lands or the server refuses.

**CONSIDER:**
- Music in the gaps: done (the match track holds through "gap").
- Results card points: done (`Session.lastPts` in the view; the test pins the no-winner round at 1 and 0).
- Level-ups: done ("LEVEL n!" on the podium card).
- How-to cards skipped when the profile is late: done (a missing profile counts as a new player).
- A trail across a teleport (from UNCERTAIN): done (`Fx.wear` clears the trail when a runner moves 12 studs in a frame).
- Deferred: five or more people on the board (the place's Max Players is 4: session.md §1); the economy's pace
  (Danzo's, after the kids play); `docs/DESIGN.md` at 309 lines (split §6 when it is next touched, → G3).

**PRESERVE:** all six untouched in substance. The bots still run the real `Movement` through rollouts (H32 added
the grapple, hazards and per-bot skill the same way: plans and scoring, no cheats); bots still never play alone;
a failed load is still never saved; the remotes are unchanged.

**Also in this commit, not from the review (Danzo's ask mid-round, H32):** bots that pass for people: bots.md §7.
