---
title: "Three acts: new mechanics and seven puzzles"
description: "A mirror shrine, a veil and crumbling stone, added as registry rows. Seven levels that each turn on one insight, with a check that the naive approach fails and a check that the solution tolerates sloppy timing."
part: 3
weight: 3
date: 2026-10-17
commits: ["d1844e5", "9591f41", "c31b489", "55a8f02", "10d1344"]
cover: "images/03-puzzles/other-side-mirror.png"
---

Five levels teach the echo. They do not yet ask much of it. The next step grew the game to twelve levels in three acts, and it ran at the same time as the interface pass ([part 4]({{< relref "04-interface" >}})) and the performance pass ([part 5]({{< relref "05-measuring" >}})). Each of the three workstreams had its own git worktree and its own agent, and the branches merged afterwards. The puzzle branch is the merge in `55a8f02`, and `10d1344` then grouped the levels into acts.

## Three tiles, three new verbs

A new puzzle needs a new thing the echo can do. Three tiles each add one:

- **Mirror shrine (violet).** Cast while touching it and the recording is reflected about the shrine before it plays. The ghost walks the mirror image of your path, so it can end up on the far side of a wall you cannot pass.
- **Veil (amber).** You walk through it. An echo whose next pose would enter it halts at the edge and stays there. That is how you park a ghost exactly where you want it.
- **Crumble stone (ochre).** It collapses half a second after any body stands on it and grows back once nothing is inside. An echo replays positions, not physics, so a ghost keeps standing in the air where the stone was.

The registry from [part 1]({{< relref "01-the-pitch" >}}) kept this cheap. Commit `d1844e5` moved each tile's interaction rectangle and the world list it belongs to into the table, so the level parser stopped special-casing plates and spikes. After that, the three new tiles are three new rows:

```lua
  plate = { plate = true, rect = { 1, 12, T - 2, 4 }, worldList = 'plates' },
  door = { solid = true, openable = true },
  mirror = { light = 56, mirror = true, worldList = 'mirrors' },
  veil = { light = 30, veil = true, rect = { 0, 0, T, T }, worldList = 'veils' },
  crumble = { solid = true, crumble = true, worldList = 'crumbles' },
```

The behaviour still needs code, but only a little. The mirror is four lines that reflect every recorded frame about the shrine's centre:

```lua
function Echo.mirror(frames, axis)
  for _, f in ipairs(frames) do
    f.x = 2 * axis - f.x - Echo.W
    f.facing = -f.facing
  end
end
```

The veil is a check in `Echo:update`. Before the ghost advances to its next recorded pose, the world asks whether that pose would be inside a veil. If it would, the echo sets `halted`, slides up to the edge, and starts its 4-second linger there.

## One insight per level

Commit `9591f41` added levels 6 to 12. Its message names the idea each one turns on, and those ideas are the design. Act II introduces one tile per level. Act III combines them.

{{< figure src="images/03-puzzles/other-side-mirror.png" caption="Level 6, Other Side, just after the cast at the shrine. The violet mirrored echo starts in the sealed room on the right and walks toward the plate that opens the door beside the light." >}}

{{< pair >}}
{{< figure src="images/03-puzzles/trapdoor-crumble.png" caption="Level 7, Trapdoor. The crumble stone under the plate has fallen away. The echo still stands on the plate, and the door in the lower corridor is open." >}}
{{< figure src="images/03-puzzles/undertow-veil.png" caption="Level 8, Undertow. The echo halted at the glowing veil. The light climbed it to reach the ledge at the upper left." >}}
{{< /pair >}}

{{< pair >}}
{{< figure src="images/03-puzzles/underfoot-door.png" caption="Level 9, Underfoot. The echo at the left holds the plate for the door set into the floor. The crumble bridge gives way under the light as it crosses." >}}
{{< figure src="images/03-puzzles/short-memory.png" caption="Level 11, Short Memory. The mirrored echo stands on the plates beyond the wall, because the light waited long enough before casting." >}}
{{< /pair >}}

{{< figure src="images/03-puzzles/confluence.png" caption="Level 12, Confluence, just after the second cast at the right-hand shrine. The first mirrored echo, which carried the light over the spikes, has stopped at the veil. The second walks through the wall toward the hidden plate in the alcove, which opens the door between the light and the goal." >}}

Level 10, Ferry, belongs in this list too. It has a post of its own, [part 7]({{< relref "07-ferry" >}}), because it turned out to be much harder for a person than the tests said.

## Proving a puzzle, three ways

A scripted solution proves a level can be beaten. It does not prove the level is a puzzle, and it does not prove a person can beat it. So each new level got three kinds of check in `selftest.lua`.

1. **The solution clears the level.** Same as act I.
2. **A negative check.** The naive approach has to fail. On Ferry a running jump has to land in the spikes. On Underfoot, walking to the hatch without an echo has to leave you standing on a closed door. If a negative check ever passes, the level has a shortcut.
3. **A perturbation check.** The solution is rerun with its timings shifted, so a level cannot depend on frame-perfect play:

```lua
local VARIANTS = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 3, 3 }, { -3, 3 } }
```

The first number shifts every fixed-length wait 3 frames shorter or longer. The second keeps each move going 3 frames past the moment its condition was met. All five variants have to clear the level.

The selftest grew from 40 checks to 139, all passing at `10d1344` when rerun for this post.

The perturbation check sounds like it guarantees human-friendly timing. It does not, and [part 7]({{< relref "07-ferry" >}}) is about the level where that gap showed.

{{< figure src="images/03-puzzles/select-three-acts.png" caption="Level select after `10d1344`, grouped into three acts and fitted into five columns. The times and death counts are seeded test records from the `--shot select` mode, not real play." >}}
