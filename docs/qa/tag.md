# QA goals: the tag (server-owned "it", the fuse, the pass, lag-fair claims, the HUD)

Branch: `claude/friendly-hawking-74891i`. Handoffs H5 (the build) and H6 (Danzo's first Play feedback: tag once only,
frozen at start, dash spam). Design: `docs/DESIGN.md` §2 "Mode: classic tag with a hot-potato fuse", §3 rules 1, 2,
4, 5, 6, 21. System doc: `docs/systems/tag.md` (the decisions, the numbers, the stated limits).

The question for this loop: **does being "it" feel tense rather than hopeless, is it always clear who is it and how
long is left, and does the server, not the client, decide every tag?** Solo in Studio the opponent is an orange box
the server drives (`Config.STUDIO_DUMMY`); it patrols, chases when it is "it", and tags back.

## Goals

1. **Server-owned "it" and fuse.** Only `server/Match.lua` changes who is it or the fuse, through the pure rules in
   `shared/Tag.lua`. A client's `TagClaim` carries one number (the target id) and nothing else; the server rate-limits
   it, checks who may claim, and re-checks the overlap against positions it recorded itself, looking back by the
   claimant's ping plus a margin, capped (rule 6). A refused claim gets no reply.
2. **The fuse rules (§2):** first it starts at 45 s; a pass hands over remaining + 5; at 0 the holder is eliminated and
   the next alive runner in join order takes a fresh, shorter fuse (45, 35, 25, never below 15); the last one standing
   wins; a new round starts after a gap.
3. **No tag-backs (rule 1):** the new holder is frozen 1.5 s (no input, still falls, cannot tag) and the fuse does not
   burn while frozen. The first "it" also waits at round start (`START_FREEZE`, length under review in H6) with a
   visible countdown.
4. **Readable (rule 2):** the fuse in seconds at the top centre, red "YOU'RE IT" when it is yours, "+5 -> name" on
   every pass, an IT marker over the holder, a status line (frozen, out, round over). Lower-middle of the screen
   stays clear (rule 23).
5. **Chaser ramp (rule 4):** no boost for the first 5 s of a chase, then up to +15% run speed over 15 s; resets on
   every tag. Hit-stop of 80 ms on both involved clients when a tag lands (rule 21).
6. **Playable solo:** a player can tag the dummy, be tagged back, and tag it again, round after round. A dash has a
   cooldown so spamming it cannot beat a run (H6).
7. **Pure where it can be pure:** `shared/Tag.lua` and the dash rule in `shared/Movement.lua` are plain functions over
   tables with tests in `test/luau/tag.test.luau` and `movement.test.luau`. `npm test`, `npm run lint:luau` and
   `rojo build` pass; the Rojo tree only gained instances (three RemoteEvents, new ModuleScripts).

## Out of scope

A second real player's sprite (each screen draws only its own runner today; the dummy is a neon part), the catch-up
animation and the bomb art and sound (rule 2, rule 6), ghosts, crates, grapple, boost pads, match scoring, the
movement remote with a server speed check (the stated limit of the position check, `docs/systems/tag.md` §2).

## Studio play-through (Danzo, keyboard, then the phone preset)

1. Play. Do you know within two seconds who is it and how long you have? Can you run at once, or is there a wait,
   and is the wait announced?
2. You are it: catch the orange box. You should see "+5", the IT marker move to the box, and a short hit-stop.
   The box now chases you more slowly than you run.
3. Let it catch you. You should be frozen 1.5 s with a countdown and the fuse should not drop while frozen. Then
   catch it again: this must work a second and a third time.
4. Spam Shift on the floor: is a dash chain still faster than a run? It should not be.
5. Let your fuse run out: the box should win the round and a new round should start after a few seconds with the
   box as it and the fuse at 45, then 35 after the next elimination.
6. Phone preset: fuse readout visible, lower-middle clear, the IT marker legible at phone size.
