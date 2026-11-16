# Bots: runners the server plays (H31)

**Created:** 2026-11-16 (H31). Answers `docs/DESIGN.md` §6.7 ("a basic bot that chases, flees and uses abilities") and
serves §3 rules 31 ("bots, and make 2 players fun") and 32 (a solo option). Before H31 the only stand-ins were the
Studio dummies: boxes that walked the floor ([tag.md](tag.md) §4). They are gone; `server/Dummy.lua` is now a bot's
body. The match that seats bots is [session.md](session.md).

## 1. The idea: a bot is a player the server presses the buttons for

A bot does not move by its own rules. It is a `shared/Movement` state, stepped every server frame with an `Input`
exactly as a player's client steps its own, in `shared/BoxWorld`: the map's blocks (and the ghosts' fixtures) as
plain boxes, with the probe and the push-out that Studio's raycasts and physics are to a player. So a bot has the
same run, jumps, wall kicks, dash, forgiveness windows, holds and pad launches as a person, to the stud, and
**cannot do anything a person cannot**. Nothing in `Movement` knows bots exist.

Since H32 that includes the **grapple**: a bot hooks the anchor the aim assist would give a player standing where it
stands (on its screen, in reach, in line of sight: `BoxWorld.clear`), swings and lets go (§7).

## 2. How it picks its buttons (`shared/BotBrain`, pure; `test/luau/bots.test.luau`)

No route graph, no waypoints. Every `BOT_THINK` (0.3 s, jittered; only on the ground, or after 0.7 s in the air: a
jump is a commitment) the bot **tries 33 plans in its head**, each played for `HORIZON` 1.1 s through the real
`Movement.step` in a copy of its state, and takes the best:

- run; a short step (0.07 s, 0.2 s); jump; jump + double jump at the top; a late jump off a deck's end; out past a
  ledge, up and back over it; straight up beside a deck's end, then drift over; dash; dash into a jump; kick up a
  shaft; hook the anchor ahead for a short or a long swing; jump, then hook. Each to the left and to the right, plus
  standing still.
- **Scoring a plan:** by the **flood-fill distance** to the goal over the map's tiles (`BoxWorld.field`: the way
  ROUND a deck, not through it). A seeker wants the closest approach (a tag or an orb is a touch, not a stop), then
  the soonest, then a little the end; a fleer wants to end far and never come close on the way, capped at `SAFE` so
  it does not live in an end shaft. Ending outside the closing walls is the worst plan; every step outside costs.
- The rollout runs at the server frame's step (1/60): at 1/30 a jump under a deck's lip landed in the bot's head and
  missed on the floor, and it hopped under the Hub for three seconds (→ S21).

Measured (the test prints it): every deck of the Yard reached from the floor, the slowest (the Mast) in 5.0 s; one
decision is 33 plans x 66 steps, ~6 ms in the standalone interpreter (3.5 ms in Studio, QA round 1); three bots are
~6% of one core; the server's Heartbeat averaged 4.2 ms with three bots. At most one bot thinks per frame.

## 3. What it wants (`server/BotMind`)

| It is | Goal |
|---|---|
| "it" | chase the nearest living runner, person or bot (sticky: a new target must be 30% nearer) |
| a living runner | flee while "it" is within 16 tiles; else fetch a living orb if the slot is empty; else wander |
| a ghost | fetch a ghost orb; a hex goes to the holder; anything else to the nearest living runner |
| outside the walls | back in first |
| in the lobby or a gap | wander the decks (company to warm up with) |

Items follow the pools' intent (rule 43): a runner drops a crate or sets a trap when the chaser is 1-7 tiles off on
its level (facing away, so the crate lands between them); the ice beam is fired at whoever is about level and in
reach; a ghost places a fixture or a pad near the action, tried every 0.6 s (a refusal costs nothing).

## 4. Fairness (trigger 3)

- **A bot's position is the server's own**: no snapshot, no speed check, no lag allowance. Its tag is judged with
  rewind 0, **and where THAT person sees it**: a person draws a bot the snapshot delay plus their own ping behind
  the server, so a bot's tag on them needs the bot's box of `SNAPSHOT_DELAY + ping + BOT_SEEN` ago (0.4 s at most) to
  touch their box now with no grace, and its present box within the server's usual grace (QA round 1: a fixed 0.12 s
  was 4 studs short of a touch for a 200 ms phone). A bot never tags from out of reach on your screen.
- **A person's tag on a bot** is an ordinary `TagClaim`, judged on the server's history like any other.
- **Handicaps:** every bot runs under run speed (0.88-0.98 x, centred on `BOT_SPEED`); only a share of its plans
  may dash (12-42%: a bot that dashed at every cooldown averaged 70 studs/s in Studio and nobody could catch or
  escape it); it thinks every 0.18-0.42 s and a new holder takes 0.25-0.6 s to sink in (§7). `Config.BOT_TAGS =
  false` stops bot holders tagging (solo item testing).
