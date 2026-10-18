-- Extra --shot targets for the dev blog, for commits that keep the game in game/ (7ae145b on).
-- shots.sh copies this file into an exported commit's dev/ folder (never into the repo) and wraps
-- that commit's dev/shot.lua so these names resolve. Each target takes one number, as --shot does.
local S = {}

local function freezeClocks()
  love.math.setRandomSeed(1)
  math.randomseed(1)
  require('gfx.ui').time = function() return 0 end
end

local function freshScenes(Scenes)
  local Save = require 'platform.save'
  Scenes.init(Save.open(Save.memoryIO()))
end

-- Other Side (level 6): run to the door, cast once at the shrine, keep holding right, and draw frame n.
-- Before d3180c1 this replayed the run across the plate's reflection and opened the door.
function S.othersiderun(Scenes, n)
  freezeClocks()
  freshScenes(Scenes)
  local Script = require 'dev.script'
  local drive = Script.driver({ { 'R', Script.cond.atX(166) }, { 1, 'RX' }, { 1200, 'R' } })
  Scenes.go('playing', 6)
  Scenes.inputSource = function(world) return drive(world) or {} end
  for _ = 1, n or 100 do Scenes.update() end
  return ('shot_othersiderun_%d.png'):format(n or 100)
end

-- Relay (level 13): play the scripted solution for n frames, press R, and draw the room after the respawn.
function S.relayrespawn(Scenes, n)
  freezeClocks()
  freshScenes(Scenes)
  Scenes.go('playing', 13)
  Scenes.inputSource = require('dev.solutions').provider(13)
  for _ = 1, n or 700 do Scenes.update() end
  Scenes.inputSource = function() return {} end
  Scenes.dispatch(require('platform.input').fromKey('r'))
  for _ = 1, 45 do Scenes.update() end
  return ('shot_relayrespawn_%d.png'):format(n or 700)
end

return S
