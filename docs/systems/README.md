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
| `MatchState` | server → all on every change and at least once a second; → one client on join | `{ round, it: number?, fuse, frozenFor, chaseFor, alive: { number }, spectating: { number }, over: boolean, held: boolean, winner: number?, ghosts: { { id } }, ward: number }` (`spectating`, H8: present but joined after the round began; `held`, 2026-10-14: no round object yet, the HUD says "waiting for players"; `ghosts`/`ward`, H15, trimmed by H18 to `{ { id } }` and the ward, `mark` gone: [ghosts.md](ghosts.md) §4): durations in seconds, no timestamps | `server/Match.lua` fires; `client/Tagging.lua` holds it, `client/Hud.lua` draws it |
| `GhostClaim` (H15; the hex's claim since H18) | client → server, at most every 0.15 s while the sender is a ghost holding a hex | `number`: the holder's runner id. Nothing else is read; rate gap `TAG_CLAIM_GAP` per player, like `TagClaim` | `client/Tagging.lua` (`Tagging.hex`) fires on an overlap with the holder's DRAWN spot; `server/Ghosts.lua` checks rate, `Ghost.canHex` (ghost of this round, holds a hex in the SERVER's slots, target is it, not frozen, ward over, on the server's clock) and its OWN position history ([ghosts.md](ghosts.md) §3) |
| `GhostVerdict` (H15; the hex's verdict since H18) | server → all, on each confirmed hex | `{ from: number, to: number, drained: number, fuse: number }`: from = the ghost, to = the holder, drained = what really came off (→ N7) (`mark` gone with the comeback, H18) | `server/Ghosts.lua` fires (never listens); `client/Tagging.lua` → `client/Hud.lua` (the "-3s HEX" pop) |
| `ItemEvent` (H18) | server → all on each orb or slot change; → one client on join; → all at round start | one of: `{ kind = "sync", orbs: { { x, y, ghost: boolean, up: boolean } }, held: { { id, item: string } } }`; `{ kind = "orb", spot: number, up: boolean, by: number?, item: string? }` (an orb back, or `by` took it and now holds `item`); `{ kind = "slot", id: number, item: string? }` (a slot changed outside an orb; nil = empty). Arrays only (→ N13) | `server/Orbs.lua` fires (never listens; no client claims an orb, the server judges touches on its own record); `client/Items.lua` draws orbs, held items and the slot; `Items.held` feeds the hex claim, the ghost look and the HUD line ([ghosts.md](ghosts.md) §3, §4). H19 adds (from `server/Items.lua`): `{ kind = "put", n, item, x, y, w, h, dir, life }` (a crate, trap or beam in the world), `{ kind = "gone", n }`, `{ kind = "hold", id, hold: "stumble" \| "freeze" \| "trap", time }`, `{ kind = "free", id }`; a `sync` clears every thing and hold on the client ([items.md](items.md) §4) |
| `UseItem` (H19) | client → server, on a Use press, and on every press while the sender is trapped | `number`: an integer 0-3 (the fixture rotation in PR 4; not read now). Nothing else is read; rate gap `Config.USE_GAP` (0.05 s) per player, the client sends at most every 0.06 s | `client/Use.lua` fires; `server/Items.lua` judges it on the server's own state: in the round, the item in the SERVER's slot, no hold or tag freeze, the user's newest TRUSTED sample as the spot and its stream's facing; while the server has the sender trapped it is a pry press ([items.md](items.md) §3) |
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

**`GhostClaim`, `GhostVerdict` (H15, 2026-10-14; the hex since H18).** The same rules as `TagClaim` and `TagVerdict`,
word for word: one number up, the sender is the `Player`, rate-gapped, judged on the server's clock, its own slots and
its own position history; the verdict carries what really happened. The full trust statement: [ghosts.md](ghosts.md) §3.

**`ItemEvent` (H18, 2026-10-19).** Server → clients only, every `SheetIds` rule above (no-op listener, the client never
blocks and checks only the shape). There is deliberately no client → server orb remote: a pickup is the server's
reading of its own position record (proposal §8). A full `sync` on join and at each round start, then one event per
change; RemoteEvents are reliable and ordered, so no resend timer.

**`UseItem` (H19, 2026-10-19).** Every `TagClaim` rule: one small number up, the sender is the `Player`, rate-gapped,
the wrong type or range dropped unread, a refusal gets no reply. The server never reads a position or a target from
it: the spot is its own newest trusted sample of the sender. The full trust statement: [items.md](items.md) §3.

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
| Tag, the fuse, elimination | [tag.md](tag.md) | `shared/Tag`, `server/Match`, `server/Dummy`, `server/Bots`, `client/Tagging`, `client/Hud` |
| Movement trust: the server's speed check, snap-back, untrusted samples (H12) | [trust.md](trust.md) | `shared/MoveCheck`, `server/MoveGuard`, `Tag.touchedBetween` |
| Players: other runners drawn, pass-through collision, off-screen arrows, round-ready (H11) | [players.md](players.md) | `shared/RemotePose`, `SideCam.edgeArrow`, `Tag.readyToStart`, `client/Others`, `client/Arrows`, `server/Runners` |
| Ghosts v2, orbs, abilities, placement, maps: the adopted spec and build order (H16, DESIGN §3 rules 37-51; PR 1 built, H18) | [ghosts-v2-proposal.md](ghosts-v2-proposal.md) | — |
| Controls layout per verb, provisional (H17) | [controls.md](controls.md) | `client/Controls` |
| Ghosts as built (v2 PR 1, H18): no comeback, ghost orbs, the hex, the shared ward | [ghosts.md](ghosts.md) | `shared/Ghost`, `shared/Orbs`, `server/Ghosts`, `server/Orbs`, `server/Bots`, `client/Items`, `client/Tagging`, `client/Look`, `client/Hud`, `client/Arrows` |
| Items as built (v2 PR 2, H19): living orbs and pools, Use, the holds (crate, bear trap, ice beam), i-frames, the per-target ward | [items.md](items.md) | `shared/Items`, `shared/Movement` (hold), `shared/MoveCheck` (hold), `server/Items`, `server/Snapshots`, `server/Bots`, `client/Use`, `client/Items`, `client/Controls`, `client/Hud` |
| Fixtures, boost pads, boost grant, placement | *(PR 4 of [ghosts-v2-proposal.md](ghosts-v2-proposal.md) §12)* | |
| Maps | the first-playable test map only: [movement.md](movement.md) §7 | `server/Arena` |
| HUD and mobile controls | the two touch buttons: [movement.md](movement.md) §5; the fuse HUD: [tag.md](tag.md) §6 | `client/Controls`, `client/Hud` |

The per-module "who owns what" tables are the folder READMEs under [`roblox/src/`](../../roblox/src/README.md).
