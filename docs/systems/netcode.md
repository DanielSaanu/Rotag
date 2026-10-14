# Netcode: how other runners reach every screen, and why the tag can land "early"

**Created:** 2026-10-14 by the routine session (H13, run 5) at Danzo's request: "do some research on the most effective
way to correct this problem because this is our 3rd attempt with no proper solution". The three attempts were all on
the drawing side ([players.md](players.md) §3: a fixed trail, then an adaptive one). This doc records what the rest of
the Roblox world does, what is wrong with the test rig, and the options with their fairness cost. Decisions are
escalation trigger 3 (networking and fairness) and are NOT taken here.

## 1. The two symptoms (Danzo, 2026-10-14, two Studio clients on one PC)

1. The other runner is "nowhere near as smooth as the player moving on their own screen", after a 0.1-0.3 s draw trail.
2. "You get tagged before you are touched on your screen": the chaser is still some distance away when the victim
   becomes it.

## 2. Finding 1: the one-PC test rig is throttled, so it exaggerates both

- **Studio renders an unfocused window at 25% of its max frame rate** (community finding, several threads; at the
  default 60 cap that is ~15 fps). Only one of the three test windows has focus, so the other player's client always
  runs slow. Roblox's own player does not do this.
- **Our runner loop steps once per frame** (`client/Client.client.lua` on `PreSimulation`) and writes the body's CFrame,
  so an unfocused player's body is SENT in ~15 Hz steps, each ~3 studs at run speed and 8 in a dash. No draw delay
  under 0.3 s hides that; the adaptive trail "slightly better" matches.
- **Worse: `MAX_DT` = 1/20 caps each step**, so at 15 fps that runner also moves at ~75% speed in game time. The
  unfocused player is slow AND steppy, and is seen by the focused one that much further behind, which is why the tag
  looks early by so much.
- **So nothing measured on this rig is the real game.** Two real devices (Studio + a phone on the published place, or
  two PCs) are the only honest test for feel. Reported mitigations for the rig, none confirmed: raise Studio's max
  frame rate to 240 (unfocused = 60), raise the Studio process priority, turn off Windows "Optimizations for windowed
  games". Try the 240 cap first; it is a Studio setting, not a game change.

**Confirmed 2026-10-14 (run 6):** with Studio's `FramerateCap` set to 240 in `%LOCALAPPDATA%\Roblox\GlobalBasicSettings_13_Studio.xml` (Studio closed; the property is RobloxScript-only, so not settable from a script),
Danzo: "smooth animation". What remains is the delay: "I press the button to jump or move and it takes a second to
register on the other player's screen", on one PC with no network at all. That is the replication path itself
(§3: client-owned physics to the server ~0.18 s (N6), the server's relay and Roblox's arrival smoothing on the
second hop, plus our 0.1-0.3 s trail), not a link. The snapshot stream (§4) is the fix for it: a remote arrives
almost at once (N6) and the receiver's buffer is 2-3 snapshots, ~70-100 ms at 30 Hz.

## 3. Finding 2: Roblox's physics replication is the wrong carrier for a CFrame-driven body

