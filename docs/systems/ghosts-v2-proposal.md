# Ghosts v2, abilities, pickups and maps: the H16 proposal

**Created:** 2026-10-19 by the heavy agent (handoff H16). **Status: ADOPTED 2026-10-19, this is the spec** (DESIGN §1,
§2, §3 rules 37-51, §6.2, §6.8). Not built yet: the H15 ghosts in [ghosts.md](ghosts.md) run until PR 1 of the build
order (§12) lands.

**Danzo's decisions (2026-10-19), which override the proposal text below wherever they differ:**
- Ruleset 1, "orbs for everyone". §1/§2 now say "the next round is their way back".
- Grapple: a kit move for the living only; ghosts never get it.
- **Bear trap capped at 1 s** ("I want it to be fast paced"); 3 presses still free you sooner. Rule 11 unchanged.
- **The dash goes OVER a bear trap, never THROUGH a crate:** i-frames cover aimed abilities and traps, not crates.
- **Hex -3 s** (`SPOOK_DRAIN` kept), still rare.
- **Separate ghost orbs** (a ghost-only orb type at its own spots), not one shared orb. Living orbs respawn 10 s;
  ghost orbs 10 s / (1 + 0.5 x ghosts).
- **Added: ignition** (rule 50): from `IGNITE_AT` (trial 10 s) the holder is visibly ignited, drawn by every client from
  the replicated fuse; a burn-out plays on elimination; the first cosmetic slot (§6.5).
- **Added: end-phase speed** (rule 51): only at the final two living, or past `END_PHASE_AFTER`, everyone living runs
  at x `END_PHASE_SPEED` (trial 1.1), with rule 3's map shrink; never during a normal fuse. Numbers tuned by hand.
Input: Danzo's notes of 2026-10-19 in [`../../ideas/INBOX.md`](../../ideas/INBOX.md) "Ghosts v2" and its Abilities
sub-section. Controls for every verb below: [controls.md](controls.md) (H17).

## 1. The problem, in numbers

Today (H15) a ghost has one verb, touch "it", -3 s, then waits 8 s, and a shared 6 s ward caps all ghosts at 1.5x
burn. In a four-player round the ghosts' whole effect is a few seconds off a fuse, and the comeback (rules 39-40)
is a coin-flip on who touched last. Danzo's direction: no comeback; ghosts stay out and place things, both to hinder
and to help; the drain stays but rare; the living earn abilities from pickups; 3-4 maps.

## 2. Recommended ruleset, "orbs for everyone" (plain words)

- **Ghosts stay out for the round.** No mark, no comeback. They keep running (pale, see-through, everything but the
  grapple), and they shape the round with what they pick up: parts they place in the map, and a few aimed abilities.
