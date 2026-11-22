# The dash and the tag (H38)

**Created:** 2026-11-18 (Fable session). **Updated:** 2026-11-22 (H40: §6 measured, §7 the reach, the dodge, the chase edge, the walls). Danzo, after his first real match with a friend: "it was very difficult to
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
| **H40:** "it" (not dashing) touches a runner dashing AWAY from it | **tag**: the dash away buys distance, not a dodge (§7) |

- **The sweep** (`Tag.sweeps`): the straight step between two positions against the target's box. The client sweeps
  from last frame's spot while its own dash is on (`Tagging.claim`); the server sweeps between two consecutive
  samples of the claimant when the newer one is inside a dash it saw start (`Tag.touchedBetween`).
- **The dodge:** a target sample inside its dash's i-frames never pairs (**H40:** only when "it" is dashing too, or the
  target's dash is aimed at "it": `Tag.dodges`, §7). `DASH_IFRAMES` is 0.2 s and the server
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

## 6. H40: where tags died (measured 2026-11-22)

QA Central playtest #10775 (19-20 Nov, build 292cfc5 = H38 live), both testers as "it": "touched the other ppl ...
but it didnt go through", "hitboxes need optimising". Danzo: "it takes a decent amount of skill to actually tag anyone".
Triage: `docs/qa/playtest-2026-11-20.md` items 1-3 (branch `claude/stoic-euler-231upu`). The question was which of
three: the client never sent a claim, the server refused it, or the H38 dodge refused it on purpose.

**The server refuses almost nothing. Measured in Studio** (solo Play against bots held still by the Studio-only
`RotagBotsHold` workspace attribute, `server/Bots`; the network simulator at 4G 45/55 ms + 20/30 jitter, then 3G
150/180 + 70/90): `Player:GetNetworkPing()` read **0.126 s** on the server against the client's own NetworkPing stat of
117-124 ms, so it is the **round trip** (the research doc's "reads 0 in Studio" is about the old Incoming Replication
Lag setting, not the simulator). **9 claims, 9 confirmed, 0 refused**: 6 at 117-124 ms, 3 at 369-381 ms. A bot target
is one hop (server to tagger); a person is two, which Studio's MCP cannot start, so:

**Modelled through the real shared code** (`test/luau/chase_sim.luau`, run with `node test/luau/sim.js chase_sim.luau`):
two clients and the server at 60 Hz, snapshots at 30 Hz over each client's own link (LAN, wifi, 4G, 3G, with jitter),
the server sampling the newest snapshot every frame, relaying, the tagger drawing through `Snapshot.Stream`, claiming
on what it draws, the claim crossing its link, judged by `Tag.claimWindow` + `touchedBetween` every frame to the
deadline. Six chases (run into a standing runner, dash into a fleeing one, a slow catch, head-on, head-on with a jump
over, a late dash away), 200 runs each, 12 link pairs: **0 claims refused, in every cell**, before and after H40. The
rewind pairs the claimant with a target sample ~(snapshot delay + the tagger's round trip) older, inside
`TAG_VIEW_DELAY` + ping (cap 0.5 s), so the time error never reaches the 1.5-stud grace. The research's "0.5 + 1.5
studs is only ~44 ms at run speed" (`docs/research/tag-netcode.md` on the cloud branch) holds for a same-instant
check; ours is not one. (The few 3G/3G cells near 0% are the scenario, not the check: the runner is drawn ~20 studs
behind its real spot, so a chaser starting close is already past it on its own screen. No claim, nothing refused.)

**The client did not send.** The drawn runner is 4 studs square; its run poses reach **1.4-2.0 studs** past the centre
(measured on the art at 32 px a stud: run_0 -1.97..+1.66, run_4 -1.94..+1.63, dash -1.97..+1.41), the box 1. A claim
went out at a centre distance of 2 + `TAG_REACH` 0.5 = **2.5 studs**; two running sprites touch on screen from
**~3.3-3.6**. So for the last stud of every approach the tagger SAW a touch and nothing was sent. Seen in Studio after
the fix: `close pass -1000: closest box gap 1.19, 0.00 studs (reach 1.25), claimed`: under H38 that pass was
`NO claim`. Scene `preview_tag_reach` (render it: `node bin/warehouse.js render preview_tag_reach`) shows the three
distances: at 2.5 the sprites are deep inside each other, at 3.25 hand meets back, at 3.6 only the scarf overlaps.

**And the dodge did, on purpose.** H38 made every target sample in its dash's i-frames untaggable, whichever way the
dash went: a runner mashing dash was untaggable a quarter of the time, and the client did not even claim a runner
DRAWN dashing. In the model, a runner who dashed away late escaped a touch the tagger saw in 12% of LAN runs
under H38 (its reach and dodge); with both H40 changes, in none.

## 7. H40: the decisions (heavy session, 2026-11-22, on Danzo's standing go-ahead; his to judge by hand)

1. **The hand matches the sprite.** `TAG_REACH` 0.5 -> **1.25** across (a claim at 3.25 studs centre to centre: body
   touches body; the scarf-only overlap at 3.6 stays out). New `TAG_REACH_Y` **0.5** up and down (the drawn height is
   the box's, and a jump clear over the tagger's head stays an escape). Bots' tags, the boost grant's touch and the
   sweep use the same reach. **The server check is unchanged** (`TAG_GRACE` 1.5, `TAG_VIEW_DELAY` 0.4,
   `TAG_REWIND_MAX` 0.5): the measurements give no reason to widen it, so the research's "grace = closing speed x
   0.1 s, cap 5" is **not** adopted. A cheat gains the same 1.5 studs past an honest claim as before (4.75 vs 3.25).
2. **The dodge is Danzo's words, no wider** (`Tag.dodges`): a target inside its i-frames dodges only when the tagger
   is dashing too, or when the tagger lies ahead along the target's dash from the spot it left (the dash goes at or
   through "it"). A dash AWAY is taggable. The client now claims a runner drawn dashing and lets the server decide
   (it cannot see where the dash began); its `DODGED!` pop shows only for a dash aimed at "it". Bots: the same rule.
