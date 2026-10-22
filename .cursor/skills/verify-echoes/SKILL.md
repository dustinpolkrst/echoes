---
name: verify-echoes
description: "Drive the Echoes LÖVE window the way a player does. Use when launching a fresh save, sending real keypresses, and capturing screenshots plus save.txt for the title, play, pause, settings, level select, or an echo cast. Reach for it before claiming a menu or gameplay change works."
---

# Verify Echoes

The primary surface is the desktop game: a 960×540 window titled `ECHOES`, started with `scripts/play.sh`. The player moves with the keyboard. This skill launches one isolated window, types into it, and captures what the player would see.

Two other surfaces are out of scope here. `web/index.html` plus `scripts/build-web.sh` is the browser build (no Quit or Fullscreen rows). `devblog/` is the Hugo site (`hugo server --source devblog`). Do not treat either as proof of the window.

Run every command from the repo root. The harness is `.cursor/skills/verify-echoes/scripts/verify-echoes`. Recipes below call it `verify-echoes`.

## Launch

Prerequisites on PATH: `love` 11.5 (`love --version` prints `LOVE 11.5`), `xdotool`, `xwininfo`, `ffmpeg`, and `python3`. `DISPLAY` must already be an X11 server. The harness does not start X and does not install packages.

One command:

```
.cursor/skills/verify-echoes/scripts/verify-echoes launch
```

That runs `scripts/play.sh` with a fresh `XDG_DATA_HOME` under `/tmp/echoes-verify-*`, so the player's real save in `~/.local/share/love/echoes` is untouched. The save identity is `echoes`. A missing `save.txt` is a fresh game: the title menu's first row is `Play`, master volume is 80%, sound effects are 70%, screen shake is On, fullscreen is Off.

Ready is a painted title, not a live process. The command returns when the `ECHOES` window is 960×540 and a client grab is a dark, non-flat frame. It prints:

```
READY pid=<pid> window=<id> title=ECHOES data=<data-dir> save=<data-dir>/love/echoes evidence=<repo>/artifacts/verify-echoes
```

ALSA lines such as `Could not open device` in the love log are normal on a machine with no sound card. The window is still usable. Do not set `SDL_AUDIODRIVER`.

A second `ECHOES` window on the same `DISPLAY` is refused. Two saves can exist (different data directories), but key events go to whichever window is focused, so one driven instance per display is the rule.

Teardown is the cleanup command in Cleanup.

## Doctor

Run this first whenever the window, the save, or focus looks wrong. It is read-only: no keys, no writes.

```
.cursor/skills/verify-echoes/scripts/verify-echoes doctor
```

Exit 0 prints `ok`, then `version: LOVE 11.5 ...`, the pid, `window: <id> ECHOES`, `class: love`, `size: 960x540`, the run's `data` and `save` directories, whether `save.txt` is present, and whether the window is focused. Any other ECHOES window on the display, a different love version, a dead pid, or a data directory that is not this run's fails with `not ok` and a reason. Do not drive a failed doctor.

## Drive

Keys are real X11 keypresses delivered to the focused `ECHOES` window. They are not Lua calls and not `--flow`. The game reads them through `love.keypressed` and `love.keyboard.isDown`, the same path as a player.

```
.cursor/skills/verify-echoes/scripts/verify-echoes key Return
.cursor/skills/verify-echoes/scripts/verify-echoes keydown Right
.cursor/skills/verify-echoes/scripts/verify-echoes keyup Right
.cursor/skills/verify-echoes/scripts/verify-echoes wait 0.7
```

Allowed key names: `Return`, `KP_Enter`, `Escape`, `BackSpace`, `Left`, `Right`, `Up`, `Down`, `space`, `z`, `x`, `k`, `p`, `r`, `c`, `shift`, `a`, `d`, `w`. Each `key` focuses the verification window and waits 0.12s so the 60Hz sim consumes the edge. Holds use `keydown` / `keyup`.

Menu rows on a fresh save, from the top: title is `Play`, `Level select`, `Settings`, `Quit`. Pause is `Resume`, `Restart level`, `Level select`, `Settings`, `Quit game`. Settings is `Master volume`, `Sound effects`, `Screen shake`, `Fullscreen`, `Back`.

