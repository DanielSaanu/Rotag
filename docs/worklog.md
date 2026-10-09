# Worklog

One dated line per block of work, newest last. Say what changed and where, and cite learnings IDs if a rule was
paid for. The detail belongs in commits and the docs; this is the timeline.

- 2026-10-09 · `claude/friendly-hawking-74891i`: repo bootstrapped from The Warehouse. Design notes in
  `docs/DESIGN.md`; the pipeline (`bin/`, `src/`, `ui/`, tests, `tools/luau-check.js`) copied unchanged; `CLAUDE.md`,
  `INDEX.md`, `docs/learnings.md` (inherited rules), `docs/handoffs.md`, the heavy agent and the qa-loop skill
  adapted to this game; a Rojo scaffold (`Config`, two entry stubs, generated `Sprites.lua`) with a placeholder
  runner (idle + two run frames) to prove `roblox build`. `npm test` and `npm run lint:luau` green. Not yet
  uploaded (sheet id 0) and not yet opened in Studio.
