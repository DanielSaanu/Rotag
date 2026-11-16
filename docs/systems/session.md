# The match, the menu's server side, profiles and cosmetics (H31)

**Created:** 2026-11-16 (H31, Fable session by Danzo's choice). What turns "endless rounds" into a game with a
start, a score, an end and something to earn. The rules are `docs/DESIGN.md` §3 31-36 (retention and structure), 50
(the first cosmetic slot), §6.4 (match structure), §6.5 (monetisation), §6.7 (bots: [bots.md](bots.md)). What the
player sees of all this is [ui.md](ui.md). QA goals: [../qa/showable.md](../qa/showable.md).

## 1. The calls (Danzo: "complete the game ... a menu screen ... between-game setup so it's not just endless rounds";
each is a recorded trial, say if one is wrong)

| Question | Decision | Why, and what was weighed |
|---|---|---|
| **Match structure (§6.4)** | **A match is `MATCH_ROUNDS` 3 rounds**, scored by placement: one point per runner you outlasted, one more for the win (four runners: 4, 2, 1, 0). Most points wins; a tie goes to round wins, then to who was seen first | Rule 33: one bad round must not decide everything. Three rounds are ~5 minutes, the "short sessions" pillar stretched once; best-of-5 was ~9. Placement points (not "tags landed") cannot be farmed by two friends passing the fuse back and forth |
| **Who plays** | **Only who pressed PLAY.** Joining puts you on the title screen watching the live map; PLAY gives you a body and a seat in the next round; SIT OUT gives both back | A player reading the how-to, or in the locker, must not be handed the fuse. It also makes a late joiner's wait a choice with something to watch |
| **Empty seats (rule 31)** | **Bots fill a round to `PLAYERS_PER_MATCH`** (`Config.BOTS`); never bots alone | "Needing a full lobby is the number-one killer". One kid from the Discord link gets a full 4-runner round at once: [bots.md](bots.md) |
| **More than four people** | In a hub (§8) each group of four gets its own match server. In a solo server four play and the rest wait one round, longest-waiting first (`Session.pick`) | §2 locks 4 per match. With the hub off, set the place's Max Players to 4 |
| **Between matches** | Podium `PODIUM_TIME` 12 s (winner, standings, coins earned), then a `LOBBY_TIME` 12 s warm-up (free running with the bots), then the next match by itself for whoever is still in | Rule 34 (celebrate the winner). No "ready up" vote: with kids one AFK player would stall the room; sitting out is the opt-out |
| **Monetisation (§6.5)** | **Cosmetics only, bought with coins earned by playing**: trails, glows, burn-outs, titles; a shop price for most, a wheel (`SPIN_COST` 100) for the rest. **No Robux anywhere yet** | Rule 36: nothing here touches a move, a speed or a hitbox (`Catalog` holds colours and names only). Selling coins or spins for Robux is one MarketplaceService call away and deliberately NOT built: paid random items need Roblox's odds disclosure (the odds are already printed on the wheel) and Danzo's decision |
| **"Rolls to unlock abilities"** (Danzo, 2026-11-16) | **Not built: it conflicts with rule 36** ("never lock moves behind a grind or shop") and §2 ("everyone gets every move from the start"). Flagged in `ideas/INBOX.md` | The wheel exists and rolls cosmetics. If Danzo wants ability rolls, the fair shape is side-grades to ITEMS (orb pool variants), not moves: his call, trigger 1 |
| **Saved data (trigger 9)** | One DataStore entry per player, `RotagProfiles_v1`, shaped by `shared/Profile` (§5) | See §5: what is saved, when, and what cannot be lost |

## 2. The flow (`shared/Session`, pure, `test/luau/session.test.luau`)

```
lobby ──(somebody is in for LOBBY_TIME)──> round 1 ──over──> gap (ROUND_GAP 6 s, the results card)
  ^                                                              │
  │                                              round < MATCH_ROUNDS: next round
  │                                                              │
  └──(PODIUM_TIME)── podium <──(after the last gap)──────────────┘        everybody out at any point: abort -> idle lobby
```

- **`Session.tick(s, now, people)`** advances it and returns what happened: `"start"`, `"abort"`, `"podium"`,
  `"lobby"`. An idle lobby (nobody in) never counts down; the first PLAY starts the countdown in full.
