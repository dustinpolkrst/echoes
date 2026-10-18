---
title: "About the game"
description: "What Echoes is, how to play it, and how an echo behaves."
---

Echoes is a puzzle platformer for LÖVE 11.5. You are a small lantern-spirit in a ruin lit by hanging torches. You can't jump very high and you can't cross wide pits. What you can do is remember.

{{< figure src="images/07-ferry/ferry-new-ride.png" caption="Level 10, Ferry. The light rides a violet, mirrored echo over spikes it could never jump." >}}

## Run it

With LÖVE 11.5 installed, run the play script from the repository root:

```
scripts\play.cmd        (Windows)
scripts/play.sh         (macOS, Linux)
```

LÖVE loads the `game/` folder, so `love game` from the repository root works too. On Windows, `"C:/Program Files/LOVE/lovec.exe" game` also prints the console output.

## Controls

Keyboard and an Xbox-style controller drive the same actions, and you can plug the controller in at any time. On-screen hints switch to button names once you touch the pad.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | <kbd>Left</kbd> <kbd>Right</kbd> or <kbd>A</kbd> <kbd>D</kbd> | D-pad or left stick |
| Jump (hold for height) | <kbd>Z</kbd>, <kbd>Space</kbd>, <kbd>W</kbd> or <kbd>Up</kbd> | A |
| Cast an echo | <kbd>X</kbd> or <kbd>K</kbd> | X or B |
| Restart the level | <kbd>R</kbd> | Back |
| Pause | <kbd>Esc</kbd> or <kbd>P</kbd> | Start |
| Menus | Arrows or <kbd>W</kbd> <kbd>S</kbd>, <kbd>Z</kbd> <kbd>Space</kbd> <kbd>Enter</kbd> to confirm, <kbd>Esc</kbd> <kbd>Backspace</kbd> to go back | D-pad or stick, A confirm, B back |

The pad gives a light rumble when you die and when you cast.

## The echo

The game records your position every simulation step, 60 times a second. A cast copies the last 3 seconds, which is 180 frames, into an echo.

- The echo appears where you were 3 seconds ago and replays what you did.
- When the replay ends, it stays frozen where you cast it for 4 seconds, then fades.
- An echo is a one-way platform. You can land on it, ride it while it moves, and jump up through it from below.
- An echo weighs down pressure plates. A door is open only while you or an echo stands on its plate, which has the same letter in the level map.
- At most 2 echoes exist. A third cast removes the oldest.

Two tricks fall out of that. Stand on a plate for 3 seconds before you cast and the echo sits on that plate for about 7 seconds. Cast at the top of a jump and you leave a platform in mid-air.

## Tiles that change an echo

The second and third acts add three tiles.

- The mirror shrine is violet. Cast while touching it and the echo replays reflected about the shrine, so it walks where you did not, even through walls. Mirrored echoes are violet too.
- The veil is amber. You walk through it. An echo whose next step would enter it stops there and stays for 4 seconds. A veil is where you park a ghost.
- Crumble stone is ochre. Half a second after anything stands on it, you or an echo, it gives way. It grows back 3 seconds after nothing is left inside it. An echo replays positions, so it keeps standing where the stone used to be.

## The twelve levels

| Act | Levels |
| --- | --- |
| I. Learning the echo | 1 Wake, 2 First Echo, 3 Stairway, 4 Two Minds, 5 Ascent |
| II. One new tile each | 6 Other Side, 7 Trapdoor, 8 Undertow, 9 Underfoot |
| III. Combinations | 10 Ferry, 11 Short Memory, 12 Confluence |

Progress, best times and fewest deaths save to `save.txt` in the LÖVE save directory. Clearing a level unlocks the next one.
