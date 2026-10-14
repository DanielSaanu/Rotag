# How the game fits together

**Created:** 2026-10-09. This is the short overview. What the game is meant to *be* is in
[`../DESIGN.md`](../DESIGN.md). Today the game is a scaffold; this file grows one row per system as each lands,
and every system file ends with **Expansion: deficits at scale** once there is something to measure.

## Server vs client

- **The server owns the match** (`roblox/src/server`, which syncs to `ServerScriptService.Server`): who is "it",
  the fuse, when a tag counts (DESIGN §3 rule 6: the client reports overlap, the server confirms), eliminations,
  ghosts, the round timer, crates. It is the only side that can change a player's state.
- **The client owns feel** (`roblox/src/client`, which syncs to `StarterPlayerScripts.Client`): input on keyboard
  and the mobile joystick, the Celeste forgiveness windows, momentum between moves, the side-on camera, juice, the
  HUD. It predicts its own movement with the same pure rules the server checks (→ learnings N2) and holds nothing
  durable.
- **`shared/` is pure Luau** (`ReplicatedStorage.Shared`): rules over plain tables, with no Instances and no Roblox
  APIs. That's why `npm run test:luau` can run it outside Studio and why `test/structure.test.js` polices it. The
  fuse maths, the tag rule, the movement constants and the crate table belong here. The one exception is the
  generated `Sprites.lua`.

## Remotes

RemoteEvents live in `ReplicatedStorage.Remotes` and are declared in `roblox/default.project.json`, never created in
code. Add a row here in the same commit as the declaration. Never rename one: both sides look them up with
`WaitForChild`.

| Name | Direction | Payload | Used by |
|---|---|---|---|
| `SheetIds` | server → one client, once on join | `{ [number]: string }`: one `"rbxassetid://<digits>"` per sheet, in `Sprites.Sheets` order (the return of `Sprites.ResolveOnServer()`) | `server/Server.server.lua` fires; `client/Client.client.lua` applies with `Sprites.ApplySheetIds` |
| `TagClaim` | client → server, at most every 0.15 s while the sender is it | `number`: the target's runner id (a UserId, or -1000 for the Studio dummy). Nothing else is read | `client/Tagging.lua` fires; `server/Match.lua` checks rate, who may claim, and its OWN position history ([tag.md](tag.md) §2) |
| `TagVerdict` | server → all, on each confirmed tag | `{ from: number, to: number, fuse: number, gained: number }`: fuse = the new holder's seconds, min(remaining + `FUSE_PASS_BONUS`, the life's fresh fuse); gained = what the pass really added (H7) | `server/Match.lua` fires; `client/Tagging.lua` (hit-stop) and `client/Hud.lua` (the "+N" pop, from `gained`) |
| `Ready` | client → server, once per client session, after its runner's first draw | none: only the sender is read; a repeat changes nothing (H11) | `client/Client.client.lua` fires; `server/Match.lua` holds a due round until every present player is ready or `Config.READY_TIMEOUT` (5 s) has passed ([players.md](players.md) §5) |
| `MatchState` | server → all on every change and at least once a second; → one client on join | `{ round, it: number?, fuse, frozenFor, chaseFor, alive: { number }, spectating: { number }, over: boolean, winner: number? }` (`spectating`, H8: present but joined after the round began): durations in seconds, no timestamps | `server/Match.lua` fires; `client/Tagging.lua` holds it, `client/Hud.lua` draws it |
| `Snapshot` (`UnreliableRemoteEvent`, H14) | client → server 30/s (`Config.SNAPSHOT_RATE`); server → all once per Heartbeat | up: one 13-byte `buffer` (`shared/Snapshot.pack`: seq, x, y, vx, vy, sprite, facing/dash flags, juice events); down: `{ [runner id] = { t: server stamp, b: that buffer } }` | `client/Client.client.lua` fires; `server/Snapshots.lua` limits, stamps, relays, feeds `Match.sample`; `client/Others.lua` draws from it ([netcode.md](netcode.md) §8) |

**`SheetIds` (H4, 2026-10-10).** Uploads are Decals; the server resolves the Image id at boot and this carries it to
each client, so `setid` by hand is no longer needed for the runner to show. The rules it sets for every
server → client event:
- **The server fires it, never listens.** `OnServerEvent` is wired to a no-op so a client's fire is dropped unread.
  It fires on `PlayerAdded`, and once for players already there, BEFORE `Runners.start`, so it normally lands ahead
  of the first body. If the remote is missing (an old `rojo serve`), the server warns and plays on; it never hangs.