- Bots never play alone, never take a person's seat, and a person who presses PLAY replaces a bot next round.

## 5. How a bot reaches every screen

`Snapshots.inject`: the server packs the bot's state with the same `shared/Snapshot.pack` a client uses and adds it
to the relay batch 30 times a second, so every client draws a bot exactly as it draws a person: sprite, facing,
squash, dust, the dash's i-frames (rule 45). Its body is an anchored, invisible part tagged `RotagRunner` with a
`RunnerId` of -1000, -1001, ... (`Session.botId`); its name is `Session.botName(id, seed)` (§7). Its rope is drawn
from the snapshot's anchor byte like a person's. Bots wear random cosmetics (`server/Shop`).

## 6. What was seen (Studio, 2026-11-16, server side only: the PC was locked)

Three bots and an AFK player, two rounds: bots climbed to the high decks and the Mast (top y 70), took living and
ghost orbs, used traps, crates and the ice beam on each other, tagged each other and the player, burnt out, placed
fixtures and pads as ghosts, granted boosts, and finished the round inside the closing walls. Before the dash gate
they averaged 70 studs/s of path; after, 58-61 (a path includes falls at 80 and jumps: a person running routes is
about the same). **Not seen:** a bot on a screen, or played against by hand: whether they are FUN to chase and to
flee is Danzo's call (the knobs are `BOT_SPEED`, `BOT_THINK`, `DASH_CHANCE`, `FLEE`).

## 7. Passing for people (H32, 2026-11-16)

Danzo, the same day: "add more advanced AI so that in the event of too few players, players can still play with
machines unknowingly, giving the impression that there are more players than there are; or just remove them if they
continue to run through walls and refuse to jump". (The wall-walkers that never jumped were the old Studio dummies,
gone since H31; nobody had yet seen the new ones.) What makes a bot read as a person:

- **It is its own player** (`BotMind.new`): one `skill` roll per bot (0..1) sets its run speed, how often it thinks,
  the share of plans that may dash (12-42%) and swing (20-70%), how sloppy its picks are (`noise` 9..0.6 added to
  each plan's score: two tiles of misjudgement at the bottom) and its reaction time. Three bots in a room are three
  different players, and the weak one loses.
- **It grapples**, only as a player could (§1), and its rope shows on every screen.
- **It reacts late.** A change of holder takes `react` 0.25-0.6 s to change what it does.
- **It sees hazards** (`goal.hazards`): a plan that runs into a crate or a trap is rated down 25, so it goes over or
  round, unless that costs more, and a sloppy bot still blunders into one.
- **It rests.** After reaching a wander spot it stands 0.3-1.5 s four times in ten; nobody runs without a breath.
- **It does not hop for nothing.** A ground jump adds speed, so every open-floor think rated a jump a hair over a
  run and a bot hopped 1.5 times a second in Studio; a jump now has to be worth `EFFORT` 2 (half a tile).
- **It has a player's name and no label.** `Session.botName(id, seed)` builds one from two word lists and a number
  in the styles players use (`TurboFox12`, `frost_panda`, `Lucky_Bean7`); the seat keeps it for the server's life
  (the seed rides `Remotes.Session`), no two seats share one, and no name says "bot". Nothing in the HUD, the
  scoreboard, the cards or the name tags marks a bot.
- **The scoreboard is the player list.** Roblox's own player list (which would show only the people) is turned off
  (`client/Present`); the strip in the corner seats bots and people together.

**What still gives a bot away, and what was deliberately not faked:** a bot never chats; the server's real player
count on the game's page and in the Roblox menu's player list (Esc) is the truth; a bot has no profile to click.
Names are generated, never copied from real accounts (one can coincide with a real account only by chance). This
is a presentation choice Danzo made for a small playtest; if the game grows, say on the game's page that empty
seats are filled by AI runners: players forgive a labelled bot faster than a discovered one.

In Studio (2026-11-16, server side): three bots named Turbo_Ace0, rocketnoodle37 and PixelFox (skill 0.72, 0.24,
0.24) played a round; per 20 s each made 24-35 jumps (before the `EFFORT` cost), 1-6 dashes and 0-4 swings; they
took orbs, set traps, froze each other and tagged each other and the idle player. Nobody has yet WATCHED one.

## Expansion: deficits at scale

- **No aimed dodge** (a bot never dashes through an ice beam on purpose) and no chat.
- **Skill is rolled, not matched** to the people in the room. A server could seat stronger bots against a winning
  player (one number, `BotMind.new`'s roll).
- **Cost grows with plans x horizon x bots.** Fine at three; a 12-bot mode would need the plans spread over frames.
