# QA round 2: ghosts v2 placement — SCORE 8/10 (target met)

Reviewer: Opus subagent, 2026-10-31, with Studio. Report verbatim:

SCORE: 8/10

Tests and build: `npm test` passed every suite. The relevant lines: `pad: rises 11.38 studs (a held jump: 14.25)`, `pad chain + grant, 10 s: 12 launches, up budget used at most 2.63 of 10.50 studs`, `map rule: 45 pieces from 15 ghosts filled the room; the keep-clear shaft is still open`. `npm run lint:luau` was ok on every file and `rojo build` succeeded. The tree is clean and Play is stopped.

What I saw in Studio, round by round:
- **Round 1.** I was "it" and stood still until the fuse ran out (`8061215879's fuse ran out`). I ran into the ghost orb (`8061215879 took ghost orb 1: fixture`).
  - The HUD read `GHOST: PIECE | Use places it ahead, grapple turns it (red: no room)` and the slot read `ITEM: PIECE`.
  - The preview was an L at rotation 0, with cells at x -30/-26/-22 (y 2) and -30 (y 6). The ghost's root was at x -37.7, so the piece sat one tile ahead.
  - The keep-clear part showed at (82, 24), 28x48, at transparency 0.8.
  - Pressing W moved the cells to -30/-26/-26/-26 (y 2, 2, 6, 10), so the turn works.
  - My E press came after the round ended and logged `use ... dropped: no round`.
- **Round 2.** I was a ghost again and took a pad (`took ghost orb 1: pad`). The preview slab was centred at x -47.99. E logged `placed pad at (-52, 0) rot 0 facing -1`, and the server part was `Pad -48, 0.5`, so the preview matched the placement. I was not launched while standing on my own pad. I walked off and back on: `[Rotag] pad: launched off pad 1`, and the ghost rose to y 12.1. No server warnings.
- **Round 3, living.** The Studio dummies tagged me back and forth (STUDIO_DUMMY_TAGS), so no dummy ghost ever placed a pad while I was alive. So I sent a `placed` pad event from the server's ItemEvent at x 28, with the server's own payload shape. After my tag freeze ran out I pressed D and got `[Rotag] pad: launched off pad 900`, root at (46.8, 13.3).
  - This proves the living client's launch path. It does not prove a pad the server placed itself (but that one reaches the client as the same `placed` event).
  - Nothing in the server Output flagged the move (the only non-Rotag line was the stock decal).
- **The grant, shown on screen.** I sent `grant` events from the server for a dummy and for me. Both drew the halo, but the capture (ScreenCapture_2) shows a flat yellow rectangle behind the sprite, not an orange halo. My HUD showed the tag-freeze line, not BOOST.

GOALS:
- Ghost pool and piece in orb/sync: met. `shared/Items.lua` POOLS has 30/15/15/12/10/10/8 and `orbs.test` passed. My two ghost rolls were fixture and pad, and the piece's shape reached my client: the preview showed an L.
- Placement: met. One tile ahead and turned by W, both seen live. The pad was centred under the ghost (preview -47.99, part -48). The ghost's own pad did not fire under it.
- The preview tells the truth: partial. Preview and placement matched exactly while standing still. I never saw a red preview live. Known gap: while running, the client draws at its predicted spot but the server places from its newest sample, which can be up to a tile behind (deferred).
- Map rule: met. The `placement.test` 45-piece fill passed, Output said `15 static boxes`, and the keep-clear part shows while a part is held.
- Fixtures solid, cap and fade: partial. Covered by tests and the builder's Play. I did not place a fixture myself (the round ended first).
- Boost pads: met. A ghost was launched off a server-placed pad, and a living runner off a pad sent by ItemEvent. The move check flagged nothing. The test chain passed.
- Boost grant: partial. `Tag.speedMult` = max(ramp, grant) is tested, and the injected grant drew the halo. I did not see a real ghost's touch-grant, and the BOOST line is the lowest-priority HUD status.
- Server decides: met, by reading the code. `server/Items.lua` use() reads the newest TRUSTED sample, `o.piece[id]` and `c.facing`. `server/Placement.place` refits on its own state, and rot is checked 0-3 in onUse. One known limit: the pad launch is the client's own (see CONSIDER).
- Readable: partial. The pale-violet preview reads near-white in ScreenCapture_1, and the grant glow reads yellow. Both are placeholders.
- Pure and tested: met. New `shared/Placement.lua` with `placement.test.luau`, `Match.lua` untouched, no new remote, three new ModuleScripts.

