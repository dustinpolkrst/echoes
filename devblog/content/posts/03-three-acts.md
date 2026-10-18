---
title: "Mirrors, veils and crumbling stone"
description: "Three new tiles change what an echo can do, and seven new levels build their puzzles on them."
part: 3
weight: 3
date: 2026-10-17
commits: ["d1844e5", "9591f41", "c31b489", "55a8f02", "10d1344"]
cover: "images/03-puzzles/other-side-mirror.png"
---

Five levels teach the echo without asking much of it. The next round of work covered harder puzzles, a real interface and performance, split into three branches that ran at the same time: the puzzles here, which grew the game to twelve levels in three acts, the interface work in [part 4]({{< relref "04-interface" >}}), and the performance work in [part 5]({{< relref "05-measuring" >}}). Each had its own git worktree and its own agent, and the branches merged afterwards. The puzzles came in with the merge `55a8f02`, and `10d1344` then grouped the levels into acts.

## Three new tiles

New puzzles needed the echo to do something new.

The mirror shrine is violet. Cast while touching it and the recording is reflected about the shrine before it plays, so the ghost walks the mirror image of your path. That can put it on the far side of a wall you can't get past.

The veil is amber. You walk straight through it, but an echo whose next pose would enter it stops at the edge and stays. It's how you park a ghost exactly where you want it.

Crumble stone is ochre. It collapses half a second after anything stands on it and grows back once nothing is inside. An echo replays positions and has no physics, so a ghost keeps standing in the air where the stone was.

The registry from [part 1]({{< relref "01-the-pitch" >}}) kept this cheap. Commit `d1844e5` moved each tile's interaction rectangle, and the world list it belongs to, into the table, so the level parser stopped special-casing plates and spikes. After that the three tiles were three new rows:

```lua
  plate = { plate = true, rect = { 1, 12, T - 2, 4 }, worldList = 'plates' },
  door = { solid = true, openable = true },
  mirror = { light = 56, mirror = true, worldList = 'mirrors' },
  veil = { light = 30, veil = true, rect = { 0, 0, T, T }, worldList = 'veils' },
  crumble = { solid = true, crumble = true, worldList = 'crumbles' },
```

They still needed a little code. The mirror is four lines that reflect every recorded frame about the shrine's centre:

```lua
function Echo.mirror(frames, axis)
  for _, f in ipairs(frames) do
    f.x = 2 * axis - f.x - Echo.W
    f.facing = -f.facing
  end
end
```

The veil is a check in `Echo:update`. Before the ghost moves to its next recorded pose, the world asks whether that pose is inside a veil. If it is, the echo sets `halted`, slides up to the edge, and starts its 4-second linger there.

## Seven levels

Commit `9591f41` added levels 6 to 12. Its message names the idea each level is built on, and those ideas are the design. Act II brings in one tile per level. Act III combines them.

{{< figure src="images/03-puzzles/other-side-mirror.png" caption="Other Side, level 6, just after casting at the shrine. The violet ghost starts in the sealed room on the right and heads for the plate that opens the door by the light." >}}

{{< pair >}}
{{< figure src="images/03-puzzles/trapdoor-crumble.png" caption="Trapdoor. The stone under the plate is gone, but the ghost is still on the plate, so the lower corridor's door is open." >}}
{{< figure src="images/03-puzzles/undertow-veil.png" caption="Undertow, level 8. The ghost stopped at the glowing veil, and the light climbed it to reach the upper-left ledge." >}}
{{< /pair >}}

{{< pair >}}
{{< figure src="images/03-puzzles/underfoot-door.png" caption="Underfoot, level 9. A ghost on the left holds the plate for the door in the floor while the crumble bridge drops out under the light." >}}
{{< figure src="images/03-puzzles/short-memory.png" caption="Short Memory, level 11. The light waited long enough before casting, so the mirrored ghost lands on the plates past the wall." >}}
{{< /pair >}}

{{< figure src="images/03-puzzles/confluence.png" caption="Confluence, right after the second cast at the right-hand shrine. The first mirrored ghost carried the light over the spikes and is parked at the veil. The second walks through the wall to the hidden plate in the alcove, which opens the door between the light and the goal." >}}

Level 10, Ferry, is missing here on purpose. It gets [part 7]({{< relref "07-ferry" >}}) to itself, because it turned out to be much harder for a person than the tests said.

## Checking that a level is a puzzle

A scripted solution shows a level can be beaten. It doesn't show the level is a puzzle, or that a person can beat it. So besides clearing its solution, each new level got two more checks in `selftest.lua`.

First, the naive approach has to fail. On Ferry a running jump has to land in the spikes. On Underfoot, walking to the hatch without an echo has to leave you standing on a closed door. If one of these ever passes, the level has a shortcut.

Second, the solution has to survive sloppy timing. The selftest reruns it with its timings shifted:

```lua
local VARIANTS = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 3, 3 }, { -3, 3 } }
```

The first number makes every fixed-length wait 3 frames shorter or longer. The second keeps each move going 3 frames past the moment its condition was met. All five variants have to clear the level.

The selftest grew from 40 checks to 139. Rerun for this post at `10d1344`, all of them pass.

That timing check was supposed to mean nobody would need frame-perfect play. It didn't, and [part 7]({{< relref "07-ferry" >}}) is about the level that showed it.

{{< figure src="images/03-puzzles/select-three-acts.png" caption="Level select after `10d1344`, in three acts and five columns. The times and deaths are seeded test records from `--shot select`, not real play." >}}
