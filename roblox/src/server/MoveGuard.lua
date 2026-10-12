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
-- Per player: the body being checked (a new body, from any spawn, starts a fresh check), the check, the last snap.
local guards: { [number]: { root: BasePart, check: MoveCheck.State, snapped: number, warned: number } } = {}

-- One sample Match just recorded for runner `id` from `root`. Marks `sample.untrusted` while that runner is suspect.
function MoveGuard.observe(id: number, root: BasePart, sample: { t: number, x: number, y: number, untrusted: boolean? })
	local player = Players:GetPlayerByUserId(id)
	if not player then return end -- the server's own runners (the Studio dummy, a stand-in) are not checked
	local g = guards[id]
	if not g or g.root ~= root then
		-- A body the server just built (join, round start, respawn, snap-back): where the server put it is trusted.
		guards[id] = { root = root, check = MoveCheck.new(sample.x, sample.y, sample.t),
			snapped = if g then g.snapped else -math.huge, warned = if g then g.warned else -math.huge }
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
