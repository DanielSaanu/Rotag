--!strict
-- Ghosts (DESIGN §3 rules 37-41, adopted by Danzo 2026-10-14, H15; docs/systems/ghosts.md). Pure Luau over plain
-- tables, every clock passed in as `now`, like shared/Tag. The SERVER owns the one Ghosts state beside its Tag.Round
-- and is the only caller that changes either; clients only read what MatchState carries.
-- A ghost is a runner eliminated in this round (r.alive[id] == false). It spooks "it" by touch: SPOOK_DRAIN seconds
-- off the fuse. One cooldown per ghost, one ward shared by all ghosts (so the burn is capped whatever their number),
-- none while the holder is frozen. The latest ghost to spook the current holder holds the mark; if the fuse runs out,
-- that ghost comes back to life where it stands (Tag.tick's `back`), once per player per round.
local Config = require(script.Parent.Config)
local Tag = require(script.Parent.Tag)

local Ghost = {}

export type Ghosts = {
	used: { [number]: number },    -- comebacks spent this round, per runner id
	readyAt: { [number]: number }, -- per ghost: no spook from it before this
	wardUntil: number,             -- no spook from ANY ghost before this (rule 38: the shared ward)
	mark: number?,                 -- the ghost holding the mark ...
	markHold: number,              -- ... on the hold r.hold had when it was set (a pass or elimination clears it)
}

function Ghost.new(): Ghosts
	return { used = {}, readyAt = {}, wardUntil = -math.huge, mark = nil, markHold = -1 }
end

-- In this round and eliminated. A runner who joined after the round began is not a ghost (it is not in r.alive).
function Ghost.isGhost(r: Tag.Round, id: number): boolean
	return not r.over and r.alive[id] == false
end

function Ghost.comebacksLeft(g: Ghosts, id: number): number
	return math.max(0, Config.GHOST_COMEBACKS - (g.used[id] or 0))
end

-- Seconds until this ghost's own cooldown ends (0 = ready), and until the shared ward ends.
function Ghost.readyIn(g: Ghosts, id: number, now: number): number
	return math.max(0, (g.readyAt[id] or -math.huge) - now)
end
function Ghost.wardLeft(g: Ghosts, now: number): number
	return math.max(0, g.wardUntil - now)
end

-- The ghost that comes back if the fuse runs out now, or nil: the mark must be on THIS hold. Only a ghost with a
-- comeback left is ever given it, and a comeback or a leave clears it (Tag.tick checks it is still a ghost too).
function Ghost.markOf(r: Tag.Round, g: Ghosts): number?
	local m = g.mark
	if m == nil or g.markHold ~= r.hold then return nil end
	return m
end

-- May `ghost` spook `target` at `now`? Rules only; positions are the caller's (the server's own history, like a tag).
-- Returns ok and, when not, the reason (for the Studio log only).
function Ghost.canSpook(r: Tag.Round, g: Ghosts, ghost: number, target: number, now: number): (boolean, string?)
	if r.over then return false, "round over" end
	if not Ghost.isGhost(r, ghost) then return false, "not a ghost" end
	if r.it ~= target then return false, "target is not it" end
	if Tag.frozen(r, now) then return false, "holder frozen" end
	if now < g.wardUntil then return false, "warded" end
	if now < (g.readyAt[ghost] or -math.huge) then return false, "cooling down" end
	if Tag.fuseLeft(r, now) <= 0 then return false, "fuse out" end
	return true, nil
end

-- A confirmed spook (call canSpook first): SPOOK_DRAIN off the fuse (never below 0), the ghost's cooldown and the
-- shared ward start, and the mark goes to this ghost if it has a comeback left (a spent ghost leaves the mark where it
-- was). Returns the fuse after, what was really drained (→ N7: the pop shows this), and whether the mark is now its.
function Ghost.spook(r: Tag.Round, g: Ghosts, ghost: number, now: number): (number, number, boolean)
	local left = Tag.fuseLeft(r, now)
	local drained = math.min(Config.SPOOK_DRAIN, left)
	r.fuse, r.since = left - drained, now
	g.wardUntil = now + Config.GHOST_WARD
	g.readyAt[ghost] = now + Config.SPOOK_COOLDOWN
	local marked = Ghost.comebacksLeft(g, ghost) > 0
	if marked then g.mark, g.markHold = ghost, r.hold end
	return r.fuse, drained, marked
end

-- Advance the round (use instead of Tag.tick). Returns who was eliminated this call and who came back, if anyone.
-- The marked ghost revives where it stands and is never the new holder; the eliminated holder becomes a ghost on a
-- full SPOOK_COOLDOWN (no instant revenge on the new holder). The fuse still shrinks: Tag.tick counts the elimination.
function Ghost.tick(r: Tag.Round, g: Ghosts, now: number): (number?, number?)
	if r.over or r.it == nil or Tag.fuseLeft(r, now) > 0 then return nil, nil end
	local back = Ghost.markOf(r, g)
	local out = Tag.tick(r, now, back)
	if out == nil then return nil, nil end
	g.readyAt[out] = now + Config.SPOOK_COOLDOWN
	g.mark = nil
	if back ~= nil and r.alive[back] then
		g.used[back] = (g.used[back] or 0) + 1
		g.readyAt[back] = nil
		return out, back
	end
	return out, nil
end

-- A runner left the game: a mark it held is gone (its comeback cannot happen).
function Ghost.leave(g: Ghosts, id: number)
	if g.mark == id then g.mark = nil end
end

return Ghost
