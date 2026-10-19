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
print("config ok")
