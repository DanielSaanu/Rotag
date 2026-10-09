# The box

Design principles that are **not about Lowlands**. Things that turn out to be true about a kind of game, worth
keeping past this project and carrying into the next one. Lowlands-specific decisions live in `docs/DESIGN.md`;
this file is portable, so copy it into whatever comes after.

One rule for what gets in: it has to be a principle a builder can *apply* at the moment of a decision, not a
description of a game someone liked. If it does not tell you what to do when you are standing at the fork, it is
a note, and notes go in `ideas/INBOX.md`.

*Copied verbatim from The Warehouse on 2026-10-09, as the file itself asks. The principles below came from an open-world
project; add Rotag's own (movement feel, tag fairness, short sessions) as new numbered sections, never by editing these.*

---

## 1. The main story is the compass, not the spine

*(Danzo, 2026-09-18, from a video about Palworld. For open-world games generally.)*

**A player should be able to get from the start of the game to the end of it by only ever doing the things that
interest them. The main story exists for the moments when nothing does.**

That is the whole principle. It sounds small and it changes the shape of everything.

### The two ways open worlds fail

Both failures come from the same mistake — treating the main quest as a load-bearing wall instead of a signpost.

- **The corridor with a field around it.** The main quest is the real game; everything else is "side content".
  The world is huge and none of it counts. The player feels the pull of the spine the entire time they are
  wandering, and wandering starts to feel like procrastinating. The punishment for exploring is irrelevance.
- **The formless sandbox.** No main quest at all, just systems, on the theory that freedom is enough. It is not.
  A new player opens it, finds no reason to walk in any particular direction, does something arbitrary, dies,
  and leaves. Every playtest of an unguided open world produces the same sentence: *"it's kind of boring, I
  don't know what to do."* Freedom with no first step is not freedom, it is a blank page.

The compass version is neither. The story is always there, one glance away, and it never expires, never blocks,
and never makes the wanderer feel like they were doing it wrong.

### What it has to satisfy to actually be a compass

1. **The story never gates a system.** Anything you can do at the end, you can attempt at the start. The world
   answers with consequences, not with locks. A locked door that the main quest is the only key to has turned
   the story back into a spine.
2. **It never expires and never scolds.** Ignore it for twenty hours and it is waiting, caught up to what you
   actually did in the meantime. No step ever says "you were supposed to do this first."
3. **It points, it does not choreograph.** A step names a place and a reason to go there. It does not script the
   middle. How you get there, who you kill or befriend on the way, and what you do instead when you arrive is
   the game.
4. **Every destination it leads to has at least two roads.** If the story is the only way to reach the throne,
   the guild, the ending — it is the spine again, wearing a hat. Whatever it leads to must also be reachable by
   a player who never opened it, by playing.
5. **The world can complete a step without being asked.** If the step was "make peace with the hunters" and you
   already did that three hours ago for your own reasons, it is done, and the game says so. **A step completed
   by accident is the strongest proof the story is guidance** — it means the story was describing the world
   rather than driving it.
6. **It is answered by a character, not a log.** The compass wants a face: someone you ask "what now" and who
   answers in terms of what they know and where you stand with them. A quest log is a menu that tells you the
   truth from nowhere; a person is the same information, in the world, and can be wrong, biased or dead.

### The one-sentence version of success

Danzo, playing it: *"somehow they made a quest system that works for both the people that need direction while
at the exact same time being completely invisible to the people that don't."* That is the bar. Not "optional
content" — **invisible**. A player who does not need it should be able to finish without ever once feeling they
are declining something.

The half people skip is what makes the invisibility possible: **the world has to supply its own reasons to keep
going.** He never needed the quest because every new area handed him one — a creature he had not seen, a boss, a
material, a dungeon, or honestly just a different-looking place. That is the actual work. A compass only reads as
invisible in a world where the next reason is always already visible from where you are standing; drop that and
the compass stops being a fallback and quietly becomes the content again, because it is the only thing pointing
anywhere.

So the practical order is: **build the reasons first, the compass second.** A compass in an empty world is a
to-do list.

### The test

Two players finish the game. One followed the story from start to end; the other never once looked at it and
just chased what caught their eye. **Both finished, and neither felt they had played the lesser version.** If the
story-follower had the better time, the world is under-built. If the wanderer had the better time, the story is
wasted work. If the wanderer never finished at all, there was no compass.

