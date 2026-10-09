# client/ — syncs to `StarterPlayer.StarterPlayerScripts.Client`

Nothing here runs outside Studio. The client owns feel: input on keyboard and the mobile joystick, the forgiveness
windows, momentum, the side-on camera, juice and the HUD. It predicts with the shared rules and never decides a tag.

| File | Instance | What | Lines |
| --- | --- | --- | --- |
| `Client.client.lua` | `Client` (LocalScript) | the entry point: one `ScreenGui` with `runner_idle` on it to prove sprites resolve | 19 |

Planned: `Input.lua` (keyboard, joystick, at most four buttons, DESIGN §3 rules 22–24), `Feel.lua` (coyote time,
jump buffer, variable jump, corner correction, refresh on contact), `Camera.lua` (side-on, leads at speed),
`Hud.lua` (the fuse, +5 s, off-screen arrows). How sprites and frames are drawn:
[`docs/systems/sprites-and-animation.md`](../../../docs/systems/sprites-and-animation.md).
