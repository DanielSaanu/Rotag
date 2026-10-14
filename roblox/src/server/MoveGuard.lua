-- The server's speed check on every player's client-owned runner (H12, docs/systems/trust.md). Match hands it each
-- position sample it records; the rule is shared/MoveCheck (pure, tested). On a violation: the sample, and every one
-- until a clean Config.MOVE_CLEAR_TIME, is marked `untrusted` (Tag never confirms a claim on it), a warning goes to the
-- server log, and the body is rebuilt at its last trusted spot (Runners.spawn, → N8), at most once per MOVE_SNAP_GAP.
-- No remote: the server reads the body Roblox already replicates (trust.md §1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MoveCheck = require(Shared:WaitForChild("MoveCheck"))
local Runners = require(script.Parent:WaitForChild("Runners"))

local MoveGuard = {}

local WARN_GAP = 1 -- seconds between two log lines about one runner
-- H13 (trust.md §9): the whole check assumes the PLAYER simulates its body. If anyone else does (the server, or another
-- client), the server's copy never follows the player's own screen: every other screen draws that runner where it
-- stood, and every claim by or against it is judged on a body that is not where its player sees it. So on EVERY
-- sample the owner is read (one call per player per frame); if it is not the player, ownership is handed back. The
-- warning is rate-limited and counts the hand-backs, so a body that keeps losing its owner shows as a big count.
-- (First version checked once a second: the re-test fixed the stuck bodies, so a wrong owner can last at most a frame.)
local BODY_LOG = 5 -- Studio only: seconds between "body:" lines (where the server sees each player, and who owns it)
local studio = game:GetService("RunService"):IsStudio()
-- Per player: the body being checked (a new body, from any spawn, starts a fresh check), the check, the last snap,
-- the last owner warning, hand-backs since it, and the last Studio body line.
local guards: { [number]: { root: BasePart, check: MoveCheck.State, snapped: number, warned: number, ownerWarned: number,
	handbacks: number, logged: number } } = {}

local function ownerName(owner: Player?): string
	return if owner then owner.Name else "the server"
end

-- True when the body's owner had to be handed back to `player` (the caller restarts the speed check).
local function checkOwner(player: Player, root: BasePart, g, sample): boolean
	local ok, owner = pcall(root.GetNetworkOwner, root)
	if studio and sample.t - g.logged >= BODY_LOG then
		g.logged = sample.t
		print(("[Rotag] body: %s at (%.1f, %.1f), simulated by %s; %d hand-back(s) since the last body line"):format(
			player.Name, sample.x, sample.y, if ok then ownerName(owner) else "? (" .. tostring(owner) .. ")", g.handbacks))
		g.handbacks = 0
	end
	if not ok or owner == player then return false end
	local set, err = pcall(root.SetNetworkOwner, root, player)
	if set then g.handbacks += 1 end
	if not set or sample.t - g.ownerWarned >= WARN_GAP then
		g.ownerWarned = sample.t
		warn(("[Rotag] owner: %s's runner was simulated by %s at (%.1f, %.1f); %s"):format(player.Name,
			ownerName(owner), sample.x, sample.y,
			if set then "handed back to " .. player.Name else "hand-back failed: " .. tostring(err)))
	end
	return set
end

-- One sample Match just recorded for runner `id` from `root`. Marks `sample.untrusted` while that runner is suspect.
function MoveGuard.observe(id: number, root: BasePart, sample: { t: number, x: number, y: number, untrusted: boolean? })
	local player = Players:GetPlayerByUserId(id)
	if not player then return end -- the server's own runners (the Studio dummy, a stand-in) are not checked
	local g = guards[id]
	if not g or g.root ~= root then
		-- A body the server just built (join, round start, respawn, snap-back): where the server put it is trusted.
		guards[id] = { root = root, check = MoveCheck.new(sample.x, sample.y, sample.t),
			snapped = if g then g.snapped else -math.huge, warned = if g then g.warned else -math.huge,
			ownerWarned = if g then g.ownerWarned else -math.huge, handbacks = if g then g.handbacks else 0,
			logged = if g then g.logged else -math.huge }
		return
	end
	if checkOwner(player, root, g, sample) then
		-- The server's copy will now jump from where the wrong owner held it to where the player really is. That jump
		-- is the server's own repair, not the client's doing: restart the check here instead of punishing it.
		g.check = MoveCheck.new(sample.x, sample.y, sample.t)
		return
	end
	local c = g.check
	local ok, axis, over = MoveCheck.step(c, sample.x, sample.y, sample.t)
	if c.suspect then sample.untrusted = true end
	if ok then return end
	local now = sample.t
	local snap = Config.MOVE_SNAP_BACK and now - g.snapped >= Config.MOVE_SNAP_GAP
	if now - g.warned >= WARN_GAP then
		g.warned = now
		warn(("[Rotag] move: %s (%d) over the %s speed limit by %.1f studs at (%.1f, %.1f); %s"):format(player.Name, id,
			tostring(axis), over or 0, sample.x, sample.y, if snap then ("snapped back to (%.1f, %.1f)"):format(
				c.trustX, c.trustY) else "untrusted for tags"))
	end
	if snap then
		g.snapped = now
		local at = Vector3.new(c.trustX, c.trustY, 0)
		-- Deferred: Match is walking its runner table when it calls this; the new body arrives through its tag signal.
		task.defer(Runners.spawn, player, at)
	end
end

function MoveGuard.forget(id: number)
	guards[id] = nil
end

return MoveGuard
