---
title: "Waystones and act IV"
description: "A checkpoint tile splits long levels into rooms, and the five levels of act IV are built from rooms that each pass the shortcut search."
part: 10
weight: 10
date: 2026-10-18
commits: ["79ff197", "0d796be", "50b2027", "37c1380"]
cover: "images/10-act-four/waystone-lit.png"
---

Acts IV and V were planned as long levels of two to four rooms each. A death in the last room shouldn't send you back to the first, so the long levels needed a checkpoint before they needed anything else.

## The waystone

Commit `79ff197` adds the waystone, `w` in a map. Touch it and it lights, with a chime, a burst of mint particles and a "waystone lit" label over the player. The waystone touched last is the respawn point, so walking back onto an earlier one moves the respawn back.

{{< figure src="images/10-act-four/waystone-lit.png" caption="Relay, level 13, frame 282 of the scripted solution. The light has just touched the first waystone." >}}

A respawn rebuilds the level from its map and stands the player on the lit waystone. Nothing carries over. There are no echoes and the memory is empty, so the first cast replays only what happened since. Every door is shut unless its plate is pressed, and every crumble stone is whole. The level clock keeps running. Death and <kbd>R</kbd> both do this. The pause menu's Restart level starts over from the beginning with a fresh clock.

{{< pair >}}
{{< figure src="images/10-act-four/relay-before-restart.png" caption="Relay, frame 700. A ghost holds the gate plate and the light has reached the dead-end plate at the far right." >}}
{{< figure src="images/10-act-four/relay-after-restart.png" caption="Then <kbd>R</kbd>. The light stands on the first waystone with both echo slots empty, 0.6 s of memory, and the gate shut. The clock went on from 0:11.7." >}}
{{< /pair >}}

The respawn is an option of the world constructor, so the game and the tests build a room the same way:

```lua
-- opts.checkpoint = k starts the player on the k-th checkpoint (map order) with everything else fresh: no echoes,
-- an empty memory, doors shut, crumble stone intact. That is the whole respawn model, so a room is solvable from
-- its checkpoint exactly when it is solvable with nothing carried in.
function M.new(def, opts)
```

That last sentence is why everything resets. If a respawn kept your echoes, whether a room could be solved would depend on what you did before you got there. With a full reset, a room is solvable from its waystone exactly when the selftest can solve it from a fresh `Level.new(def, { checkpoint = k })`.

## A level declares its rooms

Commit `0d796be` turned that into a contract. A level's solution file can declare its rooms. Each room says where it starts, which tiles count as its exit, the one insight it asks for, a solve, and the naive approaches that must fail:

```lua
{
  name = 'Loop',
  insight = 'a ghost cast on arrival opens the door three seconds later, which is when you get back',
  from = 1,
  exit = { 58, 10, 59, 12 },
  solve = { ... },
  naive = { ... },
},
```

The selftest plays every solve from a fresh respawn at `from` and every naive from the same spot. A level with a waystone also owes a strategy for `--slack` and a room for its start and for each waystone. A level that's missing any of them fails the build, so a waystone in a spot that needs a ghost from the room before it can't ship.

## Five levels

Commit `50b2027` adds act IV, levels 13 to 17. Each combines two mechanics from the first three acts.

**Relay** is about when a door opens. A ghost cast as you arrive at a plate opens its door 3 seconds later. In the second room you cast standing on the gate plate, which holds the gate for 7 seconds. Then you run to a dead-end plate, cast there on arrival, and come back through the gate to a hatch that the second ghost opens as you get there. The third room repeats the loop on the lower floor with the exit far from the gate, so the far ghost's 7 seconds also has to cover the walk out.

**Plumb Line** is about where a falling ghost stops. Its memory begins 3 seconds back, and it falls until the first veil below that point. In The Well you wait on a ledge between two veil strips, drop, and cast, so the ghost begins on the ledge and stops on the pad below it.

{{< figure src="images/10-act-four/plumb-line-well.png" caption="The Well, frame 410. The cast came after the light waited on the ledge between the strips, so the ghost begins there. When it drops, the lower strip stops it on the pad, and the door beside the light opens at frame 444." >}}

**Undercroft** is about crumble under a reflection. A reflected ghost breaks stone where you can't stand, at your own height, and the hole stays open for 3 seconds.