- **One pickup system for both.** Orbs sit at fixed spots on each map. Whoever touches one with an empty slot gets an
  item, rolled by the server from **their** pool: the runners' pool, the holder's pool, or the ghosts' pool. One slot,
  shown over your head to everyone. Orbs respawn faster as the ghost count rises (the end-phase ramp, Danzo's (c)+(d)).
- **The fuse drain becomes a rare ghost item, the Hex** (-5 s on touch), not a free spook every 8 s.
- **Holds are short and never chain:** stumble 0.7 s, freeze 1 s, trap up to 2 s but broken in 3 presses. The dash's
  first 0.2 s dodges what is aimed at you, never a tag, never what is put down (jump over that).
- **Ghost fixtures (Tetris pieces) are permanent for the round,** at most 3 live per ghost, and can never seal
  anything, because every map marks its exits and corridors as keep-clear zones nothing may be placed in (the map rule).

Why this one: it gives ghosts a reason to keep moving (orbs are on the routes, so ghosts stay in the chase), it puts
both roles on one system so every item meets every other system (movement, dash, tag, map; PRINCIPLES §2 rules 1 and
4: one thing legible to many systems), and it keeps every H15 safety (server confirm, ward, no ganging up).

## 3. The abilities

Rule 12 (distinct effect, distinct look) checked: three things you **put down** (crate, trap, fixture/pad), three you
**aim** (ice beam, hex, boost grant), all different shapes and colours. Rule 11 (no hold over ~1 s) checked per item.

| Ability | Who can roll it | What it does (trial numbers) | Beaten by |
|---|---|---|---|
| **Crate** | living, ghosts | Dropped behind you; lasts 20 s. Touching it breaks it and **stumbles** you 0.7 s: you carry on the way you were going at half run speed (22.5 studs/s), no steer, jump, dash or new item. Its dropper is safe from it for 0.5 s. | jumping over it |
| **Bear trap** | living, ghosts | Set at your feet; lasts 20 s or one catch. Pins you in place up to **1 s** (Danzo; proposed 2 s); **3 presses** of any action key / clicks / taps pry it open (a quick hand: ~0.4 s). | jumping or dashing over it; pressing fast |
| **Ice beam** | living, ghosts | A straight beam 24 studs ahead the way you face, alive 0.5 s, does not turn with you. Caught: **frozen 1 s**, sliding on your momentum (it bleeds to 0 over the second), no input. | dash i-frames timed right; being out of line |
| **Hex** (the drain) | ghosts, rare | While held, your touch on the holder takes **3 s** (Danzo; proposed 5) off the fuse (server-confirmed like a tag, H15's path); then the slot empties. After any hex a shared 6 s ward (H15's), none while frozen. | dash i-frames; seeing the ghost coming |
| **Boost grant** | ghosts | Touch a living runner: +15% run speed for 5 s. On the holder it **never stacks** with the chaser ramp: boost = max(ramp, grant), so the holder reaches the ramp top sooner, never above it. | — (it is help) |
| **Boost pad** | ghosts | Placed where you stand, facing your way, lasts 20 s; works like the map's pads (§2): launch along its arrow, refreshes dash and double jump (rule 15). Anyone may use it. | — |
| **Fixture** | ghosts only | A tetromino of 1-tile (4-stud) cells, placed in the air or on the ground, rotated in 90° steps, permanent for the round; a ghost's 4th piece fades its oldest (1 s warning). Solid to everyone. | the keep-clear map rule (§5) |
| **Grapple** | living only | NOT a pickup: it stays in everyone-living's kit from the start (DESIGN §2), on marked anchors (rule 17). Ghosts do not grapple (Danzo: "players only"). | — |

**Pools (weights, trial):** runner: crate 40, trap 35, ice 25 (escape tools: they go behind you). Holder: ice 50,
crate 25, trap 25 (chase tool first: it goes in front; rule 10 weights toward the holder). Ghost: fixture 30, boost
pad 15, boost grant 15, crate 12, trap 10, ice 10, hex 8 (≈ one hex in twelve rolls: rare, as Danzo asked).

**Items touch the living only.** Ghosts pass through crates, traps and beams (no ghost-on-ghost griefing); fixtures
and pads are map, solid or usable for everyone.

**The boost-grant lean, checked.** Ramp: +0 for 5 s, then to +15% over 15 s. A grant at the start of a chase gives the
holder 0.15 x 45 x 5 = **~34 studs** over 5 s; a grant on a runner gives the runner the same ~34 studs against a
full-ramp holder. Same size both ways, so a ghost can tip either side equally and neither side gets a built-in edge;
a granted runner only *matches* a full-ramp holder, so the ramp still ends loops (rule 4). The lean holds.

## 4. Holds, casting and the dash

- **Holds** = stumble, trap, freeze, and the tag freeze. A hold **never stops a tag**: contact is contact (a stumbling
  holder still tags; a frozen runner sliding into the holder is tagged).
- **Cast before the stumble (Danzo's rule):** an item started before a hold goes off in full (a beam already out
  stays out); no item can be started during a hold.
- **No chains:** after any hold ends, 0.5 s in which no new hold lands. A runner hit by any ghost's aimed ability is
  warded from every ghost's aimed abilities for 6 s (H15's ward, extended from the holder to every target: rule 8).
