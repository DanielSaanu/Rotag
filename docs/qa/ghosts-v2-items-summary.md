# QA summary: ghosts v2 items (PR 2 of ghosts v2, handoff H19)

Goals: [`ghosts-v2-items.md`](ghosts-v2-items.md). Two rounds, one Opus reviewer each, 2026-10-19. Target 8.0 met in
round 2. Round reports (verbatim) are in [`archive/`](archive/). Both reviewers Played for real in Studio.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7 | Items work end to end live. Two fairness holes: a jittered pry could get an honest player snapped back, and an ignored freeze was never caught. |
| 2 | 8 | Fixes hold up, no honest snap-backs. The TRAPPED / FROZEN line was hidden behind the tag-freeze line. |

## Fixed

- **Round 1 (heavy agent):** presses during a trap are never gap-dropped on the server, and the client stays pinned
  until the server frees it (no self-free, so no desync). The speed check now caps a held runner's budget from the
  server's own measured speed for the WHOLE hold: an ignored freeze is caught at 0.76 s (was never), a trap at 0.34 s
  (was 0.83), a stumble at 0.68 s (was never); stand-then-sprint inside a hold is caught too. "Tap anywhere" on touch.
- **Round 2:** the hold line now wins over "X is it: run!" (routine). The budget returns to the full burst when a hold
  ends, so a dash-jump out of a pried trap has 22.6 studs to spare (was 0.49). A runner trapped in the air drops onto
  the trap instead of hanging. `Config.STUDIO_DUMMY_TAGS` turns dummy tagging off for solo item testing (heavy).

## Preserved (confirmed in both rounds)

- The spot of every placed item comes from the server's own newest trusted sample, never the client. A suspect
  sample places nothing and collects nothing but still gets hit.
- Pure `Items.step` with swept boxes and per-thing hit sets; a beam catches each runner once and several at once.
- Dash starts taken from the server's record with the cooldown enforced there.
- Holds never touch Tag: a trapped runner was tagged, live, in both rounds.
- Dummies use items through the same press path as players, so a solo test exercises the real rules.
- `Items.acceptPress` and a client that never frees itself. `MoveCheck.hold` fed by `recentSpeed`, never the client's vx.

## Deferred, one line each

- **Owner immunity to own trap and crate:** the spec arms them 0.5 s after dropping once the owner steps off; a dummy
  got caught by its own trap. Feel call for Danzo.
- **Trap vs crate silhouette:** both are low blocks told apart by shade; a jaw shape waits for real art.
- **Dummies reach only the floor orbs:** fine for now, Danzo runs to the platform orbs himself.
- **A runner who becomes a ghost mid-hold** probably stays pinned up to 1 s. Reasoned from code, harmless, not seen.
- **Known honest limit** (trust.md §10): a client that learns of a hold more than 0.3 s late while running gets snapped
  back, i.e. about 300 ms of ping. A cheat still drifts ~40 studs in a freeze against an honest ~36.

## Open FIX from the last round, not acted on

None. The round 2 FIX was done before the loop closed.

## Danzo's checklist (Studio, `STUDIO_DUMMIES` 3; set `Config.STUDIO_DUMMY_TAGS = false` for 1-6, back to `true` for 7)

1. Run through a gold orb at 0:05: slot reads CRATE, TRAP or ICE, an icon over your head. As "it" you mostly get ICE.
2. Press E: crate behind you / trap at your feet / cyan beam ahead. Slot empties.
3. Step on a dummy's trap and MASH any key: "TRAPPED: mash any key 1/3" counts up and you are out well under a second,
   with no snap-back afterwards. Step on another and do nothing: it lets go after 1 s. Nobody has pried by hand yet.
4. Dash over a trap: nothing. Dash into a crate: you still stumble. Dash through a beam as it fires: no freeze.
5. Get frozen: you slide to a stop over a second with no input. Does 1 s feel fair? Does the half-speed stumble?
6. Straight after any hold, nothing can hold you for half a second. While held, E does nothing.
7. Dummy tags back on: a trapped you can still be tagged, and as "it" a trapped you can still tag.
8. As a ghost: most ghost-orb rolls are now crate, trap or ice; the hex about 1 in 5. The dummies' hexes no longer stream.
9. The owner-immunity call: drop a trap, turn back onto it after a second. If being caught by your own trap feels
   cheap, say "own traps safe".
10. Phone preset: the ITEM button sits above JUMP on the right, 64 px, out of the lower-middle; 3 taps anywhere pry a trap.
