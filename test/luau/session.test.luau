-- The match flow (H31, docs/systems/session.md): shared/Session. Lobby -> rounds -> podium -> lobby, who plays, what a
-- round is worth, what a match pays.
local Config = __require("Config")
local Session = __require("Session")

local A, B, C, D, E = 101, 202, 303, 404, 505

do -- an idle lobby never starts; the first person in starts the countdown; nobody left stops it
	local s = Session.new()
	assert(Session.tick(s, 0, 0) == nil and s.until_ == math.huge, "nobody in: the lobby idles")
	assert(Session.tick(s, 100, 0) == nil and s.phase == "lobby", "... however long")
	assert(Session.tick(s, 100, 1) == nil and s.until_ == 100 + Config.LOBBY_TIME, "the first Play starts the countdown")
	assert(Session.tick(s, 105, 0) == nil and s.until_ == math.huge, "everybody sat out again: it stops")
	assert(Session.tick(s, 110, 2) == nil and s.until_ == 110 + Config.LOBBY_TIME, "and restarts in full")
	assert(Session.tick(s, 110 + Config.LOBBY_TIME - 0.01, 2) == nil, "not before the countdown ends")
	assert(Session.tick(s, 110 + Config.LOBBY_TIME, 2) == "start" and s.phase == "round" and s.round == 1 and s.match == 1,
		"then round 1 of match 1")
end

