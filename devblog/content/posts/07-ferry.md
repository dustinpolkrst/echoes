---
title: "Rebuilding Ferry"
description: "Ferry passed every check but could not be beaten by hand, and a redesign widened its 9 to 10 frame boarding window to 52 frames."
part: 7
weight: 7
date: 2026-10-17
commits: ["9591f41", "1b2f9ce", "1afca9f"]
cover: "images/07-ferry/ferry-boarding.png"
---

Level 10 is called Ferry. Between you and the goal is a row of spikes too wide to jump. Past the spikes stands a veil, and near the start stands a mirror shrine. The hint read "Record a walk you can take. Let the reflection take the one you cannot." The first half of this post is Ferry as it was at `1b2f9ce`. The second half is the redesign that replaced it in `1afca9f`.

{{< figure src="images/07-ferry/ferry-start.png" caption="Old Ferry at `1b2f9ce`, 90 frames into the shot mode's generic input. From the left: shrine, spikes, amber veil, goal." >}}

The intended solution is the best idea in the game. Walk right to the shrine, turn back, and walk left a good distance. Then walk right again and cast as you touch the shrine. Your walk to the left, reflected about the shrine, becomes a violet ghost walking right, over the spikes, until the veil stops it. Jump onto the ghost as it passes and it carries you across.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-turn-back.png" caption="Frame 200. The light has turned back and is walking left, recording the walk the reflection will take." >}}
{{< figure src="images/07-ferry/ferry-cast.png" caption="Frame 280, heading back to the shrine. The cast fires on touching it." >}}
{{< /pair >}}

{{< figure src="images/07-ferry/ferry-boarding.png" caption="Frame 340, riding the ghost over the spikes." >}}

{{< figure src="images/07-ferry/ferry-across.png" caption="Frame 420. The ghost stopped at the veil and the light stepped off to the goal." >}}

## Every check passed

Ferry shipped with all three checks from [part 3]({{< relref "03-three-acts" >}}). The scripted solution clears it. A running jump lands in the spikes, as the negative check requires. The perturbation check shifts the solution's timings by 3 frames in five ways, and all five clear.

Then I played it, and I couldn't get past level 10.

## Measuring the window

A probe then measured the window. It swept every jump timing across the strategies a person would naturally try, and recorded which attempts landed on the moving ghost.

Only a 9 to 10 frame window boards the ghost, about 0.16 seconds, and only from one turn-back spot. Turn back a little earlier or later and there's no window at all. So to beat Ferry, you had to find one particular place to turn around, which nothing on screen marks, and then jump inside those 0.16 seconds while judging the speed of a ghost replaying your walk in mirror image.

## Why the perturbation check passed

The scripted solution doesn't search for anything. It already knows the spot:

```lua
['Ferry'] = {
  { 'R', atX(208) }, { 'L', atXLeft(80) }, { 'R', atX(209) }, { 1, 'X' },
  { '-', lastEchoOvertakingRight(8) }, { 'RJ', onLastEcho }, { '-', echoArrived }, { 'R', atX(400) },
},
```

It turns back at exactly x = 80 and starts the jump on the exact frame the ghost comes within 8 pixels. The perturbation check then nudged those timings by 3 frames. Three frames either side of the centre of a 9 to 10 frame window stays inside the window, so every variant cleared. The check measured how much slack the *script* had, and nothing about how much a *person* has. A person starts from a guess, not from the centre.

That lesson applies beyond Ferry. A timing check has to measure a person's slack, not the script's. To know whether a player can find the run at all, you have to model what a person actually varies, like where they turn around and when they react, and measure how much of that space wins.

## Measuring a person's slack

That tool came before the redesign. Commit `1afca9f` adds `--slack`. It reads a strategy from `solutions.lua`, which is a solution written the way a person would play it. Every decision a player has to time or place, such as where to turn back or how long to wait, is a parameter with the range a player might plausibly pick. `--slack` sweeps each parameter over its range, holds the others at their usual values, and prints the run of values that clears the level.

On the old Ferry it measured a 10-frame boarding window, which agrees with the probe. It also showed why that window could never grow. An echo counts as landed on only while your 10 px body overlaps its 10 px body, which is a 20 px span. The old ghost moved at the player's own top speed, 100 px per second or 1.67 px per frame, so it crossed that span in 12 frames. No turn-back spot, spike count or shrine position could get the window past 12 frames, and the target was 30. The level needed a different idea, not a better map.

## The new Ferry

In the new design the ghost stands still while you get on. The shrine sits on a stone pedestal two tiles wide. Walk right until the pedestal wall stops you, and wait there. Then walk away, come back, hop onto the pedestal, and cast while touching the shrine.

The reflection replays your recording mirrored about the shrine. Your wait at the foot of the pedestal becomes a ghost that appears one tile past the pedestal and stands still for as long as you waited. Your walk away becomes its walk to the right, toward the spikes.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-new-wait.png" caption="New Ferry at `1afca9f`, frame 150. The light waits at the foot of the pedestal, where the wall stops it on the same spot every time." >}}
{{< figure src="images/07-ferry/ferry-new-cast.png" caption="Frame 330, just after the cast from the pedestal. The violet reflection stands one tile past it, waiting." >}}
{{< /pair >}}

Step down onto it while it waits. It then walks right through a tunnel two tiles high, over three spike tiles, and parks at the veil. The low ceiling caps every jump at about 24 px, so neither a running jump nor any echo you can stand on clears the spikes. The selftest checks both of those failures.

{{< pair >}}
{{< figure src="images/07-ferry/ferry-boarding.png" caption="Old, at `1b2f9ce`, frame 340. You had to jump onto a ghost that was already moving." >}}
{{< figure src="images/07-ferry/ferry-new-ride.png" caption="New, at `1afca9f`, frame 400. The light stepped onto a ghost that was standing still." >}}
{{< /pair >}}

{{< figure src="images/07-ferry/ferry-new-across.png" caption="Frame 450. The reflection is parked at the veil and the light steps off toward the goal." >}}

## The new boarding window

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

The boarding window, `stepDelay`, went from 10 frames to 52. The turn-back spot, which used to be a single point, is a 38 px range from x = 78 to x = 114. Every other decision gets at least 39 frames or 25 px, except two that are small by design. `footX` is 6 px because the wall pins you to the spot, so there's nothing to aim. `stepHold` is 10 frames because the echo is only 10 px wide and the move it measures is a tap.

Confluence, level 12, opens with the same crossing and got the same pedestal and tunnel. Its sweep shows the same nine windows plus a tenth, `landDelay`, at 132 frames.

The selftest now runs these sweeps for both levels and fails if any decision drops under 30 frames or 24 px, or under the smaller limit a capped decision states. That took it from 149 checks to 155. The scripted solution isn't written by hand anymore either. `solutions.lua` builds it from the strategy's usual values, so the script and the slack numbers can't drift apart.

## What --slack can't measure

`--slack` measures only the decisions someone thought to model. It can't tell whether a person will think of waiting at the foot of a pedestal at all. The new hint says it outright: "A reflection waits as long as you did." Whether that's enough takes a person at the keyboard, and [part 12]({{< relref "12-whats-next" >}}) is about the playtests still to come.

It also changes how to read part 3, which presented the perturbation check as the guard against frame-perfect levels. It is a guard, just a weaker one than it looked. Only Ferry and Confluence have strategies so far, so the other ten levels still have only the perturbation check.
