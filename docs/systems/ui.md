# The menu, the cards, sound, punch and the stage's look (H31)

**Created:** 2026-11-16 (H31). Everything a player sees and hears that is not the move rules: what makes it read as
a finished game. The flow it shows is [session.md](session.md); the HUD's fuse line is still [tag.md](tag.md) §6.
Rules: `docs/DESIGN.md` §3 2 (the fuse is readable), 21 (juice), 22-23 (mobile), 34 (celebrate the winner), §6.3
(art direction). **None of this has been LOOKED at yet**: it was built with the PC on its lock screen (Studio drew 0
frames a second), checked for errors by script only (§8). Danzo's eyes and ears are the first test.

## 1. The theme: "glowing graphite" (§6.3, a trial pick, Danzo's to overrule)

Graphite panels with a thin lit edge, neon accents, heavy italic headlines. Cyan = you and "go", ember = the fuse and
"it", gold = coins, lime = pads and alive, pale blue = ghosts. `client/Ui.lua` is the kit (`Ui.C` the colours,
`Ui.panel`, `Ui.button`, `Ui.label`, `Ui.coin`, `Ui.pop`); every screen is laid out in design pixels and scaled to
the screen (`Ui.scaled`, `Ui.screen`). The scale never drops under 0.75 (QA round 1: a plain height / 720 made a
phone's text 8 points): on a short screen the design space is simply shorter (`Ui.height` ~520 instead of 720,
`Ui.compact`) and the title, the how-to cards and the locker lay themselves out for it (a smaller logo, tighter
buttons, fewer grid columns). The HUD (`client/Hud.lua`) is in the same scaled space. Nothing sits in the lower
middle (rule 23). Built from Roblox's own UI objects and parts: **no art upload was needed**.

The design canvas (the four screens as specified, with the real runner art; made with /design):
https://claude.ai/artifact/EaHsRizvdSQ6MFLRejSUiw

A trap worth knowing (→ A8): a `UIGradient` on a `TextButton` tints the button's own text. `Ui.button` keeps its
words in a child label (`Ui.setText`).

## 2. The menu (`client/Menu.lua`)

- **The title** (where a player lands, over the live map through the spectator camera): ROTAG, the tagline, PLAY,
  LOCKER, SPIN THE WHEEL, HOW TO PLAY, a status line (the lobby's countdown, or the round in progress), and SIT OUT
  AND WATCH while you are in. Enter / gamepad A is PLAY.
- **A new player's first PLAY** shows the how-to cards first, once (rule 18): the fuse, the moves, orbs, ghosts, the
  match, and the controls for the device in hand.
- **In play:** a MENU pill by the wallet (M / Start too) brings the title back; the game goes on behind it.
- **The wallet:** coins and level, top right; the coin count pops when it grows; "PROGRESS IS NOT SAVING RIGHT
  NOW" under it when the server could not load or keep the save (so nobody spends coins that will vanish).
- The title returns by itself if the server says you are out (and you did not just ask to play).

## 3. The locker and the wheel (`client/Locker.lua`)

Four tabs (trail, glow, burn-out, title); each item a card with its colours, its rarity, and one button: WEARING,
WEAR, BUY n, or WHEEL ONLY. The wheel: SPIN for 100, a reel of names that slows and lands on what the server
already rolled, the odds printed under it, "already yours: +n coins back" for a duplicate. The purse and the cards
change only when the server's answer arrives.

## 4. The scoreboard and the cards (`client/Board.lua`)

- **The strip** (top left, during a match): ROUND n / 3, each runner's name and points; a dot per runner (ember:
  it, lime: alive, pale: a ghost); you in cyan.
- **The lobby:** GET READY and "match starts in n", then a 3-2-1.
- **A round begins:** ROUND n (or FINAL ROUND) for two seconds, over the HUD's own "who is it" and count.
- **The gap:** a results card, the placing with what each place scored.
- **The podium:** who won the match, the standings, "+n coins", "LEVEL n!" when the coins reached one, the next
  match's countdown; confetti and a fanfare if it was you.
- `client/Hud.lua`: the fuse readout now sits on a dark pill with a bar that burns down and reddens; the HUD's old
  "x wins the round" line is gone (the cards say it); the IT marker sits half a stud higher, clear of the name tags.

## 5. Sound (`client/Audio.lua`)