- A network-owned unanchored part's motion is sent to the server and relayed to other clients at Roblox's own cadence
  (community figure ~20 Hz; no official number) and **smoothed on arrival by an interpolation system that assumes
  positions and velocities produced by physics** (Roblox staff in the "custom character physics replication
  stuttering" thread: it "should never rewind", discontinuities in script-set velocity cause jitter). Our body is
  teleported by CFrame every frame with a velocity written beside it (`client/Body.lua`): the smoother is working on
  data it was not designed for. Every custom-character game on the forum hits this and ends up with its own stream.
- Ownership is not sticky either: the engine hands unanchored parts to whichever client is nearest and most capable
  unless `SetNetworkOwner` holds, and unanchoring resets it to automatic (official docs). H13's per-frame re-assert is
  the guard; the loss itself is still unexplained.

## 4. What the rest of the world does: snapshot interpolation over an unreliable channel

The standard recipe (Gaffer On Games "Snapshot Interpolation"; the forum's working custom-character games):
1. **The mover sends a snapshot at a fixed rate** on Heartbeat over an **`UnreliableRemoteEvent`** (no resends, no
   head-of-line blocking): position, velocity, facing, a state byte. 20-30 Hz is the forum norm; one Roblox game
   (Typical Colors 2) sends every Heartbeat unreliably with 20 players and reports no jitter.
2. **The server stamps and relays** to the other clients, and can validate the same stream (rate, the `MoveCheck`
   budget) exactly as it validates the replicated body today. It is still the client's word, so trust is unchanged
   (trust.md §2's argument), but now there is ONE stream for drawing, the speed check and the tag record, with a
   known cadence.
3. **Receivers keep a buffer and draw 2-3 snapshots behind**, interpolating between the two that bracket "now minus
   the delay": linear is enough at 30 Hz; Hermite using the sent velocity removes the pulse at lower rates. Gaffer's
   numbers: ~85 ms behind at 60 Hz, ~150 ms at 30, ~350 ms at 10. Extrapolation (dead reckoning) was tried and
   rejected both by Gaffer (inaccurate for rigid bodies) and by H13 (overshoots on every stop and turn).
4. **The physics body stays** for walls, floors and the server's copy; receivers draw the sprite from the buffer, not
   from the part (what `Others` already does with the trail), and may anchor the other bodies locally.

This replaces the "no movement remote" decision of H12 (trust.md §2). It does not weaken what the server trusts; it
changes which stream it reads. It is a new remote, so the remotes list and `default.project.json` change: trigger 3.

## 5. The early tag is lag compensation, and the honest fix is latency plus a catch-up, not a rule change

- The server confirms a claim by rewinding the target up to `TAG_REWIND_MAX` (0.5 s) to what the tagger saw
  (tag.md §2). That is standard "favour the shooter" lag compensation, and its known cost is exactly symptom 2: the
  victim sees the hit before the contact on their screen. Every lag-compensated game accepts this and caps the rewind
  (ours is capped). Requiring the VICTIM's screen to agree would instead punish the honest, laggier tagger.
- **Three levers, in order:** (1) cut the latency of the target's position (§4 and a real network: at 50-100 ms RTT
  the gap is 2-5 studs at run speed, not the ~15 the rig shows); (2) build DESIGN §3 rule 6's **catch-up animation**,
  still not built (tag.md "not built", → Q1): when the verdict lands, the tagger's sprite lunges to the victim over
  ~0.1 s before the IT swap, so the hit reads as a touch; (3) only then, if it still feels wrong on real devices,
  revisit `TAG_VIEW_DELAY` (fairness, Danzo's call).

## 6. The long road: Roblox Server Authority

Roblox's server-authoritative character and physics (client beta live since 2026-05-08) does prediction, rollback and
resimulation in the engine, but needs all input through InputActions, the control loop under `BindToSimulation` on
both sides, has no lag compensation yet, and users report mispredictions. It is the right eventual home for a
competitive tag game and the wrong thing to adopt mid-prototype. Note for DESIGN §6; not now.

## 7. Recommendation (2026-10-14; (1) done the same day with the 240 cap, (2) and (3) built as H14, §8)

1. **Stop tuning on the rig.** One run on two real devices, or with Studio's frame cap at 240, before any more netcode.
2. **If it is still choppy on real devices:** build §4 (snapshot stream over an `UnreliableRemoteEvent`, 20-30 Hz,
   buffer, interpolate; server validates the same stream). This is the known fix, used by every custom-character game.
3. **For the early tag:** rule 6's catch-up animation, after (1) and (2) have cut the real gap.

## 8. Built (H14, 2026-10-14, the Fable session; pending Danzo's two-client Play)

**The stream.** `Remotes.Snapshot` is an `UnreliableRemoteEvent` declared in `default.project.json`. Each client,
on `Heartbeat`, `Config.SNAPSHOT_RATE` (30) times a second, packs its runner's Movement state into a 13-byte buffer
(`shared/Snapshot.pack`: u16 sequence, x, y, vx, vy at 1/16 and 1/8 stud, the sprite index, facing, dashing, and the
juice events since the last one: jump kind, dash start, landing impact) and fires it. `server/Snapshots` rate-limits
per sender (a token bucket at 1.5 x the rate, burst 8), refuses anything that is not exactly one snapshot, drops a
sequence older than the last, stamps it with the SERVER clock on arrival, keeps it as that runner's newest position,
and relays the whole batch once per `Heartbeat` to every client. The relayed batch is `{ [runner id] = { t, b } }`.

**What the server reads.** `Match.sample` records each player's newest snapshot position every server frame (the
same history `Tag.touchedBetween` judges on, the same `MoveCheck` budget through `MoveGuard`) and reads the physics
body only when no snapshot has come for `SNAPSHOT_STALE` (0.5 s) or the server has just rebuilt the body. After a
rebuild (join, round start, snap-back) snapshots about the old body still in flight are dropped until one lands
within 8 studs of the new body or 1 s passes, and the check restarts from the spot the server chose. The body stays:
walls, floors, the server's copy, the per-frame ownership guard (trust.md §9) are all unchanged.

**What the receivers do.** `client/Others` keeps a `Snapshot.Stream` per other runner: points on the server's clock,
an averaged offset onto this screen's clock, and a draw clock at now - offset - `SNAPSHOT_DELAY` (0.08 s, ~2.4
snapshots: one lost packet is bridged, two in a row hold at the newest point; it never extrapolates). Position and
velocity interpolate linearly between the two points around the draw clock; the sprite, facing and dash flag are the
older point's; each snapshot's juice events fire once when the draw clock passes it. A jump of 20 studs between two
snapshots empties the buffer (a respawn snaps). The tag claim on the holder's screen tests this drawn spot
(`Tagging.claim` through `Others.positionOf`), and the IT marker sits on it. With no stream (the Studio stand-in, a
client that stopped sending) the H13 path draws the replicated root through the trail, posed by `RemotePose`.

**Rule 6's catch-up.** On a `TagVerdict`, the tagger's drawn sprite moves from where it is to the victim's drawn spot
over `TAG_LUNGE_TIME` (0.1 s, ease-out), then eases back onto its stream over the same time. Only another runner's
drawing moves: your own sprite is welded to your body, and you saw the touch yourself. 0 turns it off.

**Fairness cost, stated plainly.** None of the trust numbers changed (`MOVE_*`, `TAG_*`). The stream is the same
client's word as the replicated body was, bounded by the same budget; a client can no more fake it than it could
teleport its body, and it cannot spend the server's time: 13 bytes, 45 a second at most per player, dropped unread
past that. What it buys honest players: the server sees a runner ~one frame after it moved instead of ~0.18 s, and
another screen draws it ~0.1 s plus the link behind instead of ~0.4 s, so the target the server rewinds to is far
closer to what the tagger saw, and the "tagged before touched" gap on the victim's screen shrinks to the link plus
0.08 s. The one place the drawing lies: for 0.2 s after a verdict the tagger's sprite is not where its stream says.

**Tested** (`test/luau/snapshot.test.luau`, each rule mutation-checked): the wire round-trips every field within
quantisation and refuses the wrong type, size or sprite; the sequence ring; the limiter passes an honest 30 Hz sender
and a stalled queue, cuts a 10 x flood; a Movement runner sampled at 30 Hz over a 40 ms link is drawn moving on every
frame, `SNAPSHOT_DELAY` + half the link behind, never ahead, through +-15 ms jitter; one lost packet shows nothing,
three hold; events arrive once each; a teleport snaps; late and duplicate packets are dropped. Not yet seen in Studio.

**The log lines** (Studio only): `[Rotag] others: <name> stream <n> snapshots/s, longest gap <ms> ms, starved <a> of
<b> frames` on each client (starved = frames the draw clock passed the newest point: raise `SNAPSHOT_DELAY` if it is
not near 0); `<name> has no stream` means that client is not sending (an old `rojo serve`). The server's `body:` and
`claim` lines are unchanged.

## Sources

- devforum "Low framerate in switching windows in testing mode" (3743044); "How to disable FPS drop when window is
  not focused?" (4571106): unfocused Studio windows at 25% of the cap; the 240 cap suggestion, unconfirmed.
- devforum "Custom character physics replication stuttering" (655072): staff on the interpolation system's assumptions.
- devforum "Stupid simple fast character position replication" (3162721); "Interpolation for custom character
  replication" (2518362); "How do I achieve smooth player velocity on all clients?" (4776253): the unreliable-stream
  recipe and its buffers.
- gafferongames.com/post/snapshot_interpolation: the buffer rule, linear vs Hermite, the delay numbers.
- create.roblox.com/docs/physics/network-ownership: automatic ownership, anchoring resets it.
- devforum "Server Authority - Tech Deep Dive + Engineering Insights" (4624565): the beta's requirements and gaps.
