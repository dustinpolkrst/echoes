local Shot = require 'dev.shot'

local Record = {}

local DT = 1 / 60
local TAIL = 75
local MAX_STEPS = 4000

-- Plays a level's scripted solution one sim step per frame and saves every
-- `every`-th frame to <save dir>/record/ as numbered PNGs for an encoder.
function Record.start(Scenes, level, every)
  every = every or 2
  love.math.setRandomSeed(1)
  math.randomseed(1)
  local clock = 0
  require('gfx.ui').time = function() return clock end

  local fs = love.filesystem
  fs.createDirectory('record')
  for _, name in ipairs(fs.getDirectoryItems('record')) do fs.remove('record/' .. name) end

  Scenes.init(Shot.seededStore(0))
  Scenes.go('playing', level)
  Scenes.inputSource = require('dev.solutions').provider(level)
  love.audio.setVolume(0)

  local step, saved, stopAt = 0, 0, nil
  function love.update()
    Scenes.update()
    clock = clock + DT
    step = step + 1
    if not stopAt and Scenes.name == 'levelclear' then stopAt = step + TAIL end
  end

  function love.draw()
    Scenes.draw()
    if step % every == 0 then
      saved = saved + 1
      local name = ('record/f%05d.png'):format(saved)
      love.graphics.captureScreenshot(function(image) image:encode('png', name) end)
    end
    if (stopAt and step >= stopAt) or step >= MAX_STEPS then
      print(('RECORD %d frames at %d fps in %s/record'):format(saved, 60 / every, fs.getSaveDirectory()))
      io.stdout:flush()
      love.event.quit(stopAt and 0 or 1)
    end
  end
end

return Record
