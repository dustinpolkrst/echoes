---
title: "The pitch: designing Echoes"
description: "One sentence of brief, one mechanic, and the data shapes chosen before any code: a tile registry, a ring buffer, and a selftest that solves every level."
part: 1
weight: 1
date: 2026-10-17
commits: ["a72332d"]
cover: "images/01-pitch/first-echo-holding.png"
---

The whole brief from Dustin was one line: "build a side scrolling platformer with love2d, be creative with the design." Everything else in this post was decided in the first build, which landed as commit `a72332d`.

{{< figure src="images/01-pitch/title-first-build.png" caption="The title screen of the first build. The menu is a single \"press jump\" prompt. The ruin behind it is drawn live, with no image files." >}}

## One mechanic, stated as rules

The idea that won was an echo. You are a small amber lantern-spirit. Press <kbd>X</kbd> and a cyan ghost appears where you were three seconds ago and replays your movement. When the replay ends it holds still for 4 seconds, then fades. Echoes are solid on top, so you can stand on one and it carries you while it moves. They also press pressure plates, and a plate holds its door open. You can have at most 2.

Those rules give a lot of puzzle for very little code. A plate you have to stand on becomes a plate your past self stands on. A jump that is too high becomes two jumps, because the echo of the first one is a step.

{{< figure src="images/01-pitch/first-echo-holding.png" caption="Level 2, First Echo, partway through its scripted solution. The cyan echo sits on the plate at the left. The door further right is drawn as an outline because it is open." >}}

## Data shapes before code

The lead agent wrote down the shapes before writing logic, because a replay mechanic punishes sloppy state.

**Levels are ASCII maps with a legend.** `#` is stone, `^` is spikes, `=` is a one-way ledge, lowercase `a` to `d` are plates and uppercase `A` to `D` are their doors. A level designer edits text, and the diff of a level change is readable.

**Tile behaviour lives in one registry.** Instead of `if kind == 'spike' then ... elseif ...` chains spread across collision, rendering and lighting, every tile kind is a row of flags:

```lua
M.TILES = {
  solid = { solid = true, static = true },
  oneway = { oneway = true, static = true },
  spike = { hurts = true, static = true },
  torch = { light = 64 },
  goal = { light = 78, goal = true },
  plate = { plate = true },
  door = { solid = true, openable = true },
}
```

Collision asks `TILES[c.kind].solid`. The light pass asks for `light`. When three new tiles arrived later ([part 3]({{< relref "03-three-acts" >}})), each one was mostly a new row here.

**The recorder is a ring buffer of 180 frames.** The simulation runs at a fixed step of 1/60 s, so three seconds is always exactly 180 frames, and the same inputs always produce the same positions. That determinism is what makes a replay trustworthy. The recorder overwrites the oldest slot each step and reuses its tables:

```lua
function Echo.record(rec, x, y, facing, state)
  rec.head = rec.head % Echo.FRAMES + 1
  local f = rec.buf[rec.head]
  if not f then
    f = {}
    rec.buf[rec.head] = f
  end
  f.x, f.y, f.facing, f.state = x, y, facing, state
  rec.count = math.min(rec.count + 1, Echo.FRAMES)
end
```

Casting takes a snapshot, oldest to newest, and copies each frame so later recording cannot change a ghost that is already walking.

**The player and the scenes are state machines.** The player is `ground`, `air`, `dead` or `cleared`. Doors are never toggled. Every step, each door's open state is recomputed from whether anything stands on its plate. A toggled flag has to be updated by every event that could change it. A value recomputed each step from the world has nothing to fall out of sync with.

{{< figure src="images/01-pitch/stairway-step.png" caption="Level 3, Stairway. The echo hangs in the air where the recorded jump peaked, and the light has used it as a step up to the ledge." >}}

## Art with no image files

The first build has no PNGs and no sound files. Everything is drawn with `love.graphics` primitives on a 480x270 canvas scaled up 2x. There are three parallax layers: ruined arches, hanging chains and vines, and drifting dust. Stone is bevelled with moss on top. The flame leans with your velocity and squashes and stretches. A lightmap canvas darkens the scene and cuts light out around the player, each echo, and each torch. Sounds come from `love.sound.newSoundData`, filled sample by sample.

{{< pair >}}
{{< figure src="images/01-pitch/wake-first-build.png" caption="Level 1, Wake, 90 frames in. The light has just cast its first echo." >}}
{{< figure src="images/01-pitch/two-minds.png" caption="Level 4, Two Minds. Two echoes hold two plates, and both doors stand open." >}}
{{< /pair >}}

## Five levels

The first act teaches the echo one idea at a time:

1. Wake: movement, gaps and spikes.
2. First Echo: a plate and a door.
3. Stairway: an echo of your jump becomes a step.
4. Two Minds: two plates, two doors, two echoes.
5. Ascent: a tall climb that uses all of it.

{{< figure src="images/01-pitch/ascent.png" caption="Level 5, Ascent. The echo at the bottom left holds the plate that keeps the door in the tall column open while the light climbs the ledges." >}}

## A selftest that plays the game

A platformer is easy to break without noticing. A tweak to jump height can make a ledge unreachable three levels away. So the first build also shipped a way to prove the levels still work.

`love echoes --selftest` runs the simulation with no window. Simulation is separate from rendering and from the keyboard, so a script can feed it input. Each level has a scripted solution in `solutions.lua`, written as segments like "hold right until x is 202, then jump", and the selftest plays each one to the goal. It also checks the physics: jump height, coyote time, spikes, plates, doors, echo carry. When the first build was done the selftest ran 29 checks.

A second mode, `--shot N`, loads a level, plays some scripted input, and saves a screenshot. `--shot N F` plays a level's solution for F frames first. Every image on this blog comes from that mode, run against the commit each post describes.

That habit set the tone for the rest of the session. When a claim matters, build the tool that can rerun it.
