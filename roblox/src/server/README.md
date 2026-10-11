# server/ — syncs to `ServerScriptService.Server`

`Server.server.lua` is the `Server` Script; every other file is a ModuleScript. The server owns the match and is the
only side that changes a player's state (DESIGN §3 rule 6). Update this table in the same commit as any move.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | the entry point: no stock characters, resolves the sprite sheet ids, builds the map, starts the match, starts the runners | 41 |
| `Arena.lua` | the first-playable test map: plain Parts in `Workspace.Map`, a Folder made in code (nothing waits for it by name; [movement.md](../../../docs/systems/movement.md) §7) | 67 |
| `Runners.lua` | each player's runner body (one box + a dormant Humanoid), its spawn and respawn, physics handed to the player; tags it `RotagRunner` with a `RunnerId` | 97 |
| `Match.lua` | the round ([tag.md](../../../docs/systems/tag.md)): "it", the fuse clock, position history, confirming `TagClaim`s, eliminations, `MatchState` and `TagVerdict` | 214 |
| `Dummy.lua` | the Studio-only stand-in runner (id -1000), so the tag plays before a second client | 51 |

Planned: the forced ending (rule 3) in `Match.lua`, `Ghosts.lua`, `Crates.lua`. Keep each under the 400-line
ceiling in `test/structure.test.js` (→ learnings T1).
