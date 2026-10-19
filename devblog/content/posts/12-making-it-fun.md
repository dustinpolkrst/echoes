---
title: "Rewind, a trail and an ember in every level"
description: "Echoes played well and wasn't fun. Seeing an echo before casting it, rewinding a mistake and an optional ember per level are the changes that came out of asking why."
part: 12
weight: 12
date: 2026-10-18
commits: ["9584767", "4d85699"]
cover: "images/12-fun/trail-shrine.png"
---

With 22 levels done, Echoes looked right and controlled well. Playing it from the start, it still wasn't much fun. The puzzles were fair and every one was solvable, but solving them felt more like work than discovery. This post is about why, and the four changes that came out of it.

## Why it wasn't fun

Games built on recording and replaying yourself have a known failure. Joel Goodwin's essay [I hate playing with myself](https://www.electrondance.com/i-hate-playing-with-myself/) lists it well. Once a recording is made you can't adjust it. One early slip ruins everything after it. Recording the sequence again is slow, which is an odd cost for a mechanic about time. The games he likes in the genre let you rewind and try things cheaply.

Echoes had all three problems:

- **You planned blind.** An echo replays your last three seconds, but nothing on screen showed what those three seconds were or where the ghost would appear. You found out by casting, so you learned what a cast did by failing first.
- **A mistake cost a whole retry.** A missed jump meant dying, waiting for the respawn, walking back, and then waiting three seconds for the memory to fill before the next cast.
- **The hard part was often timing, not insight.** The later levels pass the 30-frame rule from [part 7]({{< relref "07-ferry" >}}), but "cast within this window" still asks for execution. Celeste handles this kind of difficulty with what Maddy Thorson calls [forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html): small fudges that widen every timing window in the player's favour.

One more problem had nothing to do with echoes. Levels unlocked strictly in order, so getting stuck on one level meant getting stuck on the whole game.

I didn't change the jump. Every measured window, every naive check and every scripted solution in the game depends on the jump arc. The changes below leave the simulation's rules alone and change what the player can see and undo.

## Seeing the echo before you cast it

The game already records your position every step. Now it draws that recording. Dots trace the path an echo cast right now would walk, getting brighter toward the present, and a faint ghost stands where the echo would appear.

{{< figure src="images/12-fun/trail-first-echo.png" caption="First Echo, standing on the plate. The dots run back along the walk from the start, and the faint ghost at the far left is where a cast now would begin." >}}

The preview follows the same rules the echo does. At a mirror shrine it draws the reflection, and it stops at a veil, because an echo halts there. Here is the part of `drawMemoryTrail` in `game/gfx/render.lua` that does both:

```lua
  local mirror = world:touchedMirror()
  local axis = mirror and mirror.tx * T + T / 2
  local function at(k)
    local f = rec.buf[(rec.head - rec.count + k - 1) % Echo.FRAMES + 1]
    if not axis then return f end
    return { x = 2 * axis - f.x - Echo.W, y = f.y, facing = -f.facing }
  end
  for k = 1, rec.count - TRAIL_STEP, TRAIL_STEP do
    local f = at(k)
    if world:inVeil(f.x, f.y, Echo.W, Echo.H) then
      trailDot(f.x, f.y, 2, 0.4, pal.edge)
      break
    end
```

The mirror formula is the same one `Echo.mirror` uses when a cast happens, so the preview can't disagree with the cast.

{{< figure src="images/12-fun/trail-shrine.png" caption="Ferry, standing on the shrine with a full memory. The violet ghost past the pedestal is where the reflection would start waiting. Before this, you had to cast to find out." >}}

A cast echo also shows the rest of its route as dots, ending in a brighter dot where it will stop. That answers the other blind question: where is that ghost going?

{{< figure src="images/12-fun/trail-ascent.png" caption="Ascent. The cyan ghost on the floor has a route of dots ahead of it, so you can see where it will be before you commit to a jump." >}}

The trail is drawn after the lighting pass. In the first version it was drawn with the rest of the world, the darkness was multiplied over it, and it was almost invisible.

## Rewind

Hold C or Shift, or Y or a shoulder button on a pad, and the world runs backwards. Rewinding speeds up the longer you hold it, from 1x to 2x after 1.2 seconds and 4x after 2.5 seconds. It goes back up to 30 seconds. It also works after a death: the death screen now waits a little longer and says how.

{{< pair >}}
{{< figure src="images/12-fun/death-prompt.png" caption="Falling into Wake's first pit. The prompt offers rewind or a retry from the last waystone." >}}
{{< figure src="images/12-fun/rewind-ascent.png" caption="Rewinding in Ascent. The tint and the arrows mark it, and the number is how much history is left." >}}
{{< /pair >}}

Rewinding means putting the world back exactly as it was, so the first job was saying what "the world" is. Tiles, lights and the map never change after load. What a step can change is a short list: the player, the echoes, the recorder, crumble stone, plates, doors, the lit waystone and the clock. `World:save` in `game/world/level.lua` captures exactly that:

```lua
  return {
    player = p, supportAt = supportAt, echoes = echoes, rec = Echo.copyRecorder(self.rec),
    crumbles = crumbles, plates = plates, embers = embers, doors = doors,
    respawn = self.respawn, time = self.time, castPrev = self.castPrev,
  }
```

