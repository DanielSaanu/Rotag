--!strict
-- The match (H31; DESIGN §6.4, §3 rules 31-34; docs/systems/session.md): lobby -> MATCH_ROUNDS rounds, each followed
-- by a results gap -> podium -> lobby. Pure Luau over plain tables, every clock passed in. The SERVER owns the one
-- state (server/Session.lua) and is the only caller that changes it; clients only read the view it sends.
-- A round is still shared/Tag's; this file only decides WHEN one may start, WHO is in it (people first, bots fill
-- the empty seats, rule 31) and what a finished round is worth (rule 33). Tests: test/luau/session.test.luau.
local Config = require(script.Parent.Config)

local Session = {}

export type Score = { pts: number, wins: number, rounds: number }
export type State = {
	phase: string,              -- "lobby" | "round" | "gap" | "podium"
	until_: number,             -- when the lobby, gap or podium ends; math.huge in an idle lobby and during a round
	match: number,              -- +1 per match started
	round: number,              -- 1..MATCH_ROUNDS inside a match, 0 in the lobby
	scores: { [number]: Score },
	seen: { number },           -- every id that scored this match, in first-seen order (a stable tie-break)
	roster: { number },         -- who plays the current (or last) round
	out: { number },            -- this round's eliminations, first out first
	last: { number },           -- the last finished round's placing, winner first
	lastPts: { number },        -- ... and what each of those places scored (the results card shows the server's numbers)
	winner: number?,            -- the match winner, set at the podium
	waited: { [number]: number }, -- rounds each person has sat out with a full roster (the queue's priority)
}

function Session.new(): State
	return { phase = "lobby", until_ = math.huge, match = 0, round = 0, scores = {}, seen = {}, roster = {}, out = {},
		last = {}, lastPts = {}, winner = nil, waited = {} }
end

-- A bot's runner id for seat `k` (1-based) and its name. Ids -1000, -1001, ... as the Studio dummies had (tag.md §4).
Session.BOT_ID = -1000
function Session.botId(k: number): number return Session.BOT_ID - (k - 1) end
function Session.isBot(id: number): boolean return id <= Session.BOT_ID end
-- A bot's name (H32: a bot is not marked as one anywhere, bots.md §7): made from two word lists and a number in the
-- styles players use, from the seat and the server's `seed`, so every screen agrees and no two seats share one. No
-- real account is looked up: a name can coincide with one only by chance.
local NAME_A = { "Shadow", "Turbo", "Nova", "Blaze", "Frost", "Zippy", "Mango", "Cosmo", "Rocket", "Ninja", "Lucky", "Echo",
	"Glitch", "Storm", "Comet", "Pixel", "Sonic", "Fizzy", "Mellow", "Hyper", "Sneaky", "Wavy", "Chill", "Rapid" }
local NAME_B = { "Fox", "Wolf", "Kid", "Cat", "Panda", "Racer", "Runner", "Gamer", "Star", "Bean", "King", "Dino", "Tiger",
	"Frog", "Ace", "Dude", "Legend", "Noodle", "Wizard", "Otter" }
function Session.botName(id: number, seed: number?): string
	local k = Session.BOT_ID - id -- the seat, 0-based
	local h = (math.floor(seed or 0) * 7919 + 104729) % 2147483647
	local a = NAME_A[(h + k * 7) % #NAME_A + 1] -- 7 and 3 share no factor with the lists' lengths: seats never collide
	local b = NAME_B[(h // 31 + k * 3) % #NAME_B + 1]
	local num = (h // 13 + k * 37) % 90 + 10
	local style = (h // 977 + k) % 5
	if style == 0 then return a .. b end
	if style == 1 then return a .. b .. tostring(num) end
	if style == 2 then return string.lower(a) .. "_" .. string.lower(b) end
	if style == 3 then return a .. "_" .. b .. tostring(num % 10) end
	return string.lower(a .. b) .. tostring(num)
end

-- What place `place` (1 = the winner) is worth in a round of `n` runners: one point per runner you outlasted, and
-- one more for the win (4 runners: 4, 2, 1, 0). A round alone is worth nothing.
function Session.points(place: number, n: number): number
	if n < 2 then return 0 end
	return math.max(0, n - place) + (if place == 1 then 1 else 0)
end

-- Who plays the next round: up to PLAYERS_PER_MATCH of `people` (ids in join order), the longest-waiting first, then
-- bots for the empty seats when `bots` is true. Updates the queue: whoever is left out has waited one more round.
function Session.pick(s: State, people: { number }, bots: boolean): { number }
	local seats = Config.PLAYERS_PER_MATCH
	local queue = table.clone(people)
	local at: { [number]: number } = {}
	for i, id in people do at[id] = i end
	table.sort(queue, function(a, b)
		local wa, wb = s.waited[a] or 0, s.waited[b] or 0
		if wa ~= wb then return wa > wb end
		return at[a] < at[b]
	end)
	local roster, playing = {}, {}
	for i, id in queue do
		if i <= seats then
			playing[id] = true
			s.waited[id] = nil
		else
			s.waited[id] = (s.waited[id] or 0) + 1
		end
	end
	for _, id in people do if playing[id] then table.insert(roster, id) end end -- join order: the rotation (rule 5)
	if bots and #roster > 0 then
		for k = 1, seats - #roster do table.insert(roster, Session.botId(k)) end
	end
	return roster
end

local function score(s: State, id: number): Score
	local sc = s.scores[id]
	if not sc then
		sc = { pts = 0, wins = 0, rounds = 0 }
		s.scores[id] = sc
		table.insert(s.seen, id)
	end
	return sc
end

-- Every id that has scored this match, best first: points, then round wins, then who was seen first.
function Session.standings(s: State): { number }
	local ids = table.clone(s.seen)
	local at: { [number]: number } = {}
	for i, id in s.seen do at[id] = i end
	table.sort(ids, function(a, b)
		local x, y = s.scores[a], s.scores[b]
		if x.pts ~= y.pts then return x.pts > y.pts end
		if x.wins ~= y.wins then return x.wins > y.wins end
		return at[a] < at[b]
	end)
	return ids
end

-- Advance the flow. `people` is how many people are in (pressed Play and have a body). Returns what just happened:
-- "start" (start a round with Session.pick), "abort" (everybody left mid-match: back to an idle lobby), "podium"
-- (the match is over, s.winner is set: pay the rewards), "lobby" (the podium is done) or nil.
function Session.tick(s: State, now: number, people: number): string?
	if s.phase == "lobby" then
		if people == 0 then
			s.until_ = math.huge
		elseif s.until_ == math.huge then
			s.until_ = now + Config.LOBBY_TIME
		elseif now >= s.until_ then
			s.phase, s.until_, s.match, s.round = "round", math.huge, s.match + 1, 1
			s.scores, s.seen, s.last, s.lastPts, s.winner = {}, {}, {}, {}, nil
			return "start"
		end
		return nil
	end
	if people == 0 and s.phase ~= "podium" then
		s.phase, s.until_, s.round = "lobby", math.huge, 0
		return "abort"
	end
	if s.phase == "gap" and now >= s.until_ then
		if s.round < Config.MATCH_ROUNDS then
			s.phase, s.until_, s.round = "round", math.huge, s.round + 1
			return "start"
		end
		s.phase, s.until_ = "podium", now + Config.PODIUM_TIME
		s.winner = Session.standings(s)[1]
		return "podium"
	elseif s.phase == "podium" and now >= s.until_ then
		s.phase, s.round = "lobby", 0
		s.until_ = if people > 0 then now + Config.LOBBY_TIME else math.huge
		return "lobby"
	end
	return nil
end

-- A round begins with `roster` (from Session.pick).
function Session.begin(s: State, roster: { number })
	s.roster, s.out = table.clone(roster), {}
end

-- Every frame of a round: note who has dropped out of `alive` since the last look, in order (a burn-out, a wall
-- kill and a leave all land here: the server's round is the only source).
function Session.note(s: State, alive: { [number]: boolean })
	for _, id in s.roster do
		if not alive[id] and not table.find(s.out, id) then table.insert(s.out, id) end
	end
end

-- The round is over. The placing is the survivor(s) first (the winner, if any), then the eliminated, last out first.
-- Everyone in the roster scores Session.points for their place. Opens the results gap. Returns the placing.
function Session.finish(s: State, winner: number?, now: number): { number }
	local placing = {}
	if winner and table.find(s.roster, winner) and not table.find(s.out, winner) then table.insert(placing, winner) end
	for _, id in s.roster do
		if id ~= winner and not table.find(s.out, id) then table.insert(placing, id) end -- alive but not the winner
	end
	for i = #s.out, 1, -1 do table.insert(placing, s.out[i]) end
	local n = #placing
	local gains = {}
	for place, id in placing do
		local sc = score(s, id)
		sc.rounds += 1
		local won = place == 1 and winner == id -- no winner (everybody else left): nobody takes the win or its bonus
		local gained = if won then Session.points(1, n) elseif n >= 2 then math.max(0, n - place) else 0
		sc.pts += gained
		table.insert(gains, gained)
		if won then sc.wins += 1 end
	end
	s.last, s.lastPts = placing, gains
	s.phase, s.until_ = "gap", now + Config.ROUND_GAP
	return placing
end

-- What a finished match pays `id` (DESIGN §6.5): coins for playing, per point, and for the win. 0 if it never played.
function Session.reward(s: State, id: number): number
	local sc = s.scores[id]
	if not sc or sc.rounds == 0 then return 0 end
	return Config.COINS_MATCH + Config.COINS_POINT * sc.pts + (if s.winner == id then Config.COINS_WIN else 0)
end

-- What every client is sent (Remotes.Session): arrays only (→ N13), durations not timestamps.
function Session.view(s: State, now: number): any
	local rows = {}
	for _, id in Session.standings(s) do
		local sc = s.scores[id]
		table.insert(rows, { id = id, pts = sc.pts, wins = sc.wins })
	end
	return {
		phase = s.phase, left = if s.until_ == math.huge then -1 else math.max(0, s.until_ - now),
		match = s.match, round = s.round, rounds = Config.MATCH_ROUNDS, scores = rows, roster = s.roster,
		last = s.last, lastPts = s.lastPts, winner = s.winner,
	}
end

return Session
