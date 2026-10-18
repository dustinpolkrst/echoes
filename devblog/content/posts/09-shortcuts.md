---
title: "Searching the levels for shortcuts"
description: "A search that plays every shallow strategy against a level found shortcuts in three shipped levels, and each shortcut became a test that has to fail."
part: 9
weight: 9
date: 2026-10-18
commits: ["0d796be", "ea2d3dc", "d3180c1", "f61491b", "ae96d2c"]
cover: "images/09-shortcuts/other-side-before.png"
---

Acts IV and V were next. Before any new level got drawn, the rules for drawing one got written down in `docs/level-design.md`, in commit `ea2d3dc`. Writing them meant measuring what a player can actually do. Measuring that turned up three shipped levels a player could finish without understanding them.

## The numbers first

Every number in the doc came from the headless simulation, not from a guess. These are the ones the rest of this post leans on:

- A full jump rises 50.8 px and keeps you in the air for 37 frames. That clears a wall 3 tiles high and never one 4 tiles high.
- A running jump travels 60 px, plus up to 10 px of coyote time. A 3-tile gap is jumpable, a 4-tile gap needs an echo, and 5 tiles or more stops every shallow strategy.
- With echoes, a wall of 4 to 7 tiles falls to one cast, and 8 or 9 tiles falls to a ladder of two casts. 10 tiles or more is clean.
- An echo running across a plate presses it for about 14 frames, a quarter of a second. That's enough to open a door the player is already pressed against.

The last one matters most. A ghost doesn't have to stand on a plate to open its door. It only has to cross it at the right moment.

## Eight rules

The doc then sets eight rules, R1 to R8, that every new level follows:

1. One insight per room, and one room per screen.
2. Rooms chain as teach, test and twist. The first room shows the idea cheaply, the second takes away the weaker method, and the third changes one parameter.
3. The insight is discoverable from the room's waystone, before the first death. The key tiles are in sight, one tile in each room tells you what goes there, and the hint names the rule, never the solution.
4. Red herrings fail for a reason the player can see.
5. Hardness comes from reasoning about time, space or resources, never from execution. Every decision a player makes gets at least 30 frames or 24 px of slack.
6. Difficulty rises within a level and across acts.
7. Failure is cheap. A full retry of the twist room takes under 15 seconds.
8. Shortcuts are detected, not hoped against.

The last rule needed a tool.

## --cheese

Commit `0d796be` added `love game --cheese N`. It isn't a solver. It plays the moves a player tries before understanding anything, which are running, jumping and pressing X somewhere, and it reports any that reach the end of a room. There are four families of these shallow strategies:

- Autoruns, and single jumps swept along the way.
- One cast, swept along the natural path by frame, or by height up a jump.
- A ladder of two mid-air casts.
- Stacks of one or two standing echoes, used as a step.

Rerun for this post at `37c1380`, it plays 1180 of these on Other Side in 1.7 s, and 2760 per room on the four-room finale, 11,040 in all, in 21.2 s. To check the search itself, the selftest plants walls in a test corridor. A 5-tile wall has to be caught by the single cast and a 9-tile wall by the ladder, and a 10-tile wall has to come back clean.

## Three levels fell to it

Run against the first twelve levels, the tutorials hit as expected, because their solutions are meant to be shallow. Ferry and Confluence came back clean. Three levels that were supposed to be puzzles didn't. Rerun for this post at `d4f6eca`, the last commit before the fixes, level 6 shows the problem in one line:

```
level 6 "Other Side": 1 rooms, 533 runs in 0.7 s
  CHEESE room 1 "whole level": one cast on the natural path: autorun R hold 12, cast at frame 74, wait 0 reaches the goal at frame 116
```

The search prints up to four hits per family, and level 6 filled all four. Each one is the same move. Hold right, press X once, and the level is over in under two seconds.

### Other Side

Level 6 asks you to find where the plate's reflection lies. It lay on the floor between the start and the shrine. Running to the door and casting at the shrine replayed that run in mirror image, so the ghost crossed the plate on the other side of the wall for 14 frames. The door opened in front of the player, who never had to look for the reflection.

