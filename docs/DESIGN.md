# Parkour Tag (working title): Game Design Notes

_Last updated: 19 Oct 2026 (H16: ghosts v2, orbs and abilities adopted, §3 rules 37-51; §6.2 resolved; §6.8 maps added. H15: §6.1)_

This is the design contract. Code and art are judged against it. A change to §2 (locked decisions) or §3 (the
adopted rules) is escalation trigger 1 (`CLAUDE.md`). Portable principles that are not about this game live in
[`PRINCIPLES.md`](PRINCIPLES.md).

---

## 1. Concept

A **2D multiplayer parkour tag game on Roblox**. Four players race around a side-on map that is bigger than the screen, using flashy parkour movement to escape or chase. Whoever is "it" carries a **hot-potato fuse**. When it runs out, they're eliminated and come back as a **ghost** who keeps shaping the round with placed parts and pickups; the next round is their way back.

**Pillars**
- **Movement first.** Moving should be fun on an empty screen, with moves that chain and keep momentum.
- **Constant tension.** The carry-over fuse means being "it" is never hopeless, and rounds tighten over time.
- **Nobody sits out.** Eliminated players stay in the game as ghosts.
- **Eye-catching.** Hand-drawn, anime-energy animation and pencil-art identity.
- **Short sessions.** Matches of about 2–3 minutes suit mobile-heavy players.

---

## 2. Locked decisions

### Platform
- **Roblox.** Multiplayer is essential there.
- 2D is achieved with a **side-on locked camera over 3D parts**, not UI-based 2D.
- The character is constrained to one plane.

### Players and map
- **4 players** per match.
- Map **larger than the screen**. Each player has their own camera, with **off-screen arrows** pointing to the other players.
- Collision between players: **pass-through for all players**, recommended 2026-10-11, confirmed by Danzo 2026-10-12 (ran through a solid stand-in runner in Play: no stop, shove or wall-kick) ([players.md](systems/players.md) §2).

### Movement kit (everyone gets every move from the start)
- Run
- Wall-jump
- Double jump
- Dash
- Grapple
- Boost pads on the map

Moves should hand speed off to each other:
1. Run builds speed.
2. Grapple swing releases you with that speed.
3. Dash redirects it.
4. Wall-run or wall-kick banks it.
5. Double jump is the save.

### Mode: classic tag with a hot-potato fuse
- The first "it" starts with a **45 s fuse**.
- On a tag, the **remaining time + 5 s** passes to the new holder. Example: tagging someone with 20 s left hands them 25 s.
  *Trial, Danzo 2026-10-11:* the bonus is **+2 s** for now (`Config.FUSE_PASS_BONUS`), after the first solo Play. If it
  stays, this line changes to +2; the rule (remaining + bonus) does not.
  *Cap (proposed by the H6 agent, kept by Danzo 2026-10-11):* a pass never lifts the fuse above the fuse that life started with (45, then 35, 25 after
  eliminations), so quick passes cannot stretch a round (`Tag.pass`, [tag.md](systems/tag.md) §5).
- If the fuse hits 0, the holder is **eliminated**.
- The fuse shrinks across the match, so tension rises. Even weak players always get a chance to fight back.

### Elimination: ghosts
- Eliminated players become **ghosts** who shape the round for or against the living (rules 37-51, ghosts v2 adopted
  2026-10-19, H16; [ghosts-v2-proposal.md](systems/ghosts-v2-proposal.md)).
