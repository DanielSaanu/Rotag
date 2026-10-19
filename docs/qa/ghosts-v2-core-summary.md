# QA summary: ghosts v2 core (PR 1 of ghosts v2, handoff H18)

Goals: [`ghosts-v2-core.md`](ghosts-v2-core.md). Three rounds, one Opus reviewer each, 2026-10-19. Target 8.0 met in
round 3. Round reports (verbatim) are in [`archive/`](archive/).

| Round | Score | Main finding |
|---|---|---|
| 1 | 7 | Reviewer's Play was denied; the client half had never been seen with the remote present. Builder Played it: clean. |
| 2 | 7 | The round 1 commit had left `test/` and `INDEX.md` out, so HEAD failed its own tests (→ G4). |
| 3 | 8 | Everything seen working in Play. One ghost holds the 1.5x burn continuously: the hex is a stream, not rare. |

## Fixed

- **Round 1:** `Config.STUDIO_DUMMIES` 3 while ghosts are under test; the slot readout says only "ITEM: none" (the
  status line says what to do); held items and the readout clear while `MatchState.over`. Builder Play with
  `ItemEvent` present: orbs, hex, "-3s HEX" pop, ward, ghost status line, no errors.
- **Round 2:** the missed test files committed, clean-export run all ok, rule **G4** (stage from `git status`, never a
  path list); ghost orbs half-bright on a living player's screen, full only for ghosts.
- **Round 3:** nothing changed in code (target met). Decisions below.

## Preserved (confirmed in every round)

- Orb pickups judged only on the server's own samples, sweeping the path between two (a dash cannot skip an orb; no
  claim remote). Untrusted samples never collect.
- `canHex` reads the server's own slot and re-checks at judge time: a forged or stale claim never drains.
- The 1.5x burn cap tested as an outcome with endless hexes for 1-3 ghosts, and confirmed to the second in Play.
- Injected random source and clock; deterministic tests.
- Frame order tags → hexes → orbs → tick. A tag beats a killing hex.
- The H15 comeback tests retired WITH their rules and said so in the file, never loosened.

## Deferred, one line each

- **Hex rarity (all three rounds):** the ghost pool is hex-only until PR 2 fills it (spec §12 item 1), so every ghost
  sits on the 1.5x ceiling. **Danzo's call, see below.**
- **Ward halo unreadable under a stream:** follows the rarity decision; a 0.3 s red flash at ward end is the cheap fix
  for PR 2's HUD work.
- **Off-screen orb pointers:** the test arena fits one screen; belongs to PR 6 maps.
- **Item palette (orb vs diamond purples):** PR 2 art.
- **Teleport tolerance test (one orb within ~45 studs, same as a tag):** the MoveCheck test goes with PR 2's budget change.
- **Slot readout on a phone:** needs Danzo's eyes on the phone preset.
- **Dummies reach only the floor orbs:** noted in ghosts.md; solo pacing understates a real match.

## Open FIX from round 3, not acted on

**Hex cadence.** Measured: one ghost, a hex every 6.0 s, a 25 s fuse gone in 17.5 s. Options, none a new rule:
(a) accept the stream for this PR and let PR 2 dilute the pool; (b) an interim hex chance on the ghost roll, a
`Config` weight PR 2 removes; (c) slower ghost orbs until PR 2 (weakest: two floor orbs still give a hex every 6-10 s).
Builder's lean: (a), because (b) sends ghosts to orbs that give nothing most of the time, which is worse feel than a
strong hex for one PR; and PR 2 is next.

## Danzo's checklist (Studio, `STUDIO_DUMMIES` is 3 now, keyboard then the phone preset)

1. Let your fuse run out. Within two seconds you should know what to do: "GHOST: out this round | grab a ghost orb",
   purple balls visible. Nothing says you might come back.
2. Dash through an orb at full speed: it should still take (slot "ITEM: HEX", diamond over your head, your ghost
   brighter). This is the path-slab test with your hands.
3. Touch "it" with the hex: "-3s HEX <you>" pops, the slot empties, the IT halo goes pale blue for 6 s. Touch again
   inside the 6 s: nothing, and you keep nothing (the hex was spent). Grab another orb, touch again after the ward.
4. Watch the dummy ghosts: do the hexes feel like a stream? That is the open decision above.
5. Third burn-out ends the round; the next starts with everyone alive and no diamonds left over heads.
6. Phone preset: is "ITEM: HEX" top-left readable and clear of the Roblox top bar; is the diamond legible; is the
   lower-middle still empty.
7. Two-player (Test → Clients and Servers, say "started"): as a ghost, hex the other human. The reviewer could not
   drive this path; Claude's round 1 Play saw dummies do it, not a human.