PRESERVE (done well, must survive future iterations):
- **The fit test.** `shared/Placement.fits` is the same pure, allocation-free function on both sides, with the reason string carried to the HUD. Preview and placement agree by construction.
- **No launch on the frame a pad first appears.** In `client/Place.lua` frame(), `inside[n] == nil` on that frame blocks the launch. This cleanly stops a ghost firing its own pad.
- **The launch keeps your speed.** `Movement` step 4b takes max of the launch and the speed you already carry that way, refreshes dash and double jump, and the move-check chain test is the safety net.
- **The map rule is a box test plus the 45-piece room-fill test.** Simple and future-proof for PR 6's map data.
- **One Part per row run** (`server/Placement.lua` build): no seams under a runner on a piece.

FIX (done poorly; why it matters; concretely how to fix):
- **The BOOST line gets hidden** (`client/Hud.lua` ~244). It sits in the final else, so the tag freeze, any hold, and "X is it: run!" all hide it, and grants arrive mid-chase. Fix: show it on its own label, or append it to whichever status line is showing.
- **The preview still draws after the round ends.** `Place.draw` → placing() (`client/Place.lua`) does not check `state.over`, so the preview keeps drawing between rounds. I saw a Use refused with `no round`. Fix: return nil from placing() when `Tagging.state().over`, as Client.client.lua already does for the buttons.
- **Preview and grant glow colours read wrong.** Neon at 0.45 / 0.3 transparency washes out: the "pale violet" preview reads white and the orange glow reads yellow (ScreenCapture_1/2). That weakens rule 29's colour coding until the art block. Fix: SmoothPlastic or a darker violet (around 160,140,255) for the preview, and a deeper orange without Neon.

CONSIDER (fine but could change; why; how):
- **A cheating client can launch anywhere.** The pad launch is client-decided and bounded only by the speed check (`server/Placement.lua` header), so a cheater can do a 105 up-launch anywhere, at will, inside the speed budget. Fix: have the server log or flag a sample whose rise exceeds a held jump while no pad overlaps its path. Record the call in trust.md either way.
- **A runner who enters a pad on the frame it appears is never launched.** It happens when a ghost sets the pad in front of a runner moving fast (`inside[n]` nil, then true). Fix: record the pad's arrival frame and allow entry from the next frame if the runner was outside at arrival.
- **Preview vs server sample while running.** Fix: on the client, place the preview from the last position it sent, so it shows where the server's newest sample will put the part.
- **Testing dummies are hard to escape.** With STUDIO_DUMMY_TAGS on, a solo tester is tagged back and forth and never stays living long enough for a dummy ghost's pad. Fix: a Studio-only switch that makes dummy ghosts roll only pad or grant.

UNCERTAIN (could not verify):
- A living runner launched off a pad the SERVER placed. Only proven with a `placed` event I sent from the server; the launch code path is identical.
- A real touch-grant from a dummy ghost, and the felt +15% speed.
- A red preview live: keep-clear, map, a runner. A fourth fixture fading; a fixture blocking or carrying the player.
- Two clients: whether the preview lines up with the piece on the other screen, and timing under lag.
- Whether the launch feels right, 100 across / 105 up. Danzo should run onto a pad from a standstill and at full sprint against the arrow, then double-jump at the top.

## Builder decisions

- **FIX the BOOST line hidden: fixed.** "BOOST +15%  n.ns" is appended to whichever status line shows (or stands alone
  when none does), so a grant mid-chase, in a hold or at a tag freeze is still seen.
- **FIX the preview after the round ends: fixed.** `placing()` returns nil once `Tagging.state().over`, as the touch
  buttons already do.
- **FIX the washed-out colours: fixed.** The preview is SmoothPlastic at (160, 140, 255), the grant glow SmoothPlastic
  at (255, 110, 20); the keep-clear zone and the red refusal keep Neon (they are meant to shout).
- **CONSIDER a runner entering a pad on the frame it appears: fixed** (cheap): a pad someone ELSE placed launches on
  the first frame it is touched too; only the placer's own pad needs a real entry.
- **CONSIDER a cheat launching anywhere: recorded in trust.md §8** (the launch is inside the budget by construction;
  a server-side rise check against the pad list is the knob if it is ever abused). No code.
- **CONSIDER preview vs the server's sample while running: still deferred** (round 1). Exact when still.
- **CONSIDER a Studio switch for dummy-ghost rolls: deferred.** `STUDIO_DUMMY_TAGS = false` already keeps a tester
  living; one more knob is not worth its line until a tester asks.
