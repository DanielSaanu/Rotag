--!strict
-- A player's saved profile (H31; DESIGN §6.5, rule 36; docs/systems/session.md §5): coins, xp, what they own and wear.
-- Pure Luau over plain tables: the SERVER owns every profile (server/Data loads and saves it, server/Shop is the only
-- caller of buy / equip / spin) and a client is only ever SENT its own. Nothing here touches a move or a speed.
-- The saved shape is `Profile` below with `v`; `sanitize` turns whatever the DataStore holds into a valid one, so a
-- catalogue change or a bad save never breaks a join. Tests: test/luau/profile.test.luau.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)

local Profile = {}

Profile.VERSION = 1

export type Profile = {
	v: number, coins: number, xp: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },   -- slot -> item id
	wins: number, matches: number, spins: number,
	abilities: { [string]: boolean }, -- H35: the special item abilities unlocked by ability rolls (Catalog.ABILITIES)
	day: number,                      -- the day number (os.time() // 86400) of the last daily bonus
}

function Profile.new(): Profile
	local p: Profile = { v = Profile.VERSION, coins = Config.COINS_START, xp = 0, owned = {}, equipped = {}, wins = 0,
		matches = 0, spins = 0, day = 0, abilities = {} }
	for slot, id in Catalog.DEFAULTS do
		p.owned[id] = true
		p.equipped[slot] = id
	end
	return p
end

local function count(v: any, default: number): number
	if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return default end
	return math.floor(v)
end

-- Whatever was saved, as a valid profile: unknown items dropped, every slot wearing something owned of that slot,
-- every number a whole number >= 0. nil or junk gives a new profile.
function Profile.sanitize(raw: any): Profile
	local p = Profile.new()
	if type(raw) ~= "table" then return p end
	p.coins = count(raw.coins, p.coins)
	p.xp, p.wins, p.matches = count(raw.xp, 0), count(raw.wins, 0), count(raw.matches, 0)
	p.spins, p.day = count(raw.spins, 0), count(raw.day, 0)
	if type(raw.owned) == "table" then
		for id, has in raw.owned do
			if has == true and Catalog.get(id) then p.owned[id] = true end
		end
	end
	if type(raw.abilities) == "table" then -- H35: an ability the catalogue no longer has is dropped, like an item
		for id, has in raw.abilities do
			if has == true and Catalog.ability(id) then p.abilities[id] = true end
		end
	end
	if type(raw.equipped) == "table" then
		for _, slot in Catalog.SLOTS do
			local it = Catalog.get(raw.equipped[slot])
			if it and it.slot == slot and p.owned[it.id] then p.equipped[slot] = it.id end
		end
	end
	return p
end

function Profile.level(p: Profile): number
	return 1 + p.xp // Config.XP_LEVEL
end

