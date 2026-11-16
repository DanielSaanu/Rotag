-- The shop, the locker and the wheel on the server (H31; DESIGN §6.5, rule 36; docs/systems/session.md §5). The rules
-- are shared/Profile (pure, tested); this file judges every Remotes.Shop request on the server's own profile, tells
-- the owner what it now has (Remotes.Profile) and tells everyone what each runner wears (Remotes.Looks).
-- Trust (→ N4): the payload is an op string and an item id string, anything else is dropped unread; the sender is
-- the Player Roblox passes; rate-gapped per player; prices, odds and ownership are only ever read from the server's
-- Catalog and profile. A refusal gets a one-line `note` back (it is the player's own purse, not a secret).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Profile = require(Shared:WaitForChild("Profile"))
local SessionRules = require(Shared:WaitForChild("Session"))
local Data = require(script.Parent:WaitForChild("Data"))

local Shop = {}

local GAP = 0.25 -- seconds between two requests from one player
local profileRemote: RemoteEvent? = nil
local looksRemote: RemoteEvent? = nil
local lastAt: { [number]: number } = {}
local botLooks: { [number]: { string } } = {}

-- Tell `player` its profile, with whatever just happened (`extra`: spin = { id, back }, note, earned, levels).
function Shop.push(player: Player, extra: { [string]: any }?)
	local p = Data.get(player)
	if not (p and profileRemote) then return end
	local view = Profile.view(p)
	view.saved = Data.saves(player)
	for k, v in extra or {} do view[k] = v end
	profileRemote:FireClient(player, view)
end

-- A bot wears something too, as most players do: one COMMON item per slot (often the free default), fixed for the
-- server's life. Never a rare one (QA round 2): a rare wheel prize on a runner that is not a person would be an
-- advert dressed as a player.
local function botLook(id: number): { string }
	local look = botLooks[id]
	if not look then
		look = {}
		for _, slot in Catalog.SLOTS do
			local commons = {}
			for _, it in Catalog.inSlot(slot) do
				if it.rarity == "common" then table.insert(commons, it) end
			end
			table.insert(look, commons[math.random(1, #commons)].id)
		end
		botLooks[id] = look
	end
	return look
end

-- Everyone's look: { { id, worn = { item id per slot } } }, arrays only (→ N13). Bots: the ids server/Session seats.
local function looks(): { any }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local p = Data.get(player)
		if p then table.insert(rows, { id = player.UserId, worn = Profile.look(p) }) end
	end
	for k = 1, 4 do
		local id = SessionRules.botId(k)
		table.insert(rows, { id = id, worn = botLook(id) })
	end
	return rows
end

function Shop.looksTo(player: Player?)
	if not looksRemote then return end
	if player then looksRemote:FireClient(player, looks()) else looksRemote:FireAllClients(looks()) end
end

local function onShop(player: Player, op: any, arg: any)
	local now = os.clock()
	if now - (lastAt[player.UserId] or -math.huge) < GAP then return end
	lastAt[player.UserId] = now
	if type(op) ~= "string" or (arg ~= nil and type(arg) ~= "string") or (arg and #arg > 40) then return end
	local p = Data.get(player)
	if not p then return end
	if op == "buy" then
		local ok, why
		Data.update(player, function(q) ok, why = Profile.buy(q, arg) end)
		if ok then Data.update(player, function(q) Profile.equip(q, arg) end) end -- a new thing goes straight on
		Shop.push(player, { note = if ok then "bought" else why, bought = if ok then arg else nil })
		if ok then Shop.looksTo(nil) end
	elseif op == "equip" then
		local ok, why
		Data.update(player, function(q) ok, why = Profile.equip(q, arg) end)
		Shop.push(player, { note = if ok then nil else why })
		if ok then Shop.looksTo(nil) end
	elseif op == "spin" then
		local item, back
		Data.update(player, function(q) item, back = Profile.spin(q, math.random) end)
		if item then
			Shop.push(player, { spin = { id = item.id, back = back } })
		else
			Shop.push(player, { note = tostring(back) })
		end
	elseif op == "roll" then -- H35: an ability roll. Refused (nothing charged) while the rolls are off or empty.
		local won, why
		Data.update(player, function(q) won, why = Profile.rollAbility(q, math.random) end)
		Shop.push(player, if won then { roll = { id = won.id } } else { note = tostring(why) })
	elseif op == "get" then
		Shop.push(player)
		Shop.looksTo(player)
	end
end

function Shop.start(shop: RemoteEvent?, profile: RemoteEvent?, looksEvent: RemoteEvent?)
	profileRemote, looksRemote = profile, looksEvent
	if shop then shop.OnServerEvent:Connect(onShop) end
	if profile then profile.OnServerEvent:Connect(function() end) end -- server -> client only (→ N3)
	if looksEvent then looksEvent.OnServerEvent:Connect(function() end) end
	local function onPlayer(player: Player)
		if RunService:IsStudio() then -- Studio only: a test session shops from a script ("op" or "op:item id")
			player:GetAttributeChangedSignal("RotagShop"):Connect(function()
				local v = player:GetAttribute("RotagShop")
				if type(v) ~= "string" then return end
				local op, arg = string.match(v, "^(%a+):?(.*)$")
				lastAt[player.UserId] = nil
				onShop(player, op, if arg ~= "" then arg else nil)
			end)
		end
		Data.whenLoaded(player, function()
			if not player.Parent then return end
			Shop.push(player)
			Shop.looksTo(nil)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player) lastAt[player.UserId] = nil end)
end

return Shop
