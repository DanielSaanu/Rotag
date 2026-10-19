# QA round 1: ghosts v2 core — SCORE 7/10

Reviewer: Opus subagent, 2026-10-19. Studio Play was denied to the reviewer by the permission classifier; it tested the
shared modules live in edit mode and reviewed the rest from code. Report verbatim below, then the builder's decisions.

---

## QA review: ghosts v2 core (H18)

**What I ran:**
- `npm test`: 13 node tests and 10 Luau suites, all passing. ghost.test prints "1/2/3 ghost(s) with endless hexes for 60 s: the fuse burns 1.500x".
- `npm run lint:luau`: every file ok.
- Studio, edit mode: `Remotes.ItemEvent`, `Shared.Orbs` and `Server.Orbs` are synced. I required the shared modules live:
  - `isUp` is false at 4.9 s and true at 5.0 s.
  - A runner-kind orb is never up, because it has no pool yet.
  - A ghost moving from x=10 to x=-10 took the orb at x=0, so a dash-through counts.
  - Respawn times are 10.00 / 6.67 / 5.00 s.
  - The first fuse is 45 s.

**What I could not do:**
- Starting Play and setting `STUDIO_DUMMIES` to 3 in Studio's copy were both denied by the permission classifier. So I saw no Output text, no client screen and no round.
- The builder's own Play (ghosts.md §8) had no `ItemEvent` on either side. So **nobody has seen the client half yet**: the orbs, the diamond over the head, the slot readout, the pop, the halo.

**First five minutes, as a player:**
- When your fuse runs out, the status line reads "GHOST: out this round | grab a ghost orb", and a top-left readout says "ITEM: none (grab a ghost orb)". That is clear, and nothing hints at a comeback.
- The weak spot is the orbs themselves. They are only drawn when on screen, with no arrow or other pointer to them. On a wider map a ghost could be told to "grab a ghost orb" without seeing one.
- The hex flow is clear: grab, brighten (transparency 0.3 against 0.65), touch, "-3s HEX" pop, pale halo.
- The real problem is rarity. The ghost pool is the hex alone (`shared/Orbs.lua:96`), so **every orb is a hex**.
  - Ghost orbs come back every 5–6.7 s, and the ward is 6 s.
  - One ghost on the 35 s fuse can likely hex every 7–10 s: roughly 6–8 hexes a minute. With two ghosts it gets close to the 1.5x cap the whole time.
  - The cap holds, but "rare, a few per minute at most" (feel item 4, rule 40) will not. This is my estimate from the code, not observed.

**Technical:** the trust model is right.
- **Orb pickups** are judged only on the server's own history (`server/Orbs.lua:245-257`), skip untrusted samples, and count the path between two samples (a slab test).
- **The hex** is one number, rate-gapped. `Ghost.canHex` checks the hex is held in the server's own slots (`shared/Ghost.lua:49`). It is then judged with `Tag.touchedBetween` (`server/Ghosts.lua:338-339`).
- **The event order** in a frame is tags, then hexes, then orbs, then `Tag.tick` (`Match.lua:291-297`). That order is sound.
- **Payloads and listeners:** `ItemEvent` has a no-op server listener, and its payloads are arrays only.
- **Leavers:** handled by `Orbs.forget` and the `present` filter in `Ghost.count`.
- **The Rojo tree** only gained instances.

SCORE: 7/10

GOALS:
- No comeback (rules 38, 3): met. `Tag.tick` lost `back` (`shared/Tag.lua:165-182`); ghost.test:111-127 checks three burn-outs and 105 s; `config.test` checks that `GHOST_COMEBACKS` and `SPOOK_COOLDOWN` are gone.
- Ghost orbs (rules 39, 42): met. `shared/Orbs.lua:104-115,154-179`; my Studio check showed 5 s first, 10/6.67/5 s respawn, ghost-only orbs and a full slot passing through; three spots at `Arena.lua:32-37`.
- The hex (rule 40): partial. The drain, the shared ward, the frozen-holder block and the 1.5x outcome are all tested. But with a hex-only pool it is not rare (see FIX).
- Server decides (rule 6, §8): met. No pickup remote; untrusted samples skipped (`server/Orbs.lua:251-252`); hex checked against the server's own slots; `GhostClaim`/`GhostVerdict` names kept.
- Readable (rules 2, 12, 41): partial, unverified. The code is all there (`client/Items.lua`, Hud ghost line, Look brightness, ward halo), but no screen has rendered it. There is also no pointer to off-screen orbs.
- Pure where possible: met. `npm test`, lint, purity check and line ceiling all pass; new `orbs.test`; the builder reports 21 mutations, 20 caught.

PRESERVE (done well, must survive future iterations):
- Orb pickups judged on the server's own path between samples (`Orbs.touches`, slab test): no claim remote to cheat, and a dash cannot skip an orb.
- `canHex` reading the server's slot (`o.held[ghost] == "hex"`) and re-checking at judge time (`server/Ghosts.lua:333`): a stale or forged claim can never drain.
- The 1.5x cap tested as an outcome with endless hexes (ghost.test:87-107), not as a constant.
- The injected `rand`, and every clock passed in as `now`: deterministic tests.
- The H15 tests were retired with their rules and that is written down (ghosts.md §8), not loosened to make anything pass.

