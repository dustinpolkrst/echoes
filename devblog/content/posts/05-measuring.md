---
title: "Benchmarking the pause screen"
description: "A benchmark showed every scene far under its frame budget, so the one optimization was to stop redrawing the pause screen."
part: 5
weight: 5
date: 2026-10-17
commits: ["b9d194a", "a53d252", "af3114f"]
cover: "images/05-bench/pause-after-fix.png"
---

The game draws a lot by hand: parallax layers, moss, a lightmap, particles, glows. Before changing any of that for speed, it needed a number to answer to.

## The benchmark

`love echoes --bench LABEL` plays every scene the game has: the title, pause, level select, a loop of iris restarts, and every level's scripted solution. Vsync is off, so a frame's time is the game's own cost and not the monitor's refresh. Each scene gets:

1. 120 warmup frames, discarded.
2. 1200 timed frames, split into update, draw submission, and present.
3. 300 frames with the garbage collector stopped, to count kilobytes allocated per frame.

It reports the median, p95, p99 and max frame time per scene, with draw calls and allocation. `--size WxH` runs at another window size, and the window gets time to settle after a resize so the first frames at a new size don't skew the numbers.

## Every scene was far under budget

Across scenes, frames took 0.14 to 0.31 ms. At 60 frames a second the budget is 16.7 ms, so the heaviest scene used less than 2% of it.

Shaving a frame that small saves time no player can feel, and every edit to working rendering code is a chance to break how the game looks. So the only change went after a cost the numbers pointed at.

## Pause redrew a still picture every frame

One scene was doing work for nothing. Pause draws a blurred, dimmed copy of the level behind the menu. Nothing under it moves, yet every frame it redrew the whole world and then four full-window blur copies on top.

The fix composes that frame once and keeps it in a canvas:

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

`frozen()` checks whether the window size changed or art was hot-reloaded with <kbd>F5</kbd>, and the canvas gets rebuilt if either happened. Leaving pause throws it away.

| Pause screen | Before | After |
| --- | --- | --- |
| Median frame | 0.222 ms | 0.136 ms |
| Draw calls per frame | 37 | 14 |
| Median frame, 3840x2160 | 0.493 ms | 0.234 ms |

The 4K row matters most. Four full-window blur copies cost more as the window grows, so a player at 4K got the biggest saving.

{{< pair >}}
{{< figure src="images/05-bench/pause-before-fix.png" caption="Pause before the change, redrawn every frame." >}}
{{< figure src="images/05-bench/pause-after-fix.png" caption="After, drawn once. The two pictures are identical to the pixel." >}}
{{< /pair >}}

That was the bar for the change. A cached frame that looked even slightly different from the live one would have been a visual bug traded for time nobody could feel.

## Nothing else changed

Nothing else the benchmark measured stood out from the noise, so the rest of the rendering code stayed as it was. A tidier draw loop or a pooled particle table might have looked like progress. With no measured cost behind it, it would only have been churn with a small chance of a visual regression.

The benchmark stays in the game. If larger levels or sprite art ever make a scene slow, `--bench` will show which one and by how much.
