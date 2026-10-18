---
title: "What's next"
description: "Ferry's redesign, a folder layout a person can navigate, and this blog."
part: 8
weight: 8
date: 2026-10-17
commits: ["1b2f9ce"]
cover: "images/08-next/select-ferry-next.png"
---

Echoes now has twelve levels in three acts, a full set of menus, saved progress, controller support, and three tools that rerun its claims: `--selftest` (149 checks), `--flow` (33 checks), and `--bench`. Three pieces of work are underway.

{{< figure src="images/08-next/select-ferry-next.png" caption="Level select with the first two acts cleared. Ferry is next, and it is the level being rebuilt. The records are seeded test data." >}}

## Ferry, measured by a person's slack

[Part 7]({{< relref "07-ferry" >}}) showed that Ferry clears in a script and is effectively impossible by hand. The redesign comes with a tool that measures human slack directly. It asks how much of the space of natural attempts succeeds, not whether one perfect attempt survives a nudge. The same tool could then be pointed at the other eleven levels.

## A layout a person can navigate

The game is a flat folder of about 25 Lua files. That layout grew during one long session, and it is awkward for a person opening the project for the first time. The files are being reorganized into folders. The game's Lua files will move into a `game/` folder. Nothing on this blog depends on where those files live. The screenshot script exports whole commits with `git archive` and runs each one as it was.

## This blog

The blog itself lives in `devblog/`, separate from the game. Its screenshots come from `devblog/tools/shots.sh`, which renders each one from the commit the post describes, with a scratch save identity so it never touches a real save. Rerunning the script regenerates every image from its commit, so a reader can check an image instead of trusting it.
