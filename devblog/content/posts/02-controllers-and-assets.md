---
title: "Controllers, droppable assets, and the raylib question"
description: "Xbox pad support from one binding table, a folder where dropped-in art replaces the procedural kind, and why the game stayed on LÖVE."
part: 2
weight: 2
date: 2026-10-17
commits: ["a72332d"]
cover: "images/02-controls/hints-gamepad.png"
---

My next asks were practical. I wanted it to work with an Xbox controller, and I wanted to be able to swap in real sprites later without touching code. I also asked whether raylib would be a better engine for this.

The controller and the asset folder both made it into the first-build commit, `a72332d`. Rerun for this post, its selftest has 40 checks. That's the 29 from [part 1]({{< relref "01-the-pitch" >}}) plus 11 for the pad, like "pad stick inside deadzone does nothing" and "hint swaps button names for pad".

## Actions, not keys

All input goes through `input.lua`. Game code never asks whether Z is down. It asks whether `jump` is held, and the module answers from a table that lists keys and pad buttons side by side:

```lua
local BINDINGS = {
  left = { keys = { 'left', 'a' }, buttons = { 'dpleft' } },
  right = { keys = { 'right', 'd' }, buttons = { 'dpright' } },
  jump = { keys = { 'z', 'space', 'w', 'up' }, buttons = { 'a' } },
  cast = { keys = { 'x', 'k' }, buttons = { 'x', 'b' } },
  confirm = { keys = { 'z', 'space', 'w', 'up' }, buttons = { 'a', 'start' } },
  restart = { keys = { 'r' }, buttons = { 'back' } },
}
```

That's the version from the first commit. The analog stick has to get past a deadzone of 0.35 before it counts as left or right. A new binding is one more string in a list, and the menus, the HUD hints and the simulation all pick it up.

The pad rumbles a little when you die and when you cast. The module also remembers which device you touched last, so the on-screen text names the buttons you're holding.

{{< pair >}}
{{< figure src="images/02-controls/hints-keyboard.png" caption="Level 1's hint after a key press: \"Arrows move. Jump with Z, Space or Up.\"" >}}
{{< figure src="images/02-controls/hints-gamepad.png" caption="Touch the pad and it reads \"D-pad or stick moves. Jump with A.\"" >}}
{{< /pair >}}

Both shots are from the latest commit, `1b2f9ce`, so they include the HUD from [part 4]({{< relref "04-interface" >}}). The pad shot comes from a small scenario in `devblog/tools/blogscenarios.lua` that marks the pad as the last device before drawing. The swap itself is a short list of phrase pairs in `input.lua`, such as "Arrows move" to "D-pad or stick moves".

## Drop-in art

Procedural drawing is fine for a prototype and no help to someone who wants to paint sprites. So the asset system puts a folder convention on top of it and takes nothing away:

- Put `assets/sprites/<slot>.png` or `assets/sfx/<slot>.ogg` in place, named after a slot. `.wav` and `.mp3` work too.
- A PNG whose width is a multiple of its height is read as a strip of animation frames.
- Any slot with no file keeps the procedural drawing or the generated sound.
- Press <kbd>F5</kbd> to reload while the game runs.

The slots are another registry, in `assets.lua`. Each row gives the art's size, how it animates and where it anchors:

```lua
A.SLOTS = {
  player  = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'faces right; flipped when facing left' },
  echo    = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'tinted cyan and faded by the game' },
  solid   = { kind = 'sprite', size = { 16, 16 }, mode = 'variant', anchor = 'tile', note = 'strip of variants, one picked per cell' },
  -- ...nine more rows for tiles and the three background layers
}
```

The fallback works slot by slot, so an artist can replace just the player and leave everything else. `assets/README.md` lists every slot with its pixel size and anchor point, so nobody has to read Lua to make art for the game. Lighting, glows and the HUD still draw on top, which means a dropped-in sprite gets lit the same way the procedural one does.

The repository has no sprite or sound files yet. Every screenshot on this blog is the procedural fallback.

## Staying on LÖVE

Claude's answer on raylib was no, at least for this project. The game already worked, and a rewrite would have cost real time and bought nothing it needed. LÖVE already had everything the game used: canvases for the lightmap and the pixel-scaled view, blend modes for the glow, generated sound data for the audio, and built-in gamepad mappings for the controller work above.

raylib is the better pick for a web export, for raw speed with a lot of objects on screen, or when the point is to learn or ship C and C++. None of that applied here. [Part 5]({{< relref "05-measuring" >}}) later measured how much headroom the game has on LÖVE, and there was a lot of it.