{{< pair >}}
{{< figure src="images/09-shortcuts/other-side-before.png" caption="At `d4f6eca`, run right and cast once at the shrine. 21 frames after the cast, the violet ghost crosses the plate behind the wall and the door beside the light is open." >}}
{{< figure src="images/09-shortcuts/other-side-after.png" caption="The same keys at `d3180c1`, 21 frames after the cast. The plate now sits on a ledge at the right, the reflection stays on the floor, and the door is shut." >}}
{{< /pair >}}

The fix, `d3180c1`, puts the plate on a ledge in the sealed room and a matching ledge on the player's side. A body on the floor passes under the plate's reflection, and a jump past the ledge hits it. Only standing on the ledge presses the plate.

{{< figure src="images/09-shortcuts/other-side-ledge.png" caption="The intended solve at `37c1380`, frame 288. The light stood on its own ledge before casting, so the reflection is up on the sealed room's ledge by the plate, and the door is open." >}}

### Underfoot

Level 9's door is a hatch in the floor. A ghost replays a crossing of the plate exactly 3 seconds after it happened, and the hatch was 2.5 seconds of running from the plate. So you could run across the plate, stand on the hatch and cast. The replayed run opened the hatch under you, with no ghost ever left on the plate.

Commit `f61491b` puts the plate on a pedestal behind the start, off the run, and moves the hatch 4 seconds of running away across crumble bridges. Now the replayed crossing comes while you're still on the bridge, 45 frames too early. Only a ghost left standing on the plate holds the hatch open long enough.

{{< figure src="images/09-shortcuts/underfoot-pedestal.png" caption="Underfoot at `37c1380`, frame 260. The ghost stands on the plate on the pedestal behind the start, and the light heads right toward the crumble bridges." >}}

### Short Memory

At `d4f6eca` the search found one cast, at frame 230 of a plain run to the right. The doc reads it as the move a player who mashes X at the door would find. That ghost's memory began while the player ran across the block, its first frames ran over the three-plate pad, and the plate next to the veil let a ghost frozen in the veil stand on it. That left a 24-frame window that needed no insight.

Commit `ae96d2c` shrinks the pad to one plate, two tiles clear of the veil. Past the door, the way on is now a hatch in a one-tile shaft that takes 28 frames to reach from the door. A running ghost holds the plate for 14 frames, or 18 counting the frames the player holds the door open themselves. The spot where the player has to stand is one plate wide, 22 px, and the level declares that it needs 20.

{{< figure src="images/09-shortcuts/short-memory-hatch.png" caption="Short Memory at `df9c112`, frame 295. The ghost holds the single plate on its block, two tiles from the veil, and the light is past the door on its way down the shaft." >}}

## Each shortcut became a test

Finding a shortcut once isn't enough, because the next map edit can bring it back. So each fixed level now declares its rooms, and each room lists its naive approaches next to its solve. Here is level 6's list from `game/dev/solutions/act2.lua`, with the scripts left out:

```lua
naive = {
  { 'run to the door and cast at the shrine every half second', ... },
  { 'run under the ledge to the wall and back, then cast at the shrine every half second', ... },
  { 'stand three seconds under the ledge, then cast at the shrine', ... },
  { 'stand three seconds on the ledge and cast there', ... },
},
```

The selftest plays each naive and fails if any of them reaches the exit. Underfoot has three naives and Short Memory has five, including mashing X every 2, 10 and 30 frames. Rerun for this post at `37c1380`, the selftest has 125 naive checks among its 369, and all of them pass.

`--cheese` agrees. At `37c1380` it plays 1180 runs on Other Side, 1400 on Underfoot and 1180 on Short Memory, and finds no shallow strategy that reaches the goal in any of them.

A clean result means none of the four families works. It doesn't mean no shortcut exists, so R8 also has builders walk a catalogue of known shortcuts by hand. Every new room in acts IV and V had to pass both.
