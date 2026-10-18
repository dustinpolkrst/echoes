---
title: "Next: playtests and cleanup"
description: "Acts IV and V need people to play them, a few weak spots are known, and adding a tile should touch one table, not five places."
part: 12
weight: 12
date: 2026-10-18
commits: ["37c1380", "df9c112"]
cover: "images/11-act-five/select-five-acts.png"
---

Echoes now has 22 levels in five acts, waystones in every long level, menus, saved progress and controller support. Here's what's left.

{{< figure src="images/11-act-five/select-five-acts.png" caption="All five acts on the level select. The records shown are sample data." >}}

## Put acts IV and V in front of people

Every room in acts IV and V passes its solve, its naives, `--slack` and `--cheese`. None of those tools can say whether a person sees the insight from the waystone, or reads the hint and gets it. That takes playing each level with a pad, from the title, through every waystone, dying once per room on purpose. The real test is someone playing all ten levels cold while someone else watches where they get stuck.

## Close the known weak spots

Each of these is either a fix to try or a decision to confirm in the playtests:

- **Let Go.** A blind route that waits at the gate's edge for the ghost on a to fade and walks straight through has a 24-frame window in every room, under the 30-frame bar. In rooms 2 and 3 the gate and exit door are 21 and 23 tiles from the waystone, past the first screen.
- **Plumb Line.** In The Well, a masher at the bottom wins with one cast 122 to 168 frames after landing. It's accepted because The Well is the teach room and the winning ghost is the intended one.
- **Ferryman's Toll and The Last Light.** The tap that steps onto the ferry has 7 frames on Ferryman's Toll, with a declared need of 6. On both levels the need is justified the same way as level 10's, because the ghost is only 10 px wide.
- **Clockwork.** The doors of the first room are three tiles beyond the first screen, so the player sees them only after three steps.

## Make one table describe each tile

Adding a tile still means editing five places. The waystone shows it. In `game/world/level.lua`, `LEGEND` maps `w` to the kind `checkpoint`:

```lua
  ['w'] = { kind = 'checkpoint' },
```

`TILES` holds its flags:

```lua
  checkpoint = { light = 44, checkpoint = true, rect = { 3, 0, T - 6, T }, worldList = 'checkpoints' },
```

`game/gfx/render.lua` attaches its draw function, `game/platform/assets.lua` has a matching entry in `SLOTS` for drop-in art, and the comment at the top of `game/content/levels.lua` lists the map characters again. Miss one and the waystone works but has no art slot, or draws but isn't in the legend comment a level builder reads.

The plan is one `TILES` entry per tile that also names its character, with `LEGEND` built from it and the render code finding each draw function by kind. The simulation still must not require anything from `gfx/`, so the draw functions stay in `render.lua`.

## Split the two largest files by scene and by layer

`game/screens/scenes.lua` and `game/gfx/render.lua` are both over 800 lines, and both already show where they would split.

`scenes.lua` opens with code every scene shares: the camera that follows the player, the reaction to world events, and the ambient title hall behind the menus. After that come seven scenes, one table each: title, playing, pause, level select, settings, level clear, and ending. One file per scene would keep each one to a screen.

`render.lua` is already divided into sprite slots, tile drawing, level layer, backgrounds, actors, lighting, and frame plumbing. Tile drawing is the biggest section, about 360 lines, and it's where the `TILES` draw functions attach and where the door drawing lives. Moving it into its own file fits with the single tile table above.

## Make the headless rule fail loudly

[Part 8]({{< relref "08-layout" >}}) describes the rule that `world/` requires nothing outside itself, which keeps the simulation free of drawing, sound and the clock. It still holds. The only two `require` lines in `game/world` point at `world.player` and `world.echo`. Today someone has to remember to check it. A check that reads the `require` lines in `world/` and `content/` would fail the first time someone breaks it.
