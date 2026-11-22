# Research: confirming tags under latency

_22 Nov 2026. Desk research for the "tags don't register" report in
[`../qa/playtest-2026-11-20.md`](../qa/playtest-2026-11-20.md) #1. Read with [`../systems/tag.md`](../systems/tag.md) §2
and [`../systems/netcode.md`](../systems/netcode.md). Research only: changing the tag check is escalation trigger 3._

**Source caveat.** This session's network blocked page fetches (developer.valvesoftware.com, devforum.roblox.com,
edgegap.com), so the numbers below come from search-result excerpts of those pages, not full reads. Most Roblox
figures are DevForum community measurements, not official docs. Treat them as starting points to measure against.

## 1. The three ways games confirm a hit

| Model | How it works | Feels | Cheat surface | Examples |
|---|---|---|---|---|
| **Client-claimed, server sanity-checked** | The attacker's client detects the hit on its own screen and tells the server; the server checks distance against its CURRENT positions plus a buffer | Generous for the attacker | Reach hacks inside the buffer | Most Roblox sword and combat games |
| **Server-authoritative** | The server detects overlaps itself on its own positions; clients only send input | Strict; laggy players miss what they saw | Smallest | Rotag's dummy bot (rewind 0) |
| **Lag-compensated (rewind)** | The client says "I hit X at time t"; the server rewinds X to where the attacker SAW it, then tests | "Favour the shooter"; the victim is sometimes hit "behind a wall" | Bounded by the rewind cap | Source engine, Overwatch, Valorant |

### Valve Source
- Clients render other entities **100 ms in the past** by default (`cl_interp 0.1` = 2 x 1/`cl_updaterate` 20),
  so one lost snapshot still leaves two to interpolate between. Clamped to at most 0.25 s.
- The server keeps **1 s of position history** (`sv_maxunlag`) per player and, for each command, rewinds the other
  players to `command time - latency - client interp`, tests, then restores. Only players are rewound.
- Sources: https://developer.valvesoftware.com/wiki/Lag_Compensation ,
  https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking ,
  https://developer.valvesoftware.com/wiki/Interpolation
