# client/ — syncs to `StarterPlayer.StarterPlayerScripts.Client`

Nothing here runs outside Studio. The client owns feel: input on keyboard and the mobile joystick, the forgiveness
windows, momentum, the side-on camera, juice and the HUD. It predicts with the shared rules and never decides a tag.

| File | Instance | What | Lines |
| --- | --- | --- | --- |
| `Client.client.lua` | `Client` (LocalScript) | the entry point: the frame loop (input, `Movement.step`, body; then camera, sprite) and character setup; sends our runner's snapshot 30/s on Heartbeat (H14); Studio `client: own loop` rate line (H13); the ghost draw mode for every runner and `Tagging.spook` each step (H15) | 250 |
| `Body.lua` | `Body` (ModuleScript) | the ONLY file that knows the runner is a Part: raycast contacts, anti-gravity, the plane lock, velocity out | 87 |
| `Controls.lua` | `Controls` (ModuleScript) | keys, gamepad, the touch joystick (Roblox's PlayerModule), the JUMP and DASH touch buttons | 146 |
| `Look.lua` | `Look` (ModuleScript) | the runner sprite on a SurfaceGui, flip by the rect, frames, squash and stretch; a free (unwelded) mode placed each frame for other runners (H13); `Look:ghost`, pale and see-through (H15) | 188 |
| `SideCamera.lua` | `SideCamera` (ModuleScript) | applies `shared/SideCam` to the camera: Scriptable, side-on, leading | 30 |
| `Tagging.lua` | `Tagging` (ModuleScript) | the server's last `MatchState`; sends `TagClaim` on an overlap with the other runner's DRAWN spot (H14); frozen, hit-stop and chaser boost for the frame loop ([tag.md](../../../docs/systems/tag.md)); as a ghost, `GhostClaim` on an overlap with the holder, the ghost fields of `MatchState` ([ghosts.md](../../../docs/systems/ghosts.md)) | 171 |
| `Hud.lua` | `Hud` (ModuleScript) | the fuse readout, the "+N" pop, the IT marker (on the drawn holder, H13), one status line; H15: the ghost line, the "-3s" pop, the mark line, "is back!", the ward's pale halo | 264 |
| `Others.lua` | `Others` (ModuleScript) | every OTHER runner's sprite: a `Look` each, placed from the snapshot stream (`shared/Snapshot`, `Config.SNAPSHOT_DELAY` behind) with the sprite and juice the snapshot carries; rule 6's lunge on a verdict; the H13 trail + `RemotePose` as the fallback for a runner with no stream; Studio `others:` stream line ([netcode.md](../../../docs/systems/netcode.md) §8); ghosts drawn pale (H15) | 210 |
| `Arrows.lua` | `Arrows` (ModuleScript) | off-screen arrows to the other runners, the holder's red, a ghost's a hollow pale-blue ring (`SideCam.edgeArrow`, players.md §4) | 129 |

Why it is split this way, and the character choice: [`docs/systems/movement.md`](../../../docs/systems/movement.md).
Planned: corner correction in `shared/Movement`. How sprites and frames are drawn:
[`docs/systems/sprites-and-animation.md`](../../../docs/systems/sprites-and-animation.md).
