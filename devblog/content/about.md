---
title: "About the game"
description: "What Echoes is, how to play it, and how an echo behaves."
---

Echoes is a puzzle platformer for LÖVE 11.5. You are a small lantern-spirit in a ruin lit by hanging torches. You cannot jump very high and you cannot cross wide pits. What you can do is remember.

{{< figure src="images/07-ferry/ferry-boarding.png" caption="Level 10, Ferry. The light rides a violet, mirrored echo across a row of spikes it could not jump." >}}

## Run it

With LÖVE installed, run the game folder:

```
love echoes
```

On Windows, `"C:/Program Files/LOVE/lovec.exe" echoes` also prints the console output.

## Controls

The keyboard and an Xbox-style controller drive the same actions. A controller can be plugged in at any time. On-screen hints switch to button names when you last touched the pad.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | <kbd>Left</kbd> <kbd>Right</kbd> or <kbd>A</kbd> <kbd>D</kbd> | D-pad or left stick |
| Jump (hold for height) | <kbd>Z</kbd>, <kbd>Space</kbd>, <kbd>W</kbd> or <kbd>Up</kbd> | A |
| Cast an echo | <kbd>X</kbd> or <kbd>K</kbd> | X or B |
| Restart the level | <kbd>R</kbd> | Back |
| Pause | <kbd>Esc</kbd> or <kbd>P</kbd> | Start |
| Menus | Arrows or <kbd>W</kbd> <kbd>S</kbd>, <kbd>Z</kbd> <kbd>Space</kbd> <kbd>Enter</kbd> to confirm, <kbd>Esc</kbd> <kbd>Backspace</kbd> to go back | D-pad or stick, A confirm, B back |

The pad rumbles lightly when you die and when you cast.

## The echo

The game records your position every simulation step, 60 times a second. Casting copies the last 3 seconds, which is 180 frames, into an echo.

- The echo appears where you were 3 seconds ago and replays what you did.
- When the replay ends, it stays frozen at the spot where you cast it for 4 seconds, then fades.
- An echo is a one-way platform. You can land on it, ride it while it moves, and jump up through it from below.
- An echo weighs down pressure plates. A door is open only while its plate (the same letter in the level map) is pressed by you or by an echo.
- At most 2 echoes exist. A third cast removes the oldest.

Two tricks follow from those rules. If you stand on a plate for 3 seconds before you cast, the echo sits on that plate for about 7 seconds. If you cast at the top of a jump, you leave a platform in mid-air.

## Tiles that change an echo

The second and third acts add three tiles.

- **Mirror shrine (violet).** Cast while touching it and the echo replays reflected about the shrine, so it walks where you did not, even through walls. Mirrored echoes are violet.
- **Veil (amber).** You walk through it. An echo whose next step would enter it stops there and stays for 4 seconds. A veil is where you park a ghost.
- **Crumble stone (ochre).** Half a second after anything stands on it, you or an echo, it gives way. It grows back 3 seconds after nothing is left inside it. An echo replays positions, so it keeps standing where the stone used to be.

## The twelve levels

| Act | Levels |
| --- | --- |
| I. Learning the echo | 1 Wake, 2 First Echo, 3 Stairway, 4 Two Minds, 5 Ascent |
| II. One new tile each | 6 Other Side, 7 Trapdoor, 8 Undertow, 9 Underfoot |
| III. Combinations | 10 Ferry, 11 Short Memory, 12 Confluence |

Progress, best times, and fewest deaths save to `save.txt` in the LÖVE save directory. A level unlocks when you clear the one before it.