- **The client never blocks on it.** The runner draws at once with the ids built into `Sprites.lua`; when the event
  lands the client applies it and calls `Look:refresh()`, so the next draw re-applies the sprite. No event after
  10 s: one warning, play on. Why not block `Look.new`: a lost event would leave no runner at all, and with
  `Resolved = true` sheets (the usual case after `setid`) the built-in id is already right.
- **The client trusts only the shape.** Every key must be a sheet index it has, every value an
  `rbxassetid://<digits>` string; anything else is ignored with a warning. Ids are not secret or fairness-relevant
  (a wrong one only blanks your own sprite), so the shape check is enough.
- **Its own name, not a join/init blob.** The sheet ids are fixed for the server's life; map and match state change
  per round and will get their own events.

**`TagClaim`, `TagVerdict`, `MatchState` (H5, 2026-10-11).** The two server → client events follow every `SheetIds`
rule above. The first client → server event sets these for every remote a client fires (→ N4):
- **The payload is the smallest thing that names the request** (here one number). The sender is the `Player` Roblox
  passes, never a field in the payload. Anything that is not the expected type is dropped unread.
- **Rate-limited on the server per player**, dropped silently; the client limits itself above that, so an honest
  client never hits it.
- **Every decision is made from the server's own state** (who is it, frozen, alive; positions it recorded itself).
  A refused claim gets no reply; a Studio-only log line says why.
- Full reasoning, the rewind and its cap, and the limit of trusting client-owned bodies: [tag.md](tag.md) §2.

**`Snapshot` (H14, 2026-10-14).** The one `UnreliableRemoteEvent`: no resends, no ordering, so a lost packet is simply
skipped and a late one dropped (the sequence number). Client → server it follows every `TagClaim` rule: the sender is
the `Player`, the payload is exactly one 13-byte buffer or it is dropped unread, rate-limited per player (45/s), and
the server stamps it with its OWN clock. Server → clients it is one batch per Heartbeat; clients check the shape and
skip their own id. Movement is still client-owned physics on the player's own character ([movement.md](movement.md)
§1); the server checks the stream (and the body when the stream is stale) with the H12 speed budget
(`shared/MoveCheck`, `server/MoveGuard`) and snaps a runner back on a violation. Why the stream replaced reading the
replicated body, what it costs: [netcode.md](netcode.md) §8; the rule and its limit: [trust.md](trust.md).

Planned by the design, to be named when built: a notice event. (An input remote for server replay is the step after the
speed check, if a live game needs it: [trust.md](trust.md) §8.)

## Systems

One file each. Read only the one your task touches.

| System | File | Main modules |
|---|---|---|
| Sprites and animation (how 2D reaches the screen) | [sprites-and-animation.md](sprites-and-animation.md) | `Sprites` (generated) |
| The art pipeline (node) | [art-pipeline.md](art-pipeline.md) | `bin/warehouse.js`, `src/*.js` |
| Movement and feel (the body, the rules, camera, controls, juice) | [movement.md](movement.md) | `shared/Movement`, `shared/SideCam`, `client/Body`, `client/Controls`, `client/Look`, `client/SideCamera`, `server/Runners` |
| Tag, the fuse, elimination | [tag.md](tag.md) | `shared/Tag`, `server/Match`, `server/Dummy`, `client/Tagging`, `client/Hud` |
| Movement trust: the server's speed check, snap-back, untrusted samples (H12) | [trust.md](trust.md) | `shared/MoveCheck`, `server/MoveGuard`, `Tag.touchedBetween` |
| Players: other runners drawn, pass-through collision, off-screen arrows, round-ready (H11) | [players.md](players.md) | `shared/RemotePose`, `SideCam.edgeArrow`, `Tag.readyToStart`, `client/Others`, `client/Arrows`, `server/Runners` |
| Ghosts | *(not built; DESIGN §6.1 is open)* | |
| Crates and abilities | *(not built; DESIGN §6.2 is open)* | |
| Maps | the first-playable test map only: [movement.md](movement.md) §7 | `server/Arena` |
| HUD and mobile controls | the two touch buttons: [movement.md](movement.md) §5; the fuse HUD: [tag.md](tag.md) §6 | `client/Controls`, `client/Hud` |

The per-module "who owns what" tables are the folder READMEs under [`roblox/src/`](../../roblox/src/README.md).
