local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, doorOpen, echoArrived, onLastEcho, grounded =
  C.atX, C.atXLeft, C.onTop, C.doorOpen, C.echoArrived, C.onLastEcho, C.grounded
local append = S.append

local T = 16
local function plate(tx) return tx * T + 1 end

-- Relay. Rooms: Handoff (start), Loop (waystone 1), Encore (waystone 2). Every plate is a dead end or on the path,
-- so the only decisions are how long to stand on each plate before casting.
local RELAY_DECISIONS = {
  { name = 'standA', unit = 'frames', nominal = 20, min = 0, max = 300, step = 5 },
  { name = 'standB', unit = 'frames', nominal = 20, min = 0, max = 300, step = 5 },
  { name = 'standC', unit = 'frames', nominal = 190, min = 0, max = 400, step = 5 },
  { name = 'standD', unit = 'frames', nominal = 15, min = 0, max = 240, step = 3 },
  { name = 'standB2', unit = 'frames', nominal = 190, min = 0, max = 400, step = 5 },
  { name = 'standA2', unit = 'frames', nominal = 15, min = 0, max = 240, step = 3 },
}

local LOWER_FLOOR = 15 * T

local function relayHandoff(p)
  return {
    { 'R', atX(plate(3)) }, { p.standA, '-' }, { 1, 'X' },
    { 'R', atX(plate(11)) }, { p.standB, '-' }, { 1, 'X' },
    { 'R', atX(22 * T - 20) }, { '-', doorOpen('b') }, { 'R', atX(plate(23) + 3) },
  }
end

local function relayLoop(p)
  return {
    { 'R', atX(plate(27)) }, { p.standC, '-' }, { 1, 'X' },
    { 'R', atX(plate(46)) }, { p.standD, '-' }, { 1, 'X' },
    { 'L', atXLeft(398) }, { '-', onTop(LOWER_FLOOR) },
  }
end

local function relayEncore(p)
  return {
    { 'R', atX(plate(28)) }, { p.standB2, '-' }, { 1, 'X' },
    { 'R', atX(plate(46)) }, { p.standA2, '-' }, { 1, 'X' },
    { 'L', atXLeft(11 * T + 4) }, { '-', doorOpen('a') }, { 'L', atXLeft(plate(8)) },
  }
end

local strategies = {
  ['Relay'] = {
    params = RELAY_DECISIONS,
    build = function(p) return append(append(relayHandoff(p), relayLoop(p)), relayEncore(p)) end,
  },
}

-- Plumb Line. Rooms: The Well (start), Twin Well (waystone 1), Deep Drop (waystone 2), side by side in a 17-row map so
-- each room is on screen from its waystone; one-way chimneys join a room's floor to the next room's top corridor. The
-- decisions are how long to stand on the ledge the ghost should begin on and how long to wait before casting; in
-- Deep Drop the memory may begin anywhere before the drop through the pad, so both waits there are open-ended.
local PLUMB_DECISIONS = {
  { name = 'ledgeWait', unit = 'frames', nominal = 150, min = 0, max = 400, step = 5 },
  { name = 'castWait1', unit = 'frames', nominal = 15, min = 0, max = 240, step = 3 },
  { name = 'ledgeWait2', unit = 'frames', nominal = 150, min = 0, max = 400, step = 5 },
  { name = 'castWait2', unit = 'frames', nominal = 15, min = 0, max = 240, step = 3 },
  { name = 'topWait', unit = 'frames', nominal = 30, min = 0, max = 300, step = 5 },
  { name = 'castWait3', unit = 'frames', nominal = 20, min = 0, max = 300, step = 3 },
}

local FLOOR = 16 * T

local function plumbWell(p)
  return {
    { 'R', atX(6 * T + 2) }, { '-', onTop(8 * T) }, { p.ledgeWait, '-' },
    { 'L', atXLeft(84) }, { '-', onTop(FLOOR) }, { p.castWait1, '-' }, { 1, 'X' },
    { 'R', atX(19 * T - 12) }, { '-', doorOpen('a') }, { 'R', atX(21 * T) },
  }
end

