---
title: "Moving 27 files without changing a pixel"
description: "The game's Lua files moved from one flat folder into a tree under game/, with the same checks, the same counts, and screenshots that match pixel for pixel."
part: 8
weight: 8
date: 2026-10-17
commits: ["7ae145b", "eb0d82c", "0c8fcda", "eccb521"]
cover: "images/09-layout/select-game-folder.png"
---

Up to `1afca9f`, all 27 of the game's Lua files sat in the repository root, next to `README.md` and the `assets/` folder. The game grew that way over one long session, one file at a time. The layout made sense to whoever had just added a file. It made no sense to someone opening the project for the first time.

## What the flat folder hid

Sorted alphabetically, `level.lua` sits next to `levels.lua`, `hud.lua` next to `hudmodel.lua`, and `shot.lua` next to `slack.lua` and `solutions.lua`. The listing doesn't tell you that `level.lua` is the simulation and `levels.lua` is data. It doesn't tell you that eight of the 27 files are developer tools the game loads only for a command-line flag, or which three files make up the simulation the selftest replays headless. To learn any of that, you had to open `main.lua` and follow every `require`.

## The new map

Commit `7ae145b` moved the files into folders under `game/`, and `game/` is now the folder LÖVE loads. The repository root holds only `README.md`, `scripts/`, `game/` and `devblog/`.

```
game/
  main.lua  conf.lua
  world/      the simulation: level.lua, player.lua, echo.lua
  content/    levels.lua, the twelve maps
  screens/    scenes.lua, progress.lua, menu.lua, transition.lua
  gfx/        render.lua, particles.lua, ui.lua, hud.lua, hudmodel.lua
  platform/   input.lua, save.lua, assets.lua, sfx.lua
  dev/        selftest.lua, uitest.lua, flowtest.lua, solutions.lua,
              slack.lua, bench.lua, shot.lua, imgdiff.lua
  assets/     optional art and sound overrides
```

Modules require each other by dotted path from `game/`, as in `require 'world.level'`, so a file's folder tells you what it's for before you open it.

## world/ requires nothing outside itself

The whole folder has two `require` lines, both in `level.lua`, pointing at `world.player` and `world.echo`. Drawing hooks in from the other side. `gfx/render.lua` attaches a draw function to each entry of `Level.TILES`, so the simulation never loads graphics code. `content/levels.lua` requires nothing at all.

That's why `--selftest` and `--slack` can run with LÖVE's graphics, window and audio modules switched off in `conf.lua`. The README says "Keep it that way." Nothing enforces it yet. For now the check is one command someone has to remember to run:

```
grep -rn require game/world game/content
```

## Two scripts

Commit `eb0d82c` adds `scripts/play` and `scripts/test`, each as a `.cmd` for Windows and a `.sh` for macOS and Linux. `play` starts the game and passes extra arguments through, so `scripts/play.sh --shot title` works. `test` runs `--selftest`, `--flow` and `--slack` in turn and stops at the first failure with a nonzero exit code. Commit `0c8fcda` rewrote the README around the new folder map.

## Did anything change?

A move like this should change where code lives and nothing else, so we checked the diff, the test counts and the pixels.

Besides the renames, commit `7ae145b` removes 80 lines and adds 80, and every one of those 160 lines is a `require`:

```
git diff -M 1afca9f 7ae145b | grep '^[-+][^-+]' | grep -vc require
0
```

At `1afca9f` and at `eccb521`, the merge that brought the move to `main`, `--selftest` reports 155 checks with 0 failed and `--flow` reports 33 with 0 failed. The output of `--slack 10` is byte for byte the same at both commits.

For this post we also rendered 23 `--shot` targets at both commits: the title, pause, level select, settings, clear card and iris transition, every level at frame 90, and three frames from the middle of scripted solutions. All 23 pairs match pixel for pixel. That sweep was a one-off, but one pair stays checked. `devblog/tools/shots.sh` renders the level select at both commits, runs `eccb521`'s own `--diff` on them, and fails if any pixel differs:

```
DIFF before.png after.png  0 of 518400 pixels differ, max channel delta 0/255
```

{{< pair >}}
{{< figure src="images/09-layout/select-flat-folder.png" caption="Level select at `1afca9f`, before the move. The records are seeded test data." >}}
{{< figure src="images/09-layout/select-game-folder.png" caption="At `eccb521`, after the move. 0 of 518,400 pixels differ." >}}
{{< /pair >}}

The blog's screenshot script needed no change for the move. It exports each commit whole with `git archive`, and when a commit keeps `main.lua` in `game/` instead of the root, it runs that folder.
