---
title: "Four bugs behind a quit button"
description: "A code review found four bugs, and two of them were the likely reason the game seemed to race through levels and crash."
part: 6
weight: 6
date: 2026-10-17
commits: ["d33fa5e", "a4155a1", "e865580", "1b2f9ce"]
cover: "images/06-review/pause-settings-before.png"
---

Once the three branches merged, I played the game. It seemed to race through levels and then crash. Every automated check was green, so the tests and I were looking at different things.

## Trying to reproduce it

The first suspects were a simulation running too fast and a Lua error. A 10-minute playthrough of all 12 levels drove the real game loop with real frame timing. It held a steady 60 simulation steps per second and threw no Lua error. Neither suspect held up.

That run made a mess of its own. It wrote its level clears into my real save file. That file was moved aside, and it still sits next to the real one as `save.from-test-run.txt`. The screenshot script for this blog avoids the same trap by rewriting `t.identity` in every exported commit to a scratch name before it runs anything.

## Two code reviews

With nothing reproduced, two independent reviewers went through the code, one reading for correctness and one for maintainability. Both found the same visual bug on their own. Each finding below was then confirmed in the running game, not taken on a reviewer's word.

### 1. Pause, a menu, resume, and the wrong level

Opening Settings or Level select from the pause menu rebuilt the game's single shared level layer for the title hall, the little ruin drawn behind the menus. Resume, and the title hall's tiles and camera were drawn over the level you were playing.

{{< pair >}}
{{< figure src="images/06-review/pause-settings-before.png" caption="At `e865580`, level 3 after pause, Settings, back, resume. That stepped pyramid is the title hall, sitting where Stairway should be." >}}
{{< figure src="images/06-review/pause-settings-after.png" caption="At `1b2f9ce`, the same key presses. Stairway is back." >}}
{{< /pair >}}

Both shots come from one scenario in `devblog/tools/blogscenarios.lua` that presses <kbd>P</kbd>, moves down to Settings, confirms, and presses <kbd>Esc</kbd> twice. The fix, `1b2f9ce`, gives each world its own baked layer, doors, camera and particles. Its regression check draws the level, goes through pause, Settings and back, draws it again, and requires 0 differing bytes.

### 2. Up, then Quit

Menus wrapped from the top item to the bottom one, and on the title and pause menus the bottom item was Quit. <kbd>Up</kbd> and <kbd>Z</kbd> also mean jump. A player with a jump habit could press Up on the title menu, land on Quit, press Z, and the window closed with no warning.

{{< pair >}}
{{< figure src="images/06-review/title-up-before.png" caption="At `042d3bf`, one press of Up on a fresh title menu puts the cursor on Quit." >}}
{{< figure src="images/06-review/title-up-after.png" caption="At `1b2f9ce`, the same press leaves it on Play." >}}
{{< /pair >}}

To the person playing, a window that vanishes is a crash. This was the most likely cause of the crash. The fix, `d33fa5e`, stops menus at their ends and makes Quit ask first.

{{< figure src="images/06-review/quit-confirm.png" caption="Confirm Quit once and the label only changes to \"Really quit?\". A second confirm within two seconds quits." >}}

### 3. Held keys leaked into the next screen

A jump or stick direction still held when a level ended went straight into the level-clear card. A held jump could skip the card, and a held stick drifted its cursor. That's the most likely reason the game seemed to race through levels. They appeared to skip ahead by themselves.

The fix, `e865580`, only listens to fresh presses. A scene change bumps an epoch, and keys and stick directions already down at that moment stay silent until they're released:

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

A key repeat counts only if the key went down after the scene began. The stick works the same way through `navPoll`, which marks any direction held across an epoch change as `blocked` until it comes back to centre.

### 4. Restart right after the goal

Press <kbd>R</kbd> or Back just after touching the goal and the level restarted before the clear was recorded. The fix, `a4155a1`, ignores restart once the player state is `cleared`.

## Checks that fail on the old code

Every fix landed as its own commit with a regression check, and each check ran against the old code first to confirm it failed. A check that passes on broken code says nothing about the fix. The selftest went from 139 to 149 checks and `--flow` from 21 to 33. Rerun for this post at `1b2f9ce`, all 149 and all 33 pass.

The selftest drove the simulation, and the simulation was fine. The bugs were in the gaps between scenes, where a player's hands are still on the keys from the last screen. A test that sends one clean key event per action never presses Up out of habit.
