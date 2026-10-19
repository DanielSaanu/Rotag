# QA round 3: ghosts v2 core — SCORE 8/10

Reviewer: Opus subagent, 2026-10-19, HEAD d9bf0d8. Played solo in Studio with 3 dummies, drove the client, read both
Outputs, stopped Play. Report verbatim below, then the builder's decisions.

---

## QA round 3: ghosts v2 core (branch claude/friendly-hawking-74891i, HEAD d9bf0d8)

**What I ran**
- `npm test`: all 10 Luau suites ok. ghost.test prints "1/2/3 ghost(s) with endless hexes for 60 s: the fuse burns 1.500x".
- `npm run lint:luau`: every module ok.
- `rojo build`: built.
- I started Play in Studio (studio 4439bd34…), drove the client with execute_luau, read the Output, then stopped Play.
- No tracked files were modified.

**What Play showed**
- No errors from Rotag code. The only noise was the UIBlox FoundationProvider warnings and `rbxassetid://203785492 … Asset type does not match` (not from this PR).
- Round 1, in order:
  - The fuse ran out on the player, then on -1000, then on -1001.
  - Then: "round over, winner -1002", followed by "round 2: 4 runner(s)".
- After the player burned out, the HUD read "GHOST: out this round | grab a ghost orb" and the slot "ITEM: none". The three orbs were at (-40,2.5), (42,22.5) and (104,2.5), drawn at T=0.10 for a ghost.
- I walked the player's body through orb 1:
  - Server log: `[Rotag] orbs: 8061215879 took ghost orb 1: hex`.
  - The slot read "ITEM: HEX", the orb went to T=0.85, and a diamond showed over the head at y+6.75.
  - The status line read "GHOST: HEX held, touch Dummy2 for -3s | ward 3.4 … READY".
- Dummy ghost: `orbs: -1000 took ghost orb 3: hex`, then `ghost: HEX -1000 -> -1001, fuse 14.4s (-3.0s), ward 6s`, and a second one at 5.4s.
- In round 2 I polled the client for 55 s:
  - "-3s HEX  Dummy" popped at 40.1, 46.1 and 52.1 s, exactly 6.0 s apart.
  - The halo went from 255,90,60 to 170,215,255 at the first hex and stayed blue until the round ended at 53.8 s.
  - Dummy2's 25 s fuse lasted 17.5 s.

SCORE: 8/10

GOALS:
- No comeback: met. `GHOST_COMEBACKS`/`SPOOK_COOLDOWN` are absent (config.test.luau:15). In Play, round 1 ended after three burn-outs with no "is back", and round 2 started with all 4 runners.
- Ghost orbs: met. Server/Orbs.lua:52-71 builds takers from the server history and skips untrusted samples. In Play, the orbs came up after ORB_FIRST, the pickup was logged server-side, and the orb went faint. Respawn and the one-slot rule are pinned in orbs.test.luau.
- The hex: partial.
  - The rules work: Ghost.canHex requires a held hex, the shared ward is 6 s, and the 1.5x cap holds in tests and in Play.
  - It is not rare. One dummy ghost hexed at the cap, every 6.0 s, three times in 12 s. Checklist item 4 ("never a stream") fails today. The spec defers rarity to PR 2.
- Server decides everything: met.
  - Orb pickups use the server's own record and a path slab test (shared/Orbs.lua:61-68), with no claim remote.
  - GhostClaim takes one number and is rate-gapped (server/Ghosts.lua:80-95). It is re-judged after the tag claims, against the held slot (Ghosts.lua:47-60).
  - ItemEvent is server → client only, with a no-op listener (server/Orbs.lua:85).
- Readable: met (one exception, see FIX).
  - Seen working in Play: orbs half or full bright, the over-head diamond, the slot readout, "-3s HEX <ghost>", the pale-blue halo.
  - Ghost brightness when holding a hex was checked in code only (Client.client.lua:159-161).
  - The halo cannot be read while hexes stream (see FIX).
- Pure where it can be: met. Ghost.lua and Orbs.lua are pure, with tests committed (the clean-export issue from round 2 is fixed). Lint and build are clean, and the Rojo tree only gained `Remotes.ItemEvent` plus ModuleScripts.

PRESERVE (done well, must survive future iterations):
- **Path slab test on the server's samples** (shared/Orbs.lua:61-68). A dash cannot skip an orb, and a client never claims a pickup.
- **Untrusted sample handling** (server/Orbs.lua:58-61). An untrusted sample never collects, and an untrusted previous sample drops the path, not the pickup.
- **Shared ward as the burn cap** (shared/Ghost.lua). The 1.5x limit is tested as an outcome over 1-3 ghosts, not as a constant.
- **Frame order in Match.step** (Match.lua:306-312): tags, dummy tags, hexes, dummy hexes, orbs, then tick. A tag beats a killing hex, and a hex taken this frame is usable next frame.
- **`drained` in GhostVerdict** (→ N7). The pop shows what really came off the fuse.
- **Defensive client parsing** in Items.onEvent and Tagging, and the remote-missing warnings (→ T6).

