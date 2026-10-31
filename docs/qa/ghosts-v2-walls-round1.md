# QA round 1: ghosts v2 closing walls — SCORE 8/10 (target met)

Reviewer: Opus subagent, 2026-11-01, with Studio (solo, 3 dummies, Config untouched). Report verbatim:

SCORE: 8/10

How I tested: a real Play in Studio (solo, 3 dummies, Config untouched), Output read from the Server log, and screen captures. Rendering worked this time, so the walls have now been seen on screen for the first time.

Studio Output, round 1: `tag: -1000's fuse ran out, -1001 is it` / `walls: closing in: centre 32.1, half-width 44.0 -> 24 over 20s` / `tag: END PHASE: 2 alive, 83s into the round`. The holder then burned out (`round over, winner -1002`). The dummies stayed inside, so there was no wall kill this run. No errors or warnings; the only other line was the stock `ContentId 203785492` one.

Captures:
- **ScreenCapture_2**: the edge appears with the line `FINAL TWO: the walls close in  |  +10% speed`.
- **ScreenCapture_3**: both edges on screen, the box closed, both runners inside.
- **ScreenCapture_4**: `<<<  GET BACK IN  2.4`. This one is **driven, not real**. I loaded a copy of `client/Walls` in the Client datamodel and fed it a made-up window with me outside, because I could not get my own living runner past a wall in a real end phase.

Tests and tools:
- `npm test` exit 0, all Luau suites ok, including `walls ok`.
- `lint:luau` clean, including shared/server `Walls.lua`.
- `rojo build` passes.
- The sourcemap has three new `Walls` entries, all ModuleScript.

The player's view: when the end phase starts, two bright red neon edges appear and close in. They are readable at once and feel like SpeedRunners. The band past each wall does not read as red, though: over the blue sky and navy map it comes out as a dim mauve-grey haze. It reads as "out of bounds", not as "danger". The `GET BACK IN` line is big, hot and clear, and its arrow points home. The burn-out, the end-phase line and the walls arrive on the same frame and feel like one moment, not two systems.

Technical view:
- The server logic is clean. It is one pass per frame (`shared/Walls.lua:80-123`) and judges trusted samples only. Eliminations go through the shared `Tag.eliminate` (`Tag.lua:169-192`), so burn-outs and wall kills take one path. `Tag.tick` now calls into it.
- `dt` is capped at 0.1 (`server/Walls.lua:161`), so a hitch cannot eat a grace in one frame.
- A cheater cannot stay outside forever on untrusted samples: MoveGuard rebuilds the body at its last trusted spot.

GOALS:
- 1 Walls open with the end phase: met - Output `closing in: centre 32.1, half-width 44.0` on the END PHASE frame (430.0). WALL_START_MIN is respected and nobody started outside.
- 2 Close and drift: met - capped ease in `shared/Walls.lua:84-87`, linear `halfWidth`. Capture 3 shows the box closed and held. The sway pin is in `walls.test.luau`.
- 3 Grace, not instant kill: met (code and tests), not seen live - reset on back-in and pause on freeze/hold at `Walls.lua:98-105`. Ghosts are skipped via `r.alive`.
- 4 Not solid: met - `client/Walls.lua:30` turns CanCollide, CanQuery and CanTouch off. As a ghost I crossed a wall freely (captures 2 and 3).
- 5 Who dies first: met - sort at `Walls.lua:112-116`. `Tag.eliminate` refuses once the round is over, and only a holder's death moves the fuse.
- 6 Server decides: met - newest sample from Match history, `trusted ~= false`. No new remote. MatchState carries arrays (`Match.lua:98`) and the client validates them (`Tagging.lua:159-168`).
- 7 Readable: partial - the edges and the label are excellent and the phase line text is right. But the label overlaps the phase line (see FIX), the band reads mauve rather than red, and I did not see the edge glow.
- 8 Kill reads: partial - the code is right (`Ignition.lua:55-73`), but I saw no wall kill live this run. Two edge cases are miscoloured (see CONSIDER).
- 9 PR 5 preserved: met - `Tag.endPhase` is untouched, `Ignition.burst` only gained a colour argument, and MoveCheck is untouched.
- 10 Cheap: met - four parts moved, two frames, one label. No camera changes.
- 11 Verification: met - tests, lint and rojo build all pass; the sourcemap only gained the three ModuleScripts; Match.lua is 391 lines.

