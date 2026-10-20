# Pause

Pause freezes the level under a menu and resumes it on the same ground. The clock on the frozen picture does not advance while the menu is up.

## Sub-features

- `pause-open` opens the pause menu from play.
- `pause-frozen` keeps the same clock reading while the menu stays open.
- `pause-resume` returns to Wake without the menu.
- `pause-p` opens and closes pause with `P` as well as `Esc`.

## How to get to it (user POV)

- During play, press `Esc` or `P`.
- The menu's first row is `Resume`. `Esc` or `P` again resumes. Confirm on `Resume` also resumes.
- `Quit game` is the last row. The first confirm only asks `Really quit?`.

## Driving it with verify-echoes

Preconditions:

- Echoes is healthy: `verify-echoes doctor` prints `ok` and window title `ECHOES`.
- Wake is on screen (`1. Wake`), reached by the Play recipe's confirm, and the pause menu is not open.

- **Open with Esc.** Press escape. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/pause/01-paused.png`. The frame shows `PAUSED`, `1. Wake`, and the rows `Resume`, `Restart level`, `Level select`, `Settings`, and `Quit game`, with `Resume` highlighted.
- **Clock holds.** Wait, then shoot again. Run `.cursor/skills/verify-echoes/scripts/verify-echoes wait 1` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/pause/02-still-paused.png`. `PAUSED` is still up and the clock digits match `01-paused.png`.
- **Resume with Esc.** Press escape. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/pause/03-resumed.png`. The frame is Wake again and does not show `PAUSED`.
- **Open with P.** Press `P`. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key p` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/pause/04-paused-p.png`. `PAUSED` and `1. Wake` are back, with `Resume` highlighted.
- **Resume with P.** Press `P` again. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key p` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/pause/05-resumed-p.png`. Wake is back and `PAUSED` is gone.

## Gotchas

- `Esc` inside Settings or Level select goes back to the previous screen. It pauses only while the level itself is showing.
- The first confirm on `Quit game` changes that row to `Really quit?` and does not leave the game. A second confirm quits.
- Pause is ignored on the clear card. This recipe stays in Wake and never touches the goal.
- `Restart level` builds a new attempt. Do not confirm it when the proof is "the same life resumed".
