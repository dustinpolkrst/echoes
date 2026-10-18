# Level design for Echoes

This is the rulebook for acts IV and V. Part 1 is what the game's rules actually allow, measured in the simulation. Part 2 reads the twelve existing levels against those numbers. Part 3 is the rules every new level follows. Part 4 is the waystone (checkpoint) and what a respawn resets. Part 5 is the file layout, the room declaration format and the tools that check a level. Part 6 is the spec for levels 13 to 22.

Every number below was produced by running the headless simulation (`game/world`), not estimated. Where a number came from `--cheese` sweeps the sweep is named so it can be rerun.

## 1. The numbers

The tile is 16 px. The player is 10 px wide and 12 px tall. The view is 480x270, so a screen is 30 tiles wide and 17 tall, and the camera leads 30 px in the facing direction.

### Movement

| Quantity | Value | Consequence |
| --- | --- | --- |
| Run speed | 100 px/s (6.25 tiles/s) | A 90-tile level is 14.4 s of running end to end. |
| Ground acceleration | 900 px/s^2 | Full speed in 0.11 s. Stopping takes 0.09 s. |
| Air acceleration | 600 px/s^2 | A standing jump can still steer about 20 px before landing. |
| Full jump rise | 50.8 px (3.2 tiles) | Clears a 3-tile wall, never a 4-tile wall. |
| Full jump airtime | 37 frames (0.62 s) | |
| Tapped jump rise | 12.6 px (1 frame), 21.7 (3), 33.4 (6), 50.2 (12) | Hold past 12 frames changes nothing. |
| Running jump travel | 60 px, plus up to 10 px of coyote time (0.1 s) | Clears a 3-tile gap. A 4-tile gap (64 px) needs an echo. 5 tiles and up are safe from every shallow strategy. |
| Coyote time, jump buffer | 0.1 s each | A jump pressed up to 6 frames after leaving a ledge still fires. |
| Max fall speed | 280 px/s | A 30-tile shaft is about 2 s of falling. |
| Death to respawn | 0.7 s death delay, 0.2 s iris out, 0.26 s iris in | About 1.2 s before the player moves again. |

### Echoes

| Quantity | Value | Consequence |
| --- | --- | --- |
| Memory | 180 frames (3 s) | An echo appears where you were 3 s before the cast and replays forward. |
| Replay | 3 s (or less, right after a respawn, when the memory is shorter) | A cast on arriving at a plate opens its door 3 s later. |
| Linger | 4 s solid, then 0.5 s fade | An echo lives 7 s after its cast if the memory was full. |
| Cap | 2 echoes | The third cast removes the oldest. |
| Standing cast on a plate | the plate is held for 7 s after the cast | The basic timer of every plate puzzle. |
| Cast on arriving at a plate | the plate is held from 3 s to 7 s after the cast | The door opens when the ghost gets there, which is after you have left. |
| Passing press | an echo running across a 14 px plate presses it for about 14 frames (0.24 s) | Enough to open a hatch under a standing player. This is how level 9 is cheesed, see part 2. |
| Jump ride | a rider on an echo that replays a jump is lifted the full 50.8 px | Measured: a player standing on a standing echo rode its replayed jump up 50.8 px and never lost support. |
| Ghost of a ghost | an echo recorded while standing on a mid-air echo floats at that spot after the first fades | Measured: echo 2 stayed solid at the recorded height after echo 1 expired. The player has to jump up through it to stand on it, because it occupies the spot they stood in. |
| Mid-air step | a cast up a jump leaves a frozen step; it is landable only if cast less than about 38 px up | At the apex (50.8 px) the step is 62.8 px up and nothing can reach it from the floor below. Level 3 works because the player comes from a ledge. |

### Tiles

| Tile | Rule | Consequence |
| --- | --- | --- |
| Mirror shrine | a cast while touching it reflects the recording about the shrine's centre column; same height, through walls | A sealed room is reachable by a ghost only if the player can stand at its mirror image. |
| Veil | the player walks through; an echo whose next step would enter it stops at the edge and lingers 4 s | A horizontal strip catches a falling ghost; a vertical column is a dock. An echo whose first frame is already inside a veil never moves (a statue). |
| Plate over veil | a plate cell directly above a veil cell is pressed by an echo halted on the veil | A pad only ghosts can press: the player falls through both cells. Measured: halted echo bottom at the veil top, plate pressed, door open. |
| Crumble | cracks 0.5 s after a body stands on it, then gone; regrows 3 s after nothing is inside the cell; echoes count as bodies and keep standing when it goes | Running across a tile takes 0.16 s and never cracks it. A ghost standing on the far side of a shrine breaks stone where the player cannot stand. A ghost sitting in the hole keeps it open. |
| Door | solid unless its plate is pressed by the player or an echo; a body already inside the door keeps it open | A door can be a wall, a floor (level 9) or a ceiling hatch. |
| One-way | catches a body only from above | A ladder of one-ways at 3-tile spacing is climbable (50.8 > 48). |
| Waystone | lights when touched; death and R return you there with everything reset | Part 4. |

### What gates what (from `--cheese` sweeps over a corridor with one wall or one gap)

