--!strict
-- Every tuning number in one place. Pure Luau: no Instances, no Roblox APIs (see shared/README.md).
-- Starting values come from docs/DESIGN.md §2 (locked decisions) and §3 rule 14 (Celeste's forgiveness values).
local Config = {}

Config.PLAYERS_PER_MATCH = 4
Config.FUSE_START = 45            -- seconds on the first "it"
Config.FUSE_PASS_BONUS = 2        -- seconds added on every tag (remaining + this). Danzo's trial 2026-10-11, DESIGN §2 says +5
-- A pass never lifts the fuse above the fuse this life started with (Tag.freshFuse: 45, then 35, 25). Danzo 2026-10-11.
Config.TAG_FREEZE = 1.5           -- seconds the new holder is frozen: no tag-backs (rule 1)
-- The tag (docs/systems/tag.md). Feel numbers are Danzo's to tune in Play; the tests pin the rules, not the feel.
Config.FUSE_SHRINK = 10           -- each elimination: the next fresh fuse is this much shorter (45, 35, 25) (§2)
Config.FUSE_MIN = 15              -- a fresh fuse never starts below this
Config.START_FREEZE = 1           -- the first "it" waits this long at round start while the others scatter (H6: was 3;
                                  -- the HUD counts it down to GO). Danzo's to tune
Config.TAG_REACH = 0.5            -- studs past touching boxes that still count as a tag (the hand)
Config.TAG_GRACE = 1.5            -- extra studs the SERVER allows on top of TAG_REACH (lag, interpolation)
Config.TAG_VIEW_DELAY = 0.4      -- seconds, on top of ping, the target may be older than the claimant in the server's
                                  -- history (H6, tag.md §2: measured 0.18 s per hop in Studio; two clients = two hops)
Config.TAG_REWIND_MAX = 0.5       -- that allowance at most, whatever the ping: lagging buys no more (rule 6; H6: was 0.3)
Config.TAG_CONFIRM_WAIT = 0.35    -- seconds the server keeps a claim open for the claimant's body to catch up (H6)
Config.TAG_CLAIM_GAP = 0.1        -- a client's claims closer together than this are dropped unread
Config.RAMP_DELAY = 5             -- rule 4: seconds into a chase before "it" starts to speed up
Config.RAMP_TIME = 15             -- seconds from no boost to the full boost
Config.RAMP_MAX = 0.15            -- the full boost: +15% run speed; resets on every tag
Config.HIT_STOP = 0.08            -- rule 21: seconds both runners hold still when a tag lands (client only)
Config.STUDIO_DUMMY = true        -- in Studio only, a server-driven dummy runner joins the round (tag.md §4)
Config.ROUND_GAP = 4             -- seconds between one round ending and the next starting
Config.START_SPREAD = 120         -- studs of floor the runners are spread over at round start, centred on the spawn
                                  -- (H8, Tag.startPlaces): 5 runners (4 + the Studio dummy) start 30 apart

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
Config.DASH_END_SPEED_FLOOR = Config.RUN_SPEED -- H10: a dash started on the floor ends here instead
Config.DASH_COOLDOWN = 0.8        -- seconds from one dash to the next, even with the charge back (H6: 0.2 let
                                  -- a grounded runner chain dashes at ~110 studs/s). Danzo's to tune
Config.TOUCH_WINDOW_SCALE = 1.25  -- coyote and buffer are this much wider on touch (rule 23)
Config.STICK_DEADZONE = 0.3       -- stick |x| under this is no run; over it is a full run (diagonals run full speed)

Config.RUNNER_WIDTH = 2           -- the collider, studs (8 px of the 16 px sprite)
Config.RUNNER_HEIGHT = 3.5        -- 14 px: the sprite's rows 1-14, so feet and collider bottom line up
Config.RUNNER_DEPTH = 2
Config.GROUND_SNAP = 0.2          -- within this of the ground while not rising = standing on it
Config.TOUCH_DIST = 0.1           -- within this of a wall or ceiling = touching it
Config.RUN_FRAMES = 8             -- runner_run_0..7: contact, down, pass, up, twice (H3). More frames = smoother, same cadence
Config.RUN_CYCLE = 20             -- studs per full run cycle (two steps); sets the cadence (sprites-and-animation.md §3)
Config.IDLE_GRACE = 0.08          -- seconds stopped before the rest pose
Config.APEX_POSE_BELOW = Config.HALF_GRAVITY_BELOW -- airborne |vy| under this = runner_jump_apex (H3); an art knob

Config.CAMERA_VIEW_HEIGHT = 48    -- studs of world visible top to bottom (12 tiles)
Config.CAMERA_FOV = 20            -- narrow, from far away: near-orthographic
Config.CAMERA_FOLLOW = 10         -- 1/s, how hard the camera chases the runner
Config.CAMERA_FOLLOW_Y = 6
Config.CAMERA_LEAD_TIME = 0.35    -- leads ahead by speed x this (rule 21)
Config.CAMERA_LEAD_MAX = 16
Config.CAMERA_LEAD_FOLLOW = 3
Config.CAMERA_Y_OFFSET = 4

return Config