- **`Session.pick`** seats the people (join order, the rotation of rule 5) and the bots. **`Session.note`** reads the
  round's `alive` set every frame and records who dropped out, in order: a burn-out, a wall kill and a leave all land
  there, so the placing has one source (`Tag`'s round). **`Session.finish`** scores it and opens the gap.
- A round with no winner (everybody else left) pays no win bonus. A match everybody leaves is aborted, unpaid.
- **`Session.reward`**: `COINS_MATCH` 10 + `COINS_POINT` 5 x points + `COINS_WIN` 25 for the winner. A clean sweep is
  95 coins, last place every round 10: a spin every one to three matches.

`server/Session` owns the one state, the set of people who are in, the bots' seats, the pay-out and
`Remotes.Session`. `server/Match` asks it each frame: `Session.step(now)`, then `Session.due()` (the roster of a round
that may start; Match still holds it for `Ready`, players.md §5), `Session.began`, `Session.note`, `Session.finish`.
A round itself is unchanged: `shared/Tag`, the fuse, the walls, items.

## 3. Remotes (declared in `default.project.json`; rows in [README.md](README.md))

| Name | Direction | Payload | Trust |
|---|---|---|---|
| `Session` | server → all on every change and once a second; → one on join | `Session.view`: `{ phase, left (s, -1 = not counting), match, round, rounds, scores: { { id, pts, wins } }, roster, last (the last round's placing), lastPts (what each place scored), winner, playing: { id }, seed (the bots' names, H32) }` | server → client only (→ N3) |
| `Menu` | client → server | ONE string: `"play"` or `"sit"` | the sender is the Player; rate gap 0.4 s; anything else dropped unread. A lying client only seats or unseats ITSELF |
| `Profile` | server → the owner | `Profile.view` + what just happened: `spin = { id, back }`, `note`, `bought`, `earned`, `levels`, `saved` | never sent to anyone else |
| `Shop` | client → server | an op string (`"buy"`, `"equip"`, `"spin"`, `"get"`) and an item id string | rate gap 0.25 s; prices, odds and ownership only ever read from the server's `Catalog` and profile; a refusal returns a one-line `note` |
| `Looks` | server → all | `{ { id, worn: { item id per slot } } }` for every person and bot | cosmetic; the client drops ids it does not know |

In Studio only, two Player attributes stand in for the two client → server remotes so a test session can drive them
from a script (the command bar cannot fire a remote): `RotagMenu = "play" | "sit"`, `RotagShop = "op:itemId"`.

## 4. What the server trusts

Nothing new about movement or tags. `Menu` and `Shop` follow every `TagClaim` rule (→ N4). The match's coins are
computed from the server's own round results; a client never reports a score. A spin's result is rolled on the server
(`math.random`) BEFORE the client's reel animation starts: the reel only shows it.

## 5. Profiles (`shared/Profile`, `shared/Catalog`, `server/Data`, `server/Shop`; `test/luau/profile.test.luau`)

- **Saved:** `{ v, coins, xp, owned: { [itemId] = true }, equipped: { [slot] = itemId }, wins, matches, spins, day }`.
  `Profile.sanitize` turns whatever the store holds into a valid profile (unknown items dropped, every slot wearing
  an owned item of that slot, whole numbers >= 0), so a catalogue change never breaks a join.
- **Never lost, never forged:** a profile that FAILED to load plays on a fresh one in memory that is **never saved**
  (`Data.saves` false; the wallet shows "PROGRESS IS NOT SAVING RIGHT NOW"), so an outage cannot overwrite real
  progress. Saves: on leave, every 120 s, and on `BindToClose`. Every change goes through `Data.update`.
- **One server at a time (QA round 1):** a load takes a lock (this server's id and the time) in the same
  `UpdateAsync` that reads; a load that finds another server's fresh lock (under `LOCK_TTL` 300 s) waits 3 s up to
  three times for that server's leave-save, then takes it. Every save carries a revision and is refused when the
  store holds a newer one or another server's lock; the loser stops saving that profile and the wallet says so. A
  stale copy can no longer overwrite a newer save after a fast server hop.
- **Coins in:** `COINS_START` 150 for a new player (one spin at once), `COINS_DAILY` 50 on the first join of a day,
  the match reward. **Coins out:** shop prices 100-400, the wheel 100. Earned coins are xp too (`XP_LEVEL` 100 a level).
- **The wheel:** rarity by `Catalog.ODDS` (55 / 30 / 12 / 3, printed beside it), then one item of that rarity; a
  duplicate pays `Catalog.REFUND` back (30 / 50 / 80 / 150). The test spins 20 000 times and holds each rarity to
  its odds within 1.5 points.
- **The catalogue:** 4 slots (trail, glow, burn-out, title), 28 items, a free default per slot. Bots wear random
  items (the shop's advert). What each looks like: [ui.md](ui.md) §6.

## 6. Numbers (`Config`, all trial, Danzo's to tune)

`MATCH_ROUNDS` 3 · `LOBBY_TIME` 12 · `ROUND_GAP` 6 (was 4) · `PODIUM_TIME` 12 · `BOTS` true · `COINS_MATCH` 10 ·
`COINS_POINT` 5 · `COINS_WIN` 25 · `COINS_START` 150 · `COINS_DAILY` 50 · `SPIN_COST` 100 · `XP_LEVEL` 100.

## 7. What was seen (Studio, 2026-11-16, the PC locked: server and scripts only, nothing looked at)

- PLAY (through the `RotagMenu` attribute): a body at the spawn, three bots seated for the warm-up, `match 1 round 1:
  1 people, 4 seats` after 12 s, the round started.
- A whole round among the bots with the player AFK: orbs taken, traps, crates and the ice beam used and caught, a
  ghost bot placing fixtures and a pad and granting a boost, the end phase and the walls, `round 1 over: -1001 >
  -1002 > -1000 > 8061215879`, round 2 six seconds later with the rotation's next starter.
- The shop through `RotagShop`: a spin took 100 coins and gave a title; buying a 200-coin trail with 100 was refused;
  buying a wheel-only item was refused; wearing an unowned glow was refused.
- DataStore: Studio has API access off, so every load failed, the game played on and said `NOT saved this session`.
- **Not seen:** anything on a screen (the PC was on its lock screen: Studio rendered 0 frames a second), a real
  save and load (needs API access or a live server), two people in one match.

## 8. The hub and the match servers (H34, Danzo 2026-11-16: "hub with match servers")

The question was how a Discord crowd plays at once when a match seats four. The options weighed: (A) Max Players
4, separate servers, no code; (B) bigger matches (changes §2's "4 per match"); (C) a hub that queues groups into
match servers; (D) several matches inside one server (every server system from "one match" to "one per lobby":
days, and everything signed off retested). Danzo picked **C**.

One place, three kinds of server, decided at boot (`server/Hub.lua`, `Hub.MODE`):

| Kind | When | What PLAY does |
|---|---|---|
| **hub** | a public live server, `Config.HUB` true | queues you and gives you a body to warm up with. When `PLAYERS_PER_MATCH` are queued, or `LOBBY_TIME` after the first of them, the longest-waiting group is sent to a match server of its own (`TeleportService:ReserveServer`, `TeleportAsync`). No round ever runs in a hub |
| **match** | a reserved server a hub made (`PrivateServerId ~= ""`, owner 0) | nothing to press: you arrive seated, bots fill the empty seats, the lobby counts down, three rounds, the podium, then everybody is sent back to a hub. SIT OUT reads BACK TO THE LOBBY |
| **solo** | Studio, a player's own private server, or `Config.HUB` false | the game as before H34: matches run here |

- **A failed launch** (a teleport error, `TeleportInitFailed`): the players are queued again at once. Two whole
  launches failing in a row turns the hub into a solo server for its life (it runs the matches itself) with a
  warning in the log: a Roblox outage costs a wait, never the game.
- **A match server whose trip home fails** keeps its players in a counting lobby: they play another match there.
- **The save crosses the hop**: leaving a server saves and releases the profile's lock; the next server's load waits
  for it (§5). This hop is exactly what the lock was written for.
- **The relay** sends runners in chunks of 10 (`server/Snapshots`): a hub's warm-up can hold far more than four, and
  an unreliable event carries ~900 bytes.
- `Remotes.Session`'s view gained `mode`, and in a hub `queued` and `launching`; the lobby line reads FINDING A
  MATCH n / 4, then MATCH FOUND.
- **Set the place's Max Players to the hub's size** (20 is a good start), not 4: a match server only ever
  receives the four it was made for.

**Not tested: any of it, end to end.** Teleports do not exist in Studio. The queue's grouping reuses the tested
`Session.pick`; everything else here is unrun code until two real accounts press PLAY on the published game. The
test, and the way back if it misbehaves (`Config.HUB = false`, Max Players 4, republish), are in `ideas/INBOX.md`.

## Expansion: deficits at scale

- **The lock is home-made** (§5): it covers the fast-hop overwrite, not everything a battle-tested profile store
  does (no queue of pending writes, a forced take-over after 12 s). Before Robux touches coins, move to one.
- **An AFK player holds a seat** until it sits out or leaves. A "no input for two rounds: sit out" rule is cheap.
- **One map.** The flow has no map vote; `Config.MAP` is fixed (maps.md §1). A rotation is a list the day a second
  map lands.
- **No round modifiers yet** (rule 30) and no private-server settings (rule 13's vanilla toggle).
