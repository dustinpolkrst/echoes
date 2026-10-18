---
title: "The interface pass"
description: "A HUD that shows what the echo will remember, menus built on one model, a save file that survives corruption, and a --flow mode that drives the real menus with key presses."
part: 4
weight: 4
date: 2026-10-17
commits: ["86d2d95", "96bcc4f", "7b52ef4"]
cover: "images/04-interface/select-ui-pass.png"
---

The first build's title screen said "press jump", and that was the whole interface. You couldn't pause, nothing was saved, and there was no way back to an earlier level. Commit `86d2d95` added all of it. The work happened on its own branch next to the puzzles in [part 3]({{< relref "03-three-acts" >}}), so the screenshots here still have five levels.

{{< pair >}}
{{< figure src="images/01-pitch/title-first-build.png" caption="Before, in `a72332d`." >}}
{{< figure src="images/04-interface/title-ui-pass.png" caption="After, in `86d2d95`. A real menu, and a \"resume at\" line read from the save." >}}
{{< /pair >}}

## What the HUD shows

Every cast depends on state you can't see. How much of the last three seconds has the recorder filled? Which ghost goes away if you cast a third time? The HUD shows both. At the bottom left are two echo slots, oldest first, and a "memory" bar for the 3-second buffer.

{{< figure src="images/04-interface/hud-in-play.png" caption="Level 2. One slot holds the ghost on the left. The memory bar reads 1.5 s because only 90 frames have been recorded since the level started. Clock and deaths sit at the top right." >}}

The numbers come from `hudmodel.lua`, a small module that reads the world and returns plain values. The drawing code never touches the recorder:

```lua
-- Fraction of the 3 second history the recorder holds; a cast now replays exactly that much.
function Model.memory(world)
  return world.rec.count / Echo.FRAMES
end
```

Because the model is separate from the drawing, the selftest can check HUD values without a window.

## Every menu is a list

Title, pause, level select, settings and the level-clear card are the same thing underneath: a list of items, a cursor, and actions. `menu.lua` holds that model and every screen builds on it. An item is a label and an action, or for sliders and toggles, a value and an adjust function. The keyboard and the pad both produce `up`, `down`, `confirm` and `back`, so no screen needs input code of its own.

{{< pair >}}
{{< figure src="images/04-interface/pause.png" caption="Pause, over a blurred and dimmed copy of the level." >}}
{{< figure src="images/04-interface/settings.png" caption="Settings has master volume, sound effects, screen shake and fullscreen." >}}
{{< /pair >}}

{{< figure src="images/04-interface/select-ui-pass.png" caption="Level select. Cleared levels show a best time and fewest deaths, the next level is highlighted, and the rest are locked. The records are seeded test data." >}}

{{< figure src="images/04-interface/clear-card.png" caption="The clear card after a scripted run of level 1, with a new best time and a new fewest-deaths record." >}}

## A save file you can fix by hand

Progress and settings go to `save.txt` in the LÖVE save directory, as plain text with one fact per line:

```lua
out[#out + 1] = ('setting master %.2f'):format(s.master)
-- ...
out[#out + 1] = ('level %d %d %s %s'):format(i, r.done and 1 or 0,
  r.bestTime and ('%.3f'):format(r.bestTime) or '-', r.bestDeaths and tostring(r.bestDeaths) or '-')
```

The loader treats the file as untrusted. Volumes get clamped to 0 to 1. A time that isn't a finite positive number is dropped. A missing or corrupt file means defaults, not a crash. A level unlocks when the one before it is cleared.

The save module is also handed its file access as a parameter. The real game passes LÖVE's filesystem. Tests and the screenshot mode pass an in-memory store, so they never touch the real save. [Part 6]({{< relref "06-review" >}}) covers the one time a test run wrote into it anyway.

## The iris

Scene changes close the screen down to a circle, swap the scene while it's fully covered, and open again. After a death, a restart or a clear, the circle closes on the player. Menu changes close on the centre of the screen. The transition module runs a callback at full cover and ignores menu input while it's closing, so a double press can't start two scene changes.

{{< figure src="images/04-interface/iris-transition.png" caption="The iris 9 frames in, closing over level 2." >}}

## Pressing the real keys with --flow

Scripted solutions never reach the menus. The selftest drives the simulation, and nothing in it presses Esc halfway through a level. So commit `96bcc4f` added `love echoes --flow`. It boots the real scenes against an in-memory save and sends them key events. It opens pause and checks the simulation is frozen, resumes, opens settings, lowers the volume and checks the save text changed, then clears a level and checks the next one unlocked. At that commit it runs 21 checks, and all 21 pass when rerun for this post.

We leaned on it hard in [part 6]({{< relref "06-review" >}}), where every fix added a `--flow` check that failed on the old code first.
