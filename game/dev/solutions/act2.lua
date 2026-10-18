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
  ['Underfoot'] = {
    { 'R', atX(48) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(296) }, { '-', onTop(224) },
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
}

return { scripts = scripts, strategies = strategies, rooms = rooms }
