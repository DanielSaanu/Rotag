local Config = __require("Config")

-- The locked decisions in docs/DESIGN.md §2 and the forgiveness values in §3 rule 14.
assert(Config.PLAYERS_PER_MATCH == 4, "four players per match")
assert(Config.FUSE_START == 45, "the first it starts with a 45 s fuse")
-- DESIGN §2 locks remaining + 5; Danzo is trialling +2 (2026-10-11, recorded under §2). Change both together.
assert(Config.FUSE_PASS_BONUS == 2, "remaining + 2 passes on a tag (the trial; DESIGN §2 says +5)")
assert(Config.TAG_FREEZE >= 1 and Config.TAG_FREEZE <= 2, "freeze the new holder 1-2 s: no tag-backs")
assert(Config.COYOTE_TIME > 0 and Config.JUMP_BUFFER > 0, "hidden forgiveness is on")
-- DESIGN §3 rules 38 and 40 (H15, Danzo's trial numbers 2026-10-14). Change the rule text and these together.
assert(Config.SPOOK_DRAIN == 3 and Config.SPOOK_COOLDOWN == 8 and Config.GHOST_WARD == 6, "spook 3 s, 8 s, ward 6 s")
assert(Config.GHOST_COMEBACKS == 1, "one comeback per player per round")
print("config ok")
