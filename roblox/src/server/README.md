# server/ — syncs to `ServerScriptService.Server`

`Server.server.lua` is the `Server` Script; every other file is a ModuleScript. The server owns the match and is the
only side that changes a player's state (DESIGN §3 rule 6). Update this table in the same commit as any move.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | the entry point: no stock characters, resolves the sprite sheet ids, adds the sprite toggles, builds the map, starts the runners. Will own remotes | 24 |
| `Arena.lua` | the first-playable test map: plain Parts in `Workspace.Map`, a Folder made in code (nothing waits for it by name; [movement.md](../../../docs/systems/movement.md) §7) | 67 |
| `Runners.lua` | each player's runner body (one box + a dormant Humanoid), its spawn and respawn, physics handed to the player | 92 |

Planned: `Match.lua` (the round: who is "it", the fuse clock, eliminations, the forced ending), `Tags.lua` (confirm a
client's overlap claim, hand the fuse over, the freeze), `Ghosts.lua`, `Crates.lua`. Keep each under the 400-line
ceiling in `test/structure.test.js` (→ learnings T1).
