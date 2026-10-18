---
title: "Next: playtests and cleanup"
description: "Acts IV and V need people to play them, a few weak spots and a door-drawing bug are known, and the code shows where the cleanup should go."
part: 12
weight: 12
date: 2026-10-18
commits: ["37c1380"]
cover: "images/11-act-five/select-five-acts.png"
---

Echoes now has 22 levels in five acts, waystones in every long level, menus, saved progress and controller support. Five tools rerun its claims: `--selftest` with 369 checks, `--flow` with 37, `--slack`, `--cheese`, and `--bench`. Here's what's left.

{{< figure src="images/11-act-five/select-five-acts.png" caption="Level select at `37c1380`. The records are seeded test data." >}}

## Put acts IV and V in front of people

Every room in acts IV and V passes its solve, its naives, `--slack` and `--cheese`. None of those tools can say whether a person sees the insight from the waystone, or reads the hint and gets it. The last step in the doc's checklist for a new level is one no tool runs. Play it with a pad, from the title, through every waystone, dying once per room on purpose. The real test is someone playing all ten levels cold while someone else watches where they get stuck.

## Draw each door where it is

Taking the screenshots for [part 10]({{< relref "10-act-four" >}}) and [part 11]({{< relref "11-act-five" >}}) turned up a drawing bug. `drawDoor` in `game/gfx/render.lua` draws one slab per door letter, over the bounding box of every cell with that letter. That worked while each letter was one door. Seven levels now use a letter in two or more places, levels 11, 13 and 18 to 22. Let Go's door A is in six. On those levels the slab spans everything between the pieces and covers the floors under it. A door that stands upright is drawn only in the column of its first piece, so the other pieces don't show at all.

{{< figure src="images/12-next/door-slabs.png" caption="Three Steps Behind at `37c1380`, frame 760. The striped panels with magenta and yellow edges are the slabs for hatches B and C, each drawn from one hatch to its twin far away. The corridors and floors under them are hidden." >}}

Collision reads the cells, not the slab, so the levels play as tested. But a person playtesting them sees doors where there are none and floors that aren't drawn, so the fix comes before the playtests. Each connected group of cells needs its own slab. The overlapping slabs also make this shot vary between runs. In four renders of this frame, one differed from the other three in 7,348 pixels.

## Close the weak spots the doc names

The doc records each known weakness next to the level it's in:

- **Let Go.** A blind route that waits at the gate's edge for the ghost on a to fade and walks straight through has a 24-frame window in every room, under the 30-frame bar. In rooms 2 and 3 the gate and exit door are 21 and 23 tiles from the waystone, past the first screen.
- **Plumb Line.** In The Well, a masher at the bottom wins with one cast 122 to 168 frames after landing. It's accepted because The Well is the teach room and the winning ghost is the intended one.
- **Ferryman's Toll and The Last Light.** The tap that steps onto the ferry has 7 frames on Ferryman's Toll, with a declared need of 6. On both levels the need is justified the same way as level 10's, because the ghost is only 10 px wide.
- **Clockwork.** The doors of the first room are three tiles beyond the first screen, so the player sees them only after three steps.

Each one is either a fix to try or a decision to confirm in the playtests.

## Make one table describe each tile

Adding a tile still means editing five places. The waystone, commit `79ff197`, shows it. In `game/world/level.lua`, `LEGEND` maps `w` to the kind `checkpoint` and `TILES` holds its flags. `game/gfx/render.lua` attaches the draw function with `TILES.checkpoint.draw = withSlot('checkpoint', proceduralCheckpoint, ...)`. `game/platform/assets.lua` has matching entries in `SLOTS`. And the comment at the top of `game/content/levels.lua` lists the characters again.

The plan is one `TILES` entry per tile that also names its character, with `LEGEND` built from it and the render code finding each draw function by kind. The simulation still must not require anything from `gfx/`, so the draw functions stay in `render.lua`.

## Split the two largest files

`game/screens/scenes.lua` is now 824 lines and `game/gfx/render.lua` is 812. Both already show where they would split.

`scenes.lua` opens with code every scene shares: the camera that follows the player, the reaction to world events, and the ambient title hall behind the menus. After that come seven scenes, one table each: title, playing, pause, level select, settings, level clear, and ending. One file per scene, with the shared code in its own module, would keep each file to one screen.

`render.lua` is already divided by comment headers into sprite slots, tile drawing, level layer, backgrounds, actors, lighting, and frame plumbing. Tile drawing is the biggest section, about 360 lines, and it's where the `TILES` draw functions attach and where `drawDoor` lives. Moving it into its own file fits with the single tile table above.

## Check the folder rule

[Part 8]({{< relref "08-layout" >}}) describes the rule that `world/` requires nothing outside itself. It still holds at `37c1380`, where the only two `require` lines in `game/world` point at `world.player` and `world.echo`. Today someone has to remember to check it. A selftest check that reads the `require` lines in `world/` and `content/` would fail the first time someone breaks it.
