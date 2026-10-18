---
title: "Controllers, droppable assets, and the raylib question"
description: "One binding table for keyboard and pad, an asset folder where any missing file falls back to procedural art, and why the game stayed on LÖVE."
part: 2
weight: 2
date: 2026-10-17
commits: ["a72332d"]
cover: "images/02-controls/hints-gamepad.png"
---

The next requests from Dustin were practical ones. The game should work with an Xbox controller. It should be possible to swap the procedural art for real sprites later without touching code. And one question deserved a straight answer. Would raylib be a better engine for this?

The first two landed in the same commit as the first build, `a72332d`. Its selftest runs 40 checks. That is the 29 from [part 1]({{< relref "01-the-pitch" >}}) plus 11 for the pad, such as "pad stick inside deadzone does nothing" and "hint swaps button names for pad". Those counts come from rerunning `--selftest` on that commit for this post.

## One table for both devices

Input goes through one module, `input.lua`. Game code never asks "is Z down?". It asks "is `jump` held?" and the module answers from a binding table that lists keys and pad buttons side by side:

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

That is the first commit's version. The analog stick goes through a deadzone of 0.35 before it counts as left or right. Adding a binding means adding a string to a list, and the menus, the HUD hints, and the simulation all pick it up.

Two small touches make the pad feel supported rather than tolerated. The pad rumbles lightly when you die and when you cast. And the module remembers which device you touched last, so on-screen text names the buttons you are actually holding.

{{< pair >}}
{{< figure src="images/02-controls/hints-keyboard.png" caption="The level 1 hint after keyboard input: \"Arrows move. Jump with Z, Space or Up.\"" >}}
{{< figure src="images/02-controls/hints-gamepad.png" caption="The same hint after pad input: \"D-pad or stick moves. Jump with A.\"" >}}
{{< /pair >}}

Both shots are from the latest commit, `1b2f9ce`, so they include the HUD from [part 4]({{< relref "04-interface" >}}). The pad version comes from a small scenario in `devblog/tools/blogscenarios.lua` that marks the pad as the last device before drawing. The hint swap itself is a short list of phrase pairs in `input.lua`, such as "Arrows move" to "D-pad or stick moves".

## Assets you can drop in

The game draws everything procedurally, which is fine for a prototype and limiting for anyone who wants to paint sprites. The asset system adds a folder convention on top without taking anything away:

- Put `assets/sprites/<slot>.png` or `assets/sfx/<slot>.ogg` (or `.wav`, `.mp3`) in place, named after a slot.
- A PNG whose width is a multiple of its height is read as a strip of animation frames.
- Any slot with no file keeps the procedural drawing or the generated sound.
- Press <kbd>F5</kbd> to reload while the game runs.

The slots are another registry, in `assets.lua`. Each row says how big the art is, how it animates, and where it anchors:

```lua
A.SLOTS = {
  player  = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'faces right; flipped when facing left' },
  echo    = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'tinted cyan and faded by the game' },
  solid   = { kind = 'sprite', size = { 16, 16 }, mode = 'variant', anchor = 'tile', note = 'strip of variants, one picked per cell' },
  -- ...nine more rows for tiles and the three background layers
}
```

Because the fallback is per slot, an artist can replace only the player and leave the rest. `assets/README.md` lists every slot with its pixel size and anchor point, so nobody has to read Lua to make art for the game. Lighting, glows and the HUD still draw on top, so a dropped-in sprite is lit the same way the procedural one is.

The repository has no sprite or sound files yet, so every screenshot on this blog shows the procedural fallback.

## Would raylib be better?

The director asked whether raylib would be a better choice. The answer was no, for this project, and the reasons were specific:

- **The rewrite cost is real and buys nothing yet.** The game already worked, and everything it needed was in hand.
- **LÖVE already covers what the game uses.** Canvases for the lightmap and the pixel-scaled view, blend modes for the glow, generated sound data for the procedural audio, and built-in gamepad mappings for the controller work above.
- **raylib wins in other situations.** It is a better fit for a web export, for raw speed with very many objects on screen, or when the goal is to learn or ship C and C++.

None of those applied. [Part 5]({{< relref "05-measuring" >}}) later measured how much headroom the game has on LÖVE, which made the call look better in hindsight than it needed to.
