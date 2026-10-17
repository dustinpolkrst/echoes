local selftest, shotLevel, shotSolveFrames = false, nil, nil
local args = arg or {}
for i, a in pairs(args) do
  if a == '--selftest' then selftest = true end
  if a == '--shot' then
    shotLevel = tonumber(args[i + 1]) or 1
    shotSolveFrames = tonumber(args[i + 2])
  end
end

if selftest then
  function love.load()
    local ok, passed = xpcall(function() return require('selftest').run() end, function(e)
      return debug.traceback(e, 2)
    end)
    if not ok then
      print('FAIL  selftest crashed: ' .. tostring(passed))
      passed = false
    end
    io.stdout:flush()
    love.event.quit(passed and 0 or 1)
  end
  return
end

local DT = 1 / 60
local MAX_FRAME = 0.25
local SHOT_FRAMES = shotSolveFrames or 90

local Scenes
local accumulator = 0
local shot = { level = shotLevel, captured = false }

-- Walk right, hop once, leave an echo; enough to show every visual layer.
local function shotInput(f)
  return { right = f >= 10, left = false, jump = f >= 30 and f < 46, cast = f >= 62 and f < 64 }
end

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  local Render = require 'render'
  local Sfx = require 'sfx'
  Render.init()
  Sfx.init()
  Scenes = require 'scenes'

  if shot.level then
    if shot.level == 0 then
      Scenes.go('title')
    else
      Scenes.go('playing', shot.level)
    end
    local frame = 0
    if shotSolveFrames and shot.level > 0 then
      Scenes.inputSource = require('solutions').provider(shot.level)
    else
      Scenes.inputSource = function() return shotInput(frame) end
    end
    for f = 1, SHOT_FRAMES do
      frame = f
      Scenes.update()
    end
    love.audio.setVolume(0)
  else
    Scenes.go('title')
  end
end

function love.update(dt)
  if shot.level then return end
  accumulator = math.min(accumulator + dt, MAX_FRAME)
  while accumulator >= DT do
    Scenes.update()
    accumulator = accumulator - DT
  end
end

function love.draw()
  Scenes.draw()
  if shot.level and not shot.captured then
    shot.captured = true
    local name = shotSolveFrames and ('shot_%d_f%d.png'):format(shot.level, shotSolveFrames) or ('shot_%d.png'):format(shot.level)
    love.graphics.captureScreenshot(function(image)
      image:encode('png', name)
      print('SHOT ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
      io.stdout:flush()
      love.event.quit(0)
    end)
  end
end

local function dispatch(actions)
  if not Scenes then return end
  for _, action in ipairs(actions) do Scenes.action(action) end
end

function love.keypressed(key)
  if key == 'f5' then
    require('assets').reload()
  elseif key == 'escape' then
    love.event.quit()
  else
    dispatch(require('input').fromKey(key))
  end
end

function love.gamepadpressed(_, button)
  dispatch(require('input').fromButton(button))
end
