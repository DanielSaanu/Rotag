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
Config.BOT_TAGS = true            -- false: a bot holder never tags (it still chases), so solo Play can test items without
                                  -- being "it" or tag-frozen (was STUDIO_DUMMY_TAGS before H31 made the dummies bots)
-- Ghosts v2 (DESIGN §3 rules 37-42, docs/systems/ghosts.md; Danzo's trial numbers 2026-10-19, H16/H18). No comeback.
Config.SPOOK_DRAIN = 3            -- seconds a held hex takes off the holder's fuse on a ghost's touch (rule 40)
Config.GHOST_WARD = 6             -- after ANY hex no ghost may hex for this long: the fuse burns at most
                                  -- 1 + SPOOK_DRAIN / GHOST_WARD = 1.5x however many ghosts and hexes there are
Config.ORB_FIRST = 5              -- seconds into a round before any orb is up (rule 42)
Config.ORB_RESPAWN = 10           -- seconds a taken orb stays gone; a ghost orb: this / (1 + GHOST_ORB_RAMP x ghosts)
Config.GHOST_ORB_RAMP = 0.5
Config.ORB_SIZE = 2               -- studs across an orb: a runner box touching this square takes it
-- Items and holds (DESIGN §3 rules 41-45, docs/systems/items.md; Danzo's numbers 2026-10-19, H16/H19).
Config.ITEM_LIFE = 20             -- seconds a dropped crate or a set trap stays (a trap: or until it catches someone)
Config.CRATE_SIZE = 3             -- studs across a crate, dropped behind you
Config.TRAP_W = 3                 -- studs: the bear trap, set at your feet
Config.TRAP_H = 1
-- The ice beam (H33, Danzo 2026-11-16: "as large as a player's body ... we should see it shoot out ... it should
-- stay attached to the front of the player's body, moving the entire beam with the player, but the direction should
-- not change"). It grows from the shooter's front edge to ICE_LENGTH over ICE_GROW, rides with the shooter, and goes
-- at ICE_LIFE. The freeze itself is unchanged (FREEZE_TIME, rule 11), and a dash still goes through it (rule 45).
Config.ICE_LENGTH = 24            -- studs the beam reaches at full length, the way you faced when you fired
Config.ICE_HEIGHT = 3.5           -- studs tall: a runner's body (RUNNER_HEIGHT; was 2)
Config.ICE_GROW = 0.4             -- seconds from the shot to full length (60 studs/s: slower than a dash, faster than a run)
Config.ICE_LIFE = 0.7             -- seconds the beam is out in all: it stands at full length for the rest (was 0.5)
Config.STUMBLE_TIME = 0.7         -- crate: carry on at STUMBLE_SPEED x run speed, no steer, jump, dash or item
Config.STUMBLE_SPEED = 0.5
Config.FREEZE_TIME = 1            -- ice: no input, sliding on your momentum, which bleeds to 0 over the hold
Config.TRAP_TIME = 1              -- bear trap: pinned this long at most (Danzo: "fast paced"; rule 11 unchanged) ...
Config.TRAP_PRESSES = 3           -- ... or this many presses (any key or click; taps on touch) pry it open sooner
Config.HOLD_IMMUNITY = 0.5        -- after any hold (and the tag freeze) no new hold lands for this long: no chains
Config.OWNER_SAFE = 0.5           -- a crate or trap never catches its owner this soon, nor before it has stepped off it
Config.DASH_IFRAMES = 0.2         -- rule 45: the first this-long of a dash dodges aimed abilities and clears a trap
Config.HOLD_GRACE = 0.3           -- server: seconds of lateness a hold forgives (the victim's client hears of it a ping
                                  -- later): its x budget drops to its speed x this + HOLD_SLACK when it lands; trust.md §10
Config.HOLD_SLACK = 2             -- studs (and studs/s on a freeze's refill): float and snapshot-step dust
Config.USE_GAP = 0.05             -- a client's UseItem presses closer together than this are dropped unread
-- Ghosts v2 PR 4 (DESIGN §3 rules 15, 46-48; H22, docs/systems/placement.md). Trial numbers, tuned by hand.
Config.GRANT_BOOST = 0.15         -- the boost grant: +15% run speed (rule 46: = RAMP_MAX, so a grant only matches the ramp)
Config.GRANT_TIME = 5             -- seconds it lasts; a second grant restarts it, never stacks
Config.FIXTURE_CAP = 3            -- live fixtures per ghost; a 4th fades its oldest ...
Config.FIXTURE_FADE = 1           -- ... after this warning (seconds), solid until then
Config.PLACE_GAP = 4              -- studs (1 tile) from the ghost's front edge to a fixture's near edge
Config.PLACE_CLEAR = 4            -- studs (1 tile) a placed part keeps from every living runner (rule 47)
Config.PAD_W = 8                  -- studs: a boost pad, 2 tiles wide, set at your feet, its arrow your facing
Config.PAD_H = 1
Config.PAD_LIFE = 20              -- seconds a ghost's pad lasts
Config.PAD_SPEED_X = 115          -- the launch along the arrow: speed you already carry that way is kept (rule 16) ...
Config.PAD_SPEED_Y = 120          -- ... and up (H30: was 105 = 2 x JUMP_SPEED, a rise under a held jump's and "no
                                  -- oomph"; a rise above 105 spends the speed check's up burst: move_check.test
                                  -- measures the pad chain's use, config.test caps the knob). Danzo's to tune
Config.PAD_RAMP = 0.1             -- H30: seconds the launch's across speed climbs to PAD_SPEED_X (0 = at once; "it
                                  -- boosts you but feels sudden"). The up launch is always at once: it is a jump
Config.PAD_GLIDE = 0.7            -- H30: seconds the launch's across speed eases back to the run (a smooth curve: held,
                                  -- then easing, then settling) while you hold the launch's way; 0 = the plain bleed
-- Ghosts v2 PR 5 (DESIGN §3 rules 2, 3, 50, 51; H23, docs/systems/endgame.md). Trial numbers, tuned by hand.
Config.IGNITE_AT = 10             -- rule 50: seconds left on the fuse when the holder visibly ignites, growing to 0
Config.END_PHASE_AFTER = 120      -- rule 51: seconds into a round when the end phase starts if the final two have not
                                  -- come first (H23's pick: a round still 3+ alive here has ~2 lives left, ~3:00)
Config.END_PHASE_SPEED = 1.1      -- rule 51: in the end phase every living runner's top run speed x this, ramp and
                                  -- grant on top (45 x 1.15 x 1.1 = 56.9: still under the speed check's dash rate)
-- The closing walls (H24, DESIGN §3 rules 3, 51; docs/systems/endgame.md §7): SpeedRunners' shrinking screen as a
-- server-owned window in world space. Trial numbers, tuned by hand; the reasons are in endgame.md §7.
Config.WALL_START_PAD = 8         -- studs: the walls appear this far past the farthest living runner (nobody starts out)
Config.WALL_START_MIN = 44        -- ... and never nearer the centre than this: ~half a 16:9 screen (85 studs wide)
Config.WALL_MIN_HW = 24           -- studs: they stop closing here, a 48-stud box (12 tiles), both walls on one screen
Config.WALL_CLOSE_TIME = 20       -- seconds from appearing to closed, whatever the start width
Config.WALL_FOLLOW = 8            -- studs/s at most the window's centre drifts after the living (a run is 45: a zone,
                                  -- not a camera; nobody can drag it)
Config.WALL_EASE = 0.5            -- 1/s: the centre eases toward its target (a 2 s time constant) under that cap
-- H26 (endgame.md §7.7): the moving window. The target is the living mean, leaned toward the holder, plus a wander.
Config.WALL_LEAN = 0.25           -- share of the way from the living mean to the holder (0: the plain mean; < 0 leans
                                  -- toward the others). A duel: the runner may be at most 38 studs from "it", not 48
Config.WALL_DRIFT = 20            -- studs: the wander's reach in the target (two sines); after the ease the box sways
                                  -- ~24 studs end to end at up to ~7.9 studs/s. Fades in with the close (0 at the start)
Config.WALL_DRIFT_PERIOD = 8      -- seconds: the wander's main period; the second sine runs 1.618x slower (never repeats)
Config.WALL_GRACE = 6             -- seconds a living runner may be past a wall; reset once it is back inside (below).
                                  -- 3 s for the still box (H24); 6 s once the box moved on its own (Danzo, 2026-11-07):
                                  -- under a third of the close, too short to hide outside and dip back in for a reset
Config.WALL_BACK_IN = 2           -- studs: out once the whole body is past a wall, back IN (grace reset) only this much
                                  -- further in: 2 = RUNNER_WIDTH, the whole body back inside. Stops a runner at a
                                  -- swaying wall flapping out/in every frame (H26 follow-up, endgame.md §7.4)
Config.ROUND_GAP = 6             -- seconds between one round ending and the next starting (H31: 4 -> 6, the results card)
-- The match (H31, DESIGN §6.4, rules 31-34; docs/systems/session.md): a match is MATCH_ROUNDS rounds with a score, then
-- a podium, then the lobby again. Bots fill the empty seats. Trial numbers, Danzo's to tune.
Config.MATCH_ROUNDS = 3           -- rounds in a match (rule 33: one bad round does not decide everything)
Config.LOBBY_TIME = 12            -- seconds of warm-up in the lobby once somebody has pressed Play
Config.PODIUM_TIME = 12           -- seconds the podium and the rewards stay up
Config.BOTS = true                -- bots fill a round up to PLAYERS_PER_MATCH (rule 31); false: only people play
Config.HUB = true                 -- H34: a public server is a HUB (PLAY queues you; groups of PLAYERS_PER_MATCH are sent
                                  -- to their own match server after at most LOBBY_TIME, and come back after the match).
                                  -- false: every server runs its own matches, as before (server/Hub; Studio always does)
-- The walk-in lobby and private rooms (H37, docs/systems/lobby.md). Trial numbers, Danzo's to tune by hand.
Config.DOOR_HOLD = 1              -- seconds a runner stays in a door to choose it (running past does nothing)
Config.LEAVE_HOLD = 2             -- ... and in QUICK MATCH to LEAVE the queue: slower, so it is never an accident
Config.QUICK_START = 3            -- seconds from PRACTICE, or a room host's START, to the round (a short 3-2-1)
Config.HOST_IDLE = 60             -- seconds a room's host may stand still before the next player becomes host
Config.CODE_GAP = 2               -- seconds between two room-code tries from one player (4 digits: 10 000 codes)
Config.ROOM_TTL = 3600            -- seconds a room's code lives without a refresh from its server
Config.BOT_SPEED = 0.93           -- a bot's run speed x this: a person who runs clean gets away, and catches one
Config.BOT_THINK = 0.3            -- seconds between a bot's plans (shared/BotBrain); also its reaction time
Config.BOT_LABEL = false          -- true: the scoreboard and the cards mark each bot "AI" and the how-to cards say
                                  -- empty seats are filled by AI runners. false (Danzo, 2026-11-16: "unknowingly"):
                                  -- nothing marks one. QA round 2 advises true for a kids' audience: his call
-- Rewards (H31, DESIGN §6.5; shared/Profile). Coins buy cosmetics and spins, never moves or power (rule 36).
-- Settled 2026-11-16 (Danzo: "trial numbers you can decide, it's arbitrary so long as it's balanced"): a spin about
-- every two matches for a middling player (4-6 points: 40-50 coins), a match win ~110, last place every round 20.
Config.COINS_MATCH = 20           -- for finishing a match (10 at first: a spin took a loser five matches) ...
Config.COINS_POINT = 5            -- ... plus this per match point ...
Config.COINS_WIN = 30             -- ... plus this for winning it
Config.COINS_START = 150          -- a new player's purse: enough for one spin at once
Config.COINS_DAILY = 50           -- the first join of each day
Config.SPIN_COST = 100            -- coins for one spin of the wheel (cosmetics only; a duplicate pays some back)
Config.XP_LEVEL = 100             -- xp per level (xp = coins earned from play)
-- Ability rolls (H35, Danzo 2026-11-16: "rolls for abilities gets built but not added yet; current abilities stay
-- free; then we can add some special item abilities later"). The plumbing is whole and OFF: shared/Catalog.ABILITIES
-- is empty and this switch is false. Turning it on with abilities in the catalogue opens the roll in the wheel.
Config.ABILITY_ROLLS = false      -- true: Remotes.Shop takes "roll", the wheel shows the ability roll, pools gain unlocks
Config.ABILITY_ROLL_COST = 250    -- coins for one ability roll (it never lands on one you own: no duplicates)
Config.START_SPREAD = 120         -- studs of floor the runners are spread over at round start, centred on the spawn
                                  -- (H8, Tag.startPlaces): 5 runners (4 + the Studio dummy) start 30 apart
Config.MAP = "yard"               -- H27: the map every round is played on (shared/Maps.lua: "yard", "test"; maps.md)
Config.READY_TIMEOUT = 5          -- seconds a due round waits for every present client's Ready (H11, players.md §5)
Config.OTHERS_DRAW_DELAY = 0.1    -- H13: other runners are drawn this far behind their replicated position, sliding
-- between the positions that arrived, so a body that lands in steps draws smoothly (players.md §3). 0 = raw. Cosmetic:
-- the tag claim tests the replicated root, not the drawing. Danzo's knob: higher is smoother and further behind.
-- It is the FLOOR: the trail raises it toward the longest recent arrival gap (x 1.25), up to the cap below (H13 run 4).
Config.OTHERS_DRAW_DELAY_MAX = 0.3 -- the most another runner is ever drawn behind; a sender stepping slower than this shows
-- The snapshot stream (H14, docs/systems/netcode.md §8): each client sends its runner's state over Remotes.Snapshot
-- (an UnreliableRemoteEvent); the server relays it and judges tags on it; other screens draw it. The trail above is
-- now only the fallback for a runner with no stream (the Studio stand-in, a client that stopped sending).
Config.SNAPSHOT_RATE = 30         -- snapshots a second per client; the server lets 1.5 x this through per sender
Config.SNAPSHOT_DELAY = 0.08      -- seconds other runners are drawn behind their newest snapshot (~2.4 snapshots at 30 Hz:
                                  -- room for one lost packet). Danzo's knob: lower is fresher, higher survives worse links
Config.SNAPSHOT_STALE = 0.5       -- no snapshot for this long: the server and the other screens fall back to the body
Config.TAG_LUNGE_TIME = 0.1       -- rule 6's catch-up: seconds the tagger's drawn sprite takes to reach the victim on a
                                  -- verdict, then as long again to ease back to its stream (0 = off). Cosmetic
-- Movement trust (H12, docs/systems/trust.md): the server's speed check on each player's client-owned body.
Config.MOVE_BURST_TIME = 0.2      -- slack per axis, in seconds of that axis's top speed (24 studs across at DASH_SPEED);
                                  -- the worst seen in Studio was 8.6 studs (the server's copy catching up after a stop)
Config.MOVE_CLEAR_TIME = 1        -- clean seconds after a violation before that runner's samples count for a tag again
Config.MOVE_SNAP_BACK = true      -- a violation rebuilds the body at its last trusted spot (false: untrusted only)
Config.MOVE_SNAP_GAP = 0.5        -- seconds between two snap-backs of one runner (a cheat looping cannot spin the server)

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
-- The grapple (H25, DESIGN §2 kit, §3 rule 17; shared/Grapple, docs/systems/grapple.md). Trial numbers, Danzo's by hand.
Config.GRAPPLE_RANGE = 28         -- studs from the runner to an anchor it may hook (7 tiles); also the longest rope
Config.GRAPPLE_MIN_ABOVE = 4      -- an anchor must be at least this far above the runner's centre (1 tile)
Config.GRAPPLE_BEHIND = 8         -- aim assist: an anchor behind the facing scores this many studs further away
Config.GRAPPLE_STICKY = 2         -- ... and the anchor already picked this many nearer, so the pick never flickers
Config.GRAPPLE_INSET_TOP = 6      -- ... and this far below the screen's TOP, where the HUD's fuse banner sits (QA r1)
Config.GRAPPLE_BEHIND_FAST = 0.8  -- faster than this x RUN_SPEED, an anchor behind the motion is never picked (QA r1:
                                  -- a hook behind a sprinting runner threw its speed away)
Config.GRAPPLE_BEHIND_SLOW = 0.7  -- ... and one already skipped comes back only under this x RUN_SPEED (QA r3: without
                                  -- the gap the halo blinked frame to frame while slowing past a ball)
Config.GRAPPLE_INSET = 2          -- studs inside the screen edge an anchor must be to be picked (rule 17: never off-screen)
Config.GRAPPLE_MIN_LEN = 8        -- the shortest rope (no loops round the anchor below the speed cap: 5 g L > cap^2)
Config.GRAPPLE_LIFT = 1           -- hooked from the floor, the rope reels in to this far above your feet's height ...
Config.GRAPPLE_REEL = 40          -- ... at this many studs/s, so a floor hook swings instead of dragging on the floor
Config.GRAPPLE_YOINK = 20         -- H28: studs/s the rope's bite adds along the swing toward under the anchor (all of it
                                  -- hooked level with the anchor, none straight under it). 0 = no yoink. Danzo's to tune
Config.GRAPPLE_PUMP = 60          -- studs/s^2 the stick pushes along the swing: a hanging runner can get going
Config.GRAPPLE_MAX_SPEED = Config.DASH_SPEED -- the swing never goes faster than a dash: the dash still redirects it
                                  -- without a loss (DESIGN §2), and the server's speed check needs no new rate
Config.GRAPPLE_RELEASE_BOOST = 1.25 -- rule 17's release boost: the swing's velocity x this on letting go (1 = off). H30:
                                  -- 1.1 -> 1.25, Danzo: "on the release it should feel like the character is pulling
                                  -- on the string to launch himself off"
Config.GRAPPLE_RELEASE_KICK = 25  -- H30: the haul: studs/s added along the swing on letting go, all of it level or
                                  -- rising, none straight down (0 = off). Danzo's to tune
Config.GRAPPLE_RELEASE_MAX = 140  -- H30: the most a release can leave you with: the haul is felt most on a slow swing
                                  -- and tops out here (at 150 the fastest chain spent 6.7 of the check's 24-stud x burst
                                  -- and 5.3 of the 10.5 up; at 140 what move_check_grapple.test pins). Keep >= the cap
Config.GRAPPLE_GIVE = 0.05        -- H30: the catch's give, seconds: the rope stretches and springs back (critically
                                  -- damped, settles in ~3x this) instead of stopping the outward speed in one frame
                                  -- ("the arc feels forced and sudden"). 0 = the hard catch
Config.GRAPPLE_COOLDOWN = 0.2     -- seconds after a release before the next hook
Config.GRAPPLE_BUFFER = 0.1       -- a press this early still hooks the moment an anchor is picked (x touch scale)
Config.GRAPPLE_REFRESH = true     -- hooking an anchor gives back the dash and double jump (rule 15: a contact)
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
