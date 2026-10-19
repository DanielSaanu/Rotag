# server/ — syncs to `ServerScriptService.Server`

`Server.server.lua` is the `Server` Script; every other file is a ModuleScript. The server owns the match and is the
only side that changes a player's state (DESIGN §3 rule 6). Update this table in the same commit as any move.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | the entry point: no stock characters, resolves the sprite sheet ids, builds the map, starts the match, starts the runners | 41 |
| `Arena.lua` | the first-playable test map: plain Parts in `Workspace.Map`, a Folder made in code (nothing waits for it by name; [movement.md](../../../docs/systems/movement.md) §7); `GHOST_ORBS`, three ghost-orb spots (H18) | 77 |
| `Runners.lua` | each player's runner body (one box + a dormant Humanoid), its spawn and respawn, physics handed to the player; tags it `RotagRunner` with a `RunnerId`; the `RotagRunners` collision group (runners pass through each other, [players.md](../../../docs/systems/players.md) §2) | 97 |
| `Match.lua` | the round ([tag.md](../../../docs/systems/tag.md)): "it", the fuse clock, position history (from each player's snapshot stream since H14), confirming `TagClaim`s, eliminations (no comeback, H18), `MatchState` (with `ghosts`, `ward`) and `TagVerdict`; wires `Orbs` and `Ghosts`; the frame order tags → hexes → orbs → fuse; holds round 1 for every client's `Ready` (players.md §5) | 372 |
| `Snapshots.lua` | the server's end of `Remotes.Snapshot` (H14): rate limit and size check per sender, the server stamp, the newest position per runner for `Match`, the in-flight grace after a body rebuild, one relayed batch per Heartbeat ([netcode.md](../../../docs/systems/netcode.md) §8) | 92 |
| `MoveGuard.lua` | the speed check on every player's body (`shared/MoveCheck`): marks samples untrusted, warns, rebuilds the body at its last trusted spot; checks each body's network owner every frame and hands it back (H13) ([trust.md](../../../docs/systems/trust.md) §9) | 97 |
| `Ghosts.lua` | the server's end of the ghosts (H15, the hex since H18): `GhostClaim` judged like `TagClaim` (rate, `Ghost.canHex` on the server's own slots, the server's own history), `Ghosts.land` applies a hex, fires `GhostVerdict` and empties the slot, the `MatchState` ghost rows ([ghosts.md](../../../docs/systems/ghosts.md)) | 116 |
| `Orbs.lua` | the server's end of the orbs (H18): the orb state per round, touches judged on the server's own position record each frame (no claim remote; untrusted samples collect nothing), rolls, `Remotes.ItemEvent` (sync on join and round start, then per change) ([ghosts.md](../../../docs/systems/ghosts.md)) | 92 |
| `Bots.lua` | the Studio dummies (`Config.STUDIO_DUMMIES`, ids -1000, -1001, ...): where each heads (chase a player as it; as a ghost the nearest floor ghost orb, then the holder once it holds a hex; else patrol) and their own tags and hexes, judged same-frame (H15, H18) | 102 |
| `Dummy.lua` | builds and moves one Studio-only stand-in runner, so the tag plays before a second client | 62 |

Planned: the forced ending (rule 3), `Items.lua` (Use and holds, ghosts-v2-proposal.md §12 PR 2). Keep each under the 400-line
ceiling in `test/structure.test.js` (→ learnings T1).
