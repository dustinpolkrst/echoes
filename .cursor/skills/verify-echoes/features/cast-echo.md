# Cast an echo

Casting in Wake leaves a ghost that replays the last few seconds of movement, then a filled pip for that echo.

## Sub-features

- `cast-move` walks right so the recording is not a standstill.
- `cast-x` casts with `X` and shows a ghost plus a filled echo pip.
- `cast-k` is the other cast key, used from a fresh attempt so it is not a second ghost.

## How to get to it (user POV)

- Start Wake from `Play` or from the Wake card on the level grid.
- Press `X` or `K` while the level is showing, not while a menu is open.

## Driving it with verify-echoes

Preconditions:

- Echoes is healthy: `verify-echoes doctor` prints `ok` and window title `ECHOES`.
- Wake is on screen and the pause menu is closed. No echo pip is filled.

- **Walk first.** Hold right for one second so the ghost has a path. Run `.cursor/skills/verify-echoes/scripts/verify-echoes keydown Right`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 1`, `.cursor/skills/verify-echoes/scripts/verify-echoes keyup Right`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/cast-echo/01-walked.png`. The lantern has moved right and Wake is still the level. Both echo pips at the lower left are empty.
- **Cast with X.** Press `X`. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key x`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.4`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/cast-echo/02-cast.png`. A ghost lantern is visible apart from the player, retracing the walk, and one lower-left echo pip is filled.
- **Cast with K on a fresh attempt.** Restart the level so the first ghost is gone, walk for one second again, and press `K` instead of `X`. Run `.cursor/skills/verify-echoes/scripts/verify-echoes key r`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7`, then the same hold-right sequence, then `.cursor/skills/verify-echoes/scripts/verify-echoes key k`, `.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.4`, and `.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/cast-echo/03-cast-k.png`. Again one ghost is apart from the player and one pip is filled. This is not a second pip on top of the `X` cast.

## Gotchas

- `X` and `K` do nothing useful on a menu. Pause must be closed.
- Casting without moving first plants the ghost on the player, so the screenshot cannot show them apart.
- One second of right from Wake's opening floor stays on the ground. Longer walks reach a gap.
- A third cast removes the oldest ghost. This recipe expects a single ghost, so restart before the `K` cast instead of casting twice in one life.
- The memory label fills over the first three seconds. A cast still works before it reads `memory 3.0s`.
