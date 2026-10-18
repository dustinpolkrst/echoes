---
title: "Moving 27 files without changing a pixel"
description: "The game's Lua files moved from one flat folder into a tree under game/. Same checks, same counts, and screenshots that match pixel for pixel."
part: 9
weight: 9
date: 2026-10-17
commits: ["7ae145b", "eb0d82c", "0c8fcda", "eccb521"]
cover: "images/09-layout/select-game-folder.png"
---

Up to `1afca9f`, every Lua file in the game sat in the repository root: 27 of them, next to `README.md` and the `assets/` folder. The game grew that way during one long session, one file at a time, and the layout made sense to whoever had just added the last file. It did not make sense to a person opening the project for the first time.

## What a flat folder hid

An alphabetical listing puts `level.lua` next to `levels.lua`, `hud.lua` next to `hudmodel.lua`, and `shot.lua` next to `slack.lua` and `solutions.lua`. Nothing in that listing says that `level.lua` is the simulation and `levels.lua` is data. Nothing says that eight of the 27 files are developer tools the game loads only for a command-line flag. Nothing says which three files make up the simulation, the part that runs with no graphics so the selftest can replay it headless. To learn any of that, a newcomer had to open `main.lua` and follow every `require`.

## The new map

Commit `7ae145b` moved the files into folders under `game/`, and `game/` is now the folder LÖVE loads. The repository root holds only `README.md`, `scripts/`, `game/`, and `devblog/`.

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

Modules now require each other by dotted path from `game/`, as in `require 'world.level'`. The folder name tells you what a file is for before you open it.

## One rule the layout encodes

`world/` requires nothing outside itself. The whole folder has two `require` lines, both in `level.lua`, and both point at `world.player` and `world.echo`. Drawing goes the other way. `gfx/render.lua` attaches a draw function to each entry of `Level.TILES`, so the simulation never loads graphics code. `content/levels.lua` requires nothing at all.

That rule is why `--selftest` and `--slack` can run with LÖVE's graphics, window, and audio modules switched off in `conf.lua`. The README states it as "Keep it that way." No check enforces it yet. Today the check is one command that a person has to remember to run:

```
grep -rn require game/world game/content
```

## Two scripts for the common commands

Commit `eb0d82c` adds `scripts/play` and `scripts/test`, each as a `.cmd` for Windows and a `.sh` for macOS and Linux. `play` starts the game and passes any extra arguments through, so `scripts/play.sh --shot title` works. `test` runs `--selftest`, `--flow`, and `--slack` in turn and stops at the first failure with a nonzero exit code. Commit `0c8fcda` rewrote the README around the new folder map.

## Proving nothing changed

A move like this should change where code lives and nothing else. Three checks back that up.

First, the diff. Besides the renames, commit `7ae145b` removes 80 lines and adds 80, and every one of those 160 lines is a `require`:

```
git diff -M 1afca9f 7ae145b | grep '^[-+][^-+]' | grep -vc require
0
```

Second, the checks. At `1afca9f` and at `eccb521`, the merge that brought the move to `main`, `--selftest` reports 155 checks with 0 failed and `--flow` reports 33 with 0 failed. The output of `--slack 10` is byte for byte the same at both commits.

Third, the pictures. For this post, 23 `--shot` targets were rendered at both commits: the title, pause, level select, settings, clear card, and iris transition, every level at frame 90, and three frames from the middle of scripted solutions. All 23 pairs match pixel for pixel. That sweep was a one-off, but one pair stays checked. `devblog/tools/shots.sh` renders the level select at both commits and runs `eccb521`'s own `--diff` on them, and the script fails if any pixel differs:

```
DIFF before.png after.png  0 of 518400 pixels differ, max channel delta 0/255
```

{{< pair >}}
{{< figure src="images/09-layout/select-flat-folder.png" caption="Level select at `1afca9f`, before the move. The records are seeded test data." >}}
{{< figure src="images/09-layout/select-game-folder.png" caption="The same screen at `eccb521`, after the move. 0 of 518,400 pixels differ." >}}
{{< /pair >}}

The blog's screenshot script needed no change for the move. It exports each commit whole with `git archive`, and when a commit keeps `main.lua` in `game/` instead of the root, it runs that folder.
