# QA goals: ghosts v2 core (no comeback, ghost orbs, the hex)

Branch: `claude/friendly-hawking-74891i`. Handoff H18 (the build), from H16 (the adopted spec). Design: `docs/DESIGN.md`
§2 "Elimination: ghosts", §3 rules 37-42 (rule 49, the vanilla toggle, is later). Spec: `docs/systems/ghosts-v2-proposal.md`
§12 item 1 (this PR), §3 (the hex), §8 (trust). System doc: `docs/systems/ghosts.md` (rewritten for this PR).

The question for this loop: **does a ghost now have a reason to keep moving (the orbs), is the hex rare, readable and
fair, and does the server, not any client, decide every orb pickup and every drain?** Solo in Studio the other runners
are server-driven boxes (`Config.STUDIO_DUMMIES = 3`); as ghosts they run to ghost orbs and hex the holder.

## Goals

1. **No comeback (rules 38, 3).** A ghost stays out for the round: no mark, no "is back!", no `GHOST_COMEBACKS`. Every
   elimination still shrinks the next fuse (45, 35, 25). A 4-runner round with no passes ends after three burn-outs
   (at most 105 s of fuse). The H15 comeback tests are retired WITH rules 39-40 (H15 wording), not to make anything pass.
2. **Ghost orbs (rules 39, 42).** Three ghost-orb spots on the test arena, their own type (the living cannot take one).
   None before 5 s into the round; a taken orb comes back after `10 / (1 + 0.5 x ghosts)` s (10, 6.7, 5 with 0, 1, 2
   ghosts), recomputed with the ghost count now. One slot per runner: a full slot passes through an orb without
   taking it. The server rolls the taker's pool with an injected random source; the ghost pool is the hex alone until
   PRs 2 and 4 fill it.
3. **The hex (rule 40).** Only a ghost HOLDING a hex can drain: touch the holder, -3 s (`SPOOK_DRAIN`), the slot empties.
   No per-ghost cooldown any more; after any hex a shared 6 s ward (`GHOST_WARD`) for every ghost, and none while the
   holder is frozen. However many ghosts with however many hexes, the fuse burns at most 1.5x (tested as an outcome).
4. **Server decides everything (rule 6, proposal §8).** An orb pickup is judged on the server's own position record each
   frame (no claim remote; an untrusted sample never collects; the path between two samples counts, so a dash through
   an orb takes it). The hex is `GhostClaim` (one number, rate-gapped) judged like a tag on the server's history; the
   server checks the hex is held. `GhostClaim`/`GhostVerdict` keep their names. New remote `ItemEvent` is server → all
   only; the server never listens to it.
5. **Readable (rules 2, 12, 41).** Ghost orbs drawn on every screen (bright when up, faint when waiting); the held item
   shown over its holder's head to everyone; a slot readout for the local ghost; "-3s HEX <ghost>" pops on every screen;
   a ghost holding a hex is drawn brighter than an empty-handed one; ghost arrows stay hollow; the IT marker's halo
   turns pale blue while the ward holds.
6. **Pure where it can be pure.** `shared/Ghost.lua` and the new `shared/Orbs.lua` are plain functions over tables with
   tests (`ghost.test.luau` rewritten, new `orbs.test.luau`, `config.test.luau`). `npm test`, `npm run lint:luau`,
   `rojo build` pass; the Rojo tree only gained instances (`Remotes.ItemEvent`, new ModuleScripts); the line ceiling holds.

## Out of scope

Living orbs and the living pools, Use and its remote (`UseItem`), holds, i-frames and the per-target ward (PR 2); the
full controls table (PR 3); fixtures, boost pads, boost grant, placement, keep-clear zones (PR 4); ignition and the end
phase (PR 5); real maps (PR 6); the vanilla toggle (rule 49); orb and item art (placeholder neon shapes for now);
scoring ghost assists (§6.4).

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard, then the phone preset)

1. Let your fuse run out. As a ghost you should know within two seconds what to do: the status line says go get a
   ghost orb, and the orbs are visible (purple balls). Nothing tells you that you might come back.
2. Run through an orb: your slot reads HEX, a purple diamond floats over your head, your ghost brightens.
3. Touch the holder: "-3s HEX" pops, the slot empties, the halo goes pale blue for 6 s. A second hex inside the ward
   does nothing and keeps the hex.
4. Watch the dummy ghosts: they run to floor orbs, then chase the holder and hex it. Hexes should feel rare (a few per
   minute at most), never a stream.
5. The round ends after the third burn-out and the next starts with everyone alive.
6. Phone preset: the slot readout and the over-head item legible, lower-middle clear.