| Obstacle | Plain play | One cast | Two casts | Clean |
| --- | --- | --- | --- | --- |
| Wall height | 3 tiles | 4 to 7 tiles (a mid-air step, or a stack of one or two standing echoes for 4) | 8 to 9 tiles (ladder: a step cast from the first step) | 10 tiles and up |
| Gap width | 3 tiles | 4 tiles (a mid-air step or a standing echo at the edge) | | 5 tiles and up |

A ceiling does not stop a climb unless it is flush with the wall top: one tile of clearance above a wall is enough to pass over it. The sweeps are in `game/dev/selftest.lua` (`testCheeseSearch`) for 5, 9 and 10 tiles and were run for 3 to 14.

## 2. The existing levels, measured

`--cheese` was run on all twelve. It plays four families of shallow strategies against each level: autoruns and single swept jumps with no echo; one cast swept along the natural path by frame or by height up a jump; a ladder of two mid-air casts; and stacks of one or two standing echoes. Any hit means a player who understands nothing but "run, jump, press X somewhere" can finish the level.

| Level | Hits | Reading |
| --- | --- | --- |
| 1 Wake, 2 First Echo, 3 Stairway, 4 Two Minds | run and jump; one cast on the path | Tutorials. Their solutions are supposed to be shallow. |
| 5 Ascent | none | Long and clean, but its difficulty is mostly a sequence of jumps; the only insight (the apex cast at the top) is level 3's. |
| 6 Other Side | one cast on the path | Weak. Run to the door and press X: the reflected echo replays your approach and sweeps across the plate for 14 frames, which is long enough to walk into the door cell, and a body inside a door keeps it open. The insight the hint names (where is the reflection of the plate) is never needed. |
| 7 Trapdoor | one cast on the path | The intended solution is itself shallow (walk onto the plate, cast, fall). Fine for a teaching level. |
| 8 Undertow | standing stack | The hit is the intended solution: the walk-to-x phase fell off the ledge, the recording captured the fall and the echo parked under the veil. Fine for a teaching level. |
| 9 Underfoot | one cast on the path | Weak. Run onto the hatch and press X: the replayed run crosses the plate 3 s later, the hatch opens for a quarter second under a standing player, and that is enough to fall through. The 3 s stand is never needed. |
| 10 Ferry | none | Strong. The insight (a reflection waits as long as you waited) cannot be stumbled into; slack is measured at 30+ frames on every decision. |
| 11 Short Memory | one cast on the path, 24-frame window | Mostly strong. The insight (the three seconds must start on the right side of the veil) is real, but a player who mashes X at the shrine hits an accidental 24-frame window where the reflection's first frame lands on the plate inside the veil. |
| 12 Confluence | none | Strong. Two insights chained (ferry, then the ghost of the ride) under a time budget the selftest measures. |

Three lessons for the new levels come straight from this table.

1. A single-room level whose plate lies on the natural path is solved by running and pressing X. Rooms need the plate or the standing spot off the path, or a reason the passing press is not enough.
2. A passing echo presses a plate for 14 frames. Any door that only has to be open for an instant (a hatch under a standing player, a door cell the player is already touching) is opened by a passing ghost. Use that on purpose (level 21) or design against it (keep the exploit distance longer than 14 frames of running).
3. The strong levels (10, 12) are the ones where the player has to predict where and when a ghost will be, not just that there will be one.

## 3. Rules

### R1. One insight per room, one room per screen

A room is the stretch between two waystones (or the start and the first waystone). It has exactly one thing to realise, stated in one sentence in its `insight` field, and everything else in the room is already known. A room should fit the 30x17 view or scroll along one axis so the player can see the whole problem from its waystone before committing. Three rooms is a level; four is the finale.

### R2. Rooms chain as teach, test, twist

The first room shows the insight in the cheapest possible form, often solvable by a weaker method too. The second room removes the weaker method. The third changes one parameter so the insight has to be applied, not repeated: the shrine moves to the other side, the budget shrinks, the plate becomes a pad. The spec in part 6 names which of the three each room is.

### R3. The insight is discoverable before the first death

- Sightline. From the waystone the player can see the goal of the room (the door, the ledge, the pad) and every tile that matters. Shrines, veils, plates and doors are lit tiles and read at a glance; keep them in the first screen.
- Affordance. A plate over a veil says "a ghost goes here". A veil strip across a shaft says "something falls and stops". A crumble floor under a sealed room says "break this from above". Every room has one such tell.
- The hint. One line, shown for the first 4 s and visible again after a restart. It names the rule, never the solution: "A ghost standing still has weight. A ghost that walks does not."
- Failure teaches. A wrong attempt should leave a visible consequence the player can read (the ghost halted at the wrong veil, the door opened after they had passed), not just a death.

### R4. Red herrings are fair

A red herring is a feature the player will try first that fails for a reason they can see. A ledge of crumble they rest on and lose. A plate they can stand on themselves but then cannot leave. A shrine that reflects into a wall. Unfair herrings are ones that fail invisibly (a plate 1 px short, a budget that misses by 10 frames), and any feature that does nothing at all. Every tile in a room participates in the solution or in a named naive approach.

