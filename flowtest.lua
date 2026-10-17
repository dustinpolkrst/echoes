local Save = require 'save'
local Input = require 'input'
local Progress = require 'progress'
local Solutions = require 'solutions'

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

  key('p')
  key('down')
  key('down')
  key('return')
  settle()
  key('escape')
  settle()
  check('Esc in select returns to pause', Scenes.name == 'pause')
  check('Quit is the last pause entry', Scenes.pause.menu.items[#Scenes.pause.menu.items].label == 'Quit game')

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


  print(('%d flow checks, %d failed'):format(total, failed))
  return failed == 0
end

return F
