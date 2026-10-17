local Save = require 'save'

local Shot = {}

local function shotInput(f)
  return { right = f >= 10, left = false, jump = f >= 30 and f < 46, cast = f >= 62 and f < 64 }
end

-- Progress that never touches the real save file: levels 1..cleared done, with plausible records.
local function seededStore(cleared, overrides)
  local store = Save.open(Save.memoryIO())
  for i = 1, cleared do
    store.data.levels[i] = { done = true, bestTime = 14 + i * 3.7, bestDeaths = i % 3 }
  end
  for i, rec in pairs(overrides or {}) do store.data.levels[i] = rec end
  return store
end

local function frames(Scenes, n, input)
  for f = 1, n do
    if input then Scenes.inputSource = function() return input(f) end end
    Scenes.update()
  end
end

local function playTo(Scenes, level, n)
  Scenes.go('playing', level)
  frames(Scenes, n, shotInput)
end

local function playSolution(Scenes, level, n)
  Scenes.go('playing', level)
  Scenes.inputSource = require('solutions').provider(level)
  for _ = 1, n do Scenes.update() end
end

-- target: a level number (0 is the title), or title, pause, select, settings, clear, transition.
-- arg: frames of the scripted solution for a level number; the level or cleared-count for named screens.
function Shot.setup(Scenes, target, arg)
  local Levels = require 'levels'
  local level = tonumber(target)
  if level then
    Scenes.init(seededStore(0))
    if level == 0 then
      Scenes.go('title')
      frames(Scenes, 90)
    elseif arg then
      playSolution(Scenes, level, arg)
    else
      playTo(Scenes, level, 90)
    end
    return level == 0 and 'shot_0.png' or (arg and ('shot_%d_f%d.png'):format(level, arg) or ('shot_%d.png'):format(level))
  end

  if target == 'title' then
    Scenes.init(seededStore(arg or 2))
    Scenes.go('title')
    frames(Scenes, 100)
  elseif target == 'pause' then
    Scenes.init(seededStore(0))
    playTo(Scenes, arg or 2, 90)
    Scenes.go('pause', 'playing')
  elseif target == 'select' then
    local cleared = arg or 3
    Scenes.init(seededStore(cleared))
    Scenes.go('select', math.min(cleared + 1, #Levels))
    frames(Scenes, 60)
  elseif target == 'settings' then
    Scenes.init(seededStore(0))
    Scenes.go('settings')
    frames(Scenes, 40)
  elseif target == 'clear' then
    local level = arg or 1
    Scenes.init(seededStore(0, { [level] = { done = true, bestTime = 999, bestDeaths = 9 } }))
    Scenes.go('playing', level)
    Scenes.inputSource = require('solutions').provider(level)
    for _ = 1, 4000 do
      Scenes.update()
      if Scenes.name == 'levelclear' then break end
    end
    frames(Scenes, 50)
  elseif target == 'transition' then
    Scenes.init(seededStore(0))
    playTo(Scenes, arg or 2, 90)
    require('transition').start(function() end, 480, 270)
    frames(Scenes, 9)
  else
    error('unknown --shot target: ' .. tostring(target))
  end
  return arg and ('shot_%s_%d.png'):format(target, arg) or ('shot_%s.png'):format(target)
end

return Shot
