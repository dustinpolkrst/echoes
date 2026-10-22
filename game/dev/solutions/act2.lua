local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, echoArrived, onLastEcho, doorOpen =
  C.atX, C.atXLeft, C.onTop, C.echoArrived, C.onLastEcho, C.doorOpen
local append = S.append

local scripts = {
  ['Trapdoor'] = {
    { 'R', atX(190) }, { 1, 'X' }, { '-', onTop(224) },
    { 'R', atX(255) }, { '-', doorOpen('a') }, { 'R', atX(340) },
  },
  ['Undertow'] = {
    { 'R', atX(70) }, { '-', onTop(224) }, { 1, 'X' }, { '-', echoArrived },
    { 'J', onLastEcho }, { 'LJ', onTop(144, 0, 54) }, { 'L', atXLeft(40) },
  },
}

-- Casts every `every` frames, `times` times, holding `keys` throughout. Two echoes live at once, so a cast every
-- 30 frames keeps an echo alive at every moment any part of the last three seconds could replay.
local function mash(keys, every, times)
  local out = {}
  for _ = 1, times do
    out[#out + 1] = { 1, keys .. 'X' }
    out[#out + 1] = { every - 1, keys }
  end
  return out
end

local strategies = {
  ['Other Side'] = {
    params = {
      { name = 'hopX', unit = 'px', nominal = 96, min = 60, max = 115, step = 2 },
      { name = 'hopHold', unit = 'frames', nominal = 12, min = 1, max = 40, step = 1, need = 24, note = 'how long jump is held: a short press falls short of the ledge, a long one carries past it' },
      { name = 'stand', unit = 'frames', nominal = 150, min = 0, max = 300, step = 4 },
      { name = 'castDelay', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
    },
    -- Hop onto the ledge that mirrors the plate's ledge, stand, drop to the shrine, cast, walk through the door.
    build = function(p)
      return {
        { 'L', atXLeft(p.hopX) }, { p.hopHold, 'LJ' }, { 'L', onTop(192, 30, 90) }, { p.stand, '-' },
        { 'R', atX(163) }, { p.castDelay, '-' }, { 1, 'X' }, { 'R', atX(300) },
      }
    end,
  },
  ['Underfoot'] = {
    params = {
      { name = 'hopX', unit = 'px', nominal = 70, min = 48, max = 83, step = 1 },
      { name = 'hopHold', unit = 'frames', nominal = 12, min = 1, max = 40, step = 1 },
      { name = 'stand', unit = 'frames', nominal = 190, min = 0, max = 300, step = 4 },
      { name = 'leaveDelay', unit = 'frames', nominal = 10, min = 0, max = 240, step = 4 },
    },
    -- Hop onto the pedestal, stand on the plate, cast, run the long bridge to the hatch while the ghost holds the plate.
    build = function(p)
      return {
        { 'L', atXLeft(p.hopX) }, { p.hopHold, 'LJ' }, { 'L', onTop(112) }, { 'L', atXLeft(16) },
        { p.stand, '-' }, { 1, 'X' }, { p.leaveDelay, '-' }, { 'R', atX(420) }, { '-', onTop(224) }, { 'R', atX(470) },
      }
    end,
  },
}

local rooms = {
  ['Other Side'] = {
    {
      name = 'Other Side',
      insight = 'the plate\'s reflection is the ledge, not the floor, so the ghost presses the plate only if you were up there',
      solve = strategies['Other Side'].build(S.decisions(strategies['Other Side'])),
      naive = {
        { 'run to the door and cast at the shrine every half second', append(
          { { 'R', atX(166) } }, append(mash('R', 30, 12), { { 60, 'R' } })) },
        { 'run under the ledge to the wall and back, then cast at the shrine every half second', append(
          { { 'L', atXLeft(16) }, { 'R', atX(166) } }, append(mash('R', 30, 12), { { 60, 'R' } })) },
        { 'stand three seconds under the ledge, then cast at the shrine', {
          { 'L', atXLeft(62) }, { 200, '-' }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
        } },
        { 'stand three seconds on the ledge and cast there', {
          { 'L', atXLeft(96) }, { 12, 'LJ' }, { 'L', onTop(192, 30, 90) }, { 200, '-' }, { 1, 'X' },
          { 'R', atX(300) },
        } },
      },
    },
  },
  ['Underfoot'] = {
    {
      name = 'Underfoot',
      insight = 'the hatch is more than three seconds from the plate, so only a ghost left standing on the plate opens it under you',
      solve = strategies['Underfoot'].build(S.decisions(strategies['Underfoot'])),
      naive = {
        { 'run onto the hatch and cast every half second', append(
          { { 'R', atX(430) } }, append(mash('-', 30, 12), { { 60, '-' } })) },
        { 'touch the plate, run onto the hatch and cast every half second', append(
          { { 'L', atXLeft(56) }, { 12, 'LJ' }, { 'L', onTop(112) }, { 'L', atXLeft(16) }, { 'R', atX(430) } },
          append(mash('-', 30, 12), { { 60, '-' } })) },
        { 'stand on the plate without an echo, then run to the hatch', {
          { 'L', atXLeft(56) }, { 12, 'LJ' }, { 'L', onTop(112) }, { 'L', atXLeft(16) }, { 200, '-' },
          { 'R', atX(430) }, { 200, '-' },
        } },
      },
    },
  },
}

-- Holding a direction until the player is under (or over) the last echo, from its right.
local function atLastEcho(w)
  local e = w.echoes[#w.echoes]
  return e ~= nil and w.player.x <= e.x + 2
end

-- Each ember script starts from the level start, takes the ember and clears the level.
local embers = {}

-- Other Side: the reflection copies your jump as well as your stand; can it reach the ember high in the sealed room?
embers['Other Side'] = {
  { 'L', atXLeft(96) }, { 12, 'LJ' }, { 'L', onTop(192, 30, 90) }, { 'R', atX(64) }, { 30, '-' },
  { 20, 'J' }, { '-', onTop(192) }, { 40, '-' },
  { 'R', atX(163) }, { 10, '-' }, { 1, 'X' }, { 60, '-' }, { 'R', atX(300) },
}

-- Trapdoor: the floor will not hold you if you stop on it; will it hold you if you run?
embers['Trapdoor'] = {
  { 'R', atX(240) }, { 220, '-' }, { 'L', atXLeft(195) }, { 1, 'X' }, { '-', onTop(224) },
  { 'R', atX(255) }, { '-', doorOpen('a') }, { 'R', atX(340) },
}

-- Undertow: your echo stops where you fell through; where must you fall for it to lift you to the ember and still take you home?
embers['Undertow'] = {
  { 'R', atX(50) }, { 19, 'RJ' }, { '-', onTop(224) }, { 1, 'X' }, { '-', echoArrived },
  { 'L', atLastEcho }, { 'J', onLastEcho }, { 4, '-' }, { 20, 'RJ' }, { 'R', onTop(224) },
  { 'L', atLastEcho }, { 'J', onLastEcho }, { 4, '-' }, { 'LJ', onTop(144, 0, 54) }, { 'L', atXLeft(40) },
}

-- Underfoot: the ghost on the plate holds every door on it. The one above the bridge is open
-- for the same seven seconds as the hatch. What is up there before the long run?
embers['Underfoot'] = (function(p)
  return {
    { 'L', atXLeft(p.hopX) }, { p.hopHold, 'LJ' }, { 'L', onTop(112) }, { 'L', atXLeft(16) },
    { p.stand, '-' }, { 1, 'X' }, { p.leaveDelay, '-' },
    { 'R', atX(250) }, { 10, 'RJ' }, { 'R', onTop(96, 256, 336) }, { 'R', atX(300) },
    { 'L', onTop(128) },
    { 'R', atX(420) }, { '-', onTop(224) }, { 'R', atX(470) },
  }
end)(S.decisions(strategies['Underfoot']))

return { scripts = scripts, strategies = strategies, rooms = rooms, embers = embers }
