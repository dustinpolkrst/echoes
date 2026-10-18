---
title: "Measuring before optimizing"
description: "We built a benchmark before touching any rendering code. Every scene was far under budget, so we fixed one thing and left the rest alone."
part: 5
weight: 5
date: 2026-10-17
commits: ["b9d194a", "a53d252", "af3114f"]
cover: "images/05-bench/pause-after-fix.png"
---

The third branch running next to the puzzles and the interface was performance. We didn't start by changing code. We started by building a way to measure the game, so any change after that would have a number to answer to.

## The harness

Commit `b9d194a` added `love echoes --bench LABEL`. It plays every scene the game has: the title, pause, level select, a loop of iris restarts, and every level's scripted solution. Vsync is off, so a frame's time is the game's own cost and not the monitor's refresh. Each scene gets:

1. 120 warmup frames, discarded.
2. 1200 timed frames, split into update, draw submission, and present.
3. 300 frames with the garbage collector stopped, to count kilobytes allocated per frame.

It prints the median, p95, p99 and max frame time per scene, with draw calls and allocation, and writes two CSV files to the save directory. `--size WxH` runs at another window size, and `--profile` adds a per-function breakdown. A follow-up, `a53d252`, lets the window settle after a resize before timing starts, so the first frames at a new size don't skew the numbers.

The same commit added a way to check that an optimization didn't change the picture. `--diff A.png B.png` compares two screenshots pixel by pixel and writes a mask of the differences. And `--shot` became deterministic. It seeds the random generators and freezes the menu clock, so the same shot gives the same pixels every time.

## Nothing was slow

Across scenes, frames took 0.14 to 0.31 ms. At 60 frames a second the budget is 16.7 ms, so the heaviest scene used less than 2% of it.

Shaving a frame that small saves time no player can feel, and every edit to working rendering code is a chance to break how the game looks. So we only went after a cost the numbers pointed at.

## Pause redrew a still picture

One scene was doing work for nothing. Pause draws a blurred, dimmed copy of the level behind the menu. Nothing under it moves, yet every frame it redrew the whole world and then four full-window blur copies on top.

Commit `af3114f` composes that frame once and keeps it in a canvas:

```lua
-- Nothing beneath the pause steps, so its frame, blur and dim are composed once into `still`.
local function freeze()
  if frozen() then return end
  still, stillVersion = gfx.newCanvas(gfx.getDimensions()), Assets.version
  gfx.push('all')
  Render.present(still)
  Ui.begin()
  gfx.setColor(1, 1, 1, 0.28)
  for _, o in ipairs(BLUR) do gfx.draw(Render.game, o[1], o[2], 0, 2, 2) end
  Ui.dim(0.58)
  Ui.finish()
  gfx.pop()
end
```

`frozen()` checks whether the window size changed or assets were hot-reloaded, and the canvas gets rebuilt if either happened. Leaving pause throws it away.

| Pause screen | Before | After |
| --- | --- | --- |
| Median frame | 0.222 ms | 0.136 ms |
| Draw calls per frame | 37 | 14 |
| Median frame, 3840x2160 | 0.493 ms | 0.234 ms |

The commit message rounds the 4K numbers to 0.49 and 0.23 ms, each the median of 5 alternating runs per side.

{{< pair >}}
{{< figure src="images/05-bench/pause-before-fix.png" caption="Pause before the fix, at `a53d252`." >}}
{{< figure src="images/05-bench/pause-after-fix.png" caption="And after, at `af3114f`." >}}
{{< /pair >}}

If those look identical, they are. The blog's screenshot script runs `af3114f`'s own `--diff` on them, and it reports 0 of 518400 pixels differ. The before shot is from `a53d252` because `--shot` was only deterministic from `b9d194a` on. An earlier shot would differ in its drifting dust and prove nothing.

## The rest stayed as it was

Nothing else the harness measured stood out from the noise, so we left it alone. A tidier draw loop or a pooled particle table might have looked like progress in a diff. With no measured cost behind it, it would only have been churn with a small chance of a visual regression.

The harness is still in the repository. If larger levels or sprite art ever make a scene slow, `--bench` will show which one and by how much.
