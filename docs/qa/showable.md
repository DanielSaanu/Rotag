# QA goals: the showable game (a match with a menu, bots, coins and cosmetics, sound and punch)

Branch: `claude/friendly-hawking-74891i`. Handoff H31 (2026-11-16). Danzo's ask: "take what we have built so far and
complete the game to a finished showable state so I can post it in a discord server and have the kids play it and
give me feedback ... a completed game as the end product with a menu screen and all and between-game setup so it's
not just endless rounds, I want music ... run a /qa-loop with the goal of making it as fun as possible with the
intention held to monetise ... space for upgrades and skins". System docs: `docs/systems/session.md` (the match,
profiles, the shop), `docs/systems/bots.md`, `docs/systems/ui.md` (menu, cards, sound, punch, the stage). Design:
`docs/DESIGN.md` §3 rules 2, 21, 31-36, §6.3-§6.5, §6.7. Everything in the earlier summaries' PRESERVED lists
(`docs/qa/*-summary.md`) must still hold: the move rules, the tag, items, ghosts, the walls and the grapple were not
meant to change.

The question for this loop: **would a kid who clicks the Discord link understand it in a minute, have fun in the first
match (alone with bots or with friends), and want another match? And is there an honest, fair place for skins and
upgrades to live?**

## Goals

1. **A start.** A player lands on a title screen over the live map, not in a round. PLAY puts them in; a new
   player sees how to play first, once. Nothing is handed to someone who has not pressed PLAY (no fuse, no seat).
2. **A match, not endless rounds.** A lobby that counts down, three rounds each followed by a results card, a
   podium with a winner, then the lobby again. Placement points 4 / 2 / 1 / 0; the scoreboard is on screen all match.
3. **Never an empty room (rule 31).** One player gets a full four-runner round: bots fill the seats. A bot uses the
   real move rules (it can do nothing a player cannot), chases, flees, takes orbs, uses items, haunts as a ghost,
   minds the walls, and is beatable: a person who runs clean gets away from one and catches one.
4. **Fair bots (trigger 3).** A bot tags only on a touch a person can see; it gets no lag allowance; it never plays
   alone or takes a person's seat.
5. **Something to earn, nothing to buy power with (rule 36).** Coins from playing; a saved profile; a locker, a shop
   and a wheel for trails, glows, burn-outs and titles. No item changes a move, a speed or a hitbox. The wheel's
   odds are printed; its result is rolled on the server. A failed load never overwrites a save.
6. **It sounds like a game.** An effect on every move, hit, pickup and button; a fuse that beeps faster as it runs
   down; music that follows the match (menu, round, end phase).
7. **It hits (rule 21).** A tag, a burn-out and a hard landing are felt (shake, flash, sparks) without hiding the
   figure or the fuse; light, as the rule says.
8. **Four figures are four people.** Names over heads in seat colours; you can find yourself at a glance.
9. **It looks like one game.** The stage, the HUD and the menu share one look; the runner reads against the stage;
   the fuse, the anchors, the pads and the walls still read (rules 2, 17, 29).
10. **A phone.** The menu, the cards and the scoreboard fit a phone-shaped screen; the lower middle stays clear
    (rule 23).
11. **Nothing broke.** `npm test` and `npm run lint:luau` green; the Rojo tree only grew; `rojo build` succeeds; the
    line ceiling holds; `shared/` stays pure.

## What the builder saw, and did not

Studio, 2026-11-16, **with the PC on its lock screen** (Studio rendered 0 frames a second; → learnings T17):

- **Seen (server Output and scripts):** PLAY through the Studio hook, three bots seated, a whole three-round match
  to the podium with the player AFK (bots tagging each other and the player, orbs, traps, crates, ice, fixtures,
  pads, grants, the end phase, the walls with no bot flapping across them after the fix), the scores adding up, 10
  coins paid, the shop's spin, buy and refusals; 1200 hand-driven frames of the menu, the cards and the effects with
  no error and the right words in the labels; all 26 built-in sound effects load.
- **NOT seen or heard:** anything on a screen. The title, the cards, the locker, the wheel, the stage, the bloom,
  the trails and glows, the shake, the name tags, the music (three tracks picked by description only), a phone
  layout, a bot played against by hand, a real DataStore save and load, two people in one match.

**The reviewer's first job, if Studio is drawing (check: a capture returns at once, or count `RenderStepped`), is to
LOOK**: capture the title, a round against the bots, a results card, the podium, the locker and the wheel, and judge
goals 6-10 from what is there. If the PC is still locked, say so under UNCERTAIN and review the rest by code, tests
and server Output; the Studio-only hooks are `player:SetAttribute("RotagMenu", "play" | "sit")` and
`player:SetAttribute("RotagShop", "spin" | "buy:<id>" | "equip:<id>")` from the Server datamodel.

## Out of scope

More maps and a map rotation; round modifiers and new modes (rule 35); selling anything for Robux; skins that
recolour the runner itself (needs an accent layer in the sprite sheet); a settings panel; a bot that grapples; art
for the UI (a drawn logo, item icons); the phone and pad tests of the older PRs.

## Calls for Danzo (made by the builder as trials; say if any is wrong)

1. Theme: glowing graphite (DESIGN §6.3). 2. Three rounds, placement points. 3. Only PLAY seats you; no ready-up
vote. 4. Coins: 10 a match + 5 a point + 25 a win; a spin 100; 150 to start, 50 a day. 5. Bots at 0.93 speed with a
0.3 s reaction and a dash on ~30% of plans. 6. The title says ROTAG. 7. **"Rolls to unlock abilities" was not
built**: it breaks rule 36 and §2. 8. The three music tracks.

## What Danzo should look for (his hands and ears)

- **The title:** does it look like a game you would click? Is PLAY the obvious thing? Is the map alive behind it?
- **First match, alone:** how to play shows once; the lobby counts down; ROUND 1 says who is it; the bots run,
  chase and use items; can you catch one, and get away from one? Too easy, too hard, too twitchy?
- **The cards:** the results after each round and the podium at the end read at a glance and get out of the way.
- **Sound:** every jump, dash, tag and pickup has a sound that fits; the fuse's beep is tense, not annoying; the
  three tracks suit a tag game (swap ids in `client/Audio.lua`); nothing is too loud.
- **Punch:** a tag shakes and flashes without making you lose your runner; a burn-out is a moment.
- **Names and colours:** you can find yourself and tell the others apart in a scrum.
- **The stage:** the runner, the anchors, the pads, the orbs and the walls all read on the dark stage; the bloom is
  a glow, not a smear.
- **Locker and wheel:** a spin feels like a little event; the cards say clearly what you own; buy a trail, see it
  behind you in the next round; see a bot's trail and want it.
- **A phone** (Studio's device emulator): the title, the cards and the buttons fit; nothing in the lower middle.
- **With a friend:** two people and two bots; tags land both ways as before; a friend who joins mid-match waits
  on the title and is in next round.
