---
title: "Measuring before optimizing"
description: "A --bench harness, the finding that every scene was far under budget, the one fix that earned its place, and why everything else was left alone."
part: 5
weight: 5
date: 2026-10-17
commits: ["b9d194a", "a53d252", "af3114f"]
cover: "images/05-bench/pause-after-fix.png"
---

The third workstream that ran beside the puzzles and the interface was performance. Its first step was not to change any code. It was to build a way to measure the game, so that any change could be judged by a number.

## The harness

Commit `b9d194a` added `love echoes --bench LABEL`. It plays every scene the game has: the title, pause, level select, a loop of iris restarts, and every level's scripted solution. Vsync is off, so the frame time is the game's own cost, not the monitor's refresh. For each scene it runs:

1. 120 warmup frames, discarded.
2. 1200 timed frames, split into update, draw submission, and present.
3. 300 frames with the garbage collector stopped, to count kilobytes allocated per frame.

It prints the median, p95, p99, and max frame time per scene, with draw calls and allocation, and writes two CSV files to the save directory. `--size WxH` runs at another window size, and `--profile` adds a per-function breakdown. A follow-up, `a53d252`, lets the window settle after a resize before timing starts, so the first frames at a new size do not skew the numbers.

The same commit added two tools for checking that an optimization did not change the picture. `--diff A.png B.png` compares two screenshots pixel by pixel and writes a mask of the differences. And `--shot` became deterministic. It seeds the random generators and freezes the menu clock, so two runs of the same shot produce the same pixels.

## Nothing was slow

The game was already far under budget. Across scenes, frames took 0.14 to 0.31 ms. At 60 frames a second the budget is 16.7 ms, so the heaviest scene used less than 2% of it.

That result changes what "optimize" should mean. Shaving part of a frame that small saves time no player can feel, and every change to working rendering code is a chance to break how the game looks. So the bar for a fix was a cost the numbers singled out, not a cost that merely existed.

## The one fix

One scene stood out for doing work it did not need to do. Pause draws a blurred, dimmed copy of the level behind the menu. Nothing under the pause screen moves, yet every frame it redrew the whole world and then four full-window blur copies on top.

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

The cached canvas is rebuilt if the window size changes or if assets are hot-reloaded, which is what `frozen()` checks. Leaving pause throws it away.

| Pause screen | Before | After |
| --- | --- | --- |
| Median frame | 0.222 ms | 0.136 ms |
| Draw calls per frame | 37 | 14 |
| Median frame, 3840x2160 | 0.493 ms | 0.234 ms |

The commit message records the 4K numbers rounded to 0.49 and 0.23 ms, measured as the median of 5 alternating runs per side.

{{< pair >}}
{{< figure src="images/05-bench/pause-before-fix.png" caption="Pause at `a53d252`, before the fix." >}}
{{< figure src="images/05-bench/pause-after-fix.png" caption="Pause at `af3114f`, after the fix." >}}
{{< /pair >}}

The two images above look the same because they are the same. The screenshot script for this blog runs `af3114f`'s own `--diff` on them, and it reports 0 of 518400 pixels differ. The before shot is from `a53d252` rather than an earlier commit because `--shot` was only deterministic from `b9d194a` on. An earlier shot would differ in its drifting dust and prove nothing.

## What was left alone, and why

Everything else the harness measured came out as noise, and it was deliberately left as it was. A tidier draw loop or a pooled particle table might have looked like progress in a diff, but with no measured cost behind it, it would have been churn with a small chance of a visual regression.

The harness stays in the repository. If a later change, such as larger levels or sprite art, makes a scene slow, `--bench` will show which one and by how much. That is why it was built before any code changed. The next person can rerun it.
