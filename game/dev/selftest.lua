local Level = require 'world.level'
local Levels = require 'content.levels'
local Echo = require 'world.echo'
local Solutions = require 'dev.solutions'
local Input = require 'platform.input'

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
  check('echo halts touching the veil', e.halted and math.abs(e.y + e.h - veilTop) < 0.05,
    ('echo bottom=%.3f veil top=%d'):format(e.y + e.h, veilTop))
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

local CHECKPOINT_ROWS = {
  '################',
  '#..............#',
  '#.......A......#',
  '#P.a.w..A..w.^G#',
  '############%###',
  '#..............#',
  '################',
}

local function testCheckpoint()
  local def = { name = 'waystones', map = CHECKPOINT_ROWS }
  local w = Level.new(def)
  idle(w, 5)
  check('a fresh level has no respawn point', w.respawn == nil and #w.checkpoints == 2 and not w.checkpoints[1].active)
  local lit = 0
  run(w, { { 'R', cond.atX(5 * 16 + 3) } }, function(c)
    for _, ev in ipairs(c.events) do if ev.name == 'checkpoint' then lit = lit + 1 end end
  end)
  check('touching a waystone lights it and sets the respawn point', w.respawn == 1 and w.checkpoints[1].active and lit == 1)
  run(w, { { 'L', cond.atXLeft(60) }, { 'R', cond.atX(5 * 16 + 3) } }, function(c)
    for _, ev in ipairs(c.events) do if ev.name == 'checkpoint' then lit = lit + 1 end end
  end)
  check('touching the lit waystone again does nothing', lit == 1 and w.respawn == 1)

  run(w, { { 'L', cond.atXLeft(3 * 16 + 3) }, { 190, '-' }, { 1, 'X' }, { 'R', cond.atX(11 * 16 + 3) } })
  check('a later waystone takes over as the respawn point', w.respawn == 2 and w.checkpoints[2].active and not w.checkpoints[1].active)
  run(w, { { 'R', cond.atX(12 * 16 - 4) }, { 40, '-' } })
  check('the arena is spent before respawning: echo out, door held, crumble gone',
    #w.echoes == 1 and w.doorOpen.a == true and w.crumbles[1].gone, ('echoes=%d door=%s gone=%s'):format(#w.echoes, tostring(w.doorOpen.a), tostring(w.crumbles[1].gone)))

  local r = Level.new(def, { checkpoint = w.respawn })
  idle(r, 2)
  local stand = Level.standingOn(r.checkpoints[2])
  check('respawn stands the player on the lit waystone', r.respawn == 2 and r.checkpoints[2].active
    and math.abs(r.player.x - stand.x) < 0.01 and math.abs(r.player.y - stand.y) < 0.01 and r.player.state == 'ground',
    ('x=%.1f y=%.1f state=%s'):format(r.player.x, r.player.y, r.player.state))
  check('respawn carries nothing in: no echoes, empty memory, door shut, crumble intact',
    #r.echoes == 0 and r.rec.count <= 2 and r.doorOpen.a == false and not r.crumbles[1].gone and not r.crumbles[1].crack)
  local back = Level.new(def)
  run(back, { { 'R', cond.atX(3 * 16 + 3) }, { 190, '-' }, { 1, 'X' }, { 'R', cond.atX(11 * 16 + 3) }, { 'L', cond.atXLeft(5 * 16 + 3) } })
  check('walking back onto an earlier waystone makes it the respawn point',
    back.respawn == 1 and back.checkpoints[1].active and not back.checkpoints[2].active, 'respawn=' .. tostring(back.respawn))
  local okNew = pcall(Level.new, def, { checkpoint = 3 })
  check('a respawn at a checkpoint the level lacks is refused', not okNew)
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

local function bestBottom(w, frames, input)
  local best = w.player.y + w.player.h
  for _ = 1, frames do
    Level.step(w, input)
    best = math.min(best, w.player.y + w.player.h)
  end
  return best
end

local function testOtherSideNeedsMirror()
  local w = Level.new(Levels[6])
  run(w, { { 'R', cond.atX(66) }, { 200, '-' }, { 1, 'X' }, { 'R', cond.atX(300) } })
  check('level 6: a plain echo on the reflection spot leaves the door shut',
    w.doorOpen.a == false and w.player.x <= 11 * 16 - 10 + 0.01, ('x=%.1f'):format(w.player.x))
  w = Level.new(Levels[6])
  run(w, { { 'R', cond.atX(100) }, { 200, '-' }, { 'R', cond.atX(163) }, { 1, 'X' }, { 'R', cond.atX(300) } })
  check('level 6: a mirrored echo from the wrong spot misses the plate',
    w.doorOpen.a == false and w.player.x <= 11 * 16 - 10 + 0.01, ('x=%.1f'):format(w.player.x))
end

local function testTrapdoorNeedsCast()
  local w = Level.new(Levels[7])
  run(w, { { 'R', cond.atX(190) }, { 90, '-' } })
  check('level 7: waiting on the plate drops you before the door can matter',
    w.player.y + w.player.h > 8 * 16 + 16 and w.doorOpen.a == false, ('bottom=%.1f'):format(w.player.y + w.player.h))
  run(w, { { '-', cond.grounded }, { 'R', cond.atX(400) } })
  check('level 7: the lower corridor is sealed by the door', w.player.x <= 17 * 16 - 10 + 0.01, ('x=%.1f'):format(w.player.x))
end

local function testUndertowNeedsVeilEcho()
  local w = Level.new(Levels[8])
  run(w, { { 'R', cond.atX(70) }, { '-', cond.onTop(224) }, { 200, '-' } })
  local best = bestBottom(w, 60, { jump = true })
  check('level 8: the exit ledge is out of jumping reach from the pit floor', best > 9 * 16 + 16, ('best bottom=%.1f ledge top=%d'):format(best, 9 * 16))
  run(w, { { '-', cond.grounded }, { 30, '-' }, { 1, 'J' }, { 'J', cond.apex }, { 1, 'JX' }, { '-', cond.echoArrived } })
  local e = w.echoes[#w.echoes]
  check('level 8: an echo cast at the apex from the floor parks under the veil',
    e.halted and e.y >= 13 * 16 - 0.05, ('echo top=%.1f veil bottom=%d'):format(e.y, 13 * 16))
end

local function testUnderfootNeedsEcho()
  local w = Level.new(Levels[9])
  run(w, { { 'R', cond.atX(296) }, { 120, '-' } })
  check('level 9: without an echo the hatch holds you up',
    w.player.y + w.player.h == 8 * 16 and w.doorOpen.a == false, ('bottom=%.1f'):format(w.player.y + w.player.h))
end

local SPIKES_END = 18 * 16 - 2

-- The farthest any body gets by jumping from the tunnel mouth, over every press point and hold length.
local function farthestJump(def, prepare, jumpXs, holds)
  local farthest, survivors = 0, 0
  for _, jumpX in ipairs(jumpXs) do
    for _, hold in ipairs(holds) do
      local w = Level.new(def)
      if prepare then prepare(w) end
      local script = { { 'R', cond.atX(jumpX) }, { hold, 'RJ' }, { 120, 'R' } }
      run(w, script, function(c) farthest = math.max(farthest, c.player.x) end)
      if w.player.state ~= 'dead' and w.player.x >= SPIKES_END then survivors = survivors + 1 end
    end
  end
  return farthest, survivors
end

local function range(lo, hi, step)
  local out = {}
  for v = lo, hi, step do out[#out + 1] = v end
  return out
end

local function testTunnelJumps(index)
  local def = Levels[index]
  local jumpXs, holds = range(150, 232, 2), range(1, 40, 3)
  local far, survivors = farthestJump(def, nil, jumpXs, holds)
  check(('level %d: no running jump from the tunnel mouth clears the spikes'):format(index),
    survivors == 0 and far < SPIKES_END, ('farthest x=%.1f of %d jumps, spikes end at %d'):format(far, #jumpXs * #holds, SPIKES_END))

  local function perch(w)
    local pose = { x = 240, y = 204, facing = 1, state = 'ground' }
    w.echoes[1] = Echo.new({ pose, pose })
    w.player.x, w.player.y = 240, 192
  end
  far, survivors = farthestJump(def, perch, { 246 }, holds)
  check(('level %d: a jump from the highest echo you can stand on in the tunnel still lands in the spikes'):format(index),
    survivors == 0 and far < SPIKES_END, ('farthest x=%.1f'):format(far))
end

local function testShortMemoryNeedsPatience()
  local w = Level.new(Levels[11])
  run(w, { { 'R', cond.atX(26) }, { 'RJ', cond.onTop(208, 54, 102) }, { 30, '-' },
    { 'R', cond.atX(163) }, { 1, 'X' }, { 200, 'R' } })
  local e = w.echoes[1]
  check('level 11: a short pause leaves the approach in memory, so the echo halts at the veil',
    e and e.halted and e.x >= 17 * 16 and w.doorOpen.a == false and w.player.x <= 11 * 16 - 10 + 0.01,
    e and ('echo.x=%.1f halted=%s x=%.1f'):format(e.x, tostring(e.halted), w.player.x))
end

local function testConfluenceTiming()
  local strategy = Solutions.strategies['Confluence']
  local w = Level.new(Levels[12])
  run(w, strategy.build(Solutions.decisions(strategy, { landDelay = 160 })))
  check('level 12: dawdling on the landing lets the crossing fade, the second echo misses the plate',
    w.player.state == 'ground' and w.doorOpen.a == false and w.player.x <= 21 * 16 - 10 + 0.01,
    ('state=%s x=%.1f'):format(w.player.state, w.player.x))
end

local function withoutPresses(keys)
  return (keys:gsub('[JX]', ''))
end

local function perturbed(script, dt, hold)
  local out = {}
  for _, seg in ipairs(script) do
    if type(seg[1]) == 'number' then
      out[#out + 1] = { math.max(1, seg[1] + dt), seg[2] }
    else
      out[#out + 1] = seg
      if hold > 0 then out[#out + 1] = { hold, withoutPresses(seg[1]) } end
    end
  end
  return out
end

local VARIANTS = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 3, 3 }, { -3, 3 } }

local function testSolutionSlack()
  for i = 6, #Levels do
    local failures = {}
    for _, v in ipairs(VARIANTS) do
      local w = Level.new(Levels[i])
      local ok, outcome = run(w, perturbed(Solutions.scripts[Levels[i].name], v[1], v[2]))
      if not (ok and outcome == 'cleared') then
        failures[#failures + 1] = ('dt=%+d hold=%d: %s'):format(v[1], v[2], tostring(outcome))
      end
    end
    check(('level %d "%s" solution survives timing perturbed by 3 frames'):format(i, Levels[i].name),
      #failures == 0, #failures > 0 and table.concat(failures, '; ') or ('%d variants'):format(#VARIANTS))
  end
end

-- Every decision a human makes in a strategy must have a window a human can hit: half a second, or a tile and a half.
local function testHumanSlack()
  local Slack = require 'dev.slack'
  for i, def in ipairs(Levels) do
    if Solutions.strategies[def.name] then
      local r = Slack.measure(i)
      local tight = {}
      for _, row in ipairs(r.rows) do
        local need = row.need or (row.unit == 'px' and 24 or 30)
        if row.width < need then
          tight[#tight + 1] = ('%s %d %s'):format(row.name, row.width, row.unit)
        end
      end
      check(('level %d "%s" every human decision has at least 30 frames or 24 px of slack'):format(i, def.name),
        r.nominalWins and #tight == 0, #tight > 0 and table.concat(tight, '; ') or ('%d decisions'):format(#r.rows))
    end
  end
end

local function testSolutions()
  for i, def in ipairs(Levels) do
    local script = Solutions.scripts[def.name]
    local ok, outcome = false, 'no scripted solution'
    if script then ok, outcome = run(Level.new(def), script) end
    check(('level %d "%s" scripted solution reaches the goal'):format(i, def.name),
      ok and outcome == 'cleared', ok and outcome or outcome)
  end
end

-- What a long level owes beyond a script: a slack strategy, and a room for its start and every waystone.
-- A level with a waystone is a long level. Returns the list of missing pieces.
local function contractProblems(def, solutions)
  local w = Level.new(def)
  if #w.checkpoints == 0 then return {} end
  local problems = {}
  if not solutions.strategies[def.name] then problems[#problems + 1] = 'no slack strategy' end
  local covered = {}
  for _, room in ipairs(solutions.rooms[def.name] or {}) do covered[room.from or 0] = true end
  for k = 0, #w.checkpoints do
    if not covered[k] then problems[#problems + 1] = 'no room from ' .. (k == 0 and 'the start' or 'waystone ' .. k) end
  end
  return problems
end

local function testLevelContracts()
  local long = { name = 'long', map = { '####', '#P.w', '####' } }
  local none = contractProblems(long, { strategies = {}, rooms = {} })
  check('a level with a waystone owes a strategy and rooms for its start and waystone', #none == 3, table.concat(none, '; '))
  local met = contractProblems(long, { strategies = { long = {} }, rooms = { long = { { from = nil }, { from = 1 } } } })
  check('a long level with a strategy and rooms for every respawn point owes nothing', #met == 0, table.concat(met, '; '))
  for i, def in ipairs(Levels) do
    local problems = contractProblems(def, Solutions)
    if #problems > 0 or #Level.new(def).checkpoints > 0 then
      check(('level %d "%s" meets the long-level contract'):format(i, def.name), #problems == 0, table.concat(problems, '; '))
    end
  end
end

local Cheese = require 'dev.cheese'

local function reachesExit(def, room, script)
  local w = Level.new(def, { checkpoint = room.from })
  local reached = false
  run(w, script, function(c) reached = reached or Cheese.reached(c, room.exit) end)
  return reached
end

-- Each declared room is solvable from a fresh respawn at its waystone, and none of its naive approaches reach its exit.
local function testRooms()
  for i, def in ipairs(Levels) do
    for k, room in ipairs(Solutions.rooms[def.name] or {}) do
      local label = ('level %d "%s" room %d "%s"'):format(i, def.name, k, room.name or '?')
      check(label .. ': the solve reaches the exit from a fresh respawn', room.solve ~= nil and reachesExit(def, room, room.solve))
      for _, naive in ipairs(room.naive or {}) do
        check(('%s: naive "%s" does not reach the exit'):format(label, naive[1]), not reachesExit(def, room, naive[2]))
      end
    end
  end
end

-- A corridor with one wall across it: the search must find the echo step over a short wall and nothing over a tall one.
local function wallCorridor(height)
  local rows = {}
  for r = 0, 14 do
    local line = {}
    for tx = 0, 25 do
      local ch = '.'
      if r == 0 or r == 14 or tx == 0 or tx == 25 then ch = '#'
      elseif r == 13 and tx == 1 then ch = 'P'
      elseif r == 13 and tx == 23 then ch = 'G'
      elseif tx == 12 and r >= 14 - height then ch = '#' end
      line[#line + 1] = ch
    end
    rows[#rows + 1] = table.concat(line)
  end
  return { name = 'wall ' .. height, map = rows }
end

local function testCheeseSearch()
  local planted = Cheese.search(wallCorridor(5))
  local families = {}
  for _, h in ipairs(planted.rooms[1].hits) do families[h.family] = true end
  check('cheese search finds a mid-air echo step over a 5-tile wall', families['one cast on the natural path'] == true,
    ('%d hits'):format(#planted.rooms[1].hits))
  local ladder = Cheese.search(wallCorridor(9))
  check('cheese search finds a two-cast ladder over a 9-tile wall', #ladder.rooms[1].hits > 0 and ladder.rooms[1].hits[1].family == 'ladder of two mid-air casts',
    ladder.rooms[1].hits[1] and ladder.rooms[1].hits[1].family or 'no hits')
  local control = Cheese.search(wallCorridor(10))
  check('cheese search finds nothing over a 10-tile wall', #control.rooms[1].hits == 0, ('%d hits'):format(#control.rooms[1].hits))
end

local function fakePad(down, leftx)
  return {
    isGamepadDown = function(_, b) return down[b] == true end,
    getGamepadAxis = function(_, axis) return axis == 'leftx' and (leftx or 0) or 0 end,
  }
end

local function deepEqual(a, b, seen)
  if a == b then return true end
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for k, v in pairs(a) do
    if not deepEqual(v, b[k], seen) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- Rewinding must put the world back exactly: replaying the same inputs after a rewind ends in the same state.
local function testRewind()
  local Timeline = require 'world.timeline'
  for i, def in ipairs(Levels) do
    local w = Level.new(def)
    local tl = Timeline.new(w)
    local drive = Solutions.driver(Solutions.scripts[def.name])
    local inputs, n = {}, 0
    while w.player.state ~= 'cleared' and n < 20000 do
      local input = drive(w) or {}
      n = n + 1
      inputs[n] = input
      Level.step(w, input)
      Timeline.push(tl, w)
    end
    local final = w:save()
    local back = math.min(600, n)
    for _ = 1, back do Timeline.back(tl, w) end
    local rewound = w.player.state
    for k = n - back + 1, n do Level.step(w, inputs[k]) end
    check(('level %d %q: rewinding %d steps and replaying them ends in the same state'):format(i, def.name, back),
      rewound ~= 'cleared' and w.player.state == 'cleared' and deepEqual(final, w:save()))
  end

  local w = arena {
    '##########',
    '#........#',
    '#.P...^^.#',
    '##########',
  }
  local tl = Timeline.new(w)
  for _ = 1, 120 do
    Level.step(w, { right = true })
    Timeline.push(tl, w)
  end
  check('player dies on the spikes before rewinding', w.player.state == 'dead')
  while w.player.state == 'dead' and Timeline.back(tl, w) do end
  check('rewinding from death brings the player back alive', w.player.state == 'ground' or w.player.state == 'air')
  while Timeline.back(tl, w) do end
  check('rewind stops at the start of the timeline', w.player.x == w.spawn.x and w.time == 0)
end

local function testEmbers()
  local w = arena {
    '##########',
    '#........#',
    '#.P..*...#',
    '##########',
  }
  idle(w, 10)
  check('an ember starts in place', not w:emberTaken())
  idle(w, 40, 'R')
  check('walking through an ember takes it', w:emberTaken())

  local mirrorRoom = arena {
    '#################',
    '#........#......#',
    '#P......M#..*...#',
    '#################',
  }
  idle(mirrorRoom, 10)
  run(mirrorRoom, { { 90, 'R' } })
  check('the player alone cannot reach the sealed ember', not mirrorRoom:emberTaken())
  run(mirrorRoom, { { 1, 'RX' } })
  idle(mirrorRoom, 120)
  check('a mirrored echo carries an ember out of a sealed room', mirrorRoom:emberTaken() and #mirrorRoom.echoes == 1,
    ('echo x=%s'):format(mirrorRoom.echoes[1] and ('%.0f'):format(mirrorRoom.echoes[1].x) or '-'))
end

-- Every level hides one ember off its main route, and a scripted run proves it can be carried out.
local function testEmberRoutes()
  for i, def in ipairs(Levels) do
    local count = 0
    for _, row in ipairs(def.map) do
      for _ in row:gmatch('%*') do count = count + 1 end
    end
    local label = ('level %d %q'):format(i, def.name)
    check(label .. ' has exactly one ember', count == 1, 'embers=' .. count)
    local w = Level.new(def)
    run(w, Solutions.scripts[def.name])
    check(label .. ' main route leaves the ember in place', w.player.state == 'cleared' and not w:emberTaken())
    local route = Solutions.embers[def.name]
    if route then
      local e = Level.new(def)
      local ok, err = pcall(run, e, route)
      check(label .. ' ember route takes the ember and clears the level', ok and e:emberTaken() and e.player.state == 'cleared',
        ok and ('state=' .. e.player.state) or tostring(err))
    else
      check(label .. ' has an ember route', false)
    end
  end
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
  check('pad Start maps to pause', acts[1] == 'pause')
  check('hint swaps button names for pad', Input.hint('Jump with Z, Space or Up.') == 'Jump with A.')
end

function S.run()
  testGamepadInput()
  require('dev.uitest')(check)
  testPhysics()
  testHazards()
  testDoors()
  testEchoes()
  testStandOnEcho()
  testMirror()
  testVeil()
  testCrumble()
  testDoorFloor()
  testCheckpoint()
  testStairwayNeedsEcho()
  testOtherSideNeedsMirror()
  testTrapdoorNeedsCast()
  testUndertowNeedsVeilEcho()
  testUnderfootNeedsEcho()
  testTunnelJumps(10)
  testTunnelJumps(12)
  testShortMemoryNeedsPatience()
  testConfluenceTiming()
  testSolutions()
  testRewind()
  testEmbers()
  testEmberRoutes()
  testLevelContracts()
  testRooms()
  testCheeseSearch()
  testSolutionSlack()
  testHumanSlack()
  print(('%d checks, %d failed'):format(total, failed))
  return failed == 0
end

return S
