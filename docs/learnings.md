# Learnings

**Created:** 2026-10-09 · **Last updated:** 2026-10-14 (H15: S12)

Rules that **generalise** — things a session got wrong once and should never get wrong again. One-off typos and
trivia stay in the QA goals file or the commit message; they do not earn a line here.

`docs/PRINCIPLES.md` is the other rulebook: that one is about *what makes a good game*, this one is about *how
to work in this repo*. If a rule tells you what to do at a fork while building, it goes here. If it tells you
what to do at a fork while designing, it goes there.

Each rule has a stable ID so a handoff, a QA report or a commit can cite it (e.g. "→ S2"). Sections:

| ID | Section |
|---|---|
| **A** | Art — sprites, scenes, the renderer, animation |
| **S** | Shared Luau — purity, determinism, the rules modules |
| **N** | Networking and fairness — what the server trusts, remotes |
| **T** | Tooling — node CLI, Rojo, luau, the MCP Studio link |
| **G** | Git and generated files |
| **Q** | QA loop and review |

Behind each rule: the date and the branch or handoff that paid for it. Rules marked *(inherited)* were paid for in
The Warehouse (Lowlands, 2026-09/10) and restated here in this game's terms; the Lowlands-only ones (its save
format, its world sim) were left behind.

---

## The sections (one file each, split 2026-10-14 when this file passed 300 lines)

- [`A — Art`](learnings/art.md): **A** — A1, …, A5
- [`S — Shared Luau`](learnings/shared-luau.md): **S** — S1, …, S12
- [`N — Networking and fairness`](learnings/networking.md): **N** — N1, …, N14
- [`T — Tooling`](learnings/tooling.md): **T** — T1, …, T12
- [`G — Git and generated files`](learnings/git.md): **G** — G1, …, G3
- [`Q — QA loop and review`](learnings/qa.md): **Q** — Q1, …, Q5

Add a new rule to its section file and bump the ID; keep this hub to the intro and the list.
