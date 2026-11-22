# Research: short tutorials for movement games

_22 Nov 2026. Desk research for [`../qa/playtest-2026-11-20.md`](../qa/playtest-2026-11-20.md) #5 (grapple "doesn't
work") and #6 (testers asked for a step-by-step tutorial). Rotag has a static HOW TO PLAY card and a lobby practice
room (H37); the grapple is in [`../systems/grapple.md`](../systems/grapple.md)._

**Source caveat.** Page fetches were blocked in this session; findings come from search-result excerpts. No source
gave a minute count for Celeste's or Mirror's Edge's tutorial; durations below are marked as estimates where so.

## 1. Patterns, by game

### Celeste: the whole game is the tutorial
- Almost no text. Each screen has one teaching job; you learn by doing, and failure costs seconds (instant respawn
  at the screen start). The Prologue precedes Chapter 1 and introduces the dash in a single scripted moment.
  https://medium.com/super-jump/making-tutorials-better-31116c02687b ,
  https://celestegame.fandom.com/wiki/Chapter_1:_Forsaken_City
- Maddy Thorson's GDC 2017 talk "Level Design Workshop: Designing Celeste": rooms built as small "stories" around
  one mechanic rather than single-solution puzzles; offering more than one route keeps hard rooms from feeling
  unfair. https://gdcvault.com/play/1024307/Level-Design-Workshop-Designing-Celeste ,
  https://primedpixel.github.io/posts/lessons-ive-learnt-from-celestes-level-design/
- Celeste was designed with speedrunning in mind: the same rooms reward a beginner and an expert.
  https://www.usgamer.net/articles/how-celeste-was-designed-with-speedrunning-in-mind

### Nintendo's four-step room (the "one verb per room" model)
- Introduce a mechanic safely, develop it, twist it, conclude (kishotenketsu, per Koichi Hayashida on Super Mario
  3D World). World 1-1 teaches jumping, blocks and enemies with no text ("learning through play").
  https://www.mcvuk.com/development/video-nintendos-level-design-secrets-in-four-steps ,
  https://en.wikipedia.org/wiki/World_1-1

### Mirror's Edge: a training course plus colour as instruction
- The game opens on a training course (a guide character talks Faith through the moves). **Runner Vision** paints
  the objects you need red; it gets subtler as levels get harder and can be turned off (Hard disables it).
  https://mirrorsedge.fandom.com/wiki/Tutorial , https://www.ea.com/news/runners-vision-in-mirrors-edge-catalyst ,
  https://www.pcgamer.com/au/mirrors-edge-is-still-the-undisputed-queen-of-parkour/
- Takeaway: one colour means "you can use this", taught in the first minute, reused for the whole game.

### Titanfall 2: the Gauntlet, a tutorial you replay for fun
- Mission 1 is the tutorial: wall-run, slide and shoot stations, then a **timed course** with a **leaderboard** and a
  **ghost** time to beat (achievements for beating the ghost and placing top 3). Speedrunners got it to ~11 s; the
  community kept replaying it.
  https://titanfall.wiki.gg/The_Pilot%27s_Gauntlet , https://www.trueachievements.com/game/Titanfall-2/walkthrough/2 ,
  https://www.gamespot.com/articles/titanfall-2-speedrunner-claims-new-gauntlet-record-of-11-seconds/1100-6491237
- Takeaway: end the tutorial on a short timed lap so finishing it is a game, not a chore.

### Rocket League: short tiered tutorials, then drills
- Basic tutorial (drive, jump, dodge, boost, ball cam), Advanced (double jump, flips, aerials), then Striker /
  Goalie / Aerial training packs; featured community packs rotate by skill level. Many players skip tutorials.
  https://www.gamepressure.com/rocketleague/how-to-start-playing/z37a74 ,
  https://www.rocketleague.com/news/community-spotlight--training-packs-for-new-drivers ,
  https://www.nintendolife.com/news/2017/11/guide_9_straightforward_tips_to_help_you_get_started_in_rocket_league
