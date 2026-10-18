local Save = require 'platform.save'
local Input = require 'platform.input'
local Progress = require 'screens.progress'
local Solutions = require 'dev.solutions'
local Level = require 'world.level'

local F = {}

local total, failed = 0, 0

local function check(name, ok, detail)
  total = total + 1
  if not ok then failed = failed + 1 end
  print(('%s  %s%s'):format(ok and 'PASS' or 'FAIL', name, detail and ('  [' .. detail .. ']') or ''))
end

function F.run(Scenes)
  local files = {}
  local store = Save.open(Save.memoryIO(files))
  Scenes.init(store)
  Scenes.go('title')

  local function step(n)
    for _ = 1, n do Scenes.update() end
  end
  local function key(name) return Scenes.dispatch(Input.fromKey(name)) end
  local function settle() step(60) end

  Scenes.inputSource = function() return {} end
  check('title opens with Play for a fresh save', Scenes.title.menu.items[1].label == 'Play')

  key('return')
  settle()
  check('Play starts level 1', Scenes.name == 'playing' and Scenes.playing.index == 1)

  local world = Scenes.playing.world
  step(30)
  key('escape')
  check('Esc in play opens pause', Scenes.name == 'pause')
  local x, t = world.player.x, world.time
  step(60)
  check('simulation is frozen while paused', world.time == t and world.player.x == x)
  key('escape')
  check('Esc in pause resumes once, not back into pause', Scenes.name == 'playing')

  key('p')
  Scenes.dispatch(Input.fromButton('start'))
  check('Start resumes from pause', Scenes.name == 'playing')

  key('p')
  key('down')
  key('return')
  settle()
  check('pause Restart level returns to play with a fresh world', Scenes.name == 'playing' and Scenes.playing.world ~= world)

  local Render = require 'gfx.render'
  local function playingFrame()
    Scenes.draw()
    return { pixels = Render.game:newImageData():getString(), t = Render.t }
  end
  local function differingBytes(a)
    Render.t = a.t
    local b = playingFrame().pixels
    local n = 0
    for i = 1, #a.pixels do
      if a.pixels:byte(i) ~= b:byte(i) then n = n + 1 end
    end
    return n
  end

  local beforeSettings = playingFrame()
  key('p')
  for _ = 1, 3 do key('down') end
  key('return')
  settle()
  check('pause Settings opens settings', Scenes.name == 'settings')
  local before = store.data.settings.master
  key('left')
  check('left lowers master volume and saves it', store.data.settings.master < before and files['save.txt']:find('setting master', 1, true) ~= nil)
  key('down')
  key('down')
  key('return')
  check('shake toggles off', store.data.settings.shake == false)
  key('escape')
  settle()
  check('Esc in settings returns to pause', Scenes.name == 'pause')
  key('escape')
  check('Esc resumes the level', Scenes.name == 'playing')
  local changed = differingBytes(beforeSettings)
  check('the level draws the same after pause, Settings, back, resume', changed == 0, changed .. ' bytes differ')

  Scenes.inputSource = Solutions.provider(1)
  for _ = 1, 3000 do
    Scenes.update()
    if Scenes.name == 'levelclear' then break end
  end
  check('scripted solution reaches the clear card', Scenes.name == 'levelclear')
  check('clearing level 1 is saved and unlocks level 2', Progress.done(store.data, 1) and Progress.unlocked(store.data, 2)
    and Save.open(Save.memoryIO(files)).data.levels[1].done)
  key('return')
  check('confirm is ignored while the card animates in', Scenes.name == 'levelclear')
  step(40)
  key('return')
  settle()
  check('Next level goes to level 2', Scenes.name == 'playing' and Scenes.playing.index == 2)

  Scenes.inputSource = function() return {} end
  key('p')
  key('down')
  key('down')
  key('return')
  settle()
  check('pause Level select opens the grid on the current level', Scenes.name == 'select')
  for _ = 1, 3 do key('right') end
  key('return')
  check('a locked level refuses to start', Scenes.name == 'select')
  for _ = 1, 3 do key('left') end
  key('return')
  settle()
  check('an unlocked level starts from the grid', Scenes.name == 'playing' and Scenes.playing.index == 2)

  step(30)
  local beforeSelect = playingFrame()
  key('p')
  key('down')
  key('down')
  key('return')
  settle()
  key('escape')
  settle()
  check('Esc in select returns to pause', Scenes.name == 'pause')
  check('Quit is the last pause entry', Scenes.pause.menu.items[#Scenes.pause.menu.items].label == 'Quit game')
  key('escape')
  changed = differingBytes(beforeSelect)
  check('the level draws the same after pause, Level select, back, resume', changed == 0, changed .. ' bytes differ')

  local realQuit, quits = love.event.quit, 0
  love.event.quit = function() quits = quits + 1 end
  Scenes.go('title')
  key('up')
  key('z')
  settle()
  check('Up then Z on the title plays instead of quitting', quits == 0 and Scenes.name == 'playing')
  key('escape')
  key('up')
  key('space')
  check('Esc, Up, Space in play resumes instead of quitting', quits == 0 and Scenes.name == 'playing')
  key('escape')
  for _ = 1, 4 do key('down') end
  key('z')
  check('the first confirm on Quit game only asks', quits == 0 and Scenes.pause.menu.index == 5)
  key('z')
  check('the second confirm on Quit game quits', quits == 1)
  love.event.quit = realQuit

  local function runUntil(done, frame)
    for _ = 1, 3000 do
      if done() then return end
      if frame then frame() else Scenes.update() end
    end
  end
  local function onCard() return Scenes.name == 'levelclear' end

  Scenes.go('playing', 2)
  Scenes.inputSource = Solutions.provider(2)
  runUntil(function() return Scenes.playing.world.player.state == 'cleared' end)
  key('r')
  for _ = 1, 200 do
    if onCard() then break end
    Scenes.update()
  end
  check('R after touching the goal still shows the clear card', onCard() and Scenes.levelclear.index == 2, Scenes.name)
  check('R after touching the goal still records the clear', Progress.done(store.data, 2))

  local nav = Input.newNavState()
  local stickDown = {
    isGamepadDown = function() return false end,
    getGamepadAxis = function(_, axis) return axis == 'lefty' and 0.9 or 0 end,
  }
  local function padFrame(pads)
    return function()
      Scenes.dispatch(Input.navPoll(nav, pads, 1 / 60))
      Scenes.update()
    end
  end
  Scenes.go('playing', 1)
  Scenes.inputSource = Solutions.provider(1)
  runUntil(onCard, padFrame({ stickDown }))
  for _ = 1, 90 do padFrame({ stickDown })() end
  check('a stick held through the clear card leaves the cursor on Next level', onCard() and Scenes.levelclear.menu.index == 1,
    'cursor ' .. Scenes.levelclear.menu.index)
  padFrame({})()
  Scenes.dispatch(Input.fromButton('a'))
  settle()
  check('a fresh A after releasing the stick takes Next level', Scenes.name == 'playing' and Scenes.playing.index == 2)

  Scenes.go('playing', 1)
  Scenes.inputSource = Solutions.provider(1)
  key('down')
  runUntil(onCard)
  step(40)
  for _ = 1, 2 do Scenes.dispatch(Input.fromKey('down', true)) end
  Scenes.dispatch(Input.fromKey('z', true))
  check('key repeats held over from play do nothing on the clear card', onCard() and Scenes.levelclear.menu.index == 1,
    'cursor ' .. Scenes.levelclear.menu.index)
  key('down')
  check('a fresh key press moves the clear card cursor', Scenes.levelclear.menu.index == 2)

  local Levels = require 'content.levels'
  Levels[#Levels + 1] = {
    name = 'Waystone test', hint = '',
    map = {
      '##############',
      '#............#',
      '#............#',
      '#............#',
      '#P...w...^^.G#',
      '##############',
    },
  }
  Scenes.go('playing', #Levels)
  Scenes.inputSource = function() return { right = true } end
  runUntil(function() return Scenes.playing.world.player.state == 'dead' end)
  Scenes.inputSource = function() return {} end
  local dying = Scenes.playing.world
  check('the waystone lit on the way to the spikes', dying.respawn == 1)
  local before = Scenes.playing.attemptT
  settle()
  settle()
  local w = Scenes.playing.world
  check('death respawns on the waystone with the clock still running', w ~= dying and w.respawn == 1
    and math.abs(w.player.x - (5 * 16 + 3)) < 1 and Scenes.playing.attemptT > before, ('x=%.1f t=%.2f'):format(w.player.x, Scenes.playing.attemptT))
  step(10)
  key('r')
  settle()
  check('R retries from the waystone', Scenes.playing.world ~= w and Scenes.playing.world.respawn == 1 and Scenes.playing.attemptT > before)
  local kept = Scenes.playing.attemptT
  key('p')
  key('down')
  key('return')
  settle()
  check('pause Restart level starts over from the beginning with a fresh clock',
    Scenes.name == 'playing' and Scenes.playing.world.respawn == nil and Scenes.playing.attemptT < kept
    and math.abs(Scenes.playing.world.player.x - (1 * 16 + 3)) < 1, ('x=%.1f t=%.2f'):format(Scenes.playing.world.player.x, Scenes.playing.attemptT))
  Levels[#Levels] = nil

  local function drawnWorld(doorRow)
    local row = '#' .. doorRow .. '#'
    local w = Level.new({ name = 'door test', map = { '################', row, row, row, '#P.............#', '################' } })
    local canvas = love.graphics.newCanvas(w.W * 16, w.H * 16)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()
    Render.t = 0
    Render.drawWorld(w)
    love.graphics.pop()
    return canvas:newImageData()
  end
  local split, left, right, none =
    drawnWorld('..A......A....'), drawnWorld('..A...........'), drawnWorld('.........A....'), drawnWorld('..............')
  local function inColumn(x, y, tx) return x >= tx * 16 and x < (tx + 1) * 16 and y >= 16 and y < 64 end
  local wrong = 0
  for y = 0, split:getHeight() - 1 do
    for x = 0, split:getWidth() - 1 do
      local want = inColumn(x, y, 3) and left or inColumn(x, y, 10) and right or none
      local r1, g1, b1 = split:getPixel(x, y)
      local r2, g2, b2 = want:getPixel(x, y)
      if r1 ~= r2 or g1 ~= g2 or b1 ~= b2 then wrong = wrong + 1 end
    end
  end
  check('a letter used in two places draws two doors and nothing between them', wrong == 0, wrong .. ' pixels differ')

  print(('%d flow checks, %d failed'):format(total, failed))
  return failed == 0
end

return F
