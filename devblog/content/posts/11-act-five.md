---
title: "Act V and Let Go"
description: "Five levels finish the game, and Let Go replaced a planned level whose key timing window measured 12 frames."
part: 11
weight: 11
date: 2026-10-18
commits: ["50dfb13", "a3c2812", "37c1380"]
cover: "images/11-act-five/last-light-ferry.png"
---

Act V is levels 18 to 22. Commit `50dfb13` adds all five. The rules ask each act V level to combine three earlier ideas and add a time budget or the cap of two echoes. The spec in `docs/level-design.md` planned five levels too, but one of them was never built, and two more changed shape once the simulation measured them.

## Five levels

**Clockwork** is about sharing one memory. Two ghosts can be cast from the same 3 seconds, and one ghost can press two plates in turn. In the first room you cast standing on plate a, run to plate b, and cast again as you arrive.

{{< figure src="images/11-act-five/clockwork-overlap.png" caption="Clockwork, frame 300. The light cast standing on plate a, ran to plate b, and cast again on arrival 17 frames ago. Both echo slots are in use." >}}

**Hall of Mirrors** is about where a reflection stands. It stands where you stood, even if that spot is over spikes on the other side of the shrine, and two shrines reflect one stand twice. Both of its rooms use plates two cells wide, because that gives the stand a 40 px window instead of 24.

{{< figure src="images/11-act-five/hall-of-mirrors-air.png" caption="Hall of Mirrors, frame 300. The light stood on the far shrine before casting at the near one, so the reflection stands on the floating plate in the sealed pocket, over the spikes. The light is on the pocket's roof, crossing the crumble." >}}

**Three Steps Behind** is about the quarter-second press. A running ghost presses each plate for about 14 frames, 3 seconds after you did, and if you paused on a plate the ghost holds it for as long as the pause. The first room is the one place in act V where `--cheese` hits, and every hit is the intended move.

**Let Go** replaced the spec's Scaffold. The next section is about why.

**The Last Light** is the finale, four rooms across 101 tiles. It brings back the ferry with a toll gate, both of Hall of Mirrors' rooms, and a last room where one memory makes two ghosts. One holds a door, and the other is the ferry.

{{< figure src="images/11-act-five/last-light-ferry.png" caption="The Last Light, frame 430. A ghost holds plate a for the gate in the tunnel, and the light has just cast from the pedestal. The reflection waits one tile past it, as it does on Ferry." >}}

## Ideas that died in the simulation

The spec for act V had three ideas the simulation disproved.

**A reflection of a ride is a ride.** The plan for Hall of Mirrors was to reflect a ferry so it carried you somewhere new. A mirrored ghost replays its memory in time order, so the ride part runs from the far mirror point back toward the shrine. Its last pose is always within a tile of the shrine, because you had to touch the shrine to cast. Level 10's ferry only goes outward because the walk away is recorded before the walk back. Hall of Mirrors kept two rooms instead of three.

**Clockwork's cap trick.** The third room was going to force sharing with the echo cap, where a third cast drops the oldest ghost. Measured, the cap never forces anything there. A ghost that presses a and then b holds a only during its first second, so by the time a third cast could drop it, its door is already behind you. The built room forces sharing with a third plate that needs a standing ghost at the end.

**Scaffold.** This level was going to climb a wall on a staircase of ghosts. You jump, cast low enough to land on the step it leaves, stand on that step, and cast the next one from its back. The doc had estimated a window of about 60 frames for each of those casts. It measured 12. Step k+1 arrives 3 seconds after its cast, step k fades 4 seconds after it arrived, and a player needs about half a second to land and 0.3 seconds to be airborne again. A wider window is possible right after a respawn, when the short memory makes the first replay arrive early. That gives two rungs, and two rungs is the two-cast ladder that `--cheese` already counts as a shortcut. No room could pass both R5, the slack rule, and R8, the shortcut rule, so Scaffold wasn't built.

## Let Go

Three ideas were probed for the empty slot before one was built:

1. The echo cap as a tool. A third cast removes the oldest ghost, so a cast can shut a door. This one was picked.
2. The fresh memory after a respawn as a delay you can tune. Rejected, because the intended move is the single swept cast that `--cheese` already plays.
3. A rider dropped on a shelf by a replayed jump. Rejected by arithmetic. The rider's feet top out at 62.8 px against a 64 px shelf, and the window was about 24 frames.

The idea behind Let Go is that sometimes you want a ghost gone. Door A in each room is two things at once. It's a one-tile gate standing on crumble over spikes, and past one more crumble tile, a floor five tiles long over more spikes. While a ghost holds plate a, the gate is open and so is the floor. To cross, you need the gate open as you step into it and the floor shut after. You stand in the doorway, where your own body keeps the gate open, and cast until the third ghost takes the one on a with it. The stone under the doorway cracks, so you can't wait there for the ghost to fade instead.

{{< figure src="images/11-act-five/let-go-doorway.png" caption="Let Go, frame 360. Two casts from inside the doorway, at frames 353 and 356, made a third ghost, and the ghost on plate a went with it. Door A is shut, so the five-tile floor ahead is solid, though this frame doesn't draw it. That's the bug in part 12." >}}

The three rooms follow teach, test and twist. In **Let Go** you cast once on a and twice in the doorway. In **Oldest First** a second plate, b, holds the exit door, and the cast in the doorway takes the oldest ghost. So the cast on a has to come before the one on b, or the kill takes the keeper. In **Borrowed Time** the two casts in the doorway replay a pause on plate c three seconds later. That pause has to last between 0.7 and 2.8 seconds.

The selftest proves nine naive approaches fail in the first room alone, among them no ghost, one cast in the doorway, waiting in the doorway for the fade, mashing, and jumping the open floor. Its slack minimum is 42 px. One weak spot stays open. A blind route that waits at the gate's edge for the ghost on a to fade and then walks straight through has a 24-frame window in every room, under the 30-frame bar. Rooms 2 and 3 also keep their gate and exit door 21 and 23 tiles from the waystone, past the first screen, though the plates that carry each room's idea are on it.

## What building act V taught

The doc ends act V with lessons for whoever builds the next level:

- A crumble bridge two or more tiles long in front of a door stops the quarter-second press. A player who waits at the door for it falls.
- The memory after a respawn is empty. A naive approach that relies on an early ghost has to be proven to fail from a fresh respawn too.
- Plates sit one tile clear of crumble and shrines, because stopping on a plate overshoots it by 5 px.
- Two-cell plates widen a reflected stand's window from 24 px to 40.
- Landing a jump on a single ghost is a 20 px window, which fails R5. Board ghosts by stepping off ledges, the way the ferry does.

## 22 levels

{{< figure src="images/11-act-five/select-five-acts.png" caption="Level select at `37c1380`, five acts, with 21 levels cleared and The Last Light up next. Long names like Ferryman's Toll and Three Steps Behind wrap above the time, from `a3c2812`. The records are seeded test data." >}}

Rerun for this post at `37c1380`:

- `--selftest` reports 369 checks with 0 failed. That includes every room's solve and naives, and a slack check that every strategy's decisions have at least 30 frames or 24 px.
- `--flow` reports 37 checks with 0 failed, including death, <kbd>R</kbd> and Restart level through the real scenes.
- `--cheese` finds no shallow strategy in any room of levels 18, 19, 21 and 22, nor in rooms 2 and 3 of Three Steps Behind. Its only hits are in that level's first room, where they're the intended move.

Commit `a3c2812` was the last change to the game itself. Level names wider than a card now wrap in the small font, and the scroll area no longer shows an act header under the footer. Commit `37c1380` records acts IV and V as built in the level design doc.
