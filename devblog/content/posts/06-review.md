---
title: "\"It speeds through and then crashes\""
description: "A bug report that the tests could not reproduce, a two-reviewer code review, and four fixes that each came with a check that failed on the old code first."
part: 6
weight: 6
date: 2026-10-17
commits: ["d33fa5e", "a4155a1", "e865580", "1b2f9ce"]
cover: "images/06-review/pause-settings-before.png"
---

After the three workstreams merged, Dustin played the game and reported that it "speeds through and then crashes". Every automated check was green. That combination is worth taking seriously, because it means the tests and the player are looking at different things.

## First, try to reproduce it

The obvious suspects were a simulation running too fast and a Lua error. Drivers that ran the real game loop, with real frame timing, showed a steady 60 simulation steps per second and no Lua error across a 10-minute playthrough of all 12 levels. Neither suspect held up.

That run also produced a mistake of its own. It wrote its level clears into the director's real save file. The file was moved aside, and it still sits next to the real one as `save.from-test-run.txt`. The screenshot script for this blog avoids the same trap by rewriting `t.identity` in every exported commit to a scratch name before it runs anything.

## A review with two reviewers

With no reproduction, the next step was a full code review by two independent reviewers, one reading for correctness and one for maintainability. Both found the same visual bug on their own. Every finding below was then confirmed by running the game, not taken on the reviewers' word.

### 1. Pause, then a menu, then resume drew the wrong level

Opening Settings or Level select from the pause menu rebuilt the game's single shared level layer for the title hall, which is the little ruin drawn behind the menus. Resuming then drew the title hall's tiles and camera over the level you were playing.

{{< pair >}}
{{< figure src="images/06-review/pause-settings-before.png" caption="Before, at `e865580`: level 3 after pause, Settings, back, resume. The stepped pyramid is the title hall, drawn where Stairway should be." >}}
{{< figure src="images/06-review/pause-settings-after.png" caption="After, at `1b2f9ce`: the same key presses. Stairway draws correctly." >}}
{{< /pair >}}

Both shots come from one scenario in `devblog/tools/blogscenarios.lua` that presses <kbd>P</kbd>, moves down to Settings, confirms, and presses <kbd>Esc</kbd> twice. The fix, `1b2f9ce`, gives each world its own baked layer, doors, camera, and particles. Its regression check draws the level, goes through pause, Settings, and back, draws it again, and requires 0 differing bytes.

### 2. Menus wrapped onto Quit

Menus wrapped from the top item to the bottom one, and the bottom item on the title and pause menus was Quit. <kbd>Up</kbd> and <kbd>Z</kbd> also mean jump. A player with a jump habit could press Up on the title menu, land on Quit, press Z, and the window closed with no warning.

{{< pair >}}
{{< figure src="images/06-review/title-up-before.png" caption="Before, at `042d3bf`: one press of Up on a fresh title menu puts the cursor on Quit." >}}
{{< figure src="images/06-review/title-up-after.png" caption="After, at `1b2f9ce`: the same press leaves the cursor on Play." >}}
{{< /pair >}}

From the player's side, a window that vanishes is a crash. This was the most likely explanation for "and then crashes". The fix, `d33fa5e`, clamps menus at their ends and makes Quit ask first.

{{< figure src="images/06-review/quit-confirm.png" caption="Confirming Quit once now only changes the label to \"Really quit?\". A second confirm within two seconds quits." >}}

### 3. Held input carried into the next screen

A jump or a stick direction still held when a level ended went straight into the level-clear card. A held jump could skip the card, and a held stick drifted its cursor. That is the most likely "speeds through": levels seemed to skip ahead on their own.

The fix, `e865580`, is a fresh-press gate. A scene change bumps an epoch. Keys and stick directions that were already down at that moment stay silent until they are released:

```lua
function Input.requireRelease()
  Input.sceneEpoch = Input.sceneEpoch + 1
  freshKeys = {}
end

function Input.fromKey(key, isRepeat)
  Input.lastDevice = 'key'
  if not isRepeat then
    freshKeys[key] = true
  elseif not freshKeys[key] then
    return {}
  end
  -- ...
```

A key repeat only counts if the key was first pressed after the scene began. The stick works the same way through `navPoll`, which marks any direction held across an epoch change as `blocked` until it returns to centre.

### 4. Restart right after the goal threw the clear away

Pressing <kbd>R</kbd> or Back in the moment after touching the goal restarted the level before the clear was recorded. The fix, `a4155a1`, ignores restart once the player state is `cleared`.

## Each fix proved itself first

Every fix landed as its own commit with a regression check, and every one of those checks was run against the old code first to confirm it failed. A check that passes on the broken code proves nothing about the fix. The selftest went from 139 to 149 checks and `--flow` from 21 to 33. Rerun for this post at `1b2f9ce`, all 149 and all 33 pass.

The lesson is about what the tests were looking at. The selftest drove the simulation, and the simulation was fine. The bugs lived in the seams between scenes, where a person's hands are still on the keys from the last screen. A test that sends one clean key event per action cannot press Up out of habit.
