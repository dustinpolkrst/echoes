local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, echoArrived, onLastEcho, doorOpen =
  C.atX, C.atXLeft, C.onTop, C.echoArrived, C.onLastEcho, C.doorOpen
local append = S.append

-- A strategy is a solution written as a human would play it: every decision a human has to time or place is a
-- parameter with the range a player might plausibly pick. dev/slack.lua sweeps each one and reports the winning window,
-- which the selftest holds to 30 frames or 24 px unless the decision says what it needs instead.
local FERRY_DECISIONS = {
  { name = 'footX', unit = 'px', nominal = 166, min = 130, max = 166, step = 2, need = 4, note = 'the pedestal wall stops you here' },
  { name = 'idle', unit = 'frames', nominal = 120, min = 0, max = 240, step = 4 },
  { name = 'turnX', unit = 'px', nominal = 104, min = 30, max = 178, step = 2 },
  { name = 'hopX', unit = 'px', nominal = 130, min = 60, max = 180, step = 2 },
  { name = 'hopHold', unit = 'frames', nominal = 6, min = 1, max = 40, step = 1 },
  { name = 'castX', unit = 'px', nominal = 190, min = 160, max = 210, step = 1 },
  { name = 'castDelay', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
  { name = 'stepDelay', unit = 'frames', nominal = 20, min = 0, max = 200, step = 2 },
  { name = 'stepHold', unit = 'frames', nominal = 3, min = 0, max = 30, step = 1, need = 6, note = 'a tap; the echo is 10 px wide' },
}

-- Wait at the foot of the shrine pedestal, walk away, hop back up, cast, step off onto the waiting reflection, ride.
local function ferry(p)
  return {
    { 'R', atX(p.footX) }, { p.idle, '-' }, { 'L', atXLeft(p.turnX) },
    { 'R', atX(p.hopX) }, { p.hopHold, 'RJ' }, { 'R', onTop(208, 134, 208) },
    { 'R', atX(p.castX) }, { p.castDelay, '-' }, { 1, 'X' },
    { p.stepDelay, '-' }, { 'R', onLastEcho }, { p.stepHold, 'R' }, { '-', echoArrived },
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

local function stopped(w) return w.player.vx == 0 end

-- Jump onto the block, walk to standX, wait there, walk to the shrine, cast, walk through the door onto the hatch.
local function shortMemory(p)
  return {
    { 'R', atX(26) }, { 6, 'RJ' }, { 'R', onTop(208, 54, 112) }, { '-', stopped }, { 'R', atX(p.standX) }, { 'L', atXLeft(p.standX) },
    { p.wait, '-' }, { 'R', atX(163) }, { p.castDelay, '-' }, { 1, 'X' }, { 'R', atX(300) },
  }
end

local strategies = {
  ['Short Memory'] = {
    params = {
      { name = 'standX', unit = 'px', nominal = 87, min = 55, max = 111, step = 2, need = 20, note = 'one plate: a wider pad would let a running ghost hold the door' },
      { name = 'wait', unit = 'frames', nominal = 150, min = 0, max = 300, step = 4 },
      { name = 'castDelay', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
    },
    build = shortMemory,
  },
  ['Ferry'] = {
    params = FERRY_DECISIONS,
    build = function(p) return append(ferry(p), { { 'R', atX(360) } }) end,
  },
  ['Confluence'] = {
    params = append({ { name = 'landDelay', unit = 'frames', nominal = 20, min = 0, max = 240, step = 4 } }, FERRY_DECISIONS),
    build = function(p)
      return append(ferry(p), {
        { p.landDelay, '-' }, { 'R', atX(326) }, { 1, 'X' }, { '-', doorOpen('a') }, { 'R', atX(360) },
      })
    end,
  },
}

-- Rooms: where a room starts (from = nil for the level start, k for the k-th waystone in map order), what counts as its
-- exit (a tile rect { tx0, ty0, tx1, ty1 }, or nil for the goal), the insight it tests, a solve from a fresh respawn at
-- its start, and the naive approaches that must not reach the exit. The selftest proves every solve and every naive.
local rooms = {
  ['Short Memory'] = {
    {
      name = 'Short Memory',
      insight = 'the ghost starts where you were three seconds ago, so wait on the block long enough that it starts past the veil and stands on the plate',
      solve = shortMemory(S.decisions(strategies['Short Memory'])),
      naive = {
        { 'pause on the block, then cast once at the shrine', {
          { 'R', atX(26) }, { 'RJ', onTop(208, 54, 112) }, { 30, '-' }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
        } },
        { 'run to the door and cast at the shrine every other frame', append(
          { { 'R', atX(26) }, { 'RJ', onTop(208, 54, 112) }, { 'R', atX(166) } }, append(mash('R', 2, 300), { { 60, 'R' } })) },
        { 'run to the door and cast at the shrine every 10 frames', append(
          { { 'R', atX(26) }, { 'RJ', onTop(208, 54, 112) }, { 'R', atX(166) } }, append(mash('R', 10, 60), { { 60, 'R' } })) },
        { 'run to the door and cast at the shrine every half second', append(
          { { 'R', atX(26) }, { 'RJ', onTop(208, 54, 112) }, { 'R', atX(166) } }, append(mash('R', 30, 20), { { 60, 'R' } })) },
        { 'wait three seconds before the block, then cast at the shrine', {
          { 'R', atX(26) }, { 180, '-' }, { 'RJ', onTop(208, 54, 112) }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
        } },
      },
    },
  },
  ['Ferry'] = {
    {
      name = 'Crossing',
      insight = 'a reflection waits as long as you did, so wait at the foot before casting from on top',
      solve = strategies['Ferry'].build(S.decisions(strategies['Ferry'])),
      naive = {
        { 'cast on the shrine without waiting at its foot', {
          { 'R', atX(130) }, { 6, 'RJ' }, { 'R', onTop(208, 134, 208) }, { 'R', atX(190) },
          { 10, '-' }, { 1, 'X' }, { 20, '-' }, { 150, 'R' },
        } },
        { 'cast at the foot of the shrine, where nothing reflects', {
          { 'R', atX(166) }, { 120, '-' }, { 'L', atXLeft(104) }, { 'R', atX(166) }, { 1, 'X' },
          { 'L', atXLeft(130) }, { 'R', atX(130) }, { 6, 'RJ' }, { 'R', onTop(208, 134, 208) }, { 20, '-' }, { 150, 'R' },
        } },
      },
    },
  },
}

-- Each ember script starts from the level start, takes the ember and clears the level.
local grounded = C.grounded
local embers = {}

-- Ferry: the far end past the goal is the mirror of the start; can a reflection that remembers the start reach it?
embers['Ferry'] = append({
  { 8, 'J' }, { '-', grounded }, { 'R', atX(130) }, { 6, 'RJ' }, { 'R', onTop(208, 134, 208) }, { 'R', atX(190) }, { 1, 'X' },
  { 'L', atXLeft(120) }, { '-', onTop(224) },
}, strategies['Ferry'].build(S.decisions(strategies['Ferry'])))

-- Short Memory: the three seconds must start on the plate's side; can they also hold a jump at the ember's mirror?
embers['Short Memory'] = {
  { 'R', atX(26) }, { 6, 'RJ' }, { 'R', onTop(208, 54, 112) }, { '-', stopped }, { 'L', atXLeft(68) }, { 'R', atX(68) }, { '-', stopped },
  { 12, 'J' }, { '-', onTop(208) }, { 'R', atX(87) }, { 'L', atXLeft(87) }, { 50, '-' },
  { 'R', atX(163) }, { 10, '-' }, { 1, 'X' }, { 'R', atX(300) },
}

-- Confluence: once the crossing has left the memory, where does the second shrine reflect a hop at the dock?
embers['Confluence'] = (function(p)
  return append(ferry(p), {
    { p.landDelay, '-' }, { 'R', atX(326) }, { 1, 'X' }, { '-', doorOpen('a') },
    { 'L', atXLeft(296) }, { 8, 'J' }, { '-', grounded }, { 'R', atX(326) }, { 90, '-' }, { 1, 'X' }, { 70, '-' }, { 'R', atX(360) },
  })
end)(S.decisions(strategies['Confluence']))

return { strategies = strategies, rooms = rooms, embers = embers }
