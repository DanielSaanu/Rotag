-- The client's view of the match flow, its own profile and everyone's cosmetics (H31, docs/systems/session.md).
-- It DECIDES nothing: it holds the last Remotes.Session, Remotes.Profile and Remotes.Looks payloads, and sends the
-- player's own requests (Remotes.Menu: "play" / "sit"; Remotes.Shop: an op and an item id). The server judges each.
-- Like every server -> client event (→ N3): nothing waits for one, only the shape is trusted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local SessionRules = require(Shared:WaitForChild("Session"))

local Flow = {}

local WAIT = 10
local me = 0
local session: any = nil -- the server's last Session view, plus `at` = os.clock() on arrival
local profile: any = nil -- the server's last Profile view of the local player
local looks: { [number]: { [string]: Catalog.Item } } = {} -- runner id -> slot -> the item worn
local menuRemote: RemoteEvent? = nil
local shopRemote: RemoteEvent? = nil
local wantPlay = false -- pressed Play before the remote was there
local sessionFns: { (any, any) -> () } = {}
local profileFns: { (any) -> () } = {}
local looksFns: { () -> () } = {}

function Flow.session(): any return session end
function Flow.profile(): any return profile end
function Flow.onSession(fn: (any, any) -> ()) table.insert(sessionFns, fn) end -- fn(new, old)
function Flow.onProfile(fn: (any) -> ()) table.insert(profileFns, fn) end
function Flow.onLooks(fn: () -> ()) table.insert(looksFns, fn) end

-- "lobby" | "round" | "gap" | "podium", and the seconds left in a counted phase (nil: not counting).
function Flow.phase(): string return if session then session.phase else "lobby" end
function Flow.left(): number?
	if not session or session.left < 0 then return nil end
	return math.max(0, session.left - (os.clock() - session.at))
end

-- Has the server put the local player in (a body, a seat in the next round)?
function Flow.playing(): boolean
	return session ~= nil and table.find(session.playing, me) ~= nil
end

function Flow.play()
	wantPlay = true
	if menuRemote then menuRemote:FireServer("play") end
end

function Flow.sit()
	wantPlay = false
	if menuRemote then menuRemote:FireServer("sit") end
end

-- H37: any door's request (Remotes.Menu, one string: server/Doors lists them).
function Flow.op(op: string)
	if menuRemote then menuRemote:FireServer(op) end
end

-- "buy" | "equip" | "spin", and the item id for the first two.
function Flow.shop(op: string, id: string?)
	if shopRemote then shopRemote:FireServer(op, id) end
end

-- What runner `id` wears in `slot` (nil: nothing known, or the slot's empty default).
function Flow.worn(id: number, slot: string): Catalog.Item?
	local l = looks[id]
	local it = l and l[slot]
	return if it and #it.colors > 0 then it else nil
end

-- A runner's name for a LIST (the scoreboard, the cards): with Config.BOT_LABEL a bot's is marked "AI".
function Flow.listName(id: number?): string
	local name = Flow.nameOf(id)
	return if Config.BOT_LABEL and id and SessionRules.isBot(id) then name .. "  [AI]" else name
end

-- A runner's name: a person's display name, a bot's given one.
function Flow.nameOf(id: number?): string
	if id == nil then return "nobody" end
	if id == -900 then return "TARGET" end -- H41: the tutorial's runner (shared/Tutorial.BOT_ID)
	if SessionRules.isBot(id) then return SessionRules.botName(id, if session then tonumber(session.seed) else nil) end
	local p = game:GetService("Players"):GetPlayerByUserId(id)
	return if p then p.DisplayName else "runner"
end

local function onSession(v: any)
	if type(v) ~= "table" or type(v.phase) ~= "string" or type(v.left) ~= "number" or type(v.playing) ~= "table"
		or type(v.scores) ~= "table" or type(v.roster) ~= "table" or type(v.last) ~= "table" then return end
	local old = session
	v.at = os.clock()
	session = v
	for _, fn in sessionFns do task.spawn(fn, v, old) end
end

local function onProfile(v: any)
	if type(v) ~= "table" or type(v.coins) ~= "number" or type(v.owned) ~= "table" or type(v.worn) ~= "table" then return end
	profile = v
	for _, fn in profileFns do task.spawn(fn, v) end
end

local function onLooks(rows: any)
	if type(rows) ~= "table" then return end
	local next_: { [number]: { [string]: Catalog.Item } } = {}
	for _, row in rows do
		if type(row) == "table" and type(row.id) == "number" and type(row.worn) == "table" then
			local l = {}
			for _, id in row.worn do
				local it = Catalog.get(id)
				if it then l[it.slot] = it end
			end
			next_[row.id] = l
		end
	end
	looks = next_
	for _, fn in looksFns do task.spawn(fn) end
end

function Flow.start(player: Player)
	me = player.UserId
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		local function event(name: string): RemoteEvent?
			local r = remotes and remotes:WaitForChild(name, WAIT)
			if r and r:IsA("RemoteEvent") then return r end
			warn(("[Rotag] no Remotes.%s (restart rojo serve); the menu and the match flow need it"):format(name))
			return nil
		end
		local s, p, l = event("Session"), event("Profile"), event("Looks")
		if s then s.OnClientEvent:Connect(onSession) end
		if p then p.OnClientEvent:Connect(onProfile) end
		if l then l.OnClientEvent:Connect(onLooks) end
		menuRemote, shopRemote = event("Menu"), event("Shop")
		if wantPlay and menuRemote then menuRemote:FireServer("play") end
		if shopRemote then shopRemote:FireServer("get") end -- our profile, in case its first send beat this listener
	end)
end

return Flow
