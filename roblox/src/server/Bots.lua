-- The Studio stand-in runners (docs/systems/tag.md §4; H15: more than one, and they play as ghosts too: H18, a dummy
-- ghost runs to the nearest ghost orb on the floor, then, holding a hex, chases the holder). Studio only:
-- Match reads RunService:IsStudio() and Config.STUDIO_DUMMY once at boot (→ N1). Config.STUDIO_DUMMIES of them join
-- after the first player, ids -1000, -1001, ... (→ T8). server/Dummy.lua builds and moves one; this file decides where
-- each goes and makes its claims, which the server judges on this frame only (rewind 0: its position is the truth).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local OrbRules = require(Shared:WaitForChild("Orbs"))
local Config = require(Shared:WaitForChild("Config"))
local ItemRules = require(Shared:WaitForChild("Items"))
local Dummy = require(script.Parent:WaitForChild("Dummy"))
local Items = require(script.Parent:WaitForChild("Items")) -- H19: dummies use what they roll, and stop while held

local Bots = {}
Bots.ids = {} :: { [number]: boolean } -- for Tag.readyToStart: never waited for

local list: { [number]: any } = {}
local count = 0

function Bots.add(tagName: string): number
	local id = Dummy.ID - count
	count += 1
	list[id] = Dummy.new(tagName, id)
	Bots.ids[id] = true
	return id
end

function Bots.any(): boolean return count > 0 end
function Bots.isBot(id: number): boolean return Bots.ids[id] == true end
function Bots.place(id: number, x: number)
	local d = list[id]
	if d then Dummy.place(d, x) end
end

local function lastX(history: { [number]: { Tag.Sample } }, id: number): number?
	local h = history[id]
	local s = h and h[#h]
	return s and s.x
end

-- A ghost dummy's goal: the nearest ghost orb a floor-bound box can reach, preferring one that is up (H18).
local REACH_Y = Config.RUNNER_HEIGHT + Config.ORB_SIZE
local function orbX(o: OrbRules.State?, x: number): number?
	if not o then return nil end
	local best, bestD = nil, math.huge
	for i, s in o.spots do
		local d = math.abs(s.x - x) + (if o.up[i] then 0 else 1e4)
		if s.kind == "ghost" and s.y <= REACH_Y and d < bestD then best, bestD = s.x, d end
	end
	return best
end

-- Before the server samples: as it (not frozen) chase the nearest living player; as a ghost holding a hex chase the
-- holder, with an empty slot head for a ghost orb; otherwise patrol.
function Bots.move(r: Tag.Round?, dt: number, now: number, history: { [number]: { Tag.Sample } }, o: OrbRules.State?)
	for id, d in list do
		local chase: number? = nil
		local x = d.root.Position.X
		if r and not r.over and r.it then
			if r.it == id and not Tag.frozen(r, now) then
				local best = math.huge
				for _, other in r.order do
					local ox = if r.alive[other] and not Bots.isBot(other) then lastX(history, other) else nil
					if ox and math.abs(ox - x) < best then chase, best = ox, math.abs(ox - x) end
				end
			elseif r.alive[id] == false then
				chase = if o and o.held[id] ~= nil then lastX(history, r.it) else orbX(o, x) -- any item: to the holder
			end
		end
		-- A held dummy stands still for any hold (it is a stand-in, not a body that stumbles or slides).
		Dummy.step(d, dt, chase, (r ~= nil and r.it == id and Tag.frozen(r, now)) or Items.held(id, now))
	end
end

-- A dummy's facing (server/Items puts its crate behind it and its beam ahead); nil for anyone else.
function Bots.facing(id: number): number?
	local d = list[id]
	return d and d.facing
end

-- H19, after the orbs: a dummy holding a crate, trap or ice uses it once a living PLAYER is within ICE_LENGTH, turning
-- to face that player first, so a solo test shows holds. Through server/Items.press: the same rules as a player's Use.
function Bots.uses(r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } }, o: OrbRules.State?)
	if not (r and o) or r.over then return end
	for id, d in list do
		local item = o.held[id]
		local x = lastX(history, id)
		local frozen = r.it == id and Tag.frozen(r, now) -- would only log "frozen" every frame
		if item and item ~= "hex" and x and not frozen and not Items.held(id, now) then
			for _, other in r.order do
				local ox = if r.alive[other] and not Bots.isBot(other) then lastX(history, other) else nil
				if ox and math.abs(ox - x) <= Config.ICE_LENGTH then
					d.facing = if ox >= x then 1 else -1
					Items.press(id, now)
					break
				end
			end
		end
	end
end

-- After the server sampled and judged the players' tags: a dummy holder tags the first living PLAYER it touches.
-- Never another dummy: with several they share one patrol lane and would pass the fuse between them for ever (seen
-- in Play, H15), so the fuse could not run out on a dummy and no dummy would ever become a ghost.
function Bots.tags(r: Tag.Round?, now: number, history: { [number]: { Tag.Sample } },
	pass: (Tag.Round, number, number, number) -> ())
	local it = r and not r.over and r.it
	if not (r and it and list[it]) then return end
	for _, id in r.order do
		if id ~= it and r.alive[id] and not Bots.isBot(id) and Tag.canClaim(r, it, id, now) then
			local ha, hb = history[it], history[id]
			if ha and hb and Tag.confirm(ha, hb, now, 0) then pass(r, it, id, now) return end
		end
	end
end

-- After the players' hexes: a dummy ghost holding a hex hexes the holder it touches.
function Bots.hexes(r: Tag.Round?, g: Ghost.Ghosts?, o: OrbRules.State?, now: number,
	history: { [number]: { Tag.Sample } }, land: (Tag.Round, Ghost.Ghosts, OrbRules.State, number, number) -> ())
	local it = r and not r.over and r.it
	if not (r and g and o and it) then return end
	for id in list do
		if Ghost.canHex(r, g, o, id, it, now) then
			local ha, hb = history[id], history[it]
			if ha and hb and Tag.confirm(ha, ItemRules.undodged(hb), now, 0) then land(r, g, o, id, now) return end
		end
	end
end

return Bots