-- Up a two-wide chimney at tile column cx (one-ways at rows 13, 10 and 7) onto the corridor floor to its right.
local function climb(cx)
  return {
    { 'R', atX(cx * T + 3) }, { '-', onTop(FLOOR) },
    { 20, 'J' }, { '-', onTop(13 * T) }, { 20, 'J' }, { '-', onTop(10 * T) }, { 20, 'J' }, { '-', onTop(7 * T) },
    { 20, 'RJ' }, { 'R', onTop(6 * T, (cx + 2) * T) },
  }
end

-- Twin Well: from waystone 1 the corridor ends at a hole whose fall mirrors beside the pad; the ledge whose mirror is
-- the pad lies past it, under a second hole, and is only reached by jumping the first.
local function twinLedge()
  return { { 'R', atX(39 * T + 2) }, { 14, 'RJ' }, { 'R', onTop(6 * T, 42 * T, 45 * T) }, { 'R', atX(45 * T + 2) }, { '-', onTop(10 * T) } }
end

local function twinCast(castWait, castX)
  return { { 'L', atXLeft(45 * T - 12) }, { '-', onTop(FLOOR) }, { 'L', atXLeft(castX or 38 * T + 1) }, { castWait, '-' }, { 1, 'X' } }
end

local function twinOut(last)
  return append({ { 'R', atX(49 * T - 12) } }, last)
end

local function plumbTwin(p)
  return append(append(append(twinLedge(), { { p.ledgeWait2, '-' } }), twinCast(p.castWait2)),
    twinOut({ { '-', doorOpen('b') }, { 'R', atX(50 * T + 2) } }))
end

-- Deep Drop: the natural fall lands beside a walled pad shaft whose only way in is a one-way ladder from the floor; the
-- ghost replays the climb and the drop through the pad, so the cast just has to come within three seconds of the drop.
local function dropIn()
  return { { 'R', atX(60 * T + 2) }, { '-', onTop(FLOOR) } }
end

local function dropLadder()
  return {
    { 'R', atX(66 * T + 3) }, { '-', grounded },
    { 20, 'J' }, { '-', onTop(13 * T) }, { 20, 'J' }, { '-', onTop(10 * T) }, { 20, 'J' }, { '-', onTop(7 * T) },
  }
end

local function dropOff()
  return { { 'R', atX(68 * T + 2) }, { '-', onTop(FLOOR) } }
end

local function dropOut(last)
  return append({ { 'R', atX(72 * T - 12) } }, last)
end

local function plumbDrop(p)
  return append(append(append(append(dropIn(), dropLadder()), { { p.topWait, '-' } }), dropOff()),
    append({ { p.castWait3, '-' }, { 1, 'X' } }, dropOut({ { '-', doorOpen('c') }, { 'R', atX(73 * T) } })))
end

strategies['Plumb Line'] = {
  params = PLUMB_DECISIONS,
  build = function(p)
    return append(append(append(append(plumbWell(p), climb(24)), plumbTwin(p)), climb(50)), plumbDrop(p))
  end,
}

-- Undercroft. Rooms: Trapfloor (start), Far Side (waystone 1), Sunken Gallery (waystone 2). The decisions are how long
-- to pause at the spot whose reflection is the stone and how long to stand at the shrine before casting.
local UNDER_DECISIONS = {
  { name = 'castDelay1', unit = 'frames', nominal = 10, min = 0, max = 240, step = 3 },
  { name = 'spotWait', unit = 'frames', nominal = 10, min = 0, max = 200, step = 3 },
  { name = 'castDelay2', unit = 'frames', nominal = 10, min = 0, max = 240, step = 3 },
  { name = 'pitWait', unit = 'frames', nominal = 10, min = 0, max = 200, step = 3 },
  { name = 'castDelay3', unit = 'frames', nominal = 10, min = 0, max = 240, step = 3 },
}

local function stoneGone(index)
  return function(w) return w.crumbles[index].gone end
end

local function underTrapfloor(p)
  return {
    { 'R', atX(14 * T + 6) }, { 12, 'RJ' }, { 'R', onTop(7 * T, 17 * T - 10, 18 * T) }, { 'R', atX(17 * T + 5) },
    { p.castDelay1, '-' }, { 1, 'X' },
    { 'L', atXLeft(16 * T + 2) }, { '-', onTop(9 * T) }, { 'R', atX(21 * T) }, { '-', stoneGone(2) },
    { 20, 'RJ' }, { 'R', onTop(7 * T, 19 * T, 26 * T) }, { 'R', atX(plate(24) + 3) },
  }
