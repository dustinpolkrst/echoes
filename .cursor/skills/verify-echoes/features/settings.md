# Settings

Settings changes master volume from the title and again from the pause menu. The new percent stays on screen and in the save.

## Sub-features

- `settings-open-title` opens Settings from the title menu.
- `settings-volume` lowers master volume one step.
- `settings-persist` writes the save and shows the same percent after leaving and coming back.
- `settings-open-pause` opens Settings from the pause menu with that percent still shown.

## How to get to it (user POV)

- On the title, move down to `Settings` and confirm.
- During play, open pause, move down to `Settings`, and confirm.
- `Esc` from Settings returns to whichever of those opened it.

## Driving it with verify-echoes

Preconditions:

- Echoes is healthy: `verify-echoes doctor` prints `ok`, `version: LOVE 11.5`, window title `ECHOES`, and `save_file: absent`.
- The title highlight is on `Play`.

- **Title before the change.** Run `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/01-title.png`. The frame shows `ECHOES` and `Play` highlighted.
- **Open Settings from the title.** Move to `Settings` and confirm. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/02-settings-open.png`. The heading is `SETTINGS`. `Master volume` is highlighted at `80%`. `Sound effects` reads `70%`. `Screen shake` is `On`. `Fullscreen` is `Off`. `Back` is the last row.
- **Lower master volume.** Press left once. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Left` and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/03-master-70.png`. `Master volume` reads `70%`. `Sound effects` still reads `70%`.
- **Read the save.** Run `.cursor/skills/verify-echoes/scripts/verify-echoes save-cat --out artifacts/verify-echoes/settings/04-save.txt`. The text contains `setting master 0.70`, `setting sfx 0.70`, `setting fullscreen 0`, and `setting shake 1`.
- **Back to the title.** Press escape and let the wipe finish. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/05-title-again.png`. The title is back and the first row is still `Play`, not `Continue`.
- **Reopen Settings.** Move to `Settings` and confirm again. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/06-settings-again.png`. `Master volume` still reads `70%`.
- **Reach pause.** Go back to the title, start Wake, and pause. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/07-paused.png`. The frame shows `PAUSED` and `1. Wake`, with `Resume` highlighted.
- **Open Settings from pause.** Move to `Settings` and confirm. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Down`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Return`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/08-settings-from-pause.png`. The heading is `SETTINGS` and `Master volume` reads `70%`.
- **Return to Wake.** Leave Settings, then resume. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, `.cursor/skills/verify-echoes/scripts/verify-echoes key Escape`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/settings/09-resumed.png`. The frame shows Wake and does not show `SETTINGS` or `PAUSED`.

## Gotchas

- `Z`, `Return`, and `Space` on a slider raise it. `Left` lowers it. The footer `Z Change` is the raise. One extra `Left` makes master `60%` and fails the `0.70` check.
- The wipe eats keys. Wait `0.7` after `Return` and after `Escape` before moving again.
- Turning `Fullscreen` on changes the window size. Leave it `Off`.
- A cleared level renames the title row to `Continue`. This recipe never clears a level, so a later `Continue` means the save was not fresh.
- Settings opened from pause returns to pause, not to the title. One `Escape` from that screen is not a resume.
- The first confirm on `Quit` or `Quit game` only asks. Do not confirm it.
