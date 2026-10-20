# Level select

Level select shows the level grid. On a fresh save only Wake can start. Confirming a locked card stays on the grid.

## Sub-features

- `select-open` opens the grid from the title.
- `select-locked` refuses the locked card beside Wake.
- `select-start` starts Wake from its card.
- `select-back` returns to the title without starting a level.

## How to get to it (user POV)

- On the title, move down to `Level select` and confirm.
- During play, open pause, move down to `Level select`, and confirm.
- `Esc` goes back to the screen that opened the grid.

## Driving it with verify-echoes

Preconditions:

- Echoes is healthy: `verify-echoes doctor` prints `ok` and `save_file: absent`.
- The title highlight is on `Play`. No level has been cleared.

- **Open the grid.** Move to `Level select` and confirm. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/level-select/01-grid.png`. The heading is `SELECT LEVEL`. Card `1` reads `Wake` and `not cleared`. The next card reads `locked`.
- **Refuse a locked card.** Move right and confirm. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Right`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/level-select/02-locked.png`. The heading is still `SELECT LEVEL`. Wake is not showing.
- **Start Wake.** Move back to card 1 and confirm. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Left`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/level-select/03-wake.png`. The frame shows `1. Wake`.
- **Back without starting, on a fresh launch.** Launch again so the title is showing, open `Level select` the same way, then press escape. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/level-select/04-back-title.png` after that fresh open. The title is back, with `Play` highlighted, and Wake is not showing.

The pause entry is a separate open: from Wake, `Escape`, then two `Down`s, then `Return`. It shows the same `SELECT LEVEL` heading. `Escape` from that open returns to pause, not the title. Do not report the title open as the pause open.

## Gotchas

- Card 1 is selected when the grid opens from the title on a fresh save. `Right` lands on the locked neighbor.
- Confirm on a locked card plays a refusal and stays on the grid. Waiting does not start the level.
- Clearing Wake is not part of this recipe. A grid full of open cards means the save was not fresh.
- The title open and the pause open return to different screens. One `Escape` does not prove both.
