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

  Levels[#Levels] = { name = 'ember test', map = {
    '################',
    '#..............#',
    '#P.*..w....*^^G#',
    '################',
  } }
  Scenes.go('playing', #Levels)
  Scenes.inputSource = function() return { right = true } end
  runUntil(function() return Scenes.playing.world.player.state == 'dead' end)
  Scenes.inputSource = function() return {} end
  settle()
  settle()
  check('an ember carried past a lit waystone survives the death', Scenes.playing.world:emberTaken())
  Levels[#Levels] = { name = 'ember test', map = {
    '################',
    '#..............#',
    '#P....w....*^^G#',
    '################',
  } }
  Scenes.go('playing', #Levels)
  Scenes.inputSource = function() return { right = true } end
  runUntil(function() return Scenes.playing.world.player.state == 'dead' end)
  Scenes.inputSource = function() return {} end
  settle()
  settle()
  check('an ember grabbed on the way to dying is lost', Scenes.playing.world.respawn == 1 and not Scenes.playing.world:emberTaken())

  Scenes.go('playing', #Levels)
  settle()
  local rw = Scenes.playing.world
  local spawnX = rw.player.x
  Scenes.inputSource = function() return { right = true } end
  step(40)
  local ahead = rw.player.x
  Scenes.inputSource = function() return { rewind = true } end
  step(20)
  Scenes.inputSource = function() return { rewind = true, right = true } end
  check('holding rewind walks the player back', rw.player.x < ahead - 5 and Scenes.playing.world == rw, ('x=%.1f from %.1f'):format(rw.player.x, ahead))
  step(200)
  local x1 = rw.player.x
  step(1)
  check('rewind holds still once its history runs out', rw.player.x == spawnX and x1 == spawnX, ('x=%.1f'):format(rw.player.x))
  Scenes.inputSource = function() return { right = true } end
  runUntil(function() return rw.player.state == 'dead' end)
  Scenes.inputSource = function() return { rewind = true } end
  step(120)
  check('holding rewind through a death keeps the attempt and revives the player',
    Scenes.playing.world == rw and (rw.player.state == 'ground' or rw.player.state == 'air'), 'state=' .. rw.player.state)
  Scenes.inputSource = function() return {} end
  Levels[#Levels] = nil

  -- A new attempt starts at 0 deaths. Rewind puts a death, and an ember banked on the way, back.
  -- Restart level and a death with no waystone do too. A waystone death keeps the count and the clock.
  local Trans = require 'screens.transition'
  local levelCount = #Levels
  local function addLevel(name, rows)
    Levels[#Levels + 1] = { name = name, hint = '', map = rows }
    return #Levels
  end
  local function waitIdle()
    -- coverage is 0 on the first frame of the close, while the iris is already busy.
    if Trans.busy() or Trans.coverage() > 0 then
      runUntil(function() return not Trans.busy() and Trans.coverage() == 0 end)
    end
  end
  local function startPlaying(index)
    -- The clear card appears while its iris is still opening. Wait or the next level never starts.
    waitIdle()
    local slot = index - 1
    local prev = store.data.levels[slot]
    if not Progress.unlocked(store.data, index) then store.data.levels[slot] = { done = true } end
    Scenes.inputSource = function() return {} end
    Scenes.go('select', index)
    key('return')
    settle()
    store.data.levels[slot] = prev
    return Scenes.name == 'playing' and Scenes.playing.index == index
  end
  local function hold(dir, pred)
    Scenes.inputSource = function() return { [dir] = true } end
    runUntil(pred)
  end
  local function respawnFrom(dying)
    Scenes.inputSource = function() return {} end
    runUntil(function()
      local w = Scenes.playing.world
      return w ~= dying and w.player.state ~= 'dead'
    end)
    waitIdle()
  end
  local function clearWalking(dir)
    hold(dir, function() return Scenes.playing.world.player.state == 'cleared' end)
    Scenes.inputSource = function() return {} end
    runUntil(onCard)
  end
  local function savedLine(index)
    local text = files['save.txt'] or ''
    local rec = Save.decode(text).levels[index]
    return rec and rec.bestDeaths, text:match('level ' .. index .. ' [^\n]*') or 'missing'
  end

  local flat = {
    '####################',
    '#..................#',
    '#G.P...........^^..#',
    '####################',
  }
  local waystone = {
    '######################',
    '#....................#',
    '#G.P..w.........^^...#',
    '######################',
  }

  local kept = addLevel('Waystone count', waystone)
  check('waystone count level starts', startPlaying(kept))
  local keptWorld = Scenes.playing.world
  local beforeClock = Scenes.playing.attemptT
  hold('right', function() return keptWorld.player.state == 'dead' end)
  respawnFrom(keptWorld)
  local keptNow = Scenes.playing.world
  check('waystone death keeps the clock', keptNow ~= keptWorld and keptNow.respawn == 1 and Scenes.playing.attemptT > beforeClock,
    ('t=%.3f respawn=%s'):format(Scenes.playing.attemptT, tostring(keptNow.respawn)))
  clearWalking('left')
  local keptDeaths, keptLine = savedLine(kept)
  check('waystone death keeps the death count',
    Scenes.name == 'levelclear' and Scenes.levelclear.index == kept and Scenes.levelclear.deaths == 1 and keptDeaths == 1,
    ('card=%s saved=%s %s'):format(tostring(Scenes.levelclear.deaths), tostring(keptDeaths), keptLine))

  local rewound = addLevel('Rewound death', flat)
  check('rewound death level starts', startPlaying(rewound))
  local rewoundWorld = Scenes.playing.world
  hold('right', function() return rewoundWorld.player.state == 'dead' end)
  local deathX = rewoundWorld.player.x
  Scenes.inputSource = function() return { rewind = true } end
  -- Far enough back that leftover speed does not slide into the spikes again.
  runUntil(function()
    local p = rewoundWorld.player
    return Scenes.playing.world == rewoundWorld and (p.state == 'ground' or p.state == 'air') and p.x <= deathX - 32
  end)
  local revived = rewoundWorld.player
  check('rewinding through a death revives the player on the same attempt',
    Scenes.playing.world == rewoundWorld and (revived.state == 'ground' or revived.state == 'air') and revived.x <= deathX - 32,
    ('state=%s x=%.1f deathX=%.1f'):format(revived.state, revived.x, deathX))
  clearWalking('left')
  local rewoundDeaths, rewoundLine = savedLine(rewound)
  check('the clear card and save record the rewound death count',
    Scenes.playing.world == rewoundWorld and Scenes.name == 'levelclear' and Scenes.levelclear.index == rewound
    and Scenes.levelclear.deaths == 0 and rewoundDeaths == 0,
    ('card=%s saved=%s %s'):format(tostring(Scenes.levelclear.deaths), tostring(rewoundDeaths), rewoundLine))

  local fresh = addLevel('No waystone', flat)
  check('no waystone level starts', startPlaying(fresh))
  local freshWorld = Scenes.playing.world
  local freshX = freshWorld.player.x
  hold('right', function() return freshWorld.player.state == 'dead' end)
  respawnFrom(freshWorld)
  check('a death with no waystone restarts the clock at the start',
    Scenes.playing.world ~= freshWorld and Scenes.playing.world.respawn == nil
    and Scenes.playing.attemptT < 1 and math.abs(Scenes.playing.world.player.x - freshX) < 1,
    ('t=%.3f x=%.1f respawn=%s'):format(Scenes.playing.attemptT, Scenes.playing.world.player.x, tostring(Scenes.playing.world.respawn)))
  clearWalking('left')
  local freshDeaths, freshLine = savedLine(fresh)
  check('a death with no waystone starts the attempt at 0 deaths',
    Scenes.name == 'levelclear' and Scenes.levelclear.index == fresh and Scenes.levelclear.deaths == 0 and freshDeaths == 0,
    ('card=%s saved=%s %s'):format(tostring(Scenes.levelclear.deaths), tostring(freshDeaths), freshLine))

  local restarted = addLevel('Restart deaths', waystone)
  check('restart level starts', startPlaying(restarted))
  local restartWorld = Scenes.playing.world
  local restartX = restartWorld.player.x
  hold('right', function() return restartWorld.player.state == 'dead' end)
  respawnFrom(restartWorld)
  local running = Scenes.playing.attemptT
  Scenes.inputSource = function() return {} end
  key('p')
  key('down')
  key('return')
  waitIdle()
  check('pause Restart level restarts the clock at the start',
    Scenes.name == 'playing' and Scenes.playing.world ~= restartWorld and Scenes.playing.world.respawn == nil
    and Scenes.playing.attemptT < running and math.abs(Scenes.playing.world.player.x - restartX) < 1,
    ('t %.3f -> %.3f x=%.1f'):format(running, Scenes.playing.attemptT, Scenes.playing.world.player.x))
  clearWalking('left')
  local restartDeaths, restartLine = savedLine(restarted)
  check('pause Restart level starts the attempt at 0 deaths',
    Scenes.name == 'levelclear' and Scenes.levelclear.index == restarted and Scenes.levelclear.deaths == 0 and restartDeaths == 0,
    ('card=%s saved=%s %s'):format(tostring(Scenes.levelclear.deaths), tostring(restartDeaths), restartLine))

  local emberIndex = addLevel('Ember rewind', {
    '############################',
    '#..........................#',
    '#w..*..w..P............^^..#',
    '############################',
  })
  Scenes.go('playing', emberIndex)
  settle()
  local emberWorld = Scenes.playing.world
  hold('left', function() return emberWorld:emberTaken() and emberWorld.respawn == 1 end)
  check('the ember is banked at the left waystone', emberWorld:emberTaken() and emberWorld.respawn == 1,
    ('taken=%s respawn=%s'):format(tostring(emberWorld:emberTaken()), tostring(emberWorld.respawn)))
  Scenes.inputSource = function() return { rewind = true } end
  runUntil(function() return not emberWorld:emberTaken() and emberWorld.respawn == 2 end)
  local emberRect = emberWorld.embers[1].rect
  local parked = not emberWorld:emberTaken() and emberWorld.respawn == 2 and emberWorld.player.x >= emberRect.x + emberRect.w
  check('rewind puts the ember back and the right waystone in charge', parked,
    ('taken=%s respawn=%s x=%.1f emberRight=%.1f'):format(tostring(emberWorld:emberTaken()), tostring(emberWorld.respawn), emberWorld.player.x, emberRect.x + emberRect.w))
  hold('right', function() return emberWorld.player.state == 'dead' end)
  respawnFrom(emberWorld)
  check('an ember rewound back to untaken stays untaken after death',
    Scenes.playing.world ~= emberWorld and Scenes.playing.world.respawn == 2 and not Scenes.playing.world:emberTaken(),
    ('taken=%s respawn=%s'):format(tostring(Scenes.playing.world:emberTaken()), tostring(Scenes.playing.world.respawn)))

  local lateIndex = addLevel('Late rewind', {
    '############################',
    '#..........................#',
    '#P..w.................^^...#',
    '############################',
  })
  Scenes.go('playing', lateIndex)
  settle()
  hold('right', function() return Scenes.playing.world.player.state == 'dead' end)
  Scenes.inputSource = function() return {} end
  runUntil(function() return Trans.busy() end)
  local lateWorld = Scenes.playing.world
  local xIris = lateWorld.player.x
  local iris = Trans.busy()
  Scenes.inputSource = function() return { rewind = true } end
  local minX = xIris
  for _ = 1, 3000 do
    if Scenes.playing.world ~= lateWorld then break end
    local p = lateWorld.player
    if p.state == 'ground' or p.state == 'air' then break end
    Scenes.update()
    if Scenes.playing.world == lateWorld then minX = math.min(minX, lateWorld.player.x) end
  end
  local now = Scenes.playing.world
  local late = now.player
  check('rewind during the death fade undoes the death',
    iris and now == lateWorld and (late.state == 'ground' or late.state == 'air') and late.x < xIris,
    ('iris=%s same=%s state=%s xIris=%.1f minX=%.1f x=%.1f'):format(
      tostring(iris), tostring(now == lateWorld), late.state, xIris, minX, late.x))

  Scenes.inputSource = function() return {} end
  while #Levels > levelCount do Levels[#Levels] = nil end

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