A second, sharper test: **the fastest route through the game should not be the most fun one.** When it is, the
story has quietly become the spine, because now optimising and enjoying point the same way and wandering is
strictly a cost.

### The two moments it actually exists for

Everything above is in service of two specific minutes, and it is worth naming them because they are the only
times a compass gets read:

- **The first minute.** Someone who does not yet know what kind of game this is needs one direction, in the
  world, from a character, within about thirty seconds. Not a tutorial: a destination.
- **The lost minute, at hour twenty.** A player who has just finished a thing — sold the haul, won the fight,
  built the hut — and is standing still. This is where open worlds lose people, and it is nearly always
  invisible in testing because it never happens in a thirty-minute playtest.

Build the compass for those two and it will be right everywhere else. Build it for the middle and it becomes a
spine.

---

## 2. Hand them systems, not content

*(Danzo, 2026-09-18, same conversation, and he was clear this is the big one.)*

**"It hands you systems and asks you what you want to do with it."** Systems related to systems — so many of
them, interlocking, that nobody can tell you which one you are supposed to be using. That is the whole thing.

### Why it is the big one

Content is consumed at the rate you can make it. Systems are generated by the player at the rate they can think.
A game made of content is a treadmill its own developers are losing; a game made of systems is still surprising
people who have put two hundred hours in, and they are still finding things nobody has scratched.

The mistake is that both feel like "adding depth" while you are doing it. Ten more quests and ten more items
feel productive. They are **linear** — ten more things, each of which is used once and then is over. The other
kind is **multiplicative**, and the multiplication is the entire point.

### Where the multiplication actually comes from

Not from having many systems. From **one entity being legible to many systems at once**.

Danzo's example, unpacked: a Pal is not a monster. It has combat abilities, *and* passive traits, *and* work
suitability at your base, *and* a partner skill, *and* it breeds. So one new creature is not +1 content — it is
a new value in five orthogonal axes at once, and it multiplies against every creature already in the game. Some
craft, gather, farm, breed and automate; some exist for a combat build most players will never see. Nobody
authored those combinations. They fell out.

That gives the rules:

1. **Judge a new thing by how many existing systems it touches, not by what it adds.** A creature that only
   fights is content. A creature that fights, works, breeds and carries is a system. Same art budget.
2. **If a thing has exactly one use, it is a consumable, not a system.** Fine to have some. Not fine for the
   things the game is *about*.
3. **Never hand-author the combinations.** Authored combos are content wearing a system's clothes, and they run
   out. Combinations must fall out of orthogonal axes that were designed separately.
4. **The value lives in the edges, not the nodes.** A crafting system, a combat system and a farming system that
   never touch each other are three small games in a trenchcoat. Before adding a fourth system, ask what it
   plugs into. If the answer is nothing, it is a minigame.
5. **Let them be wrong.** A player who bolts together a stupid combination should get a stupid result, not a
   refusal. (Principle 1's sibling, and pillar 5 in `docs/DESIGN.md`: the world says yes, the consequences say
   no.) Every validation you add deletes combinations you did not think of, which are the good ones.
6. **You must not be able to answer "what should I be doing".** If there is a correct system, the others are
   decoration. Many valid answers is the target; one is a failure; genuinely infinite is the formless sandbox
   from principle 1 and needs a compass on top.

### The test

Describe your game's depth **without listing content**. If the only way to say why it is deep is to count
things — how many weapons, how many quests, how many biomes — it is not deep, it is large.

Second test: two players with forty hours each should be able to **surprise each other**. Not "I found an area
you didn't" — that is content. "I did not know you could do that" is the systems one.

### The cost, so nobody chases this off a cliff

Systems touching systems is quadratic in engineering and in CPU, and every new axis has to be reasoned about
against every existing one. Two consequences worth holding on to:

- **The entity that composes should be a record, not a sprite.** Composition happens in the simulation, cheaply,
  whether or not anyone is looking. Only render what is near.
- **Add axes slowly and orthogonally.** Three axes that are genuinely independent beat eight that are secretly
  the same axis renamed. The eight cost eight times as much and multiply like one.