3. **"It" gets a chase edge** (rule 4): `IT_SPEED` **1.1** from the first step, `RAMP_DELAY` 5 -> **2** s, the ramp
   (+15% over 15 s) multiplying it: 49.5 studs/s at once (seen in Studio: top `vx` 49.5 as "it"), 56.9 at 17 s,
   against everyone's 45. The research's 1.08-1.10 base and earlier ramp, near the testers' "~20%". A dash is never
   scaled, so with both mashing dash every 0.8 s "it" still gains ~4 studs/s at once, ~7 at the top. The fastest run
   anywhere (the top of the ramp in the end phase) is 62.6 studs/s, under the speed check's 120 (`Tag.topSpeedMult`,
   pinned in config.test and move_check.test). Bots as "it" get it too (x `BOT_SPEED` 0.93 = 1.02: a person running
   clean no longer outruns a bot "it" for ever).
4. **Wall grace refills, never resets** (rule 51, `shared/Walls`): back inside, what is left is kept and refills at
   `WALL_REFILL` **0.25** s a second (24 s from empty to full, longer than the 20 s close). The testers' loop (3 s
   out, 2 s in) now dies in its third cycle (`walls.test`). The HUD shows the count only while outside, as before.
5. **Not built; next if tagging still feels hard:** the research's short tag lunge (+reach for ~0.15 s, a cooldown on
   a miss) and an arrow to the nearest runner for "it" in the end phase. Speed was asked for first; this is it.

**Tests** (each rule mutation-checked, Q5): `tag.test` (reach across and up, the dash-away tag, the aimed and through
dodges, both dashing, the edge and the ramp), `walls.test` (kept, refilled, the dipper dies), `config.test` pins the
trial numbers. **Studio logs** (Studio only): the tagger's client prints `tag: close pass <id>: closest box gap x, y
studs (reach r), claimed | NO claim[, drawn dashing]` for every pass within 3 studs; the server's `claim ...
received / dropped` lines are unchanged. Together they tell "never sent" from "refused".

**For Danzo, by hand** (two devices, a friend): does a touch now count when it looks like one; is "it" too fast at
x1.1 (try 1.05) or still too slow; does a dash away still feel like a fair escape when it works (it still buys 18
studs); does a runner outside the walls understand why the count came back lower.

## Expansion: deficits at scale

- **The dash is now the main way to tag and the main way to dodge.** If chases turn into two players trading
  dashes at close range, `DASH_COOLDOWN` or `DASH_IFRAMES` is the knob, not the reach.
- **Bots do not know the rule:** a bot neither dashes to tag nor dashes to dodge on purpose.
- **H40: two runners standing still within reach ping-pong** once each freeze ends (seen in Studio with bots held
  still: 6 passes in 18 s). A person who was just tagged runs; if idle players ever do this, rule 1's other option (a
  short immunity for the passer) is the fix.
- **H40: the person-to-person (two hop) confirm was modelled, not seen.** Studio's MCP starts solo Play only; the first
  real two-device session should run with the Studio log on one end (the `close pass` and `claim` lines).