FIX (done poorly; why it matters; concretely how to fix):
- **Hex cadence is a stream, not rare (rule 40 "rare"; Danzo's checklist item 4).**
  - Why: in Play, one dummy ghost drained Dummy2's 25 s fuse in 17.5 s, landing a hex every 6.0 s. That is the cap, hit continuously. A holder chased by one ghost loses about 30% of every fuse, which works against "tense, not hopeless". With the pool hex-only and a 5 s ghost-orb respawn, the ward is the only limiter.
  - How (pick one and record it in H18; no new design needed):
    - Ship a placeholder ghost pool weight now: e.g. `{ "hex", 8 }, { "nothing", 92 }`, an empty roll that leaves the slot empty.
    - Or gate the orb: only ghost orbs respawn at 10 s flat until PR 2.
    - If neither, Danzo should explicitly accept the stream for this PR in INBOX. Today it is "deferred by spec", and the felt goal says otherwise.
- **The ward halo cannot be read under a stream** (Hud.lua:227, 110).
  - Why: hexes landed exactly as the ward ended, so the halo stayed pale blue for 13.7 s straight (40.1 → 53.8 s). It never told anyone the ward had lapsed.
  - How: fixing the cadence above mostly solves it. Otherwise flash the halo red for ~0.3 s at ward end, or pulse faster in the last second.

CONSIDER (fine but could change; why; how):
- **Player-side hex not confirmed by me.**
  - Why: my scripted chase writes the root CFrame, but Tagging.hex reads the Movement state `s` (Client.client.lua:108). No `ghost: hex … received` line appeared, so I did not exercise this path. The builder reports seeing it in round 1.
  - How: Danzo should do felt-checklist step 3 by hand.
- **The pickup teleport tolerance stands** (one jump under ~45 studs).
  - Why: my 10-stud jump plus ~168 studs/s burst still collected (server/Orbs: "8061215879 took ghost orb 1").
  - How: pin it with the MoveCheck test planned for PR 2.
- **Halo colour while hidden.**
  - Why: `placeMarker(nil)` leaves the halo blue at round over. It is invisible and harmless, and it is recoloured on the next placement.
  - How: reset it on hide if a later marker reuse ever shows it.
- **Dummies reach only the two floor orbs** (Bots.orbX, REACH_Y).
  - Why: the PlatformMid orb is effectively the human's private orb in solo testing, so solo hex pacing understates a real 4-player match.
  - How: worth a note in ghosts.md.

UNCERTAIN (could not verify):
- Movement feel and phone legibility: the slot readout at 18 px top-left and the 1.3-stud diamond on a phone-sized screen. Danzo needs to look on the phone preset.
- That a ghost holding a hex is drawn brighter. I saw the code path (Look:ghost "ready" vs "cooling") but did not check it in Play.
- Hollow ghost arrows on screen. Checked in code only (Arrows.lua:57-101).
- Behaviour under real latency and with two humans: a hex dropped as "warded" because client and server ward clocks differ by about one ping (the hex is kept, so this is only a retry).
- A player leaving while holding a hex (server/Orbs.forget fires a slot event). Read in code, not exercised.

---

## Builder decisions

Target met (8.0), loop stops here. Open FIX items are carried to the summary and to Danzo, not acted on blind:

**FIX, hex cadence → Danzo's decision, raised in all three rounds.** Measured now: one ghost, a hex every 6.0 s, a
25 s fuse gone in 17.5 s. The honest reading: the 1.5x cap is the ceiling, and on a hex-only pool every ghost sits
on the ceiling. Three options for Danzo, none a new rule: (a) accept the stream for this PR and let PR 2 dilute the
pool (the spec's path); (b) an interim hex chance on the ghost roll (a `Config` weight, removed by PR 2); (c) slower
ghost orbs until PR 2 (`GHOST_ORB_RAMP` 0 → 10 s flat; still ~every 6-10 s with two floor orbs, so weakest).

**FIX, ward halo unreadable under a stream → follows the cadence decision.** If (a), a 0.3 s red flash at ward end
is the cheap fix and goes in with PR 2's HUD work. Recorded in INBOX.

**CONSIDER, dummies reach only the floor orbs → noted in ghosts.md** (solo pacing understates a real match).

**CONSIDER, halo colour while hidden, teleport tolerance test → PR 2** (already planned there).

**PRESERVE:** all six kept.
