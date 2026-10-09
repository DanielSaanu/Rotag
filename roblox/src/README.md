# roblox/src — the game's Luau, synced to Studio by Rojo

`roblox/default.project.json` maps each folder to a Roblox service. Rojo is the source of truth for the instance
tree: never move, rename or re-nest a file here without keeping the tree identical (see `CLAUDE.md`, "Rojo rules").

| Folder | Syncs to | Read |
|---|---|---|
| [`shared/`](shared/README.md) | `ReplicatedStorage.Shared` (ModuleScripts) | pure rules, run by both sides and by `npm run test:luau` |
| [`server/`](server/README.md) | `ServerScriptService.Server` (`Server` Script + ModuleScripts) | the match, the fuse, tags |
| [`client/`](client/README.md) | `StarterPlayer.StarterPlayerScripts.Client` (`Client` LocalScript + ModuleScripts) | input, feel, camera, HUD |

RemoteEvents aren't files. They're declared in `default.project.json` under `ReplicatedStorage.Remotes` and listed
with their payloads in [`docs/systems/README.md`](../../docs/systems/README.md). Today the folder is empty (the first playable needs no remote).
