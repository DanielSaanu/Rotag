-- For the Studio log only (split out of server/Match.lua, H31: the line ceiling): why a tag claim found no overlap.
-- Nothing here decides anything; Match prints what these return when a claim is dropped (tag.md §2, H13).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tag = require(Shared:WaitForChild("Tag"))

local TagLog = {}

-- For the Studio log only: the closest the boxes came (x gap, y gap) over the pairs Tag.touchedBetween looks at.
function TagLog.closest(a: { Tag.Sample }, b: { Tag.Sample }, from: number, to: number, lag: number): (number, number)
	local bx, by = math.huge, math.huge
	for _, sa in a do
		for _, sb in b do
			if sb.t >= from and sa.t <= to and sb.t <= sa.t and sa.t - sb.t <= lag and math.abs(sa.x - sb.x) < bx then
				bx, by = math.abs(sa.x - sb.x), math.abs(sa.y - sb.y)
			end
		end
	end
	return bx, by
end

-- For the Studio log only (H13, tag.md §2): the YOUNGEST target age at which the boxes did overlap for this claim,
-- over every target sample in the history, whatever the allowance. The age of a pair is how far the target sample is
-- behind the claimant's sample or the claim's arrival `at`, whichever is more (touchedBetween needs both inside lag).
-- nil: no overlap at any age the history holds (~1 s). Also how many claimant samples in the window were untrusted.
function TagLog.neededAge(a: { Tag.Sample }, b: { Tag.Sample }, from: number, to: number, at: number): (number?, number)
	local best, untrusted = nil, 0
	for _, sa in a do
		if sa.t >= from and sa.t <= to then
			if sa.untrusted then
				untrusted += 1
			else
				for _, sb in b do
					if sb.t <= sa.t and Tag.overlaps(sa.x, sa.y, sb.x, sb.y, Config.TAG_GRACE) then
						local age = math.max(sa.t - sb.t, at - sb.t)
						if best == nil or age < best then best = age end
					end
				end
			end
		end
	end
	return best, untrusted
end

return TagLog
