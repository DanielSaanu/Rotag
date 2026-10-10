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

-- Movement (docs/systems/movement.md). Celeste's numbers mapped at 0.5 studs per Celeste px (its 8 px tile = our
-- 4-stud tile). Studs and seconds; y is up. Danzo tunes these on a phone and a keyboard, never a test.
Config.RUN_SPEED = 45             -- top run speed
Config.RUN_ACCEL = 500            -- reaches top speed in ~0.09 s: immediate, never floaty (rule 20)
Config.RUN_REDUCE = 200           -- how fast speed ABOVE top speed bleeds off while you hold that way (rule 16)
Config.AIR_MULT = 0.65            -- air control as a share of ground control
Config.GRAVITY = 450
Config.MAX_FALL = 80
Config.HALF_GRAVITY_BELOW = 20    -- |vy| under this with jump held: half gravity at the apex (rule 14)
Config.JUMP_SPEED = 52.5
Config.JUMP_H_BOOST = 20          -- a ground jump adds this in the stick's direction
Config.AIR_JUMPS = 1              -- the double jump
Config.WALL_JUMP_H_SPEED = 65
Config.WALL_JUMP_FORCE_TIME = 0.16 -- after a wall jump the stick is read as "away from the wall" this long
Config.WALL_SLIDE_MAX = 10        -- fall speed cap while pushing into a wall
Config.DASH_SPEED = 120
Config.DASH_TIME = 0.15
Config.DASH_END_SPEED = 80
Config.DASH_COOLDOWN = 0.2
Config.TOUCH_WINDOW_SCALE = 1.25  -- coyote and buffer are this much wider on touch (rule 23)
Config.STICK_DEADZONE = 0.3       -- stick |x| under this is no run; over it is a full run (diagonals run full speed)

Config.RUNNER_WIDTH = 2           -- the collider, studs (8 px of the 16 px sprite)
Config.RUNNER_HEIGHT = 3.5        -- 14 px: the sprite's rows 1-14, so feet and collider bottom line up
Config.RUNNER_DEPTH = 2
Config.GROUND_SNAP = 0.2          -- within this of the ground while not rising = standing on it
Config.TOUCH_DIST = 0.1           -- within this of a wall or ceiling = touching it
Config.RUN_FRAMES = 4             -- runner_run_0..3: stride, pass, stride, pass. More frames = smoother, same cadence
Config.RUN_CYCLE = 20             -- studs per full run cycle (two steps); sets the cadence (sprites-and-animation.md §3)
Config.IDLE_GRACE = 0.08          -- seconds stopped before the rest pose

Config.CAMERA_VIEW_HEIGHT = 48    -- studs of world visible top to bottom (12 tiles)
Config.CAMERA_FOV = 20            -- narrow, from far away: near-orthographic
Config.CAMERA_FOLLOW = 10         -- 1/s, how hard the camera chases the runner
Config.CAMERA_FOLLOW_Y = 6
Config.CAMERA_LEAD_TIME = 0.35    -- leads ahead by speed x this (rule 21)
Config.CAMERA_LEAD_MAX = 16
Config.CAMERA_LEAD_FOLLOW = 3
Config.CAMERA_Y_OFFSET = 4

return Config
