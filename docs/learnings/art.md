# Learnings: A — Art

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ A1").

**A1 — Frame 0 is the rest pose, and an animated thing joins the animation already in progress.** Lowlands'
viewport names every animated tile `<base>_<frame>` and picks the frame from the clock (`floor(now * rate) % n`),
never from "when did this one appear", so two fires on screen flicker together and a tile that scrolls into view
never rewinds the water a frame. Entities drop back to frame 0 a short time after their last move. *(inherited,
`client/Viewport.lua`, `Client.client.lua`.)*

**A2 — Match the sprite's resolution and sampling to the world it stands in.** A 16 px figure scaled 12 x with the
Pixelated sampler over smooth 3D parts reads as a mismatch, not a style. For a smooth world draw smooth art (vector,
`pixelated: false`, 128 px per tile) and sample it bilinear; keep Pixelated for art that is meant to be pixel art.
Keep the feet on the same canvas row as before so the collider needs no change. *(2026-10-10, `claude/friendly-hawking-74891i`.)*

**A3 — Give a looping animation one knob for its speed per CYCLE and a separate one for its frame count.** A rate
set per frame ("studs per frame", "seconds per frame") couples smoothness to speed: adding in-betweens silently
slows the motion, cutting frames speeds it up. Set the cycle length, cut it into N frames, and test both: the frames
come in order, and one cycle takes the cycle length whatever N is. A two-pose cycle flipped fast reads as flicker,
not motion; it needs its in-betweens. *(2026-10-10, handoff H2, `Movement.spriteFor`.)*

**A4 — A pose picked by a speed band also catches every state whose speed is CLAMPED inside that band.** Before
setting a threshold, list each rule that caps or zeroes that speed (a wall-slide cap, a dash that zeroes vy, a ledge
walk-off that starts at 0) and decide which pose each one should show; a cap that lands inside the band needs its own
flag, set where the cap is applied and checked before the bands. Test each clamp by name. *(2026-10-10, handoff H3:
the wall slide's 10 studs/s sat inside the 20 apex band and would have shown the hang pose for the whole slide.)*

**A5 — In this side-on world, a world marker is a part (or a SurfaceGui on a part), not a BillboardGui.** The H5
"IT" BillboardGui sat inside the HUD's ScreenGui, and a GUI container nested in another never draws; moved out to
PlayerGui and adorned to a part, a test BillboardGui still showed nothing in a Studio capture, while the neon wedges and
the runner's SurfaceGui did. Build markers the way the runner is drawn, and LOOK at a capture before calling one done.
*(2026-10-11, handoff H6, the IT triangle.)*
