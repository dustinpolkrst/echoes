---
title: "What's next"
description: "A playtest of the new Ferry and Confluence, slack strategies for the other ten levels, and three pieces of cleanup the code is asking for."
part: 8
weight: 8
date: 2026-10-17
commits: ["1afca9f", "eccb521"]
cover: "images/08-next/select-ferry-next.png"
---

Echoes now has twelve levels in three acts, a full set of menus, saved progress, controller support, and four tools that rerun its claims: `--selftest` (155 checks), `--flow` (33 checks), `--slack`, and `--bench`. Ferry and Confluence were rebuilt around a reflection that waits for you ([part 7]({{< relref "07-ferry" >}})), and the game's files moved into a folder tree ([part 9]({{< relref "09-layout" >}})). This is the list of what is left.

{{< figure src="images/08-next/select-ferry-next.png" caption="Level select at `1b2f9ce` with the first two acts cleared and Ferry next. Ferry has been rebuilt since this frame. The records are seeded test data." >}}

## Put the new Ferry in front of a person

`--slack` says the new Ferry gives a 52-frame boarding window and a 38 px range to turn back in. It measures only the decisions someone wrote into the strategy. It cannot tell whether a person thinks of waiting at the foot of the pedestal, or reads the hint and understands it. The next real test is a person playing Ferry and Confluence cold, with someone watching where they get stuck.

## Give the other ten levels a strategy

Only Ferry and Confluence have a strategy in `game/dev/solutions.lua`, so `--slack` with no level number measures those two and skips the rest. `--slack 1` prints `level 1 "Wake" has no strategy` and exits with an error. The other ten levels are still guarded only by the perturbation check, which [part 7]({{< relref "07-ferry" >}}) showed can pass on a level a person cannot beat. Writing a strategy for each one would put every level under the selftest's rule of at least 30 frames or 24 px per decision.

## Make one table describe each tile

Adding a tile today means editing five places. In `game/world/level.lua`, `LEGEND` maps the map character to a kind and `TILES` holds the kind's behavior flags. `game/gfx/render.lua` attaches the draw function with one line per kind, such as `TILES.veil.draw = withSlot('veil', proceduralVeil)`. `game/platform/assets.lua` has a matching entry in `SLOTS`. The comment at the top of `game/content/levels.lua` lists the characters again.

The goal is one `TILES` entry per tile that also names its character, with `LEGEND` built from it and the render code finding each draw function by kind. The simulation must still require nothing from `gfx/`, so the draw functions stay in `render.lua`.

## Split the two largest files

`game/screens/scenes.lua` is 808 lines and `game/gfx/render.lua` is 770. Both already show where they would split.

`scenes.lua` starts with code every scene shares: the camera that follows the player, the reaction to world events, and the ambient title hall behind the menus. After that it holds seven scenes, one table each: title, playing, pause, level select, settings, level clear, and ending. Level select alone runs about 150 lines of card layout. One file per scene, with the shared code in its own module, would keep each file to one screen.

`render.lua` is already divided by comment headers: sprite slots, tile drawing, level layer, backgrounds, actors, lighting, and frame plumbing. Tile drawing is the largest section, about 320 lines of `procedural*` functions, and it is also where the `TILES` draw functions attach. Moving it into its own file would fit with the single tile table above.

## Check the folder rule

[Part 9]({{< relref "09-layout" >}}) describes the rule that `world/` requires nothing outside itself. Today a person has to remember to check it. A selftest check that reads the `require` lines in `world/` and `content/` would fail the build the first time someone breaks it.
