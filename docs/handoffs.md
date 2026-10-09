# Handoffs — routine → heavy

**Created:** 2026-10-09 · **Last updated:** 2026-10-09

A routine session appends here the moment an escalation trigger fires (CLAUDE.md, "Model policy and
escalation"). The heavy agent reads this file first, works the open entries, records its full reasoning in
the doc the entry names, and marks the entry RESOLVED.

Keep this file small. Once the detail lives in the real doc, trim the resolved entry to its heading plus one
resolved line.

## Entry template

```
### H<n> — <one-line title> — <YYYY-MM-DD HH:MM> — OPEN
- **Trigger:** <which of the numbered triggers>
- **Doc:** <path> §<section>
- **Observed:** <what was seen, plainly — exact error text, failing test, the diff, the Studio Output line>
- **Evidence:** <commands run, file:line, export PNG, branch, commit>
- **Routine session's read:** <best guess, clearly marked as a guess>
- **Decision needed:** <the specific question or action>
- **Blocked routine work:** <what is on hold, if anything>

Resolution (added by the heavy agent under the same entry):
- **Resolved <date>:** <one line> → recorded in <path> §<section>
```

## Open

### H1 — First playable: side-on camera, one runner, sprites drawn two ways — 2026-10-09 14:30 — OPEN
- **Trigger:** 1 (how sprites sit on the 3D world has three reasonable options: BillboardGui on an invisible Part,
  SurfaceGui on the collider, or a UI world frame with Parts only for physics), 2 (a new `shared/Movement.lua`).
- **Doc:** `docs/systems/sprites-and-animation.md` §4; goals `docs/qa/first-playable.md`.
- **Observed:** the scaffold is proven in Studio (2026-10-09: `[Sprites] sheet 1: decal 105258973543314 -> image
  137470273985937`, server and client up, the runner on screen after `setid`). Nothing 2D exists yet: Play shows a
  stock Roblox character on a baseplate.
- **Evidence:** commits ac24657, b0246f5 and the setid commit on `claude/friendly-hawking-74891i`; Studio Output
  pasted by Danzo.
- **Routine session's read (a guess):** build the camera, the plane lock and the moves once, and draw the runner
  both ways behind a Workspace attribute so Danzo can flip it and screenshot. The UI-world-frame option is left out
  of the build because DESIGN §2 locks "3D parts", but the handoff should say if the two part-based ways both read
  badly at phone size. Danzo decides from the screenshots; the losing path is deleted in the next commit.
- **Decision needed:** which of the two drawing methods becomes the rule in `sprites-and-animation.md` §4 (Danzo,
  after the play-through). The heavy agent decides everything else inside the goals file.
- **Blocked routine work:** every client system (HUD, tag animation) waits on the drawing method.

## Resolved

*(none yet)*
