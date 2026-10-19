# Learnings: N — Networking and fairness

Part of [`docs/learnings.md`](../learnings.md) (the hub and the rules for what earns a line). Cite rules by ID (e.g. "→ N1").

**N1 — A mode that must never touch real data is gated where the store is OPENED, and read once at boot.** Returning
early from one load path is not enough; a later code path that calls the store directly would still reach the real
data. Default the mode to the side that cannot lose data, and force it off outside Studio. *(inherited, handoff H4,
Lowlands' `DevMode`.)*

**N2 — Movement and tags are checked by the server against the same pure rules the client predicts with.** Lowlands
put the step rule in `shared/Movement.lua` and ran it on both sides: the client predicts, the server validates, and
the client sets `Predicted*` attributes next to the server's authoritative ones so a Studio pass can compare them.
DESIGN §3 rule 6 asks for exactly this on tags: client overlap, server confirm, catch-up animation. *(inherited.)*

**N3 — A server → client fact never blocks the client, and its remote never listens on the server.** Draw with the
built-in default, apply the value when it lands and redraw anything already built; warn once if it never comes. The
client checks the payload's shape and format, not its sender. The server wires `OnServerEvent` to a no-op, and finds
the remote with `FindFirstChild` and a warning, never a bare `WaitForChild` that hangs the whole boot when the
remote is missing. *(2026-10-10, handoff H4, `Remotes.SheetIds`.)*

**N4 — A client → server remote carries only the name of the request, and the server decides from its own state.**
The sender is the `Player` Roblox passes, never a payload field; the payload is the smallest thing that names the
request (`TagClaim` is one number) and anything of the wrong type is dropped unread. Rate-limit per player on the
server and drop silently; the client limits itself just above that, so an honest client never hits it. Who may ask,
when, and whether it is true are all read from server state; a refusal gets no reply. *(2026-10-11, handoff H5.)*

**N5 — A lag-fair check rewinds over the server's OWN recent history, caps the look-back, and is no stronger than the
trust in the positions.** Record every body on the same server frames, pair samples only from the same frame, look back
by the claimant's ping plus interpolation but never past a fixed cap (else lagging buys reach). And write down where
the positions come from: bodies with client network ownership report their own positions, so the real fix for a
teleporting cheat is a server movement check, not a tighter tag check. *(2026-10-11, handoff H5, `Tag.confirm`.)*
**Corrected by H6 (same day):** "pair samples only from the same frame" was wrong for client claims, see N6. Same-frame
pairing is right only when neither side's samples arrive late (the server checking its own dummy).

**N6 — Measure the replication delays before writing a lag-fair check, and design for the claim arriving FIRST.**
Measured in Studio (one process, `os.clock` shared by client and server): a client-owned body reaches the server's
`Position` ~0.18 s after the client moved it, while a RemoteEvent fired at the same moment arrives almost at once; a
server-anchored part reaches the client within a frame. So "touching on the tagger's screen" is never one server frame
of both bodies: the server must (a) keep the claim open a short wait for the claimant's own late samples, and (b) pair
each claimant sample with the target's samples up to a capped allowance OLDER (never newer). A runner trailing a
target at a touch never touches it in any single server frame. Log the closest approach on every drop, so the next
mismatch is a number, not a guess. *(2026-10-11, handoff H6, `Tag.touchedBetween`, `Tag.claimWindow`.)*

**N7 — A number the player is shown travels in the event; the client never rebuilds it from `Config`. And every
path that can end a phase sets that phase's follow-on timers.** The pass pop printed `+FUSE_PASS_BONUS` while the cap
had cut the real gain to +0.9; and a round ended by a leave restarted at once because only the `tick` path set
`nextRoundAt`. Have the pure rule RETURN what happened (`Tag.pass` -> `fuse, gained`) and send that; after every call
that may set `over`, check it and schedule the gap, not just after the usual one. *(2026-10-11, handoff H7.)*

**N8 — The server never moves a body the client owns by writing its CFrame; it rebuilds it, or asks the owner.** A
server write on a client-owned part held while the runner stood still, and lost to the owner within 0.2 s while it ran:
the server's history read the new spot, then the old track again, and the client never moved. A test on an idle
body proves nothing: test the move while the body is moving. To place a runner, build a new part at the spot BEFORE
`SetNetworkOwner` (the spawn path), or have the owner's client move itself. *(2026-10-11, handoff H8, `Match.place`.)*

**N9 — Another player's look comes from the same replicated stream as its position, not from a faster remote.** A
RemoteEvent lands ~0.18 s before the body it describes (N6), so a relayed pose would show a jump before the body rises.
Derive the pose from the replicated position on each screen (pure, tested against a real `Movement` run), and expect
that stream to land in STEPS (held 2-3 frames, then jumping): hold an unchanged frame over to the next move instead of
reading it as a stop, and treat a step faster than any move as a teleport. *(2026-10-11, handoff H11, `RemotePose`.)*

**N10 — Check a client-owned body's speed as a distance budget over time, never per step, and measure what the server's
copy does to a teleport.** The server's copy is interpolated: after a stop it catches up at ~2x dash speed for a few
frames, and it smooths a client teleport into ~0.2 s of fast steps, so a per-step limit flags honest players and
"the sample before the violation" is already most of the way through a teleport. Budget each axis (refill at the
fastest legal speed from the move rules' own caps, up to a measured slack, spend the distance moved), snap back to the
last sample with every budget FULL, and pin in a test the size of teleport that still passes. Any new faster move
raises the rates in the same change. *(2026-10-12, handoff H12, `shared/MoveCheck`.)*

**N11 — Never assume a client keeps the network ownership you gave it: re-assert it every frame, and count the hand-backs.**
Solo Play never showed it, but with two real clients (Studio, server + 2 clients) each player's body stopped following
its owner. The server's copy sat at the round-start spot, every other screen drew it there, and no claim could land.
A check once a second fixed the stuck bodies but not the tags: ownership kept lapsing between checks. Checking every
frame (`GetNetworkOwner`, then `SetNetworkOwner` back and a rate-limited warning with a count) made tags land. Why the
engine drops it is still unknown, so keep the count in the log and read it after any multi-client run. Any check that
judges a client-owned body's position (speed, tag) is only as good as that ownership. *(2026-10-14, handoff H13,
`server/MoveGuard`.)*

**N12 — Never carry a script-driven body's motion on Roblox's physics replication: send your own snapshots over an
`UnreliableRemoteEvent` and draw a short, fixed delay behind.** The engine's replication smooths incoming motion on the
assumption that physics produced it; a body teleported by CFrame every frame arrives ~0.18 s late at the server and
~0.4 s late on another screen, and no drawing-side trick recovers that (H13 tried a fixed trail, then an adaptive one:
"still choppy", "a second" of input delay). The known recipe (every custom-character game on the forum, Gaffer's
snapshot interpolation): the owner sends position + velocity + pose + the one-shot events at a fixed 20-30 Hz, the
server stamps on arrival (never a client clock), bounds it with the same speed budget it had, relays, and receivers
interpolate between the two snapshots around now minus 2-3 intervals; hold at the newest, never extrapolate. Keep the
physics body for collisions and the server's copy. *(handoff H14, `docs/systems/netcode.md`, 2026-10-14.)*

**N13 — A dictionary with number keys arrives through a remote with STRING keys: `tonumber` them on receipt, or send an
array.** (H14, 2026-10-14, `claude/friendly-hawking-74891i`.) The snapshot relay `{ [runnerId] = {...} }` reached every
client at 53 batches/s and was dropped whole: `type(id) == "number"` failed because `-2` had become `"-2"`. Studio showed
it in one probe (`typeof(k)` on the received batch); the symptom was only "has no stream". Shape-check what ARRIVES, not
what you sent.
