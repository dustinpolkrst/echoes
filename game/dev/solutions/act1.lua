local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, apex, echoArrived, onLastEcho, grounded =
  C.atX, C.atXLeft, C.onTop, C.apex, C.echoArrived, C.onLastEcho, C.grounded

-- Coordinates are pixels (tile = 16). Each list is a full playthrough of the level of that name.
local scripts = {
  ['Wake'] = {
    { 'R', atX(202) }, { 'RJ', atX(246) }, { 'R', grounded },
    { 'R', atX(284) }, { 'RJ', atX(312) }, { 'R', atX(332) }, { 'R', grounded },
    { 'R', atX(348) }, { 'RJ', atX(374) }, { 'R', atX(404) }, { 'R', grounded },
    { 'R', atX(468) }, { 'RJ', atX(516) }, { 'R', grounded },
    { 'R', atX(570) }, { 'RJ', atX(630) }, { 'R', grounded },
    { 'R', atX(668) }, { 'RJ', atX(690) }, { 'R', grounded },
    { 'R', atX(694) }, { 'RJ', atX(708) }, { 'R', grounded },
    { 'R', atX(762) }, { 'R', grounded }, { 'R', atX(778) }, { 'R', grounded },
    { 'R', atX(822) }, { 'RJ', atX(870) }, { 'R', grounded },
    { 'R', atX(940) },
  },
  ['First Echo'] = {
    { 'R', atX(163) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(372) }, { 'RJ', atX(440) }, { 'R', grounded },
    { 'R', atX(488) }, { 'RJ', atX(540) }, { 'R', grounded },
    { 'R', atX(640) },
  },
  ['Stairway'] = {
    { 'R', atX(66) }, { 'RJ', onTop(192, 80) }, { 'R', atX(133) }, { 'R', grounded },
    { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', grounded },
    { 'L', atXLeft(116) }, { 'LJ', onTop(192, 80, 112) },
    { 'R', atX(104) },
    { '-', echoArrived },
    { 'RJ', onLastEcho },
    { 2, '-' }, { 'RJ', onTop(128, 144) },
    { 'R', atX(358) }, { 'RJ', atX(410) }, { 'R', grounded },
    { 'R', atX(600) },
  },
  ['Two Minds'] = {
    { 'R', atX(66) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(130) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(316) }, { 'RJ', atX(372) }, { 'R', grounded },
    { 'R', atX(424) }, { 'RJ', atX(486) }, { 'R', grounded },
    { 'R', atX(700) },
  },
  ['Ascent'] = {
    { 'R', atX(99) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(200) }, { 'RJ', onTop(528, 209) },
    { 'R', atX(246) }, { 'RJ', onTop(496, 288) },
    { 'R', atX(326) }, { 'RJ', onTop(464, 368) },
    { 'L', atXLeft(366) }, { 'LJ', onTop(432, 270, 340) },
    { 'L', atXLeft(266) }, { 'LJ', onTop(400, 190, 250) },
    { 'R', atX(246) }, { 'RJ', onTop(368, 256) },
    { 'R', atX(312) }, { 'RJ', onTop(336, 336) },
    { 'R', atX(392) }, { 'RJ', onTop(304, 400) },
    { 1, '-' }, { 'J', onTop(272, 384, 464) },
    { 'L', atXLeft(386) }, { 'LJ', onTop(240, 256, 384) },
    { 'L', atXLeft(326) }, { 'LJ', onTop(208, 288, 320) },
    { 'L', onTop(240, 256, 288) },
    { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', onTop(240, 256, 288) },
    { 'R', atX(276) }, { 'RJ', onTop(208, 288, 320) },
    { '-', echoArrived },
    { 'LJ', onLastEcho }, { 2, '-' }, { 'LJ', onTop(144, 0, 250) },
    { 'L', atXLeft(176) }, { 'LJ', atXLeft(116) }, { 'L', grounded },
    { 'L', atXLeft(40) },
  },
}

local append = S.append

-- Holding a direction until the player is over the last echo, so letting go drops them onto it.
local function overEchoFromRight(w)
  local e = w.echoes[#w.echoes]
  return e ~= nil and w.player.x <= e.x + 3
end
local function overEchoFromLeft(w)
  local e = w.echoes[#w.echoes]
  return e ~= nil and w.player.x >= e.x - 2
end

-- The script with `detour` played after its first `at` segments.
local function splice(script, at, detour)
  local out = {}
  for i = 1, at do out[#out + 1] = script[i] end
  append(out, detour)
  for i = at + 1, #script do out[#out + 1] = script[i] end
  return out
end

-- Each ember script starts from the level start, takes the ember and clears the level.
local embers = {}

-- Wake: the hint says hold jump to go higher; what hangs just above a tapped jump, right where you start?
embers['Wake'] = append({ { 20, 'J' }, { '-', grounded } }, scripts['Wake'])

-- First Echo: the echo on the plate is solid; can you stand on it and reach higher than any jump?
embers['First Echo'] = {
  { 'R', atX(163) }, { 190, '-' }, { 1, 'X' },
  { 'J', apex }, { '-', onLastEcho }, { 2, '-' }, { 'J', apex }, { '-', onLastEcho },
  { 'R', atX(372) }, { 'RJ', atX(440) }, { 'R', grounded },
  { 'R', atX(488) }, { 'RJ', atX(540) }, { 'R', grounded }, { 'R', atX(640) },
}

-- Stairway: a stair stands wherever you jump; what does one on the far side of the block reach?
embers['Stairway'] = append({
  { 'R', atX(40) }, { 10, '-' }, { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', grounded },
  { 'L', atXLeft(30) }, { '-', echoArrived },
  { 'R', atX(66) }, { 'RJ', onTop(192, 80) }, { 'L', atXLeft(90) }, { 10, '-' },
  { 10, 'LJ' }, { 'L', overEchoFromRight }, { '-', grounded }, { 2, '-' }, { 6, 'LJ' }, { 'LJ', grounded },
  { 'L', atXLeft(36) }, { 20, '-' },
}, scripts['Stairway'])

-- Two Minds: two echoes hold two doors; can they also stand one on the other?
embers['Two Minds'] = append({
  { 'R', atX(99) }, { 190, '-' }, { 1, 'X' }, { 'J', apex }, { '-', onLastEcho },
  { 190, '-' }, { 1, 'X' }, { 'J', apex }, { '-', onLastEcho }, { 2, '-' }, { 'J', apex }, { '-', grounded },
  { 'L', atXLeft(66) },
}, scripts['Two Minds'])

-- Ascent: the peak cast that reaches the top works anywhere; what does one cast over the top rung reach?
embers['Ascent'] = splice(scripts['Ascent'], 21, {
  { 'L', atXLeft(414) }, { 10, '-' }, { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', onTop(272) },
  { 'L', atXLeft(386) }, { 'LJ', onTop(240, 256, 384) },
  { 'R', atX(372) }, { '-', echoArrived }, { 8, 'RJ' }, { 'R', overEchoFromLeft }, { '-', onLastEcho }, { 4, '-' },
  { 12, 'RJ' }, { 'R', onTop(272) },
})

return { scripts = scripts, embers = embers }
