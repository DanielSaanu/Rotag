local Config = __require("Config")

-- The locked decisions in docs/DESIGN.md §2 and the forgiveness values in §3 rule 14.
assert(Config.PLAYERS_PER_MATCH == 4, "four players per match")
assert(Config.FUSE_START == 45, "the first it starts with a 45 s fuse")
-- DESIGN §2 locks remaining + 5; Danzo is trialling +2 (2026-10-11, recorded under §2). Change both together.
assert(Config.FUSE_PASS_BONUS == 2, "remaining + 2 passes on a tag (the trial; DESIGN §2 says +5)")
assert(Config.TAG_FREEZE >= 1 and Config.TAG_FREEZE <= 2, "freeze the new holder 1-2 s: no tag-backs")
assert(Config.COYOTE_TIME > 0 and Config.JUMP_BUFFER > 0, "hidden forgiveness is on")
-- DESIGN §3 rules 40 and 42 (H16, Danzo's trial numbers 2026-10-19). Change the rule text and these together.
assert(Config.SPOOK_DRAIN == 3 and Config.GHOST_WARD == 6, "a hex takes 3 s; a shared 6 s ward after any hex")
assert(Config.ORB_FIRST == 5 and Config.ORB_RESPAWN == 10 and Config.GHOST_ORB_RAMP == 0.5,
	"orbs first at 0:05, back after 10 s; ghost orbs 10 / (1 + 0.5 x ghosts)")
-- DESIGN §3 rules 44-45 (Danzo's numbers 2026-10-19, H16; built H19). Change the rule text and these together.
assert(Config.STUMBLE_TIME == 0.7 and Config.STUMBLE_SPEED == 0.5 and Config.FREEZE_TIME == 1,
	"crate: stumble 0.7 s at half speed; ice: freeze 1 s")
assert(Config.TRAP_TIME == 1 and Config.TRAP_PRESSES == 3, "bear trap: 1 s or 3 presses")
assert(Config.HOLD_IMMUNITY == 0.5 and Config.DASH_IFRAMES == 0.2, "0.5 s with no new hold after one; 0.2 s i-frames")
-- Rule 11: no hold you cannot break is longer than about 1 s.
assert(Config.STUMBLE_TIME <= 1 and Config.FREEZE_TIME <= 1 and Config.TRAP_TIME <= 1, "rule 11: no hold over ~1 s")
-- Retired with H15's rules (H16 removed the spook's cooldown and the comeback): the knobs must not linger.
assert((Config :: any).SPOOK_COOLDOWN == nil and (Config :: any).GHOST_COMEBACKS == nil, "no spook cooldown, no comeback")
-- DESIGN §3 rules 46-47 (H16 spec, built H22): the grant equals the ramp's top, 5 s; 3 live fixtures per ghost, a tile
-- clear of the living. The pad's launch stays inside the speed check's rates (move_check.test drives it).
assert(Config.GRANT_BOOST == 0.15 and Config.GRANT_TIME == 5, "boost grant: +15% for 5 s")
assert(Config.FIXTURE_CAP == 3 and Config.FIXTURE_FADE == 1, "3 live fixtures per ghost; a 4th fades the oldest in 1 s")
assert(Config.PLACE_CLEAR == Config.STUDS_PER_TILE, "a placed part keeps 1 tile from every living runner")
assert(Config.PAD_SPEED_X <= Config.DASH_SPEED and Config.PAD_SPEED_Y <= 2 * Config.JUMP_SPEED, "pad inside the check")
-- DESIGN §3 rules 50-51 (H16 spec, built H23; trial numbers, endgame.md §5). Change the rule text and these together.
assert(Config.IGNITE_AT == 10 and Config.IGNITE_AT < Config.FUSE_MIN, "ignite at 10 s left, inside every fuse")
assert(Config.END_PHASE_SPEED == 1.1, "end phase: x1.1 top speed")
assert(Config.END_PHASE_SPEED >= 1 and Config.RUN_SPEED * (1 + math.max(Config.RAMP_MAX, Config.GRANT_BOOST))
	* Config.END_PHASE_SPEED < Config.DASH_SPEED, "the fastest end-phase run stays under the dash (the check's x rate)")
-- H23's pick for the one open number (DESIGN §6): after the proposal's ~1:40 final two, inside the 2-3 minute pillar
assert(Config.END_PHASE_AFTER == 120 and Config.END_PHASE_AFTER > Config.FUSE_START + Config.FUSE_START - Config.FUSE_SHRINK,
	"the time cap never bites before two whole unpassed lives (45 + 35) have burnt")
print("config ok")