### R5. Hardness comes from reasoning, never from execution

- Every human decision in the strategy has at least 30 frames or 24 px of slack (`--slack`). A decision that needs less is a bug in the level, not a challenge.
- Hard rooms reason about time (where a ghost will be N seconds after the cast; which 3 s the memory holds; the 7 s life; the order of expiry under the 2-echo cap), space (where a reflection lands; a reflection of a ride; two shrines), and resources (two ghosts for three jobs means one ghost does two). Part 6 tags each room with the kind of reasoning it demands.
- Never require a jump the player has to time to a moving echo. Use veils to fix heights and docks, use standing echoes and halted echoes as the platforms, let moving echoes carry the player rather than be caught.
- The shallow families in `--cheese` are the floor: a room beyond act I whose exit they reach is not a puzzle room. The exception is an explicit teach room, and even then the hit must be the intended solution, as in level 8.

### R6. Difficulty paces up within a level and across acts

Within a level: teach, test, twist, and the twist is the room the expected solve time is spent in. Across acts: act IV combines two known mechanics per level and expects 5 to 15 minutes; act V combines three, adds a budget or a cap, and expects 10 to 35 minutes. Level 22 is the longest and ends on a room that needs the four strongest ideas from earlier levels at once.

### R7. Failure is cheap

- A waystone at the entrance of every room, on two or more tiles of flat solid ground, with the room's sightline from it.
- From the waystone, the room's first decisive action (the first cast) is at most 5 s away.
- A wrong cast can be undone by casting again (the third cast drops the oldest) or by R, without dying. Spikes and pits only where falling is the failure the room is about.
- Dying never costs an earlier room: the respawn model (part 4) makes every room self-contained.
- A whole retry of the twist room, from waystone to the key moment, is under 15 s.

### R8. Cheese is detected, not hoped against

Every room beyond act I passes `--cheese` clean (no shallow strategy reaches its exit from its waystone) and declares its naive approaches, which the selftest proves fail. Builders also check the catalogue of known cheeses by hand:

