---
title: "When the tests pass and the level is still impossible"
description: "Ferry passed its solution check, its negative check, and its perturbation check. A person could not reliably beat it. A probe found a 9 to 10 frame window from one spot. A redesign and a tool that measures human slack widened it to 52 frames."
part: 7
weight: 7
date: 2026-10-17
commits: ["9591f41", "1b2f9ce", "1afca9f"]
cover: "images/07-ferry/ferry-boarding.png"
---

Level 10 is called Ferry. The first half of this post shows it as it was at `1b2f9ce`, and the second half shows the redesign that replaced it in `1afca9f`. Its hint read "Record a walk you can take. Let the reflection take the one you cannot." Between you and the goal is a row of spikes too wide to jump. Beyond the spikes stands a veil. Near the start stands a mirror shrine.

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

## A tool that measures a person's slack

The fix started with the tool the last section asks for. Commit `1afca9f` adds `--slack`. It reads a strategy from `solutions.lua`, which is a solution written as a person would play it. Every decision a person has to time or place, such as where to turn back or how long to wait, is a parameter with the range a player might plausibly pick. `--slack` sweeps each parameter over that range, holds the others at their usual values, and prints the run of values that clears the level.

Pointed at the old Ferry, it measured a 10-frame boarding window, which agrees with the probe. The tool also showed why the window could not grow. An echo counts as landed on only while your 10 px body overlaps its 10 px body, which is a 20 px span. The old ghost moved at the player's own top speed, 100 px per second or 1.67 px per frame, so it crossed that span in 12 frames. No turn-back spot, spike count, or shrine position could widen the window past 12 frames, and the target was 30. The level needed a different idea, not a better map.

## The new Ferry

In the new design the ghost stands still while you board it. The shrine now sits on a stone pedestal two tiles wide. Walk right until the pedestal wall stops you, and wait there. Then walk away, come back, hop onto the pedestal, and cast while touching the shrine.

The reflection replays your recording mirrored about the shrine. Your wait at the foot of the pedestal becomes a reflection that spawns one tile past the pedestal and stands still for as long as you waited. Your walk away becomes its walk to the right, toward the spikes.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-new-wait.png" caption="Ferry at `1afca9f`, frame 150 of the scripted solution. The light waits at the foot of the pedestal. The wall stops it on the same spot every time." >}}
{{< figure src="images/07-ferry/ferry-new-cast.png" caption="Frame 330. The light has cast from the shrine on the pedestal. The violet reflection stands still one tile past the pedestal, waiting." >}}
{{< /pair >}}

Step down onto it while it waits. It then walks right through a tunnel two tiles high, over three spike tiles, and parks at the veil. The low ceiling caps every jump at about 24 px, so neither a running jump nor any echo you can stand on clears the spikes. The selftest checks both of those failures.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-boarding.png" caption="Before, at `1b2f9ce`, frame 340. Boarding meant jumping onto a ghost that was already moving." >}}
{{< figure src="images/07-ferry/ferry-new-ride.png" caption="After, at `1afca9f`, frame 400. The light stepped onto a ghost that was standing still, and now rides it over the spikes." >}}
{{< /pair >}}

{{< figure src="images/07-ferry/ferry-new-across.png" caption="Frame 450. The reflection has parked at the veil and the light has stepped off toward the goal." >}}

## The new window, measured

Here is `love game --slack 10` at `eccb521`. Each strip is one sweep. A `#` is a value that clears the level and a `.` is one that fails. The window is the run of `#` that contains the usual value.

```
level 10 "Ferry": nominal wins
  footX      nominal 166  range 130..166 step 2  window 6 px (162..166)  (the pedestal wall stops you here)
  ................###
  idle       nominal 120  range 0..240 step 4  window 212 frames (32..240)
  ........#####################################################
  turnX      nominal 104  range 30..178 step 2  window 38 px (78..114)
  ........................###################................................
  hopX       nominal 130  range 60..180 step 2  window 64 px (104..166)
  ......................################################.......
  hopHold    nominal 6    range 1..40 step 1  window 39 frames (2..40)
  .#######################################
  castX      nominal 190  range 160..210 step 1  window 25 px (177..201)
  .................#########################.........
  castDelay  nominal 10   range 0..150 step 2  window 42 frames (0..40)
  #####################.......................................................
  stepDelay  nominal 20   range 0..200 step 2  window 52 frames (0..50)
  ##########################...........................................................................
  stepHold   nominal 3    range 0..30 step 1  window 10 frames (0..9)  (a tap; the echo is 10 px wide)
  ##########.....................
```

The boarding window, `stepDelay`, is now 52 frames instead of 10. The turn-back spot that used to be a single point is a 38 px range, from x = 78 to x = 114. Every other decision has at least 39 frames or 25 px, except two that are small by design. `footX` is 6 px because the wall pins you to the spot, so there is nothing to aim. `stepHold` is 10 frames because the echo is only 10 px wide, and the move it measures is a tap.

Confluence, level 12, opens with the same crossing and got the same pedestal and tunnel. Its sweep shows the same nine windows plus a tenth, `landDelay`, at 132 frames.

The selftest now runs these sweeps for both levels and fails if any decision drops under 30 frames or 24 px, or under the smaller limit a capped decision states. It went from 149 checks to 155. The scripted solution is no longer written by hand either. `solutions.lua` builds it from the strategy's usual values, so the script and the slack measurement cannot drift apart.

## What this does not prove

`--slack` measures the decisions someone thought to model. It cannot tell whether a person will think of waiting at the foot of a pedestal at all. The new hint says so directly: "A reflection waits as long as you did." Whether that is enough is a question only a person at the keyboard can answer, and that playtest is the first item in [part 9]({{< relref "09-whats-next" >}}).

The other honest note is about the earlier parts of this blog. Part 3 presented the perturbation check as the guard against frame-perfect levels. It is a guard, but a weaker one than it looked, and Ferry is the level that showed the difference. Only Ferry and Confluence have strategies so far, so the other ten levels are still guarded only by the perturbation check.