PRESERVE (done well, must survive future iterations):
- `Tag.eliminate` as the only elimination path (`Tag.lua:169`): burn-outs and wall kills cannot drift apart.
- Judging on the server's own trusted record, where an untrusted sample changes nothing either way: no client can talk its way out of, or back into, a grace.
- The neon edges: on screen they read instantly as "the screen is closing in". This is the SpeedRunners element done right.
- The grace pauses for any hold or the tag freeze, so a trap at a wall never kills.
- `WALL_START_MIN`: the walls open near the edge of the screen and visibly sweep in. Capture 2 shows one edge arriving.

FIX (done poorly; why it matters; concretely how to fix):
- **`GET BACK IN` covers the end-phase line.**
  - Why: the walls label sits at `fromScale(0.5, 0.3)`, 70 px tall, with IgnoreGuiInset (`client/Walls.lua:65`). The Hud phase line is a fixed 106 px offset under the inset (`Hud.lua:138`). Measured in Play at a 1656x606 viewport: the phase line spans screen y 164-188, inside the walls label's box (147-217). Both show at once in exactly the moment that matters: the end phase with you outside.
  - On a short phone screen, 0.3 x height moves up into the `YOU'RE IT` and ghost lines.
  - How: put the label in the Hud's own row stack below the phase line, e.g. a fixed offset of about 150 under the inset, or the free count slot at 148. Or hide the phase line while you are outside.
- **The band is not red.** At 0.72-0.8 transparency over blue and navy, `TINT` (190,15,30) mixes to mauve-grey (captures 2, 4). The danger reads from the edges, not the zone.
  - How: lower the band transparency to about 0.55-0.6, or warm it (e.g. 255,30,30). Or add a second, more opaque thin strip just past the edge as a gradient.

CONSIDER (fine but could change; why; how):
- **Countdown sawtooth during a hold.**
  - Why: `Tagging.graceLeft` always subtracts `since()`, but the server pauses the grace during a hold and re-sends 4 times a second. The number will tick down and snap back up, roughly 2.4 -> 2.2 -> 2.4.
  - How: send `held = true` on that row, or a `paused` flag, and skip the subtraction.
- **A holder who burns out while outside bursts red, not orange.**
  - Why: `Ignition.lua:64` tests `p.outside` before `p.it`.
  - How: if the fuse ran out (`id == p.it` and `p.fuse` about 0), pick orange.
- **A leaver who was outside may get a red `walled out` burst on other screens.**
  - Why: `Tag.leave` clears `alive` and `Others.drawnAt` may still return the body. Goal 3 says a leave is not a wall kill.
  - How: carry a `walled = { id }` list in the elimination's MatchState, or skip ids missing from `s.order`.
- **The edge beat's tempo is pegged to `WALL_START_MIN`** (`client/Walls.lua:94`). With a wide start (hw0 76 in the builder's run), it stays at 1 beat a second for most of the close.
  - How: send hw0, or compute it from progress through `WALL_CLOSE_TIME`.
- **MatchState keeps going out 4 times a second after the walls have closed** (`server/Walls.lua:194`). This is harmless but wasteful.
  - How: send only on a change, or when the centre moves more than 0.5 stud since the last send.

UNCERTAIN (could not verify):
- The real `GET BACK IN` path under a hand: the server's count arriving, the 3 s feel, out-and-back-in reset. My capture was driven with a made-up window. Danzo: with `END_PHASE_AFTER = 15` and `STUDIO_DUMMY_TAGS = false`, step out, back in, then out again and watch for a full 3.0.
- A real wall kill on screen: the red burst and `walled out:` line. No dummy died to the walls this run.
- The off-screen edge glow (`client/Walls.lua:104-111`): never visible in my captures.
- Whether the +10% speed plus the closing walls feels like one ending or too much: that needs hands on a keyboard and a phone.
- Phone layout of the 600 px-wide label (`fromOffset(600, 70)`, TextSize 44, swelling 25%) on a narrow screen. It is likely clipped or too large there.

Play was stopped. No tracked files were modified. My driven `client/Walls` copy existed only inside that Play session.

## Builder decisions

- **FIX the label covering the end-phase line: fixed.** A fixed row under it (screen y 193-263 vs the line's 164-188,
  measured in Play), 90% of the screen wide.
- **FIX the mauve band: fixed.** Warm red (255, 30, 30) at 0.6 transparency.
- **CONSIDER the sawtooth during a hold: fixed.** The row carries `held`; the client stops counting while it is set.
- **CONSIDER a holder burning out while outside: fixed.** Orange when the fuse is at 0.
- **CONSIDER the beat pegged to the start width: fixed.** Progress from the width the client first saw.
- **CONSIDER the 4-a-second resend after the box closed: fixed.** Only while the walls move.
- **CONSIDER a leaver's red burst: deferred.** Rare and harmless; telling a leave from a kill needs the order in the
  state. Noted in the summary.
