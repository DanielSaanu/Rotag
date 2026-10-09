--!strict
-- Every tuning number in one place. Pure Luau: no Instances, no Roblox APIs (see shared/README.md).
-- Starting values come from docs/DESIGN.md §2 (locked decisions) and §3 rule 14 (Celeste's forgiveness values).
local Config = {}

Config.PLAYERS_PER_MATCH = 4
Config.FUSE_START = 45            -- seconds on the first "it"
Config.FUSE_PASS_BONUS = 5        -- seconds added on every tag (remaining + 5)
Config.TAG_FREEZE = 1.5           -- seconds the new holder is frozen: no tag-backs (rule 1)

Config.COYOTE_TIME = 0.1          -- rule 14
Config.JUMP_BUFFER = 0.08
Config.JUMP_HOLD_WINDOW = 0.2
Config.CORNER_CORRECTION_PX = 4
Config.WALL_JUMP_REACH_PX = 3

Config.TILE = 16                  -- pixels per tile in the art; one tile = Config.STUDS_PER_TILE studs in the world
Config.STUDS_PER_TILE = 4

return Config
