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

return { scripts = scripts }
