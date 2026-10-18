---
title: "A simulation that never draws"
description: "The game's code is split by what each part does in the game, and the simulation that replays your echoes never calls LÖVE."
part: 8
weight: 8
date: 2026-10-17
commits: ["7ae145b", "eb0d82c", "0c8fcda", "eccb521"]
cover: "images/01-pitch/wake-first-build.png"
---

Every puzzle in Echoes rests on one promise. A ghost does exactly what you did. That promise is easiest to keep if the code that moves you and your ghosts can't see the screen, the speakers or the clock. This post is about how the game's code is split to keep the simulation that blind, and what the game gets out of it.

## Split by what it does in the game

The game's Lua lives in folders named for what each part is in the game:

```
game/
  main.lua  conf.lua
  world/      the simulation: level.lua, player.lua, echo.lua
  content/    levels.lua and acts/, the maps and hints
  screens/    scenes.lua, menu.lua, progress.lua, transition.lua
  gfx/        render.lua, particles.lua, ui.lua, hud.lua, hudmodel.lua
  platform/   input.lua, save.lua, assets.lua, sfx.lua
  dev/        the tools that play the game without a window
  assets/     optional art and sound overrides
```

`world/` is the rules: tiles, bodies, echoes, plates, doors. `content/` is the twelve, later twenty-two, maps as text. `screens/` is the title, play, pause and the other scenes a player moves between. `gfx/` turns a world into pixels. `platform/` is everything that touches the machine: keys and pads, the save file, art files, sound.

## world/ requires nothing outside itself

The whole `world/` folder has two `require` lines, both in `level.lua`, pointing at `world.player` and `world.echo`. It never calls `love.*`. It uses no random numbers and never reads the clock. A step is a function of the world and one frame of input:

```lua
function M.step(w, input, dt)
  dt = dt or M.DT
  w.events = {}
  w.time = w.time + dt
  -- echoes, crumble stone, doors, then the player
```

`dt` is always 1/60 s. The game loop in `main.lua` turns real time into whole steps with an accumulator, so a slow frame runs two steps and never one long one:

```lua
accumulator = math.min(accumulator + dt, MAX_FRAME)
while accumulator >= DT do
  Scenes.dispatch(Input.navPoll(navState, nil, DT))
  Scenes.update()
  accumulator = accumulator - DT
end
```

That's what makes a recording replayable. Three seconds is always 180 steps, and the same 180 inputs always put you in the same 180 places, at any frame rate.

## Drawing hooks in from outside

The tile registry from [part 1]({{< relref "01-the-pitch" >}}) says what a tile does. It doesn't say how a tile looks:

```lua
-- draw functions are attached by gfx/render.lua so the simulation stays headless.
M.TILES = {
  solid = { solid = true, static = true },
  oneway = { oneway = true, static = true },
  spike = { hurts = true, static = true, rect = { 2, 8, T - 4, 8 }, worldList = 'spikes' },
```

`gfx/render.lua` loads after the simulation and adds the looks onto the same rows:

```lua
TILES.solid.draw = withSlot('solid', proceduralSolid, variantOf)
TILES.oneway.draw = withSlot('oneway', proceduralOneway, variantOf)
TILES.spike.draw = withSlot('spike', proceduralSpike)
```

`withSlot` is where the drop-in art from [part 2]({{< relref "02-controllers-and-assets" >}}) comes in. If `assets/sprites/spike.png` exists, it draws that, and otherwise it runs the procedural spike.

{{< figure src="images/01-pitch/wake-first-build.png" caption="Wake, just after the first cast. To the simulation, the light and its ghost are two 10 by 12 px rectangles. The flame, the cyan glow, the lightmap and the drifting dust are all drawn from outside it." >}}

## The world reports, the screens react

A jump, a landing, a death, a cast, a plate going down, a door opening and a waystone lighting all make a sound, some particles, and sometimes a rumble. The simulation does none of that. It appends an event to a list:

```lua
function World:emit(name, x, y, v)
  self.events[#self.events + 1] = { name = name, x = x, y = y, v = v }
end
```

After each step, the playing scene reads the list and decides what the player sees and hears:

```lua
elseif ev.name == 'cast' then
  Sfx.play('cast', ev.v and 0.8 or 1)
  Input.rumble(0.25, 0.12)
  burst(26, { speed = 70, life = 0.7, drag = 2, color = ev.v and { 0.85, 0.5, 1 } or { 0.4, 0.95, 1 }, glow = true })
```

`ev.v` is true for a cast at a mirror shrine, so a mirrored cast plays a lower note and throws violet sparks instead of cyan. The HUD works the same way from the other direction. `hudmodel.lua` reads the world and returns plain numbers, and `hud.lua` draws them.

## What the game gets out of it

Because nothing in `world/` or `content/` needs a window, the game can play itself with LÖVE's graphics, window and audio switched off:

```lua
if selftest then
  t.window = false
  for _, m in ipairs({ 'graphics', 'window', 'audio', 'sound', 'joystick', 'video', 'touch', 'mouse' }) do
    t.modules[m] = false
  end
end
```

With no drawing, a run of a level is just a loop over `Level.step`, and it's fast. The shortcut search in [part 9]({{< relref "09-shortcuts" >}}) plays 1180 attempts at Other Side in 1.7 seconds. The slack sweeps in [part 7]({{< relref "07-ferry" >}}) replay Ferry hundreds of times with one decision changed each time. Every level design question in the rest of this blog, from "can a person board this ghost" to "does mashing X win", got answered that way.

It also keeps the replay honest. If the simulation could read a frame time or a random number, the ghost would only be roughly what you did. Here it's the same 180 poses, every time.
