# Learnings: G — Git and generated files

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ G1").

**G1 — Generated files are regenerated, never edited, and only Danzo uploads.** `roblox/src/shared/Sprites.lua`
and `roblox/assets.lock.json` come from `node bin/warehouse.js roblox build`. Claude runs the build (it keeps the
old asset id and prints CHANGED); Danzo runs `--upload` and commits the pair. On the PC, if those two are locally
modified, `git checkout -- roblox/src/shared/Sprites.lua roblox/assets.lock.json` before `git pull`. *(inherited.)*

**G2 — The Rojo instance tree is an API: prove it unchanged with a sourcemap diff.** Code finds modules by name
(`Shared:WaitForChild("Config")`) and remotes by name, so any file move, rename or re-nest must leave the tree
identical: the same names, parents and classes (`.server.lua` Script, `.client.lua` LocalScript, `.lua`
ModuleScript). Run `rojo sourcemap roblox/default.project.json` before and after, and compare names, classNames and
nesting. `.md` files in `src/` are ignored by Rojo. Also: Windows paths are case-insensitive, so never create a file
that differs from an existing one only by case. *(inherited, `refactor/ai-friendly`.)*

**G3 — A doc that other files cite by section is an API too: split it behind a hub at the old path.** Keep the old
file as a hub with a table mapping every § and rule ID to its new file, keep the § numbers in the moved headings, and
move by LINE RANGE with a script (never retype). Prove "lose nothing" mechanically: every non-blank line of the old
file must be in the multiset of hub + new files; then a relative-link check over all tracked `.md`. *(inherited,
handoff H2.)*
