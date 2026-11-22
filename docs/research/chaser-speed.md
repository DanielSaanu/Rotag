# Research: does the chaser get a speed edge?

_22 Nov 2026. Desk research for [`../qa/playtest-2026-11-20.md`](../qa/playtest-2026-11-20.md) #2 ("IT too easy to
escape", testers asked for "~20% faster"). Changing "it"'s speed is a §3 rule change (escalation trigger 1)._

**Source caveat.** Page fetches were blocked in this session; figures come from search-result excerpts. Most are
fan wikis and guides. Exact current values should be checked in-game where it matters.

**Rotag today** (`roblox/src/shared/Config.lua`): everyone runs 45 studs/s. "It" gets DESIGN §3 rule 4's ramp:
nothing for `RAMP_DELAY` 5 s, then up to `RAMP_MAX` **+15%** over `RAMP_TIME` 15 s, reset on a tag. So "it" is
only faster after 5 s, and fully faster only after 20 s of chasing. End phase gives every runner x1.1.

## 1. Examples

### Dead by Daylight: a permanent edge plus a ramp plus a lunge
- Survivors run **4.0 m/s** (100%). Most killers run **4.6 m/s (115%)** or **4.4 m/s (110%)**.
  https://deadbydaylight.wiki.gg/wiki/Movement_Speed
- **Bloodlust:** after **15 s** of chase, +0.2 m/s (Tier I, +5% of survivor speed); Tier II at 25 s (+0.4), Tier III
  at 35 s (+0.6). Patch 6.1.0 cut the tier step from 15 s to 10 s. Lost on a hit, a pallet stun or breaking chase.
  https://deadbydaylight.wiki.gg/wiki/Status_HUD/Bloodlust
- **Lunge:** the basic attack briefly multiplies the killer's speed (x1.5 listed for a 4.6 m/s killer) with a
  longer hit window; starting it right after moving gives less range. All killers share the default lunge range.
  https://deadbydaylight.wiki.gg/wiki/Lunge , https://deadbydaylight.wiki.gg/wiki/Attacks
- **The counterweight** (general knowledge, not in the excerpts above): after a hit the SURVIVOR gets a speed burst and the killer a cooldown, so one hit never
  chains into a second. The map's loops (pallets, windows) are what the 15% is balanced against.
- Takeaway: the chaser is faster ALL the time; Bloodlust exists only to stop infinite loops, it is not the edge.

### Among Us Hide n Seek: speed edge only in the finale
- Official mode: the Impostor gets a **Final Hide** power boost (speed, a special seek map, a ping toward survivors).
  Setting "Final Hide Impostor Speed" runs **1x to 3x**; a common community setup uses **1.25x**.
  https://www.innersloth.com/new-game-mode-hide-n-seek-is-here-emergency-meeting-35/ ,
  https://n4g.com/articles/best-hide-and-seek-settings-in-among-us
- The rest of the round the seeker relies on information (vision 0.25x for crew, flashlights), not speed.

### Fall Guys tail tag: equal speed, forgiving grab, poorly received
- Everyone moves at the same speed, so stealing a tail is positioning and timing plus a dive. The grab works from
  behind and does not need to be directly behind. Reviews and guides complain the grab "isn't fine-tuned", is
  "more frustrating than fun" and lacks feedback, and that desync lets people grab "from a mile away" or miss when
  right next to the carrier.
  https://www.ggrecon.com/guides/fall-guys-tail-tag-guide/ , https://twinfinite.net/ps4/best-fall-guys-minigames-ranked/2/ ,
  https://pushsquare.com/reviews/ps4/fall_guys
- Takeaway: parity plus a twitchy, latency-sensitive touch is the combination players dislike. That is Rotag now.
- Stumble Guys: no tag-specific speed data found; its races keep everyone at the same speed.
  https://www.bluestacks.com/blog/game-guides/stumble-guys-multiplayer-royale/sg-mechanics-guide-en.html

