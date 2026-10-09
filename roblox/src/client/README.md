# client/ — syncs to `StarterPlayer.StarterPlayerScripts.Client`

Nothing here runs outside Studio. The client owns feel: input on keyboard and the mobile joystick, the forgiveness
windows, momentum, the side-on camera, juice and the HUD. It predicts with the shared rules and never decides a tag.

| File | Instance | What | Lines |
| --- | --- | --- | --- |
| `Client.client.lua` | `Client` (LocalScript) | the entry point: the frame loop (input, `Movement.step`, body; then camera, sprite) and character setup | 95 |
| `Body.lua` | `Body` (ModuleScript) | the ONLY file that knows the runner is a Part: raycast contacts, anti-gravity, the plane lock, velocity out | 87 |
| `Controls.lua` | `Controls` (ModuleScript) | keys, gamepad, the touch joystick (Roblox's PlayerModule), the JUMP and DASH touch buttons | 146 |
| `Look.lua` | `Look` (ModuleScript) | the runner sprite on a SurfaceGui, flip by the rect, frames, squash and stretch | 126 |
| `SideCamera.lua` | `SideCamera` (ModuleScript) | applies `shared/SideCam` to the camera: Scriptable, side-on, leading | 30 |

Why it is split this way, and the character choice: [`docs/systems/movement.md`](../../../docs/systems/movement.md).
Planned: `Hud.lua` (the fuse, +5 s, off-screen arrows), corner correction in `shared/Movement`. How sprites and frames are drawn:
[`docs/systems/sprites-and-animation.md`](../../../docs/systems/sprites-and-animation.md).
