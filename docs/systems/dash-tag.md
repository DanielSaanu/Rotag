# The dash and the tag (H38)

**Created:** 2026-11-18 (Fable session). Danzo, after his first real match with a friend: "it was very difficult to
actually tag anyone ... it takes a decent amount of skill"; asked which kind of hard: "probably 3" (got close, kept
just missing); and his rule: **"as tagger, dashing into or through you should count as a tag, unless you are also
dashing or are the one dashing through the tagger."** This rewrites DESIGN §3 rule 45's "never a tag". The tag
itself: [tag.md](tag.md).

## 1. Why tags missed

- The client asked "are the two boxes touching on THIS frame", with 0.5 studs of reach (`TAG_REACH`).
- A dash moves 2 studs a frame at 60 fps (4 at 30, 4 between two snapshots) and a body is 2 wide: a dash through
  a runner had one or two frames to land on, and at 30 fps could land on none.
- "It" runs no faster than anyone else, so the dash IS the way to close a gap: the move that should tag was the
  move most likely to miss.

## 2. The rule as built

| Case | Result |
|---|---|
| "it" dashes into or through a runner who is not dashing | **tag** (the whole dash path counts, +`TAG_DASH_REACH` 1 stud) |
| "it" dashes through a runner who is dashing | no tag |
| a runner dashes through "it" (whether "it" dashes or not) | no tag: the dash is the dodge |
| "it" touches a runner who is not dashing, no dash | tag, as before |

- **The sweep** (`Tag.sweeps`): the straight step between two positions against the target's box. The client sweeps
  from last frame's spot while its own dash is on (`Tagging.claim`); the server sweeps between two consecutive
  samples of the claimant when the newer one is inside a dash it saw start (`Tag.touchedBetween`).
- **The dodge:** a target sample inside its dash's i-frames never pairs. `DASH_IFRAMES` is 0.2 s and the server
  counts one dash per `DASH_COOLDOWN` 0.8 s, so a runner mashing dash is untaggable for a quarter of the time at
  most. A bot's tag is dodged the same way (`server/Bots.tags`).
- **Judged when the tagger saw it:** a claim pairs the tagger with OLDER samples of the target (rule 6). A dash
  begun after the touch the tagger saw does not undo the tag.
- **On screen:** the dodger gets `DODGED!` and a ring (what its own screen saw; the server's record decides).

## 3. What the server trusts

Nothing new. The claim is still one number (the target's id). "Dashing" is the server's own record of when each
runner's dash began (the snapshot stream, one per cooldown: items.md), never a client's say-so. A sweep never
joins two samples more than 0.1 s apart (a rebuilt body) and never uses one the speed check refused, so a
teleport is not a "dash through". The extra reach is 1 stud on top of the existing lag grace.

## 4. Numbers (`Config`, trial, Danzo's to tune by hand)

`TAG_DASH_REACH` 1 · `DASH_IFRAMES` 0.2 (shared with rule 45's items) · `DASH_COOLDOWN` 0.8 (the dodge's price and
the tagger's rhythm) · `TAG_REACH` 0.5 unchanged (a plain touch is no easier than it was).

## 5. Tests and what was seen

`test/luau/tag.test.luau`, the H38 block: the sweep's geometry, a dash through a runner between two frames, the
reach's edge, both dashing, a runner dashing through a standing tagger, the late dodge, the stall and the
untrusted sample. **Not seen in a real match yet:** this needs two people (or a person and a bot) and a hand on
the controls. What Danzo should try: dash through a standing friend as "it" (a tag every time); have the friend
dash through you as you dash (no tag, and they see DODGED!); mash dash as the runner and see whether "it" can
still catch you between dashes.

## Expansion: deficits at scale

- **The dash is now the main way to tag and the main way to dodge.** If chases turn into two players trading
  dashes at close range, `DASH_COOLDOWN` or `DASH_IFRAMES` is the knob, not the reach.
- **Bots do not know the rule:** a bot neither dashes to tag nor dashes to dodge on purpose.