- **Rule 11 tension, stated:** the trap's 2 s timer is above rule 11's ~1 s. It only bites a player who does not
  press: three presses free a quick hand in ~0.4 s. Proposed amendment to rule 11: "a hold you cannot break stays
  about 1 s; one you can break may last 2 s." (Question 4.)
- **Dash i-frames:** the first **0.2 s** of a dash (the 0.15 s dash + 0.05 s) dodges anything **aimed at you**
  (ice beam, hex). A mistimed dash dodges the front of a 0.5 s beam and is caught by the rest (Danzo's Elden Ring
  example). Never a tag. Never what is **put down** (crate, trap): those you jump. The 0.8 s dash cooldown already
  stops i-frame chaining. One sentence for players: *dash through what is thrown, jump over what is dropped.*

## 5. Placement and the map rule (no sealing)

- **Where:** a held fixture or pad previews where the ghost stands (centred one tile ahead of it, so it can hover by
  jumping); the grapple button rotates the preview (ghosts have no grapple); Use places it. On a phone this needs no
  aiming at all.
- **Valid only if** (checked by the server): the piece fits empty space (no map, piece, pad, orb spot, grapple anchor
  or spawn spot under it, and no living runner within 1 tile); it is on the ghost's own screen; it overlaps **no
  keep-clear zone**. Invalid previews show red and Use does nothing.
- **The map rule (Danzo asked for a map rule over a piece rule):** every map marks a **keep-clear zone** on every exit
  of every area (at least 2 tiles wide and 2 tiles tall, 8 studs > the runner's 3.5) and along every corridor (any
  passage under 5 tiles across), and every area has 2+ exits (rule 25). Because nothing placed may overlap a keep-
  clear zone, **no stack of pieces, however many ghosts, can seal an area or a corridor**: stacking is safe by
  construction, with a cheap box test and no path search. Pieces can still wall off a *route inside a room*; that is
  their point, and the cap of 3 live per ghost keeps rooms from filling.
- **Why not the routine read's piece-size rule** ("corridors taller than the tallest piece"): it stops one piece, not
  two stacked; it would need a path search on every placement to be safe. The keep-clear zone also does that
  routine read's job: no piece goes in a hallway at all.

## 6. Maps: 3-4 feels (rule 30: layout, not just art)

