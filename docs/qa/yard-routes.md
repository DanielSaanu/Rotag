# QA goals: the Yard relaid for routes (H29)

Branch: `claude/friendly-hawking-74891i`. Handoff H29. After QA round 1 on the maps (`docs/qa/maps-round1.md`, 6/10)
and the canvas (`docs/briefs/yard.md`), Danzo's brief on 2026-11-11: **"plenty of routes, feels fun, players have a
plethora of options on where to go."** Design: `docs/DESIGN.md` §3 rules 25-29 (maps), 17 (anchors), 48 (keep-clear).
System doc: `docs/systems/maps.md` §3 (the layout, the numbers the simulation taught). The map rule as a test:
`test/luau/maps.test.luau` (now also the pads' arcs and every anchor's swing, driven through the real Movement).

The question for this loop: **does a runner on the Yard always have three or more ways out, each a different move,
and does every pad, anchor, shaft and stair actually take you where it looks like it will?**

## Goals

1. **Every place has 3+ exits of different kinds.** Floor: jump to a mid deck, a pad, a shaft, a speed swing. Mid
   decks: jump up, drop, swing across, jump the gap. High decks: swing, drop, the Mast. The Mast: the lantern swing,
   two swing-drops, the drop to the crown. Nothing is a dead end (rule 26); a corner ledge is left by dropping.
2. **The ends differ.** The Dock (left): shaft, end pad (into the shaft or onto `MidLeft`), double jump. The Stairs
   (right): shaft, a stair of single jumps (5 → 8 → 10) that spends no double jump, double jump.
3. **Every pad lands.** Measured in `maps.test` (H30's launch: 115 across ramped and glided, 120 up): the end pads
   land on the `MidLeft` / `MidRight` quays 17 tiles in, and fling you into the shaft outward; the hub pad lands on
   `HighLeft2`. No pad bonks a deck above its own arc (a fed deck starts 9 tiles out).
4. **Every anchor carries.** `maps.test` proves each of the 7 anchors swings a runner deck to deck. In Studio: the
   lantern swing `MastLeft` ↔ `MastRight` released at the top of the swing; the swing-drops onto `HighLeft2` /
   `HighRight2`; the mid swings both ways; `HighRight2` → `HighRight` (short lands on `StepRight`).
5. **Visible tiers (rule 28).** Each tier is 5 tiles up and under the banner from the one below; `maps.test` pins it.
6. **No sealing (rule 48).** The worst case fills 125 passage tiles; every orb and anchor stand stays joined. The hub's
   keep-clear zone now covers the hole beside it (the start line's left exit).
7. **Preserved.** Everything in `docs/qa/maps.md` goals 1, 5-9 (the format, the window, map pads, trust, the test map).

## Seen by the builder (Studio, solo, 3 dummies, 2026-11-11)

Rojo synced the data live; Play booted `map "yard": 20 parts, 7 grapple anchors, 3 pads, window x -176..176`,
`placement: 36 static boxes ..., 3 map pads`, a round ran to the end phase (`walls: closing in ... in x -176..176`),
no errors. **Not driven by hand:** the runner stood at the start. The swings, pads and stairs are proven in the box
world only; the feel is Danzo's.

## What Danzo should feel (Studio, `STUDIO_DUMMIES = 3`, keyboard, then a phone)

1. Stand anywhere and count your exits. Is there ever a spot with only one way out?
2. The Dock: walk into the shaft and kick up to the ledge. Run left over the end pad: does it fling you into the
   shaft, and can you kick up from the fling? Run right over it: do you land on `MidLeft`?
3. The Stairs: from `MidRight`, single-jump to `StepRight`, then onto `HighRight`. Is the rhythm good? Then the shaft.
4. The Mast: from the crown, double jump up to a perch. Hook the lantern and let go at the top of the swing: do you
   land on the other perch? Then hook the outer anchor and ride it down onto the high deck.
5. The mid swings: from `MidLeft`'s edge toward the hub, and from `MidRight2` toward `MidRight`. Let go late (4 tiles
   past the anchor, or at the turn). Do you land on the far deck?
6. Chase a dummy / be chased: does the map give you options, or do you keep running the same loop? Where is it
   boring? Where is it unfair?
7. The hub pad running right: a hop under the crown, not a bonk. Say if it reads as a trap.

**H30 (built from your first play, 2026-11-11):**

8. Pads: more oomph? The across speed climbs over 0.1 s and eases back over 0.7 s instead of snapping. Does it
   "scale up and down" now, or still kick? Knobs: `PAD_SPEED_X` / `_Y`, `PAD_RAMP`, `PAD_GLIDE` (0 = the old way).
9. The release: let go of a swing going up and toward a deck. Does it feel like hauling on the rope to fling
   yourself off? Knobs: `GRAPPLE_RELEASE_KICK` 25, `GRAPPLE_RELEASE_BOOST` 1.25, `GRAPPLE_RELEASE_MAX` 140.
10. The catch: hook from a run or a fall. Is the bite softer (`GRAPPLE_GIVE` 0.05; 0 = the old hard catch)? If the
    arc still feels forced, try `GRAPPLE_YOINK` 0 before anything else.
11. Spacing: the decks are 2-3 tiles closer, the end pads feed long quays. Still too spread, or right now?

The ask: fun or not, and the one place that felt worst.