- **Effects** are Roblox's own built-in sounds (`rbxasset://sounds/...`, shipped with every client: no upload, no
  licence, they always load; each was checked to load in Studio), shaped by pitch: jump, double jump, wall kick,
  landing, dash, pad, grapple, tag (and a deeper thump when it is you), burn-out, orb, ice, trap, crate, hex,
  placing, the walls opening, buttons, the countdown, the wheel's ticks and prize, coins, the fanfare.
- **The fuse beeps** under `IGNITE_AT`, faster and higher toward zero, louder when it is yours (rule 2).
- **Music** follows the match: the menu's track in the lobby and on the podium, a driving track through the rounds
  and the gaps between them, a pressure track once the end phase is on. Three tracks from Roblox's licensed APM library (free for every
  experience), picked by their descriptions: **the builder could not hear them.** The ids are the `MUSIC` table at
  the top of `client/Audio.lua`; swap freely.

## 6. Punch and cosmetics (`client/Fx.lua`, `client/Present.lua`)

- **Shake** (`Fx.shake`, light on purpose, rule 21): a tag in it 0.55, a burn-out 0.8, a hard landing 0.18; added
  to the camera's position for that frame only, never to its follow.
- **A tag:** a ring and sparks on the victim, the screen's edges flash ember if you are in it. **A burn-out:** the
  runner's own burn-out style over the flash. **Moves:** dust on a ground jump, a dash and a hard landing; a ring
  under a double jump.
- **Name tags:** every runner's name over its head in its seat's colour (cyan, lime, pink, gold; YOU on your own),
  so four identical figures are four people. Its own thin part above the head, 15 pixels tall on any screen
  (`Look:name`, `Look.nameHeight`; QA round 1: on the sprite's canvas it was 4.6 points on a phone); the IT marker
  sits clear above it. Bots are named like people (bots.md §7).
- **Cosmetics** (`Fx.wear`, from `Flow.worn`): a trail (a ribbon behind the runner; "Prism" cycles), a glow (a
  coloured light and a few motes, and the sprite's rim in that colour at the lowest priority, under freeze, ignition
  and boost), a burn-out style (confetti, ink, shards, nova, coins), a title. A ghost wears none: rule 37's pale
  runner must read as a ghost. A cosmetic never changes what anyone can see of a hitbox.

`client/Present.lua` is the glue: it starts all of the above and, each frame, picks the music, beeps the fuse,
ticks the countdown, and puts each runner's name, trail and glow on its sprite. `client/Client.client.lua` gained
only the calls into it, the camera's shake offset and the spectator camera (no body: follow the holder, else the pack).

## 7. The stage (`server/Stage.lua`)

Built once at boot from the map data: every block near-black graphite with a lit strip along its top edge (a deck
reads by its edge), a dusk backdrop with ruled lines (the sketchbook) and a far skyline with a few lit windows,
darkness under the floor, night lighting with bloom (the anchors, pads, walls, embers and trails glow) and a slight
grade. Nothing a runner collides with or a probe hits; `shared/Maps` and `maps.test` never read it. The runner (grey,
inked, cyan accents) is lighter than the backdrop and the blocks are darker: the figure should read on both.

## 8. What was checked, and what was not

Checked by script in Studio Play with the PC locked (2026-11-16): every module requires and starts; 1200 frames of
`Present.frame` driven by hand with the live Session and MatchState ran with no error; every `Fx.burst` style, a
verdict, a burn-out, a wall kill and a hex ran; the menu and the board held the right words (`BACK TO THE GAME`,
`Match in progress · round 2 of 3`, `ROUND 2 / 3 | Dash 4 | Pixel 2 | Bolt 1`). All 26 built-in effects load.

**Not checked: how any of it LOOKS or SOUNDS.** Layout, sizes, colours against the stage, the bloom's strength,
the trail's width, the shake's size, the three music picks, the phone layout. First thing with the PC unlocked.

## Expansion: deficits at scale

- **A window resized in play** keeps the layout it started with (the scale follows, the compact layout does not).
- **No settings** (music and effects volume, shake off). One panel in the menu; `Audio` has one SoundGroup ready.
- **No art for the UI yet** (a logo, item icons in the locker, a bomb for the fuse). The kit takes images the day
  the sheet has them (`Sprites.Has`).