do -- the roster: people in join order, bots fill the empty seats, never bots alone
	local s = Session.new()
	local r = Session.pick(s, { A, B }, true)
	assert(#r == Config.PLAYERS_PER_MATCH and r[1] == A and r[2] == B, "two people, then bots to four")
	assert(Session.isBot(r[3]) and Session.isBot(r[4]) and r[3] ~= r[4], "two different bots")
	assert(not Session.isBot(A) and not Session.isBot(-1) and not Session.isBot(-2), "Studio's test players are people")
	assert(#Session.pick(s, { A, B }, false) == 2, "bots off: only the people")
	assert(#Session.pick(s, {}, true) == 0, "nobody in: no bots alone")
	assert(type(Session.botName(r[3])) == "string" and Session.botName(r[3]) ~= Session.botName(r[4]), "bots have names")
end

do -- more people than seats: four play, the fifth waits and is first in next round (rotation by waiting)
	local s = Session.new()
	local r1 = Session.pick(s, { A, B, C, D, E }, true)
	assert(#r1 == 4 and not table.find(r1, E), "the last to join waits first")
	local r2 = Session.pick(s, { A, B, C, D, E }, true)
	assert(table.find(r2, E) ~= nil and #r2 == 4, "then is in")
	local sat = nil
	for _, id in { A, B, C, D } do if not table.find(r2, id) then sat = id end end
	assert(sat ~= nil, "one of the first four waits instead")
	local r3 = Session.pick(s, { A, B, C, D, E }, true)
	assert(table.find(r3, sat) ~= nil, "nobody waits twice running")
	for _, r in { r1, r2, r3 } do
		for _, id in r do assert(not Session.isBot(id), "a full room has no bots") end
	end
end

do -- points: one per runner outlasted, one more for the win
	assert(Session.points(1, 4) == 4 and Session.points(2, 4) == 2 and Session.points(3, 4) == 1
		and Session.points(4, 4) == 0, "4, 2, 1, 0")
	assert(Session.points(1, 2) == 2 and Session.points(2, 2) == 0, "a duel: 2, 0")
	assert(Session.points(1, 1) == 0, "alone: nothing")
end

do -- a whole match: three rounds, the placing from the elimination order, the podium, the rewards, the lobby again
	local s = Session.new()
	local now = 0
	Session.tick(s, now, 2)
	now = Config.LOBBY_TIME
	assert(Session.tick(s, now, 2) == "start", "round 1")
	local roster = Session.pick(s, { A, B }, true)
	local X, Y = roster[3], roster[4]
	for round = 1, Config.MATCH_ROUNDS do
		Session.begin(s, roster)
		local alive = { [A] = true, [B] = true, [X] = true, [Y] = true }
		Session.note(s, alive)
		assert(#s.out == 0, "nobody out yet")
		alive[Y] = false
		Session.note(s, alive) -- Y first out
		alive[B] = false
		Session.note(s, alive)
		Session.note(s, alive) -- noting twice changes nothing
		alive[X] = false
		Session.note(s, alive)
		assert(s.out[1] == Y and s.out[2] == B and s.out[3] == X and #s.out == 3, "the order they went out")
		local placing = Session.finish(s, A, now)
		assert(placing[1] == A and placing[2] == X and placing[3] == B and placing[4] == Y, "winner, then last out first")
		assert(#s.lastPts == 4 and s.lastPts[1] == 4 and s.lastPts[2] == 2 and s.lastPts[3] == 1 and s.lastPts[4] == 0,
			"what each place scored, for the results card")
		assert(Session.view(s, now).lastPts[1] == 4, "... and it rides the view")
		assert(s.phase == "gap" and s.until_ == now + Config.ROUND_GAP, "the results gap")
		assert(Session.tick(s, now + Config.ROUND_GAP - 0.01, 2) == nil, "the gap holds")
		now += Config.ROUND_GAP
		local what = Session.tick(s, now, 2)
		if round < Config.MATCH_ROUNDS then
			assert(what == "start" and s.round == round + 1, "the next round")
		else
			assert(what == "podium" and s.winner == A, "after the last round: the podium, A won")
		end
	end
	local n = Config.MATCH_ROUNDS
	assert(s.scores[A].pts == 4 * n and s.scores[A].wins == n, "A: 4 a round")
	assert(s.scores[X].pts == 2 * n and s.scores[B].pts == n and s.scores[Y].pts == 0, "2, 1, 0 a round")
	local st = Session.standings(s)
	assert(st[1] == A and st[2] == X and st[3] == B and st[4] == Y, "standings by points")
	assert(Session.reward(s, A) == Config.COINS_MATCH + Config.COINS_POINT * 4 * n + Config.COINS_WIN, "the winner's coins")
	assert(Session.reward(s, B) == Config.COINS_MATCH + Config.COINS_POINT * n, "a loser still earns")
	assert(Session.reward(s, E) == 0, "someone who never played earns nothing")
	local v = Session.view(s, now)
	assert(v.phase == "podium" and v.winner == A and #v.scores == 4 and v.scores[1].id == A
		and v.left == Config.PODIUM_TIME, "the view: arrays, durations")
	now += Config.PODIUM_TIME
	assert(Session.tick(s, now, 2) == "lobby" and s.phase == "lobby" and s.until_ == now + Config.LOBBY_TIME,
		"the podium ends in a counting lobby when people are still in")
	now += Config.LOBBY_TIME
	assert(Session.tick(s, now, 2) == "start" and s.match == 2 and s.round == 1 and next(s.scores) == nil,
		"match 2 starts from nothing")
end

do -- a tie on points goes to round wins, then to whoever was seen first
	local s = Session.new()
	Session.tick(s, 0, 2)
	Session.tick(s, Config.LOBBY_TIME, 2)
	Session.begin(s, { A, B, C })
	Session.note(s, { [A] = true, [B] = false, [C] = true })
	Session.note(s, { [A] = true, [B] = false, [C] = false })
	Session.finish(s, A, 0) -- A 3, C 1, B 0
	Session.begin(s, { A, B, C })
	Session.note(s, { [A] = false, [B] = true, [C] = true })
	Session.note(s, { [A] = false, [B] = true, [C] = false })
	Session.finish(s, B, 0) -- B 3, C 1, A 0: A 3 (1 win), B 3 (1 win), C 2
	local st = Session.standings(s)
	assert(st[1] == A and st[2] == B and st[3] == C, "equal points and wins: first seen first")
end

do -- everybody leaves mid-match: the round has no winner, nobody takes the win bonus; then the flow aborts
	local s = Session.new()
	Session.tick(s, 0, 1)
	Session.tick(s, Config.LOBBY_TIME, 1)
	Session.begin(s, { A, B })
	Session.note(s, { [A] = false, [B] = true })
	Session.note(s, { [A] = false, [B] = false })
	Session.finish(s, nil, 5)
	assert(s.scores[A].wins == 0 and s.scores[B].wins == 0, "no winner: no win")
	assert(s.scores[B].pts == 1 and s.scores[A].pts == 0, "the later leaver outlasted one, no bonus")
	assert(s.lastPts[1] == 1 and s.lastPts[2] == 0, "the card shows 1 and 0, not the rule's 2 and 0 (QA round 1)")
	assert(Session.tick(s, 6, 0) == "abort" and s.phase == "lobby" and s.until_ == math.huge, "nobody left: an idle lobby")
end

print("    session ok")
