local Level = require 'level'
local Levels = require 'levels'
local Echo = require 'echo'
local Solutions = require 'solutions'
local Input = require 'input'

local S = {}

local total, failed = 0, 0
local run, cond = Solutions.run, Solutions.cond

local function check(name, ok, detail)
  total = total + 1
  if not ok then failed = failed + 1 end
  print(('%s  %s%s'):format(ok and 'PASS' or 'FAIL', name, detail and ('  [' .. detail .. ']') or ''))
end

local function arena(rows)
  return Level.new({ name = 'arena', map = rows })
end

local function idle(w, frames, keys)
  run(w, { { frames, keys or '-' } })
end

local function testPhysics()
  local w = arena {
    '################',
    '#..............#',
    '#..............#',
    '#..............#',
    '#..............#',
    '#..............#',
    '#.P............#',
    '################',
  }
  local floorTop = 7 * 16
  idle(w, 90)
  local p = w.player
  check('player lands on floor', p.state == 'ground' and math.abs(p.y + p.h - floorTop) < 0.01,
    ('bottom=%.2f expected %d'):format(p.y + p.h, floorTop))
  check('player stops falling', p.vy == 0 and p.state == 'ground', 'vy=' .. p.vy)

  local function peak(frames, heldFrames)
    local top, minY = w.player.y, w.player.y
    for f = 1, frames do
      Level.step(w, { jump = f <= heldFrames })
      minY = math.min(minY, w.player.y)
    end
    return top - minY
  end

  local full = peak(50, 50)
  check('full jump reaches 44-54px', full >= 44 and full <= 54, ('apex=%.1f'):format(full))
  idle(w, 60)
  local hop = peak(40, 3)
  check('released jump is a short hop (under 28px)', hop > 4 and hop < 28, ('hop=%.1f'):format(hop))

  local ledge = arena {
    '##########',
    '#........#',
    '#........#',
    '#P.......#',
    '###...####',
  }
  idle(ledge, 1)
  run(ledge, { { 'R', function(c) return c.player.state == 'air' end } })
  local before = ledge.player.y
  for _ = 1, 4 do Level.step(ledge, { right = true }) end
  Level.step(ledge, { right = true, jump = true })
  check('coyote time allows a jump just after leaving a ledge',
    ledge.player.vy < 0 and ledge.player.y < before + 4,
    ('vy=%.1f'):format(ledge.player.vy))

  local late = arena {
    '##########',
    '#........#',
    '#........#',
    '#P.......#',
    '###...####',
  }
  idle(late, 1)
  run(late, { { 'R', function(c) return c.player.state == 'air' end } })
  for _ = 1, 9 do Level.step(late, { right = true }) end
  Level.step(late, { right = true, jump = true })
  check('no jump once coyote time has expired', late.player.vy > 0, ('vy=%.1f'):format(late.player.vy))
end

local function testHazards()
  local spikes = arena {
    '##########',
    '#........#',
    '#........#',
    '#P..^^...#',
    '##########',
  }
  run(spikes, { { 'R', cond.atX(1000) } })
  check('spikes kill', spikes.player.state == 'dead', 'state=' .. spikes.player.state)

  local gap = arena {
    '########',
    '#......#',
    '#P.....#',
    '#.#..###',
  }
  run(gap, { { 'R', cond.atX(1000) } })
  check('falling into the void kills', gap.player.state == 'dead', 'state=' .. gap.player.state)
end