end

local function underFarSide(p)
  return {
    { 'R', atX(34 * T) }, { '-', onTop(10 * T) }, { 'L', atXLeft(31 * T + 2) }, { p.spotWait, '-' },
    { 'R', atX(35 * T + 5) }, { p.castDelay2, '-' }, { 1, 'X' },
    { 'L', atXLeft(29 * T + 2) }, { '-', onTop(12 * T) }, { 'R', atX(38 * T + 6) }, { '-', stoneGone(5) },
    { 20, 'RJ' }, { 'R', onTop(10 * T, 37 * T, 44 * T) }, { 'R', atX(plate(42) + 3) },
  }
end

local function underSunken(p)
  return {
    { 'R', atX(52 * T) }, { '-', onTop(13 * T) }, { 'L', atXLeft(50 * T + 4) }, { '-', onTop(14 * T) }, { p.pitWait, '-' },
    { 10, 'RJ' }, { 'R', onTop(13 * T, 51 * T, 54 * T) }, { 'R', atX(53 * T + 5) }, { p.castDelay3, '-' }, { 1, 'X' },
    { 'L', atXLeft(50 * T + 4) }, { '-', onTop(14 * T) }, { 'L', atXLeft(48 * T + 2) }, { 10, 'LJ' },
    { 'L', onTop(13 * T, 45 * T, 48 * T) }, { 'L', atXLeft(46 * T + 4) }, { '-', onTop(16 * T) },
    { 'R', atX(56 * T + 6) }, { '-', stoneGone(8) }, { 20, 'RJ' }, { 'R', onTop(14 * T, 55 * T, 62 * T) }, { 'R', atX(60 * T + 2) },
  }
end

strategies['Undercroft'] = {
  params = UNDER_DECISIONS,
  build = function(p) return append(append(underTrapfloor(p), underFarSide(p)), underSunken(p)) end,
}

-- Crawlspace. Rooms: Parked (start), Short Memory Lane (waystone 1), Wrong Way Round (waystone 2). Each run ends in a
-- pocket; the decisions are how long to wait there before casting, and in room 3 how long after the stone regrows.
local CRAWL_DECISIONS = {
  { name = 'castDelay1', unit = 'frames', nominal = 20, min = 0, max = 240, step = 3 },
  { name = 'castDelay2', unit = 'frames', nominal = 90, min = 0, max = 240, step = 3 },
  { name = 'pocketWait3', unit = 'frames', nominal = 30, min = 0, max = 300, step = 5 },
  { name = 'castDelay3', unit = 'frames', nominal = 10, min = 0, max = 240, step = 3 },
}

local function stoneBack(index)
  return function(w) return not w.crumbles[index].gone end
end

-- Back over the ledge to the solid ground before the door's crumble bridge (bridgeX is its first tile), then across.
local function crawlLedgeBack(row, bridgeX, doorId, shaftX, landing)
  return {
    { 'R', atX(17 * T + 2) }, { 14, 'RJ' }, { 'R', onTop(row * T, 18 * T, 23 * T) }, { 'R', atX(23 * T + 2) },
    { '-', onTop((row + 2) * T) }, { 'R', atX(bridgeX * T - 16) }, { '-', doorOpen(doorId) },
    { 'R', atX(shaftX * T + 2) }, { '-', onTop(landing * T) },
  }
end

local function crawlParked(p)
  return append({ { 'L', atXLeft(14 * T + 2) }, { p.castDelay1, '-' }, { 1, 'X' } }, crawlLedgeBack(3, 24, 'a', 28, 11))
end

local function crawlShortMemory(p)
  return append({ { 'L', atXLeft(14 * T + 2) }, { p.castDelay2, '-' }, { 1, 'X' } }, crawlLedgeBack(9, 30, 'b', 34, 17))
end

-- Crumble cells in map order: 1-3 room 1's bed, 4-6 its bridge, 7-9 room 2's bed, 10-12 its bridge, 13-17 room 3's bed,
-- which runs two tiles past the veil so the plate cannot be reached from the door side.
local function crawlWrongWay(p)
  return {
    { 'L', atXLeft(23 * T + 2) }, { '-', stoneBack(13) }, { p.pocketWait3, '-' },
    { 'R', atX(32 * T + 2) }, { p.castDelay3, '-' }, { 1, 'X' },
    { 'R', atX(36 * T - 12) }, { '-', doorOpen('c') }, { 'R', atX(38 * T) },
  }