- A passing echo presses a plate for 14 frames (level 9).
- An echo whose first frame is inside a veil is a statue at that frame (level 11's 24-frame window).
- A mid-air step cast under 38 px up a jump, and the ladder from it, climb 7 and 9 tiles.
- A standing echo is a 12 px step; two are 24 px.
- A rider is lifted 50.8 px by a replayed jump.
- A fresh memory right after a respawn makes a short echo that arrives early.
- A player inside a door cell keeps it open.

## 4. The waystone

`w` in a map is a waystone. Touching it lights it and makes it the respawn point; the one touched last wins, so walking back onto an earlier one moves the respawn back. Lighting one plays a chime, a burst of mint particles and a "waystone lit" label over the player; the tile glows from then on.

What a respawn is: the level is rebuilt from its map and the player is stood on the lit waystone. Nothing carries over: no echoes, an empty memory (the first cast after a respawn replays only what happened since), every door shut unless its plate is pressed, every crumble stone whole, the level clock still running. Death and R both do this. The pause menu's Restart level starts the level over from `P` with a fresh clock.

Why everything resets: it is the only model under which "the room is solvable from its waystone" is a checkable statement. The selftest runs every room's solve from a fresh respawn at its waystone (`testRooms`), so a waystone placed where the room needs a ghost from the previous room fails the build. That is the soft-lock guarantee, and it is why a waystone must sit on ground reachable with nothing carried in.

Placement: on solid ground, never on a one-way, crumble, plate or in a door's column, with the room's sightline from it (R7). One per room, at its entrance. The first room starts at `P` and has no waystone.

## 5. Files, the room format and the tools

### Layout

```
game/content/levels.lua          aggregates the acts; stamps act numbers
game/content/acts/act1.lua ...    one file per act; a list of { name, hint, map }
game/dev/script.lua               driver, run, conditions, decisions
game/dev/solutions.lua            aggregates the per-act solution files
game/dev/solutions/act1.lua ...   { scripts = {}, strategies = {}, rooms = {} } keyed by level name
game/dev/slack.lua                --slack: sweeps a strategy's decisions
game/dev/cheese.lua               --cheese: shallow strategies per room
docs/level-design.md              this file
```

Adding a level touches exactly two files: `game/content/acts/actN.lua` and `game/dev/solutions/actN.lua`. Act IV builders own `act4.lua` in both folders; act V builders own `act5.lua`. Nothing else needs editing; `--selftest` picks levels up by iterating the combined list.

### What a level owes

- A `scripts` entry, or a `strategies` entry whose `build` produces the script. `--selftest` proves it reaches the goal and survives timing shifts of 3 frames.
- If the level has a waystone (every level in part 6 does): a `strategies` entry with every human decision as a parameter, and a `rooms` entry with one room for the start and one per waystone. `testLevelContracts` fails the build otherwise.

### The room format

```lua
rooms = {
  ['Relay'] = {
    {
      name = 'Loop',
      insight = 'a ghost cast on arrival opens the door three seconds later, which is when you get back',
      from = 1,                         -- nil: the level start; k: the k-th waystone in map order (row-major)
      exit = { 58, 10, 59, 12 },        -- tile rect { tx0, ty0, tx1, ty1 }, inclusive; nil means the goal
      solve = { ... },                  -- a script from a fresh respawn at `from` that reaches `exit` without dying
      naive = {                         -- each must NOT reach `exit`; dying counts as not reaching it
        { 'stand three seconds on each plate', { ... } },
        { 'cast on the second plate and wait', { ... } },
      },
    },
  },
}
```

Scripts use `dev/script.lua`: a segment is `{ frames, 'RLJX' }` or `{ 'RLJX', condition }`, and the conditions are `atX`, `atXLeft`, `onTop(y, minx, maxx)`, `apex`, `echoArrived`, `onLastEcho`, `grounded`, `doorOpen(id)`. The strategy format is in `game/dev/solutions/act3.lua` (Ferry).

### The tools

- `love game --selftest` runs everything: physics, every level's script, the long-level contract, every room's solve and naives, the slack of every strategy, and the cheese search's own controls.
- `love game --slack N` prints the winning window of each decision of level N's strategy, with a strip of `#` and `.` per swept value.
- `love game --cheese N` prints, per room, any shallow strategy that reaches the exit, with the parameters that did it (direction, hold, the frame or height of the cast, the stack position). No hits reads "no shallow strategy reaches the exit". It runs about 1000 strategies per room in one or two seconds. Validation: planted walls of 5 and 9 tiles are caught (by the single-cast step and by the ladder) and a 10-tile wall is clean; level 10 and 12 are clean; levels 6, 9 and 11 are flagged for the reasons in part 2.

A room is done when: the solve passes from a fresh respawn, every naive fails, `--slack` shows 30 frames or 24 px on every decision, `--cheese` is clean for the room, and the builder has walked the known-cheese catalogue in R8.

## 6. The ten levels

| # | Act | Name | Size (tiles) | Rooms | Core idea | Reasoning | Solve time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 13 | IV | Relay | 72 x 18 | 3 | A ghost cast on arrival opens its door 3 s later. Use the delay. | time | 5 to 8 min |
| 14 | IV | Plumb Line | 24 x 64 | 3 | A falling ghost stops at the first veil below where its memory began. | time, space | 6 to 10 min |
| 15 | IV | Undercroft | 64 x 22 | 3 | A standing ghost breaks stone; a reflected one breaks it where you cannot stand. | space, time | 8 to 12 min |
| 16 | IV | Crawlspace | 80 x 20 | 3 | Under a low roof ghosts cannot be steps; a veil overhead fixes a ghost's height. | space | 8 to 12 min |
| 17 | IV | Ferryman's Toll | 70 x 20 | 3 | The ferry docks on the pad and pays the toll itself. | space, time | 10 to 15 min |
| 18 | V | Clockwork | 60 x 20 | 3 | Two ghosts can share one memory; one ghost can hold two plates in turn. | time, resources | 12 to 20 min |
| 19 | V | Hall of Mirrors | 72 x 20 | 3 | A reflection of a ride is a ride; two shrines copy a walk 2d away. | space | 15 to 25 min |
| 20 | V | Scaffold | 30 x 70 | 2 | A ghost cast from a ghost's back floats there after the first is gone. | time, resources | 10 to 20 min |
| 21 | V | Three Steps Behind | 80 x 24 | 3 | A running ghost presses each plate for a quarter second, three seconds after you did. | time | 15 to 25 min |
| 22 | V | The Last Light | 96 x 32 | 4 | The finale: ferry, scaffold, shared memory, and a ghost that does two jobs. | all | 20 to 35 min |

Sizes are targets within the brief's 40 to 90 tiles; builders adjust to fit the sightline rule. Coordinates in the room notes are tiles from the top-left of the map.

### 13. Relay (act IV)

Hint: "A ghost opens the door when it reaches the plate, not when you cast."

Rooms, left to right, one long hall 18 tiles tall with a 2-tile step between rooms.

**Room 1, Handoff (teach, from the start).** Plate a at tile 4, door A (3 tall) at tile 30, plate b at 33 just past A, door B at 60. The player sees a, A and the hint. Intended: stand on a, cast, run through A (2.6 s), stand on b, cast, run through B. Casting on arrival works too and the player who does it sees the door open as they reach it. Naive that must fail: no echo at all. Waystone 1 at tile 62.

**Room 2, Loop (test, from waystone 1).** Plate a at 64. Door A at 68 guards a 25-tile corridor (to tile 93) that ends in plate b and nothing else. The exit, door B, is above A on a one-way shelf at tile 66, reached from the corridor's near end. The player sees a, A, the dead-end corridor and B above. Timeline the player must find: cast on a (t=0, A held until 7); run to b (t=2.5); cast on arrival; run back (t=5, A still open); climb the shelf; B opens at 5.5 and stays until 9.5. The cast at b is good anywhere in t=2.5 to 4.5, a 2 s window. Naive that must fail: standing 3 s on b before casting (A shuts at 7, the player is back at 8). Naive: an echo on a cast on arrival instead of standing (changes nothing, the door still shuts at 7; include it so builders see it is not the lever). Waystone 2 past B.

**Room 3, Encore (twist, from waystone 2).** Room 2 mirrored: the dead-end corridor is to the left of A and the shelf is reached from the right, so the plate the player meets first is the one that must be cast on arrival, and the far one is the one to stand on. Same budget. Naive: the room 2 recipe in the room 2 order. Goal past B.

Sketch of room 2 (tiles 62 to 96, floor row 15):

```
    62        68              80                      93
    w....a....A.........................................#
    #....=....A.........................................#    = one-way shelf, B stands on it
    #....B....A.........................................#    B is 3 tall, above the shelf
    ####################################################b#
```

### 14. Plumb Line (act IV)

Hint: "A ghost falls where you fell, and stops at the first veil beneath where it began."

A shaft 24 tiles wide and 64 tall, descended top to bottom. Veil strips (rows of `~`) cross the shaft at several depths; a plate over a veil pad sits at the side of some strips (`a` above `~`, with `#` under). One-way ledges on the shaft wall at 3-tile spacing let the player climb back a few tiles where the room needs it.

**Room 1, The Well (teach, from the start, depth 0 to 30).** Strips at depths 10 and 25; the pad is on strip 25; door A at depth 29 leads to waystone 1. A ledge at depth 14 juts from the wall. The player sees the two strips and the pad before dropping. Intended: drop to the ledge, wait 3 s, drop to the floor, cast; the ghost begins on the ledge, falls, halts on the pad, A opens for 4 s. Naive: cast at the bottom straight after the fall (the memory begins above strip 10; the ghost halts there). Naive: cast while standing on the ledge (the memory still begins above strip 10).

**Room 2, Twin Well (test, from waystone 1, depth 30 to 50).** The shaft splits around a 1-tile wall: the main shaft (left) and a sealed twin (right) the player can see across. Twin strips at depths 45 and 52 with the pad on 52. Main-shaft ledges at 43 and 47. The shrine stands on a ledge at depth 50 in the main shaft; door A at the bottom of the main shaft. Intended: wait on the 47 ledge (below the twin's 45 strip), drop to the shrine, cast; the reflection begins at depth 47 in the twin shaft, skips nothing, halts on 52. Naive: wait on the 43 ledge (the reflection halts on 45). Naive: a plain cast at the shrine's foot (not reflected; the ghost falls in the main shaft).

**Room 3, Climb to Cast (twist, from waystone 2, depth 50 to 64).** As room 2 but the shrine is *above* the correct ledge: the ledge is at 60, the shrine at 56 on a one-way ladder, the twin's strips at 58 and 62 with the pad on 62. The player must wait on the 60 ledge, climb two one-ways to the shrine (under 3 s) and cast. Insight: the ghost begins where you were three seconds ago even if you climbed since. Naive: wait at the shrine's ledge (reflection halts on 58). Goal at the bottom.

Sketch of room 2 (depth 40 to 54, main shaft left, twin right):

```
   #..........#..........#   40
   #..........#..........#
   #..........#..........#
   #===.......#..........#   43  ledge (wrong)
   #..........#..........#
   #..........#~~~~~~~~~~#   45  twin strip (no pad)
   #..........#..........#
   #===.......#..........#   47  ledge (right)
   #..........#..........#
   #..........#..........#
   #......M...#..........#   50  shrine on a solid ledge
   #......###.#..........#
   #..........#.........a#   52  pad: a over ~
   #..........#~~~~~~~~~~#
   #....A.....#..........#   54  door A
```

### 15. Undercroft (act IV)

Hint: "A ghost standing still has weight. A ghost that walks does not."

Two storeys: an upper corridor the player walks and a lower corridor 2 tiles tall under it. Sealed galleries open off the upper corridor; their floors are crumble, and they can only be entered from below through a hole in that floor.

**Room 1, Trapfloor (teach, from the start).** A 4-tile crumble section in the upper floor; the goal of the room is the lower corridor. Running across does nothing; standing 0.5 s drops you. Waystone 1 below.

**Room 2, Far Side (test, from waystone 1).** Back in the upper corridor (a one-way ladder returns the player). The shrine at tile 30. A sealed gallery to the right, tiles 32 to 40, floor of crumble, containing waystone 2 and the way on. The lower corridor runs under both. The player sees the gallery through its open left wall above head height (the gallery is 3 tiles above the corridor floor, walled by a 10-tile column). Intended: stand 0.5 s or more at tile 28 (whose reflection is gallery floor tile 32), step onto the shrine, cast. The reflection stands on tile 32 for the 0.5 s it remembers, the stone cracks and goes, the ghost walks off. The hole regrows 3 s after the ghost leaves, about 4 s after the cast. Drop through the room 1 trapfloor behind you (0.8 s), run under (0.5 s), jump up through the hole (the lower corridor is 2 tiles tall, so the full 50.8 px jump clears the 32 px floor with 18 px to spare) and land beside it. Naive: cast at the shrine without standing first (the reflection crosses the stones at 0.16 s per tile and nothing cracks). Naive: stand at the wrong tile (the reflection stands on solid gallery floor). Naive: a plain echo in the lower corridor as a step (the ceiling is solid everywhere but the hole, and there is no hole).

**Room 3, Borrowed Ground (twist, from waystone 2).** The same trick, but the standing spot whose reflection is the gallery stone lies over a 3-tile spike pit. The player cannot stand there; a ghost can. Intended: cast a plain echo at the apex of a short hop so it freezes over the pit as a step (under 38 px up), stand on it 0.5 s or more, walk to the shrine within 3 s, cast. The second cast is reflected and breaks the stone; the first echo is still the step the recording remembers, and it does not matter that it fades. Naive: the room 2 recipe (there is nowhere to stand). Naive: two standing echoes stacked at the pit's edge (12 px each; the reflection then stands one tile short of the stone). Goal in the gallery.

Sketch of room 2 (upper corridor and gallery, floor row 10; lower corridor rows 11 to 12):

```
 tiles  24      28  30  32              40
        #.....................#..........#
        #.....................#..........#
        #...........M.........#....w.....#      gallery, sealed by the column at 31
        ########################%%%%%%%%%##      gallery floor is crumble, row 10
        #..................................#     lower corridor, 2 tiles tall
        #..................................#
        ####################################
```

The player stands at 28 (three tiles left of the shrine at 30 whose column centre is the axis); the reflection stands at 32, the first crumble cell.

### 16. Crawlspace (act IV)

Hint: "Under a low roof, think sideways. A veil overhead fixes a ghost's height."

**Room 1, Low Road (teach, from the start).** Corridors 2 tiles tall for 30 tiles: a jump hits the roof at 32 px, so there are no steps and no ladders here. A plate, a door 10 tiles on, and a 6-tile crumble bridge over a 1-tile drop into spikes between the door and plate b at the end. The player runs the bridge (safe at 0.16 s per tile) and casts at b; the ghost walks back over the air where the bridge was and ends on b; door B at the near end. Naive: stop on the bridge. Waystone 1.

**Room 2, Ceiling Veil (test, from waystone 1).** The roof opens into a shaft 10 tiles tall with the exit ledge at the top. A horizontal veil strip crosses the shaft 4 tiles up. The player sees the ledge, the strip and nothing else. Intended: jump into the strip and cast on the way up; the ghost rises into the veil and halts under it with its top at 64 px; stand on it (bottom at 64) and jump: 114.8 px, short of the 160 px ledge. So a second strip is needed, and the room has one at 7 tiles: jump from the first ghost into it and cast; the second halts under it at 112 px; from there the jump reaches 162.8 and the ledge. No cast height matters: the veil decides it. Naive: the two-cast ladder from the floor (tops out at 9 tiles; the ledge is at 10). Naive: an apex cast from the floor (62.8 px up, unreachable). Waystone 2 on the ledge.

**Room 3, Roofed Well (twist, from waystone 2).** A 2-tile corridor leads to a second shaft whose strips are at 3 and 8 tiles and whose ledge is at 11. The first strip is too low to chain directly: a ghost under it has its top at 48 px, and a jump from it reaches 98.8 px, short of the 8-tile strip at 128. The twist is a one-way shelf at 5 tiles on the far wall: from the first ghost the player reaches the shelf (98.8 > 80), jumps from the shelf into the 8-tile strip casting on the way up (apex top at 142.8 enters the 128 to 144 cell), and from that ghost (bottom at 128) the jump reaches 178.8 and the ledge at 176. The player has to see that the shelf, not the second ghost, is the middle rung. Builders check the heights against the table in part 1 and prove the floor ladder fails with `--cheese`. Goal on the ledge.

### 17. Ferryman's Toll (act IV)

Hint: "The ferry carries you. The toll is paid by the one who stays behind."

**Room 1, Dock (teach, from the start).** Level 10's ferry over a 7-tile spike pit with a veil dock on the far shore; the far shore has waystone 1. The one new thing: the walk-away distance decides how far the ferry goes before it turns, and the veil stops it anyway. Naive: any plain jump (the tunnel-jump sweep from level 10 applies).

**Room 2, Toll Gate (test, from waystone 1).** The same pit, but the far dock is a pad (plate a over the veil) and door A stands 2 tiles beyond it across the whole shore. The player sees the pad and the door. Intended: the ferry halts on the pad, the pad is pressed for 4 s, A opens, the rider steps off and walks through. Naive: ride, step off, then cast a plain echo on the pad (the player falls through the pad cell onto the floor beneath it; the echo cast there is not on the plate). Naive: hold the player's own weight on it (impossible, same reason). Waystone 2.

**Room 3, Hatch (twist, from waystone 2).** The pit again, but the veil column stands mid-pit with the pad on it, and door A is a hatch in the ceiling above the pad opening into the upper corridor where the goal is. The ferry docks mid-pit; the hatch opens for 4 s; the rider jumps up through it. Naive: a longer walk-away (the ferry halts at the veil whatever the distance; the naive here is to walk away *less* than the pad's distance, so the ferry turns back before the veil). Goal above.

### 18. Clockwork (act V)

Hint: "Two ghosts can share one memory."

Plates and doors with budgets the player has to write down. All distances chosen so the naive timelines miss by at least 1 s and the intended ones have at least 1.5 s of slack.

**Room 1, Overlap (teach, from the start).** Plates a and b 25 tiles apart; doors A then B 4 tiles apart in the exit corridor 25 tiles past b. Standing 3 s on each plate: A shuts at 7, the player reaches it at 8. Intended: cast on a standing (A: 0 to 7); run to b (2.5 s) and cast on arrival (B: 5.5 to 9.5); run to the doors (5 s) and wait half a second for B. Naive: 3 s stands on both. Waystone 1.

**Room 2, One Ghost (test, from waystone 1).** Plates a and b 10 tiles apart, doors A and B with a 3-tile waiting room between them, A 6 tiles past b. Only one cast is useful because a second plate c far behind needs the other ghost for door C at the very end. Intended: stand on a for 1 s, walk to b (1 s), cast on arrival at b. The ghost holds a for its first second (A open from the cast to +1), walks, and holds b from +3 to +7. The player walks through A within the first second (6 tiles is 1 s, so they must already be moving), waits in the waiting room, and B opens at +3. Naive: two ghosts on a and b (then nothing holds c; door C stays shut at the end and the room's exit is beyond C). Naive: stand on a for 3 s (the memory then holds only a; the ghost never reaches b). Waystone 2 past C.

**Room 3, Three Clocks (twist, from waystone 2).** Three plates a, b, c and three doors in the order A, B, C with the waiting-room pattern, two ghosts: one ghost does a then b in one memory as in room 2; the other holds c and must be cast *last* so it is not the one the third cast drops. The twist is the order of casting versus the order of need. Naive: the room 2 ghost cast first and then c (works only if the player then needs no fourth cast; the room makes them need one by putting a crumble step before C that drops the player once, so they must recast). Builders set the budgets with `--slack`. Goal past C.

Sketch of room 2 (floor row 12):

```
 tiles  30   34        44        50    53 56
        w....a.........b.........A.....A...B...B.............C...
        ###############################################################
                 10 tiles          6     3-tile wait     far end: C, held by the other ghost
```

### 19. Hall of Mirrors (act V)

Hint: "A ghost cast from a ghost's back reflects the ride."

**Room 1, Second Crossing (teach, from the start).** Two spike pits in a row with a shrine on the shore between them. Ferry across the first (shrine 1 on the near shore). On the middle shore, cast on shrine 2 while the memory still holds the ride: the reflection replays the ride mirrored about shrine 2, which is a ferry over the second pit. Intended: ride, land, walk to shrine 2 within 3 s, cast, step on. Naive: a plain cast on the middle shore (the ghost replays the ride back over the first pit, level 12's move, which goes nowhere here). Waystone 1.

**Room 2, Sealed Twice (test, from waystone 1).** A ferry's far shore is a sealed room with a pad at ride height and door A beyond; the second shrine stands on the near shore 4 tiles from the pit. The reflected ride must dock on the pad; the dock is a veil column at the sealed room's near wall. Intended as room 1, with the walk to shrine 2 shorter than 3 s. Naive: ferrying straight into the sealed wall. Waystone 2.

**Room 3, Double Image (twist, from waystone 2).** Two shrines 6 tiles apart on one floor, a sealed corridor beyond them at the same height with a plate 12 tiles to the right of the walk the player can make. Reflect about shrine 1 (ride the reflection), then cast on shrine 2 from the ghost's back: the second reflection's path is the player's physical path while riding, mirrored again, which is the original walk shifted right by twice the shrine distance. The player must plan a walk, 12 tiles short of the plate, that the copy will finish on. Naive: a single reflection (lands 2d short or in the wall). Goal past the door.

### 20. Scaffold (act V)

Hint: "A ghost that stood on a ghost floats there, long after the first is gone."

A shaft 30 wide and 70 tall. Crumble ledges every 3 tiles on alternating walls are rests that give way after 0.5 s; they are the red herring and the pacing.

**Room 1, The Rule (teach, from the start, 8 tiles tall).** A 6-tile wall with a 1-tile clearance under the ceiling, out of reach of one cast (part 1 says a single step clears 7, so this one is 8). Intended: jump and cast under 38 px up, land on the step after it arrives (3 s), and while standing on it cast again within a second. The second ghost arrives 3 s later at the spot the player stands on, right as the first fades; jump up through it and land on it (bottom at 50 px), jump: 100.8 px, over the wall. Naive: the ladder (two mid-air casts, tops at 9 tiles; the room's wall is 8, so the builder raises it to 10 with the one-tile clearance kept, or puts the ceiling flush). Naive: resting on a crumble ledge to stand 3 s (it drops at 0.5). Waystone 1.

**Room 2, The Climb (test and twist, from waystone 1, 60 tiles tall).** The shaft: each cycle is jump, cast under 38 px, land, cast from the ghost's back within a second, jump through the arriving second ghost, and the player gains about 50 px per cycle and spends about 7 s. The twist, two thirds up, is a veil strip across the shaft: a ghost cast on the way up into it halts under it instead of where it was cast, which gives a free fixed step (level 16) and resets the rhythm. The cast-from-the-back window is 1 s wide (60 frames); the builder proves it with `--slack` and widens it, if needed, by placing one-way rests the player can wait on instead of ghosts every third cycle. Goal at the top.

### 21. Three Steps Behind (act V)

Hint: "A running ghost presses each plate for a quarter second, three seconds after you did."

The level 9 exploit as a mechanic. Hatches (doors as floors) open for 14 frames when a replaying ghost runs across their plate, which is enough for a standing player to fall through.

**Room 1, Quarter Second (teach, from the start).** An upper corridor with plate a at tile 10 and hatch A at tile 20; below, the way on. Run across a, keep running, stand on the hatch, cast: 3 s after the cast the ghost crosses a and the hatch drops you. No stand needed; standing 3 s on a works too but then the ghost ends on a and the hatch stays open, which is fine. Naive: stand on the hatch and wait (nothing presses a). Waystone 1 below.

**Room 2, Three Steps Behind (test, from waystone 1).** A 30-tile upper corridor with plates a, b, c every 8 tiles; a lower corridor of hatches A, B, C under them at descending levels, each hatch reachable only from the previous drop. The player runs the whole upper corridor, drops to the first hatch and casts. The ghost runs the corridor 3 s behind; the hatches open in sequence as it passes each plate; the player must be on each hatch when it opens, which means walking the lower corridor at the same pace they ran the upper one, three seconds behind themselves. If they are early they wait; if late (more than 4 s behind, since the ghost's linger does not press plates it is not on) the hatch is shut. The slack is the ghost's 3 s of replay minus the walk between hatches; builders measure it. Naive: stand on each plate 3 s (the memory holds only the last plate; one hatch opens). Naive: two ghosts (the second cast, made later, replays a later stretch; it can cover the last two hatches only if the player plans it, which is the intended solution to room 3). Waystone 2.

**Room 3, Gallery (twist, from waystone 2).** The plates are in a sealed gallery and the only way to run across them is a reflection: the player runs the near corridor, casts at a shrine at its end, and the reflection runs the gallery 3 s behind over the hatches the player is now walking under. Goal below the last hatch.

### 22. The Last Light (act V, finale)

Hint: "Everything you have learned, one ghost at a time."

Four rooms, 96 wide, 32 tall, laid out as a loop: across the top, down the right, back along the bottom, up to the centre where the goal waits in a chamber lit by the first waystone of the game's final screen.

**Room 1, Toll Relay (from the start).** A ferry over a pit whose far dock is a pad (level 17), with a gate mid-pit held by plate a on the near shore (level 13): cast on a on arrival, do the ferry within 7 s (wait 1, walk 1, climb 1, cast), ride through the gate at about 5.5 s, dock, the pad opens the far door. The budget has 1.5 s of slack; the naive (standing 3 s on a) has none. Waystone 1.

**Room 2, The Well (from waystone 1).** A 14-tile scaffold climb (level 20) with one veil strip (level 16). Waystone 2 at the top.

**Room 3, Hall (from waystone 2).** Two shrines 6 tiles apart and a sealed corridor with a plate 12 tiles right of the walkable floor (level 19). The copy of the walk presses the plate; the door opens the way down. Waystone 3.

**Room 4, The Last Light (from waystone 3).** The goal chamber is sealed by doors A, B and C in sequence with a 3-tile waiting room between A and B. Plate a and plate b are 10 tiles apart on the approach; plate c is a pad on a veil column mid-pit in front of the chamber with a shrine on the near shore. Two ghosts, three plates: one ghost does a then b (level 18's shared memory, cast on arrival at b); the other is the ferry that docks on the pad and holds C while carrying the player to the doors (level 17). Cast order matters: the ferry's wait, walk and climb take about 4 s, so the a-and-b ghost must be cast *after* the ferry is cast and before stepping onto it, or A is already shut when the ride ends. The player must see that the ferry is the one to prepare first and the double-plate ghost the one to cast last, from the pedestal, just before stepping aboard. Naive: the natural order (plates first, then the ferry: A shuts at +7, the ride docks at +8). Naive: three casts (the third drops the ferry mid-ride; the player falls into the pit). Goal.

Expected: 20 to 35 minutes for a player who has finished act V's first four levels.

Sketch of room 4 (floor row 28, pit between tiles 70 and 78, chamber from 80):

```
 tiles  58   62        70          74   78  80 82 86
        w....a.........b....M##....c....==.A..A..B..B.C.G.#      c is the pad: the plate cell
        ###################.##....~....##########.......#      with the veil column under it
        ####################.#^^^^^^^^^####################     spikes under the pit
```

The shrine M stands on a pedestal at 68 to 69; the pad at 74 is 5 tiles from the axis, so the ferry docks on it after a walk-away of 5 tiles or more.

## Appendix: what Phase 2 does for one level, in order

1. Draw the map in `game/content/acts/actN.lua` with a waystone at each room entrance. Run `--shot N` and look at each room from its waystone.
2. Write the strategy in `game/dev/solutions/actN.lua` with every decision as a parameter; `--slack N` until every window is 30 frames or 24 px.
3. Declare the rooms with the solve and the naives from this spec; `--selftest` proves them from fresh respawns.
4. `--cheese N` until every room beyond a declared teach room is clean; walk the R8 catalogue by hand.
5. Play it with a pad, from the title, through every waystone, dying once per room on purpose.