- Takeaway: split "enough to play" from "how to get good"; the second is optional practice.

### Roblox obbies and Roblox's own guidance
- Roblox Creator Docs define onboarding as the **first few minutes**, judged by **Day 1 retention**; recommended
  techniques are **visual elements, contextual tutorials (triggered by first use of a feature), and timed hints**.
  Guided beams with streaming arrows (FaceCamera on) are Roblox's own example.
  https://create.roblox.com/docs/production/game-design/onboarding ,
  https://create.roblox.com/docs/production/game-design/onboarding-techniques ,
  https://create.roblox.com/docs/education/build-it-play-it-mansion-of-wonder/adding-scripts
- DevForum: first-session retention "falls very quickly during the first 5 minutes"; use funnel events to find the
  step where players leave. https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458 ,
  https://devforum.roblox.com/t/improving-new-user-engagement-on-my-game/2947546
- Obbies teach by structure: one obstacle type per stage, a checkpoint after each, so a fall costs one stage.

### Ghost replays as a demonstration
- Mario Kart staff ghosts are a baseline AND a lesson: players learn drift points and shortcuts by watching. In
  TrackMania every opponent is an intangible ghost. https://www.mariowiki.com/Ghost_(Mario_Kart_series) ,
  https://doc.trackmania.com/play/watch-replays , https://itch.io/post/9065672
- For a tutorial, a ghost doing the move once, right before the player tries it, shows timing that text cannot.

## 2. Teaching a grapple or anchor so it reads as usable

- **Fixed, distinct anchors beat free aim** for readability; Ori uses one colour (blue) for grapple points and
  infers the target from your run-up, so no precise aim is needed. Flinthook-style bespoke points remove aiming.
  https://serfofcinder.itch.io/archetype-portal-to-hell/devlog/722682/the-making-of-the-grappling-hook ,
  https://gamedeveloper.com/design/designer-interview-crafting-i-flinthook-i-s-hookshot-wasn-t-easy
- **Show which point is picked.** A known complaint is not knowing which point you will hook. Highlight the
  current target (outline, a line from the hand, a button-prompt icon on the anchor).
- **Teach the two behaviours separately** (pull vs swing); one developer called the grapple's dual behaviour the
  hardest mechanic to teach. **Constraints** like fixed anchors and limited rope length belong in the lesson.
  https://dl.digra.org/index.php/dl/article/download/2861/2845/2904
- Rotag's own rules already match (DESIGN §3 rule 17: marked anchors, aim assist, never off-screen; rule 29:
  colour-code). The playtest gap is that a dimmed button with no anchor in range teaches nothing.

## 3. How long

- Roblox's window is "the first few minutes"; first-session retention drops inside 5 minutes (sources above).
- Estimate (no source gave a figure): Celeste's Prologue and Titanfall 2's Gauntlet each take a few minutes for a
  first-timer; Rocket League's basic tutorial is a few minutes. A Roblox movement tutorial should aim at
  **60-90 s for the core, under 3 minutes total**, with the advanced part optional.

## Recommendation for Rotag

1. **A 5-room practice run in the lobby practice room**, one verb per room, no text walls: run+jump, double jump
   onto a platform, wall climb, dash across a gap, grapple an anchor. Then a sixth: tag a bot (being "it").
   Each room is introduce -> use once -> done; fall = respawn at the room's start.
2. **Skippable and short**: offered once on first join, a Skip button always visible, ~60-90 s; replayable from the
   menu. End on a timed lap with a best time, Gauntlet-style.
3. **Ghost demo per room**: a pale ghost (Rotag already has the ghost look) does the move once, then the player
   copies it. Recorded inputs, not video.
4. **Grapple room**: the anchor pulses gold when in range and shows the grapple button icon on it; out of range,
   show the anchor's reach ring instead of only dimming the button. One swing to cross a pit, no other choice.
5. **Contextual hints after the tutorial**: the first time an anchor comes in range in a real match, a 2 s prompt.
   Log a funnel event per room to see where new players quit.
