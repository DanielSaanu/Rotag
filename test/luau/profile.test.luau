-- Profiles and cosmetics (H31, docs/systems/session.md §5): shared/Catalog and shared/Profile. Coins, the shop, the
-- wheel, what a bad save turns into. Nothing here may touch a move (rule 36).
local Config = __require("Config")
local Catalog = __require("Catalog")
local Profile = __require("Profile")

do -- the catalogue is well formed: unique ids, known slots and rarities, a free default per slot, odds that add up
	local seen = {}
	for _, it in Catalog.ITEMS do
		assert(not seen[it.id], "duplicate id " .. it.id)
		seen[it.id] = true
		assert(table.find(Catalog.SLOTS, it.slot), it.id .. ": unknown slot")
		assert(Catalog.ODDS[it.rarity], it.id .. ": unknown rarity")
		assert(it.price == nil or it.price >= 0, it.id .. ": a price is a number >= 0 or nil (wheel only)")
		for _, c in it.colors do assert(#c == 3, it.id .. ": colours are { r, g, b }") end
	end
	local odds = 0
	for _, r in Catalog.RARITIES do
		odds += Catalog.ODDS[r]
		assert(#Catalog.pool(r) > 0, "the wheel has something of every rarity: " .. r)
		assert(Catalog.REFUND[r] < Config.SPIN_COST or r == "legendary", "a duplicate never pays a whole spin back")
		for _, it in Catalog.pool(r) do assert(it.price ~= 0, "a free default is never on the wheel") end
	end
	assert(odds == 100, "the odds add up to 100")
	for _, slot in Catalog.SLOTS do
		local d = Catalog.get(Catalog.DEFAULTS[slot])
		assert(d and d.slot == slot and d.price == 0, "every slot has a free default: " .. slot)
		assert(Catalog.SLOT_NAMES[slot], "and a name")
	end
end

do -- a new profile: the starting purse, the defaults owned and worn
	local p = Profile.new()
	assert(p.coins == Config.COINS_START and Profile.level(p) == 1, "the purse, level 1")
	for _, slot in Catalog.SLOTS do assert(p.owned[p.equipped[slot]], "wearing an owned default in " .. slot) end
	assert(Config.COINS_START >= Config.SPIN_COST, "a new player can spin once at once")
end

do -- buying: the price comes off once, wheel-only items cannot be bought, nothing twice, nothing on credit
	local p = Profile.new()
	p.coins = 250
	local ok, why = Profile.buy(p, "trail_cyan")
	assert(ok and p.coins == 50 and p.owned.trail_cyan, "bought")
	ok, why = Profile.buy(p, "trail_cyan")
	assert(not ok and why == "already owned" and p.coins == 50, "not twice")
	ok, why = Profile.buy(p, "trail_lime")
	assert(not ok and why == "not enough coins" and not p.owned.trail_lime and p.coins == 50, "no credit")
	p.coins = 99999
	ok, why = Profile.buy(p, "trail_rainbow")
	assert(not ok and why == "wheel only" and p.coins == 99999, "the wheel's items are not for sale")
	for _, bad in { "nope", 5, false, {} } do
		ok = Profile.buy(p, bad)
		assert(not ok and p.coins == 99999, "junk ids buy nothing")
	end
end

do -- equipping: only what you own, into its own slot
	local p = Profile.new()
	local ok, why = Profile.equip(p, "trail_cyan")
	assert(not ok and why == "not owned" and p.equipped.trail == "trail_none", "not owned: not worn")
	p.owned.trail_cyan = true
	assert(Profile.equip(p, "trail_cyan") and p.equipped.trail == "trail_cyan", "worn")
	assert(p.equipped.glow == "glow_none", "the other slots untouched")
	assert(not Profile.equip(p, 42), "junk equips nothing")
end

do -- the wheel: costs a spin, lands by the odds, a duplicate refunds, never free and never on credit
	local p = Profile.new()
	p.coins = Config.SPIN_COST - 1
	local it, why = Profile.spin(p, function() return 0 end)
	assert(it == nil and why == "not enough coins" and p.coins == Config.SPIN_COST - 1, "no credit")
	p.coins = 1000
	local function zero() return 0 end -- rarity roll 0: common; item roll 0: the first common
	local first, back = Profile.spin(p, zero)
	assert(first and first.rarity == "common" and back == 0 and p.owned[first.id], "a new common, owned")
	assert(p.coins == 1000 - Config.SPIN_COST and p.spins == 1, "it cost one spin")
	local again, back2 = Profile.spin(p, zero)
	assert(again and again.id == first.id and back2 == Catalog.REFUND.common, "the same again: a refund")
	assert(p.coins == 1000 - 2 * Config.SPIN_COST + Catalog.REFUND.common, "the refund is paid")
	local q = Profile.new()
	q.coins = 1000
	local leg = Profile.spin(q, function() return 0.999 end)
	assert(leg and leg.rarity == "legendary", "the top of the roll is a legendary")
	-- over many spins every rarity turns up about as often as the odds say
	local seed, counts, n = 7, {}, 20000
	local function lcg()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local r = Profile.new()
	for _ = 1, n do
		r.coins = Config.SPIN_COST
		local got = Profile.spin(r, lcg)
		counts[got.rarity] = (counts[got.rarity] or 0) + 1
	end
	for _, rarity in Catalog.RARITIES do
		local share = (counts[rarity] or 0) / n * 100
		assert(math.abs(share - Catalog.ODDS[rarity]) < 1.5,
			("%s came up %.1f%%, the odds say %d%%"):format(rarity, share, Catalog.ODDS[rarity]))
	end
end

do -- earning is xp; levels; the daily bonus once a day
	local p = Profile.new()
	local up = Profile.earn(p, Config.XP_LEVEL * 2 + 5)
	assert(up == 2 and Profile.level(p) == 3 and p.coins == Config.COINS_START + Config.XP_LEVEL * 2 + 5, "two levels")
	assert(Profile.earn(p, -50) == 0 and p.xp == Config.XP_LEVEL * 2 + 5, "never negative")
	local c = p.coins
	assert(Profile.daily(p, 20000) == Config.COINS_DAILY and p.coins == c + Config.COINS_DAILY, "the day's bonus")
	assert(Profile.daily(p, 20000) == 0 and p.coins == c + Config.COINS_DAILY, "once a day")
	assert(Profile.daily(p, 19999) == 0, "a clock that went back pays nothing")
	assert(Profile.daily(p, 20001) == Config.COINS_DAILY, "the next day pays again")
end

do -- whatever was saved becomes a valid profile
	local fresh = Profile.sanitize(nil)
	assert(fresh.coins == Config.COINS_START, "nothing saved: a new profile")
	local p = Profile.sanitize({ coins = -5, xp = 0 / 0, owned = { trail_cyan = true, hacked_item = true, glow_ice = "yes" },
		equipped = { trail = "trail_cyan", glow = "glow_ice", burst = "trail_cyan", title = 7 }, wins = 3.9, day = "x" })
	assert(p.coins == Config.COINS_START and p.xp == 0, "bad numbers fall back")
	assert(p.owned.trail_cyan and not p.owned.hacked_item and not p.owned.glow_ice, "unknown or not-true items dropped")
	assert(p.equipped.trail == "trail_cyan", "an owned item stays worn")
	assert(p.equipped.glow == "glow_none", "an unowned one falls back to the default")
	assert(p.equipped.burst == "burst_ember", "an item in the wrong slot falls back")
	assert(p.wins == 3 and p.day == 0, "whole numbers")
	local v = Profile.view(p)
	assert(#v.worn == #Catalog.SLOTS and v.worn[1] == "trail_cyan" and table.find(v.owned, "trail_cyan"), "the view is arrays")
	assert(#Profile.look(p) == #Catalog.SLOTS, "the look: one id per slot")
	local again = Profile.sanitize(p) -- a round trip through sanitize changes nothing
	for k, val in p do
		if type(val) ~= "table" then assert(again[k] == val, "round trip: " .. k) end
	end
end

print("    profile ok")