### Roblox
- **Untitled Tag Game** (parkour tag, the closest peer): no fixed tagger speed found. Movement tech (slide while
  sprinting for a burst, wall climb) is shared; a random **modifier wheel** can give taggers extra speed for a
  round. https://www.sportskeeda.com/roblox-news/untitled-tag-game-a-definitive-guide ,
  https://earnaldo.com/blog/untitled-tag-game-beginner-guide
- **Flee the Facility:** the Beast cannot move for **~3 s after a hit** (the post-hit cooldown); a "Runner" power
  lets it close distance. https://flee-the-facility.fandom.com/wiki/Beast
- Default Roblox WalkSpeed is 16; games set role speeds per Humanoid. A Gimkit tag builder hit the same problem
  (taggers too slow) and added a speed modifier. https://forum.creative.gimkit.com/t/im-making-a-tag-game-where-when-your-tagged-you-switch-teams-i-want-the-taggers-to-be-fast-but-cant-figure-out-how-to-make-them-fast-in-the-beginning/39459

### Playground tag
- Roles are symmetric and swap on each tag; the tagger's real edge is choosing the target and cornering it, and
  the court's edges do the trapping. Research on tag play found taggers and runners show different, recognisable
  behaviours. https://link.springer.com/10.1007/s12193-016-0211-1 , https://en.wikipedia.org/wiki/Tag_(game)

### Catch-up design in general
- A negative feedback loop (help the one behind) adds tension; too much makes early play meaningless, and
  committed players resent having an earned lead erased.
  https://computerscience.chemeketa.edu/cis125greader/MechanicsDynamics/FeedbackLoops.html ,
  https://gamedeveloper.com/design/rubber-banding-as-a-design-requirement

## 2. Typical ratios

| Game | Chaser vs runner | When |
|---|---|---|
| Dead by Daylight | 110-115%, +5/10/15% Bloodlust, x1.5 lunge burst | always; ramp after 15 s |
| Among Us H&S | 1.0x, then 1.25x (1-3x) | final phase only |
| Fall Guys tail tag | 1.0x | always (and disliked) |
| Untitled Tag Game | 1.0x, sometimes more by wheel | per round |
| Rotag now | 1.0x, ramp to 1.15x | after 5 s, full at 20 s |

Asymmetric games that stay fun land at **~10-15% permanent edge** for a lone chaser against loops.

## 3. Alternatives to raw speed

- **Catch-up ramp** (have it; Bloodlust model). Fires too late if it waits 5 s, as Rotag's does.
- **Runner dash cooldown when chased.** Rotag's dash cooldown is 0.8 s for all. A longer one for a runner within N
  studs of "it" (or no dash refresh from wall touch while chased) targets "spam jumping and dashing" directly.
- **Short lunge.** A tag input or auto-lunge: +reach for ~0.1-0.2 s, then a cooldown on a miss (DbD's lunge, FtF's
  hit lag). Rotag's `TAG_LUNGE_TIME` is only the visual catch-up; the dash sweep (rule 45, H38) is the nearest to a lunge.
- **Bigger tagger reach**, not speed: fixes the "touched but missed" feel without changing the chase.
- **Information** (Among Us ping): show "it" an arrow to the nearest runner in the end phase.
- **Post-tag cooldown for the new holder** (have it: the 1.5 s freeze).

## Recommendation for Rotag

1. **Give "it" a small permanent edge: x1.08-1.10 (about 49 studs/s)**, the low end of DbD's band; four players
   on open parkour maps need less than one killer against loops.
2. **Start the ramp sooner**: `RAMP_DELAY` 5 -> ~2 s, keep `RAMP_MAX` +15% on top. Fully ramped "it" then runs
   ~1.25x, close to the testers' "~20% faster" ask.
3. **Fix reach before tuning speed** (see [`tag-netcode.md`](tag-netcode.md)): a faster "it" can hide a reach bug.
4. **Add a short tag lunge** (~0.15 s, +1-1.5 studs reach, ~0.6 s cooldown on a miss) instead of more speed.
5. Revisit the dashing-runner dodge (rule 45, H38) together with these; it cancels all of the above.
