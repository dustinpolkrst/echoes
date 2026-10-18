---
title: "The pitch: designing Echoes"
description: "A one-line brief, a ghost that replays your last three seconds, and the data we wrote down before any logic."
part: 1
weight: 1
date: 2026-10-17
commits: ["a72332d"]
cover: "images/01-pitch/first-echo-holding.png"
---

Dustin's whole brief was one line: "build a side scrolling platformer with love2d, be creative with the design." Everything in this post comes from the first build, commit `a72332d`.

{{< figure src="images/01-pitch/title-first-build.png" caption="The first title screen. Just \"press jump\", over a ruin drawn in code with no image files." >}}

## The echo

You play a small amber lantern-spirit. Press <kbd>X</kbd> and a cyan ghost of you appears where you were three seconds ago and does what you did. When the replay runs out it holds still for 4 seconds, then fades. The ghost is solid on top, so you can stand on it, and it carries you while it moves. It also holds down pressure plates, and a held plate keeps its door open. You get 2 at a time.

That turned out to be enough to build puzzles from. A plate you would have to stand on yourself can be held by your past self. A ledge too high for one jump takes two, because the ghost of the first jump is a step.

{{< figure src="images/01-pitch/first-echo-holding.png" caption="First Echo, level 2. The ghost is parked on the plate at the left, so the door further right is only an outline. It's open." >}}

## Writing the data down first

Replays punish loose state, so before any logic we wrote down what the data would look like.

Levels are ASCII maps. `#` is stone, `^` is spikes, `=` is a one-way ledge, and lowercase `a` to `d` are the plates for doors `A` to `D`. Editing a level means editing text, and a level change shows up as a diff you can read.

Every tile kind is a row of flags in one registry, so collision, rendering and lighting don't each grow their own `if kind == 'spike' then ... elseif ...` chain:

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

Collision asks `TILES[c.kind].solid` and the light pass asks for `light`. When three new tiles came along in [part 3]({{< relref "03-three-acts" >}}), each one was mostly a new row here.

The recorder is a ring buffer of 180 frames. The simulation steps at a fixed 1/60 s, so three seconds is always exactly 180 frames, and the same inputs always put you in the same places. A replay is only worth trusting if that holds. Each step overwrites the oldest slot and reuses its table:

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

A cast copies the buffer out, oldest frame first, so nothing you record afterwards can change a ghost that's already walking.

The player and the scenes are state machines. The player is `ground`, `air`, `dead` or `cleared`. Doors are never toggled. Every step, each door looks at whether anything is standing on its plate. A toggled flag can miss an event and drift. A door recomputed from the world every step can't.

{{< figure src="images/01-pitch/stairway-step.png" caption="Stairway, level 3. The ghost hangs where the recorded jump peaked, and the light has used it as a step up to the ledge." >}}

## No image files

The first build has no PNGs and no sound files. Everything is `love.graphics` primitives on a 480x270 canvas scaled up 2x. Behind the level are three parallax layers: ruined arches, hanging chains and vines, and drifting dust. Stone has a bevel and moss on top. The flame leans with your velocity and squashes and stretches. A lightmap canvas darkens the scene and cuts light out around the player, each echo and each torch. Sounds come from `love.sound.newSoundData`, filled one sample at a time.

{{< pair >}}
{{< figure src="images/01-pitch/wake-first-build.png" caption="Wake, 90 frames in, right after the first cast." >}}
{{< figure src="images/01-pitch/two-minds.png" caption="Two Minds, level 4. Both plates held, both doors open." >}}
{{< /pair >}}

## Act one

The first five levels each add one idea:

1. Wake: movement, gaps and spikes.
2. First Echo: a plate and a door.
3. Stairway: an echo of your jump becomes a step.
4. Two Minds: two plates, two doors, two echoes.
5. Ascent: a tall climb that uses all of it.

{{< figure src="images/01-pitch/ascent.png" caption="Ascent. The ghost at the bottom left holds the plate that keeps the tall column's door open while the light climbs." >}}

## A test that plays the game

It's easy to break a platformer without noticing. Change the jump height a little and a ledge three levels away goes out of reach. So the first build also came with a way to check that every level still works.

`love echoes --selftest` runs the simulation with no window. The simulation doesn't know about rendering or the keyboard, so a script can feed it input. Each level has a scripted solution in `solutions.lua`, made of segments like "hold right until x is 202, then jump", and the selftest plays each one to the goal. It also checks the physics directly: jump height, coyote time, spikes, plates, doors, and being carried by an echo. The first build ran 29 checks.

`--shot N` loads a level, plays some scripted input and saves a screenshot. `--shot N F` plays the level's solution for F frames first. Every image on this blog comes from that mode, run against the commit the post is about.
