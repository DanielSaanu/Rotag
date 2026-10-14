# server/ — syncs to `ServerScriptService.Server`

`Server.server.lua` is the `Server` Script; every other file is a ModuleScript. The server owns the match and is the
only side that changes a player's state (DESIGN §3 rule 6). Update this table in the same commit as any move.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | the entry point: no stock characters, resolves the sprite sheet ids, builds the map, starts the match, starts the runners | 41 |
| `Arena.lua` | the first-playable test map: plain Parts in `Workspace.Map`, a Folder made in code (nothing waits for it by name; [movement.md](../../../docs/systems/movement.md) §7) | 67 |
| `Runners.lua` | each player's runner body (one box + a dormant Humanoid), its spawn and respawn, physics handed to the player; tags it `RotagRunner` with a `RunnerId`; the `RotagRunners` collision group (runners pass through each other, [players.md](../../../docs/systems/players.md) §2) | 97 |
| `Match.lua` | the round ([tag.md](../../../docs/systems/tag.md)): "it", the fuse clock, position history (from each player's snapshot stream since H14), confirming `TagClaim`s, eliminations, `MatchState` and `TagVerdict`; holds round 1 for every client's `Ready` (players.md §5) | 372 |
| `Snapshots.lua` | the server's end of `Remotes.Snapshot` (H14): rate limit and size check per sender, the server stamp, the newest position per runner for `Match`, the in-flight grace after a body rebuild, one relayed batch per Heartbeat ([netcode.md](../../../docs/systems/netcode.md) §8) | 92 |
| `MoveGuard.lua` | the speed check on every player's body (`shared/MoveCheck`): marks samples untrusted, warns, rebuilds the body at its last trusted spot; checks each body's network owner every frame and hands it back (H13) ([trust.md](../../../docs/systems/trust.md) §9) | 97 |
| `Dummy.lua` | the Studio-only stand-in runner (id -1000), so the tag plays before a second client | 51 |

Planned: the forced ending (rule 3) in `Match.lua`, `Ghosts.lua`, `Crates.lua`. Keep each under the 400-line
ceiling in `test/structure.test.js` (→ learnings T1).