local function testDoors()
  local rows = {
    '############',
    '#.....A....#',
    '#.....A....#',
    '#P.a..A...G#',
    '############',
  }
  local w = arena(rows)
  idle(w, 30)
  check('door closed with nothing on plate', w.doorOpen.a == false)
  run(w, { { 'R', cond.atX(1000) } })
  check('closed door blocks the player', w.player.x <= 6 * 16 - 10 + 0.01, ('x=%.2f'):format(w.player.x))

  w = arena(rows)
  run(w, { { 'R', cond.atX(3 * 16 + 3) } })
  check('door opens while the player stands on the plate', w.doorOpen.a == true)
  idle(w, 200)
  idle(w, 1, 'X')
  check('cast creates an echo', #w.echoes == 1)
  run(w, { { 'R', cond.atX(3 * 16 + 20) } })
  check('door open while an echo holds the plate and the player is off it',
    w.doorOpen.a == true and w.plates[1].pressed == true)
  run(w, { { 'R', cond.atX(8 * 16) } })
  check('player passes through the door held by the echo', w.player.x >= 8 * 16, ('x=%.1f'):format(w.player.x))
  idle(w, 60 * 9)
  check('echo expires and the door closes again', #w.echoes == 0 and w.doorOpen.a == false)
end

local function testEchoes()
  local w = arena {
    '####################',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#P.................#',
    '####################',
  }
  run(w, { { 120, 'R' }, { 100, '-' } })
  local castX = w.player.x
  idle(w, 1, 'X')
  local e = w.echoes[1]
  check('echo copies 180 recorded frames', e ~= nil and #e.frames == 180, e and ('frames=' .. #e.frames))
  idle(w, 179)
  check('echo ends at the pose where it was cast',
    math.abs(w.echoes[1].x - castX) < 0.01 and w.echoes[1].i == 180,
    ('echo.x=%.2f cast=%.2f'):format(w.echoes[1].x, castX))
  idle(w, 60 * 4 + 40)
  check('echo lingers 4s then fades away', #w.echoes == 0)

  w = arena {
    '####################',
    '#..................#',
    '#P.................#',
    '####################',
  }
  idle(w, 30)
  local first
  for i = 1, 3 do
    idle(w, 1, 'X')
    idle(w, 20)
    if i == 1 then first = w.echoes[1] end
  end
  check('at most 2 echoes, oldest dropped', #w.echoes == Echo.MAX and w.echoes[1] ~= first and w.echoes[2] ~= first)
end

local function testStandOnEcho()
  local rows = {
    '####################',
    '#..................#',
    '#..................#',
    '#..................#',
    '#P.................#',
    '####################',
  }
  local w = arena(rows)
  idle(w, 30)
  local hoverY = w.player.y - 36
  local pose = { x = 120, y = hoverY, facing = 1, state = 'air' }
  w.echoes[1] = Echo.new({ pose, pose })
  w.player.x = 116
  run(w, { { 'J', cond.onLastEcho } })
  check('player can land on an echo', w.player.support == w.echoes[1])
  idle(w, 40)
  check('player keeps standing on the echo',
    math.abs(w.player.y - (hoverY - w.player.h)) < 0.01 and w.player.state == 'ground',
    ('y=%.2f expected %.2f'):format(w.player.y, hoverY - w.player.h))

  w = arena(rows)
  idle(w, 30)
  local floorY = w.player.y
  local path = {}
  for i = 1, 180 do path[i] = { x = 40 + i * 0.5, y = floorY - 20, facing = 1, state = 'ground' } end
  w.echoes[1] = Echo.new(path)
  w.player.x, w.player.y = 50, floorY - 20 - w.player.h
  idle(w, 20)
  local offset = w.player.x - w.echoes[1].x
  idle(w, 100)
  local drift = (w.player.x - w.echoes[1].x) - offset
  check('moving echo carries the player', math.abs(drift) < 0.01 and w.player.support == w.echoes[1],
    ('drift=%.3f'):format(drift))

  w = arena(rows)
  idle(w, 30)
  w.echoes[1] = Echo.new({ { x = 120, y = w.player.y - 24, facing = 1, state = 'air' }, { x = 120, y = w.player.y - 24, facing = 1, state = 'air' } })
  w.player.x = 120
  local startY = w.player.y
  local minY = startY
  for f = 1, 30 do
    Level.step(w, { jump = f < 20 })
    minY = math.min(minY, w.player.y)
  end
  check('echoes are one-way: jumping up through one from below works', minY < startY - 30 and w.player.state ~= 'dead',
    ('minY=%.1f startY=%.1f'):format(minY, startY))
end

local function testMirror()
  local rows = {
    '###########',
    '#.....#...#',
    '#.....#...#',
    '#....A#...#',
    '#P..M.#a..#',
    '###########',
  }
  local w = arena(rows)
  run(w, { { 'R', cond.atX(19) }, { 200, '-' } })
  local standX = w.player.x
  run(w, { { 'R', cond.atX(4 * 16 + 3) } })
  idle(w, 1, 'X')
  local e = w.echoes[1]
  local axis = 4 * 16 + 8
  check('cast on the mirror spawns a mirrored echo', e and e.mirrored and math.abs(e.x - (2 * axis - standX - e.w)) < 0.01,
    e and ('echo.x=%.1f expected %.1f'):format(e.x, 2 * axis - standX - e.w))
  check('mirrored echo faces the other way', e and e.facing == -1)
  idle(w, 1)
  check('mirrored echo holds the plate in the sealed room', w.doorOpen.a == true and w.plates[1].pressed)
  local inWall = false
  for _ = 1, 180 do
    Level.step(w, {})
    local ex = w.echoes[1].x
    inWall = inWall or (ex > 6 * 16 - 10 and ex < 7 * 16)
  end
  check('mirrored echo walks through the wall', inWall, ('x=%.1f'):format(w.echoes[1].x))
  w = arena(rows)
  run(w, { { 'R', cond.atX(19) }, { 200, '-' } })
  idle(w, 1, 'X')
  check('cast off the mirror is a plain echo', not w.echoes[1].mirrored and w.doorOpen.a == false)
end

local function testVeil()
  local rows = {
    '##########',
    '#P.......#',
    '###......#',
    '#........#',
    '#..~~~~..#',
    '#........#',
    '#........#',
    '#........#',
    '##########',
  }
  local w = arena(rows)
  run(w, { { 'R', cond.atX(4 * 16 + 3) }, { '-', cond.grounded } })
  check('player falls through a veil', w.player.y + w.player.h == 8 * 16, ('bottom=%.1f'):format(w.player.y + w.player.h))
  idle(w, 1, 'X')
  run(w, { { '-', function(c) return c.echoes[1]:arrived() end } })
  local e = w.echoes[1]
  local veilTop = 4 * 16
  check('echo halts just above the veil', e.halted and e.y + e.h <= veilTop and e.y + e.h > veilTop - 6,
    ('echo bottom=%.1f veil top=%d'):format(e.y + e.h, veilTop))
  local haltY = e.y
  idle(w, 30)
  check('halted echo stays put', w.echoes[1].y == haltY and w.echoes[1]:isSolid())
  idle(w, 60 * 4 + 20)
  check('halted echo fades like an arrived one', #w.echoes == 0)
end

local function testCrumble()
  local rows = {
    '##########',
    '#P.......#',
    '####%#####',
    '#........#',
    '#........#',
    '##########',
  }
  local w = arena(rows)
  idle(w, 20)
  local c = w.crumbles[1]
  run(w, { { 'R', cond.atX(4 * 16) }, { '-', function(c2) return c2.player.state == 'air' end } })
  check('crumble gives way half a second after it is stood on', c.gone and w.player.y > 2 * 16 - 12,
    ('gone=%s y=%.1f'):format(tostring(c.gone), w.player.y))
  run(w, { { '-', cond.grounded } })
  idle(w, 60 * 3 + 5)
  check('crumble regrows after three seconds', not c.gone)
  w = arena(rows)
  c = w.crumbles[1]
  idle(w, 20)
  local pose = { x = 4 * 16 + 3, y = 2 * 16 - 12, facing = 1, state = 'ground' }
  w.echoes[1] = Echo.new({ pose, pose })
  idle(w, 40)
  check('an echo standing on a crumble breaks it too', c.gone)
  w = arena(rows)
  c = w.crumbles[1]
  c.gone, c.regrow = true, 0.01
  w.player.x, w.player.y = 4 * 16 + 3, 2 * 16 + 2
  idle(w, 5)
  check('crumble does not regrow around a body inside it', c.gone)
end

local function testDoorFloor()
  local w = arena {
    '############',
    '#..........#',
    '#..........#',
    '#P....a....#',
    '######AA####',
    '######AA####',
    '#..........#',
    '#..........#',
    '############',
  }
  run(w, { { 'R', cond.atX(6 * 16 + 3) }, { 190, '-' }, { 1, 'X' }, { 'R', cond.atX(7 * 16) }, { 60, '-' } })
  check('an open door in the floor drops the player', w.player.y + w.player.h == 8 * 16 and w.player.state == 'ground',
    ('bottom=%.1f'):format(w.player.y + w.player.h))
end

local function testStairwayNeedsEcho()
  local w = Level.new(Levels[3])
  run(w, { { 'R', cond.atX(66) }, { 'RJ', cond.onTop(192, 80) } })
  local ledgeTop = 8 * 16
  Level.step(w, {})
  local highest = w.player.y + w.player.h
  for f = 1, 60 do
    Level.step(w, { right = true, jump = f < 40 })
    highest = math.min(highest, w.player.y + w.player.h)
  end
  check('level 3 ledge is out of reach without an echo', highest < 192 - 40 and highest > ledgeTop + 8,
    ('best bottom=%.1f ledge top=%d'):format(highest, ledgeTop))
end

local function testSolutions()
  for i, def in ipairs(Levels) do
    local w = Level.new(def)
    local ok, outcome = run(w, Solutions.scripts[i])
    check(('level %d "%s" scripted solution reaches the goal'):format(i, def.name),
      ok and outcome == 'cleared', ok and outcome or outcome)
  end
end

local function fakePad(down, leftx)
  return {
    isGamepadDown = function(_, b) return down[b] == true end,
    getGamepadAxis = function(_, axis) return axis == 'leftx' and (leftx or 0) or 0 end,
  }
end

local function testGamepadInput()
  local noKeys = function() return false end
  local function read(pad) return Input.read({ pad }, noKeys) end
  local idle = read(fakePad({}))
  check('pad idle produces no input', not (idle.left or idle.right or idle.jump or idle.cast))
  check('pad A held jumps', read(fakePad({ a = true })).jump)
  check('pad stick left past deadzone moves left', read(fakePad({}, -0.6)).left)
  local inside = read(fakePad({}, 0.3))
  check('pad stick inside deadzone does nothing', not inside.left and not inside.right)
  check('pad dpad right moves right', read(fakePad({ dpright = true })).right)
  check('pad X casts', read(fakePad({ x = true })).cast)
  check('pad dpad up does not jump', not read(fakePad({ dpup = true })).jump)
  check('pad use switches last device', Input.lastDevice == 'pad')
  Input.read({}, function(k) return k == 'z' end)
  check('keyboard use switches last device back', Input.lastDevice == 'key')
  local acts = Input.fromButton('start')
  check('pad Start maps to confirm', acts[1] == 'confirm')
  check('hint swaps button names for pad', Input.hint('Jump with Z, Space or Up.') == 'Jump with A.')
end

function S.run()
  testGamepadInput()
  testPhysics()
  testHazards()
  testDoors()
  testEchoes()
  testStandOnEcho()
  testMirror()
  testVeil()
  testCrumble()
  testDoorFloor()
  testStairwayNeedsEcho()
  testSolutions()
  print(('%d checks, %d failed'):format(total, failed))
  return failed == 0
end

return S
