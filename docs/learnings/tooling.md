# Learnings: T — Tooling

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ T1").

**T1 — The line ceiling in `test/structure.test.js` is a design input, not a lint you notice at the end.** The 400
line ceiling and any allow-list entry may only shrink. "Add it to the big file" is not available: new behaviour goes
in a new module. Check headroom **before** planning where code goes. *(inherited, handoff H1.)*

**T2 — Rojo does NOT sync into a Studio session that is already in Play, and a Studio `require` cache is per
DataModel.** Edits made after Play started are invisible until Play stops and starts again, and an `execute_luau`
call that required a module earlier keeps the OLD copy for the life of that DataModel. Stop Play, start Play, then
test. `execute_luau` also gets its own require cache, so it cannot read the running server's state: build a state of
the right shape and bind the module under test instead. *(inherited, rung 3 part 3.)*

**T3 — A cosmetic label is never worth an error.** Anything that might run before its data exists is looked up in a
`pcall`, and the line is worded the plain way if it fails. *(inherited, rung 3 part 3.)*

**T4 — Comments count against the line ceiling too.** `test/structure.test.js` counts every line. Put long
explanations in the folder README, not in a file near its ceiling. *(inherited, `refactor/ai-friendly`.)*

**T5 — A Studio test harness that moves the player is part of the experiment.** Before blaming the code, move the
harness away and see whether the fault goes with it. *(inherited, handoff H8.)*

**T6 — A running `rojo serve` syncs `.lua` edits, but NOT an instance newly declared in `default.project.json`.**
Seen in Studio: the edited scripts arrived, the new `Remotes.SheetIds` RemoteEvent did not. After any project-file
change, stop `rojo serve`, start it again and reconnect in Studio before Play, then check the instance is there
(`search_game_tree`) before testing. *(2026-10-10, handoff H4, Rojo 7.7.0.)*

**T7 — The Bash tool's heredoc strips one level of backslashes on this PC.** A node script written through a quoted
heredoc lost every backslash: a regex class became a bare letter and an escaped newline became a real one, which broke
`test/luau/run.js` for one run. A long quoted heredoc holding apostrophes and backticks also failed to parse
(2026-10-11, H5). Write any script longer than a few lines with the Write tool, run it from the scratchpad; keep
heredocs for short text with no backslashes. *(2026-10-10, `claude/friendly-hawking-74891i`.)*

**T8 — Studio's local test players have NEGATIVE UserIds (-1, -2, ...).** Any made-up id (a dummy runner, a bot, a
placeholder) must sit outside that range and outside real ids: the Studio dummy is -1000. Never key "is this a real
player" on `UserId > 0`. *(2026-10-11, handoff H5.)*

**T9 — Driving Play through the Studio MCP: keys are slow and the first one can be lost; log on a Heartbeat.** Each
`user_keyboard_input` or `execute_luau` call costs ~1-2 s of round trip, so "press while frozen for 1.5 s" cannot be
timed from outside; a key sent in the first seconds after Play starts was swallowed twice (`IsKeyDown` false), and a
list of `keyPress` steps spread over ~0.5 s each. Start a Heartbeat logger in the client first (`_G` table, one row per
frame), send the whole key script in ONE call, then read the log. To hit a short window, lengthen it in `Config`
for the test and put it back before the tests run. Remove anything solid the harness adds (→ T5): a server-moved part
is a wall to the client's probes unless `CanQuery = false`. *(2026-10-11, handoff H6.)* The match keeps running under a key
script: the Studio dummy's tag freezes you 1.5 s and a round end rebuilds your body at a spot, so read the Output's
TAG and round lines before calling a missing dash or a jump in x a bug. *(2026-10-11, handoff H10.)*

**T10 — The Studio MCP runs one client; it cannot start Test → Clients and Servers.** `start_stop_play` is plain
Play, and setting `TestService.NumberOfPlayers` first still starts one player (put it back to 0). To test what one
client shows of another, have the server build a stand-in with the same tag and attributes as a runner and move it on
a script, log the client's view per frame, and leave the real two-client check to Danzo with a list of what to look
for. *(2026-10-11, handoff H11.)*

**T11 — Pass-through on Roblox is a collision group AND the probes cast as that group.** A ray hits anything with
`CanQuery`, collidable or not, so a group that ignores itself still leaves the other body as a wall and a floor to the
raycast contacts; set `RaycastParams.CollisionGroup` to the caster's group. `CanQuery = false` is only allowed while
`CanCollide` is false, so it is not an option for a body that must hit walls. Prove it with a control: the same block
in `Default` must stop the runner. And with `StreamingEnabled`, anything every client must always see (runner models)
needs `ModelStreamingMode = Persistent`. *(2026-10-11, handoff H11.)*

**T12 — Studio renders an unfocused window at 25% of its frame cap, so a one-PC multi-client test throttles the other
player.** Test → Clients and Servers gives one window focus; the other player's client runs at ~15 fps, its body is sent
in 15 Hz steps and (with the loop's `MAX_DT` clamp) moves slower in game time. The other runner looks choppy and tags
look early, and none of it is the game. Before tuning any netcode on one PC, set `FramerateCap` to 240 in
`%LOCALAPPDATA%\Roblox\GlobalBasicSettings_13_Studio.xml` with Studio closed (the property is RobloxScript-only, so a
script cannot set it): unfocused windows then run at 60 and the choppiness vanished (H13 run 6). Feel still needs two
real devices. *(H13, `docs/systems/netcode.md` §2, 2026-10-14.)*