Confirm is `Return`, `z`, or `space`. Back is `Escape`. In play, `Escape` and `p` pause. Cast is `x` or `k`. Move is `Left`/`Right` or `a`/`d`. Jump is `z`, `space`, `w`, or `Up` (those also confirm while a menu is open, so do not jump until the level is showing).

An iris covers the screen for about half a second after a scene change and drops input while it is closing. After every confirm or back that changes screens, `wait 0.7` before the next key. Screenshot the client area:

```
.cursor/skills/verify-echoes/scripts/verify-echoes screenshot --path artifacts/verify-echoes/<feature>/<name>.png
```

Use `xwininfo`'s client origin for the grab. `xdotool getwindowgeometry` includes the frame and clips the bottom of the window. The harness already does this. Park the pointer at 0,0 before the grab so it does not cover a row. The window is placed at 80,80 so that point is outside it.

Read the save the game actually wrote:

```
.cursor/skills/verify-echoes/scripts/verify-echoes save-cat --out artifacts/verify-echoes/<feature>/save.txt
```

`no save file` means the player has not changed a setting or cleared a level yet. That string is a valid observation.

Follow `features/README.md`, then the one feature file. Drive every bullet in that file's driving section, including each entry point it lists.

## Evidence

Proof is the player path. Do not call `--selftest`, `--flow`, `--shot`, or scene setters. Those skip the window.

For each step, keep the key command and a screenshot of the resulting screen. A screenshot of only the last screen is not enough. When the step writes a save, keep `save-cat` output next to the screenshots and read it back; do not trust the slider graphic alone.

UI captures are 960×540 PNGs of the client area. The game identity has to be visible in the frame: the `ECHOES` wordmark, a `SETTINGS` / `PAUSED` / `SELECT LEVEL` heading, or the level title `1. Wake`. Record the feature id in the directory name (`artifacts/verify-echoes/settings/`).

Also write `artifacts/verify-echoes/<feature>/transcript.txt` with the commands, their stdout, and their exit codes.

There is no external service to mock. Audio may fail to open on a headless sound device; volume proof is the on-screen percent and the `setting master` line in `save.txt`, not a sound meter. Do not point the game at a fake save directory after launch. The data directory from `READY` is the one doctor prints.

Evidence lives in `artifacts/verify-echoes/`. Cleanup never deletes that directory.

## Cleanup

```
.cursor/skills/verify-echoes/scripts/verify-echoes cleanup
```

This sends TERM, then KILL, only to the pid launch recorded, and only if that pid's command line still contains this repo's `game/` directory. It deletes that run's `/tmp/echoes-verify-*` directory and the current-run state file. It does not delete `artifacts/verify-echoes/`. After cleanup, the screenshots, `save.txt` copy, and transcript must still be on disk. Run cleanup after a failed attempt too, so the next launch is not blocked by a leftover window.

`cleanup` prints `cleaned` and the evidence path. `nothing to clean` means no state file was present.

## Helpers

The only helper is `.cursor/skills/verify-echoes/scripts/verify-echoes`. It must be executable. From the repo root:

| Command | Effect |
| --- | --- |
| `verify-echoes launch` | Start `scripts/play.sh` in a fresh data dir. Print `READY` when the title is painted. |
| `verify-echoes doctor` | Read-only health check. Exit 0 and print `ok` only when this window is worth driving. |
| `verify-echoes key <Key>` | Focus the window and tap one allowed key. |
| `verify-echoes keydown <Key>` / `verify-echoes keyup <Key>` | Hold or release a key. |
| `verify-echoes wait <seconds>` | Sleep. Use `0.7` after a scene change. |
| `verify-echoes screenshot --path <path>` | Write a 960×540 client PNG. A relative path is from the repo root. |
| `verify-echoes save-cat [--out <path>]` | Print `save.txt` or `no save file`. `--out` also copies that text. |
| `verify-echoes cleanup` | Kill the recorded pid and delete the temp data dir. Leave evidence. |

## Maintenance

When menus, bindings, or save lines change, update the feature files with `/maintain-verification-skill` so this map stays the source of truth.