All about 4 x 3 screens (~340 x 150 studs at today's 48-stud-tall view), 6 orb spots, every rule 25-29 kept.

1. **The Tower** (vertical): stacked loops joined by wall-jump shafts, high and low routes (rule 28). Few rooms, so
   fixtures matter less; the grapple and ice beams shine.
2. **The Yard** (open): wide floors broken by islands and grapple anchors, map boost pads; open centre avoided with
   one-way drops (rule 26). Fixtures change it most: ghosts build cover here.
3. **The Warren** (maze): small rooms with many doors; most of it is keep-clear, so pieces go in rooms only. Crates
   and traps are strongest; short sight lines make the arrows matter.
4. **The Rooftops** (gaps): buildings with gaps between them; falling drops you to the slow street route. Boost pads,
   grapple swings; a ghost's pad over a gap is real help, a piece in a gap a real block.

## 7. A four-player round, minute by minute (no comeback)

Fuse: 45, then 35, 25 (FUSE_SHRINK 10). With a pass every ~10 s (+2 each, capped), a life lasts about fresh / 0.8:
~56, ~44, ~31 s; a hex or two take 5-10 s off a late life. Three eliminations end it.

- **0:00-0:05** GO; the holder waits 1 s. Orbs appear at 0:05 so the first seconds are pure movement.
- **0:05-~0:55** four living. Runners grab crates and traps and drop them behind; the holder's ice beam is its catch
  tool. Orbs respawn every 10 s.
- **~0:55** first burn-out: one ghost. It runs to the orbs (respawn now 6.7 s) and starts placing: a pad that saves a
  runner, a piece across a route the holder loves, or a crate in a doorway.
- **~1:40** second burn-out: two ghosts, two living, fuse 25. Orbs every 5 s; ghost items arrive about every 10 s
  each, the map has up to 6 ghost pieces; the hex is the rare spike (one in twelve ghost rolls) the holder has to
  dash through. This is the final duel and the ghosts are its pressure (rule 3).
- **~2:10** third burn-out: winner. Worst case with no passes: 45 + 35 + 25 = 105 s (H15's comeback bound was 165 s).
  The round sits in the 2-3 minute pillar.

**What a ghost wants without a comeback:** the round to end (its next life is the next round), so the natural ghost
play is pressing the holder: hex, trap, crate in its path. A ghost with a grudge helps the holder catch someone.
Both are fine; the ward caps either. If ghosts need more pull, §6.4 can count ghost assists as points (parked).

## 8. Fairness and trust, for the build (trigger 3, recorded now)

- Orbs: the server sees the touch on its own record each frame (no new claim remote). Rolls on the server.
- Use: one new client → server remote (the press; for a fixture, the rotation 0-3; the spot is the server's record of
  the ghost, never a client position). Aimed hits are judged on the server's history like a tag (rule 6).
- Holds: the victim's client applies them; the server tightens `MoveCheck`'s budget to the hold's allowance for its
  length, so a client that ignores a trap is snapped back to it and its samples go untrusted (cannot tag): H12's tool.
- I-frames: judged from the dash bit in the server's snapshot record, with the 0.8 s dash cooldown enforced on the
  server, so a client cannot claim to be dashing for ever.
- Placement validity (§5) re-checked on the server; a refused place costs nothing and says why in Studio.

## 9. Ranked alternatives (DESIGN §4, PRINCIPLES)

1. **Recommended, "orbs for everyone"** (§2-§8). Ghosts keep the movement pillar and stay in the chase; one system
   for both roles (PRINCIPLES §2); SpeedRunners' item model (§4 "items that target leaders") with its overlong stuns
   avoided (§4 "avoid").
2. **Ghost charge timer:** ghosts take no orbs; every 12 s (faster with more ghosts) each ghost picks one of three
   cards (fixture / trap / hex). Simpler, no orb race; but ghosts have no reason to move (they wait for a card), the
   Bomberman-from-the-edge model without its arena. Second.
3. **Once per round (Danzo's (b)):** each ghost places one big thing. Cheapest; repeats today's problem (one act and
   done). Third.
4. **Keep H15's comeback and add fixtures:** most fun for a single ghost, but the comeback is the part Danzo calls
   thin, and §2's "want their turn back" pull stays coin-flip. Last.

## 10. DRAFT DESIGN text (applied 2026-10-19 with Danzo's changes; DESIGN.md is the wording of record)

**§2 lines this would change (trigger 1):** §1 Concept "come back as a ghost who can sabotage the living players and
earn a way back in" and §2 Elimination "Ghosts should want their turn back, which keeps them engaged until the end"
→ "Ghosts stay out for the round and shape it with what they place; the next round is their way back." §2 Crates
"Random abilities come from crates" → "from orbs (lucky blocks) at fixed spots". The movement kit line (grapple, boost
pads for everyone from the start) is **kept**; ghosts lose only the grapple.

**§3, replacing rules 37-41 ("Ghosts, v2"):**
37. A ghost is a pale, see-through runner: run, jump, double and wall jump, dash, no grapple. It passes through
    runners and items, collides with the map and fixtures, cannot tag or be tagged.
38. Ghosts stay out for the round: no comeback. Every elimination still shrinks the next fuse.
39. Ghosts take orbs and roll the ghost pool; they place parts and aim abilities for or against anyone.
40. The Hex is the only fuse drain: rare, -5 s on the holder by touch, confirmed like a tag; a shared 6 s ward after
    any hex, none while the holder is frozen.
41. No ganging up: a runner hit by a ghost's aimed ability is warded from all ghosts' aimed abilities for 6 s; every
    held item shows over its holder's head; ghosts' arrows stay hollow.

**New rules:**
42. **Orbs:** fixed spots per map, first at 0:05, respawn 10 s / (1 + 0.5 x ghosts). Touch with an empty slot: the
    server rolls the taker's pool (runner, holder, ghost). One slot; Use fires or places it.
43. **The living pools** weight escape items to runners and the chase item to the holder (rule 10).
44. **Holds** (stumble 0.7 s, freeze 1 s, trap up to 2 s or 3 presses, tag freeze) never stop a tag, never chain
    (0.5 s immunity after one), and block starting an item; an item started before a hold goes off.
45. **Dash i-frames:** the first 0.2 s of a dash dodges what is aimed at you, never a tag, never what is put down.
46. **The boost grant** never stacks with the chaser ramp: boost = max(ramp, grant).
47. **Placement:** ghost parts go where the ghost stands, in empty space, on its screen, at least 1 tile from any
    living runner, never in a keep-clear zone; at most 3 live fixtures per ghost.
48. **Maps:** every exit and corridor is a keep-clear zone; every area has 2+ exits; 3-4 maps that differ in layout.
49. **Toggle (rule 13):** "vanilla" turns orbs off; ghosts then hold a hex every 20 s and nothing else.

**§6.2 answer:** "Resolved by H16: crate, bear trap, ice beam (living and ghosts), hex, boost grant, boost pad,
fixture (ghosts); grapple stays a kit move. The old drafts: Sketch Wall became the fixture; Ink Splat dropped (a slip
the victim's client applies, H15's reason); Eraser Blink dropped (a teleport fights the speed check, trust.md);
Decoy Doodle and Graphite Hook+ parked." **New §6 item, Maps:** "3-4 maps from the start, feels in ghosts-v2-
proposal.md §6; which first, and their size."

## 11. Questions for Danzo (answered 2026-10-19: the decisions at the top)

1. **Which:** recommended, or alternative 2, 3 or 4?
2. **§1/§2 wording:** drop "earn a way back in" / "want their turn back" for "the next round is their way back"? (A §2
   change: trigger 1.)
3. **Grapple:** read "players only" as "a kit move the living keep from the start, ghosts don't get it" (as §2 says),
   not as a pickup? (A pickup grapple would undo §2's "everyone gets every move from the start".)
4. **Trap timer:** keep your 2 s with 3 presses and amend rule 11 for breakable holds, or cap it at 1 s?
5. **I-frames:** dash dodges only what is aimed (recommended), or crates and traps too (then crates are trivial)?
6. **Hex:** -5 s and rare (recommended), or keep -3 s?
7. **Orbs:** one shared orb for ghosts and the living (recommended: ghosts stay in the chase, and an orb race is a
   meeting point), or separate ghost orbs?

## 12. Build order (adopted 2026-10-19)

Six PRs, each one session and one `docs/qa/<name>.md` goals file, in this order; each ends playable. Headroom first
(T1, T4): `server/Match.lua` is at 369/400 lines, so new server logic goes in NEW modules and Match only wires them;
`client/Hud.lua` 264, `client/Client.client.lua` 250. Every new remote goes in `default.project.json` under
`ReplicatedStorage.Remotes` and in the remotes table of [README.md](README.md); never rename `GhostClaim` /
`GhostVerdict` (they become the hex's claim and verdict). Changed rules mean changed tests, said in the PR: a test
for a rule Danzo removed (the comeback) is retired WITH its DESIGN rule, never to make something pass.

1. **Ghosts v2 core: no comeback, ghost orbs, the hex** (rules 37-42 for ghosts, 49 later).
   `shared/Ghost.lua`: drop the mark and `tick`'s comeback (`Tag.tick`'s `back`, `GHOST_COMEBACKS`); the spook becomes
   the hex (needs a held hex, no per-ghost cooldown; drain 3, ward 6 stay). New pure `shared/Orbs.lua`: spots, the
   respawn formula, one slot per player, the pool roll with an injected random source (S-rules: determinism). New
   `server/Orbs.lua`: touches judged on the server's own record each frame (no claim remote). New remote
   **`ItemEvent`** (server → all: orb taken / back, item gained / used). Ghost pool = hex only until PRs 2 and 4 fill
   it. Client: ghost orbs drawn, the held item over heads, HUD slot; `server/Bots` dummy ghosts chase ghost orbs.
   Test arena (`server/Arena.lua`): 3 ghost-orb spots. Tests: `orbs.test.luau`, `ghost.test.luau` rewritten for the
   hex, `config.test.luau`. Triggers: 2 (shared), 3 (remote, what the server trusts).
2. **Living orbs, Use, holds: crate, bear trap, ice beam** (rules 42-45, 41's per-target ward).
   New pure `shared/Items.lua`: the pools and weights, each item's footprint and life, holds (stumble 0.7, freeze 1,
   trap 1 s or 3 presses, 0.5 s immunity, cast-before-hold), dash i-frames (aimed + traps, never crates). `shared/
   Movement.lua`: a `hold` input (stumble carries at half speed, freeze slides, trap pins), no item start in a hold.
   `shared/MoveCheck.lua`: the budget shrinks to the hold's allowance (a client ignoring a trap is snapped back, H12).
   New `server/Items.lua`. New remote **`UseItem`** (client → server: one small integer, the fixture rotation 0-3 later;
   the spot is always the server's record). Client: Use bound minimally (E, V, RB, left click, an ITEM touch button);
   pry presses. Ghost pool gains crate, trap, ice. Tests: `items.test.luau`, movement and move_check additions.
   Triggers: 2, 3, 6 (the movement loop).
3. **Controls, the full table** ([controls.md](controls.md), provisional default): every row, both keyboard schemes,
   pad, the four touch buttons, the grapple input (ghosts' rotate; the living grapple itself is its own movement PR,
   §2 kit), pry with 3 taps anywhere. `client/Controls.lua` only (147 lines). Trigger: none if the table is followed;
   Danzo judges by hand.
4. **Fixtures, boost pads, boost grant, placement** (rules 46-48). `shared/Placement.lua` (pure: tetromino shapes,
   rotation, the fit test, keep-clear boxes, 1 tile from runners, 3 per ghost), boost grant = max(ramp, grant) in
   `shared/Tag.lua`'s ramp path. `server/Arena.lua` gains keep-clear zones on its exits. Server re-checks every
   placement; the preview is client-side. Pieces are server-built anchored Parts (solid for all; the client's probes
   must see them, N-rule on `CanQuery`). Tests: `placement.test.luau`. Triggers: 2, 3.
5. **Ignition and end-phase speed** (rules 50-51). Ignition: client only, from the replicated fuse (`Look`/`Hud`), art
   via the loop (sprite or particle; upload is Danzo's). End phase: `Tag` decides it (final two or past
   `END_PHASE_AFTER`), `MatchState` carries it, `Movement`'s `speedMult` and `MoveCheck`'s budget both scale by
   `END_PHASE_SPEED` (the speed check must never flag an end-phase runner). Tests: tag, move_check. Triggers: 2, 3, 6.
6. **Maps** (rule 48, §6.8). Map data instead of the hand-built test arena: floors, walls, anchors, pads, orb spots
   (living and ghost), keep-clear zones, start spots; the first map (Danzo picks which), then the others; rule 3's map
   shrink with the end phase. Triggers: 1 (which map, the shrink's shape), 2 if the map format is shared.

The living grapple (rule 17, §2 kit) is not in this list: it is its own movement PR, best after PR 3 and before PR 6.
