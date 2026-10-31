# QA round 1: ghosts v2 endgame — SCORE 8/10 (target met)

Reviewer: Opus subagent, 2026-10-31, with Studio (one player and 3 dummies, two rounds). Report verbatim:

SCORE: 8/10

I played it in Studio (one player and 3 dummies, two rounds). The fuse running out, the burn-out, the end-phase flip and the FINAL TWO line all worked on screen with no errors in the Output. The tests are sound and the server alone decides the end phase. What I could not check is the actual point of the end phase: the speed under a hand, the 120 s time cap in Play, and a second client.

GOALS:
- The end phase (rule 51): met. `Tag.endPhase` (`shared/Tag.lua:231-235`) is tested for the count, the time cap, sticky, over, a duel and a leave (`tag.test.luau:263-284`). `r.order` never shrinks, so a leave correctly counts toward the final two. In Play the Server Output showed `END PHASE: 2 alive, 83s into the round` and `END PHASE: 2 alive, 86s` in the second round.
- The server decides it: met. `Match.lua:95` builds it from `Tag.endPhase(r, now)` on the server's clock, and `Match.lua:312-315` sends a flip at once. The client reads it only through `s.endPhase == true` (`Tagging.lua:141`). No new remote and nothing new trusted from a client.
- The speed: met in code, felt by nobody. `Tag.speedMult` gives max(ramp, grant) x 1.1 (`Tag.lua:222-225`), and `Tagging.speedMult` passes `isAlive(me)`, so ghosts are not sped up. `move_check.test` pins the top run at 56.925.
- The speed check never flags it: met. `npm test` printed `end-phase fastest chain, 10 s: burst used 1.38 of 24 studs, fastest 137.83`, and the held run and the pad chain were clean. The `config.test` assert is in.
- The ignition: met. On my own runner at 3.4 s left: emitter rate 39.5, light Range 12.6, rim colour (1, 0.27, 0.08). Capture ScreenCapture_ign2 (0.9 s left) shows a red glow on the floor and the pillar, plus a bright core. ScreenCapture_dummyign and ScreenCapture_burst3 show a DUMMY holder igniting as seen by a ghost: an ember trail, a red outline and a floor glow.
- The readout: met. Measured `YOU'RE IT 3.4 size=34.0 col=(1,0.26,0.12)`. The captures show red text for a dummy holder too, so it reddens on every screen.
- The burn-out: mostly met. Client Output showed `burn-out` lines for all 5 burn-outs, including the round's last (`-1001 at (13.6, 1.8)`) and my own. The burst graphic was captured only when forced with `Ignition.burst` (ScreenCapture_burst3: a flash and sparks), never from a real burn-out, because the captures were too slow. "A leaver gets none" is a race (see UNCERTAIN).
- Readable end phase: met. ScreenCapture_ign1 shows `FINAL TWO: everyone +10% speed` in orange under the status line, and it was gone after the round ended. OVERTIME was not seen.
- Cheap every frame: met. `Look:ignite` returns early when the level is unchanged. Emitter and light are built once per Look, and only the holder's are enabled: the Dummy and Stifffchoclate emitters read `en false`.
- Verification: met. `npm test` reported 0 fails, `lint:luau` was all ok, `rojo build` succeeded, and `Match.lua` is 387 lines.

PRESERVE (done well, must survive future iterations):
- `Tag.endPhase` has no stored flag: it is worked out from the living count and `r.started`, so the server and the tests cannot drift apart.
- The proof that `MoveCheck` needs no change is a driven 10-second test, not an argument, and the 1.38 measurement is pinned.
- One `Tag.ignition` curve drives the rim, the embers, the light and the readout, so they grow together.
- The PointLight glow: it is the part that reads at play zoom (ScreenCapture_ign2). Without it the effect is a dot.
- Every client normalises the server fields (`endPhase == true`), so an older server or a malformed field reads as off.

FIX (done poorly; why it matters; concretely how to fix):
- The holder's sprite whites out in the last second or two. In ScreenCapture_ign2 my runner is a white-yellow blob, and the ember rim, which should be the main signal, is hidden behind the bright core. That is 60 particles a second, size 1.4, with LightEmission 1 adding up right on the sprite. -> Lower `LightEmission` to about 0.5, or start the embers above the head or behind the sprite plane (a negative ZOffset or an offset Attachment), or cap the rate near 35. Then let Danzo judge the rim again.
- The burst can be clipped by walls. In ScreenCapture_burst3 a burst next to the pillar is cut in half by the wall's front face: the ball sits at `RUNNER_DEPTH/2 + 0.3` (`Ignition.lua:17`), which is in front of the runner but behind the wall's front. A runner who burns out against a wall, a common place to be caught, gets half a burst. -> Put the burst at the camera-side face of the map's deepest geometry, or render it on a SurfaceGui/BillboardGui with `AlwaysOnTop`.

CONSIDER (fine but could change; why; how):
- An off-screen holder shows no ignition except the readout. In ScreenCapture_ign1 the camera followed my ghost and the holder was only an edge arrow, which does not change. -> Pulse or redden the holder's arrow (`Arrows.lua`) by `Tagging.ignition`.
- A duel that reaches the time cap is labelled "FINAL TWO". `Hud.lua` picks the text from `#state.alive <= 2`. -> Choose FINAL TWO only when the round started with 3+; that needs a `startCount` field or `#order` in MatchState.
- The FINAL TWO line has low contrast: orange (255,150,40) on the pale sky reads brown-ish in ScreenCapture_ign1. -> Add a dark stroke or a brighter yellow.
- The flash sequence is short. The 0.35 s swell plus 1.2 s of life is easy to miss when you are looking at your own runner. -> Try a 0.5 s swell and a short ground scorch decal.

UNCERTAIN (could not verify):
- The end-phase speed under a hand: whether +10% is noticeable. Danzo should run flat out on the long floor before and after the FINAL TWO line appears, and once more as "it" after about 5 s of chase.
- The 120 s time cap and the OVERTIME text in Play. Both rounds reached the final two first, at 83 s and 86 s.
- A second client's view of the ignition and the burst. Ignition on the client is from the replicated fuse, so I expect it to match.
- "A leaving holder gets no burst". `Others.drawnAt` (`Others.lua:171`) returns a spot until the leaver's model is removed (`Others.lua:75`). If the MatchState arrives before the model removal replicates, a burst plays at the leaver's last spot. The ordering is not guaranteed by Roblox; I am reasoning, not testing.
- A real burn-out's burst on screen. I saw only the Output lines and forced bursts.

## Builder decisions

- **FIX the white-out: fixed.** The embers' `LightEmission` 1 → 0.5 and the top rate 60 → 35 a second, so the rim
  stays the main signal; the light keeps the floor glow.
- **FIX the burst clipped by walls: fixed.** The burst sits at the camera side of the map's front face (the map parts
  are 8 deep about z 0, so z 4.6), in front of every wall.
- **CONSIDER the holder's edge arrow: fixed** (cheap): the holder's arrow reddens and grows with `Tagging.ignition`.
- **CONSIDER the FINAL TWO line's contrast: fixed** (cheap): a dark stroke on the line.
- **CONSIDER a longer flash: fixed** (cheap): the swell 0.35 → 0.5 s.
- **CONSIDER FINAL TWO vs a duel at the cap: deferred.** Needs a new `MatchState` field; a round that starts with two
  is a Studio case today (`PLAYERS_PER_MATCH` 4). One line in endgame.md.
- **UNCERTAIN a leaver's burst racing the model removal: kept as is,** recorded in endgame.md as a known race with no
  harm (a burst at the spot a leaver vanished from reads fine, and it is rare).