{{< figure src="images/10-act-four/undercroft-reflection.png" caption="Undercroft, frame 300. The reflection walked across the gallery's crumble floor, and the light is in the crawlspace under the hole it left." >}}

**Crawlspace** runs sideways under low roofs. A walking ghost stops at a veil and stands where it stops, so in the first room you run over the plate into a pocket, cast, and the ghost walks back until the veil parks it on the plate.

{{< figure src="images/10-act-four/crawlspace-parked.png" caption="Crawlspace, frame 265. The ghost stopped at the veil column and stands on the plate in the crumble bed. The light took the one-way ledge back over the bed and is dropping to the next room." >}}

**Ferryman's Toll** takes level 10's ferry three times. In the second room the far dock is a plate over a veil, so the ferry that carries you also holds the door open when it stops. In the third the dock is in the middle of the pit, under a hatch in the ceiling.

{{< pair >}}
{{< figure src="images/10-act-four/toll-gate.png" caption="Toll Gate, frame 960. The ferry stopped at the veil on the dock plate, and the door past it is open." >}}
{{< figure src="images/10-act-four/toll-hatch.png" caption="Hatch, frame 1500. The ferry docked mid-pit and opened the hatch above it, and the light jumped up through it." >}}
{{< /pair >}}

## What the spec got wrong

The doc had specified all five levels before any was built. Three of its claims turned out false in the simulation, and each was confirmed with a headless probe before the level changed.

- **A walking ghost breaks crumble like a standing one.** A crumble cell starts its half-second crack on the first frame any body touches it. Undercroft was specified around the idea that a ghost standing still has weight and a walking one doesn't. That idea doesn't exist in the game, so the level was rebuilt on what crumble actually does.
- **Veils park ghosts but can't stack them.** A ghost stopped under a veil strip 4 tiles up is a step 64 px up, and no 50.8 px jump reaches it. A second rung would need a ghost whose memory begins above the first, which takes 2.7 seconds of standing on a ghost that lives 4. Crawlspace's veil ladder can't be built, so its veils work sideways.
- **A standing cast right after a respawn is shorter.** It holds its plate for the length of the memory plus 4 seconds, not 7. Relay's "stand on the gate plate" means a full 3 seconds on it.

## The red team

After the build, a separate pass went looking for exploits, and it changed two levels.

In Plumb Line's second room, Twin Well, mashing X won. In the rebuilt room the corridor ends at a hole whose fall mirrors to a spot 16 px clear of the pad, so the natural way down fails, and mashing at the shrine after it is a naive the selftest proves fails. The Well still falls to a masher, one cast 122 to 168 frames after landing. That one stays, because it's the teach room and the winning ghost is the intended one.

In Crawlspace, stepping onto a plate and straight back pressed it for up to 18 frames. Three seconds later the replayed step opened the door for a player holding into it, and Short Memory Lane fell to one cast anywhere in a 50-frame window. Each door now stands behind a three-tile crumble bridge, which takes 32 frames to cross from standing. A player waiting at the door for the replayed press falls.

## Plumb Line, turned on its side

Plumb Line was first built as one tall shaft, 71 tiles high. The camera shows eight rows above and below the player, so from a waystone in that shaft you could never see the pad the room is about. That breaks R3, which says the insight has to be visible from the waystone. The rebuild lays the three rooms side by side in a 75 by 17 map, joined by two-wide chimneys of one-way ledges. Each room is one screen tall and in view from its waystone. A retry from the waystone takes 7.5 to 7.7 seconds with the strategy's usual waits.

## The numbers

Rerun for this post at `37c1380`, `--cheese` finds no shallow strategy that reaches the exit of any act IV room:

| Level | Rooms | Runs | Slack minimum (doc) |
| --- | --- | --- | --- |
| 13 Relay | 3 | 5100 | 84 frames |
| 14 Plumb Line | 3 | 6720 | 117 frames |
| 15 Undercroft | 3 | 6060 | 138 frames |
| 16 Crawlspace | 3 | 4620 | 60 frames |
| 17 Ferryman's Toll | 3 | 7080 | 24 px |

The slack minimum is the narrowest decision in each level's strategy, from `docs/level-design.md`. Ferryman's Toll also has the tap that steps onto the ferry at 7 frames, with a declared need of 6, as on level 10, because the ghost is only 10 px wide.
