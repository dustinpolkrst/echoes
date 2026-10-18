local selftest, flow, bench, shotTarget, shotArg = false, false, nil, nil, nil
local benchOpts = {}
local diffPair, slackArgs, cheeseArgs, recordLevel, favicon
local args = arg or {}
for i, a in pairs(args) do
  if a == '--selftest' then selftest = true end
  if a == '--slack' then
    slackArgs = {}
    for j = i + 1, #args do slackArgs[#slackArgs + 1] = args[j] end
  end
  if a == '--cheese' then
    cheeseArgs = {}
    for j = i + 1, #args do cheeseArgs[#cheeseArgs + 1] = args[j] end
  end
  if a == '--flow' then flow = true end
  if a == '--bench' then
    local label = args[i + 1]
    bench = label and label:sub(1, 2) ~= '--' and label or false
  end
  if a == '--size' then
    local w, h = (args[i + 1] or ''):match('^(%d+)x(%d+)$')
    benchOpts.size = { tonumber(w), tonumber(h) }
  end
  if a == '--profile' then benchOpts.profile = true end
  if a == '--diff' then diffPair = { args[i + 1], args[i + 2] } end
  if a == '--favicon' then favicon = true end
  if a == '--record' then recordLevel = tonumber(args[i + 1]) or 1 end
  if a == '--shot' then
    shotTarget = args[i + 1] or '1'
    shotArg = tonumber(args[i + 2])
  end
end

if diffPair then
  function love.load()
    local same = require('dev.imgdiff').run(diffPair[1], diffPair[2])
    io.stdout:flush()
    love.event.quit(same and 0 or 1)
  end
  return
end

if selftest or slackArgs or cheeseArgs then
  function love.load()
    local ok, passed = xpcall(function()
      if slackArgs then return require('dev.slack').run(slackArgs) end
      if cheeseArgs then return require('dev.cheese').run(cheeseArgs) end
      return require('dev.selftest').run()
    end, function(e)
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
  local Render = require 'gfx.render'
  local Sfx = require 'platform.sfx'
  Render.init()
  Sfx.init()
  Scenes = require 'screens.scenes'
  Input = require 'platform.input'
  navState = Input.newNavState()
  love.keyboard.setKeyRepeat(true)

  if flow then
    local ok = require('dev.flowtest').run(Scenes)
    io.stdout:flush()
    love.event.quit(ok and 0 or 1)
  elseif bench ~= nil then
    local ok = require('dev.bench').run(Scenes, bench or nil, benchOpts)
    io.stdout:flush()
    love.event.quit(ok and 0 or 1)
  elseif favicon then
    love.event.quit(require('dev.favicon').run() and 0 or 1)
  elseif recordLevel then
    require('dev.record').start(Scenes, recordLevel)
  elseif shot.target then
    shot.file = require('dev.shot').setup(Scenes, shot.target, shotArg)
    love.audio.setVolume(0)
  else
    Scenes.init(require('platform.save').open(require('platform.save').fileIO()))
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
    require('platform.assets').reload()
  else
    Scenes.dispatch(Input.fromKey(key, isRepeat))
  end
end

function love.gamepadpressed(_, button)
  Scenes.dispatch(Input.fromButton(button))
end