Saving every step only works because most of the data can be shared instead of copied. An echo's frames never change after the cast, and the recorder now writes a new table for each frame instead of reusing one. So a saved state holds references to frames, not copies. That needed one fix. When an echo halted at a veil, the old code moved the frame it stopped on to the exact contact point, which changed the frame in place. The halt point now lives on the echo as `stopX` and `stopY`.

`game/world/timeline.lua` keeps a ring of saved states, one per step, and drops the oldest past 30 seconds. Stepping back is three lines:

```lua
function Timeline.back(tl, world)
  if tl.last <= tl.first then return false end
  tl.states[tl.last] = nil
  tl.last = tl.last - 1
  world:load(tl.states[tl.last])
  return true
end
```

Saving costs 4 to 8 microseconds a step, measured on Underfoot, Ferryman's Toll and The Last Light, against a frame of 16.7 milliseconds. A full 30 seconds of history on The Last Light holds about 9 MB.

Rewind can't be used to cheat. It puts back a state you already reached by playing, echoes and all, so it only ever lands you somewhere the rules allowed. The level clock keeps counting forward while you rewind, so best times stay honest.

The check for rewind is the strongest test in the game. For every level, the selftest plays the scripted solution, rewinds up to 600 steps, replays the same inputs, and requires the end state to match exactly. To make sure it can fail, I broke the crumble restore on purpose, and Let Go's check failed.

A playing-scene test caught a bug of its own. Holding rewind with no history left let the world step forward one frame and back the next, and holding a direction at the same time made the player creep. Now rewind holds the world still once its history runs out.

## An ember in every level

Clearing a level was the only goal, so a level had nothing more to offer once you'd beaten it. Celeste's strawberries and Braid's puzzle pieces are optional goals that ask more of a level from a player who wants more. Echoes now has embers, one per level, written `*` in a map.

{{< figure src="images/12-fun/ember-wake.png" caption="Wake's ember hangs just above the spot where you start. The main route runs right and never jumps there." >}}

You take an ember by passing through it, and so does any echo. That one rule makes most of them puzzles, because an echo can go where you can't. Here is `touchEmbers` in `game/world/level.lua`:

```lua
function World:touchEmbers()
  for _, c in ipairs(self.embers) do
    if not c.taken then
      for _, b in ipairs(self:bodies()) do
        if overlaps(b, c.rect) then
          c.taken = true
          self:emit('ember', c.tx * T + T / 2, c.ty * T + T / 2, b ~= self.player)
          break
        end
      end
    end
  end
end
```

Each ember asks one more question of its own level's idea. In Undertow, the veil stops your echo where you fell through it. The question is where you have to fall so the echo lifts you to the ember and still gets you home. In Hall of Mirrors, the ember floats over a spike pit. You hop on the roof and cast at the far shrine, and the reflection of your hop rises over the pit and takes it.

{{< pair >}}
{{< figure src="images/12-fun/ember-undertow.png" caption="Undertow. The echo stopped where the light fell through the veil, and the light jumps from it to the ember." >}}
{{< figure src="images/12-fun/ember-hall.png" caption="Hall of Mirrors. The violet reflection of a hop on the roof rises over the pit and takes the ember." >}}
{{< /pair >}}

Three levels needed a little geometry for their ember. In Undercroft, Ferryman's Toll and The Last Light, an enclosed rock cell became the ember, which only a reflection can reach. Crawlspace and Let Go each got a one-cell niche in the ceiling. The shortcut search from [part 9]({{< relref "09-shortcuts" >}}) found nothing new in any of them.

An ember counts once you clear the level carrying it. The first version also kept a taken ember through a death, and that turned out to be a hole. Any ember you could touch on the way to dying was free. Clockwork's first ember spot failed exactly that way and had to move. The rule now is closer to Celeste's: an ember survives a death only if you lit a waystone while carrying it. The playing scene banks it when that happens:

```lua
    for _, ev in ipairs(world.events) do
      if ev.name == 'checkpoint' and world:emberTaken() then playing.emberBanked = true end
    end
```

The level select marks each level's ember, filled once found. The title counts them, and the clear card says whether you carried one out.

{{< pair >}}
{{< figure src="images/12-fun/ember-clear.png" caption="Two Minds cleared with its ember, which asks whether the two echoes that hold the doors can also stand one on the other." >}}
{{< figure src="images/12-fun/select-embers.png" caption="The level select with sample records. Found embers are filled, and levels 7 and 8 are both open." >}}
{{< /pair >}}

The selftest proves three things for every level. It has exactly one ember, the main solution leaves it in place, and a scripted ember route takes it and then clears the level. A one-line comment above each route states the question that ember asks.

## Clearing one level opens two

The second picture above shows the last change. Levels 7 and 8 are both open after clearing 6. `Progress.unlocked` in `game/screens/progress.lua` now reads:

```lua
function Progress.unlocked(data, i)
  return i <= 1 or Progress.done(data, i - 1) or (i > 2 and Progress.done(data, i - 2))
end
```

You can skip one level you're stuck on and come back to it. You can't skip two in a row, so the acts still teach in order.

## What's not settled

No one has played these changes yet. Some ember routes are tighter than the 30-frame, 24 px rule. Those are the standing jumps in Other Side, Short Memory, Relay and Clockwork, and the wall hop in Ferry. They're optional, which is why I let them through, but they're the first thing to watch in a playtest. Underfoot's ember is the weakest idea of the 22. Several act IV and V embers use the same move, standing on your own ghost to reach higher, because their corridors are three tiles tall and nothing else gets you higher than a jump. [Part 13]({{< relref "13-whats-next" >}}) lists these with the rest.
