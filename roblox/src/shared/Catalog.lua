--!strict
-- The cosmetics (H31; DESIGN §6.5, §3 rule 36: progression stays cosmetic, no item here changes a move, a speed or a
-- hitbox). Pure data: what exists, what slot it goes in, how rare it is, what it costs. shared/Profile owns the rules
-- (buy, equip, spin); client/Cosmetics draws them from the colours here. Colours are { r, g, b } 0-255 so this file
-- stays pure Luau. Tests: test/luau/profile.test.luau.
local Catalog = {}

export type Item = {
	id: string, slot: string, name: string, rarity: string,
	price: number?,           -- coins in the shop; nil: the wheel only
	colors: { { number } },   -- one or more { r, g, b }: a trail's gradient, a glow's tint, a burst's sparks
	style: string?,           -- a slot-specific look ("rainbow": cycles; "pulse": breathes; burst shapes)
}

-- The slots, in the order the locker shows them. Every slot has a free default that everyone owns.
Catalog.SLOTS = { "trail", "glow", "burst", "title" }
Catalog.SLOT_NAMES = { trail = "Trail", glow = "Glow", burst = "Burn-out", title = "Title" }
Catalog.DEFAULTS = { trail = "trail_none", glow = "glow_none", burst = "burst_ember", title = "title_none" }

Catalog.RARITIES = { "common", "rare", "epic", "legendary" }
Catalog.RARITY_COLORS = { common = { 170, 178, 196 }, rare = { 70, 170, 255 }, epic = { 190, 100, 255 },
	legendary = { 255, 190, 60 } }
-- The wheel's odds per rarity (out of 100), shown to the player beside the wheel (Roblox's policy for random items).
Catalog.ODDS = { common = 55, rare = 30, epic = 12, legendary = 3 }
-- What a duplicate from the wheel pays back, in coins.
Catalog.REFUND = { common = 30, rare = 50, epic = 80, legendary = 150 }

local function item(id: string, slot: string, name: string, rarity: string, price: number?, colors: { { number } },
	style: string?): Item
	return { id = id, slot = slot, name = name, rarity = rarity, price = price, colors = colors, style = style }
end

Catalog.ITEMS = {
	-- Trails: a ribbon behind the runner while it moves.
	item("trail_none", "trail", "No trail", "common", 0, {}),
	item("trail_chalk", "trail", "Chalk", "common", 150, { { 235, 235, 240 }, { 160, 165, 180 } }),
	item("trail_cyan", "trail", "Neon Cyan", "common", 200, { { 60, 230, 255 }, { 20, 90, 255 } }),
	item("trail_lime", "trail", "Acid Lime", "common", 200, { { 190, 255, 60 }, { 40, 200, 90 } }),
	item("trail_magma", "trail", "Magma", "rare", 350, { { 255, 220, 90 }, { 255, 70, 20 } }),
	item("trail_grape", "trail", "Grape Soda", "rare", 350, { { 255, 120, 240 }, { 110, 60, 255 } }),
	item("trail_ghost", "trail", "Ghostlight", "epic", nil, { { 200, 235, 255 }, { 120, 160, 255 } }, "pulse"),
	item("trail_gold", "trail", "Gold Rush", "epic", nil, { { 255, 240, 170 }, { 255, 170, 30 } }, "pulse"),
	item("trail_rainbow", "trail", "Prism", "legendary", nil,
		{ { 255, 70, 70 }, { 255, 220, 60 }, { 70, 255, 120 }, { 70, 170, 255 }, { 200, 90, 255 } }, "rainbow"),
	-- Glows: the outline round the runner (the rim client/Look draws).
	item("glow_none", "glow", "No glow", "common", 0, {}),
	item("glow_ice", "glow", "Frostline", "common", 200, { { 120, 220, 255 } }),
	item("glow_rose", "glow", "Rose", "common", 200, { { 255, 110, 160 } }),
	item("glow_toxic", "glow", "Toxic", "rare", 400, { { 150, 255, 70 } }),
	item("glow_violet", "glow", "Ultraviolet", "rare", 400, { { 170, 90, 255 } }),
	item("glow_sun", "glow", "Solar", "epic", nil, { { 255, 200, 60 } }, "pulse"),
	item("glow_prism", "glow", "Prismatic", "legendary", nil,
		{ { 255, 70, 70 }, { 255, 220, 60 }, { 70, 255, 120 }, { 70, 170, 255 }, { 200, 90, 255 } }, "rainbow"),
	-- Burn-outs: what you leave behind when your fuse runs out (rule 50: the first cosmetic slot).
	item("burst_ember", "burst", "Embers", "common", 0, { { 255, 200, 90 }, { 255, 70, 20 } }),
	item("burst_confetti", "burst", "Confetti", "common", 250,
		{ { 255, 90, 90 }, { 255, 220, 70 }, { 90, 220, 255 }, { 150, 255, 110 } }, "confetti"),
	item("burst_ink", "burst", "Ink Blot", "rare", 400, { { 30, 30, 40 }, { 90, 90, 110 } }, "ink"),
	item("burst_frost", "burst", "Shatter", "rare", 400, { { 220, 245, 255 }, { 90, 190, 255 } }, "shards"),
	item("burst_nova", "burst", "Supernova", "epic", nil, { { 255, 255, 255 }, { 190, 110, 255 } }, "nova"),
	item("burst_gold", "burst", "Jackpot", "legendary", nil, { { 255, 245, 190 }, { 255, 180, 40 } }, "coins"),
	-- Titles: a word under your name on the scoreboard and the podium.
	item("title_none", "title", "No title", "common", 0, {}),
	item("title_rookie", "title", "Rookie", "common", 100, { { 200, 205, 220 } }),
	item("title_slippery", "title", "Slippery", "common", 250, { { 110, 220, 255 } }),
	item("title_hothands", "title", "Hot Hands", "rare", 400, { { 255, 130, 60 } }),
	item("title_untouchable", "title", "Untouchable", "epic", nil, { { 200, 120, 255 } }),
	item("title_fuseproof", "title", "Fuseproof", "legendary", nil, { { 255, 200, 70 } }),
} :: { Item }

Catalog.BY_ID = {} :: { [string]: Item }
for _, it in Catalog.ITEMS do Catalog.BY_ID[it.id] = it end

function Catalog.get(id: any): Item?
	return if type(id) == "string" then Catalog.BY_ID[id] else nil
end

-- Every item of `slot`, in catalogue order.
function Catalog.inSlot(slot: string): { Item }
	local out = {}
	for _, it in Catalog.ITEMS do if it.slot == slot then table.insert(out, it) end end
	return out
end

-- Everything the wheel can land on: every item that is not a free default, by rarity.
function Catalog.pool(rarity: string): { Item }
	local out = {}
	for _, it in Catalog.ITEMS do
		if it.rarity == rarity and it.price ~= 0 then table.insert(out, it) end
	end
	return out
end

return Catalog