- Plain-language walkthrough of the same ideas (interpolation ~100 ms "usually not noticeable"; the client sends
  the shot's timestamp and the server judges against the world at that moment):
  https://gabrielgambetta.com/entity-interpolation.html , https://gabrielgambetta.com/lag-compensation.html

### Overwatch "favour the shooter"
- Blizzard's 2016 developer update (Tim Ford, Philip Orwig): in laggy or non-optimal situations the netcode
  "basically always favours the shooter". The server rewinds hitboxes to the shooter's frame of reference before
  judging. Tick raised to 60 Hz on PC (from ~21).
  https://gameranx.com/updates/id/47381/article/overwatch-developers-discuss-netcode ,
  GDC 2017 "Overwatch Gameplay Architecture and Netcode": https://gdcvault.com/play/1024001
- **The cap matters.** A widely repeated (unconfirmed, forum-sourced) figure is that Overwatch stops favouring
  the shooter beyond **~250 ms**. A documented cap from another game: **Valorant cut its max rewind from 200 ms to
  140 ms** in patch 6.02 because high-ping players were too hard to fight.
  https://forums.ea.com/discussions/apex-legends-feedback-en/stop-rewarding-laggers-limit-client-side-hit-registration-to-200ms-in-the-past/8435746/replies/8435749 ,
  https://twinfinite.net/2023/02/new-valorant-server-update-makes-high-ping-demons-less-annoying/

## 2. Roblox specifics

- **Network ownership** decides who simulates a part. A client-owned character is low-latency for its owner and
  late for everyone else: the signal goes owner -> server -> other client. Ownership handoffs add a delay.
  https://devforum.roblox.com/t/inner-workings-of-network-ownership/2871924 ,
  https://devforum.roblox.com/t/soft-network-ownership/2685208
- **Replication rate and buffer.** Community measurements: physics replicates at ~20 Hz (one post says the
  sender flag defaults to 15/s); characters carry a large, non-configurable interpolation delay "designed for
  mobile", quoted as a **200 ms floor** by the Chrono library and **~100 ms** by another tester. Below 15 FPS the
  sender updates too rarely to interpolate smoothly.
  https://github.com/Parihsz/Chrono , https://parihsz.github.io/Chrono/Learn/Interpolation-Buffer.html ,
  https://devforum.roblox.com/t/allow-game-developers-to-configure-the-physics-replication-rate-for-their-games/4005498 ,
  https://devforum.roblox.com/t/humanoid-movement-replication-delays/1413118
- Roblox's improved physics replication rollout was **rolled back (05/05/2026)**; fast-game desync reports followed.
  https://devforum.roblox.com/t/heads-up-upcoming-rollout-of-improved-physics-replication/4618365 ,
  https://devforum.roblox.com/t/client-desync-with-physics-replication/4694852
- **`Player:GetNetworkPing()`** is server-readable, returns seconds, network-only (no packet processing time), and
  per Roblox engineers is a round trip; it reads 0 in Studio with Incoming Replication Lag, so it cannot be tested
  locally. https://devforum.roblox.com/t/playergetnetworkping-lacks-documentation/1544599 ,
  https://devforum.roblox.com/t/localplayergetnetworkping-returns-0-even-if-incomingreplicationlag-is-not-0-in-studio/1989802
- `Touched` is exploitable and laggy; nobody recommends it for combat.
  https://devforum.roblox.com/t/exploiters-are-able-to-trigger-touched-events-on-other-players/183273/19

### Reach tolerances in Roblox melee
- Server checks are usually **"less than 5 studs"** from the sword or player, or "slightly further than the sword's
  length"; measure from the handle (half its length plus a few studs), not the root, or a jumping target fails.
  https://devforum.roblox.com/t/magnitude-checks-exploiter-proof-or-mostly/1006279 ,
  https://devforum.roblox.com/t/classic-sword-reach/1046289 , https://devforum.roblox.com/t/safest-way-to-prevent-exploiting-with-a-sword/469967
- Common pattern: **client checks X studs, server checks X + a latency buffer**; or "enlarge the hitbox by ping"
  as the simple version and "server position history + rewind" as the accurate one. Even with rewind one poster saw
  **~0.5 studs** of residual error on jumps.
  https://devforum.roblox.com/t/how-to-make-secure-client-sided-hit-detection/2001966 ,
  https://devforum.roblox.com/t/am-i-doing-hitbox-replication-right/4773807 ,
  https://devforum.roblox.com/t/server-sided-hit-detection-with-lag-compensation/3322386
- A ready-made library exists (Rewind, server-side rewind + clock sync for melee/raycast/projectile); unverified.
  https://text21.github.io/Rewind/docs

## 3. The arithmetic for Rotag

At run speed 45 studs/s, every 100 ms of disagreement between two screens is **4.5 studs**; a dash (120 studs/s) is
**12 studs**. Rotag's touch window is reach 0.5 + grace 1.5 = **2 studs, i.e. ~44 ms of error at run speed, ~17 ms
during a dash.** Two-device paths stack: target upload (~0.18 s measured in Studio, tag.md §2) + replication to the
tagger (100-200 ms buffer) + the tagger's ping. Rotag already rewinds (up to 0.5 s) so the spatial window is
supposed to absorb this, which means misses most likely come from one of:

1. **No claim is ever sent.** The client only claims when the boxes overlap within 0.5 studs on ITS screen. If the
   drawn sprite is bigger than the box, or the target is jittering between snapshots, the player "touched" but the
   box never did. Nothing reaches the server to log.
2. **The claim is refused.** The pairing window (target sample same age to `k` older, claimant sample within
   `TAG_CONFIRM_WAIT` 0.35 s) is tuned on Studio's one-process timing; a phone's upload can exceed it.
3. **The rule refused it on purpose.** H38 makes a dashing runner untaggable; to a tagger that reads as a miss.

## 4. Logging and measuring near-misses

Log both ends, because a refused tag and an unsent tag look identical to a tester:
- **Client (tagger):** every frame where its box comes within, say, 4 studs of a live target, record the closest
  approach per encounter: drawn distance, box distance, whether a claim fired, local time. Send nothing extra; print
  to Output, and (optional) a capped debug remote in test builds only.
- **Server:** for every claim, log claimant ping (`GetNetworkPing`), `k`, the closest pair found, which gate refused
  (rate, frozen, dash-dodge, window, distance), and the margin in studs. Also log server-side **unclaimed near-misses**
  (holder within 3 studs of a target in rewound history with no claim).
- **Measure:** a histogram of refusal margins. If most refused claims miss by under 2-3 studs, widen the grace; if
  most near-misses have no claim, the client check or the visuals are the bug. Tag on two real devices (PC + phone),
  20+ deliberate touches each, at a standstill, chasing, and head-on.

## Recommendation for Rotag

1. **Keep the current model: client-claimed, server-rewound, capped.** It is the Source/Overwatch model and the one
   rule 6 already adopts. Do not move to server-only detection; it would make phones miss more.
2. **Measure first** with the two-ended log in §4; the fix differs for "no claim sent" vs "claim refused".
3. **Be generous on the tagger's client:** claim on the DRAWN sprite overlap, with reach ~1.5 studs (one hand),
   so what looks like a touch is a claim. Generosity lives on the tagger's side, as in "favour the shooter".
4. **Size the server's window in time, not studs:** grace = closing speed x ~0.1 s (4.5 studs at run speed),
   capped near the Roblox sword norm of ~5 studs. Keep the 0.5 s rewind cap: Roblox's two-hop delay (~0.4 s
   measured) is already above Valorant's 0.14 s, so a shooter-style cap would reject honest tags here.
5. Re-check H38's "dashing runner untaggable" against the logs: it may be a large share of the "misses".
