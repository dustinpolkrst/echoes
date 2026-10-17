local Save = require 'save'
local Progress = require 'progress'
local Menu = require 'menu'
local Input = require 'input'
local Trans = require 'transition'
local Model = require 'hudmodel'
local Level = require 'level'
local Echo = require 'echo'
local Solutions = require 'solutions'

return function(check)
  local d = Save.defaults()
  d.settings.master, d.settings.shake, d.settings.fullscreen = 0.4, false, true
  Save.recordClear(d, 1, 12.5, 2)
  Save.recordClear(d, 3, 40.25, 0)
  local back = Save.decode(Save.encode(d))
  check('save round-trips settings', back.settings.master == 0.4 and back.settings.shake == false and back.settings.fullscreen == true)
  check('save round-trips level records', back.levels[1].done and back.levels[1].bestTime == 12.5 and back.levels[1].bestDeaths == 2
    and back.levels[3].bestTime == 40.25 and back.levels[2] == nil)

  local io = Save.memoryIO({})
  local store = Save.open(io)
  check('missing save file yields defaults', store.data.settings.master == Save.defaults().settings.master and next(store.data.levels) == nil)
  store.data.levels[2] = { done = true, bestTime = 9, bestDeaths = 1 }
  Save.persist(store)
  check('persisted save is read back by a fresh open', Save.open(io).data.levels[2].bestTime == 9)

  local function defaultsFrom(text)
    local got = Save.decode(text)
    return next(got.levels) == nil and got.settings.master == Save.defaults().settings.master
  end
  check('empty save yields defaults', defaultsFrom(''))
  check('binary garbage yields defaults', defaultsFrom('\0\1\2 garbage {{{'))
  check('wrong header yields defaults', defaultsFrom('echoes-save 2\nlevel 1 1 5 0\n'))
  check('non-string yields defaults', defaultsFrom(nil))
  local mixed = Save.decode('echoes-save 1\nsetting master 9\nsetting shake maybe\nlevel x 1 2 3\nlevel 2 1 nan -4\nlevel 4 1 33.5 3\nnonsense\n')
  check('out-of-range volume is clamped', mixed.settings.master == 1)
  check('unparseable setting keeps its default', mixed.settings.shake == true)
  check('bad level lines are skipped', mixed.levels[4] and mixed.levels[4].bestTime == 33.5 and mixed.levels.x == nil)
  check('nan time and negative deaths are dropped but done kept', mixed.levels[2].done and mixed.levels[2].bestTime == nil and mixed.levels[2].bestDeaths == nil)
  local throwing = { read = function() error('disk on fire') end, write = function() error('disk on fire') end }
  check('a throwing read yields defaults', next(Save.open(throwing).data.levels) == nil)
  check('a throwing write is reported, not raised', Save.persist({ io = throwing, data = Save.defaults() }) == false)

  local data = Save.defaults()
  local first = Save.recordClear(data, 1, 20, 3)
  check('first clear is not a new best', first.first and not first.newTime and not first.newDeaths)
  local better = Save.recordClear(data, 1, 15, 3)
  check('faster clear is a new best time only', better.newTime and not better.newDeaths and data.levels[1].bestTime == 15)
  local worse = Save.recordClear(data, 1, 30, 5)
  check('slower clear keeps the records', not worse.newTime and data.levels[1].bestTime == 15 and data.levels[1].bestDeaths == 3)

  local prog = Save.defaults()
  check('level 1 is always unlocked', Progress.unlocked(prog, 1))
  check('level 2 starts locked', not Progress.unlocked(prog, 2))
  Save.recordClear(prog, 1, 10, 0)
  check('clearing a level unlocks the next', Progress.unlocked(prog, 2) and not Progress.unlocked(prog, 3))
  check('furthest is the first uncleared level', Progress.furthest(prog, 5) == 2)
  for i = 2, 5 do Save.recordClear(prog, i, 10, 0) end
  check('furthest stays on the last level once all are cleared', Progress.furthest(prog, 5) == 5)

  local function levels(n, acts)
    local out = {}
    for i = 1, n do out[i] = { act = acts and acts[i] } end
    return out
  end
  local chunked = Progress.acts(levels(10))
  check('acts without a field chunk by ACT_SIZE', #chunked == 3 and #chunked[1].indices == Progress.ACT_SIZE and #chunked[3].indices == 2 and chunked[2].label == 'ACT II')
  local explicit = Progress.acts(levels(5, { 1, false, 2, false, 2 }))
  check('explicit acts group consecutive levels', #explicit == 2 and #explicit[1].indices == 2 and #explicit[2].indices == 3)
  local inherit = Progress.acts({ { act = 1 }, {}, { act = 2 }, {}, {} })
  check('a level without act joins the previous one', #inherit == 2 and #inherit[1].indices == 2 and #inherit[2].indices == 3)
  local rows = Progress.rows(Progress.acts(levels(10)))
  check('rows label only the first row of an act', rows[1].label == 'ACT I' and rows[2].label == 'ACT II' and rows[3].label == 'ACT III')
  check('right wraps past the last level', Progress.neighbor(rows, 10, 'right') == 1)
  check('left wraps before the first level', Progress.neighbor(rows, 1, 'left') == 10)
  check('right crosses into the next act', Progress.neighbor(rows, 4, 'right') == 5)
  check('down keeps the column and clamps on short rows', Progress.neighbor(rows, 8, 'down') == 10 and Progress.neighbor(rows, 4, 'down') == 8)
  check('up wraps to the last row', Progress.neighbor(rows, 2, 'up') == 10)

  local fired = {}
  local value = 5
  local menu = Menu.new({
    { label = 'a', action = function() fired[#fired + 1] = 'a' end },
    { label = 'b', value = function() return value end, adjust = function(dir) value = value + dir end },
    { label = 'c', action = function() fired[#fired + 1] = 'c' end },
  })
  Menu.handle(menu, 'up')
  check('menu up from the first item wraps to the last', menu.index == 3)
  Menu.handle(menu, 'down')
  check('menu down from the last item wraps to the first', menu.index == 1)
  check('confirm fires the item action', Menu.handle(menu, 'confirm') == 'select' and fired[1] == 'a')
  check('left on an item without adjust does nothing', Menu.handle(menu, 'left') == nil)
  Menu.handle(menu, 'down')
  Menu.handle(menu, 'right')
  Menu.handle(menu, 'right')
  Menu.handle(menu, 'left')
  check('left and right adjust the value', value == 6)
  Menu.handle(menu, 'confirm')
  check('confirm on an adjust-only item steps it forward', value == 7)

  local esc = Input.fromKey('escape')
  check('Esc maps to back then pause', esc[1] == 'back' and esc[2] == 'pause')
  check('pad Start maps to pause only', #Input.fromButton('start') == 1 and Input.fromButton('start')[1] == 'pause')
  check('pad B backs out of menus', Input.fromButton('b')[1] == 'back')
  check('pad A confirms', Input.fromButton('a')[1] == 'confirm')
  check('pad d-pad presses are left to navPoll', #Input.fromButton('dpup') == 0)
  check('key repeat only repeats navigation', #Input.fromKey('z', true) == 0 and Input.fromKey('down', true)[1] == 'down')
  check('W navigates up', Input.fromKey('w')[1] == 'up')
  check('Enter confirms', Input.fromKey('return')[1] == 'confirm')

  local function pad(down, lefty)
    return {
      isGamepadDown = function(_, b) return down[b] == true end,
      getGamepadAxis = function(_, axis) return axis == 'lefty' and (lefty or 0) or 0 end,
    }
  end
  local nav = Input.newNavState()
  local held = pad({ dpdown = true })
  local pressed = Input.navPoll(nav, { held }, 1 / 60)
  check('held d-pad direction fires immediately', #pressed == 1 and pressed[1] == 'down')
  local count = 0
  for _ = 1, 20 do count = count + #Input.navPoll(nav, { held }, 1 / 60) end
  check('no repeat before the delay elapses', count == 0)
  for _ = 1, 40 do count = count + #Input.navPoll(nav, { held }, 1 / 60) end
  check('held direction repeats after the delay', count >= 5 and count <= 7, 'repeats=' .. count)
  Input.navPoll(nav, { pad({}) }, 1 / 60)
  check('releasing re-arms the press', #Input.navPoll(nav, { held }, 1 / 60) == 1)
  check('left stick down past deadzone navigates down', Input.navPoll(Input.newNavState(), { pad({}, 0.8) }, 1 / 60)[1] == 'down')
  check('left stick inside deadzone does not', #Input.navPoll(Input.newNavState(), { pad({}, 0.2) }, 1 / 60) == 0)

  Trans.reset()
  local calls, coverAtCall = 0, nil
  Trans.start(function() calls = calls + 1 coverAtCall = Trans.coverage() end)
  check('transition blocks input while closing', Trans.busy())
  check('a second transition is refused while one runs', Trans.start(function() end) == false)
  local peak = 0
  for _ = 1, 60 do
    Trans.update(1 / 60)
    peak = math.max(peak, Trans.coverage())
  end
  check('transition callback runs exactly once, fully covered', calls == 1 and coverAtCall == 1 and peak == 1)
  check('transition ends idle and open', not Trans.busy() and Trans.coverage() == 0)

  local world = Level.new({ name = 'arena', map = {
    '################',
    '#..............#',
    '#.P............#',
    '################',
  } })
  Solutions.run(world, { { 30, '-' } })
  check('HUD memory is the share of the buffer recorded', math.abs(Model.memory(world) - 30 / Echo.FRAMES) < 1e-9)
  Solutions.run(world, { { 1, 'X' }, { 1, '-' } })
  local slots = Model.slots(world)
  check('a cast fills the first slot and leaves the second empty', slots[1].alive and slots[1].replaying and not slots[2].alive)
  check('a short history gives a short echo', #world.echoes[1].frames == 31)
  Solutions.run(world, { { 60 * (Echo.LINGER + 1), '-' } })
  check('expired echo empties its slot', not Model.slots(world)[1].alive)
  Solutions.run(world, { { 200, '-' } })
  check('HUD memory caps at one full buffer', Model.memory(world) == 1)
end
