---
name: verify-echo-memory
description: "Check that a cast ghost is exactly the last three seconds of recorded poses and that a mirror shrine does not rewrite that memory. Use when a change touches game/world/echo.lua (Echo.record, Echo.snapshot, Echo.mirror, Echo.new, Echo.FRAMES, Echo.W) or the record-then-cast path in game/world/level.lua (World:cast, World:touchedMirror, Level.step)."
---

# Verify echo memory

A cast ghost has to be the path just walked. This check proves that, for every state the recorder can reach, and it runs the real Lua.

## Property

A cast's ghost is the last 180 recorded poses, oldest first — or every pose recorded so far, when there are fewer — and reflecting that ghost at a mirror shrine does not rewrite the memory those poses came from.

**Harm.** The ghost appears in the wrong place, or a shrine cast rewrites the path. Every puzzle that depends on where you were for the last three seconds then lies, and a rewind that shares those frames replays the reflection as if it had been walked.

## When to run

Run it when a change touches any of these. If the diff does not touch them, the check cannot say anything about that change.

- `game/world/echo.lua`: `Echo.newRecorder`, `Echo.record`, `Echo.snapshot`, `Echo.mirror`, `Echo.new`, `Echo.FRAMES`, `Echo.W`
- `game/world/level.lua`: `World:cast`, `World:touchedMirror`, and the record-then-cast lines in `Level.step` (record the pose after the player moves, then cast)
- `game/world/player.lua`: `Player.W`, only because the reflection subtracts the body width

`Echo.copyRecorder`, `Echo:update`, veil halting, and `game/world/timeline.lua` are not this check. A pass says nothing about them.

## Run

From the repo root, with LuaJIT 2.1 (the language LÖVE 11 embeds). The run that confirmed this skill used LuaJIT 2.1.1703358377 (`luajit` 2.1.0+git20231223.c525bcb). Do not substitute PUC Lua.

```
luajit .cursor/skills/verify-echo-memory/check.lua
```

Exit 0 is a pass. Exit 1 is a failure. The run is the whole reachable recorder, three times over, plus two real play casts. It takes well under a second.

Install the interpreter if it is missing: `sudo apt-get install luajit`.

## What the result means

A pass means every recorder length from 0 through 540 was checked on `Echo.record` / `Echo.snapshot` / `World:cast`, and a real `Level.step` run past the wrap was checked for one ordinary cast and one shrine cast. 540 is three rings of 180, so every reachable `head` and `count` occurs. Poses in the direct sweep are unique, including negatives and fractions, so a slot that is off by one cannot match by accident.

A failure prints `FAIL  echo memory` and one counterexample: how many poses were recorded, whether the ring had wrapped (`head` and `count`), which frame of the ghost is wrong, and the pose that was recorded against the pose the ghost or the memory now holds. Frame 1 is the oldest kept pose. The last frame is the pose at the cast.

A line that starts with `checker:` means the harness is wrong (it could not find the game, it was not run on LuaJIT 2.1, or its tiny level did not put the player on the shrine). That is not a game bug. Fix the harness and run again.

## Telling a bug from a stale check

The oracle is not a second copy of the ring. For the sweep, it is the `x`, `y`, `facing`, and `state` arguments just passed to `Echo.record`. For the play section, it is where the player actually stood at the end of each `Level.step`. The expected reflection is the shrine's centre column, `mirror.tx * T + T / 2`, the same expression `World:cast` passes to `Echo.mirror`, and a 10 px body, so the reflected left edge is `2 * axis - x - 10`.

- The ghost's frame does not match that pose, or the memory matches the reflection after a shrine cast. The game broke the property. Do not edit the expected pose to match the ghost.
- `Echo.FRAMES`, `Level.DT`, or the body width moved, and you meant to change the three-second window or the size of the body. Update `EXPECTED_FRAMES`, `EXPECTED_WIDTH`, or `EXPECTED_DT` in `check.lua` and the property sentence in this skill. Re-run. Only a pass after that edit is a pass for the new rule.
- `World:cast` uses a new axis on purpose. Update `shrineAxis` in `check.lua` so it still names the expression in `World:cast`, re-run, and say so in this skill.

## Coverage

Confirmed against commit `ab9b8064e9f847d4500150bafbe35d90810e1532` (`Make the Play page's fullscreen sturdier and add F in the game`). The functions below were read at that commit and the check passed on them.

| Code | What the check holds it to |
| --- | --- |
| `Echo.record`, `Echo.newRecorder` | Each call appends one pose. The kept window never exceeds 180. |
| `Echo.snapshot` | Oldest to newest, the last `min(n, 180)` poses, copied out of the ring. |
| `Echo.mirror`, `Echo.W` | Reflects left edge and facing about the axis. Does not rewrite the recorder. |
| `Echo.new` | The ghost `World:cast` stores keeps those frames and the mirrored flag. |
| `World:cast`, `World:touchedMirror` | Off the shrine, the ghost is the window. On the shrine, it is the reflection, and the recorder still holds the walked poses. |
| `Level.step` | Records the post-move pose, then casts. Checked by playing a corridor past the wrap and casting, including once while overlapping a shrine. |
| `Level.DT`, `Echo.FRAMES` | 180 frames at 1/60 s is three seconds. |
| `Player.W` | Stays 10, the width `Echo.mirror` subtracts. |

Move the sync commit forward only after you have re-read these functions at the new commit and confirmed the check still describes them. A pass by itself is not that confirmation. If a covered file changed after `ab9b8064e9f847d4500150bafbe35d90810e1532`, look at the diff before you trust the result:

```
git diff ab9b8064e9f847d4500150bafbe35d90810e1532 -- game/world/echo.lua game/world/level.lua game/world/player.lua
```

## What a pass does not cover

- Echo playback: veils, the contact slide, linger, fade, or the two-echo cap.
- `Echo.copyRecorder` and the rewind ring in `game/world/timeline.lua`. Rewind shares recorder frames on purpose. This check only shows that a shrine cast does not mutate them through `Echo.snapshot`.
- The rule that a cast with fewer than two recorded poses spawns nothing.
- Doors, plates, crumble, embers, waystones, hazards, and the save file.
- Any cast whose poses were not produced by `Echo.record` or by `Level.step` on the two corridors above. The sweep visits every reachable `(head, count)`, not every possible coordinate.

A second place worth a check, not done here: `Timeline.push` / `Timeline.back` in `game/world/timeline.lua`. The ring keeps 30 seconds (1800 steps). `testRewind` walks scripted solutions back at most 600 steps and compares `World:save()` with itself, so it never inspects the step that drops the oldest state, and a field `save` forgets is invisible to that comparison. A break there makes undo after a long attempt restore a moment that never happened.
