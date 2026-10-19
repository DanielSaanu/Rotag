-- The Studio stand-in runners (docs/systems/tag.md §4; H15: more than one, and they play as ghosts too). Studio only:
-- Match reads RunService:IsStudio() and Config.STUDIO_DUMMY once at boot (→ N1). Config.STUDIO_DUMMIES of them join
-- after the first player, ids -1000, -1001, ... (→ T8). server/Dummy.lua builds and moves one; this file decides where
-- each goes and makes its claims, which the server judges on this frame only (rewind 0: its position is the truth).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tag = require(Shared:WaitForChild("Tag"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local Dummy = require(script.Parent:WaitForChild("Dummy"))

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

-- Before the server samples: as it (not frozen) chase the nearest living player; as a ghost chase the holder;
-- otherwise patrol.
function Bots.move(r: Tag.Round?, dt: number, now: number, history: { [number]: { Tag.Sample } })
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
				chase = lastX(history, r.it)
			end
		end
		Dummy.step(d, dt, chase, r ~= nil and r.it == id and Tag.frozen(r, now))
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

-- After the players' spooks: a dummy ghost spooks the holder it touches.
function Bots.spooks(r: Tag.Round?, g: Ghost.Ghosts?, now: number, history: { [number]: { Tag.Sample } },
	land: (Tag.Round, Ghost.Ghosts, number, number) -> ())
	local it = r and not r.over and r.it
	if not (r and g and it) then return end
	for id in list do
		if Ghost.canSpook(r, g, id, it, now) then
			local ha, hb = history[id], history[it]
			if ha and hb and Tag.confirm(ha, hb, now, 0) then land(r, g, id, now) return end
		end
	end
end

return Bots
