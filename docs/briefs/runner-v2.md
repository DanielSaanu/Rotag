# Design brief: the Rotag runner, pass 2

**Written 2026-10-14** for Danzo to paste into the design command. The current runner (pass 1, 2026-10-10) reads as
"a bit strange" to him; this pass is for a slightly better figure that looks professionally made. Everything below
the line is the prompt. Paste it whole, then attach `exports/preview_runner_strip@2x.png` (render it first with
`node bin/warehouse.js render preview_runner_strip --scale 2`) and give the link to the existing sheet.

The design output is a reference for Claude, not the shipped art: the shipped frames come from the procedural rig
in `tools/runner-rig.js` (joints, bone lengths, stroke widths, palette). So the brief asks for things that can be
ported into that rig: proportions, pose keyframes, line weights and a palette, not a hand-painted sheet.

---

**Prompt**

Revise the character design for Rotag's runner. Rotag is a 2D side-on parkour tag game on Roblox: 2 to 4 runners
chase each other on floating platforms, one is "it" with a 45 s fuse, and the game is about speed, so the figure
must read as fast and light at a glance. The existing style sheet is here: https://claude.ai/artifact/JrDw2hzBgJ5o4J9abXcNgb.
Keep that canvas and add new artboards beside the old one; do not delete it.

**What exists.** A smooth vector figure on a 128 x 128 px canvas, feet on y = 120, facing right (the game mirrors it
for left). Inked graphite look: thick round-capped limbs drawn as a dark outline (#1b1b2f) around a fill (#5b5f73
near limbs, #474a5b far limbs), a hooded round head with a half-lit face (#9aa0b8) and one neon accent (#7df9ff) on
the visor and a trailing scarf. Thirteen poses: an 8-frame run cycle (contact, down, pass, up, twice) plus idle, jump
rise, jump apex, fall and dash. The run is procedural: feet and hands ride arcs, knees and elbows come from two-bone
IK. The attached strip shows all thirteen.

**What is wrong with it** (the owner's words: "the poses are a bit strange still"). Looking at the strip:
- The passing frames crouch: the knees bend too much when a leg swings through, so the figure bobs and looks heavy
  instead of skimming.
- The stride is short for the speed. At top speed the runner covers 13 body heights a second; the legs need a longer
  reach in front and a straighter push-off behind.
- The hands are blobs. There is no readable forward hand, so the arm pump does not sell the sprint.
- The silhouette is the same mass top and bottom. A fast figure tapers: a strong chest and shoulders over light legs,
  or a small head over a long body. Pick one and commit.
- The whole thing is slightly stiff and "programmatic": every limb is the same width, every joint the same radius.

**What to deliver, on new artboards.**
1. **A model sheet** of the revised runner: front-of-stride side view at 128 px and a 4x blow-up with construction
   lines. State the proportions in px on the 128 canvas: head radius, neck, torso length, hip height, thigh, shin,
   upper arm, forearm, hand size, foot length. Line weight for the outline and for the inner fill in px. These numbers
   go straight into the rig.
2. **The 13 poses, redrawn** at 128 px in one strip in the same order as the attachment (run 0 to 7, idle, rise, apex,
   fall, dash), with the joint positions annotated for the four key run poses (contact, down, pass, up): hip, knee,
   ankle, shoulder, elbow, wrist for both sides, in px from the canvas origin. The in-betweens can be implied.
3. **A palette card** of at most 7 colours with hex values and what each is for (outline, near limb, far limb, face,
   visor, scarf, highlight). Keep the inked-graphite-plus-one-neon-accent idea; propose one alternative accent colour
   for a second player skin.
4. **One line of notes per pose** on what sells it: lean angle, which foot is ahead, where the eyes look, how the
   scarf trails. Dash is a smear pose, stretched 1.5x wide in the game, so draw it already leaning 40 degrees or more.

**Constraints, all hard.**
- 128 x 128 canvas, feet on y = 120, figure facing right, transparent background. The collider is 2 studs wide by 3.5
  tall, which is the middle 8 of 16 tiles wide and rows 1 to 14 of the sprite; keep the body inside that, the scarf
  and hands may overhang.
- Flat colour, no gradients, no textures, no drop shadows. The figure is rendered small on phones; every pose must
  still read at 32 px tall.
- One silhouette rule: in every pose the head, both hands and both feet must be visible and not overlap the torso.
- No facial features beyond the visor. No logos, no text on the character.
- Style references to match: SpeedRunners (lean and stride at speed), Rayman Legends (limb economy, readable hands),
  Hollow Knight (ink-and-one-accent restraint). Do not copy any of them; the runner is its own character.

**Do not** redesign the game, the HUD, the platforms or the theme. Do not propose more poses than the thirteen.
Do not use emoji or stock icons. If something in the brief is unclear, make the call and say so in a note on the
canvas.
