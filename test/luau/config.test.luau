local Config = __require("Config")

-- The locked decisions in docs/DESIGN.md §2 and the forgiveness values in §3 rule 14.
assert(Config.PLAYERS_PER_MATCH == 4, "four players per match")
assert(Config.FUSE_START == 45, "the first it starts with a 45 s fuse")
-- DESIGN §2 locks remaining + 5; Danzo is trialling +2 (2026-10-11, recorded under §2). Change both together.
assert(Config.FUSE_PASS_BONUS == 2, "remaining + 2 passes on a tag (the trial; DESIGN §2 says +5)")
assert(Config.TAG_FREEZE >= 1 and Config.TAG_FREEZE <= 2, "freeze the new holder 1-2 s: no tag-backs")
assert(Config.COYOTE_TIME > 0 and Config.JUMP_BUFFER > 0, "hidden forgiveness is on")
print("config ok")