FIX (done poorly; why it matters; concretely how to fix):
- The hex is not rare in this PR: the pool is hex-only and orbs respawn in 5–6.7 s, so ghosts drain about every 6–10 s, which breaks rule 40's "rare" and feel item 4. -> Bring it to Danzo as a design decision (trigger 1) before playtest. Option A: for now, a Config hex chance (for example 0.25) rolled with the injected `rand`; a miss empties the orb with a "fizzle" pop. Option B: a longer ghost-orb respawn until PRs 2 and 4 fill the pool. Either way, add an orbs test that pins expected hexes per minute.
- The client half has never run: the builder's Play had no `ItemEvent` and mine was blocked. -> Before merge, Play once with `ItemEvent` present. Check: violet orbs faint before 0:05 and bright after; the diamond over a dummy ghost's head; "ITEM: HEX"; "-3s HEX"; the pale halo for 6 s. Read the client Output for errors from `Items.lua`.
- The solo test the goals describe needs `STUDIO_DUMMIES = 3`, but `Config.lua:28` ships 1. With 2 runners an elimination ends the round, so no ghost ever exists in solo Studio. -> Give Danzo the exact one-line edit in the play-test instructions, or default it to 3 while ghosts are under test.

CONSIDER (fine but could change; why; how):
- No pointer to off-screen ghost orbs for a ghost: the status line tells you to grab one, but on a real map you may not see any. -> In `Arrows.lua`, give the local ghost a small violet edge marker per up ghost orb.
- The status line and the slot readout say the same thing twice. -> Leave the slot readout as the item and the status line as what to do; drop "(grab a ghost orb)" from one of them.
- Held diamonds stay over heads during `ROUND_GAP`, until the next round's sync. -> Clear `held` in `Items` when `MatchState.over` arrives.
- The diamond and the orb are close purples ((225,70,255) against (175,120,255)). Readable now, but they will clash once more items share the colour space. -> Pick the item palette when the PR 2 art lands.

UNCERTAIN (could not verify):
- Every client visual and the Output text of a real round: Play was denied.
- Whether `ItemEvent`'s join sync, fired as the player is added, reaches `Items` before its listener connects. Roblox usually queues remote events until a listener connects, so likely fine.
- The actual hex rate with three dummies: estimated from the code, not observed.
- Movement feel as a ghost, and whether the PlatformMid orb (y = 5T + 2.5) reads as worth the climb. Danzo should try a jump-and-dash route to that orb on keyboard and the phone preset, and check the top-left slot text at phone width.

---

## Builder decisions

(filled in below after acting)

**PRESERVE:** all five kept. The slab test, `canHex` on the server's slot, the 1.5x outcome test, injected `rand`/`now`,
the retired-with-the-rule note in ghosts.md §8. Re-read the diff before committing: none touched.

**FIX 1, hex rarity → deferred by design, not skipped silently.** The hex-only pool is the spec's own transitional
state (`ghosts-v2-proposal.md` §12 item 1: "ghost pool = hex only until PRs 2 and 4 fill it"). Rarity arrives when
PR 2 adds crate, trap and ice to the ghost pool; adding a fizzle chance now would be a rule (trigger 1) that PR 2
deletes. Danzo played this build and called it good. Recorded for Danzo: if the next two-player test feels like a
hex stream, the interim knob is a longer `ORB_RESPAWN` for ghost orbs, his call.

**FIX 2, client half never seen → done, by the builder in Studio (Play via the MCP, 2026-10-19).** With `ItemEvent`
present and `STUDIO_DUMMIES = 3`: 3 orb balls drawn, status line "GHOST: out this round | grab a ghost orb", slot
readout "ITEM: none", the pop "-3s HEX Dummy" on the client, Server lines `orbs: -1000 took ghost orb 3: hex` and
`ghost: HEX -1000 -> -1001, fuse 18.7s (-3.0s), ward 6s`. No error or warning from `Items.lua`, no `ItemEvent`
warning on either side. Danzo also played it after the `rojo serve` restart: "it all works".

**FIX 3, `STUDIO_DUMMIES` ships 1 → done.** `Config.STUDIO_DUMMIES = 3` while ghosts are under test (comment says so);
ghosts.md knob table updated.

**CONSIDER, duplicate text → done.** The slot readout now says only "ITEM: none"; the status line keeps "grab a ghost
orb". Seen in the Play above.

**CONSIDER, held diamonds linger through `ROUND_GAP` → done.** `Items.draw` takes `roundOver`; icons and the readout
clear while `MatchState.over` is set (`Client.client.lua` passes it).

**Deferred:** off-screen orb pointers (the test arena fits one screen; belongs with PR 6 maps, noted in INBOX); the
item palette (PR 2 art, as the reviewer says).
