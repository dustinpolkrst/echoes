# Level design for Echoes

This is the rulebook for acts IV and V. Part 1 is what the game's rules actually allow, measured in the simulation. Part 2 reads the twelve existing levels against those numbers. Part 3 is the rules every new level follows. Part 4 is the waystone (checkpoint) and what a respawn resets. Part 5 is the file layout, the room declaration format and the tools that check a level. Part 6 is the spec for levels 13 to 22, with what was built recorded beside it. Scaffold was dropped from the original plan and Let Go took its slot.

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
| Passing press | an echo running across a 14 px plate presses it for about 14 frames (0.24 s) | Enough to open a hatch under a standing player; this is how level 9 used to be cheesed (part 2). A player holding into a door needs only one frame of press: the door opens, they step into its cell, and a body inside a door keeps it open. |
| Jump ride | a rider on an echo that replays a jump is lifted the full 50.8 px | Measured: a player standing on a standing echo rode its replayed jump up 50.8 px and never lost support. |
| Ghost of a ghost | an echo recorded while standing on a mid-air echo floats at that spot after the first fades | Measured: echo 2 stayed solid at the recorded height after echo 1 expired. The player has to jump up through it to stand on it, because it occupies the spot they stood in. |
| Mid-air step | a cast up a jump leaves a frozen step; it is landable only if cast less than about 38 px up | At the apex (50.8 px) the step is 62.8 px up and nothing can reach it from the floor below. Level 3 works because the player comes from a ledge. |

### Tiles

| Tile | Rule | Consequence |
| --- | --- | --- |
| Mirror shrine | a cast while touching it reflects the recording about the shrine's centre column; same height, through walls | A sealed room is reachable by a ghost only if the player can stand at its mirror image. |
| Veil | the player walks through; an echo whose next step would enter it stops at the edge and lingers 4 s | A horizontal strip catches a falling ghost; a vertical column is a dock. An echo whose first frame is already inside a veil never moves (a statue). |
| Plate over veil | a plate cell directly above a veil cell is pressed by an echo halted on the veil | A pad only ghosts can press: the player falls through both cells. Measured: halted echo bottom at the veil top, plate pressed, door open. |
| Crumble | cracks 0.5 s after a body stands on it, then gone; regrows 3 s after nothing is inside the cell; echoes count as bodies and keep standing when it goes | The crack starts on the first frame any body stands on the cell, so running across cracks it too; the runner is gone before it falls. A walking ghost breaks stone like a standing one. A ghost standing on the far side of a shrine breaks stone where the player cannot stand. A ghost sitting in the hole keeps it open. |
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
| 6 Other Side | none (fixed) | Was weak: the plate's reflection lay on the floor between the start and the shrine, so running to the door and pressing X swept the reflected ghost across the plate for 14 frames, which opened the door the player was pressed against. Now the plate sits on a ledge in the sealed room and its reflection is a matching ledge above the player's floor. A body on the floor is below the reflection and a jump past it collides with the ledge, so only standing on the ledge presses the plate. Proven naives: cast at the door every half second, bounce off the far wall first, stand under the ledge, cast on the ledge away from the shrine. |
| 7 Trapdoor | one cast on the path | The intended solution is itself shallow (walk onto the plate, cast, fall). Fine for a teaching level. |
| 8 Undertow | standing stack | The hit is the intended solution: the walk-to-x phase fell off the ledge, the recording captured the fall and the echo parked under the veil. Fine for a teaching level. |
| 9 Underfoot | none (fixed) | Was weak: a ghost replays a crossing of the plate exactly 3 s after it happened, and the hatch was 2.5 s of running from the plate, so the replayed run opened the hatch under a player already standing on it. Now the plate sits on a pedestal behind the start (off the run, out of reach of a walk) and the hatch is 4 s of running away, so the replayed crossing comes while the player is still on the bridge: 45 frames early, measured on the touch-then-cast naive. Casting on the plate and running is a solution, because that leaves a ghost on the plate. |
| 10 Ferry | none | Strong. The insight (a reflection waits as long as you waited) cannot be stumbled into; slack is measured at 30+ frames on every decision. |
| 11 Short Memory | none (fixed) | Was mostly strong with a 24-frame window: mashing X at the door made an echo whose memory began while the player ran across the block, its first frames ran over the three-plate pad, and the plate next to the veil let an echo frozen in the veil stand on it. Now the pad is one plate two tiles clear of the veil, and past the door the way on is a hatch in a one-tile shaft that takes 28 frames to reach from the door. A running ghost holds the plate for 14 frames, 18 counting the frames the player holds the door open themselves, measured. Mashing every 2, 10 and 30 frames is a proven naive. The standing spot is one plate wide, 22 px measured, declared with `need = 20`. |
| 12 Confluence | none | Strong. Two insights chained (ferry, then the ghost of the ride) under a time budget the selftest measures. |

