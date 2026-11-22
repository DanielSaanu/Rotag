# Danzo's two-device tag test (about 10 minutes)

The one check the playtest fixes are still waiting on (goal 1 is capped until it's done, `playtest-fixes-summary.md`).
Do **A** in Studio when the PC is free (no other games running: a 2-client test uses a lot of memory). Do **B** on the
published game with a friend whenever you can. A is enough to lift the cap; B is the real thing.

## A. Studio, two clients (5 minutes)

1. Open Rotag in Studio. Check that the Rojo plugin says Connected (port 34872).
2. Turn on simulated 4G: in the **Device Simulator** toolbar (Test tab → Device), click the network pill
   (LAN / Wifi / 4G / 3G), choose **Standard Mobile (4G/LTE)** and click **Apply** (in 45 ms / out 55 ms, plus jitter and
   loss). Or ask the PC session to apply it for you (it sets the same `settings().Network` values H40 used). The
   setting persists across Studio restarts, so turn it off afterwards (step 8).
3. **Test tab → Clients and Servers → 2 players → Start.** Three windows open: Server, Player1, Player2.
4. In each player window, open the lobby and stand in **PRACTICE**, or in **HOST A ROOM** / **ENTER A CODE** so both of
   you are in one match. Drop the bots if the room lets you.
5. Play **3 minutes as IT**, switching between the two windows:
   - Run straight into the other runner, standing still.
   - Run into them while they run away.
   - Dash **into** them, and dash **past** them while they dash away. Both should tag now.
   - Let them dash **at or through** you while you're IT. That one should NOT tag (your rule).
   - Once, right after a tag, stand still next to the new IT. Do you get tagged straight back after the 1.5 s freeze?
6. Each time you think "that was a touch and it didn't count", say the time out loud or jot it down.
7. **Copy the Output** from the tagger's window and from the Server window: every line with `tag: close pass` or
   `dropped` in it. Paste it into the chat (either session) as is.
8. **Test tab → Stop.** Set the network pill back to **Current Device** (off), or ask the PC session to clear it.

## B. The published game, with a friend (5 minutes, optional but best)

1. Publish first (you choose when; nothing has been published since 18 Nov).
2. You both join, take one room with a code, play two rounds, and take turns as IT.
3. Afterwards, tell either session three things: (1) did a touch ever not count? (2) as IT, could you catch them, and
   roughly how long did it take? (3) was being tagged ever unfair?

## What we do with it

The close-pass lines say, for every near miss, how far apart the two boxes were **on your screen** and whether a
claim was sent. "No claim" means the reach is still short; "claim dropped" means the server refused it (lag or
rewind). Either way, the next change is decided from real numbers, not guesses.