-- Coins earned by PLAYING (a match's reward): they count as xp too. Returns the levels gained.
function Profile.earn(p: Profile, coins: number): number
	local before = Profile.level(p)
	local c = math.max(0, math.floor(coins))
	p.coins += c
	p.xp += c
	return Profile.level(p) - before
end

-- The first join of a day pays COINS_DAILY. `day` is the server's day number. Returns the coins paid (0: already had).
function Profile.daily(p: Profile, day: number): number
	if day <= p.day then return 0 end
	p.day = day
	p.coins += Config.COINS_DAILY
	return Config.COINS_DAILY
end

-- Buy `id` from the shop. Returns ok and, when not, why (shown to the player).
function Profile.buy(p: Profile, id: any): (boolean, string?)
	local it = Catalog.get(id)
	if not it then return false, "no such item" end
	if p.owned[it.id] then return false, "already owned" end
	local price = it.price
	if price == nil then return false, "wheel only" end
	if p.coins < price then return false, "not enough coins" end
	p.coins -= price
	p.owned[it.id] = true
	return true, nil
end

function Profile.equip(p: Profile, id: any): (boolean, string?)
	local it = Catalog.get(id)
	if not it then return false, "no such item" end
	if not p.owned[it.id] then return false, "not owned" end
	p.equipped[it.slot] = it.id
	return true, nil
end

-- One spin of the wheel for SPIN_COST. `rand` returns [0, 1) (injected: the server's, a fixed one in tests). The
-- rarity is rolled on Catalog.ODDS, then one item of that rarity; a duplicate pays Catalog.REFUND back instead.
-- Returns the item landed on and the coins refunded (0: it is new and now owned), or nil and why.
function Profile.spin(p: Profile, rand: () -> number): (Catalog.Item?, number | string)
	if p.coins < Config.SPIN_COST then return nil, "not enough coins" end
	local roll, acc, rarity = rand() * 100, 0, Catalog.RARITIES[1]
	for _, r in Catalog.RARITIES do
		acc += Catalog.ODDS[r]
		if roll < acc then rarity = r break end
	end
	local pool = Catalog.pool(rarity)
	if #pool == 0 then return nil, "empty wheel" end
	local it = pool[math.min(#pool, math.floor(rand() * #pool) + 1)]
	p.coins -= Config.SPIN_COST
	p.spins += 1
	if p.owned[it.id] then
		local back = Catalog.REFUND[it.rarity] or 0
		p.coins += back
		return it, back
	end
	p.owned[it.id] = true
	return it, 0
end

-- One ability roll for ABILITY_ROLL_COST (H35). It lands only on an ability the player does not own yet (no
-- duplicates, so no refund): the rarity is rolled on Catalog.ODDS among the rarities that still have one, then one
-- of that rarity. Nothing is charged when the rolls are switched off or there is nothing left to win.
-- Returns the ability, or nil and why.
function Profile.rollAbility(p: Profile, rand: () -> number): (Catalog.Ability?, string?)
	if not Config.ABILITY_ROLLS then return nil, "ability rolls are not open yet" end
	local byRarity: { [string]: { Catalog.Ability } } = {}
	local total = 0
	for _, a in Catalog.ABILITIES do
		if not p.abilities[a.id] and Catalog.ODDS[a.rarity] then
			if not byRarity[a.rarity] then
				byRarity[a.rarity] = {}
				total += Catalog.ODDS[a.rarity]
			end
			table.insert(byRarity[a.rarity], a)
		end
	end
	if total == 0 then return nil, "nothing left to win" end
	if p.coins < Config.ABILITY_ROLL_COST then return nil, "not enough coins" end
	local roll, pool = rand() * total, nil
	for _, r in Catalog.RARITIES do
		local list = byRarity[r]
		if list then
			pool = list
			roll -= Catalog.ODDS[r]
			if roll < 0 then break end
		end
	end
	local list = pool :: { Catalog.Ability }
	local won = list[math.min(#list, math.floor(rand() * #list) + 1)]
	p.coins -= Config.ABILITY_ROLL_COST
	p.abilities[won.id] = true
	return won, nil
end

-- The rows a player's unlocked abilities add to its living orb pools: { { item, weight } }, in catalogue order
-- (shared/Items.poolFor's `extra`). Empty while the rolls are switched off, whatever was saved.
function Profile.unlocked(p: Profile): { { any } }
	local rows = {}
	if not Config.ABILITY_ROLLS then return rows end
	for _, a in Catalog.ABILITIES do
		if p.abilities[a.id] then table.insert(rows, { a.item, a.weight }) end
	end
	return rows
end

-- What the owner's client is sent (Remotes.Profile): arrays and plain fields only (→ N13).
function Profile.view(p: Profile): any
	local owned = {}
	for _, it in Catalog.ITEMS do if p.owned[it.id] then table.insert(owned, it.id) end end
	local worn = {}
	for _, slot in Catalog.SLOTS do table.insert(worn, p.equipped[slot]) end
	local abilities = {}
	for _, a in Catalog.ABILITIES do if p.abilities[a.id] then table.insert(abilities, a.id) end end
	return { coins = p.coins, xp = p.xp, level = Profile.level(p), owned = owned, worn = worn, wins = p.wins,
		matches = p.matches, abilities = abilities }
end

-- What EVERY client is sent about a runner (Remotes.Looks): the ids it wears, in Catalog.SLOTS order.
function Profile.look(p: Profile): { string }
	local worn = {}
	for _, slot in Catalog.SLOTS do table.insert(worn, p.equipped[slot]) end
	return worn
end

return Profile