Five lessons for the new levels come straight from this table and the levels built from it.

1. A single-room level whose plate lies on the natural path is solved by running and pressing X. Rooms need the plate or the standing spot off the path, or a reason the passing press is not enough. Levels 6 and 9 now put it off the path: a ledge the floor runs under, a pedestal behind the start.
2. A passing echo presses a plate for 14 frames, 3 s after you crossed it (sooner when the memory is not yet full after a respawn). Any door that only has to be open for an instant (a hatch under a standing player, a door cell the player is already touching) is opened by a passing ghost. Use that on purpose (level 20, Three Steps Behind) or design against it: keep the exploit distance longer than 14 frames of running (level 11's shaft is 28 frames from the door), or put the door more than 3 s of travel from the plate so the replayed crossing comes before the player gets there (level 9).
3. The strong levels (10, 12) are the ones where the player has to predict where and when a ghost will be, not just that there will be one.
4. Two doors on one plate do not make the press last. The player can wait at the second door (or on level 11's hatch) for any later press, so two quick crossings of the plate get through as well as one long stand. Level 11 accepts that because a second crossing inside the same 3 s has to be deliberate; a room that needs a long press must also make the second crossing impossible.
5. The view is 30 x 17 with the player 8 px below centre, so a room's key pieces must lie within eight rows of its waystone. Stacking rooms vertically breaks R3 for every room but the first. Level 14 shows the fix: a 17-row map with chimneys between the rooms.

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

- A passing echo presses a plate for 14 frames, and longer if you paused on it (how level 9 was cheesed before its fix). A player holding into the door needs one frame of it.
- An echo whose first frame is inside a veil is a statue at that frame, and a statue on a plate holds it 4 s from the cast (level 11's old 24-frame window; Crawlspace's old Wrong Way Round). Any plate beside a veil the player can step into has this window.
- A masher who casts every half second and stops when the door opens solves any room whose insight is a cast-time window on the natural path (Plumb Line). Keep the right memory start off the default route, or accept it in a teach room.
- A mid-air step cast under 38 px up a jump, and the ladder from it, climb 7 and 9 tiles.
- A standing echo is a 12 px step; two are 24 px.
- A rider is lifted 50.8 px by a replayed jump.
- A fresh memory right after a respawn makes a short echo that arrives early.
- A player inside a door cell keeps it open.
- A veil halts a ghost entering it from any side, so a pad over a veil is safe from a replayed jump from below. The only ghost that presses it comes from above.

## 4. The waystone

`w` in a map is a waystone. Touching it lights it and makes it the respawn point; the one touched last wins, so walking back onto an earlier one moves the respawn back. Lighting one plays a chime, a burst of mint particles and a "waystone lit" label over the player; the tile glows from then on.

What a respawn is: the level is rebuilt from its map and the player is stood on the lit waystone. Nothing carries over: no echoes, an empty memory (the first cast after a respawn replays only what happened since), every door shut unless its plate is pressed, every crumble stone whole, the level clock still running. Death and R both do this. The pause menu's Restart level starts the level over from `P` with a fresh clock.

Why everything resets: it is the only model under which "the room is solvable from its waystone" is a checkable statement. The selftest runs every room's solve from a fresh respawn at its waystone (`testRooms`), so a waystone placed where the room needs a ghost from the previous room fails the build. That is the soft-lock guarantee, and it is why a waystone must sit on ground reachable with nothing carried in.

Placement: on solid ground, never on a one-way, crumble, plate or in a door's column, with the room's sightline from it (R7). One per room, at its entrance. The first room starts at `P` and has no waystone.

## 4b. Embers

`*` in a map is an ember: an optional pickup, one per level, off the main route. The player or any solid echo takes it by
overlapping its 10x10 rect. It is recorded when the level is cleared and survives a respawn only if a waystone was lit
while it was carried, so an ember touched on the way to a death is not kept. Each ember asks one more question of its
level's own idea.

`--selftest` proves for every level: exactly one ember, the main script leaves it in place, and the level's `embers`
script (in `dev/solutions/actN.lua`, beside `scripts`) takes it and clears the level. The question each one asks is the
comment above its script.

Five maps changed geometry for their ember, and `--cheese` was rerun clean on each: Undercroft, Ferryman's Toll and The
Last Light each turned one enclosed rock cell into the ember (only a reflection reaches it); Crawlspace and Let Go each
opened a one-cell ceiling niche with the ember above it. `--slack` is unchanged for all five.

Known below the 24 px / 30 frame bar, all on optional routes: the standing jumps in Other Side (16 to 20 px), Short
Memory (12 to 16 px), Relay and Clockwork (about 20 px, steerable in the air), and Ferry's wall hop. Underfoot's ember
is the weakest idea of the set.

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
      from = 1,                         -- nil: the level start; k: the k-th waystone in map order, row-major, not room order (The Last Light's rooms run from 3, 1, 2)
      exit = { 58, 10, 59, 12 },        -- tile rect { tx0, ty0, tx1, ty1 }, inclusive; nil means the goal; never a door column
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
- `love game --cheese N` prints, per room, any shallow strategy that reaches the exit, with the parameters that did it (direction, hold, the frame or height of the cast, the stack position). No hits reads "no shallow strategy reaches the exit". It runs about 1000 strategies per room in one or two seconds. Validation: planted walls of 5 and 9 tiles are caught (by the single-cast step and by the ladder) and a 10-tile wall is clean; every level from 6 on is clean except Three Steps Behind's declared teach room, whose hits are its intended move. Acts I and II's teach levels (1 to 4, 7, 8) hit as part 2 says.

A room is done when: the solve passes from a fresh respawn, every naive fails, `--slack` shows 30 frames or 24 px on every decision, `--cheese` is clean for the room, and the builder has walked the known-cheese catalogue in R8.

## 6. The new levels

| # | Act | Name | Size (tiles) | Rooms | Core idea | Reasoning | Solve time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 13 | IV | Relay | 48 x 17 | 3 | A ghost cast on arrival opens its door 3 s later. Use the delay. | time | 5 to 8 min |
| 14 | IV | Plumb Line | 75 x 17 | 3 | A falling ghost stops at the first veil below where its memory began. | time, space | 6 to 10 min |
| 15 | IV | Undercroft | 64 x 17 | 3 | A reflected ghost breaks stone where you cannot stand, at your height. | space, time | 8 to 12 min |
| 16 | IV | Crawlspace | 40 x 20 | 3 | A walking ghost stops at a veil and stands where it stops. | space | 8 to 12 min |
| 17 | IV | Ferryman's Toll | 81 x 17 | 3 | The ferry docks on the pad and pays the toll itself. | space, time | 10 to 15 min |
| 18 | V | Clockwork | 74 x 17 | 3 | One memory serves two ghosts; one ghost presses two plates in turn. | time, resources | 12 to 20 min |
| 19 | V | Hall of Mirrors | 39 x 17 | 2 | A reflection stands where you stood, even on air; two shrines reflect one stand twice. | space | 10 to 20 min |
| 20 | V | Three Steps Behind | 57 x 29 | 3 | A running ghost presses each plate for a quarter second, three seconds after you; a pause holds it. | time | 15 to 25 min |
| 21 | V | Let Go | 43 x 21 | 3 | A third cast takes the oldest ghost with it: a cast can shut a door. | resources, time | 15 to 25 min |
| 22 | V | The Last Light | 101 x 17 | 4 | Finale: toll gate ferry, which shrine, twice mirrored, one memory as plate-holder and ferry. | all | 20 to 35 min |

Sizes are targets within the brief's 40 to 90 tiles; builders adjust to fit the sightline rule. Every row is as built; the sections record what changed from the spec and why. Scaffold was dropped and Let Go took its slot, so the game has 22 levels: act V is 18 to 22, and every test keys levels by name. Coordinates in the room notes are tiles from the top-left of the map.

### Act IV as built

The five act IV levels were built and measured against the simulation; where the built level differs from the spec below, the simulation forced it. Three sim facts the spec got wrong, each confirmed with a headless probe before the level was changed:

- A standing cast right after a respawn holds its plate for the memory length plus 4 s, not 7 s. Relay's "stand on the gate plate" means a full 3 s stand.
- A crumble cell starts its 0.5 s crack on the first frame any body stands on it, so a walking ghost breaks stone just as a standing one does (`updateCrumbles` in `world/level.lua`). Undercroft's "weight" insight does not exist; the level is built on what crumble actually does: a reflection breaks stone where you cannot stand, the hole lasts 3 s, a halted ghost standing on a regrown cell re-breaks it, and the reflection keeps your height.
- A ghost halted under a veil strip has its top at the strip's bottom, so a strip 4 tiles up is a step 64 px up that no 50.8 px jump reaches, and a second rung needs a memory that begins above the first strip, which takes 2.7 s of standing on a ghost that lives 4 s. Veils park ghosts; they do not stack them. Crawlspace's ladder cannot exist, and the level uses veils sideways instead.

A red-team pass after the build changed two levels (marked below) and proved each exploit as a failing naive in its room.

Per level, what was built (rooms, insight, measured slack minimum, cheese):

- **13 Relay** (48 x 17, two storeys). Handoff: plates a and b, doors A and B, cast on arrival at b opens B as you reach it. Loop: standing cast on c holds gate C 7 s, arrival cast at the dead-end plate d, back through C to hatch D in the floor (a hatch instead of the spec's shelf, so the return goes through the gate and every door is full height). Encore: the same loop below with the exit door far from the gate, so the far ghost's 7 s must also cover the walk out. Slack minimum 84 frames (the arrival cast's window at d), cheese clean in 5100 runs.
- **14 Plumb Line** (75 x 17, three rooms side by side joined by two-wide one-way chimneys, one-ways at rows 13, 10 and 7). The camera shows eight rows above and below the player, so a stacked shaft can never show a room's pad from its waystone. The level is laid out like the rest of the act, and each room is on screen from its waystone (R1, R3). The Well: as before, one empty row shorter. Wait on the ledge between the strips, drop, cast. Red team: a masher at the bottom wins with a single cast 122 to 168 frames after landing. This is accepted as a teach room, since the winning ghost is the intended one (it begins on the ledge and halts on the pad) and the three before it halt on strip 1. Twin Well: the corridor from waystone 1 ends at a hole whose fall mirrors beside the pad (16 px clear of it). Jumping it leads to a second hole onto the ledge below the first twin strip, whose slot mirrors onto the pad. The shrine is below the pad strip as before. Mashing at the shrine after the first hole, every 10 or 30 frames, is a proven naive. Mashing after the ledge route wins in three casts, which is the insight. Deep Drop (twist): no ledge on the way down. The natural fall lands beside a sealed pad shaft. A one-way ladder from the floor is the only way to its top, so the ghost reaches the pad only by replaying the climb and the drop through the pad, and the cast must come within three seconds of the drop (window 2 to 158 frames after landing, the top wait fully open). Casting at the top of the ladder leaves a ghost standing there (a climbed memory never falls, now a visible herring). Mashing at the door after the natural fall, every 10 or 30 frames, is a proven naive. So are casting on landing, mid-fall, after a long wait, and three seconds after the drop. A replayed jump from below cannot press the pad: a ghost rising into the strip halts under it. Slack minimum 117 frames, cheese clean in 6720 runs. Room retries take 7.5 to 7.7 s from the waystone with nominal waits.
- **15 Undercroft** (64 x 17, three rooms stepping down). Trapfloor: the reflection of the approach walk crosses the gallery's crumble floor; drop into the crawlspace and jump up through the hole within 3 s. Far Side: one stone, whose mirror is in a pocket off the natural path. Sunken Gallery: the gallery floor is one tile lower, so only a walk through the one-deep pit beside the shrine puts the reflection on the stone. The crawlspace is 1 tile tall where the jump goes up through the hole (the spec's 2 tall leaves 2.8 px, not 18). Slack minimum 138 frames, cheese clean in 6060 runs.
- **16 Crawlspace** (38 x 20, three 3-tall corridors). Each room: a plate on a three-wide crumble bed over spikes, a veil column beside it, a pocket beyond, and the door behind the start so the cheese runner never returns to it. Parked: run over the plate into the pocket, cast; the ghost halts at the veil standing on the plate; return over the bed on a one-way ledge, since a halted ghost re-breaks the stone the moment it regrows. Short Memory Lane: an extra veil on the way in; cast only once it is three seconds behind you. Wrong Way Round: the veil is before the plate, so the ghost must walk at it from the pocket side after the stone regrows. The bed is three wide because a body pressing a one-wide plate can stand half on the solid neighbour (found by `--cheese`). Red team: stepping onto the plate and straight back pressed it for up to 18 frames, and three seconds later the replayed step opened the door for a player holding into it (Short Memory Lane fell to one cast, any time in a 50-frame window). Each door now stands behind a three-tile crumble bridge, which takes 32 frames to cross from standing, so the waiting player falls. In Wrong Way Round, stepping into the veil beside the plate and back left a statue on the plate (a 13-frame cast window, mashable at the door), and hopping over the veil skipped the pocket; the bed now runs two tiles past the veil, so the door side cannot reach the plate. The map is 40 wide. Slack minimum 60 frames, cheese clean in 4620 runs.
- **17 Ferryman's Toll** (81 x 17). Three copies of level 10's measured ferry block. Dock: level 10 with a waystone. Toll Gate: the dock is a plate at floor level over a veil over a 2-deep pocket (the reflection's outbound leg is at floor level, so the pad must be too); the halted ferry presses it against the dock column and door A opens for 4 s. Hatch: the pad is mid-pit under a three-wide ceiling hatch; the rider's bottom sits at 212 on a floor-level ghost, so the jump reaches only the upper floor's top (36 px to spare) and the rider jumps up and to the right so the landing clears the open cells whatever their offset on the ferry's back. Pits are two spikes wide because the walk-away must reach the dock yet leave the reflection waiting when you board (a 98 px walk leaves 0.4 s of waiting; 70 px leaves enough). Slack minimum 24 px (castOff) and 7 frames on stepHold with its justified need of 6, as in level 10; cheese clean in 7080 runs.
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

Three rooms side by side in a 75 x 17 map, joined by two-wide one-way chimneys (one-ways at rows 13, 10 and 7). The view is 17 rows tall with the player 8 px below its centre, so a room's key pieces must lie within eight rows of its waystone. A stacked shaft breaks R3 for every room but the first, so each room is one 17-row screen and the chimneys carry the player between them. Veil strips (rows of `~`) cross each room's shaft, and a plate over a veil is the pad (`c` above `~`, with `#` under).

**Room 1, The Well (teach, from the start).** Two strips with a ledge between them. The pad is on the lower strip and door A leads to waystone 1. This is the earlier design, one empty row shorter. Intended: wait on the ledge between the strips, drop, cast. The ghost begins on the ledge, falls, halts on the pad, and A opens for 4 s. Naive: cast at the bottom straight after the fall (the memory begins above the first strip and the ghost halts there). Red team: a masher at the bottom wins with a single cast 122 to 168 frames after landing. That is accepted in a teach room, because the winning ghost is the intended one and the three casts before it halt on strip 1.

**Room 2, Twin Well (test, from waystone 1).** The corridor from waystone 1 ends at a hole. Its fall mirrors beside the pad, 16 px clear of it, so the natural way down fails. Jumping the hole leads to a second hole onto the ledge below the first twin strip, and the slot there mirrors onto the pad. The shrine is below the pad strip. Naive: mashing at the shrine after the first hole, every 10 or 30 frames. Mashing after the ledge route wins in three casts, which is the insight.

**Room 3, Deep Drop (twist, from waystone 2).** No ledge on the way down. The natural fall lands beside a sealed pad shaft. A one-way ladder from the floor is the only way to its top, so the ghost reaches the pad only by replaying the climb and the drop through the pad. The cast must come within three seconds of the drop. The window is 2 to 158 frames after landing, with the top wait fully open. Casting at the top of the ladder leaves a ghost standing there, a visible red herring because a climbed memory never falls. Naives that fail: mashing at the door after the natural fall (every 10 or 30 frames), casting on landing, casting mid-fall, casting after a long wait, and casting three seconds after the drop. A replayed jump from below cannot press the pad, because a ghost rising into the strip halts under it (R8).

Sketch of room 3 (room-local columns, rows 5 to 16; `w` waystone, `=` one-way, `~` veil, `c` pad, `C` door, `G` goal, `t` torch):

```
.....w.......#......###    5  corridor; the shaft starts at column 8
########.....#......###    6
########..t..#==....###    7  ladder top: step off right into the pad shaft
########~~~~~#......###    8  strip 1 across the main shaft
########.....#..ccc.###    9  pad
########.....#==~~~~###   10  pad strip; ladder rung
########.....#......###   11
########..t..#.....t###   12
########.....#==....###   13  ladder bottom rung
########............C.#   14  floor corridor runs under the wall to the door
########.t.........tCG#   15
```

### 15. Undercroft (act IV)

Hint: "A ghost standing still has weight. A ghost that walks does not."

Two storeys: an upper corridor the player walks and a lower corridor 2 tiles tall under it. Sealed galleries open off the upper corridor; their floors are crumble, and they can only be entered from below through a hole in that floor.

**Room 1, Trapfloor (teach, from the start).** A 4-tile crumble section in the upper floor; the goal of the room is the lower corridor. Running across does nothing; standing 0.5 s drops you. Waystone 1 below.

**Room 2, Far Side (test, from waystone 1).** Back in the upper corridor (a one-way ladder returns the player). The shrine at tile 30. A sealed gallery to the right, tiles 32 to 40, floor of crumble, containing waystone 2 and the way on. The lower corridor runs under both. The player sees the gallery through its open left wall above head height (the gallery is 3 tiles above the corridor floor, walled by a 10-tile column). Intended: stand 0.5 s or more at tile 28 (whose reflection is gallery floor tile 32), step onto the shrine, cast. The reflection stands on tile 32 for the 0.5 s it remembers, the stone cracks and goes, the ghost walks off. The hole regrows 3 s after the ghost leaves, about 4 s after the cast. Drop through the room 1 trapfloor behind you (0.8 s), run under (0.5 s), jump up through the hole (spec arithmetic, wrong: from a 2-tall corridor the jump clears the 32 px floor by 2.8 px, not 18; the built crawlspace is 1 tile tall) and land beside it. Naive: cast at the shrine without standing first (the reflection crosses the stones at 0.16 s per tile and nothing cracks). Naive: stand at the wrong tile (the reflection stands on solid gallery floor). Naive: a plain echo in the lower corridor as a step (the ceiling is solid everywhere but the hole, and there is no hole).

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

Built as specified in spirit; two of the three rooms changed shape once they were measured.

Hint: "Two ghosts can share one memory."

**Room 1, Overlap (teach, from the start).** Plates a at 3 and b at 9, doors A at 33 and B at 37 with a waiting room between. Both doors are more than 19 tiles (3 s of running) past both plates, so a passing press can never reach a player standing at a door. Intended: cast standing on a (A held 0 to 7), run to b, cast on arrival (B held from 3 to 7 after that cast), run; A is passed at about 5.0 s. Naive that fails: standing 3 s on both (A shuts 0.8 s before the player arrives). The doors are 3 tiles beyond the first screen; the player sees them after three steps.

**Room 2, One Ghost (test, from waystone 1).** Plate c beside the waystone, a two tiles on, b two tiles past a, a two-tile crumble bridge over spikes, door A, a waiting room, doors B and C side by side. The ghost on c must be a standing cast made first; the other ghost must press a (stand 1 s or more) and then b (cast on arrival). The spec put c "far behind" and used a cap trick in room 3; measured, the cap never forces sharing: a ghost that presses a then b holds a only during its first second, so by the time a third cast could drop an a-ghost its door has already been passed. What forces sharing here is the third plate needing a standing ghost at the end. The crumble bridge is the defence against the level 9 exploit: a player who runs past a and b, casts, and waits at A for the quarter-second press stands on crumble for more than 0.5 s and falls (R8). Keep plates one tile clear of crumble and of shrines: a player stopping on a plate overshoots by about 5 px, and a ghost replaying that stand cracks the next tile.

**Room 3, Double Cast (twist, from waystone 2).** The hall drops a storey; the player lands on plate a, the shrine stands by the wall four tiles on, and the sealed pocket beyond the wall holds plate c at the mirror of a, between spikes. The way on climbs the wall onto the pocket's roof, over a crumble bridge, through doors A and C side by side. One memory, cast twice: plain while standing on a (A held 7 s) and mirrored at the shrine (c held while the reflection stands, about 2 s). The spec's "Three Clocks" was dropped for the reason above.

Measured: selftest clean, `--cheese` clean in all three rooms, slack minimum 90 frames (mirrorDelay), the rest 110 to 410 frames. Failure cost: every room is under 10 s from its waystone.

### 19. Hall of Mirrors (act V)

Two rooms instead of three. The spec's premise, "a reflection of a ride is a ride", is false in the simulation: a mirrored ghost replays its memory in time order, so its ride portion runs from the far mirror point back toward the shrine, and its final pose is always within a tile of the shrine (the player had to touch it to cast). A ferry only goes outward because the walk-away is recorded before the walk back. The same fact kills the spec's "double image": a cast from a ghost's back must touch the second shrine, so the twice-reflected stand lands beside it. A floating reflected stand over a pit was also tried as a stepping stone and dropped: landing on a 10 px ghost by a jump is a 20 px window, under the 24 px bar (R5).

Hint: "A reflection stands where you stood. Even on air."

**Room 1, Which Shrine (from the start).** A three-tile spike pit, the far shrine at 12, the near shrine at 15 by the pocket wall, a sealed pocket whose plate a (two cells) floats over spikes. The plate's reflection about the near shrine is the far shrine's own cell; its reflection about the far shrine lies on the spikes. Stand on the far shrine, walk to the near one, cast, climb the wall onto the pocket's roof, cross the crumble, pass A while the reflection stands on air. Naives that fail: casting at the far shrine, standing beside the near shrine, casting on the move.

**Room 2, Twice Mirrored (from waystone 1).** Drop into the hall, two shrines side by side, a sealed pocket with plates a and b (two cells each) two shrine-spacings apart. One stand reflects onto a about the first shrine and onto b about the second: cast at both within the memory, climb, cross the crumble, pass A and B. Two-cell plates give the stand a 40 px window; one-cell plates give exactly 24. The roof the player walks in on must end three or more tiles before the shrines, or the mirrored walk-in runs along the next roof at that height and cracks its crumble.

Measured: selftest clean, `--cheese` clean, slack minimum 38 px (standX2) and 80 frames (castDelay2, castDelay3).

### Scaffold (dropped, replaced by level 21, Let Go)

Measured infeasible under R5 and R8 together. The cycle "jump, cast under 38 px, land on the step after it arrives, cast again from its back" has this timing: step k+1 arrives 3 s after its cast, and step k fades 4 s after it arrived. The player needs about 0.5 s to land on k and 0.3 s to be back in the air for the next cast, which leaves a cast window of 0.2 s (12 frames) per rung. A fresh memory after a respawn shortens the first replay and allows two rungs with wide windows, which is exactly the two-cast ladder `--cheese` plays, so any wall a human could scaffold is flagged as cheese. Veil strips fix a ghost's height but not the time it arrives. No room survives both rules, so the level is not built. Level 21, Let Go, took its slot and rests on a different idea, the echo cap. Act V has five levels.

### 20. Three Steps Behind (act V)

Hint: "A running ghost presses each plate for a quarter second, three seconds after you did."

Corridors are two tiles tall. A hatch is a door in the floor at the end of a corridor; standing on it and casting is the natural move, and the rooms differ in what the ghost must do three seconds later. A second rule the player discovers in room 2: a ghost that paused on a plate holds it for as long as the pause.

**Room 1, Quarter Second (teach, from the start).** Plate a at 6, hatch A at 11. Run across a, stand on A, cast; the hatch drops you when the ghost crosses a. This is the one room in the act where `--cheese` hits, and every hit is the intended move (one cast on the path, or a standing ghost on a that holds the hatch open), which R5 allows for a teach room.

**Room 2, Three Steps (test, from waystone 1).** Plates a, b, c at 17, 19, 21 two tiles apart, hatch A at 23; below, hatch B four tiles on, then hatch C four tiles on, then the waystone. Running the plates sends the ghost over b and c a third of a second apart while the drops and walks below take 0.8 s each, so pause on b and on c: the ghost holds each hatch for the pause. The memory bounds the pauses from above (about 1.8 s together). Naives that fail: no pauses, standing 3 s on c, casting on arrival at c (B flickers before you reach it), a standing ghost on each plate (the third cast drops the first).

**Room 3, Gallery (twist, from waystone 2).** The plates are sealed in a gallery past the shrine; hatch A is the floor under the shrine. A reflection runs the gallery, so the pauses happen at the mirror spots of the plates on the way in (two tiles apart, the first two tiles past the waystone), and the cast is made standing on A touching the shrine. Naives that fail: running straight to the shrine, one long pause at the first spot, a plain cast beside the shrine.

Measured: selftest clean, `--cheese` clean in rooms 2 and 3, slack minimum 40 frames (holdA2), pauses 60 to 80 frames.

### 21. Let Go (act V)

Built to replace Scaffold. Hint: "A third cast takes the oldest ghost with it. Sometimes that is the point."

Three storeys of three-tall corridor joined by one-way shafts. Door A is both a one-tile gate standing on crumble over spikes and, past one more crumble tile, a five-tile floor over spikes (five, so no jump, step or stack crosses it). Plate a sits behind each waystone, 21 tiles or more from its gate, so the natural run never presses it and a passing press comes while you are still on the way. The kill is cast from inside the doorway, where your own body keeps the gate open, and the crumble under the doorway means you cannot wait there.

**Room 1, Let Go (teach, from the start).** Plate a is behind the start and the gate is 23 tiles on. Stand on a, cast, run, and cast twice from inside the doorway. The third cast takes the ghost on a, and the floor beyond is solid. Naives that fail: no ghost, straight through, one cast in the doorway, two casts before it, waiting in the doorway for the fade, the passing press, the masher, two standing ghosts on a, and jumping the open floor.

**Room 2, Oldest First (test, from waystone 1).** Plate b is met first and a lies behind the waystone. Door B past the floor is held by the ghost on b. The kill takes the oldest ghost, so cast on a first, then on b, then once in the doorway. Two casts in the doorway, room 1's move, take the keeper. Casting at the near plate first leaves the floor open. Standing three seconds on both lets the ghost on a fade before the gate. The budget is standB up to 2.8 s.

**Room 3, Borrowed Time (twist, from waystone 2).** Plate c is on the way and exit door C is behind a crumble tile past the floor. The two kill casts replay a pause on c three seconds later, so the pause is 0.7 to 2.8 s. A shorter pause opens C after the stone before it has gone. A three-second standing cast on c outlives the ghost on a, because the gate is 26 tiles from a and that ghost lives seven seconds.

Measured: selftest clean (369 checks), `--cheese` clean in all three rooms (4800 runs), slack minimum 42 px (killX1) and 140 frames (pauseC). Still open: a blind route that waits at the gate's edge for the ghost on a to fade and walks straight through has a 24-frame window in every room, under the 30-frame bar. From waystones 1 and 2 the gate and exit door lie beyond the first screen (21 and 23 tiles). The plates, which carry each room's new idea, are on it.

Candidates probed for this slot: (A) the echo cap as a tool, picked. (B) The fresh memory after a respawn as a tunable delay, rejected because the intended move is the one-cast sweep `--cheese` already plays. (C) A rider deposited on a shelf by a replayed jump, rejected by arithmetic (rider bottom tops out at 62.8 px against a 64 px shelf) and a window of about 24 frames.

### 22. The Last Light (act V, finale)

Hint: "Everything you have learned, one ghost at a time."

Four rooms left to right, 101 x 17. The ferry rooms copy level 10's dock exactly (one-way shelf, two-tile pedestal with the shrine on its far cell under open sky, a two-tile-tall tunnel past it): the boarding step from the pedestal onto the waiting reflection lands with a 1 px overlap, and every other dock shape tried (one-tile pedestal, two-tile-tall pedestal) lost either the landing or the tap window.

**Room 1, Toll Gate (from the start).** Plate a at 5, the dock, gate A mid-tunnel held by a, a spike, pad c floating over a deeper pit, the veil, door C on the far shore. Cast standing on a (1.5 s or more), do the ferry, ride through the gate, dock on the pad, walk through C. Naives that fail: the ferry alone (the open-tunnel gate scrapes the rider off, and the ghost goes on without them), casting on a on arrival with a fresh memory (the gate shuts 0.5 s before the ride).

**Room 2, Which Shrine (from waystone 1)** and **Room 3, Twice Mirrored (from waystone 2)** are level 19's rooms with the finale's letters (b; a and d). Room 2's approach from the waystone is 15 tiles so the memory is full at the cast; with a shorter approach the fresh memory made the reflection arrive early enough to beat the crumble.

**Room 4, The Last Light (from waystone 3).** The dock again, with plate d at the end of the walk-away and the far shore running fourteen tiles to doors D and C. One memory, two ghosts: idle at the foot, walk away to d and cast there on arrival (that ghost ends on d and holds D from 3 to 7 s), walk back, hop up and cast at the shrine: the same memory mirrored is the ferry, and it docks on pad c. Ride and run the shore: D is reached with 1.5 s to spare. Naive that fails by 0.9 s: standing 3 s on d first. Naives that fail outright: the ferry alone; a standing ghost on d then a ferry prepared afterwards (the ferry's wait is the mirror of the foot idle, which that memory no longer holds). The spec's "two ghosts, three plates" was dropped: the ferry must be the last cast, so only one plain ghost can hold doors at the end, and it holds one plate; a plate pressed early in its memory never needs to survive a third cast.

Waystones: `from` counts waystones in row-major order, so the roof waystones of rooms 2 and 3 are 1 and 2 and room 1's floor waystone is 3.

Measured: selftest clean (232 checks), `--cheese` clean in all four rooms, slack minimum 38 px (turnX1) and 39 frames (hopHold), with stepHold at `need = 6` as in level 10.

### Lessons from building act V

- A crumble bridge of two or more tiles in front of a door is the general defence against the quarter-second press: the player who waits at the door for it falls.
- The memory after a room respawn is empty. Every room solve is proved from a fresh respawn, and a naive that relies on an early ghost (a cast on arrival with a short memory) must be proved to fail from one too.
- Plates sit one tile clear of crumble and shrines, because stopping overshoots by 5 px.
- Two-cell plates widen a reflected stand's window from 24 px to 40 px.
- Anything that lands a jumping player on a single ghost is a 20 px window and fails R5; board ghosts by stepping off ledges, as the ferry does.

## Appendix: what Phase 2 does for one level, in order

1. Draw the map in `game/content/acts/actN.lua` with a waystone at each room entrance. Run `--shot N` and look at each room from its waystone.
2. Write the strategy in `game/dev/solutions/actN.lua` with every decision as a parameter; `--slack N` until every window is 30 frames or 24 px.
3. Declare the rooms with the solve and the naives from this spec; `--selftest` proves them from fresh respawns.
4. `--cheese N` until every room beyond a declared teach room is clean; walk the R8 catalogue by hand.
5. Play it with a pad, from the title, through every waystone, dying once per room on purpose.