- Ghosts stay out for the round; the next round is their way back (Danzo, 2026-10-19, H16: replaces "ghosts should
  want their turn back" and H15's comeback).

### Crates and obstacles
- Random abilities come from **crates**. *H16 (2026-10-19): the pickups are **orbs** at fixed map spots (rule 42); the crate
  is now one of the items.*
- Physical obstacles (breakable crates, hazards) are part of the maps.

---

## 3. Design rules from research (adopt these)

### Tag and fuse
1. **No tag-backs.** Freeze the new holder for 1–2 s, or give the passer about 1 s of immunity (Gorilla Tag uses a 5 s freeze).
2. **Make the fuse readable.** The bomb grows, beeps faster and glows, and the **+5 s** shows on screen at every pass. (When a Mario Party sequel toned down its Hot Bob-omb warnings, the timing became harder to read.)
3. **Force an ending.** At the final 2 players, shrink the map or speed up the fuse (Bomberman "Hurry Up", TNT Tag deathmatch). Otherwise the final duel drags.
4. **Ramp the chaser.** "It" gets faster the longer a chase lasts, and the boost resets on a tag. Dead by Daylight's Bloodlust works this way. It stops infinite looping.
5. **Pick the starting holder fairly**, by rotation or by the previous round's leader. Never by pure random.
6. **Lag-fair tagging.** Check overlap on the client, confirm it on the server, then play a catch-up animation so it looks fair on both screens. Don't rely on Roblox `Touched` alone.

### Ghosts
7. **Ghosts need real power and a way back.**
   - Crawl: dead players possess traps, and the one who lands the kill swaps in.
   - Bomberman: eliminated players throw bombs from the arena edge and can return.
8. **Limit ghosts.** Sabotage runs on cooldowns. Ghosts shouldn't be able to gang up on one player or leak information.
9. **Option:** living players can help free ghosts, like Flee the Facility's rescue pods.

### Crates and items
10. **Weight crates toward the losing player or the fuse holder** (Mario Kart style).
11. **No stun or disable longer than about 1 s.** No instant-kill items. Long stuns and rare overpowered drops are the top complaint about randomness.
12. **Every ability has a distinct effect and a distinct look.** No near-duplicates.
13. **Optional toggles** for items or modifiers let competitive players play "vanilla" (TowerFall, Duck Game).

### Movement and game feel
14. **Hidden forgiveness.** Celeste's exact values:
    - Coyote time about 0.1 s
    - Jump buffer about 0.08 s
    - Variable jump hold window 0.2 s
    - Corner correction up to 4 px
    - Wall-jump works within 2–3 px of a wall
    - Half gravity at the apex while jump is held
15. **Refresh on contact.** Dash and double jump come back on landing, wall touch, boost pad or bouncing off a player. This is what makes moves chain.
    *Amendment, Danzo 2026-10-11 (H10, replacing H9's recharge-after-air rule the same day):* a dash started on the floor ends at run speed instead of the air dash's end speed, so a floor chain gains only the burst itself. Air dash, refresh on contact and dash-into-jump are unchanged. The chain is still a little faster than a run; the cooldown is the knob (QA rounds 1–2).
16. **Keep speed between moves.** Dash into jump keeps the speed, platform momentum carries into the jump, and wall-climb leads back into a run. Pizza Tower's open moveset beat a restricted one in testing.
17. **Grapple rules:**
    - Only clearly marked, colour-coded anchors.
    - Aim assist to the nearest anchor.
    - Release keeps swing speed, with a small optional release boost.
    - Never target off-screen anchors. Missed swings frustrate players (Grapple Dog, Parkour Reborn).
18. **Easy to start, hard to master.** Casual players do fine with run and jump alone. Hidden speed tech lets experts break routes. A steep skill floor killed Rumbleverse and keeps Parkour Reborn small.
19. **Mistakes cost little.** After a hit or fall, speed rebuilds fast (Pizza Tower).
20. **Never use floaty or delayed controls.** MultiVersus lost players when its movement felt "underwater".
21. **Juice:**
    - Squash and stretch on take-off and landing
    - Smear frames on dash
    - Dust and speed lines
    - 50–100 ms hit-stop on tags
    - Light screen shake
    - Camera leads ahead at speed

### Mobile and controls (about 80% of Roblox players are on mobile)
22. **4 action buttons at most.**
    - Wall-jump and double jump share the jump button.
    - Dash and grapple are single taps, or grapple is contextual.
23. Keep the lower-middle screen clear. Buttons at least 44 px. Make timing windows slightly wider on mobile.
24. Make sure movement scripts read the mobile joystick, not just the keyboard. Test on a phone early.

### Maps
25. **Vertical loops with 2–3 exits each.** Keep walls within easy reach, roughly 5 m in UTG terms.
26. **Avoid open centres and dead ends.** Break infinite loops with one-way drops.
27. **Short hiding spots only.** Camping is the top tag-game complaint.
28. **Visible high and low routes.** Fast routes reward skill; mistakes drop you to slower routes (classic Sonic).
29. **Colour-code** grapple points, boost pads and hazards.
30. **Get variety from rules, not just maps.** Add a random modifier each round, like UTG's Wheel of Misfortune or Tower of Hell's mutators. Maps should differ in layout, not just art.

### Retention and structure
31. **Bots, and make 2 players fun.** Needing a full lobby is the number-one killer of indie multiplayer games (Gun Monkeys, Gang Beasts, Knockout City).
32. **Have a solo option**: bot practice or time trials on the parkour routes.
33. **Score across a session** (best of 3 or 5) so one bad round doesn't decide everything.
34. **Celebrate the winner** with a pose, emote or effect. Rumbleverse's flat ending was a complaint.
35. **Change the loop over time.** Roblox games lose players between sessions 2 and 5 when the loop never changes. New modifiers and modes matter more than new cosmetics.
36. **Never lock moves or modes behind a grind or shop.** This was Vector's main complaint. Progression stays cosmetic.

### Ghosts, pickups and abilities, adopted 2026-10-19 (H16, replacing H15's rules 37-41)

*Danzo picked "orbs for everyone" and answered every question: no comeback; grapple for the living only; trap 1 s
("fast paced"), rule 11 unchanged; the dash goes over traps, never through crates; hex -3 s; separate ghost orbs; plus
ignition and end-phase speed. Trial numbers, tuned by hand. Spec and build order:
[ghosts-v2-proposal.md](systems/ghosts-v2-proposal.md). H15's spook-and-mark rules: [ghosts.md](systems/ghosts.md) (superseded).*

37. **A ghost is a pale, see-through runner:** run, jump, double and wall jump, dash; never the grapple. It passes
    through runners and items, collides with the map and fixtures, cannot tag or be tagged.
38. **Ghosts stay out for the round.** No mark, no comeback. Every elimination still shrinks the next fuse.
39. **Ghosts take ghost orbs** (their own orb type, at their own spots) and roll the ghost pool: fixture, boost pad,
    boost grant, crate, bear trap, ice beam, and a rare hex. They place parts and aim abilities for or against anyone.
40. **The hex is the only fuse drain:** rare, -3 s on the holder by a hex-holding ghost's touch, confirmed like a tag
    (rule 6); after any hex a shared 6 s ward, and none while the holder is frozen.
41. **No ganging up (rule 8):** a runner hit by a ghost's aimed ability is warded from every ghost's aimed abilities
    for 6 s. Every held item shows over its holder's head; ghost arrows stay hollow.
42. **Orbs:** living orbs at fixed map spots, first at 0:05, respawn 10 s; ghost orbs at separate spots, respawn
    10 s / (1 + 0.5 x ghosts). Touch one with an empty slot and the server rolls your pool. One slot; Use fires or places it.
43. **The living pools:** runners roll escape items (crate, trap, ice beam); the holder rolls the ice beam first (rule 10).
44. **Holds** (crate stumble 0.7 s at half speed, no steer, jump, dash or item; ice freeze 1 s, sliding; bear trap
    1 s or 3 presses; the tag freeze) never stop a tag, never chain (0.5 s immunity after one) and block starting an
    item; an item started before a hold goes off. Rule 11 stands as written.
45. **Dash i-frames:** the first 0.2 s of a dash dodges aimed abilities (ice beam, hex) and carries you over a bear
    trap; never through a crate (jump it), never a tag.
46. **The boost grant** (+15% run speed, 5 s) never stacks with the chaser ramp: on the holder, boost = max(ramp, grant).
47. **Placement:** ghost parts go where the ghost stands, rotated on the grapple input, in empty space, on its
    screen, at least 1 tile from any living runner, never in a keep-clear zone; at most 3 live fixtures per ghost.
48. **Maps:** every exit and corridor is a keep-clear zone nothing may be placed in; every area has 2+ exits; 3-4
    maps that differ in layout (§6.8).
49. **Toggle (rule 13):** "vanilla" turns orbs off; ghosts then hold a hex every 20 s and nothing else.
50. **Ignition (rule 2):** from `IGNITE_AT` (trial 10 s) left on the fuse the holder is visibly ignited, growing as it
    burns, drawn by every client from the replicated fuse; elimination plays a burn-out. Ignitions and burn-outs are
    the first cosmetic slot (§6.5).
51. **End-phase speed (rule 3):** only in the end phase (the final two living, or a round past `END_PHASE_AFTER`),
    every living runner's top speed is multiplied by `END_PHASE_SPEED` (trial 1.1), alongside rule 3's map shrink;
    the ramp and the grant apply on top. Never during a normal fuse.

---

## 4. Reference games: what to take from each

| Game | Take | Avoid |
|---|---|---|
| **SpeedRunners** | Grapple and boost kit, items that target leaders, a shrinking screen to force an end | Steep learning curve, weak tutorial, overlong stuns |
| **Ultimate Chicken Horse** | Late scoring redesign added comeback points after trailing players checked out | Repetition after a few hours |
| **TowerFall** | One input with multiple uses (dodge), cosmetic-only characters for balance, trails for readability | — |
| **Duck Game / Stick Fight** | Rounds that last seconds make dying funny, not painful | Dominant weapons, RNG drops that feel unfair |
| **Crawl** | Ghost who lands the kill swaps back in. Best model for our ghosts | — |
| **Super Bomberman** | Eliminated players attack from the arena edge; Hurry Up wall | — |
| **Hypixel TNT Tag** | Hot-potato tag, explosion hits nearby players, pickups for runners | — |
| **Gorilla Tag** | Freeze on tag, tagger boost that scales with runners left | Random boosts feel unfair, lag favours the tagger |
| **Untitled Tag Game (Roblox)** | Wall-run with no extra button, slide burst, 13 modes plus a random modifier wheel, vertical maps | Randomness players can't control; peaked and declined |
| **Flee the Facility** | Chaser handicaps (slowdown after jumping, stun on hit), rescuable pods | Chaser camping the pods |
| **Mario Kart Shine Thief** | Personal countdown carries over; the holder drives slower | — |
| **Celeste** | Exact forgiveness values (see rule 14) | — |
| **Pizza Tower** | Earned speed, moves that chain back into the run, cheap mistakes, A rank easy and P rank hard | Pixel-precise jumps made playtesters quit |
| **Grapple Dog** | Colour-coded anchors, release angle as a skill | Missed swings frustrate |
| **Vector** | Swipe-based mobile parkour, flashy trick animations | Tricks locked behind a shop, repetitive |
| **Stickman Hook** | Tap and release grapple: tiny floor, real depth | — |
| **Parkour / Parkour Reborn (Roblox)** | Deep movement builds a loyal core | Narrow grapple timing, beginner-unfriendly, small audience |

---

## 5. Gap in the market

No 2D, side-on parkour tag game has made it big on Roblox. The few 2D projects on the platform stayed small, mostly because of controls, pacing and mobile issues. The space is **open but untested**.

---

## 6. Open questions (next steps, in order)

1. ~~**Ghost rules.**~~ **Resolved 2026-10-14 (H15), superseded 2026-10-19 (H16, rules 37-51):** H15's rules 37-41 were: ghosts spook "it" by touch (-3 s, 8 s
   cooldown, a shared 6 s ward); the latest spooker holds the mark and swaps back in if the fuse runs out, once per
   player per round. Detail: [ghosts.md](systems/ghosts.md). (Kept as item 1 so "§6.2" and later citations still
   resolve; the open list now starts at 3.)
2. ~~**Crate ability list.**~~ **Resolved 2026-10-19 (H16):** rules 39-49: crate, bear trap, ice beam (living and
   ghosts), hex, boost grant, boost pad, fixture (ghosts); the grapple stays a kit move. Old drafts: Sketch Wall became
   the fixture; Ink Splat dropped (a slip the victim's client applies); Eraser Blink dropped (a teleport fights the
   speed check); Decoy Doodle and Graphite Hook+ parked.
3. **Art direction.** Pure pencil/graphite, Tron-style neon, or **glowing graphite**: pencil sketches with glowing trails.
   *Partly answered 2026-10-10 (Danzo):* characters are smooth, high-resolution 2D figures (vector art, 128 px per
   tile), not pixel art, so they read as drawn figures living in a 3D stage. The theme (graphite vs neon) is still open;
   the current runner is inked graphite with one neon accent (visor, scarf), which fits any of the three.
4. **Match structure.** Best of 3 or 5, and how scoring works.
5. **Monetisation.** Cosmetics only: trails, skins, tag effects, emotes, fuse/bomb skins, ignitions and burn-outs (rule 50). Plus possibly a VIP or private servers. Kid-friendly and fair.
6. **Name.**
7. **Bots.** Scope for a basic bot that chases, flees and uses abilities.
8. **Maps** (H16). 3-4 from the start, differing in layout (rule 48): Tower (vertical), Yard (open), Warren (maze),
   Rooftops (gaps); feels in [ghosts-v2-proposal.md](systems/ghosts-v2-proposal.md) §6. Open: which first, and size.

---

## 7. Earlier ideas (parked, may feed in later)

- **Tron-style trails.** Players leave glowing graphite lines that others can grapple onto or crash into.
- **Pencil-world mechanics.** Grapple only onto inked surfaces; smudged surfaces are slippery; erase-hop; sketch platforms.
- **Other modes for later:**
  - One chaser vs three runners (asymmetric)
  - Infection
  - Race

---

## Sources

- SpeedRunners reviews: https://vaporlens.app/app/207140/speed_runners.md
- Ultimate Chicken Horse design change: https://www.cleverendeavourgames.com/blog/2015/11/5/dont-fear-game-design-change
- TowerFall design: https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community
- Crawl review: https://www.pcgamer.com/crawl-review-early-access
- Runbow design: https://gamedeveloper.com/design/building-i-runbow-i-the-first-nine-player-wii-u-platformer
- Hypixel TNT Tag: https://hypixel.fandom.com/wiki/TNT_Tag
- Gorilla Tag Infection: https://gorillatag.fandom.com/wiki/Infection
- Untitled Tag Game guide: https://sportskeeda.com/roblox-news/untitled-tag-game-a-definitive-guide
- Untitled Tag Game stats: https://rowatcher.com/games/4864117649/untitled-tag-game
- Flee the Facility Beast: https://flee-the-facility.fandom.com/wiki/Beast
- Hot Bob-omb: https://www.mariowiki.com/Hot_Bob-omb
- Shine Thief: https://www.mariowiki.com/Shine_Thief
- Dead by Daylight Bloodlust: https://deadbydaylight.wiki.gg/wiki/Bloodlust
- Among Us ghosts: https://among-us.fandom.com/wiki/Guide:Ghost
- Celeste forgiveness: https://maddymakesgames.com/articles/celeste_and_forgiveness/
- Celeste source: https://github.com/NoelFB/Celeste
- Pizza Tower implementation: https://gamedeveloper.com/design/how-speedy-implementation-high-paced-platformer-pizza-tower
- Grapple Dog: https://wireframe.raspberrypi.com/articles/getting-into-the-swing-grapple-dog
- Neon White design: https://www.gamedeveloper.com/road-to-igf-2023/-neon-white-and-designing-for-player-creativity
- Roblox tag lag: https://devforum.roblox.com/t/player-lag-when-playing-tag/3532505
- Roblox side-scroller movement: https://devforum.roblox.com/t/how-to-make-player-move-like-a-2d-sidescroller/2986215
- 80% of Roblox users on mobile: https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue
- Roblox session 2–5 drop-off: https://rowatcher.com/news/why-your-roblox-game-bleeds-players-between-sessions-2-and-5
- Toto Temple Deluxe postmortem: https://juicybeast.com/?p=4097
- Gun Monkeys / indie multiplayer: https://www.mcvuk.com/development/why-indies-probably-shouldnt-make-a-multiplayer-game
- Why MultiVersus failed: https://gamedesignskills.com/game-development/why-did-multiversus-fail/
- Rumbleverse review: https://shacknews.com/article/131845/rumbleverse-review-40-zangiefs-walk-into-a-town