end

-- Casts every `every` frames, `times` times, holding `keys` throughout.
local function mash(keys, every, times)
  local out = {}
  for _ = 1, times do
    out[#out + 1] = { 1, keys .. 'X' }
    if every > 1 then out[#out + 1] = { every - 1, keys } end
  end
  return out
end

-- Casts every `every` frames until door `id` opens, at most `times` casts; stops casting the frame it opens.
local function mashUntilOpen(id, every, times)
  local out = {}
  for _ = 1, times do
    local n, fired = 0, false
    out[#out + 1] = { '-', function(w)
      n = n + 1
      if w.doorOpen[id] or n >= every then n = 0 return true end
      return false
    end }
    out[#out + 1] = { 'X', function(w)
      if w.doorOpen[id] or fired then fired = false return true end
      fired = true
      return false
    end }
  end
  return out
end

-- Steps onto the plate and straight back off the crumble, waits before the bridge casting until the door opens, runs.
local function crawlDip(plateX, waitX, id, every)
  return append(append({ { 'L', atXLeft(plateX * T + 10) }, { 'R', atX(waitX * T - 16) } }, mashUntilOpen(id, every, math.floor(400 / every))),
    { { 150, 'R' }, { 60, '-' } })
end

strategies['Crawlspace'] = {
  params = CRAWL_DECISIONS,
  build = function(p) return append(append(crawlParked(p), crawlShortMemory(p)), crawlWrongWay(p)) end,
}

-- Ferryman's Toll. Three copies of level 10's ferry, one per room, so the decisions are level 10's written relative to
-- each room's block (x0 tiles in) and shared by the three rooms; the slack window is the intersection.
local TOLL_DECISIONS = {
  { name = 'footX', unit = 'px', nominal = 166, min = 130, max = 166, step = 2, need = 4, note = 'the pedestal wall stops you here' },
  { name = 'idle', unit = 'frames', nominal = 120, min = 0, max = 240, step = 4 },
  { name = 'walkAway', unit = 'px', nominal = 70, min = 10, max = 136, step = 2 },
  { name = 'hopBack', unit = 'px', nominal = 36, min = 6, max = 100, step = 2 },
  { name = 'hopHold', unit = 'frames', nominal = 6, min = 1, max = 40, step = 1 },
  { name = 'castOff', unit = 'px', nominal = 24, min = 0, max = 44, step = 1 },
  { name = 'castDelay', unit = 'frames', nominal = 4, min = 0, max = 150, step = 2 },
  { name = 'stepDelay', unit = 'frames', nominal = 8, min = 0, max = 200, step = 2 },
  { name = 'stepHold', unit = 'frames', nominal = 3, min = 0, max = 30, step = 1, need = 6, note = 'a tap; the echo is 10 px wide' },
}

-- Wait at the foot of the pedestal, walk away, hop onto the step, cast on the shrine, step onto the waiting
-- reflection and ride until it halts at the dock.
local function toll(p, x0)
  local o = x0 * T
  local foot = o + p.footX
  return {
    { 'R', atX(foot) }, { p.idle, '-' }, { 'L', atXLeft(foot - p.walkAway) },
    { 'R', atX(foot - p.hopBack) }, { p.hopHold, 'RJ' }, { 'R', onTop(13 * T, o + 134, o + 208) },
    { 'R', atX(foot + p.castOff) }, { p.castDelay, '-' }, { 1, 'X' },
    { p.stepDelay, '-' }, { 'R', onLastEcho }, { p.stepHold, 'R' }, { '-', echoArrived },
  }
end

local function tollDock(p) return append(toll(p, 0), { { 'R', atX(plate(21) + 3) } }) end
local function tollGate(p) return append(toll(p, 27), { { 'R', atX(47 * T - 12) }, { '-', doorOpen('a') }, { 'R', atX(plate(49) + 3) } }) end
local function tollHatch(p) return append(toll(p, 54), { { 14, 'RJ' }, { 'R', onTop(11 * T, 73 * T, 80 * T) }, { 'R', atX(78 * T) } }) end

strategies["Ferryman's Toll"] = {
  params = TOLL_DECISIONS,
  build = function(p) return append(append(tollDock(p), tollGate(p)), tollHatch(p)) end,
}

local function nominal(name) return S.decisions(strategies[name]) end

local rooms = {
  ['Relay'] = {
    {
      name = 'Handoff',
      insight = 'a ghost opens a door when it reaches the plate, so a door three seconds away opens as you arrive',
      exit = { 23, 1, 23, 6 },
      solve = relayHandoff(nominal('Relay')),
      naive = {
        { 'run without casting', { { 'R', atX(plate(11)) }, { 300, 'R' } } },
        { 'cast on a only', { { 'R', atX(plate(3)) }, { 20, '-' }, { 1, 'X' }, { 'R', atX(plate(11)) }, { 400, 'R' } } },
      },
    },
    {
      name = 'Loop',
      insight = 'stand on the gate plate so its ghost holds seven seconds, cast on arrival at the far plate so you are back before the gate shuts',
      from = 1,
      exit = { 20, 8, 30, 14 },
      solve = relayLoop(nominal('Relay')),
      naive = {
        { 'stand three seconds on the far plate too', relayLoop(S.decisions(strategies['Relay'], { standD = 190 })) },
        { 'cast on the gate plate on arrival', relayLoop(S.decisions(strategies['Relay'], { standC = 10 })) },
        { 'cast on the gate plate only and run the corridor', {
          { 'R', atX(plate(27)) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(plate(46)) }, { 'L', atXLeft(398) }, { 300, '-' },
        } },
      },
    },
    {
      name = 'Encore',
      insight = 'the exit is far from the gate, so the far ghost must still be holding when you get there and the gate ghost must outlast the trip',
      from = 2,
      solve = relayEncore(nominal('Relay')),
      naive = {
        { 'stand three seconds on the far plate too', relayEncore(S.decisions(strategies['Relay'], { standA2 = 190 })) },
        { 'cast on the gate plate on arrival', relayEncore(S.decisions(strategies['Relay'], { standB2 = 10 })) },
        { 'cast on the gate plate only and run to the exit', {
          { 'R', atX(plate(28)) }, { 190, '-' }, { 1, 'X' }, { 'L', atXLeft(11 * T + 4) }, { 400, '-' },
        } },
      },
    },
  },
}

local function plumb(overrides) return S.decisions(strategies['Plumb Line'], overrides) end

-- The way down a player takes without the insight: off the corridor's end into the first hole, then along to the shrine.
local function twinNatural()
  return { { 'R', atX(40 * T + 2) }, { '-', onTop(FLOOR) }, { 'L', atXLeft(38 * T + 1) } }
end

local function twinMash(every)
  return append(append(twinNatural(), mashUntilOpen('b', every, math.floor(400 / every))), twinOut({ { 300, 'R' } }))
end

-- The way down in Deep Drop: off the corridor into the shaft, then along the floor to the door.
local function dropMash(every)
  return append(append(dropIn(), dropOut({})), append(mashUntilOpen('c', every, math.floor(400 / every)), { { 150, 'R' }, { 60, '-' } }))
end

rooms['Plumb Line'] = {
  {
    name = 'The Well',
    insight = 'a ghost begins where you were three seconds ago, so wait on the ledge between the strips before you drop',
    exit = { 20, 14, 22, 15 },
    solve = plumbWell(nominal('Plumb Line')),
    naive = {
      { 'drop straight through and cast at the bottom', plumbWell(plumb({ ledgeWait = 0, castWait1 = 0 })) },
      { 'wait on the ledge and cast there', {
        { 'R', atX(6 * T + 2) }, { '-', onTop(8 * T) }, { 200, '-' }, { 1, 'X' }, { 'L', atXLeft(84) }, { '-', onTop(FLOOR) },
        { 'R', atX(19 * T - 12) }, { 400, '-' },
      } },
      { 'wait at the bottom instead of on the ledge', plumbWell(plumb({ ledgeWait = 0, castWait1 = 200 })) },
    },
  },
  {
    name = 'Twin Well',
    insight = 'the reflection falls in the sealed shaft from the mirror of where you waited, so wait on the ledge below the first twin strip, not at the corridor',
    from = 1,
    exit = { 50, 14, 51, 15 },
    solve = plumbTwin(nominal('Plumb Line')),
    naive = {
      { 'walk off into the first hole and cast at the shrine', append(append(twinNatural(), { { 15, '-' }, { 1, 'X' } }), twinOut({ { 400, '-' } })) },
      { 'walk off into the first hole and cast at the shrine every 10 frames until the door opens', twinMash(10) },
      { 'walk off into the first hole and cast at the shrine every half second until the door opens', twinMash(30) },
      { 'take the ledge but do not wait on it', plumbTwin(plumb({ ledgeWait2 = 0 })) },
      { 'wait at the corridor instead of on the ledge', append(append(append({ { 200, '-' } }, twinLedge()), twinCast(10)), twinOut({ { 400, '-' } })) },
      { 'a plain cast beside the shrine', append(append(append(twinLedge(), { { 150, '-' } }), twinCast(10, 40 * T)), twinOut({ { 400, '-' } })) },
    },
  },
  {
    name = 'Deep Drop',
    insight = 'the pad shaft has no way in from above, so the ghost gets there only by replaying your climb up the ladder and your drop through the pad',
    from = 2,
    solve = plumbDrop(nominal('Plumb Line')),
    naive = {
      { 'drop and cast the moment you land', append(append(dropIn(), { { 1, 'X' } }), dropOut({ { 400, '-' } })) },
      { 'drop, wait, then cast', append(append(dropIn(), { { 200, '-' }, { 1, 'X' } }), dropOut({ { 400, '-' } })) },
      { 'cast in mid-air below the strip', append({ { 'R', atX(60 * T + 2) }, { 30, '-' }, { 1, 'X' }, { '-', onTop(FLOOR) } }, dropOut({ { 400, '-' } })) },
      { 'drop and cast every 10 frames at the door until it opens', dropMash(10) },
      { 'drop and cast every half second at the door until it opens', dropMash(30) },
      { 'run and cast every 10 frames all the way to the door', append(mash('R', 10, 60), { { 60, '-' } }) },
      { 'climb the ladder and cast at the top', append(append(append(append(dropIn(), dropLadder()), { { 20, '-' }, { 1, 'X' } }), dropOff()), dropOut({ { 400, '-' } })) },
      { 'drop through the pad and wait three seconds before casting', plumbDrop(plumb({ castWait3 = 200 })) },
    },
  },
}

local function under(overrides) return S.decisions(strategies['Undercroft'], overrides) end

rooms['Undercroft'] = {
  {
    name = 'Trapfloor',
    insight = 'the reflection of your walk breaks the sealed gallery floor, and the hole is there for three seconds',
    exit = { 23, 4, 25, 6 },
    solve = underTrapfloor(nominal('Undercroft')),
    naive = {
      { 'stand at the shrine a while, then cast', underTrapfloor(under({ castDelay1 = 200 })) },
      { 'cast on the way, before the shrine', {
        { 'R', atX(13 * T) }, { 1, 'X' }, { 'R', atX(14 * T + 6) }, { 12, 'RJ' }, { 'R', onTop(7 * T, 17 * T - 10, 18 * T) },
        { 'L', atXLeft(16 * T + 2) }, { '-', onTop(9 * T) }, { 'R', atX(21 * T) }, { 60, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
      { 'crawl under without any ghost', {
        { 'R', atX(15 * T + 2) }, { '-', onTop(9 * T) }, { 'R', atX(21 * T) }, { 20, 'RJ' }, { 300, 'R' },
      } },
    },
  },
  {
    name = 'Far Side',
    insight = 'one stone, one spot: the reflection of the pocket floor is the gallery floor, so walk the stone\'s mirror before you cast',
    from = 1,
    exit = { 41, 8, 43, 9 },
    solve = underFarSide(nominal('Undercroft')),
    naive = {
      { 'cast on arrival without visiting the pocket', {
        { 'R', atX(34 * T) }, { '-', onTop(10 * T) }, { 'R', atX(35 * T + 5) }, { 10, '-' }, { 1, 'X' },
        { 'L', atXLeft(29 * T + 2) }, { '-', onTop(12 * T) }, { 'R', atX(38 * T + 6) }, { 120, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
      { 'visit the pocket only after casting', {
        { 'R', atX(34 * T) }, { '-', onTop(10 * T) }, { 'R', atX(35 * T + 5) }, { 10, '-' }, { 1, 'X' },
        { 'L', atXLeft(31 * T + 2) }, { 30, '-' }, { 'L', atXLeft(29 * T + 2) }, { '-', onTop(12 * T) }, { 'R', atX(38 * T + 6) },
        { 120, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
      { 'cast at the spot instead of the shrine', {
        { 'R', atX(34 * T) }, { '-', onTop(10 * T) }, { 'L', atXLeft(31 * T + 2) }, { 10, '-' }, { 1, 'X' },
        { 'L', atXLeft(29 * T + 2) }, { '-', onTop(12 * T) }, { 'R', atX(38 * T + 6) }, { 180, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
    },
  },
  {
    name = 'Sunken Gallery',
    insight = 'the reflection keeps your height, so a sunken floor is only broken by walking the sunken pit',
    from = 2,
    solve = underSunken(nominal('Undercroft')),
    naive = {
      { 'walk the pocket floor beside the pit, not into it', {
        { 'R', atX(52 * T) }, { '-', onTop(13 * T) }, { 'L', atXLeft(51 * T + 6) }, { 30, '-' }, { 'R', atX(53 * T + 5) },
        { 10, '-' }, { 1, 'X' }, { 'L', atXLeft(50 * T + 4) }, { '-', onTop(14 * T) }, { 'L', atXLeft(48 * T + 2) }, { 10, 'LJ' },
        { 'L', onTop(13 * T, 45 * T, 48 * T) }, { 'L', atXLeft(46 * T + 4) }, { '-', onTop(16 * T) },
        { 'R', atX(56 * T + 6) }, { 150, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
      { 'cast on arrival at the shrine', {
        { 'R', atX(52 * T) }, { '-', onTop(13 * T) }, { 'R', atX(53 * T + 5) }, { 10, '-' }, { 1, 'X' },
        { 'L', atXLeft(50 * T + 4) }, { '-', onTop(14 * T) }, { 'L', atXLeft(48 * T + 2) }, { 10, 'LJ' },
        { 'L', onTop(13 * T, 45 * T, 48 * T) }, { 'L', atXLeft(46 * T + 4) }, { '-', onTop(16 * T) },
        { 'R', atX(56 * T + 6) }, { 150, '-' }, { 20, 'RJ' }, { 200, 'R' },
      } },
    },
  },
}

local function crawl(overrides) return S.decisions(strategies['Crawlspace'], overrides) end

rooms['Crawlspace'] = {
  {
    name = 'Parked',
    insight = 'a walking ghost stops at the veil, and a veil just past the plate parks it on a plate you cannot stand on',
    exit = { 28, 8, 29, 10 },
    solve = crawlParked(nominal('Crawlspace')),
    naive = {
      { 'cast before reaching the veil', append({ { 'L', atXLeft(22 * T) }, { 1, 'X' }, { 'L', atXLeft(14 * T + 2) }, { 60, '-' } },
        { { 'R', atX(17 * T + 2) }, { 14, 'RJ' }, { 'R', onTop(3 * T, 18 * T, 23 * T) }, { 'R', atX(23 * T + 2) }, { '-', onTop(5 * T) },
          { 300, '-' }, { 150, 'R' }, { 60, '-' } }) },
      { 'walk out along the ledge instead of the floor', {
        { 'L', atXLeft(23 * T + 10) }, { 14, 'LJ' }, { 'L', onTop(3 * T, 18 * T, 23 * T) }, { 'L', atXLeft(18 * T - 2) },
        { '-', onTop(5 * T) }, { 'L', atXLeft(14 * T + 2) }, { 20, '-' }, { 1, 'X' },
        { 'R', atX(17 * T + 2) }, { 14, 'RJ' }, { 'R', onTop(3 * T, 18 * T, 23 * T) }, { 'R', atX(23 * T + 2) }, { '-', onTop(5 * T) },
        { 300, '-' }, { 150, 'R' }, { 60, '-' },
      } },
      { 'stand on the plate', { { 'L', atXLeft(20 * T + 3) }, { 120, '-' } } },
      { 'step onto the plate and back, then cast every 10 frames before the bridge', crawlDip(20, 24, 'a', 10) },
      { 'step onto the plate and back, then cast every half second before the bridge', crawlDip(20, 24, 'a', 30) },
    },
  },
  {
    name = 'Short Memory Lane',
    insight = 'the ghost stops at the first veil in its memory, so wait until the veil you passed is three seconds behind you',
    from = 1,
    exit = { 34, 14, 35, 16 },
    solve = crawlShortMemory(nominal('Crawlspace')),
    naive = {
      { 'cast on arrival in the pocket', crawlShortMemory(crawl({ castDelay2 = 0 })) },
      { 'wait too long in the pocket', crawlShortMemory(crawl({ castDelay2 = 200 })) },
      { 'step onto the plate and back, then cast every other frame before the bridge', crawlDip(20, 30, 'b', 2) },
      { 'step onto the plate and back, then cast every 10 frames before the bridge', crawlDip(20, 30, 'b', 10) },
      { 'step onto the plate and back, then cast every half second before the bridge', crawlDip(20, 30, 'b', 30) },
    },
  },
  {
    name = 'Wrong Way Round',
    insight = 'the veil is before the plate, so the ghost must walk at it from the pocket side: wait for the stone, walk back over it and cast',
    from = 2,
    solve = crawlWrongWay(nominal('Crawlspace')),
    naive = {
      { 'cast in the pocket as before', {
        { 'L', atXLeft(23 * T + 2) }, { 60, '-' }, { 1, 'X' }, { '-', stoneBack(13) }, { 'R', atX(36 * T - 12) }, { 400, '-' },
      } },
      { 'walk back before the stone regrows', { { 'L', atXLeft(23 * T + 2) }, { 30, '-' }, { 'R', atX(36 * T - 12) }, { 300, '-' } } },
      { 'step into the veil beside the plate and back, then cast every 5 frames at the door', append(
        { { 'L', atXLeft(29 * T - 4) }, { 'R', atX(36 * T - 11) } }, append(mash('R', 5, 80), { { 60, 'R' } })) },
      { 'hop over the veil onto the plate and back, then cast every 10 frames at the door', append(
        { { 'L', atXLeft(32 * T + 4) }, { 12, 'LJ' }, { 'L', grounded }, { 12, 'RJ' }, { 'R', grounded }, { 'R', atX(36 * T - 11) } },
        append(mash('R', 10, 40), { { 60, 'R' } })) },
    },
  },
}

local function tollWith(overrides) return S.decisions(strategies["Ferryman's Toll"], overrides) end

rooms["Ferryman's Toll"] = {
  {
    name = 'Dock',
    insight = 'the ferry goes out as far as you walked away and the veil stops it there',
    exit = { 20, 12, 22, 13 },
    solve = tollDock(nominal("Ferryman's Toll")),
    naive = {
      { 'cast on the shrine without waiting at its foot', tollDock(tollWith({ idle = 0 })) },
      { 'jump the pit', { { 'R', atX(13 * T) }, { 40, 'RJ' }, { 120, 'R' } } },
    },
  },
  {
    name = 'Toll Gate',
    insight = 'the dock is a pad only a ghost can press, and the ferry halts on it, so it pays the toll while you walk through',
    from = 1,
    exit = { 49, 12, 50, 13 },
    solve = tollGate(nominal("Ferryman's Toll")),
    naive = {
      { 'walk away too little, so the ferry turns before the pad', tollGate(tollWith({ walkAway = 40 })) },
      { 'ride over, wait for the ferry to fade, then cast your own echo at the pad', append(toll(nominal("Ferryman's Toll"), 27), {
        { 'R', atX(46 * T + 2) }, { 300, '-' }, { 'L', atXLeft(44 * T + 2) }, { '-', onTop(16 * T) }, { 190, '-' }, { 1, 'X' },
        { 20, 'RJ' }, { 'R', onTop(14 * T, 45 * T, 47 * T) }, { 'R', atX(47 * T - 12) }, { 300, '-' },
      }) },
    },
  },
  {
    name = 'Hatch',
    insight = 'the pad is mid-pit under a hatch: walk away far enough that the ferry reaches it, and jump up while it holds',
    from = 2,
    solve = tollHatch(nominal("Ferryman's Toll")),
    naive = {
      { 'walk away too little, so the ferry turns before the pad', tollHatch(tollWith({ walkAway = 40 })) },
      { 'cast on the shrine without waiting at its foot', tollHatch(tollWith({ idle = 0 })) },
    },
  },
}

return { scripts = {}, strategies = strategies, rooms = rooms }
