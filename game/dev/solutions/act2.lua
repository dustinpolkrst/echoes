local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, echoArrived, onLastEcho, doorOpen =
  C.atX, C.atXLeft, C.onTop, C.echoArrived, C.onLastEcho, C.doorOpen

local scripts = {
  ['Other Side'] = {
    { 'R', atX(66) }, { 100, '-' }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
  },
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

return { scripts = scripts }
