-- Exhaustive check for the echo memory window.
-- Property, coverage, and how to read a failure: .cursor/skills/verify-echo-memory/SKILL.md
--
-- Oracle: the poses passed to Echo.record, and the poses the player actually
-- occupied at the end of each Level.step. The ring index math is not reimplemented.

local scriptDir = (arg[0] or ''):match('^(.*)/') or '.'
local root = scriptDir .. '/../../..'

local function exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

if not exists(root .. '/game/world/echo.lua') then
  root = '.'
end
if not exists(root .. '/game/world/echo.lua') then
  io.write('checker: cannot find game/world/echo.lua. Run from the repo root:\n')
  io.write('  luajit .cursor/skills/verify-echo-memory/check.lua\n')
  os.exit(1)
end

package.path = root .. '/game/?.lua;' .. root .. '/game/?/init.lua;' .. package.path

if not jit or not tostring(jit.version):find('LuaJIT 2.1', 1, true) then
  io.write('checker: this game runs on LÖVE 11, which embeds LuaJIT 2.1. Run with luajit, not another Lua.\n')
  io.write('  got: ' .. tostring(jit and jit.version) .. '\n')
  os.exit(1)
end

local Echo = require 'world.echo'
local Level = require 'world.level'
local Player = require 'world.player'

-- The promise in the README: last 3 seconds, 180 frames at 60 Hz, body 10 px wide.
local EXPECTED_FRAMES = 180
local EXPECTED_WIDTH = 10
local EXPECTED_DT = 1 / 60
local RINGS = 3

local function die(lines)
  io.write('FAIL  echo memory\n\n')
  for i = 1, #lines do io.write(lines[i], '\n') end
  os.exit(1)
end

local function checkerFault(text)
  die({ 'checker: ' .. text, 'This is a fault in the check, not a demonstrated break in the game.' })
end

local function num(v)
  if type(v) ~= 'number' then return tostring(v) end
  return string.format('%.6g', v)
end

local function poseStr(p)
  if not p then return 'nil' end
  return string.format('x=%s y=%s facing=%s state=%s', num(p.x), num(p.y), tostring(p.facing), tostring(p.state))
end

