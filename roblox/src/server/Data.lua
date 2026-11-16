-- Saved profiles (H31, trigger 9; docs/systems/session.md §5): one DataStore entry per player, shaped by
-- shared/Profile (coins, xp, owned and worn cosmetics). The server owns every profile; a client is only ever sent its
-- own view (server/Shop). Rules that keep a save from ever being lost or forged:
--   * a profile that FAILED to load is played on a fresh one in memory and NEVER saved (`saved = false`): a DataStore
--     outage must not overwrite real progress with a new purse;
--   * whatever was stored goes through Profile.sanitize, so a catalogue change or a bad entry never breaks a join;
--   * one server at a time (QA round 1): a load takes a LOCK (this server's id and the time) and a load that finds
--     another server's fresh lock waits for that server's leave-save instead of reading under it; every save carries
--     a revision and is refused when the store holds a newer one or another server's lock, so a stale copy can
--     never overwrite a newer save. A server that loses that race stops saving the profile and says so;
--   * saves happen on leave (releasing the lock), every AUTOSAVE seconds, and when the server closes.
-- In Studio without "Enable Studio Access to API Services" every call fails: the game plays on, nothing is saved,
-- one warning says so.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Profile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Profile"))

local Data = {}

local STORE = "RotagProfiles_v1"
local AUTOSAVE = 120
local TRIES = 3
local LOCK_TTL = 300 -- seconds another server's lock is honoured (it is refreshed every AUTOSAVE; a crashed server's dies)
local LOCK_WAIT, LOCK_TRIES = 3, 6 -- a load under a fresh foreign lock waits this long, this many times (15 s: a
-- leave-save lands in a second or two; longer than this the other server is gone), then takes it
local LOCKED = "locked" -- what a load attempt returns when it backed off

local SESSION = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false) -- Studio has no JobId

local store: DataStore? = nil
local profiles: { [number]: Profile.Profile } = {}
local saved: { [number]: boolean } = {} -- false: this session's profile is never written
local revs: { [number]: number } = {} -- the revision each profile was loaded at or last saved as
local waiting: { [number]: { (Profile.Profile) -> () } } = {}
local released: { [Profile.Profile]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- its lock was given up
local warned = false

local function key(id: number): string return "p_" .. tostring(id) end

local function call(what: string, fn: () -> any): (boolean, any)
	local ok, res
	for try = 1, TRIES do
		ok, res = pcall(fn)
		if ok then return true, res end
		if try < TRIES then task.wait(0.5 * try) end
	end
	if not warned then
		warned = true
		warn(("[Rotag] data: %s failed (%s). Playing on without saving for the players it failed for.%s"):format(what,
			tostring(res), if RunService:IsStudio() then " In Studio: Game Settings > Security > Enable Studio Access to API Services." else ""))
	end
	return false, res
end

-- The player's profile once it has loaded, or nil.
function Data.get(player: Player): Profile.Profile?
	return profiles[player.UserId]
end

-- Will this player's progress be saved? (false: the load failed, or another server holds the newer save; the
-- wallet says so.)
function Data.saves(player: Player): boolean
	return saved[player.UserId] == true
end

-- Change the profile (the only way anything writes one): `fn` mutates it. No-op until it has loaded.
function Data.update(player: Player, fn: (Profile.Profile) -> ())
	local p = profiles[player.UserId]
	if p then fn(p) end
end

-- Run `fn` with the profile as soon as it has loaded (at once if it has).
function Data.whenLoaded(player: Player, fn: (Profile.Profile) -> ())
	local p = profiles[player.UserId]
	if p then fn(p) return end
	local list = waiting[player.UserId] or {}
	waiting[player.UserId] = list
	table.insert(list, fn)
end

-- One read that also takes the lock. Returns the stored value, or LOCKED when another server's fresh lock is on it
-- and `mayWait` (the transform cancels: nothing is written).
local function take(s: DataStore, id: number, mayWait: boolean): any
	local got: any = nil
	s:UpdateAsync(key(id), function(old: any)
		got = old
		if mayWait and type(old) == "table" and type(old.lockId) == "string" and old.lockId ~= SESSION
			and type(old.lockAt) == "number" and os.time() - old.lockAt < LOCK_TTL then
			got = LOCKED
			return nil
		end
		local new = if type(old) == "table" then old else {}
		new.lockId, new.lockAt = SESSION, os.time()
		return new
	end)
	return got
end

local function load(player: Player)
	local id = player.UserId
	local ok, raw = false, nil
	local s = store
	if s then
		for try = 1, LOCK_TRIES do
			ok, raw = call("load", function() return take(s, id, try < LOCK_TRIES) end)
			if not ok or raw ~= LOCKED then break end
			task.wait(LOCK_WAIT) -- the server the player just left is still saving: read after it, not under it
		end
	end
	if not player.Parent then return end -- left while loading
	local p = Profile.sanitize(if ok then raw else nil)
	profiles[id], saved[id] = p, ok
	revs[id] = if ok and type(raw) == "table" and type(raw.rev) == "number" then raw.rev else 0
	Profile.daily(p, os.time() // 86400)
	print(("[Rotag] data: %s loaded (%s): %d coins, level %d"):format(player.Name, if ok then "saved"
		else "NOT saved this session", p.coins, Profile.level(p)))
	local list = waiting[id]
	waiting[id] = nil
	for _, fn in list or {} do task.spawn(fn, p) end
end

-- Write the profile if this server still holds the newest copy. `release`: the player is leaving, drop the lock.
local function save(id: number, release: boolean)
	local p, s = profiles[id], store
	if not (p and s and saved[id]) or released[p] then return end
	if release then released[p] = true end -- once: the close and the leave both ask (QA round 2: the second was
	-- refused by the first's own write and logged as "another server")
	local rev = revs[id] or 0
	local out: any = table.clone(p)
	local stale = false
	local ok = call("save", function()
		stale = false
		s:UpdateAsync(key(id), function(old: any)
			if type(old) == "table" and ((type(old.rev) == "number" and old.rev > rev)
				or (type(old.lockId) == "string" and old.lockId ~= SESSION)) then
				stale = true -- a newer save, or another server has taken the profile over: never write over it
				return nil
			end
			out.rev = rev + 1
			out.lockId, out.lockAt = if release then nil else SESSION, if release then nil else os.time()
			return out
		end)
		return true
	end)
	if stale then
		saved[id] = false
		warn(("[Rotag] data: %d's profile is newer in the store (another server saved it): this session stops saving it"):format(id))
	elseif ok then
		revs[id] = rev + 1
	end
end

function Data.start()
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	if ok then store = s else warn("[Rotag] data: no DataStore (" .. tostring(s) .. "); nothing is saved") end
	Players.PlayerAdded:Connect(function(player) task.spawn(load, player) end)
	for _, player in Players:GetPlayers() do task.spawn(load, player) end
	Players.PlayerRemoving:Connect(function(player)
		local id = player.UserId
		local p = profiles[id]
		save(id, true)
		-- QA round 2: the save yields; a player who rejoined this server meanwhile has a NEW profile here: keep it
		if profiles[id] == p then profiles[id], saved[id], revs[id], waiting[id] = nil, nil, nil, nil end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for id in profiles do task.spawn(save, id, false) end -- also refreshes this server's lock
		end
	end)
	game:BindToClose(function()
		for id in profiles do task.spawn(save, id, true) end
		task.wait(if RunService:IsStudio() then 0.5 else 3)
	end)
end

return Data
