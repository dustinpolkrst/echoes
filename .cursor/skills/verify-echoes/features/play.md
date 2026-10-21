# Play

Play starts level 1, Wake, from the title menu on a fresh save, and the lantern can move along the opening floor.

## Sub-features

- `play-title` shows `Play` selected on a fresh save, above `Level select`, `Settings`, and `Quit`.
- `play-start` confirms `Play` and lands in Wake.
- `play-move` walks right along the opening floor.

## How to get to it (user POV)

- On the title, the highlight already rests on `Play`. Press `Return`, `Z`, or `Space`.
- If the title says `Continue` instead of `Play`, a level has already been cleared. That is not this entry.

## Driving it with verify-echoes

Preconditions:

- Echoes is healthy: `verify-echoes doctor` prints `ok`, `version: LOVE 11.5`, and window title `ECHOES`.
- The title highlight is on `Play`. `save-cat` prints `no save file`.

- **Title.** Look at the menu before confirming. Run `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/play/01-title.png`. The frame shows the `ECHOES` wordmark, `Play` highlighted, then `Level select`, `Settings`, and `Quit`.
- **Start Wake.** Confirm `Play`. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Return` and `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, then `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/play/02-wake.png`. The frame shows `1. Wake` and `Arrows move. Jump with Z, Space or Up. Hold jump to go higher.`
- **Still unsaved.** Starting a level does not write a save. Run `.cursor/skills/verify-echoes/scripts/verify-echoes save-cat --out artifacts/verify-echoes/play/03-save.txt`. The text is `no save file`.
- **Walk.** Hold right for one second. Run `.cursor/skills/verify-echoes/scripts/verify-echoes keydown Right`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 1`, `.cursor/skills/verify-echoes/scripts/verify-echoes keyup Right`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/play/04-moved.png`. The lantern is to the right of where it stood in `02-wake.png`, still on the floor, and the heading or HUD still names Wake.

`Z` and `Space` are the other confirm keys on `Play`. Each one starts the level, so each needs its own fresh launch. Do not claim them from a run that already pressed `Return`.

## Gotchas

- `Continue` means the save is not fresh. Cleanup and launch again before calling this Play.
- The large `1. Wake` title fades after a few seconds. Capture it before it fades. The small HUD name remains after that.
- `Z`, `Space`, `W`, and `Up` jump once the level is running. On the title they confirm the menu.
- One second of right from the opening spot stays on the floor. A long hold reaches the gap.
- `Return` on `Play` is the entry this recipe runs. A run that only opens the level from Level select has not verified Play.
