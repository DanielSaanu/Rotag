--!strict
-- Ghosts v2 (DESIGN §3 rules 37-42, adopted by Danzo 2026-10-19, H16; built H18; docs/systems/ghosts.md). Pure Luau
-- over plain tables, every clock passed in as `now`, like shared/Tag. The SERVER owns the one Ghosts state beside its
-- Tag.Round and Orbs.State and is the only caller that changes them; clients only read what the remotes carry.
-- A ghost is a runner eliminated in this round (r.alive[id] == false). It stays out for the round: no mark, no
-- comeback (rule 38). Its one way to touch the fuse is the hex (rule 40), an item rolled from a ghost orb
-- (shared/Orbs): while it holds one, its touch on the holder takes SPOOK_DRAIN off the fuse and empties the slot. One
-- ward shared by every ghost after any hex (so the burn is capped whatever their number), none while the holder is frozen.
local Config = require(script.Parent.Config)
local Tag = require(script.Parent.Tag)
local Orbs = require(script.Parent.Orbs)

local Ghost = {}

export type Ghosts = {
	wardUntil: number, -- no hex from ANY ghost before this (rule 40: the shared ward)
	wards: { [number]: number }, -- per runner: no ghost's AIMED ability (ice beam, hex) lands before this (rule 41, H19)
}

function Ghost.new(): Ghosts
	return { wardUntil = -math.huge, wards = {} }
end

-- In this round and eliminated. A runner who joined after the round began is not a ghost (it is not in r.alive).
function Ghost.isGhost(r: Tag.Round, id: number): boolean
	return not r.over and r.alive[id] == false
end

-- How many ghosts this round has (the ghost orbs' respawn, rule 42). `present` skips a ghost that left the game
-- (Tag.leave marks a leaver not alive, so without it a leaver would count).
function Ghost.count(r: Tag.Round, present: ((number) -> boolean)?): number
	local n = 0
	for _, id in r.order do
		if Ghost.isGhost(r, id) and (present == nil or present(id)) then n += 1 end
	end
	return n
end

-- Seconds until the shared ward ends (0 = no ward).
function Ghost.wardLeft(g: Ghosts, now: number): number
	return math.max(0, g.wardUntil - now)
end

-- May `ghost` hex `target` at `now`? Rules only; positions are the caller's (the server's own history, like a tag).
-- Returns ok and, when not, the reason (for the Studio log only).
function Ghost.canHex(r: Tag.Round, g: Ghosts, o: Orbs.State, ghost: number, target: number, now: number)
	: (boolean, string?)
	if r.over then return false, "round over" end
	if not Ghost.isGhost(r, ghost) then return false, "not a ghost" end
	if o.held[ghost] ~= "hex" then return false, "no hex held" end
	if r.it ~= target then return false, "target is not it" end
	if Tag.frozen(r, now) then return false, "holder frozen" end
	if now < g.wardUntil then return false, "warded" end
	if now < (g.wards[target] or -math.huge) then return false, "target warded (a ghost's ice hit it)" end
	if Tag.fuseLeft(r, now) <= 0 then return false, "fuse out" end
	return true, nil
end

-- A confirmed hex (call canHex first): SPOOK_DRAIN off the fuse (never below 0), the shared ward starts, the ghost's
-- slot empties. Returns the fuse after and what was really drained (→ N7: the pop shows this).
function Ghost.hex(r: Tag.Round, g: Ghosts, o: Orbs.State, ghost: number, now: number): (number, number)
	local left = Tag.fuseLeft(r, now)
	local drained = math.min(Config.SPOOK_DRAIN, left)
	r.fuse, r.since = left - drained, now
	g.wardUntil = now + Config.GHOST_WARD
	local holder = r.it
	if holder then g.wards[holder] = now + Config.GHOST_WARD end -- rule 41: also safe from ghosts' ice beams
	Orbs.use(o, ghost)
	return r.fuse, drained
end

return Ghost
