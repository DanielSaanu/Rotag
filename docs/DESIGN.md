# Parkour Tag (working title): Game Design Notes

_Last updated: 9 Oct 2026, brainstorm and research phase_

This is the design contract. Code and art are judged against it. A change to §2 (locked decisions) or §3 (the
adopted rules) is escalation trigger 1 (`CLAUDE.md`). Portable principles that are not about this game live in
[`PRINCIPLES.md`](PRINCIPLES.md).

---

## 1. Concept

A **2D multiplayer parkour tag game on Roblox**. Four players race around a side-on map that is bigger than the screen, using flashy parkour movement to escape or chase. Whoever is "it" carries a **hot-potato fuse**. When it runs out, they're eliminated and come back as a **ghost** who can sabotage the living players and earn a way back in.

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
- If the fuse hits 0, the holder is **eliminated**.
- The fuse shrinks across the match, so tension rises. Even weak players always get a chance to fight back.

### Elimination: ghosts
- Eliminated players become **ghosts** who can sabotage the living (details still open).
- Ghosts should want their turn back, which keeps them engaged until the end.

### Crates and obstacles
- Random abilities come from **crates**.
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

1. **Ghost rules.** What they can do, cooldowns, and how they earn a respawn. Leading idea: the Crawl model, where the ghost whose sabotage gets the fuse holder eliminated respawns.
2. **Crate ability list.** Draft ideas:
   - Ink Splat: slippery floor
   - Sketch Wall: quick barrier
   - Eraser Blink: short teleport
   - Decoy Doodle: fake copy runs the other way
   - Graphite Hook+: longer grapple for 10 s
3. **Art direction.** Pure pencil/graphite, Tron-style neon, or **glowing graphite**: pencil sketches with glowing trails.
   *Partly answered 2026-10-10 (Danzo):* characters are smooth, high-resolution 2D figures (vector art, 128 px per
   tile), not pixel art, so they read as drawn figures living in a 3D stage. The theme (graphite vs neon) is still open;
   the current runner is inked graphite with one neon accent (visor, scarf), which fits any of the three.
4. **Match structure.** Best of 3 or 5, and how scoring works.
5. **Monetisation.** Cosmetics only: trails, skins, tag effects, emotes, fuse/bomb skins. Plus possibly a VIP or private servers. Kid-friendly and fair.
6. **Name.**
7. **Bots.** Scope for a basic bot that chases, flees and uses abilities.

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
