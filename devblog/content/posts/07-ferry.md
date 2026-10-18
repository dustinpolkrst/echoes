---
title: "When the tests pass and the level is still impossible"
description: "Ferry passed its solution check, its negative check, and its perturbation check. A person could not reliably beat it. A probe found a 9 to 10 frame window from one spot."
part: 7
weight: 7
date: 2026-10-17
commits: ["9591f41", "1b2f9ce"]
cover: "images/07-ferry/ferry-boarding.png"
---

Level 10 is called Ferry. Its hint reads "Record a walk you can take. Let the reflection take the one you cannot." Between you and the goal is a row of spikes too wide to jump. Beyond the spikes stands a veil. Near the start stands a mirror shrine.

{{< figure src="images/07-ferry/ferry-start.png" caption="Ferry at `1b2f9ce`, 90 frames into the shot mode's generic input. Left to right: the shrine, the spikes, the amber veil, and the goal." >}}

The intended solution is the best idea in the game. Walk right to the shrine, turn back, and walk left a good distance. Then walk right again and cast as you touch the shrine. The recording of your walk left, reflected about the shrine, becomes a violet ghost walking right, over the spikes, until the veil stops it. Jump onto the ghost as it passes and it carries you across.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-turn-back.png" caption="Frame 200 of the scripted solution. The light has turned back and walked left, recording the walk the reflection will take." >}}
{{< figure src="images/07-ferry/ferry-cast.png" caption="Frame 280. The light walks back to the shrine. The cast happens on touching it." >}}
{{< /pair >}}

{{< figure src="images/07-ferry/ferry-boarding.png" caption="Frame 340. The light rides the mirrored echo over the spikes." >}}

{{< figure src="images/07-ferry/ferry-across.png" caption="Frame 420. The echo has stopped at the veil and the light has stepped off it to the goal." >}}

## Every check passed

Ferry shipped with the three checks from [part 3]({{< relref "03-three-acts" >}}). The scripted solution clears it. The negative check confirms that a running jump lands in the spikes. The perturbation check reruns the solution with its timings shifted by 3 frames in five ways, and all five clear.

Then Dustin played it and reported that level 10 seems impossible.

## Measuring the window

Instead of debating how hard the level felt, the next step was to measure it. A probe swept every jump timing across the strategies a person would naturally try, and recorded which attempts landed on the moving mirrored ghost.

Only a 9 to 10 frame window boards the ghost, about 0.16 seconds, and only from one turn-back spot. Turn back a little earlier or later and there is no window at all. To beat Ferry, a player has to find one specific place to turn around, which nothing on screen marks, and then jump inside that 0.16 seconds, while judging the speed of a ghost that is replaying a walk in mirror image.

## Why the perturbation check passed

The scripted solution does not search for anything. It already knows the exact turn-back spot:

```lua
['Ferry'] = {
  { 'R', atX(208) }, { 'L', atXLeft(80) }, { 'R', atX(209) }, { 1, 'X' },
  { '-', lastEchoOvertakingRight(8) }, { 'RJ', onLastEcho }, { '-', echoArrived }, { 'R', atX(400) },
},
```

It turns back at exactly x = 80, and it starts the jump on the exact frame the ghost comes within 8 pixels. The perturbation check then nudged those timings by 3 frames. A nudge of 3 frames around the centre of a 9 to 10 frame window stays inside the window, so every variant cleared. The check measured how much slack the *script* had. It said nothing about how much slack a *person* has. A person starts from a guess, not from the centre.

The lesson is worth stating plainly, because it applies well beyond this game: **test human slack, not script slack.** A check that perturbs a perfect run tells you the perfect run is not fragile. It does not tell you that an imperfect player can find the run at all. For that you have to model what a person actually varies, such as where they turn around and when they react, and measure how much of that space succeeds.

## What happens next

A redesign of Ferry is in progress, together with a tool that measures human slack directly, so the next version of the level is judged by the size of its success region rather than by whether one script can clear it. At the time of writing nothing from that work has landed on `main`. The level as shown here is still the one in the game.

The other honest note is about the earlier parts of this blog. Part 3 presented the perturbation check as the guard against frame-perfect levels. It is a guard, but a weaker one than it looked, and Ferry is the level that showed the difference.
