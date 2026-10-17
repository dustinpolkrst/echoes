local selftest, flow, shotTarget, shotArg = false, false, nil, nil
local args = arg or {}
for i, a in pairs(args) do
  if a == '--selftest' then selftest = true end
  if a == '--flow' then flow = true end
  if a == '--shot' then
    shotTarget = args[i + 1] or '1'
    shotArg = tonumber(args[i + 2])
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

local Scenes, Input
local accumulator = 0
local navState
local shot = { target = shotTarget, captured = false }

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  local Render = require 'render'
  local Sfx = require 'sfx'
  Render.init()
  Sfx.init()
  Scenes = require 'scenes'
  Input = require 'input'
  navState = Input.newNavState()
  love.keyboard.setKeyRepeat(true)

  if flow then
    local ok = require('flowtest').run(Scenes)
    io.stdout:flush()
    love.event.quit(ok and 0 or 1)
  elseif shot.target then
    shot.file = require('shot').setup(Scenes, shot.target, shotArg)
    love.audio.setVolume(0)
  else
    Scenes.init(require('save').open(require('save').fileIO()))
    Scenes.go('title')
  end
end

function love.update(dt)
  if shot.target then return end
  accumulator = math.min(accumulator + dt, MAX_FRAME)
  while accumulator >= DT do
    Scenes.dispatch(Input.navPoll(navState, nil, DT))
    Scenes.update()
    accumulator = accumulator - DT
  end
end

function love.draw()
  Scenes.draw()
  if shot.target and not shot.captured then
    shot.captured = true
    local name = shot.file
    love.graphics.captureScreenshot(function(image)
      image:encode('png', name)
      print('SHOT ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
      io.stdout:flush()
      love.event.quit(0)
    end)
  end
end

function love.keypressed(key, _, isRepeat)
  if key == 'f5' then
    require('assets').reload()
  else
    Scenes.dispatch(Input.fromKey(key, isRepeat))
  end
end

function love.gamepadpressed(_, button)
  Scenes.dispatch(Input.fromButton(button))
end
