---
title: "The interface pass"
description: "A HUD that shows how much the echo will remember, a pause menu over a blurred world, a level select with records, saves that survive a corrupt file, and a --flow mode that drives the real menus with key presses."
part: 4
weight: 4
date: 2026-10-17
commits: ["86d2d95", "96bcc4f", "7b52ef4"]
cover: "images/04-interface/select-ui-pass.png"
---

The first build had a title that said "press jump" and nothing else. No pause, no saved progress, no way back to an earlier level. The interface pass, commit `86d2d95`, added all of it. It ran alongside the puzzle work in [part 3]({{< relref "03-three-acts" >}}), on its own branch, so the screenshots here show the game with five levels.

{{< pair >}}
{{< figure src="images/01-pitch/title-first-build.png" caption="Before: the title in `a72332d`." >}}
{{< figure src="images/04-interface/title-ui-pass.png" caption="After: the title in `86d2d95`, with a menu and a \"resume at\" line read from the save." >}}
{{< /pair >}}

## A HUD that answers "what will my echo do?"

The echo has hidden state that matters for every cast. How much of the last three seconds has the recorder actually filled? Which echo disappears if you cast a third time? The HUD answers both. At the bottom left it shows two echo slots, oldest first, and a "memory" bar for the 3-second buffer.

{{< figure src="images/04-interface/hud-in-play.png" caption="Level 2 in `86d2d95`. One slot is filled by the echo at the left, and the memory bar reads 1.5 s because only 90 frames have been recorded since the level started. The top right shows the clock and deaths." >}}

The numbers come from a small model, `hudmodel.lua`, that reads the world and returns plain values. The drawing code never touches the recorder:

```lua
-- Fraction of the 3 second history the recorder holds; a cast now replays exactly that much.
function Model.memory(world)
  return world.rec.count / Echo.FRAMES
end
```

Keeping the model apart from the drawing means the selftest can check the HUD values without a window.

## Menus share one model

Title, pause, level select, settings, and the level-clear card are the same thing underneath. Each is a list of items, a cursor, and actions. `menu.lua` holds that model and every screen builds on it. An item is a table with a label and an action, or a value and an adjust function for sliders and toggles. The keyboard and the pad produce the same actions (`up`, `down`, `confirm`, `back`), so every screen works on both without per-screen input code.

{{< pair >}}
{{< figure src="images/04-interface/pause.png" caption="Pause, drawn over a blurred and dimmed copy of the level." >}}
{{< figure src="images/04-interface/settings.png" caption="Settings: master volume, sound effects, screen shake, fullscreen." >}}
{{< /pair >}}

{{< figure src="images/04-interface/select-ui-pass.png" caption="Level select in `86d2d95`. Cleared levels show a best time and fewest deaths. The next level is highlighted and later ones are locked. The records are seeded test data from the shot mode." >}}

{{< figure src="images/04-interface/clear-card.png" caption="The level-clear card after a scripted run of level 1, marking a new best time and a new fewest-deaths record." >}}

## Saving without trusting the file

Progress and settings go to `save.txt` in the LÖVE save directory. The format is plain text, one fact per line, so it can be read and repaired by hand:

```lua
out[#out + 1] = ('setting master %.2f'):format(s.master)
-- ...
out[#out + 1] = ('level %d %d %s %s'):format(i, r.done and 1 or 0,
  r.bestTime and ('%.3f'):format(r.bestTime) or '-', r.bestDeaths and tostring(r.bestDeaths) or '-')
```

The parser treats the file as untrusted input. Volumes are clamped to 0 to 1. A time that is not a finite positive number is dropped. A missing or corrupt file falls back to defaults instead of crashing. A level unlocks when the one before it is cleared.

The save module also takes its file access as a parameter. The real game passes LÖVE's filesystem. Tests and the screenshot mode pass an in-memory store, so they never touch the real save. [Part 6]({{< relref "06-review" >}}) describes the one time a test run did write into the real file anyway.

## Transitions

Scene changes use an iris. The screen closes to a circle, the scene swaps while the screen is fully covered, and the circle opens again. After a death, a restart, or a clear, the circle closes on the player. Menu changes close on the centre of the screen. The transition module runs a callback at the moment of full cover, and while it is closing, menu input is ignored, so a double press cannot start two scene changes.

{{< figure src="images/04-interface/iris-transition.png" caption="The iris 9 frames into a transition, closing over level 2." >}}

## Driving the menus with --flow

Menus are where scripted solutions do not reach. The selftest drives the simulation, but nothing in it presses Esc during a level. So commit `96bcc4f` added `love echoes --flow`. It boots the real scenes against an in-memory save and sends them key events: open pause, check the simulation is frozen, resume, open settings, lower the volume, check the save text changed, clear a level, check the next one unlocked. At that commit it runs 21 checks, and all 21 pass when rerun for this post.

That mode paid for itself in [part 6]({{< relref "06-review" >}}). Every fix there added a `--flow` check that failed on the old code first.
