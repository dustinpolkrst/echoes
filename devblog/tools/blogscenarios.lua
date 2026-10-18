-- Extra --shot targets for the dev blog. shots.sh copies this file into an exported
-- commit (never into the repo) and wraps that commit's shot.lua so these names resolve.
local Save = require 'save'
local Input = require 'input'

local function freezeClocks()
  love.math.setRandomSeed(1)
  math.randomseed(1)
  require('ui').time = function() return 0 end
end

local function steps(Scenes, n)
  for _ = 1, n do Scenes.update() end
end

local function walk(f)
  return { right = f >= 10, left = false, jump = f >= 30 and f < 46, cast = f >= 62 and f < 64 }
end

local function playTo(Scenes, level, n)
  Scenes.go('playing', level)
  for f = 1, n do
    Scenes.inputSource = function() return walk(f) end
    Scenes.update()
  end
  Scenes.inputSource = function() return {} end
end

local function key(Scenes, name)
  Scenes.dispatch(Input.fromKey(name))
end

local S = {}

-- Pause, open Settings, back out twice, and draw the resumed level.
function S.pausesettings(Scenes, level)
  freezeClocks()
  Scenes.init(Save.open(Save.memoryIO()))
  playTo(Scenes, level or 3, 90)
  key(Scenes, 'p')
  for _ = 1, 3 do key(Scenes, 'down') end
  key(Scenes, 'return')
  steps(Scenes, 60)
  key(Scenes, 'escape')
  steps(Scenes, 60)
  key(Scenes, 'escape')
  steps(Scenes, 2)
  return ('shot_pausesettings_%d.png'):format(level or 3)
end

-- One press of Up on the title menu.
function S.titleup(Scenes)
  freezeClocks()
  Scenes.init(Save.open(Save.memoryIO()))
  Scenes.go('title')
  steps(Scenes, 100)
  key(Scenes, 'up')
  return 'shot_titleup.png'
end

-- Move to Quit on the title menu and confirm once.
function S.quitonce(Scenes)
  freezeClocks()
  Scenes.init(Save.open(Save.memoryIO()))
  Scenes.go('title')
  steps(Scenes, 100)
  for _ = 1, 3 do key(Scenes, 'down') end
  key(Scenes, 'return')
  return 'shot_quitonce.png'
end

-- A level as it looks when the last device used was a gamepad.
function S.padhints(Scenes, level)
  freezeClocks()
  Scenes.init(Save.open(Save.memoryIO()))
  playTo(Scenes, level or 1, 90)
  Input.lastDevice = 'pad'
  steps(Scenes, 1)
  return ('shot_padhints_%d.png'):format(level or 1)
end

return S
