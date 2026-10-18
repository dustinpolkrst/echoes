# ECHOES

A side-scrolling puzzle platformer in LÖVE 11.5. You are a small lantern-spirit in a dark, glowing ruin. Press the echo key and a ghost of your last three seconds appears. Echoes are solid on top and press plates, so you can leave yourself behind to hold a door open or to climb on.

## Run

    love echoes

On Windows with the console build, `"C:/Program Files/LOVE/lovec.exe" echoes` prints stdout.

## Controls

| Action | Keys |
| --- | --- |
| Move | Left / Right, or A / D |
| Jump | Z, Space, W or Up (hold for height, release to cut the jump) |
| Cast echo | X or K |
| Restart level | R |
| Pause | Esc or P |
| Menus | Arrows or W/S, Z/Space/Enter to confirm, Esc/Backspace to go back |

Any connected Xbox-style controller also works (hot-plug is fine):

| Action | Gamepad |
| --- | --- |
| Move | D-pad or left stick |
| Jump | A |
| Cast echo | X or B |
| Restart level | Back |
| Pause | Start |
| Menus | D-pad or stick, A confirm, B back |

The pad rumbles lightly on death and on cast. On-screen prompts follow whichever device you used last.

## The echo mechanic

- The game records every simulation step. Casting copies the last 3 seconds (180 frames) into an echo.
- The echo appears where you were 3 seconds ago, replays your movement, then stays frozen at its final pose (where you cast it) for 4 seconds before fading.
- An echo is a one-way platform: you can land on it and ride it as it moves, and you can jump up through it from below.
- Echoes weigh down pressure plates. A door is open only while its plate (same letter) is pressed by you or an echo.
- At most 2 echoes exist. A third cast removes the oldest.

Standing on a plate for 3 seconds before you cast gives an echo that sits on the plate for about 7 seconds. Casting at the peak of a jump leaves a platform in mid-air.

Three kinds of tile change what an echo does:

- Mirror shrine (violet). Cast while touching it and the echo replays reflected about the shrine, so it walks where you did not, through walls included. Mirrored echoes are violet.
- Veil (amber). You walk through it. An echo whose next step would enter it stops right there and stays for 4 seconds, so a veil is where you park a ghost.
- Crumble stone (ochre). Half a second after any body stands on it, you or an echo, it gives way, and it grows back 3 seconds after nothing is left inside it. Echoes replay positions, so a ghost keeps standing where the stone used to be.

## Levels

Act one teaches the echo:

1. Wake: movement, gaps, spikes.
2. First Echo: a plate and a door.
3. Stairway: use an echo of your jump as a step.
4. Two Minds: two plates, two doors, two echoes.
5. Ascent: a tall climb that combines everything.

Act two introduces one tile each:

6. Other Side: a plate in a sealed room, pressed by a reflected echo.
7. Trapdoor: a plate on crumble stone. Cast, then fall; the ghost holds what you could not.
8. Undertow: drop through a veil, cast, and climb the ghost that stopped there.
9. Underfoot: the door is the floor.

Act three combines them:

10. Ferry: a reflection that waited where you waited carries you through a tunnel too low to jump in.
11. Short Memory: an echo starts three seconds back, so the wait before casting decides which side of a veil it begins on.
12. Confluence: the ride, the veil and the sealed plate in one recording.

## Verification

    love echoes --selftest

Runs the simulation headless (no window), prints PASS or FAIL per check, and exits nonzero on any failure. It covers physics, hazards, doors and plates, echo recording and carry, the mirror, veil and crumble tiles, and a scripted solution for every level (`solutions.lua`). For levels 6 to 12 it also proves the naive approach fails (the jump falls short, the door stays shut, the echo parks in the wrong place) and reruns each solution with its timings shifted by three frames, so no level needs frame-perfect play. Levels with a strategy (see `--slack`) must give every human decision at least 30 frames or 24 px of slack.

    love echoes --slack [N] [decision=value ...]

Measures how forgiving a level is. A strategy in `solutions.lua` is a solution written the way a person plays it, with every decision a person has to time or place (how long to wait, where to turn back, when to step off) as a named parameter with a plausible range. The lever sweeps each decision on its own, holding the others at their nominal values, and prints a strip of wins and losses with the width of the winning window around the nominal, in frames or pixels. `N` limits it to one level and `turnX=120` style overrides move the nominal, which is how to read a window as a function of another decision.

    love echoes --shot N

Loads level N (0 is the title), simulates 90 frames of scripted input including an echo cast, and saves `shot_N.png` to the LÖVE save directory (`%APPDATA%/LOVE/echoes` on Windows). The full path is printed. `--shot N F` plays the level's scripted solution for F frames instead.

    love echoes --bench LABEL [--size WxH] [--profile]

Plays the title, pause, level select, an iris-restart loop and every level's scripted solution with vsync off: 120 warmup frames, then 1200 timed frames per scene split into update, draw submission and present, then 300 frames with the GC stopped to count KB allocated per frame. Prints median, p95, p99 and max frame ms, draw calls and allocation per scene, and writes `bench/LABEL_summary.csv` and `bench/LABEL_frames.csv` to the save directory. `--size` runs at another window size; `--profile` adds a per-function ms/frame breakdown (its frame times include the timers' own cost).

    love echoes --diff A.png B.png

Compares two PNGs in the save directory pixel by pixel and writes `B_diff.png` with differing pixels in red. `--shot` seeds the random generators and freezes the menu clock so two runs of the same shot match.

## Screens and saving

Title, pause, level select, settings and the level-clear card share one menu model (`menu.lua`) and are driven by the same actions on keyboard and pad. Progress (cleared levels, best time, fewest deaths) and settings (volumes, screen shake, fullscreen) are saved to `save.txt` in the LÖVE save directory. A missing or corrupt file falls back to defaults. A level unlocks when the previous one is cleared. The window is resizable and the canvas stays integer-scaled.

    love echoes --flow

Drives the real scenes with key events (title, pause, settings, clear card, level select) against an in-memory save. `--shot` also accepts `title`, `pause [N]`, `select [cleared]`, `settings`, `clear [N]` and `transition`.

## Assets

Put PNGs in `assets/sprites` and sounds in `assets/sfx`, named after a slot (`player.png`, `solid.png`, `jump.wav`, and so on), and the game uses them in place of the procedural art and generated sounds. Slots without a file keep the built-in version. `assets/README.md` lists every slot, its pixel size and the strip animation convention.

## Layout

- `conf.lua`, `main.lua`: window, fixed 1/60 step loop, `--selftest` and `--shot` modes.
- `level.lua`: level parsing, tile behavior table, collision, plates and doors, world step.
- `player.lua`: player state machine (`ground`, `air`, `dead`, `cleared`).
- `echo.lua`: ring-buffer recorder and the echo.
- `levels.lua`: the twelve ASCII levels.
- `render.lua`, `particles.lua`, `sfx.lua`, `scenes.lua`: drawing, lighting, effects, sound, menus.
- `assets.lua`: slot registry and loader for the optional files under `assets/`.
- `selftest.lua`, `solutions.lua`: headless checks and the scripted level solutions.