local function same(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.facing == b.facing and a.state == b.state
end

-- Centre column of the shrine tile. This is the axis World:cast passes to Echo.mirror.
local function shrineAxis(cell)
  return cell.tx * Level.T + Level.T / 2
end

-- Left edge of a width-px body reflected about axis. Echo.mirror does this with Echo.W.
local function reflectedLeft(x, axis)
  return 2 * axis - x - EXPECTED_WIDTH
end

local function windowOf(log, n)
  local count = math.min(n, EXPECTED_FRAMES)
  local start = n - count
  local out = {}
  for k = 1, count do out[k] = log[start + k] end
  return out, start
end

local function checkConstants()
  if Level.DT ~= EXPECTED_DT then
    die({
      string.format('Level.DT is %s. One recorded frame is one Level.step, and 180 frames are three seconds only while DT stays 1/60.', num(Level.DT)),
    })
  end
  if Echo.FRAMES ~= EXPECTED_FRAMES then
    die({
      string.format('Echo.FRAMES is %s. A cast replays the last three seconds, which is 180 frames at 60 Hz.', tostring(Echo.FRAMES)),
      'If that window was changed on purpose, update EXPECTED_FRAMES in this file and the property in SKILL.md, re-run, and only then move the sync commit.',
    })
  end
  if Echo.W ~= EXPECTED_WIDTH or Player.W ~= EXPECTED_WIDTH then
    die({
      string.format('The reflected ghost uses Echo.W (%s) as the body width. The player is Player.W (%s). Both are 10 in the current game.', tostring(Echo.W), tostring(Player.W)),
      'A mismatch reflects a body that is not the one that was recorded.',
    })
  end
end

local function checkSnapshot(rec, log, n)
  local ok, snap = pcall(Echo.snapshot, rec)
  if not ok then
    die({
      string.format('After %d calls to Echo.record (head=%d, count=%d), Echo.snapshot raised an error:', n, rec.head, rec.count),
      '  ' .. tostring(snap),
    })
  end
  local expect, start = windowOf(log, n)
  if #snap ~= #expect then
    die({
      string.format('After %d calls to Echo.record (head=%d, count=%d), Echo.snapshot returned %d poses.', n, rec.head, rec.count, #snap),
      string.format('The window is the last %d recorded poses (every pose so far, when fewer than %d were recorded).', #expect, EXPECTED_FRAMES),
    })
  end
  for k = 1, #expect do
    if not same(snap[k], expect[k]) then
      die({
        string.format('After %d calls to Echo.record (head=%d, count=%d), snapshot frame %d is not the pose from record call %d.', n, rec.head, rec.count, k, start + k),
        'Frame 1 is the oldest pose still kept. The last frame is the pose just recorded.',
        '  expected ' .. poseStr(expect[k]),
        '  got      ' .. poseStr(snap[k]),
      })
    end
  end
  return snap
end

local function place(player, x, y)
  player.x, player.y = x, y
  player.vx, player.vy = 0, 0
end

-- x,y that overlap one tile and no other. Player is 10 x 12.
local function standIn(cell)
  return cell.tx * Level.T + 1, cell.ty * Level.T + 1
end

local function castGhost(w, onShrine)
  local shrine = w.mirrors[1]
  if not shrine then checkerFault('the cast level has no mirror shrine.') end
  w.echoes = {}
  if onShrine then
    place(w.player, standIn(shrine))
    if not w:touchedMirror() then
      checkerFault('the player was placed on the shrine tile but World:touchedMirror did not see them.')
    end
  else
    place(w.player, 2, 2)
    if w:touchedMirror() then
      checkerFault('the player was placed off the shrine but World:touchedMirror still sees them.')
    end
  end
  w:cast()
  return shrine
end

local function checkCast(w, log, n)
  local expect = windowOf(log, n)
  local shrine = castGhost(w, false)
  local plain = w.echoes[1]
  if not plain then
    die({ string.format('After %d recorded poses, World:cast with the player off the shrine spawned no ghost.', n) })
  end
  if plain.mirrored then
    die({ string.format('After %d recorded poses, a cast off the shrine was marked mirrored.', n) })
  end
  if #plain.frames ~= #expect then
    die({
      string.format('After %d recorded poses, the ghost has %d frames, not %d.', n, #plain.frames, #expect),
    })
  end
  for k = 1, #expect do
    if not same(plain.frames[k], expect[k]) then
      die({
        string.format('After %d recorded poses, a cast off the shrine put the wrong pose in ghost frame %d.', n, k),
        'Frame 1 is where the ghost appears (oldest). The last frame is the pose at the cast.',
        '  expected ' .. poseStr(expect[k]),
        '  got      ' .. poseStr(plain.frames[k]),
      })
    end
  end

  local axis = shrineAxis(shrine)
  castGhost(w, true)
  local ghost = w.echoes[1]
  if not ghost or not ghost.mirrored then
    die({ string.format('After %d recorded poses, World:cast with the player on the shrine did not spawn a mirrored ghost.', n) })
  end
  for k = 1, #expect do
    local want = {
      x = reflectedLeft(expect[k].x, axis),
      y = expect[k].y,
      facing = -expect[k].facing,
      state = expect[k].state,
    }
    if not same(ghost.frames[k], want) then
      die({
        string.format('After %d recorded poses, mirrored ghost frame %d is not the shrine reflection of record call %d.', n, k, n - #expect + k),
        string.format('The shrine centre column is x=%s. The body is %d px wide, so the reflected left edge is 2*axis - x - %d.', num(axis), EXPECTED_WIDTH, EXPECTED_WIDTH),
        '  expected ' .. poseStr(want),
        '  got      ' .. poseStr(ghost.frames[k]),
      })
    end
  end

  local ok, again = pcall(Echo.snapshot, w.rec)
  if not ok then
    die({ 'Echo.snapshot raised an error after a mirror cast:', '  ' .. tostring(again) })
  end
  for k = 1, #expect do
    if not same(again[k], expect[k]) then
      local rewritten = again[k] and again[k].x == reflectedLeft(expect[k].x, axis) and again[k].facing == -expect[k].facing
      local lines = {
        string.format('After %d calls to Echo.record, World:cast ran with the player standing on the mirror shrine.', n),
        'The ghost was reflected. The recorder was rewritten as well, so the memory a later cast or a rewind would replay is no longer the path that was walked.',
        string.format('Pose %d (record call %d) is the oldest in the window.', k, n - #expect + k),
        '  recorded ' .. poseStr(expect[k]),
        '  memory   ' .. poseStr(again[k]),
      }
      if rewritten then
        lines[#lines + 1] = 'The stored pose now equals its own mirror image. Echo.snapshot handed Echo.mirror the recorder\'s own tables instead of copies.'
      end
      die(lines)
    end
  end
end

local function poseFor(n)
  -- Unique, non-integer, some negative: a wrong slot cannot hide behind a repeated coordinate.
  local state = (n % 3 == 0) and 'air' or 'ground'
  local facing = (n % 2 == 0) and -1 or 1
  return { x = n * 3 - 1000.5, y = -n * 2 + 0.25, facing = facing, state = state }
end

local function checkEveryRecorderState()
  local map = { '#####', '#M..#', '#...#', '#P..#', '#####' }
  local w = Level.new({ name = 'echo-memory', map = map })
  if #w.mirrors ~= 1 then checkerFault('expected one shrine in the cast level.') end
  local log = {}
  local limit = EXPECTED_FRAMES * RINGS
  for n = 1, limit do
    local p = poseFor(n)
    Echo.record(w.rec, p.x, p.y, p.facing, p.state)
    log[n] = p
    checkSnapshot(w.rec, log, n)
    if n >= 2 then checkCast(w, log, n) end
  end

  local fresh = Echo.snapshot(Echo.newRecorder())
  if #fresh ~= 0 then
    die({ string.format('A new recorder snapshots to %d poses; it must snapshot to none.', #fresh) })
  end
  return limit
end

local function corridor(withShrine)
  local inner = 64
  local chars = {}
  for i = 1, inner do chars[i] = '.' end
  chars[2] = 'P'
  if withShrine then chars[8] = 'M' end
  local solid = string.rep('#', inner + 2)
  local open = '#' .. string.rep('.', inner) .. '#'
  local mid = '#' .. table.concat(chars) .. '#'
  return { solid, open, mid, solid }
end

local function observe(w)
  local p = w.player
  return { x = p.x, y = p.y, facing = p.facing, state = p.state }
end

local function play(withShrine, frames)
  local w = Level.new({ name = 'echo-memory-play', map = corridor(withShrine) })
  local log = {}
  for i = 1, frames do
    Level.step(w, { right = true })
    local p = w.player
    if p.state == 'dead' or p.state == 'cleared' then
      checkerFault(string.format('the player reached state %s while running the corridor. The map is too short or blocked.', p.state))
    end
    log[i] = observe(w)
  end
  return w, log
end

local function checkPlayedWindow(w, log, ghost, mirrored, axis)
  local n = #log
  local expect = windowOf(log, n)
  if #ghost.frames ~= #expect then
    die({
      string.format('After %d Level.step frames, the ghost has %d frames, not the last %d occupied poses.', n, #ghost.frames, #expect),
    })
  end
  for k = 1, #expect do
    local want = expect[k]
    if mirrored then
      want = {
        x = reflectedLeft(expect[k].x, axis),
        y = expect[k].y,
        facing = -expect[k].facing,
        state = expect[k].state,
      }
    end
    if not same(ghost.frames[k], want) then
      die({
        string.format('After %d Level.step frames, ghost frame %d does not match where the player was at step %d%s.',
          n, k, n - #expect + k, mirrored and ' (reflected about the shrine)' or ''),
        'Level.step records the pose after it moves the player, then casts. Frame 1 is the oldest kept pose.',
        '  expected ' .. poseStr(want),
        '  got      ' .. poseStr(ghost.frames[k]),
      })
    end
  end
end

local function checkLevelStep()
  local frames = EXPECTED_FRAMES + 120
  local w, log = play(false, frames)
  local oldestX = log[#log - EXPECTED_FRAMES + 1].x
  local newestX = log[#log].x
  if not (newestX > oldestX) then
    checkerFault('the corridor run did not move, so a shifted window could still match. Lengthen the map.')
  end
  Level.step(w, { cast = true })
  log[#log + 1] = observe(w)
  local ghost = w.echoes[1]
  if not ghost or ghost.mirrored then
    die({ 'A cast after running, off any shrine, did not spawn an ordinary ghost.' })
  end
  checkPlayedWindow(w, log, ghost, false)

  local shrineWorld, shrineLog = play(true, frames)
  local shrine = shrineWorld.mirrors[1]
  if not shrine then checkerFault('the play level has no shrine.') end
  place(shrineWorld.player, standIn(shrine))
  if shrineWorld.player.state ~= 'ground' and shrineWorld.player.state ~= 'air' then
    checkerFault('the player was not alive when placed on the shrine.')
  end
  Level.step(shrineWorld, { cast = true })
  shrineLog[#shrineLog + 1] = observe(shrineWorld)
  local reflected = shrineWorld.echoes[#shrineWorld.echoes]
  if not reflected or not reflected.mirrored then
    die({
      'After a full memory, Level.step cast with the player overlapping the shrine, and no mirrored ghost appeared.',
      'World:touchedMirror after the step: ' .. tostring(shrineWorld:touchedMirror() ~= nil),
    })
  end
  local axis = shrineAxis(shrine)
  checkPlayedWindow(shrineWorld, shrineLog, reflected, true, axis)

  local memory = Echo.snapshot(shrineWorld.rec)
  local expect = windowOf(shrineLog, #shrineLog)
  for k = 1, #expect do
    if not same(memory[k], expect[k]) then
      die({
        'Level.step cast on the shrine reflected the ghost and also rewrote the recorder.',
        string.format('The pose from step %d no longer matches where the player was.', #shrineLog - #expect + k),
        '  walked  ' .. poseStr(expect[k]),
        '  memory  ' .. poseStr(memory[k]),
        'A later cast, or a rewind that shares those frames, would replay the reflection as if it had been walked.',
      })
    end
  end
  return frames + 1
end

local started = os.clock()
checkConstants()
local recorderStates = checkEveryRecorderState()
local played = checkLevelStep()
local seconds = os.clock() - started

io.write('PASS  echo memory\n')
io.write('A cast\'s ghost is the last 180 recorded poses, oldest first (every pose so far, when fewer were recorded).\n')
io.write('Reflecting that ghost at a mirror shrine does not rewrite the memory it was copied from.\n')
io.write(string.format('Checked every recorder length from 0 through %d (%d full rings), including a mirror cast from length 2 up.\n', recorderStates, RINGS))
io.write(string.format('Checked a real Level.step run of %d frames, one plain cast and one shrine cast, both past the wrap.\n', played))
io.write(string.format('Runtime: %s in %.3fs\n', jit.version, seconds))
os.exit(0)
