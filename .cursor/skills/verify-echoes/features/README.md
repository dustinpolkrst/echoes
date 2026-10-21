# Echoes verification map

This directory is the maintained source for verifying the player-facing window of Echoes. Read the index before driving the game, then use the matching feature file as the recipe.

## Baseline preconditions

- Launch with `.cursor/skills/verify-echoes/scripts/verify-echoes launch` from the repo root.
- The launch uses a disposable data directory. The title row is `Play` only when that directory has no cleared level.
- `love --version` is `LOVE 11.5` and `DISPLAY` is the X11 server that owns the window.
- Run `verify-echoes doctor` and require `ok`, `version: LOVE 11.5`, window title `ECHOES`, and this run's `save` directory.
- Never drive an `ECHOES` window that this launch did not start. One driven window per display.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Treat every command as literal. Keep key names and flags unchanged.
- `verify-echoes` means `.cursor/skills/verify-echoes/scripts/verify-echoes`.
- After a confirm or back that changes screens, wait `0.7` before the next key.
- Restore nothing in the player's real save directory. The disposable directory is removed by cleanup.
- Do not remove `artifacts/verify-echoes/` during cleanup.

## Proof and skip reporting

- Capture the keypress and the screen it produced, not only the final screen.
- UI proof is a 960×540 screenshot with Echoes identity visible (wordmark, heading, or level title).
- Save proof is the `save-cat` text. `no save file` is a real result when the recipe says the step does not save.
- Record the feature id in the artifact directory name.
- Report an unreachable path with the command that failed and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the player-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every player entry point.
3. `Driving it with verify-echoes` starts with `Preconditions:` and uses labeled bullets that pair each player action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only player paths, on-screen labels, required state, commands, and observable proof.

## Features

- [Play](./play.md) starts level 1, Wake, from the title and moves on the opening floor.
- [Pause](./pause.md) opens the pause menu from play and resumes without leaving the level.
- [Settings](./settings.md) changes master volume from the title and from pause, and checks the save.
- [Level select](./level-select.md) opens the grid, refuses a locked level, and starts Wake.
- [Cast an echo](./cast-echo.md) leaves a ghost of recent movement in Wake.
